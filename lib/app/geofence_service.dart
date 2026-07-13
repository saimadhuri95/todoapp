import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/alarm_planner.dart';
import '../core/geofence.dart';
import '../data/db/database.dart';
import 'alarm_service.dart';
import 'providers.dart';

/// A position sample handed to the geofence evaluator by the platform
/// location monitor.
class GeoPosition {
  const GeoPosition(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// Where the OS location stream plugs in (TASKS.md 6.50). Kept behind a seam
/// like every other platform capability (CLAUDE.md): the default is a no-op
/// so the app is fully functional — and never asks for location permission —
/// until a real GPS-backed monitor is injected. A geolocator-based
/// implementation registering native geofences is the follow-up native
/// wiring; the evaluation logic below is already complete and tested.
abstract interface class LocationMonitor {
  /// Emits the device position whenever it changes enough to matter. The
  /// default monitor never emits.
  Stream<GeoPosition> get positions;

  Future<void> start();
  Future<void> stop();
}

class NoopLocationMonitor implements LocationMonitor {
  const NoopLocationMonitor();

  @override
  Stream<GeoPosition> get positions => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}

/// The active geofenced todos still worth watching: not deleted, not done,
/// and with a complete geofence (a point and a positive radius).
List<Todo> geofencedTodos(List<Todo> todos) => [
  for (final todo in todos)
    if (!todo.deleted &&
        todo.completedAtMs == null &&
        todo.geofenceLat != null &&
        todo.geofenceLng != null &&
        (todo.geofenceRadiusM ?? 0) > 0)
      todo,
];

/// Pure enter-transition evaluator (TASKS.md 6.50). Given the current
/// position and the set of todo ids the device was already inside, returns
/// the todos newly *entered* this sample plus the refreshed inside-set.
/// Firing only on the outside→inside edge means a reminder rings once on
/// arrival, not repeatedly while the user lingers in the zone; leaving and
/// returning arms it again.
class GeofenceTransition {
  const GeofenceTransition(this.entered, this.inside);

  /// Todos whose geofence the device just entered.
  final List<Todo> entered;

  /// Ids of every geofence currently containing the device.
  final Set<String> inside;
}

GeofenceTransition evaluateGeofences(
  List<Todo> todos,
  GeoPosition position,
  Set<String> previouslyInside,
) {
  final entered = <Todo>[];
  final inside = <String>{};
  for (final todo in geofencedTodos(todos)) {
    final within = isWithinGeofence(
      position.lat,
      position.lng,
      todo.geofenceLat!,
      todo.geofenceLng!,
      todo.geofenceRadiusM!.toDouble(),
    );
    if (!within) continue;
    inside.add(todo.id);
    if (!previouslyInside.contains(todo.id)) entered.add(todo);
  }
  return GeofenceTransition(entered, inside);
}

final locationMonitorProvider = Provider<LocationMonitor>(
  (_) => const NoopLocationMonitor(),
);

/// Wires the [LocationMonitor] to the evaluator and rings an arrival
/// notification through the shared [AlarmScheduler]. Purely local: it reads
/// the todos already in the database and never emits a position anywhere.
class GeofenceService {
  GeofenceService(this._ref);

  final Ref _ref;
  StreamSubscription<GeoPosition>? _sub;
  final _inside = <String>{};

  Future<void> start() async {
    final monitor = _ref.read(locationMonitorProvider);
    _sub = monitor.positions.listen(_onPosition);
    await monitor.start();
  }

  Future<void> _onPosition(GeoPosition position) async {
    // Location reminders honour the same on/off switch as time alarms.
    if (!_ref.read(alarmsEnabledProvider)) return;
    final db = _ref.read(databaseProvider);
    final todos = await db.todos.select().get();
    final transition = evaluateGeofences(todos, position, _inside);
    _inside
      ..clear()
      ..addAll(transition.inside);
    final scheduler = _ref.read(alarmSchedulerProvider);
    for (final todo in transition.entered) {
      await scheduler.showInfo(
        title: todo.title,
        body: todo.geofenceLabel == null
            ? 'You have arrived'
            : 'You have arrived: ${todo.geofenceLabel}',
      );
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _ref.read(locationMonitorProvider).stop();
  }
}

final geofenceServiceProvider = Provider<GeofenceService>(GeofenceService.new);
