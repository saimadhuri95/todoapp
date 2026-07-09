import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/app/sync_service.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/core/cloud_folder.dart';
import 'package:todoapp/core/hlc.dart';
import 'package:todoapp/data/db/database.dart' hide Device;
import 'package:todoapp/data/repositories/group_repository.dart';
import 'package:todoapp/data/repositories/list_repository.dart';
import 'package:todoapp/data/sync/device_identity.dart';
import 'package:todoapp/data/sync/pairing_service.dart';
import 'package:todoapp/features/cloud/cloud_connect_screen.dart';

import '../support/fake_http.dart';

/// Sharing & storage groups UI (TASKS 8.8, ADR 0004).
void testApp(String description, Future<void> Function(WidgetTester) body) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(minutes: 1));
  });
}

class FakeCloudFolder implements CloudFolderLocator {
  FakeCloudFolder(this.path);

  final String? path;

  @override
  bool get isSupported => true;

  @override
  Future<String?> documentsPath() async => path;

  @override
  Future<String?> createBookmark(String path) async => null;

  @override
  Future<String?> resolveBookmark(String bookmark) async => null;

  @override
  Future<bool> shareFolder(String path) async => false;
}

class NoopSyncService extends SyncService {
  NoopSyncService(super.ref);

  @override
  Future<void> syncSoon() async {}
}

void main() {
  late AppDatabase db;
  late InMemoryKeyStore keyStore;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    keyStore = InMemoryKeyStore();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => db.close());

  List<Override> overrides() => [
    databaseProvider.overrideWithValue(db),
    deviceIdProvider.overrideWithValue('test-device'),
    keyStoreProvider.overrideWithValue(keyStore),
    cloudFolderProvider.overrideWithValue(FakeCloudFolder('/tmp/icloud')),
    cloudHttpProvider.overrideWithValue(FakeHttp()),
    syncServiceProvider.overrideWith(NoopSyncService.new),
  ];

  Widget screen() => ProviderScope(
    overrides: overrides(),
    child: const MaterialApp(home: CloudConnectScreen()),
  );

  testApp('groups section shows Local plus each group with counts', (
    tester,
  ) async {
    final hlc = HlcClock(
      nodeId: 'test-device',
      clock: FixedClock(DateTime.utc(2026, 7, 8)),
    );
    final groups = GroupRepository(db, hlc);
    final lists = ListRepository(db, hlc);
    final family = await groups.create(name: 'Family', backendKind: 'icloud');
    await db.devices.insertOne(
      DevicesCompanion.insert(
        id: 'test-device',
        name: 'Me',
        platform: 'ios',
        publicKey: 'pk',
      ),
    );
    await groups.addMember(family.id, 'test-device');
    final l = await lists.create(name: 'Groceries');
    await lists.setGroup(l.id, family.id);

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);
    expect(find.text('iCloud Drive · 1 member · 1 list'), findsOneWidget);
    expect(find.text('New group'), findsOneWidget);
    expect(find.text('Join group'), findsOneWidget);
  });

  testApp('new-group wizard creates the group and shows the invite QR', (
    tester,
  ) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('New group'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Family');
    await tester.tap(find.text('iCloud Drive').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // Invite dialog with a QR appears; the group exists with a key.
    expect(find.text('Invite to Family'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final group = (await db.syncGroups.select().get()).single;
    expect(group.name, 'Family');
    expect(group.backendKind, 'icloud');
    expect(group.localAccountRef, '/tmp/icloud');
    expect(await keyStore.read('group_key:${group.id}'), isNotEmpty);
    // The wizard registered this device as a member.
    expect(find.text('iCloud Drive · 1 member · 0 lists'), findsOneWidget);
  });

  testApp('manage lists assigns and unassigns a list', (tester) async {
    final hlc = HlcClock(
      nodeId: 'test-device',
      clock: FixedClock(DateTime.utc(2026, 7, 8)),
    );
    await GroupRepository(
      db,
      hlc,
    ).create(name: 'Family', backendKind: 'webdav');
    await ListRepository(db, hlc).create(name: 'Groceries');

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage lists'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No lists yet'),
      findsNothing,
      reason: 'dialog thinks there are no lists',
    );
    expect(
      find.text('Lists in Family'),
      findsOneWidget,
      reason: 'manage dialog did not open',
    );

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    final list = (await db.todoLists.select().get()).single;
    expect(list.groupId, isNotNull);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect((await db.todoLists.select().get()).single.groupId, isNull);
  });

  testApp('joining a pasted invitation adopts the group', (tester) async {
    // Build a real invitation from a second "device".
    final inviterDb = AppDatabase(NativeDatabase.memory());
    addTearDown(inviterDb.close);
    final inviterStore = InMemoryKeyStore();
    final inviterHlc = HlcClock(
      nodeId: 'inviter',
      clock: FixedClock(DateTime.utc(2026, 7, 8)),
    );
    final inviterPairing = PairingService(
      db: inviterDb,
      hlc: inviterHlc,
      keyStore: inviterStore,
    );
    final inviterIdentity = await DeviceIdentity.loadOrCreate(
      inviterStore,
      'inviter',
    );
    final group = await GroupRepository(
      inviterDb,
      inviterHlc,
    ).create(name: 'Friends', backendKind: 'webdav');
    final invitation = await inviterPairing.createGroupInvitation(
      identity: inviterIdentity,
      name: 'Inviter phone',
      platform: 'ios',
      group: group,
    );

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join group'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Invitation'),
      invitation,
    );
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    // The group materialized locally with the adopted key.
    expect(find.text('Friends'), findsOneWidget);
    expect(await keyStore.read('group_key:${group.id}'), isNotEmpty);
    expect(find.textContaining('confirm fingerprint'), findsOneWidget);
  });

  testApp('leaving a group forgets its key and hides the card', (tester) async {
    final hlc = HlcClock(
      nodeId: 'test-device',
      clock: FixedClock(DateTime.utc(2026, 7, 8)),
    );
    final groups = GroupRepository(db, hlc);
    final family = await groups.create(name: 'Family', backendKind: 'webdav');
    await keyStore.write('group_key:${family.id}', 'a-key');
    await db.devices.insertOne(
      DevicesCompanion.insert(
        id: 'test-device',
        name: 'Me',
        platform: 'ios',
        publicKey: 'pk',
      ),
    );
    await groups.addMember(family.id, 'test-device');

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(find.text('Family'), findsNothing);
    expect(await keyStore.read('group_key:${family.id}'), isEmpty);
  });
}
