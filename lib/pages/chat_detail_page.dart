import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:telegramflutter/services/telegram_service.dart';
import 'package:telegramflutter/theme/colors.dart';
import 'package:telegramflutter/pages/profile_page.dart';
import 'package:telegramflutter/pages/media_viewer_page.dart';
import 'package:telegramflutter/widgets/media_widgets.dart';
import 'package:telegramflutter/models/user_profile.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';

class ChatDetailPage extends StatefulWidget {
  final String name;
  final String img;
  final int chatId;

  const ChatDetailPage({
    super.key,
    required this.name,
    required this.img,
    required this.chatId,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TelegramService _telegramService = TelegramService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  List<TelegramMessage> _messages = [];
  StreamSubscription<List<TelegramMessage>>? _messagesSubscription;
  StreamSubscription<FileDownloadProgress>? _fileProgressSubscription;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  String _statusText = 'last seen recently';
  bool _isOnline = false;

  // Reply state
  TelegramMessage? _replyToMessage;
  // Edit state
  TelegramMessage? _editingMessage;

  // Voice recording state
  bool _isRecording = false;
  String? _recordingPath;
  int _recordingDuration = 0;
  Timer? _recordingTimer;

  // Audio playback state
  int? _playingMessageId;
  double _playbackProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadStatus();

    // Subscribe to file download progress
    _fileProgressSubscription = _telegramService.fileDownloadProgressStream
        .listen((progress) {
          if (mounted) {
            setState(() {}); // Refresh to show updated media
          }
        });

    // Add scroll listener for loading more messages
    _scrollController.addListener(_onScroll);

    // Mark chat as read when opening
    _telegramService.markChatAsRead(widget.chatId);
  }

  void _onScroll() {
    // Load more when scrolling to the top (older messages) - since list is reversed
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _messages.isEmpty) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Get the oldest message ID to load messages before it
      final oldestMessage = _messages.last;
      final previousCount = _messages.length;

      await _telegramService.loadChatHistory(
        widget.chatId,
        limit: 50,
        fromMessageId: oldestMessage.id,
      );

      // Check if we got more messages
      await Future.delayed(Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          // If message count didn't change, no more messages
          if (_messages.length == previousCount) {
            _hasMoreMessages = false;
          }
        });
      }
    } catch (e) {
      print('Error loading more messages: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _fileProgressSubscription?.cancel();
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _loadStatus() {
    // Load online status for private chats
    final userId = _telegramService.getChatUserId(widget.chatId);
    if (userId != null) {
      _telegramService.requestUser(userId);
      setState(() {
        _statusText = _telegramService.getUserStatusText(userId);
        _isOnline = _telegramService.isUserOnline(userId);
      });
    } else {
      setState(() {
        _statusText = _telegramService.getChatSubtitle(widget.chatId);
      });
    }
  }

  void _loadMessages() {
    print('ChatDetailPage: Loading messages for chat ${widget.chatId}');

    // Subscribe to message stream for this chat
    _messagesSubscription = _telegramService
        .getMessagesStream(widget.chatId)
        .listen(
          (messages) {
            print('ChatDetailPage: Received ${messages.length} messages');
            if (mounted) {
              setState(() {
                _messages = messages;
                _isLoading = false;
              });
            }
          },
          onError: (error) {
            print('ChatDetailPage: Stream error: $error');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        );

    // Get any cached messages first
    final cachedMessages = _telegramService.getMessages(widget.chatId);
    if (cachedMessages.isNotEmpty) {
      setState(() {
        _messages = cachedMessages;
        _isLoading = false;
      });
    }

    // Request to load chat history - load more for complete history
    _telegramService.loadChatHistory(widget.chatId, limit: 100);

    // Set a timeout
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    _messageController.clear();

    try {
      if (_editingMessage != null) {
        // Edit existing message
        await _telegramService.editMessage(
          widget.chatId,
          _editingMessage!.id,
          text,
        );
        _cancelEdit();
      } else if (_replyToMessage != null) {
        // Reply to message
        await _telegramService.replyToMessage(
          widget.chatId,
          _replyToMessage!.id,
          text,
        );
        _cancelReply();
      } else {
        // Send normal message
        await _telegramService.sendMessage(widget.chatId, text);
      }

      // Scroll to bottom after sending
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _replyTo(TelegramMessage message) {
    setState(() {
      _replyToMessage = message;
      _editingMessage = null;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  void _editMessage(TelegramMessage message) {
    setState(() {
      _editingMessage = message;
      _replyToMessage = null;
      _messageController.text = message.text;
      _messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: message.text.length),
      );
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });
  }

  void _showMessageActions(TelegramMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: greyColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 16),
            // Reply
            ListTile(
              leading: Icon(Icons.reply, color: white),
              title: Text('Reply', style: TextStyle(color: white)),
              onTap: () {
                Navigator.pop(context);
                _replyTo(message);
              },
            ),
            // Copy
            ListTile(
              leading: Icon(Icons.copy, color: white),
              title: Text('Copy', style: TextStyle(color: white)),
              onTap: () {
                Navigator.pop(context);
                // Copy to clipboard
                if (message.text.isNotEmpty) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Text copied')));
                }
              },
            ),
            // Forward
            ListTile(
              leading: Icon(Icons.forward, color: white),
              title: Text('Forward', style: TextStyle(color: white)),
              onTap: () {
                Navigator.pop(context);
                _showForwardDialog(message);
              },
            ),
            // Edit (only for own messages with text)
            if (message.isOutgoing && message.text.isNotEmpty)
              ListTile(
                leading: Icon(Icons.edit, color: white),
                title: Text('Edit', style: TextStyle(color: white)),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
            // Delete
            ListTile(
              leading: Icon(Icons.delete, color: Colors.redAccent),
              title: Text('Delete', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(message);
              },
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showForwardDialog(TelegramMessage message) {
    // Get all chats to forward to
    final chats = _telegramService.chats;
    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Forward to...',
                style: TextStyle(
                  color: white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  if (chat.id == widget.chatId) return SizedBox.shrink();
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(0xFF37AEE2),
                      child: Text(
                        chat.title.isNotEmpty
                            ? chat.title[0].toUpperCase()
                            : '?',
                        style: TextStyle(color: white),
                      ),
                    ),
                    title: Text(chat.title, style: TextStyle(color: white)),
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        await _telegramService.forwardMessages(
                          widget.chatId,
                          chat.id,
                          [message.id],
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Message forwarded')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to forward')),
                          );
                        }
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(TelegramMessage message) {
    bool deleteForAll = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: greyColor,
          title: Text('Delete message', style: TextStyle(color: white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Are you sure you want to delete this message?',
                style: TextStyle(color: white.withOpacity(0.8)),
              ),
              if (message.isOutgoing)
                CheckboxListTile(
                  value: deleteForAll,
                  onChanged: (val) =>
                      setDialogState(() => deleteForAll = val ?? false),
                  title: Text(
                    'Delete for everyone',
                    style: TextStyle(color: white, fontSize: 14),
                  ),
                  activeColor: Color(0xFF37AEE2),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: white.withOpacity(0.7)),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _telegramService.deleteMessages(widget.chatId, [
                    message.id,
                  ], revokeForAll: deleteForAll);
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Message deleted')));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Failed to delete')));
                  }
                }
              },
              child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: getAppBar(),
      ),
      body: Column(
        children: [
          Expanded(child: getBody()),
          getBottomBar(),
        ],
      ),
    );
  }

  Widget getAppBar() {
    return AppBar(
      elevation: 0.5,
      backgroundColor: greyColor,
      shadowColor: Colors.black.withOpacity(0.2),
      leading: IconButton(
        onPressed: () {
          Navigator.pop(context);
        },
        icon: Icon(Icons.arrow_back, color: white, size: 26),
      ),
      title: GestureDetector(
        onTap: () {
          // Open profile page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfilePage(
                chatId: widget.chatId,
                chatTitle: widget.name,
                chatPhotoPath: widget.img.isNotEmpty ? widget.img : null,
              ),
            ),
          );
        },
        child: Row(
          children: [
            Hero(
              tag: 'avatar_${widget.chatId}',
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getAvatarColor(widget.name),
                ),
                child: Stack(
                  children: [
                    widget.img.isNotEmpty
                        ? ClipOval(
                            child: widget.img.startsWith('http')
                                ? Image.network(
                                    widget.img,
                                    fit: BoxFit.cover,
                                    width: 38,
                                    height: 38,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            _buildInitials(),
                                  )
                                : Image.file(
                                    File(widget.img),
                                    fit: BoxFit.cover,
                                    width: 38,
                                    height: 38,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            _buildInitials(),
                                  ),
                          )
                        : _buildInitials(),
                    // Online indicator
                    if (_isOnline)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: greyColor, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 16,
                      color: white,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _statusText,
                    style: TextStyle(
                      fontSize: 13,
                      color: _isOnline
                          ? Colors.lightBlueAccent
                          : white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.call, color: white.withOpacity(0.8), size: 24),
          tooltip: 'Call',
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.more_vert, color: white.withOpacity(0.8), size: 24),
          tooltip: 'More',
        ),
      ],
    );
  }

  Widget getBottomBar() {
    final hasText = _messageController.text.trim().isNotEmpty;
    final isEditing = _editingMessage != null;
    final isReplying = _replyToMessage != null;

    return Container(
      decoration: BoxDecoration(
        color: greyColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply/Edit preview bar
            if (isEditing || isReplying)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border(
                    left: BorderSide(
                      color: isEditing ? Colors.orange : Color(0xFF37AEE2),
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isEditing ? Icons.edit : Icons.reply,
                      color: isEditing ? Colors.orange : Color(0xFF37AEE2),
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing
                                ? 'Edit message'
                                : 'Reply to ${_replyToMessage!.isOutgoing ? 'yourself' : (_replyToMessage!.senderName ?? widget.name)}',
                            style: TextStyle(
                              color: isEditing
                                  ? Colors.orange
                                  : Color(0xFF37AEE2),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            isEditing
                                ? _editingMessage!.text
                                : _replyToMessage!.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: isEditing ? _cancelEdit : _cancelReply,
                      icon: Icon(Icons.close, color: white.withOpacity(0.7)),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),
            // Input area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attachment button
                  IconButton(
                    onPressed: _showAttachmentPicker,
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: white.withOpacity(0.7),
                      size: 28,
                    ),
                    padding: EdgeInsets.all(8),
                  ),
                  // Message input
                  Expanded(
                    child: Container(
                      constraints: BoxConstraints(
                        minHeight: 40,
                        maxHeight: 120,
                      ),
                      decoration: BoxDecoration(
                        color: textfieldColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: TextField(
                                controller: _messageController,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                style: TextStyle(color: white, fontSize: 16),
                                cursorColor: Color(0xFF37AEE2),
                                onChanged: (text) {
                                  setState(() {}); // Update send button icon
                                },
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: isEditing
                                      ? 'Edit message...'
                                      : 'Message',
                                  hintStyle: TextStyle(
                                    color: white.withOpacity(0.5),
                                    fontSize: 16,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Emoji button
                          IconButton(
                            onPressed: () {},
                            icon: Icon(
                              Icons.emoji_emotions_outlined,
                              color: white.withOpacity(0.7),
                              size: 24,
                            ),
                            padding: EdgeInsets.all(8),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  // Voice/Send button
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Color(0xFF37AEE2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _isSending
                          ? null
                          : (hasText ? _sendMessage : null),
                      icon: _isSending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: white,
                              ),
                            )
                          : Icon(
                              hasText ? Icons.send : Icons.mic,
                              color: white,
                              size: 24,
                            ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: greyColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAttachmentOption(
                        Icons.photo_library,
                        'Gallery',
                        Colors.purple,
                        () {
                          Navigator.pop(context);
                          _pickFromGallery();
                        },
                      ),
                      _buildAttachmentOption(
                        Icons.camera_alt,
                        'Camera',
                        Colors.redAccent,
                        () {
                          Navigator.pop(context);
                          _takePhoto();
                        },
                      ),
                      _buildAttachmentOption(
                        Icons.videocam,
                        'Video',
                        Colors.orange,
                        () {
                          Navigator.pop(context);
                          _pickVideo();
                        },
                      ),
                      _buildAttachmentOption(
                        Icons.insert_drive_file,
                        'File',
                        Colors.blue,
                        () {
                          Navigator.pop(context);
                          _pickFile();
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildAttachmentOption(
                        Icons.location_on,
                        'Location',
                        Colors.green,
                        () {
                          Navigator.pop(context);
                          _shareLocation();
                        },
                      ),
                      _buildAttachmentOption(
                        Icons.person,
                        'Contact',
                        Colors.cyan,
                        () {
                          Navigator.pop(context);
                          _shareContact();
                        },
                      ),
                      _buildAttachmentOption(
                        Icons.music_note,
                        'Audio',
                        Colors.pink,
                        () {
                          Navigator.pop(context);
                          _pickAudio();
                        },
                      ),
                      _buildAttachmentOption(
                        Icons.gif_box,
                        'GIF',
                        Colors.amber,
                        () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('GIF picker coming soon')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // MEDIA PICKING METHODS
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        _showSendMediaDialog(image.path, 'photo');
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        _showSendMediaDialog(photo.path, 'photo');
      }
    } catch (e) {
      print('Error taking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to take photo: $e')));
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );

      if (video != null) {
        _showSendMediaDialog(video.path, 'video');
      }
    } catch (e) {
      print('Error picking video: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick video: $e')));
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          _showSendMediaDialog(file.path!, 'document', fileName: file.name);
        }
      }
    } catch (e) {
      print('Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick file: $e')));
      }
    }
  }

  Future<void> _pickAudio() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          _showSendMediaDialog(file.path!, 'audio', fileName: file.name);
        }
      }
    } catch (e) {
      print('Error picking audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick audio: $e')));
      }
    }
  }

  Future<void> _shareLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location permission permanently denied. Please enable in settings.',
              ),
            ),
          );
        }
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: greyColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF37AEE2)),
                SizedBox(height: 16),
                Text('Getting location...', style: TextStyle(color: white)),
              ],
            ),
          ),
        ),
      );

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      Navigator.pop(context); // Dismiss loading

      _showLocationConfirmDialog(position.latitude, position.longitude);
    } catch (e) {
      Navigator.pop(context); // Dismiss loading if error
      print('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
      }
    }
  }

  void _showLocationConfirmDialog(double latitude, double longitude) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: greyColor,
        title: Text('Share Location', style: TextStyle(color: white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LocationMessageWidget(latitude: latitude, longitude: longitude),
            SizedBox(height: 16),
            Text(
              'Send your current location?',
              style: TextStyle(color: white.withOpacity(0.7)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: white.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _telegramService.sendLocation(
                widget.chatId,
                latitude,
                longitude,
                replyToMessageId: _replyToMessage?.id,
              );
              _clearReply();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF37AEE2)),
            child: Text('Send', style: TextStyle(color: white)),
          ),
        ],
      ),
    );
  }

  void _shareContact() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: greyColor,
        title: Text('Share Contact', style: TextStyle(color: white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(color: white),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: white.withOpacity(0.7)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: white.withOpacity(0.3)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF37AEE2)),
                ),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: phoneController,
              style: TextStyle(color: white),
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                labelStyle: TextStyle(color: white.withOpacity(0.7)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: white.withOpacity(0.3)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF37AEE2)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: white.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  phoneController.text.isNotEmpty) {
                Navigator.pop(context);
                _telegramService.sendContact(
                  widget.chatId,
                  phoneController.text,
                  nameController.text,
                  replyToMessageId: _replyToMessage?.id,
                );
                _clearReply();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF37AEE2)),
            child: Text('Send', style: TextStyle(color: white)),
          ),
        ],
      ),
    );
  }

  void _showSendMediaDialog(String filePath, String type, {String? fileName}) {
    final captionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: greyColor,
        title: Text(
          'Send ${type.capitalize()}',
          style: TextStyle(color: white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type == 'photo')
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(filePath),
                  height: 200,
                  fit: BoxFit.cover,
                ),
              )
            else if (type == 'video')
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam, color: Colors.white54, size: 48),
                      SizedBox(height: 8),
                      Text(
                        fileName ?? filePath.split('/').last,
                        style: TextStyle(
                          color: white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(_getFileIcon(type), color: Colors.white54, size: 40),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        fileName ?? filePath.split('/').last,
                        style: TextStyle(color: white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 16),
            TextField(
              controller: captionController,
              style: TextStyle(color: white),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Add a caption...',
                hintStyle: TextStyle(color: white.withOpacity(0.5)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: white.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF37AEE2)),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: white.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendMedia(filePath, type, captionController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF37AEE2)),
            child: Text('Send', style: TextStyle(color: white)),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String type) {
    switch (type) {
      case 'photo':
        return Icons.photo;
      case 'video':
        return Icons.videocam;
      case 'audio':
        return Icons.music_note;
      case 'document':
      default:
        return Icons.insert_drive_file;
    }
  }

  void _sendMedia(String filePath, String type, String caption) {
    final replyId = _replyToMessage?.id;
    _clearReply();

    switch (type) {
      case 'photo':
        _telegramService.sendPhoto(
          widget.chatId,
          filePath,
          caption: caption.isNotEmpty ? caption : null,
          replyToMessageId: replyId,
        );
        break;
      case 'video':
        _telegramService.sendVideo(
          widget.chatId,
          filePath,
          caption: caption.isNotEmpty ? caption : null,
          replyToMessageId: replyId,
        );
        break;
      case 'audio':
      case 'document':
        _telegramService.sendDocument(
          widget.chatId,
          filePath,
          caption: caption.isNotEmpty ? caption : null,
          replyToMessageId: replyId,
        );
        break;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // VOICE RECORDING METHODS
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path =
            '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordingPath = path;
          _recordingDuration = 0;
        });

        _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration++;
          });
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Microphone permission denied')));
      }
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start recording: $e')));
    }
  }

  Future<void> _stopRecording({bool send = true}) async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();

      if (send && path != null && _recordingDuration > 0) {
        await _telegramService.sendVoiceNote(
          widget.chatId,
          path,
          duration: _recordingDuration,
          replyToMessageId: _replyToMessage?.id,
        );
        _clearReply();
      }

      setState(() {
        _isRecording = false;
        _recordingPath = null;
        _recordingDuration = 0;
      });
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  void _cancelRecording() {
    _stopRecording(send: false);
  }

  String _formatRecordingDuration() {
    final minutes = _recordingDuration ~/ 60;
    final seconds = _recordingDuration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ════════════════════════════════════════════════════════════════════════
  // AUDIO PLAYBACK METHODS
  // ════════════════════════════════════════════════════════════════════════

  Future<void> _playAudio(int messageId, String path) async {
    try {
      // Use system audio player via open_file
      final result = await OpenFile.open(path);
      if (result.type != ResultType.done) {
        print('Error playing audio: ${result.message}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not play audio: ${result.message}')),
          );
        }
      }
    } catch (e) {
      print('Error playing audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error playing audio')));
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // MEDIA VIEWING METHODS
  // ════════════════════════════════════════════════════════════════════════

  void _viewPhoto(TelegramMessage message) {
    final mediaInfo = message.mediaInfo;
    if (mediaInfo == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewerPage(
          localPath: mediaInfo['localPath'] as String?,
          fileId: mediaInfo['fileId'] as int?,
          caption: mediaInfo['caption'] as String?,
        ),
      ),
    );
  }

  void _viewVideo(TelegramMessage message) {
    final mediaInfo = message.mediaInfo;
    if (mediaInfo == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(
          localPath: mediaInfo['localPath'] as String?,
          fileId: mediaInfo['fileId'] as int?,
          caption: mediaInfo['caption'] as String?,
        ),
      ),
    );
  }

  void _downloadMedia(TelegramMessage message) {
    final mediaInfo = message.mediaInfo;
    if (mediaInfo == null) return;

    final fileId = mediaInfo['fileId'] as int?;
    if (fileId != null) {
      _telegramService.downloadMediaFile(fileId, priority: 16);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download started...')));
    }
  }

  void _openDocument(TelegramMessage message) async {
    final mediaInfo = message.mediaInfo;
    if (mediaInfo == null) return;

    final localPath = mediaInfo['localPath'] as String?;
    if (localPath != null) {
      try {
        await OpenFile.open(localPath);
      } catch (e) {
        print('Error opening file: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cannot open file: $e')));
      }
    } else {
      _downloadMedia(message);
    }
  }

  void _openLocation(double latitude, double longitude) async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Error opening maps: $e');
    }
  }

  void _clearReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  Widget _buildAttachmentOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: white.withOpacity(0.8), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget getBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF37AEE2)),
            SizedBox(height: 16),
            Text(
              'Loading messages...',
              style: TextStyle(color: white.withOpacity(0.6)),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: white.withOpacity(0.3),
            ),
            SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(color: white.withOpacity(0.6), fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Send a message to start the conversation',
              style: TextStyle(color: white.withOpacity(0.4), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Show newest messages at the bottom
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the end (top of reversed list)
        if (_isLoadingMore && index == _messages.length) {
          return Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF37AEE2),
                ),
              ),
            ),
          );
        }

        final message = _messages[index];
        final isLast =
            index == 0 || _messages[index - 1].isOutgoing != message.isOutgoing;

        return _buildMessageBubble(message, isLast);
      },
    );
  }

  Widget _buildMessageBubble(TelegramMessage message, bool isLast) {
    final isMe = message.isOutgoing;
    final hasMedia = message.mediaInfo != null;
    final mediaType = message.contentType;

    return GestureDetector(
      onLongPress: () => _showMessageActions(message),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe && isLast) SizedBox(width: 4),
            if (!isMe && !isLast) SizedBox(width: 38),
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: hasMedia
                    ? EdgeInsets.all(4)
                    : EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isMe ? Color(0xFF2B5278) : greyColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isMe ? 18 : (isLast ? 4 : 18)),
                    topRight: Radius.circular(isMe ? (isLast ? 4 : 18) : 18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // Show sender name for group chats (if not outgoing)
                    if (!isMe &&
                        message.senderName != null &&
                        message.senderName!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: 4,
                          left: hasMedia ? 8 : 0,
                        ),
                        child: Text(
                          message.senderName!,
                          style: TextStyle(
                            fontSize: 13,
                            color: _getSenderColor(message.senderId),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    // Media content
                    if (hasMedia) _buildMediaContent(message),
                    // Message text (if any)
                    if (!hasMedia ||
                        (message.text.isNotEmpty &&
                            !message.text.startsWith('📷') &&
                            !message.text.startsWith('🎥') &&
                            !message.text.startsWith('🎤') &&
                            !message.text.startsWith('📎') &&
                            !message.text.startsWith('📹') &&
                            !message.text.startsWith('🎨')))
                      Padding(
                        padding: hasMedia ? EdgeInsets.all(8) : EdgeInsets.zero,
                        child: Text(
                          _getDisplayText(message),
                          style: TextStyle(
                            fontSize: 16,
                            color: white,
                            height: 1.3,
                          ),
                        ),
                      ),
                    SizedBox(height: 4),
                    // Time and status
                    Padding(
                      padding: hasMedia
                          ? EdgeInsets.only(right: 8, bottom: 4)
                          : EdgeInsets.zero,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.time,
                            style: TextStyle(
                              fontSize: 12,
                              color: white.withOpacity(0.6),
                            ),
                          ),
                          if (isMe) ...[
                            SizedBox(width: 4),
                            _buildMessageStatus(message.status),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isMe && isLast) SizedBox(width: 4),
            if (isMe && !isLast) SizedBox(width: 38),
          ],
        ),
      ),
    );
  }

  String _getDisplayText(TelegramMessage message) {
    // Remove media indicators from text if we're showing actual media
    if (message.mediaInfo != null) {
      return message.text
          .replaceFirst(RegExp(r'^📷\s*'), '')
          .replaceFirst(RegExp(r'^🎥\s*'), '')
          .replaceFirst(RegExp(r'^🎤\s*'), '')
          .replaceFirst(RegExp(r'^📎\s*'), '')
          .replaceFirst(RegExp(r'^📹\s*'), '')
          .replaceFirst(RegExp(r'^🎨\s*'), '')
          .replaceFirst('Photo', '')
          .replaceFirst('Video', '')
          .replaceFirst('Voice message', '')
          .replaceFirst('Video message', '')
          .replaceFirst('Document', '')
          .replaceFirst('Sticker', '')
          .trim();
    }
    return message.text;
  }

  Widget _buildMediaContent(TelegramMessage message) {
    final media = message.mediaInfo;
    if (media == null) return SizedBox.shrink();

    final type = media['type'] as String? ?? '';
    final fileId = media['fileId'] as int?;
    final localPath = media['localPath'] as String?;
    final isDownloaded = media['isDownloaded'] as bool? ?? false;
    final thumbnailPath = media['thumbnailPath'] as String?;

    // Build MediaInfo object
    final mediaInfo = MediaInfo(
      type: _getMediaType(type),
      fileId: fileId,
      localPath: localPath,
      width: media['width'] as int?,
      height: media['height'] as int?,
      duration: media['duration'] as int?,
      fileSize: media['fileSize'] as int?,
      caption: media['caption'] as String?,
      thumbnailPath: thumbnailPath,
      isDownloaded: isDownloaded,
      isDownloading: fileId != null
          ? (_telegramService.getFileDownloadState(fileId)?.isDownloading ??
                false)
          : false,
      downloadProgress: fileId != null
          ? (_telegramService.getFileDownloadState(fileId)?.progress ?? 0.0)
          : 0.0,
    );

    switch (type) {
      case 'photo':
        return PhotoMessageWidget(
          mediaInfo: mediaInfo,
          onTap: isDownloaded && localPath != null
              ? () => _viewPhoto(message)
              : null,
          onDownload: fileId != null ? () => _downloadMedia(message) : null,
        );
      case 'video':
        return VideoMessageWidget(
          mediaInfo: mediaInfo,
          onTap: isDownloaded && localPath != null
              ? () => _viewVideo(message)
              : null,
          onDownload: fileId != null ? () => _downloadMedia(message) : null,
        );
      case 'voiceNote':
      case 'audio':
        return VoiceNoteWidget(
          mediaInfo: mediaInfo,
          onPlayPause: () {
            if (isDownloaded && localPath != null) {
              _playAudio(message.id, localPath);
            } else if (!isDownloaded && fileId != null) {
              _downloadMedia(message);
            }
          },
          onDownload: fileId != null ? () => _downloadMedia(message) : null,
          isPlaying: _playingMessageId == message.id,
          playbackProgress: _playingMessageId == message.id
              ? _playbackProgress
              : 0.0,
        );
      case 'videoNote':
        return VideoMessageWidget(
          mediaInfo: mediaInfo,
          onTap: isDownloaded ? () => _openMedia(localPath) : null,
          onDownload: fileId != null ? () => _downloadMedia(message) : null,
        );
      case 'document':
        final fileName = media['fileName'] as String? ?? 'Document';
        return DocumentWidget(
          mediaInfo: mediaInfo,
          fileName: fileName,
          onTap: isDownloaded ? () => _openDocument(message) : null,
          onDownload: fileId != null ? () => _downloadMedia(message) : null,
        );
      case 'sticker':
        return StickerWidget(mediaInfo: mediaInfo, onTap: () {});
      case 'animation':
        return VideoMessageWidget(
          mediaInfo: mediaInfo,
          onTap: isDownloaded ? () => _viewVideo(message) : null,
          onDownload: fileId != null ? () => _downloadMedia(message) : null,
        );
      case 'location':
        final latitude = media['latitude'] as double? ?? 0.0;
        final longitude = media['longitude'] as double? ?? 0.0;
        return LocationMessageWidget(
          latitude: latitude,
          longitude: longitude,
          onTap: () => _openLocation(latitude, longitude),
        );
      case 'contact':
        final firstName = media['firstName'] as String? ?? '';
        final lastName = media['lastName'] as String? ?? '';
        final phoneNumber = media['phoneNumber'] as String? ?? '';
        return ContactMessageWidget(
          firstName: firstName,
          lastName: lastName,
          phoneNumber: phoneNumber,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Adding contact: $firstName $lastName')),
            );
          },
        );
      default:
        // Show text for unsupported media types
        return SizedBox.shrink();
    }
  }

  MediaType _getMediaType(String type) {
    switch (type) {
      case 'photo':
        return MediaType.photo;
      case 'video':
        return MediaType.video;
      case 'voiceNote':
        return MediaType.voiceNote;
      case 'videoNote':
        return MediaType.videoNote;
      case 'document':
        return MediaType.document;
      case 'sticker':
        return MediaType.sticker;
      case 'animation':
        return MediaType.animation;
      case 'audio':
        return MediaType.audio;
      case 'location':
        return MediaType.location;
      case 'contact':
        return MediaType.contact;
      default:
        return MediaType.unknown;
    }
  }

  void _downloadMediaByFileId(int fileId) {
    print('Downloading file: $fileId');
    _telegramService.downloadFileWithProgress(fileId);
  }

  void _openMedia(String? path) {
    if (path == null || path.isEmpty) return;
    // TODO: Open media in full screen viewer
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Opening: $path')));
  }

  Widget _buildMessageStatus(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: white.withOpacity(0.6),
          ),
        );
      case MessageStatus.sent:
        return Icon(Icons.done, size: 16, color: white.withOpacity(0.6));
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 16, color: white.withOpacity(0.6));
      case MessageStatus.read:
        return Icon(
          Icons.done_all,
          size: 16,
          color: Color(0xFF37AEE2), // Blue for read
        );
      case MessageStatus.failed:
        return Icon(Icons.error_outline, size: 16, color: Colors.red);
    }
  }

  Color _getSenderColor(int senderId) {
    final colors = [
      Color(0xFFE17076),
      Color(0xFF7BC862),
      Color(0xFFE5A64E),
      Color(0xFF65AADD),
      Color(0xFFEE7AAE),
      Color(0xFF6EC9CB),
      Color(0xFF9B87D3),
      Color(0xFFF5A547),
    ];
    return colors[senderId.abs() % colors.length];
  }

  Widget _buildInitials() {
    String initials = '';
    final words = widget.name.split(' ');
    if (words.isNotEmpty) {
      initials = words[0].isNotEmpty ? words[0][0].toUpperCase() : '';
      if (words.length > 1 && words[1].isNotEmpty) {
        initials += words[1][0].toUpperCase();
      }
    }
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getAvatarColor(String title) {
    final colors = [
      Color(0xFFE17076),
      Color(0xFF7BC862),
      Color(0xFFE5A64E),
      Color(0xFF65AADD),
      Color(0xFFEE7AAE),
      Color(0xFF6EC9CB),
      Color(0xFF9B87D3),
      Color(0xFFF5A547),
    ];
    final colorIndex = title.isNotEmpty
        ? title.codeUnitAt(0) % colors.length
        : 0;
    return colors[colorIndex];
  }
}

/// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
