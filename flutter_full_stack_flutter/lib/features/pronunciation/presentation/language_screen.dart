import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_full_stack_flutter/app/app_bar_actions.dart';
import 'package:flutter_full_stack_flutter/core/audio/sound.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/model_store.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/presentation/country_scene.dart';
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
/// on the device - and is where that pack is downloaded.
///
/// Each language is a destination with a page of its own: a place where it
/// is spoken, filling the screen (`CountryScene`) - New York, Seville,
/// Seoul - and at its foot a glass panel with the language's name, how its
/// pack stands, and the one thing to do: download the pack, or start
/// practising.
/// The learner swipes from one to the next, or taps a language in the tabs
/// under the headline. The place moves slower than its page as it is
/// swiped, as a view does through a window going past it; it arrives, with
/// its sound, the first time its page comes into view, and tells its story
/// again each time it comes back.
///
/// A download runs on its panel, its button filling as the pack comes down,
/// and practice opens by itself once the pack has landed and been checked.
///
/// It is also where practice gets its sound ready (`SoundBoard.warm`): the
/// sounds made, the players set up, the voices found. That costs - on a
/// modest phone, most of a second of work - and done as practice opened it
/// competed with the first scene's arrival and made it stutter. Here it
/// runs while the learner looks at the first place, once this screen has
/// finished rising in.
class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  /// Long enough for the headline and the panel to have risen in.
  static const settle = Duration(milliseconds: 900);

  /// How long a pack that has just landed shows as ready, chiming, before
  /// practice opens: long enough to see that it arrived.
  static const landing = Duration(milliseconds: 450);

  /// When the first place starts to arrive, once the page has risen in.
  static const firstArrival = Duration(milliseconds: 500);

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

/// The page's fixed measures, shared by the layout and by what the places
/// are told the page covers.
abstract final class _Layout {
  static const gutter = 16.0;

  /// Room left between the headline and tabs and the place under them,
  /// before the headline has been measured.
  static const header = 116.0;

  /// How tall the panel is taken to be before it has been measured.
  static const panel = 190.0;

  /// The room left between the panel and the place.
  static const gap = 12.0;

  /// How wide the headline, the tabs and the panel grow at most: on a
  /// tablet, a line of type or a button the width of the screen reads as a
  /// stretched phone, not as a page.
  static const content = 560.0;

  /// How wide the panel is at the side of a wide screen, at most.
  static const side = 400.0;

  /// How much slower than its page a place moves as the pages are swiped.
  static const parallax = 0.45;
}

/// How the page fits the screen it is on.
///
/// [compact] on a short screen - a small phone, any phone on its side: the
/// type, the gaps and the panel come down a size, so the place still has
/// room. [wide] on a screen wider than it is tall: the panel goes to the
/// side and the place takes the height beside it, instead of a short strip
/// between a headline and a panel.
@immutable
class _Fit {
  const _Fit({required this.compact, required this.wide});

