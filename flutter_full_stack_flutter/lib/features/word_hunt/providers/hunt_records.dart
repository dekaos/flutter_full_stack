import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_full_stack_flutter/core/audio/quietly.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/word_bank.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'hunt_records.g.dart';

/// The best a learner has done on one deck: the stars they collected and
/// their highest score - each the best on its own, so a high score earned
/// with hints does not take away three stars won another day.
@immutable
class DeckRecord {
  const DeckRecord({required this.score, required this.stars});

  final int score;

  /// `0` to `3`.
  final int stars;

  /// The best of this and [other], field by field.
  DeckRecord merge(DeckRecord other) => DeckRecord(
    score: math.max(score, other.score),
    stars: math.max(stars, other.stars),
  );

  @override
  bool operator ==(Object other) =>
      other is DeckRecord && other.score == score && other.stars == stars;

  @override
  int get hashCode => Object.hash(score, stars);
}

/// Where the records are kept: one small JSON file in the app's support
/// folder, which the platforms back up - progress is worth keeping across a
/// new phone, unlike a language pack.
///
/// Fails quietly both ways. Records are encouragement, not data the game
/// needs, so a device that cannot read or write them - the web build, where
/// there is no such folder - still plays, and simply starts from nothing.
class HuntRecordStore {
  HuntRecordStore({this.directory});

  /// The folder to keep the file in; the app's support folder when `null`.
  final Directory? directory;

  static const _name = 'word_hunt_records.json';

  Future<File> _file() async {
    final folder = directory ?? await getApplicationSupportDirectory();
    return File('${folder.path}/$_name');
  }

  Future<Map<WordDeck, DeckRecord>> load() async =>
      await quietly('read the word hunt records', () async {
        final file = await _file();
        if (!file.existsSync()) return <WordDeck, DeckRecord>{};
        final json = jsonDecode(await file.readAsString());
        final decks = json is Map ? json['decks'] : null;
        return {
          if (decks is Map)
            for (final MapEntry(:key, :value) in decks.entries)
              if (WordDeck.named('$key') case final deck?)
                if (value case {
                  'score': final int score,
                  'stars': final int stars,
                })
                  deck: DeckRecord(score: score, stars: stars.clamp(0, 3)),
        };
      }) ??
      {};

  Future<void> save(Map<WordDeck, DeckRecord> records) async {
    await quietly('save the word hunt records', () async {
      final file = await _file();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'version': 1,
          'decks': {
            for (final MapEntry(key: deck, value: record) in records.entries)
              deck.name: {'score': record.score, 'stars': record.stars},
          },
        }),
        flush: true,
      );
    });
  }
}

/// The one store for the app's lifetime. Overridden in tests with one in a
/// temporary folder.
@Riverpod(keepAlive: true)
HuntRecordStore huntRecordStore(Ref ref) => HuntRecordStore();

/// Every deck's best, as far as this device knows.
@Riverpod(keepAlive: true)
class HuntRecords extends _$HuntRecords {
  @override
  Future<Map<WordDeck, DeckRecord>> build() =>
      ref.watch(huntRecordStoreProvider).load();

  /// Counts a finished mission on [deck]: keeps whichever of [result] and
  /// what was there before is better, and writes it down if that changed.
  Future<void> submit(WordDeck deck, DeckRecord result) async {
    final records = await future;
    final before = records[deck];
    final best = before?.merge(result) ?? result;
    if (best == before) return;
    final updated = {...records, deck: best};
    state = AsyncData(updated);
    await ref.read(huntRecordStoreProvider).save(updated);
  }
}
