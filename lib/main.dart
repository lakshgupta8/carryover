import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  var firebaseReady = false;
  Object? firebaseError;
  if (AppConfig.firebaseConfigured) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      firebaseReady = true;
    } catch (e) {
      firebaseError = e;
    }
  }

  final notifications = NotificationService();
  try {
    await notifications.init();
  } catch (e) {
    debugPrint('Notifications unavailable: $e');
  }

  runApp(AurumApp(
    notifications: notifications,
    firebaseReady: firebaseReady,
    firebaseError: firebaseError,
  ));
}
