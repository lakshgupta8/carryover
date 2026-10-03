import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../core/dates.dart';
import '../../../core/rewards.dart';
import '../../notifications/notification_service.dart';
import '../engine/streak_engine.dart';
import '../models/day_record.dart';
import '../models/habit.dart';
import '../models/user_profile.dart';
import 'habit_repository.dart';

/// Holds live data for the signed-in user, derives [Stats], auto-claims
/// milestones and keeps notifications in sync.
class HabitController extends ChangeNotifier {
  HabitController({required this.repo, required this.notifications});

  final HabitRepository repo;
  final NotificationService notifications;

  List<Habit> _habits = const [];
  Map<String, DayRecord> _days = const {};
  Map<String, WeekRecord> _weeks = const {};
  UserProfile _profile = const UserProfile();
  bool _habitsLoaded = false;
  bool _daysLoaded = false;
  bool _weeksLoaded = false;
  bool _profileLoaded = false;
  Object? _error;

  Stats _stats = Stats.empty(dateKey(DateTime.now()), const UserProfile());

  /// Milestones claimed since the UI last called [dismissCelebrations].
  final List<Milestone> celebrations = [];
  final Set<String> _claiming = {};

  final List<StreamSubscription<void>> _subs = [];
  Timer? _tick;
  Timer? _syncDebounce;
  String? _lastSyncSignature;
  bool _disposed = false;

  // ---- Read side ----------------------------------------------------------

  bool get isLoaded =>
      _habitsLoaded && _daysLoaded && _weeksLoaded && _profileLoaded;
  Object? get error => _error;
  Stats get stats => _stats;
  UserProfile get profile => _profile;
  String get todayKey => _stats.todayKey;

  /// The current logical day, honouring the "day starts at" setting.
  DateTime get logicalToday =>
      logicalDay(DateTime.now(), _profile.dayStartMinutes);

  /// Yesterday's key while it can still be ticked for free, else null.
  String? get graceDay {
    if (_profile.graceMinutes <= 0) return null;
    final into = minutesIntoLogicalDay(DateTime.now(), _profile.dayStartMinutes);
    if (into >= _profile.graceMinutes) return null;
    return dateKey(addDays(logicalToday, -1));
  }

  /// When the current grace period ends, for display.
  DateTime? get graceEndsAt {
    if (graceDay == null) return null;
    final start = logicalToday.add(Duration(minutes: _profile.dayStartMinutes));
    return start.add(Duration(minutes: _profile.graceMinutes));
  }

  List<Habit> get activeHabits =>
      _habits.where((h) => !h.isArchived).toList()..sort(compareHabitOrder);

  List<Habit> get archivedHabits =>
      _habits.where((h) => h.isArchived).toList()
        ..sort((a, b) => (b.archivedOn ?? '').compareTo(a.archivedOn ?? ''));

  Habit? habitById(String id) {
    for (final h in _habits) {
      if (h.id == id) return h;
    }
    return null;
  }

  bool isDone(String habitId, String dateKey) =>
      _days[dateKey]?.done.contains(habitId) ?? false;

  bool isDoneToday(String habitId) => isDone(habitId, todayKey);

  // ---- Lifecycle ----------------------------------------------------------

  void start() {
    notifications.onMarkDone = (habitId, _) => markDone(habitId, todayKey);
    _subs.add(repo.watchHabits().listen((h) {
      _habits = h;
      _habitsLoaded = true;
      _recompute();
    }, onError: _onError));
    _subs.add(repo.watchDays().listen((d) {
      _days = d;
      _daysLoaded = true;
      _recompute();
    }, onError: _onError));
    _subs.add(repo.watchWeeks().listen((w) {
      _weeks = w;
      _weeksLoaded = true;
      _recompute();
    }, onError: _onError));
    _subs.add(repo.watchProfile().listen((p) {
      _profile = p;
      _profileLoaded = true;
      _recompute();
    }, onError: _onError));
  }

  void _onError(Object e, StackTrace st) {
    debugPrint('Firestore stream error: $e');
    _error = e;
    notifyListeners();
  }

