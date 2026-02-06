import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:telegramflutter/pages/chat_detail_page.dart';
import 'package:telegramflutter/pages/search_page.dart';
import 'package:telegramflutter/services/telegram_service.dart';
import 'package:telegramflutter/theme/colors.dart';
import 'package:telegramflutter/widgets/media_widgets.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TelegramService _telegramService = TelegramService();
  List<TelegramChat> _chats = [];
  bool _isLoading = true;
  String _debugInfo = '';
  StreamSubscription<List<TelegramChat>>? _chatsSubscription;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    super.dispose();
  }

  void _loadChats() {
    print('ChatPage: Starting to load chats...');

    // Listen to chats stream
    _chatsSubscription = _telegramService.chatsStream.listen(
      (chats) {
        print('ChatPage: Received ${chats.length} chats from stream');
        if (mounted) {
          setState(() {
            _chats = chats;
            _isLoading = false;
            _debugInfo = 'Received ${chats.length} chats';
          });
        }
      },
      onError: (error) {
        print('ChatPage: Stream error: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _debugInfo = 'Error: $error';
          });
        }
      },
    );

    // Request to load chats
    _telegramService.loadChats(limit: 100);

    // Also get any already cached chats
    final cachedChats = _telegramService.getChats();
    print('ChatPage: Got ${cachedChats.length} cached chats');
    if (cachedChats.isNotEmpty) {
      setState(() {
        _chats = cachedChats;
        _isLoading = false;
      });
    }

    // Set a timeout to stop showing loading after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _debugInfo = 'Timeout - check console for logs';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        child: getAppBar(),
        preferredSize: Size.fromHeight(60),
      ),
      body: getBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Open new chat/contact selector
        },
        backgroundColor: Color(0xFF37AEE2),
        elevation: 4,
        child: Icon(Icons.edit, color: white, size: 26),
      ),
    );
  }

  Widget getAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: greyColor,
      title: const Text(
        'Telegram',
        style: TextStyle(
          fontSize: 22,
          color: white,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchPage()),
            );
          },
          icon: Icon(Icons.search, color: white.withOpacity(0.8), size: 26),
          tooltip: 'Search',
        ),
        IconButton(
          onPressed: () {
            _showMainMenu(context);
          },
          icon: Icon(Icons.more_vert, color: white.withOpacity(0.8), size: 26),
          tooltip: 'Menu',
        ),
      ],
    );
  }

  void _showMainMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: greyColor,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.group_add, color: Colors.white),
                title: const Text(
                  'New Group',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New group coming soon')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add, color: Colors.white),
                title: const Text(
                  'Contacts',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark, color: Colors.white),
                title: const Text(
                  'Saved Messages',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Saved messages coming soon')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.white),
                title: const Text(
                  'Settings',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget getBody() {
    return Column(
      children: [
        // Search Bar
        Container(
          decoration: BoxDecoration(
            color: greyColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: textfieldColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                style: const TextStyle(color: white, fontSize: 16),
                cursorColor: Color(0xFF37AEE2),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.search,
                    color: white.withOpacity(0.5),
                    size: 22,
                  ),
                  hintText: 'Search',
                  hintStyle: TextStyle(
                    color: white.withOpacity(0.5),
                    fontSize: 16,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
        ),
        // Chats List
        Expanded(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF37AEE2)),
                      SizedBox(height: 16),
                      Text(
                        'Loading chats...',
                        style: TextStyle(
                          color: white.withOpacity(0.6),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : _chats.isEmpty
              ? Center(
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
                        'No chats yet',
                        style: TextStyle(
                          color: white.withOpacity(0.6),
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _debugInfo.isNotEmpty
                            ? _debugInfo
                            : 'Start a conversation!',
                        style: TextStyle(
                          color: white.withOpacity(0.4),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _isLoading = true);
                          _telegramService.loadChats(limit: 100);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF37AEE2),
                        ),
                        child: Text('Retry', style: TextStyle(color: white)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    _telegramService.loadChats(limit: 100);
                  },
                  color: Color(0xFF37AEE2),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _chats.length,
                    itemBuilder: (context, index) =>
                        _buildChatItem(_chats[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildChatItem(TelegramChat chat) {
    final bool hasUnread = chat.unreadCount > 0;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailPage(
              name: chat.title,
              img: chat.photoUrl ?? '',
              chatId: chat.id,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: white.withOpacity(0.08), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasUnread
                          ? Color(0xFF37AEE2).withOpacity(0.3)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: chat.photoUrl != null && chat.photoUrl!.isNotEmpty
                        ? Image.file(
                            File(chat.photoUrl!),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildDefaultAvatar(chat.title);
                            },
                          )
                        : _buildDefaultAvatar(chat.title),
                  ),
                ),
              ],
            ),
            SizedBox(width: 12),
            // Chat Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Name
                      Expanded(
                        child: Text(
                          chat.title,
                          style: TextStyle(
                            fontSize: 16,
                            color: white,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      // Time
                      Row(
                        children: [
                          if (chat.isSentByMe)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.done_all,
                                size: 16,
                                color: chat.isRead
                                    ? Color(0xFF37AEE2)
                                    : white.withOpacity(0.5),
                              ),
                            ),
                          Text(
                            chat.lastMessageTime,
                            style: TextStyle(
                              fontSize: 13,
                              color: hasUnread
                                  ? Color(0xFF37AEE2)
                                  : white.withOpacity(0.5),
                              fontWeight: hasUnread
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      // Message preview
                      Expanded(
                        child: Text(
                          chat.lastMessage,
                          style: TextStyle(
                            fontSize: 15,
                            color: white.withOpacity(hasUnread ? 0.7 : 0.5),
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      // Unread badge
                      if (hasUnread)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF37AEE2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            chat.unreadCount > 99
                                ? '99+'
                                : chat.unreadCount.toString(),
                            style: TextStyle(
                              color: white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String title) {
    // Generate a color based on the title
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

    // Get initials
    String initials = '';
    final words = title.split(' ');
    if (words.isNotEmpty) {
      initials = words[0].isNotEmpty ? words[0][0].toUpperCase() : '';
      if (words.length > 1 && words[1].isNotEmpty) {
        initials += words[1][0].toUpperCase();
      }
    }

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: colors[colorIndex],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
