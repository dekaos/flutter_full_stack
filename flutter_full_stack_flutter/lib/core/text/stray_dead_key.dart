import 'package:flutter/services.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Removes the stray accent a dead key leaves behind on iOS.
///
/// Typing `Stühler` on a physical keyboard produces `St¨ühler`: the engine
/// commits the dead key as a character of its own *and* delivers the composed
/// letter. It is a long-standing Flutter engine bug —
/// https://github.com/flutter/flutter/issues/59541 — fixed upstream in commit
/// `bf705aa` on 2026-09-04, which is after the 3.47.2 this project pins.
///
/// **Delete this once the fix reaches the pinned Flutter version.** It is a
/// shim, not a design decision: nothing else should grow to depend on it.
///
/// The rule is narrow on purpose. A lone accent is dropped only when the very
/// next character already carries that same accent, which is the shape the bug
/// produces and essentially never something a person types deliberately.
/// Whether the accent arrives spacing (`U+00A8`) or combining (`U+0308`) does
/// not matter: both are reduced to their combining form and compared against
/// the decomposition of the next character, so the check is exact rather than
/// a hand-kept table of letters.
String stripStrayDeadKeys(String input) {
  if (input.length < 2) return input;

  final out = StringBuffer();
  final runes = input.runes.toList();

  for (var i = 0; i < runes.length; i++) {
    final mark = _combiningFormOf(String.fromCharCode(runes[i]));
    if (mark != null && i + 1 < runes.length) {
      final next = String.fromCharCode(runes[i + 1]);
      if (unorm.nfd(next).contains(mark)) {
        // The next character already carries this accent: the lone one is the
        // duplicate, so it goes and the composed letter stays.
        continue;
      }
    }
    out.writeCharCode(runes[i]);
  }

  return out.toString();
}

/// The ASCII accents, which are dead keys on common layouts but have no
/// compatibility decomposition, so NFKD cannot derive their combining form.
///
/// `'` and `\"` are deliberately absent even though some layouts use them as
/// dead keys. They open quotations, so `\"über\"` and `'école'` are ordinary
/// text that this would silently corrupt. Missing a fix is cheaper than eating
/// a character somebody meant to type.
const _asciiAccents = <String, String>{
  '`': '\u0300', // grave
  '^': '\u0302', // circumflex
  '~': '\u0303', // tilde
};

/// The combining mark [char] represents, or null if it is not an accent.
///
/// A Latin-1 spacing accent decomposes under NFKD to a space plus its
/// combining form, which is what turns `¨` into `U+0308` with no lookup table.
/// The ASCII ones have no decomposition and are listed above.
String? _combiningFormOf(String char) {
  final ascii = _asciiAccents[char];
  if (ascii != null) return ascii;

  final decomposed = unorm.nfkd(char);
  if (decomposed.length == 2 && decomposed.codeUnitAt(0) == 0x20) {
    return decomposed[1];
  }
  // Already a combining mark on its own.
  if (char.length == 1 && _isCombining(char.codeUnitAt(0))) return char;
  return null;
}

bool _isCombining(int code) =>
    (code >= 0x0300 && code <= 0x036F) ||
    (code >= 0x1AB0 && code <= 0x1AFF) ||
    (code >= 0x20D0 && code <= 0x20F0);

/// Applies [stripStrayDeadKeys] while the user types.
///
/// It stands down whenever an input method has an active composing region,
/// because rewriting text mid-composition is how formatters break accent entry
/// on other platforms — see flutter/flutter#189056. By the time this bug shows
/// itself the stray accent is already committed, so there is nothing to lose
/// by waiting.
class StrayDeadKeyFormatter extends TextInputFormatter {
  const StrayDeadKeyFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;

    final cleaned = stripStrayDeadKeys(newValue.text);
    if (cleaned == newValue.text) return newValue;

    // Every removal happened before the caret, so the caret moves back by the
    // number of characters that disappeared.
    final removed = newValue.text.length - cleaned.length;
    final offset = (newValue.selection.baseOffset - removed).clamp(
      0,
      cleaned.length,
    );

    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
