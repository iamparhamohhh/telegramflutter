import 'dart:async';
import 'package:flutter/material.dart';
import 'package:telegramflutter/pages/chat_detail_page.dart';
import 'package:telegramflutter/services/telegram_service.dart';
import 'package:telegramflutter/theme/colors.dart';
import 'package:telegramflutter/widgets/media_widgets.dart';
import 'package:tdlib/td_api.dart' hide Text, RichText;

/// Global search page for chats, messages, and contacts
class SearchPage extends StatefulWidget {
  final int? initialChatId; // If provided, search within this chat only
  final String? initialChatTitle;

  const SearchPage({super.key, this.initialChatId, this.initialChatTitle});

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
  List<SearchResultMessage> _messageResults = [];
  List<TelegramContact> _contactResults = [];
  StreamSubscription<SearchResults>? _searchSubscription;

  bool _isSearching = false;
  String _query = '';
  Timer? _debounceTimer;

  // Filters
  SearchMessagesFilter? _activeFilter;
  DateTime? _startDate;
  DateTime? _endDate;

  // Date formatting helpers
  static const _months = [
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

  String _formatDate(DateTime date) {
    return '${_months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatShortDate(DateTime date) {
    return '${_months[date.month - 1]} ${date.day}';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.initialChatId != null ? 1 : 3,
      vsync: this,
    );

    // Subscribe to search results
    _searchSubscription = _telegramService.searchResultsStream.listen((
      results,
    ) {
      if (mounted) {
        setState(() {
          _messageResults = results.messages;
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
        _contactResults = [];
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

    if (widget.initialChatId != null) {
      // Search within specific chat
      _searchChatMessages(query);
    } else {
      // Global search based on current tab
      final currentTab = _tabController.index;
      if (currentTab == 0) {
        _searchChats(query);
      } else if (currentTab == 1) {
        _searchMessages(query);
      } else {
        _searchContacts(query);
      }
    }
  }

  void _searchChats(String query) {
    // Search in local cache
    final results = _telegramService.searchChatsLocal(query);
    setState(() {
      _chatResults = results;
      _isSearching = false;
    });

    // Also request from server
    _telegramService.requestSearchPublicChats(query);
  }

  void _searchMessages(String query) {
    if (_startDate != null && _endDate != null) {
      _telegramService.searchMessagesByDate(
        query: query,
        startDate: _startDate!,
        endDate: _endDate!,
        limit: 50,
        filter: _activeFilter,
      );
    } else {
      _telegramService.searchMessages(
        query: query,
        limit: 50,
        filter: _activeFilter,
      );
    }
  }

  void _searchChatMessages(String query) {
    _telegramService.searchChatMessages(
      chatId: widget.initialChatId!,
      query: query,
      limit: 50,
      filter: _activeFilter,
    );
  }

  void _searchContacts(String query) {
    final results = _telegramService.searchContacts(query);
    setState(() {
      _contactResults = results;
      _isSearching = false;
    });

    // Also request from server
    _telegramService.requestSearchContacts(query);
  }

  void _setFilter(SearchMessagesFilter? filter) {
    setState(() {
      _activeFilter = filter;
    });
    if (_query.isNotEmpty) {
      _performSearch(_query);
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: const Color(0xFF37AEE2),
              onPrimary: white,
              surface: greyColor,
              onSurface: white,
            ),
            dialogBackgroundColor: bgColor,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      if (_query.isNotEmpty) {
        _performSearch(_query);
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _activeFilter = null;
      _startDate = null;
      _endDate = null;
    });
    if (_query.isNotEmpty) {
      _performSearch(_query);
    }
  }

  String _getActiveFiltersText() {
    final parts = <String>[];

    if (_activeFilter != null) {
      if (_activeFilter is SearchMessagesFilterPhoto) parts.add('Photos');
      if (_activeFilter is SearchMessagesFilterVideo) parts.add('Videos');
      if (_activeFilter is SearchMessagesFilterDocument) parts.add('Documents');
      if (_activeFilter is SearchMessagesFilterAudio) parts.add('Audio');
      if (_activeFilter is SearchMessagesFilterVoiceNote) parts.add('Voice');
      if (_activeFilter is SearchMessagesFilterUrl) parts.add('Links');
    }

    if (_startDate != null && _endDate != null) {
      parts.add('${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}');
    }

    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Active filters bar
          if (_activeFilter != null || _startDate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: greyColor.withOpacity(0.5),
              child: Row(
                children: [
                  const Icon(
                    Icons.filter_alt,
                    color: Color(0xFF37AEE2),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getActiveFiltersText(),
                      style: TextStyle(
                        color: white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearFilters,
                    child: Icon(
                      Icons.close,
                      color: white.withOpacity(0.5),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),

          // Tabs (only for global search)
          if (widget.initialChatId == null)
            TabBar(
              controller: _tabController,
              onTap: (_) {
                if (_query.isNotEmpty) {
                  setState(() => _isSearching = true);
                  _performSearch(_query);
                }
              },
              indicatorColor: const Color(0xFF37AEE2),
              labelColor: const Color(0xFF37AEE2),
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(text: 'Chats'),
                Tab(text: 'Messages'),
                Tab(text: 'Contacts'),
              ],
            ),

          // Content
          Expanded(
            child: widget.initialChatId != null
                ? _buildMessagesTab()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildChatsTab(),
                      _buildMessagesTab(),
                      _buildContactsTab(),
                    ],
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
          hintText: widget.initialChatId != null
              ? 'Search in ${widget.initialChatTitle ?? 'chat'}'
              : 'Search',
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
        PopupMenuButton<String>(
          icon: Icon(
            Icons.filter_list,
            color: (_activeFilter != null || _startDate != null)
                ? const Color(0xFF37AEE2)
                : Colors.white,
          ),
          color: greyColor,
          onSelected: (value) {
            switch (value) {
              case 'photos':
                _setFilter(TelegramService.searchFilterPhotos);
                break;
              case 'videos':
                _setFilter(TelegramService.searchFilterVideos);
                break;
              case 'documents':
                _setFilter(TelegramService.searchFilterDocuments);
                break;
              case 'audio':
                _setFilter(TelegramService.searchFilterAudio);
                break;
              case 'voice':
                _setFilter(TelegramService.searchFilterVoice);
                break;
              case 'links':
                _setFilter(TelegramService.searchFilterLinks);
                break;
              case 'date':
                _selectDateRange();
                break;
              case 'clear':
                _clearFilters();
                break;
            }
          },
          itemBuilder: (context) => [
            _buildFilterMenuItem(
              'photos',
              Icons.photo,
              'Photos',
              _activeFilter is SearchMessagesFilterPhoto,
            ),
            _buildFilterMenuItem(
              'videos',
              Icons.videocam,
              'Videos',
              _activeFilter is SearchMessagesFilterVideo,
            ),
            _buildFilterMenuItem(
              'documents',
              Icons.description,
              'Documents',
              _activeFilter is SearchMessagesFilterDocument,
            ),
            _buildFilterMenuItem(
              'audio',
              Icons.audiotrack,
              'Audio',
              _activeFilter is SearchMessagesFilterAudio,
            ),
            _buildFilterMenuItem(
              'voice',
              Icons.mic,
              'Voice',
              _activeFilter is SearchMessagesFilterVoiceNote,
            ),
            _buildFilterMenuItem(
              'links',
              Icons.link,
              'Links',
              _activeFilter is SearchMessagesFilterUrl,
            ),
            const PopupMenuDivider(),
            _buildFilterMenuItem(
              'date',
              Icons.date_range,
              'Date range',
              _startDate != null,
            ),
            if (_activeFilter != null || _startDate != null)
              _buildFilterMenuItem(
                'clear',
                Icons.clear_all,
                'Clear filters',
                false,
              ),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildFilterMenuItem(
    String value,
    IconData icon,
    String label,
    bool isActive,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF37AEE2) : white.withOpacity(0.7),
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: isActive ? const Color(0xFF37AEE2) : white),
          ),
          if (isActive) ...[
            const Spacer(),
            const Icon(Icons.check, color: Color(0xFF37AEE2), size: 18),
          ],
        ],
      ),
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
        title: widget.initialChatId != null
            ? 'Search messages in this chat'
            : 'Search for messages',
        subtitle: 'Enter text to find messages',
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
          _buildMessageResultItem(_messageResults[index]),
    );
  }

  Widget _buildContactsTab() {
    if (_query.isEmpty) {
      // Show all contacts when no search query
      final allContacts = _telegramService.contacts;
      if (allContacts.isEmpty) {
        return _buildEmptyState(
          icon: Icons.contacts,
          title: 'No contacts',
          subtitle: 'Your contacts will appear here',
        );
      }
      return ListView.builder(
        itemCount: allContacts.length,
        itemBuilder: (context, index) => _buildContactItem(allContacts[index]),
      );
    }

    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF37AEE2)),
      );
    }

    if (_contactResults.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_search,
        title: 'No contacts found',
        subtitle: 'Try a different search term',
      );
    }

    return ListView.builder(
      itemCount: _contactResults.length,
      itemBuilder: (context, index) =>
          _buildContactItem(_contactResults[index]),
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
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            chat.lastMessageTime,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
          if (chat.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF37AEE2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                chat.unreadCount > 99 ? '99+' : chat.unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailPage(
              name: chat.title,
              imageUrl: chat.photoUrl,
              chatId: chat.id,
              actualChatId: chat.id,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageResultItem(SearchResultMessage message) {
    final textSpans = _highlightMatches(message.text, _query);
    final dateStr = _formatShortDate(message.dateTime);

    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: _getContentTypeColor(message.contentType),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _getContentTypeIcon(message.contentType),
          color: Colors.white,
          size: 22,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              message.chatTitle.isNotEmpty ? message.chatTitle : 'Chat',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            dateStr,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.senderName.isNotEmpty)
            Text(
              message.isOutgoing ? 'You' : message.senderName,
              style: const TextStyle(color: Color(0xFF37AEE2), fontSize: 13),
            ),
          RichText(
            text: TextSpan(children: textSpans),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      isThreeLine: message.senderName.isNotEmpty,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailPage(
              name: message.chatTitle,
              chatId: message.chatId,
              actualChatId: message.chatId,
              highlightMessageId: message.id,
            ),
          ),
        );
      },
    );
  }

