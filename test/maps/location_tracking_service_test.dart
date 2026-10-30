import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/services/location_tracking_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocationTrackingService State Machine Tests', () {
    test('1. TrackingState initial values are zeroed', () {
      final state = TrackingState.initial;
      expect(state.status, equals(OutdoorActivityStatus.discarded));
      expect(state.distanceMeters, equals(0.0));
      expect(state.durationSeconds, equals(0));
      expect(state.points, isEmpty);
      expect(state.formattedDistance, equals('0.00'));
      expect(state.formattedDuration, equals('00:00'));
      expect(state.formattedPace, equals('--:--'));
    });

    test('2. Formats duration correctly for minutes and hours', () {
      const stateMins = TrackingState(
        status: OutdoorActivityStatus.active,
        activityType: OutdoorActivityType.running,
        points: [],
        distanceMeters: 1000,
        durationSeconds: 154, // 2 mins 34 secs
        currentPaceSecondsPerKm: 300,
        currentSpeedKmh: 12.0,
        currentPosition: null,
      );
      expect(stateMins.formattedDuration, equals('02:34'));

      const stateHours = TrackingState(
        status: OutdoorActivityStatus.active,
        activityType: OutdoorActivityType.hiking,
        points: [],
        distanceMeters: 12000,
        durationSeconds: 3725, // 1 hour 2 mins 5 secs
        currentPaceSecondsPerKm: 400,
        currentSpeedKmh: 8.0,
        currentPosition: null,
      );
      expect(stateHours.formattedDuration, equals('1:02:05'));
    });

    test('3. Pause and Resume transitions', () {
      final service = LocationTrackingService();

      service.value = const TrackingState(
        status: OutdoorActivityStatus.active,
        activityType: OutdoorActivityType.walking,
        points: [],
        distanceMeters: 500,
        durationSeconds: 60,
        currentPaceSecondsPerKm: 360,
        currentSpeedKmh: 5.0,
        currentPosition: null,
      );

      service.pauseRecording();
      expect(service.value.status, equals(OutdoorActivityStatus.paused));

      service.resumeRecording();
      expect(service.value.status, equals(OutdoorActivityStatus.active));

      service.dispose();
    });

    test('4. Finish compiling completed OutdoorActivity', () {
      final service = LocationTrackingService();
      service.value = const TrackingState(
        status: OutdoorActivityStatus.active,
        activityType: OutdoorActivityType.running,
        points: [],
        distanceMeters: 3000,
        durationSeconds: 900,
        currentPaceSecondsPerKm: 300,
        currentSpeedKmh: 12.0,
        currentPosition: null,
      );

      final activity = service.finishRecording(title: 'Morning 3K Jog');
      expect(activity, isNotNull);
      expect(activity!.title, equals('Morning 3K Jog'));
      expect(activity.distanceMeters, equals(3000));
      expect(activity.durationSeconds, equals(900));
      expect(activity.status, equals(OutdoorActivityStatus.completed));
      expect(activity.activityType, equals(OutdoorActivityType.running));

      service.dispose();
    });
  });
}

