import 'package:flutter/material.dart';

/// Scaffold only (TASKS.md 1.13): real controls arrive with their features —
/// the per-device alarm toggle in Phase 2 (2.5), sync/devices in Phase 3.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      children: const [
        ListTile(
          leading: Icon(Icons.palette_outlined),
          title: Text('Theme'),
          subtitle: Text('Follows system'),
          enabled: false,
        ),
        SwitchListTile(
          secondary: Icon(Icons.alarm),
          title: Text('Enable alarms on this device'),
          subtitle: Text('Coming with Phase 2'),
          value: false,
          onChanged: null,
        ),
        ListTile(
          leading: Icon(Icons.sync),
          title: Text('Sync & devices'),
          subtitle: Text('Coming with Phase 3'),
          enabled: false,
        ),
        AboutListTile(
          icon: Icon(Icons.info_outline),
          applicationName: 'TodoApp',
          applicationVersion: '0.1.0-dev',
        ),
      ],
    ),
  );
}
