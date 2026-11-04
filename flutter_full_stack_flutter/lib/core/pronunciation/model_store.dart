import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_full_stack_flutter/core/backup_exclusion.dart';
import 'package:path_provider/path_provider.dart';

/// A download that could not start, or stopped short.
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

/// A pack that arrived whole but is not the pack its lexicon names: damaged
/// on the way, or a different file on the host.
///
/// It is deleted, so the next try downloads it afresh. Resuming would only
/// add to the same wrong bytes.
class ModelIntegrityException implements Exception {
  const ModelIntegrityException(
    this.name, {
    required this.expected,
    required this.actual,
  });

  final String name;

  /// The SHA-256 the lexicon carries for [name], and the one that arrived.
  final String expected;
  final String actual;

  @override
  String toString() =>
      '$name failed its check: SHA-256 $actual, expected $expected';
}

/// How far a model download has got.
class DownloadProgress {
  const DownloadProgress({
    required this.received,
    required this.total,
    this.checking = false,
  });

  /// Bytes on the device so far, counting any an earlier attempt kept.
  final int received;

  /// The whole pack's size, or null when the server did not say.
  final int? total;

  /// Every byte is in, and the pack is being checked against its SHA-256:
  /// a couple of seconds for 355 MB, with nothing left to download.
  final bool checking;

  double? get fraction =>
      total == null || total == 0 ? null : received / total!;
}

/// The SHA-256 of [file], in hex, taken on a background isolate: a phone
/// needs a couple of seconds to read 355 MB, and the UI must go on drawing.
Future<String> sha256OfFile(File file) {
  final path = file.path;
  return Isolate.run(
    () async =>
        (await crypto.sha256.bind(File(path).openRead()).first).toString(),
  );
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
/// the download already running: a second one would write the same partial
/// file under the first.
///
/// Nor does a dropped connection cost what already arrived. What came down is
/// kept, and the next try asks the server for the rest only - on a phone
/// network, 355 MB in one go is not something to count on. A pack is only
/// used once its SHA-256 matches the one its lexicon carries.
class ModelStore {
  ModelStore({
    this.directoryName = 'pronunciation_models',
    this.baseUrl,
    this.directory,
    this.progressInterval = const Duration(milliseconds: 100),
    this.backup = const BackupExclusion(),
    this.fingerprint = sha256OfFile,
  });

  /// Where the packs are served from - the server's web server, at `/models`
  /// (`LanguagePacks` on the server side). Resolved like the server URL is:
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

  /// How a pack's SHA-256 is taken. Replaced by tests that serve stand-in
  /// bytes under a real pack's name: they cannot serve its 355 MB, so they
  /// cannot match its digest either.
  final Future<String> Function(File file) fingerprint;

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

  /// Deletes [name], and what was kept of an unfinished download of it -
  /// unless that download is still running.
  Future<void> remove(String name) async {
    final file = await fileFor(name);
    final partial = _partial(file);
    if (!isDownloading(name) && partial.existsSync()) await partial.delete();
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
  /// The download lands in a `.part` file, and becomes [name] only once it is
  /// complete and its SHA-256 is [sha256] - the digest the lexicon carries
  /// for it. So a truncated or damaged download can never be mistaken for a
  /// usable model: ONNX Runtime would fail on one much later and much less
  /// legibly. A download cut short leaves its `.part` behind, and the next
  /// call picks up from where it stopped.
  ///
  /// A pack already on disk is not checked again: it was checked as it
  /// arrived, and reading 355 MB every time practice opens is not free.
  Future<File> ensure(
    String name, {
    required String sha256,
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
    download.done = _fetch(
      name,
      sha256,
      target,
      download.report,
    ).whenComplete(() => _downloads.remove(name));
    return await download.done;
  }

  Future<void> dispose() => _changes.close();

  File _partial(File target) => File('${target.path}.part');

  Future<File> _fetch(
    String name,
    String expected,
    File target,
    void Function(DownloadProgress) onProgress,
  ) async {
    final baseUrl = await resolveBaseUrl();
    final uri = Uri.parse('$baseUrl/$name');
    final partial = _partial(target);

    // Without this, an unreachable host hangs on the platform default
    // instead of failing while the user is still looking at the screen.
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      // What an earlier try got before it was cut off. Only bytes the server
      // sent reach the file, and in order, so it is always the true start of
      // the pack: ask for the rest. No If-Range - a pack's name never changes
      // content, and the check below would catch one that did.
      final kept = partial.existsSync() ? await partial.length() : 0;
      final request = await client.getUrl(uri);
      if (kept > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$kept-');
      }
      final response = await request.close();

      final int from;
      final int? total;
      switch (response.statusCode) {
        case HttpStatus.partialContent:
          final range = _contentRange(
            response.headers.value(HttpHeaders.contentRangeHeader),
          );
          if (range == null || range.start != kept) {
            // The rest of something, but not of what is on disk: what is
            // kept cannot be lined up with it.
            await partial.delete();
            throw HttpException(
              'asked for bytes $kept on, got '
              '${response.headers.value(HttpHeaders.contentRangeHeader)}',
              uri: uri,
            );
          }
          from = kept;
          total = range.total;
        case HttpStatus.ok:
          // The whole pack: nothing was kept, or the server does not do
          // ranges and starts again from the top.
          from = 0;
          total = response.contentLength < 0 ? null : response.contentLength;
        case HttpStatus.requestedRangeNotSatisfiable when kept > 0:
          // Nothing past what is kept. Either every byte is already in - the
          // app stopped between the last one and the check - or more than
          // the pack has, which the check tells apart.
          from = kept;
          total = kept;
        default:
          throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }

      var received = from;
      if (response.statusCode != HttpStatus.requestedRangeNotSatisfiable) {
        // Straight away, so a resumed bar starts where it was, not at zero.
        onProgress(DownloadProgress(received: received, total: total));
        final sink = partial.openWrite(
          mode: from > 0 ? FileMode.append : FileMode.write,
        );
        final since = Stopwatch()..start();
        try {
          // addStream, not `await for` with add: it propagates
          // backpressure, so a disk slower than the network pauses the
          // socket instead of letting the sink buffer a 355 MB file in
          // memory.
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
        if (total != null && received < total) {
          throw ModelDownloadException(
            uri,
            'the connection closed after $received of $total bytes',
          );
        }
      }

      // Also what takes the bar to its end, which the throttle above may
      // have stopped short of.
      onProgress(
        DownloadProgress(received: received, total: total, checking: true),
      );
      final actual = await fingerprint(partial);
      if (actual != expected) {
        await partial.delete();
        throw ModelIntegrityException(name, expected: expected, actual: actual);
      }
      await partial.rename(target.path);
      // After the rename, not before: the flag belongs to the file that
      // stays, and the `.part` is gone by now.
      await _keepOutOfBackups(target.path);
      _changes.add(name);
      return target;
    } on SocketException catch (error) {
      throw ModelDownloadException(uri, error);
    } finally {
      // Forced: an error can leave a response unread, which would otherwise
      // hold the connection - and its socket - open.
      client.close(force: true);
    }
  }
}

/// Where a 206 answer starts, and the whole pack's size if the server says:
/// `bytes <first>-<last>/<size or *>`.
({int start, int? total})? _contentRange(String? header) {
  final match = RegExp(
    r'^bytes (\d+)-\d+/(\d+|\*)$',
  ).firstMatch(header?.trim() ?? '');
  if (match == null) return null;
  return (
    start: int.parse(match[1]!),
    total: match[2] == '*' ? null : int.parse(match[2]!),
  );
}
