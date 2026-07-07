import 'package:drift/drift.dart' show TableOrViewStatements;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/core/hlc.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/data/sync/device_identity.dart';
import 'package:todoapp/data/sync/pairing_service.dart';
import 'package:todoapp/features/settings/sync_settings_screen.dart';

import '../support/widget_test_support.dart';

void main() {
  late AppDatabase db;
  late InMemoryKeyStore keyStore;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    keyStore = InMemoryKeyStore();
  });
  tearDown(() => db.close());

  Widget screen() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      deviceIdProvider.overrideWithValue('this-device'),
      clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026, 7, 5))),
      keyStoreProvider.overrideWithValue(keyStore),
    ],
    child: const MaterialApp(home: SyncSettingsScreen()),
  );

  testApp('shows empty device list and unset folder initially', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.text('No paired devices yet'), findsOneWidget);
    expect(find.textContaining('Not set'), findsOneWidget);
    // 6.3 status line before any pass this session.
    expect(find.text('No sync pass yet this session'), findsOneWidget);
  });

  testApp('status line shows the last sync pass time', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWithValue('this-device'),
          clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026, 7, 5))),
          keyStoreProvider.overrideWithValue(keyStore),
          lastSyncPassProvider.overrideWith((_) => DateTime(2026, 7, 5, 9, 30)),
        ],
        child: const MaterialApp(home: SyncSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Last sync 09:30'), findsOneWidget);
  });

  testApp('showing an invitation renders a QR and registers this device', (
    tester,
  ) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show pairing invitation'));
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Own device row registered and listed.
    expect(find.text('This device'), findsOneWidget);
    expect(await db.devices.all().get(), hasLength(1));
  });

  testApp('accepting a valid invitation pairs and shows the fingerprint', (
    tester,
  ) async {
    // Another device creates the invitation out-of-band.
    final otherDb = AppDatabase(NativeDatabase.memory());
    addTearDown(otherDb.close);
    final otherStore = InMemoryKeyStore();
    final otherService = PairingService(
      db: otherDb,
      hlc: HlcClock(
        nodeId: 'other-device',
        clock: FixedClock(DateTime.utc(2026, 7, 5)),
      ),
      keyStore: otherStore,
    );
    final invitation = await otherService.createInvitation(
      identity: await DeviceIdentity.loadOrCreate(otherStore, 'other-device'),
      name: 'Other laptop',
      platform: 'linux',
    );

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enter invitation'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), invitation);
    await tester.tap(find.text('Pair'));
    await tester.pumpAndSettle();

    expect(find.text('Paired!'), findsOneWidget);
    // Dialog text + the live device list behind it can both match.
    expect(find.textContaining('Other laptop'), findsAtLeastNWidgets(1));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Both device rows present: inviter + self.
    expect(await db.devices.all().get(), hasLength(2));
    // Group keys match on both sides.
    final myKey = await PairingService(
      db: db,
      hlc: HlcClock(
        nodeId: 'this-device',
        clock: FixedClock(DateTime.utc(2026, 7, 5)),
      ),
      keyStore: keyStore,
    ).loadOrCreateGroupKey();
    final otherKey = await otherService.loadOrCreateGroupKey();
    expect(await myKey.extractBytes(), await otherKey.extractBytes());
  });

  testApp('bad invitation shows an error and pairs nothing', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enter invitation'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'garbage');
    await tester.tap(find.text('Pair'));
    await tester.pumpAndSettle();

    expect(find.text('Not a valid invitation'), findsOneWidget);
    expect(await db.devices.all().get(), isEmpty);
  });

  testApp('sync now without pairing asks to pair first', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    // The scan-invitation tile (6.1) can push the button below the fold.
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();

    expect(find.text('Pair a device first'), findsOneWidget);
  });
}
