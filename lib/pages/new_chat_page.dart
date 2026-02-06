import 'package:flutter/material.dart';
import '../services/telegram_service.dart';
import '../theme/colors.dart';
import 'chat_detail_page.dart';

class NewChatPage extends StatefulWidget {
  const NewChatPage({super.key});

  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  final TelegramService _telegramService = TelegramService();
  final TextEditingController _searchController = TextEditingController();
  
  List<TelegramContact> _contacts = [];
  List<TelegramContact> _filteredContacts = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _telegramService.contactsStream.listen((contacts) {
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _filteredContacts = contacts;
          _isLoading = false;
        });
      }
    });
  }

  void _loadContacts() {
    _telegramService.loadContacts();
  }

  void _filterContacts(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredContacts = _contacts;
        _searchResults = [];
      } else {
        _filteredContacts = _contacts.where((contact) {
          final name = contact.fullName.toLowerCase();
          final phone = contact.phone?.toLowerCase() ?? '';
          final username = contact.username?.toLowerCase() ?? '';
          final q = query.toLowerCase();
          return name.contains(q) || phone.contains(q) || username.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _searchGlobally(String query) async {
    if (query.isEmpty || query.length < 3) return;
    
    setState(() => _isSearching = true);
    
    // Just trigger the search - results will come via updates
    _telegramService.requestSearchPublicChats(query);
    
    // Wait a bit for results to come back
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      setState(() {
        _isSearching = false;
        // Results will come from the chats stream if users found
      });
    }
  }

  Future<void> _openChat(int userId) async {
    // Request private chat creation
    _telegramService.createPrivateChat(userId);
    
    // Wait for chat to be created and show up in chats
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Find the user to get their name for temp chat
    final user = _telegramService.getUser(userId);
    
    // Try to find the chat in chats list
    final chats = _telegramService.chats;
    final existingChat = chats.where((c) => c.id == userId).firstOrNull;
    
    if (existingChat != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(chat: existingChat),
        ),
      );
    } else if (mounted) {
      // Create temp chat object
      final chat = TelegramChat(
        id: userId,
        title: user?.firstName ?? 'Chat',
        lastMessage: '',
        lastMessageTime: '',
        unreadCount: 0,
        isRead: true,
        isSentByMe: false,
      );
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(chat: chat),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: greyColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Message',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // Focus on search field
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: greyColor,
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                _filterContacts(value);
                if (value.length >= 3) {
                  _searchGlobally(value);
                }
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name, phone, or username...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                filled: true,
                fillColor: bgColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          
          // Action buttons
          Container(
            color: greyColor,
            child: Column(
              children: [
                _buildActionTile(
                  icon: Icons.group_add,
                  title: 'New Group',
                  onTap: () {
                    Navigator.pushNamed(context, '/new-group');
                  },
                ),
                _buildActionTile(
                  icon: Icons.campaign,
                  title: 'New Channel',
                  onTap: () {
                    Navigator.pushNamed(context, '/new-channel');
                  },
                ),
                _buildActionTile(
                  icon: Icons.person_add,
                  title: 'Invite Friends',
                  onTap: () {
                    // Share app invite
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share feature coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Contacts label
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: greyColor,
            child: Text(
              _searchQuery.isEmpty ? 'Contacts' : 'Contacts (${_filteredContacts.length})',
              style: TextStyle(
                color: Colors.blue[300],
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          
          // Contacts list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredContacts.isEmpty && _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.contacts,
                              size: 64,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No contacts yet'
                                  : 'No contacts found',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredContacts.length + _searchResults.length,
                        itemBuilder: (context, index) {
                          if (index < _filteredContacts.length) {
                            return _buildContactTile(_filteredContacts[index]);
                          } else {
                            final resultIndex = index - _filteredContacts.length;
                            return _buildSearchResultTile(_searchResults[resultIndex]);
                          }
                        },
                      ),
          ),
          
          if (_isSearching)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Searching globally...',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildContactTile(TelegramContact contact) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.primaries[contact.id.abs() % Colors.primaries.length],
        child: Text(
          contact.fullName.isNotEmpty
              ? contact.fullName[0].toUpperCase()
              : '?',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(
        contact.fullName,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        contact.username != null
            ? '@${contact.username}'
            : (contact.phone ?? 'No phone'),
        style: TextStyle(color: Colors.grey[500]),
      ),
      onTap: () => _openChat(contact.id),
    );
  }

  Widget _buildSearchResultTile(Map<String, dynamic> result) {
    final title = result['title'] ?? 'Unknown';
    final type = result['type'];
    final isPrivate = type?['@type'] == 'chatTypePrivate';
    final userId = isPrivate ? type['user_id'] as int? : null;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.teal,
        child: Icon(
          isPrivate ? Icons.person : Icons.group,
          color: Colors.white,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        isPrivate ? 'User' : 'Group/Channel',
        style: TextStyle(color: Colors.grey[500]),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
      onTap: () {
        if (userId != null) {
          _openChat(userId);
        } else {
          // Open chat directly if it already exists
          final chatId = result['id'] as int?;
          if (chatId != null) {
            final chat = TelegramChat(
              id: chatId,
              title: title,
              lastMessage: '',
              lastMessageTime: '',
              unreadCount: 0,
              isRead: true,
              isSentByMe: false,
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ChatDetailPage(chat: chat),
              ),
            );
          }
        }
      },
    );
  }
}
