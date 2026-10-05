import 'package:flutter/material.dart';

import '../../core/theme/cognitive_aibot_theme.dart';
import '../../domain/entities/chat_message.dart';

/// CognitiveAI Bot style message bubble - glassmorphic dark theme
class AIHubMessageBubble extends StatelessWidget {
  const AIHubMessageBubble({
    super.key,
    required this.message,
    this.modelName,
  });

  final ChatMessage message;
  final String? modelName;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) _buildAIAvatar(modelName),
          if (!isUser) const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isUser && modelName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      modelName!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CognitiveAIBotTheme.textSecondary,
                      ),
                    ),
                  ),
                if (isUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'YOU',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CognitiveAIBotTheme.textSecondary,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUser
                        ? CognitiveAIBotTheme.primaryBlue
                        : CognitiveAIBotTheme.cardBackground,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: const TextStyle(
                      fontSize: 14,
                      color: CognitiveAIBotTheme.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
                if (!isUser) _buildFeedbackRow(),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: const TextStyle(
                    fontSize: 11,
                    color: CognitiveAIBotTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 12),
          if (isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildAIAvatar(String? modelName) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.smart_toy,
        size: 20,
        color: CognitiveAIBotTheme.textPrimary,
      ),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: Color(0xFFE8D5C4),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person,
        size: 18,
        color: Color(0xFF5C4A2E),
      ),
    );
  }

  Widget _buildFeedbackRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.content_copy, size: 18),
            onPressed: () {},
            style: IconButton.styleFrom(
              minimumSize: const Size(32, 32),
              foregroundColor: CognitiveAIBotTheme.textSecondary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.thumb_up_outlined, size: 18),
            onPressed: () {},
            style: IconButton.styleFrom(
              minimumSize: const Size(32, 32),
              foregroundColor: CognitiveAIBotTheme.textSecondary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.thumb_down_outlined, size: 18),
            onPressed: () {},
            style: IconButton.styleFrom(
              minimumSize: const Size(32, 32),
              foregroundColor: CognitiveAIBotTheme.textSecondary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: () {},
            style: IconButton.styleFrom(
              minimumSize: const Size(32, 32),
              foregroundColor: CognitiveAIBotTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }
}
