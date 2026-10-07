import '../../core/usecases/usecase.dart';
import '../entities/app_user.dart';

abstract interface class AuthRepository {
  Future<Result<AuthSession>> signIn({required String email, required String password});
  Future<Result<AuthSession>> signUp({required String email, required String password, String? name});

  /// The session saved on this device, checked with the server. Null when
  /// there is none or it has expired.
  Future<Result<AuthSession?>> restoreSession();
  Future<void> signOut();
}
