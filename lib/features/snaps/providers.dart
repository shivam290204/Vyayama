import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/core/services/step_tracking_service.dart';
import 'package:fitbuddy/features/dashboard/providers.dart';
import 'package:fitbuddy/features/snap_streaks/providers.dart';
import 'package:fitbuddy/features/snaps/data/mock_snap_repository.dart';
import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:fitbuddy/features/snaps/data/snap_image_processor.dart';
import 'package:fitbuddy/features/snaps/data/snap_repository.dart';
import 'package:fitbuddy/features/snaps/data/snap_verification_service.dart';
import 'package:fitbuddy/features/snaps/data/supabase_snap_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides [SupabaseSnapRepository] when configured, falling back to mock.
final snapRepositoryProvider = Provider<SnapRepository>((ref) {
  if (Env.isSupabaseConfigured) {
    return SupabaseSnapRepository();
  }
  return MockSnapRepository(
    currentUserId: ref.watch(currentUserIdProvider),
    clock: ref.watch(clockProvider),
  );
});

final snapImageUrlSignerProvider = Provider<SnapImageUrlSigner>((ref) {
  if (Env.isSupabaseConfigured) {
    return SupabaseSnapImageUrlSigner();
  }
  return MockSnapImageUrlSigner();
});

final snapPreCheckProvider = Provider<SnapPreCheck>((ref) => MlKitSnapPreCheck());

final snapImageProcessorProvider =
    Provider<SnapImageProcessor>((ref) => const SnapImageProcessor());

/// Provides [SupabaseSnapVerificationService] when configured, falling back to mock.
final snapVerificationServiceProvider = Provider<SnapVerificationService>((ref) {
  if (Env.isSupabaseConfigured) {
    return SupabaseSnapVerificationService();
  }
  return MockSnapVerificationService(
    ref.watch(snapRepositoryProvider) as MockSnapRepository,
    ref.watch(snapStreakRepositoryProvider),
    ref.watch(currentUserIdProvider),
  );
});

/// Steps shown on the optional steps sticker wired to today's steps.
final snapStepsTodayProvider = Provider<int?>((ref) {
  final todayAsync = ref.watch(todayStatsProvider);
  final steps = todayAsync.asData?.value.steps ?? StepTrackingService.instance.todaySteps;
  return steps > 0 ? steps : null;
});

/// The photo just captured by the camera, waiting for the preview screen.
class CapturedPhotoNotifier extends Notifier<CapturedPhoto?> {
  @override
  CapturedPhoto? build() => null;

  void set(CapturedPhoto? photo) => state = photo;
}

final capturedPhotoProvider =
    NotifierProvider<CapturedPhotoNotifier, CapturedPhoto?>(CapturedPhotoNotifier.new);

/// Direct snaps waiting in the inbox.
final inboxProvider = FutureProvider<List<ReceivedSnap>>((ref) {
  return ref.watch(snapRepositoryProvider).inbox();
});

/// Number of unviewed direct snaps in the inbox (for badges and notifications).
final unviewedSnapsCountProvider = Provider<int>((ref) {
  final list = ref.watch(inboxProvider).valueOrNull ?? const [];
  return list.where((s) => s.isUnviewed).length;
});

/// Friends Feed posts from the last 24 hours.
final feedProvider = FutureProvider<List<ReceivedSnap>>((ref) {
  return ref.watch(snapRepositoryProvider).feed();
});

/// One received snap by id.
final receivedSnapProvider =
    FutureProvider.family<ReceivedSnap?, String>((ref, id) {
  return ref.watch(snapRepositoryProvider).getReceived(id);
});

/// Short-lived signed URL for a storage path.
final signedUrlProvider = FutureProvider.family<String, String>((ref, path) {
  return ref.watch(snapImageUrlSignerProvider).signedUrl(path);
});
