import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/app_bar_actions.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_audio.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/deck_look.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/hunt_theme.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/space_view.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/space_world.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/hunt_records.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/word_bank.dart';
import 'package:flutter_full_stack_flutter/l10n/app_localizations.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';
import 'package:flutter_full_stack_flutter/theme/rise_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Where the app opens: the word hunt's themes, over a slowly turning
/// planet, each with the best its learner has done on it.
class WordHuntScreen extends ConsumerStatefulWidget {
  const WordHuntScreen({super.key});

  /// When the sound gets ready: once the lobby has risen in, while the
  /// learner reads the themes - not during the entrance, which it would
  /// make stutter (see `SoundBoard.warm`).
  static const warmSoundAfter = Duration(milliseconds: 1400);

  @override
  ConsumerState<WordHuntScreen> createState() => _WordHuntScreenState();
}

class _WordHuntScreenState extends ConsumerState<WordHuntScreen> {
  final SpaceWorld _world = SpaceWorld(ambient: true, seed: 11);
  Timer? _warm;

  @override
  void initState() {
    super.initState();
    _warm = warmPracticeSoundAfter(ref, WordHuntScreen.warmSoundAfter);
  }

  @override
  void dispose() {
    _warm?.cancel();
    _world.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final records =
        ref.watch(huntRecordsProvider).value ?? const <WordDeck, DeckRecord>{};
    return HuntTheme(
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: theme.colorScheme.surface,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              actions: [
                IconButton(
                  key: const Key('hunt-pronunciation'),
                  onPressed: () => context.goNamed('languages'),
                  icon: const Icon(Icons.record_voice_over_outlined),
                  tooltip: l10n.huntPronunciation,
                ),
                // Always dark here, so no light switch: it would change
                // nothing on this screen.
                const AppBarActions(theme: false),
              ],
            ),
            body: Stack(
              fit: StackFit.expand,
              children: [
                SpaceView(world: _world),
                // A wash of the night behind the headline, so it reads
                // clearly over whatever flies past.
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: FractionallySizedBox(
                      heightFactor: 0.32,
                      widthFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              theme.colorScheme.surface.withValues(alpha: 0.85),
                              theme.colorScheme.surface.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) => _Decks(
                      width: constraints.maxWidth,
                      records: records,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Decks extends StatelessWidget {
  const _Decks({required this.width, required this.records});

  final double width;
  final Map<WordDeck, DeckRecord> records;

  static const _content = 980.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final side = math.max(16, (width - _content) / 2).toDouble();
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final bottom = MediaQuery.paddingOf(context).bottom + 24;
    // Staggered down the first screenful, then all at once: a card first
    // built when it is scrolled to should not keep the learner waiting.
    var delay = 0;
    Duration next() => Duration(milliseconds: math.min(60 + 40 * delay++, 380));

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(side, 12, side, 8),
          sliver: SliverToBoxAdapter(
            child: RiseIn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.huntTitle,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      l10n.huntTagline,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Room for the planet to be seen between the headline and the
        // themes, on a screen tall enough to spare it.
        SliverToBoxAdapter(
          child: SizedBox(
            height: (MediaQuery.sizeOf(context).height * 0.14).clamp(8, 140),
          ),
        ),
        for (final level in const [1, 2, 3]) ...[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(side, 18, side, 10),
            sliver: SliverToBoxAdapter(
              child: RiseIn(
                delay: next(),
                child: Text(
                  levelTitle(l10n, level),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: side),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisExtent: 142 * scale,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              delegate: SliverChildListDelegate([
                for (final deck in WordDeck.values)
                  if (deck.level == level)
                    RiseIn(
                      delay: next(),
                      child: _DeckCard(deck: deck, record: records[deck]),
                    ),
              ]),
            ),
          ),
        ],
        SliverToBoxAdapter(child: SizedBox(height: bottom)),
      ],
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({required this.deck, required this.record});

  final WordDeck deck;
  final DeckRecord? record;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = theme.appTokens;
    final radius = BorderRadius.circular(tokens.radiusMedium);
    final stars = record?.stars ?? 0;
    final best = record?.score ?? 0;
    final accent = deck.accent;

    return Material(
      color: tokens.glassDense,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: tokens.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('hunt-deck-${deck.name}'),
        onTap: () =>
            context.goNamed('mission', pathParameters: {'deck': deck.name}),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [accent, accent.withValues(alpha: 0.55)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.45),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        deck.icon,
                        size: 22,
                        color: theme.colorScheme.surface,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    label: l10n.huntDeckStars(stars),
                    child: ExcludeSemantics(child: StarRow(earned: stars)),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                deck.title(l10n),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.huntDeckWords(deck.words.length),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (best > 0)
                Text(
                  l10n.huntDeckBest(best),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: HuntColours.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
