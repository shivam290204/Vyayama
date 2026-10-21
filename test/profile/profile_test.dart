import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Profile Model', () {
    test('serializes and deserializes correctly', () {
      const profile = Profile(
        id: 'user-123',
        name: 'Alex Rivera',
        age: 26,
        gender: 'male',
        weightKg: 75.5,
        heightCm: 180.0,
        goal: 'gain',
        fitnessLevel: 'intermediate',
        wakeTime: TimeOfDay(hour: 6, minute: 30),
        sleepTime: TimeOfDay(hour: 22, minute: 45),
        workStart: TimeOfDay(hour: 9, minute: 0),
        workEnd: TimeOfDay(hour: 17, minute: 0),
        username: 'alex_r',
        avatarUrl: 'https://example.com/avatar.png',
        timezone: 'America/New_York',
        onboardingCompleted: true,
      );

      final json = profile.toJson();
      expect(json['id'], 'user-123');
      expect(json['name'], 'Alex Rivera');
      expect(json['age'], 26);
      expect(json['gender'], 'male');
      expect(json['weight_kg'], 75.5);
      expect(json['height_cm'], 180.0);
      expect(json['goal'], 'gain');
      expect(json['fitness_level'], 'intermediate');
      expect(json['wake_time'], '06:30:00');
      expect(json['sleep_time'], '22:45:00');
      expect(json['work_start'], '09:00:00');
      expect(json['work_end'], '17:00:00');
      expect(json['username'], 'alex_r');
      expect(json['avatar_url'], 'https://example.com/avatar.png');
      expect(json['timezone'], 'America/New_York');
      expect(json['onboarding_completed'], true);

      final deserialized = Profile.fromJson(json);
      expect(deserialized.id, profile.id);
      expect(deserialized.name, profile.name);
      expect(deserialized.age, profile.age);
      expect(deserialized.gender, profile.gender);
      expect(deserialized.weightKg, profile.weightKg);
      expect(deserialized.heightCm, profile.heightCm);
      expect(deserialized.goal, profile.goal);
      expect(deserialized.fitnessLevel, profile.fitnessLevel);
      expect(deserialized.wakeTime?.hour, 6);
      expect(deserialized.wakeTime?.minute, 30);
      expect(deserialized.sleepTime?.hour, 22);
      expect(deserialized.sleepTime?.minute, 45);
      expect(deserialized.workStart?.hour, 9);
      expect(deserialized.workStart?.minute, 0);
      expect(deserialized.workEnd?.hour, 17);
      expect(deserialized.workEnd?.minute, 0);
      expect(deserialized.username, profile.username);
      expect(deserialized.avatarUrl, profile.avatarUrl);
      expect(deserialized.timezone, profile.timezone);
      expect(deserialized.onboardingCompleted, true);
    });

    test('handles default and null values safely', () {
      final json = <String, dynamic>{
        'id': 'empty-user',
      };

      final profile = Profile.fromJson(json);
      expect(profile.id, 'empty-user');
      expect(profile.name, isNull);
      expect(profile.age, isNull);
      expect(profile.gender, isNull);
      expect(profile.weightKg, isNull);
      expect(profile.heightCm, isNull);
      expect(profile.goal, isNull);
      expect(profile.fitnessLevel, 'beginner');
      expect(profile.wakeTime, isNull);
      expect(profile.sleepTime, isNull);
      expect(profile.workStart, isNull);
      expect(profile.workEnd, isNull);
      expect(profile.username, isNull);
      expect(profile.avatarUrl, isNull);
      expect(profile.timezone, 'UTC');
      expect(profile.onboardingCompleted, false);
      expect(profile.displayName, 'Friend');
      expect(profile.initials, '?');
    });

    test('displayName and initials work as expected', () {
      const p1 = Profile(id: '1', name: 'John Doe');
      expect(p1.displayName, 'John Doe');
      expect(p1.initials, 'JD');

      const p2 = Profile(id: '2', name: 'Madonna');
      expect(p2.displayName, 'Madonna');
      expect(p2.initials, 'M');

      const p3 = Profile(id: '3', name: '   ');
      expect(p3.displayName, 'Friend');
      expect(p3.initials, '?');
    });

    test('isMinor check works correctly', () {
      const adult = Profile(id: '1', age: 20);
      expect(adult.isMinor, false);

      const minor = Profile(id: '2', age: 16);
      expect(minor.isMinor, true);

      const unknown = Profile(id: '3');
      expect(unknown.isMinor, false);
    });

    test('updates weight and height to 50kg and 182cm accurately', () {
      const initial = Profile(
        id: 'user-xyz',
        name: 'Shivam',
        age: 22,
        gender: 'male',
        weightKg: 70.0,
        heightCm: 175.0,
        goal: 'maintain',
        fitnessLevel: 'beginner',
      );

      final updated = initial.copyWith(
        weightKg: 50.0,
        heightCm: 182.0,
        goal: 'lose',
      );

      expect(updated.weightKg, 50.0);
      expect(updated.heightCm, 182.0);
      expect(updated.goal, 'lose');
      expect(updated.name, 'Shivam');
      expect(updated.age, 22);

      final json = updated.toJson();
      expect(json['weight_kg'], 50.0);
      expect(json['height_cm'], 182.0);
      expect(json['goal'], 'lose');
    });
  });
}
