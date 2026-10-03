import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/auth/auth_validators.dart';
import 'package:fitbuddy/features/auth/providers.dart';
import 'package:fitbuddy/features/auth/widgets/auth_action_mixin.dart';
import 'package:fitbuddy/features/auth/widgets/auth_scaffold.dart';
import 'package:fitbuddy/features/auth/widgets/button_spinner.dart';

/// Requests a password-reset email.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
    with AuthActionMixin<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    runAction(() async {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      withAppBar: true,
      title: _sent ? 'Check your inbox' : 'Reset your password',
      subtitle: _sent
          ? 'If an account exists for ${_email.text.trim()}, a reset link is on its way.'
          : "Enter your email and we'll send you a reset link.",
      child: _sent ? _buildSent(context) : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: AuthValidators.email,
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: busy ? null : _submit,
            child: busy ? const ButtonSpinner() : const Text('Send reset link'),
          ),
        ],
      ),
    );
  }

  Widget _buildSent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
          semanticLabel: 'Email sent',
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: () => context.go(AppRoutes.login),
          child: const Text('Back to log in'),
        ),
      ],
    );
  }
}
