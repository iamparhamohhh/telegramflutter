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
    setState(() => _isLoading = true);

    try {
      await _telegramService.initialize();
    } catch (e) {
      _showError('Failed to initialize: $e');
      setState(() => _isLoading = false);
      return;
    }

    _telegramService.authStateStream.listen(
      (state) {
        if (!mounted) return;

        if (state == 'WaitingForPhone') {
          setState(() => _isLoading = false);
        } else if (state == 'WaitingForCode') {
          _showCodeDialog();
        } else if (state == 'WaitingForPassword') {
          _showPasswordDialog();
        } else if (state == 'Authorized') {
          // Preload chats before navigating
          _telegramService.loadChats(limit: 100);

          // Give TDLib a moment to start sending chat updates, then navigate
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            // Close any open dialogs first
            Navigator.of(context).popUntil((route) => route.isFirst);
            // Then navigate to home
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => RootApp()),
            );
          });
        }
      },
      onError: (error) {
        _showError(error.toString());
        setState(() => _isLoading = false);
      },
    );
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
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: textfieldColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Enter Code',
            style: TextStyle(
              color: white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'We have sent you a verification code via SMS',
                style: TextStyle(color: white.withOpacity(0.6), fontSize: 14),
              ),
              SizedBox(height: 20),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                autofocus: true,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: white,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 8,
                ),
                enabled: !isSubmitting,
                decoration: InputDecoration(
                  hintText: '-----',
                  hintStyle: TextStyle(
                    color: white.withOpacity(0.3),
                    letterSpacing: 8,
                  ),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: white.withOpacity(0.2)),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: white.withOpacity(0.2)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF37AEE2), width: 2),
                  ),
                ),
              ),
              if (isSubmitting) ...[
                SizedBox(height: 24),
                CircularProgressIndicator(
                  color: Color(0xFF37AEE2),
                  strokeWidth: 2.5,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final code = codeController.text.trim();
                      if (code.isEmpty) {
                        _showError('Please enter the verification code');
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      try {
                        await _telegramService.checkAuthenticationCode(code);
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        _showError(e.toString());
                      }
                    },
              child: Text(
                isSubmitting ? 'Verifying...' : 'SUBMIT',
                style: TextStyle(
                  color: isSubmitting
                      ? white.withOpacity(0.5)
                      : Color(0xFF37AEE2),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPasswordDialog() {
    final passwordController = TextEditingController();
    bool isSubmitting = false;
    bool obscureText = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: textfieldColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Enter Password',
            style: TextStyle(
              color: white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your account has Two-Step Verification enabled',
                textAlign: TextAlign.center,
                style: TextStyle(color: white.withOpacity(0.6), fontSize: 14),
              ),
              SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: obscureText,
                autofocus: true,
                style: TextStyle(color: white, fontSize: 16),
                enabled: !isSubmitting,
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: TextStyle(color: white.withOpacity(0.4)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility : Icons.visibility_off,
                      color: white.withOpacity(0.5),
                    ),
                    onPressed: () {
                      setDialogState(() => obscureText = !obscureText);
                    },
                  ),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: white.withOpacity(0.2)),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: white.withOpacity(0.2)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF37AEE2), width: 2),
                  ),
                ),
              ),
              if (isSubmitting) ...[
                SizedBox(height: 24),
                CircularProgressIndicator(
                  color: Color(0xFF37AEE2),
                  strokeWidth: 2.5,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final password = passwordController.text.trim();
                      if (password.isEmpty) {
                        _showError('Please enter your password');
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      try {
                        await _telegramService.checkPassword(password);
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        _showError(e.toString());
                      }
                    },
              child: Text(
                isSubmitting ? 'Verifying...' : 'SUBMIT',
                style: TextStyle(
                  color: isSubmitting
                      ? white.withOpacity(0.5)
                      : Color(0xFF37AEE2),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 80),
                // Telegram Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF37AEE2), Color(0xFF1E96C8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF37AEE2).withOpacity(0.3),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(Icons.send_rounded, size: 56, color: white),
                ),
                SizedBox(height: 32),
                Text(
                  'Your Phone Number',
                  style: TextStyle(
                    color: white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Please confirm your country code\nand enter your phone number.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: white.withOpacity(0.6),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: 48),
                // Country & Phone Input
                Container(
                  decoration: BoxDecoration(
                    color: textfieldColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: white.withOpacity(0.1), width: 1),
                  ),
                  child: Column(
                    children: [
                      // Country Code Selector
                      InkWell(
                        onTap: () {
                          // TODO: Show country selector bottom sheet
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Country',
                                style: TextStyle(
                                  color: white.withOpacity(0.5),
                                  fontSize: 15,
                                ),
                              ),
                              Spacer(),
                              Text(
                                _getCountryName(countryCode),
                                style: TextStyle(color: white, fontSize: 15),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: white.withOpacity(0.3),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: white.withOpacity(0.05),
                      ),
                      // Phone Number Input
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            // Country Code Dropdown
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                dropdownColor: greyColor,
                                value: countryCode,
                                items:
                                    [
                                          '+1',
                                          '+7',
                                          '+20',
                                          '+27',
                                          '+30',
                                          '+31',
                                          '+32',
                                          '+33',
                                          '+34',
                                          '+36',
                                          '+39',
                                          '+40',
                                          '+41',
                                          '+43',
                                          '+44',
                                          '+45',
                                          '+46',
                                          '+47',
                                          '+48',
                                          '+49',
                                          '+51',
                                          '+52',
                                          '+53',
                                          '+54',
                                          '+55',
                                          '+56',
                                          '+57',
                                          '+58',
                                          '+60',
                                          '+61',
                                          '+62',
                                          '+63',
                                          '+64',
                                          '+65',
                                          '+66',
                                          '+81',
                                          '+82',
                                          '+84',
                                          '+86',
                                          '+90',
                                          '+91',
                                          '+92',
                                          '+93',
                                          '+94',
                                          '+95',
                                          '+98',
                                          '+212',
                                          '+213',
                                          '+216',
                                          '+218',
                                          '+220',
                                          '+221',
                                          '+234',
                                          '+249',
                                          '+254',
                                          '+255',
                                          '+256',
                                          '+260',
                                          '+261',
                                          '+263',
                                          '+351',
                                          '+352',
                                          '+353',
                                          '+354',
                                          '+355',
                                          '+358',
                                          '+359',
                                          '+370',
                                          '+371',
                                          '+372',
                                          '+373',
                                          '+374',
                                          '+375',
                                          '+380',
                                          '+381',
                                          '+385',
                                          '+386',
                                          '+387',
                                          '+389',
                                          '+420',
                                          '+421',
                                          '+423',
                                          '+852',
                                          '+853',
                                          '+855',
                                          '+856',
                                          '+880',
                                          '+886',
                                          '+960',
                                          '+961',
                                          '+962',
                                          '+963',
                                          '+964',
                                          '+965',
                                          '+966',
                                          '+967',
                                          '+968',
                                          '+970',
                                          '+971',
                                          '+972',
                                          '+973',
                                          '+974',
                                          '+975',
                                          '+976',
                                          '+977',
                                          '+992',
                                          '+993',
                                          '+994',
                                          '+995',
                                          '+996',
                                          '+998',
                                        ]
                                        .map(
                                          (code) => DropdownMenuItem(
                                            value: code,
                                            child: Text(
                                              code,
                                              style: TextStyle(
                                                color: white,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => countryCode = v);
                                  }
                                },
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 24,
                              color: white.withOpacity(0.2),
                              margin: EdgeInsets.symmetric(horizontal: 12),
                            ),
                            Expanded(
                              child: TextField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                autofocus: !_isLoading,
                                style: TextStyle(color: white, fontSize: 15),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Phone number',
                                  hintStyle: TextStyle(
                                    color: white.withOpacity(0.4),
                                    fontSize: 15,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    'We will send you a code via SMS to verify your phone number.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: white.withOpacity(0.4),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: 24),
                // Next Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF37AEE2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'NEXT',
                            style: TextStyle(
                              fontSize: 15,
                              color: white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 40),
                // Keep Signed In Option (Optional)
                Text(
                  'By signing up, you agree to our',
                  style: TextStyle(color: white.withOpacity(0.4), fontSize: 12),
                ),
                SizedBox(height: 4),
                Text(
                  'Terms of Service and Privacy Policy',
                  style: TextStyle(color: Color(0xFF37AEE2), fontSize: 12),
                ),
                // DEBUG: Reset button - remove in production
                SizedBox(height: 32),
                TextButton.icon(
                  onPressed: () async {
                    setState(() => _isLoading = true);
                    try {
                      await _telegramService.clearDatabase();
                      _showError('Database cleared! Please restart the app.');
                    } catch (e) {
                      _showError('Error: $e');
                    }
                    setState(() => _isLoading = false);
                  },
                  icon: Icon(
                    Icons.delete_forever,
                    color: Colors.red.withOpacity(0.5),
                    size: 18,
                  ),
                  label: Text(
                    'Reset TDLib (Debug)',
                    style: TextStyle(
                      color: Colors.red.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getCountryName(String code) {
    final Map<String, String> countryNames = {
      '+1': 'United States',
      '+7': 'Russia',
      '+20': 'Egypt',
      '+27': 'South Africa',
      '+30': 'Greece',
      '+31': 'Netherlands',
      '+32': 'Belgium',
      '+33': 'France',
      '+34': 'Spain',
      '+36': 'Hungary',
      '+39': 'Italy',
      '+40': 'Romania',
      '+41': 'Switzerland',
      '+43': 'Austria',
      '+44': 'United Kingdom',
      '+45': 'Denmark',
      '+46': 'Sweden',
      '+47': 'Norway',
      '+48': 'Poland',
      '+49': 'Germany',
      '+51': 'Peru',
      '+52': 'Mexico',
      '+54': 'Argentina',
      '+55': 'Brazil',
      '+56': 'Chile',
      '+57': 'Colombia',
      '+60': 'Malaysia',
      '+61': 'Australia',
      '+62': 'Indonesia',
      '+63': 'Philippines',
      '+64': 'New Zealand',
      '+65': 'Singapore',
      '+66': 'Thailand',
      '+81': 'Japan',
      '+82': 'South Korea',
      '+84': 'Vietnam',
      '+86': 'China',
      '+90': 'Turkey',
      '+91': 'India',
      '+92': 'Pakistan',
      '+93': 'Afghanistan',
      '+94': 'Sri Lanka',
      '+95': 'Myanmar',
      '+98': 'Iran',
      '+212': 'Morocco',
      '+213': 'Algeria',
      '+216': 'Tunisia',
      '+218': 'Libya',
      '+220': 'Gambia',
      '+221': 'Senegal',
      '+234': 'Nigeria',
      '+249': 'Sudan',
      '+254': 'Kenya',
      '+255': 'Tanzania',
      '+256': 'Uganda',
      '+260': 'Zambia',
      '+261': 'Madagascar',
      '+263': 'Zimbabwe',
      '+351': 'Portugal',
      '+352': 'Luxembourg',
      '+353': 'Ireland',
      '+354': 'Iceland',
      '+355': 'Albania',
      '+358': 'Finland',
      '+359': 'Bulgaria',
      '+370': 'Lithuania',
      '+371': 'Latvia',
      '+372': 'Estonia',
      '+373': 'Moldova',
      '+374': 'Armenia',
      '+375': 'Belarus',
      '+380': 'Ukraine',
      '+381': 'Serbia',
      '+385': 'Croatia',
      '+386': 'Slovenia',
      '+387': 'Bosnia',
      '+389': 'North Macedonia',
      '+420': 'Czech Republic',
      '+421': 'Slovakia',
      '+423': 'Liechtenstein',
      '+852': 'Hong Kong',
      '+853': 'Macau',
      '+855': 'Cambodia',
      '+856': 'Laos',
      '+880': 'Bangladesh',
      '+886': 'Taiwan',
      '+960': 'Maldives',
      '+961': 'Lebanon',
      '+962': 'Jordan',
      '+963': 'Syria',
      '+964': 'Iraq',
      '+965': 'Kuwait',
      '+966': 'Saudi Arabia',
      '+967': 'Yemen',
      '+968': 'Oman',
      '+970': 'Palestine',
      '+971': 'UAE',
      '+972': 'Israel',
      '+973': 'Bahrain',
      '+974': 'Qatar',
      '+975': 'Bhutan',
      '+976': 'Mongolia',
      '+977': 'Nepal',
      '+992': 'Tajikistan',
      '+993': 'Turkmenistan',
      '+994': 'Azerbaijan',
      '+995': 'Georgia',
      '+996': 'Kyrgyzstan',
      '+998': 'Uzbekistan',
    };
    return countryNames[code] ?? 'Unknown';
  }
}
