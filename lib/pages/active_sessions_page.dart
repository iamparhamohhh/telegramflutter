import 'dart:async';
import 'package:flutter/material.dart';
import 'package:line_icons/line_icons.dart';
import '../services/telegram_service.dart';
import '../theme/colors.dart';

class ActiveSessionsPage extends StatefulWidget {
  const ActiveSessionsPage({super.key});

  @override
  State<ActiveSessionsPage> createState() => _ActiveSessionsPageState();
}

class _ActiveSessionsPageState extends State<ActiveSessionsPage> {
  final _telegramService = TelegramService();
  StreamSubscription? _sessionsSub;
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _sessionsSub = _telegramService.sessionsStream.listen((sessions) {
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _loading = false;
        });
      }
    });
    _telegramService.getActiveSessions();
  }

  @override
  void dispose() {
    _sessionsSub?.cancel();
    super.dispose();
  }

  String _formatLastActive(int timestamp) {
    if (timestamp == 0) return 'Online now';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  IconData _getDeviceIcon(Map<String, dynamic> session) {
    final platform = (session['platform'] as String? ?? '').toLowerCase();
    final model = (session['device_model'] as String? ?? '').toLowerCase();
    if (platform.contains('ios') ||
        model.contains('iphone') ||
        model.contains('ipad')) {
      return LineIcons.mobilePhone;
    } else if (platform.contains('android') || model.contains('android')) {
      return LineIcons.mobilePhone;
    } else if (platform.contains('macos') || platform.contains('mac')) {
      return LineIcons.laptop;
    } else if (platform.contains('windows')) {
      return LineIcons.desktop;
    } else if (platform.contains('linux')) {
      return LineIcons.linux;
    } else if (platform.contains('web') || platform.contains('browser')) {
      return LineIcons.globe;
    }
    return LineIcons.desktop;
  }

  Color _getPlatformColor(Map<String, dynamic> session) {
    final platform = (session['platform'] as String? ?? '').toLowerCase();
    if (platform.contains('ios') || platform.contains('macos')) {
      return Colors.blue;
    } else if (platform.contains('android')) {
      return Colors.green;
    } else if (platform.contains('windows')) {
      return Colors.cyan;
    } else if (platform.contains('linux')) {
      return Colors.orange;
    } else if (platform.contains('web')) {
      return Colors.purple;
    }
    return Colors.grey;
  }

  void _showTerminateDialog(Map<String, dynamic> session) {
    final appName = session['application_name'] as String? ?? 'Unknown';
    final deviceModel = session['device_model'] as String? ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surface,
        title: Text(
          'Terminate Session',
          style: TextStyle(color: context.onSurface),
        ),
        content: Text(
          'Terminate the session on "$appName" ($deviceModel)?',
          style: TextStyle(color: context.onSurface.withOpacity(0.7)),
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
              Navigator.pop(ctx);
              final sessionId = session['id'] as int? ?? 0;
              _telegramService.terminateSession(sessionId);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Session terminated')),
              );
            },
            child: const Text('Terminate', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showTerminateAllDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surface,
        title: Text(
          'Terminate All Other Sessions',
          style: TextStyle(color: context.onSurface),
        ),
        content: Text(
          'Are you sure you want to terminate all other sessions? You will be logged out from all other devices.',
          style: TextStyle(color: context.onSurface.withOpacity(0.7)),
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
              Navigator.pop(ctx);
              _telegramService.terminateAllOtherSessions();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All other sessions terminated')),
              );
            },
            child: const Text(
              'Terminate All',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Split into current session and other sessions
    Map<String, dynamic>? currentSession;
    List<Map<String, dynamic>> otherSessions = [];
    for (final s in _sessions) {
      if (s['is_current'] == true) {
        currentSession = s;
      } else {
        otherSessions.add(s);
      }
    }

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.appBarBg,
        title: Text(
          'Active Sessions',
          style: TextStyle(color: context.onSurface),
        ),
        iconTheme: IconThemeData(color: context.onSurface),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Current session
                if (currentSession != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'CURRENT SESSION',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _buildSessionTile(currentSession, isCurrent: true),
                ],

                // Other sessions
                if (otherSessions.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'OTHER SESSIONS',
                          style: TextStyle(
                            color: context.onSurface.withOpacity(0.5),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: _showTerminateAllDialog,
                          child: const Text(
                            'Terminate All',
                            style: TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...otherSessions.map((s) => _buildSessionTile(s)),
                ],

                if (otherSessions.isEmpty && !_loading) ...[
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          LineIcons.lock,
                          size: 48,
                          color: context.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No other active sessions',
                          style: TextStyle(
                            color: context.onSurface.withOpacity(0.5),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Info text
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'You can log in to Telegram from other devices using the same phone number. '
                    'Sessions that have been inactive for more than 6 months will be terminated automatically.',
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

  Widget _buildSessionTile(
    Map<String, dynamic> session, {
    bool isCurrent = false,
  }) {
    final appName = session['application_name'] as String? ?? 'Unknown App';
    final appVersion = session['application_version'] as String? ?? '';
    final deviceModel = session['device_model'] as String? ?? '';
    final platform = session['platform'] as String? ?? '';
    final systemVersion = session['system_version'] as String? ?? '';
    final ip = session['ip_address'] as String? ?? '';
    final country = session['country'] as String? ?? '';
    final lastActive = session['last_active_date'] as int? ?? 0;
    final subtitle = '$platform $systemVersion • $deviceModel';
    final location = [country, ip].where((s) => s.isNotEmpty).join(' • ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _getPlatformColor(session).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getDeviceIcon(session),
            color: _getPlatformColor(session),
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '$appName $appVersion',
                style: TextStyle(
                  color: context.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'This device',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: context.onSurface.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
            if (location.isNotEmpty)
              Text(
                location,
                style: TextStyle(
                  color: context.onSurface.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            if (!isCurrent)
              Text(
                _formatLastActive(lastActive),
                style: TextStyle(
                  color: lastActive == 0
                      ? Colors.green
                      : context.onSurface.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        onLongPress: isCurrent ? null : () => _showTerminateDialog(session),
        onTap: isCurrent ? null : () => _showTerminateDialog(session),
      ),
    );
  }
}
