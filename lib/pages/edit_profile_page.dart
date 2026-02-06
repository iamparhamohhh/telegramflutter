import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:telegramflutter/services/telegram_service.dart';
import 'package:telegramflutter/theme/colors.dart';

/// Page to edit the current user's profile
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _telegramService = TelegramService();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _photoPath;
  String? _newPhotoPath;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      await _telegramService.loadCurrentUser();
      await Future.delayed(const Duration(milliseconds: 300));
      final user = _telegramService.currentUser;
      if (user != null && mounted) {
        setState(() {
          _firstNameController.text = user['first_name'] ?? '';
          _lastNameController.text = user['last_name'] ?? '';
          _bioController.text = user['bio'] ?? '';
          _usernameController.text =
              user['usernames']?['editable_username'] ?? '';
          _photoPath = user['profile_photo']?['small']?['local']?['path'];
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() => _newPhotoPath = image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to pick image')));
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_firstNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First name cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Update name and bio
      await _telegramService.updateProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        bio: _bioController.text.trim(),
      );

      // Update username if changed
      final currentUsername =
          _telegramService.currentUser?['usernames']?['editable_username'] ??
          '';
      if (_usernameController.text.trim() != currentUsername) {
        await _telegramService.setUsername(_usernameController.text.trim());
      }

      // Update photo if changed
      if (_newPhotoPath != null) {
        await _telegramService.setProfilePhoto(_newPhotoPath!);
      }

      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: greyColor,
        title: const Text('Edit Profile', style: TextStyle(color: white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF37AEE2),
                      ),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _saveProfile,
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Color(0xFF37AEE2),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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
    final displayPhoto = _newPhotoPath ?? _photoPath;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Photo
          GestureDetector(
            onTap: _pickPhoto,
            child: Stack(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade400],
                    ),
                  ),
                  child: displayPhoto != null && File(displayPhoto).existsSync()
                      ? ClipOval(
                          child: Image.file(
                            File(displayPhoto),
                            fit: BoxFit.cover,
                            width: 110,
                            height: 110,
                          ),
                        )
                      : Center(
                          child: Text(
                            _firstNameController.text.isNotEmpty
                                ? _firstNameController.text[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: white,
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF37AEE2),
                      shape: BoxShape.circle,
                      border: Border.all(color: bgColor, width: 3),
                    ),
                    child: const Icon(Icons.camera_alt, color: white, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _pickPhoto,
            child: const Text(
              'Change Photo',
              style: TextStyle(color: Color(0xFF37AEE2), fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),

          // Fields
          _buildField('First Name', _firstNameController, autofocus: true),
          const SizedBox(height: 16),
          _buildField('Last Name', _lastNameController),
          const SizedBox(height: 16),
          _buildField(
            'Username',
            _usernameController,
            prefix: '@',
            hint: 'username',
          ),
          const SizedBox(height: 16),
          _buildField(
            'Bio',
            _bioController,
            maxLines: 3,
            hint: 'A few words about yourself',
            maxLength: 70,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Any details such as age, occupation or city.\nExample: 23 y.o. designer from San Francisco.',
              style: TextStyle(color: white.withOpacity(0.4), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool autofocus = false,
    int maxLines = 1,
    String? prefix,
    String? hint,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF37AEE2),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          autofocus: autofocus,
          maxLines: maxLines,
          maxLength: maxLength,
          style: const TextStyle(color: white, fontSize: 16),
          cursorColor: const Color(0xFF37AEE2),
          decoration: InputDecoration(
            filled: true,
            fillColor: greyColor,
            prefixText: prefix,
            prefixStyle: TextStyle(color: white.withOpacity(0.5), fontSize: 16),
            hintText: hint,
            hintStyle: TextStyle(color: white.withOpacity(0.25)),
            counterStyle: TextStyle(color: white.withOpacity(0.4)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF37AEE2),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}
