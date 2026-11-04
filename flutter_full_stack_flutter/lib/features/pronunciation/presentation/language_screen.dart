import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/app_bar_actions.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/language_pack.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_audio.dart';
import 'package:flutter_full_stack_flutter/l10n/app_localizations.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';
import 'package:flutter_full_stack_flutter/theme/aurora_backdrop.dart';
import 'package:flutter_full_stack_flutter/theme/glass_surface.dart';
import 'package:flutter_full_stack_flutter/theme/motion.dart';
import 'package:flutter_full_stack_flutter/theme/rise_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Roughly what one language pack weighs, for the download prompt. Exact to
/// the byte would be worse: the number sets an expectation about disk and
/// time, it is not there to be audited.
const packMegabytes = 355;

/// Picks the language, which decides both the prompts and which pack has to be
/// on the device - and is where that pack is downloaded. A tap on a language
/// whose pack is not here starts the download on its card, and practice
/// opens by itself once the pack has landed and been checked.
///
/// It is also where practice gets its sound ready (`SoundBoard.warm`): the
/// sounds made, the players set up, the voices found. That costs - on a
/// modest phone, most of a second of work - and done as practice opened it
/// competed with the first scene's arrival and made it stutter. Here it
/// runs while the learner reads the choices, once this screen has finished
/// rising in.
class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  /// Long enough for the headline and the cards to have risen in.
  static const settle = Duration(milliseconds: 900);

  /// How long a pack that has just landed shows as ready, chiming, before
  /// practice opens: long enough to see that it arrived.
  static const landing = Duration(milliseconds: 450);

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  Timer? _warm;

  /// The language last tapped whose pack is on its way: the one practice
  /// opens on once it lands.
  String? _awaiting;

  @override
  void initState() {
    super.initState();
    _warm = warmPracticeSoundAfter(ref, LanguageScreen.settle);
  }

  @override
  void dispose() {
    _warm?.cancel();
    super.dispose();
  }

  /// Opens practice in [lang]: straight away if its pack is here, otherwise
  /// once the download this starts - or joins - has landed.
  Future<void> _open(String lang) async {
    final pack = ref.read(languagePackControllerProvider(lang)).value;
    // Still looking at the disk: a tap now would not know which it means.
    if (pack == null) return;
    if (pack is PackReady) return _practise(lang);

    _awaiting = lang;
    final landed = await ref
        .read(languagePackControllerProvider(lang).notifier)
        .download();
    // Only for the language asked for last, and only while the learner is
    // still here waiting for it: a pack that lands after they have gone on
    // to something else must not pull them out of it.
    if (!landed || !mounted || _awaiting != lang) return;
    _awaiting = null;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    ref.read(soundBoardProvider).play(Sound.sparkle);
    await Future<void>.delayed(context.motion(LanguageScreen.landing));
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
      _practise(lang);
    }
  }

  void _practise(String lang) {
    // Going to practise one language is changing mind about waiting for
    // another.
    _awaiting = null;
    context.goNamed('practice', pathParameters: {'lang': lang});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        actions: const [
          AppBarActions(),
        ],
      ),
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
                    child: _LanguageCard(
                      lang: practiceLanguages[i],
                      onTap: () => unawaited(_open(practiceLanguages[i])),
                    ),
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
  const _LanguageCard({required this.lang, required this.onTap});

  final String lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final pack = ref.watch(languagePackControllerProvider(lang)).value;

    return GlassSurface(
      onTap: onTap,
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
                // rather than behind the tap - and so is the download.
                Text(
                  _status(l10n, pack),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: switch (pack) {
                      PackReady() => theme.appTokens.scoreStrong,
                      PackMissing(failure: Object()) => theme.colorScheme.error,
                      _ => theme.colorScheme.onSurfaceVariant,
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox.square(
            dimension: _PackBadge.size,
            child: AnimatedSwitcher(
              duration: context.motion(const Duration(milliseconds: 250)),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                ),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: _PackBadge(key: ValueKey(pack.runtimeType), pack: pack),
            ),
          ),
        ],
      ),
    );
  }

  String _status(AppLocalizations l10n, LanguagePack? pack) => switch (pack) {
    null => '',
    PackReady() => l10n.packReady,
    PackDownloading(progress: DownloadProgress(checking: true)) =>
      l10n.packChecking,
    PackDownloading() => l10n.packDownloading,
    PackMissing(failure: ModelIntegrityException()) => l10n.packDamaged,
    PackMissing(failure: Object()) => l10n.packInterrupted,
    PackMissing() => l10n.packMissing(packMegabytes),
  };

  /// Each language named in itself: a chooser that renders every option in a
  /// language the reader may not have yet is useless to the person choosing.
  String _name(AppLocalizations l10n, String code) => switch (code) {
    'en' => l10n.languageEnglish,
    'es' => l10n.languageSpanish,
    'ko' => l10n.languageKorean,
    _ => code.toUpperCase(),
  };
}

/// What a tap on the card will do, at a glance: open practice, download the
/// pack, or try again - or, while it comes down, how far it has got.
class _PackBadge extends StatelessWidget {
  const _PackBadge({required this.pack, super.key});

  static const size = 40.0;

  final LanguagePack? pack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return switch (pack) {
      PackDownloading(:final progress) => _DownloadRing(progress: progress),
      PackMissing(failure: Object()) => Icon(
        Icons.refresh_rounded,
        color: colors.error,
      ),
      PackMissing() => Icon(Icons.download_rounded, color: colors.primary),
      PackReady() || null => Icon(
        Icons.chevron_right,
        color: colors.onSurfaceVariant,
      ),
    };
  }
}

/// A ring that fills as the pack comes down, with how far in the middle -
/// and goes round on its own while the pack is checked, which has no
/// "how far" to show.
class _DownloadRing extends StatelessWidget {
  const _DownloadRing({required this.progress});

  final DownloadProgress? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checking = progress?.checking ?? false;
    final fraction = checking ? null : progress?.fraction;
    final track = theme.colorScheme.primary.withValues(alpha: 0.15);
    if (fraction == null) {
      return CircularProgressIndicator(
        strokeWidth: 3,
        backgroundColor: track,
      );
    }
    // Eased between reports, which come a tenth of a second apart, so the
    // ring fills rather than ticks.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: fraction),
      duration: context.motion(const Duration(milliseconds: 250)),
      builder: (context, value, _) => Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 3,
            backgroundColor: track,
            semanticsValue: '${(value * 100).floor()}%',
          ),
          Center(
            child: Text(
              '${(value * 100).floor()}',
              style: theme.textTheme.labelSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
