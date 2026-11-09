import 'badge_models.dart';

/// Comprehensive localization metadata for all 50 Mastery Badges across 8 productivity pillars.
class BadgeLocalizationData {
  final String title;
  final String subtitle;
  final Map<int, BadgeTierLocalization> tiers;

  const BadgeLocalizationData({
    required this.title,
    required this.subtitle,
    required this.tiers,
  });
}

class BadgeTierLocalization {
  final String name;
  final String description;
  final String unit;

  const BadgeTierLocalization({
    required this.name,
    required this.description,
    required this.unit,
  });
}

/// Arabic translations registry for all 50 Mastery Badges in AXIS OS.
final Map<String, BadgeLocalizationData> kArabicBadgeCatalog = {
  // ===========================================================================
  // PILLAR 1: EXECUTION & VELOCITY (10 Badges)
  // ===========================================================================
  'first_spark': const BadgeLocalizationData(
    title: 'الخطوات الأولى',
    subtitle: 'انطلاقة مسيرة الإنتاجية',
    tiers: {
      1: BadgeTierLocalization(name: 'الضربة الأولى', unit: 'مهمة', description: 'أكمل مهمتك الأولى في النظام.'),
      2: BadgeTierLocalization(name: 'الإحماء', unit: 'مهام', description: 'أكمل 5 مهام وثبّت انطلاقتك.'),
      3: BadgeTierLocalization(name: 'ضبط الإيقاع', unit: 'مهام', description: 'أكمل 10 مهام بتنفيذ ثابت.'),
      4: BadgeTierLocalization(name: 'مشغل نشط', unit: 'مهام', description: 'أكمل 25 مهمة عبر مشاريعك.'),
    },
  ),
  'task_closer': const BadgeLocalizationData(
    title: 'المنجز الحاسم',
    subtitle: 'أنهِ ما بدأت',
    tiers: {
      1: BadgeTierLocalization(name: 'حاسم I', unit: 'مهام', description: 'أنجز 10 مهام مكتملة.'),
      2: BadgeTierLocalization(name: 'حاسم II', unit: 'مهام', description: 'أفرغ 50 مهمة من قائمة الانتظار.'),
      3: BadgeTierLocalization(name: 'حاسم III', unit: 'مهام', description: 'نفّذ 150 مهمة بحسم قاطع.'),
      4: BadgeTierLocalization(name: 'حاسم نخبوي', unit: 'مهام', description: 'تغلب على 300 مهمة مكتملة.'),
    },
  ),
  'task_centurion': const BadgeLocalizationData(
    title: 'المئوي',
    subtitle: 'حاجز الأرقام الثلاثية',
    tiers: {
      1: BadgeTierLocalization(name: 'مبتدئ القرن', unit: 'مهام', description: 'منتصف الطريق إلى أول مئة مهمة.'),
      2: BadgeTierLocalization(name: 'حارس القرن', unit: 'مهام', description: 'افتح علامة الـ 100 مهمة التاريخية.'),
      3: BadgeTierLocalization(name: 'مئوي مضاعف', unit: 'مهام', description: 'تجاوز 200 بند مكتمل.'),
      4: BadgeTierLocalization(name: 'الخمسمائة', unit: 'مهام', description: 'تجاوز 500 مهمة. إنجاز أسطوري.'),
    },
  ),
  'apex_executioner': const BadgeLocalizationData(
    title: 'ساحق القمم',
    subtitle: 'إنتاجية تنفيذ لا هوادة فيها',
    tiers: {
      1: BadgeTierLocalization(name: 'قوة الدفع', unit: 'مهام', description: 'حافظ على زخم قوي في إنجاز المهام.'),
      2: BadgeTierLocalization(name: 'قوة طبيعية', unit: 'مهام', description: 'تغلّب على 350 مهمة بتركيز منضبط.'),
      3: BadgeTierLocalization(name: 'منفذ عملاق', unit: 'مهام', description: 'اسحق 750 مهمة عبر كافة المجالات.'),
      4: BadgeTierLocalization(name: 'سيد القمة', unit: 'مهام', description: '1,500 مهمة تم فتحها. قمة الإنجاز المطلق.'),
    },
  ),
  'high_priority': const BadgeLocalizationData(
    title: 'المواقف الحاسمة',
    subtitle: 'مواجهة الأهداف الحرجة',
    tiers: {
      1: BadgeTierLocalization(name: 'قلب شجاع', unit: 'مهام عاجلة', description: 'أنجز 3 مهام عاجلة ذات أولوية قصوى.'),
      2: BadgeTierLocalization(name: 'منقذ الطليعة', unit: 'مهام عاجلة', description: 'حل 15 مهمة عاجلة حرجة دون تردد.'),
      3: BadgeTierLocalization(name: 'قائد الأزمات', unit: 'مهام عاجلة', description: 'أبطل مفعول 50 مهمة طارئة تحت الضغط.'),
      4: BadgeTierLocalization(name: 'تكتيكي القمة', unit: 'مهام عاجلة', description: '120 بنداً حرجاً نُفّذت بدقة متناهية.'),
    },
  ),
  'deep_firefight': const BadgeLocalizationData(
    title: 'نخبة الاشتباك',
    subtitle: 'إتقان إدارة الأولويات الثقيلة',
    tiers: {
      1: BadgeTierLocalization(name: 'مختبر بالضغط', unit: 'مهام عاجلة', description: 'واجه 5 مهام حرجة دون تأخير.'),
      2: BadgeTierLocalization(name: 'درع صلب', unit: 'مهام عاجلة', description: 'أكمل 25 مهمة مصيرية عالية الأهمية.'),
      3: BadgeTierLocalization(name: 'مشغل خبير', unit: 'مهام عاجلة', description: 'أكمل 75 محطة ذات أولوية كبرى.'),
      4: BadgeTierLocalization(name: 'لا يُقهر', unit: 'مهام عاجلة', description: '200 مهمة عالية الأولوية. لا يمكن إيقافك.'),
    },
  ),
  'precision_planner': const BadgeLocalizationData(
    title: 'مقدّر الأوقات',
    subtitle: 'معايرة ميزانيات الوقت',
    tiers: {
      1: BadgeTierLocalization(name: 'مقدّر دقيق', unit: 'مهام مقدرة', description: 'خصص تقديراً زمنياً لخمس مهام.'),
      2: BadgeTierLocalization(name: 'حساب زمني', unit: 'مهام مقدرة', description: 'قدّر أوقات 20 مهمة.'),
      3: BadgeTierLocalization(name: 'معاير زمني', unit: 'مهام مقدرة', description: 'أدر ميزانيات الوقت لـ 50 مهمة.'),
      4: BadgeTierLocalization(name: 'مخطط محترف', unit: 'مهام مقدرة', description: '100 مهمة تم تقديرها بدقة عالية.'),
    },
  ),
  'rhythm_keeper': const BadgeLocalizationData(
    title: 'ضابط الإيقاع',
    subtitle: 'استمرار المهام المتكررة',
    tiers: {
      1: BadgeTierLocalization(name: 'دوري I', unit: 'مهام دورية', description: 'أكمل 3 مهام دورية متكررة.'),
      2: BadgeTierLocalization(name: 'دوري II', unit: 'مهام دورية', description: 'حافظ على 15 تكراراً للمهام.'),
      3: BadgeTierLocalization(name: 'إيقاعي', unit: 'مهام دورية', description: 'أكمل 40 تكراراً دورياً.'),
      4: BadgeTierLocalization(name: 'نبض مستمر', unit: 'مهام دورية', description: '100 تكرار دوري منتظم.'),
    },
  ),
  'deadline_hunter': const BadgeLocalizationData(
    title: 'صياد المواعيد',
    subtitle: 'الوفاء بمواعيد الاستحقاق',
    tiers: {
      1: BadgeTierLocalization(name: 'في الموعد', unit: 'مهام مجدولة', description: 'أنجز 5 مهام مجدولة بمواعيدها.'),
      2: BadgeTierLocalization(name: 'دقيق كالساعة', unit: 'مهام مجدولة', description: 'أكمل 20 مهمة قبل انتهاء موعدها.'),
      3: BadgeTierLocalization(name: 'منضبط زمنياً', unit: 'مهام مجدولة', description: 'التزم بإنهاء 60 مهمة محددة الموعد.'),
      4: BadgeTierLocalization(name: 'حاكم الزمن', unit: 'مهام مجدولة', description: '150 مهمة أُنجزت في موعدها تماماً.'),
    },
  ),
  'horizon_clearer': const BadgeLocalizationData(
    title: 'مجلّي الأفق',
    subtitle: 'تنظيف وتصفية المهام',
    tiers: {
      1: BadgeTierLocalization(name: 'تصفية I', unit: 'مهام مجدولة', description: 'أكمل 10 مهام مجدولة.'),
      2: BadgeTierLocalization(name: 'تصفية II', unit: 'مهام مجدولة', description: 'أنهِ 35 مهمة قادمة.'),
      3: BadgeTierLocalization(name: 'تصفية III', unit: 'مهام مجدولة', description: 'أنجز 90 مهمة من الأفق المستقبلي.'),
      4: BadgeTierLocalization(name: 'سماء صافية', unit: 'مهام مجدولة', description: '200 مهمة مجدولة تم إنجازها بنجاح.'),
    },
  ),

  // ===========================================================================
  // PILLAR 2: DEEP WORK & FOCUS (8 Badges)
  // ===========================================================================
  'focus_initiate': const BadgeLocalizationData(
    title: 'مبتدئ التركيز',
    subtitle: 'بداية جلسات العمل العميق',
    tiers: {
      1: BadgeTierLocalization(name: 'أول تركيز', unit: 'دقائق', description: 'أكمل 15 دقيقة من العمل المركز.'),
      2: BadgeTierLocalization(name: 'تركيز أعمق', unit: 'دقائق', description: 'سجل 60 دقيقة من التركيز الخالص.'),
      3: BadgeTierLocalization(name: 'توسع الانتباه', unit: 'دقائق', description: 'اقضِ 180 دقيقة في جلسات التركيز.'),
      4: BadgeTierLocalization(name: 'منطقة التدفق', unit: 'دقائق', description: 'تجاوز 300 دقيقة من العمل المركز.'),
    },
  ),
  'deep_diver': const BadgeLocalizationData(
    title: 'الغواص العميق',
    subtitle: 'ساعات تركيز ممتدة',
    tiers: {
      1: BadgeTierLocalization(name: 'غوص I', unit: 'دقائق', description: 'سجل 120 دقيقة عمل عميق.'),
      2: BadgeTierLocalization(name: 'غوص II', unit: 'دقائق', description: 'حقق 360 دقيقة من التركيز المتواصل.'),
      3: BadgeTierLocalization(name: 'أعماق التدفق', unit: 'دقائق', description: 'سجل 900 دقيقة من التركيز الخالص.'),
      4: BadgeTierLocalization(name: 'الهاوية الزرقاء', unit: 'دقائق', description: '2,000 دقيقة تركيز. غوص عميق حقيقي.'),
    },
  ),
  'zen_monk': const BadgeLocalizationData(
    title: 'راهب الزن',
    subtitle: 'سيادة تامة على الانتباه',
    tiers: {
      1: BadgeTierLocalization(name: 'سكون', unit: 'دقائق', description: 'اجمع 300 دقيقة من هدوء الزن.'),
      2: BadgeTierLocalization(name: 'تأمل العمل', unit: 'دقائق', description: 'سجل 1,000 دقيقة من صفاء الذهن.'),
      3: BadgeTierLocalization(name: 'حضور مطلق', unit: 'دقائق', description: 'حقق 2,500 دقيقة من العمل الصامت.'),
      4: BadgeTierLocalization(name: 'تنوير إنتاجي', unit: 'دقائق', description: '5,000 دقيقة تركيز. صفاء ذهني لا يتزعزع.'),
    },
  ),
  'chronomancer': const BadgeLocalizationData(
    title: 'حاكم الساعات',
    subtitle: 'مئات الساعات من الإنجاز',
    tiers: {
      1: BadgeTierLocalization(name: 'سيد الساعات I', unit: 'دقائق', description: 'اقضِ 600 دقيقة (10 ساعات) تركيز.'),
      2: BadgeTierLocalization(name: 'سيد الساعات II', unit: 'دقائق', description: 'اقضِ 1,800 دقيقة (30 ساعة) تركيز.'),
      3: BadgeTierLocalization(name: 'نسيج الزمن', unit: 'دقائق', description: 'اقضِ 4,500 دقيقة (75 ساعة) تركيز.'),
      4: BadgeTierLocalization(name: 'حاكم الأزل', unit: 'دقائق', description: '10,000 دقيقة (166 ساعة) تركيز عميق.'),
    },
  ),
  'flow_seeker': const BadgeLocalizationData(
    title: 'باحث التدفق',
    subtitle: 'تراكم الجلسات المركزة',
    tiers: {
      1: BadgeTierLocalization(name: 'جلسة I', unit: 'جلسات', description: 'أكمل 3 جلسات تركيز فردية.'),
      2: BadgeTierLocalization(name: 'جلسة II', unit: 'جلسات', description: 'أكمل 10 جلسات تركيز مخصصة.'),
      3: BadgeTierLocalization(name: 'جلسة III', unit: 'جلسات', description: 'أتمم 25 جلسة عمل عميق.'),
      4: BadgeTierLocalization(name: 'خبير الجلسات', unit: 'جلسات', description: 'أتمم 60 جلسة تركيز مسجلة.'),
    },
  ),
  'session_veteran': const BadgeLocalizationData(
    title: 'مخضرم الجلسات',
    subtitle: 'أحجام جلسات العمل القياسية',
    tiers: {
      1: BadgeTierLocalization(name: 'مخضرم I', unit: 'جلسات', description: 'أنجز 15 جلسة تركيز متقنة.'),
      2: BadgeTierLocalization(name: 'مخضرم II', unit: 'جلسات', description: 'أنجز 40 جلسة تركيز متقنة.'),
      3: BadgeTierLocalization(name: 'مخضرم III', unit: 'جلسات', description: 'أنجز 100 جلسة تركيز متقنة.'),
      4: BadgeTierLocalization(name: 'أسطورة التركيز', unit: 'جلسات', description: '250 جلسة عمل عميق مكتملة.'),
    },
  ),
  'pomodoro_artisan': const BadgeLocalizationData(
    title: 'فنان البومودورو',
    subtitle: 'إتقان دورات المؤقت الكلاسيكية',
    tiers: {
      1: BadgeTierLocalization(name: 'حبة أولى', unit: 'دورات بومودورو', description: 'أنهِ أول دورتين بومودورو.'),
      2: BadgeTierLocalization(name: 'طاهي بومودورو', unit: 'دورات بومودورو', description: 'أنهِ 8 دورات بومودورو.'),
      3: BadgeTierLocalization(name: 'حرفي متمرس', unit: 'دورات بومودورو', description: 'أنهِ 20 دورة بومودورو.'),
      4: BadgeTierLocalization(name: 'أستاذ البومودورو', unit: 'دورات بومودورو', description: '50 دورة بومودورو مع استراحات منضبطة.'),
    },
  ),
  'ultra_marathoner': const BadgeLocalizationData(
    title: 'عداء الماراثون',
    subtitle: 'جلسات عمل عميق فائقة الطول',
    tiers: {
      1: BadgeTierLocalization(name: 'ماراثون I', unit: 'جلسات ماراثون', description: 'أكمل جلسة تركيز واحدة لأكثر من 60 دقيقة.'),
      2: BadgeTierLocalization(name: 'ماراثون II', unit: 'جلسات ماراثون', description: 'أكمل 3 جلسات ماراثون طويلة.'),
      3: BadgeTierLocalization(name: 'ماراثون III', unit: 'جلسات ماراثون', description: 'أكمل 8 جلسات عمل ماراثونية.'),
      4: BadgeTierLocalization(name: 'عداء لا نهائي', unit: 'جلسات ماراثون', description: '20 جلسة عمل عميق طويلة مكتملة.'),
    },
  ),
  'hyperflow_monk': const BadgeLocalizationData(
    title: 'تدفق خارق',
    subtitle: 'انغماس تام وتجاوز للحدود',
    tiers: {
      1: BadgeTierLocalization(name: 'شرارة تدفق', unit: 'دقائق', description: '180 دقيقة تركيز تام.'),
      2: BadgeTierLocalization(name: 'موجة تدفق', unit: 'دقائق', description: '500 دقيقة تركيز خارق.'),
      3: BadgeTierLocalization(name: 'إعصار تدفق', unit: 'دقائق', description: '1,200 دقيقة في حالة التدفق.'),
      4: BadgeTierLocalization(name: 'سيد التدفق', unit: 'دقائق', description: '3,000 دقيقة في أعلى حالات التركيز.'),
    },
  ),

  // ===========================================================================
  // PILLAR 3: STREAKS & MOMENTUM (7 Badges)
  // ===========================================================================
  'streak_spark': const BadgeLocalizationData(
    title: 'شرارة التتابع',
    subtitle: 'إشعال الأيام المتتالية الأولى',
    tiers: {
      1: BadgeTierLocalization(name: 'اليوم الأول', unit: 'أيام', description: 'ابدأ تتابعك اليومي الأول.'),
      2: BadgeTierLocalization(name: '3 أيام متتالية', unit: 'أيام', description: 'حافظ على 3 أيام من الاستمرارية.'),
      3: BadgeTierLocalization(name: 'أسبوع كامل', unit: 'أيام', description: '7 أيام متتالية دون انقطاع.'),
      4: BadgeTierLocalization(name: 'أسبوعان', unit: 'أيام', description: '14 يوماً من الحضور اليومي المتواصل.'),
    },
  ),
  'streak_vanguard': const BadgeLocalizationData(
    title: 'طليعة الاستمرار',
    subtitle: 'بناء سلسلة متماسكة',
    tiers: {
      1: BadgeTierLocalization(name: 'أسبوع متين', unit: 'أيام', description: '7 أيام استمرارية قوية.'),
      2: BadgeTierLocalization(name: 'نصف شهر', unit: 'أيام', description: '14 يوماً من العطاء المستمر.'),
      3: BadgeTierLocalization(name: '3 أسابيع', unit: 'أيام', description: '21 يوماً ترسخ عاداتك اليومية.'),
      4: BadgeTierLocalization(name: 'شهر كامل', unit: 'أيام', description: '30 يوماً من الالتزام الثابت.'),
    },
  ),
  'streak_titan': const BadgeLocalizationData(
    title: 'عملاق التتابع',
    subtitle: 'ثبات يمتد لشهور',
    tiers: {
      1: BadgeTierLocalization(name: 'شهر ذهبي', unit: 'أيام', description: 'أكمل 30 يوماً متتالياً.'),
      2: BadgeTierLocalization(name: 'شهران', unit: 'أيام', description: 'حافظ على 60 يوماً من الإنجاز اليومي.'),
      3: BadgeTierLocalization(name: 'ربع سنة', unit: 'أيام', description: '90 يوماً متتالياً من الانضباط.'),
      4: BadgeTierLocalization(name: 'عملاق راسخ', unit: 'أيام', description: '120 يوماً متتالياً. ثبات أسطوري.'),
    },
  ),
  'streak_century': const BadgeLocalizationData(
    title: 'مئوية التتابع',
    subtitle: 'بلوغ علامة 100 يوم',
    tiers: {
      1: BadgeTierLocalization(name: 'نصف مئوية', unit: 'أيام', description: '50 يوماً متتالياً من الحضور.'),
      2: BadgeTierLocalization(name: 'حاجز المئة', unit: 'أيام', description: '100 يوم متواصل. إنجاز تاريخي.'),
      3: BadgeTierLocalization(name: '150 يوماً', unit: 'أيام', description: '150 يوماً من العمل الدؤوب.'),
      4: BadgeTierLocalization(name: 'مئتان متصلة', unit: 'أيام', description: '200 يوم متتابع. التزام نادر.'),
    },
  ),
  'streak_unbreakable': const BadgeLocalizationData(
    title: 'سلسلة لا تنكسر',
    subtitle: 'نصف عام من الانضباط الخالص',
    tiers: {
      1: BadgeTierLocalization(name: 'صلابة', unit: 'أيام', description: '75 يوماً متتالياً دون توقف.'),
      2: BadgeTierLocalization(name: 'فولاذ', unit: 'أيام', description: '120 يوماً من الاستمرار المتقن.'),
      3: BadgeTierLocalization(name: 'نصف عام', unit: 'أيام', description: '180 يوماً متتالياً. نصف عام من الثبات.'),
      4: BadgeTierLocalization(name: 'منيع', unit: 'أيام', description: '250 يوماً متواصلاً.'),
    },
  ),
  'streak_immortal': const BadgeLocalizationData(
    title: 'تتابع خالد',
    subtitle: 'عام كامل من الإنجاز اليومي',
    tiers: {
      1: BadgeTierLocalization(name: '100 يوم فخر', unit: 'أيام', description: '100 يوم من الاستقامة.'),
      2: BadgeTierLocalization(name: '200 يوم عزم', unit: 'أيام', description: '200 يوم من الإصرار.'),
      3: BadgeTierLocalization(name: '300 يوم همة', unit: 'أيام', description: '300 يوم متتالي.'),
      4: BadgeTierLocalization(name: 'تاج العام', unit: 'أيام', description: '365 يوماً كاملاً. عام من الانضباط الخالد.'),
    },
  ),
  'streak_resilience': const BadgeLocalizationData(
    title: 'مرونة العودة',
    subtitle: 'استعادة السلسلة بعد العثرات',
    tiers: {
      1: BadgeTierLocalization(name: 'بداية ثانية', unit: 'أيام', description: 'حقق تتابع 5 أيام من جديد.'),
      2: BadgeTierLocalization(name: 'وثبة مرونة', unit: 'أيام', description: 'حقق تتابع 14 يوماً بعد التوقف.'),
      3: BadgeTierLocalization(name: 'صلابة العودة', unit: 'أيام', description: 'تجاوز 30 يوماً بعد انقطاع سابق.'),
      4: BadgeTierLocalization(name: 'روح لا تنكسر', unit: 'أيام', description: '60 يوماً من التتابع المستعاد.'),
    },
  ),
  'perpetual_motion': const BadgeLocalizationData(
    title: 'حركة دائمة',
    subtitle: 'زخم عمل مستمر لا يتوقف',
    tiers: {
      1: BadgeTierLocalization(name: 'دوران I', unit: 'أيام', description: '10 أيام من النشاط الحركي اليومي.'),
      2: BadgeTierLocalization(name: 'دوران II', unit: 'أيام', description: '25 يوماً من الزخم المستمر.'),
      3: BadgeTierLocalization(name: 'طاقة كامنة', unit: 'أيام', description: '60 يوماً في مدار الحركة.'),
      4: BadgeTierLocalization(name: 'محرك دائم', unit: 'أيام', description: '100 يوم من الزخم المتصل.'),
    },
  ),

  // ===========================================================================
  // PILLAR 4: HABITS & DISCIPLINE (8 Badges)
  // ===========================================================================
  'habit_spark': const BadgeLocalizationData(
    title: 'زارع العادات',
    subtitle: 'ازرع بذورك اليومية',
    tiers: {
      1: BadgeTierLocalization(name: 'أول تسجيل', unit: 'تسجيلات', description: 'سجل إنجاز أول 3 عادات.'),
      2: BadgeTierLocalization(name: 'برعم', unit: 'تسجيلات', description: 'سجل 15 عادة منجزة.'),
      3: BadgeTierLocalization(name: 'شتلة', unit: 'تسجيلات', description: 'سجل إنجاز 40 عادة.'),
      4: BadgeTierLocalization(name: 'إزهار', unit: 'تسجيلات', description: 'تجاوز 100 تسجيل عادات مكتملة.'),
    },
  ),
  'iron_discipline': const BadgeLocalizationData(
    title: 'انضباط حديدي',
    subtitle: 'اصنع عادات راسخة',
    tiers: {
      1: BadgeTierLocalization(name: 'شرارة حديدية', unit: 'تسجيلات', description: 'أكمل 25 تسجيل عادات.'),
      2: BadgeTierLocalization(name: 'مسبك حديدي', unit: 'تسجيلات', description: 'حقق 75 تكرار عادة ناجح.'),
      3: BadgeTierLocalization(name: 'إرادة حديدية', unit: 'تسجيلات', description: 'سجل 200 إنجاز عادة.'),
      4: BadgeTierLocalization(name: 'أسطورة حديدية', unit: 'تسجيلات', description: '500 إنجاز عادة. انضباط حديدي مطلق.'),
    },
  ),
  'routine_centurion': const BadgeLocalizationData(
    title: 'مئوي الروتين',
    subtitle: 'أحجام عادات بأرقام ثلاثية',
    tiers: {
      1: BadgeTierLocalization(name: 'مئوي I', unit: 'تسجيلات', description: 'بلغ 100 تكرار عادة مكتمل.'),
      2: BadgeTierLocalization(name: 'مئوي II', unit: 'تسجيلات', description: 'صل إلى 250 تسجيل عادة.'),
      3: BadgeTierLocalization(name: 'مئوي III', unit: 'تسجيلات', description: 'تجاوز 600 تسجيل عادة.'),
      4: BadgeTierLocalization(name: 'ألفية الروتين', unit: 'تسجيلات', description: '1,000 تسجيل عادة. سيادة الروتين.'),
    },
  ),
  'master_of_routine': const BadgeLocalizationData(
    title: 'سيد الروتين',
    subtitle: 'تحويل العادة إلى غريزة',
    tiers: {
      1: BadgeTierLocalization(name: 'غريزة I', unit: 'تسجيلات', description: '150 عادة: الأفعال تصبح طبيعة ثانية.'),
      2: BadgeTierLocalization(name: 'غريزة II', unit: 'تسجيلات', description: '400 عادة: عاداتك تعمل تلقائياً.'),
      3: BadgeTierLocalization(name: 'غريزة III', unit: 'تسجيلات', description: '800 عادة: نمط حياة منضبط تماماً.'),
      4: BadgeTierLocalization(name: 'أستاذ أعظم', unit: 'تسجيلات', description: '2,000 تكرار عادة مكتمل. لا مثيل لك.'),
    },
  ),
  'habit_architect': const BadgeLocalizationData(
    title: 'مهندس العادات',
    subtitle: 'تصميم روتين مخصص',
    tiers: {
      1: BadgeTierLocalization(name: 'بنّاء I', unit: 'عادات', description: 'صمم أول عادتين مخصصتين.'),
      2: BadgeTierLocalization(name: 'بنّاء II', unit: 'عادات', description: 'ابنِ 5 عادات مخصصة نشطة.'),
      3: BadgeTierLocalization(name: 'بنّاء III', unit: 'عادات', description: 'نسق منظومة روتين من 10 عادات.'),
      4: BadgeTierLocalization(name: 'كبير المهندسين', unit: 'عادات', description: '20 عادة مخصصة مهندسة بعناية.'),
    },
  ),
  'domain_master': const BadgeLocalizationData(
    title: 'سيد التصنيفات',
    subtitle: 'تنظيم العادات في مجالات',
    tiers: {
      1: BadgeTierLocalization(name: 'مصنّف', unit: 'تصنيف', description: 'أنشئ أول تصنيف عادات مخصص.'),
      2: BadgeTierLocalization(name: 'منسق المجالات', unit: 'تصنيفات', description: 'نظم عاداتك في 3 مجالات حياة.'),
      3: BadgeTierLocalization(name: 'قيّم المجالات', unit: 'تصنيفات', description: 'ابنِ 6 تصنيفات مخصصة للروتين.'),
      4: BadgeTierLocalization(name: 'سيد المجالات', unit: 'تصنيفات', description: '12 تصنيف عادات مخصص متقن.'),
    },
  ),
  'daily_ritualist': const BadgeLocalizationData(
    title: 'الطقس اليومي',
    subtitle: 'ترسيخ طقسك الأساسي',
    tiers: {
      1: BadgeTierLocalization(name: 'طقسي I', unit: 'تسجيلات', description: 'سجل 10 تسجيلات للطقس اليومي.'),
      2: BadgeTierLocalization(name: 'طقسي II', unit: 'تسجيلات', description: '50 تسجيلاً للطقوس اليومية.'),
      3: BadgeTierLocalization(name: 'طقسي III', unit: 'تسجيلات', description: '150 إنجازاً للطقس المسائي أو الصباحي.'),
      4: BadgeTierLocalization(name: 'سادن الالتزام', unit: 'تسجيلات', description: '350 تسجيلاً. التزام مقدس لا يتزحزح.'),
    },
  ),
  'unshakeable_will': const BadgeLocalizationData(
    title: 'إرادة ألمازية',
    subtitle: 'مقاومة كافة المشتتات',
    tiers: {
      1: BadgeTierLocalization(name: 'مرن صامد', unit: 'تسجيلات', description: '30 تسجيلاً تظهر إرادة متماسكة.'),
      2: BadgeTierLocalization(name: 'راسخ', unit: 'تسجيلات', description: '120 تسجيلاً لعاداتك اليومية.'),
      3: BadgeTierLocalization(name: 'ثابت الجنان', unit: 'تسجيلات', description: '300 إنجاز عادة متحققة.'),
      4: BadgeTierLocalization(name: 'عقل ألمازي', unit: 'تسجيلات', description: '700 عادة منجزة. إرادة ذهنية صلبة كالألماس.'),
    },
  ),

  // ===========================================================================
  // PILLAR 5: KNOWLEDGE & WISDOM (5 Badges)
  // ===========================================================================
  'note_scribe': const BadgeLocalizationData(
    title: 'كاتب الملاحظات',
    subtitle: 'تدوين الأفكار والتأملات',
    tiers: {
      1: BadgeTierLocalization(name: 'موثّق', unit: 'ملاحظات', description: 'دوّن أول 3 ملاحظات لك.'),
      2: BadgeTierLocalization(name: 'ناسخ', unit: 'ملاحظات', description: 'سجل 10 أفكار ومذكرات في خزينتك.'),
      3: BadgeTierLocalization(name: 'مؤرخ', unit: 'ملاحظات', description: 'ابنِ مكتبة من 25 ملاحظة محفوظة.'),
      4: BadgeTierLocalization(name: 'مؤلف', unit: 'ملاحظات', description: 'وثّق 60 خاطرة وملاحظة دراسية.'),
    },
  ),
  'grand_archivist': const BadgeLocalizationData(
    title: 'كبير الأرشيفيين',
    subtitle: 'جمع وتنسيق الحكمة',
    tiers: {
      1: BadgeTierLocalization(name: 'أرشيفي I', unit: 'ملاحظات', description: 'أرشف 15 ملاحظة منظمة.'),
      2: BadgeTierLocalization(name: 'أرشيفي II', unit: 'ملاحظات', description: 'احفظ 50 فكرة في خزينة المعرفة.'),
      3: BadgeTierLocalization(name: 'أرشيفي III', unit: 'ملاحظات', description: '120 ملاحظة مفهرسة ومبوبة.'),
      4: BadgeTierLocalization(name: 'عالم المعرفة', unit: 'ملاحظات', description: '250 ملاحظة محفوظة للأجيال القادمة.'),
    },
  ),
  'second_brain': const BadgeLocalizationData(
    title: 'العقل الثاني',
    subtitle: 'تفريغ الذاكرة الذهنية خارجياً',
    tiers: {
      1: BadgeTierLocalization(name: 'قشرة دماغية I', unit: 'ملاحظات', description: 'ابنِ قشرة ذاكرتك الخارجية (20 ملاحظة).'),
      2: BadgeTierLocalization(name: 'قشرة دماغية II', unit: 'ملاحظات', description: 'وسّع عقلك الثاني بـ 70 ملاحظة.'),
      3: BadgeTierLocalization(name: 'تشابك عصبي', unit: 'ملاحظات', description: 'اربط بين 180 فكرة وعنصر معرفي.'),
      4: BadgeTierLocalization(name: 'عقل فائق', unit: 'ملاحظات', description: '400 ملاحظة موثقة. عقل ثانٍ حقيقي.'),
    },
  ),
  'pinned_vault': const BadgeLocalizationData(
    title: 'حارس الخزينة',
    subtitle: 'تثبيت المراجع الجوهرية',
    tiers: {
      1: BadgeTierLocalization(name: 'تثبيت I', unit: 'ملاحظات مثبتة', description: 'ثبّت ملاحظتك الأساسية الأولى بالأعلى.'),
      2: BadgeTierLocalization(name: 'تثبيت II', unit: 'ملاحظات مثبتة', description: 'ثبّت 3 ملاحظات فائقة الأهمية.'),
      3: BadgeTierLocalization(name: 'تثبيت III', unit: 'ملاحظات مثبتة', description: 'حافظ على 7 مراجع رئيسية مثبتة.'),
      4: BadgeTierLocalization(name: 'الخزينة الكبرى', unit: 'ملاحظات مثبتة', description: 'نسّق 15 وثيقة مرجعية عليا مثبتة.'),
    },
  ),
  'encyclopedist': const BadgeLocalizationData(
    title: 'الموسوعي',
    subtitle: 'مستودع المعرفة الشامل',
    tiers: {
      1: BadgeTierLocalization(name: 'مجلد I', unit: 'ملاحظات', description: 'اجمع 30 ملاحظة مرجعية.'),
      2: BadgeTierLocalization(name: 'مجلد II', unit: 'ملاحظات', description: 'اجمع 100 ملاحظة مرجعية.'),
      3: BadgeTierLocalization(name: 'مجلد III', unit: 'ملاحظات', description: 'اجمع 250 ملاحظة مرجعية.'),
      4: BadgeTierLocalization(name: 'المخطوط الأعظم', unit: 'ملاحظات', description: '600 ملاحظة. موسوعة شخصية متكاملة.'),
    },
  ),

  // ===========================================================================
  // PILLAR 6: ORGANIZATION & SYSTEMS (4 Badges)
  // ===========================================================================
  'project_founder': const BadgeLocalizationData(
    title: 'مؤسس المشاريع',
    subtitle: 'هيكلة النتائج والمخرجات',
    tiers: {
      1: BadgeTierLocalization(name: 'مبادر', unit: 'مشروع', description: 'أنشئ أول مشروع مخصص لك.'),
      2: BadgeTierLocalization(name: 'منظم', unit: 'مشاريع', description: 'هيكل 3 مساحات مشاريع متباينة.'),
      3: BadgeTierLocalization(name: 'قائد مسار', unit: 'مشاريع', description: 'أدر 7 مسارات مشاريع نشطة.'),
      4: BadgeTierLocalization(name: 'سيد المحافظ', unit: 'مشاريع', description: 'أنشئ 15 مشروعاً منظماً ومحكماً.'),
    },
  ),
  'portfolio_director': const BadgeLocalizationData(
    title: 'مدير الأنظمة',
    subtitle: 'إدارة الأعمال متعددة المشاريع',
    tiers: {
      1: BadgeTierLocalization(name: 'فرع I', unit: 'مشاريع', description: 'أسس فرعين لمشاريعك.'),
      2: BadgeTierLocalization(name: 'فرع II', unit: 'مشاريع', description: 'أدر 5 مساحات عمل للمشاريع.'),
      3: BadgeTierLocalization(name: 'مؤسسي', unit: 'مشاريع', description: 'نسق 10 مساحات مشاريع مهيكلة.'),
      4: BadgeTierLocalization(name: 'صاحب رؤية', unit: 'مشاريع', description: 'أدر 25 مجال مشروع منظم بدقة.'),
    },
  ),
  'tag_virtuoso': const BadgeLocalizationData(
    title: 'فنان الوسوم',
    subtitle: 'تصنيف دقيق ومتقن',
    tiers: {
      1: BadgeTierLocalization(name: 'مميّز', unit: 'وسوم', description: 'أنشئ أول وسمين مخصصين للمهام.'),
      2: BadgeTierLocalization(name: 'مبوّب', unit: 'وسوم', description: 'صمم 5 وسوم مخصصة للتصنيف.'),
      3: BadgeTierLocalization(name: 'مفهرس', unit: 'وسوم', description: 'فهرس بنودك بـ 12 وسماً مميزاً.'),
      4: BadgeTierLocalization(name: 'سيد الفرز', unit: 'وسوم', description: '25 وسماً مخصصاً للفرز المرن السريع.'),
    },
  ),
  'taxonomy_architect': const BadgeLocalizationData(
    title: 'معماري التصنيف',
    subtitle: 'فرز متقدم للبيانات الوصفية',
    tiers: {
      1: BadgeTierLocalization(name: 'مخطط I', unit: 'وسوم', description: 'انشر 3 وسوم مهيكلة.'),
      2: BadgeTierLocalization(name: 'مخطط II', unit: 'وسوم', description: 'ابنِ نظام فهرسة من 8 وسوم.'),
      3: BadgeTierLocalization(name: 'مخطط III', unit: 'وسوم', description: 'انشر 18 وسماً عبر بيئة عملك.'),
      4: BadgeTierLocalization(name: 'ملك التصنيف', unit: 'وسوم', description: '40 وسماً مخصصاً مصممة بدقة متناهية.'),
    },
  ),

  // ===========================================================================
  // PILLAR 7: KINETIC EVOLUTION & LEVEL (4 Badges)
  // ===========================================================================
  'kinetic_awakened': const BadgeLocalizationData(
    title: 'يقظة الطاقة',
    subtitle: 'المراحل الأولى لترقية المشغل',
    tiers: {
      1: BadgeTierLocalization(name: 'مستيقظ', unit: 'المستوى', description: 'ارتقِ إلى المستوى 2 في نظام AXIS.'),
      2: BadgeTierLocalization(name: 'متناغم', unit: 'المستوى', description: 'ابلغ المستوى 3 بنقاط الخبرة المكتسبة.'),
      3: BadgeTierLocalization(name: 'مشحون', unit: 'المستوى', description: 'ابلغ المستوى 4 عبر الإنتاجية المستمرة.'),
      4: BadgeTierLocalization(name: 'متمكن', unit: 'المستوى', description: 'ارتقِ للمستوى 5. مشغل نظام متكامل.'),
    },
  ),
  'system_operative': const BadgeLocalizationData(
    title: 'مشغل النظام',
    subtitle: 'رتبة الطاقة المتوسطة',
    tiers: {
      1: BadgeTierLocalization(name: 'أخصائي', unit: 'المستوى', description: 'ارتقِ إلى المستوى 6.'),
      2: BadgeTierLocalization(name: 'متمرس', unit: 'المستوى', description: 'ابلغ المستوى 9 بكفاءة مثبتة.'),
      3: BadgeTierLocalization(name: 'قائد', unit: 'المستوى', description: 'ابلغ المستوى 12 عبر التنفيذ الشامل.'),
      4: BadgeTierLocalization(name: 'مخضرم', unit: 'المستوى', description: 'ابلغ المستوى 15 في المنظومة.'),
    },
  ),
  'quantum_ascendant': const BadgeLocalizationData(
    title: 'الصاعد الكمومي',
    subtitle: 'رتب الشرف والمكانة الرفيعة',
    tiers: {
      1: BadgeTierLocalization(name: 'صاعد I', unit: 'المستوى', description: 'ارتقِ إلى مستوى الشرف 18.'),
      2: BadgeTierLocalization(name: 'صاعد II', unit: 'المستوى', description: 'ارتقِ إلى المستوى 22.'),
      3: BadgeTierLocalization(name: 'متسامٍ', unit: 'المستوى', description: 'ابلغ المستوى 26. مشغل أسطوري.'),
      4: BadgeTierLocalization(name: 'أستاذ أعظم', unit: 'المستوى', description: 'تم بلوغ المستوى 30. قمة الإتقان.'),
    },
  ),
  'energy_gatherer': const BadgeLocalizationData(
    title: 'جامع الطاقة',
    subtitle: 'حصد نقاط الخبرة الإجمالية',
    tiers: {
      1: BadgeTierLocalization(name: 'مبتدئ XP', unit: 'نقطة خبرة', description: 'اجمع 500 نقطة خبرة تراكمية.'),
      2: BadgeTierLocalization(name: 'جامع XP', unit: 'نقطة خبرة', description: 'اكسب 2,000 نقطة خبرة مدى الحياة.'),
      3: BadgeTierLocalization(name: 'حاصد XP', unit: 'نقطة خبرة', description: 'تجاوز 6,000 نقطة خبرة.'),
      4: BadgeTierLocalization(name: 'سيد الطاقة', unit: 'نقطة خبرة', description: '15,000 نقطة خبرة. طاقة خالصة.'),
    },
  ),

  // ===========================================================================
  // PILLAR 8: MINDFULNESS & CONTINUITY (2 Badges)
  // ===========================================================================
  'pillar_of_dawn': const BadgeLocalizationData(
    title: 'عماد الفجر',
    subtitle: 'المواظبة الروحية وأداء الصلوات',
    tiers: {
      1: BadgeTierLocalization(name: 'مواظب I', unit: 'صلوات', description: 'أكمل تسجيل 5 صلوات في وقتها.'),
      2: BadgeTierLocalization(name: 'مواظب II', unit: 'صلوات', description: 'سجل 25 صلاة مكتملة.'),
      3: BadgeTierLocalization(name: 'مواظب III', unit: 'صلوات', description: 'أتمم 100 صلاة مسجلة.'),
      4: BadgeTierLocalization(name: 'ثابت على الصلاة', unit: 'صلوات', description: '300 صلاة مؤداة في مواقيتها. هنيئاً لك.'),
    },
  ),
  'black_box_logger': const BadgeLocalizationData(
    title: 'الصندوق الأسود',
    subtitle: 'سجل تدقيق الأنشطة والعمليات',
    tiers: {
      1: BadgeTierLocalization(name: 'قياس I', unit: 'أحداث', description: 'سجل 10 أحداث إنتاجية في السجل.'),
      2: BadgeTierLocalization(name: 'قياس II', unit: 'أحداث', description: 'سجل 50 حدثاً في الصندوق الأسود.'),
      3: BadgeTierLocalization(name: 'قياس III', unit: 'أحداث', description: 'التقط 200 محطة نشاط في السجل.'),
      4: BadgeTierLocalization(name: 'استرجاع شامل', unit: 'أحداث', description: '600 حدث موثق في سجل التاريخ.'),
    },
  ),
};

