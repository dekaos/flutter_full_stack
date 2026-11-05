import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_full_stack_flutter/core/backup_exclusion.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// [kb] KB standing in for a pack. Not all zeros: a piece out of place has to
/// change the digest, or a resume that lined up wrongly would pass.
Uint8List _pack(int kb) =>
    Uint8List.fromList([for (var i = 0; i < kb * 1024; i++) i * 7 % 251]);

String _digest(List<int> bytes) => crypto.sha256.convert(bytes).toString();

/// For a pack already on disk, which is not checked again.
const _unchecked = 'not checked: already on disk';

/// Serves [chunks] KB of [_pack], pausing now and then so the transfer spans
/// several progress intervals instead of finishing inside one.
///
/// [requests] counts what reached the server, which is how a test tells one
/// shared download from two racing ones; [ranges] records the `Range` each
/// one asked for. A server that does not do [ranges] answers every request
/// with the whole pack, and [dropFirstAfter] cuts the first response off
/// after that many bytes, the way a phone losing its signal does.
Future<HttpServer> _server({
  int chunks = 500,
  int status = 200,
  List<String>? requests,
  List<String?>? ranges,
  bool doesRanges = true,
  int? dropFirstAfter,
}) async {
  final pack = _pack(chunks);
  var served = 0;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    requests?.add(request.uri.path);
    final range = request.headers.value(HttpHeaders.rangeHeader);
    ranges?.add(range);
    final response = request.response;
    if (status != 200) {
      response.statusCode = status;
      await response.close();
      return;
    }
    var from = 0;
    if (doesRanges && range != null) {
      from = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)![1]!);
      if (from >= pack.length) {
        response
          ..statusCode = HttpStatus.requestedRangeNotSatisfiable
          ..headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes */${pack.length}',
          );
        await response.close();
        return;
      }
      response
        ..statusCode = HttpStatus.partialContent
        ..headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $from-${pack.length - 1}/${pack.length}',
        );
    }
    response.headers.contentLength = pack.length - from;
    if (served++ == 0 && dropFirstAfter != null) {
      final socket = await response.detachSocket();
      socket.add(pack.sublist(from, from + dropFirstAfter));
      await socket.flush();
      socket.destroy();
      return;
    }
    for (var at = from, i = 0; at < pack.length; at += 1024, i++) {
      response.add(pack.sublist(at, (at + 1024).clamp(0, pack.length)));
      if (i % 100 == 0) {
        await response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
    }
    await response.close();
  });
  return server;
}

/// Records what would have been kept out of the backup, and can fail the way
/// the platform call can.
class _FakeBackup implements BackupExclusion {
  _FakeBackup({this.fails = false});

  final bool fails;
  final excluded = <String>[];

