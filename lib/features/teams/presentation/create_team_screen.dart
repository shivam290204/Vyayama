import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/wellness_app_bar.dart';
import 'package:fitbuddy/features/teams/data/team.dart';
import 'package:fitbuddy/features/teams/data/team_repository.dart';
import 'package:fitbuddy/features/teams/domain/team_goals.dart';
import 'package:fitbuddy/features/teams/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Create a team: a name and a type (running, workout or walking).
class CreateTeamScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const CreateTeamScreen({super.key});

  @override
  ConsumerState<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends ConsumerState<CreateTeamScreen> {
  final TextEditingController _name = TextEditingController();
  TeamType _type = TeamType.workout;
  String? _nameError;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final problem = validateTeamName(_name.text);
    if (problem != null) {
      setState(() => _nameError = problem);
      return;
    }
    setState(() {
      _busy = true;
      _nameError = null;
    });
    try {
      final team = await ref
          .read(myTeamsProvider.notifier)
          .create(name: _name.text, type: _type);
      if (!mounted) return;
      context.pushReplacement(AppRoutes.teamDetailPath(team.id));
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _nameError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create the team. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const WellnessAppBar(title: 'Create a team'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextField(
              controller: _name,
              maxLength: 30,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Team name',
                errorText: _nameError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: 16),
            Text('Team type', style: text.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<TeamType>(
              style: SegmentedButton.styleFrom(minimumSize: const Size(48, 48)),
              showSelectedIcon: false,
              segments: <ButtonSegment<TeamType>>[
                for (final type in TeamType.values)
                  ButtonSegment<TeamType>(value: type, label: Text(type.label)),
              ],
              selected: <TeamType>{_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              TeamGoals.describe(_type),
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              'You will get an invite code to share with friends.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _busy ? null : _create,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create team'),
            ),
          ],
        ),
      ),
    );
  }
}
