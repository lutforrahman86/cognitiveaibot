import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cognitive_aibot_theme.dart';
import '../providers/chat_settings_provider.dart';
import 'profile_management_screen.dart';
import 'revenuecat_subscription_screen.dart';
import '../widgets/plan_status_text.dart';

/// Desktop Settings design tokens — pixel-perfect match to design image
class _DesktopSettingsDesign {
  _DesktopSettingsDesign._();
  static const mainBg = Color(0xFF0D0D0D);
  static const cardBg = Color(0xFF1F1F1F);
  static const sidebarBg = Color(0xFF181818);
  static const accentBlue = Color(0xFF2196F3);
  static const navActiveBg = Color(0xFF1E3A5F);
  static const logoutRed = Color(0xFFE53935);
}

/// Chat Settings screen - appearance, behavior, voice, model, data
/// When [useDesktopLayout] is true, renders desktop-optimized layout
class ChatSettingsScreen extends ConsumerWidget {
  const ChatSettingsScreen({
    super.key,
    this.onBack,
    this.useDesktopLayout = false,
    this.fullLayoutWithSidebar = false,
    this.contentOnly = false,
    this.onNavTap,
  });

  /// When provided, back button uses this (e.g. when used as tab)
  final VoidCallback? onBack;
  final bool useDesktopLayout;
  /// When true, renders full layout with sidebar (standalone)
  final bool fullLayoutWithSidebar;
  /// When true, renders only the content (for embedding in MainShell with root sidebar)
  final bool contentOnly;
  /// Called when user taps nav item (index)
  final ValueChanged<int>? onNavTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(chatSettingsProvider);

    if (contentOnly) {
      return const _DesktopSettingsContentOnly();
    }
    if (fullLayoutWithSidebar) {
      return _DesktopSettingsFullLayout(onNavTap: onNavTap ?? (_) {});
    }
    if (useDesktopLayout) {
      return const _DesktopSettingsLayout();
    }

