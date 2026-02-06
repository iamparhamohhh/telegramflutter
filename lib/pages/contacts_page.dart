import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telegramflutter/services/telegram_service.dart';
import 'package:telegramflutter/theme/colors.dart';
import 'package:telegramflutter/pages/add_contact_page.dart';

/// Contacts page with real TDLib data, sync, search, and add contact
class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final _telegramService = TelegramService();
  final _searchController = TextEditingController();
  StreamSubscription? _contactsSub;
  List<TelegramContact> _contacts = [];
  List<TelegramContact> _filteredContacts = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String _sortMode = 'name'; // name | lastSeen

  @override
  void initState() {
    super.initState();
    _contactsSub = _telegramService.contactsStream.listen((contacts) {
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _applyFilter();
          _isLoading = false;
          _isSyncing = false;
        });
      }
    });
    _telegramService.loadContacts();
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      _filteredContacts = List.from(_contacts);
    } else {
      _filteredContacts = _contacts.where((c) {
        return c.fullName.toLowerCase().contains(query) ||
            (c.phone?.contains(query) ?? false) ||
            (c.username?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    // Sort
    _filteredContacts.sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  Future<void> _syncContacts() async {
    setState(() => _isSyncing = true);

    // Request contacts permission
    final status = await Permission.contacts.request();
    if (status.isGranted) {
      // Reload from TDLib
      await _telegramService.loadContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contacts synced successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts permission denied')),
        );
      }
    }
  }

  @override
  void dispose() {
    _contactsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: greyColor,
        title: const Text('Contacts', style: TextStyle(color: white)),
        leading: IconButton(
          onPressed: () => _showSortOptions(),
          icon: Text(
            'Sort',
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF37AEE2),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF37AEE2),
                  ),
                ),
              ),
            )
          else
            IconButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddContactPage()),
                );
                if (result == true) {
                  _telegramService.loadContacts();
                }
              },
              icon: const Icon(Icons.person_add, color: Color(0xFF37AEE2)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: greyColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() => _applyFilter()),
                style: const TextStyle(color: white),
                cursorColor: const Color(0xFF37AEE2),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: white.withOpacity(0.3)),
                  hintText: 'Search contacts',
                  hintStyle: TextStyle(
                    color: white.withOpacity(0.3),
                    fontSize: 16,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close,
                            color: white.withOpacity(0.3),
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _applyFilter());
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
          // Action buttons
          _buildActionButtons(),
          // Contacts list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF37AEE2)),
                  )
                : _filteredContacts.isEmpty
                ? _buildEmptyState()
                : _buildContactsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      color: bgColor,
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildActionTile(
            icon: Icons.sync,
            label: 'Sync Contacts',
            onTap: _syncContacts,
          ),
          _buildActionTile(
            icon: Icons.person_add_outlined,
            label: 'Invite Friends',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invite feature coming soon')),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Divider(height: 1, color: white.withOpacity(0.08)),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF37AEE2), size: 26),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF37AEE2),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, color: white.withOpacity(0.2), size: 64),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? 'No contacts found'
                : 'No contacts yet',
            style: TextStyle(color: white.withOpacity(0.5), fontSize: 16),
          ),
          if (_searchController.text.isEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _syncContacts,
              child: const Text(
                'Sync Contacts',
                style: TextStyle(color: Color(0xFF37AEE2)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    // Group by first letter
    final grouped = <String, List<TelegramContact>>{};
    for (final contact in _filteredContacts) {
      final letter = contact.fullName.isNotEmpty
          ? contact.fullName[0].toUpperCase()
          : '#';
      grouped.putIfAbsent(letter, () => []).add(contact);
    }
    final sortedKeys = grouped.keys.toList()..sort();

    return ListView.builder(
      itemCount: sortedKeys.length,
      itemBuilder: (context, sectionIndex) {
        final letter = sortedKeys[sectionIndex];
        final contacts = grouped[letter]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                letter,
                style: TextStyle(
                  color: const Color(0xFF37AEE2),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...contacts.map((contact) => _buildContactTile(contact)),
          ],
        );
      },
    );
  }

  Widget _buildContactTile(TelegramContact contact) {
    final isOnline = _telegramService.isUserOnline(contact.id);
    final statusText = _telegramService.getUserStatusText(contact.id);
    final photoPath = _telegramService.getUserPhotoPath(contact.id);

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor:
                Colors.primaries[contact.fullName.hashCode.abs() %
                    Colors.primaries.length],
            backgroundImage: photoPath != null
                ? FileImage(File(photoPath))
                : null,
            child: photoPath == null
                ? Text(
                    contact.fullName.isNotEmpty
                        ? contact.fullName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          if (isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: bgColor, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        contact.fullName,
        style: const TextStyle(
          color: white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        isOnline ? 'online' : statusText,
        style: TextStyle(
          color: isOnline ? Colors.green : white.withOpacity(0.5),
          fontSize: 13,
        ),
      ),
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: white.withOpacity(0.3)),
        color: greyColor,
        onSelected: (value) async {
          if (value == 'message') {
            await _telegramService.createPrivateChat(contact.id);
            if (mounted) Navigator.pop(context);
          } else if (value == 'block') {
            _showBlockConfirmation(contact);
          } else if (value == 'remove') {
            _showRemoveConfirmation(contact);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'message',
            child: Text('Send Message', style: TextStyle(color: white)),
          ),
          const PopupMenuItem(
            value: 'block',
            child: Text('Block User', style: TextStyle(color: Colors.red)),
          ),
          const PopupMenuItem(
            value: 'remove',
            child: Text('Remove Contact', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
      onTap: () async {
        await _telegramService.createPrivateChat(contact.id);
      },
    );
  }

  void _showBlockConfirmation(TelegramContact contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: greyColor,
        title: const Text('Block User', style: TextStyle(color: white)),
        content: Text(
          'Block ${contact.fullName}? They will not be able to contact you.',
          style: TextStyle(color: white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: white.withOpacity(0.7)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _telegramService.toggleBlockUser(contact.id, true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${contact.fullName} blocked')),
                );
              }
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showRemoveConfirmation(TelegramContact contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: greyColor,
        title: const Text('Remove Contact', style: TextStyle(color: white)),
        content: Text(
          'Remove ${contact.fullName} from your contacts?',
          style: TextStyle(color: white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: white.withOpacity(0.7)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _telegramService.removeContact(contact.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${contact.fullName} removed')),
                );
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: greyColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sort Contacts',
                style: TextStyle(
                  color: white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.sort_by_alpha,
                color: _sortMode == 'name'
                    ? const Color(0xFF37AEE2)
                    : white.withOpacity(0.5),
              ),
              title: Text(
                'By Name',
                style: TextStyle(
                  color: _sortMode == 'name' ? const Color(0xFF37AEE2) : white,
                ),
              ),
              trailing: _sortMode == 'name'
                  ? const Icon(Icons.check, color: Color(0xFF37AEE2))
                  : null,
              onTap: () {
                setState(() {
                  _sortMode = 'name';
                  _applyFilter();
                });
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.access_time,
                color: _sortMode == 'lastSeen'
                    ? const Color(0xFF37AEE2)
                    : white.withOpacity(0.5),
              ),
              title: Text(
                'By Last Seen',
                style: TextStyle(
                  color: _sortMode == 'lastSeen'
                      ? const Color(0xFF37AEE2)
                      : white,
                ),
              ),
              trailing: _sortMode == 'lastSeen'
                  ? const Icon(Icons.check, color: Color(0xFF37AEE2))
                  : null,
              onTap: () {
                setState(() {
                  _sortMode = 'lastSeen';
                  _applyFilter();
                });
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
