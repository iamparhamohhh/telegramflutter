import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:telegramflutter/services/telegram_service.dart';
import 'package:telegramflutter/theme/colors.dart';
import 'package:telegramflutter/pages/edit_profile_page.dart';

/// Page to view the current user's own profile
class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  final _telegramService = TelegramService();
  bool _isLoading = true;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      await _telegramService.loadCurrentUser();
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _user = _telegramService.currentUser;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: greyColor,
        title: const Text('My Profile', style: TextStyle(color: white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfilePage()),
              );
              if (result == true) _loadProfile();
            },
            child: const Text(
              'Edit',
              style: TextStyle(color: Color(0xFF37AEE2), fontSize: 16),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF37AEE2)),
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final firstName = _user?['first_name'] ?? '';
    final lastName = _user?['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final username = _user?['usernames']?['editable_username'] ?? '';
    final phone = _user?['phone_number'] ?? '';
    final bio = _user?['bio'] ?? '';
    final photoPath = _user?['profile_photo']?['small']?['local']?['path'];

    return RefreshIndicator(
      color: const Color(0xFF37AEE2),
      onRefresh: _loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Profile Photo
            _buildProfilePhoto(fullName, photoPath),
            const SizedBox(height: 20),
            // Name
            Text(
              fullName.isNotEmpty ? fullName : 'Unknown',
              style: const TextStyle(
                fontSize: 26,
                color: white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            // Online status
            _buildOnlineStatus(),
            const SizedBox(height: 28),
            // Info Cards
            _buildInfoSection(phone, username, bio),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePhoto(String fullName, String? photoPath) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: photoPath != null && File(photoPath).existsSync()
          ? ClipOval(
              child: Image.file(
                File(photoPath),
                fit: BoxFit.cover,
                width: 120,
                height: 120,
              ),
            )
          : Center(
              child: Text(
                fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  Widget _buildOnlineStatus() {
    final userId = _telegramService.currentUserId;
    if (userId == null) return const SizedBox.shrink();

    final isOnline = _telegramService.isUserOnline(userId);
    final statusText = _telegramService.getUserStatusText(userId);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOnline ? Colors.green : Colors.grey,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isOnline
              ? 'Online'
              : (statusText.isNotEmpty ? statusText : 'offline'),
          style: TextStyle(
            color: isOnline ? Colors.green : Colors.white54,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(String phone, String username, String bio) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: greyColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (phone.isNotEmpty)
            _buildInfoTile(
              icon: Icons.phone,
              iconColor: Colors.green,
              title: '+$phone',
              subtitle: 'Phone',
              onTap: () {
                Clipboard.setData(ClipboardData(text: '+$phone'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone number copied')),
                );
              },
            ),
          if (phone.isNotEmpty) _divider(),
          if (username.isNotEmpty)
            _buildInfoTile(
              icon: Icons.alternate_email,
              iconColor: const Color(0xFF37AEE2),
              title: '@$username',
              subtitle: 'Username',
              onTap: () {
                Clipboard.setData(ClipboardData(text: '@$username'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Username copied')),
                );
              },
            ),
          if (username.isNotEmpty && bio.isNotEmpty) _divider(),
          if (bio.isNotEmpty)
            _buildInfoTile(
              icon: Icons.info_outline,
              iconColor: Colors.orange,
              title: bio,
              subtitle: 'Bio',
            ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: white, fontSize: 16)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: white.withOpacity(0.5), fontSize: 12),
      ),
      onTap: onTap,
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Divider(height: 1, color: white.withOpacity(0.08)),
    );
  }
}
