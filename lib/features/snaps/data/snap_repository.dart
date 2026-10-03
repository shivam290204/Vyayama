import 'dart:typed_data';

import 'package:fitbuddy/features/snaps/data/snap.dart';

/// Reads and writes snaps. Swap the mock for a Supabase version later.
abstract class SnapRepository {
  /// Uploads [imageBytes] (already compressed, EXIF stripped) to the private
  /// `snaps` bucket and inserts the `snaps` and `snap_recipients` rows with
  /// status `pending`.
  ///
  /// Returns one snap for direct recipients (counts for streaks) and, when
  /// `draft.postToFeed` is set, a second one flagged `is_story`.
  Future<List<Snap>> submitSnap({
    required SnapDraft draft,
    required Uint8List imageBytes,
  });

  /// Verified, unexpired snaps sent directly to the user.
  Future<List<ReceivedSnap>> inbox();

  /// Verified, unexpired Friends Feed posts from accepted friends.
  Future<List<ReceivedSnap>> feed();

  /// A single received snap, or null if it expired or is not available.
  Future<ReceivedSnap?> getReceived(String snapId);

  Future<void> markViewed(String snapId);

  /// Saves an emoji reaction or preset reply on `snap_recipients.reaction`.
  Future<void> react(String snapId, String reaction);

  Future<void> reportSnap(String snapId, String reason);
}

/// Turns a storage path into a short-lived signed URL.
abstract class SnapImageUrlSigner {
  Future<String> signedUrl(
    String imagePath, {
    Duration ttl = const Duration(minutes: 5),
  });
}

/// Emoji reactions allowed on a snap.
const List<String> kSnapReactions = ['🔥', '💪', '👏'];

/// Preset replies (there is no free-text chat).
const List<String> kSnapPresetReplies = [
  'Nice work!',
  'Beast mode!',
  'Let\'s go together next time',
  'You inspire me',
];
