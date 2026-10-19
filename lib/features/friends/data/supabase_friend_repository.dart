import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/friends/data/friend_repository.dart';
import 'package:flutter/foundation.dart';
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
    // 1. Try friend_profiles view (covers accepted friends and self)
    try {
      final res = await _client
          .from('friend_profiles')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (res != null) {
        return FriendUser.fromJson(Map<String, dynamic>.from(res as Map));
      }
    } catch (_) {}

    // 2. Direct profiles table query
    try {
      final direct = await _client
          .from('profiles')
          .select('id, username, name, avatar_url, timezone')
          .eq('id', id)
          .maybeSingle();
      if (direct != null) {
        return FriendUser.fromJson(Map<String, dynamic>.from(direct as Map));
      }
    } catch (_) {}

    // 3. Try find_profile_by_identifier RPC (UUID match in SQL)
    try {
      final rpcRes = await _client.rpc(
        'find_profile_by_identifier',
        params: {'p_query': id},
      );
      if (rpcRes != null && (rpcRes as List).isNotEmpty) {
        final row = Map<String, dynamic>.from(rpcRes.first as Map);
        return FriendUser.fromJson(row);
      }
    } catch (_) {}

    // 4. Try find_profile_by_user_id RPC
    try {
      final rpcRes = await _client.rpc(
        'find_profile_by_user_id',
        params: {'p_user_id': id},
      );
      if (rpcRes != null && (rpcRes as List).isNotEmpty) {
        final row = Map<String, dynamic>.from(rpcRes.first as Map);
        return FriendUser.fromJson(row);
      }
    } catch (_) {}

    return null;
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
      final row = Map<String, dynamic>.from(res.first as Map);
      return FriendUser.fromJson(row);
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
        final row = Map<String, dynamic>.from(res.first as Map);
        return FriendUser.fromJson(row);
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
    if (addresseeId == _userId) {
      throw ArgumentError('Cannot add yourself as a friend');
    }

    // 1. Try secure RPC that handles existing friendships, reversals & duplicates
    try {
      final res = await _client.rpc(
        'send_friend_request',
        params: {'p_addressee_id': addresseeId},
      );
      debugPrint('send_friend_request RPC response: $res');
      return;
    } catch (e) {
      debugPrint('send_friend_request RPC unavailable ($e), using direct query...');
    }

    // 2. Direct fallback: check existing friendship to prevent constraint collisions
    final existing = await _client
        .from('friendships')
        .select()
        .or('and(requester_id.eq.$_userId,addressee_id.eq.$addresseeId),and(requester_id.eq.$addresseeId,addressee_id.eq.$_userId)')
        .maybeSingle();

    if (existing != null) {
      final status = existing['status'] as String?;
      final existingId = existing['id'] as String;
      if (status == 'accepted') {
        return; // Already friends
      } else if (status == 'pending' && existing['requester_id'] == addresseeId) {
        // The other user already sent a pending request: auto-accept!
        await acceptRequest(existingId);
        return;
      } else {
        // Revive declined or resend: delete old row and insert fresh to respect column-level RLS grants
        try {
          await _client.from('friendships').delete().eq('id', existingId);
        } catch (delErr) {
          debugPrint('Could not delete prior friendship row: $delErr');
        }
        await _client.from('friendships').insert({
          'requester_id': _userId,
          'addressee_id': addresseeId,
          'status': 'pending',
        });
        return;
      }
    }

    // 3. Fresh request insert
    await _client.from('friendships').insert({
      'requester_id': _userId,
      'addressee_id': addresseeId,
      'status': 'pending',
    });
  }

  @override
  Future<List<FriendRequest>> requests() async {
    // 1. Try secure RPC get_my_friend_requests
    try {
      final rpcRes = await _client.rpc('get_my_friend_requests');
      if (rpcRes is List && rpcRes.isNotEmpty) {
        final list = <FriendRequest>[];
        for (final row in rpcRes) {
          final rMap = Map<String, dynamic>.from(row as Map);
          final rawName = (rMap['other_name'] as String?)?.trim();
          final rawUname = (rMap['other_username'] as String?)?.trim();

          // Prefer real name if not generic, otherwise username (e.g. "shree")
          final displayName = (rawName != null &&
                  rawName.isNotEmpty &&
                  rawName != 'Athlete' &&
                  rawName != 'Pending Friend')
              ? rawName
              : ((rawUname != null && rawUname.isNotEmpty)
                  ? rawUname
                  : (rawName != null && rawName.isNotEmpty ? rawName : 'Friend'));

          final user = FriendUser(
            id: rMap['other_id'] as String,
            username: rawUname ?? '',
            name: displayName,
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
    } catch (e) {
      debugPrint('get_my_friend_requests RPC note: $e (using fallback query)');
    }

    // 2. Resilient fallback: Query friendships table directly, joining profiles if possible
    try {
      List res;
      try {
        res = await _client
            .from('friendships')
            .select(
                '*, requester:profiles!requester_id(id, username, name, avatar_url, timezone), addressee:profiles!addressee_id(id, username, name, avatar_url, timezone)')
            .eq('status', 'pending');
      } catch (_) {
        res = await _client
            .from('friendships')
            .select()
            .eq('status', 'pending');
      }

      final list = <FriendRequest>[];
      for (final row in res) {
        final rMap = Map<String, dynamic>.from(row as Map);
        final incoming = rMap['addressee_id'] == _userId;
        final otherId =
            (incoming ? rMap['requester_id'] : rMap['addressee_id']) as String;

        FriendUser? user;
        final joinedProfile = incoming ? rMap['requester'] : rMap['addressee'];
        if (joinedProfile != null && joinedProfile is Map) {
          final pMap = Map<String, dynamic>.from(joinedProfile);
          final rawName = (pMap['name'] as String?)?.trim();
          final rawUname = (pMap['username'] as String?)?.trim();
          final displayName = (rawName != null &&
                  rawName.isNotEmpty &&
                  rawName != 'Athlete' &&
                  rawName != 'Pending Friend')
              ? rawName
              : ((rawUname != null && rawUname.isNotEmpty)
                  ? rawUname
                  : (rawName != null && rawName.isNotEmpty ? rawName : 'Friend'));
          user = FriendUser(
            id: otherId,
            username: rawUname ?? '',
            name: displayName,
            avatarUrl: pMap['avatar_url'] as String?,
            timezone: (pMap['timezone'] as String?) ?? 'UTC',
          );
        }

        // Fetch user profile safely via getUser if not in join or username empty
        if (user == null || user.username.isEmpty) {
          try {
            final fetched = await getUser(otherId);
            if (fetched != null) {
              final rawName = fetched.name.trim();
              final rawUname = fetched.username.trim();
              final displayName = (rawName.isNotEmpty &&
                      rawName != 'Athlete' &&
                      rawName != 'Pending Friend')
                  ? rawName
                  : (rawUname.isNotEmpty
                      ? rawUname
                      : (rawName.isNotEmpty ? rawName : 'Friend'));
              user = FriendUser(
                id: fetched.id,
                username: rawUname,
                name: displayName,
                avatarUrl: fetched.avatarUrl,
                timezone: fetched.timezone,
              );
            }
          } catch (e) {
            debugPrint('getUser failed for $otherId: $e');
          }
        }

        user ??= FriendUser(
          id: otherId,
          username: '',
          name: 'Friend',
          avatarUrl: null,
          timezone: 'UTC',
        );

        final friendship = Friendship.fromJson(rMap);
        list.add(FriendRequest(
          friendship: friendship,
          user: user,
          incoming: incoming,
        ));
      }
      return list;
    } catch (e) {
      debugPrint('Friend requests fallback query error: $e');
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
