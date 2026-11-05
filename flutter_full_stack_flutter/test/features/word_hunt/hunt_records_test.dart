import 'dart:io';

import 'package:flutter_full_stack_flutter/features/word_hunt/providers/hunt_records.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/word_bank.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Directory _folder() {
  final folder = Directory.systemTemp.createTempSync('hunt_records_test');
  addTearDown(() => folder.deleteSync(recursive: true));
  return folder;
}

void main() {
  group('the record store', () {
    test('starts from nothing on a new device', () async {
      expect(await HuntRecordStore(directory: _folder()).load(), isEmpty);
    });

    test('keeps what it was given', () async {
      final folder = _folder();
      await HuntRecordStore(directory: folder).save({
        WordDeck.animals: const DeckRecord(score: 1840, stars: 3),
        WordDeck.time: const DeckRecord(score: 300, stars: 1),
      });
      expect(await HuntRecordStore(directory: folder).load(), {
        WordDeck.animals: const DeckRecord(score: 1840, stars: 3),
        WordDeck.time: const DeckRecord(score: 300, stars: 1),
      });
    });

    test('reads what it can of a file it does not fully understand', () async {
      final folder = _folder();
      File('${folder.path}/word_hunt_records.json').writeAsStringSync(
        '{"version": 1, "decks": { '
        '"animals": {"score": 500, "stars": 7}, '
        '"dinosaurs": {"score": 9000, "stars": 3}, '
        '"food": {"score": "lots"}}}',
      );
      // A deck that is gone, or a record that makes no sense, is dropped;
      // stars are never more than three.
      expect(await HuntRecordStore(directory: folder).load(), {
        WordDeck.animals: const DeckRecord(score: 500, stars: 3),
      });
    });

    test('starts from nothing rather than fail on a damaged file', () async {
      final folder = _folder();
      File('${folder.path}/word_hunt_records.json').writeAsStringSync('{{');
      expect(await HuntRecordStore(directory: folder).load(), isEmpty);
    });
  });

  group('a deck record', () {
    test('keeps the best of each, separately', () {
      expect(
        const DeckRecord(
          score: 900,
          stars: 1,
        ).merge(const DeckRecord(score: 400, stars: 3)),
        const DeckRecord(score: 900, stars: 3),
      );
    });
  });

  group('the records', () {
    test('take a better mission, and write it down', () async {
      final folder = _folder();
      final container = ProviderContainer(
        overrides: [
          huntRecordStoreProvider.overrideWithValue(
            HuntRecordStore(directory: folder),
          ),
        ],
      );
      addTearDown(container.dispose);
      final records = container.read(huntRecordsProvider.notifier);
      expect(await container.read(huntRecordsProvider.future), isEmpty);

      await records.submit(
        WordDeck.colors,
        const DeckRecord(score: 700, stars: 2),
      );
      // A lower score with more stars improves the stars only.
      await records.submit(
        WordDeck.colors,
        const DeckRecord(score: 200, stars: 3),
      );
      // And a worse one changes nothing.
      await records.submit(
        WordDeck.colors,
        const DeckRecord(score: 100, stars: 0),
      );

      const best = {WordDeck.colors: DeckRecord(score: 700, stars: 3)};
      expect(container.read(huntRecordsProvider).value, best);
      expect(await HuntRecordStore(directory: folder).load(), best);
    });
  });
}
