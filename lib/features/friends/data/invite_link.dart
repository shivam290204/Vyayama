/// Base URL of user deep links and QR codes: https://vyayama.app/u/{id_or_username}
const String kProfileBaseUrl = 'https://vyayama.app/u/';
const String kInviteBaseUrl = 'https://fitbuddy.app/invite/';

/// Builds the shareable deep link for [identifier] (either username or user UUID).
String buildProfileLink(String identifier) =>
    '$kProfileBaseUrl${Uri.encodeComponent(identifier.trim().replaceFirst(RegExp(r'^@'), ''))}';

/// Builds the invite link for [username].
String buildInviteLink(String username) =>
    '$kInviteBaseUrl${Uri.encodeComponent(username)}';

/// Extracts a clean identifier (username, user UUID, or token) from a scanned QR value,
/// deep link, or pasted text.
///
/// Accepts:
/// - https://vyayama.app/u/{identifier}
/// - vyayama://u/{identifier}
/// - https://fitbuddy.app/invite/{username}
/// - /u/{identifier}
/// - @username
/// - bare identifier / UUID
String? parseProfileIdentifier(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return null;

  // Check for https://vyayama.app/u/ or /u/
  final uIdx = value.toLowerCase().indexOf('/u/');
  if (uIdx >= 0) {
    value = value.substring(uIdx + 3);
  } else {
    // Check for legacy /invite/
    final invIdx = value.toLowerCase().indexOf('/invite/');
    if (invIdx >= 0) {
      value = value.substring(invIdx + 8);
    } else {
      // Check for vyayama://u/
      final schemeIdx = value.toLowerCase().indexOf('vyayama://u');
      if (schemeIdx >= 0) {
        value = value.substring(schemeIdx + 11).replaceFirst(RegExp(r'^/'), '');
      }
    }
  }

  // Strip query parameters, fragments, or trailing paths
  value = value.split(RegExp(r'[?#/]')).first;
  value = Uri.decodeComponent(value).trim().replaceFirst(RegExp(r'^@'), '');
  return value.isEmpty ? null : value.toLowerCase();
}

/// Backward-compatible parser alias.
String? parseInviteUsername(String raw) => parseProfileIdentifier(raw);
