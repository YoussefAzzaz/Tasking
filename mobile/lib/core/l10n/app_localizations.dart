import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// Centralized typed localization class for Axis application.
/// Provides comprehensive English ('en') and Arabic ('ar') translations
/// covering navigation, screens, dialogs, forms, empty states, and actions.
class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    final registered = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (registered != null) return registered;
    final locale = Localizations.maybeLocaleOf(context) ?? const Locale('en');
    return AppLocalizations(locale);
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
  String get calendar => isArabic ? 'التقويم' : 'Calendar';
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

  String localizedHabitCategory(String name) {
    if (!isArabic) return name;
    switch (name.toLowerCase().trim()) {
      case 'morning routines':
      case 'morning routine':
      case 'morning':
        return 'روتين الصباح';
      case 'evening routines':
      case 'evening routine':
      case 'evening':
        return 'روتين المساء';
      case 'general routines':
      case 'general':
        return 'عادات عامة';
      case 'health & fitness':
      case 'health':
      case 'fitness':
        return 'الصحة واللياقة';
      case 'focus & work':
      case 'focus':
      case 'work':
        return 'التركيز والعمل';
      case 'reading & learning':
      case 'reading':
      case 'learning':
        return 'القراءة والتعلم';
      case 'mindfulness':
      case 'meditation':
        return 'التأمل والسكينة';
      default:
        return name;
    }
  }

  String localizedNoteCategory(String name) {
    if (!isArabic) return name;
    switch (name.toLowerCase().trim()) {
      case 'personal':
        return 'شخصي';
      case 'work':
        return 'عمل';
      case 'ideas':
      case 'idea':
        return 'أفكار';
      case 'architecture':
        return 'هندسة وتصميم';
      case 'study':
      case 'learning':
        return 'دراسة وتعلم';
      case 'general':
        return 'عام';
      case 'reading':
        return 'قراءة';
      case 'vault':
        return 'الخزينة';
      case 'journal':
      case 'journals':
        return 'اليوميات';
      default:
        return name;
    }
  }

  String localizedMood(String mood) {
    if (!isArabic) return mood;
    switch (mood.toUpperCase().trim()) {
      case 'HIGH ENERGY':
        return 'طاقة عالية';
      case 'CALM FOCUS':
        return 'تركيز هادئ';
      case 'DEEP FLOW':
        return 'تدفق عميق';
      case 'RECHARGE':
        return 'استعادة نشاط';
      default:
        return mood;
    }
  }

  String localizedSoundscapeTitle(String title) {
    if (!isArabic) return title;
    switch (title.toLowerCase()) {
      case 'gentle rain':
        return 'مطر هادئ';
      case 'ocean waves':
        return 'أمواج المحيط';
      case 'campfire glow':
        return 'دفء الموقد';
      case 'deep space':
        return 'الفضاء العميق';
      case 'zen garden':
        return 'حديقة الزن';
      case 'night crickets':
        return 'أصوات الليل الهادئة';
      case 'alpha wave 10hz':
        return 'موجات ألفا 10 هرتز';
      case 'brown noise':
        return 'الضجيج البني';
      default:
        return title;
    }
  }

  String localizedSoundscapeCategory(String category) {
    if (!isArabic) return category;
    switch (category.toLowerCase()) {
      case 'nature':
        return 'طبيعة';
      case 'cozy':
        return 'دافئ';
      case 'ambient':
        return 'محيطي';
      case 'zen':
        return 'سكينة';
      default:
        return category;
    }
  }

  String localizedSoundscapeSubtitle(String subtitle) {
    if (!isArabic) return subtitle;
    switch (subtitle.toLowerCase()) {
      case 'soothing forest drizzle & soft drops':
        return 'رذاذ الغابة الهادئ وقطرات المطر الرقيقة';
      case 'rhythmic surf & tidal breathing flow':
        return 'إيقاع الأمواج وتدفق المد والجزر المريح';
      case 'warm crackling embers & low hearth':
        return 'فرقعة الجمر الدافئ وهدير الموقد الهادئ';
      case 'velvet cosmic harmonic pad drone':
        return 'نغمات كونية مخملية لتعزيز الصفاء الذهني';
      case 'singing bowl resonance & calm breeze':
        return 'رنين الأوعية الموسيقية ونسيم هادئ';
      case 'tranquil meadow nocturnal air':
        return 'هواء الحقول الليلي وسكينة المساء';
      case 'subconscious calm focus entrainment':
        return 'تحفيز التركيز والاسترخاء العميق';
      case 'deep warm sound veil & tinnitus mask':
        return 'عازل صوتي دافئ لحجب التشتت والضوضاء';
      default:
        return subtitle;
    }
  }

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
  String get todayPrayerSub =>
      isArabic ? 'نلهم ونذكر بعضنا البعض بالصلوات والطاعات' : 'Inspire and remind each other. Stay steadfast together.';
  String get connectedCompanions => isArabic ? 'الرفاق المتصلون' : 'Connected Companions';
  String get pendingRequests => isArabic ? 'الطلبات المعلقة' : 'Pending Requests';
  String get allCompletedBadge => isArabic ? 'اكتملت جميعاً' : 'All completed';
  String get circleStandingsSub =>
      isArabic ? 'تنافس أخوي مبني على نقاط الانضباط الأسبوعية' : 'Supportive weekly progress. Ranked by discipline XP.';
  String get copyCodeSuccess => isArabic ? 'تم نسخ رمز الصديق إلى الحافظة!' : 'Friend code copied to clipboard!';
  String get searchCompanionHint => isArabic ? 'رمز الصديق أو الاسم (مثلاً AX-8492)' : 'Friend code or name (e.g. AX-8492)';
  String get addCompanionDesc =>
      isArabic ? 'أدخل رمز الصديق أو اسمه للتواصل ومشاركة المتابعة اليومية للصلوات والعادات.' : 'Enter your companion\'s friend code or display name to connect and share daily prayer & habit consistency.';
  String get noCompanionsDesc =>
      isArabic ? 'أضف رفيقاً برمز الصديق للتعاون على الصلاة والمواظبة على العادات.' : 'Add a companion with their friend code to share daily prayer and habit consistency.';
  String get removeCompanion => isArabic ? 'إزالة الرفيق' : 'Remove Companion';
  String get removeCompanionConfirm => isArabic ? 'هل تريد إزالة هذا الرفيق من قائمة المتابعة؟' : 'Remove companion from your accountability circle?';
  String get remove => isArabic ? 'إزالة' : 'Remove';
  String get dailyHabitsCount => isArabic ? 'العادات اليومية' : 'Daily Habits';
  String get sendConnectionRequest => isArabic ? 'إرسال طلب تواصل' : 'Send Connection Request';
  String get prayersDoneCount => isArabic ? 'صلوات مكتملة اليوم' : 'prayers completed today';
  String get youLabel => isArabic ? 'أنت' : 'YOU';
  String get tapToRemind => isArabic ? 'انقر للتذكير' : 'Tap to remind';
  String get yourChecklist => isArabic ? 'حالتك اليوم' : 'YOUR CHECKLIST';
  String get companionsAccountability => isArabic ? 'متابعة الرفاق' : 'COMPANIONS ACCOUNTABILITY';
  String get companionProfile => isArabic ? 'ملف الرفيق' : 'Companion Profile';
  String get completedBadges => isArabic ? 'الشارات المكتملة' : 'Completed Badges';
  String get noBadgesYet => isArabic ? 'لا توجد شارات مكتملة بعد' : 'No badges completed yet';
  String get companionHabitsProgress => isArabic ? 'عادات الرفيق اليومية' : 'Companion Daily Habits';
  String get candidateFound => isArabic ? 'تم العثور على رفيق' : 'Companion Found';
  String get noCompanionFound => isArabic ? 'لم يتم العثور على رفيق بهذا الرمز أو الاسم' : 'No companion found with this code or name';
  String get searching => isArabic ? 'جارٍ البحث...' : 'Searching...';
  String get friendNotifications => isArabic ? 'إشعارات الرفاق والتذكيرات' : 'Companion Reminders & Activity';
  String get noNotificationsYet => isArabic ? 'لا توجد تنبيهات جديدة من الرفاق' : 'No new companion notifications';
  String get clearNotifications => isArabic ? 'مسح الكل' : 'Clear All';
  String get refuse => isArabic ? 'رفض' : 'Refuse';
  String get requestAccepted => isArabic ? 'تم قبول طلب الرفقة بنجاح' : 'Companion request accepted!';
  String get requestDeclined => isArabic ? 'تم رفض طلب الرفقة' : 'Companion request declined';
  String get alreadyFriends => isArabic ? 'رفيق متصل بالفعل' : 'Already connected companion';
  String get requestAlreadyPending => isArabic ? 'الطلب معلق بالفعل' : 'Request already pending';
  String sendRequestTo(String name) => isArabic ? 'إرسال طلب إلى $name' : 'Send Request to $name';

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
    'refuse': 'رفض',
    'pending request': 'طلب معلق',
    'pending requests': 'الطلبات المعلقة',
    'connected companions': 'الرفاق المتصلون',
    'companion reminders & activity': 'إشعارات الرفاق والتذكيرات',
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

    // Profile & Operator Settings
    'settings / operator profile': 'الإعدادات / ملف المشغل',
    'account & customization': 'الحساب والتخصيص',
    'save changes': 'حفظ التغييرات',
    'operator identity': 'هوية المشغل',
    'avatar photo & identity picture': 'الصورة الشخصية وصورة الهوية',
    'choose picture': 'اختيار صورة',
    'uploading...': 'جارٍ الرفع...',
    'remove': 'إزالة',
    'or avatar image url': 'أو رابط صورة الهوية (URL)',
    'display name': 'اسم العرض',
    'enter operator name': 'أدخل اسم المشغل',
    'call-sign / identifier': 'رمز النداء / المعرف',
    'enter callsign': 'أدخل رمز النداء',
    'primary station email': 'البريد الإلكتروني الأساسي للمحطة',
    'note categories': 'تصنيفات الملاحظات',
    'habit categories': 'تصنيفات العادات',
    'task tags & labels': 'وسوم وعلامات المهام',
    'new note category...': 'تصنيف ملاحظات جديد...',
    'new habit category title...': 'عنوان تصنيف عادات جديد...',
    '#new-identifier...': '#وسم-جديد...',
    '+ add': '+ إضافة',
    '+ create tag': '+ إنشاء وسم',
    'preview sample': 'نموذج المعاينة',
    'operator mastery badges': 'أوسمة إتقان المشغل',
    'open badges ↗': 'فتح الشارات ↗',
    'open badges': 'فتح الشارات',
    'trophy showroom': 'معرض الجوائز',
    'verified': 'مُوثَّق',
    'unlocked': 'مفتوحة',
    'locked': 'مقفل',
    'all state': 'كل الحالات',
    'tier roadmap': 'خارطة المستويات',

    // Focus Timers & Pomodoro
    'focus sprint': 'جلسة تركيز',
    'active sprint': 'جلسة نشطة',
    'break in progress': 'الاستراحة قيد التقدم',
    'break standby': 'استراحة في وضع الاستعداد',
    'deep work focus session': 'جلسة تركيز للعمل العميق',
    'cognitive reset & hydration': 'إعادة ضبط التركيز والترطيب',
    'focus sprint protocol': 'بروتوكول جلسات التركيز',
    'focus sprint duration': 'مدة جلسة التركيز',
    'short reboot break': 'استراحة استعادة النشاط القصيرة',
    'cycles before long reset': 'الدورات قبل الاستراحة الطويلة',
    'auto-start reboot breaks': 'بدء استراحات الاستعادة تلقائياً',
    'save protocol': 'حفظ البروتوكول',
    'time remaining': 'الوقت المتبقي',
    'skip break': 'تخطي الاستراحة',
    'start session': 'بدء الجلسة',
    'start break': 'بدء الاستراحة',
    'session': 'الجلسة',
    'session 1': 'الجلسة 1',
    'session 2': 'الجلسة 2',
    'session 3': 'الجلسة 3',
    'session 4': 'الجلسة 4',

    // Soundscapes
    'ambient soundscapes': 'أصوات الخلفية المحيطة',
    'neural audio entrainment for deep concentration': 'مؤثرات صوتية هادئة لتعزيز التركيز والانغماس الذهني',
    'audio active': 'الصوت نشط',
    'gentle rain': 'مطر هادئ',
    'ocean waves': 'أمواج المحيط',
    'campfire glow': 'دفء الموقد',
    'deep space': 'الفضاء العميق',
    'zen garden': 'حديقة الزن',
    'white noise': 'ضوضاء بيضاء',

    // Session Goal & Attach Task
    'current session goal': 'هدف الجلسة الحالية',
    'switch task': 'تبديل المهمة',
    'attach task': 'ربط مهمة',
    'detach task': 'إلغاء ربط المهمة',
    'attach task to focus session': 'ربط مهمة بجلسة التركيز',
    'no active deliverables found.': 'لا توجد مهام نشطة حالياً.',
    'deep cognitive focus & flow': 'تركيز ذهني عميق وانسيابية',
    'eliminate interruptions and maintain uninterrupted concentration.': 'تجنب المقاطعات وحافظ على تركيز مستمر دون انقطاع.',
    'eliminate interruptions and maintain uninterrupted concentration on this deliverable.': 'تجنب المقاطعات وحافظ على تركيز مستمر لإنجاز هذه المهمة.',

    // Quick notes & Distractions
    'quick notes & distractions': 'ملاحظات سريعة ومشتتات الذهن',
    'capture fleeting thoughts without breaking flow': 'التقط الأفكار العابرة دون قطع حبل تركيزك',
    'capture a quick idea, task or thought to review later...': 'التقط فكرة سريعة أو مهمة أو خاطرة لمراجعتها لاحقاً...',
    'save note to vault': 'حفظ الملاحظة في الخزينة',
    'distraction captured to vault': 'تم حفظ الفكرة المشتتة في الخزينة',

    // Today's schedule and sprints
    'today\'s schedule & sprints': 'جدول اليوم وجلسات التركيز',
    'logged today': 'سُجلت اليوم',
    'scheduled': 'مجدولة',
    'no focus sprints recorded yet today. launch a session to begin deep work.': 'لم تسجل أي جلسات تركيز اليوم بعد. ابدأ جلسة للانطلاق في العمل العميق.',
    'active focus sprint': 'جلسة تركيز نشطة',
    'deep focus sprint': 'جلسة تركيز عميق',

    // Journal & Vault
    'knowledge base / journals / ': 'قاعدة المعرفة / اليوميات / ',
    'knowledge base / notes / ': 'قاعدة المعرفة / الملاحظات / ',
    'overview': 'نظرة عامة',
    'create daily journal': 'إنشاء يومية جديدة',
    'create note': 'إنشاء ملاحظة جديدة',
    'journal vault': 'خزينة اليوميات',
    'vault & architecture notes': 'الخزينة وملاحظات البنية البرمجية',
    'pinned': 'مثبت',
    'pin': 'تثبيت',
    'export .md': 'تصدير .md',
    'markdown editor': 'محرر ماركداون',
    'auto-saved': 'حفظ تلقائي',
    'save journal': 'حفظ اليومية',
    'save note': 'حفظ الملاحظة',
    'daily reflection title...': 'عنوان يومية التأمل...',
    'note title...': 'عنوان الملاحظة...',
    'category: ': 'التصنيف: ',
    'preview': 'المعاينة',
    'empty note': 'ملاحظة فارغة',
    'no content yet.': 'لا يوجد محتوى بعد.',
    'search notes & tags...': 'البحث في الملاحظات والوسوم...',
    'vault hierarchy': 'شجرة الخزينة',
    'no journals recorded yet': 'لم يتم تسجيل يوميات بعد',
    'untitled': 'بلا عنوان',
    'journal deck': 'سجل اليوميات',
    'daily review prompt': 'سؤال المراجعة اليومية',

    // Prayer & Habits Telemetry
    'track daily prayer times and personal habit consistency': 'متابعة مواقيت الصلوات اليومية وتناسق العادات الشخصية',
    'today\'s prayers': 'صلوات اليوم',
    'completed today': 'مكتملة اليوم',
    'habits completed today': 'عادات مكتملة اليوم',
    'daily xp': 'نقاط الخبرة اليومية',
    'from habits and prayer completion': 'من إنجاز العادات والصلوات',
    'upcoming window': 'الموعد القادم',
    'all obligations fulfilled': 'تمت جميع الفرائض',
    'daily prayers': 'الصلوات اليومية',
    'local station': 'المحطة المحلية',
    'this week consistency': 'تناسق هذا الأسبوع',
    'adherence': 'الالتزام',
    'prayer telemetry & alarms': 'قياسات ومنبهات الصلوات',
    'qibla bearing': 'اتجاه القبلة',
    'relative to north': 'بالنسبة للشمال',
    'mecca': 'مكة المكرمة',
    'adhan notifications': 'إشعارات الأذان',
    'daily notification on every prayer window': 'إشعار يومي عند حلول وقت كل صلاة',
    'fajr smart wake-up alarm': 'منبه الفجر الذكي للاستيقاظ',
    'persistent acoustic wake-up alert at dawn': 'تنبيه صوتي مستمر للاستيقاظ لصلاة الفجر',
    'sync gps': 'مزامنة الموقع GPS',
    'daily habits': 'العادات اليومية',
    'all habits': 'كل العادات',
    'general': 'عام',
    'paused': 'متوقفة مؤقتاً',
    'pause habit': 'إيقاف العادة مؤقتاً',
    'activate habit': 'تفعيل العادة',
    'delete habit': 'حذف العادة',
    'edit habit routine': 'تعديل العادة',
    'new habit routine': 'عادة جديدة',
    'update habit': 'تحديث العادة',
    'habit name *': 'اسم العادة *',
    'habit name': 'اسم العادة',
    'color accent': 'درجة اللون',
    'xp reward': 'مكافأة نقاط الخبرة',

    // Projects & Tasks
    'sprint active': 'دورة العمل نشطة',
    'manage deliverables, sprints, and task execution queues': 'إدارة المهام والمشاريع وقوائم التنفيذ',
    'active': 'النشطة',
    'delete project': 'حذف المشروع',
    '+ new project': '+ مشروع جديد',
    'create new project': 'إنشاء مشروع جديد',
    'create project': 'إنشاء المشروع',
    'project color': 'لون المشروع',
    'all projects': 'جميع المشاريع',
    'workspaces': 'مساحات عمل',
    'task queue': 'قائمة المهام',
    'tomorrow': 'غداً',
    'no due date': 'بدون تاريخ استحقاق',
    'finished': 'منتهية',
    'task inspector': 'فاحص المهام',
    'notes & context': 'الملاحظات والسياق',
    'deliverable checklist': 'قائمة المهام الفرعية',
    '+ add subtask': '+ إضافة مهمة فرعية',
    'add subtask checkpoint': 'إضافة مهمة فرعية',
    'mark as incomplete': 'تعيين كغير مكتملة',
    'mark completed': 'تعيين كمكتملة',
    '▶ start focus session': '▶ بدء جلسة تركيز',
    'edit task': 'تعديل المهمة',
    'task name *': 'اسم المهمة *',
    'task name': 'اسم المهمة',
    'create task': 'إنشاء مهمة',
    'select a task to inspect details and checklist': 'اختر مهمة لمعاينة التفاصيل وقائمة المهام الفرعية',
    'no additional notes provided for this deliverable.': 'لا توجد ملاحظات إضافية مسجلة لهذه المهمة.',
    'no checklist items yet. click + add subtask to add checkpoints.': 'لا توجد عناصر بعد. انقر على + إضافة مهمة فرعية لإضافة خطوات.',

    // Command Deck
    'system active • local node': 'النظام نشط • العقدة المحلية',
    'all systems online': 'جميع الأنظمة متصلة',
    'daily tasks': 'المهام اليومية',
    'tasks target': 'الهدف المنجز',
    'best adherence': 'أفضل التزام',
    'focus today': 'التركيز اليوم',
    'deep work sprints': 'جلسات العمل العميق',
    'all done': 'تمت جميعاً',
    'all obligations met': 'تمت جميع الفرائض',
    'today\'s execution stream': 'مسار تنفيذ اليوم',
    'no tasks scheduled for today': 'لا توجد مهام مجدولة لليوم',
    '15 min macro slots': 'الفترات المصغرة 15 د',
    'reschedule': 'إعادة الجدولة',
    'no 15-minute slots scheduled': 'لا توجد فترات 15 دقيقة مجدولة',
    'today\'s tasks with estimates of 15 minutes or less appear here.': 'تظهر هنا مهام اليوم التي يستغرق إنجازها 15 دقيقة أو أقل.',
    'today\'s journal logged': 'تم تسجيل يومية اليوم',
    'daily journal': 'اليوميات اليومية',
    'log more events': 'تسجيل أحداث إضافية',
    'log things that happened in your day': 'دوّن الأحداث التي وقعت خلال يومك',
    'capture timeline milestones, key wins, blockers, and reflections.': 'التقط المحطات الرئيسية، الإنجازات، التحديات، والتأملات الشخصية.',
    'start today\'s journal entry': 'بدء تدوينة يوميات اليوم',
    'prayer telemetry': 'قياسات الصلوات',
    'streaks & habit loops': 'التتابع وحلقات العادات',
    'view ↗': 'عرض ↗',
    'task preview // today\'s stream': 'معاينة المهمة // مسار اليوم',
    'checklist subtasks': 'المهام الفرعية',
    'complete task': 'إكمال المهمة',
    'mark incomplete': 'تعيين كغير مكتملة',
  };

  /// Translates a given English UI label to Arabic if the active locale is Arabic.
  /// If the locale is English or no translation exists, returns the original text.
  /// Safe date formatting with fallback to default locale if locale data is uninitialized in tests.
  String formatDate(DateTime date, String pattern) {
    if (isArabic) {
      try {
        return DateFormat(pattern, 'ar').format(date);
      } catch (_) {}
    }
    return DateFormat(pattern).format(date);
  }

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

/// Convenient BuildContext extension for localization
extension BuildContextL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  bool get isArabic => AppLocalizations.of(this).isArabic;
  String formatDate(DateTime date, String pattern) => l10n.formatDate(date, pattern);
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
