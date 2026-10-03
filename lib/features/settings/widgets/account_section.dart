import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/auth/data/auth_repository.dart';
import 'package:fitbuddy/features/auth/providers.dart';
import 'package:fitbuddy/features/settings/widgets/delete_account_dialogs.dart';
import 'package:fitbuddy/features/settings/widgets/settings_section.dart';

/// Log out and delete account. The router redirect handles navigation
/// once the auth state becomes signed-out.
class AccountSection extends ConsumerStatefulWidget {
  const AccountSection({super.key});

  @override
  ConsumerState<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<AccountSection> {
  bool _busy = false;

  Future<void> _logOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can log back in any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() => ref.read(authRepositoryProvider).signOut());
  }

  Future<void> _delete() async {
    final confirmed = await confirmDeleteAccount(context);
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await _run(() async {
      await ref.read(authRepositoryProvider).deleteAccount();
      messenger.showSnackBar(
        const SnackBar(content: Text('Your account and data have been deleted.')),
      );
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } on AuthFailure catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final email = ref.watch(authStateProvider).valueOrNull?.email;

    return SettingsSection(
      title: 'Account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (email != null) ...[
            Text(
              'Signed in as $email',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          OutlinedButton.icon(
            onPressed: _busy ? null : _logOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete account'),
          ),
        ],
      ),
    );
  }
}
