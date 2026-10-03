import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/theme/app_theme.dart';
import 'package:habit_tracker/features/habits/engine/streak_engine.dart';
import 'package:habit_tracker/features/habits/models/day_record.dart';
import 'package:habit_tracker/features/habits/models/habit.dart';
import 'package:habit_tracker/features/habits/widgets/habit_tile.dart';
import 'package:habit_tracker/features/habits/widgets/repair_card.dart';

/// Renders [child] the way the app does, on a narrow phone, so that any
/// RenderFlex overflow surfaces as a test failure.
Future<void> pumpOnPhone(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: ListView(padding: const EdgeInsets.all(20), children: [child]),
    ),
  ));
  await tester.pump();
}

Habit habit(String name, {bool weekly = false, int? reminder}) => Habit(
      id: name,
      name: name,
      emoji: '📖',
      scheduleType: weekly ? ScheduleType.weekly : ScheduleType.weekdays,
      timesPerWeek: 3,
      weekdays: const {1, 2, 3, 4, 5, 6, 7},
      createdOn: '2026-09-01',
      reminderMinutes: reminder,
    );

HabitStats stats(Habit h, {bool done = false, bool required = true}) =>
    HabitStats(
      habit: h,
      current: 123,
      best: 200,
      totalDone: 50,
      requiredToday: required,
      doneToday: done,
      weekDone: 1,
      weekCredits: 0,
      weekTarget: 3,
      skipsUsedThisWeek: 2,
      daysLeftInWeek: 4,
      internalEarned: 100,
      internalFromMilestones: 10,
      internalSpent: 0,
      exchanged: 0,
    );

RepairOption option(Habit h, {bool week = false, int units = 1}) =>
    RepairOption(
      habit: h,
      isWeek: week,
      key: '2026-09-28',
      date: DateTime(2026, 9, 28),
      units: units,
      payment: Payment(internal: 4, external: units * 10 - 4),
      affordable: true,
      habitStreakAfter: 12,
      dailyStreakAfter: 9,
    );

void main() {
  testWidgets('habit tile with a long name and weekly label fits', (tester) async {
    final h = habit(
      'A fairly long habit name that should ellipsise instead of overflowing',
      weekly: true,
      reminder: 21 * 60 + 30,
    );
    await pumpOnPhone(tester, HabitTile(stats: stats(h), onToggle: () {}));
    expect(tester.takeException(), isNull);
    expect(find.text('DUE'), findsOneWidget);
    expect(find.textContaining('1/3 this week'), findsOneWidget);
  });

  testWidgets('day repair card with several habits fits', (tester) async {
    final options = [
      option(habit('Drink a full glass of water first thing')),
      option(habit('Walk')),
      option(habit('Stretch')),
    ];
    await pumpOnPhone(
      tester,
      DayRepairCard(
        dateKey: '2026-09-28',
        options: options,
        sharedBalance: 50,
        onRepair: (_) async {},
        onRepairAll: () async {},
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Repair all'), findsOneWidget);
  });

  testWidgets('week repair card fits and explains the shortfall', (tester) async {
    await pumpOnPhone(
      tester,
      WeekRepairCard(
        option: option(habit('Run', weekly: true), week: true, units: 2),
        sharedBalance: 3,
        onRepair: (_) async {},
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Skipped 2 days more'), findsOneWidget);
    expect(find.textContaining('Repair · 20'), findsOneWidget);
  });
}
