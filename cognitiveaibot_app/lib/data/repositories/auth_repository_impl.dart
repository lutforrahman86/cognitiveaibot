import '../../core/error/exceptions.dart';
import '../../core/error/failures.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/token_store.dart';
import '../../core/usecases/usecase.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required TokenStore tokenStore,
    required SessionHolder session,
  })  : _remote = remote,
        _store = tokenStore,
        _session = session;

  final AuthRemoteDataSource _remote;
  final TokenStore _store;
  final SessionHolder _session;

  Future<Result<AuthSession>> _start(Future<AuthSession> Function() call) async {
    final result = await Result.guard(call);
    if (result case Success(:final data)) {
      if (data.token.isEmpty) return const FailureResult(ServerFailure('Sign-in failed. Try again.'));
      _session.token = data.token;
      await _store.write(data.token);
    }
    return result;
  }

  @override
  Future<Result<AuthSession>> signIn({required String email, required String password}) =>
      _start(() => _remote.login(email: email, password: password));

  @override
  Future<Result<AuthSession>> signUp({required String email, required String password, String? name}) =>
      _start(() => _remote.register(email: email, password: password, name: name));

  @override
  Future<Result<AuthSession?>> restoreSession() async {
    final token = await _store.read();
    if (token == null || token.isEmpty) return const Success(null);
    _session.token = token;
    try {
      final user = await _remote.me();
      return Success(AuthSession(user: user, token: token));
    } on UnauthorizedException {
      _session.token = null;
      await _store.delete();
      return const Success(null);
    } catch (e) {
      // Offline or server down: keep the saved token so the next try works.
      _session.token = null;
      return FailureResult(Failure.from(e));
    }
  }

  @override
  Future<void> signOut() async {
    _session.token = null;
    await _store.delete();
  }

  @override
  Future<Result<AppUser>> currentUser() => Result.guard(_remote.me);

  @override
  Future<Result<void>> requestPasswordReset(String email) => Result.guard(() => _remote.forgotPassword(email));

  @override
  Future<Result<bool>> resendVerification() => Result.guard(_remote.resendVerification);

  @override
  Future<Result<void>> changePassword({required String currentPassword, required String newPassword}) async {
    final result = await Result.guard(
      () => _remote.changePassword(currentPassword: currentPassword, newPassword: newPassword),
    );
    switch (result) {
      case Success(:final data):
        // The server rejects the old token from now on.
        if (data.isEmpty) return const FailureResult(ServerFailure('Password changed. Sign in again.'));
        _session.token = data;
        await _store.write(data);
        return const Success(null);
      case FailureResult(:final failure):
        return FailureResult(failure);
    }
  }

  @override
  Future<Result<void>> deleteAccount(String confirm) async {
    final result = await Result.guard(() => _remote.deleteAccount(confirm));
    if (result is Success) await signOut();
    return result;
  }
}
