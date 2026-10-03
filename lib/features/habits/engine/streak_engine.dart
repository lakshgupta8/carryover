import 'dart:math' as math;

import '../../../core/dates.dart';
import '../../../core/rewards.dart';
import '../models/day_record.dart';
import '../models/habit.dart';
import '../models/user_profile.dart';

/// Outcome of one calendar day (or one week / month) for streak purposes.
enum DayStatus {
  /// Nothing was required and nothing happened; neither helps nor hurts.
  neutral,

  /// Everything required was done (or repaired), or something was done on a
  /// day with no requirements.
  kept,

  /// Today, still in progress.
  pending,

  /// Something required was missed and not repaired.
  missed,
}

class DayEval {
  const DayEval({
    required this.key,
    required this.date,
    required this.required,
    required this.done,
    required this.missed,
    required this.activity,
    required this.perfect,
    required this.status,
    required this.habitStatus,
  });

  final String key;
  final DateTime date;

  /// Habits that had to be done this day: weekday habits scheduled on it and
  /// weekly habits that were *due* (no skips left in their week).
  final List<Habit> required;
  final Set<String> done;

  /// Required habits that were neither done nor repaired.
  final List<Habit> missed;

  /// Number of check-ins that day.
  final int activity;

  /// Everything required was actually done (repairs don't count) and at
  /// least something happened. Earns the perfect-day bonus.
  final bool perfect;
  final DayStatus status;

  /// Per-habit outcome for that day, for per-habit streaks.
  final Map<String, DayStatus> habitStatus;
}

class HabitStats {
  const HabitStats({
    required this.habit,
    required this.current,
    required this.best,
    required this.totalDone,
    required this.requiredToday,
    required this.doneToday,
    this.doneTodayAt,
    required this.weekDone,
    required this.weekCredits,
    required this.weekTarget,
    required this.skipsUsedThisWeek,
    required this.daysLeftInWeek,
    required this.internalEarned,
    required this.internalFromMilestones,
    required this.internalSpent,
    required this.exchanged,
  });

  final Habit habit;
  final int current;
  final int best;
  final int totalDone;

  /// Must be done today (scheduled weekday, or weekly habit that is due).
  final bool requiredToday;
  final bool doneToday;

  /// When today's check-in happened, if known.
  final DateTime? doneTodayAt;

  /// Weekly-habit bookkeeping for the current week.
  final int weekDone;
  final int weekCredits;
  final int weekTarget;
  final int skipsUsedThisWeek;

  /// Days of the current week still available for a check-in (today counts
  /// unless it is already done).
  final int daysLeftInWeek;

  final int internalEarned;
  final int internalFromMilestones;
  final int internalSpent;
  final int exchanged;

  int get internalBalance =>
      internalEarned + internalFromMilestones - internalSpent - exchanged;

  /// How many of the remaining days this week may still be skipped.
  int get skipsLeftThisWeek {
    final needed = math.max(0, weekTarget - weekDone - weekCredits);
    return math.max(0, daysLeftInWeek - needed);
  }

  bool get weekTargetMet => weekDone + weekCredits >= weekTarget;
}

/// A miss the user can still buy back.
class RepairOption {
  const RepairOption({
    required this.habit,
    required this.isWeek,
    required this.key,
    required this.date,
    required this.units,
    required this.payment,
    required this.affordable,
    required this.habitStreakAfter,
    required this.dailyStreakAfter,
  });

  final Habit habit;

  /// Week repair (weekly habit) vs. single-day repair (weekday habit).
  final bool isWeek;

  /// `yyyy-MM-dd` of the day, or of the week's Monday.
  final String key;
  final DateTime date;

  /// Missed days being bought back (always 1 for a day repair).
  final int units;

  /// How it would be paid right now: habit wallet first, then shared.
  final Payment payment;
  final bool affordable;
  final int habitStreakAfter;
  final int dailyStreakAfter;

  int get cost => payment.total;
}

class Stats {
  const Stats({
    required this.todayKey,
    this.graceDay,
    required this.habitStats,
    required this.todayRequired,
    required this.todayDone,
    required this.dailyStreak,
    required this.bestDailyStreak,
    required this.weeklyStreak,
    required this.bestWeeklyStreak,
    required this.monthlyStreak,
    required this.bestMonthlyStreak,
    required this.perfectDays,
    required this.totalCompletions,
    required this.sharedFromMilestones,
    required this.sharedFromExchanges,
    required this.sharedSpent,
    required this.repairOptions,
    required this.reached,
    required this.days,
  });

