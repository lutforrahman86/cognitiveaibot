import 'dart:convert';

import 'package:cognitiveaibot/core/network/api_client.dart';
import 'package:cognitiveaibot/core/storage/token_store.dart';
import 'package:cognitiveaibot/core/usecases/usecase.dart';
import 'package:cognitiveaibot/data/datasources/account_remote_datasource.dart';
import 'package:cognitiveaibot/data/datasources/auth_remote_datasource.dart';
import 'package:cognitiveaibot/data/datasources/chat_remote_datasource_impl.dart';
import 'package:cognitiveaibot/data/repositories/account_repository_impl.dart';
import 'package:cognitiveaibot/data/repositories/auth_repository_impl.dart';
import 'package:cognitiveaibot/data/repositories/chat_repository_impl.dart';
import 'package:cognitiveaibot/domain/entities/content_report.dart';
import 'package:cognitiveaibot/domain/usecases/auth_usecases.dart';
import 'package:cognitiveaibot/domain/usecases/report_message.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late SessionHolder session;
  late MemoryTokenStore store;
  late AuthRepositoryImpl auth;

  setUp(() {
    backend = FakeBackend();
    session = SessionHolder()..token = backend.token;
    store = MemoryTokenStore(backend.token);
    final api = ApiClient(baseUrl: 'http://api.test', session: session, httpClient: backend);
    auth = AuthRepositoryImpl(remote: AuthRemoteDataSourceImpl(api), tokenStore: store, session: session);
  });

  Map<String, dynamic> lastBody() => jsonDecode(backend.bodies.last) as Map<String, dynamic>;

  test('email_verified is read from sign-in and /me', () async {
    backend.emailVerified = false;
    final result = await auth.currentUser() as Success;
    expect(result.data.emailVerified, isFalse);
    backend.emailVerified = true;
    expect(((await auth.currentUser()) as Success).data.emailVerified, isTrue);
  });

  test('forgot password posts the email without a token', () async {
    expect(await ForgotPassword(auth).call('  a@b.co '), isA<Success>());
    expect(backend.requests.last.url.path, '/api/auth/forgot-password');
    expect(backend.requests.last.headers.containsKey('Authorization'), isFalse);
    expect(lastBody(), {'email': 'a@b.co'});
  });

  test('resend verification reports already-confirmed', () async {
    backend.emailVerified = false;
    expect(((await auth.resendVerification()) as Success).data, isFalse);
    backend.emailVerified = true;
    expect(((await auth.resendVerification()) as Success).data, isTrue);
  });

  test('change password stores the new token; errors keep the old one', () async {
    final wrong = await ChangePassword(auth)
        .call(const ChangePasswordParams(currentPassword: 'bad-pass', newPassword: 'new-password'));
    expect((wrong as FailureResult).failure.code, 'WRONG_PASSWORD');
    expect(session.token, 'valid-token');

    final weak = await ChangePassword(auth).call(const ChangePasswordParams(currentPassword: 'x', newPassword: '1234567'));
    expect((weak as FailureResult).failure.code, 'WEAK_PASSWORD');

    final ok = await ChangePassword(auth)
        .call(const ChangePasswordParams(currentPassword: 'right-password', newPassword: 'new-password'));
    expect(ok, isA<Success>());
    expect(session.token, 'token-after-password-change');
    expect(await store.read(), 'token-after-password-change');
  });

  test('delete account forgets the session only on success', () async {
    final refused = await DeleteAccount(auth).call('nope');
    expect((refused as FailureResult).failure.code, 'CONFIRMATION_FAILED');
    expect(await store.read(), 'valid-token');

    expect(await DeleteAccount(auth).call('right-password'), isA<Success>());
    expect(backend.requests.last.method, 'DELETE');
    expect(lastBody(), {'confirm': 'right-password'});
    expect(session.token, isNull);
    expect(await store.read(), isNull);
  });

  test('sign-up needs 8 characters', () async {
    final r = await SignUp(auth).call(const SignUpParams(email: 'a@b.co', password: '1234567'));
    expect((r as FailureResult).failure.code, 'WEAK_PASSWORD');
    expect(backend.requests, isEmpty);
  });

  test('export returns indented JSON', () async {
    final api = ApiClient(baseUrl: 'http://api.test', session: session, httpClient: backend);
    final repo = AccountRepositoryImpl(AccountRemoteDataSourceImpl(api));
    final r = await repo.exportData() as Success<String>;
    expect(r.data, contains('\n  "profile"'));
    expect(backend.requests.last.url.path, '/api/users/me/export');
  });

  test('report: sends reason name and trimmed details; refuses unsaved replies', () async {
    final api = ApiClient(baseUrl: 'http://api.test', session: session, httpClient: backend);
    final repo = ChatRepositoryImpl(remoteDataSource: ChatRemoteDataSourceImpl(api));
    backend.messages['c'] = [
      {'id': 'm-1', 'role': 'assistant', 'content': 'x'},
    ];
    final local = await ReportMessage(repo)
        .call(const ReportMessageParams(messageId: 'local-reply-3', reason: ReportReason.other));
    expect(local, isA<FailureResult>());
    expect(backend.requests, isEmpty);

    final ok = await ReportMessage(repo)
        .call(const ReportMessageParams(messageId: 'm-1', reason: ReportReason.hateful, details: '   '));
    expect(ok, isA<Success>());
    expect(lastBody(), {'message_id': 'm-1', 'reason': 'hateful'});

    final missing = await ReportMessage(repo)
        .call(const ReportMessageParams(messageId: 'm-404', reason: ReportReason.violent, details: 'why'));
    expect((missing as FailureResult).failure.code, 'NOT_FOUND');
  });
}
