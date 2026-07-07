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

enum _ExportFormat {
  json(
    'JSON',
    'Full backup — the only format Knot can restore', //
    'knot-export.json',
  ),
  markdown('Markdown', 'Readable document grouped by list', 'knot-todos.md'),
  todoTxt(
    'todo.txt',
    'One task per line for todo.txt apps (drops notes)',
    'todo.txt',
  );

  const _ExportFormat(this.label, this.description, this.fileName);

  final String label;
  final String description;
  final String fileName;
}

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
          secondary: const Icon(Icons.fit_screen_outlined),
          title: const Text('Glanceable mode'),
          subtitle: const Text(
            'Larger type and checkboxes — readable across the room',
          ),
          value: ref.watch(displayDensityProvider) == DisplayDensity.large,
          onChanged: (large) => _setDensity(ref, large),
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
          subtitle: const Text('JSON backup, Markdown, or todo.txt'),
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

  Future<void> _setDensity(WidgetRef ref, bool large) async {
    final density = large ? DisplayDensity.large : DisplayDensity.standard;
    ref.read(displayDensityProvider.notifier).state = density;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('displayDensity', density.name);
  }

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
    final format = await showDialog<_ExportFormat>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Export as'),
        children: [
          for (final format in _ExportFormat.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(format),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(format.label),
                subtitle: Text(format.description),
              ),
            ),
        ],
      ),
    );
    if (format == null) return;
    final location = await getSaveLocation(suggestedName: format.fileName);
    if (location == null) return;
    final service = _service(ref);
    final content = switch (format) {
      _ExportFormat.json => await service.exportJson(),
      _ExportFormat.markdown => await service.exportMarkdown(),
      _ExportFormat.todoTxt => await service.exportTodoTxt(),
    };
    await File(location.path).writeAsString(content);
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