  Widget _buildContactItem(TelegramContact contact) {
    final nameSpans = _highlightMatches(contact.fullName, _query);

    return ListTile(
      leading: UserAvatar(
        photoPath: contact.photoUrl,
        name: contact.fullName,
        size: 50,
      ),
      title: RichText(
        text: TextSpan(children: nameSpans),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (contact.username != null)
            Text(
              '@${contact.username}',
              style: const TextStyle(color: Color(0xFF37AEE2), fontSize: 13),
            ),
          if (contact.phone != null)
            Text(
              contact.phone!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
        ],
      ),
      isThreeLine: contact.username != null && contact.phone != null,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailPage(
              name: contact.fullName,
              imageUrl: contact.photoUrl,
              chatId: contact.id,
              actualChatId: contact.id,
            ),
          ),
        );
      },
    );
  }

  IconData _getContentTypeIcon(String contentType) {
    switch (contentType) {
      case 'messageText':
      case 'text':
        return Icons.message;
      case 'messagePhoto':
        return Icons.photo;
      case 'messageVideo':
        return Icons.videocam;
      case 'messageDocument':
        return Icons.description;
      case 'messageAudio':
        return Icons.audiotrack;
      case 'messageVoiceNote':
        return Icons.mic;
      case 'messageSticker':
        return Icons.emoji_emotions;
      case 'messageLocation':
        return Icons.location_on;
      case 'messageContact':
        return Icons.person;
      default:
        return Icons.message;
    }
  }

  Color _getContentTypeColor(String contentType) {
    switch (contentType) {
      case 'messagePhoto':
        return Colors.purple;
      case 'messageVideo':
        return Colors.red;
      case 'messageDocument':
        return Colors.orange;
      case 'messageAudio':
        return Colors.pink;
      case 'messageVoiceNote':
        return Colors.teal;
      case 'messageSticker':
        return Colors.amber;
      case 'messageLocation':
        return Colors.green;
      case 'messageContact':
        return Colors.blue;
      default:
        return const Color(0xFF37AEE2);
    }
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

      if (index > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, index),
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
        );
      }

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
