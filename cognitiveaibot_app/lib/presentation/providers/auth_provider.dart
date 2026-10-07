import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/error_messages.dart';
import '../../core/revenuecat/subscription_service.dart';
import '../../core/usecases/usecase.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/usecases/auth_usecases.dart';
import 'providers.dart';

enum AuthStatus { restoring, signedOut, signedIn }

/// Shown on the sign-in screen after the account was deleted.
const accountDeletedMessage = 'Your account was deleted. Web (card) subscriptions were cancelled with it. '
    'An App Store subscription isn’t: cancel it in your Apple account settings '
    '(Settings › your name › Subscriptions).';

class AuthState {
  const AuthState._(this.status, {this.user, this.notice, this.info, this.restoreError});

  const AuthState.restoring() : this._(AuthStatus.restoring);
  const AuthState.signedOut({String? notice, String? info})
      : this._(AuthStatus.signedOut, notice: notice, info: info);
  const AuthState.signedIn(AppUser user) : this._(AuthStatus.signedIn, user: user);

  /// Restoring failed because the server couldn't be reached.
  const AuthState.offline(String message) : this._(AuthStatus.signedOut, restoreError: message);

  final AuthStatus status;
  final AppUser? user;

  /// Shown on the sign-in screen as a problem, e.g. after the session expired.
  final String? notice;

  /// Shown on the sign-in screen as information, e.g. after deleting the account.
  final String? info;
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

  /// Reloads the account from the server (e.g. the email was confirmed on
  /// the web meanwhile). Quietly keeps the current state on failure.
  Future<void> refreshUser() async {
    if (state.status != AuthStatus.signedIn) return;
    final result = await _ref.read(refreshUserProvider).call(const NoParams());
    if (!mounted || state.status != AuthStatus.signedIn) return;
    if (result case Success(:final data) when data.id == state.user?.id) state = AuthState.signedIn(data);
  }

  /// Sends a new confirmation email. Returns the message to show.
  Future<String> resendVerification() async {
    final result = await _ref.read(resendVerificationProvider).call(const NoParams());
    switch (result) {
      case Success(data: true):
        final user = state.user;
        if (mounted && user != null) state = AuthState.signedIn(user.copyWith(emailVerified: true));
        return 'Your email is already confirmed.';
      case Success():
        return 'Confirmation email sent to ${state.user?.email ?? 'your address'}.';
      case FailureResult(:final failure):
        return errorMessageFor(failure.code, failure.message, fallback: 'Couldn’t send the email. Try again.');
    }
  }

  /// Null on success, otherwise the message to show. This device stays
  /// signed in with the new token; every other session ends.
  Future<String?> changePassword(String currentPassword, String newPassword) async {
    final result = await _ref
        .read(changePasswordProvider)
        .call(ChangePasswordParams(currentPassword: currentPassword, newPassword: newPassword));
    return switch (result) {
      Success() => null,
      FailureResult(:final failure) => failure.message ?? 'Couldn’t change the password. Try again.',
    };
  }

  /// Deletes the account. Null on success (and the app returns to sign-in,
  /// explaining what happens to App Store subscriptions), otherwise the
  /// message to show.
  Future<String?> deleteAccount(String confirm) async {
    final result = await _ref.read(deleteAccountProvider).call(confirm);
    switch (result) {
      case Success():
        await _subscriptions.logOut();
        if (mounted) state = const AuthState.signedOut(info: accountDeletedMessage);
        return null;
      case FailureResult(:final failure):
        return failure.message ?? 'Couldn’t delete the account. Try again.';
    }
  }

  Future<void> signOut({String? notice}) async {
    await _ref.read(signOutProvider).call();
    await _subscriptions.logOut();
    if (mounted) state = AuthState.signedOut(notice: notice);
  }

  /// A 401 (expired session, or the password was changed elsewhere) or a
  /// suspended account: back to sign-in, showing the server's reason.
  void _sessionExpired(String message, String? code) {
    if (state.status == AuthStatus.signedIn) {
      final explained = code == 'SESSION_EXPIRED' || code == 'ACCOUNT_SUSPENDED' || message.contains('suspended');
      signOut(notice: explained ? message : 'Your session has ended. Sign in again.');
    }
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});

/// The signed-in user, or null.
final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authControllerProvider).user);
