import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// The backend's minimum password length (sign-up, change and reset).
const minPasswordLength = 8;
const _weakPassword = 'Use a password of at least $minPasswordLength characters.';

class SignIn implements UseCase<AuthSession, SignInParams> {
  SignIn(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AuthSession>> call(SignInParams params) async {
    final email = params.email.trim();
    if (email.isEmpty || params.password.isEmpty) {
      return const FailureResult(ServerFailure('Enter your email and password.'));
    }
    return _repository.signIn(email: email, password: params.password);
  }
}

class SignInParams {
  const SignInParams({required this.email, required this.password});

  final String email;
  final String password;
}

class SignUp implements UseCase<AuthSession, SignUpParams> {
  SignUp(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AuthSession>> call(SignUpParams params) async {
    final email = params.email.trim();
    if (!_emailPattern.hasMatch(email)) {
      return const FailureResult(ServerFailure('Enter a valid email address.'));
    }
    if (params.password.length < minPasswordLength) {
      return const FailureResult(ServerFailure(_weakPassword, 'WEAK_PASSWORD'));
    }
    final name = params.name?.trim();
    return _repository.signUp(
      email: email,
      password: params.password,
      name: name == null || name.isEmpty ? null : name,
    );
  }
}

class SignUpParams {
  const SignUpParams({required this.email, required this.password, this.name});

  final String email;
  final String password;
  final String? name;
}

class RestoreSession implements UseCase<AuthSession?, NoParams> {
  RestoreSession(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AuthSession?>> call(NoParams params) => _repository.restoreSession();
}

class SignOut {
  SignOut(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.signOut();
}

/// The signed-in account, fresh from the server.
class RefreshUser implements UseCase<AppUser, NoParams> {
  RefreshUser(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<AppUser>> call(NoParams params) => _repository.currentUser();
}

/// "Forgot password?": the reset itself happens on the web page the email links to.
class ForgotPassword implements UseCase<void, String> {
  ForgotPassword(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<void>> call(String email) async {
    final address = email.trim();
    if (!_emailPattern.hasMatch(address)) {
      return const FailureResult(ServerFailure('Enter a valid email address.'));
    }
    return _repository.requestPasswordReset(address);
  }
}

class ResendVerification implements UseCase<bool, NoParams> {
  ResendVerification(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<bool>> call(NoParams params) => _repository.resendVerification();
}

class ChangePassword implements UseCase<void, ChangePasswordParams> {
  ChangePassword(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<void>> call(ChangePasswordParams params) async {
    if (params.currentPassword.isEmpty) {
      return const FailureResult(ServerFailure('Enter your current password.'));
    }
    if (params.newPassword.length < minPasswordLength) {
      return const FailureResult(ServerFailure(_weakPassword, 'WEAK_PASSWORD'));
    }
    if (params.newPassword == params.currentPassword) {
      return const FailureResult(ServerFailure('Choose a password that’s different from the current one.'));
    }
    return _repository.changePassword(currentPassword: params.currentPassword, newPassword: params.newPassword);
  }
}

class ChangePasswordParams {
  const ChangePasswordParams({required this.currentPassword, required this.newPassword});

  final String currentPassword;
  final String newPassword;
}

/// Deletes the account. [confirm] is the password (or, for an account
/// without one, its email address).
class DeleteAccount implements UseCase<void, String> {
  DeleteAccount(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<void>> call(String confirm) async {
    if (confirm.isEmpty) return const FailureResult(ServerFailure('Enter your password to confirm.'));
    return _repository.deleteAccount(confirm);
  }
}
