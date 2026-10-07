import '../../../core/models/enums.dart';

class AppSettings {
  const AppSettings({
    this.mode,
    this.organizationId,
    this.deviceId = '',
    this.dataSaver = DataSaverMode.balanced,
    this.dimWhileMonitoring = true,
    this.notificationsEnabled = true,
    this.activeCameraId,
  });

  final AppMode? mode;
  final String? organizationId;
  final String deviceId;
  final DataSaverMode dataSaver;
  final bool dimWhileMonitoring;
  final bool notificationsEnabled;
  final String? activeCameraId;

  AppSettings copyWith({
    AppMode? mode,
    String? organizationId,
    String? deviceId,
    DataSaverMode? dataSaver,
    bool? dimWhileMonitoring,
    bool? notificationsEnabled,
    String? activeCameraId,
    bool clearMode = false,
    bool clearCamera = false,
  }) {
    return AppSettings(
      mode: clearMode ? null : mode ?? this.mode,
      organizationId: organizationId ?? this.organizationId,
      deviceId: deviceId ?? this.deviceId,
      dataSaver: dataSaver ?? this.dataSaver,
      dimWhileMonitoring: dimWhileMonitoring ?? this.dimWhileMonitoring,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      activeCameraId: clearCamera ? null : activeCameraId ?? this.activeCameraId,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode?.name,
        'organizationId': organizationId,
        'deviceId': deviceId,
        'dataSaver': dataSaver.name,
        'dimWhileMonitoring': dimWhileMonitoring,
        'notificationsEnabled': notificationsEnabled,
        'activeCameraId': activeCameraId,
      };

  factory AppSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AppSettings();
    return AppSettings(
      mode: json['mode'] == null
          ? null
          : enumByName(AppMode.values, json['mode'], AppMode.dashboard),
      organizationId: json['organizationId'] as String?,
      deviceId: json['deviceId'] as String? ?? '',
      dataSaver: enumByName(DataSaverMode.values, json['dataSaver'], DataSaverMode.balanced),
      dimWhileMonitoring: json['dimWhileMonitoring'] as bool? ?? true,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      activeCameraId: json['activeCameraId'] as String?,
    );
  }
}
