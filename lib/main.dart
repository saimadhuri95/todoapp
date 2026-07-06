import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'app/alarm_service.dart';
import 'app/cloud_folder_channel.dart';
import 'app/notification_scheduler.dart';
import 'app/providers.dart';
import 'app/sync_service.dart';
import 'data/db/database.dart';
import 'features/todos/todo_list_screen.dart';
import 'l10n/generated/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  var deviceId = prefs.getString('deviceId');
  if (deviceId == null) {
    deviceId = const Uuid().v7();
    await prefs.setString('deviceId', deviceId);
  }
  var mailboxPath = prefs.getString('mailboxPath');
  // Sandboxed macOS forgets picker grants between launches; the bookmark
  // restores access (and tracks the folder if it moved) — TASKS.md 4.18.
  final mailboxBookmark = prefs.getString('mailboxBookmark');
  if (mailboxBookmark != null) {
    final resolved = await platformCloudFolder().resolveBookmark(
      mailboxBookmark,
    );
    if (resolved != null && resolved != mailboxPath) {
      mailboxPath = resolved;
      await prefs.setString('mailboxPath', resolved);
    }
  }
  final alarmsEnabled =
      prefs.getBool('alarmsEnabled') ?? (Platform.isAndroid || Platform.isIOS);

  late final ProviderContainer container;
  final scheduler = LocalNotificationsScheduler(
    onAction: (todoId, occurrenceMs, action) {
      final repo = container.read(todoRepositoryProvider);
      if (action == 'snooze') {
        final until = container
            .read(clockProvider)
            .now()
            .add(const Duration(minutes: 10))
            .millisecondsSinceEpoch;
        repo.snoozeAlarm(todoId, until);
      } else {
        repo.dismissAlarm(todoId, occurrenceMs);
      }
    },
  );
  container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(AppDatabase.open()),
      deviceIdProvider.overrideWithValue(deviceId),
      if (mailboxPath != null)
        mailboxPathProvider.overrideWith((_) => mailboxPath),
      alarmsEnabledProvider.overrideWith((_) => alarmsEnabled),
      alarmSchedulerProvider.overrideWithValue(scheduler),
    ],
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SyncBootstrap(child: TodoApp()),
    ),
  );
}

/// Starts the background sync service (auto-triggers, LAN server, mDNS)
/// for the real app. Widget tests pump [TodoApp] directly and skip it.
class SyncBootstrap extends ConsumerStatefulWidget {
  const SyncBootstrap({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SyncBootstrap> createState() => _SyncBootstrapState();
}

class _SyncBootstrapState extends ConsumerState<SyncBootstrap> {
  @override
  void initState() {
    super.initState();
    ref.read(syncServiceProvider).start();
    ref.read(alarmServiceProvider).start();
  }

  @override
  void dispose() {
    ref.read(syncServiceProvider).stop();
    ref.read(alarmServiceProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
    ),
    home: const TodoListScreen(),
  );
}