  final String todayKey;

  /// Yesterday's key while the grace period is active, else null.
  final String? graceDay;
  final List<HabitStats> habitStats;
  final int todayRequired;
  final int todayDone;
  final int dailyStreak;
  final int bestDailyStreak;
  final int weeklyStreak;
  final int bestWeeklyStreak;
  final int monthlyStreak;
  final int bestMonthlyStreak;
  final int perfectDays;
  final int totalCompletions;
  final int sharedFromMilestones;
  final int sharedFromExchanges;
  final int sharedSpent;
  final List<RepairOption> repairOptions;

  /// Every milestone whose threshold has been reached, keyed by milestone key.
  final Map<String, Milestone> reached;

  /// Day evaluations keyed by `yyyy-MM-dd`, oldest first in iteration order.
  final Map<String, DayEval> days;

  DayEval? get today => days[todayKey];

  /// Yesterday's evaluation while it can still be ticked for free.
  DayEval? get graceDayEval => graceDay == null ? null : days[graceDay!];

  bool get todayPerfect => today?.perfect ?? false;

  int get sharedFromPerfectDays => perfectDays * RewardRules.perPerfectDay;
  int get sharedEarned =>
      sharedFromPerfectDays + sharedFromMilestones + sharedFromExchanges;
  int get sharedBalance => sharedEarned - sharedSpent;

  int get totalHabitTokens =>
      habitStats.fold(0, (s, h) => s + h.internalBalance);

  HabitStats? habitStat(String habitId) {
    for (final h in habitStats) {
      if (h.habit.id == habitId) return h;
    }
    return null;
  }

  /// Current progress toward a milestone, for progress bars.
  int progressFor(Milestone m, {String? habitId}) {
    switch (m.kind) {
      case MilestoneKind.daily:
        return dailyStreak;
      case MilestoneKind.weekly:
        return weeklyStreak;
      case MilestoneKind.monthly:
        return monthlyStreak;
      case MilestoneKind.completions:
        return totalCompletions;
      case MilestoneKind.habit:
        return habitStat(habitId ?? m.habitId ?? '')?.current ?? 0;
    }
  }

  static Stats empty(String todayKey, UserProfile profile) => Stats(
        todayKey: todayKey,
        habitStats: const [],
        todayRequired: 0,
        todayDone: 0,
        dailyStreak: 0,
        bestDailyStreak: 0,
        weeklyStreak: 0,
        bestWeeklyStreak: 0,
        monthlyStreak: 0,
        bestMonthlyStreak: 0,
        perfectDays: 0,
        totalCompletions: 0,
        sharedFromMilestones: profile.sharedFromMilestones,
        sharedFromExchanges: 0,
        sharedSpent: 0,
        repairOptions: const [],
        reached: const {},
        days: const {},
      );
}

/// Display order: the user's manual order, then creation order. Never by
/// name, so two habits with the same sort position stay in the order they
/// were added.
int compareHabitOrder(Habit a, Habit b) {
  final c = a.sortOrder.compareTo(b.sortOrder);
  if (c != 0) return c;
  final d = a.createdOn.compareTo(b.createdOn);
  return d != 0 ? d : a.id.compareTo(b.id);
}

class _Run {
  const _Run(this.current, this.best);
  final int current;
  final int best;
}

/// Pure functions that turn raw habits + records into streaks, wallets and
/// milestones. Everything is derived, so there is no counter to drift.
class StreakEngine {
  StreakEngine._();