/// Category translations
final Map<BadgeCategory, String> kArabicBadgeCategories = {
  BadgeCategory.all: 'الكل',
  BadgeCategory.execution: 'التنفيذ والسرعة',
  BadgeCategory.focus: 'العمل العميق',
  BadgeCategory.consistency: 'التتابع والاستمرار',
  BadgeCategory.habits: 'العادات والانضباط',
  BadgeCategory.knowledge: 'المعرفة والحكمة',
  BadgeCategory.systems: 'الأنظمة والتنظيم',
  BadgeCategory.evolution: 'التطور والمستوى',
  BadgeCategory.mindfulness: 'اليقظة الروحية',
};

/// Extension providing easy Arabic localization for badges, tiers, and categories.
extension MasteryBadgeLocalizationExt on MasteryBadgeData {
  String localizedTitle(bool isArabic) {
    if (!isArabic) return title;
    return kArabicBadgeCatalog[id]?.title ?? title;
  }

  String localizedSubtitle(bool isArabic) {
    if (!isArabic) return subtitle;
    return kArabicBadgeCatalog[id]?.subtitle ?? subtitle;
  }

  String localizedCategory(bool isArabic) {
    if (!isArabic) return category;
    return categoryEnum.localizedLabel(isArabic);
  }

  String localizedProgressLabel(bool isArabic) {
    final next = nextTier;
    if (next == null) {
      final maxName = tiers.isNotEmpty ? tiers.last.localizedName(isArabic, badgeId: id) : '';
      return isArabic ? 'الحد الأقصى ($maxName)' : 'Maxed ($maxName)';
    }
    final unit = next.localizedUnit(isArabic, badgeId: id);
    return '$currentValue / ${next.targetValue} $unit';
  }
}

