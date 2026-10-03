import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/rewards.dart';
import '../models/day_record.dart';
import '../models/habit.dart';
import '../models/user_profile.dart';

/// Firestore layout (all under the signed-in user, enforced by rules):
///
///     users/{uid}                     profile, settings, claimed milestones,
///                                     exchanged habit tokens per habit
///     users/{uid}/habits/{habitId}    one doc per habit
///     users/{uid}/days/{yyyy-MM-dd}   completions + repaired misses per day
///     users/{uid}/weeks/{yyyy-MM-dd}  (Monday) repairs of weekly habits
class HabitRepository {
  HabitRepository({required this.uid, FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get _habits =>
      _user.collection('habits');

  CollectionReference<Map<String, dynamic>> get _days =>
      _user.collection('days');

  CollectionReference<Map<String, dynamic>> get _weeks =>
      _user.collection('weeks');

  // ---- Streams ------------------------------------------------------------

  Stream<List<Habit>> watchHabits() => _habits.snapshots().map(
        (snap) => snap.docs.map((d) => Habit.fromMap(d.id, d.data())).toList(),
      );

  Stream<Map<String, DayRecord>> watchDays() => _days.snapshots().map(
        (snap) => {
          for (final d in snap.docs)
            d.id: DayRecord.fromMap(d.id, d.data(), toDateTime: _toDateTimeOrNull),
        },
      );

  Stream<Map<String, WeekRecord>> watchWeeks() => _weeks.snapshots().map(
        (snap) => {
          for (final d in snap.docs) d.id: WeekRecord.fromMap(d.id, d.data()),
        },
      );

  Stream<UserProfile> watchProfile() => _user.snapshots().map((snap) {
        final data = snap.data();
        if (data == null) return const UserProfile();
        return UserProfile.fromMap(data, toDateTime: _toDateTime);
      });

  static DateTime _toDateTime(Object? raw) => _toDateTimeOrNull(raw) ?? DateTime.now();

  static DateTime? _toDateTimeOrNull(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  // ---- Profile ------------------------------------------------------------

  Future<void> ensureProfile({String? email, String? displayName}) =>
      _user.set(
        {
          'email': email,
          'displayName': displayName,
          'lastSeenAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

  Future<void> updateSettings({
    int? checkInMinutes,
    bool clearCheckIn = false,
    bool? remindersEnabled,
    int? dayStartMinutes,
    int? graceMinutes,
  }) {
    final data = <String, dynamic>{};
    if (clearCheckIn) {
      data['checkInMinutes'] = null;
    } else if (checkInMinutes != null) {
      data['checkInMinutes'] = checkInMinutes;
    }
    if (remindersEnabled != null) data['remindersEnabled'] = remindersEnabled;
    if (dayStartMinutes != null) data['dayStartMinutes'] = dayStartMinutes;
    if (graceMinutes != null) data['graceMinutes'] = graceMinutes;
    if (data.isEmpty) return Future.value();
    return _user.set(data, SetOptions(merge: true));
  }

  Future<void> claimMilestones(Iterable<Milestone> milestones) {
    final data = <String, dynamic>{
      'milestones': {
        for (final m in milestones)
          m.key: {
            'reward': m.reward,
            'title': m.title,
            'at': FieldValue.serverTimestamp(),
          },
      },
    };
    return _user.set(data, SetOptions(merge: true));
  }

  /// Converts [internalAmount] habit tokens of [habitId] into shared tokens.
  Future<void> exchange(String habitId, int internalAmount) => _user.set(
        {
          'exchanged': {habitId: FieldValue.increment(internalAmount)},
        },
        SetOptions(merge: true),
      );

  // ---- Habits -------------------------------------------------------------

  String newHabitId() => _habits.doc().id;

  Future<void> saveHabit(Habit habit) =>
      _habits.doc(habit.id).set(habit.toMap(), SetOptions(merge: true));

  /// Persists a new display order: index in [habitIds] becomes sortOrder.
  Future<void> saveOrder(List<String> habitIds) {
    final batch = _db.batch();
    for (var i = 0; i < habitIds.length; i++) {
      batch.set(_habits.doc(habitIds[i]), {'sortOrder': i}, SetOptions(merge: true));
    }
    return batch.commit();
  }

  Future<void> archiveHabit(String habitId, String todayKey) =>
      _habits.doc(habitId).set({'archivedOn': todayKey}, SetOptions(merge: true));

  Future<void> restoreHabit(String habitId) =>
      _habits.doc(habitId).set({'archivedOn': null}, SetOptions(merge: true));

  Future<void> deleteHabit(String habitId) => _habits.doc(habitId).delete();

  // ---- Days and weeks -----------------------------------------------------

  Future<void> setDone(String habitId, String dateKey, bool done) =>
      _days.doc(dateKey).set(
        {
          'done': done
              ? FieldValue.arrayUnion([habitId])
              : FieldValue.arrayRemove([habitId]),
          // Client time, so the order of ticks is right even while offline.
          'doneAt': {
            habitId: done ? Timestamp.now() : FieldValue.delete(),
          },
        },
        SetOptions(merge: true),
      );

  /// Repairs the given weekday habits' misses on [dateKey].
  Future<void> repairDay(String dateKey, Map<String, Payment> payments) =>
      _days.doc(dateKey).set(
        {
          'repairs': {
            for (final e in payments.entries) e.key: e.value.toMap(),
          },
        },
        SetOptions(merge: true),
      );

  /// Buys back [credits] skipped days of a weekly habit in the week [weekKey].
  Future<void> repairWeek(
    String weekKey,
    String habitId,
    int credits,
    Payment payment,
  ) =>
      _weeks.doc(weekKey).set(
        {
          'repairs': {
            habitId: {
              'credits': FieldValue.increment(credits),
              'payment': {
                'internal': FieldValue.increment(payment.internal),
                'external': FieldValue.increment(payment.external),
              },
            },
          },
        },
        SetOptions(merge: true),
      );

  // ---- Whole-account operations ------------------------------------------

  /// Everything stored for this user, as plain JSON-friendly maps.
  Future<Map<String, dynamic>> exportAll() async {
    final profile = await _user.get();
    final habits = await _habits.get();
    final days = await _days.get();
    final weeks = await _weeks.get();
    Map<String, dynamic> clean(Map<String, dynamic> m) => {
          for (final e in m.entries) e.key: _jsonSafe(e.value),
        };
    return {
      'exportedAt': DateTime.now().toIso8601String(),
      'uid': uid,
      'profile': clean(profile.data() ?? {}),
      'habits': {for (final d in habits.docs) d.id: clean(d.data())},
      'days': {for (final d in days.docs) d.id: clean(d.data())},
      'weeks': {for (final d in weeks.docs) d.id: clean(d.data())},
    };
  }

  static Object? _jsonSafe(Object? v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is Map) return {for (final e in v.entries) '${e.key}': _jsonSafe(e.value)};
    if (v is List) return v.map(_jsonSafe).toList();
    return v;
  }

  /// Deletes every document under the user. Firestore has no recursive
  /// delete on the client, so each collection is cleared in batches.
  Future<void> deleteAllData() async {
    for (final col in [_habits, _days, _weeks]) {
      final snap = await col.get();
      for (var i = 0; i < snap.docs.length; i += 400) {
        final batch = _db.batch();
        for (final d in snap.docs.skip(i).take(400)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }
    await _user.delete();
  }
}
