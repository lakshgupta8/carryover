import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/dates.dart';
import '../../firebase_options.dart';
import '../habits/data/habit_repository.dart';
import 'notification_service.dart';

/// Handles "Mark done" taps while the app is not running.
///
/// This runs in its own isolate, so Firebase has to be initialised here. The
/// write goes through Firestore's offline queue, which means it is safe even
/// without a network connection; the app picks the change up on next launch.
@pragma('vm:entry-point')
Future<void> notificationActionBackground(NotificationResponse response) async {
  if (response.actionId != NotificationService.doneActionId) return;
  final parsed = NotificationService.parsePayload(response.payload);
  if (parsed == null) return;

  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('Mark done ignored: no signed-in user.');
      return;
    }
    final day = dateKey(logicalDay(DateTime.now(), parsed.dayStartMinutes));
    await HabitRepository(uid: uid).setDone(parsed.habitId, day, true);
  } catch (e) {
    debugPrint('Mark done from notification failed: $e');
  }
}