  static Stats compute({
    required List<Habit> habits,
    required Map<String, DayRecord> days,
    required Map<String, WeekRecord> weeks,
    required UserProfile profile,
    required DateTime today,
    String? graceDay,
  }) {
    final todayD = dateOnly(today);
    final todayKey = dateKey(todayD);
    // Days that are still open: today, plus yesterday during the grace period.
    bool isOpen(String key) => key == todayKey || key == graceDay;
    if (habits.isEmpty) return Stats.empty(todayKey, profile);

    var firstKey = habits.first.createdOn;
    for (final h in habits) {
      if (h.createdOn.compareTo(firstKey) < 0) firstKey = h.createdOn;
    }
    var start = parseDateKey(firstKey);
    if (start.isAfter(todayD)) start = todayD;

    int credits(String weekKey, String habitId) =>
        weeks[weekKey]?.repairs[habitId]?.credits ?? 0;

    // ---- Day evaluations -------------------------------------------------
    final evals = <DayEval>[];
    final weekDoneRunning = <String, int>{};
    String? runningWeek;
    for (var d = start; !d.isAfter(todayD); d = addDays(d, 1)) {
      final key = dateKey(d);
      final wk = weekKey(d);
      if (wk != runningWeek) {
        runningWeek = wk;
        weekDoneRunning.clear();
      }
      final rec = days[key];
      final done = rec?.done ?? const <String>{};
      final repairs = rec?.repairs ?? const <String, Payment>{};

      final required = <Habit>[];
      final habitStatus = <String, DayStatus>{};
      var activity = 0;
      for (final h in habits) {
        if (!h.isActiveOn(d)) {
          habitStatus[h.id] = DayStatus.neutral;
          continue;
        }
        final didIt = done.contains(h.id);
        if (didIt) activity++;
        if (h.isWeekly) {
          final target = _effectiveTarget(h, d);
          final before = (weekDoneRunning[h.id] ?? 0) + credits(wk, h.id);
          final needed = target - before;
          final remainingIncl = 8 - d.weekday;
          final due = needed > 0 && needed >= remainingIncl;
          if (due) required.add(h);
          habitStatus[h.id] = didIt
              ? DayStatus.kept
              : due
                  ? (isOpen(key) ? DayStatus.pending : DayStatus.missed)
                  : DayStatus.neutral;
          if (didIt) weekDoneRunning[h.id] = (weekDoneRunning[h.id] ?? 0) + 1;
        } else {
          final scheduled = h.weekdays.contains(d.weekday);
          if (scheduled) required.add(h);
          final satisfied = didIt || repairs.containsKey(h.id);
          habitStatus[h.id] = !scheduled
              ? DayStatus.neutral
              : satisfied
                  ? DayStatus.kept
                  : (isOpen(key) ? DayStatus.pending : DayStatus.missed);
        }
      }

      final missed = required
          .where((h) => habitStatus[h.id] != DayStatus.kept)
          .toList();
      final perfect = required.every((h) => done.contains(h.id)) &&
          (required.isNotEmpty || activity > 0);
      DayStatus status;
      if (required.isEmpty) {
        status = activity > 0 ? DayStatus.kept : DayStatus.neutral;
      } else if (missed.isEmpty) {
        status = DayStatus.kept;
      } else if (isOpen(key)) {
        status = DayStatus.pending;
      } else {
        status = DayStatus.missed;
      }

      evals.add(DayEval(
        key: key,
        date: d,
        required: required,
        done: done,
        missed: missed,
        activity: activity,
        perfect: perfect,
        status: status,
        habitStatus: habitStatus,
      ));
    }

    final dayStatuses = evals.map((e) => e.status).toList();
    final daily = _runs(dayStatuses);
    final weekly = _runs(_periodStatuses(evals, todayD, isWeek: true));
    final monthly = _runs(_periodStatuses(evals, todayD, isWeek: false));

    // ---- Per-habit --------------------------------------------------------
    final habitIds = habits.map((h) => h.id).toSet();
    final thisWeek = weekKey(todayD);
    final habitStats = <HabitStats>[];
    final habitBest = <String, int>{};
    final habitRuns = <String, _Run>{};
    var sharedSpent = 0;
    for (final h in habits) {
      final statuses = evals.map((e) => e.habitStatus[h.id]!).toList();
      final run = _runs(statuses);
      habitBest[h.id] = run.best;
      habitRuns[h.id] = run;

      var total = 0;
      var weekDone = 0;
      var skipsUsed = 0;
      var internalSpent = 0;
      for (final e in evals) {
        final didIt = e.done.contains(h.id);
        if (didIt) total++;
        final p = days[e.key]?.repairs[h.id];
        if (p != null) {
          internalSpent += p.internal;
          sharedSpent += p.external;
        }
        if (weekKey(e.date) == thisWeek && h.isActiveOn(e.date)) {
          if (didIt) {
            weekDone++;
          } else if (!isOpen(e.key) && h.isWeekly) {
            skipsUsed++;
          }
        }
      }
      for (final w in weeks.values) {
        final r = w.repairs[h.id];
        if (r != null) {
          internalSpent += r.payment.internal;
          sharedSpent += r.payment.external;
        }
      }

      if (!h.isArchived) {
        final todayEval = evals.last;
        habitStats.add(HabitStats(
          habit: h,
          current: run.current,
          best: run.best,
          totalDone: total,
          requiredToday: todayEval.required.any((x) => x.id == h.id),
          doneToday: todayEval.done.contains(h.id),
          doneTodayAt: days[todayKey]?.doneAt[h.id],
          weekDone: weekDone,
          weekCredits: credits(thisWeek, h.id),
          weekTarget: h.isWeekly ? _effectiveTarget(h, todayD) : 0,
          skipsUsedThisWeek: skipsUsed,
          daysLeftInWeek: (8 - todayD.weekday) -
              (todayEval.done.contains(h.id) ? 1 : 0),
          internalEarned: total * RewardRules.perCompletion,
          internalFromMilestones: profile.habitMilestoneTokens(h.id),
          internalSpent: internalSpent,
          exchanged: profile.exchanged[h.id] ?? 0,
        ));
      }
    }
    habitStats.sort((a, b) => compareHabitOrder(a.habit, b.habit));

    // ---- Shared wallet ----------------------------------------------------
    var completions = 0;
    var perfectDays = 0;
    for (final e in evals) {
      completions += e.done.where(habitIds.contains).length;
      if (e.perfect) perfectDays++;
    }
    final sharedFromExchanges = profile.exchanged.values
        .fold<int>(0, (s, v) => s + v ~/ RewardRules.exchangeRate);
    final sharedBalance = perfectDays * RewardRules.perPerfectDay +
        profile.sharedFromMilestones +
        sharedFromExchanges -
        sharedSpent;

    // ---- Repair options ---------------------------------------------------
    final windowStart = addDays(todayD, -RewardRules.repairWindowDays);
    final options = <RepairOption>[];

    RepairOption buildOption({
      required Habit habit,
      required bool isWeek,
      required String key,
      required DateTime date,
      required int units,
    }) {
      final cost = units * RewardRules.repairCostPerDay;
      final wallet = habitStats
          .where((s) => s.habit.id == habit.id)
          .map((s) => s.internalBalance)
          .fold(0, (a, b) => a + b);
      final internal = math.min(cost, math.max(0, wallet));
      final external = cost - internal;

      // What changes if this repair is applied.
      bool covers(DayEval e) =>
          isWeek ? weekKey(e.date) == key : e.key == key;
      final patchedHabit = evals
          .map((e) => covers(e) && e.habitStatus[habit.id] == DayStatus.missed
              ? (isWeek ? DayStatus.neutral : DayStatus.kept)
              : e.habitStatus[habit.id]!)
          .toList();
      final patchedDays = evals.map((e) {
        if (e.status == DayStatus.missed &&
            covers(e) &&
            e.missed.every((m) => m.id == habit.id)) {
          // A week repair removes the requirement rather than fulfilling it,
          // so a day that required nothing else becomes neutral.
          final nothingElseRequired =
              e.required.every((r) => r.id == habit.id);
          if (isWeek && nothingElseRequired && e.activity == 0) {
            return DayStatus.neutral;
          }
          return DayStatus.kept;
        }
        return e.status;
      }).toList();

      return RepairOption(
        habit: habit,
        isWeek: isWeek,
        key: key,
        date: date,
        units: units,
        payment: Payment(internal: internal, external: external),
        affordable: external <= sharedBalance,
        habitStreakAfter: _runs(patchedHabit).current,
        dailyStreakAfter: _runs(patchedDays).current,
      );
    }

    // Single-day repairs for weekday habits.
    for (final e in evals.reversed) {
      if (isOpen(e.key)) continue; // today, or yesterday during grace
      if (e.date.isBefore(windowStart)) break;
      for (final h in e.missed) {
        if (h.isWeekly) continue;
        options.add(buildOption(
          habit: h,
          isWeek: false,
          key: e.key,
          date: e.date,
          units: 1,
        ));
      }
    }

    // Week repairs for weekly habits: current week plus recent past weeks.
    for (final h in habits) {
      if (!h.isWeekly || h.isArchived) continue;
      for (var monday = startOfWeek(todayD);
          !endOfWeek(monday).isBefore(windowStart) &&
              !endOfWeek(monday).isBefore(parseDateKey(h.createdOn));
          monday = addDays(monday, -7)) {
        final wk = dateKey(monday);
        final isCurrent = wk == thisWeek;
        var done = 0;
        for (final e in evals) {
          if (weekKey(e.date) == wk && e.done.contains(h.id)) done++;
        }
        final target = _effectiveTarget(h, monday);
        final needed = target - done - credits(wk, h.id);
        final shortfall = isCurrent
            ? math.max(0, needed - (8 - todayD.weekday))
            : math.max(0, needed);
        if (shortfall > 0) {
          options.add(buildOption(
            habit: h,
            isWeek: true,
            key: wk,
            date: monday,
            units: shortfall,
          ));
        }
      }
    }
    options.sort((a, b) => b.date.compareTo(a.date));

    // ---- Milestones -------------------------------------------------------
    final reached = <String, Milestone>{};
    for (final m in Milestones.global) {
      final value = switch (m.kind) {
        MilestoneKind.daily => daily.best,
        MilestoneKind.weekly => weekly.best,
        MilestoneKind.monthly => monthly.best,
        MilestoneKind.completions => completions,
        MilestoneKind.habit => 0,
      };
      if (value >= m.threshold) reached[m.key] = m;
    }
    for (final h in habits) {
      final best = habitBest[h.id] ?? 0;
      for (final tier in Milestones.habitTiers) {
        if (best >= tier.threshold) {
          final m = Milestones.habitMilestone(h.id, h.name, tier);
          reached[m.key] = m;
        }
      }
    }

    final todayEval = evals.last;
    return Stats(
      todayKey: todayKey,
      graceDay: graceDay,
      habitStats: habitStats,
      todayRequired: todayEval.required.length,
      todayDone: todayEval.required
          .where((h) => todayEval.done.contains(h.id))
          .length,
      dailyStreak: daily.current,
      bestDailyStreak: daily.best,
      weeklyStreak: weekly.current,
      bestWeeklyStreak: weekly.best,
      monthlyStreak: monthly.current,
      bestMonthlyStreak: monthly.best,
      perfectDays: perfectDays,
      totalCompletions: completions,
      sharedFromMilestones: profile.sharedFromMilestones,
      sharedFromExchanges: sharedFromExchanges,
      sharedSpent: sharedSpent,
      repairOptions: options,
      reached: reached,
      days: {for (final e in evals) e.key: e},
    );
  }

