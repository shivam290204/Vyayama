/// Persistent tombstone record representing an entity pending or confirmed in remote deletion.
class OutdoorTombstone {
  const OutdoorTombstone({
    required this.id,
    required this.entityType,
    required this.userId,
    required this.deletedAt,
    this.isRemoteSynced = false,
  });

  /// The unique identifier of the deleted record.
  final String id;

  /// The entity type: 'activity' or 'route'.
  final String entityType;

  /// The owner user ID at the time of deletion.
  final String userId;

  /// When the deletion was requested locally.
  final DateTime deletedAt;

  /// Whether this tombstone has been acknowledged and synced in Supabase outdoor_tombstones.
  final bool isRemoteSynced;

  OutdoorTombstone copyWith({
    String? id,
    String? entityType,
    String? userId,
    DateTime? deletedAt,
    bool? isRemoteSynced,
  }) =>
      OutdoorTombstone(
        id: id ?? this.id,
        entityType: entityType ?? this.entityType,
        userId: userId ?? this.userId,
        deletedAt: deletedAt ?? this.deletedAt,
        isRemoteSynced: isRemoteSynced ?? this.isRemoteSynced,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'entity_type': entityType,
        'user_id': userId,
        'deleted_at': deletedAt.toIso8601String(),
        'is_remote_synced': isRemoteSynced,
      };

  factory OutdoorTombstone.fromJson(Map<String, dynamic> json) =>
      OutdoorTombstone(
        id: json['id'] as String,
        entityType: json['entity_type'] as String? ?? 'activity',
        userId: json['user_id'] as String? ?? 'local_user',
        deletedAt: DateTime.tryParse(json['deleted_at'] as String? ?? '') ??
            DateTime.now(),
        isRemoteSynced: json['is_remote_synced'] as bool? ?? false,
      );

  /// Generates the payload to upsert into Supabase `outdoor_tombstones` table.
  Map<String, dynamic> toRemotePayload() => {
        'id': id,
        'entity_type': entityType,
        'user_id': userId,
        'deleted_at': deletedAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutdoorTombstone &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          entityType == other.entityType &&
          userId == other.userId;

  @override
  int get hashCode => id.hashCode ^ entityType.hashCode ^ userId.hashCode;
}

