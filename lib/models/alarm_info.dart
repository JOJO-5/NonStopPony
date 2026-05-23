enum RepeatType {
  once,
  daily,
  weekdays,
  weekends,
  singleRest,
  doubleRest,
  custom,
}

/// Represents a selectable ringtone with a display title, system URI, and type.
class RingtoneInfo {
  final String title;
  final String uri;
  final String type; // 'default', 'alarm', 'notification', 'ringtone', 'custom'

  const RingtoneInfo({required this.title, required this.uri, this.type = 'alarm'});

  /// The built-in default alarm sound.
  static const defaultRingtone = RingtoneInfo(title: '默认', uri: 'default', type: 'default');

  factory RingtoneInfo.fromMap(Map<dynamic, dynamic> map) {
    return RingtoneInfo(
      title: map['title'] as String? ?? '未知',
      uri: map['uri'] as String? ?? 'default',
      type: map['type'] as String? ?? 'alarm',
    );
  }

  Map<String, String> toMap() => {'title': title, 'uri': uri, 'type': type};
}

class AlarmInfo {
  final int? id;
  final int hour;
  final int minute;
  final RepeatType repeatType;
  final List<int> weekdays;
  final String? label;
  final bool vibrate;
  final int snoozeMinutes;
  final bool isEnabled;
  final String ringtone;  // URI string: 'default' for built-in, or content:// / file:// URI
  final String ringtoneTitle;  // Display name for the ringtone

  AlarmInfo.create({
    this.id,
    required this.hour,
    required this.minute,
    this.repeatType = RepeatType.once,
    List<int>? weekdays,
    this.label,
    this.vibrate = true,
    this.snoozeMinutes = 5,
    this.isEnabled = true,
    this.ringtone = 'default',
    this.ringtoneTitle = '默认',
  }) : weekdays = weekdays ?? [];

  AlarmInfo({
    this.id,
    required this.hour,
    required this.minute,
    required this.repeatType,
    required this.weekdays,
    this.label,
    required this.vibrate,
    required this.snoozeMinutes,
    required this.isEnabled,
    this.ringtone = 'default',
    this.ringtoneTitle = '默认',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'hour': hour,
      'minute': minute,
      'repeatType': repeatType.index,
      'weekdays': weekdays.join(','),
      'label': label,
      'vibrate': vibrate ? 1 : 0,
      'snoozeMinutes': snoozeMinutes,
      'isEnabled': isEnabled ? 1 : 0,
      'ringtone': ringtone,
      'ringtoneTitle': ringtoneTitle,
    };
  }

  factory AlarmInfo.fromMap(Map<String, dynamic> map) {
    final weekdaysStr = map['weekdays'] as String? ?? '';
    final weekdays = weekdaysStr.isEmpty
        ? <int>[]
        : weekdaysStr.split(',').map((s) => int.parse(s)).toList();

    return AlarmInfo(
      id: map['id'] as int?,
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      repeatType: RepeatType.values[map['repeatType'] as int],
      weekdays: weekdays,
      label: map['label'] as String?,
      vibrate: (map['vibrate'] as int) == 1,
      snoozeMinutes: map['snoozeMinutes'] as int,
      isEnabled: (map['isEnabled'] as int) == 1,
      ringtone: map['ringtone'] as String? ?? 'default',
      ringtoneTitle: map['ringtoneTitle'] as String? ?? '默认',
    );
  }

  AlarmInfo copyWith({
    int? id,
    int? hour,
    int? minute,
    RepeatType? repeatType,
    List<int>? weekdays,
    String? label,
    bool? vibrate,
    int? snoozeMinutes,
    bool? isEnabled,
    String? ringtone,
    String? ringtoneTitle,
  }) {
    return AlarmInfo(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      repeatType: repeatType ?? this.repeatType,
      weekdays: weekdays ?? List<int>.from(this.weekdays),
      label: label ?? this.label,
      vibrate: vibrate ?? this.vibrate,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      isEnabled: isEnabled ?? this.isEnabled,
      ringtone: ringtone ?? this.ringtone,
      ringtoneTitle: ringtoneTitle ?? this.ringtoneTitle,
    );
  }
}