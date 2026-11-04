import 'dart:async';

import 'package:flutter_full_stack_flutter/core/pronunciation/gop_scorer.dart';
import 'package:flutter_full_stack_flutter/core/pronunciation/lexicon.dart';
import 'package:flutter_full_stack_flutter/features/pronunciation/providers/practice_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A phoneme as scored; [heard] is what it sounded like instead, when the
/// scorer could name it.
PhoneScore phone(String symbol, double score, {String? heard}) => PhoneScore(
  symbol: symbol,
  start: 0,
  end: 0.2,
  logPosterior: -1,
  margin: 0.5,
  score: score,
  heardInstead: heard,
);

/// A word as scored, said from [start] to [end] seconds into the attempt.
/// With [heard], its phoneme [symbol] sounded like that instead - which is
/// what makes it a word a hint can say something about.
WordScore word(
  String text, {
  required double score,
  double start = 0,
  double end = 0.2,
  String symbol = 'x',
  String? heard,
}) {
  final weakest = heard == null ? null : phone(symbol, score, heard: heard);
  return WordScore(
    word: text,
    start: start,
    end: end,
    score: score,
    phones: [weakest ?? phone(symbol, score)],
    weakest: weakest,
  );
}

/// An attempt scored [overall], made of [words].
PronunciationResult scored(
  double overall, {
  List<WordScore> words = const [],
  double? fluency = 50,
}) => PronunciationResult(
  overall: overall,
  accuracy: overall,
  fluency: fluency,
  speechRate: 11,
  pauses: 0,
  words: words,
);

/// "The weather": "The" from 0 to 0.2 s, sounded like /w/; "weather" from
/// 0.2 to 0.6 s, its /ð/ like a /t/ - and so the worse of the two, the one
/// a hint starts on.
List<WordScore> theWeather() => [
  word('The', score: 48, symbol: 'ə', heard: 'w'),
  word('weather', score: 22, start: 0.2, end: 0.6, symbol: 'ð', heard: 't'),
];

/// Practice holding still on [value] - by default a deck whose pack is not
/// on the device yet, which reaches for no platform channel - and moved on
/// by the test, as the real controller would move it.
class StubPracticeController extends PracticeController {
  StubPracticeController([this.value = opened]);

  /// One prompt, as practice opens.
  static const opened = PracticeState(
    stage: PracticeStage.ready,
    kind: ExerciseKind.phrase,
    items: [Exercise(id: 'x', text: 'hello', words: [], phones: [])],
    index: 0,
  );

  final PracticeState value;

  @override
  FutureOr<PracticeState> build(String lang) => value;

  /// What the real controller does when an action fails: the error goes on
  /// top of the value it happened to, which Riverpod keeps.
  void fail(PracticeFailure failure) =>
      state = AsyncError(failure, StackTrace.empty);

  /// Moves the screen on, as the real controller would.
  void show(PracticeState next) => state = AsyncData(next);

  int rechecks = 0;

  @override
  Future<void> recheckMicrophone() async => rechecks++;

  /// What the record button asked for, in order: `start` as it is
  /// pressed, `score` as it is let go, `cancel` for a tap.
  final asked = <String>[];

  @override
  Future<void> startRecording() async => asked.add('start');

  @override
  Future<void> stopAndScore() async => asked.add('score');

  @override
  void cancelRecording() => asked.add('cancel');
}
