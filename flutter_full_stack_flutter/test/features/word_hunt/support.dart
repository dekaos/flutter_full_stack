import 'package:flutter_full_stack_flutter/features/word_hunt/providers/hunt_records.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/word_bank.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Records kept in memory: no file, no platform folder, and every mission
/// handed in written down for the test to read.
class MemoryRecords extends HuntRecords {
  MemoryRecords([this.start = const {}]);

  final Map<WordDeck, DeckRecord> start;

  /// Every finished mission, in the order it was handed in.
  final List<(WordDeck, DeckRecord)> submitted = [];

  @override
  Future<Map<WordDeck, DeckRecord>> build() async => start;

  @override
  Future<void> submit(WordDeck deck, DeckRecord result) async {
    submitted.add((deck, result));
    final records = state.value ?? start;
    final before = records[deck];
    state = AsyncData({...records, deck: before?.merge(result) ?? result});
  }
}
