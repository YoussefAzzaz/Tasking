import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Centralized typed localization class for Axis application.
/// Provides comprehensive English ('en') and Arabic ('ar') translations
/// covering navigation, screens, dialogs, forms, empty states, and actions.
class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('ar'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('ar'),
    Locale('en'),
  ];

  bool get isArabic => locale.languageCode == 'ar';
  TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  // --------------------------------------------------------------------------
  // Navigation & Shell
  // --------------------------------------------------------------------------
  String get today => isArabic ? 'اليوم' : 'Today';
  String get tasks => isArabic ? 'المهام' : 'Tasks';
  String get habits => isArabic ? 'العادات' : 'Habits';
  String get notes => isArabic ? 'الملاحظات' : 'Notes';
  String get me => isArabic ? 'حسابي' : 'Me';
  String get companions => isArabic ? 'الرفاق' : 'Companions';
  String get friends => isArabic ? 'الأصدقاء' : 'Friends';
  String get focus => isArabic ? 'التركيز' : 'Focus';

  // Tabs & Views
  String get inbox => isArabic ? 'الوارد' : 'Inbox';
  String get upcoming => isArabic ? 'القادمة' : 'Upcoming';
  String get outdated => isArabic ? 'الفائتة' : 'Outdated';
  String get projects => isArabic ? 'المشاريع' : 'Projects';
  String get journals => isArabic ? 'اليوميات' : 'Journals';
  String get vault => isArabic ? 'الخزينة' : 'Vault';

  // Desktop Navigation
  String get commandDeck => isArabic ? 'لوحة التحكم' : 'Command Deck';
  String get projectsTasks => isArabic ? 'المشاريع والمهام' : 'Projects & Tasks';
  String get prayerHabits => isArabic ? 'الصلوات والعادات' : 'Prayer & Habits';
  String get journalVault => isArabic ? 'اليوميات والخزينة' : 'Journal & Vault';
  String get focusTimers => isArabic ? 'مؤقتات التركيز' : 'Focus Timers';
  String get profileSettings => isArabic ? 'الملف الشخصي والإعدادات' : 'Profile & Settings';

  // --------------------------------------------------------------------------
  // Language & Settings
  // --------------------------------------------------------------------------
  String get language => isArabic ? 'اللغة' : 'Language';
  String get appLanguage => isArabic ? 'لغة التطبيق' : 'App Language';
  String get english => isArabic ? 'الإنجليزية' : 'English';
  String get arabic => isArabic ? 'العربية' : 'العربية';
  String get readingFontSize => isArabic ? 'حجم خط القراءة' : 'Reading Font Size';
  String get selectLanguage => isArabic ? 'اختر لغة التطبيق' : 'Select App Language';

  // --------------------------------------------------------------------------
  // Common Actions
  // --------------------------------------------------------------------------
  String get save => isArabic ? 'حفظ' : 'Save';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get delete => isArabic ? 'حذف' : 'Delete';
  String get edit => isArabic ? 'تعديل' : 'Edit';
  String get add => isArabic ? 'إضافة' : 'Add';
  String get close => isArabic ? 'إغلاق' : 'Close';
  String get search => isArabic ? 'بحث' : 'Search';
  String get filter => isArabic ? 'تصفية' : 'Filter';
  String get all => isArabic ? 'الكل' : 'All';
  String get completed => isArabic ? 'مكتمل' : 'Completed';
  String get pending => isArabic ? 'معلق' : 'Pending';
  String get inProgress => isArabic ? 'قيد التنفيذ' : 'In Progress';
  String get done => isArabic ? 'تم' : 'Done';
  String get copy => isArabic ? 'نسخ' : 'Copy';
  String get copied => isArabic ? 'تم النسخ إلى الحافظة' : 'Copied to clipboard';
  String get refresh => isArabic ? 'تحديث' : 'Refresh';
  String get confirm => isArabic ? 'تأكيد' : 'Confirm';
  String get clear => isArabic ? 'مسح' : 'Clear';
  String get clearSearch => isArabic ? 'مسح البحث' : 'Clear Search';
  String get reset => isArabic ? 'إعادة تعيين' : 'Reset';
  String get signOut => isArabic ? 'تسجيل الخروج' : 'Sign Out';
  String get signIn => isArabic ? 'تسجيل الدخول' : 'Sign In';
  String get guestMode => isArabic ? 'وضع الزائر' : 'Guest Mode';
  String get exitGuest => isArabic ? 'الخروج من وضع الزائر' : 'Exit Guest';
  String get level => isArabic ? 'المستوى' : 'Level';
  String get xp => isArabic ? 'نقطة خبرة' : 'XP';

  // --------------------------------------------------------------------------
  // Prayers
  // --------------------------------------------------------------------------
  String get fajr => isArabic ? 'الفجر' : 'Fajr';
  String get sunrise => isArabic ? 'الشروق' : 'Sunrise';
  String get dhuhr => isArabic ? 'الظهر' : 'Dhuhr';
  String get asr => isArabic ? 'العصر' : 'Asr';
  String get maghrib => isArabic ? 'المغرب' : 'Maghrib';
  String get isha => isArabic ? 'العشاء' : 'Isha';
  String get nextPrayer => isArabic ? 'الصلاة القادمة' : 'Next Prayer';
  String get prayerStreak => isArabic ? 'سلسلة الصلوات' : 'Prayer Streak';
  String get allPrayersDone => isArabic ? 'تمت جميع صلوات اليوم' : 'All Prayers Completed';
  String get missingPrayers => isArabic ? 'صلوات متبقية اليوم' : 'Missing Prayers Today';
  String get prayersCompletedToday => isArabic ? 'صلوات مكتملة اليوم' : 'prayers completed today';
  String get prayerTimes => isArabic ? 'مواقيت الصلاة' : 'Prayer Times';
  String get qibla => isArabic ? 'القبلة' : 'Qibla';

  String prayerName(String key) {
    switch (key.toLowerCase()) {
      case 'fajr':
        return fajr;
      case 'sunrise':
        return sunrise;
      case 'dhuhr':
        return dhuhr;
      case 'asr':
        return asr;
      case 'maghrib':
        return maghrib;
      case 'isha':
        return isha;
      default:
        return key;
    }
  }

  // --------------------------------------------------------------------------
  // Tasks & Habits
  // --------------------------------------------------------------------------
  String get newTask => isArabic ? 'مهمة جديدة' : 'New Task';
  String get newProject => isArabic ? 'مشروع جديد' : 'New Project';
  String get taskTitle => isArabic ? 'عنوان المهمة' : 'Task Title';
  String get priority => isArabic ? 'الأولوية' : 'Priority';
  String get dueDate => isArabic ? 'تاريخ الاستحقاق' : 'Due Date';
  String get dueTime => isArabic ? 'وقت الاستحقاق' : 'Due Time';
  String get dueToday => isArabic ? 'تستحق اليوم' : 'Due Today';
  String get overdue => isArabic ? 'متأخرة' : 'Overdue';
  String get noTasks => isArabic ? 'لا توجد مهام' : 'No tasks found';
  String get newHabit => isArabic ? 'عادة جديدة' : 'New Habit';
  String get addHabit => isArabic ? 'إضافة عادة' : 'Add Habit';
  String get habitTitle => isArabic ? 'عنوان العادة' : 'Habit Title';
  String get streak => isArabic ? 'التتابع' : 'Streak';
  String get days => isArabic ? 'أيام' : 'days';
  String get day => isArabic ? 'يوم' : 'day';
  String get daily => isArabic ? 'يومي' : 'Daily';
  String get weekly => isArabic ? 'أسبوعي' : 'Weekly';
  String get monthly => isArabic ? 'شهري' : 'Monthly';
  String get noHabits => isArabic ? 'لا توجد عادات بعد' : 'No habits yet';
  String get habitRoutinesByCategory =>
      isArabic ? 'العادات والروتين حسب التصنيف' : 'HABIT ROUTINES BY CATEGORY';

  // --------------------------------------------------------------------------
  // Companions & Mutual Accountability
  // --------------------------------------------------------------------------
  String get friendCode => isArabic ? 'رمز الصديق' : 'Friend Code';
  String get yourFriendCode => isArabic ? 'رمزك الخاص' : 'Your Friend Code';
  String get addCompanion => isArabic ? 'إضافة رفيق' : 'Add Companion';
  String get enterFriendCode =>
      isArabic ? 'أدخل رمز الصديق المكون من 8 خانات' : 'Enter 8-character friend code';
  String get sendRequest => isArabic ? 'إرسال طلب' : 'Send Request';
  String get friendRequests => isArabic ? 'طلبات الصداقة' : 'Friend Requests';
  String get noCompanionsYet =>
      isArabic ? 'لم تقم بإضافة أي رفاق بعد' : 'No companions added yet';
  String get mutualPrayerAccountability =>
      isArabic ? 'المتابعة المتبادلة للصلوات' : 'Mutual Prayer Accountability';
  String get accept => isArabic ? 'قبول' : 'Accept';
  String get decline => isArabic ? 'رفض' : 'Decline';
  String get pendingRequest => isArabic ? 'طلب معلق' : 'Pending Request';
  String get prayerStreakLabel => isArabic ? 'سلسلة أيام متتالية' : 'day streak';
  String get todaysBoard => isArabic ? 'لوحة اليوم' : "Today's Board";
  String get weeklyStandings => isArabic ? 'الترتيب الأسبوعي' : 'Weekly Standings';
  String get circle => isArabic ? 'الدائرة' : 'Circle';

  // --------------------------------------------------------------------------
  // Focus & Timers
  // --------------------------------------------------------------------------
  String get focusSession => isArabic ? 'جلسة تركيز' : 'Focus Session';
  String get startFocus => isArabic ? 'بدء التركيز' : 'Start Focus';
  String get pause => isArabic ? 'إيقاف مؤقت' : 'Pause';
  String get resume => isArabic ? 'استئناف' : 'Resume';
  String get stop => isArabic ? 'إيقاف' : 'Stop';
  String get pomodoro => isArabic ? 'بومودورو' : 'Pomodoro';
  String get shortBreak => isArabic ? 'استراحة قصيرة' : 'Short Break';
  String get longBreak => isArabic ? 'استراحة طويلة' : 'Long Break';
  String get deepWorkCycle => isArabic ? 'دورة تركيز عميق' : 'Deep Work Cycle';
  String get rebootBreak => isArabic ? 'استراحة استعادة الطاقة' : 'Reboot Break';
  String get takeBreak => isArabic ? 'أخذ استراحة' : 'Take Break';
  String get endBreak => isArabic ? 'إنهاء الاستراحة' : 'End Break';
  String get addFiveMinutes => isArabic ? '+5 دقائق تركيز' : '+5 Min Focus';

  // --------------------------------------------------------------------------
  // General UI Translation Lookup
  // --------------------------------------------------------------------------
  static final Map<String, String> _arDictionary = {
    // Navigation & Tabs
    'today': 'اليوم',
    'tasks': 'المهام',
    'habits': 'العادات',
    'notes': 'الملاحظات',
    'me': 'حسابي',
    'profile': 'الملف الشخصي',
    'companions': 'الرفاق',
    'friends': 'الأصدقاء',
    'focus': 'التركيز',
    'command deck': 'لوحة التحكم',
    'projects & tasks': 'المشاريع والمهام',
    'prayer & habits': 'الصلوات والعادات',
    'journal & vault': 'اليوميات والخزينة',
    'focus timers': 'مؤقتات التركيز',
    'profile & settings': 'الملف الشخصي والإعدادات',
    'inbox': 'الوارد',
    'upcoming': 'القادمة',
    'outdated': 'الفائتة',
    'projects': 'المشاريع',
    'journals': 'اليوميات',
    'vault': 'الخزينة',
    'settings': 'الإعدادات',

    // Prayers
    'fajr': 'الفجر',
    'sunrise': 'الشروق',
    'dhuhr': 'الظهر',
    'asr': 'العصر',
    'maghrib': 'المغرب',
    'isha': 'العشاء',
    'next prayer': 'الصلاة القادمة',
    'prayer streak': 'سلسلة الصلوات',
    'all prayers completed': 'تمت جميع صلوات اليوم',
    'missing prayers today': 'صلوات متبقية اليوم',
    'missing prayers': 'صلوات متبقية',
    'prayers completed today': 'صلوات مكتملة اليوم',
    'prayer times': 'مواقيت الصلاة',
    'qibla': 'القبلة',
    'qibla compass': 'بوصلة القبلة',
    'adhan alarm': 'منبه الأذان',
    'fajr alarm': 'منبه صلاة الفجر',
    'daily prayer checklist': 'قائمة الصلوات اليومية',

    // Actions & Buttons
    'save': 'حفظ',
    'cancel': 'إلغاء',
    'delete': 'حذف',
    'edit': 'تعديل',
    'add': 'إضافة',
    'close': 'إغلاق',
    'search': 'بحث',
    'filter': 'تصفية',
    'all': 'الكل',
    'completed': 'مكتمل',
    'pending': 'قيد الانتظار',
    'in progress': 'قيد التنفيذ',
    'done': 'تم',
    'copy': 'نسخ',
    'copy code': 'نسخ الرمز',
    'copied': 'تم النسخ',
    'refresh': 'تحديث',
    'confirm': 'تأكيد',
    'clear': 'مسح',
    'clear search': 'مسح البحث',
    'reset': 'إعادة تعيين',
    'reset to 0': 'إعادة للصفر',
    'sign out': 'تسجيل الخروج',
    'sign in': 'تسجيل الدخول',
    'sign out?': 'تسجيل الخروج؟',
    'guest mode': 'وضع الزائر',
    'exit guest': 'الخروج من وضع الزائر',
    'exit guest mode?': 'الخروج من وضع الزائر؟',

    // Tasks & Projects
    'new task': 'مهمة جديدة',
    'new project': 'مشروع جديد',
    'add task': 'إضافة مهمة',
    'add project': 'إضافة مشروع',
    'task title': 'عنوان المهمة',
    'description': 'الوصف',
    'priority': 'الأولوية',
    'urgent (p1)': 'عاجل (P1)',
    'high (p2)': 'مرتفع (P2)',
    'medium (p3)': 'متوسط (P3)',
    'low (p4)': 'منخفض (P4)',
    'due date': 'تاريخ الاستحقاق',
    'due time': 'وقت الاستحقاق',
    'due today': 'تستحق اليوم',
    'overdue': 'متأخرة',
    'no tasks found': 'لا توجد مهام',
    'no tasks': 'لا توجد مهام',
    'project': 'المشروع',
    'tags': 'الوسوم',
    'tag': 'وسم',
    'category': 'التصنيف',
    'categories': 'التصنيفات',

    // Habits & Streaks
    'new habit': 'عادة جديدة',
    'add habit': 'إضافة عادة',
    'habit title': 'عنوان العادة',
    'habit routines by category': 'العادات والروتين حسب التصنيف',
    'reset habit streak?': 'إعادة تعيين تتابع العادات؟',
    'streak': 'التتابع',
    'days': 'أيام',
    'day': 'يوم',
    'days streak': 'أيام متتالية',
    'day streak': 'أيام متتالية',
    'daily': 'يومي',
    'weekly': 'أسبوعي',
    'monthly': 'شهري',
    'no habits yet': 'لا توجد عادات بعد',
    'best streak': 'أفضل تتابع',
    'current streak': 'التتابع الحالي',
    'monthly rate': 'المعدل الشهري',

    // Focus & Pomodoro
    'focus session': 'جلسة تركيز',
    'start focus': 'بدء التركيز',
    'engage focus': 'بدء التركيز',
    'pause focus': 'إيقاف مؤقت',
    'pause': 'إيقاف مؤقت',
    'resume': 'استئناف',
    'stop': 'إيقاف',
    'pomodoro': 'بومودورو',
    'short break': 'استراحة قصيرة',
    'long break': 'استراحة طويلة',
    'deep work cycle': 'دورة تركيز عميق',
    'reboot break': 'استراحة استعادة الطاقة',
    '+5 min focus': '+5 دقائق تركيز',
    'take break': 'أخذ استراحة',
    'end break': 'إنهاء الاستراحة',
    'ambient soundscape': 'الأصوات المحيطة',
    'view setup & stats': 'عرض الإعدادات والإحصائيات',
    'soundscapes': 'المؤثرات الصوتية',

    // Notes & Journals
    'new note': 'ملاحظة جديدة',
    'new journal': 'يومية جديدة',
    'start daily journal': 'بدء يومية اليوم',
    'daily review': 'المراجعة اليومية',
    'journal entry': 'تدوينة اليوميات',
    'no notes found': 'لا توجد ملاحظات',
    'general notes': 'ملاحظات عامة',
    'search notes...': 'البحث في الملاحظات...',
    'search habits...': 'البحث في العادات...',
    'search tasks...': 'البحث في المهام...',

    // Companions & Friends
    'today\'s board': 'لوحة اليوم',
    'weekly standings': 'الترتيب الأسبوعي',
    'circle': 'الدائرة',
    'add companion': 'إضافة رفيق',
    '+ add companion': '+ إضافة رفيق',
    'friend code': 'رمز الصديق',
    'your friend code': 'رمزك الخاص',
    'enter friend code': 'أدخل رمز الصديق المكون من 8 خانات',
    'send request': 'إرسال طلب',
    'friend requests': 'طلبات الصداقة',
    'no companions added yet': 'لم تقم بإضافة رفاق بعد',
    'mutual prayer accountability': 'المتابعة المتبادلة للصلوات',
    'accept': 'قبول',
    'decline': 'رفض',
    'pending request': 'طلب معلق',
    'friend code copied to clipboard!': 'تم نسخ رمز الصديق إلى الحافظة!',

    // Gamification & Telemetry
    'level': 'المستوى',
    'xp': 'نقطة خبرة',
    'earned today': 'تم كسبها اليوم',
    'trophy room & badges': 'غرفة الجوائز والأوسمة',
    'master operator trophy room & badges': 'غرفة جوائز وأوسمة المشغل المتميز',
    'mastery badges': 'أوسمة الإتقان',
    'telemetry': 'القياسات',
    'system status': 'حالة النظام',
    'online': 'متصل',
    'offline': 'غير متصل',
    'synced': 'تمت المزامنة',
    'syncing...': 'جارٍ المزامنة...',
    'reading preferences': 'تفضيلات القراءة',
    'reading font size': 'حجم خط القراءة',
    'language': 'اللغة',
    'app language': 'لغة التطبيق',
    'select app language': 'اختر لغة التطبيق',
    'english': 'الإنجليزية',
    'arabic': 'العربية',
  };

  /// Translates a given English UI label to Arabic if the active locale is Arabic.
  /// If the locale is English or no translation exists, returns the original text.
  String translate(String text) {
    if (!isArabic) return text;
    final normalized = text.trim().toLowerCase();
    return _arDictionary[normalized] ?? _arDictionary[text] ?? text;
  }
}

/// Extension providing easy `.tr(context)` translation on string literals.
extension LocalizedStringExt on String {
  String tr(BuildContext context) => AppLocalizations.of(context).translate(this);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
