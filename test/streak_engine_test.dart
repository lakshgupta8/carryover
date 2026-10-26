import 'package:flutter_test/flutter_test.dart';
import 'package:carryover/core/dates.dart';
import 'package:carryover/core/rewards.dart';
import 'package:carryover/features/habits/engine/streak_engine.dart';
import 'package:carryover/features/habits/models/day_record.dart';
import 'package:carryover/features/habits/models/habit.dart';
import 'package:carryover/features/habits/models/user_profile.dart';

Habit habit(
  String id, {
  Set<int> days = const {1, 2, 3, 4, 5, 6, 7},
  required String createdOn,
  String? archivedOn,
}) =>
    Habit(
      id: id,
      name: id,
      emoji: '✨',
      weekdays: days,
      createdOn: createdOn,
      archivedOn: archivedOn,
    );

Habit weeklyHabit(String id, int n, {required String createdOn}) => Habit(
      id: id,
      name: id,
      emoji: '✨',
      scheduleType: ScheduleType.weekly,
      timesPerWeek: n,
      weekdays: const {},
      createdOn: createdOn,
    );

/// Day records: `{'2026-09-01': ['a', 'b']}`. An entry `'~a'` marks habit
/// `a` as repaired that day (paid with 10 shared tokens).
Map<String, DayRecord> records(Map<String, List<String>> input) => {
      for (final e in input.entries)
        e.key: DayRecord(
          date: e.key,
          done: e.value.where((x) => !x.startsWith('~')).toSet(),
          repairs: {
            for (final x in e.value.where((x) => x.startsWith('~')))
              x.substring(1): const Payment(external: 10),
          },
        ),
    };

Map<String, WeekRecord> weekRepair(String weekKey, String habitId, int credits) =>
    {
      weekKey: WeekRecord(weekKey: weekKey, repairs: {
        habitId: WeekRepair(
          credits: credits,
          payment: Payment(external: credits * RewardRules.repairCostPerDay),
        ),
      }),
    };

Stats run({
  required List<Habit> habits,
  required Map<String, DayRecord> days,
  required DateTime today,
  Map<String, WeekRecord> weeks = const {},
  UserProfile profile = const UserProfile(),
  String? graceDay,
}) =>
    StreakEngine.compute(
      habits: habits,
      days: days,
      weeks: weeks,
      profile: profile,
      today: today,
      graceDay: graceDay,
    );

Map<String, List<String>> everyDay(String id, DateTime from, DateTime to) {
  final out = <String, List<String>>{};
  for (var d = from; !d.isAfter(to); d = addDays(d, 1)) {
    out[dateKey(d)] = [id];
  }
  return out;
}

