import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/telegram_service.dart';
import '../theme/colors.dart';

/// Story viewer page - displays story content fullscreen
class StoryViewerPage extends StatefulWidget {
  final int storySenderChatId;
  final String senderName;
  final String? senderPhoto;
  final List<Map<String, dynamic>> stories;
  final int initialIndex;

  const StoryViewerPage({
    super.key,
    required this.storySenderChatId,
    required this.senderName,
    this.senderPhoto,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage>
    with SingleTickerProviderStateMixin {
  final TelegramService _telegramService = TelegramService();
  late PageController _pageController;
  late AnimationController _progressController;
  int _currentIndex = 0;
  bool _isPaused = false; // ignore: unused_field

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _progressController =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _nextStory();
            }
          });

    _startStory();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    // Close story view
    if (widget.stories.isNotEmpty && _currentIndex < widget.stories.length) {
      final story = widget.stories[_currentIndex];
      _telegramService.closeStory(
        widget.storySenderChatId,
        story['id'] as int? ?? 0,
      );
    }
    super.dispose();
  }

  void _startStory() {
    if (_currentIndex >= widget.stories.length) return;
    final story = widget.stories[_currentIndex];
    final storyId = story['id'] as int? ?? 0;
    _telegramService.openStory(widget.storySenderChatId, storyId);
    _progressController.forward(from: 0);
  }

  void _nextStory() {
    // Close current
    if (_currentIndex < widget.stories.length) {
      final story = widget.stories[_currentIndex];
      _telegramService.closeStory(
        widget.storySenderChatId,
        story['id'] as int? ?? 0,
      );
    }

    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startStory();
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      // Close current
      final story = widget.stories[_currentIndex];
      _telegramService.closeStory(
        widget.storySenderChatId,
        story['id'] as int? ?? 0,
      );

      setState(() => _currentIndex--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startStory();
    } else {
      _progressController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _previousStory();
          } else if (details.globalPosition.dx > width * 2 / 3) {
            _nextStory();
          }
        },
        onLongPressStart: (_) {
          setState(() => _isPaused = true);
          _progressController.stop();
        },
        onLongPressEnd: (_) {
          setState(() => _isPaused = false);
          _progressController.forward();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Story content
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.stories.length,
              itemBuilder: (context, index) {
                return _buildStoryContent(widget.stories[index]);
              },
            ),

            // Top overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                  ),
                ),
                child: Column(
                  children: [
                    // Progress bars
                    Row(
                      children: List.generate(widget.stories.length, (i) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 2),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: i < _currentIndex
                                  ? Container(height: 3, color: Colors.white)
                                  : i == _currentIndex
                                  ? AnimatedBuilder(
                                      animation: _progressController,
                                      builder: (ctx, _) {
                                        return LinearProgressIndicator(
                                          value: _progressController.value,
                                          backgroundColor: Colors.white24,
                                          valueColor:
                                              const AlwaysStoppedAnimation(
                                                Colors.white,
                                              ),
                                          minHeight: 3,
                                        );
                                      },
                                    )
                                  : Container(height: 3, color: Colors.white24),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 12),

                    // User info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue,
                          backgroundImage: widget.senderPhoto != null
                              ? FileImage(File(widget.senderPhoto!))
                              : null,
                          child: widget.senderPhoto == null
                              ? Text(
                                  widget.senderName.isNotEmpty
                                      ? widget.senderName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.senderName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              if (_currentIndex < widget.stories.length)
                                Text(
                                  _getTimeAgo(widget.stories[_currentIndex]),
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom caption overlay
            if (_currentIndex < widget.stories.length &&
                (widget.stories[_currentIndex]['caption'] as String? ?? '')
                    .isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    widget.stories[_currentIndex]['caption'] as String? ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryContent(Map<String, dynamic> story) {
    final photoPath = story['photoPath'] as String?;
    final videoPath = story['videoPath'] as String?;

    if (photoPath != null && photoPath.isNotEmpty) {
      return Image.file(
        File(photoPath),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    } else if (videoPath != null && videoPath.isNotEmpty) {
      // Video playback placeholder
      return Stack(
        alignment: Alignment.center,
        children: [
          _buildPlaceholder(),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
          ),
        ],
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF1a1a2e),
      child: const Center(
        child: Icon(Icons.image, color: Colors.white24, size: 72),
      ),
    );
  }

  String _getTimeAgo(Map<String, dynamic> story) {
    final date = story['date'] as int? ?? 0;
    if (date == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(date * 1000);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Story creation page - pick photo/video and post
class StoryCreationPage extends StatefulWidget {
  const StoryCreationPage({super.key});

  @override
  State<StoryCreationPage> createState() => _StoryCreationPageState();
}

class _StoryCreationPageState extends State<StoryCreationPage> {
  final TelegramService _telegramService = TelegramService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();

  XFile? _selectedFile;
  bool _isVideo = false;
  bool _isSending = false;
  int _privacyType = 0; // 0=everyone, 1=contacts, 2=close friends

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (file != null && mounted) {
      setState(() {
        _selectedFile = file;
        _isVideo = false;
      });
    }
  }

  Future<void> _takePhoto() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (file != null && mounted) {
      setState(() {
        _selectedFile = file;
        _isVideo = false;
      });
    }
  }

  Future<void> _pickVideo() async {
    final file = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );
    if (file != null && mounted) {
      setState(() {
        _selectedFile = file;
        _isVideo = true;
      });
    }
  }

  Future<void> _sendStory() async {
    if (_selectedFile == null) return;
    setState(() => _isSending = true);

    if (_isVideo) {
      await _telegramService.sendVideoStory(
        _selectedFile!.path,
        caption: _captionController.text.trim(),
        privacyRulesType: _privacyType,
      );
    } else {
      await _telegramService.sendPhotoStory(
        _selectedFile!.path,
        caption: _captionController.text.trim(),
        privacyRulesType: _privacyType,
      );
    }

    if (mounted) Navigator.pop(context, true);
  }

  String get _privacyLabel {
    switch (_privacyType) {
      case 1:
        return 'Contacts';
      case 2:
        return 'Close Friends';
      default:
        return 'Everyone';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.appBarBg,
        leading: IconButton(
          icon: Icon(Icons.close, color: context.appBarText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('New Story', style: TextStyle(color: context.appBarText)),
        actions: [
          if (_selectedFile != null)
            TextButton(
              onPressed: _isSending ? null : _sendStory,
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blue,
                      ),
                    )
                  : const Text(
                      'Post',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
        ],
      ),
      body: _selectedFile == null ? _buildPicker() : _buildPreview(),
    );
  }

  Widget _buildPicker() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo, color: Colors.white24, size: 72),
          const SizedBox(height: 24),
          const Text(
            'Share a Story',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a photo or video to share',
            style: TextStyle(color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPickerButton(
                icon: Icons.photo_library,
                label: 'Gallery',
                color: Colors.purple,
                onTap: _pickPhoto,
              ),
              const SizedBox(width: 24),
              _buildPickerButton(
                icon: Icons.camera_alt,
                label: 'Camera',
                color: Colors.red,
                onTap: _takePhoto,
              ),
              const SizedBox(width: 24),
              _buildPickerButton(
                icon: Icons.videocam,
                label: 'Video',
                color: Colors.orange,
                onTap: _pickVideo,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        // Preview
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.black,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _isVideo
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.videocam,
                                color: Colors.white54,
                                size: 48,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedFile!.name,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Image.file(
                          File(_selectedFile!.path),
                          fit: BoxFit.contain,
                        ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 24,
                      ),
                      onPressed: () => setState(() => _selectedFile = null),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Caption + privacy
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              // Caption
              TextField(
                controller: _captionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Add a caption...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  filled: true,
                  fillColor: context.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  counterStyle: const TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              // Privacy
              GestureDetector(
                onTap: _showPrivacyPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility, color: Colors.white54),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Who can see',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _privacyLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white54),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showPrivacyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Who can see your story',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            RadioListTile<int>(
              value: 0,
              groupValue: _privacyType,
              title: const Text(
                'Everyone',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'All Telegram users',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              activeColor: Colors.blue,
              onChanged: (v) {
                setState(() => _privacyType = v!);
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<int>(
              value: 1,
              groupValue: _privacyType,
              title: const Text(
                'Contacts',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Your contacts only',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              activeColor: Colors.blue,
              onChanged: (v) {
                setState(() => _privacyType = v!);
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<int>(
              value: 2,
              groupValue: _privacyType,
              title: const Text(
                'Close Friends',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Your close friends list',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              activeColor: Colors.blue,
              onChanged: (v) {
                setState(() => _privacyType = v!);
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
