/// Base URL of invite links. Antigravity: point this at your real domain and
/// register it as an app link / universal link (handled by `app_links`).
const String kInviteBaseUrl = 'https://fitbuddy.app/invite/';

/// Builds the shareable invite link for [username].
String buildInviteLink(String username) =>
    '$kInviteBaseUrl${Uri.encodeComponent(username)}';

/// Extracts a username from a scanned QR value or a pasted invite link.
///
/// Accepts either the full link or a bare username. Returns null when empty.
String? parseInviteUsername(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return null;
  final idx = value.toLowerCase().indexOf('/invite/');
  if (idx >= 0) {
    value = value.substring(idx + '/invite/'.length);
  }
  value = value.split(RegExp(r'[?#/]')).first;
  value = Uri.decodeComponent(value).trim().replaceFirst(RegExp(r'^@'), '');
  return value.isEmpty ? null : value.toLowerCase();
}
