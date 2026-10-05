import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cognitive_aibot_theme.dart';
import '../providers/auth_provider.dart';

const emailVerificationMessage = 'Confirm your email to get your trial credits and to buy credits';

/// Hidden for the rest of the session once dismissed; reset per account.
final verificationBannerDismissedProvider = StateProvider<bool>((ref) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return false;
});

/// Sends a new confirmation email and shows the outcome in a snack bar.
Future<void> resendVerificationEmail(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = await ref.read(authControllerProvider.notifier).resendVerification();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Whether the banner should show now.
final showVerificationBannerProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null && !user.emailVerified && !ref.watch(verificationBannerDismissedProvider);
});

/// "Confirm your email…" with Resend, while the signed-in account's email
/// isn't confirmed. (The shell rechecks with the server when the app comes
/// back to the front, since the link is usually opened in another app.)
class EmailVerificationBanner extends ConsumerStatefulWidget {
  const EmailVerificationBanner({super.key, this.dismissible = true});

  final bool dismissible;

  @override
  ConsumerState<EmailVerificationBanner> createState() => _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends ConsumerState<EmailVerificationBanner> {
  bool _sending = false;

  Future<void> _resend() async {
    setState(() => _sending = true);
    await resendVerificationEmail(context, ref);
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final dismissed = widget.dismissible && ref.watch(verificationBannerDismissedProvider);
    if (user == null || user.emailVerified || dismissed) return const SizedBox.shrink();
    return Container(
      key: const Key('verify-email-banner'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      decoration: BoxDecoration(
        color: CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_unread_outlined, size: 20, color: CognitiveAIBotTheme.primaryBlue),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              emailVerificationMessage,
              style: TextStyle(fontSize: 13, color: CognitiveAIBotTheme.textPrimary),
            ),
          ),
          TextButton(
            key: const Key('resend-verification'),
            onPressed: _sending ? null : _resend,
            child: _sending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Resend email'),
          ),
          if (widget.dismissible)
            IconButton(
              key: const Key('dismiss-verify-banner'),
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close, size: 18, color: Colors.white70),
              onPressed: () => ref.read(verificationBannerDismissedProvider.notifier).state = true,
            ),
        ],
      ),
    );
  }
}
