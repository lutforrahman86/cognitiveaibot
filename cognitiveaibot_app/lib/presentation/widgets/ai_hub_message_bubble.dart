import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/cognitive_aibot_theme.dart';
import '../../domain/entities/chat_message.dart';

/// A chat message. Assistant replies render as Markdown with highlighted
/// code, and offer Copy and (on the latest reply) Regenerate.
class AIHubMessageBubble extends StatelessWidget {
  const AIHubMessageBubble({
    super.key,
    required this.message,
    this.streaming = false,
    this.onRegenerate,
    this.fontSize = 15,
    this.showTimestamp = true,
  });

  final ChatMessage message;

  /// The reply is still arriving.
  final bool streaming;

  /// Shown on the latest reply when not streaming.
  final VoidCallback? onRegenerate;
  final double fontSize;
  final bool showTimestamp;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) _buildAIAvatar(),
          if (!isUser) const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    isUser ? 'YOU' : (message.modelName ?? 'Assistant'),
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
                    color: isUser ? CognitiveAIBotTheme.primaryBlueDim : CognitiveAIBotTheme.cardBackground,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                  ),
                  child: isUser
                      ? SelectableText(
                          message.content,
                          style: TextStyle(fontSize: fontSize, color: CognitiveAIBotTheme.textPrimary, height: 1.5),
                        )
                      : _buildReply(context),
                ),
                if (!isUser && !streaming && message.content.isNotEmpty) _buildActions(context),
                if (showTimestamp && !streaming) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: const TextStyle(fontSize: 11, color: CognitiveAIBotTheme.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 12),
          if (isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildReply(BuildContext context) {
    if (message.content.isEmpty && streaming) {
      return const SizedBox(
        width: 24,
        height: 16,
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: CognitiveAIBotTheme.textSecondary),
          ),
        ),
      );
    }
    return MarkdownBlock(
      data: message.content,
      selectable: !streaming,
      config: markdownConfig(fontSize: fontSize),
    );
  }

  /// Dark Markdown styling that matches the app, with highlighted code
  /// blocks that each have their own Copy button.
  static MarkdownConfig markdownConfig({double fontSize = 15}) {
    final body = TextStyle(fontSize: fontSize, color: CognitiveAIBotTheme.textPrimary, height: 1.5);
    return MarkdownConfig.darkConfig.copy(configs: [
      PConfig(textStyle: body),
      const CodeConfig(
        style: TextStyle(
          fontFamily: 'monospace',
          fontFamilyFallback: ['Menlo', 'Courier'],
          backgroundColor: CognitiveAIBotTheme.cardBackgroundAlt,
          color: Color(0xFFE6EDF3),
        ),
      ),
      PreConfig(
        theme: atomOneDarkTheme,
        language: 'plaintext',
        textStyle: TextStyle(fontSize: fontSize - 2, fontFamily: 'monospace', fontFamilyFallback: const ['Menlo', 'Courier']),
        decoration: BoxDecoration(
          color: const Color(0xFF282C34),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: CognitiveAIBotTheme.cardBackgroundAlt),
        ),
        padding: const EdgeInsets.fromLTRB(12, 30, 12, 12),
        wrapper: (child, code, language) => _CodeBlockWrapper(code: code, language: language, child: child),
      ),
      LinkConfig(
        style: const TextStyle(color: CognitiveAIBotTheme.primaryBlue, decoration: TextDecoration.underline),
        onTap: (url) {
          final uri = Uri.tryParse(url);
          if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ),
    ]);
  }

  Widget _buildAIAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.smart_toy, size: 20, color: CognitiveAIBotTheme.textPrimary),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(color: Color(0xFFE8D5C4), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: const Icon(Icons.person, size: 18, color: Color(0xFF5C4A2E)),
    );
  }

  Widget _buildActions(BuildContext context) {
    final style = IconButton.styleFrom(
      minimumSize: const Size(32, 32),
      foregroundColor: CognitiveAIBotTheme.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.content_copy, size: 18),
            style: style,
            onPressed: () => copyToClipboard(context, message.content),
          ),
          if (onRegenerate != null)
            IconButton(
              tooltip: 'Regenerate',
              icon: const Icon(Icons.refresh, size: 18),
              style: style,
              onPressed: onRegenerate,
            ),
        ],
      ),
    );
  }

  static Future<void> copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }
}

class _CodeBlockWrapper extends StatelessWidget {
  const _CodeBlockWrapper({required this.child, required this.code, required this.language});

  final Widget child;
  final String code;
  final String language;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 12,
          left: 12,
          right: 4,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  language == 'plaintext' ? '' : language,
                  style: const TextStyle(fontSize: 11, color: CognitiveAIBotTheme.textSecondary),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => AIHubMessageBubble.copyToClipboard(context, code.trimRight()),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.content_copy, size: 13, color: CognitiveAIBotTheme.textSecondary),
                      SizedBox(width: 4),
                      Text('Copy code', style: TextStyle(fontSize: 11, color: CognitiveAIBotTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
