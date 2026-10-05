import '../../core/usecases/usecase.dart';
import '../entities/app_user.dart';

abstract interface class AuthRepository {
  Future<Result<AuthSession>> signIn({required String email, required String password});
  Future<Result<AuthSession>> signUp({required String email, required String password, String? name});

  /// The session saved on this device, checked with the server. Null when
  /// there is none or it has expired.
  Future<Result<AuthSession?>> restoreSession();
  Future<void> signOut();

  /// The signed-in account as the server has it now (e.g. once the email
  /// was confirmed on the web).
  Future<Result<AppUser>> currentUser();

  /// Emails a password-reset link if an account uses [email].
  Future<Result<void>> requestPasswordReset(String email);

  /// Sends a new confirmation link. True when the email was already confirmed.
  Future<Result<bool>> resendVerification();

  /// Changes the password and keeps this device signed in with the new
  /// session token the server returns (every other session ends).
  Future<Result<void>> changePassword({required String currentPassword, required String newPassword});

  /// Deletes the account on the server, then forgets the session here.
  Future<Result<void>> deleteAccount(String confirm);
}
