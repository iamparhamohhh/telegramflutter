import 'dart:async';

import 'package:flutter/material.dart';
import 'package:telegramflutter/services/telegram_service.dart';
import 'package:telegramflutter/theme/colors.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final TelegramService _telegramService = TelegramService();
  StreamSubscription? _settingsSub;
  StreamSubscription? _soundsSub;

  // Per-scope settings
  bool _privateEnabled = true;
  bool _privatePreview = true;
  int _privateSoundId = 0;

  bool _groupEnabled = true;
  bool _groupPreview = true;
  int _groupSoundId = 0;

  bool _channelEnabled = true;
  bool _channelPreview = true;
  int _channelSoundId = 0;

  // General
  bool _inAppSounds = true;
  bool _inAppVibrate = true;
  bool _inAppPreview = true;

  // Badge
  bool _badgeCountEnabled = true;
  bool _badgeIncludeMuted = false;

  bool _isLoading = true;

  List<NotificationSoundInfo> _sounds = [];

  @override
  void initState() {
    super.initState();
    _settingsSub = _telegramService.notificationSettingsStream.listen((
      settings,
    ) {
      if (mounted) {
        setState(() {
          _applySettings(settings);
          _isLoading = false;
        });
      }
    });
    _soundsSub = _telegramService.notificationSoundsStream.listen((sounds) {
      if (mounted) {
        setState(() => _sounds = sounds);
      }
    });
    _loadSettings();
  }

  void _applySettings(Map<String, NotificationScopeSettings> settings) {
    final priv = settings['private'];
    if (priv != null) {
      _privateEnabled = !priv.isMuted;
      _privatePreview = priv.showPreview;
      _privateSoundId = priv.soundId;
    }
    final grp = settings['group'];
    if (grp != null) {
      _groupEnabled = !grp.isMuted;
      _groupPreview = grp.showPreview;
      _groupSoundId = grp.soundId;
    }
    final ch = settings['channel'];
    if (ch != null) {
      _channelEnabled = !ch.isMuted;
      _channelPreview = ch.showPreview;
      _channelSoundId = ch.soundId;
    }
  }

  Future<void> _loadSettings() async {
    await _telegramService.loadAllNotificationSettings();
    _telegramService.getNotificationSounds();
    // Give time for responses
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _soundsSub?.cancel();
    super.dispose();
  }

  void _updateScope(String scope) {
    bool muted;
    bool showPreview;
    int soundId;
    switch (scope) {
      case 'private':
        muted = !_privateEnabled;
        showPreview = _privatePreview;
        soundId = _privateSoundId;
        break;
      case 'group':
        muted = !_groupEnabled;
        showPreview = _groupPreview;
        soundId = _groupSoundId;
        break;
      case 'channel':
        muted = !_channelEnabled;
        showPreview = _channelPreview;
        soundId = _channelSoundId;
        break;
      default:
        return;
    }
    _telegramService.setScopeNotificationSettings(
      scope: scope,
      muted: muted,
      showPreview: showPreview,
      soundId: soundId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: greyColor,
        title: const Text(
          'Notifications and Sounds',
          style: TextStyle(color: white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF37AEE2)),
            )
          : ListView(
              children: [
                const SizedBox(height: 16),
                // ── Private Chats ──
                _buildSectionHeader('PRIVATE CHATS'),
                _buildSwitchTile(
                  'Notifications',
                  'Show notifications for private chats',
                  _privateEnabled,
                  Icons.person_outline,
                  (v) {
                    setState(() => _privateEnabled = v);
                    _updateScope('private');
                  },
                ),
                _buildSwitchTile(
                  'Message Preview',
                  'Show message text in notifications',
                  _privatePreview,
                  Icons.visibility_outlined,
                  _privateEnabled
                      ? (v) {
                          setState(() => _privatePreview = v);
                          _updateScope('private');
                        }
                      : null,
                ),
                _buildSoundSelector(
                  'Sound',
                  _privateSoundId,
                  _privateEnabled
                      ? (id) {
                          setState(() => _privateSoundId = id);
                          _updateScope('private');
                        }
                      : null,
                ),
                const SizedBox(height: 24),

                // ── Group Chats ──
                _buildSectionHeader('GROUPS'),
                _buildSwitchTile(
                  'Notifications',
                  'Show notifications for group chats',
                  _groupEnabled,
                  Icons.group_outlined,
                  (v) {
                    setState(() => _groupEnabled = v);
                    _updateScope('group');
                  },
                ),
                _buildSwitchTile(
                  'Message Preview',
                  'Show message text in notifications',
                  _groupPreview,
                  Icons.visibility_outlined,
                  _groupEnabled
                      ? (v) {
                          setState(() => _groupPreview = v);
                          _updateScope('group');
                        }
                      : null,
                ),
                _buildSoundSelector(
                  'Sound',
                  _groupSoundId,
                  _groupEnabled
                      ? (id) {
                          setState(() => _groupSoundId = id);
                          _updateScope('group');
                        }
                      : null,
                ),
                const SizedBox(height: 24),

                // ── Channels ──
                _buildSectionHeader('CHANNELS'),
                _buildSwitchTile(
                  'Notifications',
                  'Show notifications for channels',
                  _channelEnabled,
                  Icons.campaign_outlined,
                  (v) {
                    setState(() => _channelEnabled = v);
                    _updateScope('channel');
                  },
                ),
                _buildSwitchTile(
                  'Message Preview',
                  'Show message text in notifications',
                  _channelPreview,
                  Icons.visibility_outlined,
                  _channelEnabled
                      ? (v) {
                          setState(() => _channelPreview = v);
                          _updateScope('channel');
                        }
                      : null,
                ),
                _buildSoundSelector(
                  'Sound',
                  _channelSoundId,
                  _channelEnabled
                      ? (id) {
                          setState(() => _channelSoundId = id);
                          _updateScope('channel');
                        }
                      : null,
                ),
                const SizedBox(height: 24),

                // ── In-App Notifications ──
                _buildSectionHeader('IN-APP NOTIFICATIONS'),
                _buildSwitchTile(
                  'In-App Sounds',
                  'Play notification sounds while in the app',
                  _inAppSounds,
                  Icons.volume_up_outlined,
                  (v) => setState(() => _inAppSounds = v),
                ),
                _buildSwitchTile(
                  'In-App Vibrate',
                  'Vibrate on new messages while in the app',
                  _inAppVibrate,
                  Icons.vibration,
                  (v) => setState(() => _inAppVibrate = v),
                ),
                _buildSwitchTile(
                  'In-App Preview',
                  'Show pop-up notifications while in the app',
                  _inAppPreview,
                  Icons.notifications_active_outlined,
                  (v) => setState(() => _inAppPreview = v),
                ),
                const SizedBox(height: 24),

                // ── Badge Counter ──
                _buildSectionHeader('BADGE COUNTER'),
                _buildSwitchTile(
                  'Badge Counter',
                  'Show unread message count on the app icon',
                  _badgeCountEnabled,
                  Icons.pin_outlined,
                  (v) => setState(() => _badgeCountEnabled = v),
                ),
                _buildSwitchTile(
                  'Include Muted Chats',
                  'Count messages from muted chats',
                  _badgeIncludeMuted,
                  Icons.notifications_off_outlined,
                  _badgeCountEnabled
                      ? (v) => setState(() => _badgeIncludeMuted = v)
                      : null,
                ),
                const SizedBox(height: 24),

                // ── Reset ──
                _buildSectionHeader('RESET'),
                ListTile(
                  onTap: _resetAllNotifications,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.restore,
                      color: Colors.redAccent,
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    'Reset All Notifications',
                    style: TextStyle(color: Colors.redAccent, fontSize: 16),
                  ),
                  subtitle: Text(
                    'Undo all custom notification settings',
                    style: TextStyle(
                      color: white.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF37AEE2),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    IconData icon,
    ValueChanged<bool>? onChanged,
  ) {
    final enabled = onChanged != null;
    return SwitchListTile(
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (enabled ? const Color(0xFF37AEE2) : Colors.grey).withOpacity(
            0.2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: enabled ? const Color(0xFF37AEE2) : Colors.grey,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? white : white.withOpacity(0.4),
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: white.withOpacity(0.5), fontSize: 13),
      ),
      value: value,
      activeColor: const Color(0xFF37AEE2),
      onChanged: onChanged,
    );
  }

  Widget _buildSoundSelector(
    String label,
    int currentSoundId,
    ValueChanged<int>? onChanged,
  ) {
    final enabled = onChanged != null;
    final soundName = _getSoundName(currentSoundId);

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (enabled ? Colors.orange : Colors.grey).withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.music_note_outlined,
          color: enabled ? Colors.orange : Colors.grey,
          size: 22,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: enabled ? white : white.withOpacity(0.4),
          fontSize: 16,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            soundName,
            style: TextStyle(
              color: enabled ? const Color(0xFF37AEE2) : white.withOpacity(0.3),
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: white.withOpacity(0.3)),
        ],
      ),
      onTap: enabled ? () => _showSoundPicker(currentSoundId, onChanged) : null,
    );
  }

  String _getSoundName(int soundId) {
    if (soundId == 0) return 'Default';
    final match = _sounds.where((s) => s.id == soundId);
    if (match.isNotEmpty) return match.first.title;
    return 'Custom';
  }

  void _showSoundPicker(int currentId, ValueChanged<int> onChanged) {
    final allSounds = [
      NotificationSoundInfo(id: 0, title: 'Default'),
      ..._sounds,
    ];

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
                'Notification Sound',
                style: TextStyle(
                  color: white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // No sound option
            ListTile(
              leading: Icon(
                Icons.notifications_off_outlined,
                color: currentId == -1
                    ? const Color(0xFF37AEE2)
                    : white.withOpacity(0.7),
              ),
              title: Text(
                'No Sound',
                style: TextStyle(
                  color: currentId == -1 ? const Color(0xFF37AEE2) : white,
                ),
              ),
              trailing: currentId == -1
                  ? const Icon(Icons.check, color: Color(0xFF37AEE2))
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                onChanged(-1);
              },
            ),
            const Divider(color: Colors.white12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: allSounds.length,
                itemBuilder: (_, i) {
                  final sound = allSounds[i];
                  final isSelected = sound.id == currentId;
                  return ListTile(
                    leading: Icon(
                      Icons.music_note,
                      color: isSelected
                          ? const Color(0xFF37AEE2)
                          : white.withOpacity(0.7),
                    ),
                    title: Text(
                      sound.title,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF37AEE2) : white,
                      ),
                    ),
                    subtitle: sound.duration > 0
                        ? Text(
                            '${sound.duration}s',
                            style: TextStyle(
                              color: white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          )
                        : null,
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Color(0xFF37AEE2))
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onChanged(sound.id);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _resetAllNotifications() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: greyColor,
        title: const Text(
          'Reset Notifications',
          style: TextStyle(color: white),
        ),
        content: Text(
          'Reset all notification settings to defaults?',
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
            onPressed: () {
              Navigator.pop(ctx);
              // Reset all scopes to defaults
              for (final scope in ['private', 'group', 'channel']) {
                _telegramService.setScopeNotificationSettings(
                  scope: scope,
                  muted: false,
                  showPreview: true,
                  soundId: 0,
                );
              }
              setState(() {
                _privateEnabled = true;
                _privatePreview = true;
                _privateSoundId = 0;
                _groupEnabled = true;
                _groupPreview = true;
                _groupSoundId = 0;
                _channelEnabled = true;
                _channelPreview = true;
                _channelSoundId = 0;
                _inAppSounds = true;
                _inAppVibrate = true;
                _inAppPreview = true;
                _badgeCountEnabled = true;
                _badgeIncludeMuted = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification settings reset')),
              );
            },
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
