import 'dart:typed_data';

import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:fitbuddy/features/snaps/data/snap_repository.dart';
import 'package:fitbuddy/features/snaps/data/snap_verification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase implementation of [SnapImageUrlSigner] generating signed URLs for the private `snaps` bucket.
class SupabaseSnapImageUrlSigner implements SnapImageUrlSigner {
  SupabaseSnapImageUrlSigner({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<String> signedUrl(
    String imagePath, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    try {
      return await _client.storage
          .from('snaps')
          .createSignedUrl(imagePath, ttl.inSeconds);
    } catch (_) {
      return '';
    }
  }
}

/// Supabase implementation of [SnapVerificationService] invoking the `verify-snap` Edge Function.
class SupabaseSnapVerificationService implements SnapVerificationService {
  SupabaseSnapVerificationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<VerificationResult> verify(String snapId) async {
    try {
      final res = await _client.functions.invoke(
        'verify-snap',
        body: {'snap_id': snapId},
      );

      final data = res.data;
      if (data is Map<String, dynamic>) {
        final status = data['status'] as String?;
        if (status == 'verified') {
          return VerificationResult.verified(
            activity: data['activity'] as String?,
            confidence: (data['confidence'] as num?)?.toDouble(),
          );
        } else if (status == 'rejected') {
          return VerificationResult.rejected(
            reason: (data['reason'] as String?) ?? kFriendlyRejection,
          );
        }
      }
      return VerificationResult.rejected(reason: kFriendlyRejection);
    } catch (e) {
      // If function is not yet deployed or error, report friendly error
      return VerificationResult.rejected(reason: kFriendlyRejection);
    }
  }
}

/// Supabase implementation of [SnapRepository] backed by storage bucket `snaps`,
/// tables `snaps` and `snap_recipients`.
class SupabaseSnapRepository implements SnapRepository {
  SupabaseSnapRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('User not signed in');
    return user.id;
  }

  @override
  Future<List<Snap>> submitSnap({
    required SnapDraft draft,
    required Uint8List imageBytes,
  }) async {
    final snapId = _generateUuid();
    final imagePath = '$_userId/$snapId.jpg';

    // 1. Upload to private 'snaps' bucket
    await _client.storage.from('snaps').uploadBinary(
          imagePath,
          imageBytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    final results = <Snap>[];

    // 2. Direct snap for recipients (counts for streak)
    if (draft.recipientIds.isNotEmpty) {
      final res = await _client.from('snaps').insert({
        'id': snapId,
        'sender_id': _userId,
        'image_path': imagePath,
        'activity_type': draft.activity.dbValue,
        'caption': draft.caption,
        'is_story': false,
      }).select().single();

      final directSnap = Snap.fromJson(Map<String, dynamic>.from(res));
      results.add(directSnap);

      // Add recipients
      for (final recipientId in draft.recipientIds) {
        await _client.from('snap_recipients').insert({
          'snap_id': snapId,
          'recipient_id': recipientId,
        });
      }
    }

    // 3. Optional Friends Feed post (is_story: true)
    if (draft.postToFeed) {
      final storyId = _generateUuid();
      final res = await _client.from('snaps').insert({
        'id': storyId,
        'sender_id': _userId,
        'image_path': imagePath,
        'activity_type': draft.activity.dbValue,
        'caption': draft.caption,
        'is_story': true,
      }).select().single();

      final storySnap = Snap.fromJson(Map<String, dynamic>.from(res));
      results.add(storySnap);
    }

    return results;
  }

  @override
  Future<List<ReceivedSnap>> inbox() async {
    try {
      final res = await _client
          .from('snap_recipients')
          .select('*, snap:snaps!inner(*, sender:profiles!sender_id(id, username, name, avatar_url))')
          .eq('recipient_id', _userId)
          .eq('snap.verification_status', 'verified')
          .order('snap(created_at)', ascending: false);

      final list = <ReceivedSnap>[];
      for (final row in res as List) {
        final rMap = Map<String, dynamic>.from(row);
        final snapMap = Map<String, dynamic>.from(rMap['snap'] as Map);
        final senderMap = snapMap['sender'] != null
            ? Map<String, dynamic>.from(snapMap['sender'] as Map)
            : <String, dynamic>{};

        list.add(ReceivedSnap(
          snap: Snap.fromJson(snapMap),
          senderName: (senderMap['name'] as String?) ?? 'Friend',
          senderUsername: senderMap['username'] as String?,
          senderAvatarUrl: senderMap['avatar_url'] as String?,
          viewedAt: rMap['viewed_at'] == null
              ? null
              : DateTime.parse(rMap['viewed_at'] as String),
          reaction: rMap['reaction'] as String?,
        ));
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<ReceivedSnap>> feed() async {
    try {
      final res = await _client
          .from('snaps')
          .select('*, sender:profiles!sender_id(id, username, name, avatar_url)')
          .eq('is_story', true)
          .eq('verification_status', 'verified')
          .order('created_at', ascending: false);

      final list = <ReceivedSnap>[];
      for (final row in res as List) {
        final snapMap = Map<String, dynamic>.from(row);
        final senderMap = snapMap['sender'] != null
            ? Map<String, dynamic>.from(snapMap['sender'] as Map)
            : <String, dynamic>{};

        list.add(ReceivedSnap(
          snap: Snap.fromJson(snapMap),
          senderName: (senderMap['name'] as String?) ?? 'Friend',
          senderUsername: senderMap['username'] as String?,
          senderAvatarUrl: senderMap['avatar_url'] as String?,
        ));
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<ReceivedSnap?> getReceived(String snapId) async {
    try {
      final res = await _client
          .from('snap_recipients')
          .select('*, snap:snaps!inner(*, sender:profiles!sender_id(id, username, name, avatar_url))')
          .eq('snap_id', snapId)
          .eq('recipient_id', _userId)
          .maybeSingle();

      if (res == null) return null;
      final rMap = Map<String, dynamic>.from(res);
      final snapMap = Map<String, dynamic>.from(rMap['snap'] as Map);
      final senderMap = snapMap['sender'] != null
          ? Map<String, dynamic>.from(snapMap['sender'] as Map)
          : <String, dynamic>{};

      return ReceivedSnap(
        snap: Snap.fromJson(snapMap),
        senderName: (senderMap['name'] as String?) ?? 'Friend',
        senderUsername: senderMap['username'] as String?,
        senderAvatarUrl: senderMap['avatar_url'] as String?,
        viewedAt: rMap['viewed_at'] == null
            ? null
            : DateTime.parse(rMap['viewed_at'] as String),
        reaction: rMap['reaction'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> markViewed(String snapId) async {
    try {
      await _client
          .from('snap_recipients')
          .update({'viewed_at': DateTime.now().toUtc().toIso8601String()})
          .eq('snap_id', snapId)
          .eq('recipient_id', _userId);
    } catch (_) {}
  }

  @override
  Future<void> react(String snapId, String reaction) async {
    try {
      await _client
          .from('snap_recipients')
          .update({'reaction': reaction})
          .eq('snap_id', snapId)
          .eq('recipient_id', _userId);
    } catch (_) {}
  }

  @override
  Future<void> reportSnap(String snapId, String reason) async {
    try {
      await _client.from('reports').insert({
        'reporter_id': _userId,
        'snap_id': snapId,
        'reason': reason,
        'status': 'open',
      });
    } catch (_) {}
  }

  String _generateUuid() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'snap_$now';
  }
}
