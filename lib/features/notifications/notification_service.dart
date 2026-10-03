import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../app_config.dart';
import '../habits/models/habit.dart';
import 'notification_actions.dart';

/// Called when the user taps "Mark done" on a reminder while the app is
/// running. [dayStartMinutes] is the day-boundary setting baked into the
/// notification when it was scheduled.
typedef MarkDoneHandler = Future<void> Function(
  String habitId,
  int dayStartMinutes,
);

/// On-device scheduled notifications. Nothing goes through a server, so
/// reminders fire even with the app closed and cost nothing.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  /// Set by the controller while the app is running.
  MarkDoneHandler? onMarkDone;

  static const String doneActionId = 'mark_done';

  static const _reminderChannel = AndroidNotificationChannel(
    'habit_reminders',
    'Habit reminders',
    description: 'Reminders at the time you set for each habit.',
    importance: Importance.high,
  );

  static const _checkInChannel = AndroidNotificationChannel(
    'evening_check_in',
    'Evening check-in',
    description: 'A nudge in the evening if habits are still open.',
    importance: Importance.defaultImportance,
  );

  static const int _checkInId = 1;
  static const int _testId = 2;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Could not resolve local timezone, using UTC: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: notificationActionBackground,
    );
    final android = _android;
    if (android != null) {
      await android.createNotificationChannel(_reminderChannel);
      await android.createNotificationChannel(_checkInChannel);
    }
    _ready = true;
  }

  Future<void> _onResponse(NotificationResponse response) async {
    if (response.actionId != doneActionId) return;
    final parsed = parsePayload(response.payload);
    if (parsed == null) return;
    await onMarkDone?.call(parsed.habitId, parsed.dayStartMinutes);
  }

  // ---- Payload ------------------------------------------------------------

  static String encodePayload(String habitId, int dayStartMinutes) =>
      'done|$habitId|$dayStartMinutes';

  static ({String habitId, int dayStartMinutes})? parsePayload(String? raw) {
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length != 3 || parts[0] != 'done') return null;
    return (habitId: parts[1], dayStartMinutes: int.tryParse(parts[2]) ?? 0);
  }

  // ---- Permissions --------------------------------------------------------

  /// Asks for POST_NOTIFICATIONS (Android 13+) and, if needed, exact alarms.
  Future<bool> requestPermission() async {
    final android = _android;
    if (android == null) return true;
    final granted = await android.requestNotificationsPermission() ?? true;
    final exact = await android.canScheduleExactNotifications() ?? true;
    if (!exact) {
      await android.requestExactAlarmsPermission();
    }
    return granted;
  }

  Future<bool> areEnabled() async {
    final android = _android;
    if (android == null) return true;
    return await android.areNotificationsEnabled() ?? true;
  }

  Future<void> showTest() => _plugin.show(
        id: _testId,
        title: '${AppConfig.appName} is set up ✨',
        body: 'Reminders will look like this.',
        notificationDetails: _details(_reminderChannel),
      );

  // ---- Scheduling ---------------------------------------------------------

  /// Rebuilds every scheduled notification from current state.
  ///
  /// Weekday habits get one weekly-repeating alarm per scheduled weekday;
  /// weekly ("n days a week") habits get one daily-repeating alarm. Habits
  /// done today skip today's instance; weekly habits whose target is met are
  /// quiet until next Monday. The evening check-in repeats daily and skips
  /// today once nothing is left to do.
  Future<void> sync({
    required List<Habit> habits,
    required Set<String> doneToday,
    required Set<String> weeklyTargetMet,
    required bool nothingLeftToday,
    required int? checkInMinutes,
    required int dayStartMinutes,
    required bool enabled,
  }) async {
    if (!_ready) return;
    await _plugin.cancelAllPendingNotifications();
    if (!enabled) return;

    final now = tz.TZDateTime.now(tz.local);
    final nextMonday = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + (8 - now.weekday),
    );

    for (final habit in habits) {
      final minutes = habit.reminderMinutes;
      if (habit.isArchived || minutes == null) continue;
      final skip = doneToday.contains(habit.id);
      final payload = encodePayload(habit.id, dayStartMinutes);
      if (habit.isWeekly) {
        await _schedule(
          id: _reminderId(habit.id, 0),
          title: '${habit.emoji} ${habit.name}',
          body: '${habit.timesPerWeek} days a week. Is today one of them?',
          when: _nextInstance(
            minutes,
            skipToday: skip,
            notBefore: weeklyTargetMet.contains(habit.id) ? nextMonday : null,
          ),
          channel: _reminderChannel,
          repeat: DateTimeComponents.time,
          payload: payload,
        );
        continue;
      }
      for (final weekday in habit.weekdays) {
        await _schedule(
          id: _reminderId(habit.id, weekday),
          title: '${habit.emoji} ${habit.name}',
          body: 'It is time. Keep the streak golden.',
          when: _nextInstance(minutes, weekday: weekday, skipToday: skip),
          channel: _reminderChannel,
          repeat: DateTimeComponents.dayOfWeekAndTime,
          payload: payload,
        );
      }
    }

    if (checkInMinutes != null) {
      await _schedule(
        id: _checkInId,
        title: 'Evening check-in',
        body: 'Anything left for today? A quick tap keeps your streak alive.',
        when: _nextInstance(checkInMinutes, skipToday: nothingLeftToday),
        channel: _checkInChannel,
        repeat: DateTimeComponents.time,
      );
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required AndroidNotificationChannel channel,
    required DateTimeComponents repeat,
    String? payload,
  }) async {
    Future<void> attempt(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: _details(channel, withDoneAction: payload != null),
          androidScheduleMode: mode,
          matchDateTimeComponents: repeat,
          payload: payload,
        );
    try {
      await attempt(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException catch (e) {
      // Exact alarms not permitted on this device/OS: fall back to inexact.
      debugPrint('Exact alarm refused (${e.code}); using inexact schedule.');
      await attempt(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  NotificationDetails _details(
    AndroidNotificationChannel channel, {
    bool withDoneAction = false,
  }) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: channel.importance == Importance.high
              ? Priority.high
              : Priority.defaultPriority,
          color: const Color(0xFFD4AF37),
          actions: withDoneAction
              ? const [
                  AndroidNotificationAction(
                    doneActionId,
                    'Mark done',
                    showsUserInterface: false,
                    cancelNotification: true,
                  ),
                ]
              : null,
        ),
      );

  /// Next occurrence of [minutes]-past-midnight, optionally on [weekday]
  /// (Monday = 1 … Sunday = 7), strictly in the future and not before
  /// [notBefore].
  static tz.TZDateTime _nextInstance(
    int minutes, {
    int? weekday,
    bool skipToday = false,
    tz.TZDateTime? notBefore,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    for (var offset = 0; offset < 16; offset++) {
      final candidate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + offset,
        minutes ~/ 60,
        minutes % 60,
      );
      if (!candidate.isAfter(now)) continue;
      if (notBefore != null && candidate.isBefore(notBefore)) continue;
      if (weekday != null && candidate.weekday != weekday) continue;
      if (skipToday && offset == 0) continue;
      return candidate;
    }
    // Unreachable in practice; keep the type system happy.
    return tz.TZDateTime(tz.local, now.year, now.month, now.day + 7,
        minutes ~/ 60, minutes % 60);
  }

  /// Stable 31-bit id per (habit, weekday).
  static int _reminderId(String habitId, int weekday) =>
      ((habitId.hashCode & 0x0FFFFFFF) << 3) | weekday;
}
