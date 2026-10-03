import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app_config.dart';
import '../../../core/dates.dart';
import '../../../core/rewards.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_service.dart';
import '../../notifications/notification_service.dart';
import '../data/habit_controller.dart';
import '../widgets/gold_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.user,
    required this.auth,
    required this.notifications,
  });

  final User user;
  final AuthService auth;
  final NotificationService notifications;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool? _systemEnabled;
  bool _busy = false;

  static const _dayStartOptions = [0, 60, 120, 180, 240, 300];
  static const _graceOptions = {
    0: 'Off',
    60: '1 hour into the new day',
    180: '3 hours into the new day',
    720: 'Until noon',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final enabled = await widget.notifications.areEnabled();
    if (mounted) setState(() => _systemEnabled = enabled);
  }

  Future<void> _requestPermission() async {
    await widget.notifications.requestPermission();
    await _refreshPermission();
    if (mounted) ControllerScope.of(context).resyncNotifications();
  }

  Future<void> _pickCheckIn(HabitController c) async {
    final current = c.profile.checkInMinutes ?? 21 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked != null) {
      await c.setCheckIn(picked.hour * 60 + picked.minute);
    }
  }

  Future<void> _pickDayStart(HabitController c) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Day starts at'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Check-ins before this time count for the previous day. Handy '
              'for night owls.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
          ),
          RadioGroup<int>(
            groupValue: c.profile.dayStartMinutes,
            onChanged: (v) => Navigator.pop(ctx, v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final m in _dayStartOptions)
                  RadioListTile<int>(
                    value: m,
                    title: Text(m == 0 ? 'Midnight' : formatMinutes(m)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) await c.setDayStart(picked);
  }

  Future<void> _pickGrace(HabitController c) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Grace period'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              "How long after a day ends you can still tick yesterday's "
              'habits for free. After that, a miss costs tokens to repair.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
          ),
          RadioGroup<int>(
            groupValue: c.profile.graceMinutes,
            onChanged: (v) => Navigator.pop(ctx, v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in _graceOptions.entries)
                  RadioListTile<int>(value: e.key, title: Text(e.value)),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) await c.setGrace(picked);
  }

  Future<void> _export(HabitController c) async {
    setState(() => _busy = true);
    try {
      final json = await c.exportJson();
      final dir = await getTemporaryDirectory();
      final stamp = dateKey(DateTime.now());
      final file = File('${dir.path}/habitual-offender-$stamp.json');
      await file.writeAsString(json);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'Habitual Offender export $stamp',
      ));
    } catch (e) {
      if (mounted) showSnack(context, 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount(HabitController c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your habits, history, tokens and the '
          'sign-in itself. Export your data first if you want a copy. This '
          'cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep my account')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await c.deleteAllData();
      await widget.user.delete();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'requires-recent-login') {
        showSnack(context,
            'Your data is gone, but Firebase needs a fresh sign-in to remove the account. Sign out, sign in again, then delete.');
      } else {
        showSnack(context, AuthService.describe(e));
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Could not delete: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your habits stay safely in the cloud.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) await widget.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final c = ControllerScope.of(context);
    final p = c.profile;
    final t = Theme.of(context).textTheme;
    final name = widget.user.displayName?.trim();
    final email = widget.user.email ?? '';
    final initial = (name?.isNotEmpty == true ? name![0] : (email.isNotEmpty ? email[0] : 'A')).toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          SoftCard(
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldGradient,
                  ),
                  child: Text(
                    initial,
                    style: t.titleLarge?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name?.isNotEmpty == true ? name! : 'You',
                          style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      Text(email, style: t.bodySmall?.copyWith(color: AppColors.inkMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('Your day'),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.bedtime_outlined),
                  title: const Text('Day starts at'),
                  subtitle: Text(p.dayStartMinutes == 0
                      ? 'Midnight'
                      : '${formatMinutes(p.dayStartMinutes)} · late nights count for the day before'),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
                  onTap: () => _pickDayStart(c),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.history_toggle_off_rounded),
                  title: const Text('Grace period for yesterday'),
                  subtitle: Text(_graceOptions[p.graceMinutes] ?? '${p.graceMinutes} minutes'),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
                  onTap: () => _pickGrace(c),
                ),
              ],
            ),
          ),
          const SectionTitle('Notifications'),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (_systemEnabled == false)
                  ListTile(
                    leading: const Icon(Icons.notifications_off_outlined, color: AppColors.error),
                    title: const Text('Notifications are blocked'),
                    subtitle: Text('Tap to allow them for ${AppConfig.appName}.'),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
                    onTap: _requestPermission,
                  ),
                SwitchListTile(
                  secondary: const Icon(Icons.alarm_rounded),
                  title: const Text('Habit reminders'),
                  subtitle: const Text('At the time set on each habit, with a "Mark done" button'),
                  value: p.remindersEnabled,
                  onChanged: (v) => c.setRemindersEnabled(v),
                ),
                const Divider(indent: 16, endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.nightlight_round),
                  title: const Text('Evening check-in'),
                  subtitle: Text(
                    p.checkInMinutes == null
                        ? 'Off'
                        : 'Daily at ${formatMinutes(p.checkInMinutes!)} unless the day is already perfect',
                  ),
                  value: p.checkInMinutes != null,
                  onChanged: (v) => v ? _pickCheckIn(c) : c.setCheckIn(null),
                ),
                if (p.checkInMinutes != null)
                  ListTile(
                    leading: const SizedBox(width: 24),
                    title: const Text('Check-in time'),
                    trailing: Text(formatMinutes(p.checkInMinutes!),
                        style: t.titleSmall?.copyWith(color: AppColors.goldDark)),
                    onTap: () => _pickCheckIn(c),
                  ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.send_rounded),
                  title: const Text('Send a test notification'),
                  onTap: () async {
                    await widget.notifications.showTest();
                    if (context.mounted) showSnack(context, 'Sent.');
                  },
                ),
              ],
            ),
          ),
          const SectionTitle('How rewards work'),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Rule(Icons.check_circle_outline_rounded,
                    "Each check-in pays ${RewardRules.perCompletion} tokens into that habit's own wallet."),
                _Rule(Icons.auto_awesome_rounded,
                    'Finish everything required in a day for +${RewardRules.perPerfectDay} shared tokens. Shared tokens work for any habit.'),
                _Rule(Icons.swap_horiz_rounded,
                    'Exchange ${RewardRules.exchangeRate} habit tokens for 1 shared token, any time.'),
                _Rule(Icons.local_fire_department_rounded,
                    'Weekday habits must be done on their days. "Days a week" habits can be done any day and only break after more than 7 minus n skipped days in a week.'),
                _Rule(Icons.build_circle_outlined,
                    "Missed something? Repair it within ${RewardRules.repairWindowDays} days for ${RewardRules.repairCostPerDay} tokens per missed day, paid from the habit's wallet first and shared tokens for the rest."),
                _Rule(Icons.workspace_premium_rounded,
                    "Milestones pay bonus tokens once, forever: global ones into shared, per-habit ones into that habit's wallet."),
              ],
            ),
          ),
          const SectionTitle('Your data'),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.ios_share_rounded),
                  title: const Text('Export everything as JSON'),
                  subtitle: const Text('Habits, check-ins, repairs and settings'),
                  enabled: !_busy,
                  onTap: () => _export(c),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: AppColors.error),
                  title: const Text('Delete account and data'),
                  subtitle: const Text('Permanent. Export first if you want a copy.'),
                  enabled: !_busy,
                  onTap: () => _deleteAccount(c),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign out'),
          ),
          const SizedBox(height: 16),
          Text(
            '${AppConfig.appName} · data lives in your own Firebase project',
            textAlign: TextAlign.center,
            style: t.bodySmall?.copyWith(color: AppColors.inkFaint),
          ),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.goldDeep),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
