/// Pure domain utility for converting Gregorian dates to the Islamic (Hijri) calendar
/// using the standard Kuwaiti tabular astronomical Julian Day algorithm.
class HijriDate {
  final int year;
  final int month;
  final int day;

  const HijriDate({
    required this.year,
    required this.month,
    required this.day,
  });

  static const List<String> arabicMonthNames = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الثاني',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  static const List<String> englishShortMonthNames = [
    'Muh',
    'Saf',
    'Rab I',
    'Rab II',
    'Jum I',
    'Jum II',
    'Raj',
    'Sha',
    'Ram',
    'Shaw',
    'Dhu Q',
    'Dhu H',
  ];

  /// Converts a local Gregorian [DateTime] into an approximate Hijri date.
  factory HijriDate.fromGregorian(DateTime date) {
    int y = date.year;
    int m = date.month;
    final int d = date.day;

    if (m <= 2) {
      y -= 1;
      m += 12;
    }

    final int a = y ~/ 100;
    final int b = 2 - a + (a ~/ 4);
    final int jd =
        (365.25 * (y + 4716)).floor() + (30.6001 * (m + 1)).floor() + d + b - 1524;

    int l = jd - 1948440 + 10632;
    final int n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final int j = (((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719)) +
        ((l ~/ 5670) * ((43 * l) ~/ 15238));
    l = l - (((30 - j) ~/ 15) * ((17719 * j) ~/ 50)) -
        ((j ~/ 16) * ((15238 * j) ~/ 43)) +
        29;
    final int hMonth = (24 * l) ~/ 709;
    final int hDay = l - (709 * hMonth) ~/ 24;
    final int hYear = 30 * n + j - 30;

    return HijriDate(year: hYear, month: hMonth, day: hDay);
  }

  String get arabicMonthName =>
      arabicMonthNames[(month - 1).clamp(0, arabicMonthNames.length - 1)];

  String get englishShortMonthName =>
      englishShortMonthNames[(month - 1).clamp(0, englishShortMonthNames.length - 1)];

  /// Formats the Hijri date in Arabic, e.g. `13 جمادى الآخرة 1448`.
  String formatArabic({bool includeYear = true, bool includeSuffix = false}) {
    final base = includeYear ? '$day $arabicMonthName $year' : '$day $arabicMonthName';
    return includeSuffix ? '$base هـ' : base;
  }

  /// Formats the Hijri date in concise English/Latin form, e.g. `13 Jum II 1448 AH`.
  String formatEnglish({bool includeYear = false}) {
    return includeYear
        ? '$day $englishShortMonthName $year AH'
        : '$day $englishShortMonthName';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HijriDate &&
          runtimeType == other.runtimeType &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'HijriDate($year-$month-$day)';
}
