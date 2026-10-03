/// Password strength buckets used by the sign-up hint.
enum PasswordStrength { empty, weak, fair, strong }

/// Pure form validators for the auth screens.
abstract final class AuthValidators {
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please tell us your name.';
    if (text.length > 50) return 'That name is a little too long.';
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your email.';
    if (!_email.hasMatch(text)) return 'Enter a valid email address.';
    return null;
  }

  static String? loginPassword(String? value) {
    return (value == null || value.isEmpty) ? 'Enter your password.' : null;
  }

  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Choose a password.';
    if (value.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  static PasswordStrength strength(String password) {
    if (password.isEmpty) return PasswordStrength.empty;
    if (password.length < 8) return PasswordStrength.weak;

    var score = 1;
    if (password.length >= 12) score++;
    if (RegExp('[a-z]').hasMatch(password) && RegExp('[A-Z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp('[^A-Za-z0-9]').hasMatch(password)) score++;

    if (score <= 2) return PasswordStrength.weak;
    if (score == 3) return PasswordStrength.fair;
    return PasswordStrength.strong;
  }
}
