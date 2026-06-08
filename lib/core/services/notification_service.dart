import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

// Top-level handler required by flutter_local_notifications for background taps.
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse details) {}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static void Function(String payload)? onNotificationTap;

  /* -------------------- INITIALIZE -------------------- */

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload != null) onNotificationTap?.call(payload);
      },
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }

    await _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static bool _periodicReminderScheduled = false;

  /* -------------------- DAILY MESSAGES -------------------- */

  static final List<String> _quranMessages = [
    'Whoever reads a letter from the Book of Allah will receive a Hasanah (good deed) — [Tirmidhi 2910] 📖',
    'The best of you are those who learn the Qur\'an and teach it — [Bukhari 5027] 🌿',
    'The one who is proficient in reciting the Qur\'an will be with the noble, dutiful scribes — [Muslim 798] ✨',
    'A house in which the Qur\'an is recited is spacious for its people — [Ibn Hibban, Sahih] 🤲',
    'Recite the Qur\'an, for it will come as an intercessor for its companions on the Day of Resurrection — [Muslim 804] 🤍',
  ];

  static final List<String> _hadithMessages = [
    'Actions are by intentions — [Bukhari 1, Muslim 1907] 🌱',
    'Make things easy, do not make them difficult — [Bukhari 69] ☀️',
    'None of you truly believes until he loves for his brother what he loves for himself — [Bukhari 13] 🤝',
    'The strong man is not the one who can overpower others. The strong man is the one who controls himself when angry — [Bukhari 6114] 💪',
    'Speak good or remain silent — [Bukhari 6018] 🤐',
    'Cleanliness is half of faith — [Muslim 223] ✨',
    'Whoever removes a worldly hardship from a believer, Allah will remove a hardship from him on the Day — [Muslim 2699] 🌿',
    'Do not belittle any good deed, even meeting your brother with a cheerful face — [Muslim 2626] 😊',
    'Pay the worker his wages before his sweat dries — [Ibn Majah 2443, Hasan] 💼',
    'The merciful are shown mercy by the Most Merciful — be merciful to those on earth — [Tirmidhi 1924] 🤲',
  ];

  static final List<String> _streakMessages = [
    'The most beloved deeds to Allah are those done consistently, even if small — [Bukhari 6464] 🔥',
    'Take up good deeds only as much as you are able — [Ibn Majah 4240] 📈',
    'Be steadfast — Allah does not waste the reward of the good-doers — [Qur\'an 11:115] 🌟',
    'Whoever guides someone to goodness will have a reward like the one who did it — [Muslim 1893] 🎯',
  ];

  static String _randomMessage(List<String> list) {
    final random = Random();
    return list[random.nextInt(list.length)];
  }

  /* -------------------- SCHEDULE DAILY -------------------- */

  static Future<void> scheduleDailyQuranAndHadith({
    required int quranHour,
    required int quranMinute,
    required int hadithHour,
    required int hadithMinute,
  }) async {
    // Qur'an Reminder
    await _notifications.zonedSchedule(
      1,
      'Time for Qur\'an 📖',
      _randomMessage(_quranMessages),
      _nextInstanceOfTime(quranHour, quranMinute),
      _notificationDetails(
        channelId: 'quran_channel',
        channelName: 'Qur\'an Reminder',
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Hadith Reminder
    await _notifications.zonedSchedule(
      2,
      'Hadith of the Day 📜',
      _randomMessage(_hadithMessages),
      _nextInstanceOfTime(hadithHour, hadithMinute),
      _notificationDetails(
        channelId: 'hadith_channel',
        channelName: 'Hadith Reminder',
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /* -------------------- MOTIVATIONAL REMINDER EVERY 4–5 HOURS -------------------- */

  static Future<void> scheduleEvery3HoursReminder() async {
    if (_periodicReminderScheduled) return;
    try {
      // Clear old schedule to avoid duplicates across app restarts.
      await _notifications.cancel(3000);
      for (int i = 0; i < 10; i++) {
        await _notifications.cancel(3001 + i);
      }

      final now = tz.TZDateTime.now(tz.local);
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      bool canUseExact = true;
      if (androidPlugin != null) {
        try {
          canUseExact = await androidPlugin.canScheduleExactNotifications() ?? false;
        } catch (_) {
          // Keep default true on older Android/plugin behaviors.
        }
      }

      final scheduleMode = canUseExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      // True every-3-hours schedule: 0,3,6,9,12,15,18,21 (8 reminders/day).
      // Repeats daily at these local times.
      const reminderHours = [0, 3, 6, 9, 12, 15, 18, 21];

      for (int i = 0; i < reminderHours.length; i++) {
        var scheduled = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          reminderHours[i],
          0,
        );
        // Ensure first trigger is in the future (next occurrence of this time).
        if (!scheduled.isAfter(now)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }

        await _notifications.zonedSchedule(
          3001 + i,
          'Time to read 📖',
          _randomMessage(_quranMessages),
          scheduled,
          _notificationDetails(
            channelId: 'quran_3hour_channel',
            channelName: 'Quran Reminder (every 3 hours)',
          ),
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }

      _periodicReminderScheduled = true;
    } catch (e) {
      // Do not set _periodicReminderScheduled so next app launch can retry.
      debugPrint('NotificationService: scheduleEvery3HoursReminder failed: $e');
    }
  }

  /* -------------------- MOTIVATIONAL -------------------- */

  static Future<void> sendMotivationalNotification(int daysCompleted) async {
    await _notifications.show(
      daysCompleted + 100,
      'Keep Going 🌟',
      _getMotivationalMessage(daysCompleted),
      _notificationDetails(
        channelId: 'motivation_channel',
        channelName: 'Motivational Messages',
      ),
    );
  }

  static String _getMotivationalMessage(int days) =>
      _randomMessage(_streakMessages);

  /* -------------------- HELPERS -------------------- */

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  static NotificationDetails _notificationDetails({
    required String channelId,
    required String channelName,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /* -------------------- NIGHT RECITATION -------------------- */

  static Future<void> scheduleNightRecitationReminder() async {
    await _notifications.zonedSchedule(
      4001,
      'Night Recitation 🌙',
      'Time for your nightly recitations — Al-Mulk, Al-Ikhlas & more.',
      _nextInstanceOfTime(19, 0),
      _notificationDetails(
        channelId: 'night_recitation_channel',
        channelName: 'Night Recitation',
      ),
      payload: 'night_recitation',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /* -------------------- FRIDAY RECITATION -------------------- */

  static Future<void> scheduleFridayRecitationReminder() async {
    await _notifications.zonedSchedule(
      4002,
      "Jumu'ah Mubarak 🕌",
      "Don't forget to recite Surah Al-Kahf and Al-Jumu'ah today.",
      _nextFriday(12, 0),
      _notificationDetails(
        channelId: 'friday_recitation_channel',
        channelName: 'Friday Recitation',
      ),
      payload: 'friday_recitation',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static tz.TZDateTime _nextFriday(int hour, int minute) {
    var candidate = tz.TZDateTime.now(tz.local);
    candidate = tz.TZDateTime(
        tz.local, candidate.year, candidate.month, candidate.day, hour, minute);
    while (candidate.weekday != DateTime.friday ||
        !candidate.isAfter(tz.TZDateTime.now(tz.local))) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  /* -------------------- CANCEL -------------------- */

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
