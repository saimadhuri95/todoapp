import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/alarm_service.dart';
import '../../app/notification_scheduler.dart';
import '../../app/providers.dart';
import '../../data/backup_service.dart';
import '../../data/export_service.dart';
import '../../data/import_parsers.dart';
import '../cloud/cloud_connect_screen.dart';
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
        ListTile(
          leading: const Icon(Icons.color_lens_outlined),
          title: const Text('Accent color'),
          subtitle: Wrap(
            spacing: 8,
            children: [
              for (final color in accentColorChoices)
                _AccentSwatch(
                  key: ValueKey(color),
                  color: color,
                  selected: ref.watch(accentColorProvider) == color,
                  onTap: () => _setAccentColor(ref, color),
                ),
            ],
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
          leading: const Icon(Icons.cloud_outlined),
          title: const Text('Sharing & storage'),
          subtitle: const Text(
            'Sharing groups, iCloud Drive, WebDAV, Dropbox and more',
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CloudConnectScreen()),
          ),
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
          subtitle: const Text(
            'Knot backup, todo.txt, or CSV (Todoist, TickTick)',
          ),
          onTap: () => _import(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Encrypted backup'),
          subtitle: const Text('Password-protected snapshot to store anywhere'),
          onTap: () => _backup(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.lock_open_outlined),
          title: const Text('Restore encrypted backup'),
          subtitle: const Text('Import from a password-protected backup'),
          onTap: () => _restore(context, ref),
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

  Future<void> _setAccentColor(WidgetRef ref, Color color) async {
    ref.read(accentColorProvider.notifier).state = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accentColor', accentColorChoices.indexOf(color));
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
    await XFile.fromData(
      Uint8List.fromList(utf8.encode(content)),
      name: format.fileName,
      mimeType: _mimeType(format),
    ).saveTo(location.path);
    messenger.showSnackBar(
      SnackBar(content: Text('Exported to ${location.path}')),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Todos', extensions: ['json', 'txt', 'csv', 'tsv']),
      ],
    );
    if (file == null) return;
    final service = _service(ref);
    final content = await file.readAsString();
    final name = file.name.toLowerCase();
    try {
      if (name.endsWith('.json')) {
        final (lists, todos) = await service.importJson(content);
        messenger.showSnackBar(
          SnackBar(content: Text('Imported $todos todos, $lists lists')),
        );
        return;
      }
      final parsed = name.endsWith('.txt')
          ? parseTodoTxt(content)
          : parseCsv(content);
      final count = await service.importParsed(parsed);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            count == 0 ? 'No todos found in file' : 'Imported $count todos',
          ),
        ),
      );
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  BackupService _backupService(WidgetRef ref) =>
      BackupService(export: _service(ref));

  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    final passphrase = await _askPassphrase(
      context,
      title: 'Encrypt backup',
      confirm: true,
    );
    if (passphrase == null) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final location = await getSaveLocation(suggestedName: 'knot-backup.json');
    if (location == null) return;
    final content = await _backupService(ref).createBackup(passphrase);
    await XFile.fromData(
      Uint8List.fromList(utf8.encode(content)),
      name: 'knot-backup.json',
      mimeType: 'application/json',
    ).saveTo(location.path);
    messenger.showSnackBar(
      SnackBar(content: Text('Encrypted backup saved to ${location.path}')),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Knot backup', extensions: ['json']),
      ],
    );
    if (file == null || !context.mounted) return;
    final passphrase = await _askPassphrase(context, title: 'Restore backup');
    if (passphrase == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final (lists, todos) = await _backupService(
        ref,
      ).restoreBackup(await file.readAsString(), passphrase);
      messenger.showSnackBar(
        SnackBar(content: Text('Restored $todos todos, $lists lists')),
      );
    } on BackupPassphraseError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Prompts for a passphrase; when [confirm] is set, a second field must
  /// match before the dialog returns. Returns null if the user cancels.
  Future<String?> _askPassphrase(
    BuildContext context, {
    required String title,
    bool confirm = false,
  }) => showDialog<String>(
    context: context,
    builder: (context) => _PassphraseDialog(title: title, confirm: confirm),
  );

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

  String _mimeType(_ExportFormat format) => switch (format) {
    _ExportFormat.json => 'application/json',
    _ExportFormat.markdown => 'text/markdown',
    _ExportFormat.todoTxt => 'text/plain',
  };
}

/// Passphrase prompt for encrypted backup/restore (TASKS.md 6.41). Pops the
/// entered passphrase, or null on cancel. With [confirm], a second field must
/// match — a mistyped backup password would otherwise be unrecoverable.
class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog({required this.title, required this.confirm});

  final String title;
  final bool confirm;

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _passphrase = TextEditingController();
  final _repeat = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _passphrase.dispose();
    _repeat.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _passphrase.text;
    if (value.isEmpty) {
      setState(() => _error = 'Passphrase must not be empty');
      return;
    }
    if (widget.confirm && value != _repeat.text) {
      setState(() => _error = 'Passphrases do not match');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _passphrase,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Passphrase'),
          onSubmitted: (_) => _submit(),
        ),
        if (widget.confirm)
          TextField(
            controller: _repeat,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm passphrase'),
            onSubmitted: (_) => _submit(),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('OK')),
    ],
  );
}

/// A tappable accent-color swatch for the settings picker (TASKS.md 6.53).
class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkResponse(
      onTap: onTap,
      radius: 22,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    ),
  );
}
