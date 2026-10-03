import 'package:fitbuddy/features/snaps/data/activity_type.dart';
import 'package:flutter/foundation.dart';

/// `snaps.verification_status`.
enum VerificationStatus { pending, verified, rejected }

VerificationStatus _statusFrom(String? v) => VerificationStatus.values.firstWhere(
      (e) => e.name == v,
      orElse: () => VerificationStatus.pending,
    );

/// Maximum caption length, matching the database check constraint.
const int kMaxCaptionLength = 140;

/// Friendly reason shown when a photo does not look like exercise.
const String kFriendlyRejection =
    'This doesn\'t look like exercise yet. Try a photo of your workout, your run, your mat or your gym spot!';

/// One row of `snaps`.
@immutable
class Snap {
  const Snap({
    required this.id,
    required this.senderId,
    required this.imagePath,
    required this.activityType,
    required this.createdAt,
    required this.expiresAt,
    this.caption,
    this.isStory = false,
    this.verificationStatus = VerificationStatus.pending,
    this.verificationLabel,
    this.verificationConfidence,
    this.rejectionReason,
  });

  factory Snap.fromJson(Map<String, dynamic> j) => Snap(
        id: j['id'] as String,
        senderId: j['sender_id'] as String,
        imagePath: j['image_path'] as String,
        activityType: ActivityType.fromDb(j['activity_type'] as String?),
        caption: j['caption'] as String?,
        isStory: (j['is_story'] as bool?) ?? false,
        verificationStatus: _statusFrom(j['verification_status'] as String?),
        verificationLabel: j['verification_label'] as String?,
        verificationConfidence: (j['verification_confidence'] as num?)?.toDouble(),
        rejectionReason: j['rejection_reason'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        expiresAt: DateTime.parse(j['expires_at'] as String),
      );

  final String id;
  final String senderId;
  final String imagePath;
  final ActivityType activityType;
  final String? caption;
  final bool isStory;
  final VerificationStatus verificationStatus;
  final String? verificationLabel;
  final double? verificationConfidence;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime expiresAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_id': senderId,
        'image_path': imagePath,
        'activity_type': activityType.dbValue,
        'caption': caption,
        'is_story': isStory,
        'verification_status': verificationStatus.name,
        'verification_label': verificationLabel,
        'verification_confidence': verificationConfidence,
        'rejection_reason': rejectionReason,
        'created_at': createdAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      };

  Snap copyWith({
    VerificationStatus? verificationStatus,
    String? verificationLabel,
    double? verificationConfidence,
    String? rejectionReason,
  }) =>
      Snap(
        id: id,
        senderId: senderId,
        imagePath: imagePath,
        activityType: activityType,
        caption: caption,
        isStory: isStory,
        verificationStatus: verificationStatus ?? this.verificationStatus,
        verificationLabel: verificationLabel ?? this.verificationLabel,
        verificationConfidence: verificationConfidence ?? this.verificationConfidence,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        createdAt: createdAt,
        expiresAt: expiresAt,
      );
}

/// A snap as seen by a recipient (joins `snap_recipients` and the sender).
@immutable
class ReceivedSnap {
  const ReceivedSnap({
    required this.snap,
    required this.senderName,
    this.senderUsername,
    this.senderAvatarUrl,
    this.viewedAt,
    this.reaction,
  });

  final Snap snap;
  final String senderName;
  final String? senderUsername;
  final String? senderAvatarUrl;

  /// `snap_recipients.viewed_at`.
  final DateTime? viewedAt;

  /// `snap_recipients.reaction`: an emoji or a preset reply.
  final String? reaction;

  bool get isUnviewed => viewedAt == null;

  ReceivedSnap copyWith({DateTime? viewedAt, String? reaction}) => ReceivedSnap(
        snap: snap,
        senderName: senderName,
        senderUsername: senderUsername,
        senderAvatarUrl: senderAvatarUrl,
        viewedAt: viewedAt ?? this.viewedAt,
        reaction: reaction ?? this.reaction,
      );
}

/// What the user chose in the preview screen.
@immutable
class SnapDraft {
  const SnapDraft({
    required this.activity,
    required this.recipientIds,
    required this.postToFeed,
    this.caption,
  });

  final ActivityType activity;
  final String? caption;

  /// Friends who receive the snap directly (these count for pair streaks).
  final List<String> recipientIds;

  /// Also post to the Friends Feed (does not count for streaks).
  final bool postToFeed;
}

/// Outcome of the server-side check.
@immutable
class VerificationResult {
  const VerificationResult._(this.status, {this.reason, this.activity, this.confidence});

  factory VerificationResult.verified({String? activity, double? confidence}) =>
      VerificationResult._(VerificationStatus.verified,
          activity: activity, confidence: confidence);

  factory VerificationResult.rejected({required String reason}) =>
      VerificationResult._(VerificationStatus.rejected, reason: reason);

  final VerificationStatus status;
  final String? reason;
  final String? activity;
  final double? confidence;

  bool get isVerified => status == VerificationStatus.verified;
}

/// A photo captured by the in-app camera (never from the gallery).
@immutable
class CapturedPhoto {
  const CapturedPhoto({required this.path, required this.bytes});

  final String path;
  final Uint8List bytes;
}
