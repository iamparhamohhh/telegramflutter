import 'package:flutter/material.dart';
import 'package:telegramflutter/services/telegram_service.dart';
import 'package:telegramflutter/theme/colors.dart';

/// Page to add a new contact by phone number
class AddContactPage extends StatefulWidget {
  const AddContactPage({super.key});

  @override
  State<AddContactPage> createState() => _AddContactPageState();
}

class _AddContactPageState extends State<AddContactPage> {
  final _telegramService = TelegramService();
  final _phoneController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isSaving = false;

  Future<void> _addContact() async {
    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Phone number is required')));
      return;
    }
    if (_firstNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('First name is required')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _telegramService.addContact(
        phoneNumber: _phoneController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to add contact')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: greyColor,
        title: const Text('Add Contact', style: TextStyle(color: white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: white),
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
                  onPressed: _addContact,
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Color(0xFF37AEE2),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar preview
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade600,
              ),
              child: const Icon(Icons.person_add, color: white, size: 36),
            ),
            const SizedBox(height: 32),

            _buildField(
              'Phone Number',
              _phoneController,
              keyboardType: TextInputType.phone,
              prefix: '+',
              hint: '1234567890',
              autofocus: true,
            ),
            const SizedBox(height: 20),
            _buildField('First Name', _firstNameController, hint: 'Required'),
            const SizedBox(height: 20),
            _buildField('Last Name', _lastNameController, hint: 'Optional'),
            const SizedBox(height: 24),
            Text(
              'Enter the phone number registered with Telegram to add as a contact.',
              style: TextStyle(color: white.withOpacity(0.4), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    String? prefix,
    String? hint,
    bool autofocus = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF37AEE2),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          autofocus: autofocus,
          style: const TextStyle(color: white, fontSize: 16),
          cursorColor: const Color(0xFF37AEE2),
          decoration: InputDecoration(
            filled: true,
            fillColor: greyColor,
            prefixText: prefix,
            prefixStyle: TextStyle(color: white.withOpacity(0.5), fontSize: 16),
            hintText: hint,
            hintStyle: TextStyle(color: white.withOpacity(0.25)),
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
