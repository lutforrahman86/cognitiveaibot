import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/subscription_provider.dart';

/// Shown where the account's name goes. The app has no sign-in yet (roadmap
/// Phase 4), so there is no name to show.
const String notSignedInLabel = 'Not signed in';

/// Which piece of plan text to show.
enum PlanText { title, detail, badge, memberLabel, actionLabel }

/// Plan text based on the real RevenueCat entitlement check, so the app never
/// claims a plan or billing date the user doesn't have.
class PlanStatusText extends ConsumerWidget {
  const PlanStatusText(
    this.kind, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final PlanText kind;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  static String labelFor(PlanText kind, {required bool isPro}) => switch (kind) {
        PlanText.title => isPro ? 'CognitiveAI Bot Pro' : 'Free plan',
        PlanText.detail => isPro
            ? 'Manage billing in your app store account.'
            : 'Upgrade for more models and higher limits.',
        PlanText.badge => isPro ? 'PRO' : 'FREE',
        PlanText.memberLabel => isPro ? 'Pro member' : 'Free plan',
        PlanText.actionLabel => isPro ? 'Manage Subscription' : 'View plans',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(isProEntitledProvider).valueOrNull ?? false;
    return Text(
      labelFor(kind, isPro: isPro),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
