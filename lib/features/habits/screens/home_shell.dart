import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/auth_service.dart';
import '../../notifications/notification_service.dart';
import '../data/habit_controller.dart';
import '../data/habit_repository.dart';
import '../widgets/celebration_dialog.dart';
import 'habits_screen.dart';
import 'rewards_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';

/// Signed-in root: owns the controller and the bottom navigation.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.user,
    required this.auth,
    required this.notifications,
  });

  final User user;
  final AuthService auth;
  final NotificationService notifications;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final HabitRepository _repo;
  late final HabitController _controller;
  int _tab = 0;
  bool _celebrating = false;
  bool _askedPermission = false;

  @override
  void initState() {
    super.initState();
    _repo = HabitRepository(uid: widget.user.uid);
    _controller = HabitController(
      repo: _repo,
      notifications: widget.notifications,
    )..start();
    _repo.ensureProfile(
      email: widget.user.email,
      displayName: widget.user.displayName,
    );
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!_askedPermission && _controller.isLoaded) {
      _askedPermission = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await widget.notifications.requestPermission();
        _controller.resyncNotifications();
      });
    }
    if (!_celebrating && _controller.celebrations.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _celebrate());
    }
  }

  Future<void> _celebrate() async {
    if (!mounted || _celebrating || _controller.celebrations.isEmpty) return;
    _celebrating = true;
    final items = List.of(_controller.celebrations);
    _controller.dismissCelebrations();
    await CelebrationDialog.show(context, items);
    _celebrating = false;
    if (mounted) _celebrate();
  }

  @override
  Widget build(BuildContext context) {
    return ControllerScope(
      controller: _controller,
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            TodayScreen(onOpenRewards: () => setState(() => _tab = 2)),
            const HabitsScreen(),
            const RewardsScreen(),
            SettingsScreen(
              user: widget.user,
              auth: widget.auth,
              notifications: widget.notifications,
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.wb_sunny_outlined),
                selectedIcon: Icon(Icons.wb_sunny_rounded),
                label: 'Today',
              ),
              NavigationDestination(
                icon: Icon(Icons.checklist_rounded),
                label: 'Habits',
              ),
              NavigationDestination(
                icon: Icon(Icons.workspace_premium_outlined),
                selectedIcon: Icon(Icons.workspace_premium_rounded),
                label: 'Rewards',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
