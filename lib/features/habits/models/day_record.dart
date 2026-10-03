/// How a repair was paid for: habit tokens first, shared tokens for the rest.
class Payment {
  const Payment({this.internal = 0, this.external = 0});

  final int internal;
  final int external;

  int get total => internal + external;

  Payment operator +(Payment other) => Payment(
        internal: internal + other.internal,
        external: external + other.external,
      );

  Map<String, dynamic> toMap() => {'internal': internal, 'external': external};

  factory Payment.fromMap(Map<dynamic, dynamic>? map) => Payment(
        internal: (map?['internal'] as num?)?.toInt() ?? 0,
        external: (map?['external'] as num?)?.toInt() ?? 0,
      );
}

/// What happened on one calendar day: which habits were checked off, and
/// which weekday-habit misses on that day were repaired afterwards.
class DayRecord {
  const DayRecord({
    required this.date,
    this.done = const <String>{},
    this.doneAt = const <String, DateTime>{},
    this.repairs = const <String, Payment>{},
  });

  /// `yyyy-MM-dd` key.
  final String date;

  /// Ids of habits completed on this day.
  final Set<String> done;

  /// When each habit was ticked (missing for check-ins made before this
  /// field existed).
  final Map<String, DateTime> doneAt;

  /// Repaired misses, keyed by habit id, with what was paid.
  final Map<String, Payment> repairs;

  Map<String, dynamic> toMap() => {
        'done': done.toList(),
        'repairs': {for (final e in repairs.entries) e.key: e.value.toMap()},
      };

  factory DayRecord.fromMap(
    String date,
    Map<String, dynamic> map, {
    DateTime? Function(Object? raw)? toDateTime,
  }) {
    final raw = (map['done'] as List?) ?? const [];
    final rawRepairs = (map['repairs'] as Map?) ?? const {};
    final rawDoneAt = (map['doneAt'] as Map?) ?? const {};
    final convert = toDateTime ?? (Object? v) => v is DateTime ? v : null;
    return DayRecord(
      date: date,
      done: raw.map((e) => e.toString()).toSet(),
      doneAt: {
        for (final e in rawDoneAt.entries)
          if (convert(e.value) != null) e.key.toString(): convert(e.value)!,
      },
      repairs: {
        for (final e in rawRepairs.entries)
          e.key.toString(): Payment.fromMap(e.value as Map?),
      },
    );
  }
}

/// A repair of a weekly habit's week: [credits] skipped days were bought back.
class WeekRepair {
  const WeekRepair({required this.credits, required this.payment});

  final int credits;
  final Payment payment;

  Map<String, dynamic> toMap() => {
        'credits': credits,
        'payment': payment.toMap(),
      };

  factory WeekRepair.fromMap(Map<dynamic, dynamic>? map) => WeekRepair(
        credits: (map?['credits'] as num?)?.toInt() ?? 0,
        payment: Payment.fromMap(map?['payment'] as Map?),
      );
}

/// Per calendar week (keyed by its Monday): repairs of weekly habits.
class WeekRecord {
  const WeekRecord({required this.weekKey, this.repairs = const {}});

  final String weekKey;
  final Map<String, WeekRepair> repairs;

  factory WeekRecord.fromMap(String weekKey, Map<String, dynamic> map) {
    final raw = (map['repairs'] as Map?) ?? const {};
    return WeekRecord(
      weekKey: weekKey,
      repairs: {
        for (final e in raw.entries)
          e.key.toString(): WeekRepair.fromMap(e.value as Map?),
      },
    );
  }
}
