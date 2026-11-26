import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/auth/auth_validators.dart';
import 'package:fitbuddy/features/auth/data/auth_repository.dart';
import 'package:fitbuddy/features/auth/providers.dart';
import 'package:fitbuddy/features/auth/widgets/auth_action_mixin.dart';
import 'package:fitbuddy/features/auth/widgets/auth_error_banner.dart';
import 'package:fitbuddy/features/auth/widgets/auth_scaffold.dart';
import 'package:fitbuddy/features/auth/widgets/button_spinner.dart';
import 'package:fitbuddy/features/auth/widgets/google_sign_in_button.dart';
import 'package:fitbuddy/features/auth/widgets/password_field.dart';

/// Email/password login with a Google option.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with AuthActionMixin<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  StreamSubscription<String>? _authErrorSub;
  String? _unconfirmedEmail;

  @override
  void initState() {
    super.initState();
    _authErrorSub = ref.read(authRepositoryProvider).authErrors.listen((msg) {
      if (!mounted) return;
      setState(() {
        actionError = msg;
        _unconfirmedEmail = null;
      });
      showMessage(msg);
    });
  }

  @override
  void dispose() {
    _authErrorSub?.cancel();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _onFieldChanged(String _) {
    if (_unconfirmedEmail != null || actionError != null) {
      setState(() {
        _unconfirmedEmail = null;
        actionError = null;
      });
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _unconfirmedEmail = null);
    runAction(
      () => ref.read(authRepositoryProvider).signInWithEmail(
            email: _email.text.trim(),
            password: _password.text,
          ),
      onAuthFailure: (failure) {
        if (failure is EmailNotConfirmedFailure && mounted) {
          setState(() => _unconfirmedEmail = failure.email);
        }
      },
    );
  }

  Future<void> _resendVerification() async {
    final email = _unconfirmedEmail ?? _email.text.trim();
    if (email.isEmpty) return;
    final sent = await runAction(
      () => ref.read(authRepositoryProvider).resendConfirmationEmail(email),
    );
    if (sent && mounted) {
      setState(() => _unconfirmedEmail = email);
      showMessage('Verification email sent to $email.');
    }
  }

  void _google() {
    setState(() => _unconfirmedEmail = null);
    runAction(() => ref.read(authRepositoryProvider).signInWithGoogle());
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Your buddy has been waiting for you.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: AuthValidators.email,
                onChanged: _onFieldChanged,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PasswordField(
                controller: _password,
                validator: AuthValidators.loginPassword,
                textInputAction: TextInputAction.done,
                onChanged: _onFieldChanged,
                onSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy ? null : () => context.push(AppRoutes.forgot),
                  child: const Text('Forgot password?'),
                ),
              ),
              if (actionError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AuthErrorBanner(
                  message: actionError!,
                  actionLabel: _unconfirmedEmail != null
                      ? 'Resend verification email'
                      : null,
                  onAction: _unconfirmedEmail != null && !busy
                      ? _resendVerification
                      : null,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: busy ? null : _submit,
                child: busy ? const ButtonSpinner() : const Text('Log in'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Text('or', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              GoogleSignInButton(onPressed: busy ? null : _google),
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('New here?'),
                  TextButton(
                    onPressed: busy ? null : () => context.go(AppRoutes.signup),
                    child: const Text('Create an account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
