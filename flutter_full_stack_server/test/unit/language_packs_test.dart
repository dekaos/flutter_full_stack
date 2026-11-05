import 'package:flutter_full_stack_server/src/web/routes/language_packs.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

void main() {
  group('LanguagePacks.directory', () {
    test('is the folder MODELS_DIR names, in any run mode', () {
      for (final mode in [
        ServerpodRunMode.development,
        ServerpodRunMode.production,
      ]) {
        expect(
          LanguagePacks.directory(
            runMode: mode,
            environment: {'MODELS_DIR': '/srv/language-packs'},
          ).path,
          '/srv/language-packs',
        );
      }
    });

    test(
      "in development, is the scorer's output, where packs are exported",
      () {
        expect(
          LanguagePacks.directory(
            runMode: ServerpodRunMode.development,
            environment: {},
          ).path,
          '../scorer/build',
        );
      },
    );

    test('anywhere else, is models beside the server - where the Docker '
        'image expects them mounted', () {
      for (final mode in [
        ServerpodRunMode.production,
        ServerpodRunMode.staging,
        ServerpodRunMode.test,
      ]) {
        expect(
          LanguagePacks.directory(runMode: mode, environment: {}).path,
          'models',
        );
      }
    });

    test('an empty MODELS_DIR counts as unset', () {
      expect(
        LanguagePacks.directory(
          runMode: ServerpodRunMode.production,
          environment: {'MODELS_DIR': ''},
        ).path,
        'models',
      );
    });
  });
}
