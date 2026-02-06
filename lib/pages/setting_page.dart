import 'dart:io';

import 'package:flutter/material.dart';
import 'package:telegramflutter/services/telegram_service.dart';
import 'package:telegramflutter/theme/colors.dart';
import 'package:telegramflutter/pages/login_page.dart';
import 'package:telegramflutter/pages/my_profile_page.dart';
import 'package:telegramflutter/pages/edit_profile_page.dart';
import 'package:telegramflutter/pages/privacy_security_page.dart';
import 'package:telegramflutter/pages/notification_settings_page.dart';
import 'package:telegramflutter/pages/active_sessions_page.dart';
import 'package:telegramflutter/pages/data_storage_page.dart';
import 'package:telegramflutter/pages/app_lock_page.dart';
import 'package:line_icons/line_icons.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final TelegramService _telegramService = TelegramService();
  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;
  Map<String, dynamic>? _storageStats;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      await _telegramService.loadCurrentUser();
      await _telegramService.getStorageStatistics();
      final user = _telegramService.currentUser;
      final stats = _telegramService.storageStatistics;
      if (mounted) {
        setState(() {
          _currentUser = user;
          _storageStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Silently handle errors in production
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: PreferredSize(
        child: getAppBar(),
        preferredSize: Size.fromHeight(60),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF37AEE2)))
          : getBody(),
    );
  }

  getAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: context.appBarBg,
      title: Text('Settings', style: TextStyle(color: context.appBarText)),
      centerTitle: true,
      actions: [
        TextButton(
          onPressed: _editProfile,
          child: Text(
            "Edit",
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF37AEE2),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _editProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfilePage()),
    ).then((result) {
      if (result == true) _loadUserData();
    });
  }

  Widget _buildEditProfileSheet() {
    final firstNameController = TextEditingController(
      text: _currentUser?['first_name'] ?? '',
    );
    final lastNameController = TextEditingController(
      text: _currentUser?['last_name'] ?? '',
    );
    final bioController = TextEditingController(
      text: _currentUser?['bio'] ?? '',
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: white.withOpacity(0.7)),
                    ),
                  ),
                  Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        await _telegramService.updateProfile(
                          firstName: firstNameController.text,
                          lastName: lastNameController.text,
                          bio: bioController.text,
                        );
                        _loadUserData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Profile updated')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update profile')),
                          );
                        }
                      }
                    },
                    child: Text(
                      'Save',
                      style: TextStyle(color: Color(0xFF37AEE2)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildTextField('First Name', firstNameController),
                  SizedBox(height: 16),
                  _buildTextField('Last Name', lastNameController),
                  SizedBox(height: 16),
                  _buildTextField('Bio', bioController, maxLines: 3),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: white.withOpacity(0.6), fontSize: 14),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: white),
          cursorColor: Color(0xFF37AEE2),
          decoration: InputDecoration(
            filled: true,
            fillColor: textfieldColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget getBody() {
    final firstName = _currentUser?['first_name'] ?? '';
    final lastName = _currentUser?['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final username = _currentUser?['usernames']?['editable_username'] ?? '';
    final phone = _currentUser?['phone_number'] ?? '';
    final bio = _currentUser?['bio'] ?? '';
    final photoPath =
        _currentUser?['profile_photo']?['small']?['local']?['path'];

    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 20),
          // Profile photo
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyProfilePage()),
              );
            },
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF37AEE2),
                  ),
                  child: photoPath != null && File(photoPath).existsSync()
                      ? ClipOval(
                          child: Image.file(
                            File(photoPath),
                            fit: BoxFit.cover,
                            width: 100,
                            height: 100,
                          ),
                        )
                      : Center(
                          child: Text(
                            fullName.isNotEmpty
                                ? fullName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(0xFF37AEE2),
                      shape: BoxShape.circle,
                      border: Border.all(color: bgColor, width: 2),
                    ),
                    child: Icon(Icons.camera_alt, color: white, size: 18),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          // Name
          Text(
            fullName.isNotEmpty ? fullName : 'Unknown',
            style: TextStyle(
              fontSize: 24,
              color: white,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          // Phone & username
          Text(
            '+$phone${username.isNotEmpty ? ' • @$username' : ''}',
            style: TextStyle(fontSize: 16, color: white.withOpacity(0.6)),
          ),
          if (bio.isNotEmpty) ...[
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                bio,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: white.withOpacity(0.7)),
              ),
            ),
          ],
          SizedBox(height: 24),

          // Account section
          _buildSectionHeader('Account'),
          _buildSettingItem(
            icon: Icons.notifications_outlined,
            color: Colors.orange,
            title: 'Notifications and Sounds',
            onTap: () => _showNotificationSettings(),
          ),
          _buildSettingItem(
            icon: Icons.lock_outline,
            color: Colors.grey,
            title: 'Privacy and Security',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacySecurityPage()),
            ),
          ),
          _buildSettingItem(
            icon: Icons.storage_outlined,
            color: Colors.green,
            title: 'Data and Storage',
            subtitle: _storageStats != null
                ? 'Using ${_formatFileSize(_storageStats!['size'] as int?)}'
                : null,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DataStoragePage()),
            ),
          ),
          _buildSettingItem(
            icon: Icons.chat_bubble_outline,
            color: Colors.cyan,
            title: 'Chat Settings',
            onTap: () {},
          ),
          _buildSettingItem(
            icon: Icons.brightness_6,
            color: Colors.amber,
            title: 'Appearance',
            subtitle: AppTheme().isDark ? 'Dark Mode' : 'Light Mode',
            trailing: Switch(
              value: AppTheme().isDark,
              onChanged: (val) {
                AppTheme().toggleTheme();
                setState(() {});
              },
              activeColor: Color(0xFF37AEE2),
            ),
            onTap: () {
              AppTheme().toggleTheme();
              setState(() {});
            },
          ),
          _buildSettingItem(
            icon: Icons.devices_outlined,
            color: Colors.orange,
            title: 'Active Sessions',
            subtitle: 'Manage your devices',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ActiveSessionsPage()),
            ),
          ),
          _buildSettingItem(
            icon: LineIcons.lock,
            color: Colors.indigo,
            title: 'App Lock',
            subtitle: 'Passcode & biometrics',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppLockPage()),
            ),
          ),

          SizedBox(height: 24),

          // Help section
          _buildSectionHeader('Help'),
          _buildSettingItem(
            icon: Icons.help_outline,
            color: Colors.blue,
            title: 'Telegram FAQ',
            onTap: () {},
          ),
          _buildSettingItem(
            icon: Icons.question_answer_outlined,
            color: Colors.purple,
            title: 'Ask a Question',
            onTap: () {},
          ),

          SizedBox(height: 24),

          // Danger zone
          _buildSettingItem(
            icon: Icons.logout,
            color: Colors.redAccent,
            title: 'Log Out',
            textColor: Colors.redAccent,
            onTap: () => _showLogoutConfirmation(),
          ),

          SizedBox(height: 40),

          // App version
          Text(
            'Telegram Flutter v1.0.0',
            style: TextStyle(color: white.withOpacity(0.4), fontSize: 14),
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: Color(0xFF37AEE2),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    Color? textColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(color: textColor ?? context.onSurface, fontSize: 16),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(color: context.onSurfaceSecondary, fontSize: 14),
            )
          : null,
      trailing:
          trailing ??
          (textColor == null
              ? Icon(Icons.chevron_right, color: context.onSurfaceSecondary)
              : null),
    );
  }

  void _showNotificationSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationSettingsPage()),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.surface,
        title: Text('Log Out', style: TextStyle(color: context.onSurface)),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: context.onSurface.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.onSurface.withOpacity(0.7)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _telegramService.logOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => LoginPage()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Failed to log out')));
                }
              }
            },
            child: Text('Log Out', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
