import '../../../core/models/enums.dart';
import '../../../core/time/json_time.dart';

class NormPoint {
  const NormPoint(this.x, this.y);

  final double x;
  final double y;

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory NormPoint.fromJson(Map<String, dynamic> json) {
    return NormPoint((json['x'] as num).toDouble(), (json['y'] as num).toDouble());
  }
}

class SecurityZone {
  const SecurityZone({
    required this.id,
    required this.organizationId,
    required this.cameraId,
    required this.name,
    required this.type,
    required this.points,
    required this.createdAt,
  });

  final String id;
  final String organizationId;
  final String cameraId;
  final String name;
  final ZoneType type;
  final List<NormPoint> points;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'organizationId': organizationId,
        'cameraId': cameraId,
        'name': name,
        'type': type.name,
        'points': points.map((point) => point.toJson()).toList(),
        'createdAt': writeTime(createdAt),
      };

  factory SecurityZone.fromJson(Map<String, dynamic> json) {
    return SecurityZone(
      id: json['id'] as String,
      organizationId: json['organizationId'] as String,
      cameraId: json['cameraId'] as String,
      name: json['name'] as String,
      type: enumByName(ZoneType.values, json['type'], ZoneType.watchArea),
      points: (json['points'] as List<dynamic>? ?? [])
          .map((point) => NormPoint.fromJson(point as Map<String, dynamic>))
          .toList(),
      createdAt: parseTime(json['createdAt']),
    );
  }
}

/// Ray casting on a normalized polygon. Coordinates are frame-relative, never pixels.
bool pointInPolygon(NormPoint point, List<NormPoint> polygon) {
  if (polygon.length < 3) return false;
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final xi = polygon[i].x;
    final yi = polygon[i].y;
    final xj = polygon[j].x;
    final yj = polygon[j].y;
    final intersects = ((yi > point.y) != (yj > point.y)) &&
        (point.x < (xj - xi) * (point.y - yi) / ((yj - yi) == 0 ? 1e-9 : (yj - yi)) + xi);
    if (intersects) inside = !inside;
  }
  return inside;
}
