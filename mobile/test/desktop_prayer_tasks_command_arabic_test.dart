import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/desktop/screens/prayer_habits_screen.dart';
import 'package:axis/ui/desktop/screens/projects_tasks_screen.dart';
import 'package:axis/ui/desktop/screens/command_deck_screen.dart';
import 'package:axis/ui/notes/widgets/daily_journal_card.dart';

Widget _wrapWithArabicTheme(Widget child, {Size size = const Size(1280, 900)}) {
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
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('Prayer & Habits Arabic Localization Tests', () {
    testWidgets('PrayerHabitsScreen renders Arabic header and stats labels', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(_wrapWithArabicTheme(const PrayerHabitsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('الصلوات والعادات'), findsOneWidget);
      expect(find.text('متابعة مواقيت الصلوات اليومية وتناسق العادات الشخصية'), findsOneWidget);
      expect(find.text('صلوات اليوم'), findsOneWidget);
      expect(find.text('تتابع العادات'), findsOneWidget);
      expect(find.text('نقاط الخبرة اليومية'), findsOneWidget);
      expect(find.text('الصلاة القادمة'), findsOneWidget);
    });

    testWidgets('DesktopDailyPrayersCard renders Arabic title, station chip, and settings button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      await tester.pumpWidget(
        _wrapWithArabicTheme(
          DesktopDailyPrayersCard(onShowSettings: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الصلوات اليومية'), findsOneWidget);
      expect(find.text('الإعدادات'), findsOneWidget);
    });

    testWidgets('WeeklyConsistencyGrid renders Arabic consistency header and adherence', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 400));
      await tester.pumpWidget(_wrapWithArabicTheme(const WeeklyConsistencyGrid()));
      await tester.pumpAndSettle();

      expect(find.text('تناسق هذا الأسبوع'), findsOneWidget);
      expect(find.textContaining('الالتزام'), findsOneWidget);
      expect(find.text('اليوم'), findsOneWidget);
    });

    testWidgets('DesktopPrayerSettingsDialog renders Arabic title, Mecca, Qibla and alarms', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 700));
      await tester.pumpWidget(
        _wrapWithArabicTheme(
          DesktopPrayerSettingsDialog(onSettingsUpdated: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('قياسات ومنبهات الصلوات'), findsOneWidget);
      expect(find.text('اتجاه القبلة'), findsOneWidget);
      expect(find.text('مكة المكرمة'), findsOneWidget);
      expect(find.text('إشعارات الأذان'), findsOneWidget);
      expect(find.text('منبه الفجر الذكي للاستيقاظ'), findsOneWidget);
      expect(find.text('مزامنة الموقع GPS'), findsOneWidget);
    });

    testWidgets('DesktopDailyHabitsCard renders Arabic title, new habit button, and all habits category tab', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
      await tester.pumpWidget(
        _wrapWithArabicTheme(
          DesktopDailyHabitsCard(
            selectedCategory: 'All Habits',
            onCategorySelected: (_) {},
            onShowCreateHabitDialog: ([_]) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('العادات اليومية'), findsOneWidget);
      expect(find.text('عادة جديدة'), findsOneWidget);
      expect(find.text('كل العادات'), findsOneWidget);
    });
  });

  group('Projects & Tasks Arabic Localization Tests', () {
    testWidgets('ProjectsTasksHeader renders Arabic project title, sprint chip, and buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 400));
      await tester.pumpWidget(
        _wrapWithArabicTheme(
          ProjectsTasksHeader(
            selectedProjectId: null,
            onNewProject: () {},
            onDeleteProject: (_) {},
            taskRepo: TaskRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('المشاريع والمهام'), findsOneWidget);
      expect(find.text('دورة العمل نشطة'), findsOneWidget);
      expect(find.text('+ مشروع جديد'), findsOneWidget);
      expect(find.text('مهمة جديدة'), findsOneWidget);
    });

    testWidgets('NewProjectDialog renders Arabic title, hint, project color, and buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 500));
      await tester.pumpWidget(_wrapWithArabicTheme(const NewProjectDialog()));
      await tester.pumpAndSettle();

      expect(find.text('إنشاء مشروع جديد'), findsOneWidget);
      expect(find.text('مثال: مركز التحكم v2'), findsOneWidget);
      expect(find.text('لون المشروع'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);
      expect(find.text('إنشاء المشروع'), findsOneWidget);
    });

    testWidgets('ProjectsTaskListPane renders Arabic queue title and filter pills', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 700));
      await tester.pumpWidget(
        _wrapWithArabicTheme(
          ProjectsTaskListPane(
            selectedProjectId: null,
            selectedTaskId: null,
            onSelectTask: (_) {},
            onResetProjectFilter: () {},
            taskRepo: TaskRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('قائمة المهام'), findsOneWidget);
      expect(find.text('الكل'), findsOneWidget);
      expect(find.text('اليوم'), findsOneWidget);
      expect(find.text('النشطة'), findsOneWidget);
      expect(find.text('المكتملة'), findsOneWidget);
    });

    testWidgets('ProjectsTaskInspectorPane renders empty standby in Arabic and inspector labels when task is passed', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 700));
      await tester.pumpWidget(
        _wrapWithArabicTheme(
          ProjectsTaskInspectorPane(
            selectedTaskId: null,
            selectedTask: null,
            taskRepo: TaskRepository(),
            onTaskUpdated: (_) {},
            onTaskDeleted: () {},
            onNavigateToTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('اختر مهمة لمعاينة التفاصيل وقائمة المهام الفرعية'), findsOneWidget);

      final sampleTask = Task(
        id: 'test_task_1',
        title: 'تنفيذ بنية التطبيق',
        notes: 'ملاحظات المشروع الهامة\n- [ ] مهمة فرعية أولى',
        status: 'todo',
      );

      await tester.pumpWidget(
        _wrapWithArabicTheme(
          ProjectsTaskInspectorPane(
            selectedTaskId: sampleTask.id,
            selectedTask: sampleTask,
            taskRepo: TaskRepository(),
            onTaskUpdated: (_) {},
            onTaskDeleted: () {},
            onNavigateToTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('فاحص المهام'), findsOneWidget);
      expect(find.text('تعديل'), findsOneWidget);
      expect(find.text('قيد التنفيذ'), findsOneWidget);
      expect(find.text('الملاحظات والسياق'), findsOneWidget);
      expect(find.text('+ إضافة مهمة فرعية'), findsOneWidget);
      expect(find.text('تعيين كمكتملة'), findsOneWidget);
      expect(find.text('حذف'), findsOneWidget);
      expect(find.text('▶ بدء جلسة تركيز'), findsOneWidget);
    });
  });

  group('Command Center Deck Arabic Localization Tests', () {
    testWidgets('CommandDeckWelcomeHeader renders Arabic status and online chips', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 300));
      await tester.pumpWidget(_wrapWithArabicTheme(const CommandDeckWelcomeHeader()));
      await tester.pumpAndSettle();

      expect(find.text('النظام نشط • العقدة المحلية'), findsOneWidget);
      expect(find.textContaining('مرحباً بعودتك'), findsOneWidget);
      expect(find.text('جميع الأنظمة متصلة'), findsOneWidget);
    });

    testWidgets('CommandDeckStatsRow renders Arabic metrics labels', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 400));
      await tester.pumpWidget(_wrapWithArabicTheme(const CommandDeckStatsRow()));
      await tester.pumpAndSettle();

      expect(find.text('المهام اليومية'), findsOneWidget);
      expect(find.text('تتابع العادات'), findsOneWidget);
      expect(find.text('التركيز اليوم'), findsOneWidget);
      expect(find.text('الصلاة القادمة'), findsOneWidget);
    });

    testWidgets('ExecutionStreamCard renders Arabic execution stream header', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 400));
      await tester.pumpWidget(
        _wrapWithArabicTheme(
          ExecutionStreamCard(onTaskPreview: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("مسار تنفيذ اليوم"), findsOneWidget);
      expect(find.textContaining('متبقي'), findsOneWidget);
    });

    testWidgets('MacroSlotsCard renders Arabic 15-min slots header and reschedule button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 400));
      await tester.pumpWidget(
        _wrapWithArabicTheme(
          MacroSlotsCard(onTaskPreview: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الفترات المصغرة 15 د'), findsOneWidget);
      expect(find.text('إعادة الجدولة'), findsOneWidget);
      expect(find.text('0 فترات'), findsOneWidget);
    });

    testWidgets('DailyJournalCard renders Arabic start prompt and button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 400));
      await tester.pumpWidget(
        _wrapWithArabicTheme(
          DailyJournalCard(
            todayJournal: null,
            onOpenTodayJournal: (_) {},
            onStartNewJournal: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('اليوميات اليومية'), findsOneWidget);
      expect(find.text('دوّن الأحداث التي وقعت خلال يومك'), findsOneWidget);
      expect(find.text('بدء تدوينة يوميات اليوم'), findsOneWidget);
    });

    testWidgets('CommandDeckPrayerTelemetryCard renders Arabic prayer telemetry title', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 400));
      await tester.pumpWidget(_wrapWithArabicTheme(const CommandDeckPrayerTelemetryCard()));
      await tester.pumpAndSettle();

      expect(find.text('قياسات الصلوات'), findsOneWidget);
      expect(find.textContaining('الفرائض:'), findsOneWidget);
    });

    testWidgets('CommandDeckHabitLoopsCard renders Arabic streaks and buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 400));
      await tester.pumpWidget(
        _wrapWithArabicTheme(
          CommandDeckHabitLoopsCard(onNavigateToTab: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('التتابع وحلقات العادات'), findsOneWidget);
      expect(find.text('جديدة'), findsOneWidget);
      expect(find.text('عرض ↗'), findsOneWidget);
    });

    testWidgets('CommandDeckLevelXpCard renders Arabic level operator title', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 200));
      await tester.pumpWidget(_wrapWithArabicTheme(const CommandDeckLevelXpCard()));
      await tester.pumpAndSettle();

      expect(find.textContaining('مشغل مستوى'), findsOneWidget);
      expect(find.textContaining('نقطة خبرة'), findsOneWidget);
    });

    testWidgets('DesktopTaskPreviewDialog renders Arabic title, edit button, and close', (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 800));
      final sampleTask = Task(
        id: 'task_preview_test',
        title: 'مراجعة الكود النهائي',
        notes: '- [ ] خطوة الفحص الأولى\n- [ ] خطوة الفحص الثانية',
        estimateMin: 15,
        dueDate: '2026-11-09',
        status: 'todo',
      );

      await tester.pumpWidget(
        _wrapWithArabicTheme(
          DesktopTaskPreviewDialog(
            initialTask: sampleTask,
            onTaskUpdated: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("معاينة المهمة // مسار اليوم"), findsOneWidget);
      expect(find.text('تعديل'), findsNWidgets(2));
      expect(find.text('إغلاق'), findsOneWidget);
      expect(find.text('إكمال المهمة'), findsOneWidget);
      expect(find.text('قيد التنفيذ'), findsOneWidget);
      expect(find.textContaining('الاستحقاق:'), findsOneWidget);
      expect(find.textContaining('تقدير'), findsOneWidget);
      expect(find.textContaining('المهام الفرعية'), findsOneWidget);
    });
  });
}
