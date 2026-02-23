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

  await NotificationService.initialize();
  await NotificationService.scheduleEvery3HoursReminder();

  runApp(const QuranCompanionApp());
}
