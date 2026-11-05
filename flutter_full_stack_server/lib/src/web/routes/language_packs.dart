import 'dart:io';

import 'package:serverpod/serverpod.dart';

/// The pronunciation language packs, served to the app for download.
///
/// Each pack is one acoustic model, about 355 MB: far too big to bundle, so
/// the app fetches the one a learner needs, once, from
/// `<modelBaseUrl>/<file name>` - and this is where that lands. The web
/// server serves the packs from a folder of their own, at [path].
///
/// A pack's name carries the revision of its export
/// (`phoneme_en_r2.int8.onnx`), and a changed model always ships under a new
/// name, so a name never changes content. That is what lets them be cached
/// for good, by the client and by any CDN in front of the server - and it is
/// also why an old pack must stay on the host while app versions that name
/// it are still installed.
///
/// Range requests are honoured, so a CDN can fetch them in pieces and a
/// download can be resumed.
abstract final class LanguagePacks {
  /// Where on the web server the packs are: the `modelBaseUrl` the app is
  /// given ends here.
  static const path = '/models';

  /// The environment variable that names the folder the packs are in.
  static const variable = 'MODELS_DIR';

  /// The folder the packs are served from.
  ///
  /// [variable] if it is set. Otherwise, in development, the scorer's own
  /// output folder - the server runs from its folder in the repository,
  /// beside the scorer that exports the packs, so a freshly exported pack is
  /// downloadable at once, with nothing copied. Anywhere else, `models`
  /// beside the server: `/app/models` in the Docker image, where the host's
  /// folder of packs is mounted.
  static Directory directory({
    required String runMode,
    Map<String, String>? environment,
  }) {
    final configured = (environment ?? Platform.environment)[variable];
    if (configured != null && configured.isNotEmpty) {
      return Directory(configured);
    }
    return Directory(
      runMode == ServerpodRunMode.development ? '../scorer/build' : 'models',
    );
  }

  /// Serves the packs in [folder] at [path].
  ///
  /// Only if the folder is there: a missing one would turn every download
  /// into a server error instead of a plain 404. It says either way, since
  /// a server with no packs looks healthy from everywhere but the app.
  ///
  /// The packs must be real files, or hard links. The static handler will
  /// not follow a symbolic link out of [folder], and answers 404 for one.
  static void mount(WebServer web, Directory folder) {
    if (!folder.existsSync()) {
      stdout.writeln(
        'Language packs: ${folder.absolute.path} does not exist, so $path '
        'serves none and '
        'the app cannot download a language. Set $variable to the folder '
        'that holds them.',
      );
      return;
    }
    web.addRoute(
      StaticRoute.directory(
        folder,
        cacheControlFactory: StaticRoute.publicImmutable(
          maxAge: const Duration(days: 365),
        ),
      ),
      path,
    );
    final packs = folder
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.int8.onnx'))
        .length;
    stdout.writeln(
      'Language packs: serving ${folder.resolveSymbolicLinksSync()} at '
      '$path ($packs packs).',
    );
  }
}
