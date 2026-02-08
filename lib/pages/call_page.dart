import 'dart:async';
import 'package:flutter/material.dart';
import '../services/telegram_service.dart';

/// Full-screen call page for voice and video calls
class CallPage extends StatefulWidget {
  final int userId;
  final String userName;
  final String? userPhoto;
  final bool isVideo;
  final bool isIncoming;
  final int? callId;

  const CallPage({
    super.key,
    required this.userId,
    required this.userName,
    this.userPhoto,
    this.isVideo = false,
    this.isIncoming = false,
    this.callId,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> with TickerProviderStateMixin {
  final TelegramService _telegramService = TelegramService();
  StreamSubscription<Map<String, dynamic>>? _callSub;

  String _callState = 'connecting';
  int _duration = 0;
  Timer? _durationTimer;
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isVideoEnabled = false;
  int? _currentCallId;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _currentCallId = widget.callId;
    _isVideoEnabled = widget.isVideo;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _callSub = _telegramService.callStateStream.listen((event) {
      if (mounted) {
        final state = event['state'] as String? ?? '';
        final callId = event['callId'] as int?;
        if (callId != null) _currentCallId = callId;

        setState(() {
          if (state.contains('Ready') || state.contains('ready')) {
            _callState = 'active';
            _startDurationTimer();
          } else if (state.contains('Discard') ||
              state.contains('Hangup') ||
              state.contains('Error')) {
            _callState = 'ended';
            _stopDurationTimer();
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) Navigator.pop(context);
            });
          } else if (state.contains('Pending')) {
            _callState = widget.isIncoming ? 'incoming' : 'ringing';
          } else if (state.contains('Exchanging')) {
            _callState = 'connecting';
          }
        });
      }
    });

    if (!widget.isIncoming) {
      _callState = 'ringing';
      _telegramService.startCall(widget.userId, isVideo: widget.isVideo);
    } else {
      _callState = 'incoming';
    }
  }

  @override
  void dispose() {
    _callSub?.cancel();
    _durationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _duration = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _duration++);
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
  }

  void _acceptCall() {
    if (_currentCallId != null) {
      _telegramService.acceptCall(_currentCallId!);
      setState(() => _callState = 'connecting');
    }
  }

  void _endCall() {
    if (_currentCallId != null) {
      _telegramService.discardCall(_currentCallId!);
    }
    setState(() => _callState = 'ended');
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) Navigator.pop(context);
    });
  }

  void _declineCall() {
    if (_currentCallId != null) {
      _telegramService.discardCall(_currentCallId!, isDisconnected: true);
    }
    if (mounted) Navigator.pop(context);
  }

  String get _durationText {
    final m = (_duration ~/ 60).toString().padLeft(2, '0');
    final s = (_duration % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _stateText {
    switch (_callState) {
      case 'incoming':
        return widget.isVideo ? 'Incoming Video Call...' : 'Incoming Call...';
      case 'ringing':
        return 'Ringing...';
      case 'connecting':
        return 'Connecting...';
      case 'active':
        return _durationText;
      case 'ended':
        return 'Call Ended';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: SafeArea(
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1a1a2e),
                    _callState == 'active'
                        ? const Color(0xFF16213e)
                        : const Color(0xFF0f3460),
                  ],
                ),
              ),
            ),

            // Content
            Column(
              children: [
                const Spacer(flex: 2),

                // Avatar
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final scale =
                        _callState == 'ringing' || _callState == 'incoming'
                        ? _pulseAnimation.value
                        : 1.0;
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: _buildAvatar(),
                ),

                const SizedBox(height: 24),

                // Name
                Text(
                  widget.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 8),

                // State
                Text(
                  _stateText,
                  style: TextStyle(
                    color: _callState == 'active'
                        ? Colors.greenAccent
                        : Colors.white70,
                    fontSize: 16,
                  ),
                ),

                const Spacer(flex: 3),

                // Control buttons
                if (_callState == 'incoming')
                  _buildIncomingControls()
                else
                  _buildActiveControls(),

                const SizedBox(height: 48),
              ],
            ),

            // Encryption badge
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock,
                        color: Colors.white.withOpacity(0.6),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'End-to-End Encrypted',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue.shade700,
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: widget.userPhoto != null && widget.userPhoto!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                widget.userPhoto!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildInitials(),
              ),
            )
          : _buildInitials(),
    );
  }

  Widget _buildInitials() {
    final initials = widget.userName.isNotEmpty
        ? widget.userName
              .split(' ')
              .where((w) => w.isNotEmpty)
              .take(2)
              .map((w) => w[0].toUpperCase())
              .join()
        : '?';
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 48,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildIncomingControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Decline
          _buildCallButton(
            icon: Icons.call_end,
            color: Colors.red,
            label: 'Decline',
            onTap: _declineCall,
            size: 64,
          ),
          // Accept
          _buildCallButton(
            icon: widget.isVideo ? Icons.videocam : Icons.call,
            color: Colors.green,
            label: 'Accept',
            onTap: _acceptCall,
            size: 64,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveControls() {
    return Column(
      children: [
        // Secondary controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCallButton(
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              color: _isMuted ? Colors.red : Colors.white24,
              label: _isMuted ? 'Unmute' : 'Mute',
              onTap: () => setState(() => _isMuted = !_isMuted),
            ),
            _buildCallButton(
              icon: _isSpeaker ? Icons.volume_up : Icons.volume_down,
              color: _isSpeaker ? Colors.blue : Colors.white24,
              label: 'Speaker',
              onTap: () => setState(() => _isSpeaker = !_isSpeaker),
            ),
            _buildCallButton(
              icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
              color: _isVideoEnabled ? Colors.blue : Colors.white24,
              label: 'Video',
              onTap: () => setState(() => _isVideoEnabled = !_isVideoEnabled),
            ),
          ],
        ),
        const SizedBox(height: 32),
        // End call
        _buildCallButton(
          icon: Icons.call_end,
          color: Colors.red,
          label: 'End',
          onTap: _endCall,
          size: 64,
        ),
      ],
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    double size = 56,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: size * 0.45),
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
}
