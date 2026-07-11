import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';

import 'app/alarm_service.dart';
import 'app/cloud_folder_channel.dart';
import 'app/key_store_factory.dart';
import 'app/notification_scheduler.dart';
import 'app/providers.dart';
import 'app/quick_capture.dart';
import 'app/sync_service.dart';
import 'core/clock.dart';
import 'core/platform_info.dart';
import 'data/cloud/cloud_account_service.dart';
import 'data/cloud/cloud_http.dart';
import 'data/db/database.dart';
import 'features/cloud/cloud_onboarding.dart';
import 'features/todos/todo_list_screen.dart';
import 'l10n/generated/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (platformIsDesktop) {
    // The global quick-capture hotkey raises the window (TASKS.md 6.14).
    await windowManager.ensureInitialized();
  }
  final prefs = await SharedPreferences.getInstance();
  var deviceId = prefs.getString('deviceId');
  if (deviceId == null) {
    deviceId = const Uuid().v7();
    await prefs.setString('deviceId', deviceId);
  }
  var mailboxPath = prefs.getString('mailboxPath');
  // Sandboxed macOS forgets picker grants between launches; the bookmark
  // restores access (and tracks the folder if it moved) - TASKS.md 4.18.
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
  final alarmsEnabled = prefs.getBool('alarmsEnabled') ?? defaultAlarmsEnabled;
  // Connected OAuth/WebDAV cloud account, read back from the key store
  // (the same one CloudAccountService writes).
  final cloudProvider = await CloudAccountService(
    keyStore: createKeyStore(),
    http: createCloudHttp(),
    clock: const SystemClock(),
  ).connectedProvider();
  final themeMode =
      ThemeMode.values.asNameMap()[prefs.getString('themeMode')] ??
      ThemeMode.system;
  final density =
      DisplayDensity.values.asNameMap()[prefs.getString('displayDensity')] ??
      DisplayDensity.standard;
  final accentIndex = (prefs.getInt('accentColor') ?? 0).clamp(
    0,
    accentColorChoices.length - 1,
  );

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
      // key store; this mirrors just the provider choice for the UI).
      if (cloudProvider != null)
        cloudAccountProvider.overrideWith((_) => cloudProvider),
      // One-time "where should your todos live?" sheet - only on a fresh
      // install with nothing configured yet.
      if (!(prefs.getBool('cloudOnboarded') ?? false) &&
          cloudProvider == null &&
          mailboxPath == null)
        cloudOnboardingDueProvider.overrideWith((_) => true),
      alarmsEnabledProvider.overrideWith((_) => alarmsEnabled),
      themeModeProvider.overrideWith((_) => themeMode),
      accentColorProvider.overrideWith((_) => accentColorChoices[accentIndex]),
      displayDensityProvider.overrideWith((_) => density),
      kioskBootLaunchProvider.overrideWith(
        (_) => prefs.getBool('kioskBootLaunch') ?? false,
      ),
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
    ref.read(quickCaptureServiceProvider).start();
  }

  @override
  void dispose() {
    ref.read(syncServiceProvider).stop();
    ref.read(alarmServiceProvider).stop();
    ref.read(quickCaptureServiceProvider).stop();
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
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: ref.watch(accentColorProvider),
      ),
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: ref.watch(accentColorProvider),
        brightness: Brightness.dark,
      ),
    ),
    home: const CloudOnboarding(child: TodoListScreen()),
  );
}
