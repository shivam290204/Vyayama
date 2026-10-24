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
    if (animationAsset != null && animationAsset!.isNotEmpty) {
      return animationAsset!;
    }

    final clean = '${id.toLowerCase()}_${name.toLowerCase()}';

    // Exact and specialized 3D character exercise poses
    if (clean.contains('calf_raise') || clean.contains('calf raise')) {
      return 'assets/exercises/calf_raise.webp';
    }
    if (clean.contains('straight_leg_raise') || clean.contains('straight leg raise')) {
      return 'assets/exercises/straight_leg_raise.webp';
    }
    if (clean.contains('goblet_squat') || clean.contains('goblet squat')) {
      return 'assets/exercises/goblet_squat.webp';
    }
    if (clean.contains('clamshell')) {
      return 'assets/exercises/clamshell.webp';
    }
    if (clean.contains('rdl') || clean.contains('romanian deadlift')) {
      return 'assets/exercises/dumbbell_rdl.webp';
    }
    if (clean.contains('floor_press') || clean.contains('floor press')) {
      return 'assets/exercises/dumbbell_floor_press.webp';
    }
    if (clean.contains('cross_body') || clean.contains('shoulder_stretch') || clean.contains('shoulder stretch')) {
      return 'assets/exercises/shoulder_crossbody_stretch.webp';
    }
    if (clean.contains('band_pull_apart') || clean.contains('pull-apart') || clean.contains('pull apart')) {
      return 'assets/exercises/band_pull_apart.webp';
    }
    if (clean.contains('burpee')) {
      return 'assets/exercises/burpee.webp';
    }
    if (clean.contains('hamstring_stretch') || clean.contains('hamstring stretch') || clean.contains('hamstring')) {
      return 'assets/exercises/hamstring_stretch.webp';
    }
    if (clean.contains('warrior')) {
      return 'assets/exercises/warrior_pose.webp';
    }
    if (clean.contains('downward_dog') || clean.contains('downward dog') || clean.contains('downward-facing')) {
      return 'assets/exercises/downward_dog.webp';
    }
    if (clean.contains('cobra')) {
      return 'assets/exercises/cobra_pose.webp';
    }
    if (clean.contains('bicycle_crunch') || clean.contains('bicycle crunch')) {
      return 'assets/exercises/bicycle_crunch.webp';
    }
    if (clean.contains('bird_dog') || clean.contains('bird dog')) {
      return 'assets/exercises/bird_dog.webp';
    }
    if (clean.contains('cat_cow') || clean.contains('cat-cow') || clean.contains('cat cow')) {
      return 'assets/exercises/cat_cow.webp';
    }
    if (clean.contains('chair_dips') || clean.contains('dips')) {
      return 'assets/exercises/chair_dips.webp';
    }
    if (clean.contains('child_pose') || clean.contains("child's pose") || clean.contains('childs pose')) {
      return 'assets/exercises/child_pose.webp';
    }
    if (clean.contains('dead_bug') || clean.contains('dead bug')) {
      return 'assets/exercises/dead_bug.webp';
    }
    if (clean.contains('curl')) {
      return 'assets/exercises/bicep_curl.webp';
    }
    if (clean.contains('shoulder_press') || clean.contains('shoulder press')) {
      return 'assets/exercises/shoulder_press.webp';
    }
    if (clean.contains('bridge')) {
      return 'assets/exercises/glute_bridge.webp';
    }
    if (clean.contains('high_knees') || clean.contains('high knees')) {
      return 'assets/exercises/high_knees.webp';
    }
    if (clean.contains('incline_pushup') || clean.contains('incline push-up')) {
      return 'assets/exercises/incline_pushup.webp';
    }
    if (clean.contains('pushup') || clean.contains('push-up') || clean.contains('push_up')) {
      return 'assets/exercises/pushup.webp';
    }
    if (clean.contains('jumping_jacks') || clean.contains('jumping jacks')) {
      return 'assets/exercises/jumping_jacks.webp';
    }
    if (clean.contains('step_jacks') || clean.contains('step jacks')) {
      return 'assets/exercises/step_jacks.webp';
    }
    if (clean.contains('march')) {
      return 'assets/exercises/march_in_place.webp';
    }
    if (clean.contains('row')) {
      return 'assets/exercises/one_arm_dumbbell_row.webp';
    }
    if (clean.contains('plank')) {
      return 'assets/exercises/plank.webp';
    }
    if (clean.contains('quad_stretch') || clean.contains('quad stretch')) {
      return 'assets/exercises/quad_stretch.webp';
    }
    if (clean.contains('sun_salutation') || clean.contains('sun salutation')) {
      return 'assets/exercises/sun_salutation.webp';
    }
    if (clean.contains('superman')) {
      return 'assets/exercises/superman_hold.webp';
    }
    if (clean.contains('wall_sit') || clean.contains('wall sit')) {
      return 'assets/exercises/wall_sit.webp';
    }
    if (clean.contains('squat')) {
      return 'assets/exercises/squat.webp';
    }
    if (clean.contains('lunge')) {
      return 'assets/exercises/lunge.webp';
    }
    if (clean.contains('jog') || clean.contains('run') || clean.contains('walk')) {
      return 'assets/exercises/running.webp';
    }
    if (clean.contains('stretch') || clean.contains('yoga')) {
      return 'assets/exercises/meditation.webp';
    }
    if (clean.contains('tree_pose') || clean.contains('tree pose')) {
      return 'assets/exercises/tree_pose.webp';
    }
    if (clean.contains('seated_forward_fold') || clean.contains('forward fold')) {
      return 'assets/exercises/seated_forward_fold.webp';
    }
    if (clean.contains('russian_twist') || clean.contains('russian twist')) {
      return 'assets/exercises/russian_twist.webp';
    }
    if (clean.contains('mountain_climber') || clean.contains('mountain climber') || clean.contains('mountain_climbers')) {
      return 'assets/exercises/mountain_climbers.webp';
    }
    if (clean.contains('side_plank') || clean.contains('side plank')) {
      return 'assets/exercises/side_plank.webp';
    }
    if (clean.contains('lateral_raise') || clean.contains('lateral raise')) {
      return 'assets/exercises/lateral_raise.webp';
    }
    if (clean.contains('overhead_triceps') || clean.contains('overhead_tricep') || clean.contains('tricep')) {
      return 'assets/exercises/overhead_triceps_ext.webp';
    }
    if (clean.contains('reverse_lunge') || clean.contains('reverse lunge')) {
      return 'assets/exercises/lunge.webp';
    }
    if (clean.contains('press') || clean.contains('raise')) {
      return 'assets/exercises/flex_proud.webp';
    }

    return 'assets/exercises/standing_hero.webp';
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
