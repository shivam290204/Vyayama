import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Shares a team invite message.
abstract class InviteSharer {
  /// Shares [text]. May return a short message to show the user.
  Future<String?> share(String text);
}

/// Native share implementation using `share_plus`, falling back to clipboard.
class SharePlusInviteSharer implements InviteSharer {
  @override
  Future<String?> share(String text) async {
    try {
      await Share.share(text);
      return null;
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      return 'Invite copied. Paste it into any chat.';
    }
  }
}

/// Fallback sharer: copies the invite text to the clipboard.
class ClipboardInviteSharer implements InviteSharer {
  @override
  Future<String?> share(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    return 'Invite copied. Paste it into any chat.';
  }
}
