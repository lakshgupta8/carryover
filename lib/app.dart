import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/setup_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/habits/screens/home_shell.dart';
import 'features/habits/widgets/gold_widgets.dart';
import 'features/notifications/notification_service.dart';

/// Root widget. Owns the MaterialApp and the auth gate.
class AurumApp extends StatelessWidget {
  const AurumApp({
    super.key,
    required this.notifications,
    required this.firebaseReady,
    this.firebaseError,
  });

  final NotificationService notifications;
  final bool firebaseReady;
  final Object? firebaseError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: firebaseReady
          ? AuthGate(notifications: notifications)
          : SetupScreen(error: firebaseError),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.notifications});

  final NotificationService notifications;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Splash();
        }
        final user = snapshot.data;
        if (user == null) return SignInScreen(auth: _auth);
        return HomeShell(
          key: ValueKey(user.uid),
          user: user,
          auth: _auth,
          notifications: widget.notifications,
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: AurumMark(size: 84)),
    );
  }
}