extension BadgeTierLocalizationExt on BadgeTier {
  String localizedName(bool isArabic, {String? badgeId}) {
    if (!isArabic) return name;
    if (badgeId != null) {
      final tierData = kArabicBadgeCatalog[badgeId]?.tiers[tierNumber];
      if (tierData != null) return tierData.name;
    }
    return name;
  }

  String localizedDescription(bool isArabic, {String? badgeId}) {
    if (!isArabic) return description;
    if (badgeId != null) {
      final tierData = kArabicBadgeCatalog[badgeId]?.tiers[tierNumber];
      if (tierData != null) return tierData.description;
    }
    return description;
  }

  String localizedUnit(bool isArabic, {String? badgeId}) {
    if (!isArabic) return unit;
    if (badgeId != null) {
      final tierData = kArabicBadgeCatalog[badgeId]?.tiers[tierNumber];
      if (tierData != null) return tierData.unit;
    }
    // Generic fallback unit translations
    switch (unit.toLowerCase()) {
      case 'task':
      case 'tasks':
        return 'مهام';
      case 'urgent tasks':
        return 'مهام عاجلة';
      case 'logs':
        return 'تسجيلات';
      case 'habits':
        return 'عادات';
      case 'notes':
        return 'ملاحظات';
      case 'pinned note':
      case 'pinned notes':
        return 'ملاحظات مثبتة';
      case 'project':
      case 'projects':
        return 'مشاريع';
      case 'tag':
      case 'tags':
        return 'وسوم';
      case 'prayers':
        return 'صلوات';
      case 'events':
        return 'أحداث';
      case 'level':
        return 'المستوى';
      case 'xp':
        return 'نقطة خبرة';
      case 'minutes':
        return 'دقائق';
      case 'sessions':
        return 'جلسات';
      case 'pomodoro cycles':
        return 'دورات بومودورو';
      case 'marathons':
      case 'marathon sessions':
        return 'جلسات ماراثون';
      case 'days':
      case 'streak days':
        return 'أيام';
      default:
        return unit;
    }
  }
}

extension BadgeCategoryLocalizationExt on BadgeCategory {
  String localizedLabel(bool isArabic) {
    if (!isArabic) return label;
    return kArabicBadgeCategories[this] ?? label;
  }
}

