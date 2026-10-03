import '../../../core/dates.dart';

/// How a habit is scheduled.
enum ScheduleType {
  /// Required on specific weekdays.
  weekdays,

  /// Required [Habit.timesPerWeek] times per calendar week (Mon–Sun), on any
  /// days. The streak breaks only after more than `7 - n` skipped days.
  weekly,
}

/// A habit the user wants to keep.
///
/// A habit only counts on days between [createdOn] (inclusive) and
/// [archivedOn] (exclusive), so archiving keeps history intact without
/// scheduling anything new.
class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.emoji,
    required this.weekdays,
    required this.createdOn,
    this.scheduleType = ScheduleType.weekdays,
    this.timesPerWeek = 3,
    this.reminderMinutes,
    this.archivedOn,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String emoji;

  final ScheduleType scheduleType;

  /// Weekdays ([DateTime.weekday], Monday = 1 … Sunday = 7). Used when
  /// [scheduleType] is [ScheduleType.weekdays].
  final Set<int> weekdays;

  /// Target check-ins per week. Used when [scheduleType] is
  /// [ScheduleType.weekly].
  final int timesPerWeek;

  /// Minutes since local midnight for the reminder, or null for no reminder.
  final int? reminderMinutes;

  /// `yyyy-MM-dd` key of the first day this habit exists.
  final String createdOn;

  /// `yyyy-MM-dd` key of the day the habit was archived, if any.
  final String? archivedOn;

  final int sortOrder;

  bool get isArchived => archivedOn != null;

  bool get isWeekly => scheduleType == ScheduleType.weekly;

  bool get isEveryDay => !isWeekly && weekdays.length == 7;

  /// Days per week that may be skipped without breaking the streak.
  int get allowedSkipsPerWeek => isWeekly ? 7 - timesPerWeek : 0;

  /// Whether the habit exists (not yet archived) on [day].
  bool isActiveOn(DateTime day) {
    final key = dateKey(day);
    if (key.compareTo(createdOn) < 0) return false;
    final archived = archivedOn;
    if (archived != null && key.compareTo(archived) >= 0) return false;
    return true;
  }

  /// Weekday habits: required on this day. Weekly habits: can be done on any
  /// active day, so this is simply [isActiveOn].
  bool isScheduledOn(DateTime day) {
    if (!isActiveOn(day)) return false;
    return isWeekly || weekdays.contains(day.weekday);
  }

  String get scheduleLabel {
    if (isWeekly) {
      return timesPerWeek == 1 ? 'Once a week' : '$timesPerWeek days a week';
    }
    if (isEveryDay) return 'Every day';
    final sorted = weekdays.toList()..sort();
    if (sorted.length == 6) {
      final off = [1, 2, 3, 4, 5, 6, 7].firstWhere((d) => !weekdays.contains(d));
      return 'Every day except ${weekdayShort[off - 1]}';
    }
    if (sorted.length == 5 && sorted.first == 1 && sorted.last == 5) {
      return 'Weekdays';
    }
    if (sorted.length == 2 && sorted.contains(6) && sorted.contains(7)) {
      return 'Weekends';
    }
    if (sorted.length == 1) return '${weekdayShort[sorted.single - 1]}s';
    return sorted.map((d) => weekdayShort[d - 1]).join(', ');
  }

  Habit copyWith({
    String? name,
    String? emoji,
    ScheduleType? scheduleType,
    Set<int>? weekdays,
    int? timesPerWeek,
    int? reminderMinutes,
    bool clearReminder = false,
    String? createdOn,
    String? archivedOn,
    bool clearArchived = false,
    int? sortOrder,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      scheduleType: scheduleType ?? this.scheduleType,
      weekdays: weekdays ?? this.weekdays,
      timesPerWeek: timesPerWeek ?? this.timesPerWeek,
      reminderMinutes:
          clearReminder ? null : (reminderMinutes ?? this.reminderMinutes),
      createdOn: createdOn ?? this.createdOn,
      archivedOn: clearArchived ? null : (archivedOn ?? this.archivedOn),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'emoji': emoji,
        'scheduleType': scheduleType.name,
        'weekdays': (weekdays.toList()..sort()),
        'timesPerWeek': timesPerWeek,
        'reminderMinutes': reminderMinutes,
        'createdOn': createdOn,
        'archivedOn': archivedOn,
        'sortOrder': sortOrder,
      };

  factory Habit.fromMap(String id, Map<String, dynamic> map) {
    final rawDays = (map['weekdays'] as List?) ?? const [1, 2, 3, 4, 5, 6, 7];
    final type = map['scheduleType'] == ScheduleType.weekly.name
        ? ScheduleType.weekly
        : ScheduleType.weekdays;
    return Habit(
      id: id,
      name: (map['name'] as String?) ?? 'Habit',
      emoji: (map['emoji'] as String?) ?? '✨',
      scheduleType: type,
      weekdays: rawDays.map((d) => (d as num).toInt()).toSet(),
      timesPerWeek: ((map['timesPerWeek'] as num?)?.toInt() ?? 3).clamp(1, 7),
      reminderMinutes: (map['reminderMinutes'] as num?)?.toInt(),
      createdOn: (map['createdOn'] as String?) ?? dateKey(DateTime.now()),
      archivedOn: map['archivedOn'] as String?,
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}
