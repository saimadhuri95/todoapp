import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/providers.dart';
import '../../core/platform_info.dart';
import '../../data/cloud/cloud_account_service.dart';
import '../../data/cloud/cloud_providers.dart';
import '../../data/db/database.dart';
import 'cloud_connect_screen.dart' show unawaitedSync;

/// "Your groups" (TASKS 8.8, ADR 0004): the sharing-groups half of the
/// Sharing & storage screen — group cards with invite / manage lists /
/// set account / leave, a new-group wizard, and paste-to-join.
///
/// Lists are local by default; a group is what makes a list shared. Every
/// member brings their own storage account; the QR invitation carries the
/// group's key (the security boundary), so it must travel person-to-person.

final groupMemberCountProvider = StreamProvider.family<int, String>(
  (ref, groupId) => ref
      .watch(groupRepositoryProvider)
      .watchMemberIds(groupId)
      .map((ids) => ids.length),
);

final groupListCountProvider = StreamProvider.family<int, String>(
  (ref, groupId) => ref.watch(groupRepositoryProvider).watchListCount(groupId),
);

class GroupsSection extends ConsumerWidget {
  const GroupsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(syncGroupsProvider).value ?? const <SyncGroup>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListTile(
          leading: Icon(Icons.smartphone),
          title: Text('Local'),
          subtitle: Text('Lists with no group — they never leave this device'),
        ),
        for (final group in groups) _GroupCard(group: group),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('New group'),
                  onPressed: () => _newGroup(context, ref),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Join group'),
                  onPressed: () => _joinGroup(context, ref),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// New-group wizard: name + backend (an existing account or iCloud
  /// Drive) → create + key + own membership → invite QR right away.
  Future<void> _newGroup(BuildContext context, WidgetRef ref) async {
    final accounts =
        ref.read(cloudAccountsProvider).value ?? const <CloudAccount>[];
    final icloudSupported = ref.read(cloudFolderProvider).isSupported;
    final setup = await showDialog<(String, _Backend)>(
      context: context,
      builder: (context) =>
          _NewGroupDialog(accounts: accounts, icloudSupported: icloudSupported),
    );
    if (setup == null || !context.mounted) return;
    final (name, backend) = setup;

    final messenger = ScaffoldMessenger.of(context);
    String? localRef;
    String backendKind;
    switch (backend) {
      case _IcloudBackend():
        backendKind = CloudProviderId.icloud.name;
        localRef = await ref.read(cloudFolderProvider).documentsPath();
        if (localRef == null) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'iCloud Drive is unavailable — check you are signed in',
              ),
            ),
          );
          return;
        }
      case _AccountBackend(:final account):
        backendKind = account.provider.name;
        localRef = account.id;
    }

    final group = await ref
        .read(groupRepositoryProvider)
        .create(
          name: name,
          backendKind: backendKind,
          localAccountRef: localRef,
        );
    await ref.read(pairingServiceProvider).loadOrCreateGroupKeyFor(group.id);
    if (context.mounted) {
      await _showInvite(context, ref, group);
      unawaitedSync(ref);
    }
  }

  Future<void> _joinGroup(BuildContext context, WidgetRef ref) async {
    final invitation = await showDialog<String>(
      context: context,
      builder: (context) => const _JoinGroupDialog(),
    );
    if (invitation == null || invitation.trim().isEmpty || !context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      final identity = await ref.read(deviceIdentityProvider.future);
      final result = await ref
          .read(pairingServiceProvider)
          .acceptGroupInvitation(
            invitation.trim(),
            identity: identity,
            name: platformDeviceName,
            platform: platformName,
          );
      // Wire this device's own way into the backend: first signed-in
      // account of the matching provider, if any.
      final joined = result.groupId == null
          ? null
          : await ref.read(groupRepositoryProvider).getById(result.groupId!);
      if (joined != null && (joined.localAccountRef ?? '').isEmpty) {
        final match = (ref.read(cloudAccountsProvider).value ?? const [])
            .where((a) => a.provider.name == joined.backendKind)
            .firstOrNull;
        if (match != null) {
          await ref
              .read(groupRepositoryProvider)
              .setLocalAccountRef(joined.id, match.id);
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Joined! Now connect a ${joined.backendKind} account and '
                'pick it via the group’s "Set account".',
              ),
            ),
          );
        }
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Joined — confirm fingerprint ${result.fingerprint} with the '
            'inviter',
          ),
        ),
      );
      unawaitedSync(ref);
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  static Future<void> _showInvite(
    BuildContext context,
    WidgetRef ref,
    SyncGroup group,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final identity = await ref.read(deviceIdentityProvider.future);
      final invitation = await ref
          .read(pairingServiceProvider)
          .createGroupInvitation(
            identity: identity,
            name: platformDeviceName,
            platform: platformName,
            group: group,
          );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Invite to ${group.name}'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                QrImageView(
                  data: invitation,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 8),
                const Text(
                  'This carries the group’s key — share it only with '
                  'the person joining. They also need their own account on '
                  'the same storage.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } on Exception catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Invite failed: $e')));
    }
  }
}

sealed class _Backend {}

class _IcloudBackend extends _Backend {
  @override
  bool operator ==(Object other) => other is _IcloudBackend;

  @override
  int get hashCode => 0;
}

class _AccountBackend extends _Backend {
  _AccountBackend(this.account);

