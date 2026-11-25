import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/auth/auth_validators.dart';
import 'package:fitbuddy/features/auth/providers.dart';
import 'package:fitbuddy/features/auth/widgets/auth_action_mixin.dart';
import 'package:fitbuddy/features/auth/widgets/auth_scaffold.dart';
import 'package:fitbuddy/features/auth/widgets/password_field.dart';
import 'package:fitbuddy/features/auth/widgets/password_strength_meter.dart';

/// Destination for Supabase password recovery deep links.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen>
    with AuthActionMixin {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await runAction(() async {
      await ref
          .read(authRepositoryProvider)
          .updatePassword(_password.text.trim());
      if (!mounted) return;
      showMessage('Password updated successfully.');
      context.go(AppRoutes.home);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuthScaffold(
      title: 'Set a new password',
      subtitle: 'Choose a strong password for your Vyayama account.',
      withAppBar: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PasswordField(
              controller: _password,
              label: 'New password',
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              validator: AuthValidators.newPassword,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            PasswordStrengthMeter(password: _password.text),
            const SizedBox(height: AppSpacing.md),
            PasswordField(
              controller: _confirm,
              label: 'Confirm password',
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _password.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: busy
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : const Text('Update Password'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: busy ? null : () => context.go(AppRoutes.login),
              child: const Text('Back to login'),
            ),
          ],
        ),
      ),
    );
  }
}
