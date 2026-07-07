import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/alarm_service.dart';
import '../../app/notification_scheduler.dart';
import '../../app/providers.dart';
import '../../data/export_service.dart';
import 'sync_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('Theme'),
          trailing: DropdownButton<ThemeMode>(
            value: ref.watch(themeModeProvider),
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
              DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
            ],
            onChanged: (mode) => _setThemeMode(ref, mode),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.alarm),
          title: const Text('Enable alarms on this device'),
          subtitle: const Text(
            'Ring here when todos are due (on by default on phones)',
          ),
          value: ref.watch(alarmsEnabledProvider),
          onChanged: (enabled) => _setAlarmsEnabled(context, ref, enabled),
        ),
        ListTile(
          leading: const Icon(Icons.sync),
          title: const Text('Sync & devices'),
          subtitle: const Text('Pair devices, pick a sync folder'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SyncSettingsScreen()),
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.upload_file),
          title: const Text('Export todos'),
          subtitle: const Text('Save everything as a JSON file'),
          onTap: () => _export(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: const Text('Import todos'),
          subtitle: const Text('Restore from a Knot export file'),
          onTap: () => _import(context, ref),
        ),
        const AboutListTile(
          icon: Icon(Icons.info_outline),
          applicationName: 'Knot',
          applicationVersion: '0.1.0-dev',
        ),
      ],
    ),
  );

  Future<void> _setThemeMode(WidgetRef ref, ThemeMode? mode) async {
    if (mode == null) return;
    ref.read(themeModeProvider.notifier).state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
  }

  ExportService _service(WidgetRef ref) => ExportService(
    db: ref.read(databaseProvider),
    hlc: ref.read(hlcClockProvider),
  );

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final location = await getSaveLocation(suggestedName: 'knot-export.json');
    if (location == null) return;
    final json = await _service(ref).exportJson();
    await File(location.path).writeAsString(json);
    messenger.showSnackBar(
      SnackBar(content: Text('Exported to ${location.path}')),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Knot export', extensions: ['json']),
      ],
    );
    if (file == null) return;
    try {
      final (lists, todos) = await _service(
        ref,
      ).importJson(await file.readAsString());
      messenger.showSnackBar(
        SnackBar(content: Text('Imported $todos todos, $lists lists')),
      );
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _setAlarmsEnabled(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    if (enabled) {
      final scheduler = ref.read(alarmSchedulerProvider);
      if (scheduler is LocalNotificationsScheduler &&
          !await scheduler.ensurePermissions()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification permission denied')),
          );
        }
        return;
      }
    }
    ref.read(alarmsEnabledProvider.notifier).state = enabled;
    await ref.read(alarmServiceProvider).replan();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alarmsEnabled', enabled);
  }
}
