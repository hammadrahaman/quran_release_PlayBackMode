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
  } catch (e) {
    debugPrint('NotificationService.initialize failed: $e');
  }

  try {
    // Brief delay so Android can show permission dialog and user can accept before we schedule.
    await Future.delayed(const Duration(milliseconds: 1500));
    await NotificationService.scheduleEvery3HoursReminder();
    await NotificationService.scheduleNightRecitationReminder();
    await NotificationService.scheduleFridayRecitationReminder();
  } catch (e) {
    debugPrint('NotificationService.scheduleEvery3HoursReminder failed: $e');
  }
  runApp(const QuranCompanionApp());
}
