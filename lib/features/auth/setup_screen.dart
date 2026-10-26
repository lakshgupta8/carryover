import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../habits/widgets/gold_widgets.dart';

/// Shown instead of the app when Firebase has not been configured yet.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key, this.error});

  final Object? error;

  static const _steps = [
    'Create a free Firebase project at console.firebase.google.com (Spark plan).',
    'Add an Android app with package name com.lakshya.carryover and your debug SHA-1 (run: cd android && ./gradlew signingReport).',
    'Authentication → Sign-in method: enable Email/Password and Google.',
    'Firestore Database → Create database, then publish the rules from firestore.rules.',
    'Copy the Android app values into lib/firebase_options.dart (or run: flutterfire configure).',
    'Copy the Web client ID from the Google provider into lib/app_config.dart.',
    'Rebuild: flutter run',
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          children: [
            const Center(child: CarryoverMark()),
            const SizedBox(height: 20),
            Text(
              error == null ? 'One-time setup' : 'Firebase failed to start',
              style: t.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error == null
                  ? 'Carryover keeps your data in your own free Firebase project. '
                      'Connect it once and you are set.'
                  : '$error',
              style: t.bodyMedium?.copyWith(color: AppColors.inkMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            for (var i = 0; i < _steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.goldGradient,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: t.labelLarge?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(_steps[i], style: t.bodyMedium),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(
                  const ClipboardData(text: 'com.lakshya.carryover'),
                );
                showSnack(context, 'Package name copied.');
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy package name'),
            ),
            const SizedBox(height: 12),
            Text(
              'Full instructions are in README.md.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: AppColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}
