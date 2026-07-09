import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/oauth_callback_channel.dart';
import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../data/cloud/cloud_account_service.dart';
import '../../data/cloud/cloud_providers.dart';
import '../todos/linkified_text.dart' show urlOpenerProvider;
import 'groups_section.dart';

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

/// "iPhone" on iOS, "device" everywhere else — these screens ship to all
/// platforms even though the flow is iPhone-first.
String deviceWord() =>
    defaultTargetPlatform == TargetPlatform.iOS ? 'iPhone' : 'device';

class _CloudConnectScreenState extends ConsumerState<CloudConnectScreen> {
  /// Provider a connect/disconnect is in flight for (spinner on that row).
  CloudProviderId? _busy;

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(cloudAccountProvider);
    final accounts =
        ref.watch(cloudAccountsProvider).value ?? const <CloudAccount>[];
    final mailboxPath = ref.watch(mailboxPathProvider);
    final devices = ref.watch(devicesProvider).value ?? const [];
    final peerCount = (devices.length - 1).clamp(0, 999);
    // The OAuth account wins over a folder when both exist (mirrors
    // buildOrchestrator); iCloud counts as connected via the folder path.
    final icloudActive = connected == null && mailboxPath != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Sharing & storage')),
      body: ListView(
        children: [
          _SectionHeader(
            'Your groups',
            'Who you share with — each group lives in its own storage',
          ),
          const GroupsSection(),
          const Divider(),
          _SectionHeader(
            'Your data',
            'Where your todos live — every source shows in the one list',
          ),
          ListTile(
            leading: const Icon(Icons.phone_iphone),
            title: Text('This ${deviceWord()}'),
            subtitle: const Text('Always on — works fully offline'),
            trailing: const Icon(Icons.check_circle, color: Colors.teal),
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
          // WebDAV (TASKS 8.11): the zero-registration backend — Nextcloud,
          // NAS boxes, Koofr… server URL + app-password, no OAuth.
          _ProviderTile(
            id: CloudProviderId.webdav,
            icon: Icons.dns_outlined,
            active: connected == CloudProviderId.webdav,
            busy: _busy == CloudProviderId.webdav,
            enabled: _busy == null,
            onConnect: _connectWebDav,
            onDisconnect: _disconnectOAuth,
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
          if (accounts.isNotEmpty) ...[
            const Divider(),
            _SectionHeader(
              'Signed-in accounts',
              'Sharing groups can use any of these (each member brings '
                  'their own)',
            ),
            for (final account in accounts)
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(account.label),
                subtitle: Text(account.provider.displayName),
                trailing: IconButton(
                  tooltip: 'Remove account',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _busy == null
                      ? () => _removeAccount(account)
                      : null,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _removeAccount(CloudAccount account) async {
    try {
      await ref.read(cloudAccountServiceProvider).removeAccount(account.id);
      // The primary may have gone with it; refresh the mirrors.
      ref.read(cloudAccountProvider.notifier).state = await ref
          .read(cloudAccountServiceProvider)
          .connectedProvider();
      ref.invalidate(cloudAccountsProvider);
      _toast('Removed ${account.label}');
    } on StateError catch (e) {
      _toast(e.message);
    }
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
      ref.invalidate(cloudAccountsProvider);
      unawaitedSync(ref);
      _toast('Connected to ${id.displayName}');
    } on Exception catch (e) {
      _toast('Could not connect: $e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _connectWebDav() async {
    final creds = await showDialog<(Uri, String, String)>(
      context: context,
      builder: (context) => const _WebDavDialog(),
    );
    if (creds == null) return;
    setState(() => _busy = CloudProviderId.webdav);
    try {
      await ref
          .read(cloudAccountServiceProvider)
          .connectWebDav(
            serverUrl: creds.$1,
            username: creds.$2,
            password: creds.$3,
          );
      await ref.read(pairingServiceProvider).loadOrCreateGroupKey();
      ref.read(cloudAccountProvider.notifier).state = CloudProviderId.webdav;
      ref.invalidate(cloudAccountsProvider);
      unawaitedSync(ref);
      _toast('Connected to ${creds.$1.host}');
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
    ref.invalidate(cloudAccountsProvider);
    _toast('Disconnected — your todos stay on this ${deviceWord()}');
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
    _toast('Disconnected — your todos stay on this ${deviceWord()}');
  }

  Future<bool> _confirmDisconnect(CloudProviderId id) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disconnect ${id.displayName}?'),
        content: Text(
          'Nothing is deleted: your todos stay on this ${deviceWord()} and '
          'the encrypted copy stays in your cloud for when you reconnect.',
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

/// Server URL + username + app-password form for WebDAV (TASKS 8.11).
/// Pops `(serverUrl, username, password)`; validation beyond URL shape
/// happens in [CloudAccountService.connectWebDav]'s server probe.
class _WebDavDialog extends StatefulWidget {
  const _WebDavDialog();

  @override
  State<_WebDavDialog> createState() => _WebDavDialogState();
}

class _WebDavDialogState extends State<_WebDavDialog> {
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final url = Uri.tryParse(_url.text.trim());
    if (url == null || !(url.isScheme('https') || url.isScheme('http'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the full server URL, starting with https://'),
        ),
      );
      return;
    }
    Navigator.of(context).pop((url, _user.text.trim(), _password.text));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Connect WebDAV'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _url,
          autofocus: true,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Server URL',
            hintText: 'https://cloud.example.com/remote.php/dav/files/you/',
          ),
        ),
        TextField(
          controller: _user,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Username'),
        ),
        TextField(
          controller: _password,
          obscureText: true,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            labelText: 'Password',
            helperText: 'Use an app password if your server offers them',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Connect')),
    ],
  );
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
          : switch (id) {
              CloudProviderId.icloud => 'Uses your device’s iCloud account',
              CloudProviderId.webdav =>
                'Nextcloud, NAS, Koofr… — no account with us, ever',
              _ => 'Sign in with your ${id.displayName} account',
            },
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
