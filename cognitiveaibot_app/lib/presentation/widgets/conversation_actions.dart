import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cognitive_aibot_theme.dart';
import '../../core/usecases/usecase.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/usecases/delete_conversation.dart';
import '../../domain/usecases/update_conversation_title.dart';
import '../providers/chat_providers.dart';
import '../providers/chat_session_provider.dart';
import '../providers/providers.dart';

/// Rename / Delete menu for a chat. Both act on the server.
class ConversationMenu extends ConsumerWidget {
  const ConversationMenu({super.key, required this.conversation, this.iconColor = CognitiveAIBotTheme.textSecondary});

  final Conversation conversation;
  final Color iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Chat options',
      icon: Icon(Icons.more_horiz, size: 20, color: iconColor),
      color: CognitiveAIBotTheme.cardBackground,
      onSelected: (v) => v == 'rename'
          ? renameConversation(context, ref, conversation)
          : deleteConversation(context, ref, conversation),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'rename', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 10), Text('Rename')])),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ]),
        ),
      ],
    );
  }
}

void _snack(BuildContext context, String text) {
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Future<void> renameConversation(BuildContext context, WidgetRef ref, Conversation conversation) async {
  final title = await showDialog<String>(
    context: context,
    builder: (ctx) => _RenameDialog(initial: conversation.title),
  );
  if (title == null || title.trim() == conversation.title) return;
  final result = await ref
      .read(updateConversationTitleProvider)
      .call(UpdateConversationTitleParams(conversationId: conversation.id, title: title));
  switch (result) {
    case Success(:final data):
      ref.read(chatSessionProvider.notifier).renamed(data);
      ref.invalidate(conversationsProvider);
    case FailureResult(:final failure):
      if (context.mounted) _snack(context, failure.message ?? 'Couldn’t rename the chat.');
  }
}

Future<void> deleteConversation(BuildContext context, WidgetRef ref, Conversation conversation) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: CognitiveAIBotTheme.cardBackground,
      title: const Text('Delete chat?'),
      content: Text('“${conversation.title}” and its messages will be deleted.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    ),
  );
  if (ok != true) return;
  final result = await ref
      .read(deleteConversationProvider)
      .call(DeleteConversationParams(conversationId: conversation.id));
  switch (result) {
    case Success():
      final session = ref.read(chatSessionProvider);
      if (session.conversation?.id == conversation.id) ref.read(chatSessionProvider.notifier).startNew();
      ref.invalidate(conversationsProvider);
    case FailureResult(:final failure):
      if (context.mounted) _snack(context, failure.message ?? 'Couldn’t delete the chat.');
  }
}

/// "Today, 3:04 PM" / "Yesterday, ..." / "12 Mar 2026".
String formatChatTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final time = '$hour:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
  if (day == today) return 'Today, $time';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday, $time';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

/// Waits for typing to pause before searching on the server.
class SearchDebouncer {
  String query = '';
  Timer? _timer;

  void update(String value, VoidCallback apply, {Duration delay = const Duration(milliseconds: 350)}) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      final q = value.trim();
      if (q == query) return;
      query = q;
      apply();
    });
  }

  void dispose() => _timer?.cancel();
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.onChanged, this.hintText = 'Search...'});

  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('search-field'),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
        prefixIcon: Icon(Icons.search, size: 20, color: Colors.white.withValues(alpha: 0.5)),
        filled: true,
        fillColor: CognitiveAIBotTheme.cardBackground,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
      style: const TextStyle(color: Colors.white, fontSize: 14),
    );
  }
}

/// Owns its text controller, so it is disposed only after the dialog's
/// closing animation.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: CognitiveAIBotTheme.cardBackground,
      title: const Text('Rename chat'),
      content: TextField(
        key: const Key('rename-field'),
        controller: _controller,
        autofocus: true,
        maxLength: 255,
        decoration: const InputDecoration(hintText: 'Title'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text), child: const Text('Save')),
      ],
    );
  }
}
