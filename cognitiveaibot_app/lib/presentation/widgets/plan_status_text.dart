import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/account_providers.dart';

/// The account's plan name from the server (`GET /api/billing`), or
/// "Free plan" when it has no subscription.
class PlanStatusText extends ConsumerWidget {
  const PlanStatusText({super.key, this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billing = ref.watch(billingProvider).valueOrNull;
    return Text(billing?.plan?.name ?? (billing == null ? '' : 'Free plan'), style: style, overflow: TextOverflow.ellipsis);
  }
}

/// "123.45 credits" from the server's available balance.
class CreditsText extends ConsumerWidget {
  const CreditsText({super.key, this.style, this.suffix = ' credits'});

  final TextStyle? style;
  final String suffix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billing = ref.watch(billingProvider);
    return Text(
      billing.when(
        data: (b) => '${formatCredits(b.credits.available)}$suffix',
        loading: () => '…',
        error: (_, _) => 'Balance unavailable',
      ),
      style: style,
      overflow: TextOverflow.ellipsis,
    );
  }
}

String formatCredits(double credits) {
  final abs = credits.abs();
  final fixed = credits.toStringAsFixed(abs >= 100 ? 0 : (abs >= 1 || abs == 0 ? 2 : 4));
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return parts.length > 1 ? '$whole.${parts[1]}' : whole;
}
