import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todoapp/app/background_mode.dart';
import 'package:todoapp/app/login_item.dart';
import 'package:todoapp/app/providers.dart';
import 'package:todoapp/core/clock.dart';
import 'package:todoapp/data/db/database.dart';
import 'package:todoapp/features/settings/settings_screen.dart';

class FakeBackgroundMode implements BackgroundMode {
  final calls = <bool>[];
  var quits = 0;

  @override
  Future<void> setEnabled(bool enabled) async {
    calls.add(enabled);
  }

  @override
  Future<void> quit() async {
    quits++;
  }
}

void main() {
  group('LoginItem', () {
    final item = LoginItem(execPath: '/opt/knot/knot');

    test('desktop entry autostarts the executable hidden', () {
      final entry = item.desktopEntry();
      expect(entry, contains('[Desktop Entry]'));
      expect(entry, contains('Exec="/opt/knot/knot" --hidden'));
      expect(entry, contains('Type=Application'));
    });

    test('linux autostart path lands in XDG autostart', () {
      expect(
        item.linuxAutostartFile('/home/sai').path,
        '/home/sai/.config/autostart/com.sai.knot.desktop',
      );
    });

    test('windows registry command adds and removes the Run value', () {
      final (exe, addArgs) = item.windowsRegCommand(enabled: true);
      expect(exe, 'reg');
      expect(addArgs, contains('add'));
      expect(
        addArgs,
        contains(
          r'HKCU\Software\Microsoft\Windows'
          r'\CurrentVersion\Run',
        ),
      );
      expect(addArgs, contains('"/opt/knot/knot" --hidden'));

      final (_, delArgs) = item.windowsRegCommand(enabled: false);
      expect(delArgs.first, 'delete');
      expect(delArgs, contains('Knot'));
    });

    test('apply writes and removes the Linux entry (injected home)', () async {
      final home = await Directory.systemTemp.createTemp('knot-home');
      addTearDown(() => home.delete(recursive: true));
      final file = item.linuxAutostartFile(home.path);

      // The host isn't Linux, so exercise the file plumbing directly.
      if (Platform.isLinux) {
        await item.apply(enabled: true, home: home.path);
        expect(await file.exists(), isTrue);
        await item.apply(enabled: false, home: home.path);
        expect(await file.exists(), isFalse);
      } else {
        await file.parent.create(recursive: true);
        await file.writeAsString(item.desktopEntry());
        expect(await file.readAsString(), contains('Exec='));
      }
    });
  });

  group('settings toggle', () {
    late AppDatabase db;
    late FakeBackgroundMode mode;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      mode = FakeBackgroundMode();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWithValue('bg-device'),
          clockProvider.overrideWithValue(
            FixedClock(DateTime.utc(2026, 7, 6, 12)),
          ),
          backgroundModeProvider.overrideWithValue(mode),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    testWidgets('flipping the toggle arms background mode and persists', (
      tester,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final toggle = find.text('Run in background at login');
      expect(toggle, findsOneWidget);

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(mode.calls, [true]);
      expect(container.read(backgroundAtLoginProvider), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('backgroundAtLogin'), isTrue);

      // Enabled mode exposes an explicit Quit (the close button only
      // hides the window now).
      final quit = find.text('Quit Knot');
      expect(quit, findsOneWidget);
      await tester.tap(quit);
      await tester.pumpAndSettle();
      expect(mode.quits, 1);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(mode.calls, [true, false]);
      expect(prefs.getBool('backgroundAtLogin'), isFalse);
    });
  });
}
