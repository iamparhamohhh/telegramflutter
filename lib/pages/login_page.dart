import 'package:flutter/material.dart';
import 'package:telegramflutter/pages/root_app.dart';
import 'package:telegramflutter/services/telegram_service.dart';
import 'package:telegramflutter/theme/colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String countryCode = '+1';
  final TextEditingController phoneController = TextEditingController();
  final TelegramService _telegramService = TelegramService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initTelegram();
  }

  Future<void> _initTelegram() async {
    await _telegramService.initialize();

    _telegramService.authStateStream.listen((state) {
      if (!mounted) return;

      if (state == 'WaitingForCode') {
        _showCodeDialog();
      } else if (state == 'Authorized') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => RootApp()),
        );
      }
    });
  }

  Future<void> _handleLogin() async {
    final phone = countryCode + phoneController.text.trim();

    if (phone.length < 10) {
      _showError('Please enter a valid phone number');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _telegramService.sendPhoneNumber(phone);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showCodeDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: greyColor,
        title: Text('Enter Code', style: TextStyle(color: white)),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: white),
          decoration: InputDecoration(
            hintText: 'Verification code',
            hintStyle: TextStyle(color: white.withOpacity(0.5)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await _telegramService.checkAuthenticationCode(
                  codeController.text.trim(),
                );
                Navigator.pop(context);
              } catch (e) {
                _showError(e.toString());
              }
            },
            child: Text('Submit', style: TextStyle(color: primary)),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 40),
              CircleAvatar(
                radius: 42,
                backgroundColor: primary,
                child: Icon(Icons.send_rounded, size: 46, color: white),
              ),
              SizedBox(height: 24),
              Text(
                'Welcome to Telegram',
                style: TextStyle(
                  color: white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Enter your phone number to continue',
                textAlign: TextAlign.center,
                style: TextStyle(color: white.withOpacity(0.7)),
              ),
              SizedBox(height: 36),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Phone',
                  style: TextStyle(color: white.withOpacity(0.7)),
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: textfieldColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: greyColor,
                        value: countryCode,
                        items: ['+1', '+7', '+44', '+91']
                            .map(
                              (code) => DropdownMenuItem(
                                value: code,
                                child: Text(
                                  code,
                                  style: TextStyle(color: white),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => countryCode = v);
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: white),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Phone number',
                          hintStyle: TextStyle(color: white.withOpacity(0.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Next',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: () {},
                child: Text(
                  'Log in with username',
                  style: TextStyle(color: white.withOpacity(0.7)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
