/// WeekSchedule model for 单双休 (single/double weekend) scheduling.
///
/// Stores per-week overrides indicating whether a given week of a month
/// follows 单休 (single weekend) or 双休 (double weekend) pattern.
///
/// Unique constraint: (year, month, weekOfMonth) should be unique in the database.
enum WeekType {
  /// 单休 - Saturday rings (work), Sunday off
  single,

  /// 双休 - both Saturday and Sunday off
  double,
}

class WeekSchedule {
  final int? id;
  final int year;
  final int month; // 1-12
  final int weekOfMonth; // 1-based, which week within the month
  final WeekType weekType;
  final DateTime createdAt;

  WeekSchedule({
    this.id,
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
    int? year,
    int? month,
    int? weekOfMonth,
    WeekType? weekType,
    DateTime? createdAt,
  }) {
    return WeekSchedule(
      id: id ?? this.id,
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
        other.year == year &&
        other.month == month &&
        other.weekOfMonth == weekOfMonth &&
        other.weekType == weekType &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, year, month, weekOfMonth, weekType, createdAt);
  }

  @override
  String toString() {
    return 'WeekSchedule(id: $id, year: $year, month: $month, '
        'weekOfMonth: $weekOfMonth, weekType: $weekType, createdAt: $createdAt)';
  }
}