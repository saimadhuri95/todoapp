import 'package:drift/drift.dart' show TableOrViewStatements;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/app/shared_content_service.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/db/database.dart';

void main() {
  group('sharedTextToTitle', () {
    test('trims and collapses whitespace', () {
      expect(sharedTextToTitle('  buy   milk  '), 'buy milk');
    });

    test('prefers the human title line over a bare URL', () {
      expect(
        sharedTextToTitle('Great article\nhttps://example.com/x'),
        'Great article',
      );
    });

    test('falls back to the URL when there is no title line', () {
      expect(
        sharedTextToTitle('https://example.com/x'),
        'https://example.com/x',
      );
    });

    test('blank share yields null', () {
      expect(sharedTextToTitle('   \n  '), isNull);
    });
  });

  group('ingestSharedText', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWithValue('share-device'),
          clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026, 7, 6))),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('creates an Inbox todo from shared text', () async {
      final service = container.read(sharedContentServiceProvider);

      await service.ingestSharedText('Read this later\nhttps://example.com');

      final rows = await db.todos.all().get();
      expect(rows, hasLength(1));
      expect(rows.single.title, 'Read this later');
      expect(rows.single.listId, isNull); // Inbox
    });

    test('ignores a blank share', () async {
      final service = container.read(sharedContentServiceProvider);

      await service.ingestSharedText('   ');

      expect(await db.todos.all().get(), isEmpty);
    });
  });
}
