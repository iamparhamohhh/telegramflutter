import 'package:flutter/material.dart';
import '../services/telegram_service.dart';
import '../theme/colors.dart';
import 'chat_detail_page.dart';

class NewChannelPage extends StatefulWidget {
  const NewChannelPage({super.key});

  @override
  State<NewChannelPage> createState() => _NewChannelPageState();
}

class _NewChannelPageState extends State<NewChannelPage> {
  final TelegramService _telegramService = TelegramService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  List<TelegramContact> _contacts = [];
  List<TelegramContact> _filteredContacts = [];
  final Set<int> _selectedUserIds = {};
  
  bool _isLoading = true;
  bool _isCreating = false;
  bool _isPublic = true;
  int _step = 0; // 0 = channel info, 1 = add members (optional)

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
          final q = query.toLowerCase();
          return name.contains(q);
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

  void _proceedToMembersStep() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a channel name')),
      );
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _createChannel() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a channel name')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Create supergroup/channel (void return)
      _telegramService.createSupergroup(
        title: name,
        description: _descriptionController.text.trim(),
        isChannel: true,
        isForum: false,
      );
      
      // Wait for channel to be created
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        // Go back to chats list - user will see new channel there
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Channel "$name" created')),
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
    _nameController.dispose();
    _descriptionController.dispose();
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
          onPressed: () {
            if (_step == 1) {
              setState(() => _step = 0);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _step == 0 ? 'New Channel' : 'Add Subscribers',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          if (_step == 1)
            TextButton(
              onPressed: _isCreating ? null : _createChannel,
              child: Text(
                _selectedUserIds.isEmpty ? 'Skip' : 'Done',
                style: const TextStyle(color: Colors.blue),
              ),
            ),
        ],
      ),
      body: _step == 0 ? _buildInfoStep() : _buildMembersStep(),
    );
  }

  Widget _buildInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Channel avatar placeholder
          Center(
            child: GestureDetector(
              onTap: () {
                // TODO: Pick channel photo
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

          // Channel name field
          TextField(
            controller: _nameController,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              labelText: 'Channel Name',
              labelStyle: TextStyle(color: Colors.grey[500]),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Description field
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              labelStyle: TextStyle(color: Colors.grey[500]),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Channel type toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: greyColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Channel Type',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTypeOption(
                  icon: Icons.public,
                  title: 'Public Channel',
                  subtitle: 'Anyone can find and join',
                  isSelected: _isPublic,
                  onTap: () => setState(() => _isPublic = true),
                ),
                const SizedBox(height: 12),
                _buildTypeOption(
                  icon: Icons.lock,
                  title: 'Private Channel',
                  subtitle: 'Only invited users can join',
                  isSelected: !_isPublic,
                  onTap: () => setState(() => _isPublic = false),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Info text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _isPublic
                  ? 'Public channels can be found in search and anyone can join.'
                  : 'Private channels can only be joined via an invite link.',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Next button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _proceedToMembersStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Next',
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

  Widget _buildTypeOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[700]!,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.grey[700],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersStep() {
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
            'Add subscribers to your channel (optional)',
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

        // Create button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _createChannel,
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
                  : Text(
                      _selectedUserIds.isEmpty
                          ? 'Create Channel'
                          : 'Create Channel with ${_selectedUserIds.length} subscriber${_selectedUserIds.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ],
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
