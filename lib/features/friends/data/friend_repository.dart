import 'package:fitbuddy/features/friends/data/friend.dart';

/// Friend graph operations. Swap the mock for a Supabase version later.
abstract class FriendRepository {
  /// Accepted friends.
  Future<List<FriendUser>> friends();

  Future<FriendUser?> getUser(String id);

  /// Exact username match only. Returns null when nobody matches.
  Future<FriendUser?> findByUsername(String exactUsername);

  Future<FriendRelation> relationTo(String userId);

  Future<void> sendRequest(String addresseeId);

  /// Incoming and outgoing pending requests.
  Future<List<FriendRequest>> requests();

  Future<void> acceptRequest(String friendshipId);

  Future<void> declineRequest(String friendshipId);

  Future<void> cancelRequest(String friendshipId);

  Future<void> removeFriend(String friendId);

  Future<void> blockUser(String userId);

  Future<void> reportUser(String userId, String reason);
}
