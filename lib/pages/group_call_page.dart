import 'dart:async';
import 'package:flutter/material.dart';
import '../services/telegram_service.dart';
import '../theme/colors.dart';

/// Group call / voice chat page
class GroupCallPage extends StatefulWidget {
  final int chatId;
  final String chatTitle;
  final int? groupCallId;
  final bool isCreating;

  const GroupCallPage({
    super.key,
    required this.chatId,
    required this.chatTitle,
    this.groupCallId,
    this.isCreating = false,
  });

  @override
  State<GroupCallPage> createState() => _GroupCallPageState();
}

class _GroupCallPageState extends State<GroupCallPage> {
  final TelegramService _telegramService = TelegramService();
  StreamSubscription<Map<String, dynamic>>? _groupCallSub;

  int? _groupCallId;
  String _callState = 'connecting';
  int _participantCount = 0;
  bool _isMuted = true;
  bool _isVideoOn = false;
  int _duration = 0;
  Timer? _durationTimer;
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _groupCallId = widget.groupCallId;

    _groupCallSub = _telegramService.groupCallStream.listen((event) {
      if (mounted) {
        setState(() {
          if (event.containsKey('groupCallId')) {
            _groupCallId = event['groupCallId'] as int?;
          }
          if (event.containsKey('participantCount')) {
            _participantCount = event['participantCount'] as int? ?? 0;
          }
          if (event.containsKey('state')) {
            final state = event['state'] as String? ?? '';
            if (state.contains('active') || state.contains('Active')) {
              _callState = 'active';
              _startTimer();
            } else if (state.contains('ended') || state.contains('Discard')) {
              _callState = 'ended';
              _stopTimer();
            }
          }
        });
      }
    });

    if (widget.isCreating) {
      _showCreateDialog();
    } else if (_groupCallId != null) {
      _joinCall();
    }
  }

  @override
  void dispose() {
    _groupCallSub?.cancel();
    _durationTimer?.cancel();
    _titleController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _duration = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _duration++);
    });
  }

  void _stopTimer() {
    _durationTimer?.cancel();
  }

  Future<void> _showCreateDialog() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surface,
        title: const Text(
          'Start Voice Chat',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Voice Chat Title (optional)',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _titleController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      await _telegramService.createGroupCall(widget.chatId, title: result);
      setState(() => _callState = 'connecting');
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _joinCall() async {
    if (_groupCallId != null) {
      await _telegramService.joinGroupCall(_groupCallId!);
      setState(() => _callState = 'active');
      _startTimer();
    }
  }

  Future<void> _leaveCall() async {
    if (_groupCallId != null) {
      await _telegramService.leaveGroupCall(_groupCallId!);
    }
    _stopTimer();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _endCall() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surface,
        title: const Text(
          'End Voice Chat',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'End this voice chat for everyone?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && _groupCallId != null) {
      await _telegramService.endGroupCall(_groupCallId!);
      _stopTimer();
      if (mounted) Navigator.pop(context);
    }
  }

  String get _durationText {
    final m = (_duration ~/ 60).toString().padLeft(2, '0');
    final s = (_duration % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.expand_more,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => _leaveCall(),
                  ),
                  const Spacer(),
                  if (_callState == 'active')
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.fiber_manual_record,
                            color: Colors.white,
                            size: 10,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _durationText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () => _showOptions(),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Chat title
            Text(
              widget.chatTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _callState == 'connecting'
                  ? 'Connecting...'
                  : '$_participantCount participant${_participantCount != 1 ? 's' : ''}',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),

            const SizedBox(height: 40),

            // Central voice indicator
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isMuted
                    ? Colors.red.withOpacity(0.2)
                    : Colors.blue.withOpacity(0.2),
                border: Border.all(
                  color: _isMuted ? Colors.red : Colors.blue,
                  width: 3,
                ),
              ),
              child: Icon(
                _isMuted ? Icons.mic_off : Icons.mic,
                color: _isMuted ? Colors.red : Colors.blue,
                size: 48,
              ),
            ),

            const SizedBox(height: 16),
            Text(
              _isMuted ? 'You are muted' : 'You are speaking',
              style: TextStyle(
                color: _isMuted ? Colors.red.shade300 : Colors.blue.shade300,
                fontSize: 14,
              ),
            ),

            const Spacer(flex: 2),

            // Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControl(
                    icon: _isVideoOn ? Icons.videocam : Icons.videocam_off,
                    label: 'Video',
                    isActive: _isVideoOn,
                    onTap: () => setState(() => _isVideoOn = !_isVideoOn),
                  ),
                  _buildControl(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    isActive: !_isMuted,
                    activeColor: Colors.blue,
                    onTap: () => setState(() => _isMuted = !_isMuted),
                  ),
                  _buildControl(
                    icon: Icons.call_end,
                    label: 'Leave',
                    isActive: false,
                    activeColor: Colors.red,
                    inactiveColor: Colors.red,
                    onTap: _leaveCall,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildControl({
    required IconData icon,
    required String label,
    required bool isActive,
    Color activeColor = Colors.blue,
    Color inactiveColor = Colors.white24,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? activeColor : inactiveColor,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add, color: Colors.white),
              title: const Text(
                'Invite Members',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite feature coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.record_voice_over, color: Colors.white),
              title: const Text(
                'Speaker Permissions',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.stop_circle, color: Colors.red),
              title: const Text(
                'End Voice Chat',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _endCall();
              },
            ),
          ],
        ),
      ),
    );
  }
}
