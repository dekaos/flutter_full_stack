import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_full_stack_flutter/core/backup_exclusion.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves [chunks] KB, pausing now and then so the transfer spans several
/// progress intervals instead of finishing inside one.
///
/// [requests] counts what reached the server, which is how a test tells one
/// shared download from two racing ones.
Future<HttpServer> _server({
  int chunks = 500,
  int status = 200,
  List<String>? requests,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    requests?.add(request.uri.path);
    if (status != 200) {
      request.response.statusCode = status;
      await request.response.close();
      return;
    }
    request.response.headers.contentLength = chunks * 1024;
    for (var i = 0; i < chunks; i++) {
      request.response.add(Uint8List(1024));
      if (i % 100 == 0) {
        await request.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
    }
    await request.response.close();
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

    final file = await store.ensure('model.onnx', onProgress: events.add);

    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), 500 * 1024);
    // 500 chunks arrived. Reporting each one means a Riverpod state update and
    // a widget rebuild per network packet, which is what made a 355 MB pack
    // crawl while the server was serving at 800 MB/s.
    expect(events.length, lessThan(50));
    // The throttle must still let the bar reach the end.
    expect(events.last.received, 500 * 1024);
    expect(events.last.fraction, 1.0);
  });

  test('a failed download leaves nothing that looks usable', () async {
    final server = await _server(status: 404);
    addTearDown(() => server.close(force: true));

    final store = ModelStore(
      baseUrl: 'http://${server.address.host}:${server.port}',
      directory: temp,
    );

    await expectLater(store.ensure('model.onnx'), throwsA(isA<Exception>()));
    // Neither the target nor the partial file survives: ONNX Runtime would
    // fail on a truncated model much later and much less legibly.
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

    final file = await store.ensure('model.onnx');

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
    final first = store.ensure('model.onnx');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(store.isDownloading('model.onnx'), isTrue);
    final joined = <DownloadProgress>[];
    final second = store.ensure('model.onnx', onProgress: joined.add);

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

    await store.ensure('model.onnx');
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

    final file = await store.ensure('model.onnx');

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

    final file = await store.ensure('model.onnx');

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
      () => store.ensure('model.onnx'),
      (error, _) => reported.add(error),
    );

    expect(file?.lengthSync(), 10 * 1024);
    expect(reported.single, isA<StateError>());
  });
}
