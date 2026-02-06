import 'dart:io';
import 'package:flutter/material.dart';
import 'package:telegramflutter/services/telegram_service.dart';
import 'package:telegramflutter/theme/colors.dart';

/// Page to manage blocked users
class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final _telegramService = TelegramService();
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final users = await _telegramService.getBlockedUsers();
      if (mounted) {
        setState(() {
          _blockedUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unblockUser(int userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: greyColor,
        title: const Text('Unblock User', style: TextStyle(color: white)),
        content: Text(
          'Unblock $name? They will be able to contact you again.',
          style: TextStyle(color: white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: white.withOpacity(0.7)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Unblock',
              style: TextStyle(color: Color(0xFF37AEE2)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _telegramService.toggleBlockUser(userId, false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$name unblocked')));
        _loadBlockedUsers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: greyColor,
        title: const Text('Blocked Users', style: TextStyle(color: white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF37AEE2)),
            )
          : _blockedUsers.isEmpty
          ? _buildEmptyState()
          : _buildBlockedList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block, color: white.withOpacity(0.15), size: 64),
          const SizedBox(height: 16),
          Text(
            'No blocked users',
            style: TextStyle(color: white.withOpacity(0.5), fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Blocked users will appear here',
            style: TextStyle(color: white.withOpacity(0.3), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _blockedUsers.length,
      separatorBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(left: 72),
        child: Divider(height: 1, color: white.withOpacity(0.08)),
      ),
      itemBuilder: (context, index) {
        final user = _blockedUsers[index];
        final userId = user['user_id'] as int;
        final firstName = user['first_name'] as String? ?? '';
        final lastName = user['last_name'] as String? ?? '';
        final fullName = '$firstName $lastName'.trim();
        final displayName = fullName.isNotEmpty ? fullName : 'User $userId';
        final photoPath = _telegramService.getUserPhotoPath(userId);

        return ListTile(
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.red.shade700,
            backgroundImage: photoPath != null
                ? FileImage(File(photoPath))
                : null,
            child: photoPath == null
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          title: Text(
            displayName,
            style: const TextStyle(color: white, fontSize: 16),
          ),
          subtitle: Text(
            user['phone'] as String? ?? '',
            style: TextStyle(color: white.withOpacity(0.5), fontSize: 13),
          ),
          trailing: TextButton(
            onPressed: () => _unblockUser(userId, displayName),
            child: const Text(
              'Unblock',
              style: TextStyle(color: Color(0xFF37AEE2)),
            ),
          ),
        );
      },
    );
  }
}
