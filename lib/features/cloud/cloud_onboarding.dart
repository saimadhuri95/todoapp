import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_connect_screen.dart';

/// True when the first-launch "where should your todos live?" sheet is
/// still owed. Defaults false so widget tests (and every later launch)
/// see nothing; main() flips it on the real first run only.
final cloudOnboardingDueProvider = StateProvider<bool>((_) => false);

/// Wraps the home screen; shows the one-time cloud onboarding sheet.
/// Deliberately a sheet, not a wall: the app is fully usable without any
/// account (CLAUDE.md invariant 1) and both choices land in the same list.
class CloudOnboarding extends ConsumerStatefulWidget {
  const CloudOnboarding({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CloudOnboarding> createState() => _CloudOnboardingState();
}

class _CloudOnboardingState extends ConsumerState<CloudOnboarding> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(cloudOnboardingDueProvider)) _show();
    });
  }

  Future<void> _show() async {
    ref.read(cloudOnboardingDueProvider.notifier).state = false;
    final connect = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Where should your todos live?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'They always stay on this iPhone and work offline. You can '
                'also keep an encrypted copy in your own cloud — nothing '
                'readable ever leaves this device.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.cloud_outlined),
                label: const Text('Also in my cloud'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Just this iPhone'),
              ),
            ],
          ),
        ),
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cloudOnboarded', true);
    if (connect == true && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const CloudConnectScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
