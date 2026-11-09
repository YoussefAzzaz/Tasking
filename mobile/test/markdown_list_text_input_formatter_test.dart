import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/ui/common/markdown_list_text_input_formatter.dart';

void main() {
  const formatter = MarkdownListTextInputFormatter();

  group('MarkdownListTextInputFormatter - Ordered Lists', () {
    test('continues ordered list with next number on newline', () {
      const oldValue = TextEditingValue(
        text: '1. First item',
        selection: TextSelection.collapsed(offset: 13),
      );
      const newValue = TextEditingValue(
        text: '1. First item\n',
        selection: TextSelection.collapsed(offset: 14),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('1. First item\n2. '));
      expect(result.selection.baseOffset, equals(17));
    });

    test('increments multi-digit ordered numbers (e.g. 9. -> 10., 99. -> 100.)', () {
      const oldValue = TextEditingValue(
        text: '9. Ninth item',
        selection: TextSelection.collapsed(offset: 13),
      );
      const newValue = TextEditingValue(
        text: '9. Ninth item\n',
        selection: TextSelection.collapsed(offset: 14),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('9. Ninth item\n10. '));
      expect(result.selection.baseOffset, equals(18));
    });

    test('preserves parenthesis delimiter (e.g. 1) -> 2) )', () {
      const oldValue = TextEditingValue(
        text: '1) Step one',
        selection: TextSelection.collapsed(offset: 11),
      );
      const newValue = TextEditingValue(
        text: '1) Step one\n',
        selection: TextSelection.collapsed(offset: 12),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('1) Step one\n2) '));
      expect(result.selection.baseOffset, equals(15));
    });

    test('preserves indentation for nested ordered lists', () {
      const oldValue = TextEditingValue(
        text: '  1. Sub item',
        selection: TextSelection.collapsed(offset: 13),
      );
      const newValue = TextEditingValue(
        text: '  1. Sub item\n',
        selection: TextSelection.collapsed(offset: 14),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('  1. Sub item\n  2. '));
      expect(result.selection.baseOffset, equals(19));
    });

    test('splits list item in the middle correctly', () {
      const oldValue = TextEditingValue(
        text: '1. Part one Part two',
        selection: TextSelection.collapsed(offset: 11),
      );
      const newValue = TextEditingValue(
        text: '1. Part one\n Part two',
        selection: TextSelection.collapsed(offset: 12),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('1. Part one\n2. Part two'));
      expect(result.selection.baseOffset, equals(15));
    });

    test('stops list when pressing Enter on an empty ordered list item', () {
      const oldValue = TextEditingValue(
        text: '1. Item one\n2. ',
        selection: TextSelection.collapsed(offset: 15),
      );
      const newValue = TextEditingValue(
        text: '1. Item one\n2. \n',
        selection: TextSelection.collapsed(offset: 16),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('1. Item one\n'));
      expect(result.selection.baseOffset, equals(12));
    });

    test('stops list when erasing/backspacing an empty ordered list item', () {
      const oldValue = TextEditingValue(
        text: '1. Item one\n2. ',
        selection: TextSelection.collapsed(offset: 15),
      );
      // Backspace deletes space from "2. "
      const newValue = TextEditingValue(
        text: '1. Item one\n2.',
        selection: TextSelection.collapsed(offset: 14),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('1. Item one\n'));
      expect(result.selection.baseOffset, equals(12));
    });
  });

  group('MarkdownListTextInputFormatter - Checklists', () {
    test('continues checklist on newline with unchecked box', () {
      const oldValue = TextEditingValue(
        text: '- [ ] First checklist item',
        selection: TextSelection.collapsed(offset: 26),
      );
      const newValue = TextEditingValue(
        text: '- [ ] First checklist item\n',
        selection: TextSelection.collapsed(offset: 27),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('- [ ] First checklist item\n- [ ] '));
      expect(result.selection.baseOffset, equals(33));
    });

    test('continues checked item (- [x]) with unchecked box (- [ ] )', () {
      const oldValue = TextEditingValue(
        text: '- [x] Completed item',
        selection: TextSelection.collapsed(offset: 20),
      );
      const newValue = TextEditingValue(
        text: '- [x] Completed item\n',
        selection: TextSelection.collapsed(offset: 21),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('- [x] Completed item\n- [ ] '));
      expect(result.selection.baseOffset, equals(27));
    });

    test('preserves indentation for nested checklist item', () {
      const oldValue = TextEditingValue(
        text: '    - [ ] Sub-task',
        selection: TextSelection.collapsed(offset: 18),
      );
      const newValue = TextEditingValue(
        text: '    - [ ] Sub-task\n',
        selection: TextSelection.collapsed(offset: 19),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('    - [ ] Sub-task\n    - [ ] '));
      expect(result.selection.baseOffset, equals(29));
    });

    test('stops checklist when pressing Enter on empty checklist item', () {
      const oldValue = TextEditingValue(
        text: '- [ ] First task\n- [ ] ',
        selection: TextSelection.collapsed(offset: 23),
      );
      const newValue = TextEditingValue(
        text: '- [ ] First task\n- [ ] \n',
        selection: TextSelection.collapsed(offset: 24),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('- [ ] First task\n'));
      expect(result.selection.baseOffset, equals(17));
    });

    test('stops checklist when backspacing empty checklist item', () {
      const oldValue = TextEditingValue(
        text: '- [ ] First task\n- [ ] ',
        selection: TextSelection.collapsed(offset: 23),
      );
      // Backspace deletes space from "- [ ] "
      const newValue = TextEditingValue(
        text: '- [ ] First task\n- [ ]',
        selection: TextSelection.collapsed(offset: 22),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('- [ ] First task\n'));
      expect(result.selection.baseOffset, equals(17));
    });
  });

  group('MarkdownListTextInputFormatter - Unordered Lists', () {
    test('continues bullet with dash (- item)', () {
      const oldValue = TextEditingValue(
        text: '- Bullet one',
        selection: TextSelection.collapsed(offset: 12),
      );
      const newValue = TextEditingValue(
        text: '- Bullet one\n',
        selection: TextSelection.collapsed(offset: 13),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('- Bullet one\n- '));
      expect(result.selection.baseOffset, equals(15));
    });

    test('continues bullet with asterisk (* item)', () {
      const oldValue = TextEditingValue(
        text: '* Star bullet',
        selection: TextSelection.collapsed(offset: 13),
      );
      const newValue = TextEditingValue(
        text: '* Star bullet\n',
        selection: TextSelection.collapsed(offset: 14),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('* Star bullet\n* '));
      expect(result.selection.baseOffset, equals(16));
    });

    test('continues bullet with unicode dot (• item)', () {
      const oldValue = TextEditingValue(
        text: '• Dot bullet',
        selection: TextSelection.collapsed(offset: 12),
      );
      const newValue = TextEditingValue(
        text: '• Dot bullet\n',
        selection: TextSelection.collapsed(offset: 13),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('• Dot bullet\n• '));
      expect(result.selection.baseOffset, equals(15));
    });

    test('stops bullet list when pressing Enter on empty bullet', () {
      const oldValue = TextEditingValue(
        text: '- Bullet one\n- ',
        selection: TextSelection.collapsed(offset: 15),
      );
      const newValue = TextEditingValue(
        text: '- Bullet one\n- \n',
        selection: TextSelection.collapsed(offset: 16),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('- Bullet one\n'));
      expect(result.selection.baseOffset, equals(13));
    });

    test('stops bullet list when backspacing empty bullet', () {
      const oldValue = TextEditingValue(
        text: '- Bullet one\n- ',
        selection: TextSelection.collapsed(offset: 15),
      );
      // Backspace deletes space from "- "
      const newValue = TextEditingValue(
        text: '- Bullet one\n-',
        selection: TextSelection.collapsed(offset: 14),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('- Bullet one\n'));
      expect(result.selection.baseOffset, equals(13));
    });
  });

  group('MarkdownListTextInputFormatter - Edge Cases', () {
    test('does not continue regular text without lists', () {
      const oldValue = TextEditingValue(
        text: 'Just regular paragraph text',
        selection: TextSelection.collapsed(offset: 27),
      );
      const newValue = TextEditingValue(
        text: 'Just regular paragraph text\n',
        selection: TextSelection.collapsed(offset: 28),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('Just regular paragraph text\n'));
    });

    test('does not continue markdown headers (## Title)', () {
      const oldValue = TextEditingValue(
        text: '## Section Title',
        selection: TextSelection.collapsed(offset: 16),
      );
      const newValue = TextEditingValue(
        text: '## Section Title\n',
        selection: TextSelection.collapsed(offset: 17),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('## Section Title\n'));
    });

    test('does not continue markdown divider (---)', () {
      const oldValue = TextEditingValue(
        text: '---',
        selection: TextSelection.collapsed(offset: 3),
      );
      const newValue = TextEditingValue(
        text: '---\n',
        selection: TextSelection.collapsed(offset: 4),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('---\n'));
    });

    test('does not interfere with multi-line paste', () {
      const oldValue = TextEditingValue(
        text: '1. Item',
        selection: TextSelection.collapsed(offset: 7),
      );
      const newValue = TextEditingValue(
        text: '1. Item\nline a\nline b',
        selection: TextSelection.collapsed(offset: 21),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('1. Item\nline a\nline b'));
    });

    test('normal character deletion inside list item text does not erase prefix', () {
      const oldValue = TextEditingValue(
        text: '1. Apples',
        selection: TextSelection.collapsed(offset: 9),
      );
      const newValue = TextEditingValue(
        text: '1. Apple',
        selection: TextSelection.collapsed(offset: 8),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('1. Apple'));
      expect(result.selection.baseOffset, equals(8));
    });

    test('erasing empty list on first line empties document completely', () {
      const oldValue = TextEditingValue(
        text: '1. ',
        selection: TextSelection.collapsed(offset: 3),
      );
      const newValue = TextEditingValue(
        text: '1.',
        selection: TextSelection.collapsed(offset: 2),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals(''));
      expect(result.selection.baseOffset, equals(0));
    });

    test('full flow: create item -> jump line -> erase element -> continue normally', () {
      // Step 1: User types "1. Task A" and jumps to next line (presses Enter)
      final step1 = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '1. Task A',
          selection: TextSelection.collapsed(offset: 9),
        ),
        const TextEditingValue(
          text: '1. Task A\n',
          selection: TextSelection.collapsed(offset: 10),
        ),
      );
      expect(step1.text, equals('1. Task A\n2. '));
      expect(step1.selection.baseOffset, equals(13));

      // Step 2: User removes the created element "2. " via Backspace
      final step2 = formatter.formatEditUpdate(
        step1,
        const TextEditingValue(
          text: '1. Task A\n2.',
          selection: TextSelection.collapsed(offset: 12),
        ),
      );
      expect(step2.text, equals('1. Task A\n'));
      expect(step2.selection.baseOffset, equals(10));

      // Step 3: User types normal text on that line: "Just some notes"
      final step3 = TextEditingValue(
        text: '${step2.text}Just some notes',
        selection: const TextSelection.collapsed(offset: 25),
      );

      // Step 4: User jumps to next line from normal text
      final step4 = formatter.formatEditUpdate(
        step3,
        TextEditingValue(
          text: '${step3.text}\n',
          selection: const TextSelection.collapsed(offset: 26),
        ),
      );
      // The list is stopped, and text continues normally without list prefix!
      expect(step4.text, equals('1. Task A\nJust some notes\n'));
      expect(step4.selection.baseOffset, equals(26));
    });

    test('full flow: checklist item -> jump line -> Enter on empty item -> continue normally', () {
      // Step 1: User types checklist and hits Enter
      final step1 = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '- [ ] Finish feature',
          selection: TextSelection.collapsed(offset: 20),
        ),
        const TextEditingValue(
          text: '- [ ] Finish feature\n',
          selection: TextSelection.collapsed(offset: 21),
        ),
      );
      expect(step1.text, equals('- [ ] Finish feature\n- [ ] '));

      // Step 2: User hits Enter on empty "- [ ] "
      final step2 = formatter.formatEditUpdate(
        step1,
        TextEditingValue(
          text: '${step1.text}\n',
          selection: TextSelection.collapsed(offset: step1.text.length + 1),
        ),
      );
      expect(step2.text, equals('- [ ] Finish feature\n'));

      // Step 3: User types normal text and hits Enter
      const normalText = '- [ ] Finish feature\nAll done here';
      final step4 = formatter.formatEditUpdate(
        const TextEditingValue(
          text: normalText,
          selection: TextSelection.collapsed(offset: normalText.length),
        ),
        const TextEditingValue(
          text: '$normalText\n',
          selection: TextSelection.collapsed(offset: normalText.length + 1),
        ),
      );
      expect(step4.text, equals('$normalText\n'));
    });

    test('continues unordered list in journal template with content below', () {
      const templateBefore = '### 📅 What Happened Today\n- Met with team\n\n### 🏆 Key Wins & Accomplishments\n1. \n';
      const offset = '### 📅 What Happened Today\n- Met with team'.length;
      const oldValue = TextEditingValue(
        text: templateBefore,
        selection: TextSelection.collapsed(offset: offset),
      );
      final newValue = TextEditingValue(
        text: templateBefore.replaceRange(offset, offset, '\n'),
        selection: const TextSelection.collapsed(offset: offset + 1),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('### 📅 What Happened Today\n- Met with team\n- \n\n### 🏆 Key Wins & Accomplishments\n1. \n'));
    });

    test('continues ordered list in journal template with content below', () {
      const templateBefore = '### 🏆 Key Wins & Accomplishments\n1. Shipped release\n\n### 💭 Thoughts\n';
      const offset = '### 🏆 Key Wins & Accomplishments\n1. Shipped release'.length;
      const oldValue = TextEditingValue(
        text: templateBefore,
        selection: TextSelection.collapsed(offset: offset),
      );
      final newValue = TextEditingValue(
        text: templateBefore.replaceRange(offset, offset, '\n'),
        selection: const TextSelection.collapsed(offset: offset + 1),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('### 🏆 Key Wins & Accomplishments\n1. Shipped release\n2. \n\n### 💭 Thoughts\n'));
    });

    test('continues checklist in journal template with content below', () {
      const templateBefore = '### 📅 What Happened Today\n- [ ] Review PR\n\n### 🏆 Key Wins\n';
      const offset = '### 📅 What Happened Today\n- [ ] Review PR'.length;
      const oldValue = TextEditingValue(
        text: templateBefore,
        selection: TextSelection.collapsed(offset: offset),
      );
      final newValue = TextEditingValue(
        text: templateBefore.replaceRange(offset, offset, '\n'),
        selection: const TextSelection.collapsed(offset: offset + 1),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('### 📅 What Happened Today\n- [ ] Review PR\n- [ ] \n\n### 🏆 Key Wins\n'));
    });

    test('stops list in journal template on empty item when pressing Enter', () {
      const templateBefore = '### 📅 What Happened Today\n- \n\n### 🏆 Key Wins\n';
      const offset = '### 📅 What Happened Today\n- '.length;
      const oldValue = TextEditingValue(
        text: templateBefore,
        selection: TextSelection.collapsed(offset: offset),
      );
      final newValue = TextEditingValue(
        text: templateBefore.replaceRange(offset, offset, '\n'),
        selection: const TextSelection.collapsed(offset: offset + 1),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      // Clears "- " leaving an empty line, preserving the rest of template
      expect(result.text, equals('### 📅 What Happened Today\n\n\n### 🏆 Key Wins\n'));
    });

    test('stops list in journal template on empty item when backspacing', () {
      const templateBefore = '### 📅 What Happened Today\n- \n\n### 🏆 Key Wins\n';
      const offset = '### 📅 What Happened Today\n- '.length;
      const oldValue = TextEditingValue(
        text: templateBefore,
        selection: TextSelection.collapsed(offset: offset),
      );
      // Backspace deletes space from "- "
      const newValue = TextEditingValue(
        text: '### 📅 What Happened Today\n-\n\n### 🏆 Key Wins\n',
        selection: TextSelection.collapsed(offset: offset - 1),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      // Erases "- " completely
      expect(result.text, equals('### 📅 What Happened Today\n\n\n### 🏆 Key Wins\n'));
    });
  });
}
