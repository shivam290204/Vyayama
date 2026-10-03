import 'package:fitbuddy/features/snap_streaks/providers.dart';
import 'package:fitbuddy/features/snaps/data/mock_snap_repository.dart';
import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:fitbuddy/features/snaps/data/snap_image_processor.dart';
import 'package:fitbuddy/features/snaps/data/snap_repository.dart';
import 'package:fitbuddy/features/snaps/data/snap_verification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Swap for a Supabase-backed repository later. Keep it a singleton per user.
final snapRepositoryProvider = Provider<SnapRepository>((ref) {
  return MockSnapRepository(
    currentUserId: ref.watch(currentUserIdProvider),
    clock: ref.watch(clockProvider),
  );
});

final snapImageUrlSignerProvider = Provider<SnapImageUrlSigner>((ref) {
  return MockSnapImageUrlSigner();
});

final snapPreCheckProvider = Provider<SnapPreCheck>((ref) => MlKitSnapPreCheck());

final snapImageProcessorProvider =
    Provider<SnapImageProcessor>((ref) => const SnapImageProcessor());

/// Swap for a service that calls the `verify-snap` Edge Function.
final snapVerificationServiceProvider = Provider<SnapVerificationService>((ref) {
  return MockSnapVerificationService(
    ref.watch(snapRepositoryProvider) as MockSnapRepository,
    ref.watch(snapStreakRepositoryProvider),
    ref.watch(currentUserIdProvider),
  );
});

/// Steps shown on the optional steps sticker. Antigravity: wire this to the
/// dashboard's steps provider. Null hides the sticker.
final snapStepsTodayProvider = Provider<int?>((ref) => 6420);

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
