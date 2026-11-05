import 'package:flutter/material.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/presentation/space/palette.dart';
import 'package:flutter_full_stack_flutter/features/word_hunt/providers/word_bank.dart';
import 'package:flutter_full_stack_flutter/l10n/app_localizations.dart';

final Map<WordDeck, SpacePalette> _palettes = {};

/// How a deck looks: its name, its icon, and the corner of space its
/// missions are flown in.
extension DeckLook on WordDeck {
  String title(AppLocalizations l10n) => switch (this) {
    WordDeck.greetings => l10n.huntDeckGreetings,
    WordDeck.colors => l10n.huntDeckColors,
    WordDeck.numbers => l10n.huntDeckNumbers,
    WordDeck.animals => l10n.huntDeckAnimals,
    WordDeck.family => l10n.huntDeckFamily,
    WordDeck.food => l10n.huntDeckFood,
    WordDeck.home => l10n.huntDeckHome,
    WordDeck.body => l10n.huntDeckBody,
    WordDeck.clothes => l10n.huntDeckClothes,
    WordDeck.time => l10n.huntDeckTime,
    WordDeck.city => l10n.huntDeckCity,
    WordDeck.nature => l10n.huntDeckNature,
    WordDeck.school => l10n.huntDeckSchool,
    WordDeck.actions => l10n.huntDeckActions,
    WordDeck.feelings => l10n.huntDeckFeelings,
  };

  IconData get icon => switch (this) {
    WordDeck.greetings => Icons.waving_hand_rounded,
    WordDeck.colors => Icons.palette_rounded,
    WordDeck.numbers => Icons.pin_rounded,
    WordDeck.animals => Icons.pets_rounded,
    WordDeck.family => Icons.family_restroom_rounded,
    WordDeck.food => Icons.restaurant_rounded,
    WordDeck.home => Icons.home_rounded,
    WordDeck.body => Icons.accessibility_new_rounded,
    WordDeck.clothes => Icons.checkroom_rounded,
    WordDeck.time => Icons.calendar_month_rounded,
    WordDeck.city => Icons.location_city_rounded,
    WordDeck.nature => Icons.park_rounded,
    WordDeck.school => Icons.school_rounded,
    WordDeck.actions => Icons.directions_run_rounded,
    WordDeck.feelings => Icons.mood_rounded,
  };

  /// The hue of its space, on the colour wheel: the jungle green of the
  /// animals, the warm orange of food, the deep blue of the night.
  double get hue => switch (this) {
    WordDeck.greetings => 190,
    WordDeck.colors => 300,
    WordDeck.numbers => 245,
    WordDeck.animals => 135,
    WordDeck.family => 335,
    WordDeck.food => 22,
    WordDeck.home => 38,
    WordDeck.body => 355,
    WordDeck.clothes => 275,
    WordDeck.time => 222,
    WordDeck.city => 205,
    WordDeck.nature => 160,
    WordDeck.school => 52,
    WordDeck.actions => 12,
    WordDeck.feelings => 318,
  };

  SpacePalette get palette =>
      _palettes.putIfAbsent(this, () => SpacePalette(hue));

  /// The deck's colour as an accent on the dark screens of the game.
  Color get accent => HSLColor.fromAHSL(1, hue, 0.85, 0.66).toColor();
}

/// The heading over the decks of [level].
String levelTitle(AppLocalizations l10n, int level) => switch (level) {
  1 => l10n.huntLevelFirst,
  2 => l10n.huntLevelEveryday,
  _ => l10n.huntLevelFurther,
};
