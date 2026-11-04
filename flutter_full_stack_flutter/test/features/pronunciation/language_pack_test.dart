import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/language_pack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _english = 'phoneme_en_r2.int8.onnx';

/// The digest the English lexicon carries for its pack, read from the asset.
final _englishDigest =
    (json.decode(File('assets/lexicons/en.json').readAsStringSync())
            as Map<String, dynamic>)['modelSha256']
        as String;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory packs;

  setUp(() async {
    // The test binding answers every HTTP request with a 400, which is right
    // for widget tests and wrong for one that serves a pack from loopback.
    HttpOverrides.global = null;
    packs = await Directory.systemTemp.createTemp('language_pack_test');
  });

  tearDown(() {
    if (packs.existsSync()) packs.deleteSync(recursive: true);
  });

  /// Serves 20 KB under the English pack's name, slowly enough that a test
  /// can leave in the middle of it.
  Future<(HttpServer, List<String>)> serve() async {
    final requests = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(request.uri.path);
      request.response.headers.contentLength = 20 * 1024;
      for (var i = 0; i < 20; i++) {
        request.response.add(Uint8List(1024));
        await request.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    return (server, requests);
  }

  /// Downloads go to [baseUrl] - by default a port nothing listens on.
  ProviderContainer container({String baseUrl = 'http://127.0.0.1:1'}) {
    final container = ProviderContainer(
      overrides: [
        modelStoreProvider.overrideWithValue(
          ModelStore(
            directory: packs,
            baseUrl: baseUrl,
            // Vouches for what is served: a few KB under the pack's name,
            // never its 355 MB, so it could never match the digest the
            // lexicon carries. The check itself is tested with the store.
            fingerprint: (_) async => _englishDigest,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Keeps the auto-disposed controller alive between reads, the way the
    // chooser watching it does.
    container.listen(languagePackControllerProvider('en'), (_, _) {});
    return container;
  }

  test('says whether the pack is on the device', () async {
    expect(
      await container().read(languagePackControllerProvider('en').future),
      isA<PackMissing>().having((p) => p.failure, 'failure', isNull),
    );

    File('${packs.path}/$_english').createSync();

    expect(
      await container().read(languagePackControllerProvider('en').future),
      isA<PackReady>(),
    );
  });

  test('a download says how far it has got, then that it landed', () async {
    final (server, requests) = await serve();
    final c = container(
      baseUrl: 'http://${server.address.host}:${server.port}',
    );
    final seen = <LanguagePack>[];
    c.listen(languagePackControllerProvider('en'), (_, next) {
      if (next.value case final pack?) seen.add(pack);
    });
    await c.read(languagePackControllerProvider('en').future);

    final landed = await c
        .read(languagePackControllerProvider('en').notifier)
        .download();

    expect(landed, isTrue);
    expect(requests, ['/$_english']);
    expect(File('${packs.path}/$_english').existsSync(), isTrue);
    expect(
      c.read(languagePackControllerProvider('en')).value,
      isA<PackReady>(),
    );
    final downloading = seen.whereType<PackDownloading>().toList();
    expect(downloading.map((p) => p.progress?.received), contains(20 * 1024));
    // The last word before it landed: the pack was being checked.
    expect(downloading.last.progress?.checking, isTrue);
  });

  test('a download that fails says why, without throwing, and a retry goes '
      'again', () async {
    final c = container();
    await c.read(languagePackControllerProvider('en').future);
    final pack = c.read(languagePackControllerProvider('en').notifier);

    expect(await pack.download(), isFalse);
    expect(
      c.read(languagePackControllerProvider('en')).value,
      isA<PackMissing>().having(
        (p) => p.failure,
        'failure',
        isA<ModelDownloadException>(),
      ),
    );

    // The card's tap is the retry: it goes to the network again rather than
    // reporting the old failure.
    expect(await pack.download(), isFalse);
  });

  test('leaving mid-download neither aborts it nor starts a second, and '
      'coming back follows it', () async {
    final (server, requests) = await serve();
    final c = container(
      baseUrl: 'http://${server.address.host}:${server.port}',
    );
    final store = c.read(modelStoreProvider);
    await c.read(languagePackControllerProvider('en').future);

    unawaited(c.read(languagePackControllerProvider('en').notifier).download());
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // The chooser goes - to the Serverpod demo, say - and its controller
    // with it.
    c.invalidate(languagePackControllerProvider('en'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(store.isDownloading(_english), isTrue);

    // Coming back finds the download under way instead of offering it.
    expect(
      await c.read(languagePackControllerProvider('en').future),
      isA<PackDownloading>(),
    );

    while (store.isDownloading(_english)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await Future<void>.delayed(Duration.zero);

    expect(requests, hasLength(1));
    expect(
      await c.read(languagePackControllerProvider('en').future),
      isA<PackReady>(),
    );
  });

  test('a pack that lands by any other way shows', () async {
    final (server, _) = await serve();
    final c = container(
      baseUrl: 'http://${server.address.host}:${server.port}',
    );
    expect(
      await c.read(languagePackControllerProvider('en').future),
      isA<PackMissing>(),
    );

    await c.read(modelStoreProvider).ensure(_english, sha256: _englishDigest);
    await Future<void>.delayed(Duration.zero);

    expect(
      await c.read(languagePackControllerProvider('en').future),
      isA<PackReady>(),
    );
  });

  test('practice can open only on a pack that is on the device', () async {
    final store = ModelStore(directory: packs);
    expect(await packOnDevice(store, 'en'), isFalse);

    File('${packs.path}/$_english').createSync();

    expect(await packOnDevice(store, 'en'), isTrue);
  });
}
