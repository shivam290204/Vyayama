import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/features/nutrition/data/local_nutrition_repository.dart';

void main() {
  group('LocalNutritionRepository', () {
    late SharedPreferences prefs;
    late LocalNutritionRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = LocalNutritionRepository(prefs: prefs);
    });

    test('stores and retrieves water glasses for a specific date', () async {
      final today = DateTime(2026, 10, 20);
      final yesterday = DateTime(2026, 10, 19);

      expect(await repo.getWaterGlasses(today), 0);

      await repo.setWaterGlasses(today, 6);
      expect(await repo.getWaterGlasses(today), 6);
      expect(await repo.getWaterGlasses(yesterday), 0); // separate day isolated

      await repo.setWaterGlasses(yesterday, 8);
      expect(await repo.getWaterGlasses(yesterday), 8);
      expect(await repo.getWaterGlasses(today), 6);
    });

    test('saves and loads dietary preferences', () async {
      expect(repo.getSavedDietType(), isNull);
      await repo.saveDietType('vegan');
      expect(repo.getSavedDietType(), 'vegan');

      expect(repo.getSavedActivityLevel(), isNull);
      await repo.saveActivityLevel('active');
      expect(repo.getSavedActivityLevel(), 'active');

      expect(repo.getSavedConditionFriendly(), isNull);
      await repo.saveConditionFriendly(false);
      expect(repo.getSavedConditionFriendly(), isFalse);
    });
  });
}
