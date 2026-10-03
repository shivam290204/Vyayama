import 'package:flutter/services.dart';

/// Shares a team invite message.
///
/// Antigravity: replace [ClipboardInviteSharer] with an implementation that
/// calls `share_plus` and returns null.
abstract class InviteSharer {
  /// Shares [text]. May return a short message to show the user.
  Future<String?> share(String text);
}

/// Default sharer: copies the invite text to the clipboard.
class ClipboardInviteSharer implements InviteSharer {
  @override
  Future<String?> share(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    return 'Invite copied. Paste it into any chat.';
  }
}
