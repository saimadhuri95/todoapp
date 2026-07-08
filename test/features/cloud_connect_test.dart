import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/app/sync_service.dart';
import 'package:todoapp/core/cloud_folder.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/data/sync/device_identity.dart';
import 'package:todoapp/features/cloud/cloud_connect_screen.dart';
import 'package:todoapp/features/cloud/cloud_onboarding.dart';
import 'package:todoapp/main.dart';

/// Same drift-safe teardown as the other widget tests.
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
}

/// Sync passes hit the network/LAN; tests only care that connect flows
/// don't blow up, so the pass itself is a no-op.
class NoopSyncService extends SyncService {
  NoopSyncService(super.ref);

  @override
  Future<void> syncSoon() async {}
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => db.close());

  List<Override> overrides({String? icloudPath}) => [
    databaseProvider.overrideWithValue(db),
    deviceIdProvider.overrideWithValue('test-device'),
    keyStoreProvider.overrideWithValue(InMemoryKeyStore()),
    cloudFolderProvider.overrideWithValue(FakeCloudFolder(icloudPath)),
    syncServiceProvider.overrideWith(NoopSyncService.new),
  ];

  Widget screen({List<Override> extra = const []}) => ProviderScope(
    overrides: [...overrides(), ...extra],
    child: const MaterialApp(home: CloudConnectScreen()),
  );

  group('CloudConnectScreen', () {
    testApp('lists sources and all four providers', (tester) async {
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();

      expect(find.text('This device'), findsOneWidget);
      expect(find.text('No cloud connected'), findsOneWidget);
      expect(find.text('Paired devices'), findsOneWidget);
      expect(find.text('iCloud Drive'), findsOneWidget);
      expect(find.text('Dropbox'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('OneDrive'), 80);
      expect(find.text('Google Drive'), findsOneWidget);
      expect(find.text('OneDrive'), findsOneWidget);
      // No client ids are dart-defined in tests: OAuth rows await setup.
      expect(find.text('Setup required'), findsNWidgets(3));
    });

    testApp('setup-required provider explains what is missing', (tester) async {
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Details').first);
      await tester.pumpAndSettle();

      expect(find.text('Dropbox needs setup'), findsOneWidget);
      expect(find.textContaining('docs/cloud-providers.md'), findsOneWidget);
    });

    testApp('iCloud connect wires the mailbox and can disconnect', (
      tester,
    ) async {
      late ProviderScope scope;
      await tester.pumpWidget(
        scope = ProviderScope(
          overrides: overrides(icloudPath: '/tmp/icloud-docs'),
          child: const MaterialApp(home: CloudConnectScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CloudConnectScreen)),
      );
      expect(container.read(mailboxPathProvider), '/tmp/icloud-docs');
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Connected to iCloud Drive'), findsOneWidget);
      // The overview row flips to the provider name.
      expect(find.text('iCloud Drive'), findsNWidgets(2));
      expect(scope, isNotNull);

      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disconnect').last); // Confirm dialog.
      await tester.pumpAndSettle();

      expect(container.read(mailboxPathProvider), isNull);
      expect(find.text('No cloud connected'), findsOneWidget);
    });

    testApp('iCloud unavailable explains instead of connecting', (
      tester,
    ) async {
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('iCloud Drive is unavailable'),
        findsOneWidget,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CloudConnectScreen)),
      );
      expect(container.read(mailboxPathProvider), isNull);
    });
  });

  group('CloudOnboarding', () {
    Widget app({required bool due}) => ProviderScope(
      overrides: [
        ...overrides(),
        cloudOnboardingDueProvider.overrideWith((_) => due),
      ],
      child: const TodoApp(),
    );

    testApp('not due: no sheet', (tester) async {
      await tester.pumpWidget(app(due: false));
      await tester.pumpAndSettle();

      expect(find.text('Where should your todos live?'), findsNothing);
    });

    testApp('"Just this iPhone" dismisses and marks onboarded', (tester) async {
      await tester.pumpWidget(app(due: true));
      await tester.pumpAndSettle();

      expect(find.text('Where should your todos live?'), findsOneWidget);
      await tester.tap(find.text('Just this device'));
      await tester.pumpAndSettle();

      expect(find.text('Where should your todos live?'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('cloudOnboarded'), isTrue);
    });

    testApp('"Also in my cloud" opens the connect screen', (tester) async {
      await tester.pumpWidget(app(due: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Also in my cloud'));
      await tester.pumpAndSettle();

      expect(find.byType(CloudConnectScreen), findsOneWidget);
    });
  });
}
