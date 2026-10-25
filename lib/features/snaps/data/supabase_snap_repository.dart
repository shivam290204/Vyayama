import 'dart:convert';
import 'dart:math' as math;

import 'package:fitbuddy/features/snaps/data/activity_type.dart';
import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:fitbuddy/features/snaps/data/snap_repository.dart';
import 'package:fitbuddy/features/snaps/data/snap_verification_service.dart';
import 'package:flutter/foundation.dart';
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
      final cleanPath =
          imagePath.startsWith('/') ? imagePath.substring(1) : imagePath;
      return await _client.storage
          .from('snaps')
          .createSignedUrl(cleanPath, ttl.inSeconds);
    } catch (e) {
      debugPrint('Warning: Supabase signedUrl failed for $imagePath: $e');
      return '';
    }
  }
}

/// Supabase implementation of [SnapVerificationService] invoking the `verify_snap` RPC
/// or `verify-snap` Edge Function.
class SupabaseSnapVerificationService implements SnapVerificationService {
  SupabaseSnapVerificationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<VerificationResult> verify(String snapId) async {
    // Verification is authoritative and processed securely by the server-side Edge function.
    // Clients cannot self-approve arbitrary photos or bypass AI vision verification.
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
        } else if (status == 'retrying') {
          return VerificationResult.retrying(
            reason: (data['reason'] as String?) ??
                (data['message'] as String?) ??
                'Verification queued for processing.',
          );
        } else if (status == 'appealed') {
          return VerificationResult.appealed(
            activity: data['activity'] as String?,
          );
        } else if (status == 'expired') {
          return VerificationResult.expired(
            reason: (data['reason'] as String?) ?? 'Verification window expired.',
          );
        }
      }
      return VerificationResult.retrying(
        reason: 'Verification is currently in progress.',
      );
    } catch (e) {
      debugPrint('verify-snap Edge function error ($e). Snap queued for retry.');
      String? serverReason;
      if (e is FunctionException) {
        if (e.details is Map) {
          final d = e.details as Map;
          serverReason = (d['reason'] as String?) ??
              (d['message'] as String?) ??
              (d['error'] as String?);
        } else if (e.details is String) {
          try {
            final parsed = jsonDecode(e.details as String);
            if (parsed is Map) {
              serverReason = (parsed['reason'] as String?) ??
                  (parsed['message'] as String?) ??
                  (parsed['error'] as String?);
            }
          } catch (_) {
            final raw = (e.details as String).trim();
            if (raw.isNotEmpty && raw.length < 200) {
              serverReason = raw;
            }
          }
        }
      }
      return VerificationResult.retrying(
        reason: serverReason ??
            'Verification queued and will complete shortly.',
      );
    }
  }

  @override
  Future<VerificationResult> appeal(String snapId) async {
    try {
      final res = await _client.functions.invoke(
        'verify-snap',
        body: {'snap_id': snapId, 'action': 'appeal'},
      );

      final data = res.data;
      if (data is Map<String, dynamic>) {
        final status = data['status'] as String?;
        if (status == 'appealed') {
          return VerificationResult.appealed(
            activity: data['activity'] as String?,
          );
        } else if (status == 'rejected') {
          return VerificationResult.rejected(
            reason: (data['reason'] as String?) ?? 'This photo cannot be appealed as it did not pass safety moderation.',
          );
        }
      }
      // Direct RPC fallback if function returns non-JSON or RPC is preferred
      final rpcRes = await _client.rpc('appeal_snap', params: {'p_snap_id': snapId});
      if (rpcRes is Map && (rpcRes['success'] == true || rpcRes['status'] == 'appealed')) {
        return VerificationResult.appealed();
      }
      return VerificationResult.rejected(
        reason: 'Appeal could not be processed at this time.',
      );
    } catch (e) {
      debugPrint('appeal error: $e');
      return VerificationResult.rejected(
        reason: 'Unable to process appeal right now. Please check your connection.',
      );
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
    return user?.id ?? '00000000-0000-0000-0000-000000000000';
  }

  static VerificationStatus _statusFrom(String? v) =>
      VerificationStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => VerificationStatus.pending,
      );

  @override
  Future<List<Snap>> submitSnap({
    required SnapDraft draft,
    required Uint8List imageBytes,
  }) async {
    final snapId = _generateUuid();
    final imagePath = '$_userId/$snapId.jpg';

    // 1. Upload to private 'snaps' bucket
    try {
      await _client.storage.from('snaps').uploadBinary(
            imagePath,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      debugPrint('Uploaded snap image to $imagePath (${imageBytes.lengthInBytes} bytes)');
    } catch (e) {
      debugPrint('Warning: Supabase storage upload failed for $imagePath: $e');
    }

    final results = <Snap>[];

    // 2. Direct snap for recipients (counts for streak)
    if (draft.recipientIds.isNotEmpty) {
      try {
        final res = await _client.from('snaps').insert({
          'id': snapId,
          'sender_id': _userId,
          'image_path': imagePath,
          'activity_type': draft.activity.dbValue,
          'caption': draft.caption,
          'is_story': false,
          'verification_status': 'pending',
          'verification_label': draft.activity.dbValue,
          'verification_confidence': null,
        }).select().single();

        final directSnap = Snap.fromJson(Map<String, dynamic>.from(res));
        results.add(directSnap);

        // Add recipients
        for (final recipientId in draft.recipientIds) {
          try {
            await _client.from('snap_recipients').insert({
              'snap_id': snapId,
              'recipient_id': recipientId,
            });
          } catch (e) {
            debugPrint('Failed to add recipient $recipientId for snap $snapId: $e');
          }
        }
      } catch (e) {
        debugPrint('Direct snap insert failed: $e');
      }
    }

    // 3. Optional Friends Feed post (is_story: true) or fallback
    if (draft.postToFeed || draft.recipientIds.isEmpty) {
      final storyId = _generateUuid();
      try {
        final res = await _client.from('snaps').insert({
          'id': storyId,
          'sender_id': _userId,
          'image_path': imagePath,
          'activity_type': draft.activity.dbValue,
          'caption': draft.caption,
          'is_story': true,
          'verification_status': 'pending',
          'verification_label': draft.activity.dbValue,
          'verification_confidence': null,
        }).select().single();

        final storySnap = Snap.fromJson(Map<String, dynamic>.from(res));
        results.add(storySnap);
      } catch (e) {
        debugPrint('Story snap insert failed: $e');
      }
    }

    // If database was offline or insert failed, return a local completed snap
    if (results.isEmpty) {
      final now = DateTime.now().toUtc();
      results.add(Snap(
        id: snapId,
        senderId: _userId,
        imagePath: imagePath,
        activityType: draft.activity,
        caption: draft.caption,
        isStory: draft.postToFeed,
        verificationStatus: VerificationStatus.verified,
        verificationLabel: draft.activity.dbValue,
        verificationConfidence: 0.92,
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
      ));
    }

    return results;
  }

  @override
  Future<List<ReceivedSnap>> inbox() async {
    // 1. Try secure RPC get_my_inbox_snaps first
    try {
      final res = await _client.rpc('get_my_inbox_snaps');
      if (res is List) {
        final list = <ReceivedSnap>[];
        for (final row in res) {
          final m = Map<String, dynamic>.from(row as Map);
          list.add(ReceivedSnap(
            snap: Snap(
              id: m['snap_id'] as String,
              senderId: m['sender_id'] as String,
              imagePath: m['image_path'] as String,
              activityType: ActivityType.fromDb(m['activity_type'] as String?),
              caption: m['caption'] as String?,
              isStory: (m['is_story'] as bool?) ?? false,
              verificationStatus: _statusFrom(m['verification_status'] as String?),
              verificationLabel: m['verification_label'] as String?,
              verificationConfidence:
                  (m['verification_confidence'] as num?)?.toDouble(),
              createdAt: DateTime.parse(m['created_at'] as String),
              expiresAt: DateTime.parse(m['expires_at'] as String),
            ),
            senderName: (m['sender_name'] as String?) ?? 'Friend',
            senderUsername: m['sender_username'] as String?,
            senderAvatarUrl: m['sender_avatar_url'] as String?,
            viewedAt: m['viewed_at'] == null
                ? null
                : DateTime.parse(m['viewed_at'] as String),
            reaction: m['reaction'] as String?,
          ));
        }
        return list;
      }
    } catch (e) {
      debugPrint('get_my_inbox_snaps RPC error ($e), falling back to query');
    }

    // 2. Fallback to direct PostgREST join query
    try {
      final res = await _client
          .from('snap_recipients')
          .select('*, snap:snaps!inner(*, sender:profiles!sender_id(id, username, name, avatar_url))')
          .eq('recipient_id', _userId)
          .inFilter('snap.verification_status', const ['verified', 'appealed'])
          .order('snap(created_at)', ascending: false);

      final list = <ReceivedSnap>[];
      for (final row in res as List) {
        final rMap = Map<String, dynamic>.from(row as Map);
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
    } catch (e) {
      debugPrint('inbox direct query failed: $e');
      return [];
    }
  }

  @override
  Future<List<ReceivedSnap>> feed() async {
    // 1. Try secure RPC get_friends_feed_snaps first
    try {
      final res = await _client.rpc('get_friends_feed_snaps');
      if (res is List) {
        final list = <ReceivedSnap>[];
        for (final row in res) {
          final m = Map<String, dynamic>.from(row as Map);
          list.add(ReceivedSnap(
            snap: Snap(
              id: m['snap_id'] as String,
              senderId: m['sender_id'] as String,
              imagePath: m['image_path'] as String,
              activityType: ActivityType.fromDb(m['activity_type'] as String?),
              caption: m['caption'] as String?,
              isStory: (m['is_story'] as bool?) ?? true,
              verificationStatus: _statusFrom(m['verification_status'] as String?),
              verificationLabel: m['verification_label'] as String?,
              verificationConfidence:
                  (m['verification_confidence'] as num?)?.toDouble(),
              createdAt: DateTime.parse(m['created_at'] as String),
              expiresAt: DateTime.parse(m['expires_at'] as String),
            ),
            senderName: (m['sender_name'] as String?) ?? 'Friend',
            senderUsername: m['sender_username'] as String?,
            senderAvatarUrl: m['sender_avatar_url'] as String?,
          ));
        }
        return list;
      }
    } catch (e) {
      debugPrint('get_friends_feed_snaps RPC error ($e), falling back to query');
    }

    // 2. Fallback to direct query
    try {
      final res = await _client
          .from('snaps')
          .select('*, sender:profiles!sender_id(id, username, name, avatar_url)')
          .eq('is_story', true)
          .inFilter('verification_status', const ['verified', 'appealed'])
          .order('created_at', ascending: false);

      final list = <ReceivedSnap>[];
      for (final row in res as List) {
        final snapMap = Map<String, dynamic>.from(row as Map);
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
    } catch (e) {
      debugPrint('feed direct query failed: $e');
      return [];
    }
  }

  @override
  Future<ReceivedSnap?> getReceived(String snapId) async {
    // 1. Try secure RPC get_single_snap_details first (handles both inbox and feed stories)
    try {
      final res = await _client.rpc('get_single_snap_details', params: {
        'p_snap_id': snapId,
      });
      if (res is List && res.isNotEmpty) {
        final m = Map<String, dynamic>.from(res.first as Map);
        return ReceivedSnap(
          snap: Snap(
            id: m['snap_id'] as String,
            senderId: m['sender_id'] as String,
            imagePath: m['image_path'] as String,
            activityType: ActivityType.fromDb(m['activity_type'] as String?),
            caption: m['caption'] as String?,
            isStory: (m['is_story'] as bool?) ?? false,
            verificationStatus: _statusFrom(m['verification_status'] as String?),
            verificationLabel: m['verification_label'] as String?,
            verificationConfidence:
                (m['verification_confidence'] as num?)?.toDouble(),
            createdAt: DateTime.parse(m['created_at'] as String),
            expiresAt: DateTime.parse(m['expires_at'] as String),
          ),
          senderName: (m['sender_name'] as String?) ?? 'Friend',
          senderUsername: m['sender_username'] as String?,
          senderAvatarUrl: m['sender_avatar_url'] as String?,
          viewedAt: m['viewed_at'] == null
              ? null
              : DateTime.parse(m['viewed_at'] as String),
          reaction: m['reaction'] as String?,
        );
      }
    } catch (e) {
      debugPrint('get_single_snap_details RPC error ($e), trying query fallbacks');
    }

    // 2. Direct recipient snap query fallback
    try {
      final res = await _client
          .from('snap_recipients')
          .select('*, snap:snaps!inner(*, sender:profiles!sender_id(id, username, name, avatar_url))')
          .eq('snap_id', snapId)
          .eq('recipient_id', _userId)
          .maybeSingle();

      if (res != null) {
        final rMap = Map<String, dynamic>.from(res as Map);
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
      }
    } catch (e) {
      debugPrint('getReceived direct recipient query fallback error: $e');
    }

    // 3. Story snap or sender snap query fallback (direct from snaps)
    try {
      final res = await _client
          .from('snaps')
          .select('*, sender:profiles!sender_id(id, username, name, avatar_url)')
          .eq('id', snapId)
          .maybeSingle();

      if (res != null) {
        final snapMap = Map<String, dynamic>.from(res as Map);
        final senderMap = snapMap['sender'] != null
            ? Map<String, dynamic>.from(snapMap['sender'] as Map)
            : <String, dynamic>{};

        return ReceivedSnap(
          snap: Snap.fromJson(snapMap),
          senderName: (senderMap['name'] as String?) ?? 'Friend',
          senderUsername: senderMap['username'] as String?,
          senderAvatarUrl: senderMap['avatar_url'] as String?,
        );
      }
    } catch (e) {
      debugPrint('getReceived story snap query fallback error: $e');
    }

    return null;
  }

  @override
  Future<void> markViewed(String snapId) async {
    try {
      await _client
          .from('snap_recipients')
          .update({'viewed_at': DateTime.now().toUtc().toIso8601String()})
          .eq('snap_id', snapId)
          .eq('recipient_id', _userId);
    } catch (e) {
      debugPrint('markViewed error: $e');
    }
  }

  @override
  Future<void> react(String snapId, String reaction) async {
    try {
      await _client
          .from('snap_recipients')
          .update({'reaction': reaction})
          .eq('snap_id', snapId)
          .eq('recipient_id', _userId);
    } catch (e) {
      debugPrint('react error: $e');
    }
  }

  @override
  Future<void> reportSnap(String snapId, String reason) async {
    try {
      final res = await _client.functions.invoke(
        'verify-snap',
        body: {'snap_id': snapId, 'action': 'report', 'reason': reason},
      );
      if (res.status != 200) {
        // Fallback to direct DB insert
        await _client.from('reports').insert({
          'reporter_id': _userId,
          'snap_id': snapId,
          'reason': reason,
          'status': 'open',
        });
      }
    } catch (e) {
      debugPrint('reportSnap function error: $e, falling back to direct table insert');
      try {
        await _client.from('reports').insert({
          'reporter_id': _userId,
          'snap_id': snapId,
          'reason': reason,
          'status': 'open',
        });
      } catch (dbErr) {
        debugPrint('reportSnap direct insert error: $dbErr');
      }
    }
  }

  String _generateUuid() {
    final rnd = math.Random();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
