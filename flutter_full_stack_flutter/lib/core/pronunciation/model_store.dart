import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// A download that could not even start.
///
/// The raw [SocketException] names the host and port it failed on but not the
/// URL it was asked for, which is exactly what you need to see when the
/// answer is "that address means the phone itself".
class ModelDownloadException implements Exception {
  const ModelDownloadException(this.uri, this.cause);

  final Uri uri;
  final Object cause;

  @override
  String toString() => 'could not fetch $uri: $cause';
}

/// How far a model download has got.
class DownloadProgress {
  const DownloadProgress({required this.received, required this.total});

  final int received;

  /// Bytes the server promised, or null when it sent no `Content-Length`.
  final int? total;

  double? get fraction =>
      total == null || total == 0 ? null : received / total!;
}

/// Keeps the acoustic models on disk.
///
/// A language pack is around 355 MB, which is why it is fetched instead of
/// bundled: `melos run size` holds the release APK to a byte budget. This is
/// the only part of pronunciation practice that touches the network, and only
/// once per language - scoring itself never does.
class ModelStore {
  const ModelStore({
    this.directoryName = 'pronunciation_models',
    this.baseUrl,
    this.directory,
    this.progressInterval = const Duration(milliseconds: 100),
  });

  /// Where the packs are served from. Resolved like the server URL is:
  /// `--dart-define=MODEL_BASE_URL=...` first, then `assets/config.json`.
  static const _defined = String.fromEnvironment('MODEL_BASE_URL');

  final String directoryName;

  /// Overrides the configured host. Set by tests, and by anything that needs
  /// to point at a different mirror without rebuilding the asset bundle.
  final String? baseUrl;

  /// Overrides where packs are kept. Tests use it; the app does not.
  final Directory? directory;

  /// How often progress is reported. One event per network chunk means one
  /// widget rebuild per network chunk - tens of thousands of them across a
  /// 355 MB pack, which starves the download of the frames it is competing
  /// for and looks exactly like a slow server.
  final Duration progressInterval;

  Future<String> resolveBaseUrl() async {
    if (baseUrl != null) return baseUrl!;
    if (_defined.isNotEmpty) return _defined;
    final raw = await rootBundle.loadString('assets/config.json');
    final config = json.decode(raw) as Map<String, dynamic>;
    final url = config['modelBaseUrl'] as String?;
    if (url == null || url.isEmpty) {
      throw StateError(
        'no modelBaseUrl in assets/config.json and no '
        '--dart-define=MODEL_BASE_URL',
      );
    }
    return url;
  }

  Future<Directory> _directory() async {
    final documents = directory ?? await getApplicationSupportDirectory();
    final target = directory == null
        ? Directory('${documents.path}/$directoryName')
        : documents;
    if (!target.existsSync()) await target.create(recursive: true);
    return target;
  }

  Future<File> fileFor(String name) async =>
      File('${(await _directory()).path}/$name');

  Future<bool> isDownloaded(String name) async =>
      (await fileFor(name)).existsSync();

  /// Total bytes the packs occupy, for a "free up space" screen.
  Future<int> bytesOnDisk() async {
    final directory = await _directory();
    var total = 0;
    await for (final entity in directory.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<void> remove(String name) async {
    final file = await fileFor(name);
    if (file.existsSync()) await file.delete();
  }

  /// Returns the local model, downloading it first if it is not there yet.
  ///
  /// The download lands in a `.part` file and is renamed only once complete,
  /// so an interrupted download can never be mistaken for a usable model -
  /// ONNX Runtime would fail on a truncated file much later and much less
  /// legibly.
  Future<File> ensure(
    String name, {
    void Function(DownloadProgress)? onProgress,
  }) async {
    final target = await fileFor(name);
    if (target.existsSync()) return target;

    final baseUrl = await resolveBaseUrl();
    final uri = Uri.parse('$baseUrl/$name');
    final partial = File('${target.path}.part');
    if (partial.existsSync()) await partial.delete();

    // Without this, an unreachable host hangs on the platform default
    // instead of failing while the user is still looking at the screen.
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final response = await client.getUrl(uri).then((r) => r.close());
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final total = response.contentLength < 0 ? null : response.contentLength;
      final sink = partial.openWrite();
      var received = 0;
      final since = Stopwatch()..start();
      try {
        // addStream, not `await for` with add: it propagates backpressure, so
        // a disk slower than the network pauses the socket instead of letting
        // the sink buffer a 355 MB file in memory.
        await sink.addStream(
          response.map((chunk) {
            received += chunk.length;
            if (since.elapsed >= progressInterval) {
              since.reset();
              onProgress?.call(
                DownloadProgress(received: received, total: total),
              );
            }
            return chunk;
          }),
        );
      } finally {
        await sink.close();
      }
      // The throttle would otherwise leave the bar short of the end.
      onProgress?.call(DownloadProgress(received: received, total: total));
      await partial.rename(target.path);
      return target;
    } on SocketException catch (error) {
      if (partial.existsSync()) await partial.delete();
      throw ModelDownloadException(uri, error);
    } catch (_) {
      if (partial.existsSync()) await partial.delete();
      rethrow;
    } finally {
      client.close();
    }
  }
}
