import 'dart:async';
import 'package:flutter/material.dart';
import '../services/telegram_service.dart';
import '../theme/colors.dart';

/// Page for creating and managing secret chats
class SecretChatPage extends StatefulWidget {
  final int? userId;
  final String? userName;

  const SecretChatPage({super.key, this.userId, this.userName});

  @override
  State<SecretChatPage> createState() => _SecretChatPageState();
}

class _SecretChatPageState extends State<SecretChatPage> {
  final TelegramService _telegramService = TelegramService();
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _secretChatSub;

  List<TelegramContact> _contacts = [];
  List<TelegramContact> _filteredContacts = [];
  bool _isLoading = true;
  bool _isCreating = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _secretChatSub = _telegramService.secretChatStream.listen((event) {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _statusMessage = 'Secret chat created!';
        });
        // Pop back after a moment
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
    });

    if (widget.userId != null) {
      // Direct creation
      _createSecretChat(widget.userId!);
    } else {
      _loadContacts();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _secretChatSub?.cancel();
    super.dispose();
  }

  void _loadContacts() {
    _telegramService.contactsStream.listen((contacts) {
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _filteredContacts = contacts;
          _isLoading = false;
        });
      }
    });
    _telegramService.loadContacts();
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        _filteredContacts = _contacts.where((c) {
          return c.fullName.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _createSecretChat(int userId) async {
    setState(() {
      _isCreating = true;
      _statusMessage = 'Creating secret chat...';
    });
    await _telegramService.createSecretChat(userId);
    // Timeout in case no response
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isCreating) {
        setState(() {
          _isCreating = false;
          _statusMessage = 'Secret chat request sent. Check your chats.';
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.appBarBg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.appBarText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'New Secret Chat',
          style: TextStyle(color: context.appBarText),
        ),
      ),
      body: _isCreating
          ? _buildCreatingState()
          : widget.userId != null
          ? _buildCreatingState()
          : _buildContactsList(),
    );
  }

  Widget _buildCreatingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: _isCreating
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: Colors.green),
                  )
                : const Icon(Icons.lock, color: Colors.green, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            _statusMessage ?? 'Creating secret chat...',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    return Column(
      children: [
        // Info banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.green.withOpacity(0.1),
          child: Row(
            children: [
              const Icon(Icons.lock, color: Colors.green, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'End-to-End Encrypted',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Messages in secret chats use end-to-end encryption and can self-destruct.',
                      style: TextStyle(
                        color: Colors.green.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.white54,
                size: 20,
              ),
              filled: true,
              fillColor: context.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: _filterContacts,
          ),
        ),

        // Contacts list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredContacts.isEmpty
              ? Center(
                  child: Text(
                    'No contacts found',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredContacts.length,
                  itemBuilder: (context, index) {
                    final contact = _filteredContacts[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.withOpacity(0.3),
                        child: Text(
                          contact.fullName.isNotEmpty
                              ? contact.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                      title: Text(
                        contact.fullName,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        _telegramService.getUserStatusText(contact.id),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.lock_outline,
                        color: Colors.green,
                        size: 20,
                      ),
                      onTap: () => _createSecretChat(contact.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
