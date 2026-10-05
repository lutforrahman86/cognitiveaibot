import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cognitive_aibot_theme.dart';
import '../../core/usecases/usecase.dart';
import '../providers/providers.dart';

/// "Forgot password?": asks for the email and has the server send a reset
/// link. The new password is chosen on the web page the email links to.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail.trim());
  bool _busy = false;
  bool _sent = false;
  String? _error;

  static const sentMessage = 'If an account uses that email, a reset link is on its way. '
      'Open it to choose a new password, then sign in here.';

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(forgotPasswordProvider).call(_email.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (result) {
        case Success():
          _sent = true;
        case FailureResult(:final failure):
          _error = failure.message ?? 'Couldn’t send the email. Try again.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CognitiveAIBotTheme.background,
      appBar: AppBar(
        backgroundColor: CognitiveAIBotTheme.background,
        title: const Text('Reset password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Enter the email you signed up with. We’ll send you a link to choose a new password.',
                    style: TextStyle(fontSize: 14, color: CognitiveAIBotTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    key: const Key('forgot-email-field'),
                    controller: _email,
                    enabled: !_sent,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.mail_outline, size: 20),
                      filled: true,
                      fillColor: CognitiveAIBotTheme.cardBackground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      key: const Key('forgot-error'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Color(0xFFFF7B72)),
                    ),
                  ],
                  if (_sent) ...[
                    const SizedBox(height: 16),
                    Container(
                      key: const Key('forgot-sent'),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: CognitiveAIBotTheme.cardBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.mark_email_read_outlined, size: 20, color: CognitiveAIBotTheme.primaryBlue),
                          SizedBox(width: 10),
                          Expanded(child: Text(sentMessage, style: TextStyle(fontSize: 14, height: 1.4))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_sent)
                    FilledButton(
                      key: const Key('forgot-done'),
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Back to sign in'),
                    )
                  else
                    FilledButton(
                      key: const Key('forgot-submit'),
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Send reset link'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
