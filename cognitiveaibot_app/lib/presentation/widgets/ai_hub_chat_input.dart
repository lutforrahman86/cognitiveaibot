import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/cognitive_aibot_theme.dart';

/// CognitiveAI Bot style chat input - glassmorphic with +, mic, send
class AIHubChatInput extends StatefulWidget {
  const AIHubChatInput({
    super.key,
    required this.onSend,
    this.enabled = true,
    this.hintText = 'Type a message...',
  });

  final ValueChanged<String> onSend;
  final bool enabled;
  final String hintText;

  @override
  State<AIHubChatInput> createState() => _AIHubChatInputState();
}

class _AIHubChatInputState extends State<AIHubChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          decoration: BoxDecoration(
            color: CognitiveAIBotTheme.surface.withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(
                color: CognitiveAIBotTheme.textSecondary.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _IconButton(
                      icon: Icons.add,
                      onPressed: () {},
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: CognitiveAIBotTheme.cardBackground,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          enabled: widget.enabled,
                          maxLines: 4,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: widget.hintText,
                            hintStyle: const TextStyle(
                              color: CognitiveAIBotTheme.textSecondary,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(
                            color: CognitiveAIBotTheme.textPrimary,
                            fontSize: 14,
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _IconButton(
                      icon: Icons.mic,
                      onPressed: () {},
                      isPrimary: false,
                    ),
                    const SizedBox(width: 8),
                    _IconButton(
                      icon: Icons.send,
                      onPressed: widget.enabled ? _send : null,
                      isPrimary: true,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'PRESS ⌘ + ENTER TO SEND',
                  style: TextStyle(
                    fontSize: 10,
                    color: CognitiveAIBotTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isPrimary
                ? CognitiveAIBotTheme.primaryBlue
                : CognitiveAIBotTheme.cardBackground,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 22,
            color: onPressed != null
                ? CognitiveAIBotTheme.textPrimary
                : CognitiveAIBotTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
