import '../../../core/rewards.dart';

/// A milestone the user has already been paid for. The reward is stored so
/// later changes to the reward table never alter history.
class ClaimedMilestone {
  const ClaimedMilestone({
    required this.key,
    required this.reward,
    required this.at,
  });

  final String key;
  final int reward;
  final DateTime at;

  /// Non-null for per-habit milestones, whose reward goes to that habit.
  String? get habitId => Milestone.habitIdFromKey(key);
}

class UserProfile {
  const UserProfile({
    this.displayName,
    this.email,
    this.claimed = const {},
    this.exchanged = const {},
    this.checkInMinutes = 21 * 60,
    this.remindersEnabled = true,
    this.dayStartMinutes = 0,
    this.graceMinutes = 12 * 60,
  });

  final String? displayName;
  final String? email;

  /// Claimed milestones keyed by milestone key.
  final Map<String, ClaimedMilestone> claimed;

  /// Habit tokens exchanged into shared tokens, keyed by habit id.
  final Map<String, int> exchanged;

  /// Minutes since midnight for the evening check-in nudge, or null to disable.
  final int? checkInMinutes;

  final bool remindersEnabled;

  /// Minutes after midnight at which a new day begins (0 = midnight,
  /// 180 = 3 AM). Late-night check-ins before this still count for the
  /// previous day.
  final int dayStartMinutes;

  /// For this many minutes after a day begins, yesterday's missed habits can
  /// still be ticked for free. 0 disables the grace period.
  final int graceMinutes;

  /// Shared-token rewards from global milestones.
  int get sharedFromMilestones => claimed.values
      .where((m) => m.habitId == null)
      .fold(0, (sum, m) => sum + m.reward);

  /// Habit-token rewards from that habit's own milestones.
  int habitMilestoneTokens(String habitId) => claimed.values
      .where((m) => m.habitId == habitId)
      .fold(0, (sum, m) => sum + m.reward);

  UserProfile copyWith({
    String? displayName,
    String? email,
    Map<String, ClaimedMilestone>? claimed,
    Map<String, int>? exchanged,
    int? checkInMinutes,
    bool clearCheckIn = false,
    bool? remindersEnabled,
    int? dayStartMinutes,
    int? graceMinutes,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      claimed: claimed ?? this.claimed,
      exchanged: exchanged ?? this.exchanged,
      checkInMinutes:
          clearCheckIn ? null : (checkInMinutes ?? this.checkInMinutes),
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      dayStartMinutes: dayStartMinutes ?? this.dayStartMinutes,
      graceMinutes: graceMinutes ?? this.graceMinutes,
    );
  }

  /// [toDateTime] converts the stored timestamp (a Firestore `Timestamp` in
  /// production, a [DateTime] in tests) into a [DateTime].
  factory UserProfile.fromMap(
    Map<String, dynamic> map, {
    DateTime Function(Object? raw)? toDateTime,
  }) {
    final convert = toDateTime ?? _defaultToDateTime;
    final rawClaimed = (map['milestones'] as Map?) ?? const {};
    final claimed = <String, ClaimedMilestone>{};
    rawClaimed.forEach((key, value) {
      if (value is Map) {
        claimed[key as String] = ClaimedMilestone(
          key: key,
          reward: (value['reward'] as num?)?.toInt() ?? 0,
          at: convert(value['at']),
        );
      }
    });
    final rawExchanged = (map['exchanged'] as Map?) ?? const {};
    final hasCheckIn = map.containsKey('checkInMinutes');
    return UserProfile(
      displayName: map['displayName'] as String?,
      email: map['email'] as String?,
      claimed: claimed,
      exchanged: {
        for (final e in rawExchanged.entries)
          e.key.toString(): (e.value as num?)?.toInt() ?? 0,
      },
      checkInMinutes: hasCheckIn
          ? (map['checkInMinutes'] as num?)?.toInt()
          : 21 * 60,
      remindersEnabled: (map['remindersEnabled'] as bool?) ?? true,
      dayStartMinutes: (map['dayStartMinutes'] as num?)?.toInt() ?? 0,
      graceMinutes: (map['graceMinutes'] as num?)?.toInt() ?? 12 * 60,
    );
  }

  static DateTime _defaultToDateTime(Object? raw) {
    if (raw is DateTime) return raw;
    return DateTime.now();
  }
}
