import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/features/greetings/providers/greeting_controller.dart';
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
    final state = ref.watch(greetingControllerProvider);
    final mode = ref.watch(themeModeControllerProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: ref.read(themeModeControllerProvider.notifier).cycle,
            icon: Icon(_iconFor(mode)),
            tooltip: 'Theme: ${_labelFor(mode)}',
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

  IconData _iconFor(ThemeMode mode) => switch (mode) {
    ThemeMode.system => Icons.brightness_auto_outlined,
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
  };

  String _labelFor(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'following the device',
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
  };
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Say hello.',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.5,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your name travels to the Serverpod endpoint and comes back '
          'as a typed model.',
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
            controller: controller,
            onSubmitted: (_) => onSubmit(),
            textInputAction: TextInputAction.send,
            decoration: const InputDecoration(
              labelText: 'Your name',
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filled(
          onPressed: onSubmit,
          icon: const Icon(Icons.arrow_upward_rounded),
          tooltip: 'Send',
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
          label: 'The call failed',
          body: '$error',
          tint: theme.colorScheme.error,
        ),
        AsyncData(:final value) when value != null => _Card(
          key: const ValueKey('data'),
          label: 'From the server',
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
          'Calling the server',
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