void main() {
  group('dates', () {
    test('week starts on Monday', () {
      expect(dateKey(startOfWeek(DateTime(2026, 10, 3))), '2026-09-28');
      expect(dateKey(startOfWeek(DateTime(2026, 10, 4))), '2026-09-28');
      expect(dateKey(startOfWeek(DateTime(2026, 10, 5))), '2026-10-05');
    });

    test('formatMinutes', () {
      expect(formatMinutes(0), '12:00 AM');
      expect(formatMinutes(9 * 60 + 5), '9:05 AM');
      expect(formatMinutes(21 * 60), '9:00 PM');
    });
  });

  group('weekday habits', () {
    final a = habit('a', createdOn: '2026-10-01');

    test('consecutive perfect days count; pending today does not break', () {
      final s = run(
        habits: [a],
        days: records({
          '2026-10-01': ['a'],
          '2026-10-02': ['a'],
          '2026-10-03': ['a'],
        }),
        today: DateTime(2026, 10, 4),
      );
      expect(s.dailyStreak, 3);
      expect(s.bestDailyStreak, 3);
      expect(s.todayPerfect, isFalse);
      expect(s.days['2026-10-04']!.status, DayStatus.pending);
      expect(s.habitStat('a')!.requiredToday, isTrue);
    });

    test('a missed day breaks the streak and becomes a repair option', () {
      final s = run(
        habits: [a],
        days: records({
          '2026-10-01': ['a'],
          '2026-10-02': ['a'],
          // 03 missed
          '2026-10-04': ['a'],
        }),
        today: DateTime(2026, 10, 5),
      );
      expect(s.dailyStreak, 1);
      expect(s.bestDailyStreak, 2);
      final opt = s.repairOptions.single;
      expect(opt.isWeek, isFalse);
      expect(opt.key, '2026-10-03');
      expect(opt.units, 1);
      expect(opt.cost, RewardRules.repairCostPerDay);
      // 3 check-ins → 6 habit tokens; the rest comes from the shared wallet.
      expect(opt.payment.internal, 6);
      expect(opt.payment.external, 4);
      // 3 perfect days → 15 shared tokens, so it is affordable.
      expect(s.sharedBalance, 15);
      expect(opt.affordable, isTrue);
      expect(opt.habitStreakAfter, 4);
      expect(opt.dailyStreakAfter, 4);
    });

    test('a repaired day keeps streaks, costs tokens, is not a perfect day', () {
      final s = run(
        habits: [a],
        days: records({
          '2026-10-01': ['a'],
          '2026-10-02': ['a'],
          '2026-10-03': ['~a'],
          '2026-10-04': ['a'],
        }),
        today: DateTime(2026, 10, 5),
      );
      expect(s.dailyStreak, 4);
      expect(s.habitStat('a')!.current, 4);
      expect(s.repairOptions, isEmpty);
      expect(s.perfectDays, 3);
      expect(s.sharedSpent, 10);
      expect(s.sharedBalance, 15 - 10);
    });

    test('misses older than the repair window are not offered', () {
      final old = habit('a', createdOn: '2026-09-01');
      final s = run(
        habits: [old],
        days: records({
          '2026-09-01': ['a'],
          // 02 missed, long ago
          ...everyDay('a', DateTime(2026, 9, 3), DateTime(2026, 9, 30)),
        }),
        today: DateTime(2026, 9, 30),
      );
      expect(s.repairOptions, isEmpty);
      expect(s.dailyStreak, 28);
    });

    test('a day is perfect only when every required habit is done', () {
      final b = habit('b', createdOn: '2026-10-01');
      final s = run(
        habits: [a, b],
        days: records({
          '2026-10-01': ['a', 'b'],
          '2026-10-02': ['a'],
          '2026-10-03': ['a', 'b'],
        }),
        today: DateTime(2026, 10, 3),
      );
      expect(s.dailyStreak, 1);
      final opt = s.repairOptions.single;
      expect(opt.habit.id, 'b');
      expect(opt.dailyStreakAfter, 3, reason: 'b was the only miss that day');
      expect(s.habitStat('a')!.current, 3);
      expect(s.habitStat('b')!.current, 1);
    });

    test('unscheduled weekdays are neutral', () {
      final gym = habit('gym', days: {1, 3, 5}, createdOn: '2026-09-28');
      final s = run(
        habits: [gym],
        days: records({
          '2026-09-28': ['gym'],
          '2026-09-30': ['gym'],
          '2026-10-02': ['gym'],
        }),
        today: DateTime(2026, 10, 4), // Sunday
      );
      expect(s.dailyStreak, 3);
      expect(s.habitStat('gym')!.current, 3);
      expect(s.todayRequired, 0);
      expect(s.days['2026-10-04']!.status, DayStatus.neutral);
    });

    test('archived habits stop being required but keep history', () {
      final x = habit('x', createdOn: '2026-10-01', archivedOn: '2026-10-03');
      final b = habit('b', createdOn: '2026-10-01');
      final s = run(
        habits: [x, b],
        days: records({
          '2026-10-01': ['x', 'b'],
          '2026-10-02': ['x', 'b'],
          '2026-10-03': ['b'],
        }),
        today: DateTime(2026, 10, 3),
      );
      expect(s.dailyStreak, 3);
      expect(s.habitStats.map((h) => h.habit.id), ['b']);
      expect(s.totalCompletions, 5);
    });
  });

  group('weekly habits (n days a week)', () {
    // 2026-09-28 is a Monday.
    final run3 = weeklyHabit('run', 3, createdOn: '2026-09-28');

    test('becomes due only once all skips are used', () {
      final s = run(
        habits: [run3],
        days: records({
          '2026-09-28': ['run'],
          '2026-09-30': ['run'],
        }),
        today: DateTime(2026, 10, 4), // Sunday, 4 skips used (Tue Thu Fri Sat)
      );
      final hs = s.habitStat('run')!;
      expect(hs.requiredToday, isTrue);
      expect(hs.skipsUsedThisWeek, 4);
      expect(hs.skipsLeftThisWeek, 0);
      expect(hs.weekDone, 2);
      expect(hs.weekTarget, 3);
      expect(hs.current, 2, reason: 'streak counts check-ins');
      expect(s.days['2026-10-03']!.status, DayStatus.neutral,
          reason: 'Saturday still had a skip in hand');
      expect(s.days['2026-10-04']!.status, DayStatus.pending);
      expect(s.repairOptions, isEmpty);
    });

    test('a voluntary check-in on a free day is a perfect day', () {
      final s = run(
        habits: [run3],
        days: records({'2026-09-28': ['run']}),
        today: DateTime(2026, 9, 29),
      );
      expect(s.days['2026-09-28']!.perfect, isTrue);
      expect(s.days['2026-09-28']!.status, DayStatus.kept);
      expect(s.perfectDays, 1);
      expect(s.habitStat('run')!.skipsLeftThisWeek, 4,
          reason: 'Tue..Sun = 6 days left, 2 still needed');
      expect(s.days['2026-09-29']!.status, DayStatus.neutral,
          reason: 'nothing due, nothing done');
      expect(s.dailyStreak, 1);
    });

    test('more than 7-n skips breaks the streak; repair costs the extra days', () {
      final s = run(
        habits: [run3],
        days: records({'2026-09-28': ['run']}),
        today: DateTime(2026, 10, 4), // Sunday: skipped Tue..Sat = 5 > 4
      );
      expect(s.days['2026-10-03']!.habitStatus['run'], DayStatus.missed);
      expect(s.days['2026-10-03']!.status, DayStatus.missed);
      expect(s.habitStat('run')!.current, 0);
      expect(s.dailyStreak, 0);

      final opt = s.repairOptions.single;
      expect(opt.isWeek, isTrue);
      expect(opt.key, '2026-09-28');
      expect(opt.units, 1, reason: 'one more skip than allowed');
      expect(opt.cost, RewardRules.repairCostPerDay);
      expect(opt.habitStreakAfter, 1);
      expect(opt.dailyStreakAfter, 1);
    });

    test('a week repair restores the streak and reduces what is due', () {
      final s = run(
        habits: [run3],
        days: records({'2026-09-28': ['run']}),
        weeks: weekRepair('2026-09-28', 'run', 1),
        today: DateTime(2026, 10, 4),
      );
      expect(s.days['2026-10-03']!.habitStatus['run'], DayStatus.neutral);
      expect(s.days['2026-10-04']!.habitStatus['run'], DayStatus.pending,
          reason: 'still needs one check-in: 1 done + 1 credit of 3');
      expect(s.habitStat('run')!.current, 1);
      expect(s.habitStat('run')!.weekCredits, 1);
      expect(s.habitStat('run')!.requiredToday, isTrue);
      expect(s.repairOptions, isEmpty);
      expect(s.sharedSpent, 10);
    });

    test('a fully missed past week offers a repair for the whole shortfall', () {
      final s = run(
        habits: [run3],
        days: records({
          '2026-09-29': ['run'],
          ...everyDay('run', DateTime(2026, 10, 5), DateTime(2026, 10, 7)),
        }),
        today: DateTime(2026, 10, 8),
      );
      final weekOpt =
          s.repairOptions.where((o) => o.key == '2026-09-28').single;
      expect(weekOpt.units, 2);
      expect(weekOpt.cost, 20);
      expect(s.habitStat('run')!.current, 3, reason: 'new week after the break');
      expect(weekOpt.habitStreakAfter, 4);
    });

    test('target is capped by the days the habit exists in its first week', () {
      final late = weeklyHabit('late', 3, createdOn: '2026-10-03'); // Saturday
      final s = run(
        habits: [late],
        days: const {},
        today: DateTime(2026, 10, 3),
      );
      expect(s.habitStat('late')!.weekTarget, 2);
      expect(s.habitStat('late')!.requiredToday, isTrue);
      expect(s.habitStat('late')!.skipsLeftThisWeek, 0);
    });

    test('weekly streak milestones still work via day statuses', () {
      final daily = habit('a', createdOn: '2026-09-14');
      final s = run(
        habits: [daily, run3],
        days: records({
          for (final e in everyDay('a', DateTime(2026, 9, 14), DateTime(2026, 10, 3)).entries)
            e.key: [
              ...e.value,
              if (const {'2026-09-28', '2026-09-30', '2026-10-02'}.contains(e.key)) 'run',
            ],
        }),
        today: DateTime(2026, 10, 4),
      );
      expect(s.weeklyStreak, 2);
      expect(s.days['2026-10-02']!.perfect, isTrue);
    });
  });

  group('grace period and day boundary', () {
    final a = habit('a', createdOn: '2026-10-01');

    test('during grace, yesterday is still open: no break, no repair offer', () {
      final s = run(
        habits: [a],
        days: records({
          '2026-10-01': ['a'],
          '2026-10-02': ['a'],
          // 03 not ticked yet
        }),
        today: DateTime(2026, 10, 4),
        graceDay: '2026-10-03',
      );
      expect(s.days['2026-10-03']!.status, DayStatus.pending);
      expect(s.graceDayEval!.missed.map((h) => h.id), ['a']);
      expect(s.dailyStreak, 2);
      expect(s.repairOptions, isEmpty);
    });

    test('after grace ends the same day is a miss with a repair offer', () {
      final s = run(
        habits: [a],
        days: records({
          '2026-10-01': ['a'],
          '2026-10-02': ['a'],
        }),
        today: DateTime(2026, 10, 4),
      );
      expect(s.days['2026-10-03']!.status, DayStatus.missed);
      expect(s.repairOptions.single.key, '2026-10-03');
    });

    test('logical day honours the day-start setting', () {
      expect(dateKey(logicalDay(DateTime(2026, 10, 5, 0, 30), 180)), '2026-10-04');
      expect(dateKey(logicalDay(DateTime(2026, 10, 5, 3, 0), 180)), '2026-10-05');
      expect(minutesIntoLogicalDay(DateTime(2026, 10, 5, 4, 15), 180), 75);
    });

    test('schedule labels read naturally', () {
      expect(habit('x', days: {1, 2, 3, 4, 5, 6}, createdOn: '2026-10-01').scheduleLabel,
          'Every day except Sun');
      expect(habit('x', days: {3}, createdOn: '2026-10-01').scheduleLabel, 'Weds');
      expect(habit('x', days: {1, 2, 3, 4, 5}, createdOn: '2026-10-01').scheduleLabel, 'Weekdays');
      expect(weeklyHabit('x', 1, createdOn: '2026-10-01').scheduleLabel, 'Once a week');
    });
  });

  group('wallets', () {
    final a = habit('a', createdOn: '2026-10-01');
    final b = habit('b', createdOn: '2026-10-01');

    test('habit tokens, shared tokens and exchanges are derived', () {
      final profile = UserProfile(
        claimed: {
          'daily:3': ClaimedMilestone(key: 'daily:3', reward: 10, at: DateTime(2026)),
          'habit:a:7': ClaimedMilestone(key: 'habit:a:7', reward: 10, at: DateTime(2026)),
        },
        exchanged: const {'a': 4},
      );
      final s = run(
        habits: [a, b],
        days: records({
          '2026-10-01': ['a', 'b'],
          '2026-10-02': ['a', 'b'],
          '2026-10-03': ['a', '~b'],
          '2026-10-04': ['a', 'b'],
        }),
        today: DateTime(2026, 10, 4),
        profile: profile,
      );
      final wa = s.habitStat('a')!;
      final wb = s.habitStat('b')!;
      expect(wa.internalEarned, 8);
      expect(wa.internalFromMilestones, 10);
      expect(wa.exchanged, 4);
      expect(wa.internalBalance, 8 + 10 - 4);
      expect(wb.internalEarned, 6);
      expect(wb.internalSpent, 0, reason: 'repair was paid from shared');
      expect(wb.internalBalance, 6);

      expect(s.perfectDays, 3);
      expect(s.sharedFromPerfectDays, 15);
      expect(s.sharedFromMilestones, 10);
      expect(s.sharedFromExchanges, 2);
      expect(s.sharedSpent, 10);
      expect(s.sharedBalance, 15 + 10 + 2 - 10);
    });

    test('repair payment prefers the habit wallet and reports affordability', () {
      final s = run(
        habits: [a],
        days: records({
          '2026-10-01': ['a'],
          // 02 missed
        }),
        today: DateTime(2026, 10, 3),
      );
      final opt = s.repairOptions.single;
      expect(opt.payment.internal, 2);
      expect(opt.payment.external, 8);
      expect(s.sharedBalance, 5);
      expect(opt.affordable, isFalse);
    });

    test('reached milestones use best streaks and totals', () {
      final s = run(
        habits: [habit('a', createdOn: '2026-09-20')],
        days: records(everyDay('a', DateTime(2026, 9, 20), DateTime(2026, 9, 29))),
        today: DateTime(2026, 9, 29),
      );
      expect(s.dailyStreak, 10);
      expect(s.reached.keys,
          containsAll(['daily:3', 'daily:7', 'done:10', 'habit:a:7']));
      expect(s.reached.containsKey('daily:14'), isFalse);
      expect(s.reached['habit:a:7']!.habitId, 'a');
    });

    test('no habits yields an empty, non-crashing result', () {
      final s = run(habits: const [], days: const {}, today: DateTime(2026, 10, 3));
      expect(s.sharedBalance, 0);
      expect(s.habitStats, isEmpty);
      expect(s.repairOptions, isEmpty);
    });
  });
}
