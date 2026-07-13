import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/core/geofence.dart';

void main() {
  group('haversineMetres', () {
    test('is zero for the same point', () {
      expect(haversineMetres(40.0, -74.0, 40.0, -74.0), 0);
    });

    test('roughly one degree of latitude is ~111 km', () {
      final d = haversineMetres(40.0, -74.0, 41.0, -74.0);
      expect(d, closeTo(111195, 500)); // ~111.2 km per degree
    });

    test('is symmetric', () {
      final ab = haversineMetres(51.5, -0.12, 48.85, 2.35); // London↔Paris
      final ba = haversineMetres(48.85, 2.35, 51.5, -0.12);
      expect(ab, closeTo(ba, 0.001));
      expect(ab, closeTo(343000, 3000)); // ~343 km great-circle
    });
  });

  group('isWithinGeofence', () {
    test('inside a generous radius is true', () {
      expect(isWithinGeofence(40.0001, -74.0001, 40.0, -74.0, 150), isTrue);
    });

    test('far outside is false', () {
      expect(isWithinGeofence(41.0, -74.0, 40.0, -74.0, 150), isFalse);
    });

    test('the boundary counts as inside', () {
      // A point ~111 m north of the target, radius 150 m → inside; radius
      // 100 m → outside.
      expect(isWithinGeofence(40.001, -74.0, 40.0, -74.0, 150), isTrue);
      expect(isWithinGeofence(40.001, -74.0, 40.0, -74.0, 100), isFalse);
    });
  });
}
