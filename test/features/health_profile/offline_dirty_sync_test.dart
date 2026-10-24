import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/features/health_profile/data/medicine.dart';
import 'package:fitbuddy/features/health_profile/data/supabase_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  const testUserId = 'test_user_health_dirty_sync';

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'last_signed_in_user_id': testUserId,
    });
    prefs = await SharedPreferences.getInstance();
  });

  group('BUG-04: Health Profile Offline Overwrite Protection Tests', () {
    test('saveSelectedConditionKeys sets dirty flag and getSelectedConditionKeys retains local edits', () async {
      final repo = SupabaseHealthRepository(prefs: prefs, client: null);

      await repo.saveSelectedConditionKeys(['hypertension', 'type_2_diabetes']);

      // Check dirty flag in SharedPreferences
      final isDirty = prefs.getBool('vyayama_health_conditions_dirty');
      expect(isDirty, isTrue,
          reason: 'Offline condition edits must mark the dirty flag');

      // Fetch conditions: should return local edits without getting overwritten
      final retrieved = await repo.getSelectedConditionKeys();
      expect(retrieved, ['hypertension', 'type_2_diabetes']);
      expect(prefs.getStringList('vyayama_health_selected_conditions'),
          ['hypertension', 'type_2_diabetes']);
    });

    test('saveMedicine enqueues into pending medicine sync queue', () async {
      final repo = SupabaseHealthRepository(prefs: prefs, client: null);

      const med = Medicine(
        id: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Atorvastatin',
        reminderTimes: [TimeOfDay(hour: 8, minute: 0)],
      );

      await repo.saveMedicine(med);

      final pendingSync = prefs.getStringList('vyayama_health_pending_medicine_sync');
      expect(pendingSync, isNotNull);
      expect(pendingSync!.contains(med.id), isTrue,
          reason: 'Offline saved medicine must be tracked in pending sync queue');

      final list = await repo.listMedicines();
      expect(list.length, 1);
      expect(list.first.name, 'Atorvastatin');
    });

    test('deleteMedicine enqueues into pending deletes queue and removes from pending sync', () async {
      final repo = SupabaseHealthRepository(prefs: prefs, client: null);

      const med = Medicine(
        id: '660e8400-e29b-41d4-a716-446655440000',
        name: 'Metformin',
        reminderTimes: [TimeOfDay(hour: 12, minute: 0)],
      );

      await repo.saveMedicine(med);
      expect(prefs.getStringList('vyayama_health_pending_medicine_sync')?.contains(med.id), isTrue);

      await repo.deleteMedicine(med.id);

      // Should be removed from pending sync and added to pending deletes
      final pendingSync = prefs.getStringList('vyayama_health_pending_medicine_sync');
      final pendingDeletes = prefs.getStringList('vyayama_health_pending_medicine_deletes');

      expect(pendingSync?.contains(med.id) ?? false, isFalse);
      expect(pendingDeletes?.contains(med.id), isTrue,
          reason: 'Deleted medicine must be queued in pending deletes');

      final list = await repo.listMedicines();
      expect(list, isEmpty);
    });
  });
}
