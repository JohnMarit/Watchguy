import '../../../core/models/enums.dart';
import '../../zones/domain/zone_geometry.dart';
import 'object_detector.dart';

class ZoneObservation {
  const ZoneObservation({
    required this.restrictedOccupied,
    required this.entranceInteractions,
    required this.loitering,
    required this.occupiedZoneName,
    required this.peopleCount,
    required this.vehicleCount,
  });

  final bool restrictedOccupied;
  final int entranceInteractions;
  final bool loitering;
  final String? occupiedZoneName;
  final int peopleCount;
  final int vehicleCount;
}

class ZoneDetector {
  ZoneObservation observe({
    required List<Track> tracks,
    required List<SecurityZone> zones,
    required DateTime now,
    required Duration loiterAfter,
  }) {
    var restricted = false;
    var interactions = 0;
    var loitering = false;
    String? zoneName;
    var people = 0;
    var vehicles = 0;

    for (final track in tracks) {
      final ignored = zones.where((zone) => zone.type == ZoneType.ignoredArea);
      if (ignored.any((zone) => pointInPolygon(track.feet, zone.points))) {
        track.insideZoneId = null;
        continue;
      }
      if (!isSecuritySubject(track.label)) continue;
      if (track.label == 'person') people += 1;
      if (track.label == 'car' ||
          track.label == 'truck' ||
          track.label == 'bus' ||
          track.label == 'motorcycle') {
        vehicles += 1;
      }
      SecurityZone? hit;
      for (final zone in zones) {
        if (zone.type == ZoneType.ignoredArea) continue;
        if (pointInPolygon(track.feet, zone.points)) {
          hit = zone;
          break;
        }
      }
      if (hit == null) {
        track.insideZoneId = null;
        track.zoneEnteredAt = null;
        continue;
      }
      if (track.insideZoneId != hit.id) {
        track.insideZoneId = hit.id;
        track.zoneEnteredAt = now;
        if (hit.type == ZoneType.entrance || hit.type == ZoneType.restricted) {
          track.zoneEntries += 1;
        }
      }
      zoneName ??= hit.name;
      if (hit.type == ZoneType.restricted) restricted = true;
      if (hit.type == ZoneType.entrance) interactions += track.zoneEntries;
      final entered = track.zoneEnteredAt;
      if (entered != null && now.difference(entered) >= loiterAfter) {
        loitering = true;
      }
    }

    return ZoneObservation(
      restrictedOccupied: restricted,
      entranceInteractions: interactions,
      loitering: loitering,
      occupiedZoneName: zoneName,
      peopleCount: people,
      vehicleCount: vehicles,
    );
  }
}
