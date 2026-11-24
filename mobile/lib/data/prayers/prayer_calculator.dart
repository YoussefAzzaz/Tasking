import 'package:intl/intl.dart';
import 'package:adhan_dart/adhan_dart.dart' hide Prayer;
import 'prayer_model.dart';
import '../qibla_service.dart';

/// Pure domain calculation service for Islamic astronomical calculations.
/// Completely decoupled from database and Flutter widgets for fast, deterministic testing.
class PrayerCalculator {
  const PrayerCalculator();

  /// Resolves the optimal Islamic calculation method based on country or UTC offset
  CalculationParameters getOptimalParameters(String country, [int? timezoneOffsetHours]) {
    final lowerCountry = country.toLowerCase().trim();
    if (lowerCountry.contains('tunis') || lowerCountry.contains('alger')) {
      return CalculationMethodParameters.tunisia();
    } else if (lowerCountry.contains('egypt')) {
      return CalculationMethodParameters.egyptian();
    } else if (lowerCountry.contains('morocco')) {
      return CalculationMethodParameters.morocco();
    } else if (lowerCountry.contains('saudi') || lowerCountry.contains('arabia')) {
      return CalculationMethodParameters.ummAlQura();
    } else if (lowerCountry.contains('pakistan') ||
        lowerCountry.contains('india') ||
        lowerCountry.contains('bangladesh')) {
      return CalculationMethodParameters.karachi();
    } else if (lowerCountry.contains('united states') || lowerCountry.contains('canada')) {
      return CalculationMethodParameters.northAmerica();
    } else if (lowerCountry.contains('singapore') || lowerCountry.contains('malaysia')) {
      return CalculationMethodParameters.singapore();
    }

    final offset = timezoneOffsetHours ?? DateTime.now().timeZoneOffset.inHours;
    if (offset == 1) {
      return CalculationMethodParameters.tunisia();
    } else if (offset == 2) {
      return CalculationMethodParameters.egyptian();
    } else if (offset == 3) {
      return CalculationMethodParameters.ummAlQura();
    } else if (offset >= 5 && offset <= 6) {
      return CalculationMethodParameters.karachi();
    }

    return CalculationMethodParameters.muslimWorldLeague();
  }

  /// Calculates the 5 daily prayer times for the given coordinates and date
  List<PrayerItem> calculatePrayers({
    required Coordinates coordinates,
    required DateTime date,
    CalculationParameters? parameters,
    String country = '',
  }) {
    final params = parameters ?? getOptimalParameters(country, date.timeZoneOffset.inHours);
    final prayerTimes = PrayerTimes(
      coordinates: coordinates,
      date: date,
      calculationParameters: params,
      precision: false,
    );

    return [
      PrayerItem(
        id: 'fajr',
        name: 'Fajr',
        icon: 'fajr',
        sortOrder: 1,
        time: prayerTimes.fajr.toLocal(),
        formattedTime: formatAdanTime(prayerTimes.fajr),
      ),
      PrayerItem(
        id: 'dhuhr',
        name: 'Dhuhr',
        icon: 'dhuhr',
        sortOrder: 2,
        time: prayerTimes.dhuhr.toLocal(),
        formattedTime: formatAdanTime(prayerTimes.dhuhr),
      ),
      PrayerItem(
        id: 'asr',
        name: 'Asr',
        icon: 'asr',
        sortOrder: 3,
        time: prayerTimes.asr.toLocal(),
        formattedTime: formatAdanTime(prayerTimes.asr),
      ),
      PrayerItem(
        id: 'maghrib',
        name: 'Maghrib',
        icon: 'maghrib',
        sortOrder: 4,
        time: prayerTimes.maghrib.toLocal(),
        formattedTime: formatAdanTime(prayerTimes.maghrib),
      ),
      PrayerItem(
        id: 'isha',
        name: 'Isha',
        icon: 'isha',
        sortOrder: 5,
        time: prayerTimes.isha.toLocal(),
        formattedTime: formatAdanTime(prayerTimes.isha),
      ),
    ];
  }

