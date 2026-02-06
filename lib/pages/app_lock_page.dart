import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:line_icons/line_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import '../theme/colors.dart';

class AppLockPage extends StatefulWidget {
  const AppLockPage({super.key});

  @override
  State<AppLockPage> createState() => _AppLockPageState();
}

class _AppLockPageState extends State<AppLockPage> {
  bool _isLockEnabled = false;
  bool _biometricEnabled = false;
  String _autoLockTimeout = '1 minute';
  bool _showContent = true;
  String? _storedPasscode;
  bool _loading = true;

  final List<String> _autoLockOptions = [
    'Immediately',
    '1 minute',
    '5 minutes',
    '15 minutes',
    '1 hour',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<File> get _settingsFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/app_lock_settings.json');
  }

  Future<void> _loadSettings() async {
    try {
      final file = await _settingsFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content) as Map<String, dynamic>;
        setState(() {
          _isLockEnabled = data['enabled'] as bool? ?? false;
          _biometricEnabled = data['biometric'] as bool? ?? false;
          _autoLockTimeout = data['timeout'] as String? ?? '1 minute';
          _showContent = data['showContent'] as bool? ?? true;
          _storedPasscode = data['passcode'] as String?;
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _saveSettings() async {
    try {
      final file = await _settingsFile;
      await file.writeAsString(
        json.encode({
          'enabled': _isLockEnabled,
          'biometric': _biometricEnabled,
          'timeout': _autoLockTimeout,
          'showContent': _showContent,
          'passcode': _storedPasscode,
        }),
      );
    } catch (_) {}
  }

  void _showSetPasscodeDialog() {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    String? error;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.surface,
          title: Text(
            _storedPasscode == null ? 'Set Passcode' : 'Change Passcode',
            style: TextStyle(color: context.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Enter 4-6 digit passcode',
                  labelStyle: TextStyle(
                    color: context.onSurface.withOpacity(0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  counterText: '',
                ),
                style: TextStyle(
                  color: context.onSurface,
                  fontSize: 24,
                  letterSpacing: 8,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Confirm passcode',
                  labelStyle: TextStyle(
                    color: context.onSurface.withOpacity(0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  counterText: '',
                ),
                style: TextStyle(
                  color: context.onSurface,
                  fontSize: 24,
                  letterSpacing: 8,
                ),
                textAlign: TextAlign.center,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: context.onSurface.withOpacity(0.5)),
              ),
            ),
            TextButton(
              onPressed: () {
                final code = controller.text;
                final confirm = confirmController.text;
                if (code.length < 4) {
                  setDialogState(
                    () => error = 'Passcode must be at least 4 digits',
                  );
                  return;
                }
                if (code != confirm) {
                  setDialogState(() => error = 'Passcodes do not match');
                  return;
                }
                Navigator.pop(ctx);
                setState(() {
                  _storedPasscode = code;
                  _isLockEnabled = true;
                });
                _saveSettings();
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passcode set successfully')),
                );
              },
              child: const Text('Set', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDisableLockDialog() {
    final controller = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.surface,
          title: Text(
            'Enter Passcode to Disable',
            style: TextStyle(color: context.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Current passcode',
                  labelStyle: TextStyle(
                    color: context.onSurface.withOpacity(0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  counterText: '',
                ),
                style: TextStyle(
                  color: context.onSurface,
                  fontSize: 24,
                  letterSpacing: 8,
                ),
                textAlign: TextAlign.center,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: context.onSurface.withOpacity(0.5)),
              ),
            ),
            TextButton(
              onPressed: () {
                if (controller.text != _storedPasscode) {
                  setDialogState(() => error = 'Incorrect passcode');
                  return;
                }
                Navigator.pop(ctx);
                setState(() {
                  _isLockEnabled = false;
                  _biometricEnabled = false;
                  _storedPasscode = null;
                });
                _saveSettings();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('App lock disabled')),
                );
              },
              child: const Text('Disable', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAutoLockPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: context.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Auto-Lock',
              style: TextStyle(
                color: context.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ..._autoLockOptions.map(
            (option) => ListTile(
              leading: Icon(
                _autoLockTimeout == option
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: _autoLockTimeout == option
                    ? Colors.blue
                    : context.onSurface.withOpacity(0.4),
              ),
              title: Text(option, style: TextStyle(color: context.onSurface)),
              onTap: () {
                setState(() => _autoLockTimeout = option);
                _saveSettings();
                Navigator.pop(ctx);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.appBarBg,
        title: Text('App Lock', style: TextStyle(color: context.onSurface)),
        iconTheme: IconThemeData(color: context.onSurface),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Lock illustration
                Container(
                  margin: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: (_isLockEnabled ? Colors.blue : Colors.grey)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          _isLockEnabled ? LineIcons.lock : LineIcons.lockOpen,
                          size: 40,
                          color: _isLockEnabled ? Colors.blue : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isLockEnabled ? 'App Lock is ON' : 'App Lock is OFF',
                        style: TextStyle(
                          color: context.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLockEnabled
                            ? 'Your app is protected with a passcode'
                            : 'Add a passcode to protect your chats',
                        style: TextStyle(
                          color: context.onSurface.withOpacity(0.5),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Main toggle / set passcode
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      if (!_isLockEnabled)
                        ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              LineIcons.lock,
                              color: Colors.blue,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            'Set Passcode',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: _showSetPasscodeDialog,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        )
                      else ...[
                        ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              LineIcons.key,
                              color: Colors.blue,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            'Change Passcode',
                            style: TextStyle(color: context.onSurface),
                          ),
                          onTap: _showSetPasscodeDialog,
                        ),
                        Divider(
                          height: 1,
                          indent: 56,
                          color: context.onSurface.withOpacity(0.1),
                        ),
                        ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              LineIcons.lockOpen,
                              color: Colors.red,
                              size: 18,
                            ),
                          ),
                          title: const Text(
                            'Disable Passcode',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: _showDisableLockDialog,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Additional options (only when lock is enabled)
                if (_isLockEnabled) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      'OPTIONS',
                      style: TextStyle(
                        color: context.onSurface.withOpacity(0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              LineIcons.fingerprint,
                              color: Colors.green,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            'Biometric Unlock',
                            style: TextStyle(color: context.onSurface),
                          ),
                          subtitle: Text(
                            'Use fingerprint or face recognition',
                            style: TextStyle(
                              color: context.onSurface.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                          value: _biometricEnabled,
                          onChanged: (val) {
                            setState(() => _biometricEnabled = val);
                            _saveSettings();
                          },
                          activeColor: Colors.blue,
                        ),
                        Divider(
                          height: 1,
                          indent: 56,
                          color: context.onSurface.withOpacity(0.1),
                        ),
                        ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              LineIcons.clock,
                              color: Colors.purple,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            'Auto-Lock',
                            style: TextStyle(color: context.onSurface),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _autoLockTimeout,
                                style: TextStyle(
                                  color: context.onSurface.withOpacity(0.5),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                LineIcons.angleRight,
                                size: 16,
                                color: context.onSurface.withOpacity(0.3),
                              ),
                            ],
                          ),
                          onTap: _showAutoLockPicker,
                        ),
                        Divider(
                          height: 1,
                          indent: 56,
                          color: context.onSurface.withOpacity(0.1),
                        ),
                        SwitchListTile(
                          secondary: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              LineIcons.eyeSlash,
                              color: Colors.orange,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            'Show Content in Notifications',
                            style: TextStyle(color: context.onSurface),
                          ),
                          subtitle: Text(
                            'Show message previews when locked',
                            style: TextStyle(
                              color: context.onSurface.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                          value: _showContent,
                          onChanged: (val) {
                            setState(() => _showContent = val);
                            _saveSettings();
                          },
                          activeColor: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ],

                // Info
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'When app lock is enabled, you will need to enter your passcode '
                    'to open the app after the auto-lock timeout.',
                    style: TextStyle(
                      color: context.onSurface.withOpacity(0.4),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
