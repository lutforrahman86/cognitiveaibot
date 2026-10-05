import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cognitive_aibot_theme.dart';
import '../../core/usecases/usecase.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../providers/auth_provider.dart';
import '../providers/providers.dart';

const _errorColor = Color(0xFFFF7B72);

InputDecoration _fieldDecoration(String label, {String? helper}) => InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 2,
      filled: true,
      fillColor: CognitiveAIBotTheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    );

/// Settings › Change password. This device stays signed in; every other
/// session is signed out by the server.
Future<void> showChangePasswordDialog(BuildContext context) async {
  final changed = await showDialog<bool>(context: context, builder: (_) => const _ChangePasswordDialog());
  if (changed == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password changed. Other devices were signed out.')),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_next.text != _repeat.text) {
      setState(() => _error = 'The new passwords don’t match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref.read(authControllerProvider.notifier).changePassword(_current.text, _next.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: CognitiveAIBotTheme.cardBackground,
      title: const Text('Change password'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('current-password-field'),
                  controller: _current,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.next,
                  decoration: _fieldDecoration('Current password'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('new-password-field'),
                  controller: _next,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  decoration: _fieldDecoration('New password', helper: 'At least $minPasswordLength characters'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('repeat-password-field'),
                  controller: _repeat,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: _fieldDecoration('Repeat new password'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, key: const Key('change-password-error'), style: const TextStyle(fontSize: 13, color: _errorColor)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(
          key: const Key('change-password-submit'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Change password'),
        ),
      ],
    );
  }
}

/// Settings › Delete account (App Store guideline 5.1.1(v)). Asks for the
/// password; on success the app returns to sign-in, explaining that an App
/// Store subscription has to be cancelled in the Apple account.
Future<void> showDeleteAccountDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _DeleteAccountDialog());

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final error = await ref.read(authControllerProvider.notifier).deleteAccount(_confirm.text);
    if (!mounted) return;
    if (error == null) {
      // Signed out: the app is returning to sign-in.
      if (navigator.canPop()) navigator.pop();
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(fontSize: 14, height: 1.4);
    return AlertDialog(
      backgroundColor: CognitiveAIBotTheme.cardBackground,
      title: const Text('Delete your account?'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Your chats, settings, credits and API keys are deleted for good. This can’t be undone.',
                style: body,
              ),
              const SizedBox(height: 10),
              const Text(
                'A web (card) subscription is cancelled with the account. An App Store subscription isn’t: '
                'cancel it in your Apple account settings (Settings › your name › Subscriptions).',
                style: TextStyle(fontSize: 13, height: 1.4, color: CognitiveAIBotTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('delete-account-confirm-field'),
                controller: _confirm,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: (_) => _submit(),
                decoration: _fieldDecoration(
                  'Password',
                  helper: 'Signed up with Google or GitHub? Type your email address instead.',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, key: const Key('delete-account-error'), style: const TextStyle(fontSize: 13, color: _errorColor)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          key: const Key('delete-account-submit'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Delete account', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    );
  }
}

/// Settings › Download my data: fetches the export and saves it as a JSON
/// file (macOS: Downloads; iOS: the app's folder in the Files app).
Future<void> downloadMyData(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Preparing your data…')));
  final result = await ref.read(exportDataProvider).call(const NoParams());
  final String json;
  switch (result) {
    case Success(:final data):
      json = data;
    case FailureResult(:final failure):
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message ?? 'Couldn’t export your data. Try again.')));
      return;
  }
  final now = DateTime.now();
  final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final fileName = 'cognitiveaibot-export-$date.json';
  try {
    final saved = await ref.read(exportSaverProvider).save(fileName, json);
    final name = saved.path.split('/').last;
    final folder = saved.path.substring(0, saved.path.length - name.length);
    final canReveal = !kIsWeb && Platform.isMacOS;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        key: const Key('export-saved'),
        duration: const Duration(seconds: 8),
        content: Text('Saved $name to ${saved.description}.'),
        action: canReveal
            ? SnackBarAction(label: 'Show', onPressed: () => ref.read(linkOpenerProvider)(Uri.directory(folder)))
            : null,
      ));
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Couldn’t save the file. Try again.')));
  }
}
