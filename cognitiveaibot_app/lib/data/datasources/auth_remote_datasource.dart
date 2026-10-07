import '../../core/network/api_client.dart';
import '../../domain/entities/app_user.dart';
import '../models/json_utils.dart';
import '../models/user_model.dart';

abstract interface class AuthRemoteDataSource {
  Future<AuthSession> login({required String email, required String password});
  Future<AuthSession> register({required String email, required String password, String? name});

  /// `GET /api/auth/me` with the current session token.
  Future<AppUserModel> me();

  /// `POST /api/auth/forgot-password`. The server always answers 200, so it
  /// can't be used to find out which emails have accounts.
  Future<void> forgotPassword(String email);

  /// `POST /api/auth/resend-verification`. True when the email was already
  /// confirmed (nothing was sent).
  Future<bool> resendVerification();

  /// `POST /api/users/me/password`. Returns the new session token: the old
  /// one stops working.
  Future<String> changePassword({required String currentPassword, required String newPassword});

  /// `DELETE /api/users/me`. [confirm] is the password, or the account's
  /// email for accounts without one (Google/GitHub sign-in).
  Future<void> deleteAccount(String confirm);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._api);

  final ApiClient _api;

  AuthSession _session(Object? body) {
    final json = readMap(body);
    return AuthSession(
      user: AppUserModel.fromJson(readMap(json['user'])),
      token: readString(json['token']) ?? '',
    );
  }

  @override
  Future<AuthSession> login({required String email, required String password}) async =>
      _session(await _api.post('/api/auth/login', body: {'email': email, 'password': password}, auth: false));

  @override
  Future<AuthSession> register({required String email, required String password, String? name}) async =>
      _session(await _api.post(
        '/api/auth/register',
        body: {'email': email, 'password': password, 'name': ?name},
        auth: false,
      ));

  @override
  Future<AppUserModel> me() async {
    final json = readMap(await _api.get('/api/auth/me'));
    return AppUserModel.fromJson(readMap(json['user']));
  }

  @override
  Future<void> forgotPassword(String email) async {
    await _api.post('/api/auth/forgot-password', body: {'email': email}, auth: false);
  }

  @override
  Future<bool> resendVerification() async =>
      readBool(readMap(await _api.post('/api/auth/resend-verification', body: const {}))['already_verified']);

  @override
  Future<String> changePassword({required String currentPassword, required String newPassword}) async {
    final json = readMap(await _api.post(
      '/api/users/me/password',
      body: {'current_password': currentPassword, 'new_password': newPassword},
    ));
    return readString(json['token']) ?? '';
  }

  @override
  Future<void> deleteAccount(String confirm) async {
    await _api.delete('/api/users/me', body: {'confirm': confirm});
  }
}
