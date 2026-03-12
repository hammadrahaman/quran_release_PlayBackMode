import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('progress');
  await Hive.openBox('bookmarks');

  try {
    await NotificationService.initialize();
    // Brief delay so Android can show permission dialog and user can accept before we schedule.
    await Future.delayed(const Duration(milliseconds: 1500));
    await NotificationService.scheduleEvery3HoursReminder();
  } catch (_) {
    // Notification scheduling failed; app still runs.
  }
  runApp(const QuranCompanionApp());
}
