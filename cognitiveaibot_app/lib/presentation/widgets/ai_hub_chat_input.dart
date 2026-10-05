import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/cognitive_aibot_theme.dart';

/// Message box with Send, which turns into Stop while a reply streams.
///
/// With [enterToSend], Enter sends and Shift+Enter starts a new line; without
/// it, Enter starts a new line and ⌘/Ctrl+Enter sends.
class AIHubChatInput extends StatefulWidget {
  const AIHubChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.onStop,
    this.streaming = false,
    this.enabled = true,
    this.enterToSend = true,
    this.hintText = 'Type a message...',
  });

  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final VoidCallback? onStop;
  final bool streaming;
  final bool enabled;
  final bool enterToSend;
  final String hintText;

  @override
  State<AIHubChatInput> createState() => _AIHubChatInputState();
}

class _AIHubChatInputState extends State<AIHubChatInput> {
  late final FocusNode _focusNode = FocusNode(onKeyEvent: _onKey);

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canSend => widget.enabled && !widget.streaming;

  void _send() {
    final text = widget.controller.text.trim();
    if (text.isEmpty || !_canSend) return;
    widget.onSend(text);
    widget.controller.clear();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.enter && event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    final keys = HardwareKeyboard.instance;
    final modifier = keys.isMetaPressed || keys.isControlPressed;
    final sends = widget.enterToSend ? !keys.isShiftPressed : modifier;
    if (!sends) return KeyEventResult.ignored;
    _send();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final hint = widget.enterToSend ? 'ENTER TO SEND · SHIFT + ENTER FOR A NEW LINE' : '⌘ + ENTER TO SEND';
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          decoration: BoxDecoration(
            color: CognitiveAIBotTheme.surface.withValues(alpha: 0.9),
            border: Border(top: BorderSide(color: CognitiveAIBotTheme.textSecondary.withValues(alpha: 0.2))),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: CognitiveAIBotTheme.cardBackground,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          key: const Key('chat-input'),
                          controller: widget.controller,
                          focusNode: _focusNode,
                          enabled: widget.enabled,
                          maxLines: 6,
                          minLines: 1,
                          keyboardType: TextInputType.multiline,
                          textInputAction: widget.enterToSend ? TextInputAction.send : TextInputAction.newline,
                          onSubmitted: widget.enterToSend ? (_) => _send() : null,
                          decoration: InputDecoration(
                            hintText: widget.hintText,
                            hintStyle: const TextStyle(color: CognitiveAIBotTheme.textSecondary, fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(color: CognitiveAIBotTheme.textPrimary, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    widget.streaming
                        ? _RoundButton(
                            key: const Key('stop-button'),
                            icon: Icons.stop_rounded,
                            tooltip: 'Stop',
                            color: const Color(0xFFDA3633),
                            onPressed: widget.onStop,
                          )
                        : ListenableBuilder(
                            listenable: widget.controller,
                            builder: (context, _) => _RoundButton(
                              key: const Key('send-button'),
                              icon: Icons.send,
                              tooltip: 'Send',
                              color: CognitiveAIBotTheme.primaryBlue,
                              onPressed: _canSend && widget.controller.text.trim().isNotEmpty ? _send : null,
                            ),
                          ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(hint, style: const TextStyle(fontSize: 10, color: CognitiveAIBotTheme.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.icon, required this.tooltip, required this.color, this.onPressed});

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: onPressed != null ? color : CognitiveAIBotTheme.cardBackground,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 22,
              color: onPressed != null ? CognitiveAIBotTheme.textPrimary : CognitiveAIBotTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
