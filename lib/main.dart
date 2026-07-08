import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'app/alarm_service.dart';
import 'app/cloud_folder_channel.dart';
import 'app/notification_scheduler.dart';
import 'app/providers.dart';
import 'app/sync_service.dart';
import 'core/clock.dart';
import 'data/cloud/cloud_account_service.dart';
import 'data/cloud/cloud_http.dart';
import 'data/db/database.dart';
import 'data/sync/device_identity.dart';
import 'features/cloud/cloud_onboarding.dart';
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
  // Connected OAuth cloud account, read back from the keychain-backed
  // store (the same one CloudAccountService writes).
  final cloudProvider = await CloudAccountService(
    keyStore: FallbackKeyStore(
      primary: const SecureKeyStore(),
      fallback: FileKeyStore(getApplicationSupportDirectory),
    ),
    http: IoCloudHttp(),
    clock: const SystemClock(),
  ).connectedProvider();
  final themeMode =
      ThemeMode.values.asNameMap()[prefs.getString('themeMode')] ??
      ThemeMode.system;
  final density =
      DisplayDensity.values.asNameMap()[prefs.getString('displayDensity')] ??
      DisplayDensity.standard;

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
      // Reflect a previously connected cloud account (tokens are in the
      // keychain; this mirrors just the provider choice for the UI).
      if (cloudProvider != null)
        cloudAccountProvider.overrideWith((_) => cloudProvider),
      // One-time "where should your todos live?" sheet — only on a fresh
      // install with nothing configured yet.
      if (!(prefs.getBool('cloudOnboarded') ?? false) &&
          cloudProvider == null &&
          mailboxPath == null)
        cloudOnboardingDueProvider.overrideWith((_) => true),
      alarmsEnabledProvider.overrideWith((_) => alarmsEnabled),
      themeModeProvider.overrideWith((_) => themeMode),
      displayDensityProvider.overrideWith((_) => density),
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

class TodoApp extends ConsumerWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    themeMode: ref.watch(themeModeProvider),
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
    ),
    home: const CloudOnboarding(child: TodoListScreen()),
  );
}
