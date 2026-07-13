import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/geofence_service.dart';
import 'package:todoapp/data/db/database.dart';

Todo todo(
  String id, {
  double? lat,
  double? lng,
  int? radiusM,
  String? label,
  bool completed = false,
  bool deleted = false,
}) => Todo(
  id: id,
  title: id,
  notes: '',
  priority: 0,
  tagsJson: '[]',
  sortKey: '',
  alarmOffsetsJson: '[]',
  pinned: false,
  currentStreak: 0,
  completedAtMs: completed ? 1 : null,
  deleted: deleted,
  geofenceLat: lat,
  geofenceLng: lng,
  geofenceRadiusM: radiusM,
  geofenceLabel: label,
);

void main() {
  // A geofence around (40.0, -74.0), radius 150 m.
  final home = todo('home', lat: 40.0, lng: -74.0, radiusM: 150, label: 'Home');
  const inside = GeoPosition(40.0005, -74.0005); // ~65 m away
  const far = GeoPosition(41.0, -74.0);

  group('geofencedTodos', () {
    test('keeps only active todos with a complete geofence', () {
      final kept = geofencedTodos([
        home,
        todo('no-geo'),
        todo('no-radius', lat: 1, lng: 1),
        todo('zero-radius', lat: 1, lng: 1, radiusM: 0),
        todo('done', lat: 1, lng: 1, radiusM: 50, completed: true),
        todo('deleted', lat: 1, lng: 1, radiusM: 50, deleted: true),
      ]);
      expect(kept.map((t) => t.id), ['home']);
    });
  });

  group('evaluateGeofences (enter transitions)', () {
    test('fires on the outside→inside edge', () {
      final t = evaluateGeofences([home], inside, const {});
      expect(t.entered.map((e) => e.id), ['home']);
      expect(t.inside, {'home'});
    });

    test('does not re-fire while still inside', () {
      final t = evaluateGeofences([home], inside, const {'home'});
      expect(t.entered, isEmpty);
      expect(t.inside, {'home'}); // still tracked as inside
    });

    test('leaving clears the inside-set so a return re-arms', () {
      final left = evaluateGeofences([home], far, const {'home'});
      expect(left.entered, isEmpty);
      expect(left.inside, isEmpty);

      final returned = evaluateGeofences([home], inside, left.inside);
      expect(returned.entered.map((e) => e.id), ['home']);
    });

    test('a position outside every zone enters nothing', () {
      final t = evaluateGeofences([home], far, const {});
      expect(t.entered, isEmpty);
      expect(t.inside, isEmpty);
    });
  });
}
