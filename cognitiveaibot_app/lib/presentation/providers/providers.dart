import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/token_store.dart';
import '../../data/datasources/account_remote_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/datasources/chat_remote_datasource_impl.dart';
import '../../data/repositories/account_repository_impl.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/account_usecases.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../../domain/usecases/create_conversation.dart';
import '../../domain/usecases/delete_conversation.dart';
import '../../domain/usecases/get_chat_messages.dart';
import '../../domain/usecases/get_conversations.dart';
import '../../domain/usecases/get_models.dart';
import '../../domain/usecases/stream_chat_reply.dart';
import '../../domain/usecases/update_conversation_title.dart';

/// Core. Tests override [httpClientProvider] (mock HTTP) and [tokenStoreProvider].
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final sessionHolderProvider = Provider<SessionHolder>((ref) => SessionHolder());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    session: ref.watch(sessionHolderProvider),
    httpClient: ref.watch(httpClientProvider),
  );
});

/// Data sources
final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  return ChatRemoteDataSourceImpl(ref.watch(apiClientProvider));
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(ref.watch(apiClientProvider));
});

final accountRemoteDataSourceProvider = Provider<AccountRemoteDataSource>((ref) {
  return AccountRemoteDataSourceImpl(ref.watch(apiClientProvider));
});

/// Repositories
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(remoteDataSource: ref.watch(chatRemoteDataSourceProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    tokenStore: ref.watch(tokenStoreProvider),
    session: ref.watch(sessionHolderProvider),
  );
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepositoryImpl(ref.watch(accountRemoteDataSourceProvider));
});

/// Use cases
final getModelsProvider = Provider<GetModels>((ref) => GetModels(ref.watch(chatRepositoryProvider)));

final getChatMessagesProvider = Provider<GetChatMessages>((ref) {
  return GetChatMessages(ref.watch(chatRepositoryProvider));
});

final streamChatReplyProvider = Provider<StreamChatReply>((ref) {
  return StreamChatReply(ref.watch(chatRepositoryProvider));
});

final getConversationsProvider = Provider<GetConversations>((ref) {
  return GetConversations(ref.watch(chatRepositoryProvider));
});

final createConversationProvider = Provider<CreateConversation>((ref) {
  return CreateConversation(ref.watch(chatRepositoryProvider));
});

final updateConversationTitleProvider = Provider<UpdateConversationTitle>((ref) {
  return UpdateConversationTitle(ref.watch(chatRepositoryProvider));
});

final deleteConversationProvider = Provider<DeleteConversation>((ref) {
  return DeleteConversation(ref.watch(chatRepositoryProvider));
});

final signInProvider = Provider<SignIn>((ref) => SignIn(ref.watch(authRepositoryProvider)));
final signUpProvider = Provider<SignUp>((ref) => SignUp(ref.watch(authRepositoryProvider)));
final restoreSessionProvider = Provider<RestoreSession>((ref) => RestoreSession(ref.watch(authRepositoryProvider)));
final signOutProvider = Provider<SignOut>((ref) => SignOut(ref.watch(authRepositoryProvider)));

final getBillingProvider = Provider<GetBilling>((ref) => GetBilling(ref.watch(accountRepositoryProvider)));
final getPlansProvider = Provider<GetPlans>((ref) => GetPlans(ref.watch(accountRepositoryProvider)));
final getUsageDashboardProvider = Provider<GetUsageDashboard>((ref) {
  return GetUsageDashboard(ref.watch(accountRepositoryProvider));
});
final getSettingsProvider = Provider<GetSettings>((ref) => GetSettings(ref.watch(accountRepositoryProvider)));
final updateSettingsProvider = Provider<UpdateSettings>((ref) => UpdateSettings(ref.watch(accountRepositoryProvider)));
