import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:telegramflutter/pages/chat_detail_page.dart';
import 'package:telegramflutter/services/telegram_service.dart';
import 'package:telegramflutter/theme/colors.dart';
import 'package:telegramflutter/widgets/media_widgets.dart';

/// Global search page for chats and messages
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  final TelegramService _telegramService = TelegramService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late TabController _tabController;
  List<TelegramChat> _chatResults = [];
  List<TelegramMessage> _messageResults = [];
  StreamSubscription<List<TelegramChat>>? _searchSubscription;

  bool _isSearching = false;
  String _query = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Subscribe to search results
    _searchSubscription = _telegramService.searchResultsStream.listen((chats) {
      if (mounted) {
        setState(() {
          _chatResults = chats;
          _isSearching = false;
        });
      }
    });

    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    _searchSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _query = '';
        _chatResults = [];
        _messageResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _query = query;
      _isSearching = true;
    });

    // Debounce search by 300ms
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) return;

    // Search chats
    _telegramService.searchChats(query);

    // Also search in local cache
    final allChats = _telegramService.getChats();
    final localResults = allChats.where((chat) {
      return chat.title.toLowerCase().contains(query.toLowerCase()) ||
          chat.lastMessage.toLowerCase().contains(query.toLowerCase());
    }).toList();

    setState(() {
      _chatResults = localResults;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF37AEE2),
            labelColor: const Color(0xFF37AEE2),
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: 'Chats'),
              Tab(text: 'Messages'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildChatsTab(), _buildMessagesTab()],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: greyColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        cursorColor: const Color(0xFF37AEE2),
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          border: InputBorder.none,
        ),
      ),
      actions: [
        if (_searchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.white54),
            onPressed: () {
              _searchController.clear();
              _onSearchChanged('');
            },
          ),
      ],
    );
  }

  Widget _buildChatsTab() {
    if (_query.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search,
        title: 'Search for chats',
        subtitle: 'Enter a name or message to find chats',
      );
    }

    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF37AEE2)),
      );
    }

    if (_chatResults.isEmpty) {
      return _buildEmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'No chats found',
        subtitle: 'Try a different search term',
      );
    }

    return ListView.builder(
      itemCount: _chatResults.length,
      itemBuilder: (context, index) => _buildChatItem(_chatResults[index]),
    );
  }

  Widget _buildMessagesTab() {
    if (_query.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search,
        title: 'Search for messages',
        subtitle: 'Enter text to find messages across all chats',
      );
    }

    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF37AEE2)),
      );
    }

    if (_messageResults.isEmpty) {
      return _buildEmptyState(
        icon: Icons.message_outlined,
        title: 'No messages found',
        subtitle: 'Try a different search term',
      );
    }

    return ListView.builder(
      itemCount: _messageResults.length,
      itemBuilder: (context, index) =>
          _buildMessageItem(_messageResults[index]),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(TelegramChat chat) {
    // Highlight matching text
    final titleSpans = _highlightMatches(chat.title, _query);
    final messageSpans = _highlightMatches(chat.lastMessage, _query);

    return ListTile(
      leading: UserAvatar(photoPath: chat.photoUrl, name: chat.title, size: 50),
      title: RichText(
        text: TextSpan(children: titleSpans),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: RichText(
        text: TextSpan(children: messageSpans),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        chat.lastMessageTime,
        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
      ),
      onTap: () {
        Navigator.pushReplacement(
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
    );
  }

  Widget _buildMessageItem(TelegramMessage message) {
    final chatTitle = _telegramService.getChatTitle(message.chatId);
    final textSpans = _highlightMatches(message.text, _query);

    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.blueGrey,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.message, color: Colors.white54),
      ),
      title: Text(
        chatTitle,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: RichText(
        text: TextSpan(children: textSpans),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        message.time,
        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
      ),
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailPage(
              name: chatTitle,
              img: '',
              chatId: message.chatId,
            ),
          ),
        );
      },
    );
  }

  List<TextSpan> _highlightMatches(String text, String query) {
    if (query.isEmpty) {
      return [
        TextSpan(
          text: text,
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
      ];
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        // Add remaining text
        if (start < text.length) {
          spans.add(
            TextSpan(
              text: text.substring(start),
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          );
        }
        break;
      }

      // Add text before match
      if (index > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, index),
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
        );
      }

      // Add highlighted match
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: const TextStyle(
            color: Color(0xFF37AEE2),
            fontWeight: FontWeight.w600,
          ),
        ),
      );

      start = index + query.length;
    }

    if (spans.isEmpty) {
      return [
        TextSpan(
          text: text,
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
      ];
    }

    return spans;
  }
}