  /// Recomputes at the next day boundary or grace-period end, whichever is
  /// sooner, so the Today screen rolls over without a restart.
  void _scheduleTick() {
    _tick?.cancel();
    final now = DateTime.now();
    final dayStart = logicalToday.add(Duration(minutes: _profile.dayStartMinutes));
    final candidates = <DateTime>[
      dayStart.add(const Duration(days: 1, seconds: 5)),
      if (_profile.graceMinutes > 0)
        dayStart.add(Duration(minutes: _profile.graceMinutes, seconds: 5)),
    ].where((t) => t.isAfter(now)).toList()
      ..sort();
    if (candidates.isEmpty) return;
    _tick = Timer(candidates.first.difference(now), _recompute);
  }

  @override
  void dispose() {
    _disposed = true;
    notifications.onMarkDone = null;
    for (final s in _subs) {
      s.cancel();
    }
    _tick?.cancel();
    _syncDebounce?.cancel();
    super.dispose();
  }

  // ---- Derivation ---------------------------------------------------------

  void _recompute() {
    if (_disposed) return;
    _error = null;
    _stats = StreakEngine.compute(
      habits: _habits,
      days: _days,
      weeks: _weeks,
      profile: _profile,
      today: logicalToday,
      graceDay: graceDay,
    );
    notifyListeners();
    _scheduleTick();
    if (isLoaded) {
      unawaited(_autoClaim());
      _queueNotificationSync();
    }
  }

  Future<void> _autoClaim() async {
    final fresh = _stats.reached.values
        .where((m) =>
            !_profile.claimed.containsKey(m.key) && !_claiming.contains(m.key))
        .toList();
    if (fresh.isEmpty) return;
    final keys = fresh.map((m) => m.key).toSet();
    _claiming.addAll(keys);
    try {
      await repo.claimMilestones(fresh);
      celebrations.addAll(fresh);
      notifyListeners();
    } catch (e) {
      debugPrint('Claiming milestones failed: $e');
      _claiming.removeAll(keys);
    }
  }

  void dismissCelebrations() {
    celebrations.clear();
    notifyListeners();
  }

  Set<String> get _doneToday => {...?_days[todayKey]?.done};

  Set<String> get _weeklyTargetMet => {
        for (final s in _stats.habitStats)
          if (s.habit.isWeekly && s.weekTargetMet) s.habit.id,
      };

