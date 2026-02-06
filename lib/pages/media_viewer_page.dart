import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:telegramflutter/theme/colors.dart';
import 'package:telegramflutter/services/telegram_service.dart';
import 'package:open_file/open_file.dart';

/// Full-screen photo viewer with zoom and pan
class PhotoViewerPage extends StatefulWidget {
  final String? localPath;
  final int? fileId;
  final String? caption;

  const PhotoViewerPage({super.key, this.localPath, this.fileId, this.caption});

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  final TelegramService _telegramService = TelegramService();
  final TransformationController _transformationController =
      TransformationController();
  String? _localPath;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _localPath = widget.localPath;

    if (_localPath == null && widget.fileId != null) {
      _downloadFile();
    }

    _telegramService.fileDownloadProgressStream.listen((progress) {
      if (progress.fileId == widget.fileId && mounted) {
        setState(() {
          _downloadProgress = progress.progress;
          if (progress.isCompleted && progress.localPath != null) {
            _localPath = progress.localPath;
            _isDownloading = false;
          }
        });
      }
    });
  }

  void _downloadFile() {
    if (widget.fileId == null) return;
    setState(() {
      _isDownloading = true;
    });
    _telegramService.downloadMediaFile(widget.fileId!, priority: 32);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_localPath != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                // Share functionality
              },
            ),
          if (_localPath != null)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Photo saved to: $_localPath')),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _localPath != null
                ? InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.file(
                        File(_localPath!),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.broken_image,
                              color: Colors.white54,
                              size: 64,
                            ),
                      ),
                    ),
                  )
                : Center(
                    child: _isDownloading
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 64,
                                height: 64,
                                child: CircularProgressIndicator(
                                  value: _downloadProgress,
                                  strokeWidth: 3,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '${(_downloadProgress * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          )
                        : IconButton(
                            icon: const Icon(
                              Icons.download,
                              color: Colors.white,
                              size: 48,
                            ),
                            onPressed: _downloadFile,
                          ),
                  ),
          ),
          if (widget.caption != null && widget.caption!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: Text(
                widget.caption!,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-screen video player
class VideoPlayerPage extends StatefulWidget {
  final String? localPath;
  final int? fileId;
  final String? caption;

  const VideoPlayerPage({super.key, this.localPath, this.fileId, this.caption});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  final TelegramService _telegramService = TelegramService();
  VideoPlayerController? _controller;
  String? _localPath;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _showControls = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _localPath = widget.localPath;

    if (_localPath != null) {
      _initializeVideo();
    } else if (widget.fileId != null) {
      _downloadFile();
    }

    _telegramService.fileDownloadProgressStream.listen((progress) {
      if (progress.fileId == widget.fileId && mounted) {
        setState(() {
          _downloadProgress = progress.progress;
          if (progress.isCompleted && progress.localPath != null) {
            _localPath = progress.localPath;
            _isDownloading = false;
            _initializeVideo();
          }
        });
      }
    });
  }

  void _downloadFile() {
    if (widget.fileId == null) return;
    setState(() {
      _isDownloading = true;
    });
    _telegramService.downloadMediaFile(widget.fileId!, priority: 32);
  }

  Future<void> _initializeVideo() async {
    if (_localPath == null) return;

    _controller = VideoPlayerController.file(File(_localPath!));
    await _controller!.initialize();
    setState(() {
      _isInitialized = true;
    });
    _controller!.play();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _showControls
          ? AppBar(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
              elevation: 0,
            )
          : null,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            // Video
            Center(
              child: _isInitialized && _controller != null
                  ? AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    )
                  : _isDownloading
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: CircularProgressIndicator(
                            value: _downloadProgress,
                            strokeWidth: 3,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${(_downloadProgress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.download,
                        color: Colors.white,
                        size: 48,
                      ),
                      onPressed: _downloadFile,
                    ),
            ),
            // Controls
            if (_showControls && _isInitialized && _controller != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress bar
                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: _controller!,
                        builder: (context, value, child) {
                          return Column(
                            children: [
                              Slider(
                                value: value.position.inMilliseconds.toDouble(),
                                min: 0,
                                max:
                                    value.duration.inMilliseconds.toDouble() +
                                    1,
                                onChanged: (newValue) {
                                  _controller!.seekTo(
                                    Duration(milliseconds: newValue.toInt()),
                                  );
                                },
                                activeColor: Colors.white,
                                inactiveColor: Colors.white30,
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(value.position),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(value.duration),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      // Play/Pause button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              _controller!.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: 48,
                            ),
                            onPressed: () {
                              setState(() {
                                if (_controller!.value.isPlaying) {
                                  _controller!.pause();
                                } else {
                                  _controller!.play();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Location message widget
class LocationMessageWidget extends StatelessWidget {
  final double latitude;
  final double longitude;
  final bool isMe;
  final VoidCallback? onTap;

  const LocationMessageWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    this.isMe = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Static map image URL (using OpenStreetMap tiles through a simple service)
    final mapUrl =
        'https://static-maps.yandex.ru/1.x/?lang=en-US&ll=$longitude,$latitude&z=15&l=map&size=300,200&pt=$longitude,$latitude,pm2rdm';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: greyColor,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Container(
                height: 150,
                width: double.infinity,
                color: greyColor,
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.map,
                        size: 64,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: isMe ? Colors.white70 : const Color(0xFF37AEE2),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Location',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  const Icon(
                    Icons.open_in_new,
                    color: Colors.white54,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contact message widget
class ContactMessageWidget extends StatelessWidget {
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final bool isMe;
  final VoidCallback? onTap;

  const ContactMessageWidget({
    super.key,
    required this.firstName,
    this.lastName = '',
    required this.phoneNumber,
    this.isMe = false,
    this.onTap,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final first = firstName.isNotEmpty ? firstName[0] : '';
    final last = lastName.isNotEmpty ? lastName[0] : '';
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: greyColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isMe ? const Color(0xFF2B5278) : const Color(0xFF37AEE2),
              ),
              child: Center(
                child: Text(
                  initials.isNotEmpty ? initials : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fullName.isNotEmpty ? fullName : 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phoneNumber,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Audio message widget with playback
class AudioMessageWidget extends StatelessWidget {
  final String title;
  final String performer;
  final int? duration;
  final int? fileSize;
  final bool isDownloaded;
  final bool isDownloading;
  final double downloadProgress;
  final bool isPlaying;
  final double playbackProgress;
  final VoidCallback? onPlayPause;
  final VoidCallback? onDownload;

  const AudioMessageWidget({
    super.key,
    required this.title,
    this.performer = '',
    this.duration,
    this.fileSize,
    this.isDownloaded = false,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
    this.isPlaying = false,
    this.playbackProgress = 0.0,
    this.onPlayPause,
    this.onDownload,
  });

  String get durationText {
    if (duration == null) return '';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: greyColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: isDownloaded ? onPlayPause : onDownload,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF2B5278),
                shape: BoxShape.circle,
              ),
              child: isDownloading
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        value: downloadProgress,
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                  : Icon(
                      isDownloaded
                          ? (isPlaying ? Icons.pause : Icons.play_arrow)
                          : Icons.download,
                      color: Colors.white,
                      size: 28,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.isNotEmpty ? title : 'Audio',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (performer.isNotEmpty)
                  Text(
                    performer,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      durationText,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                    if (fileSize != null) ...[
                      Text(
                        ' • ',
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                      Text(
                        _formatFileSize(fileSize!),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                if (isDownloaded) ...[
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: playbackProgress,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF37AEE2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
