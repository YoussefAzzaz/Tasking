import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/ui/desktop/screens/focus_timers_screen.dart';
import 'package:axis/ui/desktop/screens/journal/journal_live_preview_pane.dart';
import 'package:axis/ui/desktop/screens/journal/journal_markdown_editor_pane.dart';
import 'package:axis/ui/desktop/screens/journal/journal_vault_header.dart';
import 'package:axis/ui/desktop/screens/journal/journal_vault_navigator_pane.dart';

Widget _wrapWithArabicTheme(Widget child) {
  return MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: child,
      ),
    ),
  );
}

void main() {
  group('Focus Timers Arabic Localization Tests', () {
    testWidgets('FocusTimersScreen header renders Arabic labels and badges', (tester) async {
      await tester.pumpWidget(_wrapWithArabicTheme(const FocusTimersScreen()));
      await tester.pumpAndSettle();

      expect(find.text('جلسة تركيز عميق'), findsOneWidget);
      expect(find.text('جلسة تركيز للعمل العميق'), findsOneWidget);
      expect(find.text('الإعدادات'), findsOneWidget);
      expect(find.textContaining('الجلسة:'), findsOneWidget);
      expect(find.textContaining('المدة:'), findsOneWidget);
    });

    testWidgets('DesktopTimerHeroCard renders sessions, dial, and buttons in Arabic', (tester) async {
      await tester.pumpWidget(_wrapWithArabicTheme(const DesktopTimerHeroCard()));
      await tester.pumpAndSettle();

      expect(find.text('الجلسة 1'), findsOneWidget);
      expect(find.text('الجلسة 2'), findsOneWidget);
      expect(find.text('الجلسة 3'), findsOneWidget);
      expect(find.text('الجلسة 4'), findsOneWidget);
      expect(find.text('الوقت المتبقي'), findsOneWidget);
      expect(find.text('بدء الجلسة'), findsOneWidget);
      expect(find.text('5 د'), findsOneWidget);
      expect(find.text('إعادة تعيين'), findsOneWidget);
      expect(find.text('إنهاء'), findsOneWidget);
    });

    testWidgets('DesktopFocusProtocolDialog renders Arabic settings and options', (tester) async {
      await tester.pumpWidget(
        _wrapWithArabicTheme(
          DesktopFocusProtocolDialog(onConfigSaved: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('بروتوكول جلسات التركيز'), findsOneWidget);
      expect(find.text('مدة جلسة التركيز'), findsOneWidget);
      expect(find.text('استراحة استعادة النشاط القصيرة'), findsOneWidget);
      expect(find.text('الدورات قبل الاستراحة الطويلة'), findsOneWidget);
      expect(find.text('بدء استراحات الاستعادة تلقائياً'), findsOneWidget);
      expect(find.text('حفظ البروتوكول'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);
    });

    testWidgets('DesktopSoundscapesCard renders Arabic header and track names', (tester) async {
      await tester.pumpWidget(_wrapWithArabicTheme(const DesktopSoundscapesCard()));
      await tester.pumpAndSettle();

      expect(find.text('أصوات الخلفية المحيطة'), findsOneWidget);
      expect(find.text('مؤثرات صوتية هادئة لتعزيز التركيز والانغماس الذهني'), findsOneWidget);
      expect(find.text('مطر هادئ'), findsOneWidget);
      expect(find.text('أمواج المحيط'), findsOneWidget);
      expect(find.text('دفء الموقد'), findsOneWidget);
      expect(find.text('الفضاء العميق'), findsOneWidget);
      expect(find.text('حديقة الزن'), findsOneWidget);
      expect(find.text('ضوضاء بيضاء'), findsOneWidget);
    });

    testWidgets('DesktopSessionGoalCard renders Arabic title, buttons, and standby text', (tester) async {
      await tester.pumpWidget(
        _wrapWithArabicTheme(
          DesktopSessionGoalCard(onShowTaskSelection: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('هدف الجلسة الحالية'), findsOneWidget);
      expect(find.text('ربط مهمة'), findsOneWidget);
      expect(find.text('تركيز ذهني عميق وانسيابية'), findsOneWidget);
      expect(find.text('تجنب المقاطعات وحافظ على تركيز مستمر دون انقطاع.'), findsOneWidget);
    });

    testWidgets('DesktopDistractionsCard renders Arabic header, hint, and button with padded input', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrapWithArabicTheme(
          DesktopDistractionsCard(
            controller: controller,
            onSave: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ملاحظات سريعة ومشتتات الذهن'), findsOneWidget);
      expect(find.text('التقط الأفكار العابرة دون قطع حبل تركيزك'), findsOneWidget);
      expect(find.text('حفظ الملاحظة في الخزينة'), findsOneWidget);

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.hintText, 'التقط فكرة سريعة أو مهمة أو خاطرة لمراجعتها لاحقاً...');
      expect(textField.decoration?.contentPadding?.horizontal, greaterThanOrEqualTo(8.0));
    });

    testWidgets('DesktopTodayScheduleCard renders Arabic header and empty status', (tester) async {
      await tester.pumpWidget(_wrapWithArabicTheme(const DesktopTodayScheduleCard()));
      await tester.pumpAndSettle();

      expect(find.text('جدول اليوم وجلسات التركيز'), findsOneWidget);
    });
  });

  group('Journal & Vault Arabic Localization Tests', () {
    testWidgets('JournalVaultHeader renders Arabic breadcrumbs, title, and buttons', (tester) async {
      await tester.pumpWidget(
        _wrapWithArabicTheme(
          JournalVaultHeader(
            selectedNote: null,
            isCreating: false,
            activeTab: 'notes',
            editorText: 'تجربة محتوى باللغة العربية',
            onTogglePin: () {},
            onDeleteSelectedNote: () {},
            onExportMarkdown: () {},
            onStartNewEntry: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('قاعدة المعرفة / الملاحظات / '), findsOneWidget);
      expect(find.text('الخزينة وملاحظات البنية البرمجية'), findsOneWidget);
      expect(find.text('ملاحظة جديدة'), findsOneWidget);
    });

    testWidgets('JournalMarkdownEditorPane renders Arabic title, category, and action buttons', (tester) async {
      final titleController = TextEditingController();
      final editorController = TextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        _wrapWithArabicTheme(
          JournalMarkdownEditorPane(
            selectedNote: null,
            isCreating: true,
            activeTab: 'notes',
            creatingCategory: 'General',
            titleController: titleController,
            editorController: editorController,
            editorFocusNode: focusNode,
            onTitleChanged: (_) {},
            onEditorChanged: (_) {},
            onSaveEditor: () {},
            onUpdateCategory: (_) {},
            onCreatingCategoryChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('محرر ماركداون'), findsOneWidget);
      expect(find.text('حفظ الملاحظة'), findsOneWidget);
      expect(find.text('التصنيف: '), findsOneWidget);

      final textFields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(textFields.first.decoration?.hintText, 'عنوان الملاحظة...');
      expect(textFields.last.decoration?.hintText, contains('# العنوان'));
    });

    testWidgets('JournalLivePreviewPane renders Arabic title and empty placeholder', (tester) async {
      await tester.pumpWidget(
        _wrapWithArabicTheme(
          JournalLivePreviewPane(
            editorText: '',
            selectedNote: null,
            onMarkdownChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('● المعاينة'), findsOneWidget);
      expect(find.textContaining('ملاحظة فارغة'), findsOneWidget);
    });

    testWidgets('JournalVaultNavigatorPane renders Arabic tabs, search hint, and hierarchy title', (tester) async {
      final searchController = TextEditingController();
      final vaultScrollController = ScrollController();

      await tester.pumpWidget(
        _wrapWithArabicTheme(
          JournalVaultNavigatorPane(
            activeTab: 'notes',
            selectedCategoryFilter: 'All',
            searchQuery: '',
            searchController: searchController,
            vaultScrollController: vaultScrollController,
            selectedNote: null,
            onSwitchTab: (_) {},
            onSelectCategoryFilter: (_) {},
            onSearchChanged: (_) {},
            onSelectNote: (_) {},
            onStartNewEntry: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('≡ الملاحظات'), findsOneWidget);
      expect(find.text('اليوميات'), findsOneWidget);
      expect(find.text('شجرة الخزينة'), findsOneWidget);

      final searchField = tester.widget<TextField>(find.byType(TextField));
      expect(searchField.decoration?.hintText, 'البحث في الملاحظات والوسوم...');
    });
  });
}
