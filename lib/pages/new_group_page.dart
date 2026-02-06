import 'package:flutter/material.dart';
import '../services/telegram_service.dart';
import '../theme/colors.dart';
import 'chat_detail_page.dart';

class NewGroupPage extends StatefulWidget {
  const NewGroupPage({super.key});

  @override
  State<NewGroupPage> createState() => _NewGroupPageState();
}

class _NewGroupPageState extends State<NewGroupPage> {
  final TelegramService _telegramService = TelegramService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  
  List<TelegramContact> _contacts = [];
  List<TelegramContact> _filteredContacts = [];
  final Set<int> _selectedUserIds = {};
  bool _isLoading = true;
  bool _isCreating = false;
  int _step = 0; // 0 = select members, 1 = set group name

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
      if (query.isEmpty) {
        _filteredContacts = _contacts;
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

  void _toggleSelection(int userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  void _proceedToNameStep() {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _createGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Create the group (void return)
      _telegramService.createBasicGroup(
        title: name,
        userIds: _selectedUserIds.toList(),
      );
      
      // Wait for group to be created
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        final chat = TelegramChat(
          id: 0, // Will be updated when group loads
          title: name,
          lastMessage: '',
          lastMessageTime: '',
          unreadCount: 0,
          isRead: true,
          isSentByMe: false,
        );
        
        // Go back to chats - user will see new group there
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group "$name" created')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _groupNameController.dispose();
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
          onPressed: () {
            if (_step == 1) {
              setState(() => _step = 0);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _step == 0 ? 'New Group' : 'New Group',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          if (_step == 0 && _selectedUserIds.isNotEmpty)
            TextButton(
              onPressed: _proceedToNameStep,
              child: const Text(
                'Next',
                style: TextStyle(color: Colors.blue),
              ),
            ),
        ],
      ),
      body: _step == 0 ? _buildMemberSelectionStep() : _buildNameStep(),
      floatingActionButton: _step == 0 && _selectedUserIds.isNotEmpty
          ? FloatingActionButton(
              onPressed: _proceedToNameStep,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.arrow_forward, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildMemberSelectionStep() {
    return Column(
      children: [
        // Selected members chips
        if (_selectedUserIds.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: greyColor,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedUserIds.map((userId) {
                final contact = _contacts.firstWhere(
                  (c) => c.id == userId,
                  orElse: () => TelegramContact(
                    id: userId,
                    firstName: 'User',
                    lastName: '',
                  ),
                );
                return Chip(
                  label: Text(
                    contact.fullName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.blue.withOpacity(0.3),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  deleteIconColor: Colors.white,
                  onDeleted: () => _toggleSelection(userId),
                );
              }).toList(),
            ),
          ),

        // Search bar
        Container(
          color: greyColor,
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            onChanged: _filterContacts,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search contacts...',
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

        // Info text
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _selectedUserIds.isEmpty
                ? 'Add members to the group'
                : '${_selectedUserIds.length} member${_selectedUserIds.length > 1 ? 's' : ''} selected',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
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
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredContacts.length,
                      itemBuilder: (context, index) {
                        final contact = _filteredContacts[index];
                        final isSelected = _selectedUserIds.contains(contact.id);
                        return _buildContactTile(contact, isSelected);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildNameStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group avatar placeholder
          Center(
            child: GestureDetector(
              onTap: () {
                // TODO: Pick group photo
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),

          // Group name field
          TextField(
            controller: _groupNameController,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              labelText: 'Group Name',
              labelStyle: TextStyle(color: Colors.grey[500]),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Members preview
          Text(
            '${_selectedUserIds.length} member${_selectedUserIds.length > 1 ? 's' : ''}',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
          
          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedUserIds.map((userId) {
              final contact = _contacts.firstWhere(
                (c) => c.id == userId,
                orElse: () => TelegramContact(
                  id: userId,
                  firstName: 'User',
                  lastName: '',
                ),
              );
              return Column(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.primaries[userId.abs() % Colors.primaries.length],
                    radius: 24,
                    child: Text(
                      contact.fullName.isNotEmpty
                          ? contact.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 60,
                    child: Text(
                      contact.firstName,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Create button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _createGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isCreating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Create Group',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(TelegramContact contact, bool isSelected) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: Colors.primaries[contact.id.abs() % Colors.primaries.length],
            child: Text(
              contact.fullName.isNotEmpty
                  ? contact.fullName[0].toUpperCase()
                  : '?',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (isSelected)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: bgColor, width: 2),
                ),
                child: const Icon(
                  Icons.check,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
        ],
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
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.blue)
          : null,
      onTap: () => _toggleSelection(contact.id),
    );
  }
}
