import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/app/locale_controller.dart';
import 'package:flutter_full_stack_flutter/core/text/stray_dead_key.dart';
import 'package:flutter_full_stack_flutter/features/greetings/providers/greeting_controller.dart';
import 'package:flutter_full_stack_flutter/l10n/app_localizations.dart';
import 'package:flutter_full_stack_flutter/theme/app_tokens.dart';
import 'package:flutter_full_stack_flutter/theme/aurora_backdrop.dart';
import 'package:flutter_full_stack_flutter/theme/glass_surface.dart';
import 'package:flutter_full_stack_flutter/theme/rise_in.dart';
import 'package:flutter_full_stack_flutter/theme/theme_mode_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GreetingsScreen extends ConsumerStatefulWidget {
  const GreetingsScreen({super.key});

  @override
  ConsumerState<GreetingsScreen> createState() => _GreetingsScreenState();
}

class _GreetingsScreenState extends ConsumerState<GreetingsScreen> {
  final _textEditingController = TextEditingController();

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  void _callHello() {
    unawaited(
      ref
          .read(greetingControllerProvider.notifier)
          .sayHello(_textEditingController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(greetingControllerProvider);
    final mode = ref.watch(themeModeControllerProvider);
    final locale = ref.watch(localeControllerProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        actions: [
          IconButton(
            key: const Key('greeting-language'),
            onPressed: () => ref
                .read(localeControllerProvider.notifier)
                .cycle(deviceLocaleOf(context)),
            icon: Icon(_localeIconFor(locale)),
            tooltip: l10n.languageTooltip(_languageName(l10n, locale)),
          ),
          IconButton(
            key: const Key('greeting-theme'),
            onPressed: () => ref
                .read(themeModeControllerProvider.notifier)
                .cycle(MediaQuery.platformBrightnessOf(context)),
            icon: Icon(_iconFor(mode)),
            tooltip: l10n.themeTooltip(_themeName(l10n, mode)),
          ),
        ],
      ),
      body: AuroraBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The hierarchy is the composition: one large line, one quiet
                // one, then the control. Uniform blocks are what read as
                // machine-made.
                const RiseIn(child: _Headline()),
                const SizedBox(height: 32),
                RiseIn(
                  delay: const Duration(milliseconds: 90),
                  child: _NameField(
                    controller: _textEditingController,
                    onSubmit: _callHello,
                  ),
                ),
                const SizedBox(height: 20),
                // The response is not a permanent box. It exists only when
                // there is something in it, which is what keeps the screen
                // from being two identical rectangles.
                RiseIn(
                  delay: const Duration(milliseconds: 180),
                  child: _Response(state: state),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A globe for "whatever the device speaks", a translate mark for a language
  /// the user picked — the same distinction [_iconFor] draws for the theme.
  /// Pinning the language the device already speaks renders identical copy, so
  /// the icon is the only thing that can report the change.
  IconData _localeIconFor(Locale? locale) =>
      locale == null ? Icons.language_outlined : Icons.translate_outlined;

  IconData _iconFor(ThemeMode mode) => switch (mode) {
    ThemeMode.system => Icons.brightness_auto_outlined,
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
  };

  String _themeName(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
    ThemeMode.system => l10n.themeModeSystem,
    ThemeMode.light => l10n.themeModeLight,
    ThemeMode.dark => l10n.themeModeDark,
  };

  /// A locale's own name, never translated: a language picker that renders
  /// every option in the language you are already reading is useless to
  /// someone who cannot read it.
  String _languageName(AppLocalizations l10n, Locale? locale) {
    if (locale == null) return l10n.languageSystem;

    return switch (locale.languageCode) {
      'en' => l10n.languageEnglish,
      'pt' => l10n.languagePortuguese,
      // A supported locale with no name here is an unfinished change, not a
      // state to handle: dropping an .arb file into lib/l10n puts the locale
      // into the cycle on its own, and this switch has to keep up. Showing
      // the raw code makes that visible instead of mislabelling the new
      // language as "following the device".
      _ => locale.languageCode.toUpperCase(),
    };
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.headline,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.5,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.tagline,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    // No GlassSurface here on purpose. The field carries the theme's own well
    // treatment, which reads as something to type into; the pane treatment is
    // reserved for surfaces that display rather than accept.
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('greeting-name-field'),
            controller: controller,
            onSubmitted: (_) => onSubmit(),
            textInputAction: TextInputAction.send,
            // Shim for a Flutter engine bug; delete with the helper once the
            // pinned Flutter carries the fix.
            inputFormatters: const [StrayDeadKeyFormatter()],
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.nameFieldLabel,
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filled(
          key: const Key('greeting-send'),
          onPressed: onSubmit,
          icon: const Icon(Icons.arrow_upward_rounded),
          tooltip: AppLocalizations.of(context)!.sendTooltip,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(56),
          ),
        ),
      ],
    );
  }
}

class _Response extends StatelessWidget {
  const _Response({required this.state});

  final AsyncValue<Object?> state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // A switcher rather than a rebuild, so a new answer slides over the old
    // one instead of blinking into place.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: switch (state) {
        AsyncLoading() => const _Waiting(key: ValueKey('loading')),
        AsyncError(:final error) => _Card(
          key: const ValueKey('error'),
          label: AppLocalizations.of(context)!.errorLabel,
          body: '$error',
          tint: theme.colorScheme.error,
        ),
        AsyncData(:final value) when value != null => _Card(
          key: const ValueKey('data'),
          label: AppLocalizations.of(context)!.responseLabel,
          body: value.toString(),
          tint: theme.colorScheme.primary,
        ),
        _ => const SizedBox.shrink(key: ValueKey('empty')),
      },
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          AppLocalizations.of(context)!.callingServer,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.label,
    required this.body,
    required this.tint,
    super.key,
  });

  final String label;
  final String body;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.appTokens;

    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 6,
                width: 6,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.radiusMedium * 0.75),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}
