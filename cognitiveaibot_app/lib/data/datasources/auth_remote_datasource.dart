import '../../core/network/api_client.dart';
import '../../domain/entities/app_user.dart';
import '../models/json_utils.dart';
import '../models/user_model.dart';

abstract interface class AuthRemoteDataSource {
  Future<AuthSession> login({required String email, required String password});
  Future<AuthSession> register({required String email, required String password, String? name});

  /// `GET /api/auth/me` with the current session token.
  Future<AppUserModel> me();
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
}
