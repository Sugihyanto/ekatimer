import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'providers/timer_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/session_provider.dart';
import 'services/audio_service.dart';
import 'services/vibration_service.dart';
import 'services/notification_service.dart';
import 'services/alarm_service.dart';
import 'services/widget_data_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The plugins set themselves up independently, so start them together;
  // awaiting each in turn held the first frame for the sum of all of them.
  await Future.wait([
    AudioService().init(),
    VibrationService().init(),
    NotificationService().init(),
    AlarmService().init(),
    WidgetDataService.initialize(),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TimerProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
      ],
      child: const MeditationTimerApp(),
    ),
  );

  // Ask once the app is on screen. Before runApp, a first-launch prompt, or
  // the exact-alarm settings page on newer Android, kept the user looking at
  // the splash screen until they answered.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => unawaited(_requestPermissions()),
  );
}

Future<void> _requestPermissions() async {
  try {
    final notificationService = NotificationService();
    await notificationService.requestPermissions();

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.scheduleExactAlarm.status;
      if (status.isDenied) {
        debugPrint('main: SCHEDULE_EXACT_ALARM not granted, requesting...');
        await Permission.scheduleExactAlarm.request();
      }
    }
  } catch (e) {
    debugPrint('main: Failed to request permissions: $e');
  }
}
