import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:line_icons/line_icons.dart';
import '../services/telegram_service.dart';
import '../theme/colors.dart';

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({super.key});

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  final _telegramService = TelegramService();
  StreamSubscription? _ttlSub;
  int _accountTtlDays = 365;
  bool _loading = true;
  int _step = 0; // 0 = info, 1 = reason, 2 = confirm
  String _selectedReason = '';
  final _customReasonController = TextEditingController();

  final List<String> _reasons = [
    'I have another account',
    'Too many notifications',
    'Privacy concerns',
    'Don\'t use Telegram anymore',
    'Other',
  ];

  final List<int> _ttlOptions = [30, 90, 180, 365];

  @override
  void initState() {
    super.initState();
    _ttlSub = _telegramService.accountTtlStream.listen((days) {
      if (mounted) {
        setState(() {
          _accountTtlDays = days;
          _loading = false;
        });
      }
    });
    _telegramService.getAccountTtl();
    // Fallback if stream doesn't fire
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _loading) {
        setState(() {
          _accountTtlDays = _telegramService.accountTtlDays;
          _loading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _ttlSub?.cancel();
    _customReasonController.dispose();
    super.dispose();
  }

  String _formatTtl(int days) {
    if (days <= 30) return '1 month';
    if (days <= 90) return '3 months';
    if (days <= 180) return '6 months';
    return '1 year';
  }

  void _showTtlPicker() {
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
              'Auto-Delete Account After',
              style: TextStyle(
                color: context.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ..._ttlOptions.map(
            (days) => ListTile(
              leading: Icon(
                _accountTtlDays == days
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: _accountTtlDays == days
                    ? Colors.blue
                    : context.onSurface.withOpacity(0.4),
              ),
              title: Text(
                _formatTtl(days),
                style: TextStyle(color: context.onSurface),
              ),
              subtitle: Text(
                '$days days of inactivity',
                style: TextStyle(
                  color: context.onSurface.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
              onTap: () {
                _telegramService.setAccountTtl(days);
                setState(() => _accountTtlDays = days);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Account will auto-delete after ${_formatTtl(days)}',
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'If you do not come online at least once within this period, '
              'your account will be deleted along with all messages and contacts.',
              style: TextStyle(
                color: context.onSurface.withOpacity(0.4),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _proceedToDelete() {
    setState(() => _step = 1);
  }

  void _confirmDeletion() {
    final reason = _selectedReason == 'Other'
        ? _customReasonController.text
        : _selectedReason;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surface,
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              'Final Warning',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action is IRREVERSIBLE. You will lose:',
              style: TextStyle(
                color: context.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildWarningItem('All your messages and chats'),
            _buildWarningItem('All your contacts'),
            _buildWarningItem('All your groups and channels'),
            _buildWarningItem('Your Telegram account permanently'),
            const SizedBox(height: 16),
            Text(
              'Are you absolutely sure?',
              style: TextStyle(
                color: context.onSurface.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Go Back',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _telegramService.deleteAccount(reason);
              HapticFeedback.heavyImpact();
            },
            child: const Text(
              'Delete My Account',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.remove_circle, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.onSurface.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ),
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
        title: Text(
          'Account Deletion',
          style: TextStyle(color: context.onSurface),
        ),
        iconTheme: IconThemeData(color: context.onSurface),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _step == 0
          ? _buildInfoStep()
          : _buildReasonStep(),
    );
  }

  Widget _buildInfoStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Warning icon
        Container(
          margin: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  LineIcons.exclamationTriangle,
                  size: 40,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Account Self-Destruct',
                style: TextStyle(
                  color: context.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        // Auto-delete timer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account Self-Destruct Timer',
                style: TextStyle(
                  color: context.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'If you do not log in for ${_formatTtl(_accountTtlDays)}, your account will be automatically deleted.',
                style: TextStyle(
                  color: context.onSurface.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showTtlPicker,
                  icon: const Icon(LineIcons.clock, size: 18),
                  label: Text('Change to ${_formatTtl(_accountTtlDays)}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Info cards
        _buildInfoCard(
          LineIcons.exclamationCircle,
          'Permanent Action',
          'Deleting your account will permanently remove all your data from Telegram servers.',
          Colors.red,
        ),
        _buildInfoCard(
          LineIcons.commentDots,
          'Messages',
          'All your messages in private chats will be deleted. Messages in groups will remain.',
          Colors.orange,
        ),
        _buildInfoCard(
          LineIcons.userFriends,
          'Groups & Channels',
          'You will leave all groups and channels. Groups you created will continue to exist.',
          Colors.blue,
        ),

        const SizedBox(height: 24),

        // Delete button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _proceedToDelete,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Delete My Account',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildReasonStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Why are you leaving?',
          style: TextStyle(
            color: context.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please let us know why you want to delete your account. This helps us improve.',
          style: TextStyle(
            color: context.onSurface.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),

        // Reason options
        Container(
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: _reasons.asMap().entries.map((entry) {
              final idx = entry.key;
              final reason = entry.value;
              return Column(
                children: [
                  RadioListTile<String>(
                    value: reason,
                    groupValue: _selectedReason,
                    onChanged: (val) =>
                        setState(() => _selectedReason = val ?? ''),
                    title: Text(
                      reason,
                      style: TextStyle(color: context.onSurface),
                    ),
                    activeColor: Colors.red,
                    shape: idx == 0
                        ? const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          )
                        : idx == _reasons.length - 1
                        ? const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(12),
                            ),
                          )
                        : null,
                  ),
                  if (idx < _reasons.length - 1)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: context.onSurface.withOpacity(0.1),
                    ),
                ],
              );
            }).toList(),
          ),
        ),

        // Custom reason input
        if (_selectedReason == 'Other') ...[
          const SizedBox(height: 16),
          TextField(
            controller: _customReasonController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Tell us more...',
              hintStyle: TextStyle(color: context.onSurface.withOpacity(0.4)),
              filled: true,
              fillColor: context.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            style: TextStyle(color: context.onSurface),
          ),
        ],

        const SizedBox(height: 32),

        // Confirm delete button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _selectedReason.isEmpty ? null : _confirmDeletion,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.red.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Proceed to Delete',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Go back button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: TextButton(
            onPressed: () => setState(() => _step = 0),
            child: Text(
              'Go Back',
              style: TextStyle(
                color: context.onSurface.withOpacity(0.6),
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: context.onSurface.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