  /// A weekly habit's target for the week containing [day], capped by how
  /// many days of that week the habit actually exists (so a habit created on
  /// Saturday is not asked for three check-ins by Sunday).
  static int _effectiveTarget(Habit h, DateTime day) {
    final monday = startOfWeek(day);
    var activeDays = 0;
    for (var i = 0; i < 7; i++) {
      if (h.isActiveOn(addDays(monday, i))) activeDays++;
    }
    return math.min(h.timesPerWeek, activeDays);
  }

  /// Current run (walking back from the end, skipping neutral/pending) and
  /// the best run ever.
  static _Run _runs(List<DayStatus> statuses) {
    var current = 0;
    for (var i = statuses.length - 1; i >= 0; i--) {
      final s = statuses[i];
      if (s == DayStatus.kept) {
        current++;
      } else if (s == DayStatus.missed) {
        break;
      }
    }
    var best = 0;
    var run = 0;
    for (final s in statuses) {
      if (s == DayStatus.kept) {
        run++;
        best = math.max(best, run);
      } else if (s == DayStatus.missed) {
        run = 0;
      }
    }
    return _Run(current, best);
  }

  /// Collapses day evaluations into calendar weeks (Mon–Sun) or months.
  /// A period is kept only when every day in it was kept or neutral and the
  /// period has fully elapsed.
  static List<DayStatus> _periodStatuses(
    List<DayEval> evals,
    DateTime today, {
    required bool isWeek,
  }) {
    final result = <DayStatus>[];
    String? currentKey;
    DateTime? periodEnd;
    var anyMissed = false;
    var anyKept = false;
    var anyPending = false;

    void flush() {
      if (currentKey == null) return;
      if (anyMissed) {
        result.add(DayStatus.missed);
      } else if (!anyKept && !anyPending) {
        result.add(DayStatus.neutral);
      } else if (anyPending || periodEnd!.isAfter(today)) {
        result.add(DayStatus.pending);
      } else {
        result.add(DayStatus.kept);
      }
    }

    for (final e in evals) {
      final key = isWeek ? weekKey(e.date) : monthKey(e.date);
      if (key != currentKey) {
        flush();
        currentKey = key;
        periodEnd = isWeek ? endOfWeek(e.date) : endOfMonth(e.date);
        anyMissed = false;
        anyKept = false;
        anyPending = false;
      }
      switch (e.status) {
        case DayStatus.missed:
          anyMissed = true;
        case DayStatus.kept:
          anyKept = true;
        case DayStatus.pending:
          anyPending = true;
        case DayStatus.neutral:
          break;
      }
    }
    flush();
    return result;
  }
}
