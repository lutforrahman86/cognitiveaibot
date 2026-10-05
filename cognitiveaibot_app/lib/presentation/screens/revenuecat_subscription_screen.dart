import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../../core/revenuecat/paywall_presenter.dart';
import '../../core/theme/cognitive_aibot_theme.dart';
import '../providers/subscription_provider.dart';

/// RevenueCat subscription screen — Upgrade (Paywall) and Manage (Customer Center).
///
/// Products: monthly, yearly, lifetime (configured in RevenueCat dashboard).
class RevenueCatSubscriptionScreen extends ConsumerWidget {
  const RevenueCatSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerInfo = ref.watch(customerInfoProvider);
    final isPro = ref.watch(isProEntitledProvider);

    return Scaffold(
      backgroundColor: CognitiveAIBotTheme.background,
      appBar: AppBar(
        backgroundColor: CognitiveAIBotTheme.background,
        foregroundColor: CognitiveAIBotTheme.textPrimary,
        title: const Text(
          'Subscription',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: CognitiveAIBotTheme.textPrimary,
          ),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildStatusCard(context, ref, isPro, customerInfo),
            const SizedBox(height: 24),
            _buildUpgradeButton(context),
            const SizedBox(height: 12),
            _buildManageButton(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<bool> isPro,
    AsyncValue<dynamic> customerInfo,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CognitiveAIBotTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.auto_awesome,
                  color: CognitiveAIBotTheme.primaryBlue,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CognitiveAI Bot Pro',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: CognitiveAIBotTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    isPro.when(
                      data: (pro) => Text(
                        pro ? 'Active subscription' : 'Free tier',
                        style: TextStyle(
                          fontSize: 14,
                          color: CognitiveAIBotTheme.textSecondary,
                        ),
                      ),
                      loading: () => Text(
                        'Checking...',
                        style: TextStyle(
                          fontSize: 14,
                          color: CognitiveAIBotTheme.textSecondary,
                        ),
                      ),
                      error: (err, _) => Text(
                        'Unable to load status',
                        style: TextStyle(
                          fontSize: 14,
                          color: CognitiveAIBotTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              isPro.when(
                data: (pro) => pro
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: CognitiveAIBotTheme.primaryBlue,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (err, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _showPaywall(context),
        icon: const Icon(Icons.workspace_premium, size: 22),
        label: const Text('Upgrade to Pro'),
        style: FilledButton.styleFrom(
          backgroundColor: CognitiveAIBotTheme.primaryBlue,
          foregroundColor: CognitiveAIBotTheme.textPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildManageButton(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      onPressed: () => _showCustomerCenter(context, ref),
      icon: const Icon(Icons.settings, size: 20),
      label: const Text('Manage Subscription & Restore'),
      style: TextButton.styleFrom(
        foregroundColor: CognitiveAIBotTheme.textSecondary,
      ),
    );
  }

  Future<void> _showPaywall(BuildContext context) async {
    final result = await PaywallPresenter.presentPaywall(
      context: context,
      displayCloseButton: true,
    );
    if (!context.mounted) return;
    switch (result) {
      case PaywallResult.purchased:
      case PaywallResult.restored:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your purchase!')),
        );
        break;
      case PaywallResult.cancelled:
        break;
      case PaywallResult.error:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
        break;
      case PaywallResult.notPresented:
        break;
    }
  }

  Future<void> _showCustomerCenter(BuildContext context, WidgetRef ref) async {
    await PaywallPresenter.presentCustomerCenter(
      onRestoreCompleted: () {
        ref.invalidate(customerInfoProvider);
        ref.invalidate(isProEntitledProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchases restored successfully')),
          );
        }
      },
      onRestoreFailed: () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No purchases to restore')),
          );
        }
      },
    );
  }
}
