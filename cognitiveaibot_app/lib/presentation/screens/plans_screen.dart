import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/revenuecat/subscription_service.dart';
import '../../core/theme/cognitive_aibot_theme.dart';
import '../../core/utils/platform_info.dart';
import '../../domain/entities/account.dart';
import '../providers/account_providers.dart';
import '../providers/subscription_provider.dart';
import '../widgets/plan_status_text.dart';
import '../widgets/upgrade.dart';

/// Plans from the server (`GET /api/plans`).
///
/// - iOS/Android: plans are bought through RevenueCat. Only plans with a
///   `revenuecat_product_id` are offered; the backend's RevenueCat webhook
///   adds the credits to the account (`app_user_id` = our user id).
/// - Desktop: no in-app purchase; Upgrade opens the web Upgrade page.
class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key, this.desktop});

  /// Defaults to the platform. Tests set it.
  final bool? desktop;

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  String? _buyingPlanId;

  bool get _desktop => widget.desktop ?? isDesktopPlatform;

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _buy(Plan plan) async {
    final service = ref.read(subscriptionServiceProvider);
    setState(() => _buyingPlanId = plan.id);
    try {
      final bought = await service.purchaseProduct(plan.revenueCatProductId!, subscription: plan.isSubscription);
      if (bought) {
        _snack('Thanks! Your credits are added as soon as the App Store confirms the purchase.');
        ref.invalidate(billingProvider);
      }
    } on PurchaseUnavailable catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('The purchase didn’t go through. You haven’t been charged.');
    } finally {
      if (mounted) setState(() => _buyingPlanId = null);
    }
  }

  Future<void> _restore() async {
    try {
      await ref.read(subscriptionServiceProvider).restorePurchases();
      ref.invalidate(billingProvider);
      _snack('Purchases restored. Credits from them are added to this account.');
    } catch (e) {
      _snack(e is PurchaseUnavailable ? e.message : 'Couldn’t restore purchases. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(plansProvider);
    final purchasesOn = ref.watch(subscriptionServiceProvider).isInitialized;

    return Scaffold(
      backgroundColor: CognitiveAIBotTheme.background,
      appBar: AppBar(
        title: const Text('Plans & credits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: CognitiveAIBotTheme.background,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(billingProvider);
          ref.invalidate(plansProvider);
          await ref.read(plansProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CurrentPlanCard(),
                    const SizedBox(height: 20),
                    if (_desktop) ...[
                      const Text(
                        'Plans are bought on the CognitiveAI Bot website. Credits appear here as soon as the payment goes through.',
                        style: TextStyle(fontSize: 14, color: CognitiveAIBotTheme.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          key: const Key('open-web-upgrade'),
                          onPressed: () => openWebUpgradePage(context),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Upgrade on the web'),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else if (!purchasesOn) ...[
                      const _Notice('In-app purchases aren’t available in this build.'),
                      const SizedBox(height: 16),
                    ],
                    plans.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Column(
                        children: [
                          _Notice(errorText(e)),
                          TextButton(onPressed: () => ref.invalidate(plansProvider), child: const Text('Retry')),
                        ],
                      ),
                      data: (all) => _buildPlans(all, purchasesOn),
                    ),
                    if (!_desktop && purchasesOn) ...[
                      const SizedBox(height: 12),
                      TextButton(onPressed: _restore, child: const Text('Restore purchases')),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlans(List<Plan> all, bool purchasesOn) {
    // In the app store only plans linked to a store product can be sold.
    final shown = _desktop ? all : all.where((p) => p.revenueCatProductId != null).toList();
    if (shown.isEmpty) {
      return _Notice(_desktop ? 'No plans are on sale right now.' : 'No plans can be bought in the app yet.');
    }
    final subscriptions = shown.where((p) => p.isSubscription).toList();
    final topups = shown.where((p) => !p.isSubscription).toList();
    final current = ref.watch(billingProvider).valueOrNull?.plan?.id;
    Widget card(Plan p) => _PlanCard(
          plan: p,
          current: p.id == current,
          busy: _buyingPlanId == p.id,
          onBuy: !_desktop && purchasesOn && _buyingPlanId == null ? () => _buy(p) : null,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (subscriptions.isNotEmpty) ...[
          const _SectionTitle('SUBSCRIPTIONS'),
          ...subscriptions.map(card),
        ],
        if (topups.isNotEmpty) ...[
          const _SectionTitle('TOP-UPS'),
          ...topups.map(card),
        ],
      ],
    );
  }
}

/// Current plan, available credits and plan credits that will expire.
class CurrentPlanCard extends ConsumerWidget {
  const CurrentPlanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billing = ref.watch(billingProvider);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: CognitiveAIBotTheme.cardBackground, borderRadius: BorderRadius.circular(14)),
      child: billing.when(
        loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Row(
          children: [
            Expanded(child: Text(errorText(e), style: const TextStyle(color: CognitiveAIBotTheme.textSecondary))),
            TextButton(onPressed: () => ref.invalidate(billingProvider), child: const Text('Retry')),
          ],
        ),
        data: (b) => BalanceSummary(billing: b),
      ),
    );
  }
}

class BalanceSummary extends StatelessWidget {
  const BalanceSummary({super.key, required this.billing});

  final BillingInfo billing;

  @override
  Widget build(BuildContext context) {
    final c = billing.credits;
    final expiring = c.expiringCredits;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          billing.plan?.name ?? 'Free plan',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CognitiveAIBotTheme.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          '${formatCredits(c.available)} credits',
          key: const Key('available-credits'),
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: CognitiveAIBotTheme.textPrimary),
        ),
        const Text('available', style: TextStyle(fontSize: 13, color: CognitiveAIBotTheme.textSecondary)),
        if (c.held > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${formatCredits(c.held)} reserved for a reply in progress',
              style: const TextStyle(fontSize: 12, color: CognitiveAIBotTheme.textSecondary),
            ),
          ),
        if (expiring != null && expiring > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${formatCredits(expiring)} plan credits expire${c.expiringAt != null ? ' on ${formatDate(c.expiringAt!)}' : ' at the end of the period'}',
              style: const TextStyle(fontSize: 12, color: Color(0xFFD29922)),
            ),
          ),
        if (billing.subscriptionStatus != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _subscriptionLine(billing),
              style: TextStyle(
                fontSize: 12,
                color: billing.paymentFailed ? const Color(0xFFFF7B72) : CognitiveAIBotTheme.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  String _subscriptionLine(BillingInfo b) {
    if (b.paymentFailed) return 'The last payment failed. Update your payment method.';
    final end = b.currentPeriodEnd;
    if (end == null) return 'Subscription ${b.subscriptionStatus}';
    return b.cancelAtPeriodEnd ? 'Ends on ${formatDate(end)}' : 'Renews on ${formatDate(end)}';
  }
}

String formatDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.current, required this.busy, this.onBuy});

  final Plan plan;
  final bool current;
  final bool busy;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CognitiveAIBotTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: current ? CognitiveAIBotTheme.primaryBlue : CognitiveAIBotTheme.cardBackgroundAlt),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(plan.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CognitiveAIBotTheme.textPrimary)),
                    ),
                    if (current) ...[
                      const SizedBox(width: 8),
                      const Text('CURRENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CognitiveAIBotTheme.primaryBlue)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(plan.formattedPrice, style: const TextStyle(fontSize: 14, color: CognitiveAIBotTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  '${formatCredits(plan.credits.toDouble())} credits${plan.isSubscription ? ' each ${plan.interval ?? 'period'}' : ''}'
                  '${plan.includesApi ? ' · API access' : ''}',
                  style: const TextStyle(fontSize: 13, color: CognitiveAIBotTheme.textSecondary),
                ),
                if (plan.description != null && plan.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(plan.description!, style: const TextStyle(fontSize: 13, color: CognitiveAIBotTheme.textSecondary)),
                ],
              ],
            ),
          ),
          if (onBuy != null || busy) ...[
            const SizedBox(width: 12),
            busy
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : FilledButton(onPressed: onBuy, child: Text(plan.isSubscription ? 'Subscribe' : 'Buy')),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 0, 10),
        child: Text(text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CognitiveAIBotTheme.textSecondary, letterSpacing: 0.6)),
      );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: CognitiveAIBotTheme.surface, borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: const TextStyle(fontSize: 14, color: CognitiveAIBotTheme.textSecondary)),
      );
}
