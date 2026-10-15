import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/friends/providers.dart';
import 'package:fitbuddy/features/snap_streaks/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _UserMenuAction { block, report }

/// `/u/:id`: Public profile screen opened via QR code scan or deep link.
/// Displays verified public profile data and full friend request lifecycle.
class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key, required this.identifier});

  final String identifier;

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _isActing = false;

  Future<void> _sendFriendRequest(FriendUser user) async {
    setState(() => _isActing = true);
    try {
      await ref.read(friendRepositoryProvider).sendRequest(user.id);
      invalidateFriendData(ref);
      ref.invalidate(userRelationProvider(user.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend request sent to ${user.name}! 💪'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not send friend request. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _acceptRequest(FriendUser user) async {
    setState(() => _isActing = true);
    try {
      final requests = await ref.read(friendRequestsProvider.future);
      final req = requests.firstWhere(
        (r) => r.user.id == user.id && r.incoming,
        orElse: () => throw StateError('Request not found'),
      );
      await ref.read(friendRepositoryProvider).acceptRequest(req.friendship.id);
      invalidateFriendData(ref);
      ref.invalidate(userRelationProvider(user.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You and ${user.name} are now friends! 🎉')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not accept request.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _declineRequest(FriendUser user) async {
    setState(() => _isActing = true);
    try {
      final requests = await ref.read(friendRequestsProvider.future);
      final req = requests.firstWhere(
        (r) => r.user.id == user.id && r.incoming,
        orElse: () => throw StateError('Request not found'),
      );
      await ref.read(friendRepositoryProvider).declineRequest(req.friendship.id);
      invalidateFriendData(ref);
      ref.invalidate(userRelationProvider(user.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request declined.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not decline request.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _cancelRequest(FriendUser user) async {
    setState(() => _isActing = true);
    try {
      final requests = await ref.read(friendRequestsProvider.future);
      final req = requests.firstWhere(
        (r) => r.user.id == user.id && !r.incoming,
        orElse: () => throw StateError('Request not found'),
      );
      await ref.read(friendRepositoryProvider).cancelRequest(req.friendship.id);
      invalidateFriendData(ref);
      ref.invalidate(userRelationProvider(user.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request cancelled.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not cancel request.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _handleMenuAction(_UserMenuAction action, FriendUser user) async {
    final repo = ref.read(friendRepositoryProvider);
    if (action == _UserMenuAction.block) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Block ${user.name}?'),
          content: Text(
            'They will no longer be able to find you, send you friend requests, or view your snaps.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Block'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await repo.blockUser(user.id);
        invalidateFriendData(ref);
        if (mounted) {
          context.go(AppRoutes.friends);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${user.name} is now blocked.')),
          );
        }
      }
    } else if (action == _UserMenuAction.report) {
      final reason = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Why are you reporting this user?'),
          children: [
            for (final r in [
              'Inappropriate content or photo',
              'Harassment or bullying',
              'Spam or fake profile',
              'Other',
            ])
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(r),
                ),
              ),
          ],
        ),
      );
      if (reason != null) {
        await repo.reportUser(user.id, reason);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report submitted. Thank you.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(userProfileByIdentifierProvider(widget.identifier));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          userAsync.maybeWhen(
            data: (user) {
              if (user == null || user.id == currentUserId) return null;
              return PopupMenuButton<_UserMenuAction>(
                tooltip: 'More options',
                onSelected: (a) => _handleMenuAction(a, user),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _UserMenuAction.block,
                    child: Row(
                      children: [
                        Icon(Icons.block, size: 20),
                        SizedBox(width: 8),
                        Text('Block user'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _UserMenuAction.report,
                    child: Row(
                      children: [
                        Icon(Icons.flag_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Report user'),
                      ],
                    ),
                  ),
                ],
              );
            },
            orElse: () => null,
          ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Could not load profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check your internet connection or verify the QR code.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => ref.invalidate(
                      userProfileByIdentifierProvider(widget.identifier)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (user) {
          if (user == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_off_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'User Not Found',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This profile could not be found, or privacy settings prevent viewing it.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.go(AppRoutes.friendsAdd),
                      icon: const Icon(Icons.search),
                      label: const Text('Search by Username'),
                    ),
                  ],
                ),
              ),
            );
          }

          final isMe = user.id == currentUserId;
          final relationAsync = isMe
              ? null
              : ref.watch(userRelationProvider(user.id));

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Avatar & Name Card
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor:
                          const Color(0xFF8BCF45).withValues(alpha: 0.3),
                      child: Text(
                        user.initials,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF14532D),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      user.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (user.username.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '@${user.username}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Relationship Status / Action Section
              if (isMe)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.badge_outlined, color: Color(0xFF14532D)),
                            SizedBox(width: 8),
                            Text(
                              'This is your personal profile',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => context.push(AppRoutes.profileEdit),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit Profile'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (relationAsync != null)
                relationAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (_, __) => _buildAddButton(user),
                  data: (relation) {
                    return switch (relation) {
                      FriendRelation.friends => _buildFriendsBadge(user),
                      FriendRelation.requestSent => _buildPendingSent(user),
                      FriendRelation.requestReceived =>
                        _buildIncomingRequestCard(user),
                      FriendRelation.none => _buildAddButton(user),
                    };
                  },
                ),

              const SizedBox(height: 24),

              // Web Fallback notice if running in web browser
              if (kIsWeb)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14532D).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF14532D).withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.phone_android_rounded,
                          color: Color(0xFF14532D), size: 32),
                      SizedBox(height: 8),
                      Text(
                        'Install Vyayama App',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF14532D),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Download the Android APK to track steps in real time, build snap streaks, and exercise with friends!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFriendsBadge(FriendUser user) {
    return Card(
      elevation: 0,
      color: const Color(0xFF14532D).withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF14532D), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF14532D)),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'You and this athlete are Friends',
                    style: TextStyle(
                      color: Color(0xFF14532D),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF14532D),
                    ),
                    onPressed: () => context.push(AppRoutes.snapsCamera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Send Snap'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.push(AppRoutes.friendDetailPath(user.id)),
                    icon: const Icon(Icons.local_fire_department_rounded),
                    label: const Text('View Streak'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingSent(FriendUser user) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Friend Request Pending',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for ${user.name} to accept your request.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _isActing ? null : () => _cancelRequest(user),
              child: _isActing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Cancel Request'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingRequestCard(FriendUser user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mail_outline_rounded,
                    color: Color(0xFF14532D)),
                const SizedBox(width: 8),
                Text(
                  '${user.name} sent you a friend request!',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isActing ? null : () => _declineRequest(user),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF14532D),
                    ),
                    onPressed: _isActing ? null : () => _acceptRequest(user),
                    child: _isActing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(FriendUser user) {
    return Center(
      child: Column(
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF14532D),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: _isActing ? null : () => _sendFriendRequest(user),
            icon: _isActing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.person_add_rounded),
            label: const Text(
              'Add Friend',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Connect to share workouts, photos, and maintain daily streaks.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
