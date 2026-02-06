import 'dart:async';
import 'package:flutter/material.dart';
import 'package:line_icons/line_icons.dart';
import 'package:telegramflutter/services/telegram_service.dart';
import 'package:telegramflutter/theme/colors.dart';
import 'package:telegramflutter/pages/blocked_users_page.dart';
import 'package:telegramflutter/pages/two_factor_auth_page.dart';
import 'package:telegramflutter/pages/active_sessions_page.dart';
import 'package:telegramflutter/pages/account_deletion_page.dart';

/// Privacy and Security settings page
class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  final _telegramService = TelegramService();
  StreamSubscription? _passwordStateSub;
  StreamSubscription? _privacySub;
  bool _has2FA = false;
  Map<String, String> _privacySettings = {};

  @override
  void initState() {
    super.initState();
    _passwordStateSub = _telegramService.passwordStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _has2FA = state['has_password'] as bool? ?? false;
        });
      }
    });
    _privacySub = _telegramService.privacySettingsStream.listen((settings) {
      if (mounted) {
        setState(() => _privacySettings = Map.from(settings));
      }
    });
    _telegramService.getPasswordState();
    _telegramService.loadAllPrivacySettings();
  }

  @override
  void dispose() {
    _passwordStateSub?.cancel();
    _privacySub?.cancel();
    super.dispose();
  }

  String _privacyLabel(String? value) {
    switch (value) {
      case 'everybody':
        return 'Everybody';
      case 'contacts':
        return 'My Contacts';
      case 'nobody':
        return 'Nobody';
      default:
        return 'Loading...';
    }
  }

  void _showPrivacyPicker(String settingType, String title) {
    final current = _privacySettings[settingType] ?? 'contacts';
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: TextStyle(
                  color: context.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildPrivacyRadio('Everybody', 'everybody', current, settingType),
            _buildPrivacyRadio('My Contacts', 'contacts', current, settingType),
            _buildPrivacyRadio('Nobody', 'nobody', current, settingType),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyRadio(
    String label,
    String value,
    String current,
    String settingType,
  ) {
    final isSelected = current == value;
    return ListTile(
      title: Text(label, style: TextStyle(color: context.onSurface)),
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isSelected ? Colors.blue : context.onSurface.withOpacity(0.4),
      ),
      onTap: () {
        _telegramService.setPrivacySettingRules(settingType, value);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.appBarBg,
        title: Text(
          'Privacy and Security',
          style: TextStyle(color: context.onSurface),
        ),
        iconTheme: IconThemeData(color: context.onSurface),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // ─── Security Section ────────────────────────────────
            _buildSectionHeader('SECURITY'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSettingItem(
                    icon: LineIcons.lock,
                    color: Colors.green,
                    title: 'Two-Step Verification',
                    subtitle: _has2FA ? 'On' : 'Off',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TwoFactorAuthPage(),
                      ),
                    ).then((_) => _telegramService.getPasswordState()),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    icon: LineIcons.desktop,
                    color: Colors.orange,
                    title: 'Active Sessions',
                    subtitle: 'Control your sessions on other devices',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ActiveSessionsPage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ─── Privacy Section ─────────────────────────────────
            _buildSectionHeader('PRIVACY'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSettingItem(
                    icon: LineIcons.phone,
                    color: Colors.blue,
                    title: 'Phone Number',
                    subtitle: _privacyLabel(_privacySettings['phone']),
                    onTap: () => _showPrivacyPicker(
                      'phone',
                      'Who can see my phone number',
                    ),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    icon: LineIcons.clock,
                    color: Colors.teal,
                    title: 'Last Seen & Online',
                    subtitle: _privacyLabel(_privacySettings['lastSeen']),
                    onTap: () => _showPrivacyPicker(
                      'lastSeen',
                      'Who can see my last seen',
                    ),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    icon: LineIcons.userCircle,
                    color: Colors.pink,
                    title: 'Profile Photos',
                    subtitle: _privacyLabel(_privacySettings['profilePhoto']),
                    onTap: () => _showPrivacyPicker(
                      'profilePhoto',
                      'Who can see my profile photos',
                    ),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    icon: LineIcons.phoneVolume,
                    color: Colors.green,
                    title: 'Calls',
                    subtitle: _privacyLabel(_privacySettings['calls']),
                    onTap: () => _showPrivacyPicker('calls', 'Who can call me'),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    icon: LineIcons.share,
                    color: Colors.amber,
                    title: 'Forwarded Messages',
                    subtitle: _privacyLabel(_privacySettings['forwards']),
                    onTap: () => _showPrivacyPicker(
                      'forwards',
                      'Who can add a link to my account',
                    ),
                  ),
                  _buildDivider(),
                  _buildSettingItem(
                    icon: LineIcons.users,
                    color: Colors.cyan,
                    title: 'Groups & Channels',
                    subtitle: _privacyLabel(_privacySettings['groups']),
                    onTap: () => _showPrivacyPicker(
                      'groups',
                      'Who can add me to groups',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ─── Blocked Users ───────────────────────────────────
            _buildSectionHeader('BLOCKED USERS'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildSettingItem(
                icon: LineIcons.ban,
                color: Colors.red,
                title: 'Blocked Users',
                subtitle: 'Manage blocked users',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BlockedUsersPage()),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ─── Account ─────────────────────────────────────────
            _buildSectionHeader('ACCOUNT'),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildSettingItem(
                icon: LineIcons.exclamationTriangle,
                color: Colors.red,
                title: 'Delete My Account',
                subtitle: 'Account self-destruct settings',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AccountDeletionPage(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: context.onSurface.withOpacity(0.5),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 56,
      color: context.onSurface.withOpacity(0.1),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(color: context.onSurface, fontSize: 15),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: context.onSurface.withOpacity(0.5),
                fontSize: 13,
              ),
            )
          : null,
      trailing: Icon(
        LineIcons.angleRight,
        color: context.onSurface.withOpacity(0.3),
        size: 16,
      ),
    );
  }
}
