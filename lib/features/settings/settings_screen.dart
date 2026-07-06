import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/alarm_service.dart';
import '../../app/notification_scheduler.dart';
import 'sync_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      children: [
        const ListTile(
          leading: Icon(Icons.palette_outlined),
          title: Text('Theme'),
          subtitle: Text('Follows system'),
          enabled: false,
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
        const AboutListTile(
          icon: Icon(Icons.info_outline),
          applicationName: 'Knot',
          applicationVersion: '0.1.0-dev',
        ),
      ],
    ),
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
}
