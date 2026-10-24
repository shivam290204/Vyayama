/// Configuration placeholder for public web invite and profile deep links.
///
/// NOTE: Before shipping in production, you MUST own and configure your custom domain
/// (e.g. 'https://your-domain.com') and host the associated Android Digital Asset Links
/// (assetlinks.json) and Apple App Site Association (apple-app-site-association).
const String kDefaultInviteBaseUrl = 'https://invite.vyayama.example/invite/';
const String kDefaultProfileBaseUrl = 'https://invite.vyayama.example/u/';

const String kProfileBaseUrl = String.fromEnvironment(
  'PROFILE_BASE_URL',
  defaultValue: kDefaultProfileBaseUrl,
);

const String kInviteBaseUrl = String.fromEnvironment(
  'INVITE_BASE_URL',
  defaultValue: kDefaultInviteBaseUrl,
);

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
/// - Any domain with /u/{identifier}
/// - vyayama://u/{identifier}
/// - Any domain with /invite/{username}
/// - /u/{identifier}
/// - @username
/// - bare identifier / UUID
String? parseProfileIdentifier(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return null;

  // Check for /u/
  final uIdx = value.toLowerCase().indexOf('/u/');
  if (uIdx >= 0) {
    value = value.substring(uIdx + 3);
  } else {
    // Check for /invite/
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