  /// Calculates local astronomical Sunrise time for the given coordinates and date.
  DateTime calculateSunrise({
    required Coordinates coordinates,
    required DateTime date,
    CalculationParameters? parameters,
    String country = '',
  }) {
    final params = parameters ?? getOptimalParameters(country, date.timeZoneOffset.inHours);
    final prayerTimes = PrayerTimes(
      coordinates: coordinates,
      date: date,
      calculationParameters: params,
      precision: false,
    );
    return prayerTimes.sunrise.toLocal();
  }

  /// Returns the currently active obligatory prayer code ('fajr', 'dhuhr', 'asr', 'maghrib', 'isha')
  /// or 'sunrise' during the post-sunrise window before Dhuhr.
  String determineCurrentPrayerCode(
    List<PrayerItem> prayers,
    DateTime sunrise, [
    DateTime? currentTime,
  ]) {
    if (prayers.length < 5) return 'fajr';
    final now = currentTime ?? DateTime.now();
    final fajr = prayers[0].time;
    final dhuhr = prayers[1].time;
    final asr = prayers[2].time;
    final maghrib = prayers[3].time;
    final isha = prayers[4].time;

    if (now.isBefore(fajr)) {
      return 'isha';
    } else if (now.isBefore(sunrise)) {
      return 'fajr';
    } else if (now.isBefore(dhuhr)) {
      return 'sunrise';
    } else if (now.isBefore(asr)) {
      return 'dhuhr';
    } else if (now.isBefore(maghrib)) {
      return 'asr';
    } else if (now.isBefore(isha)) {
      return 'maghrib';
    }
    return 'isha';
  }

  /// Calculates Great Circle Qibla bearing towards the Kaaba in Mecca
  double calculateQiblaBearing(double latitude, double longitude) {
    return QiblaService().calculateQiblaBearing(latitude, longitude);
  }

  /// Computes the next upcoming prayer telemetry for countdown timers and progress indicators
  NextPrayerTelemetry computeNextPrayer(List<Prayer> prayers, [DateTime? currentTime]) {
    final now = currentTime ?? DateTime.now();
    if (prayers.isEmpty) {
      final fallback = defaultPrayers().first;
      return (
        nextPrayer: fallback,
        countdownText: 'in 1h',
        isDueNow: false,
        progress: 0.5,
        timeRemaining: const Duration(hours: 1),
      );
    }

    final parsed = <MapEntry<Prayer, DateTime>>[];
    for (final p in prayers) {
      final dt = parseTimeToDateTime(p.time, now) ??
          DateTime(now.year, now.month, now.day, 12, 0);
      parsed.add(MapEntry(p, dt));
    }
    parsed.sort((a, b) => a.value.compareTo(b.value));

    // Check if any prayer is "DUE NOW" (within 20 minutes after its adan)
    for (final entry in parsed) {
      final diffMin = now.difference(entry.value).inMinutes;
      if (diffMin >= 0 && diffMin <= 20) {
        return (
          nextPrayer: entry.key,
          countdownText: 'DUE NOW',
          isDueNow: true,
          progress: 0.95,
          timeRemaining: Duration.zero,
        );
      }
    }

    // Find next upcoming prayer today
    for (int i = 0; i < parsed.length; i++) {
      if (parsed[i].value.isAfter(now)) {
        final next = parsed[i];
        final prevDt = i > 0
            ? parsed[i - 1].value
            : parsed.last.value.subtract(const Duration(days: 1));
        final diff = next.value.difference(now);
        final countdown = diff.inHours > 0
            ? 'in ${diff.inHours}h ${diff.inMinutes % 60}m'
            : 'in ${diff.inMinutes}m';

        final span = next.value.difference(prevDt).inSeconds;
        final elapsed = now.difference(prevDt).inSeconds;
        final progress = span > 0 ? (elapsed / span).clamp(0.05, 1.0) : 0.5;

        return (
          nextPrayer: next.key,
          countdownText: countdown,
          isDueNow: false,
          progress: progress,
          timeRemaining: diff,
        );
      }
    }

    // All prayers passed for today; next is tomorrow's Fajr
    final fajr = parsed.first;
    final tomorrowFajr = fajr.value.add(const Duration(days: 1));
    final prevDt = parsed.last.value;
    final diff = tomorrowFajr.difference(now);
    final countdown = diff.inHours > 0
        ? 'in ${diff.inHours}h ${diff.inMinutes % 60}m'
        : 'in ${diff.inMinutes}m';
    final span = tomorrowFajr.difference(prevDt).inSeconds;
    final elapsed = now.difference(prevDt).inSeconds;
    final progress = span > 0 ? (elapsed / span).clamp(0.05, 1.0) : 0.5;

    return (
      nextPrayer: fajr.key,
      countdownText: countdown,
      isDueNow: false,
      progress: progress,
      timeRemaining: diff,
    );
  }

