import 'dart:async';
import 'package:flutter/material.dart';
import 'package:telegramflutter/services/telegram_service.dart';
import 'package:telegramflutter/theme/colors.dart';
import 'package:telegramflutter/pages/blocked_users_page.dart';
import 'package:telegramflutter/pages/two_factor_auth_page.dart';

/// Privacy and Security settings page
class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  final _telegramService = TelegramService();
  StreamSubscription? _passwordStateSub;
  bool _has2FA = false;

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
    _telegramService.getPasswordState();
  }

  @override
  void dispose() {
    _passwordStateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: greyColor,
        title: const Text(
          'Privacy and Security',
          style: TextStyle(color: white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Security section
            _buildSectionHeader('SECURITY'),
            _buildSettingItem(
              icon: Icons.lock,
              color: Colors.green,
              title: 'Two-Step Verification',
              subtitle: _has2FA ? 'On' : 'Off',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TwoFactorAuthPage()),
              ).then((_) => _telegramService.getPasswordState()),
            ),
            _buildSettingItem(
              icon: Icons.devices,
              color: Colors.orange,
              title: 'Active Sessions',
              subtitle: 'Control your sessions on other devices',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Active sessions coming soon')),
                );
              },
            ),
            _buildSettingItem(
              icon: Icons.timer,
              color: Colors.purple,
              title: 'Auto-Delete Messages',
              subtitle: 'Off',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Auto-delete coming soon')),
                );
              },
            ),

            const SizedBox(height: 24),

            // Privacy section
            _buildSectionHeader('PRIVACY'),
            _buildSettingItem(
              icon: Icons.phone,
              color: Colors.blue,
              title: 'Phone Number',
              subtitle: 'Who can see my phone number',
              onTap: () {},
            ),
            _buildSettingItem(
              icon: Icons.access_time,
              color: Colors.teal,
              title: 'Last Seen & Online',
              subtitle: 'Who can see my last seen time',
              onTap: () => _showLastSeenOptions(),
            ),
            _buildSettingItem(
              icon: Icons.photo,
              color: Colors.pink,
              title: 'Profile Photos',
              subtitle: 'Who can see my profile photos',
              onTap: () {},
            ),
            _buildSettingItem(
              icon: Icons.call,
              color: Colors.green,
              title: 'Calls',
              subtitle: 'Who can call me',
              onTap: () {},
            ),
            _buildSettingItem(
              icon: Icons.forward,
              color: Colors.amber,
              title: 'Forwarded Messages',
              subtitle: 'Who can add a link to my account',
              onTap: () {},
            ),
            _buildSettingItem(
              icon: Icons.group_add,
              color: Colors.cyan,
              title: 'Groups & Channels',
              subtitle: 'Who can add me to groups',
              onTap: () {},
            ),

            const SizedBox(height: 24),

            // Blocked users
            _buildSectionHeader('BLOCKED USERS'),
            _buildSettingItem(
              icon: Icons.block,
              color: Colors.red,
              title: 'Blocked Users',
              subtitle: 'Manage blocked users',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlockedUsersPage()),
              ),
            ),

            const SizedBox(height: 24),

            // Data privacy
            _buildSectionHeader('DATA SETTINGS'),
            _buildSettingItem(
              icon: Icons.delete_forever,
              color: Colors.red,
              title: 'Delete My Account',
              subtitle: 'If away for...',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account deletion settings coming soon'),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF37AEE2),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
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
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: const TextStyle(color: white, fontSize: 16)),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(color: white.withOpacity(0.5), fontSize: 13),
            )
          : null,
      trailing: Icon(Icons.chevron_right, color: white.withOpacity(0.3)),
    );
  }

  void _showLastSeenOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: greyColor,
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
                color: white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Last Seen & Online',
                style: TextStyle(
                  color: white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Who can see your last seen time:',
                style: TextStyle(color: white.withOpacity(0.6)),
              ),
            ),
            const SizedBox(height: 8),
            _buildRadioOption('Everybody', true),
            _buildRadioOption('My Contacts', false),
            _buildRadioOption('Nobody', false),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioOption(String label, bool selected) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: white)),
      trailing: selected
          ? const Icon(Icons.check_circle, color: Color(0xFF37AEE2))
          : Icon(Icons.circle_outlined, color: white.withOpacity(0.3)),
      onTap: () => Navigator.pop(context),
    );
  }
}
