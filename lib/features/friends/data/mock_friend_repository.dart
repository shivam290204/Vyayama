import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/friends/data/friend_repository.dart';
import 'package:fitbuddy/features/snap_streaks/data/mock_ids.dart';

/// In-memory [FriendRepository] with a few seeded people.
class MockFriendRepository implements FriendRepository {
  MockFriendRepository({required this.currentUserId}) {
    _friends.addAll({kMockSamId, kMockPriyaId, kMockArjunId});
    _requests
      ..add(_request('r1', kMockNehaId, incoming: true))
      ..add(_request('r2', kMockRohanId, incoming: false));
  }

  final String currentUserId;

  static const _directory = <String, FriendUser>{
    kMockSamId: FriendUser(
        id: kMockSamId, username: 'sam_runs', name: 'Sam', timezone: kMockTimezone),
    kMockPriyaId: FriendUser(
        id: kMockPriyaId,
        username: 'priya.yoga',
        name: 'Priya Nair',
        timezone: kMockTimezone),
    kMockArjunId: FriendUser(
        id: kMockArjunId,
        username: 'arjun_gym',
        name: 'Arjun',
        timezone: kMockTimezone),
    kMockNehaId: FriendUser(
        id: kMockNehaId,
        username: 'neha_walks',
        name: 'Neha',
        timezone: kMockTimezone),
    kMockRohanId: FriendUser(
        id: kMockRohanId,
        username: 'rohan_rides',
        name: 'Rohan',
        timezone: kMockTimezone),
    kMockMayaId: FriendUser(
        id: kMockMayaId,
        username: 'maya_fit',
        name: 'Maya',
        timezone: kMockTimezone),
  };

  final Set<String> _friends = {};
  final Set<String> _blocked = {};
  final List<FriendRequest> _requests = [];
  int _counter = 0;

  FriendRequest _request(String id, String other, {required bool incoming}) {
    return FriendRequest(
      friendship: Friendship(
        id: id,
        requesterId: incoming ? other : currentUserId,
        addresseeId: incoming ? currentUserId : other,
        createdAt: DateTime.now(),
      ),
      user: _directory[other]!,
      incoming: incoming,
    );
  }

  Future<void> _latency() => Future<void>.delayed(const Duration(milliseconds: 250));

  @override
  Future<List<FriendUser>> friends() async {
    await _latency();
    return _friends.map((id) => _directory[id]!).toList();
  }

  @override
  Future<FriendUser?> getUser(String id) async {
    await _latency();
    return _friends.contains(id) ? _directory[id] : null;
  }

  @override
  Future<FriendUser?> findByUsername(String exactUsername) async {
    await _latency();
    final q = exactUsername.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final u in _directory.values) {
      if (u.username.toLowerCase() == q && !_blocked.contains(u.id)) return u;
    }
    return null;
  }

  @override
  Future<FriendRelation> relationTo(String userId) async {
    if (_friends.contains(userId)) return FriendRelation.friends;
    for (final r in _requests) {
      if (r.user.id == userId) {
        return r.incoming ? FriendRelation.requestReceived : FriendRelation.requestSent;
      }
    }
    return FriendRelation.none;
  }

  @override
  Future<void> sendRequest(String addresseeId) async {
    await _latency();
    if (await relationTo(addresseeId) != FriendRelation.none) {
      throw StateError('Already connected or pending');
    }
    _requests.add(_request('r${++_counter + 10}', addresseeId, incoming: false));
  }

  @override
  Future<List<FriendRequest>> requests() async {
    await _latency();
    return List.unmodifiable(_requests);
  }

  @override
  Future<void> acceptRequest(String friendshipId) async {
    await _latency();
    final i = _requests.indexWhere((r) => r.friendship.id == friendshipId);
    if (i < 0) return;
    _friends.add(_requests[i].user.id);
    _requests.removeAt(i);
  }

  @override
  Future<void> declineRequest(String friendshipId) async {
    await _latency();
    _requests.removeWhere((r) => r.friendship.id == friendshipId);
  }

  @override
  Future<void> cancelRequest(String friendshipId) => declineRequest(friendshipId);

  @override
  Future<void> removeFriend(String friendId) async {
    await _latency();
    _friends.remove(friendId);
  }

  @override
  Future<void> blockUser(String userId) async {
    await _latency();
    _friends.remove(userId);
    _requests.removeWhere((r) => r.user.id == userId);
    _blocked.add(userId);
  }

  @override
  Future<void> reportUser(String userId, String reason) async {
    await _latency();
  }
}
