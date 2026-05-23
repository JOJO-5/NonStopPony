/// WeekSchedule model for 单双休 (single/double weekend) scheduling.
///
/// Stores per-week overrides indicating whether a given week
/// follows 单休 (single weekend) or 双休 (double weekend) pattern.
///
/// Key fields:
/// - [weekIndex]: Absolute week number since Jan 1, 2024 (epoch).
///   Used for chain-linkage algorithm.
/// - [year], [month], [weekOfMonth]: Convenience fields for UI display.
enum WeekType {
  /// 单休 - Saturday rings (work), Sunday off
  single,

  /// 双休 - both Saturday and Sunday off
  double,
}

class WeekSchedule {
  final int? id;
  final int weekIndex; // Absolute week number from epoch (primary key for logic)
  final int year;      // Convenience: year for UI grouping
  final int month;     // Convenience: 1-12 for UI grouping
  final int weekOfMonth; // Convenience: which week within the month (for UI)
  final WeekType weekType;
  final DateTime createdAt;

  WeekSchedule({
    this.id,
    required this.weekIndex,
    required this.year,
    required this.month,
    required this.weekOfMonth,
    required this.weekType,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Serializes this instance to a Map.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'weekIndex': weekIndex,
      'year': year,
      'month': month,
      'weekOfMonth': weekOfMonth,
      'weekType': weekType.index,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Creates a WeekSchedule from a Map (e.g., database row).
  factory WeekSchedule.fromMap(Map<String, dynamic> map) {
    return WeekSchedule(
      id: map['id'] as int?,
      weekIndex: map['weekIndex'] as int? ?? 0,
      year: map['year'] as int,
      month: map['month'] as int,
      weekOfMonth: map['weekOfMonth'] as int,
      weekType: WeekType.values[map['weekType'] as int],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  /// Creates a copy with optional field overrides.
  WeekSchedule copyWith({
    int? id,
    int? weekIndex,
    int? year,
    int? month,
    int? weekOfMonth,
    WeekType? weekType,
    DateTime? createdAt,
  }) {
    return WeekSchedule(
      id: id ?? this.id,
      weekIndex: weekIndex ?? this.weekIndex,
      year: year ?? this.year,
      month: month ?? this.month,
      weekOfMonth: weekOfMonth ?? this.weekOfMonth,
      weekType: weekType ?? this.weekType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeekSchedule &&
        other.id == id &&
        other.weekIndex == weekIndex &&
        other.year == year &&
        other.month == month &&
        other.weekOfMonth == weekOfMonth &&
        other.weekType == weekType &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, weekIndex, year, month, weekOfMonth, weekType, createdAt);
  }

  @override
  String toString() {
    return 'WeekSchedule(id: $id, weekIndex: $weekIndex, year: $year, month: $month, '
        'weekOfMonth: $weekOfMonth, weekType: $weekType, createdAt: $createdAt)';
  }
}
