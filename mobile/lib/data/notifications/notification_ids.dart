/// Centralized notification and native alarm ID registry.
///
/// Reserving strictly disjoint ranges prevents one subsystem's notification
/// cancellation (for example, stopping a focus session) from dismissing scheduled
/// daily Adhan alarms or habit reminders.
class NotificationIds {
  const NotificationIds._();

  // Prayer Adhan AwesomeNotifications IDs: 1001..1005 (Fajr..Isha)
  static const int adhanBase = 1000;
  static int adhanForOrder(int sortOrder) => adhanBase + sortOrder;

  // Native Android AlarmClock requestCodes: 2001..2005 (Fajr..Isha)
  static const int adhanNativeAlarmBase = 2000;
  static int adhanNativeAlarmForOrder(int sortOrder) =>
      adhanNativeAlarmBase + sortOrder;

  // Focus Session progress & completion notifications: 3001..3002
  static const int focusProgress = 3001;
  static const int focusCompleted = 3002;

  // Debug alarm diagnostics: 8888
  static const int adhanDebugTest = 8888;

  // Android Keep-Alive foreground & wakeup service IDs: 9001..9003
  static const int keepAliveForeground = 9001;
  static const int keepAliveWakeup = 9002;
  static const int keepAliveRestart = 9003;

  // Legacy Fajr wake-up alarm ID: 9991
  static const int fajrLegacyWakeup = 9991;
}
