import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/main.dart';

/// Same drift-safe teardown as the other widget tests: advance fake time so
/// the stream keep-alive timer fires before the binding asserts !timersPending.
void testApp(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(minutes: 1));
  });
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        deviceIdProvider.overrideWithValue('my-device'),
        clockProvider.overrideWithValue(
          FixedClock(DateTime.utc(2026, 7, 6, 12)),
        ),
      ],
    );
    await db
        .into(db.devices)
        .insert(
          DevicesCompanion.insert(
            id: 'device-2',
            name: 'Her Phone',
            platform: 'ios',
            publicKey: 'pk',
          ),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testApp('assignee chip assigns and — regression — unassigns (6.51)', (
    tester,
  ) async {
    final groups = container.read(groupRepositoryProvider);
    final lists = container.read(listRepositoryProvider);
    final todos = container.read(todoRepositoryProvider);
    final group = await groups.create(name: 'Family', backendKind: 'folder');
    await groups.addMember(group.id, 'device-2');
    final list = await lists.create(name: 'Family list');
    await lists.setGroup(list.id, group.id);
    final todo = await todos.create(title: 'shared task', listId: list.id);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const TodoApp()),
    );
    await tester.pumpAndSettle();

    // Assign via the chip.
    await tester.tap(find.byTooltip('Assign'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Her Phone'));
    await tester.pumpAndSettle();
    expect((await todos.getById(todo.id))!.assigneeDeviceId, 'device-2');

    // Unassign via the chip — a null menu value never reaches onSelected,
    // so this exercises the sentinel path.
    await tester.tap(find.byTooltip('Assigned to Her Phone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unassigned'));
    await tester.pumpAndSettle();
    expect((await todos.getById(todo.id))!.assigneeDeviceId, isNull);
  });
}
