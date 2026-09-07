import 'package:flutter/services.dart';
import 'package:flutter_full_stack_flutter/core/text/stray_dead_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stripStrayDeadKeys removes the duplicate', () {
    test('spacing diaeresis before a letter that carries it', () {
      expect(stripStrayDeadKeys('St¨ühler'), 'Stühler');
    });

    test('combining diaeresis before a letter that carries it', () {
      expect(stripStrayDeadKeys('Sẗühler'), 'Stühler');
    });

    test('acute, grave, circumflex and tilde alike', () {
      expect(stripStrayDeadKeys('Jos´é'), 'José');
      expect(stripStrayDeadKeys('cr`ème'), 'crème');
      expect(stripStrayDeadKeys('h^ôtel'), 'hôtel');
      expect(stripStrayDeadKeys('S~ão'), 'São');
    });

    test('more than one in the same string', () {
      expect(stripStrayDeadKeys('´á ¨ü'), 'á ü');
    });
  });

  group('leaves alone what it should', () {
    test('ordinary text, accented or not', () {
      for (final s in ['Anderson', 'Stühler', 'José', '', 'a']) {
        expect(stripStrayDeadKeys(s), s);
      }
    });

    test('an accent followed by a letter that does not carry it', () {
      // A real typed diaeresis, then an unrelated letter: nothing to dedupe.
      expect(stripStrayDeadKeys('¨a'), '¨a');
    });

    test('an accent that is the last character', () {
      expect(stripStrayDeadKeys('wait¨'), 'wait¨');
    });

    test('a mismatched pair keeps both', () {
      // Acute then a letter carrying a diaeresis: different marks, so no.
      expect(stripStrayDeadKeys('´ü'), '´ü');
    });

    test('an accent legitimately typed twice in a row', () {
      expect(stripStrayDeadKeys('¨¨'), '¨¨');
    });

    test('quote characters, which open real text', () {
      // Some layouts use these as dead keys, but they are excluded on
      // purpose: these are ordinary strings, not bug output.
      expect(stripStrayDeadKeys('"über"'), '"über"');
      expect(stripStrayDeadKeys("'école'"), "'école'");
    });
  });

  group('the formatter', () {
    const formatter = StrayDeadKeyFormatter();

    TextEditingValue value(String text, {TextRange? composing}) =>
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
          composing: composing ?? TextRange.empty,
        );

    test('cleans the text and pulls the caret back with it', () {
      final result = formatter.formatEditUpdate(
        value('St'),
        value('St¨ü'),
      );

      expect(result.text, 'Stü');
      expect(result.selection.baseOffset, 3);
    });

    test('stands down while an input method is composing', () {
      final composing = value(
        'St¨ü',
        composing: const TextRange(start: 2, end: 4),
      );

      // Untouched: rewriting mid-composition is how formatters break accent
      // entry elsewhere (flutter/flutter#189056).
      expect(formatter.formatEditUpdate(value('St'), composing), composing);
    });

    test('returns the value untouched when there is nothing to fix', () {
      final clean = value('Anderson');
      expect(formatter.formatEditUpdate(value('Anderso'), clean), clean);
    });
  });
}
