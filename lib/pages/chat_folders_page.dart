import 'package:flutter/material.dart';
import '../services/telegram_service.dart';
import '../theme/colors.dart';

class ChatFoldersPage extends StatefulWidget {
  const ChatFoldersPage({super.key});

  @override
  State<ChatFoldersPage> createState() => _ChatFoldersPageState();
}

class _ChatFoldersPageState extends State<ChatFoldersPage> {
  final TelegramService _telegramService = TelegramService();
  List<TelegramChatFolder> _folders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFolders();
    _telegramService.chatFoldersStream.listen((folders) {
      if (mounted) {
        setState(() {
          _folders = folders;
          _isLoading = false;
        });
      }
    });
  }

  void _loadFolders() {
    _telegramService.loadChatFolders();
    // Also get current folders from cache
    setState(() {
      _folders = _telegramService.chatFolders;
      _isLoading = _folders.isEmpty;
    });
  }

  void _showCreateFolderDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: greyColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CreateFolderSheet(
        onCreated: () {
          Navigator.pop(context);
          _loadFolders();
        },
      ),
    );
  }

  void _showEditFolderDialog(TelegramChatFolder folder) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: greyColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _EditFolderSheet(
        folder: folder,
        onUpdated: () {
          Navigator.pop(context);
          _loadFolders();
        },
      ),
    );
  }

  Future<void> _deleteFolder(TelegramChatFolder folder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: greyColor,
        title: const Text(
          'Delete Folder',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${folder.title}"?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _telegramService.deleteChatFolder(folder.id);
    }
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
          'Chat Folders',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _folders.isEmpty
              ? _buildEmptyState()
              : _buildFoldersList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateFolderDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_outlined,
              size: 80,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 24),
            Text(
              'No Chat Folders',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create folders to organize your chats and quickly switch between them.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showCreateFolderDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Folder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoldersList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _folders.length + 1,
      onReorder: (oldIndex, newIndex) {
        // Handle reorder - folders can be reordered
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          if (oldIndex < _folders.length && newIndex < _folders.length) {
            final item = _folders.removeAt(oldIndex);
            _folders.insert(newIndex, item);
          }
        });
      },
      itemBuilder: (context, index) {
        if (index == _folders.length) {
          return Container(
            key: const ValueKey('recommended'),
            margin: const EdgeInsets.only(top: 16),
            child: _buildRecommendedSection(),
          );
        }
        
        final folder = _folders[index];
        return _buildFolderItem(folder, key: ValueKey(folder.id));
      },
    );
  }

  Widget _buildFolderItem(TelegramChatFolder folder, {Key? key}) {
    return Card(
      key: key,
      color: greyColor,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getFolderIcon(folder.iconName),
            color: Colors.blue,
          ),
        ),
        title: Text(
          folder.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          _getFolderDescription(folder),
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.grey),
              onPressed: () => _showEditFolderDialog(folder),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteFolder(folder),
            ),
            const Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
        onTap: () => _showEditFolderDialog(folder),
      ),
    );
  }

  Widget _buildRecommendedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Recommended Folders',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        _buildRecommendedFolder(
          icon: Icons.people,
          title: 'Contacts',
          description: 'Chats with your contacts',
          onTap: () => _createQuickFolder(
            title: 'Contacts',
            iconName: 'Contacts',
            includeContacts: true,
          ),
        ),
        _buildRecommendedFolder(
          icon: Icons.group,
          title: 'Groups',
          description: 'All your groups',
          onTap: () => _createQuickFolder(
            title: 'Groups',
            iconName: 'Groups',
            includeGroups: true,
          ),
        ),
        _buildRecommendedFolder(
          icon: Icons.campaign,
          title: 'Channels',
          description: 'All your channels',
          onTap: () => _createQuickFolder(
            title: 'Channels',
            iconName: 'Channels',
            includeChannels: true,
          ),
        ),
        _buildRecommendedFolder(
          icon: Icons.smart_toy,
          title: 'Bots',
          description: 'All your bots',
          onTap: () => _createQuickFolder(
            title: 'Bots',
            iconName: 'Bots',
            includeBots: true,
          ),
        ),
        _buildRecommendedFolder(
          icon: Icons.notifications_off,
          title: 'Unread',
          description: 'Chats with unread messages',
          onTap: () => _createQuickFolder(
            title: 'Unread',
            iconName: 'Unread',
            excludeRead: true,
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedFolder({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    // Check if folder already exists
    final exists = _folders.any((f) => f.title == title);
    
    return Card(
      color: greyColor,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[700],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          description,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        trailing: exists
            ? const Icon(Icons.check, color: Colors.green)
            : const Icon(Icons.add, color: Colors.blue),
        onTap: exists ? null : onTap,
      ),
    );
  }

  Future<void> _createQuickFolder({
    required String title,
    required String iconName,
    bool includeContacts = false,
    bool includeNonContacts = false,
    bool includeGroups = false,
    bool includeChannels = false,
    bool includeBots = false,
    bool excludeMuted = false,
    bool excludeRead = false,
    bool excludeArchived = false,
  }) async {
    await _telegramService.createChatFolder(
      title: title,
      iconName: iconName,
      includeContacts: includeContacts,
      includeNonContacts: includeNonContacts,
      includeGroups: includeGroups,
      includeChannels: includeChannels,
      includeBots: includeBots,
      excludeMuted: excludeMuted,
      excludeRead: excludeRead,
      excludeArchived: excludeArchived,
    );
    _loadFolders();
  }

  IconData _getFolderIcon(String? iconName) {
    switch (iconName) {
      case 'All':
        return Icons.chat_bubble_outline;
      case 'Unread':
        return Icons.mark_email_unread;
      case 'Unmuted':
        return Icons.notifications_active;
      case 'Bots':
        return Icons.smart_toy;
      case 'Channels':
        return Icons.campaign;
      case 'Groups':
        return Icons.group;
      case 'Private':
        return Icons.person;
      case 'Contacts':
        return Icons.people;
      case 'NonContacts':
        return Icons.person_add_disabled;
      default:
        return Icons.folder;
    }
  }

  String _getFolderDescription(TelegramChatFolder folder) {
    final parts = <String>[];
    
    if (folder.includeContacts) parts.add('Contacts');
    if (folder.includeNonContacts) parts.add('Non-contacts');
    if (folder.includeGroups) parts.add('Groups');
    if (folder.includeChannels) parts.add('Channels');
    if (folder.includeBots) parts.add('Bots');
    
    if (folder.excludeMuted) parts.add('Exclude muted');
    if (folder.excludeRead) parts.add('Exclude read');
    if (folder.excludeArchived) parts.add('Exclude archived');
    
    if (folder.includedChatIds.isNotEmpty) {
      parts.add('${folder.includedChatIds.length} chats');
    }
    
    return parts.isEmpty ? 'Custom folder' : parts.join(' • ');
  }
}

class _CreateFolderSheet extends StatefulWidget {
  final VoidCallback onCreated;

  const _CreateFolderSheet({required this.onCreated});

  @override
  State<_CreateFolderSheet> createState() => _CreateFolderSheetState();
}

class _CreateFolderSheetState extends State<_CreateFolderSheet> {
  final TelegramService _telegramService = TelegramService();
  final TextEditingController _nameController = TextEditingController();
  
  bool _includeContacts = false;
  bool _includeNonContacts = false;
  bool _includeGroups = false;
  bool _includeChannels = false;
  bool _includeBots = false;
  bool _excludeMuted = false;
  bool _excludeRead = false;
  bool _excludeArchived = false;
  bool _isCreating = false;

  Future<void> _createFolder() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a folder name')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      await _telegramService.createChatFolder(
        title: name,
        includeContacts: _includeContacts,
        includeNonContacts: _includeNonContacts,
        includeGroups: _includeGroups,
        includeChannels: _includeChannels,
        includeBots: _includeBots,
        excludeMuted: _excludeMuted,
        excludeRead: _excludeRead,
        excludeArchived: _excludeArchived,
      );
      widget.onCreated();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Create Folder',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Name field
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Folder Name',
                labelStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: bgColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              'Include',
              style: TextStyle(
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            
            _buildSwitch('Contacts', _includeContacts, (v) => setState(() => _includeContacts = v)),
            _buildSwitch('Non-Contacts', _includeNonContacts, (v) => setState(() => _includeNonContacts = v)),
            _buildSwitch('Groups', _includeGroups, (v) => setState(() => _includeGroups = v)),
            _buildSwitch('Channels', _includeChannels, (v) => setState(() => _includeChannels = v)),
            _buildSwitch('Bots', _includeBots, (v) => setState(() => _includeBots = v)),
            
            const SizedBox(height: 16),
            
            Text(
              'Exclude',
              style: TextStyle(
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            
            _buildSwitch('Muted', _excludeMuted, (v) => setState(() => _excludeMuted = v)),
            _buildSwitch('Read', _excludeRead, (v) => setState(() => _excludeRead = v)),
            _buildSwitch('Archived', _excludeArchived, (v) => setState(() => _excludeArchived = v)),
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createFolder,
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
                        'Create Folder',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitch(String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

class _EditFolderSheet extends StatefulWidget {
  final TelegramChatFolder folder;
  final VoidCallback onUpdated;

  const _EditFolderSheet({required this.folder, required this.onUpdated});

  @override
  State<_EditFolderSheet> createState() => _EditFolderSheetState();
}

class _EditFolderSheetState extends State<_EditFolderSheet> {
  final TelegramService _telegramService = TelegramService();
  late TextEditingController _nameController;
  
  late bool _includeContacts;
  late bool _includeNonContacts;
  late bool _includeGroups;
  late bool _includeChannels;
  late bool _includeBots;
  late bool _excludeMuted;
  late bool _excludeRead;
  late bool _excludeArchived;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.folder.title);
    _includeContacts = widget.folder.includeContacts;
    _includeNonContacts = widget.folder.includeNonContacts;
    _includeGroups = widget.folder.includeGroups;
    _includeChannels = widget.folder.includeChannels;
    _includeBots = widget.folder.includeBots;
    _excludeMuted = widget.folder.excludeMuted;
    _excludeRead = widget.folder.excludeRead;
    _excludeArchived = widget.folder.excludeArchived;
  }

  Future<void> _updateFolder() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a folder name')),
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      await _telegramService.editChatFolder(
        widget.folder.id,
        title: name,
        includeContacts: _includeContacts,
        includeNonContacts: _includeNonContacts,
        includeGroups: _includeGroups,
        includeChannels: _includeChannels,
        includeBots: _includeBots,
        excludeMuted: _excludeMuted,
        excludeRead: _excludeRead,
        excludeArchived: _excludeArchived,
      );
      widget.onUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Folder',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Folder Name',
                labelStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: bgColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              'Include',
              style: TextStyle(
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            
            _buildSwitch('Contacts', _includeContacts, (v) => setState(() => _includeContacts = v)),
            _buildSwitch('Non-Contacts', _includeNonContacts, (v) => setState(() => _includeNonContacts = v)),
            _buildSwitch('Groups', _includeGroups, (v) => setState(() => _includeGroups = v)),
            _buildSwitch('Channels', _includeChannels, (v) => setState(() => _includeChannels = v)),
            _buildSwitch('Bots', _includeBots, (v) => setState(() => _includeBots = v)),
            
            const SizedBox(height: 16),
            
            Text(
              'Exclude',
              style: TextStyle(
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            
            _buildSwitch('Muted', _excludeMuted, (v) => setState(() => _excludeMuted = v)),
            _buildSwitch('Read', _excludeRead, (v) => setState(() => _excludeRead = v)),
            _buildSwitch('Archived', _excludeArchived, (v) => setState(() => _excludeArchived = v)),
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUpdating ? null : _updateFolder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isUpdating
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitch(String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