  /// Parses 12h or 24h formatted time strings into local DateTime
  DateTime? parseTimeToDateTime(String timeStr, DateTime now) {
    try {
      final clean = timeStr.trim();
      if (clean.toUpperCase().contains('AM') || clean.toUpperCase().contains('PM')) {
        final df = DateFormat('hh:mm a');
        final dt = df.parse(clean);
        return DateTime(now.year, now.month, now.day, dt.hour, dt.minute);
      }
      final parts = clean.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0].trim());
        final min = int.parse(parts[1].trim());
        return DateTime(now.year, now.month, now.day, hour, min);
      }
    } catch (_) {}
    return null;
  }

  /// Formats raw time string into clean 24h format ('HH:mm')
  String formatPrayerTime24(String raw) {
    final now = DateTime.now();
    final dt = parseTimeToDateTime(raw, now);
    if (dt != null) {
      return DateFormat('HH:mm').format(dt);
    }
    return raw.replaceAll(' AM', '').replaceAll(' PM', '').trim();
  }

  /// Formats DateTime into 12h AM/PM Adhan display string
  String formatAdanTime(DateTime dt) => DateFormat('hh:mm a').format(dt.toLocal());

  /// Default canonical 5 prayers fallback list
  static List<Prayer> defaultPrayers([String? userId]) {
    final uid = userId ?? '';
    String pid(String code) => uid.isNotEmpty ? 'prayer_${uid}_$code' : 'prayer_$code';
    return [
      Prayer(
        id: pid('fajr'),
        userId: uid,
        prayerCode: 'fajr',
        name: 'Fajr',
        icon: 'fajr',
        time: '05:30 AM',
        sortOrder: 1,
        isDone: false,
        createdAt: '',
        updatedAt: '',
      ),
      Prayer(
        id: pid('dhuhr'),
        userId: uid,
        prayerCode: 'dhuhr',
        name: 'Dhuhr',
        icon: 'dhuhr',
        time: '12:45 PM',
        sortOrder: 2,
        isDone: false,
        createdAt: '',
        updatedAt: '',
      ),
      Prayer(
        id: pid('asr'),
        userId: uid,
        prayerCode: 'asr',
        name: 'Asr',
        icon: 'asr',
        time: '04:15 PM',
        sortOrder: 3,
        isDone: false,
        createdAt: '',
        updatedAt: '',
      ),
      Prayer(
        id: pid('maghrib'),
        userId: uid,
        prayerCode: 'maghrib',
        name: 'Maghrib',
        icon: 'maghrib',
        time: '06:45 PM',
        sortOrder: 4,
        isDone: false,
        createdAt: '',
        updatedAt: '',
      ),
      Prayer(
        id: pid('isha'),
        userId: uid,
        prayerCode: 'isha',
        name: 'Isha',
        icon: 'isha',
        time: '08:15 PM',
        sortOrder: 5,
        isDone: false,
        createdAt: '',
        updatedAt: '',
      ),
    ];
  }
}
