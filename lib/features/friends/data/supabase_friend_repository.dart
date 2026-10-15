import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/friends/data/friend_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase implementation of [FriendRepository] backed by `friendships`,
/// `friend_profiles` view, `reports`, and friend RPCs.
class SupabaseFriendRepository implements FriendRepository {
  SupabaseFriendRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('User not signed in');
    return user.id;
  }

  @override
  Future<List<FriendUser>> friends() async {
    try {
      final res = await _client
          .from('friend_profiles')
          .select()
          .neq('id', _userId);

      return (res as List)
          .map((r) => FriendUser.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<FriendUser?> getUser(String id) async {
    try {
      // 1. Try friend_profiles view (covers accepted friends and self)
      final res = await _client
          .from('friend_profiles')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (res != null) {
        return FriendUser.fromJson(Map<String, dynamic>.from(res));
      }

      // 2. Try secure RPC for users not yet friends
      final rpcRes = await _client.rpc(
        'find_profile_by_user_id',
        params: {'p_user_id': id},
      );
      if (rpcRes != null && (rpcRes as List).isNotEmpty) {
        final row = rpcRes.first as Map<String, dynamic>;
        return FriendUser.fromJson(Map<String, dynamic>.from(row));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<FriendUser?> findByUsername(String exactUsername) async {
    final query = exactUsername.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');
    if (query.isEmpty) return null;

    try {
      final res = await _client.rpc(
        'find_profile_by_username',
        params: {'p_username': query},
      );

      if (res == null || (res as List).isEmpty) return null;
      final row = res.first as Map<String, dynamic>;
      return FriendUser.fromJson(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<FriendUser?> findByIdentifier(String identifier) async {
    final query = identifier.trim();
    if (query.isEmpty) return null;

    try {
      // Try unified RPC first
      final res = await _client.rpc(
        'find_profile_by_identifier',
        params: {'p_query': query},
      );

      if (res != null && (res as List).isNotEmpty) {
        final row = res.first as Map<String, dynamic>;
        return FriendUser.fromJson(Map<String, dynamic>.from(row));
      }
    } catch (_) {
      // Fallback below
    }

    // Check if query is UUID format
    final isUuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(query);

    if (isUuid) {
      return getUser(query);
    }
    return findByUsername(query);
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final query = username.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');
    if (query.isEmpty) return false;

    try {
      final res = await _client.rpc(
        'check_username_available',
        params: {'p_username': query},
      );
      if (res is bool) return res;
    } catch (_) {
      // Fallback
    }

    final existing = await findByUsername(query);
    return existing == null;
  }

  @override
  Future<FriendRelation> relationTo(String userId) async {
    try {
      final res = await _client
          .from('friendships')
          .select()
          .or('and(requester_id.eq.$_userId,addressee_id.eq.$userId),and(requester_id.eq.$userId,addressee_id.eq.$_userId)')
          .maybeSingle();

      if (res == null) return FriendRelation.none;
      final status = res['status'] as String?;
      if (status == 'accepted') return FriendRelation.friends;
      if (status == 'pending') {
        return res['requester_id'] == _userId
            ? FriendRelation.requestSent
            : FriendRelation.requestReceived;
      }
      return FriendRelation.none;
    } catch (_) {
      return FriendRelation.none;
    }
  }

  @override
  Future<void> sendRequest(String addresseeId) async {
    // 1. Try secure RPC that handles existing friendships, reversals & duplicates
    try {
      await _client.rpc(
        'send_friend_request',
        params: {'p_addressee_id': addresseeId},
      );
      return;
    } catch (_) {
      // Fallback to direct upsert/insert
    }

    try {
      await _client.from('friendships').upsert({
        'requester_id': _userId,
        'addressee_id': addresseeId,
        'status': 'pending',
      });
    } catch (_) {
      await _client.from('friendships').insert({
        'requester_id': _userId,
        'addressee_id': addresseeId,
        'status': 'pending',
      });
    }
  }

  @override
  Future<List<FriendRequest>> requests() async {
    // 1. Try secure RPC get_my_friend_requests
    try {
      final rpcRes = await _client.rpc('get_my_friend_requests');
      if (rpcRes is List) {
        final list = <FriendRequest>[];
        for (final row in rpcRes) {
          final rMap = Map<String, dynamic>.from(row as Map);
          final user = FriendUser(
            id: rMap['other_id'] as String,
            username: (rMap['other_username'] as String?) ?? '',
            name: (rMap['other_name'] as String?) ?? 'Athlete',
            avatarUrl: rMap['other_avatar_url'] as String?,
            timezone: (rMap['other_timezone'] as String?) ?? 'UTC',
          );
          final friendship = Friendship.fromJson(rMap);
          final incoming = rMap['is_incoming'] == true ||
              rMap['addressee_id'] == _userId;

          list.add(FriendRequest(
            friendship: friendship,
            user: user,
            incoming: incoming,
          ));
        }
        return list;
      }
    } catch (_) {
      // Fallback to table query + getUser profile resolution
    }

    // 2. Fallback: Query friendships table directly, then fetch user profiles
    try {
      final res = await _client
          .from('friendships')
          .select()
          .eq('status', 'pending');

      final list = <FriendRequest>[];
      for (final row in res as List) {
        final rMap = Map<String, dynamic>.from(row as Map);
        final incoming = rMap['addressee_id'] == _userId;
        final otherId =
            (incoming ? rMap['requester_id'] : rMap['addressee_id']) as String;

        // Fetch user profile safely via getUser (which uses find_profile_by_user_id RPC)
        final user = await getUser(otherId);
        if (user != null) {
          final friendship = Friendship.fromJson(rMap);
          list.add(FriendRequest(
            friendship: friendship,
            user: user,
            incoming: incoming,
          ));
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> acceptRequest(String friendshipId) async {
    await _client
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('id', friendshipId);
  }

  @override
  Future<void> declineRequest(String friendshipId) async {
    await _client
        .from('friendships')
        .update({'status': 'declined'})
        .eq('id', friendshipId);
  }

  @override
  Future<void> cancelRequest(String friendshipId) async {
    await _client.from('friendships').delete().eq('id', friendshipId);
  }

  @override
  Future<void> removeFriend(String friendId) async {
    await _client.from('friendships').delete().or(
      'and(requester_id.eq.$_userId,addressee_id.eq.$friendId),and(requester_id.eq.$friendId,addressee_id.eq.$_userId)',
    );
  }

  @override
  Future<void> blockUser(String userId) async {
    await _client.rpc('block_user', params: {'p_user_id': userId});
  }

  @override
  Future<void> reportUser(String userId, String reason) async {
    await _client.from('reports').insert({
      'reporter_id': _userId,
      'reported_user_id': userId,
      'reason': reason,
      'status': 'open',
    });
  }
}
