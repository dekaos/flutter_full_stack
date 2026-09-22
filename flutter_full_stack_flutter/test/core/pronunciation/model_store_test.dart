import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves [chunks] KB, pausing now and then so the transfer spans several
/// progress intervals instead of finishing inside one.
Future<HttpServer> _server({int chunks = 500, int status = 200}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
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
}
