import 'package:flutter/material.dart';

import 'sync_settings_screen.dart';

/// Scaffold (TASKS.md 1.13): controls arrive with their features — the
/// per-device alarm toggle lands with the alarms phase.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      children: [
        const ListTile(
          leading: Icon(Icons.palette_outlined),
          title: Text('Theme'),
          subtitle: Text('Follows system'),
          enabled: false,
        ),
        const SwitchListTile(
          secondary: Icon(Icons.alarm),
          title: Text('Enable alarms on this device'),
          subtitle: Text('Coming with the alarms phase'),
          value: false,
          onChanged: null,
        ),
        ListTile(
          leading: const Icon(Icons.sync),
          title: const Text('Sync & devices'),
          subtitle: const Text('Pair devices, pick a sync folder'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SyncSettingsScreen()),
          ),
        ),
        const AboutListTile(
          icon: Icon(Icons.info_outline),
          applicationName: 'TodoApp',
          applicationVersion: '0.1.0-dev',
        ),
      ],
    ),
  );
}