  final CloudAccount account;

  @override
  bool operator ==(Object other) =>
      other is _AccountBackend && other.account.id == account.id;

  @override
  int get hashCode => account.id.hashCode;
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.group});

  final SyncGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(groupMemberCountProvider(group.id)).value ?? 0;
    final lists = ref.watch(groupListCountProvider(group.id)).value ?? 0;
    final backend = CloudProviderId.values.asNameMap()[group.backendKind];
    return ListTile(
      leading: const Icon(Icons.group_outlined),
      title: Text(group.name),
      subtitle: Text(
        '${backend?.displayName ?? group.backendKind} · '
        '$members member${members == 1 ? '' : 's'} · '
        '$lists list${lists == 1 ? '' : 's'}',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) => switch (action) {
          'invite' => GroupsSection._showInvite(context, ref, group),
          'lists' => _manageLists(context, ref),
          'account' => _setAccount(context, ref),
          _ => _leave(context, ref),
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'invite', child: Text('Invite member')),
          PopupMenuItem(value: 'lists', child: Text('Manage lists')),
          PopupMenuItem(value: 'account', child: Text('Set account')),
          PopupMenuItem(value: 'leave', child: Text('Leave group')),
        ],
      ),
    );
  }

  /// Checkbox per list: checked = shared through this group. Unchecking
  /// moves it back to local-only.
  Future<void> _manageLists(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Lists in ${group.name}'),
        content: SizedBox(width: 320, child: _ListToggles(group: group)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _setAccount(BuildContext context, WidgetRef ref) async {
    final accounts =
        ref.read(cloudAccountsProvider).value ?? const <CloudAccount>[];
    final messenger = ScaffoldMessenger.of(context);
    if (accounts.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Connect an account below first, then retry.'),
        ),
      );
      return;
    }
    final chosen = await showDialog<CloudAccount>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Account for ${group.name}'),
        children: [
          for (final account in accounts)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(account),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(account.label),
                subtitle: Text(account.provider.displayName),
              ),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    await ref
        .read(groupRepositoryProvider)
        .setLocalAccountRef(group.id, chosen.id);
    messenger.showSnackBar(
      SnackBar(content: Text('${group.name} now syncs via ${chosen.label}')),
    );
    unawaitedSync(ref);
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave ${group.name}?'),
        content: const Text(
          'Your copy of its lists stays on this device (as local lists for '
          'you). Other members keep the history they already received, and '
          'you stop sending or receiving changes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deviceId = ref.read(deviceIdProvider);
    final groups = ref.read(groupRepositoryProvider);
    try {
      await groups.removeMember(group.id, deviceId);
    } on StateError {
      // Own membership row may never have synced in; leaving still works.
    }
    await ref.read(pairingServiceProvider).forgetGroupKey(group.id);
    await groups.dissolve(group.id);
  }
}

class _ListToggles extends ConsumerWidget {
  const _ListToggles({required this.group});

  final SyncGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(listsProvider).value ?? const <TodoList>[];
    if (live.isEmpty) {
      return const Text('No lists yet — create one from the drawer first.');
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final list in live)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(list.name),
            subtitle: list.groupId != null && list.groupId != group.id
                ? const Text('In another group')
                : null,
            value: list.groupId == group.id,
            onChanged: (checked) => ref
                .read(listRepositoryProvider)
                .setGroup(list.id, checked == true ? group.id : null),
          ),
      ],
    );
  }
}

class _NewGroupDialog extends StatefulWidget {
  const _NewGroupDialog({
    required this.accounts,
    required this.icloudSupported,
  });

  final List<CloudAccount> accounts;
  final bool icloudSupported;

  @override
  State<_NewGroupDialog> createState() => _NewGroupDialogState();
}

class _NewGroupDialogState extends State<_NewGroupDialog> {
  final _name = TextEditingController();
  _Backend? _backend;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New sharing group'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Family, Friends…',
          ),
        ),
        const SizedBox(height: 12),
        Text('Where it syncs', style: Theme.of(context).textTheme.labelMedium),
        RadioGroup<_Backend>(
          groupValue: _backend,
          onChanged: (v) => setState(() => _backend = v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icloudSupported)
                RadioListTile<_Backend>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('iCloud Drive'),
                  value: _IcloudBackend(),
                ),
              for (final account in widget.accounts)
                RadioListTile<_Backend>(
                  contentPadding: EdgeInsets.zero,
                  title: Text(account.label),
                  subtitle: Text(account.provider.displayName),
                  value: _AccountBackend(account),
                ),
            ],
          ),
        ),
        if (!widget.icloudSupported && widget.accounts.isEmpty)
          const Text(
            'Connect a cloud account below first — the group needs '
            'somewhere to live.',
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _backend == null || _name.text.trim().isEmpty
            ? null
            : () => Navigator.of(context).pop((_name.text.trim(), _backend!)),
        child: const Text('Create'),
      ),
    ],
  );
}

class _JoinGroupDialog extends StatefulWidget {
  const _JoinGroupDialog();

  @override
  State<_JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends State<_JoinGroupDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Join a group'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLines: 4,
      decoration: const InputDecoration(
        labelText: 'Invitation',
        hintText:
            'Paste the invitation text (or scan the QR from Sync '
            '& devices on the inviter’s phone)',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Join'),
      ),
    ],
  );
}
