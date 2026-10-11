import 'package:fitbuddy/features/workouts/data/json_helpers.dart';
import 'package:flutter/foundation.dart';

/// An exercise from the library (table `exercises`, plus `common_mistakes`
/// and `met` which come from the bundled JSON).
@immutable
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    required this.instructions,
    required this.commonMistakes,
    required this.contraindications,
    required this.met,
    this.animationAsset,
    this.videoUrl,
    this.formChecklist = const [],
    this.poses = const [],
    this.semanticDescription = '',
    this.reviewedBy,
    this.reviewedAt,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'].toString(),
      name: (json['name'] as String?) ?? '',
      muscleGroup: (json['muscle_group'] as String?) ?? 'full_body',
      equipment: (json['equipment'] as String?) ?? 'none',
      instructions: jsonSteps(json['instructions']),
      commonMistakes: jsonStringList(json['common_mistakes']),
      contraindications: jsonStringList(json['contraindications']),
      met: (json['met'] as num?)?.toDouble() ?? 3.0,
      animationAsset: json['animation_asset'] as String?,
      videoUrl: (json['video_url'] ?? json['youtube_id']) as String?,
      formChecklist: jsonStringList(json['form_checklist']),
      poses: jsonStringList(json['poses']),
      semanticDescription: (json['semantic_description'] as String?) ?? '',
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] as String?,
    );
  }

  final String id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final List<String> instructions;
  final List<String> commonMistakes;
  final List<String> contraindications;
  final double met;
  final String? animationAsset;
  final String? videoUrl;
  final List<String> formChecklist;
  final List<String> poses;
  final String semanticDescription;
  final String? reviewedBy;
  final String? reviewedAt;

  /// Extracts the YouTube video ID if [videoUrl] contains a valid YouTube link or ID.
  String? get youtubeVideoId {
    final url = videoUrl?.trim();
    if (url == null || url.isEmpty) return null;
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(url)) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtube.com')) {
      return uri.queryParameters['v'];
    } else if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    return null;
  }

  /// Returns the relative path of the best matching 3D character pose asset.
  String get characterAsset {
    final clean = '${id.toLowerCase()}_${name.toLowerCase()}';

    // Exact and specialized 3D character exercise poses
    if (clean.contains('bicycle_crunch') || clean.contains('bicycle crunch')) {
      return 'assets/exercises/bicycle_crunch.png';
    }
    if (clean.contains('bird_dog') || clean.contains('bird dog')) {
      return 'assets/exercises/bird_dog.png';
    }
    if (clean.contains('cat_cow') || clean.contains('cat-cow') || clean.contains('cat cow')) {
      return 'assets/exercises/cat_cow.png';
    }
    if (clean.contains('chair_dips') || clean.contains('dips')) {
      return 'assets/exercises/chair_dips.png';
    }
    if (clean.contains('child_pose') || clean.contains("child's pose") || clean.contains('childs pose')) {
      return 'assets/exercises/child_pose.png';
    }
    if (clean.contains('dead_bug') || clean.contains('dead bug')) {
      return 'assets/exercises/dead_bug.png';
    }
    if (clean.contains('curl')) {
      return 'assets/exercises/bicep_curl.png';
    }
    if (clean.contains('shoulder_press') || clean.contains('shoulder press')) {
      return 'assets/exercises/shoulder_press.png';
    }
    if (clean.contains('bridge')) {
      return 'assets/exercises/glute_bridge.png';
    }
    if (clean.contains('high_knees') || clean.contains('high knees')) {
      return 'assets/exercises/high_knees.png';
    }
    if (clean.contains('incline_pushup') || clean.contains('incline push-up')) {
      return 'assets/exercises/incline_pushup.png';
    }
    if (clean.contains('pushup') || clean.contains('push-up') || clean.contains('push_up')) {
      return 'assets/exercises/pushup.png';
    }
    if (clean.contains('jumping_jacks') || clean.contains('jumping jacks')) {
      return 'assets/exercises/jumping_jacks.png';
    }
    if (clean.contains('step_jacks') || clean.contains('step jacks')) {
      return 'assets/exercises/step_jacks.png';
    }
    if (clean.contains('march')) {
      return 'assets/exercises/march_in_place.png';
    }
    if (clean.contains('row')) {
      return 'assets/exercises/one_arm_dumbbell_row.png';
    }
    if (clean.contains('plank')) {
      return 'assets/exercises/plank.png';
    }
    if (clean.contains('quad_stretch') || clean.contains('quad stretch')) {
      return 'assets/exercises/quad_stretch.png';
    }
    if (clean.contains('sun_salutation') || clean.contains('sun salutation')) {
      return 'assets/exercises/sun_salutation.png';
    }
    if (clean.contains('superman')) {
      return 'assets/exercises/superman_hold.png';
    }
    if (clean.contains('wall_sit') || clean.contains('wall sit')) {
      return 'assets/exercises/wall_sit.png';
    }
    if (clean.contains('squat')) {
      return 'assets/exercises/squat.png';
    }
    if (clean.contains('lunge')) {
      return 'assets/exercises/lunge.png';
    }
    if (clean.contains('jog') || clean.contains('run') || clean.contains('walk') || clean.contains('burpee')) {
      return 'assets/exercises/running.png';
    }
    if (clean.contains('stretch') || clean.contains('yoga')) {
      return 'assets/exercises/meditation.png';
    }
    if (clean.contains('press') || clean.contains('raise') || clean.contains('rdl')) {
      return 'assets/exercises/flex_proud.png';
    }

    return 'assets/exercises/standing_hero.png';
  }

  /// Contraindication tags of this exercise that match [tags]
  /// (case-insensitive). Empty means no conflict.
  Set<String> conflictsWith(Iterable<String> tags) {
    final wanted = tags
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toSet();
    return {
      for (final c in contraindications)
        if (wanted.contains(c.toLowerCase())) c.toLowerCase(),
    };
  }

  bool isSafeFor(Iterable<String> tags) => conflictsWith(tags).isEmpty;

  Exercise copyWith({
    String? id,
    String? name,
    String? muscleGroup,
    String? equipment,
    List<String>? instructions,
    List<String>? commonMistakes,
    List<String>? contraindications,
    double? met,
    String? animationAsset,
    String? videoUrl,
    List<String>? formChecklist,
    List<String>? poses,
    String? semanticDescription,
    String? reviewedBy,
    String? reviewedAt,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      equipment: equipment ?? this.equipment,
      instructions: instructions ?? this.instructions,
      commonMistakes: commonMistakes ?? this.commonMistakes,
      contraindications: contraindications ?? this.contraindications,
      met: met ?? this.met,
      animationAsset: animationAsset ?? this.animationAsset,
      videoUrl: videoUrl ?? this.videoUrl,
      formChecklist: formChecklist ?? this.formChecklist,
      poses: poses ?? this.poses,
      semanticDescription: semanticDescription ?? this.semanticDescription,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'muscle_group': muscleGroup,
        'equipment': equipment,
        'instructions': instructions,
        'common_mistakes': commonMistakes,
        'animation_asset': animationAsset,
        'video_url': videoUrl,
        'contraindications': contraindications,
        'met': met,
        'form_checklist': formChecklist,
        'poses': poses,
        'semantic_description': semanticDescription,
        'reviewed_by': reviewedBy,
        'reviewed_at': reviewedAt,
      };

  @override
  bool operator ==(Object other) => other is Exercise && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
