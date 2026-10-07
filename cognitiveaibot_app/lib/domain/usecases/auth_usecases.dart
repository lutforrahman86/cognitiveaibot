import '../../core/error/failures.dart';
import '../../core/usecases/usecase.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

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
    if (params.password.length < 6) {
      return const FailureResult(ServerFailure('Password must be at least 6 characters.'));
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
