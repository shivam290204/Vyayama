import 'package:fitbuddy/features/auth/data/mock_auth_repository.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/data/profile_repository.dart';

/// In-memory [ProfileRepository]. Mimics the auto-create-profile trigger:
/// a missing profile is created empty with onboarding not completed.
class MockProfileRepository implements ProfileRepository {
  MockProfileRepository() {
    _store[kDemoUserId] = const Profile(
      id: kDemoUserId,
      name: 'Demo Buddy',
      age: 28,
      gender: 'other',
      weightKg: 70,
      heightCm: 172,
      goal: 'maintain',
      username: 'demo_buddy',
      onboardingCompleted: true,
    );
  }

  final Map<String, Profile> _store = {};

  @override
  Future<Profile?> fetchProfile(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _store.putIfAbsent(userId, () => Profile(id: userId));
  }

  @override
  Future<Profile> upsertProfile(Profile profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _store[profile.id] = profile;
    return profile;
  }
}
