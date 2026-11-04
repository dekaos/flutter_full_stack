import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('turning the sounds off reaches the board, and on again', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final board = container.read(soundBoardProvider);
    expect(board.effects, isTrue);

    container.read(soundEffectsProvider.notifier).toggle();
    expect(board.effects, isFalse);

    container.read(soundEffectsProvider.notifier).toggle();
    expect(board.effects, isTrue);
  });
}
