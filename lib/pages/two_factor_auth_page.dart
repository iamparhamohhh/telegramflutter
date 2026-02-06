import 'dart:async';
import 'package:flutter/material.dart';
import 'package:telegramflutter/services/telegram_service.dart';
import 'package:telegramflutter/theme/colors.dart';

/// Page to manage Two-Factor Authentication (2FA / Two-Step Verification)
class TwoFactorAuthPage extends StatefulWidget {
  const TwoFactorAuthPage({super.key});

  @override
  State<TwoFactorAuthPage> createState() => _TwoFactorAuthPageState();
}

class _TwoFactorAuthPageState extends State<TwoFactorAuthPage> {
  final _telegramService = TelegramService();
  StreamSubscription? _passwordStateSub;
  bool _isLoading = true;
  bool _hasPassword = false;
  String? _passwordHint;
  bool _hasRecoveryEmail = false;
  String? _recoveryEmail;

  @override
  void initState() {
    super.initState();
    _passwordStateSub = _telegramService.passwordStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _hasPassword = state['has_password'] as bool? ?? false;
          _passwordHint = state['password_hint'] as String?;
          _hasRecoveryEmail =
              state['has_recovery_email_address'] as bool? ?? false;
          _recoveryEmail = state['recovery_email_address_pattern'] as String?;
          _isLoading = false;
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
          'Two-Step Verification',
          style: TextStyle(color: white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF37AEE2)),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildStatusCard(),
                  const SizedBox(height: 16),
                  _buildActions(),
                  const SizedBox(height: 32),
                  _buildInfoText(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _hasPassword
                ? Colors.green.withOpacity(0.15)
                : Colors.orange.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _hasPassword ? Icons.lock : Icons.lock_open,
            size: 40,
            color: _hasPassword ? Colors.green : Colors.orange,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _hasPassword
              ? 'Two-Step Verification is On'
              : 'Two-Step Verification is Off',
          style: const TextStyle(
            color: white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            _hasPassword
                ? 'Your account is protected with an additional password.'
                : 'Set an additional password to secure your account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: white.withOpacity(0.6), fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: greyColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildStatusTile(
            icon: Icons.lock,
            iconColor: _hasPassword ? Colors.green : Colors.grey,
            title: 'Password',
            value: _hasPassword ? 'Set' : 'Not set',
            valueColor: _hasPassword ? Colors.green : Colors.orange,
          ),
          _divider(),
          if (_hasPassword &&
              _passwordHint != null &&
              _passwordHint!.isNotEmpty) ...[
            _buildStatusTile(
              icon: Icons.lightbulb_outline,
              iconColor: Colors.amber,
              title: 'Password Hint',
              value: _passwordHint!,
            ),
            _divider(),
          ],
          _buildStatusTile(
            icon: Icons.email_outlined,
            iconColor: _hasRecoveryEmail ? Colors.green : Colors.grey,
            title: 'Recovery Email',
            value: _hasRecoveryEmail ? (_recoveryEmail ?? 'Set') : 'Not set',
            valueColor: _hasRecoveryEmail ? Colors.green : Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    Color? valueColor,
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
      title: Text(title, style: const TextStyle(color: white, fontSize: 15)),
      trailing: Text(
        value,
        style: TextStyle(
          color: valueColor ?? white.withOpacity(0.6),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: greyColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (!_hasPassword)
            _buildActionTile(
              icon: Icons.add_circle_outline,
              iconColor: const Color(0xFF37AEE2),
              title: 'Set Password',
              onTap: () => _showSetPasswordDialog(),
            ),
          if (_hasPassword) ...[
            _buildActionTile(
              icon: Icons.edit,
              iconColor: const Color(0xFF37AEE2),
              title: 'Change Password',
              onTap: () => _showChangePasswordDialog(),
            ),
            _divider(),
            _buildActionTile(
              icon: Icons.email_outlined,
              iconColor: Colors.orange,
              title: _hasRecoveryEmail
                  ? 'Change Recovery Email'
                  : 'Set Recovery Email',
              onTap: () => _showSetRecoveryEmailDialog(),
            ),
            _divider(),
            _buildActionTile(
              icon: Icons.delete_outline,
              iconColor: Colors.red,
              title: 'Remove Password',
              textColor: Colors.red,
              onTap: () => _showRemovePasswordDialog(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    Color? textColor,
    required VoidCallback onTap,
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
      title: Text(
        title,
        style: TextStyle(color: textColor ?? white, fontSize: 15),
      ),
      trailing: Icon(Icons.chevron_right, color: white.withOpacity(0.3)),
      onTap: onTap,
    );
  }

  Widget _buildInfoText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        'Two-step verification adds an extra layer of security to your '
        'Telegram account. When enabled, you\'ll need to enter your '
        'password whenever you log in on a new device, in addition to '
        'the code you receive via SMS.',
        textAlign: TextAlign.center,
        style: TextStyle(color: white.withOpacity(0.35), fontSize: 13),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Divider(height: 1, color: white.withOpacity(0.08)),
    );
  }

  void _showSetPasswordDialog() {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final hintController = TextEditingController();
    final emailController = TextEditingController();
    bool obscure = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: greyColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Set Password',
                      style: TextStyle(
                        color: white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildPasswordField(
                    'New Password',
                    passwordController,
                    obscure,
                    () => setModalState(() => obscure = !obscure),
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    'Confirm Password',
                    confirmController,
                    obscure,
                    () => setModalState(() => obscure = !obscure),
                  ),
                  const SizedBox(height: 16),
                  _buildInputField('Password Hint (optional)', hintController),
                  const SizedBox(height: 16),
                  _buildInputField(
                    'Recovery Email (optional)',
                    emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (passwordController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password cannot be empty'),
                            ),
                          );
                          return;
                        }
                        if (passwordController.text != confirmController.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Passwords do not match'),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        await _telegramService.setPassword(
                          newPassword: passwordController.text,
                          newHint: hintController.text.isNotEmpty
                              ? hintController.text
                              : null,
                          newRecoveryEmail: emailController.text.isNotEmpty
                              ? emailController.text
                              : null,
                        );
                        await Future.delayed(const Duration(milliseconds: 500));
                        _telegramService.getPasswordState();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password set successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF37AEE2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Set Password',
                        style: TextStyle(color: white, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmController = TextEditingController();
    final hintController = TextEditingController();
    bool obscure = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: greyColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Change Password',
                      style: TextStyle(
                        color: white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildPasswordField(
                    'Current Password',
                    oldPasswordController,
                    obscure,
                    () => setModalState(() => obscure = !obscure),
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    'New Password',
                    newPasswordController,
                    obscure,
                    () => setModalState(() => obscure = !obscure),
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    'Confirm New Password',
                    confirmController,
                    obscure,
                    () => setModalState(() => obscure = !obscure),
                  ),
                  const SizedBox(height: 16),
                  _buildInputField('New Hint (optional)', hintController),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (oldPasswordController.text.isEmpty ||
                            newPasswordController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill all fields'),
                            ),
                          );
                          return;
                        }
                        if (newPasswordController.text !=
                            confirmController.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Passwords do not match'),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        await _telegramService.setPassword(
                          oldPassword: oldPasswordController.text,
                          newPassword: newPasswordController.text,
                          newHint: hintController.text.isNotEmpty
                              ? hintController.text
                              : null,
                        );
                        await Future.delayed(const Duration(milliseconds: 500));
                        _telegramService.getPasswordState();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password changed'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF37AEE2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Change Password',
                        style: TextStyle(color: white, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSetRecoveryEmailDialog() {
    final passwordController = TextEditingController();
    final emailController = TextEditingController();
    bool obscure = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: greyColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Recovery Email',
                      style: TextStyle(
                        color: white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildPasswordField(
                    'Current Password',
                    passwordController,
                    obscure,
                    () => setModalState(() => obscure = !obscure),
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    'Recovery Email',
                    emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (passwordController.text.isEmpty ||
                            emailController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill all fields'),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        await _telegramService.setRecoveryEmail(
                          passwordController.text,
                          emailController.text,
                        );
                        await Future.delayed(const Duration(milliseconds: 500));
                        _telegramService.getPasswordState();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Recovery email set'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF37AEE2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Set Recovery Email',
                        style: TextStyle(color: white, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRemovePasswordDialog() {
    final passwordController = TextEditingController();
    bool obscure = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: greyColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Remove Password',
                      style: TextStyle(
                        color: white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'This will disable two-step verification.',
                      style: TextStyle(
                        color: Colors.red.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildPasswordField(
                    'Current Password',
                    passwordController,
                    obscure,
                    () => setModalState(() => obscure = !obscure),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (passwordController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Enter current password'),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        await _telegramService.removePassword(
                          passwordController.text,
                        );
                        await Future.delayed(const Duration(milliseconds: 500));
                        _telegramService.getPasswordState();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password removed'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Remove Password',
                        style: TextStyle(color: white, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller,
    bool obscure,
    VoidCallback toggleObscure,
  ) {
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
          obscureText: obscure,
          style: const TextStyle(color: white, fontSize: 16),
          cursorColor: const Color(0xFF37AEE2),
          decoration: InputDecoration(
            filled: true,
            fillColor: bgColor,
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: white.withOpacity(0.4),
              ),
              onPressed: toggleObscure,
            ),
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

  Widget _buildInputField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
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
          keyboardType: keyboardType,
          style: const TextStyle(color: white, fontSize: 16),
          cursorColor: const Color(0xFF37AEE2),
          decoration: InputDecoration(
            filled: true,
            fillColor: bgColor,
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
