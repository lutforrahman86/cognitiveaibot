import 'chat_message.dart';

/// One event of a streamed reply (`POST /api/chats/:id/completions`).
sealed class CompletionEvent {
  const CompletionEvent();
}

/// The server saved the user's message and the model started answering.
final class CompletionStarted extends CompletionEvent {
  const CompletionStarted({required this.userMessage, this.chatTitle});

  final ChatMessage userMessage;

  /// The chat's title, which the server sets from the first message.
  final String? chatTitle;
}

/// The next piece of the reply.
final class CompletionDelta extends CompletionEvent {
  const CompletionDelta(this.text);

  final String text;
}

/// The reply finished and was saved.
final class CompletionDone extends CompletionEvent {
  const CompletionDone({this.message, this.creditsCharged, this.balance});

  final ChatMessage? message;
  final double? creditsCharged;
  final double? balance;
}

/// The reply failed. When [refused] is true the server turned the request
/// down before answering (e.g. `INSUFFICIENT_CREDITS`): nothing was saved
/// or charged. Otherwise the provider failed mid-reply and [message] holds
/// whatever part of the reply was saved.
final class CompletionFailed extends CompletionEvent {
  const CompletionFailed({
    required this.message,
    this.code,
    this.refused = false,
    this.partial,
    this.balance,
  });

  final String message;
  final String? code;
  final bool refused;
  final ChatMessage? partial;
  final double? balance;
}
