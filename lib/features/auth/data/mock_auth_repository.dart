import 'dart:async';

import 'package:fitbuddy/features/auth/data/auth_repository.dart';

/// Id of the pre-seeded demo account (see [MockProfileRepository]).
const String kDemoUserId = 'demo-user';

class _Account {
  _Account({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
  });

  final String id;
  final String name;
  final String email;
  final String password;

  AuthUser toUser() => AuthUser(id: id, email: email, displayName: name);
}

/// In-memory [AuthRepository].
/// Demo login: `demo@fitbuddy.app` / `fitbuddy123`.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository() {
    _accounts['demo@fitbuddy.app'] = _Account(
      id: kDemoUserId,
      name: 'Demo Buddy',
      email: 'demo@fitbuddy.app',
      password: 'fitbuddy123',
    );
  }

  final Map<String, _Account> _accounts = {};
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _current;

  static const Duration _latency = Duration(milliseconds: 500);

  @override
  AuthUser? get currentUser => _current;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  void _setCurrent(AuthUser? user) {
    _current = user;
    _controller.add(user);
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(_latency);
    final account = _accounts[email.trim().toLowerCase()];
    if (account == null || account.password != password) {
      throw const AuthFailure('Email or password is incorrect.');
    }
    _setCurrent(account.toUser());
  }

  @override
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(_latency);
    final key = email.trim().toLowerCase();
    if (_accounts.containsKey(key)) {
      throw const AuthFailure('An account with this email already exists.');
    }
    final account = _Account(
      id: 'user-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      email: key,
      password: password,
    );
    _accounts[key] = account;
    _setCurrent(account.toUser());
  }

  @override
  Future<void> signInWithGoogle() async {
    await Future<void>.delayed(_latency);
    const key = 'google.buddy@example.com';
    final account = _accounts.putIfAbsent(
      key,
      () => _Account(
        id: 'google-user',
        name: 'Google Buddy',
        email: key,
        password: '',
      ),
    );
    _setCurrent(account.toUser());
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    // Never reveal whether the email exists.
    await Future<void>.delayed(_latency);
  }

  @override
  Future<void> signOut() async {
    _setCurrent(null);
  }

  @override
  Future<void> deleteAccount() async {
    await Future<void>.delayed(_latency);
    final user = _current;
    if (user == null) throw const AuthFailure('You are not signed in.');
    _accounts.remove(user.email);
    _setCurrent(null);
  }

  void dispose() => _controller.close();
}
