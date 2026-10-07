import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/usecases/usecase.dart';
import '../../domain/entities/ai_model.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/usecases/get_conversations.dart';
import 'auth_provider.dart';
import 'providers.dart';

T _unwrap<T>(Result<T> result) => switch (result) {
      Success(:final data) => data,
      FailureResult(:final failure) => throw failure,
    };

/// The server's model catalog, unavailable models included.
final modelsProvider = FutureProvider<List<AiModel>>((ref) async {
  return _unwrap(await ref.read(getModelsProvider).call(const NoParams()));
});

/// The model chosen on the Models tab; new chats start with it. Null: the
/// first available model.
final preferredModelIdProvider = StateProvider<String?>((ref) => null);

/// The model new chats use: the preferred one if it's available, otherwise
/// the first available model.
AiModel? defaultModel(List<AiModel> models, String? preferredId) {
  for (final m in models) {
    if (m.id == preferredId && m.available) return m;
  }
  for (final m in models) {
    if (m.available) return m;
  }
  return null;
}

/// The signed-in user's chats, newest first, filtered on the server by the
/// search text (empty: all chats).
final conversationsProvider = FutureProvider.family<List<Conversation>, String>((ref, search) async {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return _unwrap(await ref.read(getConversationsProvider).call(GetConversationsParams(search: search)));
});
