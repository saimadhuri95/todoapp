import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/app/sync_service.dart';
import 'package:todoapp/core/cloud_folder.dart';
import 'package:todoapp/data/cloud/cloud_providers.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/data/sync/device_identity.dart';
import 'package:todoapp/features/cloud/cloud_connect_screen.dart';
import 'package:todoapp/features/cloud/cloud_onboarding.dart';
import 'package:todoapp/main.dart';

import '../support/fake_http.dart';

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

Future<void> scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
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

      // Groups section leads the screen now (8.8). The list is lazy, so
      // scroll to each row and assert while it is on screen.
      expect(find.text('Local'), findsOneWidget);
      await scrollTo(tester, find.text('This device'));
      expect(find.text('No cloud connected'), findsOneWidget);
      expect(find.text('Paired devices'), findsOneWidget);
      await scrollTo(tester, find.text('iCloud Drive'));
      // No client ids are dart-defined in tests: each OAuth row awaits
      // setup as it scrolls into view.
      for (final name in ['Dropbox', 'Google Drive', 'OneDrive']) {
        await scrollTo(tester, find.text(name));
        expect(
          find.descendant(
            of: find.widgetWithText(ListTile, name),
            matching: find.text('Setup required'),
          ),
          findsOneWidget,
        );
      }
    });

    testApp('setup-required provider explains what is missing', (tester) async {
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();

      await scrollTo(tester, find.widgetWithText(ListTile, 'Dropbox'));
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Dropbox'),
          matching: find.text('Details'),
        ),
      );
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

      await scrollTo(tester, find.widgetWithText(ListTile, 'iCloud Drive'));
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'iCloud Drive'),
          matching: find.text('Connect'),
        ),
      );
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

    testApp('WebDAV connects through the credentials form', (tester) async {
      final http = FakeHttp()
        ..on(
          'PROPFIND',
          'https://nas.example/dav/knot-mailbox/',
          '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">'
              '<d:response><d:href>/dav/knot-mailbox/</d:href>'
              '<d:propstat><d:prop><d:resourcetype><d:collection/>'
              '</d:resourcetype></d:prop></d:propstat></d:response>'
              '</d:multistatus>',
          status: 207,
        );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides(),
            cloudHttpProvider.overrideWithValue(http),
          ],
          child: const MaterialApp(home: CloudConnectScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await scrollTo(tester, find.widgetWithText(ListTile, 'WebDAV'));
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'WebDAV'),
          matching: find.text('Connect'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Connect WebDAV'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Server URL'),
        'https://nas.example/dav/',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Username'),
        'alice',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        's3cret',
      );
      await tester.tap(find.text('Connect').last);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CloudConnectScreen)),
      );
      expect(container.read(cloudAccountProvider), CloudProviderId.webdav);
      expect(find.text('Connected to nas.example'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
    });

    testApp('iCloud unavailable explains instead of connecting', (
      tester,
    ) async {
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();

      await scrollTo(tester, find.widgetWithText(ListTile, 'iCloud Drive'));
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'iCloud Drive'),
          matching: find.text('Connect'),
        ),
      );
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
