import 'dart:io';
import 'package:flutter/material.dart';
import 'package:telegramflutter/models/user_profile.dart';
import 'package:telegramflutter/theme/colors.dart';

/// Widget for displaying photo messages
class PhotoMessageWidget extends StatelessWidget {
  final MediaInfo mediaInfo;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;

  const PhotoMessageWidget({
    super.key,
    required this.mediaInfo,
    this.onTap,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.65,
            maxHeight: 300,
          ),
          child: Stack(
            children: [
              _buildImage(),
              if (mediaInfo.isDownloading) _buildDownloadProgress(),
              if (!mediaInfo.isDownloaded && !mediaInfo.isDownloading)
                _buildDownloadButton(),
              if (mediaInfo.caption != null && mediaInfo.caption!.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Text(
                      mediaInfo.caption!,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (mediaInfo.hasLocalFile) {
      return Image.file(
        File(mediaInfo.localPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    } else if (mediaInfo.thumbnailPath != null) {
      return Image.file(
        File(mediaInfo.thumbnailPath!),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: mediaInfo.width?.toDouble() ?? 200,
      height: mediaInfo.height?.toDouble() ?? 200,
      color: greyColor,
      child: const Icon(Icons.photo, color: Colors.white54, size: 48),
    );
  }

  Widget _buildDownloadProgress() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: mediaInfo.downloadProgress,
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                Text(
                  '${(mediaInfo.downloadProgress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadButton() {
    return Positioned.fill(
      child: Container(
        color: Colors.black38,
        child: Center(
          child: IconButton(
            icon: const Icon(Icons.download, color: Colors.white, size: 32),
            onPressed: onDownload,
          ),
        ),
      ),
    );
  }
}

/// Widget for displaying video messages
class VideoMessageWidget extends StatelessWidget {
  final MediaInfo mediaInfo;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;

  const VideoMessageWidget({
    super.key,
    required this.mediaInfo,
    this.onTap,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.65,
            maxHeight: 300,
          ),
          child: Stack(
            children: [
              _buildThumbnail(),
              _buildPlayOverlay(),
              if (mediaInfo.duration != null)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      mediaInfo.durationText,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              if (mediaInfo.isDownloading) _buildDownloadProgress(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (mediaInfo.thumbnailPath != null) {
      return Image.file(
        File(mediaInfo.thumbnailPath!),
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: mediaInfo.width?.toDouble() ?? 200,
      height: mediaInfo.height?.toDouble() ?? 150,
      color: greyColor,
      child: const Icon(Icons.videocam, color: Colors.white54, size: 48),
    );
  }

  Widget _buildPlayOverlay() {
    return Positioned.fill(
      child: Center(
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: Icon(
            mediaInfo.isDownloaded ? Icons.play_arrow : Icons.download,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadProgress() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: mediaInfo.downloadProgress,
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                Text(
                  '${(mediaInfo.downloadProgress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget for displaying voice notes
class VoiceNoteWidget extends StatelessWidget {
  final MediaInfo mediaInfo;
  final bool isPlaying;
  final double playbackProgress;
  final VoidCallback? onPlayPause;
  final VoidCallback? onDownload;

  const VoiceNoteWidget({
    super.key,
    required this.mediaInfo,
    this.isPlaying = false,
    this.playbackProgress = 0.0,
    this.onPlayPause,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: greyColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: mediaInfo.isDownloaded ? onPlayPause : onDownload,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF2B5278),
                shape: BoxShape.circle,
              ),
              child: Icon(
                mediaInfo.isDownloading
                    ? Icons.hourglass_empty
                    : mediaInfo.isDownloaded
                    ? (isPlaying ? Icons.pause : Icons.play_arrow)
                    : Icons.download,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform placeholder
                Container(
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        // Background bars
                        Row(
                          children: List.generate(
                            20,
                            (index) => Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                height: 8 + (index % 3) * 6.0,
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Progress overlay
                        FractionallySizedBox(
                          widthFactor: playbackProgress,
                          child: Row(
                            children: List.generate(
                              20,
                              (index) => Expanded(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  height: 8 + (index % 3) * 6.0,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2B5278),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mediaInfo.durationText,
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
    );
  }
}

/// Widget for displaying documents
class DocumentWidget extends StatelessWidget {
  final MediaInfo mediaInfo;
  final String fileName;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;

  const DocumentWidget({
    super.key,
    required this.mediaInfo,
    required this.fileName,
    this.onTap,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: mediaInfo.isDownloaded ? onTap : onDownload,
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getFileColor(),
                borderRadius: BorderRadius.circular(8),
              ),
              child: mediaInfo.isDownloading
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: CircularProgressIndicator(
                        value: mediaInfo.downloadProgress,
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                  : Icon(
                      mediaInfo.isDownloaded ? _getFileIcon() : Icons.download,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
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
                    mediaInfo.fileSizeText,
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

  IconData _getFileIcon() {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file;
      case 'apk':
        return Icons.android;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor() {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Colors.red.shade700;
      case 'doc':
      case 'docx':
        return Colors.blue.shade700;
      case 'xls':
      case 'xlsx':
        return Colors.green.shade700;
      case 'ppt':
      case 'pptx':
        return Colors.orange.shade700;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.amber.shade700;
      case 'apk':
        return Colors.teal.shade700;
      default:
        return Colors.blueGrey.shade600;
    }
  }
}

/// Widget for displaying stickers
class StickerWidget extends StatelessWidget {
  final MediaInfo mediaInfo;
  final VoidCallback? onTap;

  const StickerWidget({super.key, required this.mediaInfo, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 150,
        height: 150,
        child: mediaInfo.hasLocalFile
            ? Image.file(
                File(mediaInfo.localPath!),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.transparent,
      child: const Icon(Icons.emoji_emotions, color: Colors.white54, size: 48),
    );
  }
}

/// Avatar widget with online status indicator
class UserAvatar extends StatelessWidget {
  final String? photoPath;
  final String name;
  final double size;
  final bool isOnline;
  final bool showOnlineIndicator;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.photoPath,
    required this.name,
    this.size = 48,
    this.isOnline = false,
    this.showOnlineIndicator = false,
    this.onTap,
  });

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color get _backgroundColor {
    final colors = [
      Colors.red.shade400,
      Colors.pink.shade400,
      Colors.purple.shade400,
      Colors.deepPurple.shade400,
      Colors.indigo.shade400,
      Colors.blue.shade400,
      Colors.cyan.shade400,
      Colors.teal.shade400,
      Colors.green.shade400,
      Colors.amber.shade600,
      Colors.orange.shade400,
      Colors.deepOrange.shade400,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _backgroundColor,
            ),
            child: ClipOval(
              child: photoPath != null && photoPath!.isNotEmpty
                  ? (photoPath!.startsWith('http')
                        ? Image.network(
                            photoPath!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildInitials(),
                          )
                        : Image.file(
                            File(photoPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildInitials(),
                          ))
                  : _buildInitials(),
            ),
          ),
          if (showOnlineIndicator && isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: bgColor, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInitials() {
    return Center(
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}
