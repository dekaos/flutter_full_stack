import 'dart:convert';
import 'dart:io';

import 'package:flutter_full_stack_flutter/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

// The name is written in each platform's own files, which nothing else keeps
// in step with the app's - so a rename that missed one would ship an app
// called two things.
void main() {
  test('the app is called the same everywhere its name is shown', () {
    const name = App.name;

    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:label="$name"'),
    );

    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    for (final key in ['CFBundleDisplayName', 'CFBundleName']) {
      expect(
        RegExp('<key>$key</key>\\s*<string>([^<]*)</string>')
            .firstMatch(plist)?[1],
        name,
        reason: key,
      );
    }

    final manifest = jsonDecode(
      File('web/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(manifest['name'], name);
    expect(manifest['short_name'], name);

    final page = File('web/index.html').readAsStringSync();
    expect(page, contains('<title>$name</title>'));
    expect(page, contains('apple-mobile-web-app-title" content="$name"'));
  });
}
