import 'dart:async';
import 'package:flutter/material.dart';
import 'package:line_icons/line_icons.dart';
import '../services/telegram_service.dart';
import '../theme/colors.dart';

class DataStoragePage extends StatefulWidget {
  const DataStoragePage({super.key});

  @override
  State<DataStoragePage> createState() => _DataStoragePageState();
}

class _DataStoragePageState extends State<DataStoragePage> {
  final _telegramService = TelegramService();
  bool _loading = true;
  Map<String, dynamic>? _stats;

  // Auto-download settings (local state)
  bool _autoDownloadPhotos = true;
  bool _autoDownloadVideos = false;
  bool _autoDownloadDocuments = false;
  bool _autoDownloadVoice = true;
  bool _autoDownloadVideoMessages = true;

  // Data saving
  bool _dataSaving = false;

  @override
  void initState() {
    super.initState();
    _loadStorageStats();
  }

  void _loadStorageStats() {
    setState(() => _loading = true);
    _telegramService.getStorageStatistics();
    // Listen for storage stats update
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _stats = _telegramService.storageStatistics;
          _loading = false;
        });
      }
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  int _getTotalSize() {
    return _stats?['size'] as int? ?? 0;
  }

  int _getTotalCount() {
    return _stats?['count'] as int? ?? 0;
  }

  List<Map<String, dynamic>> _getFileBreakdown() {
    final byFileType = _stats?['by_file_type'] as List<dynamic>? ?? [];
    List<Map<String, dynamic>> breakdown = [];
    for (final item in byFileType) {
      final map = item as Map<String, dynamic>;
      final fileType = map['file_type'] as Map<String, dynamic>?;
      if (fileType != null) {
        final typeName = fileType['@type'] as String? ?? '';
        final size = map['size'] as int? ?? 0;
        final count = map['count'] as int? ?? 0;
        if (size > 0) {
          breakdown.add({
            'type': _friendlyTypeName(typeName),
            'size': size,
            'count': count,
            'icon': _typeIcon(typeName),
            'color': _typeColor(typeName),
          });
        }
      }
    }
    breakdown.sort((a, b) => (b['size'] as int).compareTo(a['size'] as int));
    return breakdown;
  }

  String _friendlyTypeName(String type) {
    switch (type) {
      case 'fileTypePhoto':
        return 'Photos';
      case 'fileTypeVideo':
        return 'Videos';
      case 'fileTypeDocument':
        return 'Documents';
      case 'fileTypeAudio':
        return 'Audio';
      case 'fileTypeVoiceNote':
        return 'Voice Messages';
      case 'fileTypeVideoNote':
        return 'Video Messages';
      case 'fileTypeAnimation':
        return 'GIFs';
      case 'fileTypeSticker':
        return 'Stickers';
      case 'fileTypeProfilePhoto':
        return 'Profile Photos';
      case 'fileTypeThumbnail':
        return 'Thumbnails';
      case 'fileTypeWallpaper':
        return 'Wallpapers';
      default:
        return 'Other';
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'fileTypePhoto':
        return LineIcons.image;
      case 'fileTypeVideo':
        return LineIcons.video;
      case 'fileTypeDocument':
        return LineIcons.file;
      case 'fileTypeAudio':
        return LineIcons.music;
      case 'fileTypeVoiceNote':
        return LineIcons.microphone;
      case 'fileTypeVideoNote':
        return LineIcons.videoSlash;
      case 'fileTypeAnimation':
        return LineIcons.photoVideo;
      case 'fileTypeSticker':
        return LineIcons.stickyNote;
      default:
        return LineIcons.folder;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'fileTypePhoto':
        return Colors.blue;
      case 'fileTypeVideo':
        return Colors.red;
      case 'fileTypeDocument':
        return Colors.orange;
      case 'fileTypeAudio':
        return Colors.purple;
      case 'fileTypeVoiceNote':
        return Colors.teal;
      case 'fileTypeVideoNote':
        return Colors.indigo;
      case 'fileTypeAnimation':
        return Colors.green;
      case 'fileTypeSticker':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surface,
        title: Text('Clear Cache', style: TextStyle(color: context.onSurface)),
        content: Text(
          'This will free up ${_formatBytes(_getTotalSize())} of storage. '
          'Cached media will be re-downloaded when needed.',
          style: TextStyle(color: context.onSurface.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.onSurface.withOpacity(0.5)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _telegramService.optimizeStorage(size: 0);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
              Future.delayed(const Duration(seconds: 1), _loadStorageStats);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final breakdown = _getFileBreakdown();

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.appBarBg,
        title: Text(
          'Data and Storage',
          style: TextStyle(color: context.onSurface),
        ),
        iconTheme: IconThemeData(color: context.onSurface),
      ),
      body: ListView(
        children: [
          // ─── Storage Usage ─────────────────────────────────
          _buildSectionHeader('STORAGE USAGE'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatBytes(_getTotalSize()),
                                style: TextStyle(
                                  color: context.onSurface,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_getTotalCount()} files cached',
                                style: TextStyle(
                                  color: context.onSurface.withOpacity(0.5),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: _loadStorageStats,
                            icon: Icon(
                              LineIcons.syncIcon,
                              color: context.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                      if (breakdown.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        // Storage bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 8,
                            child: Row(
                              children: breakdown.map((item) {
                                final fraction =
                                    (item['size'] as int) / _getTotalSize();
                                return Expanded(
                                  flex: (fraction * 1000).round().clamp(
                                    1,
                                    1000,
                                  ),
                                  child: Container(
                                    color: item['color'] as Color,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Breakdown list
                        ...breakdown.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: item['color'] as Color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item['type'] as String,
                                    style: TextStyle(
                                      color: context.onSurface,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${item['count']} files',
                                  style: TextStyle(
                                    color: context.onSurface.withOpacity(0.4),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _formatBytes(item['size'] as int),
                                  style: TextStyle(
                                    color: context.onSurface.withOpacity(0.6),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),

          // Clear cache button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(LineIcons.trash, color: Colors.red),
              title: const Text(
                'Clear Cache',
                style: TextStyle(color: Colors.red),
              ),
              onTap: _showClearCacheDialog,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // ─── Auto-Download Media ───────────────────────────
          _buildSectionHeader('AUTO-DOWNLOAD MEDIA'),
          _buildAutoDownloadSection(),

          // ─── Data Saving ───────────────────────────────────
          _buildSectionHeader('DATA SAVING'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'Data Saving Mode',
                    style: TextStyle(color: context.onSurface),
                  ),
                  subtitle: Text(
                    'Reduce data usage for calls and media',
                    style: TextStyle(
                      color: context.onSurface.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  ),
                  value: _dataSaving,
                  onChanged: (val) => setState(() => _dataSaving = val),
                  activeColor: Colors.blue,
                ),
              ],
            ),
          ),

          // ─── Network Usage ─────────────────────────────────
          _buildSectionHeader('NETWORK'),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildNetworkItem(
                  LineIcons.wifi,
                  'Wi-Fi',
                  'Unlimited',
                  Colors.green,
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: context.onSurface.withOpacity(0.1),
                ),
                _buildNetworkItem(
                  LineIcons.signal,
                  'Mobile Data',
                  'Standard quality',
                  Colors.blue,
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: context.onSurface.withOpacity(0.1),
                ),
                _buildNetworkItem(
                  LineIcons.broadcastTower,
                  'Roaming',
                  'Limited',
                  Colors.orange,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: context.onSurface.withOpacity(0.5),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAutoDownloadSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildToggleTile(
            LineIcons.image,
            'Photos',
            'Auto-download photos',
            _autoDownloadPhotos,
            (v) => setState(() => _autoDownloadPhotos = v),
            Colors.blue,
          ),
          Divider(
            height: 1,
            indent: 56,
            color: context.onSurface.withOpacity(0.1),
          ),
          _buildToggleTile(
            LineIcons.video,
            'Videos',
            'Up to 15 MB',
            _autoDownloadVideos,
            (v) => setState(() => _autoDownloadVideos = v),
            Colors.red,
          ),
          Divider(
            height: 1,
            indent: 56,
            color: context.onSurface.withOpacity(0.1),
          ),
          _buildToggleTile(
            LineIcons.file,
            'Documents',
            'Up to 1 MB',
            _autoDownloadDocuments,
            (v) => setState(() => _autoDownloadDocuments = v),
            Colors.orange,
          ),
          Divider(
            height: 1,
            indent: 56,
            color: context.onSurface.withOpacity(0.1),
          ),
          _buildToggleTile(
            LineIcons.microphone,
            'Voice Messages',
            'Always download',
            _autoDownloadVoice,
            (v) => setState(() => _autoDownloadVoice = v),
            Colors.teal,
          ),
          Divider(
            height: 1,
            indent: 56,
            color: context.onSurface.withOpacity(0.1),
          ),
          _buildToggleTile(
            LineIcons.videoSlash,
            'Video Messages',
            'Always download',
            _autoDownloadVideoMessages,
            (v) => setState(() => _autoDownloadVideoMessages = v),
            Colors.indigo,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    Color iconColor,
  ) {
    return SwitchListTile(
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(color: context.onSurface, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: context.onSurface.withOpacity(0.5),
          fontSize: 12,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.blue,
    );
  }

  Widget _buildNetworkItem(
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        title,
        style: TextStyle(color: context.onSurface, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: context.onSurface.withOpacity(0.5),
          fontSize: 12,
        ),
      ),
      trailing: Icon(
        LineIcons.angleRight,
        color: context.onSurface.withOpacity(0.3),
        size: 16,
      ),
    );
  }
}