  factory _Fit.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return _Fit(
      compact: size.height < 720,
      wide: size.width >= 600 && size.width > size.height * 1.15,
    );
  }

  final bool compact;
  final bool wide;

  /// The breathing room between the panel and the bottom of the safe area
  /// - the system's bar, or the screen's edge.
  double get breath => compact ? 12 : 20;

  /// How tall the tabs and the panel's button are.
  double get tabs => compact ? 40 : 44;
  double get button => compact ? 48 : 56;
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  final _pages = PageController();
  Timer? _warm;

  /// The page in view.
  int _index = 0;

  /// How tall the headline and the tabs are, as laid out: what the places
  /// stand clear of at the top, whatever the text size.
  double _header = _Layout.header;

  /// How tall the tallest panel has been, as laid out, on this screen:
  /// what the places stand clear of at the foot. The tallest, so a page
  /// whose panel says more does not move the place on the next.
  double _panel = _Layout.panel;
  Size? _panelOn;

  void _measuredPanel(double height, Size screen) {
    if (screen != _panelOn) {
      setState(() {
        _panelOn = screen;
        _panel = height;
      });
    } else if (height > _panel) {
      setState(() => _panel = height);
    }
  }

  /// The pages that have come into view at all, if only at the edge of a
  /// swipe: their places are arriving, or have.
  final Set<int> _seen = {0};

  /// The language last asked for whose pack is on its way: the one
  /// practice opens on once it lands.
  String? _awaiting;

  @override
  void initState() {
    super.initState();
    _warm = warmPracticeSoundAfter(ref, LanguageScreen.settle);
    _pages.addListener(_watch);
  }

  @override
  void dispose() {
    _warm?.cancel();
    _pages.dispose();
    super.dispose();
  }

  /// Notes a page coming into view as the pages are swiped, so its place
  /// can start to arrive before the swipe is over.
  void _watch() {
    final page = _pageOf(_pages, _index);
    final showing = {page.floor(), page.ceil()};
    if (!_seen.containsAll(showing)) setState(() => _seen.addAll(showing));
  }

  /// Brings [index]'s page into view, as a tap on its tab asks.
  void _show(int index) {
    if (context.still) {
      _pages.jumpToPage(index);
    } else {
      _pages
          .animateToPage(
            index,
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeInOutCubic,
          )
          .ignore();
    }
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
    final places = Theme.of(context).appTokens.sceneOpacity > 0;
    final fit = _Fit.of(context);
    final screen = MediaQuery.sizeOf(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(actions: const [AppBarActions()]),
      body: AuroraBackdrop(
        // A Builder because the padding that includes the app bar only
        // exists below the Scaffold, and the places need it.
        child: Builder(
          builder: (context) {
            final padding = MediaQuery.paddingOf(context);
            // Wide, the place stands beside the panel and takes the height;
            // otherwise between the headline and the panel.
            final clear = fit.wide
                ? EdgeInsets.only(
                    top: padding.top + _header,
                    bottom: padding.bottom + fit.breath,
                    right:
                        padding.right +
                        math.min(_Layout.side, screen.width * 0.42) +
                        _Layout.gutter * 2,
                  )
                : EdgeInsets.only(
                    top: padding.top + _header,
                    bottom: padding.bottom + fit.breath + _panel + _Layout.gap,
                  );
            return Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _pages,
                  itemCount: practiceLanguages.length,
                  onPageChanged: (index) {
                    HapticFeedback.selectionClick().ignore();
                    setState(() => _index = index);
                  },
                  itemBuilder: (context, index) => _Destination(
                    lang: practiceLanguages[index],
                    index: index,
                    pages: _pages,
                    shown: _seen.contains(index),
                    heard: index == _index,
                    clear: clear,
                    place: places,
                    fit: fit,
                    onPanel: (height) => _measuredPanel(height, screen),
                    onOpen: () => unawaited(_open(practiceLanguages[index])),
                  ),
                ),
                _Header(
                  pages: _pages,
                  index: _index,
                  scrim: places,
                  onSelect: _show,
                  onHeight: (height) {
                    if (height != _header) setState(() => _header = height);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The headline, and the languages as tabs under it - which one is in view,
/// and a tap away from any other - over a scrim that keeps them legible on
/// whatever sky is behind.
class _Header extends StatelessWidget {
  const _Header({
    required this.pages,
    required this.index,
    required this.scrim,
    required this.onSelect,
    required this.onHeight,
  });

  final PageController pages;
  final int index;
  final bool scrim;
  final ValueChanged<int> onSelect;

  /// Told how much room, under the app bar, the headline and the tabs take
  /// - with a little left under them - whenever that changes.
  final ValueChanged<double> onHeight;

  static const _top = 8.0;
  static const _under = 16.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final fit = _Fit.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Stack(
        children: [
          if (scrim)
            // Lets swipes through to the pages under it.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        surface.withValues(alpha: 0.86),
                        surface.withValues(alpha: 0.58),
                        surface.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.6, 1],
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                _Layout.gutter + 8,
                _top,
                _Layout.gutter + 8,
                40,
              ),
              // As wide as a page of type, at most: left beside the panel
              // on a wide screen, in the middle above it on a tall one.
              child: Align(
                alignment: fit.wide ? Alignment.topLeft : Alignment.topCenter,
                // As tall as what is in it: the header, and so its scrim,
                // must not reach down over the place.
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _Layout.content),
                  child: RiseIn(
                    child: _Measured(
                      onSize: (size) => onHeight(_top + size.height + _under),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IgnorePointer(
                            child: Text(
                              l10n.pickLanguageHeadline,
                              style: fit.compact
                                  ? theme.textTheme.titleLarge
                                  : theme.textTheme.headlineMedium,
                            ),
                          ),
                          SizedBox(height: fit.compact ? 10 : 16),
                          _LanguageTabs(
                            pages: pages,
                            index: index,
                            onSelect: onSelect,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tells [onSize] how big [child] is laid out, after the frame, whenever
/// that changes.
class _Measured extends SingleChildRenderObjectWidget {
  const _Measured({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasured(onSize);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasured renderObject) =>
      renderObject.onSize = onSize;
}

class _RenderMeasured extends RenderProxyBox {
  _RenderMeasured(this.onSize);

  ValueChanged<Size> onSize;
  Size? _told;

  @override
  void performLayout() {
    super.performLayout();
    final measured = size;
    if (measured == _told) return;
    _told = measured;
    // Not during layout: what it tells may set state.
    SchedulerBinding.instance.addPostFrameCallback((_) => onSize(measured));
  }
}

/// The languages, each named in itself, on a glass track - and a pill under
/// the one in view that follows the swipe as it happens, not after it.
class _LanguageTabs extends StatelessWidget {
  const _LanguageTabs({
    required this.pages,
    required this.index,
    required this.onSelect,
  });

  final PageController pages;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tokens = theme.appTokens;
    final height = _Fit.of(context).tabs;
    final shape = BorderRadius.circular(height / 2);
    return ClipRRect(
      borderRadius: shape,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.glassDense,
          borderRadius: shape,
          border: Border.all(color: tokens.glassBorder),
        ),
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth / practiceLanguages.length;
              return Stack(
                children: [
                  AnimatedBuilder(
                    animation: pages,
                    builder: (context, _) => Positioned(
                      left: width * _pageOf(pages, index) + 3,
                      top: 3,
                      bottom: 3,
                      width: width - 6,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          shape: const StadiumBorder(),
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (final (i, lang) in practiceLanguages.indexed)
                        Expanded(
                          child: Semantics(
                            selected: i == index,
                            button: true,
                            child: InkWell(
                              key: Key('language-tab-$lang'),
                              customBorder: const StadiumBorder(),
                              onTap: () => onSelect(i),
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: context.motion(
                                    const Duration(milliseconds: 200),
                                  ),
                                  style: theme.textTheme.titleSmall!.copyWith(
                                    color: i == index
                                        ? colors.onPrimary
                                        : colors.onSurfaceVariant,
                                  ),
                                  child: Text(languageName(l10n, lang)),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Where the pages are, in pages, while they are being swiped: [fallback]
/// before the pager has been laid out.
double _pageOf(PageController pages, int fallback) =>
    pages.hasClients && pages.position.haveDimensions
    ? pages.page ?? fallback.toDouble()
    : fallback.toDouble();

/// One language's page: its place filling it, seen through the page as
/// through a window, and its panel at the foot.
class _Destination extends ConsumerWidget {
  const _Destination({
    required this.lang,
    required this.index,
    required this.pages,
    required this.shown,
    required this.heard,
    required this.clear,
    required this.place,
    required this.fit,
    required this.onPanel,
    required this.onOpen,
  });

  final String lang;
  final int index;
  final PageController pages;
  final bool shown;
  final bool heard;
  final EdgeInsets clear;
  final _Fit fit;

  /// Told how tall the panel is laid out, whenever that changes.
  final ValueChanged<double> onPanel;

  /// Whether to show the place at all - not under high contrast.
  final bool place;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final script = CountryScene.of(lang);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (place && script != null)
          ClipRect(
            child: LayoutBuilder(
              builder: (context, box) => AnimatedBuilder(
                animation: pages,
                // The page moves a whole width as it is swiped; the place in
                // it lags behind by [_Layout.parallax] of that.
                builder: (context, child) => Transform.translate(
                  offset: Offset(
                    (_pageOf(pages, index) - index) *
                        box.maxWidth *
                        _Layout.parallax,
                    0,
                  ),
                  child: child,
                ),
                child: CountryScene(
                  script: script,
                  shown: shown,
                  heard: heard,
                  delay: index == 0
                      ? LanguageScreen.firstArrival
                      : Duration.zero,
                  clear: clear,
                  onSound: ref.read(soundBoardProvider).play,
                ),
              ),
            ),
          ),
        Align(
          // At the side of a wide screen, at the foot of a tall one.
          alignment: fit.wide ? Alignment.bottomRight : Alignment.bottomCenter,
          // The breath on top of the safe area, not instead of it: a phone
          // with a system bar along the bottom still gets room above it.
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                _Layout.gutter,
                0,
                _Layout.gutter,
                fit.breath,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: fit.wide
                      ? math.min(
                          _Layout.side,
                          MediaQuery.sizeOf(context).width * 0.42,
                        )
                      : _Layout.content,
                ),
                child: RiseIn(
                  delay: const Duration(milliseconds: 120),
                  child: _Measured(
                    onSize: (size) => onPanel(size.height),
                    child: _Panel(lang: lang, onOpen: onOpen),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The language, where it is spoken, how its pack stands, and the one thing
/// to do about it.
class _Panel extends ConsumerWidget {
  const _Panel({required this.lang, required this.onOpen});

  final String lang;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final pack = ref.watch(languagePackControllerProvider(lang)).value;
    final fit = _Fit.of(context);
    // Dense: the places are vivid, and the status is small type.
    return GlassSurface(
      dense: true,
      padding: EdgeInsets.all(fit.compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            languageName(l10n, lang),
            style:
                (fit.compact
                        ? theme.textTheme.headlineMedium
                        : theme.textTheme.displaySmall)
                    ?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: fit.compact ? 4 : 8),
          // Whether the pack is here decides whether the button starts
          // practice or a 355 MB download, so it is said before the tap.
          Row(
            children: [
              if (pack is PackReady) ...[
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: theme.appTokens.scoreStrong,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  _status(l10n, pack),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    // The full text colour, not the muted one: the glass
                    // over a vivid place takes the contrast a muted colour
                    // would need.
                    color: switch (pack) {
                      PackReady() => theme.appTokens.scoreStrong,
                      PackMissing(failure: Object()) => theme.colorScheme.error,
                      _ => theme.colorScheme.onSurface,
                    },
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: fit.compact ? 12 : 16),
          // Keyed outside the switcher: the place of the button, whichever
          // button is in it, even while one gives way to the next.
          KeyedSubtree(
            key: Key('language-action-$lang'),
            child: AnimatedSwitcher(
              duration: context.motion(const Duration(milliseconds: 250)),
              child: _PackAction(
                key: ValueKey((pack.runtimeType, _failed(pack))),
                pack: pack,
                onOpen: onOpen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static bool _failed(LanguagePack? pack) =>
      pack is PackMissing && pack.failure != null;

  String _status(AppLocalizations l10n, LanguagePack? pack) => switch (pack) {
    null => '',
    PackReady() => l10n.packReady,
    // How much has come down, once the server has said how much there is.
    PackDownloading(
      progress: DownloadProgress(:final received, total: final total?),
    ) =>
      l10n.packProgress(_megabytes(received), _megabytes(total)),
    // Before the server has said how much there is, the button says it all.
    PackDownloading() => '',
    PackMissing(failure: ModelIntegrityException()) => l10n.packDamaged,
    PackMissing(failure: Object()) => l10n.packInterrupted,
    PackMissing() => l10n.packOnce,
  };
}

/// Each language named in itself: a chooser that renders every option in a
/// language the reader may not have yet is useless to the person choosing.
String languageName(AppLocalizations l10n, String code) => switch (code) {
  'en' => l10n.languageEnglish,
  'es' => l10n.languageSpanish,
  'ko' => l10n.languageKorean,
  _ => code.toUpperCase(),
};

/// The panel's one button: start practising, download the pack, or try
/// again - and, while the pack comes down, the button itself filling up.
class _PackAction extends StatelessWidget {
  const _PackAction({
    required this.pack,
    required this.onOpen,
    super.key,
  });

  final LanguagePack? pack;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final height = _Fit.of(context).button;
    final style = FilledButton.styleFrom(
      minimumSize: Size.fromHeight(height),
      shape: const StadiumBorder(),
      textStyle: theme.textTheme.titleMedium,
    );
    return switch (pack) {
      PackDownloading(:final progress) => _Filling(progress: progress),
      PackReady() => FilledButton.icon(
        style: style,
        onPressed: onOpen,
        icon: const Icon(Icons.arrow_forward_rounded),
        iconAlignment: IconAlignment.end,
        label: Text(l10n.languageStart),
      ),
      PackMissing(failure: Object()) => FilledButton.tonalIcon(
        style: style,
        onPressed: onOpen,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(l10n.practiceTryAgain),
      ),
      PackMissing() => FilledButton.icon(
        style: style,
        onPressed: onOpen,
        icon: const Icon(Icons.download_rounded),
        label: Text(l10n.languageDownload(packMegabytes)),
      ),
      null => SizedBox(height: height),
    };
  }
}

/// Bytes as the megabytes the download is announced in: decimal, as the
/// size on the button is.
int _megabytes(int bytes) => (bytes / 1e6).round();

/// The download button while the pack comes down: the same pill, filling
/// from the left in the button's own colour as the pack arrives, with how
/// far in the middle - and its words changing colour exactly where the fill
/// reaches, so they read on the fill and on the track alike. While the pack
/// is checked it is full, and says so.
class _Filling extends StatelessWidget {
  const _Filling({required this.progress});

  final DownloadProgress? progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final height = _Fit.of(context).button;
    final checking = progress?.checking ?? false;
    final fraction = checking ? 1.0 : progress?.fraction;
    final percent = fraction == null ? null : (fraction * 100).floor();
    final busy = checking || percent == null;
    final label = checking
        ? l10n.packChecking
        : percent == null
        ? l10n.packDownloading
        : l10n.packDownloadingPercent(percent);
    final style = theme.textTheme.titleMedium!.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    Widget words(Color colour) => Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) ...[
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: colour),
            ),
            const SizedBox(width: 10),
          ],
          Text(label, style: style.copyWith(color: colour)),
        ],
      ),
    );

    return Semantics(
      label: label,
      value: percent == null ? null : '$percent%',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          // Eased between reports, which come a tenth of a second apart, so
          // it fills rather than ticks.
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: fraction ?? 0),
            duration: context.motion(const Duration(milliseconds: 250)),
            builder: (context, filled, _) => ClipRRect(
              // The track's shape is the fill's edge: a sliver at the start
              // is the curve of the pill, not a pill of its own.
              borderRadius: BorderRadius.circular(height / 2),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: colors.primary.withValues(alpha: 0.16)),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: filled,
                    child: ColoredBox(color: colors.primary),
                  ),
                  ClipRect(
                    clipper: _Span(from: filled, to: 1),
                    child: words(colors.onSurface),
                  ),
                  ClipRect(
                    clipper: _Span(from: 0, to: filled),
                    child: words(colors.onPrimary),
                  ),
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: colors.primary.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The stretch of a box from [from] to [to] of its width.
class _Span extends CustomClipper<Rect> {
  const _Span({required this.from, required this.to});

  final double from;
  final double to;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(size.width * from, 0, size.width * to, size.height);

  @override
  bool shouldReclip(_Span old) => old.from != from || old.to != to;
}
