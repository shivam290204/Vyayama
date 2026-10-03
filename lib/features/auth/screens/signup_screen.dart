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
import 'package:fitbuddy/features/auth/widgets/password_field.dart';
import 'package:fitbuddy/features/auth/widgets/password_strength_meter.dart';

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
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _agreed = false;
  bool _showTermsError = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    setState(() => _showTermsError = !_agreed);
    if (!valid || !_agreed) return;
    FocusScope.of(context).unfocus();
    runAction(
      () => ref.read(authRepositoryProvider).signUpWithEmail(
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                title: const Text(
                  'I agree to the Terms and Privacy Policy, and I understand '
                  'Vyayama gives general wellness information, not medical advice.',
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
