import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'app/providers.dart';
import 'app/sync_service.dart';
import 'data/db/database.dart';
import 'features/todos/todo_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  var deviceId = prefs.getString('deviceId');
  if (deviceId == null) {
    deviceId = const Uuid().v7();
    await prefs.setString('deviceId', deviceId);
  }
  final mailboxPath = prefs.getString('mailboxPath');
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(AppDatabase.open()),
        deviceIdProvider.overrideWithValue(deviceId),
        if (mailboxPath != null)
          mailboxPathProvider.overrideWith((_) => mailboxPath),
      ],
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
  }

  @override
  void dispose() {
    ref.read(syncServiceProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Knot',
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
