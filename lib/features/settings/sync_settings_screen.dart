import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../../data/sync/mailbox_transport.dart';
import '../../data/sync/sync_orchestrator.dart';

/// Sync & devices (TASKS.md 3.6 UI, 3.12, 3.14 first cut).
class SyncSettingsScreen extends ConsumerWidget {
  const SyncSettingsScreen({super.key});

  static String get _deviceName => Platform.localHostname;
  static String get _platformName => Platform.operatingSystem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider).value ?? const [];
    final mailboxPath = ref.watch(mailboxPathProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sync & devices')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Sync folder'),
            subtitle: Text(
              mailboxPath ??
                  'Not set — pick a folder your cloud drive syncs '
                      '(iCloud Drive, Google Drive, Dropbox…)',
            ),
            onTap: () => _pickMailboxFolder(ref),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('Show pairing invitation'),
            subtitle: const Text('Scan or paste it on your other device'),
            onTap: () => _showInvitation(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.input),
            title: const Text('Enter invitation'),
            subtitle: const Text('Paste an invitation from another device'),
            onTap: () => _enterInvitation(context, ref),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Devices',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (devices.isEmpty)
            const ListTile(title: Text('No paired devices yet')),
          for (final device in devices)
            ListTile(
              leading: Icon(_platformIcon(device.platform)),
              title: Text(device.name),
              subtitle: Text(
                device.id == ref.watch(deviceIdProvider)
                    ? 'This device'
                    : device.platform,
              ),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              icon: const Icon(Icons.sync),
              label: const Text('Sync now'),
              onPressed: () => _syncNow(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _platformIcon(String platform) => switch (platform) {
    'android' || 'ios' => Icons.smartphone,
    'macos' || 'windows' || 'linux' => Icons.computer,
    _ => Icons.devices,
  };

  Future<void> _pickMailboxFolder(WidgetRef ref) async {
    final path = await getDirectoryPath();
    if (path == null) return;
    ref.read(mailboxPathProvider.notifier).state = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mailboxPath', path);
  }

  Future<void> _showInvitation(BuildContext context, WidgetRef ref) async {
    final identity = await ref.read(deviceIdentityProvider.future);
    final invitation = await ref
        .read(pairingServiceProvider)
        .createInvitation(
          identity: identity,
          name: _deviceName,
          platform: _platformName,
        );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pairing invitation'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(data: invitation, size: 220),
              const SizedBox(height: 8),
              const Text(
                'Keep this private — anyone with it can read your todos.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: invitation));
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Copy as text'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _enterInvitation(BuildContext context, WidgetRef ref) async {
    final invitation = await showDialog<String>(
      context: context,
      builder: (context) => const _EnterInvitationDialog(),
    );
    if (invitation == null || invitation.trim().isEmpty) return;
    if (!context.mounted) return;

    try {
      final identity = await ref.read(deviceIdentityProvider.future);
      final result = await ref
          .read(pairingServiceProvider)
          .accept(
            invitation.trim(),
            identity: identity,
            name: _deviceName,
            platform: _platformName,
          );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Paired!'),
          content: Text(
            'Paired with ${result.peer.name}.\n\n'
            'Fingerprint (should match on both devices):\n'
            '${result.fingerprint}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on FormatException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(pairingServiceProvider);
    if (!await service.hasGroupKey()) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Pair a device first')),
      );
      return;
    }
    final mailboxPath = ref.read(mailboxPathProvider);
    if (mailboxPath == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Pick a sync folder first')),
      );
      return;
    }
    final engine = ref.read(syncEngineProvider);
    final orchestrator = SyncOrchestrator(
      engine: engine,
      groupKey: await service.loadOrCreateGroupKey(),
      mailbox: MailboxTransport(
        root: Directory(mailboxPath),
        engine: engine,
        db: ref.read(databaseProvider),
        deviceId: ref.read(deviceIdProvider),
        groupKey: await service.loadOrCreateGroupKey(),
      ),
    );
    final report = await orchestrator.syncNow();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          report.errors.isEmpty
              ? 'Synced: ${report.totalApplied} received, '
                    '${report.mailboxPublished} published'
              : 'Sync issues: ${report.errors.join('; ')}',
        ),
      ),
    );
  }
}

class _EnterInvitationDialog extends StatefulWidget {
  const _EnterInvitationDialog();

  @override
  State<_EnterInvitationDialog> createState() => _EnterInvitationDialogState();
}

class _EnterInvitationDialogState extends State<_EnterInvitationDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Enter invitation'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLines: 4,
      decoration: const InputDecoration(
        hintText: 'Paste the invitation text here',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Pair'),
      ),
    ],
  );
}
