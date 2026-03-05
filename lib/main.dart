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
    await NotificationService.scheduleEvery3HoursReminder();
    } catch (e) {
    // Optional: log the error if needed
    // print('Notification initialization failed: $e');
    }
  runApp(const QuranCompanionApp());
}
