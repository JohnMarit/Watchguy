class ScheduleWindow {
  const ScheduleWindow({
    required this.weekdays,
    required this.startMinutes,
    required this.endMinutes,
  });

  /// Monday = 1 ... Sunday = 7, matching [DateTime.weekday].
  final Set<int> weekdays;
  final int startMinutes;
  final int endMinutes;

  bool contains(DateTime local) {
    if (!weekdays.contains(local.weekday)) return false;
    final minutes = local.hour * 60 + local.minute;
    if (startMinutes == endMinutes) return true;
    if (startMinutes < endMinutes) {
      return minutes >= startMinutes && minutes < endMinutes;
    }
    return minutes >= startMinutes || minutes < endMinutes;
  }

  Map<String, dynamic> toJson() => {
        'weekdays': weekdays.toList()..sort(),
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
      };

  factory ScheduleWindow.fromJson(Map<String, dynamic> json) {
    return ScheduleWindow(
      weekdays: (json['weekdays'] as List<dynamic>).map((day) => (day as num).toInt()).toSet(),
      startMinutes: (json['startMinutes'] as num).toInt(),
      endMinutes: (json['endMinutes'] as num).toInt(),
    );
  }
}

class MonitoringSchedule {
  const MonitoringSchedule({
    this.alwaysArmed = false,
    this.armedWindows = const [],
  });

  final bool alwaysArmed;
  final List<ScheduleWindow> armedWindows;

  bool isArmed(DateTime instant) {
    if (alwaysArmed) return true;
    final local = instant.toLocal();
    return armedWindows.any((window) => window.contains(local));
  }

  Map<String, dynamic> toJson() => {
        'alwaysArmed': alwaysArmed,
        'armedWindows': armedWindows.map((window) => window.toJson()).toList(),
      };

  factory MonitoringSchedule.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MonitoringSchedule();
    return MonitoringSchedule(
      alwaysArmed: json['alwaysArmed'] as bool? ?? false,
      armedWindows: (json['armedWindows'] as List<dynamic>? ?? [])
          .map((window) => ScheduleWindow.fromJson(window as Map<String, dynamic>))
          .toList(),
    );
  }

  static MonitoringSchedule nights() {
    return MonitoringSchedule(
      armedWindows: [
        ScheduleWindow(
          weekdays: {1, 2, 3, 4, 5, 6, 7},
          startMinutes: 20 * 60,
          endMinutes: 6 * 60,
        ),
      ],
    );
  }
}
