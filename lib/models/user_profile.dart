/// User profile information from Telegram
class UserProfile {
  final int id;
  final String firstName;
  final String lastName;
  final String? username;
  final String? phoneNumber;
  final String? bio;
  final String? smallPhotoPath;
  final String? bigPhotoPath;
  final int? smallPhotoId;
  final int? bigPhotoId;
  final UserStatus status;
  final bool isContact;
  final bool isMutualContact;
  final bool isPremium;
  final bool isVerified;

  UserProfile({
    required this.id,
    required this.firstName,
    this.lastName = '',
    this.username,
    this.phoneNumber,
    this.bio,
    this.smallPhotoPath,
    this.bigPhotoPath,
    this.smallPhotoId,
    this.bigPhotoId,
    this.status = UserStatus.unknown,
    this.isContact = false,
    this.isMutualContact = false,
    this.isPremium = false,
    this.isVerified = false,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get displayName => fullName.isNotEmpty ? fullName : username ?? 'User';

  String get initials {
    final first = firstName.isNotEmpty ? firstName[0] : '';
    final last = lastName.isNotEmpty ? lastName[0] : '';
    return '$first$last'.toUpperCase();
  }

  String get statusText {
    switch (status) {
      case UserStatus.online:
        return 'online';
      case UserStatus.recently:
        return 'last seen recently';
      case UserStatus.lastWeek:
        return 'last seen within a week';
      case UserStatus.lastMonth:
        return 'last seen within a month';
      case UserStatus.longTimeAgo:
        return 'last seen a long time ago';
      case UserStatus.offline:
        return 'offline';
      case UserStatus.unknown:
        return '';
    }
  }

  bool get isOnline => status == UserStatus.online;

  UserProfile copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? username,
    String? phoneNumber,
    String? bio,
    String? smallPhotoPath,
    String? bigPhotoPath,
    int? smallPhotoId,
    int? bigPhotoId,
    UserStatus? status,
    bool? isContact,
    bool? isMutualContact,
    bool? isPremium,
    bool? isVerified,
  }) {
    return UserProfile(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      bio: bio ?? this.bio,
      smallPhotoPath: smallPhotoPath ?? this.smallPhotoPath,
      bigPhotoPath: bigPhotoPath ?? this.bigPhotoPath,
      smallPhotoId: smallPhotoId ?? this.smallPhotoId,
      bigPhotoId: bigPhotoId ?? this.bigPhotoId,
      status: status ?? this.status,
      isContact: isContact ?? this.isContact,
      isMutualContact: isMutualContact ?? this.isMutualContact,
      isPremium: isPremium ?? this.isPremium,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}

/// User online status
enum UserStatus {
  online,
  recently,
  lastWeek,
  lastMonth,
  longTimeAgo,
  offline,
  unknown,
}

/// Chat type classification
enum ChatType { private, group, supergroup, channel, secret, unknown }

/// Extended chat info
class ChatInfo {
  final int id;
  final String title;
  final ChatType type;
  final String? description;
  final String? inviteLink;
  final int memberCount;
  final String? smallPhotoPath;
  final String? bigPhotoPath;
  final int? smallPhotoId;
  final int? bigPhotoId;
  final bool canSendMessages;
  final bool isMuted;

  ChatInfo({
    required this.id,
    required this.title,
    required this.type,
    this.description,
    this.inviteLink,
    this.memberCount = 0,
    this.smallPhotoPath,
    this.bigPhotoPath,
    this.smallPhotoId,
    this.bigPhotoId,
    this.canSendMessages = true,
    this.isMuted = false,
  });

  String get typeLabel {
    switch (type) {
      case ChatType.private:
        return 'Private Chat';
      case ChatType.group:
        return 'Group';
      case ChatType.supergroup:
        return 'Supergroup';
      case ChatType.channel:
        return 'Channel';
      case ChatType.secret:
        return 'Secret Chat';
      case ChatType.unknown:
        return 'Chat';
    }
  }

  String get memberCountText {
    if (memberCount == 0) return '';
    if (memberCount == 1) return '1 member';
    return '$memberCount members';
  }
}

/// Media attachment info for messages
class MediaInfo {
  final MediaType type;
  final int? fileId;
  final String? localPath;
  final String? remotePath;
  final int? width;
  final int? height;
  final int? duration; // For video/audio
  final int? fileSize;
  final String? mimeType;
  final String? caption;
  final String? thumbnailPath;
  final int? thumbnailId;
  final bool isDownloading;
  final bool isDownloaded;
  final double downloadProgress;

  MediaInfo({
    required this.type,
    this.fileId,
    this.localPath,
    this.remotePath,
    this.width,
    this.height,
    this.duration,
    this.fileSize,
    this.mimeType,
    this.caption,
    this.thumbnailPath,
    this.thumbnailId,
    this.isDownloading = false,
    this.isDownloaded = false,
    this.downloadProgress = 0.0,
  });

  bool get hasLocalFile => localPath != null && localPath!.isNotEmpty;

  String get durationText {
    if (duration == null) return '';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get fileSizeText {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize! < 1024 * 1024 * 1024) {
      return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize! / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  MediaInfo copyWith({
    MediaType? type,
    int? fileId,
    String? localPath,
    String? remotePath,
    int? width,
    int? height,
    int? duration,
    int? fileSize,
    String? mimeType,
    String? caption,
    String? thumbnailPath,
    int? thumbnailId,
    bool? isDownloading,
    bool? isDownloaded,
    double? downloadProgress,
  }) {
    return MediaInfo(
      type: type ?? this.type,
      fileId: fileId ?? this.fileId,
      localPath: localPath ?? this.localPath,
      remotePath: remotePath ?? this.remotePath,
      width: width ?? this.width,
      height: height ?? this.height,
      duration: duration ?? this.duration,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      caption: caption ?? this.caption,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      thumbnailId: thumbnailId ?? this.thumbnailId,
      isDownloading: isDownloading ?? this.isDownloading,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }
}

/// Media types
enum MediaType {
  photo,
  video,
  audio,
  voiceNote,
  videoNote,
  document,
  sticker,
  animation,
  location,
  contact,
  poll,
  unknown,
}
