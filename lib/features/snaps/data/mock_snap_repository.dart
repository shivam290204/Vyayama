import 'dart:typed_data';

import 'package:fitbuddy/features/snap_streaks/data/mock_ids.dart';
import 'package:fitbuddy/features/snaps/data/activity_type.dart';
import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:fitbuddy/features/snaps/data/snap_repository.dart';

/// In-memory [SnapRepository] seeded with a few friends' snaps.
class MockSnapRepository implements SnapRepository {
  MockSnapRepository({required this.currentUserId, required this.clock}) {
    _seed();
  }

  final String currentUserId;
  final DateTime Function() clock;

  final List<ReceivedSnap> _received = [];
  final Map<String, Snap> _sent = {};
  final Map<String, List<String>> _recipients = {};
  int _counter = 0;

  void _seed() {
    final now = clock().toUtc();
    ReceivedSnap make(
      String id,
      String sender,
      ActivityType type,
      Duration age, {
      bool story = false,
      String? caption,
      bool viewed = false,
      String? reaction,
    }) {
      final created = now.subtract(age);
      return ReceivedSnap(
        snap: Snap(
          id: id,
          senderId: sender,
          imagePath: '$sender/$id.jpg',
          activityType: type,
          caption: caption,
          isStory: story,
          verificationStatus: VerificationStatus.verified,
          verificationLabel: type.dbValue,
          verificationConfidence: 0.92,
          createdAt: created,
          expiresAt: created.add(const Duration(hours: 24)),
        ),
        senderName: kMockUserNames[sender] ?? 'Friend',
        viewedAt: viewed ? created.add(const Duration(minutes: 10)) : null,
        reaction: reaction,
      );
    }

    _received.addAll([
      make('seed-1', kMockSamId, ActivityType.running, const Duration(hours: 2),
          caption: '5K done before work!'),
      make('seed-2', kMockPriyaId, ActivityType.yoga, const Duration(hours: 5),
          viewed: true, reaction: '🔥'),
      make('seed-3', kMockArjunId, ActivityType.gym, const Duration(hours: 3),
          story: true, caption: 'Leg day'),
      make('seed-4', kMockSamId, ActivityType.walking, const Duration(hours: 9),
          story: true),
      make('seed-5', kMockPriyaId, ActivityType.stretching, const Duration(hours: 20),
          story: true, caption: 'Cool down'),
    ]);
  }

  Future<void> _latency([int ms = 250]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  @override
  Future<List<Snap>> submitSnap({
    required SnapDraft draft,
    required Uint8List imageBytes,
  }) async {
    await _latency(700);
    final now = clock().toUtc();
    Snap make({required bool story}) {
      final id = 'snap-${++_counter}';
      final snap = Snap(
        id: id,
        senderId: currentUserId,
        imagePath: '$currentUserId/$id.jpg',
        activityType: draft.activity,
        caption: draft.caption,
        isStory: story,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
      );
      _sent[id] = snap;
      _recipients[id] = story ? const [] : List.of(draft.recipientIds);
      return snap;
    }

    return [
      if (draft.recipientIds.isNotEmpty) make(story: false),
      if (draft.postToFeed) make(story: true),
    ];
  }

  /// Mock only: the snap the user just sent.
  Snap? sentSnap(String id) => _sent[id];

  /// Mock only: recipients of a sent snap.
  List<String> recipientsOf(String id) => _recipients[id] ?? const [];

  /// Mock only: applies a verification verdict, like the Edge Function does.
  void markVerification(String id, VerificationResult result) {
    final snap = _sent[id];
    if (snap == null) return;
    final updated = snap.copyWith(
      verificationStatus: result.status,
      verificationLabel: result.activity,
      verificationConfidence: result.confidence,
      rejectionReason: result.reason,
    );
    _sent[id] = updated;
    if (result.isVerified && updated.isStory) {
      _received.add(ReceivedSnap(
        snap: updated,
        senderName: kMockUserNames[currentUserId]!,
        viewedAt: clock().toUtc(),
      ));
    }
  }

  bool _live(ReceivedSnap r) =>
      r.snap.verificationStatus == VerificationStatus.verified &&
      r.snap.expiresAt.isAfter(clock().toUtc());

  @override
  Future<List<ReceivedSnap>> inbox() async {
    await _latency();
    return _received.where((r) => _live(r) && !r.snap.isStory && r.snap.senderId != currentUserId).toList()
      ..sort((a, b) => b.snap.createdAt.compareTo(a.snap.createdAt));
  }

  @override
  Future<List<ReceivedSnap>> feed() async {
    await _latency();
    return _received.where((r) => _live(r) && r.snap.isStory).toList()
      ..sort((a, b) => b.snap.createdAt.compareTo(a.snap.createdAt));
  }

  @override
  Future<ReceivedSnap?> getReceived(String snapId) async {
    await _latency(100);
    for (final r in _received) {
      if (r.snap.id == snapId && _live(r)) return r;
    }
    return null;
  }

  void _update(String snapId, ReceivedSnap Function(ReceivedSnap) change) {
    final i = _received.indexWhere((r) => r.snap.id == snapId);
    if (i >= 0) _received[i] = change(_received[i]);
  }

  @override
  Future<void> markViewed(String snapId) async {
    _update(snapId, (r) => r.viewedAt != null ? r : r.copyWith(viewedAt: clock().toUtc()));
  }

  @override
  Future<void> react(String snapId, String reaction) async {
    await _latency(100);
    _update(snapId, (r) => r.copyWith(reaction: reaction));
  }

  @override
  Future<void> reportSnap(String snapId, String reason) async {
    await _latency();
  }
}

/// Signer for mock data. Real impl: `storage.from('snaps').createSignedUrl`.
class MockSnapImageUrlSigner implements SnapImageUrlSigner {
  @override
  Future<String> signedUrl(String imagePath,
      {Duration ttl = const Duration(minutes: 5)}) async {
    return 'mock://$imagePath';
  }
}
