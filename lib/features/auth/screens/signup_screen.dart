import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:fitbuddy/features/auth/widgets/password_field.dart';
import 'package:fitbuddy/features/auth/widgets/password_strength_meter.dart';
import 'package:fitbuddy/features/settings/widgets/privacy_policy_sheet.dart';

/// Sign-up with name, email, password strength hint and a terms checkbox.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with AuthActionMixin<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _agreed = false;
  bool _showTermsError = false;
  String? _pendingConfirmationEmail;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    setState(() => _showTermsError = !_agreed);
    if (!valid || !_agreed) return;
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    await runAction(() async {
      final outcome = await ref.read(authRepositoryProvider).signUpWithEmail(
            name: _name.text.trim(),
            email: email,
            password: _password.text,
            username:
                _username.text.trim().isEmpty ? null : _username.text.trim(),
          );
      if (outcome == SignUpOutcome.confirmationRequired && mounted) {
        setState(() => _pendingConfirmationEmail = email);
      }
    });
  }

  Future<void> _resendConfirmation() async {
    final email = _pendingConfirmationEmail;
    if (email == null || email.isEmpty) return;
    final sent = await runAction(
      () => ref.read(authRepositoryProvider).resendConfirmationEmail(email),
    );
    if (sent && mounted) {
      showMessage('Verification email resent to $email.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pendingEmail = _pendingConfirmationEmail;

    if (pendingEmail != null) {
      return AuthScaffold(
        title: 'Check your inbox',
        subtitle:
            'We sent a verification link to $pendingEmail. Confirm your email, then log in.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.mark_email_unread_outlined,
              size: 56,
              color: theme.colorScheme.primary,
              semanticLabel: 'Confirmation email sent',
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              "Didn't receive it? Check your spam folder, or resend the confirmation email below.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionError != null) ...[
              const SizedBox(height: AppSpacing.md),
              AuthErrorBanner(message: actionError!),
            ],
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton(
              onPressed: busy ? null : _resendConfirmation,
              child: busy
                  ? const ButtonSpinner()
                  : const Text('Resend verification email'),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: busy ? null : () => context.go(AppRoutes.login),
              child: const Text('Back to log in'),
            ),
          ],
        ),
      );
    }

    return AuthScaffold(
      title: 'Create your account',
      subtitle: "Let's meet your new fitness buddy.",
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.givenName],
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: AuthValidators.name,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _username,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) => AuthValidators.username(v, required: false),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                decoration: const InputDecoration(
                  labelText: 'Username (optional)',
                  prefixText: '@',
                  helperText: 'Unique handle for friends & QR invites',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: AuthValidators.email,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PasswordField(
                controller: _password,
                validator: AuthValidators.newPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.sm),
              PasswordStrengthMeter(password: _password.text),
              const SizedBox(height: AppSpacing.md),
              CheckboxListTile(
                value: _agreed,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: busy
                    ? null
                    : (value) => setState(() {
                          _agreed = value ?? false;
                          if (_agreed) _showTermsError = false;
                        }),
                title: Text.rich(
                  TextSpan(
                    text: 'I agree to the ',
                    style: theme.textTheme.bodyMedium,
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: () => PrivacyPolicySheet.show(context),
                          child: Text(
                            'Terms, Community Standards & Privacy Policy',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(
                        text:
                            ', and understand photos must not contain objectionable or unsafe content, and Vyayama gives wellness information, not medical advice.',
                      ),
                    ],
                  ),
                ),
              ),
              if (_showTermsError)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'Please accept to continue.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              if (actionError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AuthErrorBanner(message: actionError!),
              ],
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: busy ? null : _submit,
                child: busy ? const ButtonSpinner() : const Text('Sign up'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Already have an account?'),
                  TextButton(
                    onPressed: busy ? null : () => context.go(AppRoutes.login),
                    child: const Text('Log in'),
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
