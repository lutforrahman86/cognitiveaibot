import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cognitive_aibot_theme.dart';
import '../../core/utils/platform_info.dart';
import '../../domain/entities/conversation.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_providers.dart';
import '../providers/chat_session_provider.dart';
import '../widgets/email_verification_banner.dart';
import '../widgets/plan_status_text.dart';
import 'chat_history_screen.dart';
import 'chat_screen.dart';
import 'chat_settings_screen.dart';
import 'select_ai_model_screen.dart';
import 'usage_dashboard_screen.dart';

/// Desktop root sidebar design tokens
class _DesktopRootSidebarDesign {
  _DesktopRootSidebarDesign._();
  static const sidebarBg = Color(0xFF181818);
  static const accentBlue = Color(0xFF2196F3);
  static const navActiveBg = Color(0xFF1E3A5F);
  static const logoutRed = Color(0xFFE53935);
}

/// Main app shell — sidebar on Mac/Windows/Linux, bottom nav on mobile.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, this.desktop});

  /// Defaults to the platform. Tests set it.
  final bool? desktop;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // The confirmation link is usually opened in another app: recheck the
    // account when the app comes back to the front.
    _lifecycle = AppLifecycleListener(onResume: () {
      if (ref.read(currentUserProvider)?.emailVerified == false) {
        ref.read(authControllerProvider.notifier).refreshUser();
      }
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  bool get _desktop => widget.desktop ?? isDesktopPlatform;

  static const _tabs = [
    _NavItem(icon: Icons.home, label: 'Home'),
    _NavItem(icon: Icons.history, label: 'History'),
    _NavItem(icon: Icons.view_in_ar, label: 'Models'),
    _NavItem(icon: Icons.show_chart, label: 'Usage'),
    _NavItem(icon: Icons.settings, label: 'Settings'),
  ];

  void _openChat({Conversation? conversation}) {
    if (_desktop) {
      if (conversation != null) {
        ref.read(chatSessionProvider.notifier).open(conversation, models: ref.read(modelsProvider).valueOrNull ?? const []);
      }
      setState(() => _currentIndex = 0);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ChatScreen(conversation: conversation)),
      );
    }
  }

  void _newChat() {
    if (_desktop) ref.read(chatSessionProvider.notifier).startNew();
    _openChat();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _desktop ? const ChatScreen(useDesktopLayout: true) : _HomeTab(onStartChat: _newChat),
      ChatHistoryScreen(
        useDesktopLayout: _desktop,
        onOpenConversation: (c) => _openChat(conversation: c),
        onNewChat: _newChat,
      ),
      SelectAIModelScreen(onModelChosen: _desktop ? null : (_) => setState(() => _currentIndex = 0)),
      UsageDashboardScreen(useDesktopLayout: _desktop),
      ChatSettingsScreen(useDesktopLayout: _desktop),
    ];

    final stack = IndexedStack(index: _currentIndex, children: pages);
    final showBanner = ref.watch(showVerificationBannerProvider);

    if (_desktop) {
      return Scaffold(
        backgroundColor: CognitiveAIBotTheme.background,
        body: Row(
          children: [
            _DesktopRootSidebar(
              currentIndex: _currentIndex,
              onIndexChanged: (i) => setState(() => _currentIndex = i),
            ),
            Expanded(
              child: Column(
                children: [
                  if (showBanner) const EmailVerificationBanner(),
                  Expanded(key: const ValueKey('pages'), child: stack),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: CognitiveAIBotTheme.background,
      // The column keeps the pages' state when the banner comes or goes.
      body: Column(
        children: [
          if (showBanner) const SafeArea(bottom: false, child: EmailVerificationBanner()),
          Expanded(
            key: const ValueKey('pages'),
            // Below the banner, the pages needn't keep clear of the status bar.
            // (The Builder reads the body's MediaQuery, which the Scaffold
            // has already adjusted for the keyboard and the navigation bar.)
            child: Builder(
              builder: (context) => MediaQuery.removePadding(context: context, removeTop: showBanner, child: stack),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: CognitiveAIBotTheme.surface,
        indicatorColor: CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.2),
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: _tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon, color: CognitiveAIBotTheme.textSecondary),
                  selectedIcon: Icon(t.icon, color: CognitiveAIBotTheme.primaryBlue),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}

/// Root sidebar for desktop: account, plan, credits, navigation, Log Out.
class _DesktopRootSidebar extends ConsumerWidget {
  const _DesktopRootSidebar({required this.currentIndex, required this.onIndexChanged});

  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  static const _navItems = [
    (Icons.chat_bubble_outline, 'Chat', 0),
    (Icons.history, 'History', 1),
    (Icons.view_in_ar, 'Models', 2),
    (Icons.show_chart, 'Usage', 3),
    (Icons.settings, 'Settings', 4),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Container(
      width: 240,
      color: _DesktopRootSidebarDesign.sidebarBg,
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
                  backgroundColor: _DesktopRootSidebarDesign.accentBlue.withValues(alpha: 0.4),
                  child: Text(
                    (user?.displayName.isNotEmpty ?? false) ? user!.displayName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.displayName ?? '',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                PlanStatusText(style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
                const SizedBox(height: 2),
                CreditsText(style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ..._navItems.map((item) {
            final (icon, label, index) = item;
            final selected = currentIndex == index;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Material(
                color: selected ? _DesktopRootSidebarDesign.navActiveBg : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => onIndexChanged(index),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(icon, size: 22, color: selected ? Colors.white : Colors.white70),
                        const SizedBox(width: 14),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            color: selected ? Colors.white : Colors.white70,
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
                onTap: () => confirmSignOut(context, ref),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 22, color: _DesktopRootSidebarDesign.logoutRed),
                      SizedBox(width: 14),
                      Text(
                        'Log Out',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _DesktopRootSidebarDesign.logoutRed),
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

class _NavItem {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab({required this.onStartChat});

  final VoidCallback onStartChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      backgroundColor: CognitiveAIBotTheme.background,
      body: SafeArea(
        child: Center(
          // Scrolls when space is short, e.g. while the keyboard from the
          // sign-in form is still closing, or under the email banner.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.smart_toy, size: 80, color: CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.5)),
                const SizedBox(height: 24),
                Text(
                  user == null ? 'CognitiveAI Bot' : 'Hi, ${user.displayName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: CognitiveAIBotTheme.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Start a conversation with AI',
                  style: TextStyle(fontSize: 14, color: CognitiveAIBotTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const CreditsText(
                  style: TextStyle(fontSize: 14, color: CognitiveAIBotTheme.textSecondary),
                  suffix: ' credits available',
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: onStartChat,
                  icon: const Icon(Icons.chat),
                  label: const Text('Start Chat'),
                  style: FilledButton.styleFrom(
                    backgroundColor: CognitiveAIBotTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: CognitiveAIBotTheme.cardBackground,
      title: const Text('Log out?'),
      content: const Text('You can sign in again with your email and password.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    ),
  );
  if (ok == true) await ref.read(authControllerProvider.notifier).signOut();
}
