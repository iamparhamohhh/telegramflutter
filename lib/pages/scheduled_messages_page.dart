import 'dart:async';
import 'package:flutter/material.dart';
import '../services/telegram_service.dart';
import '../theme/colors.dart';

/// Page to view and manage scheduled messages for a chat
class ScheduledMessagesPage extends StatefulWidget {
  final int chatId;
  final String chatTitle;

  const ScheduledMessagesPage({
    super.key,
    required this.chatId,
    required this.chatTitle,
  });

  @override
  State<ScheduledMessagesPage> createState() => _ScheduledMessagesPageState();
}

class _ScheduledMessagesPageState extends State<ScheduledMessagesPage> {
  final TelegramService _telegramService = TelegramService();
  StreamSubscription<List<TelegramMessage>>? _subscription;
  List<TelegramMessage> _messages = [];
  bool _isLoading = true;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _subscription = _telegramService.scheduledMessagesStream.listen((msgs) {
      if (mounted) {
        setState(() {
          _messages = msgs;
          _isLoading = false;
        });
      }
    });
    _telegramService.loadScheduledMessages(widget.chatId);
    // Fallback timeout
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  bool get _hasSelection => _selectedIds.isNotEmpty;

  void _toggleSelection(int messageId) {
    setState(() {
      if (_selectedIds.contains(messageId)) {
        _selectedIds.remove(messageId);
      } else {
        _selectedIds.add(messageId);
      }
    });
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

  Future<void> _sendNow() async {
    if (_selectedIds.isEmpty) return;
    await _telegramService.sendScheduledMessagesNow(
      widget.chatId,
      _selectedIds.toList(),
    );
    _clearSelection();
    _telegramService.loadScheduledMessages(widget.chatId);
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surface,
        title: const Text(
          'Delete Scheduled Messages',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Delete ${_selectedIds.length} scheduled message(s)?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _telegramService.deleteScheduledMessages(
        widget.chatId,
        _selectedIds.toList(),
      );
      _clearSelection();
      _telegramService.loadScheduledMessages(widget.chatId);
    }
  }

  Future<void> _rescheduleMessage(TelegramMessage msg) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.blue),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.blue),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    final newDate = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final timestamp = newDate.millisecondsSinceEpoch ~/ 1000;
    await _telegramService.editScheduledMessageDate(
      widget.chatId,
      msg.id,
      timestamp,
    );
    _telegramService.loadScheduledMessages(widget.chatId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.appBarBg,
        leading: _hasSelection
            ? IconButton(
                icon: Icon(Icons.close, color: context.appBarText),
                onPressed: _clearSelection,
              )
            : IconButton(
                icon: Icon(Icons.arrow_back, color: context.appBarText),
                onPressed: () => Navigator.pop(context),
              ),
        title: _hasSelection
            ? Text(
                '${_selectedIds.length} selected',
                style: TextStyle(color: context.appBarText),
              )
            : Text(
                'Scheduled Messages',
                style: TextStyle(color: context.appBarText),
              ),
        actions: _hasSelection
            ? [
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  tooltip: 'Send Now',
                  onPressed: _sendNow,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: _deleteSelected,
                ),
              ]
            : [],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
          ? _buildEmptyState()
          : _buildMessagesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, color: Colors.white24, size: 72),
          const SizedBox(height: 16),
          const Text(
            'No Scheduled Messages',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Schedule messages from the chat to send later',
            style: TextStyle(color: Colors.white.withOpacity(0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isSelected = _selectedIds.contains(msg.id);
        return _buildMessageTile(msg, isSelected);
      },
    );
  }

  Widget _buildMessageTile(TelegramMessage msg, bool isSelected) {
    final scheduledDate = msg.date > 0
        ? DateTime.fromMillisecondsSinceEpoch(msg.date * 1000)
        : null;

    return Container(
      color: isSelected ? Colors.blue.withOpacity(0.15) : null,
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_getMessageIcon(msg), color: Colors.blue, size: 22),
        ),
        title: Text(
          _getMessagePreview(msg),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: scheduledDate != null
            ? Text(
                'Scheduled: ${_formatDate(scheduledDate)}',
                style: const TextStyle(color: Colors.blue, fontSize: 12),
              )
            : null,
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Colors.blue)
            : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white54),
                color: context.surface,
                onSelected: (action) {
                  switch (action) {
                    case 'send_now':
                      _telegramService.sendScheduledMessagesNow(widget.chatId, [
                        msg.id,
                      ]);
                      _telegramService.loadScheduledMessages(widget.chatId);
                      break;
                    case 'reschedule':
                      _rescheduleMessage(msg);
                      break;
                    case 'delete':
                      _telegramService.deleteScheduledMessages(widget.chatId, [
                        msg.id,
                      ]);
                      _telegramService.loadScheduledMessages(widget.chatId);
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'send_now',
                    child: Row(
                      children: [
                        Icon(Icons.send, color: Colors.blue, size: 20),
                        SizedBox(width: 12),
                        Text('Send Now', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'reschedule',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_calendar,
                          color: Colors.orange,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Reschedule',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Text('Delete', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
        onTap: () => _toggleSelection(msg.id),
        onLongPress: () => _toggleSelection(msg.id),
      ),
    );
  }

  IconData _getMessageIcon(TelegramMessage msg) {
    final type = msg.contentType;
    if (type.contains('Photo')) return Icons.photo;
    if (type.contains('Video')) return Icons.videocam;
    if (type.contains('Audio')) return Icons.audiotrack;
    if (type.contains('Voice')) return Icons.mic;
    if (type.contains('Document')) return Icons.insert_drive_file;
    if (type.contains('Sticker')) return Icons.emoji_emotions;
    if (type.contains('Poll')) return Icons.poll;
    if (type.contains('Location')) return Icons.location_on;
    if (type.contains('Contact')) return Icons.person;
    return Icons.message;
  }

  String _getMessagePreview(TelegramMessage msg) {
    if (msg.text.isNotEmpty) return msg.text;
    final type = msg.contentType;
    if (type.contains('Photo')) return '📷 Photo';
    if (type.contains('Video')) return '🎬 Video';
    if (type.contains('Audio')) return '🎵 Audio';
    if (type.contains('Voice')) return '🎤 Voice Message';
    if (type.contains('Document')) return '📎 Document';
    if (type.contains('Sticker')) return '😀 Sticker';
    if (type.contains('Poll')) return '📊 Poll';
    if (type.contains('Location')) return '📍 Location';
    if (type.contains('Contact')) return '👤 Contact';
    return 'Message';
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $h:$m';
  }
}
