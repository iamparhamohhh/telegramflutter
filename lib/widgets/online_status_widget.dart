import 'dart:async';
import 'package:flutter/material.dart';
import 'package:telegramflutter/services/telegram_service.dart';

/// A widget that displays a user's online status with a colored dot indicator.
/// It periodically refreshes the status to keep it up to date.
class OnlineStatusIndicator extends StatefulWidget {
  final int userId;
  final double size;
  final bool showText;
  final TextStyle? textStyle;

  const OnlineStatusIndicator({
    super.key,
    required this.userId,
    this.size = 10,
    this.showText = false,
    this.textStyle,
  });

  @override
  State<OnlineStatusIndicator> createState() => _OnlineStatusIndicatorState();
}

class _OnlineStatusIndicatorState extends State<OnlineStatusIndicator> {
  final _telegramService = TelegramService();
  Timer? _refreshTimer;
  bool _isOnline = false;
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _updateStatus();
    // Refresh every 30 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateStatus(),
    );
  }

  void _updateStatus() {
    if (mounted) {
      setState(() {
        _isOnline = _telegramService.isUserOnline(widget.userId);
        _statusText = _telegramService.getUserStatusText(widget.userId);
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showText) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDot(),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _isOnline ? 'online' : _statusText,
              style:
                  widget.textStyle ??
                  TextStyle(
                    color: _isOnline ? Colors.green : Colors.white54,
                    fontSize: 13,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    return _buildDot();
  }

  Widget _buildDot() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _isOnline ? Colors.green : Colors.grey.shade600,
        boxShadow: _isOnline
            ? [
                BoxShadow(
                  color: Colors.green.withOpacity(0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

/// A badge-style online indicator to overlay on avatars.
class OnlineStatusBadge extends StatelessWidget {
  final int userId;
  final Widget child;
  final double badgeSize;

  const OnlineStatusBadge({
    super.key,
    required this.userId,
    required this.child,
    this.badgeSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline = TelegramService().isUserOnline(userId);

    return Stack(
      children: [
        child,
        if (isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF010101), width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
