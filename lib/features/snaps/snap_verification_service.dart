import 'package:flutter/foundation.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

enum SnapVerificationState {
  idle,
  sending,
  verifying,
  verified,
  rejected,
}

abstract class SnapVerificationService {
  Future<bool> preCheckImage(String imagePath);
  Future<Map<String, dynamic>> submitForVerification(String imagePath, String activity);
}

class MockSnapVerificationService implements SnapVerificationService {
  @override
  Future<bool> preCheckImage(String imagePath) async {
    if (kIsWeb) return true; // ML Kit doesn't support web easily, assume true

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final imageLabeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5));
      final labels = await imageLabeler.processImage(inputImage);
      imageLabeler.close();

      // Simple heuristic: if we see labels related to exercise/sports, it's likely an exercise
      final exerciseKeywords = ['sport', 'exercise', 'gym', 'fitness', 'running', 'shoe', 'dumbbell', 'weight', 'yoga'];
      
      for (final label in labels) {
        final text = label.label.toLowerCase();
        if (exerciseKeywords.any((keyword) => text.contains(keyword))) {
          return true;
        }
      }
      // It's just a hint, we return true if we're unsure so we don't block the user
      return true; 
    } catch (e) {
      debugPrint('ML Kit error: $e');
      return true; // Fallback to allowing submission
    }
  }

  @override
  Future<Map<String, dynamic>> submitForVerification(String imagePath, String activity) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 3));
    
    // In mock, 80% chance of success
    final isSuccess = DateTime.now().millisecond % 10 < 8;
    
    if (isSuccess) {
      return {'status': 'verified', 'reason': null};
    } else {
      return {'status': 'rejected', 'reason': 'We couldn\'t clearly see the exercise in this photo. Please try again!'};
    }
  }
}
