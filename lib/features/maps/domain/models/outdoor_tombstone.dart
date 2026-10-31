/// Persistent tombstone record representing an entity pending remote deletion.
class OutdoorTombstone {
  const OutdoorTombstone({
    required this.id,
    required this.entityType,
    required this.userId,
    required this.deletedAt,
  });

  /// The unique identifier of the deleted record.
  final String id;

  /// The entity type: 'activity' or 'route'.
  final String entityType;

  /// The owner user ID at the time of deletion.
  final String userId;

  /// When the deletion was requested locally.
  final DateTime deletedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'entity_type': entityType,
        'user_id': userId,
        'deleted_at': deletedAt.toIso8601String(),
      };

  factory OutdoorTombstone.fromJson(Map<String, dynamic> json) =>
      OutdoorTombstone(
        id: json['id'] as String,
        entityType: json['entity_type'] as String? ?? 'activity',
        userId: json['user_id'] as String? ?? 'local_user',
        deletedAt: DateTime.tryParse(json['deleted_at'] as String? ?? '') ??
            DateTime.now(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutdoorTombstone &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          entityType == other.entityType;

  @override
  int get hashCode => id.hashCode ^ entityType.hashCode;
}

