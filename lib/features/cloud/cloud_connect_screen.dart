import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/oauth_callback_channel.dart';
import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../data/cloud/cloud_providers.dart';
import '../todos/linkified_text.dart' show urlOpenerProvider;

/// Cloud storage login + data-source overview (user direction 2026-07-07:
/// iPhone-first, data optionally stored in the user's own cloud account).
///
/// Local-first stays intact (CLAUDE.md invariant 1): connecting a cloud is
/// optional, everything keeps working on-device without it, and what goes
/// up is the encrypted sync mailbox — ciphertext only (invariant 3). A
/// solo device gets durable off-device storage now and instant multi-device
/// sync later: pairing hands the same group key to new devices.
class CloudConnectScreen extends ConsumerStatefulWidget {
  const CloudConnectScreen({super.key});

  @override
  ConsumerState<CloudConnectScreen> createState() => _CloudConnectScreenState();
}

class _CloudConnectScreenState extends ConsumerState<CloudConnectScreen> {
  /// Provider a connect/disconnect is in flight for (spinner on that row).
  CloudProviderId? _busy;

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(cloudAccountProvider);
    final mailboxPath = ref.watch(mailboxPathProvider);
    final devices = ref.watch(devicesProvider).value ?? const [];
    final peerCount = (devices.length - 1).clamp(0, 999);
    // The OAuth account wins over a folder when both exist (mirrors
    // buildOrchestrator); iCloud counts as connected via the folder path.
    final icloudActive = connected == null && mailboxPath != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Cloud storage')),
      body: ListView(
        children: [
          _SectionHeader(
            'Your data',
            'Where your todos live — every source shows in the one list',
          ),
          const ListTile(
            leading: Icon(Icons.phone_iphone),
            title: Text('This iPhone'),
            subtitle: Text('Always on — works fully offline'),
            trailing: Icon(Icons.check_circle, color: Colors.teal),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: Text(switch ((connected, icloudActive)) {
              ((final p?, _)) => p.displayName,
              ((null, true)) => CloudProviderId.icloud.displayName,
              _ => 'No cloud connected',
            }),
            subtitle: Text(
              connected != null || icloudActive
                  ? 'Encrypted copy syncs automatically'
                  : 'Connect below to keep an encrypted copy in your cloud',
            ),
            trailing: connected != null || icloudActive
                ? const Icon(Icons.check_circle, color: Colors.teal)
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.devices_other),
            title: const Text('Paired devices'),
            subtitle: Text(
              peerCount == 0
                  ? 'None yet — their todos appear here once paired'
                  : '$peerCount other device${peerCount == 1 ? '' : 's'} '
                        'syncing with you',
            ),
            enabled: peerCount > 0,
          ),
          const Divider(),
          _SectionHeader(
            'Connect your cloud',
            'Sign in once; only ciphertext is ever uploaded',
          ),
          _ProviderTile(
            id: CloudProviderId.icloud,
            icon: Icons.cloud_queue,
            active: icloudActive,
            busy: _busy == CloudProviderId.icloud,
            enabled: _busy == null,
            onConnect: _connectIcloud,
            onDisconnect: _disconnectIcloud,
          ),
          for (final id in const [
            CloudProviderId.dropbox,
            CloudProviderId.googleDrive,
            CloudProviderId.oneDrive,
          ])
            _ProviderTile(
              id: id,
              icon: switch (id) {
                CloudProviderId.dropbox => Icons.folder_shared_outlined,
                CloudProviderId.googleDrive => Icons.add_to_drive,
                _ => Icons.cloud_circle_outlined,
              },
              active: connected == id,
              busy: _busy == id,
              enabled: _busy == null,
              onConnect: () => _connectOAuth(id),
              onDisconnect: _disconnectOAuth,
            ),
        ],
      ),
    );
  }

  Future<void> _connectOAuth(CloudProviderId id) async {
    final config = id.oauthConfig!;
    if (!config.isConfigured) {
      _explainSetup(id);
      return;
    }
    setState(() => _busy = id);
    try {
      await ref
          .read(cloudAccountServiceProvider)
          .connect(
            id,
            authenticate: (url) {
              ref.read(urlOpenerProvider)(url);
              return OAuthCallbackChannel.instance.waitForRedirect();
            },
          );
      // Solo devices sync from now on: the group key exists from here and
      // is what pairing later shares with new devices.
      await ref.read(pairingServiceProvider).loadOrCreateGroupKey();
      ref.read(cloudAccountProvider.notifier).state = id;
      unawaitedSync(ref);
      _toast('Connected to ${id.displayName}');
    } on Exception catch (e) {
      _toast('Could not connect: $e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _disconnectOAuth() async {
    final id = ref.read(cloudAccountProvider);
    if (id == null || !await _confirmDisconnect(id)) return;
    await ref.read(cloudAccountServiceProvider).disconnect();
    ref.read(cloudAccountProvider.notifier).state = null;
    _toast('Disconnected — your todos stay on this iPhone');
  }

  Future<void> _connectIcloud() async {
    setState(() => _busy = CloudProviderId.icloud);
    try {
      final path = await ref.read(cloudFolderProvider).documentsPath();
      if (path == null) {
        _toast(
          'iCloud Drive is unavailable — check you are signed in to '
          'iCloud and iCloud Drive is on',
        );
        return;
      }
      ref.read(mailboxPathProvider.notifier).state = path;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mailboxPath', path);
      await ref.read(pairingServiceProvider).loadOrCreateGroupKey();
      unawaitedSync(ref);
      _toast('Connected to iCloud Drive');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _disconnectIcloud() async {
    if (!await _confirmDisconnect(CloudProviderId.icloud)) return;
    ref.read(mailboxPathProvider.notifier).state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mailboxPath');
    _toast('Disconnected — your todos stay on this iPhone');
  }

  Future<bool> _confirmDisconnect(CloudProviderId id) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disconnect ${id.displayName}?'),
        content: const Text(
          'Nothing is deleted: your todos stay on this iPhone and the '
          'encrypted copy stays in your cloud for when you reconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  void _explainSetup(CloudProviderId id) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${id.displayName} needs setup'),
        content: Text(
          'This build has no ${id.displayName} app registration yet. '
          'Create one (free) and rebuild with its client id — steps in '
          'docs/cloud-providers.md.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Kick a sync pass without awaiting it (connect should feel instant).
void unawaitedSync(WidgetRef ref) {
  // ignore: unawaited_futures
  ref.read(syncServiceProvider).syncSoon();
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.id,
    required this.icon,
    required this.active,
    required this.busy,
    required this.enabled,
    required this.onConnect,
    required this.onDisconnect,
  });

  final CloudProviderId id;
  final IconData icon;
  final bool active;
  final bool busy;
  final bool enabled;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  bool get _needsSetup =>
      id.needsOAuth && !(id.oauthConfig?.isConfigured ?? false);

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(id.displayName),
    subtitle: Text(
      active
          ? 'Connected'
          : _needsSetup
          ? 'Setup required'
          : id == CloudProviderId.icloud
          ? 'Uses your device’s iCloud account'
          : 'Sign in with your ${id.displayName} account',
    ),
    trailing: busy
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : active
        ? TextButton(
            onPressed: enabled ? onDisconnect : null,
            child: const Text('Disconnect'),
          )
        : FilledButton.tonal(
            onPressed: enabled ? onConnect : null,
            child: Text(_needsSetup ? 'Details' : 'Connect'),
          ),
  );
}
