import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_full_stack_flutter/core/backup_exclusion.dart';
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

/// One pack on its way down, shared by everyone who asks for it meanwhile.
class _Download {
  final listeners = <void Function(DownloadProgress)>[];
  DownloadProgress? last;
  late final Future<File> done;

  void report(DownloadProgress progress) {
    last = progress;
    for (final listener in [...listeners]) {
      // The download belongs to the store, not to whoever is watching it: a
      // listener that throws - a screen torn down mid-callback - must not
      // abort 355 MB for everyone else.
      try {
        listener(progress);
      } on Object catch (error, stackTrace) {
        Zone.current.handleUncaughtError(error, stackTrace);
      }
    }
  }
}

/// Keeps the acoustic models on disk.
///
/// A language pack is around 355 MB, which is why it is fetched instead of
/// bundled: `melos run size` holds the release APK to a byte budget. This is
/// the only part of pronunciation practice that touches the network, and only
/// once per language - scoring itself never does.
///
/// The packs are kept out of the device's backups, see [BackupExclusion]:
/// they are fetched again in one tap, and 355 MB each is what would push a
/// learner's iCloud over its free tier - and, on Android, the whole app past
/// Auto Backup's 25 MB quota, which stops *everything* of the app being
/// backed up.
///
/// A download outlives whoever started it. The learner leaving the practice
/// screen is not a reason to throw away half a pack, and coming back must join
/// the download already running: a second one would delete the first one's
/// partial file from under it.
class ModelStore {
  ModelStore({
    this.directoryName = 'pronunciation_models',
    this.baseUrl,
    this.directory,
    this.progressInterval = const Duration(milliseconds: 100),
    this.backup = const BackupExclusion(),
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

  /// What keeps the packs out of backups. Replaced by tests, which have no
  /// platform to ask.
  final BackupExclusion backup;

  final _downloads = <String, _Download>{};
  final _changes = StreamController<String>.broadcast();

  /// The name of every pack that lands on or leaves the disk. What lets the
  /// language chooser, which stays mounted under the practice route, notice a
  /// download that finished while it was not the screen being looked at.
  Stream<String> get changes => _changes.stream;

  /// Whether [name] is being downloaded right now.
  bool isDownloading(String name) => _downloads.containsKey(name);

  /// How far the running download of [name] has got, if one is running.
  DownloadProgress? progressOf(String name) => _downloads[name]?.last;

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
    if (!target.existsSync()) {
      await target.create(recursive: true);
      await _keepOutOfBackups(target.path);
    }
    return target;
  }

  /// A pack whose flag could not be set is still a good pack. Failing the
  /// download over it would cost the learner 355 MB again for a problem that
  /// is not theirs, so the error is reported and the pack kept.
  Future<void> _keepOutOfBackups(String path) async {
    try {
      await backup.exclude(path);
    } on Object catch (error, stackTrace) {
      Zone.current.handleUncaughtError(error, stackTrace);
    }
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
    if (file.existsSync()) {
      await file.delete();
      _changes.add(name);
    }
  }

  /// Returns the local model, downloading it first if it is not there yet.
  ///
  /// A call made while [name] is already downloading joins that download
  /// instead of starting another, and [onProgress] is told where it stands
  /// straight away rather than at the next tick.
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
    if (target.existsSync()) {
      // Marked on every open, not only on arrival: a pack fetched by a build
      // that did not mark it would otherwise stay in the backup for good.
      await _keepOutOfBackups(target.path);
      return target;
    }

    // Nothing is awaited between this lookup and the registration below, so
    // two callers cannot both find the slot empty.
    final running = _downloads[name];
    if (running != null) {
      if (onProgress != null) {
        running.listeners.add(onProgress);
        if (running.last case final last?) onProgress(last);
      }
      return await running.done;
    }

    final download = _Download();
    if (onProgress != null) download.listeners.add(onProgress);
    _downloads[name] = download;
    download.done = _fetch(name, target, download.report).whenComplete(() {
      _downloads.remove(name);
    });
    return await download.done;
  }

  Future<void> dispose() => _changes.close();

  Future<File> _fetch(
    String name,
    File target,
    void Function(DownloadProgress) onProgress,
  ) async {
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
              onProgress(DownloadProgress(received: received, total: total));
            }
            return chunk;
          }),
        );
      } finally {
        await sink.close();
      }
      // The throttle would otherwise leave the bar short of the end.
      onProgress(DownloadProgress(received: received, total: total));
      await partial.rename(target.path);
      // After the rename, not before: the flag belongs to the file that
      // stays, and the `.part` is gone by now.
      await _keepOutOfBackups(target.path);
      _changes.add(name);
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