  @override
  Future<void> exclude(String path) async {
    if (fails) throw StateError('could not set the flag');
    excluded.add(path);
  }
}

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('model_store_test');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('progress is throttled, not one event per network chunk', () async {
    final server = await _server();
    addTearDown(() => server.close(force: true));

    final events = <DownloadProgress>[];
    final store = ModelStore(
      baseUrl: 'http://${server.address.host}:${server.port}',
      directory: temp,
      progressInterval: const Duration(milliseconds: 50),
    );

    final file = await store.ensure(
      'model.onnx',
      sha256: _digest(_pack(500)),
      onProgress: events.add,
    );

    expect(file.existsSync(), isTrue);
    expect(file.readAsBytesSync(), _pack(500));
    // 500 chunks arrived. Reporting each one means a Riverpod state update and
    // a widget rebuild per network packet, which is what made a 355 MB pack
    // crawl while the server was serving at 800 MB/s.
    expect(events.length, lessThan(50));
    // The throttle must still let the bar reach the end.
    expect(events.last.received, 500 * 1024);
    expect(events.last.fraction, 1.0);
    // And the last thing it says is that the pack is being checked.
    expect(events.last.checking, isTrue);
    expect(events.where((e) => e.checking), hasLength(1));
  });

  test('a download refused outright leaves nothing behind', () async {
    final server = await _server(status: 404);
    addTearDown(() => server.close(force: true));

    final store = ModelStore(
      baseUrl: 'http://${server.address.host}:${server.port}',
      directory: temp,
    );

    await expectLater(
      store.ensure('model.onnx', sha256: _digest(_pack(500))),
      throwsA(isA<HttpException>()),
    );
    // No byte arrived, so there is not even a partial file to resume.
    expect(temp.listSync(), isEmpty);
  });

  test('a pack already on disk is not downloaded again', () async {
    final server = await _server();
    addTearDown(() => server.close(force: true));

    final existing = File('${temp.path}/model.onnx')..writeAsStringSync('kept');
    final store = ModelStore(
      baseUrl: 'http://${server.address.host}:${server.port}',
      directory: temp,
    );

    final file = await store.ensure('model.onnx', sha256: _unchecked);

    expect(file.readAsStringSync(), 'kept');
    expect(existing.lengthSync(), 4);
  });

  test('asking twice while downloading fetches the pack once', () async {
    final requests = <String>[];
    final server = await _server(requests: requests);
    addTearDown(() => server.close(force: true));
    final store = ModelStore(
      baseUrl: 'http://${server.address.host}:${server.port}',
      directory: temp,
    );

    // The learner leaves the practice screen mid-download and comes back:
    // the second call must join the first, not delete its partial file and
    // start again.
    final first = store.ensure('model.onnx', sha256: _digest(_pack(500)));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(store.isDownloading('model.onnx'), isTrue);
    final joined = <DownloadProgress>[];
    final second = store.ensure(
      'model.onnx',
      sha256: _digest(_pack(500)),
      onProgress: joined.add,
    );

    final files = await Future.wait([first, second]);

    expect(requests, ['/model.onnx']);
    expect(files[0].path, files[1].path);
    expect(files[0].lengthSync(), 500 * 1024);
    expect(joined.last.received, 500 * 1024);
    expect(store.isDownloading('model.onnx'), isFalse);
  });

  test('a listener that throws does not abort the download', () async {
    final server = await _server();
    addTearDown(() => server.close(force: true));
    final store = ModelStore(
      baseUrl: 'http://${server.address.host}:${server.port}',
      directory: temp,
      progressInterval: Duration.zero,
    );

    // What a torn-down screen does when it is called back.
    final reported = <Object>[];
    final file = await runZonedGuarded(
      () => store.ensure(
        'model.onnx',
        sha256: _digest(_pack(500)),
        onProgress: (_) => throw StateError('screen is gone'),
      ),
      (error, _) => reported.add(error),
    );

    expect(file?.lengthSync(), 500 * 1024);
    // Not swallowed: reported, just not allowed to kill the transfer.
    expect(reported, isNotEmpty);
  });

  test('a pack landing is announced', () async {
    final server = await _server(chunks: 10);
    addTearDown(() => server.close(force: true));
    final store = ModelStore(
      baseUrl: 'http://${server.address.host}:${server.port}',
      directory: temp,
    );
    final changes = <String>[];
    final subscription = store.changes.listen(changes.add);
    addTearDown(subscription.cancel);

    await store.ensure('model.onnx', sha256: _digest(_pack(10)));
    await store.remove('model.onnx');
    await Future<void>.delayed(Duration.zero);

    expect(changes, ['model.onnx', 'model.onnx']);
  });

  test('a pack that lands is kept out of the backup', () async {
    final server = await _server(chunks: 10);
    addTearDown(() => server.close(force: true));
    final backup = _FakeBackup();
    final packs = Directory('${temp.path}/packs');
    final store = ModelStore(
      baseUrl: 'http://${server.address.host}:${server.port}',
      directory: packs,
      backup: backup,
    );

    final file = await store.ensure('model.onnx', sha256: _digest(_pack(10)));

    // The folder, so anything put there is covered, and the pack itself -
    // the file that stays, never the `.part` it was written to.
    expect(backup.excluded, [packs.path, file.path]);
  });

  test('a pack already on disk is marked too', () async {
    // Fetched by a build that did not mark it: it must not stay in the
    // backup for good.
    File('${temp.path}/model.onnx').writeAsStringSync('kept');
    final backup = _FakeBackup();
    final store = ModelStore(directory: temp, backup: backup);

    final file = await store.ensure('model.onnx', sha256: _unchecked);

    expect(backup.excluded, [file.path]);
  });

  test('a flag that cannot be set does not cost the pack', () async {
    final server = await _server(chunks: 10);
    addTearDown(() => server.close(force: true));
    final store = ModelStore(
      baseUrl: 'http://${server.address.host}:${server.port}',
      directory: temp,
      backup: _FakeBackup(fails: true),
    );

    final reported = <Object>[];
    final file = await runZonedGuarded(
      () => store.ensure('model.onnx', sha256: _digest(_pack(10))),
      (error, _) => reported.add(error),
    );

    expect(file?.lengthSync(), 10 * 1024);
    expect(reported.single, isA<StateError>());
  });

  group('resuming', () {
    test('a dropped download keeps what arrived, and the next try asks for '
        'the rest only', () async {
      final ranges = <String?>[];
      final server = await _server(ranges: ranges, dropFirstAfter: 300 * 1024);
      addTearDown(() => server.close(force: true));
      final store = ModelStore(
        baseUrl: 'http://${server.address.host}:${server.port}',
        directory: temp,
      );

      await expectLater(
        store.ensure('model.onnx', sha256: _digest(_pack(500))),
        throwsA(isA<Exception>()),
      );
      final kept = File('${temp.path}/model.onnx.part');
      expect(kept.lengthSync(), 300 * 1024);
      // Not the pack: only a whole, checked download becomes one.
      expect(await store.isDownloaded('model.onnx'), isFalse);

      final events = <DownloadProgress>[];
      final file = await store.ensure(
        'model.onnx',
        sha256: _digest(_pack(500)),
        onProgress: events.add,
      );

      expect(ranges, [null, 'bytes=${300 * 1024}-']);
      // The bar picks up where it was, not at nothing.
      expect(events.first.received, 300 * 1024);
      expect(events.first.total, 500 * 1024);
      expect(file.readAsBytesSync(), _pack(500));
      expect(kept.existsSync(), isFalse);
    });

    test('a server that does not do ranges sends it all again, and the pack '
        'is still whole', () async {
      final server = await _server(doesRanges: false);
      addTearDown(() => server.close(force: true));
      File('${temp.path}/model.onnx.part').writeAsBytesSync(_pack(100));
      final store = ModelStore(
        baseUrl: 'http://${server.address.host}:${server.port}',
        directory: temp,
      );

      final file = await store.ensure(
        'model.onnx',
        sha256: _digest(_pack(500)),
      );

      // Written over, not added to: 100 KB twice would fail the check.
      expect(file.readAsBytesSync(), _pack(500));
    });

    test('a kept download that is already whole goes straight to the '
        'check', () async {
      // The app stopped between the last byte and the check.
      final ranges = <String?>[];
      final server = await _server(ranges: ranges);
      addTearDown(() => server.close(force: true));
      File('${temp.path}/model.onnx.part').writeAsBytesSync(_pack(500));
      final store = ModelStore(
        baseUrl: 'http://${server.address.host}:${server.port}',
        directory: temp,
      );

      final file = await store.ensure(
        'model.onnx',
        sha256: _digest(_pack(500)),
      );

      // The server answered "nothing past that": not one byte came again.
      expect(ranges, ['bytes=${500 * 1024}-']);
      expect(file.readAsBytesSync(), _pack(500));
    });

    test('removing a pack takes what was kept of it too', () async {
      final kept = File('${temp.path}/model.onnx.part')
        ..writeAsBytesSync(_pack(1));
      final store = ModelStore(directory: temp);

      await store.remove('model.onnx');

      expect(kept.existsSync(), isFalse);
    });
  });

  group('checking', () {
    test('a pack that is not the one the lexicon names is thrown away, not '
        'used', () async {
      final server = await _server(chunks: 10);
      addTearDown(() => server.close(force: true));
      final store = ModelStore(
        baseUrl: 'http://${server.address.host}:${server.port}',
        directory: temp,
      );

      await expectLater(
        store.ensure('model.onnx', sha256: _digest(_pack(11))),
        throwsA(
          isA<ModelIntegrityException>()
              .having((e) => e.actual, 'actual', _digest(_pack(10)))
              .having((e) => e.expected, 'expected', _digest(_pack(11))),
        ),
      );
      // The `.part` too: resuming would only add to the same wrong bytes.
      expect(temp.listSync(), isEmpty);
    });

    test('a resumed download that does not add up is caught', () async {
      // A kept start that is not this pack's - a file changed on the host
      // under the same name, say. The rest lines up by position only, so
      // only the digest can tell.
      final server = await _server(chunks: 10);
      addTearDown(() => server.close(force: true));
      File('${temp.path}/model.onnx.part').writeAsBytesSync(Uint8List(4096));
      final store = ModelStore(
        baseUrl: 'http://${server.address.host}:${server.port}',
        directory: temp,
      );

      await expectLater(
        store.ensure('model.onnx', sha256: _digest(_pack(10))),
        throwsA(isA<ModelIntegrityException>()),
      );
      expect(temp.listSync(), isEmpty);

      // And trying again, from the start this time, gets the real pack.
      final file = await store.ensure(
        'model.onnx',
        sha256: _digest(_pack(10)),
      );
      expect(file.readAsBytesSync(), _pack(10));
    });
  });
}
