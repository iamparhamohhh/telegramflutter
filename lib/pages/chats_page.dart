import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:telegramflutter/pages/chat_detail_page.dart';
import 'package:telegramflutter/pages/search_page.dart';
import 'package:telegramflutter/pages/new_chat_page.dart';
import 'package:telegramflutter/pages/new_group_page.dart';
import 'package:telegramflutter/pages/new_channel_page.dart';
import 'package:telegramflutter/pages/chat_folders_page.dart';
import 'package:telegramflutter/services/telegram_service.dart';
import 'package:telegramflutter/theme/colors.dart';
import 'package:telegramflutter/widgets/media_widgets.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with SingleTickerProviderStateMixin {
  final TelegramService _telegramService = TelegramService();
  List<TelegramChat> _chats = [];
  List<TelegramChat> _archivedChats = [];
  List<TelegramChatFolder> _folders = [];
  bool _isLoading = true;
  String _debugInfo = '';
  bool _showArchived = false;
  int _selectedFolderIndex = 0; // 0 = All Chats
  StreamSubscription<List<TelegramChat>>? _chatsSubscription;
  StreamSubscription<List<TelegramChat>>? _archivedChatsSubscription;
  StreamSubscription<List<TelegramChatFolder>>? _foldersSubscription;
  TabController? _tabController;

  // Track pinned/muted state locally for UI feedback
  final Map<int, bool> _pinnedChats = {};
  final Map<int, bool> _mutedChats = {};

  @override
  void initState() {
    super.initState();
    _loadChats();
    _loadFolders();
    _loadArchivedChats();
  }

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    _archivedChatsSubscription?.cancel();
    _foldersSubscription?.cancel();
    _tabController?.dispose();
    super.dispose();
  }

  void _loadFolders() {
    _foldersSubscription = _telegramService.chatFoldersStream.listen((folders) {
      if (mounted) {
        setState(() {
          _folders = folders;
          _updateTabController();
        });
      }
    });
    _telegramService.loadChatFolders();
  }

  void _updateTabController() {
    _tabController?.dispose();
    if (_folders.isNotEmpty) {
      _tabController = TabController(
        length: _folders.length + 1, // +1 for "All Chats"
        vsync: this,
        initialIndex: _selectedFolderIndex.clamp(0, _folders.length),
      );
      _tabController!.addListener(() {
        if (!_tabController!.indexIsChanging) {
          setState(() {
            _selectedFolderIndex = _tabController!.index;
          });
          if (_tabController!.index > 0) {
            _telegramService.loadChatsForFolder(
              _folders[_tabController!.index - 1].id,
            );
          }
        }
      });
    }
  }

  void _loadArchivedChats() {
    _archivedChatsSubscription = _telegramService.archivedChatsStream.listen((
      chats,
    ) {
      if (mounted) {
        setState(() {
          _archivedChats = chats;
        });
      }
    });
    _telegramService.loadArchivedChats();
  }

  void _loadChats() {
    // Listen to chats stream
    _chatsSubscription = _telegramService.chatsStream.listen(
      (chats) {
        if (mounted) {
          setState(() {
            _chats = chats;
            _isLoading = false;
            _debugInfo = 'Received ${chats.length} chats';
          });
        }
      },
      onError: (error) {
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
        preferredSize: Size.fromHeight(_folders.isNotEmpty ? 108 : 60),
      ),
      body: _showArchived ? _buildArchivedBody() : getBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewChatPage()),
          );
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
      title: Text(
        _showArchived ? 'Archived Chats' : 'Telegram',
        style: TextStyle(
          fontSize: 22,
          color: white,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      leading: _showArchived
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: white),
              onPressed: () => setState(() => _showArchived = false),
            )
          : null,
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
      bottom: _folders.isNotEmpty && !_showArchived
          ? TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: [
                const Tab(text: 'All Chats'),
                ..._folders.map((f) => Tab(text: f.title)),
              ],
            )
          : null,
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
                leading: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                ),
                title: const Text(
                  'New Chat',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NewChatPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_add, color: Colors.white),
                title: const Text(
                  'New Group',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NewGroupPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.campaign, color: Colors.white),
                title: const Text(
                  'New Channel',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NewChannelPage()),
                  );
                },
              ),
              const Divider(color: Colors.grey),
              ListTile(
                leading: const Icon(Icons.folder_outlined, color: Colors.white),
                title: const Text(
                  'Chat Folders',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatFoldersPage()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.archive_outlined,
                  color: Colors.white,
                ),
                title: Row(
                  children: [
                    const Text(
                      'Archived Chats',
                      style: TextStyle(color: Colors.white),
                    ),
                    if (_archivedChats.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_archivedChats.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _showArchived = true);
                },
              ),
              const Divider(color: Colors.grey),
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

  Widget _buildArchivedBody() {
    if (_archivedChats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.archive_outlined,
              size: 64,
              color: white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No archived chats',
              style: TextStyle(color: white.withOpacity(0.6), fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _archivedChats.length,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      cacheExtent: 500,
      itemBuilder: (context, index) {
        final chat = _archivedChats[index];
        return RepaintBoundary(
          key: ValueKey('archived_${chat.id}'),
          child: _buildChatItem(chat, isArchived: true),
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
                    // Performance optimizations
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    cacheExtent: 500, // Pre-cache items
                    itemBuilder: (context, index) {
                      final chat = _chats[index];
                      return RepaintBoundary(
                        key: ValueKey('chat_repaint_${chat.id}'),
                        child: _buildChatItem(chat),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  void _showChatActions(TelegramChat chat, {bool isArchived = false}) {
    final isPinned = _pinnedChats[chat.id] ?? false;
    final isMuted = _mutedChats[chat.id] ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: greyColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with chat info
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildDefaultAvatar(chat.title),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        chat.title,
                        style: const TextStyle(
                          color: white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.grey, height: 1),

              // Actions
              if (!isArchived)
                ListTile(
                  leading: Icon(
                    isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                    color: Colors.white,
                  ),
                  title: Text(
                    isPinned ? 'Unpin' : 'Pin',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _telegramService.toggleChatPinned(chat.id, !isPinned);
                    setState(() => _pinnedChats[chat.id] = !isPinned);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isPinned ? 'Chat unpinned' : 'Chat pinned',
                        ),
                      ),
                    );
                  },
                ),

              ListTile(
                leading: Icon(
                  isMuted ? Icons.notifications : Icons.notifications_off,
                  color: Colors.white,
                ),
                title: Text(
                  isMuted ? 'Unmute' : 'Mute',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _telegramService.setChatMuted(chat.id, !isMuted);
                  setState(() => _mutedChats[chat.id] = !isMuted);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isMuted
                            ? 'Notifications unmuted'
                            : 'Notifications muted',
                      ),
                    ),
                  );
                },
              ),

              ListTile(
                leading: Icon(
                  isArchived ? Icons.unarchive : Icons.archive,
                  color: Colors.white,
                ),
                title: Text(
                  isArchived ? 'Unarchive' : 'Archive',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _telegramService.archiveChat(chat.id, !isArchived);
                  if (isArchived) {
                    setState(() {
                      _archivedChats.removeWhere((c) => c.id == chat.id);
                    });
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isArchived ? 'Chat unarchived' : 'Chat archived',
                      ),
                    ),
                  );
                },
              ),

              if (_folders.isNotEmpty && !isArchived)
                ListTile(
                  leading: const Icon(
                    Icons.folder_outlined,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Add to Folder',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddToFolderDialog(chat);
                  },
                ),

              ListTile(
                leading: const Icon(Icons.mark_chat_read, color: Colors.white),
                title: const Text(
                  'Mark as Read',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _telegramService.markChatAsRead(chat.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Marked as read')),
                  );
                },
              ),

              const Divider(color: Colors.grey, height: 1),

              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete Chat',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteChat(chat);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddToFolderDialog(TelegramChat chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: greyColor,
        title: const Text(
          'Add to Folder',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _folders.map((folder) {
            return ListTile(
              leading: const Icon(Icons.folder, color: Colors.blue),
              title: Text(
                folder.title,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await _telegramService.addChatToFolder(chat.id, folder.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added to ${folder.title}')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteChat(TelegramChat chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: greyColor,
        title: const Text('Delete Chat', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${chat.title}"? This action cannot be undone.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _telegramService.deleteChat(chat.id);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Chat deleted')));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(TelegramChat chat, {bool isArchived = false}) {
    final bool hasUnread = chat.unreadCount > 0;
    final bool isPinned = _pinnedChats[chat.id] ?? false;
    final bool isMuted = _mutedChats[chat.id] ?? false;

    // Use a simple InkWell instead of heavy Dismissible for better performance
    // Swipe actions are available via long-press menu
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatDetailPage(chat: chat)),
        );
      },
      onLongPress: () => _showChatActions(chat, isArchived: isArchived),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: white.withOpacity(0.08), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Avatar - cached
            _ChatAvatar(
              photoUrl: chat.photoUrl,
              title: chat.title,
              hasUnread: hasUnread,
            ),
            const SizedBox(width: 12),
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
                      const SizedBox(width: 8),
                      // Time
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (chat.isSentByMe)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.done_all,
                                size: 16,
                                color: chat.isRead
                                    ? const Color(0xFF37AEE2)
                                    : white.withOpacity(0.5),
                              ),
                            ),
                          Text(
                            chat.lastMessageTime,
                            style: TextStyle(
                              fontSize: 13,
                              color: hasUnread
                                  ? const Color(0xFF37AEE2)
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
                  const SizedBox(height: 4),
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
                      const SizedBox(width: 8),
                      // Status icons (pinned, muted)
                      if (isPinned)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.push_pin,
                            size: 16,
                            color: white.withOpacity(0.5),
                          ),
                        ),
                      if (isMuted)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.notifications_off,
                            size: 16,
                            color: white.withOpacity(0.5),
                          ),
                        ),
                      // Unread badge
                      if (hasUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isMuted
                                ? Colors.grey
                                : const Color(0xFF37AEE2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            chat.unreadCount > 99
                                ? '99+'
                                : chat.unreadCount.toString(),
                            style: const TextStyle(
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
      const Color(0xFFE17076),
      const Color(0xFF7BC862),
      const Color(0xFFE5A64E),
      const Color(0xFF65AADD),
      const Color(0xFFEE7AAE),
      const Color(0xFF6EC9CB),
      const Color(0xFF9B87D3),
      const Color(0xFFF5A547),
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
          style: const TextStyle(
            color: white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Optimized avatar widget with caching
class _ChatAvatar extends StatelessWidget {
  final String? photoUrl;
  final String title;
  final bool hasUnread;

  const _ChatAvatar({
    required this.photoUrl,
    required this.title,
    required this.hasUnread,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: hasUnread
              ? const Color(0xFF37AEE2).withOpacity(0.3)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: photoUrl != null && photoUrl!.isNotEmpty
            ? Image.file(
                File(photoUrl!),
                fit: BoxFit.cover,
                cacheWidth: 116, // 58 * 2 for retina
                cacheHeight: 116,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultAvatar();
                },
              )
            : _buildDefaultAvatar(),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    final colors = [
      const Color(0xFFE17076),
      const Color(0xFF7BC862),
      const Color(0xFFE5A64E),
      const Color(0xFF65AADD),
      const Color(0xFFEE7AAE),
      const Color(0xFF6EC9CB),
      const Color(0xFF9B87D3),
      const Color(0xFFF5A547),
    ];
    final colorIndex = title.isNotEmpty
        ? title.codeUnitAt(0) % colors.length
        : 0;

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
          style: const TextStyle(
            color: white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
