import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/cognitive_aibot_theme.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../providers/auth_provider.dart';
import '../widgets/legal_links.dart';
import 'forgot_password_screen.dart';

/// Email and password sign-in / sign-up. (Google and GitHub sign-in are on
/// the web app only for now.)
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authControllerProvider.notifier);
    final error = _signUp
        ? await auth.signUp(_email.text, _password.text, _name.text)
        : await auth.signIn(_email.text, _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: CognitiveAIBotTheme.cardBackground,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final notice = _error ?? state.notice ?? state.restoreError;
    final info = _error == null ? state.info : null;
    return Scaffold(
      backgroundColor: CognitiveAIBotTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.smart_toy, size: 64, color: CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.8)),
                    const SizedBox(height: 16),
                    const Text(
                      AppConstants.appName,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: CognitiveAIBotTheme.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _signUp ? 'Create your account' : 'Sign in to your account',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: CognitiveAIBotTheme.textSecondary),
                    ),
                    const SizedBox(height: 28),
                    if (_signUp) ...[
                      TextField(
                        key: const Key('name-field'),
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        decoration: _decoration('Name (optional)', Icons.person_outline),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      key: const Key('email-field'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      decoration: _decoration('Email', Icons.mail_outline),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('password-field'),
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      autofillHints: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                      decoration: _decoration(
                        _signUp ? 'Password (at least $minPasswordLength characters)' : 'Password',
                        Icons.lock_outline,
                        suffix: IconButton(
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    if (!_signUp)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const Key('forgot-password'),
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).push(MaterialPageRoute<void>(
                                    builder: (_) => ForgotPasswordScreen(initialEmail: _email.text),
                                  )),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    if (info != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        key: const Key('auth-info'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CognitiveAIBotTheme.cardBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(info, style: const TextStyle(fontSize: 13, color: CognitiveAIBotTheme.textPrimary, height: 1.4)),
                      ),
                    ],
                    if (notice != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        notice,
                        key: const Key('auth-message'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Color(0xFFFF7B72)),
                      ),
                    ],
                    if (state.restoreError != null && _error == null) ...[
                      TextButton(
                        onPressed: () => ref.read(authControllerProvider.notifier).restore(),
                        child: const Text('Try again'),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('auth-submit'),
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_signUp ? 'Create account' : 'Sign in'),
                    ),
                    if (_signUp) ...[
                      const SizedBox(height: 12),
                      const SignUpAgreement(),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
                      key: const Key('auth-toggle'),
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _signUp = !_signUp;
                                _error = null;
                              }),
                      child: Text(_signUp ? 'Already have an account? Sign in' : 'New here? Create an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