    return Scaffold(
      backgroundColor: CognitiveAIBotTheme.background,
      appBar: AppBar(
        backgroundColor: CognitiveAIBotTheme.background,
        foregroundColor: CognitiveAIBotTheme.textPrimary,
        
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: CognitiveAIBotTheme.textPrimary,
          ),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _ProfileSection(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ProfileManagementScreen(),
                ),
              );
            },
          ),
          const _SubscriptionSection(),
          const _NotificationSections(),
          const _SectionHeader(title: 'APPEARANCE'),
          _SettingsTile(
            title: 'Dark Mode',
            trailing: Switch(
              value: settings.darkMode,
              onChanged: (v) =>
                  ref.read(chatSettingsProvider.notifier).setDarkMode(v),
            ),
          ),
          _SettingsTile(
            title: 'Font size',
            leading: const Icon(Icons.text_fields, color: CognitiveAIBotTheme.textSecondary),
            trailing: Text(
              '${settings.fontSize.toInt()}px',
              style: const TextStyle(
                color: CognitiveAIBotTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            subtitle: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: CognitiveAIBotTheme.primaryBlue,
                inactiveTrackColor: CognitiveAIBotTheme.cardBackgroundAlt,
                thumbColor: CognitiveAIBotTheme.textPrimary,
              ),
              child: Slider(
                value: settings.fontSize,
                min: 12,
                max: 24,
                divisions: 12,
                onChanged: (v) =>
                    ref.read(chatSettingsProvider.notifier).setFontSize(v),
              ),
            ),
          ),
          _SectionHeader(title: 'CHAT BEHAVIOR'),
          _SettingsTile(
            title: 'Enter to Send',
            subtitle: const Text(
              'Press enter key to send message',
              style: TextStyle(
                fontSize: 12,
                color: CognitiveAIBotTheme.textSecondary,
              ),
            ),
            trailing: Switch(
              value: settings.enterToSend,
              onChanged: (v) =>
                  ref.read(chatSettingsProvider.notifier).setEnterToSend(v),
            ),
          ),
          _SettingsTile(
            title: 'Show Timestamps',
            subtitle: const Text(
              'Display time for each bubble',
              style: TextStyle(
                fontSize: 12,
                color: CognitiveAIBotTheme.textSecondary,
              ),
            ),
            trailing: Switch(
              value: settings.showTimestamps,
              onChanged: (v) =>
                  ref.read(chatSettingsProvider.notifier).setShowTimestamps(v),
            ),
          ),
          _SectionHeader(title: 'VOICE & AUDIO'),
          _SettingsTile(
            title: 'Read Responses Aloud',
            subtitle: const Text(
              'Automatic text-to-speech',
              style: TextStyle(
                fontSize: 12,
                color: CognitiveAIBotTheme.textSecondary,
              ),
            ),
            trailing: Switch(
              value: settings.readResponsesAloud,
              onChanged: (v) =>
                  ref.read(chatSettingsProvider.notifier).setReadResponsesAloud(v),
            ),
          ),
          _SettingsTile(
            title: 'AI Voice Model',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  settings.aiVoiceModel,
                  style: const TextStyle(
                    color: CognitiveAIBotTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: CognitiveAIBotTheme.textSecondary,
                ),
              ],
            ),
            onTap: () => _showVoiceModelPicker(context, ref),
          ),
          _SectionHeader(title: 'MODEL PREFERENCES'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'System Prompt',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: CognitiveAIBotTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: CognitiveAIBotTheme.textSecondary.withValues(alpha: 0.8),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  maxLines: 4,
                  initialValue: settings.systemPrompt,
                  onChanged: (v) =>
                      ref.read(chatSettingsProvider.notifier).setSystemPrompt(v),
                  decoration: InputDecoration(
                    hintText:
                        'You are a helpful assistant that provides concise and accurate answers...',
                    hintStyle: const TextStyle(
                      color: CognitiveAIBotTheme.textSecondary,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: CognitiveAIBotTheme.cardBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  style: const TextStyle(
                    color: CognitiveAIBotTheme.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _SettingsTile(
            title: 'Temperature',
            subtitle: const Text(
              'Controls randomness & creativity',
              style: TextStyle(
                fontSize: 12,
                color: CognitiveAIBotTheme.textSecondary,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                settings.temperature.toStringAsFixed(1),
                style: const TextStyle(
                  color: CognitiveAIBotTheme.primaryBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            customTrailing: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: CognitiveAIBotTheme.primaryBlue,
                      inactiveTrackColor: CognitiveAIBotTheme.cardBackgroundAlt,
                      thumbColor: CognitiveAIBotTheme.textPrimary,
                    ),
                    child: Slider(
                      value: settings.temperature,
                      min: 0,
                      max: 1,
                      onChanged: (v) =>
                          ref.read(chatSettingsProvider.notifier).setTemperature(v),
                    ),
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PRECISE',
                        style: TextStyle(
                          fontSize: 10,
                          color: CognitiveAIBotTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'BALANCED',
                        style: TextStyle(
                          fontSize: 10,
                          color: CognitiveAIBotTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'CREATIVE',
                        style: TextStyle(
                          fontSize: 10,
                          color: CognitiveAIBotTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _SectionHeader(title: 'DATA MANAGEMENT'),
          _SettingsTile(
            title: 'Export Chat History',
            leading: const Icon(Icons.download, color: CognitiveAIBotTheme.textSecondary),
            trailing: const Icon(Icons.chevron_right, color: CognitiveAIBotTheme.textSecondary),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export chat history')),
              );
            },
          ),
          _SettingsTile(
            title: 'Clear All Conversations',
            leading: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close, size: 20, color: Colors.white),
            ),
            titleColor: Colors.red,
            onTap: () => _showClearConfirmDialog(context, ref),
          ),
        ],
      ),
    );
  }

  void _showVoiceModelPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: CognitiveAIBotTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Nova (Female, Professional)'),
              onTap: () {
                ref.read(chatSettingsProvider.notifier).setAiVoiceModel(
                      'Nova (Female, Professional)',
                    );
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Alloy (Male, Neutral)'),
              onTap: () {
                ref.read(chatSettingsProvider.notifier).setAiVoiceModel(
                      'Alloy (Male, Neutral)',
                    );
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Echo (Male, Warm)'),
              onTap: () {
                ref.read(chatSettingsProvider.notifier).setAiVoiceModel(
                      'Echo (Male, Warm)',
                    );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showClearConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CognitiveAIBotTheme.cardBackground,
        title: const Text(
          'Clear All Conversations?',
          style: TextStyle(color: CognitiveAIBotTheme.textPrimary),
        ),
        content: const Text(
          'This will permanently delete all your chat history. This action cannot be undone.',
          style: TextStyle(color: CognitiveAIBotTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(chatSettingsProvider.notifier).clearAllConversations();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All conversations cleared')),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// Settings content only — two-column layout for embedding in MainShell (no sidebar)
class _DesktopSettingsContentOnly extends ConsumerWidget {
  const _DesktopSettingsContentOnly();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: _DesktopSettingsDesign.mainBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'Manage your account preferences and application behavior.',
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 32),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 24.0;
                final colWidth = (constraints.maxWidth - gap) / 2;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: colWidth, child: const _SettingsLeftColumn()),
                    const SizedBox(width: gap),
                    SizedBox(width: colWidth, child: const _SettingsRightColumn()),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Full Settings layout: sidebar + two-column content (pixel-perfect per design image)
class _DesktopSettingsFullLayout extends ConsumerWidget {
  const _DesktopSettingsFullLayout({required this.onNavTap});

  final ValueChanged<int> onNavTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: _DesktopSettingsDesign.mainBg,
      body: Row(
        children: [
          _SettingsSidebar(onNavTap: onNavTap),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Manage your account preferences and application behavior.',
                    style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 32),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 24.0;
                      final colWidth = (constraints.maxWidth - gap) / 2;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: colWidth,
                            child: const _SettingsLeftColumn(),
                          ),
                          const SizedBox(width: gap),
                          SizedBox(
                            width: colWidth,
                            child: const _SettingsRightColumn(),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSidebar extends StatelessWidget {
  const _SettingsSidebar({required this.onNavTap});

  final ValueChanged<int> onNavTap;

  static const _navItems = [
    (Icons.home_outlined, 'Home', 0),
    (Icons.history, 'History', 1),
    (Icons.view_in_ar, 'Models', 2),
    (Icons.show_chart, 'Usage', 3),
    (Icons.settings, 'Settings', 4),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: _DesktopSettingsDesign.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: _DesktopSettingsDesign.accentBlue.withValues(alpha: 0.4),
                  child: const Icon(Icons.person, size: 32, color: Colors.white),
                ),
                const SizedBox(height: 12),
                const Text(
                  notSignedInLabel,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                PlanStatusText(
                  PlanText.memberLabel,
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ..._navItems.map((item) {
            final (icon, label, index) = item;
            final isSettings = index == 4;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Material(
                color: isSettings ? _DesktopSettingsDesign.navActiveBg : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => onNavTap(index),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(icon, size: 22, color: isSettings ? Colors.white : Colors.white70),
                        const SizedBox(width: 14),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSettings ? FontWeight.w600 : FontWeight.w500,
                            color: isSettings ? Colors.white : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log out'))),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 22, color: _DesktopSettingsDesign.logoutRed),
                      const SizedBox(width: 14),
                      Text(
                        'Log Out',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _DesktopSettingsDesign.logoutRed),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsLeftColumn extends ConsumerWidget {
  const _SettingsLeftColumn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(chatSettingsProvider);
    final notifier = ref.read(chatSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsSection(
          title: 'SUBSCRIPTION',
          child: const _SubscriptionBlock(),
        ),
        const SizedBox(height: 24),
        _SettingsSection(
          title: 'GLOBAL CONTROLS',
          child: _SettingsNotificationRow(
            icon: Icons.notifications,
            title: 'Push Notifications',
            subtitle: 'Main switch for all app alerts',
            value: settings.pushNotifications ?? true,
            onChanged: notifier.setPushNotifications,
          ),
        ),
        const SizedBox(height: 24),
        _SettingsSection(
          title: 'AI INSIGHTS',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsNotificationRow(
                icon: Icons.refresh,
                title: 'New AI Models',
                subtitle: 'Alerts for GPT-5, Claude 4, etc.',
                value: settings.newAiModels ?? true,
                onChanged: notifier.setNewAiModels,
              ),
              const SizedBox(height: 4),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 4),
              _SettingsNotificationRow(
                icon: Icons.auto_awesome,
                title: 'Feature Updates',
                subtitle: 'New tools and UI enhancements',
                value: settings.featureUpdates ?? false,
                onChanged: notifier.setFeatureUpdates,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SettingsSection(
          title: 'USAGE ALERTS',
          trailing: Text('Limits refresh in 12 days', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
          child: const _TokenThresholdsBlock(),
        ),
        const SizedBox(height: 24),
        _SettingsSection(
          title: 'FINANCIALS',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsNotificationRow(
                icon: Icons.receipt_long,
                title: 'Invoices & Receipts',
                subtitle: 'Monthly billing statements',
                value: settings.invoicesReceipts ?? true,
                onChanged: notifier.setInvoicesReceipts,
              ),
              const SizedBox(height: 4),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 4),
              _SettingsNotificationRow(
                icon: Icons.credit_card_off,
                title: 'Payment Issues',
                subtitle: 'Critical alerts for failed transactions',
                value: settings.paymentIssues ?? false,
                onChanged: notifier.setPaymentIssues,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRightColumn extends ConsumerWidget {
  const _SettingsRightColumn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(chatSettingsProvider);
    final notifier = ref.read(chatSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsSection(
          title: 'GROWTH & NEWS',
          child: _SettingsNotificationRow(
            icon: Icons.campaign,
            title: 'AI Trends & News',
            subtitle: 'Weekly digest and exclusive offers',
            value: settings.aiTrendsNews ?? false,
            onChanged: notifier.setAiTrendsNews,
          ),
        ),
        const SizedBox(height: 24),
        _SettingsSection(
          title: 'APPEARANCE',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsSwitchRow(title: 'Dark Mode', value: settings.darkMode, onChanged: notifier.setDarkMode),
              const SizedBox(height: 4),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 4),
              _SettingsFontSizeRow(value: settings.fontSize, onChanged: notifier.setFontSize),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SettingsSection(
          title: 'CHAT BEHAVIOR',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsSwitchRow(title: 'Enter to Send', subtitle: 'Press enter key to send message', value: settings.enterToSend, onChanged: notifier.setEnterToSend),
              const SizedBox(height: 4),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 4),
              _SettingsSwitchRow(title: 'Show Timestamps', subtitle: 'Display time for each bubble', value: settings.showTimestamps, onChanged: notifier.setShowTimestamps),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SettingsSection(
          title: 'VOICE & AUDIO',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsSwitchRow(title: 'Read Responses Aloud', subtitle: 'Automatic text-to-speech', value: settings.readResponsesAloud, onChanged: notifier.setReadResponsesAloud),
              const SizedBox(height: 4),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 4),
              _SettingsVoiceModelRow(settings: settings),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SettingsSection(
          title: 'MODEL PREFERENCES',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsSystemPromptRow(value: settings.systemPrompt, onChanged: notifier.setSystemPrompt),
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 12),
              _SettingsTemperatureRow(value: settings.temperature, onChanged: notifier.setTemperature),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6), letterSpacing: 0.8),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _DesktopSettingsDesign.cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _SubscriptionBlock extends StatelessWidget {
  const _SubscriptionBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: _DesktopSettingsDesign.accentBlue, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PlanStatusText(PlanText.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  PlanStatusText(PlanText.detail, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: _DesktopSettingsDesign.accentBlue.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(20)),
              child: const PlanStatusText(PlanText.badge, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RevenueCatSubscriptionScreen())),
            icon: const Icon(Icons.calendar_today, size: 18),
            label: const PlanStatusText(PlanText.actionLabel),
            style: FilledButton.styleFrom(backgroundColor: _DesktopSettingsDesign.accentBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
      ],
    );
  }
}

class _SettingsNotificationRow extends StatelessWidget {
  const _SettingsNotificationRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Icon(icon, color: _DesktopSettingsDesign.accentBlue, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _TokenThresholdsBlock extends ConsumerWidget {
  const _TokenThresholdsBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(chatSettingsProvider);
    final notifier = ref.read(chatSettingsProvider.notifier);
    final active = settings.tokenThresholds ?? const {80, 100};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: Icon(Icons.speed, color: _DesktopSettingsDesign.accentBlue, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Token Thresholds', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('Notify when reaching usage limits', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [80, 90, 100].map((t) {
            final isActive = active.contains(t);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Material(
                  color: isActive ? _DesktopSettingsDesign.accentBlue : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => notifier.toggleTokenThreshold(t),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          Text('$t%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(
                            isActive ? 'ACTIVE' : 'DISABLED',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isActive ? Colors.white : Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({required this.title, this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
              if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)))],
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _SettingsFontSizeRow extends StatelessWidget {
  const _SettingsFontSizeRow({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: const Icon(Icons.text_fields, color: _DesktopSettingsDesign.accentBlue, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(activeTrackColor: _DesktopSettingsDesign.accentBlue),
            child: Slider(value: value, min: 12, max: 24, divisions: 12, onChanged: onChanged),
          ),
        ),
        const SizedBox(width: 12),
        Text('${value.toInt()}px', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8))),
      ],
    );
  }
}

class _SettingsVoiceModelRow extends ConsumerWidget {
  const _SettingsVoiceModelRow({required this.settings});

  final ChatSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _showVoicePicker(context, ref),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Voice Model', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
              ],
            ),
          ),
          Text(settings.aiVoiceModel, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7))),
          const SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 22),
        ],
      ),
    );
  }

  void _showVoicePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _DesktopSettingsDesign.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('Nova (Female, Professional)'), onTap: () { ref.read(chatSettingsProvider.notifier).setAiVoiceModel('Nova (Female, Professional)'); Navigator.pop(ctx); }),
            ListTile(title: const Text('Alloy (Male, Neutral)'), onTap: () { ref.read(chatSettingsProvider.notifier).setAiVoiceModel('Alloy (Male, Neutral)'); Navigator.pop(ctx); }),
            ListTile(title: const Text('Echo (Male, Warm)'), onTap: () { ref.read(chatSettingsProvider.notifier).setAiVoiceModel('Echo (Male, Warm)'); Navigator.pop(ctx); }),
          ],
        ),
      ),
    );
  }
}

class _SettingsSystemPromptRow extends StatelessWidget {
  const _SettingsSystemPromptRow({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('System Prompt', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
            const SizedBox(width: 6),
            Icon(Icons.info_outline, size: 16, color: Colors.white.withValues(alpha: 0.5)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          maxLines: 4,
          initialValue: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'You are a helpful assistant that provides concise and accurate answers...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(14),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ],
    );
  }
}

class _SettingsTemperatureRow extends StatelessWidget {
  const _SettingsTemperatureRow({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Temperature', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
        const SizedBox(height: 4),
        Text('Controls randomness & creativity', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(activeTrackColor: _DesktopSettingsDesign.accentBlue),
          child: Slider(value: value, min: 0, max: 1, onChanged: onChanged),
        ),
      ],
    );
  }
}

class _DesktopSettingsLayout extends ConsumerWidget {
  const _DesktopSettingsLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(chatSettingsProvider);
    final notifier = ref.read(chatSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: _DesktopSettingsDesign.mainBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 28),
            _DesktopProfileCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ProfileManagementScreen()),
              ),
            ),
            const SizedBox(height: 24),
            const _DesktopSubscriptionCard(),
            const SizedBox(height: 24),
            const _DesktopNotificationSection(),
            const SizedBox(height: 24),
            _DesktopSectionCard(
              title: 'APPEARANCE',
              children: [
                _DesktopSettingsRow(
                  title: 'Dark Mode',
                  trailing: Switch(
                    value: settings.darkMode,
                    onChanged: (v) => notifier.setDarkMode(v),
                  ),
                ),
                _DesktopSettingsRow(
                  title: 'Font size',
                  trailing: Text('${settings.fontSize.toInt()}px', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7))),
                  customTrailing: SliderTheme(
                    data: SliderTheme.of(context).copyWith(activeTrackColor: _DesktopSettingsDesign.accentBlue, inactiveTrackColor: _DesktopSettingsDesign.cardBg),
                    child: Slider(value: settings.fontSize, min: 12, max: 24, divisions: 12, onChanged: (v) => notifier.setFontSize(v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _DesktopSectionCard(
              title: 'CHAT BEHAVIOR',
              children: [
                _DesktopSettingsRow(title: 'Enter to Send', subtitle: 'Press enter key to send message', trailing: Switch(value: settings.enterToSend, onChanged: (v) => notifier.setEnterToSend(v))),
                _DesktopSettingsRow(title: 'Show Timestamps', subtitle: 'Display time for each bubble', trailing: Switch(value: settings.showTimestamps, onChanged: (v) => notifier.setShowTimestamps(v))),
              ],
            ),
            const SizedBox(height: 24),
            _DesktopSectionCard(
              title: 'VOICE & AUDIO',
              children: [
                _DesktopSettingsRow(title: 'Read Responses Aloud', subtitle: 'Automatic text-to-speech', trailing: Switch(value: settings.readResponsesAloud, onChanged: (v) => notifier.setReadResponsesAloud(v))),
                _DesktopSettingsRow(
                  title: 'AI Voice Model',
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text(settings.aiVoiceModel, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7))), const SizedBox(width: 4), Icon(Icons.keyboard_arrow_down, color: Colors.white70)]),
                  onTap: () => _showVoicePicker(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _DesktopSectionCard(
              title: 'MODEL PREFERENCES',
              children: [
                _DesktopSystemPromptRow(
                  value: settings.systemPrompt,
                  onChanged: (v) => notifier.setSystemPrompt(v),
                ),
                _DesktopSettingsRow(
                  title: 'Temperature',
                  subtitle: 'Controls randomness & creativity',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _DesktopSettingsDesign.accentBlue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text(settings.temperature.toStringAsFixed(1), style: const TextStyle(color: _DesktopSettingsDesign.accentBlue, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  customTrailing: SliderTheme(
                    data: SliderTheme.of(context).copyWith(activeTrackColor: _DesktopSettingsDesign.accentBlue),
                    child: Slider(value: settings.temperature, min: 0, max: 1, onChanged: (v) => notifier.setTemperature(v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _DesktopSectionCard(
              title: 'DATA MANAGEMENT',
              children: [
                _DesktopSettingsRow(title: 'Export Chat History', leading: Icon(Icons.download, color: Colors.white70), trailing: Icon(Icons.chevron_right, color: Colors.white70), onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export chat history')))),
                _DesktopSettingsRow(
                  title: 'Clear All Conversations',
                  titleColor: Colors.red,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Icon(Icons.close, size: 20, color: Colors.white),
                  ),
                  onTap: () => _showClearDialog(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showVoicePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _DesktopSettingsDesign.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('Nova (Female, Professional)'), onTap: () { ref.read(chatSettingsProvider.notifier).setAiVoiceModel('Nova (Female, Professional)'); Navigator.pop(ctx); }),
            ListTile(title: const Text('Alloy (Male, Neutral)'), onTap: () { ref.read(chatSettingsProvider.notifier).setAiVoiceModel('Alloy (Male, Neutral)'); Navigator.pop(ctx); }),
            ListTile(title: const Text('Echo (Male, Warm)'), onTap: () { ref.read(chatSettingsProvider.notifier).setAiVoiceModel('Echo (Male, Warm)'); Navigator.pop(ctx); }),
          ],
        ),
      ),
    );
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _DesktopSettingsDesign.cardBg,
        title: const Text('Clear All Conversations?', style: TextStyle(color: Colors.white)),
        content: const Text('This will permanently delete all your chat history. This action cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () { ref.read(chatSettingsProvider.notifier).clearAllConversations(); Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All conversations cleared'))); }, child: const Text('Clear', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

class _DesktopProfileCard extends StatelessWidget {
  const _DesktopProfileCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _DesktopSettingsDesign.cardBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: _DesktopSettingsDesign.accentBlue.withValues(alpha: 0.3),
                child: const Icon(Icons.person, size: 36, color: _DesktopSettingsDesign.accentBlue),
              ),
              const SizedBox(width: 20),
              const Expanded(child: Text(notSignedInLabel, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white))),
              Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopSubscriptionCard extends StatelessWidget {
  const _DesktopSubscriptionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _DesktopSettingsDesign.cardBg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: _DesktopSettingsDesign.accentBlue, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PlanStatusText(PlanText.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    PlanStatusText(PlanText.detail, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _DesktopSettingsDesign.accentBlue, borderRadius: BorderRadius.circular(20)),
                child: const PlanStatusText(PlanText.badge, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RevenueCatSubscriptionScreen())),
              icon: const Icon(Icons.credit_card, size: 20),
              label: const PlanStatusText(PlanText.actionLabel),
              style: FilledButton.styleFrom(backgroundColor: _DesktopSettingsDesign.accentBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopNotificationSection extends ConsumerWidget {
  const _DesktopNotificationSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(chatSettingsProvider);
    final notifier = ref.read(chatSettingsProvider.notifier);
    return _DesktopSectionCard(
      title: 'NOTIFICATIONS',
      children: [
        _DesktopSettingsRow(
          title: 'Push Notifications',
          subtitle: 'Main switch for all app alerts',
          trailing: Switch(value: settings.pushNotifications ?? true, onChanged: notifier.setPushNotifications),
        ),
        _DesktopSettingsRow(
          title: 'New AI Models',
          subtitle: 'Alerts for GPT-5, Claude 4, etc.',
          trailing: Switch(value: settings.newAiModels ?? true, onChanged: notifier.setNewAiModels),
        ),
        _DesktopSettingsRow(
          title: 'Feature Updates',
          subtitle: 'New tools and UI enhancements',
          trailing: Switch(value: settings.featureUpdates ?? false, onChanged: notifier.setFeatureUpdates),
        ),
        _DesktopSettingsRow(
          title: 'Invoices & Receipts',
          subtitle: 'Monthly billing statements',
          trailing: Switch(value: settings.invoicesReceipts ?? true, onChanged: notifier.setInvoicesReceipts),
        ),
        _DesktopSettingsRow(
          title: 'Payment Issues',
          subtitle: 'Critical alerts for failed transactions',
          trailing: Switch(value: settings.paymentIssues ?? false, onChanged: notifier.setPaymentIssues),
        ),
        _DesktopSettingsRow(
          title: 'AI Trends & News',
          subtitle: 'Weekly digest and exclusive offers',
          trailing: Switch(value: settings.aiTrendsNews ?? false, onChanged: notifier.setAiTrendsNews),
        ),
        _DesktopTokenThresholds(activeThresholds: settings.tokenThresholds ?? const {80, 100}, onToggle: notifier.toggleTokenThreshold),
      ],
    );
  }
}

class _DesktopTokenThresholds extends StatelessWidget {
  const _DesktopTokenThresholds({required this.activeThresholds, required this.onToggle});

  final Set<int> activeThresholds;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Token Thresholds', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Notify when reaching usage limits', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
          const SizedBox(height: 12),
          Row(
            children: [80, 90, 100].map((t) {
              final isActive = activeThresholds.contains(t);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => onToggle(t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isActive ? _DesktopSettingsDesign.accentBlue.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text('$t%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(isActive ? 'ACTIVE' : 'DISABLED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isActive ? _DesktopSettingsDesign.accentBlue : Colors.white54)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _DesktopSectionCard extends StatelessWidget {
  const _DesktopSectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.6), letterSpacing: 0.8)),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _DesktopSettingsDesign.cardBg, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopSettingsRow extends StatelessWidget {
  const _DesktopSettingsRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.customTrailing,
    this.titleColor,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget? customTrailing;
  final Color? titleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: titleColor ?? Colors.white)),
                  if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)))],
                ],
              ),
            ),
            if (trailing != null && customTrailing == null) trailing!,
          ],
        ),
        if (customTrailing != null) ...[const SizedBox(height: 8), customTrailing!],
      ],
    );

    if (onTap != null) {
      return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: content));
    }
    return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: content);
  }
}

