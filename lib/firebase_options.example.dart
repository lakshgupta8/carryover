// Template for lib/firebase_options.dart (which is git-ignored).
//
//   cp lib/firebase_options.example.dart lib/firebase_options.dart
//
// Then fill in the values from Firebase console → Project settings → Your
// apps → Android, or run `flutterfire configure` which writes the real file
// for you. Until the placeholders are replaced the app shows a setup screen.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.firebasestorage.app',
  );
}
