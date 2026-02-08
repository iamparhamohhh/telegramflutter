import 'dart:io';
import 'package:flutter/material.dart';
import 'package:telegramflutter/services/telegram_service.dart';
import 'package:telegramflutter/theme/colors.dart';
import 'package:telegramflutter/widgets/media_widgets.dart';
import 'package:telegramflutter/pages/call_page.dart';

/// Profile page for viewing user/chat details
class ProfilePage extends StatefulWidget {
  final int chatId;
  final String chatTitle;
  final String? chatPhotoPath;

  const ProfilePage({
    super.key,
    required this.chatId,
    required this.chatTitle,
    this.chatPhotoPath,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final _telegramService = TelegramService();
  late TabController _tabController;

  int? _userId;
  String _statusText = '';
  bool _isOnline = false;
  String? _bio;
  String? _phoneNumber;
  String? _username;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfileData();
  }

  void _loadProfileData() {
    // Get user ID for private chats
    _userId = _telegramService.getChatUserId(widget.chatId);

    if (_userId != null) {
      // Request full user info
      _telegramService.requestUserFullInfo(_userId!);

      final user = _telegramService.getUser(_userId!);
      if (user != null) {
        setState(() {
          _statusText = _telegramService.getUserStatusText(_userId!);
          _isOnline = _telegramService.isUserOnline(_userId!);
          _phoneNumber = user.phoneNumber.isNotEmpty
              ? '+${user.phoneNumber}'
              : null;
          _username = user.usernames?.activeUsernames.isNotEmpty == true
              ? '@${user.usernames!.activeUsernames.first}'
              : null;
        });
      }
    }

    setState(() {
      _statusText = _telegramService.getChatSubtitle(widget.chatId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: bgColor,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onPressed: () {
                    _showMoreOptions(context);
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _buildProfileHeader(),
              ),
            ),
            SliverToBoxAdapter(child: _buildInfoSection()),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.blue,
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.white54,
                  tabs: const [
                    Tab(text: 'Media'),
                    Tab(text: 'Files'),
                    Tab(text: 'Links'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [_buildMediaTab(), _buildFilesTab(), _buildLinksTab()],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background photo or gradient
        widget.chatPhotoPath != null
            ? Image.file(
                File(widget.chatPhotoPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildGradientBackground(),
              )
            : _buildGradientBackground(),

        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
            ),
          ),
        ),

        // Profile info
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  UserAvatar(
                    photoPath: widget.chatPhotoPath,
                    name: widget.chatTitle,
                    size: 80,
                    isOnline: _isOnline,
                    showOnlineIndicator: _userId != null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.chatTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _statusText,
                          style: TextStyle(
                            color: _isOnline
                                ? Colors.lightBlueAccent
                                : Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGradientBackground() {
    // Generate a gradient based on the chat title
    final colors = [
      [Colors.blue.shade700, Colors.blue.shade400],
      [Colors.purple.shade700, Colors.purple.shade400],
      [Colors.teal.shade700, Colors.teal.shade400],
      [Colors.orange.shade700, Colors.orange.shade400],
      [Colors.pink.shade700, Colors.pink.shade400],
    ];
    final index = widget.chatTitle.hashCode.abs() % colors.length;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors[index][0], colors[index][1]],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      color: greyColor,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_phoneNumber != null)
            _buildInfoTile(
              icon: Icons.phone,
              title: _phoneNumber!,
              subtitle: 'Mobile',
              onTap: () {
                // Copy phone number
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone number copied')),
                );
              },
            ),
          if (_username != null)
            _buildInfoTile(
              icon: Icons.alternate_email,
              title: _username!,
              subtitle: 'Username',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Username copied')),
                );
              },
            ),
          if (_bio != null && _bio!.isNotEmpty)
            _buildInfoTile(
              icon: Icons.info_outline,
              title: _bio!,
              subtitle: 'Bio',
            ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white54),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      onTap: onTap,
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.message,
            label: 'Message',
            onTap: () => Navigator.pop(context),
          ),
          if (_userId != null)
            _buildActionButton(
              icon: Icons.call,
              label: 'Call',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CallPage(
                      userId: _userId!,
                      userName: widget.chatTitle,
                      userPhoto: widget.chatPhotoPath,
                    ),
                  ),
                );
              },
            ),
          if (_userId != null)
            _buildActionButton(
              icon: Icons.videocam,
              label: 'Video',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CallPage(
                      userId: _userId!,
                      userName: widget.chatTitle,
                      userPhoto: widget.chatPhotoPath,
                      isVideo: true,
                    ),
                  ),
                );
              },
            ),
          _buildActionButton(
            icon: Icons.notifications,
            label: 'Mute',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification settings coming soon'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaTab() {
    // TODO: Load shared media from TDLib
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          Text(
            'Shared media will appear here',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesTab() {
    // TODO: Load shared files from TDLib
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          Text(
            'Shared files will appear here',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildLinksTab() {
    // TODO: Load shared links from TDLib
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          Text(
            'Shared links will appear here',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: greyColor,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share, color: Colors.white),
                title: const Text(
                  'Share',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share coming soon')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.search, color: Colors.white),
                title: const Text(
                  'Search',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Search coming soon')),
                  );
                },
              ),
              if (_userId != null)
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.red),
                  title: const Text(
                    'Block User',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showBlockUserDialog();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Chat',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Delete chat coming soon')),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBlockUserDialog() {
    if (_userId == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: greyColor,
        title: const Text('Block User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Block ${widget.chatTitle}? They will not be able to contact you.',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _telegramService.toggleBlockUser(_userId!, true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${widget.chatTitle} blocked')),
                );
              }
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// Delegate for pinned tab bar
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: greyColor, child: tabBar);
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}
