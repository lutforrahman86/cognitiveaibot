import 'package:flutter/material.dart';

import '../../core/theme/cognitive_aibot_theme.dart';
import 'revenuecat_subscription_screen.dart';
import '../widgets/plan_status_text.dart';

/// Profile Management screen - account info, subscription, connected services
class ProfileManagementScreen extends StatefulWidget {
  const ProfileManagementScreen({super.key});

  @override
  State<ProfileManagementScreen> createState() =>
      _ProfileManagementScreenState();
}

class _ProfileManagementScreenState extends State<ProfileManagementScreen> {
  bool _googleConnected = true;
  bool _githubConnected = false;
  bool _appleConnected = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CognitiveAIBotTheme.background,
      appBar: AppBar(
        backgroundColor: CognitiveAIBotTheme.background,
        foregroundColor: CognitiveAIBotTheme.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.close, color: CognitiveAIBotTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Profile Management',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: CognitiveAIBotTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: CognitiveAIBotTheme.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 32),
          _buildAccountInformation(),
          const SizedBox(height: 24),
          _buildSubscriptionSection(),
          const SizedBox(height: 24),
          _buildConnectedServices(),
          const SizedBox(height: 24),
          _buildDangerZone(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Change profile photo')),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: CognitiveAIBotTheme.primaryBlue.withValues(alpha: 0.3),
                child: const Icon(
                  Icons.person,
                  size: 56,
                  color: CognitiveAIBotTheme.primaryBlue,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: CognitiveAIBotTheme.primaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: CognitiveAIBotTheme.background,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.edit,
                    size: 16,
                    color: CognitiveAIBotTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'John Doe',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: CognitiveAIBotTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'john.doe@aihub.io',
              style: TextStyle(
                fontSize: 15,
                color: CognitiveAIBotTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.verified,
              size: 18,
              color: CognitiveAIBotTheme.primaryBlue,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountInformation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(title: 'ACCOUNT INFORMATION'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: CognitiveAIBotTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _AccountInfoTile(
                icon: Icons.person_outline,
                label: 'Full Name',
                value: 'John Doe',
                onTap: () => _showSnackBar('Edit Full Name'),
            ),
              _Divider(),
              _AccountInfoTile(
                icon: Icons.email_outlined,
                label: 'Email Address',
                value: 'john.doe@aihub.io',
                onTap: () => _showSnackBar('Edit Email'),
            ),
              _Divider(),
              _AccountInfoTile(
                icon: Icons.lock_outline,
                label: 'Password',
                value: '••••••••••',
                onTap: () => _showSnackBar('Change Password'),
            ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(title: 'SUBSCRIPTION'),
        const SizedBox(height: 12),
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
    );
  }

  Widget _buildConnectedServices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(title: 'CONNECTED SERVICES'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: CognitiveAIBotTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _ConnectedServiceTile(
                icon: Icons.g_mobiledata,
                serviceName: 'Google',
                status: 'Connected',
                isConnected: _googleConnected,
                onToggle: (v) => setState(() => _googleConnected = v),
              ),
              _Divider(),
              _ConnectedServiceTile(
                icon: Icons.code,
                serviceName: 'GitHub',
                status: 'Not connected',
                isConnected: _githubConnected,
                onToggle: (v) => setState(() => _githubConnected = v),
              ),
              _Divider(),
              _ConnectedServiceTile(
                icon: Icons.apple,
                serviceName: 'Apple ID',
                status: 'Connected',
                isConnected: _appleConnected,
                onToggle: (v) => setState(() => _appleConnected = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'DANGER ZONE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.red,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.5), width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delete Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CognitiveAIBotTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Permanently delete your profile and all data.',
                      style: TextStyle(
                        fontSize: 13,
                        color: CognitiveAIBotTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: () => _showDeleteConfirmDialog(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CognitiveAIBotTheme.cardBackground,
        title: const Text(
          'Delete Account?',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          'This action cannot be undone. All your data will be permanently deleted.',
          style: TextStyle(color: CognitiveAIBotTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showSnackBar('Account deletion requested');
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
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

class _AccountInfoTile extends StatelessWidget {
  const _AccountInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: CognitiveAIBotTheme.textSecondary, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: CognitiveAIBotTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: CognitiveAIBotTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: CognitiveAIBotTheme.textSecondary, size: 24),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: CognitiveAIBotTheme.cardBackgroundAlt),
    );
  }
}

class _ConnectedServiceTile extends StatelessWidget {
  const _ConnectedServiceTile({
    required this.icon,
    required this.serviceName,
    required this.status,
    required this.isConnected,
    required this.onToggle,
  });

  final IconData icon;
  final String serviceName;
  final String status;
  final bool isConnected;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: CognitiveAIBotTheme.cardBackgroundAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: CognitiveAIBotTheme.textSecondary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CognitiveAIBotTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 13,
                    color: isConnected ? CognitiveAIBotTheme.positiveGreen : CognitiveAIBotTheme.textSecondary,
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
              value: isConnected,
              onChanged: onToggle,
            ),
          ),
        ],
      ),
    );
  }
}
