import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/app_bar_actions.dart';
import 'package:flutter_full_stack_flutter/app/licenses.dart';
import 'package:flutter_full_stack_flutter/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('what Flutter does not collect is registered', () async {
    registerLicenses();
    // The registry is global: left populated, the licences page in the next
    // test would try to load these assets through the fake clock and never
    // settle.
    addTearDown(LicenseRegistry.reset);

    final entries = await LicenseRegistry.licenses.toList();
    List<String> textOf(String package) => [
      for (final entry in entries)
        if (entry.packages.contains(package))
          entry.paragraphs.map((p) => p.text).join('\n'),
    ];

    // The models' licence travels with the notice that they were modified,
    // which Apache-2.0 asks for on top of the licence text itself.
    final model = textOf('wav2vec2-lv-60-espeak-cv-ft').single;
    expect(model, contains(modelModificationNotice));
    expect(model, contains('Apache License'));
    expect(textOf('wav2vec2-xlsr-53-espeak-cv-ft').single, model);
    expect(textOf('ONNX Runtime').single, contains('Microsoft Corporation'));
    expect(textOf('Inter').single, contains('SIL Open Font License'));
  });

  testWidgets('the licences page is one tap away', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(appBar: AppBar(actions: const [AppBarActions()])),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('app-licenses')));
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
  });
}