  void _queueNotificationSync() {
    final done = _doneToday;
    final met = _weeklyTargetMet;
    final signature = [
      todayKey,
      _profile.remindersEnabled,
      _profile.checkInMinutes,
      _profile.dayStartMinutes,
      _stats.todayPerfect || _stats.todayRequired == 0,
      (done.toList()..sort()).join(','),
      (met.toList()..sort()).join(','),
      for (final h in activeHabits)
        '${h.id}:${h.reminderMinutes}:${h.scheduleType.name}:'
            '${(h.weekdays.toList()..sort()).join()}',
    ].join('|');
    if (signature == _lastSyncSignature) return;
    _lastSyncSignature = signature;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 700), () {
      notifications
          .sync(
            habits: activeHabits,
            doneToday: done,
            weeklyTargetMet: met,
            nothingLeftToday: _stats.todayPerfect || _stats.todayRequired == 0,
            checkInMinutes: _profile.checkInMinutes,
            dayStartMinutes: _profile.dayStartMinutes,
            enabled: _profile.remindersEnabled,
          )
          .catchError((Object e) => debugPrint('Notification sync failed: $e'));
    });
  }

  /// Forces a reschedule, e.g. after notification permission was granted.
  void resyncNotifications() {
    _lastSyncSignature = null;
    _queueNotificationSync();
  }

  // ---- Write side ---------------------------------------------------------

  /// Toggles today's check-in. Returns false (and does nothing) when
  /// unticking would push the habit's wallet below zero, i.e. the tokens that
  /// check-in earned were already exchanged or spent on a repair.
  Future<bool> toggleToday(String habitId) async {
    final done = isDoneToday(habitId);
    if (done) {
      final wallet = _stats.habitStat(habitId)?.internalBalance ?? 0;
      if (wallet - RewardRules.perCompletion < 0) return false;
    }
    await repo.setDone(habitId, todayKey, !done);
    return true;
  }

  /// Marks a habit done on a specific day (today, or yesterday during grace).
  Future<void> markDone(String habitId, String dateKey, {bool done = true}) =>
      repo.setDone(habitId, dateKey, done);

  /// Applies one repair. Returns false if it is not affordable right now.
  Future<bool> repair(RepairOption option) async {
    if (!option.affordable) return false;
    if (option.isWeek) {
      await repo.repairWeek(
        option.key,
        option.habit.id,
        option.units,
        option.payment,
      );
    } else {
      await repo.repairDay(option.key, {option.habit.id: option.payment});
    }
    return true;
  }

  /// Repairs every affordable weekday-habit miss on [dateKey] in one write.
  /// Returns how many habits were repaired.
  Future<int> repairWholeDay(String dateKey) async {
    var sharedLeft = _stats.sharedBalance;
    final payments = <String, Payment>{};
    for (final o in _stats.repairOptions) {
      if (o.isWeek || o.key != dateKey) continue;
      if (o.payment.external > sharedLeft) continue;
      sharedLeft -= o.payment.external;
      payments[o.habit.id] = o.payment;
    }
    if (payments.isEmpty) return 0;
    await repo.repairDay(dateKey, payments);
    return payments.length;
  }

  /// Exchanges [internalAmount] of a habit's tokens into shared tokens.
  /// The amount must be a multiple of [RewardRules.exchangeRate] and within
  /// the wallet balance; returns the shared tokens minted.
  Future<int> exchange(String habitId, int internalAmount) async {
    final wallet = _stats.habitStat(habitId)?.internalBalance ?? 0;
    final amount = internalAmount -
        internalAmount.remainder(RewardRules.exchangeRate);
    if (amount <= 0 || amount > wallet) return 0;
    await repo.exchange(habitId, amount);
    return amount ~/ RewardRules.exchangeRate;
  }

  Future<void> createHabit({
    required String name,
    required String emoji,
    required ScheduleType scheduleType,
    required Set<int> weekdays,
    required int timesPerWeek,
    int? reminderMinutes,
  }) {
    final habit = Habit(
      id: repo.newHabitId(),
      name: name.trim(),
      emoji: emoji,
      scheduleType: scheduleType,
      weekdays: weekdays,
      timesPerWeek: timesPerWeek,
      createdOn: todayKey,
      reminderMinutes: reminderMinutes,
      // Always after every existing habit, even if several are added before
      // the stream catches up.
      sortOrder: _habits.fold<int>(-1, (m, h) => h.sortOrder > m ? h.sortOrder : m) + 1,
    );
    return repo.saveHabit(habit);
  }

  Future<void> updateHabit(Habit habit) => repo.saveHabit(habit);

  /// Moves the active habit at [oldIndex] to [newIndex] (list semantics as in
  /// [ReorderableListView.onReorder]).
  Future<void> reorderHabits(int oldIndex, int newIndex) {
    final list = activeHabits;
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    return repo.saveOrder(list.map((h) => h.id).toList());
  }

  Future<void> archiveHabit(String habitId) =>
      repo.archiveHabit(habitId, todayKey);

  Future<void> restoreHabit(String habitId) => repo.restoreHabit(habitId);

  Future<void> deleteHabit(String habitId) => repo.deleteHabit(habitId);

  Future<void> setRemindersEnabled(bool enabled) =>
      repo.updateSettings(remindersEnabled: enabled);

  Future<void> setCheckIn(int? minutes) => repo.updateSettings(
        checkInMinutes: minutes,
        clearCheckIn: minutes == null,
      );

  Future<void> setDayStart(int minutes) =>
      repo.updateSettings(dayStartMinutes: minutes);

  Future<void> setGrace(int minutes) =>
      repo.updateSettings(graceMinutes: minutes);

  /// All data as pretty-printed JSON.
  Future<String> exportJson() async {
    final data = await repo.exportAll();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> deleteAllData() => repo.deleteAllData();
}

/// Makes a [HabitController] available to the subtree.
class ControllerScope extends InheritedNotifier<HabitController> {
  const ControllerScope({
    super.key,
    required HabitController controller,
    required super.child,
  }) : super(notifier: controller);

  static HabitController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ControllerScope>();
    assert(scope != null, 'No ControllerScope above this widget');
    return scope!.notifier!;
  }
}