class _DesktopSystemPromptRow extends StatelessWidget {
  const _DesktopSystemPromptRow({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('System Prompt', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
              const SizedBox(width: 6),
              Icon(Icons.info_outline, size: 16, color: Colors.white.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            maxLines: 4,
            initialValue: value,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: 'You are a helpful assistant that provides concise and accurate answers...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(14),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _NotificationSections extends ConsumerWidget {
  const _NotificationSections();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(chatSettingsProvider);
    final notifier = ref.read(chatSettingsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NotificationSectionHeader(title: 'GLOBAL CONTROLS'),
          _NotificationCard(
            children: [
              _NotificationTile(
                icon: Icons.notifications,
                title: 'Push Notifications',
                subtitle: 'Main switch for all app alerts',
                value: settings.pushNotifications ?? true,
                onChanged: notifier.setPushNotifications,
              ),
            ],
          ),
          _NotificationSectionHeader(title: 'AI INSIGHTS'),
          _NotificationCard(
            children: [
              _NotificationTile(
                icon: Icons.refresh,
                title: 'New AI Models',
                subtitle: 'Alerts for GPT-5, Claude 4, etc.',
                value: settings.newAiModels ?? true,
                onChanged: notifier.setNewAiModels,
              ),
              _NotificationTile(
                icon: Icons.auto_awesome,
                title: 'Feature Updates',
                subtitle: 'New tools and UI enhancements',
                value: settings.featureUpdates ?? false,
                onChanged: notifier.setFeatureUpdates,
              ),
            ],
          ),
          _NotificationSectionHeader(
            title: 'USAGE ALERTS',
            trailing: Text(
              'Limits refresh in 12 days',
              style: TextStyle(
                fontSize: 12,
                color: CognitiveAIBotTheme.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ),
          _TokenThresholdsCard(
            activeThresholds: settings.tokenThresholds ?? const {80, 100},
            onToggle: notifier.toggleTokenThreshold,
          ),
          _NotificationSectionHeader(title: 'FINANCIALS'),
          _NotificationCard(
            children: [
              _NotificationTile(
                icon: Icons.receipt_long,
                title: 'Invoices & Receipts',
                subtitle: 'Monthly billing statements',
                value: settings.invoicesReceipts ?? true,
                onChanged: notifier.setInvoicesReceipts,
              ),
              _NotificationTile(
                icon: Icons.credit_card_off,
                title: 'Payment Issues',
                subtitle: 'Critical alerts for failed transactions',
                value: settings.paymentIssues ?? false,
                onChanged: notifier.setPaymentIssues,
              ),
            ],
          ),
          _NotificationSectionHeader(title: 'GROWTH & NEWS'),
          _NotificationCard(
            children: [
              _NotificationTile(
                icon: Icons.campaign,
                title: 'AI Trends & News',
                subtitle: 'Weekly digest and exclusive offers',
                value: settings.aiTrendsNews ?? false,
                onChanged: notifier.setAiTrendsNews,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationSectionHeader extends StatelessWidget {
  const _NotificationSectionHeader({
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CognitiveAIBotTheme.primaryBlue,
              letterSpacing: 1,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CognitiveAIBotTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: CognitiveAIBotTheme.cardBackgroundAlt),
              ),
          ],
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: CognitiveAIBotTheme.cardBackgroundAlt.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: CognitiveAIBotTheme.primaryBlue, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: CognitiveAIBotTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: CognitiveAIBotTheme.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
        SwitchTheme(
          data: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return CognitiveAIBotTheme.primaryBlue;
              }
              return CognitiveAIBotTheme.textSecondary;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.5);
              }
              return CognitiveAIBotTheme.cardBackgroundAlt;
            }),
          ),
          child: Switch(
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _TokenThresholdsCard extends StatelessWidget {
  const _TokenThresholdsCard({
    required this.activeThresholds,
    required this.onToggle,
  });

  final Set<int> activeThresholds;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CognitiveAIBotTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CognitiveAIBotTheme.cardBackgroundAlt.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.speed,
                  color: CognitiveAIBotTheme.primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Token Thresholds',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: CognitiveAIBotTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Notify when reaching usage limits',
                      style: TextStyle(
                        fontSize: 13,
                        color: CognitiveAIBotTheme.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [80, 90, 100].map((threshold) {
              final isActive = activeThresholds.contains(threshold);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => onToggle(threshold),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.3)
                            : CognitiveAIBotTheme.cardBackgroundAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$threshold%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: CognitiveAIBotTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isActive ? 'ACTIVE' : 'DISABLED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? CognitiveAIBotTheme.primaryBlue
                                  : CognitiveAIBotTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionSection extends StatelessWidget {
  const _SubscriptionSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Center(
              child: Text(
                'SUBSCRIPTION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: CognitiveAIBotTheme.textSecondary,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CognitiveAIBotTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
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
                        color: CognitiveAIBotTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.auto_awesome,
                        color: CognitiveAIBotTheme.textPrimary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const PlanStatusText(
                            PlanText.title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: CognitiveAIBotTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          PlanStatusText(
                            PlanText.detail,
                            style: TextStyle(
                              fontSize: 13,
                              color: CognitiveAIBotTheme.textSecondary.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: CognitiveAIBotTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const PlanStatusText(
                        PlanText.badge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: CognitiveAIBotTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RevenueCatSubscriptionScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.credit_card, size: 20),
                    label: const PlanStatusText(PlanText.actionLabel),
                    style: FilledButton.styleFrom(
                      backgroundColor: CognitiveAIBotTheme.primaryBlue,
                      foregroundColor: CognitiveAIBotTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.3),
              child: const Icon(
                Icons.person,
                size: 40,
                color: CognitiveAIBotTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              notSignedInLabel,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: CognitiveAIBotTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: CognitiveAIBotTheme.textSecondary,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.customTrailing,
    this.titleColor,
    this.onTap,
  });

  final String title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget? customTrailing;
  final Color? titleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: titleColor ?? CognitiveAIBotTheme.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        subtitle!,
                      ],
                    ],
                  ),
                ),
                ...(trailing != null && customTrailing == null ? [trailing!] : []),
              ],
            ),
            ...?(customTrailing != null ? [customTrailing!] : null),
          ],
        ),
      ),
    );
  }
}
