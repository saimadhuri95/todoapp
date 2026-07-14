import 'dart:math' as math;

/// On-device geofencing helpers for location reminders (TASKS.md 6.50).
///
/// Pure math, no plugins and no clock/GPS access: the platform location
/// monitor passes the current position in, exactly like the injected clock
/// pattern elsewhere (CLAUDE.md). Nothing here ever leaves the device.

/// Mean Earth radius in metres (WGS-84 authalic sphere).
const double _earthRadiusM = 6371008.8;

double _deg2rad(double deg) => deg * math.pi / 180.0;

/// Great-circle distance in metres between two lat/lng points via the
/// haversine formula. Accurate to well within a geofence's tolerance at the
/// city scale these reminders operate on.
double haversineMetres(double lat1, double lng1, double lat2, double lng2) {
  final dLat = _deg2rad(lat2 - lat1);
  final dLng = _deg2rad(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return _earthRadiusM * c;
}

/// Whether ([lat], [lng]) is within [radiusM] metres of the target point.
/// The boundary counts as inside (arrival at exactly the radius fires).
bool isWithinGeofence(
  double lat,
  double lng,
  double targetLat,
  double targetLng,
  double radiusM,
) => haversineMetres(lat, lng, targetLat, targetLng) <= radiusM;
