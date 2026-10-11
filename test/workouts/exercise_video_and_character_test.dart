import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/providers.dart';

void main() {
  group('Exercise Model - Video and Character Character Tests', () {
    test('Parses video_url and youtubeVideoId from various URL formats', () {
      const ex1 = Exercise(
        id: 'ex_squat',
        name: 'Bodyweight Squat',
        muscleGroup: 'legs',
        equipment: 'none',
        instructions: ['Squat down'],
        commonMistakes: [],
        contraindications: [],
        met: 5.0,
        videoUrl: 'https://www.youtube.com/watch?v=aclHkVaku9U',
      );
      expect(ex1.youtubeVideoId, 'aclHkVaku9U');

      const ex2 = Exercise(
        id: 'ex_lunge',
        name: 'Forward Lunge',
        muscleGroup: 'legs',
        equipment: 'none',
        instructions: ['Step forward'],
        commonMistakes: [],
        contraindications: [],
        met: 4.0,
        videoUrl: 'https://youtu.be/QOVaHwm-Q6U',
      );
      expect(ex2.youtubeVideoId, 'QOVaHwm-Q6U');

      const ex3 = Exercise(
        id: 'ex_pushup',
        name: 'Push-Up',
        muscleGroup: 'chest',
        equipment: 'none',
        instructions: ['Push up'],
        commonMistakes: [],
        contraindications: [],
        met: 3.8,
        videoUrl: 'IODxDxX7oi4',
      );
      expect(ex3.youtubeVideoId, 'IODxDxX7oi4');

      const ex4 = Exercise(
        id: 'ex_custom',
        name: 'Custom',
        muscleGroup: 'legs',
        equipment: 'none',
        instructions: [],
        commonMistakes: [],
        contraindications: [],
        met: 3.0,
        videoUrl: null,
      );
      expect(ex4.youtubeVideoId, isNull);
    });

    test('Correctly maps 3D character asset poses based on exercise type', () {
      const squat = Exercise(
        id: 'ex_bodyweight_squat',
        name: 'Squat',
        muscleGroup: 'legs',
        equipment: 'none',
        instructions: [],
        commonMistakes: [],
        contraindications: [],
        met: 5.0,
      );
      expect(squat.characterAsset, 'assets/exercises/squat.png');

      const lunge = Exercise(
        id: 'ex_lunge',
        name: 'Lunge',
        muscleGroup: 'legs',
        equipment: 'none',
        instructions: [],
        commonMistakes: [],
        contraindications: [],
        met: 4.0,
      );
      expect(lunge.characterAsset, 'assets/exercises/lunge.png');

      const jog = Exercise(
        id: 'ex_light_jog',
        name: 'Easy Jog',
        muscleGroup: 'cardio',
        equipment: 'none',
        instructions: [],
        commonMistakes: [],
        contraindications: [],
        met: 7.0,
      );
      expect(jog.characterAsset, 'assets/exercises/running.png');

      const sun = Exercise(
        id: 'ex_sun_salutation',
        name: 'Sun Salutation',
        muscleGroup: 'flexibility',
        equipment: 'mat',
        instructions: [],
        commonMistakes: [],
        contraindications: [],
        met: 3.0,
      );
      expect(sun.characterAsset, 'assets/exercises/sun_salutation.png');

      const pushup = Exercise(
        id: 'ex_pushup',
        name: 'Push-Up',
        muscleGroup: 'chest',
        equipment: 'none',
        instructions: [],
        commonMistakes: [],
        contraindications: [],
        met: 3.8,
      );
      expect(pushup.characterAsset, 'assets/exercises/pushup.png');
    });

    test('Serialization to/from JSON preserves video_url', () {
      final json = {
        'id': 'ex_test',
        'name': 'Test',
        'muscle_group': 'core',
        'equipment': 'none',
        'instructions': ['step 1'],
        'common_mistakes': ['mistake 1'],
        'contraindications': ['wrist'],
        'met': 4.5,
        'video_url': 'https://www.youtube.com/watch?v=wiFNA3sqjCA',
      };

      final ex = Exercise.fromJson(json);
      expect(ex.videoUrl, 'https://www.youtube.com/watch?v=wiFNA3sqjCA');
      expect(ex.youtubeVideoId, 'wiFNA3sqjCA');

      final serialized = ex.toJson();
      expect(serialized['video_url'], 'https://www.youtube.com/watch?v=wiFNA3sqjCA');
    });

    test('customExerciseVideosProvider allows dynamic overrides', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(customExerciseVideosProvider), isEmpty);

      container.read(customExerciseVideosProvider.notifier).setVideoUrl(
        'ex_bodyweight_squat',
        'https://youtu.be/my_custom_video_1',
      );

      final state = container.read(customExerciseVideosProvider);
      expect(state['ex_bodyweight_squat'], 'https://youtu.be/my_custom_video_1');
    });
  });
}
