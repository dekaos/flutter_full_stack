import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/features/greetings/providers/greeting_controller.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Full Stack')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _textEditingController,
              onSubmitted: (_) => _callHello(),
              decoration: InputDecoration(
                hintText: 'Enter your name',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: _callHello,
                  icon: const Icon(Icons.send),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ResultDisplay(state: greetingState),
          ],
        ),
      ),
    );
  }
}

class ResultDisplay extends StatelessWidget {
  const ResultDisplay({required this.state, super.key});

  final AsyncValue<Object?> state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final (text, backgroundColor, foregroundColor) = switch (state) {
      AsyncError(:final error) => (
        '$error',
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      AsyncData(:final value) when value != null => (
        value.toString(),
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      AsyncLoading() => (
        'Calling server...',
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
      _ => (
        'No server response yet.',
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: backgroundColor,
        shape: OutlineInputBorder(
          borderSide: BorderSide(color: foregroundColor),
        ),
      ),
      child: Center(
        child: Text(text, style: TextStyle(color: foregroundColor)),
      ),
    );
  }
}
