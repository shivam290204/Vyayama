import 'package:flutter/foundation.dart';

/// Timestamped measurement record tracking weight and BMI progress over time.
@immutable
class BmiRecord {
  const BmiRecord({
    required this.id,
    required this.userId,
    required this.weightKg,
    required this.heightCm,
    required this.bmi,
    required this.recordedAt,
    this.notes,
  });

  final String id;
  final String userId;
  final double weightKg;
  final double heightCm;
  final double bmi;
  final DateTime recordedAt;
  final String? notes;

  factory BmiRecord.fromJson(Map<String, dynamic> json) {
    return BmiRecord(
      id: json['id'] as String,
      userId: (json['user_id'] ?? '') as String,
      weightKg: (json['weight_kg'] as num).toDouble(),
      heightCm: (json['height_cm'] as num).toDouble(),
      bmi: (json['bmi'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'bmi': bmi,
      'recorded_at': recordedAt.toIso8601String(),
      if (notes != null) 'notes': notes,
    };
  }
}
