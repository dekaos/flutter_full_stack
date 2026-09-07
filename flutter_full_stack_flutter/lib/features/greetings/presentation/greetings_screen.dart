import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/features/greetings/providers/greeting_controller.dart';
import 'package:flutter_full_stack_flutter/theme/app_backdrop.dart';
import 'package:flutter_full_stack_flutter/theme/glass_surface.dart';
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
    final greetingState = ref.watch(greetingControllerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);

    return Scaffold(
      // The backdrop runs behind the bar too, so the glass has the gradient
      // to blur rather than the bar's own colour.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Flutter Full Stack'),
        actions: [
          IconButton(
            onPressed: ref.read(themeModeControllerProvider.notifier).cycle,
            icon: Icon(_iconFor(themeMode)),
            tooltip: 'Theme: ${_labelFor(themeMode)}',
          ),
        ],
      ),
      body: AppBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                GlassSurface(
                  child: Column(
                    children: [
                      TextField(
                        controller: _textEditingController,
                        onSubmitted: (_) => _callHello(),
                        decoration: const InputDecoration(
                          hintText: 'Enter your name',
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _callHello,
                          icon: const Icon(Icons.send),
                          label: const Text('Say hello'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ResultDisplay(state: greetingState),
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

class ResultDisplay extends StatelessWidget {
  const ResultDisplay({required this.state, super.key});

  final AsyncValue<Object?> state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final (text, foreground) = switch (state) {
      AsyncError(:final error) => ('$error', colors.error),
      AsyncData(:final value) when value != null => (
        value.toString(),
        colors.onSurface,
      ),
      AsyncLoading() => ('Calling server...', colors.onSurfaceVariant),
      _ => ('No server response yet.', colors.onSurfaceVariant),
    };

    return GlassSurface(
      child: SizedBox(
        width: double.infinity,
        child: Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
        ),
      ),
    );
  }
}
