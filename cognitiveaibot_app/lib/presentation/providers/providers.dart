import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/chat_local_datasource.dart';
import '../../data/datasources/chat_local_datasource_impl.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/datasources/chat_remote_datasource_impl.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/create_conversation.dart';
import '../../domain/usecases/delete_conversation.dart';
import '../../domain/usecases/get_conversation_snippet.dart';
import '../../domain/usecases/get_chat_messages.dart';
import '../../domain/usecases/get_conversations.dart';
import '../../domain/usecases/send_chat_message.dart';
import '../../domain/usecases/update_conversation_title.dart';

/// Data sources
final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  return ChatRemoteDataSourceImpl();
});

final chatLocalDataSourceProvider = Provider<ChatLocalDataSource>((ref) {
  return ChatLocalDataSourceImpl();
});

/// Repository
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(
    remoteDataSource: ref.watch(chatRemoteDataSourceProvider),
    localDataSource: ref.watch(chatLocalDataSourceProvider),
  );
});

/// Use cases
final getChatMessagesProvider = Provider<GetChatMessages>((ref) {
  return GetChatMessages(ref.watch(chatRepositoryProvider));
});

final sendChatMessageProvider = Provider<SendChatMessage>((ref) {
  return SendChatMessage(ref.watch(chatRepositoryProvider));
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

final getConversationSnippetProvider = Provider<GetConversationSnippet>((ref) {
  return GetConversationSnippet(ref.watch(chatRepositoryProvider));
});
