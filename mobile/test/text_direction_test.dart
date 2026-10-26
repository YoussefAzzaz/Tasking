import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/text_direction.dart';
import 'package:axis/ui/common/axis_markdown_viewer.dart';

void main() {
  group('isArabicText detection tests', () {
    test('accurately identifies Arabic text vs Latin and edge cases', () {
      expect(isArabicText('مرحبا'), isTrue);
      expect(isArabicText('Hello'), isFalse);
      expect(isArabicText('1. مرحبا'), isTrue);
      expect(isArabicText('- [ ] مهمة'), isTrue);
      expect(isArabicText('### عنوان'), isTrue);
      expect(isArabicText('> اقتباس'), isTrue);
      expect(isArabicText('🚀 مهمة جديدة'), isTrue);
      expect(isArabicText('...مرحبا'), isTrue);
      expect(isArabicText('Axis: مرحباً بكم في التطبيق'), isTrue);
      expect(isArabicText('The Arabic word for peace is سلام'), isFalse);
      expect(isArabicText(''), isFalse);
      expect(isArabicText('   '), isFalse);
      expect(isArabicText(null), isFalse);
    });

    test('extension methods work as expected', () {
      expect('مرحبا'.isArabic, isTrue);
      expect('مرحبا'.textDirection, TextDirection.rtl);
      expect('Hello'.isArabic, isFalse);
      expect('Hello'.textDirection, TextDirection.ltr);
    });
  });

  group('AutoDirectionText widget tests', () {
    testWidgets('renders RTL direction for Arabic text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AutoDirectionText(
              'مرحبا بكم',
              key: ValueKey('arabic_text'),
            ),
          ),
        ),
      );

      final autoDirFinder = find.byKey(const ValueKey('arabic_text'));
      expect(autoDirFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(
        find.descendant(of: autoDirFinder, matching: find.byType(Text)),
      );
      expect(textWidget.textDirection, TextDirection.rtl);
    });

    testWidgets('renders LTR direction for English text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AutoDirectionText(
              'Welcome',
              key: ValueKey('english_text'),
            ),
          ),
        ),
      );

      final autoDirFinder = find.byKey(const ValueKey('english_text'));
      expect(autoDirFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(
        find.descendant(of: autoDirFinder, matching: find.byType(Text)),
      );
      expect(textWidget.textDirection, isNull);
    });
  });

  group('AutoDirectionScope widget tests', () {
    testWidgets('dynamically changes direction on Arabic input and back on clear',
        (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AutoDirectionScope(
              controller: controller,
              child: TextField(
                key: const ValueKey('test_field'),
                controller: controller,
              ),
            ),
          ),
        ),
      );

      // Initial direction is LTR
      Directionality dirWidget = tester.widget(find.byType(Directionality).last);
      expect(dirWidget.textDirection, TextDirection.ltr);

      // Enter English text
      await tester.enterText(find.byKey(const ValueKey('test_field')), 'Review design');
      await tester.pump();
      dirWidget = tester.widget(find.byType(Directionality).last);
      expect(dirWidget.textDirection, TextDirection.ltr);

      // Enter Arabic text
      await tester.enterText(find.byKey(const ValueKey('test_field')), 'مهمة تصميم الواجهة');
      await tester.pump();
      dirWidget = tester.widget(find.byType(Directionality).last);
      expect(dirWidget.textDirection, TextDirection.rtl);

      // Clear text
      await tester.enterText(find.byKey(const ValueKey('test_field')), '');
      await tester.pump();
      dirWidget = tester.widget(find.byType(Directionality).last);
      expect(dirWidget.textDirection, TextDirection.ltr);
    });
  });

  group('AxisMarkdownViewer Arabic support', () {
    testWidgets('renders Arabic headings, paragraphs, and checklists in RTL',
        (tester) async {
      const markdown = '''
# عنوان رئيسي
هذه فقرة مكتوبة باللغة العربية.
- [ ] مهمة للمتابعة
- عنصر قائمة
1. خطوة أولى
> اقتباس عربي
English paragraph
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AxisMarkdownViewer(markdown: markdown),
            ),
          ),
        ),
      );

      // Verify that rich texts with Arabic have textDirection: TextDirection.rtl
      final richTexts = tester.widgetList<Text>(find.byType(Text)).toList();

      final headingText = richTexts.firstWhere(
        (t) => t.textSpan?.toPlainText().contains('عنوان رئيسي') ?? false,
      );
      expect(headingText.textDirection, TextDirection.rtl);

      final paragraphText = richTexts.firstWhere(
        (t) => t.textSpan?.toPlainText().contains('فقرة مكتوبة') ?? false,
      );
      expect(paragraphText.textDirection, TextDirection.rtl);

      final checklistText = richTexts.firstWhere(
        (t) => t.textSpan?.toPlainText().contains('مهمة للمتابعة') ?? false,
      );
      expect(checklistText.textDirection, TextDirection.rtl);

      final englishText = richTexts.firstWhere(
        (t) => t.textSpan?.toPlainText().contains('English paragraph') ?? false,
      );
      expect(englishText.textDirection, TextDirection.ltr);
    });
  });
}
