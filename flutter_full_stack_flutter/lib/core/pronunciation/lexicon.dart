import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_full_stack_flutter/core/pronunciation/calibration.dart';

/// A word and the slice of [Exercise.phones] it covers.
class LexiconWord {
  const LexiconWord({
    required this.word,
    required this.phoneStart,
    required this.phoneEnd,
  });

  factory LexiconWord.fromJson(Map<String, dynamic> json) {
    final range = (json['p'] as List).cast<int>();
    return LexiconWord(
      word: json['w'] as String,
      phoneStart: range[0],
      phoneEnd: range[1],
    );
  }

  final String word;
  final int phoneStart;
  final int phoneEnd;
}

/// One canonical phoneme and the model vocabulary ids it maps to.
///
/// A diphthong that the model's vocabulary does not carry as a single symbol
/// is decomposed, so [tokenIds] can hold more than one id.
class LexiconPhone {
  const LexiconPhone({required this.symbol, required this.tokenIds});

  factory LexiconPhone.fromJson(Map<String, dynamic> json) => LexiconPhone(
    symbol: json['s'] as String,
    tokenIds: (json['t'] as List).cast<int>(),
  );

  final String symbol;
  final List<int> tokenIds;
}

/// Whether a prompt is a single word or a running phrase.
enum ExerciseKind {
  word,
  phrase;

  static ExerciseKind parse(String? value) =>
      value == 'word' ? ExerciseKind.word : ExerciseKind.phrase;
}

/// A read-aloud prompt with its phonemes resolved at build time.
class Exercise {
  const Exercise({
    required this.id,
    required this.text,
    required this.words,
    required this.phones,
    this.kind = ExerciseKind.phrase,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'] as String,
    kind: ExerciseKind.parse(json['kind'] as String?),
    text: json['text'] as String,
    words: (json['words'] as List)
        .map((w) => LexiconWord.fromJson(w as Map<String, dynamic>))
        .toList(),
    phones: (json['phones'] as List)
        .map((p) => LexiconPhone.fromJson(p as Map<String, dynamic>))
        .toList(),
  );

  final String id;
  final ExerciseKind kind;
  final String text;
  final List<LexiconWord> words;
  final List<LexiconPhone> phones;

  /// The flat CTC target: every token id of every phoneme, in order.
  List<int> get targetIds => [
    for (final phone in phones) ...phone.tokenIds,
  ];
}

/// Everything the app needs to score one language, built by
/// `scorer/tool/build_lexicon.py`.
///
/// Grapheme-to-phoneme runs at build time because the prompts are curated, so
/// the device never needs espeak-ng.
class Lexicon {
  const Lexicon({
    required this.lang,
    required this.model,
    required this.vocab,
    required this.blankId,
    required this.calibration,
    required this.exercises,
  });

  factory Lexicon.fromJson(Map<String, dynamic> json) => Lexicon(
    lang: json['lang'] as String,
    model: json['model'] as String,
    vocab: (json['vocab'] as List).cast<String>(),
    blankId: json['blankId'] as int,
    calibration: GopCalibration.fromJson(
      json['calibration'] as Map<String, dynamic>?,
    ),
    exercises: (json['exercises'] as List)
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  static Future<Lexicon> load(String lang) async {
    final raw = await rootBundle.loadString('assets/lexicons/$lang.json');
    return Lexicon.fromJson(json.decode(raw) as Map<String, dynamic>);
  }

  final String lang;
  final String model;

  /// The model's phoneme vocabulary, indexed by token id. It is what lets a
  /// bad score name what the model heard instead.
  final List<String> vocab;
  final int blankId;

  /// How a log posterior becomes a 0-100 score, per phoneme. Shipped with the
  /// lexicon because it is measured, not decided.
  final GopCalibration calibration;

  final List<Exercise> exercises;

  int get vocabSize => vocab.length;

  /// Blank, padding and word-delimiter ids, which must never be offered as
  /// "what you said instead".
  Set<int> get specialIds => {
    blankId,
    for (var i = 0; i < vocab.length; i++)
      if (vocab[i].startsWith('<') || vocab[i] == '|') i,
  };

  Exercise byId(String id) => exercises.firstWhere((e) => e.id == id);

  List<Exercise> byKind(ExerciseKind kind) =>
      exercises.where((e) => e.kind == kind).toList();
}
