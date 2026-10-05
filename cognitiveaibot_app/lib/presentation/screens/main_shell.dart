import 'package:flutter/material.dart';

import '../../core/theme/cognitive_aibot_theme.dart';
import '../../core/utils/platform_info.dart';
import 'chat_screen.dart';
import 'chat_history_screen.dart';
import 'chat_settings_screen.dart';
import 'select_ai_model_screen.dart';
import 'usage_dashboard_screen.dart';
import '../widgets/plan_status_text.dart';

/// Desktop root sidebar design tokens — matches Settings screen design
class _DesktopRootSidebarDesign {
  _DesktopRootSidebarDesign._();
  static const sidebarBg = Color(0xFF181818);
  static const accentBlue = Color(0xFF2196F3);
  static const navActiveBg = Color(0xFF1E3A5F);
  static const logoutRed = Color(0xFFE53935);
}

/// Main app shell — sidebar on Mac/Windows/Linux, bottom nav on mobile
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _chatOpen = false;

  static const _tabs = [
    _NavItem(icon: Icons.home, label: 'Home'),
    _NavItem(icon: Icons.history, label: 'History'),
    _NavItem(icon: Icons.view_in_ar, label: 'Models'),
    _NavItem(icon: Icons.show_chart, label: 'Usage'),
    _NavItem(icon: Icons.settings, label: 'Settings'),
  ];

  void _openChatScreen() {
    if (isDesktopPlatform) {
      setState(() => _chatOpen = true);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const ChatScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDesktopPlatform;

    if (isDesktop) {
      return _DesktopLayout(
        currentIndex: _currentIndex,
        chatOpen: _chatOpen,
        onIndexChanged: (i) => setState(() => _currentIndex = i),
        onStartChat: _openChatScreen,
        onCloseChat: () => setState(() => _chatOpen = false),
      );
    }

    return Scaffold(
      backgroundColor: CognitiveAIBotTheme.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _buildTabChildren(),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: CognitiveAIBotTheme.surface,
        indicatorColor: CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.2),
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
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

  List<Widget> _buildTabChildren() => [
        _AIChatTab(onStartChat: _openChatScreen),
        const ChatHistoryScreen(),
        SelectAIModelScreen(
          onBack: () => setState(() => _currentIndex = 0),
        ),
        const UsageDashboardScreen(),
        ChatSettingsScreen(
          onBack: () => setState(() => _currentIndex = 0),
        ),
      ];
}

/// Sidebar layout for Mac/Windows/Linux — matches Usage Dashboard design
class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.currentIndex,
    required this.chatOpen,
    required this.onIndexChanged,
    required this.onStartChat,
    required this.onCloseChat,
  });

  final int currentIndex;
  final bool chatOpen;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onStartChat;
  final VoidCallback onCloseChat;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CognitiveAIBotTheme.background,
      body: chatOpen
          ? ChatScreen(
              useDesktopLayout: true,
              onGoHome: onCloseChat,
            )
          : Row(
              children: [
                _DesktopRootSidebar(
                  currentIndex: currentIndex,
                  onIndexChanged: onIndexChanged,
                ),
                Expanded(
                  child: IndexedStack(
                    index: currentIndex,
                    children: [
                      _AIChatTab(onStartChat: onStartChat),
                      ChatHistoryScreen(useDesktopLayout: isDesktopPlatform),
                      SelectAIModelScreen(
                        onBack: () => onIndexChanged(0),
                      ),
                      const UsageDashboardScreen(useDesktopLayout: true),
                      ChatSettingsScreen(
                        onBack: () => onIndexChanged(0),
                        useDesktopLayout: true,
                        contentOnly: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// Root sidebar for desktop — Settings-style design (account, plan, nav, Log Out)
class _DesktopRootSidebar extends StatelessWidget {
  const _DesktopRootSidebar({
    required this.currentIndex,
    required this.onIndexChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

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
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Log out'))),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 22, color: _DesktopRootSidebarDesign.logoutRed),
                      const SizedBox(width: 14),
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

class _AIChatTab extends StatelessWidget {
  const _AIChatTab({required this.onStartChat});

  final VoidCallback onStartChat;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CognitiveAIBotTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.smart_toy,
                size: 80,
                color: CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              const Text(
                'CognitiveAI Bot',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: CognitiveAIBotTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Start a conversation with AI',
                style: TextStyle(
                  fontSize: 14,
                  color: CognitiveAIBotTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onStartChat,
                icon: const Icon(Icons.chat),
                label: const Text('Start Chat'),
                style: FilledButton.styleFrom(
                  backgroundColor: CognitiveAIBotTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

