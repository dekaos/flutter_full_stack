import 'dart:math' as math;

import 'package:flutter_full_stack_flutter/features/word_hunt/providers/word_bank.dart';
import 'package:flutter_test/flutter_test.dart';

/// [word] as it is compared for sameness: lower case, without accents or
/// anything but letters - "Avó" and "avo" are the same spelling to the eye
/// of someone who does not know the language yet.
String _plain(String word) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final buffer = StringBuffer();
  for (final char in word.toLowerCase().split('')) {
    final at = from.indexOf(char);
    final plain = at < 0 ? char : to[at];
    if (RegExp('[a-z]').hasMatch(plain)) buffer.write(plain);
  }
  return buffer.toString();
}

final List<WordPair> _all = [for (final deck in WordDeck.values) ...deck.words];

void main() {
  group('the word bank', () {
    test('has enough words in every deck for a mission and its decoys', () {
      for (final deck in WordDeck.values) {
        expect(
          deck.words.length,
          greaterThanOrEqualTo(MissionPlan.words + 4),
          reason: deck.name,
        );
      }
    });

    test('offers no English word twice, so a ship is right for one reason', () {
      final seen = <String, WordPair>{};
      for (final pair in _all) {
        final key = pair.en.toLowerCase();
        expect(
          seen[key],
          isNull,
          reason: '"${pair.en}" is both $pair and ${seen[key]}',
        );
        seen[key] = pair;
      }
    });

    test('asks for no Portuguese word twice', () {
      final seen = <String, WordPair>{};
      for (final pair in _all) {
        final key = pair.pt.toLowerCase();
        expect(
          seen[key],
          isNull,
          reason: '"${pair.pt}" is both $pair and ${seen[key]}',
        );
        seen[key] = pair;
      }
    });

    test('holds nothing spelled the same in both languages', () {
      for (final pair in _all) {
        expect(_plain(pair.pt), isNot(_plain(pair.en)), reason: '$pair');
      }
    });

    test('fits every word on a ship and in the prompt', () {
      for (final pair in _all) {
        expect(pair.en.length, lessThanOrEqualTo(15), reason: pair.en);
        expect(pair.pt.length, lessThanOrEqualTo(14), reason: pair.pt);
      }
    });

    test('writes words as a dictionary would', () {
      // English capitalises its days, and the T of a T-shirt; nothing
      // else here is a name.
      const capitalised = {
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
        'T-shirt',
      };
      for (final pair in _all) {
        expect(pair.pt, pair.pt.trim(), reason: pair.pt);
        expect(pair.en, pair.en.trim(), reason: pair.en);
        expect(pair.pt, pair.pt.toLowerCase(), reason: pair.pt);
        if (!capitalised.contains(pair.en)) {
          expect(pair.en, pair.en.toLowerCase(), reason: pair.en);
        }
      }
    });

    test('leaves out what the web version got wrong', () {
      final english = {for (final pair in _all) pair.en.toLowerCase()};
      final portuguese = {for (final pair in _all) pair.pt.toLowerCase()};
      // An insult is not vocabulary; rare, abstract words are not a
      // beginner's.
      for (final word in const [
        'stupid',
        'dishonest',
        'jealous',
        'impatient',
        'unfriendly',
        'rude',
        'mean',
      ]) {
        expect(english, isNot(contains(word)), reason: word);
      }
      // Each of these has several translations, depending on what is meant.
      const several = ['right', 'time', 'free', 'high', 'low', 'kind'];
      for (final word in several) {
        expect(english, isNot(contains(word)), reason: word);
      }
      // "Adeus" is not how anyone in Brazil says goodbye; "tempo" is also
      // the weather, and "direito" is not "right" as in correct.
      for (final word in const ['adeus', 'tempo', 'direito']) {
        expect(portuguese, isNot(contains(word)), reason: word);
      }
    });

    test('names its decks the way the routes do', () {
      for (final deck in WordDeck.values) {
        expect(WordDeck.named(deck.name), deck);
      }
      expect(WordDeck.named('dinosaurs'), isNull);
      expect(WordDeck.named(null), isNull);
    });

    test('rises in level: first steps, everyday life, further', () {
      final levels = [for (final deck in WordDeck.values) deck.level];
      expect(levels, orderedEquals([...levels]..sort()));
      expect(levels.toSet(), {1, 2, 3});
    });
  });

  group('a mission plan', () {
    test('asks for its deck words, never the same one twice', () {
      for (final deck in WordDeck.values) {
        final targets = MissionPlan.targets(deck, math.Random(deck.index));
        expect(targets, hasLength(MissionPlan.words));
        expect(targets.toSet(), hasLength(MissionPlan.words));
        expect(deck.words, containsAll(targets));
      }
    });

    test('flies its answer among decoys of the same deck', () {
      final random = math.Random(3);
      for (final deck in WordDeck.values) {
        for (final target in deck.words) {
          final choices = MissionPlan.choices(deck, target, 5, random);
          expect(choices, hasLength(6));
          expect(choices, contains(target));
          expect(choices.toSet(), hasLength(6), reason: 'no word twice');
          expect(deck.words, containsAll(choices));
        }
      }
    });

    test('adds ships as the mission goes on', () {
      expect(
        [for (var n = 1; n <= MissionPlan.words; n++) MissionPlan.shipsIn(n)],
        [4, 4, 4, 5, 5, 5, 5, 6, 6, 6],
      );
    });
  });
}
