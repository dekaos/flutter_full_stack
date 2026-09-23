import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/app_bar_actions.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_controller.dart';
import 'package:flutter_full_stack_flutter/l10n/app_localizations.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';
import 'package:flutter_full_stack_flutter/theme/aurora_backdrop.dart';
import 'package:flutter_full_stack_flutter/theme/glass_surface.dart';
import 'package:flutter_full_stack_flutter/theme/rise_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Roughly what one language pack weighs, for the download prompt. Exact to
/// the byte would be worse: the number sets an expectation about disk and
/// time, it is not there to be audited.
const packMegabytes = 355;

/// The languages practice is offered in.
///
/// Not derived from the bundled lexicons: the asset list is not something the
/// app can enumerate at runtime, and a language nobody wrote prompts for
/// should not appear just because a file exists.
const practiceLanguages = ['en', 'es'];

/// Picks the language, which decides both the prompts and which pack has to be
/// on the device.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(actions: const [AppBarActions()]),
      body: AuroraBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RiseIn(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.pickLanguageHeadline,
                        style: theme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.pickLanguageTagline,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                for (var i = 0; i < practiceLanguages.length; i++) ...[
                  RiseIn(
                    delay: Duration(milliseconds: 90 + i * 60),
                    child: _LanguageCard(lang: practiceLanguages[i]),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageCard extends ConsumerWidget {
  const _LanguageCard({required this.lang});

  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final downloaded = ref.watch(packDownloadedProvider(lang));

    return GlassSurface(
      onTap: () => context.goNamed('practice', pathParameters: {'lang': lang}),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_name(l10n, lang), style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                // Whether the pack is here decides whether tapping starts
                // practice or starts a 355 MB download, so it is on the card
                // rather than behind the tap.
                Text(
                  switch (downloaded) {
                    AsyncData(value: true) => l10n.packReady,
                    AsyncData(value: false) => l10n.packMissing(packMegabytes),
                    _ => '',
                  },
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: (downloaded.value ?? false)
                        ? theme.appTokens.scoreStrong
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  /// Each language named in itself: a chooser that renders every option in a
  /// language the reader may not have yet is useless to the person choosing.
  String _name(AppLocalizations l10n, String code) => switch (code) {
    'en' => l10n.languageEnglish,
    'es' => l10n.languageSpanish,
    _ => code.toUpperCase(),
  };
}
