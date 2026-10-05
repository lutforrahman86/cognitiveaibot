import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/revenuecat/subscription_service.dart';
import '../../core/usecases/usecase.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/usecases/auth_usecases.dart';
import 'providers.dart';

enum AuthStatus { restoring, signedOut, signedIn }

class AuthState {
  const AuthState._(this.status, {this.user, this.notice, this.restoreError});

  const AuthState.restoring() : this._(AuthStatus.restoring);
  const AuthState.signedOut({String? notice}) : this._(AuthStatus.signedOut, notice: notice);
  const AuthState.signedIn(AppUser user) : this._(AuthStatus.signedIn, user: user);

  /// Restoring failed because the server couldn't be reached.
  const AuthState.offline(String message) : this._(AuthStatus.signedOut, restoreError: message);

  final AuthStatus status;
  final AppUser? user;

  /// Shown on the sign-in screen, e.g. after the session expired.
  final String? notice;
  final String? restoreError;
}

/// Sign-in state. Restores the saved session on launch, and returns to the
/// sign-in screen whenever the server answers 401.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref, {SubscriptionService? subscriptions})
      : _subscriptions = subscriptions ?? SubscriptionService.instance,
        super(const AuthState.restoring()) {
    _ref.read(sessionHolderProvider).onUnauthorized = _sessionExpired;
    restore();
  }

  final Ref _ref;
  final SubscriptionService _subscriptions;

  Future<void> restore() async {
    state = const AuthState.restoring();
    final result = await _ref.read(restoreSessionProvider).call(const NoParams());
    if (!mounted) return;
    switch (result) {
      case Success(data: final session?):
        await _signedIn(session.user);
      case Success():
        state = const AuthState.signedOut();
      case FailureResult(:final failure):
        state = AuthState.offline(failure.message ?? 'Can’t reach the server.');
    }
  }

  /// Null on success, otherwise the message to show.
  Future<String?> signIn(String email, String password) async =>
      _finish(await _ref.read(signInProvider).call(SignInParams(email: email, password: password)));

  Future<String?> signUp(String email, String password, String? name) async =>
      _finish(await _ref.read(signUpProvider).call(SignUpParams(email: email, password: password, name: name)));

  Future<String?> _finish(Result<AuthSession> result) async {
    switch (result) {
      case Success(:final data):
        await _signedIn(data.user);
        return null;
      case FailureResult(:final failure):
        return failure.message ?? 'Something went wrong. Try again.';
    }
  }

  Future<void> _signedIn(AppUser user) async {
    // RevenueCat identifies purchases by our user id (the webhook contract).
    await _subscriptions.logIn(user.id);
    if (mounted) state = AuthState.signedIn(user);
  }

  Future<void> signOut({String? notice}) async {
    await _ref.read(signOutProvider).call();
    await _subscriptions.logOut();
    if (mounted) state = AuthState.signedOut(notice: notice);
  }

  /// A 401 (expired session) or a suspended account: back to sign-in,
  /// showing the server's reason.
  void _sessionExpired(String message) {
    if (state.status == AuthStatus.signedIn) {
      signOut(notice: message.contains('suspended') ? message : 'Your session has ended. Sign in again.');
    }
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});

/// The signed-in user, or null.
final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authControllerProvider).user);
