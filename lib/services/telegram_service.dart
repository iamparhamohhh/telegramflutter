import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:tdlib/td_api.dart';
import 'package:tdlib/tdlib.dart';
import 'package:tdlib/src/tdclient/platform_interfaces/td_plugin.dart';

/// Represents a chat item from Telegram
class TelegramChat {
  final int id;
  final String title;
  final String? photoUrl;
  final String lastMessage;
  final String lastMessageTime;
  final int unreadCount;
  final bool isRead;
  final bool isSentByMe;
  final int lastMessageDate;
  final int order;

  TelegramChat({
    required this.id,
    required this.title,
    this.photoUrl,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.isRead,
    required this.isSentByMe,
    this.lastMessageDate = 0,
    this.order = 0,
  });
}

/// Message status enumeration
enum MessageStatus {
  sending, // Message is being sent
  sent, // Message sent to server
  delivered, // Message delivered to recipient
  read, // Message read by recipient
  failed, // Message failed to send
}

/// Represents a message in a chat
class TelegramMessage {
  final int id;
  final int chatId;
  final String text;
  final String time;
  final bool isOutgoing;
  final int senderId;
  final String? senderName;
  final MessageStatus status;
  final String contentType; // text, photo, video, etc.
  final Map<String, dynamic>? mediaInfo;
  final int date; // Unix timestamp

  TelegramMessage({
    required this.id,
    required this.chatId,
    required this.text,
    required this.time,
    required this.isOutgoing,
    required this.senderId,
    this.senderName,
    required this.status,
    this.contentType = 'text',
    this.mediaInfo,
    required this.date,
  });
}

class TelegramService {
  static final TelegramService _instance = TelegramService._internal();
  factory TelegramService() => _instance;
  TelegramService._internal();

  int _clientId = 0;
  final _authStateController = StreamController<String>.broadcast();
  Stream<String> get authStateStream => _authStateController.stream;

  // Stream for chats updates
  final _chatsController = StreamController<List<TelegramChat>>.broadcast();
  Stream<List<TelegramChat>> get chatsStream => _chatsController.stream;

  // Debounce timer for emitting chats
  Timer? _emitChatsDebounceTimer;
  static const _emitChatsDebounceMs = 100; // Debounce by 100ms

  // Typing indicators - chatId -> {userId -> action description}
  final Map<int, Map<int, String>> _typingUsers = {};
  final _typingController =
      StreamController<Map<int, Map<int, String>>>.broadcast();
  Stream<Map<int, Map<int, String>>> get typingStream =>
      _typingController.stream;
  final Map<int, Timer> _typingTimers = {};

  /// Get typing text for a chat (e.g. "John is typing...")
  String? getTypingText(int chatId) {
    final users = _typingUsers[chatId];
    if (users == null || users.isEmpty) return null;

    final names = <String>[];
    for (final userId in users.keys) {
      final user = _usersCache[userId];
      if (user != null) {
        names.add(user.firstName);
      }
    }
    if (names.isEmpty) return null;
    if (names.length == 1) return '${names[0]} is typing...';
    if (names.length == 2) return '${names[0]} and ${names[1]} are typing...';
    return '${names[0]} and ${names.length - 1} others are typing...';
  }

  /// Send typing action to indicate the current user is typing
  Future<void> sendTypingAction(int chatId) async {
    if (_clientId == 0) return;
    tdSend(
      _clientId,
      SendChatAction(
        chatId: chatId,
        messageThreadId: 0,
        action: const ChatActionTyping(),
      ),
    );
  }

  /// Cancel typing action
  Future<void> cancelTypingAction(int chatId) async {
    if (_clientId == 0) return;
    tdSend(
      _clientId,
      SendChatAction(
        chatId: chatId,
        messageThreadId: 0,
        action: const ChatActionCancel(),
      ),
    );
  }

  // Debug mode - set to false for production
  static const bool _debugMode = false;

  void _debugPrint(String message) {
    if (_debugMode) print(message);
  }

  // Stream for messages updates (per chat)
  final Map<int, StreamController<List<TelegramMessage>>> _messageControllers =
      {};

  // Get message stream for a specific chat
  Stream<List<TelegramMessage>> getMessagesStream(int chatId) {
    if (!_messageControllers.containsKey(chatId)) {
      _messageControllers[chatId] =
          StreamController<List<TelegramMessage>>.broadcast();
    }
    return _messageControllers[chatId]!.stream;
  }

  // Cache for chats and chat details
  final Map<int, Chat> _chatsCache = {};
  final Map<int, User> _usersCache = {};
  final Map<int, BasicGroup> _basicGroupsCache = {};
  final Map<int, Supergroup> _supergroupsCache = {};
  final Map<int, File> _filesCache = {};
  List<int> _chatIds = [];

  // Message cache per chat
  final Map<int, List<TelegramMessage>> _messagesCache = {};
  //final Map<int, Map<String, dynamic>> _rawMessagesCache =
  //    {}; // messageId -> raw JSON

  // Track current user ID
  int? _currentUserId;

  bool _isRunning = false;
  static bool _libraryInitialized = false;
  String? _databasePath;
  bool _parametersSet = false;

  // Debug counters
  int _updateCount = 0;
  int _nullCount = 0;

  // Get your own API credentials from https://my.telegram.org
  static const int apiId = 17349;
  static const String apiHash = '344583e45741c457fe1862106095a5eb';

  /// Clears the TDLib database to start fresh. Call this if TDLib is stuck.
  Future<void> clearDatabase() async {
    _debugPrint('Clearing TDLib database...');

    // Stop the current client if running
    _isRunning = false;
    _receiveTimer?.cancel();
    _receiveTimer = null;

    if (_clientId != 0) {
      try {
        tdSend(_clientId, const Close());
        // Wait for close to complete
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        _debugPrint('Error closing client: $e');
      }
      _clientId = 0;
    }
    _parametersSet = false;

    // Delete the database directory
    if (_databasePath != null) {
      final dbDir = Directory(_databasePath!);
      if (await dbDir.exists()) {
        await dbDir.delete(recursive: true);
      }
    } else {
      final appDocDir = await getApplicationDocumentsDirectory();
      final dbPath = '${appDocDir.path}/tdlib';
      final dbDir = Directory(dbPath);
      if (await dbDir.exists()) {
        await dbDir.delete(recursive: true);
      }
    }
    _databasePath = null;
  }

  Future<void> initialize() async {
    if (_clientId != 0) {
      _debugPrint('TelegramService already initialized');
      return;
    }

    try {
      // Pre-compute database path BEFORE initializing TDLib
      if (_databasePath == null) {
        final appDocDir = await getApplicationDocumentsDirectory();
        _databasePath = '${appDocDir.path}/tdlib';

        final databaseDir = Directory(_databasePath!);
        if (!await databaseDir.exists()) {
          await databaseDir.create(recursive: true);
        }
      }

      // Initialize the TDLib native library first (required for FFI)
      if (!_libraryInitialized) {
        // On Android, we need to load the library by name (it will be found in the native lib path)
        // The library is named "libtdjson.so" but we load it as "tdjson"
        if (Platform.isAndroid) {
          await TdPlugin.initialize('libtdjson.so');
        } else if (Platform.isIOS || Platform.isMacOS) {
          await TdPlugin.initialize(); // Uses DynamicLibrary.process()
        } else if (Platform.isWindows) {
          await TdPlugin.initialize('tdjson.dll');
        } else if (Platform.isLinux) {
          await TdPlugin.initialize('libtdjson.so');
        } else {
          await TdPlugin.initialize();
        }

        _libraryInitialized = true;
      }

      // Create TDLib client
      _clientId = tdCreate();
      _debugPrint('TDLib client created: $_clientId');

      if (_clientId == 0) {
        throw Exception('Failed to create TDLib client');
      }

      // Start receiving updates BEFORE sending any requests
      _isRunning = true;

      // Use Timer-based polling instead of Future.doWhile
      _startReceivingUpdates();

      // Give the receive loop time to start
      await Future.delayed(const Duration(milliseconds: 100));

      // Send GetAuthorizationState to "wake up" the TDLib client
      // This triggers TDLib to initialize and start sending updates
      tdSend(_clientId, const GetAuthorizationState());
    } catch (e, stack) {
      _debugPrint('TDLib initialization error: $e');
      _authStateController.addError(e);
      rethrow;
    }
  }

  Timer? _receiveTimer;

  void _startReceivingUpdates() {
    _updateCount = 0;
    _nullCount = 0;

    // Cancel existing timer if any
    _receiveTimer?.cancel();

    // Use a periodic timer to poll for updates
    // Poll every 500ms to reduce UI lag (was 100ms)
    _receiveTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isRunning) {
        timer.cancel();
        return;
      }

      _pollUpdates();
    });

    // Also do an immediate poll
    _pollUpdates();
  }

  void _pollUpdates() {
    try {
      // Get raw JSON string from TDLib instead of using tdReceive() which parses it
      final jsonString = TdPlugin.instance.tdReceive(0.01);

      if (jsonString == null || jsonString.isEmpty) {
        _nullCount++;
        // Only log occasionally in debug mode
        if (_debugMode && (_nullCount <= 3 || _nullCount % 500 == 0)) {
          _debugPrint(
            'Waiting... ($_nullCount polls, ${_chatsCache.length} chats)',
          );
        }
        return;
      }

      _updateCount++;

      // Parse JSON manually with error handling
      TdObject? update;
      try {
        update = convertToObject(jsonString);
      } catch (parseError, parseStack) {
        // Try to extract useful info from raw JSON even if full parsing fails
        _handleRawJson(jsonString);

        // Continue polling
        Future.microtask(() {
          if (_isRunning) _pollUpdates();
        });
        return;
      }

      if (update != null) {
        // Handle the update
        _handleUpdate(update);
      }

      // If we got data, immediately check for more (burst mode)
      Future.microtask(() {
        if (_isRunning) _pollUpdates();
      });
    } catch (e, stack) {
      // TDLib JSON parsing errors can happen due to API version mismatches
      // Log the error but continue receiving updates
      _debugPrint('TDLib receive error: $e');
      // Continue polling for the next update
      Future.microtask(() {
        if (_isRunning) _pollUpdates();
      });
    }
  }

  /// Handle raw JSON when standard parsing fails
  void _handleRawJson(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final type = json['@type'] as String?;

      // Handle updateNewChat manually if parsing failed
      if (type == 'updateNewChat') {
        final chatJson = json['chat'] as Map<String, dynamic>?;
        if (chatJson != null) {
          final chatId = chatJson['id'] as int?;
          final title = chatJson['title'] as String? ?? 'Unknown';
          _debugPrint('RAW: New chat: $title (ID: $chatId)');

          if (chatId != null) {
            // Create a minimal Chat object manually without using fromJson
            _cacheRawChat(chatId, chatJson);
            _emitChats();
          }
        }
      } else if (type == 'chats') {
        final chatIds = (json['chat_ids'] as List?)?.cast<int>() ?? [];
        _debugPrint('RAW: ${chatIds.length} chat IDs received');
        _chatIds = chatIds;
        _emitChats();
      } else if (type == 'updateChatLastMessage') {
        final chatId = json['chat_id'] as int?;
        final lastMessageJson = json['last_message'] as Map<String, dynamic>?;
        if (chatId != null &&
            (_chatsCache.containsKey(chatId) ||
                _rawChatData.containsKey(chatId))) {
          _updateChatLastMessageFromRaw(chatId, lastMessageJson);
          _emitChats();
        }
      } else if (type == 'updateNewMessage') {
        // Handle new incoming/outgoing message
        final msgJson = json['message'] as Map<String, dynamic>?;
        if (msgJson != null) {
          final chatId = msgJson['chat_id'] as int?;
          if (chatId != null) {
            _handleRawNewMessage(chatId, msgJson);
          }
        }
      } else if (type == 'messages') {
        // Response to getChatHistory
        final messagesJson = json['messages'] as List?;
        if (messagesJson != null && messagesJson.isNotEmpty) {
          final firstMsg = messagesJson.first as Map<String, dynamic>;
          final chatId = firstMsg['chat_id'] as int?;
          if (chatId != null) {
            _handleRawMessages(
              chatId,
              messagesJson.cast<Map<String, dynamic>>(),
            );
          }
        }
      } else if (type == 'message') {
        // Single message response (e.g., after sending)
        final chatId = json['chat_id'] as int?;
        if (chatId != null) {
          _handleRawNewMessage(chatId, json);
        }
      } else if (type == 'updateMessageSendSucceeded') {
        // Message was successfully sent
        final msgJson = json['message'] as Map<String, dynamic>?;
        final oldMsgId = json['old_message_id'] as int?;
        if (msgJson != null) {
          final chatId = msgJson['chat_id'] as int?;
          if (chatId != null) {
            _handleMessageSendSucceeded(chatId, msgJson, oldMsgId);
          }
        }
      } else if (type == 'updateMessageSendFailed') {
        // Message failed to send
        final msgJson = json['message'] as Map<String, dynamic>?;
        final oldMsgId = json['old_message_id'] as int?;
        if (msgJson != null) {
          final chatId = msgJson['chat_id'] as int?;
          if (chatId != null) {
            _handleMessageSendFailed(chatId, oldMsgId);
          }
        }
      } else if (type == 'user') {
        // User info response - might be current user
        final userId = json['id'] as int?;
        final isMe = json['is_me'] as bool? ?? false;
        if (isMe && userId != null) {
          _currentUserId = userId;
        }
      } else if (type == 'updateFile') {
        // File download progress from raw JSON
        final fileJson = json['file'] as Map<String, dynamic>?;
        if (fileJson != null) {
          final fileId = fileJson['id'] as int?;
          if (fileId != null) {
            _handleRawFileUpdate(fileJson);
          }
        }
      } else if (type == 'userFullInfo') {
        // User full info response
        final userId = json['user_id'] as int?;
        if (userId != null) {
          _userFullInfoCache[userId] = json;
        }
      } else if (type == 'updateUserStatus') {
        // User status changed - don't emit chats for every status update
        // The status will be shown when user opens the chat
      } else if (type == 'chats' && json['chat_ids'] != null) {
        // Search results
        final chatIds = (json['chat_ids'] as List?)?.cast<int>() ?? [];
        final results = <TelegramChat>[];
        for (final id in chatIds) {
          if (_chatsCache.containsKey(id)) {
            results.add(_convertToTelegramChat(_chatsCache[id]!));
          } else if (_rawChatData.containsKey(id)) {
            results.add(_convertRawToTelegramChat(id, _rawChatData[id]!, null));
          }
        }
        _chatSearchResultsController.add(results);
      } else if (type == 'foundMessages') {
        // Global search messages results
        final messagesJson = json['messages'] as List?;
        final totalCount = json['total_count'] as int? ?? 0;
        final nextOffset = json['next_offset'] as String?;
        if (messagesJson != null) {
          _handleRawFoundMessages(
            messagesJson.cast<Map<String, dynamic>>(),
            totalCount,
            nextOffset,
          );
        }
      } else if (type == 'foundChatMessages') {
        // Chat-specific search results
        final messagesJson = json['messages'] as List?;
        final totalCount = json['total_count'] as int? ?? 0;
        final nextFromMessageId = json['next_from_message_id'] as int? ?? 0;
        final chatId = messagesJson?.isNotEmpty == true
            ? (messagesJson!.first as Map<String, dynamic>)['chat_id'] as int?
            : null;
        if (messagesJson != null && chatId != null) {
          _handleRawFoundChatMessages(
            chatId,
            messagesJson.cast<Map<String, dynamic>>(),
            totalCount,
            nextFromMessageId,
          );
        }
      } else if (type == 'passwordState') {
        // 2FA password state response
        _passwordState = json;
        _passwordStateController.add(json);
      } else if (type == 'messageSenders') {
        // Blocked users list response
        final senders = json['senders'] as List?;
        _blockedUsers.clear();
        if (senders != null) {
          for (final sender in senders) {
            final senderMap = sender as Map<String, dynamic>?;
            final msgSender = senderMap?['sender'] as Map<String, dynamic>?;
            if (msgSender != null &&
                msgSender['@type'] == 'messageSenderUser') {
              final userId = msgSender['user_id'] as int?;
              if (userId != null) {
                final user = _usersCache[userId];
                _blockedUsers.add({
                  'user_id': userId,
                  'first_name': user?.firstName ?? '',
                  'last_name': user?.lastName ?? '',
                  'phone': user?.phoneNumber ?? '',
                });
              }
            }
          }
        }
      } else if (type == 'storageStatistics') {
        // Storage statistics response
        _storageStatistics = json;
      } else if (type == 'sessions') {
        // Active sessions response
        final sessionsList = json['sessions'] as List<dynamic>? ?? [];
        _activeSessions = sessionsList
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();
        _sessionsController.add(_activeSessions);
      } else if (type == 'accountTtl') {
        // Account TTL response
        _accountTtlDays = json['days'] as int? ?? 365;
        _accountTtlController.add(_accountTtlDays);
      } else if (type == 'userPrivacySettingRules') {
        // Privacy setting rules response
        final rules = json['rules'] as List<dynamic>? ?? [];
        if (_pendingPrivacySetting != null && rules.isNotEmpty) {
          final firstRule = rules.first as Map<String, dynamic>;
          final ruleType = firstRule['@type'] as String? ?? '';
          String value;
          if (ruleType.contains('AllowAll')) {
            value = 'everybody';
          } else if (ruleType.contains('AllowContacts')) {
            value = 'contacts';
          } else if (ruleType.contains('RestrictAll')) {
            value = 'nobody';
          } else {
            value = 'contacts';
          }
          _privacySettings[_pendingPrivacySetting!] = value;
          _privacySettingsController.add(_privacySettings);
          _pendingPrivacySetting = null;
        }
      } else if (type == 'scopeNotificationSettings') {
        // Response to GetScopeNotificationSettings
        // We need to figure out which scope this was for from the context
        final muteFor = json['mute_for'] as int? ?? 0;
        final soundId = json['sound_id'] as int? ?? 0;
        final showPreview = json['show_preview'] as bool? ?? true;
        final disablePinned =
            json['disable_pinned_message_notifications'] as bool? ?? false;
        final disableMention =
            json['disable_mention_notifications'] as bool? ?? false;
        final muteStories = json['mute_stories'] as bool? ?? false;
        final storySoundId = json['story_sound_id'] as int? ?? 0;
        // Store as the last requested scope
        if (_pendingNotifScope != null) {
          _notificationSettings[_pendingNotifScope!] =
              NotificationScopeSettings(
                scope: _pendingNotifScope!,
                isMuted: muteFor > 0,
                showPreview: showPreview,
                soundId: soundId,
                disablePinnedMessageNotifications: disablePinned,
                disableMentionNotifications: disableMention,
                muteStories: muteStories,
                storySoundId: storySoundId,
              );
          _notificationSettingsController.add(_notificationSettings);
          _pendingNotifScope = null;
        }
      } else if (type == 'updateScopeNotificationSettings') {
        // Scope notification settings changed
        final scopeJson = json['scope'] as Map<String, dynamic>?;
        final settingsJson =
            json['notification_settings'] as Map<String, dynamic>?;
        if (scopeJson != null && settingsJson != null) {
          String scope;
          switch (scopeJson['@type']) {
            case 'notificationSettingsScopePrivateChats':
              scope = 'private';
              break;
            case 'notificationSettingsScopeGroupChats':
              scope = 'group';
              break;
            case 'notificationSettingsScopeChannelChats':
              scope = 'channel';
              break;
            default:
              scope = 'unknown';
          }
          _notificationSettings[scope] = NotificationScopeSettings(
            scope: scope,
            isMuted: (settingsJson['mute_for'] as int? ?? 0) > 0,
            showPreview: settingsJson['show_preview'] as bool? ?? true,
            soundId: settingsJson['sound_id'] as int? ?? 0,
            disablePinnedMessageNotifications:
                settingsJson['disable_pinned_message_notifications'] as bool? ??
                false,
            disableMentionNotifications:
                settingsJson['disable_mention_notifications'] as bool? ?? false,
            muteStories: settingsJson['mute_stories'] as bool? ?? false,
            storySoundId: settingsJson['story_sound_id'] as int? ?? 0,
          );
          _notificationSettingsController.add(_notificationSettings);
        }
      } else if (type == 'notificationSounds') {
        // Response to GetSavedNotificationSounds
        final sounds = json['notification_sounds'] as List? ?? [];
        _savedNotificationSounds = sounds
            .map(
              (s) => NotificationSoundInfo(
                id: s['id'] as int? ?? 0,
                title: s['title'] as String? ?? 'Unknown',
                duration: s['duration'] as int? ?? 0,
                data: s['data'] as String? ?? '',
              ),
            )
            .toList();
        _notificationSoundsController.add(_savedNotificationSounds);
      } else if (type == 'user' && json['is_me'] == true) {
        // Current user info
        _currentUserInfo = json;
        _currentUserId = json['id'] as int?;
      } else if (type == 'updateMessageContent') {
        // Message was edited
        final chatId = json['chat_id'] as int?;
        final messageId = json['message_id'] as int?;
        final newContent = json['new_content'] as Map<String, dynamic>?;
        if (chatId != null && messageId != null && newContent != null) {
          _handleMessageContentUpdate(chatId, messageId, newContent);
        }
      } else if (type == 'updateChatReadOutbox') {
        // Message was read by recipient
        final chatId = json['chat_id'] as int?;
        final lastReadOutboxMessageId =
            json['last_read_outbox_message_id'] as int?;
        if (chatId != null && lastReadOutboxMessageId != null) {
          _handleReadOutbox(chatId, lastReadOutboxMessageId);
        }
      } else if (type == 'ok') {
        // Success - no need to log
      } else if (type == 'updateChatAction') {
        final chatId = json['chat_id'] as int?;
        final senderJson = json['sender_id'] as Map<String, dynamic>?;
        final actionJson = json['action'] as Map<String, dynamic>?;
        if (chatId != null && senderJson != null && actionJson != null) {
          int userId = 0;
          if (senderJson['@type'] == 'messageSenderUser') {
            userId = senderJson['user_id'] as int? ?? 0;
          }
          if (userId != _currentUserId && userId != 0) {
            final actionType = actionJson['@type'] as String? ?? '';
            if (actionType == 'chatActionCancel') {
              _typingUsers[chatId]?.remove(userId);
              if (_typingUsers[chatId]?.isEmpty == true) {
                _typingUsers.remove(chatId);
              }
            } else {
              _typingUsers.putIfAbsent(chatId, () => {});
              _typingUsers[chatId]![userId] = 'typing';
              final timerKey = chatId * 1000000 + userId;
              _typingTimers[timerKey]?.cancel();
              _typingTimers[timerKey] = Timer(const Duration(seconds: 6), () {
                _typingUsers[chatId]?.remove(userId);
                if (_typingUsers[chatId]?.isEmpty == true) {
                  _typingUsers.remove(chatId);
                }
                _typingController.add(Map.from(_typingUsers));
              });
            }
            _typingController.add(Map.from(_typingUsers));
          }
        }
      } else if (type == 'error') {
        final code = json['code'] as int?;
        final message = json['message'] as String?;
        _debugPrint('TDLib error $code: $message');
      }
    } catch (e, stack) {
      _debugPrint('Raw JSON error: $e');
    }
  }

  /// Cache a chat from raw JSON data without using TDLib's broken fromJson
  void _cacheRawChat(int chatId, Map<String, dynamic> chatJson) {
    // Check if we already have this chat cached (either in proper cache or raw cache)
    if (_chatsCache.containsKey(chatId) || _rawChatData.containsKey(chatId)) {
      return;
    }

    // We can't create a Chat object directly without TDLib's broken parsing,
    // so we'll store the raw data and create TelegramChat objects directly
    _rawChatData[chatId] = chatJson;
    _debugPrint(
      'Cached raw chat data for $chatId (raw cache size: ${_rawChatData.length})',
    );
  }

  /// Update last message info from raw JSON
  void _updateChatLastMessageFromRaw(
    int chatId,
    Map<String, dynamic>? msgJson,
  ) {
    if (msgJson == null) return;
    _rawLastMessageData[chatId] = msgJson;
  }

  // Store raw chat data when TDLib parsing fails
  final Map<int, Map<String, dynamic>> _rawChatData = {};
  final Map<int, Map<String, dynamic>> _rawLastMessageData = {};

  void _handleUpdate(TdObject update) {
    // Only log important updates in debug mode
    if (_debugMode &&
        (update is UpdateNewChat ||
            update is UpdateAuthorizationState ||
            update is Chats ||
            update is Chat ||
            update is TdError)) {
      _debugPrint('TDLib update: ${update.runtimeType}');
    }

    if (update is UpdateAuthorizationState) {
      _handleAuthorizationState(update.authorizationState);
    } else if (update is AuthorizationState) {
      // Direct auth state from getAuthorizationState response
      _handleAuthorizationState(update);
    } else if (update is UpdateNewChat) {
      // A new chat was received
      _chatsCache[update.chat.id] = update.chat;
      _debugPrint(
        'New chat: ${update.chat.title} (${_chatsCache.length} total)',
      );
      _emitChats();
    } else if (update is UpdateChatLastMessage) {
      // Chat's last message was updated
      if (update.lastMessage != null) {
        final chat = _chatsCache[update.chatId];
        if (chat != null) {
          // Update positions if provided
          for (final pos in update.positions) {
            // TDLib handles position updates internally
          }
        }
      }
      _emitChats();
    } else if (update is UpdateChatPosition) {
      // Chat position in the list was updated - handled by TDLib cache
      _emitChats();
    } else if (update is UpdateChatReadInbox) {
      // Chat unread count was updated
      _emitChats();
    } else if (update is UpdateUser) {
      // User info was updated - don't emit chats for every user update
      _usersCache[update.user.id] = update.user;
      // Only emit if this affects visible chats (debounced anyway)
    } else if (update is UpdateBasicGroup) {
      _basicGroupsCache[update.basicGroup.id] = update.basicGroup;
    } else if (update is UpdateSupergroup) {
      _supergroupsCache[update.supergroup.id] = update.supergroup;
    } else if (update is UpdateChatAction) {
      // Typing indicator
      final chatId = update.chatId;
      final senderId = update.senderId;
      int userId = 0;
      if (senderId is MessageSenderUser) {
        userId = senderId.userId;
      }
      if (userId == _currentUserId) return; // Ignore own typing
      final action = update.action;
      if (action is ChatActionCancel) {
        _typingUsers[chatId]?.remove(userId);
        if (_typingUsers[chatId]?.isEmpty == true) {
          _typingUsers.remove(chatId);
        }
      } else {
        String desc = 'typing';
        if (action is ChatActionRecordingVideo) desc = 'recording video';
        if (action is ChatActionUploadingVideo) desc = 'sending video';
        if (action is ChatActionRecordingVoiceNote) desc = 'recording voice';
        if (action is ChatActionUploadingVoiceNote) desc = 'sending voice';
        if (action is ChatActionUploadingPhoto) desc = 'sending photo';
        if (action is ChatActionUploadingDocument) desc = 'sending file';
        if (action is ChatActionChoosingSticker) desc = 'choosing sticker';
        if (action is ChatActionChoosingLocation) desc = 'choosing location';
        if (action is ChatActionChoosingContact) desc = 'choosing contact';
        _typingUsers.putIfAbsent(chatId, () => {});
        _typingUsers[chatId]![userId] = desc;
        // Auto-clear after 6 seconds (TDLib standard)
        final timerKey = chatId * 1000000 + userId;
        _typingTimers[timerKey]?.cancel();
        _typingTimers[timerKey] = Timer(const Duration(seconds: 6), () {
          _typingUsers[chatId]?.remove(userId);
          if (_typingUsers[chatId]?.isEmpty == true) {
            _typingUsers.remove(chatId);
          }
          _typingController.add(Map.from(_typingUsers));
        });
      }
      _typingController.add(Map.from(_typingUsers));
    } else if (update is UpdateChatFolders) {
      // Chat folders updated
      _debugPrint('Chat folders updated: ${update.chatFolders.length} folders');
      _chatFolders.clear();
      for (final folderInfo in update.chatFolders) {
        _chatFolders.add(TelegramChatFolder.fromInfo(folderInfo));
      }
      _chatFoldersController.add(_chatFolders);
    } else if (update is ChatFolder) {
      // Response to GetChatFolder - detailed folder info
      _debugPrint('Received chat folder details: ${update.title}');
    } else if (update is Users) {
      // Response to GetContacts
      _debugPrint('Received ${update.userIds.length} contacts');
      _contacts.clear();
      for (final userId in update.userIds) {
        final user = _usersCache[userId];
        if (user != null) {
          _contacts.add(
            TelegramContact(
              id: user.id,
              firstName: user.firstName,
              lastName: user.lastName,
              phone: user.phoneNumber,
              username: user.usernames?.activeUsernames.firstOrNull,
              photoUrl: null,
            ),
          );
        }
      }
      _contactsController.add(_contacts);
    } else if (update is UpdateFile) {
      // File download progress
      _filesCache[update.file.id] = update.file;
      _handleFileUpdate(update.file);
      if (update.file.local.isDownloadingCompleted) {
        _emitChats();
      }
    } else if (update is Chats) {
      // Response to GetChats - contains list of chat IDs
      _chatIds = update.chatIds;
      _debugPrint('Received ${_chatIds.length} chat IDs');

      // Request details for each chat that we don't have yet
      for (final chatId in _chatIds) {
        if (!_chatsCache.containsKey(chatId)) {
          tdSend(_clientId, GetChat(chatId: chatId));
        }
      }
      _emitChats();
    } else if (update is Chat) {
      // Response to GetChat - full chat details
      _chatsCache[update.id] = update;
      _emitChats();
    } else if (update is TdError) {
      _debugPrint('TDLib Error: ${update.code} - ${update.message}');
      final msg = update.message;
      if (update.code == 400 && msg.contains('Can\'t lock file')) {
        _authStateController.addError(Exception(msg));
        return;
      }
      _authStateController.addError(Exception(msg));
    } else if (update is Ok) {
      // Ok response means the last command was successful
    } else {
      // Silently ignore other updates in production
    }
  }

  Future<void> _handleAuthorizationState(AuthorizationState state) async {
    _debugPrint('Auth state: ${state.runtimeType}');

    if (state is AuthorizationStateWaitTdlibParameters) {
      if (_parametersSet) {
        return;
      }

      if (_databasePath == null) {
        _authStateController.addError(
          Exception('Database path not initialized'),
        );
        return;
      }

      try {
        _debugPrint('Sending TdlibParameters');
        _parametersSet = true;

        tdSend(
          _clientId,
          SetTdlibParameters(
            useTestDc: false,
            databaseDirectory: _databasePath!,
            filesDirectory: '$_databasePath/files',
            databaseEncryptionKey: '',
            useFileDatabase: true,
            useChatInfoDatabase: true,
            useMessageDatabase: true,
            useSecretChats: true,
            apiId: apiId,
            apiHash: apiHash,
            systemLanguageCode: 'en',
            deviceModel: Platform.isAndroid
                ? 'Android'
                : Platform.operatingSystem,
            systemVersion: Platform.operatingSystemVersion,
            applicationVersion: '1.0.0',
            enableStorageOptimizer: true,
            ignoreFileNames: false,
          ),
        );
        _debugPrint('✓ TdlibParameters sent successfully!');
      } catch (e, stackTrace) {
        _debugPrint('Error setting TDLib parameters: $e');
        _debugPrint('Stack trace: $stackTrace');
        _authStateController.addError(e);
      }
    } else if (state is AuthorizationStateWaitPhoneNumber) {
      _debugPrint('✓ Ready for phone number input');
      _authStateController.add('WaitingForPhone');
    } else if (state is AuthorizationStateWaitCode) {
      _debugPrint('✓ Code verification required');
      _authStateController.add('WaitingForCode');
    } else if (state is AuthorizationStateWaitPassword) {
      _debugPrint('✓ Password required');
      _authStateController.add('WaitingForPassword');
    } else if (state is AuthorizationStateReady) {
      _debugPrint('✓ Authorization complete!');
      _authStateController.add('Authorized');
    } else if (state is AuthorizationStateClosed) {
      _debugPrint('⚠ TDLib closed');
      // Clean up internal state when TDLib reports closed
      _isRunning = false;
      _receiveTimer?.cancel();
      _receiveTimer = null;
      _parametersSet = false;
      if (_clientId != 0) {
        try {
          tdSend(_clientId, const Close());
        } catch (e) {
          // ignore send errors when already closed
        }
      }
      _clientId = 0;
      _authStateController.add('Closed');
    } else {
      _debugPrint('⚠ Unknown authorization state: ${state.runtimeType}');
    }
  }

  Future<void> sendPhoneNumber(String phone) async {
    if (_clientId == 0) {
      throw Exception('TelegramService not initialized');
    }

    tdSend(
      _clientId,
      SetAuthenticationPhoneNumber(
        phoneNumber: phone,
        settings: const PhoneNumberAuthenticationSettings(
          allowFlashCall: false,
          allowMissedCall: false,
          isCurrentPhoneNumber: false,
          allowSmsRetrieverApi: false,
          authenticationTokens: [],
        ),
      ),
    );
  }

  Future<void> checkAuthenticationCode(String code) async {
    if (_clientId == 0) {
      throw Exception('TelegramService not initialized');
    }

    tdSend(_clientId, CheckAuthenticationCode(code: code));
  }

  Future<void> checkPassword(String password) async {
    if (_clientId == 0) {
      throw Exception('TelegramService not initialized');
    }

    tdSend(_clientId, CheckAuthenticationPassword(password: password));
  }

  /// Load chats from Telegram
  Future<void> loadChats({int limit = 50}) async {
    if (_clientId == 0) {
      throw Exception('TelegramService not initialized');
    }

    _debugPrint('══════════════════════════════════════════');
    _debugPrint('Loading chats from Telegram (limit: $limit)...');
    _debugPrint('Current cache size: ${_chatsCache.length}');
    _debugPrint('══════════════════════════════════════════');

    // First, request to load chats - this triggers UpdateNewChat events
    tdSend(_clientId, LoadChats(chatList: const ChatListMain(), limit: limit));

    // Also try GetChats to get the list of chat IDs
    tdSend(_clientId, const GetChats(chatList: ChatListMain(), limit: 100));
  }

  /// Get cached chats as TelegramChat objects
  List<TelegramChat> getChats() {
    _debugPrint(
      'Getting chats from cache. Cache size: ${_chatsCache.length}, Raw cache size: ${_rawChatData.length}',
    );

    final chats = <TelegramChat>[];

    // First, add chats from the properly parsed cache
    final sortedChatIds = _chatsCache.keys.toList();
    sortedChatIds.sort((a, b) {
      final chatA = _chatsCache[a];
      final chatB = _chatsCache[b];
      if (chatA == null || chatB == null) return 0;

      // Get the main chat list position
      int orderA = 0;
      int orderB = 0;

      for (final pos in chatA.positions) {
        if (pos.list is ChatListMain) {
          orderA = pos.order;
          break;
        }
      }

      for (final pos in chatB.positions) {
        if (pos.list is ChatListMain) {
          orderB = pos.order;
          break;
        }
      }

      return orderB.compareTo(orderA); // Descending order (most recent first)
    });

    for (final chatId in sortedChatIds) {
      final chat = _chatsCache[chatId];
      if (chat == null) continue;

      // Include all chats that are in the cache
      // TDLib only sends chats that should be visible
      chats.add(_convertToTelegramChat(chat));
    }

    // Also add chats from raw data that weren't fully parsed
    for (final entry in _rawChatData.entries) {
      final chatId = entry.key;
      // Skip if we already have this chat from the proper cache
      if (_chatsCache.containsKey(chatId)) continue;

      final rawChat = entry.value;
      final rawLastMsg = _rawLastMessageData[chatId];
      chats.add(_convertRawToTelegramChat(chatId, rawChat, rawLastMsg));
    }

    _debugPrint(
      'Returning ${chats.length} chats (${_chatsCache.length} parsed, ${_rawChatData.length} raw)',
    );
    return chats;
  }

  /// Convert raw JSON chat data to TelegramChat
  TelegramChat _convertRawToTelegramChat(
    int chatId,
    Map<String, dynamic> chatJson,
    Map<String, dynamic>? lastMsgJson,
  ) {
    final title = chatJson['title'] as String? ?? 'Chat $chatId';

    String lastMessage = '';
    String lastMessageTime = '';
    bool isSentByMe = false;
    //bool isRead = false;
    int unreadCount = 0;

    // Extract from raw chat JSON
    unreadCount = chatJson['unread_count'] as int? ?? 0;

    // Extract from last message if available
    if (lastMsgJson != null) {
      final contentJson = lastMsgJson['content'] as Map<String, dynamic>?;
      if (contentJson != null) {
        lastMessage = _getMessageTextFromRaw(contentJson);
      }
      final date = lastMsgJson['date'] as int?;
      if (date != null) {
        lastMessageTime = _formatMessageTime(date);
      }
      isSentByMe = lastMsgJson['is_outgoing'] as bool? ?? false;
    } else {
      // Try to get last message from the chat json itself
      final lastMsgInChat = chatJson['last_message'] as Map<String, dynamic>?;
      if (lastMsgInChat != null) {
        final contentJson = lastMsgInChat['content'] as Map<String, dynamic>?;
        if (contentJson != null) {
          lastMessage = _getMessageTextFromRaw(contentJson);
        }
        final date = lastMsgInChat['date'] as int?;
        if (date != null) {
          lastMessageTime = _formatMessageTime(date);
        }
        isSentByMe = lastMsgInChat['is_outgoing'] as bool? ?? false;
      }
    }

    // Get last message date for sorting
    int lastMessageDate = 0;
    if (lastMsgJson != null) {
      lastMessageDate = lastMsgJson['date'] as int? ?? 0;
    } else {
      final lastMsgInChat = chatJson['last_message'] as Map<String, dynamic>?;
      if (lastMsgInChat != null) {
        lastMessageDate = lastMsgInChat['date'] as int? ?? 0;
      }
    }

    return TelegramChat(
      id: chatId,
      title: title,
      photoUrl: null, // Can't easily get photo from raw without downloading
      lastMessage: lastMessage,
      lastMessageTime: lastMessageTime,
      unreadCount: unreadCount,
      isRead: unreadCount == 0,
      isSentByMe: isSentByMe,
      lastMessageDate: lastMessageDate,
      order: 0,
    );
  }

  /// Get message text from raw content JSON
  String _getMessageTextFromRaw(Map<String, dynamic> content) {
    try {
      final type = content['@type'] as String?;
      switch (type) {
        case 'messageText':
          final text = content['text'] as Map<String, dynamic>?;
          return _sanitizeString(text?['text'] as String? ?? '');
        case 'messagePhoto':
          final caption = content['caption'] as Map<String, dynamic>?;
          final captionText = _sanitizeString(
            caption?['text'] as String? ?? '',
          );
          return captionText.isNotEmpty ? '📷 $captionText' : '📷 Photo';
        case 'messageVideo':
          final caption = content['caption'] as Map<String, dynamic>?;
          final captionText = _sanitizeString(
            caption?['text'] as String? ?? '',
          );
          return captionText.isNotEmpty ? '🎥 $captionText' : '🎥 Video';
        case 'messageVoiceNote':
          return '🎤 Voice message';
        case 'messageVideoNote':
          return '📹 Video message';
        case 'messageDocument':
          return '📎 Document';
        case 'messageSticker':
          final sticker = content['sticker'] as Map<String, dynamic>?;
          final emoji = _sanitizeString(sticker?['emoji'] as String? ?? '');
          return emoji.isNotEmpty ? emoji : '🎨 Sticker';
        case 'messageAnimation':
          return 'GIF';
        case 'messageAudio':
          return '🎵 Audio';
        case 'messageLocation':
          return '📍 Location';
        case 'messageContact':
          return '👤 Contact';
        case 'messagePoll':
          final poll = content['poll'] as Map<String, dynamic>?;
          final questionObj = poll?['question'];
          String question = '';
          if (questionObj is Map<String, dynamic>) {
            question = _sanitizeString(questionObj['text'] as String? ?? '');
          } else if (questionObj is String) {
            question = _sanitizeString(questionObj);
          }
          return question.isNotEmpty ? '📊 $question' : '📊 Poll';
        default:
          return 'Message';
      }
    } catch (e) {
      _debugPrint('Error in _getMessageTextFromRaw: $e');
      return 'Message';
    }
  }

  /// Sanitize a string to ensure it's valid UTF-16 for Flutter
  String _sanitizeString(String input) {
    try {
      // Test if the string is valid by encoding and decoding
      return String.fromCharCodes(input.runes);
    } catch (e) {
      // If invalid, try to filter out problematic characters
      final buffer = StringBuffer();
      for (int i = 0; i < input.length; i++) {
        try {
          final char = input[i];
          // Check if it's a valid character
          if (char.codeUnitAt(0) > 0) {
            buffer.write(char);
          }
        } catch (_) {
          // Skip invalid characters
        }
      }
      return buffer.toString();
    }
  }

  TelegramChat _convertToTelegramChat(Chat chat) {
    String lastMessage = '';
    String lastMessageTime = '';
    bool isSentByMe = false;
    bool isRead = false;

    if (chat.lastMessage != null) {
      final msg = chat.lastMessage!;
      lastMessage = _getMessageText(msg.content);
      lastMessageTime = _formatMessageTime(msg.date);

      // Check if the message was sent by me
      if (msg.senderId is MessageSenderUser) {
        final senderId = (msg.senderId as MessageSenderUser).userId;
        isSentByMe = _isCurrentUser(senderId);
      }

      // Check if the message was read
      isRead = chat.lastReadOutboxMessageId >= msg.id;
    }

    // Get photo URL if available
    String? photoUrl;
    if (chat.photo != null && chat.photo!.small.local.isDownloadingCompleted) {
      photoUrl = chat.photo!.small.local.path;
    } else if (chat.photo != null) {
      // Request to download the photo
      _downloadFile(chat.photo!.small.id);
    }

    // Get last message date for sorting
    int lastMessageDate = 0;
    if (chat.lastMessage != null) {
      lastMessageDate = chat.lastMessage!.date;
    }

    return TelegramChat(
      id: chat.id,
      title: chat.title,
      photoUrl: photoUrl,
      lastMessage: lastMessage,
      lastMessageTime: lastMessageTime,
      unreadCount: chat.unreadCount,
      isRead: isRead,
      isSentByMe: isSentByMe,
      lastMessageDate: lastMessageDate,
      order: chat.positions.isNotEmpty ? 0 : 0, // Use position for ordering
    );
  }

  String _getMessageText(MessageContent content) {
    if (content is MessageText) {
      return content.text.text;
    } else if (content is MessagePhoto) {
      return content.caption.text.isNotEmpty
          ? content.caption.text
          : '📷 Photo';
    } else if (content is MessageVideo) {
      return content.caption.text.isNotEmpty
          ? content.caption.text
          : '🎬 Video';
    } else if (content is MessageDocument) {
      return content.caption.text.isNotEmpty
          ? content.caption.text
          : '📄 Document';
    } else if (content is MessageVoiceNote) {
      return '🎤 Voice message';
    } else if (content is MessageVideoNote) {
      return '📹 Video message';
    } else if (content is MessageSticker) {
      return '${content.sticker.emoji} Sticker';
    } else if (content is MessageAudio) {
      return '🎵 Audio';
    } else if (content is MessageAnimation) {
      return 'GIF';
    } else if (content is MessageContact) {
      return '👤 Contact';
    } else if (content is MessageLocation) {
      return '📍 Location';
    } else if (content is MessagePoll) {
      return '📊 Poll';
    } else if (content is MessageCall) {
      return '📞 Call';
    }
    return 'Message';
  }

  String _formatMessageTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      // Today - show time
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      // This week - show day name
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    } else {
      // Older - show date
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      return '$day.$month';
    }
  }

  bool _isCurrentUser(int userId) {
    if (_currentUserId != null) {
      return userId == _currentUserId;
    }
    return false;
  }

  void _downloadFile(int fileId) {
    if (_clientId == 0) return;

    tdSend(
      _clientId,
      DownloadFile(
        fileId: fileId,
        priority: 1,
        offset: 0,
        limit: 0,
        synchronous: false,
      ),
    );
  }

  /// Handle file download updates from raw JSON
  void _handleRawFileUpdate(Map<String, dynamic> fileJson) {
    final fileId = fileJson['id'] as int?;
    if (fileId == null) return;

    final local = fileJson['local'] as Map<String, dynamic>?;
    if (local == null) return;

    final expectedSize = fileJson['expected_size'] as int? ?? 1;
    final downloadedSize = local['downloaded_size'] as int? ?? 0;
    final isCompleted = local['is_downloading_completed'] as bool? ?? false;
    final isActive = local['is_downloading_active'] as bool? ?? false;
    final path = local['path'] as String?;

    final progress = expectedSize > 0 ? downloadedSize / expectedSize : 0.0;

    _fileDownloadStates[fileId] = FileDownloadState(
      fileId: fileId,
      isDownloading: isActive,
      progress: progress.clamp(0.0, 1.0),
      localPath: isCompleted ? path : null,
    );

    _fileDownloadProgressController.add(
      FileDownloadProgress(
        fileId: fileId,
        progress: progress.clamp(0.0, 1.0),
        isCompleted: isCompleted,
        localPath: isCompleted ? path : null,
      ),
    );

    if (isCompleted && path != null) {
      _debugPrint('RAW: File $fileId download completed: $path');
    }
  }

  /// Handle message content update (when a message is edited)
  void _handleMessageContentUpdate(
    int chatId,
    int messageId,
    Map<String, dynamic> newContent,
  ) {
    final messages = _messagesCache[chatId];
    if (messages == null) return;

    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final oldMessage = messages[index];
    final newText = _getMessageTextFromRaw(newContent);
    final newMediaInfo = extractMediaInfo(newContent);

    messages[index] = TelegramMessage(
      id: oldMessage.id,
      chatId: oldMessage.chatId,
      text: newText,
      time: oldMessage.time,
      isOutgoing: oldMessage.isOutgoing,
      senderId: oldMessage.senderId,
      senderName: oldMessage.senderName,
      status: oldMessage.status,
      contentType: newContent['@type'] as String? ?? 'text',
      mediaInfo: newMediaInfo,
      date: oldMessage.date,
    );

    _debugPrint('RAW: Updated message $messageId content in chat $chatId');
    _emitMessages(chatId);
    _emitChats();
  }

  /// Handle message read status update (when recipient reads a message)
  void _handleReadOutbox(int chatId, int lastReadOutboxMessageId) {
    final messages = _messagesCache[chatId];
    if (messages == null) return;

    bool updated = false;
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      // Update status to 'read' for outgoing messages that were read
      if (msg.isOutgoing &&
          msg.id <= lastReadOutboxMessageId &&
          msg.status != MessageStatus.read) {
        messages[i] = TelegramMessage(
          id: msg.id,
          chatId: msg.chatId,
          text: msg.text,
          time: msg.time,
          isOutgoing: msg.isOutgoing,
          senderId: msg.senderId,
          senderName: msg.senderName,
          status: MessageStatus.read,
          contentType: msg.contentType,
          mediaInfo: msg.mediaInfo,
          date: msg.date,
        );
        updated = true;
      }
    }

    if (updated) {
      _debugPrint(
        'RAW: Updated read status for messages in chat $chatId up to $lastReadOutboxMessageId',
      );
      _emitMessages(chatId);
    }
  }

  /// Handle file download updates
  void _handleFileUpdate(File file) {
    final local = file.local;
    final expectedSize = file.expectedSize > 0 ? file.expectedSize : 1;
    final downloadedSize = local.downloadedSize;
    final progress = downloadedSize / expectedSize;

    _fileDownloadStates[file.id] = FileDownloadState(
      fileId: file.id,
      isDownloading: local.isDownloadingActive,
      progress: progress.clamp(0.0, 1.0),
      localPath: local.isDownloadingCompleted ? local.path : null,
    );

    _fileDownloadProgressController.add(
      FileDownloadProgress(
        fileId: file.id,
        progress: progress.clamp(0.0, 1.0),
        isCompleted: local.isDownloadingCompleted,
        localPath: local.isDownloadingCompleted ? local.path : null,
      ),
    );

    if (local.isDownloadingCompleted) {
      _debugPrint('File ${file.id} download completed: ${local.path}');
    }
  }

  /// Debounced emit chats to prevent excessive UI updates
  void _emitChats() {
    _emitChatsDebounceTimer?.cancel();
    _emitChatsDebounceTimer = Timer(
      const Duration(milliseconds: _emitChatsDebounceMs),
      _emitChatsNow,
    );
  }

  /// Immediately emit chats (called after debounce)
  void _emitChatsNow() {
    final chats = getChats();
    _debugPrint('Emitting ${chats.length} chats');
    _chatsController.add(chats);
    _updateUnreadCount();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MESSAGE METHODS - Phase 1 Implementation
  // ═══════════════════════════════════════════════════════════════════════════

  /// Load chat history for a specific chat
  Future<void> loadChatHistory(
    int chatId, {
    int limit = 50,
    int fromMessageId = 0,
  }) async {
    if (_clientId == 0) {
      throw Exception('TelegramService not initialized');
    }

    _debugPrint(
      'Loading chat history for chat $chatId (limit: $limit, from: $fromMessageId)',
    );

    // Request to get current user first if we don't have it
    if (_currentUserId == null) {
      tdSend(_clientId, const GetMe());
    }

    tdSend(
      _clientId,
      GetChatHistory(
        chatId: chatId,
        fromMessageId: fromMessageId,
        offset: 0,
        limit: limit,
        onlyLocal: false,
      ),
    );
  }

  /// Get cached messages for a chat
  List<TelegramMessage> getMessages(int chatId) {
    return _messagesCache[chatId] ?? [];
  }

  /// Send a text message to a chat
  Future<void> sendMessage(int chatId, String text) async {
    if (_clientId == 0) {
      throw Exception('TelegramService not initialized');
    }

    if (text.trim().isEmpty) {
      return;
    }

    _debugPrint(
      'Sending message to chat $chatId: "${text.substring(0, text.length.clamp(0, 50))}..."',
    );

    // Create a temporary message with "sending" status
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final tempMessage = TelegramMessage(
      id: tempId,
      chatId: chatId,
      text: text,
      time: _formatMessageTime(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      isOutgoing: true,
      senderId: _currentUserId ?? 0,
      status: MessageStatus.sending,
      date: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    // Add to cache immediately for instant UI feedback
    _messagesCache[chatId] ??= [];
    _messagesCache[chatId]!.insert(0, tempMessage);
    _emitMessages(chatId);

    // Send the message via TDLib
    tdSend(
      _clientId,
      SendMessage(
        chatId: chatId,
        messageThreadId: 0,
        replyTo: null,
        options: null,
        replyMarkup: null,
        inputMessageContent: InputMessageText(
          text: FormattedText(text: text, entities: []),
          disableWebPagePreview: false,
          clearDraft: true,
        ),
      ),
    );
  }

  /// Send a photo message
  Future<void> sendPhoto(
    int chatId,
    String filePath, {
    String? caption,
    int? replyToMessageId,
  }) async {
    if (_clientId == 0) {
      throw Exception('TelegramService not initialized');
    }

    _debugPrint('Sending photo to chat $chatId: $filePath');

    // Create a temporary message
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final tempMessage = TelegramMessage(
      id: tempId,
      chatId: chatId,
      text: caption ?? '📷 Photo',
      time: _formatMessageTime(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      isOutgoing: true,
      senderId: _currentUserId ?? 0,
      status: MessageStatus.sending,
      contentType: 'messagePhoto',
      mediaInfo: {'type': 'photo', 'localPath': filePath, 'isDownloaded': true},
      date: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    _messagesCache[chatId] ??= [];
    _messagesCache[chatId]!.insert(0, tempMessage);
    _emitMessages(chatId);

    tdSend(
      _clientId,
      SendMessage(
        chatId: chatId,
        messageThreadId: 0,
        replyTo: replyToMessageId != null
            ? MessageReplyToMessage(chatId: chatId, messageId: replyToMessageId)
            : null,
        options: null,
        replyMarkup: null,
        inputMessageContent: InputMessagePhoto(
          photo: InputFileLocal(path: filePath),
          thumbnail: null,
          addedStickerFileIds: [],
          width: 0,
          height: 0,
          caption: FormattedText(text: caption ?? '', entities: []),
          selfDestructTime: 0,
          hasSpoiler: false,
        ),
      ),
    );
  }

  /// Send a video message
  Future<void> sendVideo(
    int chatId,
    String filePath, {
    String? caption,
    int? duration,
    int? width,
    int? height,
    int? replyToMessageId,
  }) async {
    if (_clientId == 0) {
      throw Exception('TelegramService not initialized');
    }

    _debugPrint('Sending video to chat $chatId: $filePath');

    // Create a temporary message
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final tempMessage = TelegramMessage(
      id: tempId,
      chatId: chatId,
      text: caption ?? '🎬 Video',
      time: _formatMessageTime(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      isOutgoing: true,
      senderId: _currentUserId ?? 0,
      status: MessageStatus.sending,
      contentType: 'messageVideo',
      mediaInfo: {
        'type': 'video',
        'localPath': filePath,
        'isDownloaded': true,
        'duration': duration,
      },
      date: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    _messagesCache[chatId] ??= [];
    _messagesCache[chatId]!.insert(0, tempMessage);
    _emitMessages(chatId);

    tdSend(
      _clientId,
      SendMessage(
        chatId: chatId,
        messageThreadId: 0,
        replyTo: replyToMessageId != null
            ? MessageReplyToMessage(chatId: chatId, messageId: replyToMessageId)
            : null,
        options: null,
        replyMarkup: null,
        inputMessageContent: InputMessageVideo(
          video: InputFileLocal(path: filePath),
          thumbnail: null,
          addedStickerFileIds: [],
          duration: duration ?? 0,
          width: width ?? 0,
          height: height ?? 0,
          supportsStreaming: true,
          caption: FormattedText(text: caption ?? '', entities: []),
          selfDestructTime: 0,
          hasSpoiler: false,
        ),
      ),
    );
  }

  /// Send a document/file
  Future<void> sendDocument(
    int chatId,
    String filePath, {
    String? caption,
    int? replyToMessageId,
  }) async {
    if (_clientId == 0) {
      throw Exception('TelegramService not initialized');
    }

    final fileName = filePath.split('/').last.split('\\').last;
    _debugPrint('Sending document to chat $chatId: $fileName');

    // Create a temporary message
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final tempMessage = TelegramMessage(
      id: tempId,
      chatId: chatId,
      text: caption ?? '📄 $fileName',
      time: _formatMessageTime(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      isOutgoing: true,
      senderId: _currentUserId ?? 0,
      status: MessageStatus.sending,
      contentType: 'messageDocument',
      mediaInfo: {
        'type': 'document',
        'localPath': filePath,
        'fileName': fileName,
        'isDownloaded': true,
      },
      date: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    _messagesCache[chatId] ??= [];
    _messagesCache[chatId]!.insert(0, tempMessage);
    _emitMessages(chatId);

    tdSend(
      _clientId,
      SendMessage(
        chatId: chatId,
        messageThreadId: 0,
        replyTo: replyToMessageId != null
            ? MessageReplyToMessage(chatId: chatId, messageId: replyToMessageId)
            : null,
        options: null,
        replyMarkup: null,
        inputMessageContent: InputMessageDocument(
          document: InputFileLocal(path: filePath),
          thumbnail: null,
          disableContentTypeDetection: false,
          caption: FormattedText(text: caption ?? '', entities: []),
        ),
      ),
    );
  }

  /// Send a voice note
  Future<void> sendVoiceNote(
    int chatId,
    String filePath, {
    int? duration,
    int? replyToMessageId,
  }) async {
    if (_clientId == 0) {
      throw Exception('TelegramService not initialized');
    }

    _debugPrint('Sending voice note to chat $chatId');

    // Create a temporary message
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final tempMessage = TelegramMessage(
      id: tempId,
      chatId: chatId,
      text: '🎤 Voice message',
      time: _formatMessageTime(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      isOutgoing: true,
      senderId: _currentUserId ?? 0,
      status: MessageStatus.sending,
      contentType: 'messageVoiceNote',
      mediaInfo: {
        'type': 'voiceNote',
        'localPath': filePath,
        'duration': duration,
        'isDownloaded': true,
      },
      date: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    _messagesCache[chatId] ??= [];
    _messagesCache[chatId]!.insert(0, tempMessage);
    _emitMessages(chatId);

    tdSend(
      _clientId,
      SendMessage(
        chatId: chatId,
        messageThreadId: 0,
        replyTo: replyToMessageId != null
            ? MessageReplyToMessage(chatId: chatId, messageId: replyToMessageId)
            : null,
        options: null,
        replyMarkup: null,
        inputMessageContent: InputMessageVoiceNote(
          voiceNote: InputFileLocal(path: filePath),
          duration: duration ?? 0,
          waveform: '',
          caption: FormattedText(text: '', entities: []),
        ),
      ),
    );
  }

  /// Send a location
  Future<void> sendLocation(
    int chatId,
    double latitude,
    double longitude, {
    int? replyToMessageId,
    int? livePeriod,
  }) async {
    if (_clientId == 0) {
      throw Exception('TelegramService not initialized');
    }

    _debugPrint('Sending location to chat $chatId: $latitude, $longitude');

    // Create a temporary message
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final tempMessage = TelegramMessage(
      id: tempId,
      chatId: chatId,
      text: '📍 Location',
      time: _formatMessageTime(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      isOutgoing: true,
      senderId: _currentUserId ?? 0,
      status: MessageStatus.sending,
      contentType: 'messageLocation',
      mediaInfo: {
        'type': 'location',
        'latitude': latitude,
        'longitude': longitude,
      },
      date: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    _messagesCache[chatId] ??= [];
    _messagesCache[chatId]!.insert(0, tempMessage);
    _emitMessages(chatId);

    tdSend(
      _clientId,
      SendMessage(
        chatId: chatId,
        messageThreadId: 0,
        replyTo: replyToMessageId != null
            ? MessageReplyToMessage(chatId: chatId, messageId: replyToMessageId)
            : null,
        options: null,
        replyMarkup: null,
        inputMessageContent: InputMessageLocation(
          location: Location(
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracy: 0,
          ),
          livePeriod: livePeriod ?? 0,
          heading: 0,
          proximityAlertRadius: 0,
        ),
      ),
    );
  }

  /// Send a contact
  Future<void> sendContact(
    int chatId,
    String phoneNumber,
    String firstName, {
    String? lastName,
    int? replyToMessageId,
  }) async {
    if (_clientId == 0) {
      throw Exception('TelegramService not initialized');
    }

    _debugPrint('Sending contact to chat $chatId: $firstName $phoneNumber');

    // Create a temporary message
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final tempMessage = TelegramMessage(
      id: tempId,
      chatId: chatId,
      text: '👤 $firstName',
      time: _formatMessageTime(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      isOutgoing: true,
      senderId: _currentUserId ?? 0,
      status: MessageStatus.sending,
      contentType: 'messageContact',
      mediaInfo: {
        'type': 'contact',
        'firstName': firstName,
        'lastName': lastName ?? '',
        'phoneNumber': phoneNumber,
      },
      date: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    _messagesCache[chatId] ??= [];
    _messagesCache[chatId]!.insert(0, tempMessage);
    _emitMessages(chatId);

    tdSend(
      _clientId,
      SendMessage(
        chatId: chatId,
        messageThreadId: 0,
        replyTo: replyToMessageId != null
            ? MessageReplyToMessage(chatId: chatId, messageId: replyToMessageId)
            : null,
        options: null,
        replyMarkup: null,
        inputMessageContent: InputMessageContact(
          contact: Contact(
            phoneNumber: phoneNumber,
            firstName: firstName,
            lastName: lastName ?? '',
            vcard: '',
            userId: 0,
          ),
        ),
      ),
    );
  }

  /// Send a sticker by file ID
  Future<void> sendSticker(
    int chatId,
    int stickerFileId, {
    int? replyToMessageId,
  }) async {
    if (_clientId == 0) {
      throw Exception('TelegramService not initialized');
    }

    _debugPrint('Sending sticker to chat $chatId');

    tdSend(
      _clientId,
      SendMessage(
        chatId: chatId,
        messageThreadId: 0,
        replyTo: replyToMessageId != null
            ? MessageReplyToMessage(chatId: chatId, messageId: replyToMessageId)
            : null,
        options: null,
        replyMarkup: null,
        inputMessageContent: InputMessageSticker(
          sticker: InputFileId(id: stickerFileId),
          thumbnail: null,
          width: 0,
          height: 0,
          emoji: '',
        ),
      ),
    );
  }

  /// Download a media file
  Future<void> downloadMediaFile(int fileId, {int priority = 5}) async {
    if (_clientId == 0) return;

    _debugPrint('Starting download for file $fileId with priority $priority');

    tdSend(
      _clientId,
      DownloadFile(
        fileId: fileId,
        priority: priority,
        offset: 0,
        limit: 0,
        synchronous: false,
      ),
    );
  }

  /// Cancel a file download
  Future<void> cancelDownload(int fileId) async {
    if (_clientId == 0) return;

    tdSend(_clientId, CancelDownloadFile(fileId: fileId, onlyIfPending: false));
  }

  /// Get file download state
  FileDownloadState? getFileDownloadState(int fileId) {
    return _fileDownloadStates[fileId];
  }

  /// Get file local path if downloaded
  String? getFileLocalPath(int fileId) {
    final state = _fileDownloadStates[fileId];
    return state?.localPath;
  }

  /// Handle raw new message from TDLib
  void _handleRawNewMessage(int chatId, Map<String, dynamic> msgJson) {
    final message = _convertRawToTelegramMessage(msgJson);
    if (message == null) return;

    _messagesCache[chatId] ??= [];

    // Check if message already exists (avoid duplicates)
    final existingIndex = _messagesCache[chatId]!.indexWhere(
      (m) => m.id == message.id,
    );

    // For outgoing messages, check if we have a pending temp message to replace
    if (message.isOutgoing) {
      final tempIndex = _messagesCache[chatId]!.indexWhere(
        (m) => m.id < 0 && m.text == message.text,
      );
      if (tempIndex != -1) {
        // Replace the temp message with the real one
        _messagesCache[chatId]![tempIndex] = message;
        _debugPrint('Replaced temp message with real message ${message.id}');
        _emitMessages(chatId);
        _emitChats();
        return;
      }
    }

    if (existingIndex == -1) {
      // Insert at the beginning (newest first)
      _messagesCache[chatId]!.insert(0, message);
      _debugPrint(
        'Added new message to chat $chatId: ${message.text.substring(0, message.text.length.clamp(0, 30))}',
      );
    }

    _emitMessages(chatId);
    _emitChats(); // Update chat list with new last message
  }

  /// Handle messages response (chat history)
  void _handleRawMessages(int chatId, List<Map<String, dynamic>> messagesJson) {
    final newMessages = <TelegramMessage>[];

    for (final msgJson in messagesJson) {
      final message = _convertRawToTelegramMessage(msgJson);
      if (message != null) {
        newMessages.add(message);
      }
    }

    _messagesCache[chatId] ??= [];

    // Merge with existing messages, avoiding duplicates
    for (final msg in newMessages) {
      final existingIndex = _messagesCache[chatId]!.indexWhere(
        (m) => m.id == msg.id,
      );
      if (existingIndex == -1) {
        _messagesCache[chatId]!.add(msg);
      }
    }

    // Sort messages by date (newest first for display)
    _messagesCache[chatId]!.sort((a, b) => b.date.compareTo(a.date));

    _debugPrint(
      'Chat $chatId now has ${_messagesCache[chatId]!.length} messages',
    );
    _emitMessages(chatId);
  }

  /// Handle message send succeeded
  void _handleMessageSendSucceeded(
    int chatId,
    Map<String, dynamic> msgJson,
    int? oldMsgId,
  ) {
    final newMessage = _convertRawToTelegramMessage(msgJson);
    if (newMessage == null) return;

    _messagesCache[chatId] ??= [];

    bool replaced = false;

    // Find and replace the temporary message by oldMsgId
    if (oldMsgId != null) {
      final tempIndex = _messagesCache[chatId]!.indexWhere(
        (m) => m.id == oldMsgId,
      );
      if (tempIndex != -1) {
        _messagesCache[chatId]![tempIndex] = newMessage;
        replaced = true;
        _debugPrint(
          'Updated temp message $oldMsgId to real message ${newMessage.id}',
        );
      }
    }

    // Also try to find by negative ID or matching text
    if (!replaced) {
      final tempIndex = _messagesCache[chatId]!.indexWhere(
        (m) => m.id < 0 && m.text == newMessage.text,
      );
      if (tempIndex != -1) {
        _messagesCache[chatId]![tempIndex] = newMessage;
        replaced = true;
        _debugPrint(
          'Updated temp message (by text match) to real message ${newMessage.id}',
        );
      }
    }

    // Check if this message already exists (avoid duplicates)
    if (!replaced) {
      final existingIndex = _messagesCache[chatId]!.indexWhere(
        (m) => m.id == newMessage.id,
      );
      if (existingIndex == -1) {
        // Message doesn't exist, add it
        _messagesCache[chatId]!.insert(0, newMessage);
      }
    }

    _emitMessages(chatId);
    _emitChats();
  }

  /// Handle message send failed
  void _handleMessageSendFailed(int chatId, int? oldMsgId) {
    _messagesCache[chatId] ??= [];

    // Find the failed message and update its status
    int index = -1;
    if (oldMsgId != null) {
      index = _messagesCache[chatId]!.indexWhere((m) => m.id == oldMsgId);
    }
    if (index == -1) {
      index = _messagesCache[chatId]!.indexWhere((m) => m.id < 0);
    }

    if (index != -1) {
      final failedMsg = _messagesCache[chatId]![index];
      _messagesCache[chatId]![index] = TelegramMessage(
        id: failedMsg.id,
        chatId: failedMsg.chatId,
        text: failedMsg.text,
        time: failedMsg.time,
        isOutgoing: failedMsg.isOutgoing,
        senderId: failedMsg.senderId,
        senderName: failedMsg.senderName,
        status: MessageStatus.failed,
        contentType: failedMsg.contentType,
        date: failedMsg.date,
      );
      _debugPrint('Message send failed for chat $chatId');
    }

    _emitMessages(chatId);
  }

  /// Handle global search results from raw JSON
  void _handleRawFoundMessages(
    List<Map<String, dynamic>> messagesJson,
    int totalCount,
    String? nextOffset,
  ) {
    final messages = <SearchResultMessage>[];

    for (final msgJson in messagesJson) {
      final converted = _convertRawToSearchResult(msgJson);
      if (converted != null) {
        messages.add(converted);
      }
    }

    _lastSearchResults = SearchResults(
      messages: messages,
      totalCount: totalCount,
      nextOffset: nextOffset,
    );

    _searchResultsController.add(_lastSearchResults!);
    _debugPrint(
      'Global search returned ${messages.length} messages (total: $totalCount)',
    );
  }

  /// Handle chat-specific search results from raw JSON
  void _handleRawFoundChatMessages(
    int chatId,
    List<Map<String, dynamic>> messagesJson,
    int totalCount,
    int nextFromMessageId,
  ) {
    final messages = <SearchResultMessage>[];

    for (final msgJson in messagesJson) {
      final converted = _convertRawToSearchResult(msgJson);
      if (converted != null) {
        messages.add(converted);
      }
    }

    _lastSearchResults = SearchResults(
      messages: messages,
      totalCount: totalCount,
      nextFromMessageId: nextFromMessageId,
      chatId: chatId,
    );

    _searchResultsController.add(_lastSearchResults!);
    _debugPrint(
      'Chat search returned ${messages.length} messages in chat $chatId',
    );
  }

  /// Convert raw JSON message to SearchResultMessage
  SearchResultMessage? _convertRawToSearchResult(Map<String, dynamic> msgJson) {
    try {
      final id = msgJson['id'] as int?;
      final chatId = msgJson['chat_id'] as int?;
      final date = msgJson['date'] as int?;
      final isOutgoing = msgJson['is_outgoing'] as bool? ?? false;

      if (id == null || chatId == null || date == null) return null;

      // Get sender info
      int senderId = 0;
      String senderName = '';
      final senderJson = msgJson['sender_id'] as Map<String, dynamic>?;
      if (senderJson != null) {
        final senderType = senderJson['@type'] as String?;
        if (senderType == 'messageSenderUser') {
          senderId = senderJson['user_id'] as int? ?? 0;
          final user = _usersCache[senderId];
          if (user != null) {
            senderName = _sanitizeString(
              '${user.firstName} ${user.lastName}'.trim(),
            );
          }
        } else if (senderType == 'messageSenderChat') {
          senderId = senderJson['chat_id'] as int? ?? 0;
          final chat = _chatsCache[senderId];
          if (chat != null) {
            senderName = chat.title;
          }
        }
      }

      // Get chat title
      String chatTitle = '';
      if (_chatsCache.containsKey(chatId)) {
        chatTitle = _chatsCache[chatId]!.title;
      } else if (_rawChatData.containsKey(chatId)) {
        chatTitle = _rawChatData[chatId]!['title'] as String? ?? 'Chat $chatId';
      }

      // Get message content
      String text = '';
      String contentType = 'text';
      final contentJson = msgJson['content'] as Map<String, dynamic>?;
      if (contentJson != null) {
        contentType = contentJson['@type'] as String? ?? 'text';
        text = _getMessageTextFromRaw(contentJson);
      }

      return SearchResultMessage(
        id: id,
        chatId: chatId,
        chatTitle: chatTitle,
        senderId: senderId,
        senderName: senderName,
        text: text,
        contentType: contentType,
        date: date,
        isOutgoing: isOutgoing,
      );
    } catch (e) {
      _debugPrint('Error converting raw message to search result: $e');
      return null;
    }
  }

  /// Convert raw JSON message to TelegramMessage
  TelegramMessage? _convertRawToTelegramMessage(Map<String, dynamic> msgJson) {
    try {
      final id = msgJson['id'] as int?;
      final chatId = msgJson['chat_id'] as int?;
      final date = msgJson['date'] as int?;
      final isOutgoing = msgJson['is_outgoing'] as bool? ?? false;

      if (id == null || chatId == null || date == null) return null;

      // Get sender info
      int senderId = 0;
      String? senderName;
      final senderJson = msgJson['sender_id'] as Map<String, dynamic>?;
      if (senderJson != null) {
        final senderType = senderJson['@type'] as String?;
        if (senderType == 'messageSenderUser') {
          senderId = senderJson['user_id'] as int? ?? 0;
          final user = _usersCache[senderId];
          if (user != null) {
            senderName = _sanitizeString(
              '${user.firstName} ${user.lastName}'.trim(),
            );
          }
        } else if (senderType == 'messageSenderChat') {
          senderId = senderJson['chat_id'] as int? ?? 0;
        }
      }

      // Get message content
      String text = '';
      String contentType = 'text';
      Map<String, dynamic>? mediaInfo;
      final contentJson = msgJson['content'] as Map<String, dynamic>?;
      if (contentJson != null) {
        contentType = contentJson['@type'] as String? ?? 'text';
        text = _getMessageTextFromRaw(contentJson);
        // Extract media info for media messages
        mediaInfo = extractMediaInfo(contentJson);
      }

      // Determine message status
      MessageStatus status = MessageStatus.sent;
      if (isOutgoing) {
        // Check if message has been read by using chat's last read outbox message id
        final chat = _chatsCache[chatId];
        if (chat != null && chat.lastReadOutboxMessageId >= id) {
          status = MessageStatus.read;
        } else {
          // Message is sent but not yet read
          status = MessageStatus.sent;
        }
      }

      return TelegramMessage(
        id: id,
        chatId: chatId,
        text: text,
        time: _formatMessageTime(date),
        isOutgoing: isOutgoing,
        senderId: senderId,
        senderName: senderName,
        status: status,
        contentType: contentType,
        mediaInfo: mediaInfo,
        date: date,
      );
    } catch (e) {
      _debugPrint('Error converting raw message: $e');
      return null;
    }
  }

  /// Emit messages for a specific chat
  void _emitMessages(int chatId) {
    if (_messageControllers.containsKey(chatId)) {
      final messages = _messagesCache[chatId] ?? [];
      _debugPrint('Emitting ${messages.length} messages for chat $chatId');
      _messageControllers[chatId]!.add(messages);
    }
  }

  /// Mark messages as read in a chat
  Future<void> markChatAsRead(int chatId) async {
    if (_clientId == 0) return;

    final messages = _messagesCache[chatId];
    if (messages == null || messages.isEmpty) return;

    // Get the latest message ID
    final latestMsgId = messages
        .map((m) => m.id)
        .reduce((a, b) => a > b ? a : b);

    tdSend(
      _clientId,
      ViewMessages(chatId: chatId, messageIds: [latestMsgId], forceRead: true),
    );
  }

  void dispose() {
    _isRunning = false;
    _receiveTimer?.cancel();
    _receiveTimer = null;
    if (_clientId != 0) {
      tdSend(_clientId, const Close());
    }
    _authStateController.close();
    _chatsController.close();
    for (final controller in _messageControllers.values) {
      controller.close();
    }
    _messageControllers.clear();
    _fileDownloadProgressController.close();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 2: USER PROFILES & MEDIA HANDLING
  // ═══════════════════════════════════════════════════════════════════════════

  // Cache for user profiles (extended info)
  final Map<int, Map<String, dynamic>> _userFullInfoCache = {};

  // Stream for file download progress
  final _fileDownloadProgressController =
      StreamController<FileDownloadProgress>.broadcast();
  Stream<FileDownloadProgress> get fileDownloadProgressStream =>
      _fileDownloadProgressController.stream;

  // Cache for file download states
  final Map<int, FileDownloadState> _fileDownloadStates = {};

  /// Get current user ID
  int? get currentUserId => _currentUserId;

  /// Get user from cache
  User? getUser(int userId) => _usersCache[userId];

  /// Request user info from TDLib
  Future<void> requestUser(int userId) async {
    if (_clientId == 0) return;
    if (_usersCache.containsKey(userId)) return;

    tdSend(_clientId, GetUser(userId: userId));
  }

  /// Request full user info (bio, etc.)
  Future<void> requestUserFullInfo(int userId) async {
    if (_clientId == 0) return;

    tdSend(_clientId, GetUserFullInfo(userId: userId));
  }

  /// Get user's online status text
  String getUserStatusText(int userId) {
    final user = _usersCache[userId];
    if (user == null) return '';

    final status = user.status;
    if (status is UserStatusOnline) {
      return 'online';
    } else if (status is UserStatusRecently) {
      return 'last seen recently';
    } else if (status is UserStatusLastWeek) {
      return 'last seen within a week';
    } else if (status is UserStatusLastMonth) {
      return 'last seen within a month';
    } else if (status is UserStatusOffline) {
      final wasOnline = DateTime.fromMillisecondsSinceEpoch(
        status.wasOnline * 1000,
      );
      final diff = DateTime.now().difference(wasOnline);
      if (diff.inMinutes < 1) {
        return 'last seen just now';
      } else if (diff.inMinutes < 60) {
        return 'last seen ${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return 'last seen ${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return 'last seen ${diff.inDays}d ago';
      } else {
        return 'last seen ${wasOnline.day}.${wasOnline.month}';
      }
    }
    return 'last seen a long time ago';
  }

  /// Check if user is online
  bool isUserOnline(int userId) {
    final user = _usersCache[userId];
    if (user == null) return false;
    return user.status is UserStatusOnline;
  }

  /// Get chat info (for private chats, returns user ID)
  int? getChatUserId(int chatId) {
    final chat = _chatsCache[chatId];
    if (chat == null) return null;

    final chatType = chat.type;
    if (chatType is ChatTypePrivate) {
      return chatType.userId;
    } else if (chatType is ChatTypeSecret) {
      return chatType.userId;
    }
    return null;
  }

  /// Get chat photo local path
  String? getChatPhotoPath(int chatId) {
    final chat = _chatsCache[chatId];
    if (chat?.photo == null) return null;

    final photo = chat!.photo!;
    if (photo.small.local.isDownloadingCompleted) {
      return photo.small.local.path;
    }
    return null;
  }

  /// Download a file with progress tracking
  Future<void> downloadFileWithProgress(int fileId, {int priority = 1}) async {
    if (_clientId == 0) return;

    // Initialize download state
    _fileDownloadStates[fileId] = FileDownloadState(
      fileId: fileId,
      isDownloading: true,
      progress: 0.0,
    );

    _fileDownloadProgressController.add(
      FileDownloadProgress(fileId: fileId, progress: 0.0, isCompleted: false),
    );

    tdSend(
      _clientId,
      DownloadFile(
        fileId: fileId,
        priority: priority,
        offset: 0,
        limit: 0,
        synchronous: false,
      ),
    );
  }

  /// Cancel a file download
  Future<void> cancelFileDownload(int fileId) async {
    if (_clientId == 0) return;

    tdSend(_clientId, CancelDownloadFile(fileId: fileId, onlyIfPending: false));

    _fileDownloadStates[fileId] = FileDownloadState(
      fileId: fileId,
      isDownloading: false,
      progress: 0.0,
    );
  }

  /// Check if file is downloaded
  bool isFileDownloaded(int fileId) {
    final file = _filesCache[fileId];
    return file?.local.isDownloadingCompleted ?? false;
  }

  /// Extract media info from message content JSON
  Map<String, dynamic>? extractMediaInfo(Map<String, dynamic>? contentJson) {
    if (contentJson == null) return null;

    final type = contentJson['@type'] as String?;
    switch (type) {
      case 'messagePhoto':
        return _extractPhotoInfo(contentJson);
      case 'messageVideo':
        return _extractVideoInfo(contentJson);
      case 'messageVoiceNote':
        return _extractVoiceNoteInfo(contentJson);
      case 'messageVideoNote':
        return _extractVideoNoteInfo(contentJson);
      case 'messageDocument':
        return _extractDocumentInfo(contentJson);
      case 'messageSticker':
        return _extractStickerInfo(contentJson);
      case 'messageAnimation':
        return _extractAnimationInfo(contentJson);
      case 'messageAudio':
        return _extractAudioInfo(contentJson);
      case 'messageLocation':
        return _extractLocationInfo(contentJson);
      case 'messageContact':
        return _extractContactInfo(contentJson);
      default:
        return null;
    }
  }

  Map<String, dynamic> _extractLocationInfo(Map<String, dynamic> content) {
    final location = content['location'] as Map<String, dynamic>?;
    return {
      'type': 'location',
      'latitude': location?['latitude'] as double? ?? 0.0,
      'longitude': location?['longitude'] as double? ?? 0.0,
      'horizontalAccuracy': location?['horizontal_accuracy'] as double?,
    };
  }

  Map<String, dynamic> _extractContactInfo(Map<String, dynamic> content) {
    final contact = content['contact'] as Map<String, dynamic>?;
    return {
      'type': 'contact',
      'phoneNumber': contact?['phone_number'] as String? ?? '',
      'firstName': contact?['first_name'] as String? ?? '',
      'lastName': contact?['last_name'] as String? ?? '',
      'userId': contact?['user_id'] as int?,
      'vcard': contact?['vcard'] as String?,
    };
  }

  Map<String, dynamic>? _extractPhotoInfo(Map<String, dynamic> content) {
    final photo = content['photo'] as Map<String, dynamic>?;
    if (photo == null) return null;

    final sizes = photo['sizes'] as List?;
    if (sizes == null || sizes.isEmpty) return null;

    // Get the largest size
    Map<String, dynamic>? bestSize;
    int maxWidth = 0;
    for (final size in sizes) {
      final sizeMap = size as Map<String, dynamic>;
      final width = sizeMap['width'] as int? ?? 0;
      if (width > maxWidth) {
        maxWidth = width;
        bestSize = sizeMap;
      }
    }

    if (bestSize == null) return null;

    final fileJson = bestSize['photo'] as Map<String, dynamic>?;
    final caption = content['caption'] as Map<String, dynamic>?;

    return {
      'type': 'photo',
      'fileId': fileJson?['id'] as int?,
      'width': bestSize['width'] as int?,
      'height': bestSize['height'] as int?,
      'fileSize':
          fileJson?['size'] as int? ?? fileJson?['expected_size'] as int?,
      'caption': _sanitizeString(caption?['text'] as String? ?? ''),
      'localPath': _getLocalPath(fileJson),
      'isDownloaded': _isFileDownloaded(fileJson),
    };
  }

  Map<String, dynamic>? _extractVideoInfo(Map<String, dynamic> content) {
    final video = content['video'] as Map<String, dynamic>?;
    if (video == null) return null;

    final fileJson = video['video'] as Map<String, dynamic>?;
    final thumbJson = video['thumbnail'] as Map<String, dynamic>?;
    final caption = content['caption'] as Map<String, dynamic>?;

    return {
      'type': 'video',
      'fileId': fileJson?['id'] as int?,
      'width': video['width'] as int?,
      'height': video['height'] as int?,
      'duration': video['duration'] as int?,
      'fileSize':
          fileJson?['size'] as int? ?? fileJson?['expected_size'] as int?,
      'mimeType': video['mime_type'] as String?,
      'caption': _sanitizeString(caption?['text'] as String? ?? ''),
      'localPath': _getLocalPath(fileJson),
      'isDownloaded': _isFileDownloaded(fileJson),
      'thumbnailFileId': thumbJson?['file']?['id'] as int?,
      'thumbnailPath': _getLocalPath(
        thumbJson?['file'] as Map<String, dynamic>?,
      ),
    };
  }

  Map<String, dynamic>? _extractVoiceNoteInfo(Map<String, dynamic> content) {
    final voiceNote = content['voice_note'] as Map<String, dynamic>?;
    if (voiceNote == null) return null;

    final fileJson = voiceNote['voice'] as Map<String, dynamic>?;

    return {
      'type': 'voiceNote',
      'fileId': fileJson?['id'] as int?,
      'duration': voiceNote['duration'] as int?,
      'fileSize':
          fileJson?['size'] as int? ?? fileJson?['expected_size'] as int?,
      'mimeType': voiceNote['mime_type'] as String?,
      'waveform': voiceNote['waveform'] as String?,
      'localPath': _getLocalPath(fileJson),
      'isDownloaded': _isFileDownloaded(fileJson),
    };
  }

  Map<String, dynamic>? _extractVideoNoteInfo(Map<String, dynamic> content) {
    final videoNote = content['video_note'] as Map<String, dynamic>?;
    if (videoNote == null) return null;

    final fileJson = videoNote['video'] as Map<String, dynamic>?;
    final thumbJson = videoNote['thumbnail'] as Map<String, dynamic>?;

    return {
      'type': 'videoNote',
      'fileId': fileJson?['id'] as int?,
      'duration': videoNote['duration'] as int?,
      'length': videoNote['length'] as int?,
      'fileSize':
          fileJson?['size'] as int? ?? fileJson?['expected_size'] as int?,
      'localPath': _getLocalPath(fileJson),
      'isDownloaded': _isFileDownloaded(fileJson),
      'thumbnailFileId': thumbJson?['file']?['id'] as int?,
      'thumbnailPath': _getLocalPath(
        thumbJson?['file'] as Map<String, dynamic>?,
      ),
    };
  }

  Map<String, dynamic>? _extractDocumentInfo(Map<String, dynamic> content) {
    final document = content['document'] as Map<String, dynamic>?;
    if (document == null) return null;

    final fileJson = document['document'] as Map<String, dynamic>?;
    final caption = content['caption'] as Map<String, dynamic>?;

    return {
      'type': 'document',
      'fileId': fileJson?['id'] as int?,
      'fileName': document['file_name'] as String?,
      'fileSize':
          fileJson?['size'] as int? ?? fileJson?['expected_size'] as int?,
      'mimeType': document['mime_type'] as String?,
      'caption': _sanitizeString(caption?['text'] as String? ?? ''),
      'localPath': _getLocalPath(fileJson),
      'isDownloaded': _isFileDownloaded(fileJson),
    };
  }

  Map<String, dynamic>? _extractStickerInfo(Map<String, dynamic> content) {
    final sticker = content['sticker'] as Map<String, dynamic>?;
    if (sticker == null) return null;

    final fileJson = sticker['sticker'] as Map<String, dynamic>?;

    return {
      'type': 'sticker',
      'fileId': fileJson?['id'] as int?,
      'width': sticker['width'] as int?,
      'height': sticker['height'] as int?,
      'emoji': _sanitizeString(sticker['emoji'] as String? ?? ''),
      'isAnimated': sticker['is_animated'] as bool? ?? false,
      'isVideo': sticker['is_video'] as bool? ?? false,
      'localPath': _getLocalPath(fileJson),
      'isDownloaded': _isFileDownloaded(fileJson),
    };
  }

  Map<String, dynamic>? _extractAnimationInfo(Map<String, dynamic> content) {
    final animation = content['animation'] as Map<String, dynamic>?;
    if (animation == null) return null;

    final fileJson = animation['animation'] as Map<String, dynamic>?;
    final thumbJson = animation['thumbnail'] as Map<String, dynamic>?;
    final caption = content['caption'] as Map<String, dynamic>?;

    return {
      'type': 'animation',
      'fileId': fileJson?['id'] as int?,
      'width': animation['width'] as int?,
      'height': animation['height'] as int?,
      'duration': animation['duration'] as int?,
      'fileSize':
          fileJson?['size'] as int? ?? fileJson?['expected_size'] as int?,
      'mimeType': animation['mime_type'] as String?,
      'caption': _sanitizeString(caption?['text'] as String? ?? ''),
      'localPath': _getLocalPath(fileJson),
      'isDownloaded': _isFileDownloaded(fileJson),
      'thumbnailFileId': thumbJson?['file']?['id'] as int?,
      'thumbnailPath': _getLocalPath(
        thumbJson?['file'] as Map<String, dynamic>?,
      ),
    };
  }

  Map<String, dynamic>? _extractAudioInfo(Map<String, dynamic> content) {
    final audio = content['audio'] as Map<String, dynamic>?;
    if (audio == null) return null;

    final fileJson = audio['audio'] as Map<String, dynamic>?;
    final caption = content['caption'] as Map<String, dynamic>?;

    return {
      'type': 'audio',
      'fileId': fileJson?['id'] as int?,
      'duration': audio['duration'] as int?,
      'title': _sanitizeString(audio['title'] as String? ?? ''),
      'performer': _sanitizeString(audio['performer'] as String? ?? ''),
      'fileName': audio['file_name'] as String?,
      'fileSize':
          fileJson?['size'] as int? ?? fileJson?['expected_size'] as int?,
      'mimeType': audio['mime_type'] as String?,
      'caption': _sanitizeString(caption?['text'] as String? ?? ''),
      'localPath': _getLocalPath(fileJson),
      'isDownloaded': _isFileDownloaded(fileJson),
    };
  }

  String? _getLocalPath(Map<String, dynamic>? fileJson) {
    if (fileJson == null) return null;
    final local = fileJson['local'] as Map<String, dynamic>?;
    if (local == null) return null;
    final isCompleted = local['is_downloading_completed'] as bool? ?? false;
    if (!isCompleted) return null;
    return local['path'] as String?;
  }

  bool _isFileDownloaded(Map<String, dynamic>? fileJson) {
    if (fileJson == null) return false;
    final local = fileJson['local'] as Map<String, dynamic>?;
    if (local == null) return false;
    return local['is_downloading_completed'] as bool? ?? false;
  }

  /// Get chat title (handles private chats with user names)
  String getChatTitle(int chatId) {
    final chat = _chatsCache[chatId];
    if (chat != null) return chat.title;

    final rawChat = _rawChatData[chatId];
    if (rawChat != null) {
      return rawChat['title'] as String? ?? 'Chat $chatId';
    }

    return 'Chat $chatId';
  }

  /// Get chat subtitle (online status for private, member count for groups)
  String getChatSubtitle(int chatId) {
    final chat = _chatsCache[chatId];
    if (chat == null) return '';

    final chatType = chat.type;
    if (chatType is ChatTypePrivate) {
      return getUserStatusText(chatType.userId);
    } else if (chatType is ChatTypeBasicGroup) {
      final group = _basicGroupsCache[chatType.basicGroupId];
      if (group != null) {
        return '${group.memberCount} members';
      }
    } else if (chatType is ChatTypeSupergroup) {
      final supergroup = _supergroupsCache[chatType.supergroupId];
      if (supergroup != null) {
        if (supergroup.isChannel) {
          return '${supergroup.memberCount} subscribers';
        }
        return '${supergroup.memberCount} members';
      }
    }
    return '';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHASE 3: SEARCH, MESSAGE ACTIONS, SETTINGS
  // ═══════════════════════════════════════════════════════════════════════════

  // Current user info
  Map<String, dynamic>? _currentUserInfo;
  Map<String, dynamic>? get currentUserInfo => _currentUserInfo;
  Map<String, dynamic>? get currentUser => _currentUserInfo;

  // Get all chats as a list
  List<TelegramChat> get chats {
    final chatsList = <TelegramChat>[];
    for (final entry in _chatsCache.entries) {
      chatsList.add(_convertToTelegramChat(entry.value));
    }
    // Also include raw chats
    for (final entry in _rawChatData.entries) {
      if (!_chatsCache.containsKey(entry.key)) {
        chatsList.add(_convertRawToTelegramChat(entry.key, entry.value, null));
      }
    }
    chatsList.sort((a, b) => b.lastMessageDate.compareTo(a.lastMessageDate));
    return chatsList;
  }

  /// Search for chats by query (simple version using SearchPublicChats)
  Future<void> searchChats(String query) async {
    if (_clientId == 0 || query.isEmpty) {
      return;
    }

    tdSend(_clientId, SearchChats(query: query, limit: 50));
  }

  /// Search messages in a specific chat (simple version)
  Future<void> searchMessagesInChat(
    int chatId,
    String query, {
    int limit = 50,
    int fromMessageId = 0,
  }) async {
    if (_clientId == 0) return;

    tdSend(
      _clientId,
      SearchChatMessages(
        chatId: chatId,
        query: query,
        senderId: null,
        fromMessageId: fromMessageId,
        offset: 0,
        limit: limit,
        filter: null,
        messageThreadId: 0,
      ),
    );
  }

  /// Delete messages
  Future<void> deleteMessages(
    int chatId,
    List<int> messageIds, {
    bool revokeForAll = false,
  }) async {
    if (_clientId == 0) return;

    tdSend(
      _clientId,
      DeleteMessages(
        chatId: chatId,
        messageIds: messageIds,
        revoke: revokeForAll,
      ),
    );

    // Remove from local cache
    _messagesCache[chatId]?.removeWhere((m) => messageIds.contains(m.id));
    _emitMessages(chatId);
  }

  /// Forward messages to another chat
  Future<void> forwardMessages(
    int fromChatId,
    int toChatId,
    List<int> messageIds, {
    bool sendCopy = false,
    bool removeCaption = false,
  }) async {
    if (_clientId == 0) return;

    tdSend(
      _clientId,
      ForwardMessages(
        chatId: toChatId,
        messageThreadId: 0,
        fromChatId: fromChatId,
        messageIds: messageIds,
        options: null,
        sendCopy: sendCopy,
        removeCaption: removeCaption,
        onlyPreview: false,
      ),
    );
  }

  /// Reply to a message
  Future<void> replyToMessage(
    int chatId,
    int replyToMessageId,
    String text,
  ) async {
    if (_clientId == 0 || text.trim().isEmpty) return;

    // Create a temporary message with "sending" status
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final tempMessage = TelegramMessage(
      id: tempId,
      chatId: chatId,
      text: text,
      time: _formatMessageTime(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      isOutgoing: true,
      senderId: _currentUserId ?? 0,
      status: MessageStatus.sending,
      date: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    // Add to cache immediately
    _messagesCache[chatId] ??= [];
    _messagesCache[chatId]!.insert(0, tempMessage);
    _emitMessages(chatId);

    // Note: Reply functionality requires InputMessageReplyTo which may not be available
    // in all TDLib versions. For now, we send a regular message.
    // TODO: Check TDLib version and use appropriate reply method
    tdSend(
      _clientId,
      SendMessage(
        chatId: chatId,
        messageThreadId: 0,
        options: null,
        replyMarkup: null,
        inputMessageContent: InputMessageText(
          text: FormattedText(text: text, entities: []),
          disableWebPagePreview: false,
          clearDraft: true,
        ),
      ),
    );
  }

  /// Edit a text message
  Future<void> editMessage(int chatId, int messageId, String newText) async {
    if (_clientId == 0 || newText.trim().isEmpty) return;

    tdSend(
      _clientId,
      EditMessageText(
        chatId: chatId,
        messageId: messageId,
        replyMarkup: null,
        inputMessageContent: InputMessageText(
          text: FormattedText(text: newText, entities: []),
          disableWebPagePreview: false,
          clearDraft: false,
        ),
      ),
    );
  }

  /// Copy message text to clipboard (handled in UI)
  String? getMessageText(int chatId, int messageId) {
    final messages = _messagesCache[chatId];
    if (messages == null) return null;

    final msg = messages.where((m) => m.id == messageId).firstOrNull;
    return msg?.text;
  }

  /// Get current user info
  Future<void> loadCurrentUser() async {
    if (_clientId == 0) return;
    tdSend(_clientId, const GetMe());
  }

  /// Update current user profile
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? bio,
  }) async {
    if (_clientId == 0) return;

    if (firstName != null || lastName != null) {
      tdSend(
        _clientId,
        SetName(firstName: firstName ?? '', lastName: lastName ?? ''),
      );
    }

    if (bio != null) {
      tdSend(_clientId, SetBio(bio: bio));
    }
  }

  /// Set profile photo
  Future<void> setProfilePhoto(String filePath) async {
    if (_clientId == 0) return;

    tdSend(
      _clientId,
      SetProfilePhoto(
        photo: InputChatPhotoStatic(photo: InputFileLocal(path: filePath)),
        isPublic: true,
      ),
    );
  }

  /// Log out from Telegram
  Future<void> logOut() async {
    if (_clientId == 0) return;
    tdSend(_clientId, const LogOut());
  }

  /// Delete account (dangerous!)
  Future<void> deleteAccount(String reason) async {
    if (_clientId == 0) return;
    tdSend(_clientId, DeleteAccount(reason: reason, password: ''));
  }

  // Storage statistics
  Map<String, dynamic>? _storageStatistics;
  Map<String, dynamic>? get storageStatistics => _storageStatistics;

  /// Get storage statistics
  Future<void> getStorageStatistics() async {
    if (_clientId == 0) return;
    tdSend(_clientId, const GetStorageStatistics(chatLimit: 100));
  }

  /// Clear storage
  Future<void> optimizeStorage({
    int? size,
    int? ttl,
    int? count,
    int? immunityDelay,
  }) async {
    if (_clientId == 0) return;
    tdSend(
      _clientId,
      OptimizeStorage(
        size: size ?? -1,
        ttl: ttl ?? -1,
        count: count ?? -1,
        immunityDelay: immunityDelay ?? -1,
        fileTypes: [],
        chatIds: [],
        excludeChatIds: [],
        returnDeletedFileStatistics: true,
        chatLimit: 100,
      ),
    );
  }

  // ─── Active Sessions Management ──────────────────────────────────────

  final _sessionsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get sessionsStream =>
      _sessionsController.stream;
  List<Map<String, dynamic>> _activeSessions = [];
  List<Map<String, dynamic>> get activeSessions => _activeSessions;

  /// Get all active sessions
  Future<void> getActiveSessions() async {
    if (_clientId == 0) return;
    tdSend(_clientId, const GetActiveSessions());
  }

  /// Terminate a specific session
  Future<void> terminateSession(int sessionId) async {
    if (_clientId == 0) return;
    tdSend(_clientId, TerminateSession(sessionId: sessionId));
    // Refresh sessions list after terminating
    Future.delayed(
      const Duration(milliseconds: 500),
      () => getActiveSessions(),
    );
  }

  /// Terminate all other sessions
  Future<void> terminateAllOtherSessions() async {
    if (_clientId == 0) return;
    tdSend(_clientId, const TerminateAllOtherSessions());
    Future.delayed(
      const Duration(milliseconds: 500),
      () => getActiveSessions(),
    );
  }

  // ─── Account TTL Management ─────────────────────────────────────────

  final _accountTtlController = StreamController<int>.broadcast();
  Stream<int> get accountTtlStream => _accountTtlController.stream;
  int _accountTtlDays = 365;
  int get accountTtlDays => _accountTtlDays;

  /// Get account self-destruct timer
  Future<void> getAccountTtl() async {
    if (_clientId == 0) return;
    tdSend(_clientId, const GetAccountTtl());
  }

  /// Set account self-destruct timer (in days)
  Future<void> setAccountTtl(int days) async {
    if (_clientId == 0) return;
    tdSend(_clientId, SetAccountTtl(ttl: AccountTtl(days: days)));
    _accountTtlDays = days;
    _accountTtlController.add(days);
  }

  // ─── Privacy Settings Management ────────────────────────────────────

  final _privacySettingsController =
      StreamController<Map<String, String>>.broadcast();
  Stream<Map<String, String>> get privacySettingsStream =>
      _privacySettingsController.stream;
  final Map<String, String> _privacySettings = {};
  Map<String, String> get privacySettings => Map.unmodifiable(_privacySettings);
  String? _pendingPrivacySetting;

  /// Get privacy setting rules for a specific setting
  Future<void> getPrivacySettingRules(String settingType) async {
    if (_clientId == 0) return;
    UserPrivacySetting setting;
    switch (settingType) {
      case 'phone':
        setting = const UserPrivacySettingShowPhoneNumber();
        break;
      case 'lastSeen':
        setting = const UserPrivacySettingShowStatus();
        break;
      case 'profilePhoto':
        setting = const UserPrivacySettingShowProfilePhoto();
        break;
      case 'forwards':
        setting = const UserPrivacySettingShowLinkInForwardedMessages();
        break;
      case 'calls':
        setting = const UserPrivacySettingAllowCalls();
        break;
      case 'groups':
        setting = const UserPrivacySettingAllowChatInvites();
        break;
      default:
        return;
    }
    _pendingPrivacySetting = settingType;
    tdSend(_clientId, GetUserPrivacySettingRules(setting: setting));
  }

  /// Set privacy setting rules
  Future<void> setPrivacySettingRules(
    String settingType,
    String ruleType,
  ) async {
    if (_clientId == 0) return;
    UserPrivacySetting setting;
    switch (settingType) {
      case 'phone':
        setting = const UserPrivacySettingShowPhoneNumber();
        break;
      case 'lastSeen':
        setting = const UserPrivacySettingShowStatus();
        break;
      case 'profilePhoto':
        setting = const UserPrivacySettingShowProfilePhoto();
        break;
      case 'forwards':
        setting = const UserPrivacySettingShowLinkInForwardedMessages();
        break;
      case 'calls':
        setting = const UserPrivacySettingAllowCalls();
        break;
      case 'groups':
        setting = const UserPrivacySettingAllowChatInvites();
        break;
      default:
        return;
    }

    UserPrivacySettingRule rule;
    switch (ruleType) {
      case 'everybody':
        rule = const UserPrivacySettingRuleAllowAll();
        break;
      case 'contacts':
        rule = const UserPrivacySettingRuleAllowContacts();
        break;
      case 'nobody':
        rule = const UserPrivacySettingRuleRestrictAll();
        break;
      default:
        return;
    }

    tdSend(
      _clientId,
      SetUserPrivacySettingRules(
        setting: setting,
        rules: UserPrivacySettingRules(rules: [rule]),
      ),
    );
    _privacySettings[settingType] = ruleType;
    _privacySettingsController.add(_privacySettings);
  }

  /// Load all privacy settings at once
  Future<void> loadAllPrivacySettings() async {
    for (final s in [
      'phone',
      'lastSeen',
      'profilePhoto',
      'forwards',
      'calls',
      'groups',
    ]) {
      getPrivacySettingRules(s);
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  // ─── Notification Management ────────────────────────────────────────

  // Notification settings streams
  final _notificationSettingsController =
      StreamController<Map<String, NotificationScopeSettings>>.broadcast();
  Stream<Map<String, NotificationScopeSettings>>
  get notificationSettingsStream => _notificationSettingsController.stream;

  // Cached notification settings per scope
  final Map<String, NotificationScopeSettings> _notificationSettings = {};

  // Pending scope for correlating response
  String? _pendingNotifScope;

  // Notification sounds
  final _notificationSoundsController =
      StreamController<List<NotificationSoundInfo>>.broadcast();
  Stream<List<NotificationSoundInfo>> get notificationSoundsStream =>
      _notificationSoundsController.stream;
  List<NotificationSoundInfo> _savedNotificationSounds = [];
  List<NotificationSoundInfo> get savedNotificationSounds =>
      _savedNotificationSounds;

  // Total unread count stream
  final _unreadCountController = StreamController<int>.broadcast();
  Stream<int> get unreadCountStream => _unreadCountController.stream;
  int _totalUnreadCount = 0;
  int get totalUnreadCount => _totalUnreadCount;

  /// Calculate total unread count from all chats
  int _computeTotalUnread() {
    int total = 0;
    for (final chat in _chatsCache.values) {
      total += chat.unreadCount;
    }
    for (final entry in _rawChatData.entries) {
      if (!_chatsCache.containsKey(entry.key)) {
        total += (entry.value['unread_count'] as int?) ?? 0;
      }
    }
    return total;
  }

  /// Update and emit total unread count
  void _updateUnreadCount() {
    _totalUnreadCount = _computeTotalUnread();
    _unreadCountController.add(_totalUnreadCount);
  }

  /// Get notification settings for a scope
  Future<NotificationScopeSettings?> getScopeNotificationSettings(
    String scope,
  ) async {
    if (_clientId == 0) return null;

    NotificationSettingsScope tdScope;
    switch (scope) {
      case 'private':
        tdScope = const NotificationSettingsScopePrivateChats();
        break;
      case 'group':
        tdScope = const NotificationSettingsScopeGroupChats();
        break;
      case 'channel':
        tdScope = const NotificationSettingsScopeChannelChats();
        break;
      default:
        return null;
    }

    _pendingNotifScope = scope;
    tdSend(_clientId, GetScopeNotificationSettings(scope: tdScope));
    return _notificationSettings[scope];
  }

  /// Load all notification settings
  Future<void> loadAllNotificationSettings() async {
    if (_clientId == 0) return;
    await getScopeNotificationSettings('private');
    await getScopeNotificationSettings('group');
    await getScopeNotificationSettings('channel');
  }

  /// Set notification settings for a scope
  Future<void> setScopeNotificationSettings({
    required String scope,
    required bool muted,
    bool showPreview = true,
    int soundId = 0,
    bool disablePinnedMessageNotifications = false,
    bool disableMentionNotifications = false,
    bool muteStories = false,
    int storySoundId = 0,
  }) async {
    if (_clientId == 0) return;

    NotificationSettingsScope tdScope;
    switch (scope) {
      case 'private':
        tdScope = const NotificationSettingsScopePrivateChats();
        break;
      case 'group':
        tdScope = const NotificationSettingsScopeGroupChats();
        break;
      case 'channel':
        tdScope = const NotificationSettingsScopeChannelChats();
        break;
      default:
        return;
    }

    tdSend(
      _clientId,
      SetScopeNotificationSettings(
        scope: tdScope,
        notificationSettings: ScopeNotificationSettings(
          muteFor: muted ? 2147483647 : 0,
          soundId: soundId,
          showPreview: showPreview,
          useDefaultMuteStories: false,
          muteStories: muteStories,
          storySoundId: storySoundId,
          showStorySender: true,
          disablePinnedMessageNotifications: disablePinnedMessageNotifications,
          disableMentionNotifications: disableMentionNotifications,
        ),
      ),
    );

    // Update local cache
    _notificationSettings[scope] = NotificationScopeSettings(
      scope: scope,
      isMuted: muted,
      showPreview: showPreview,
      soundId: soundId,
      disablePinnedMessageNotifications: disablePinnedMessageNotifications,
      disableMentionNotifications: disableMentionNotifications,
      muteStories: muteStories,
      storySoundId: storySoundId,
    );
    _notificationSettingsController.add(_notificationSettings);
  }

  /// Set chat-specific notification settings with full control
  Future<void> setChatNotificationSettings({
    required int chatId,
    bool? muted,
    bool? showPreview,
    int? soundId,
    bool? disablePinnedMessageNotifications,
    bool? disableMentionNotifications,
    bool? muteStories,
    int? storySoundId,
  }) async {
    if (_clientId == 0) return;

    tdSend(
      _clientId,
      SetChatNotificationSettings(
        chatId: chatId,
        notificationSettings: ChatNotificationSettings(
          useDefaultMuteFor: muted == null,
          muteFor: muted == true ? 2147483647 : 0,
          useDefaultSound: soundId == null,
          soundId: soundId ?? 0,
          useDefaultShowPreview: showPreview == null,
          showPreview: showPreview ?? true,
          useDefaultMuteStories: muteStories == null,
          muteStories: muteStories ?? false,
          useDefaultStorySound: storySoundId == null,
          storySoundId: storySoundId ?? 0,
          useDefaultShowStorySender: true,
          showStorySender: true,
          useDefaultDisablePinnedMessageNotifications:
              disablePinnedMessageNotifications == null,
          disablePinnedMessageNotifications:
              disablePinnedMessageNotifications ?? false,
          useDefaultDisableMentionNotifications:
              disableMentionNotifications == null,
          disableMentionNotifications: disableMentionNotifications ?? false,
        ),
      ),
    );
  }

  /// Reset a chat to use default notification settings
  Future<void> resetChatNotificationSettings(int chatId) async {
    if (_clientId == 0) return;

    tdSend(
      _clientId,
      SetChatNotificationSettings(
        chatId: chatId,
        notificationSettings: const ChatNotificationSettings(
          useDefaultMuteFor: true,
          muteFor: 0,
          useDefaultSound: true,
          soundId: 0,
          useDefaultShowPreview: true,
          showPreview: true,
          useDefaultMuteStories: true,
          muteStories: false,
          useDefaultStorySound: true,
          storySoundId: 0,
          useDefaultShowStorySender: true,
          showStorySender: true,
          useDefaultDisablePinnedMessageNotifications: true,
          disablePinnedMessageNotifications: false,
          useDefaultDisableMentionNotifications: true,
          disableMentionNotifications: false,
        ),
      ),
    );
  }

  /// Get available notification sounds
  Future<void> getNotificationSounds() async {
    if (_clientId == 0) return;
    tdSend(_clientId, const GetSavedNotificationSounds());
  }

  /// Mark all chats as read
  Future<void> markAllChatsAsRead() async {
    if (_clientId == 0) return;
    // Individually mark each chat with unread as read
    for (final chat in _chatsCache.values) {
      if (chat.unreadCount > 0) {
        markChatAsRead(chat.id);
      }
    }
  }

  /// Pin/unpin a chat
  Future<void> toggleChatPinned(int chatId, bool isPinned) async {
    if (_clientId == 0) return;

    tdSend(
      _clientId,
      ToggleChatIsPinned(
        chatList: const ChatListMain(),
        chatId: chatId,
        isPinned: isPinned,
      ),
    );
  }

  /// Mute/unmute a chat
  Future<void> setChatMuted(int chatId, bool isMuted) async {
    if (_clientId == 0) return;

    tdSend(
      _clientId,
      SetChatNotificationSettings(
        chatId: chatId,
        notificationSettings: ChatNotificationSettings(
          useDefaultMuteFor: !isMuted,
          muteFor: isMuted ? 2147483647 : 0,
          useDefaultSound: true,
          soundId: 0,
          useDefaultShowPreview: true,
          showPreview: true,
          useDefaultMuteStories: true,
          muteStories: false,
          useDefaultStorySound: true,
          storySoundId: 0,
          useDefaultShowStorySender: true,
          showStorySender: true,
          useDefaultDisablePinnedMessageNotifications: true,
          disablePinnedMessageNotifications: false,
          useDefaultDisableMentionNotifications: true,
          disableMentionNotifications: false,
        ),
      ),
    );
  }

  /// Archive/unarchive a chat
  Future<void> archiveChat(int chatId, bool archive) async {
    if (_clientId == 0) return;

    tdSend(
      _clientId,
      AddChatToList(
        chatId: chatId,
        chatList: archive ? const ChatListArchive() : const ChatListMain(),
      ),
    );
  }

  /// Delete a chat (leave and delete history)
  Future<void> deleteChat(int chatId) async {
    if (_clientId == 0) return;

    // First leave the chat
    tdSend(_clientId, LeaveChat(chatId: chatId));

    // Then delete the chat history
    tdSend(
      _clientId,
      DeleteChatHistory(
        chatId: chatId,
        removeFromChatList: true,
        revoke: false,
      ),
    );

    // Remove from local cache
    _chatsCache.remove(chatId);
    _rawChatData.remove(chatId);
    _messagesCache.remove(chatId);
    _emitChats();
  }

  /// Block/unblock a user
  Future<void> toggleBlockUser(int userId, bool block) async {
    if (_clientId == 0) return;

    tdSend(
      _clientId,
      ToggleMessageSenderIsBlocked(
        senderId: MessageSenderUser(userId: userId),
        isBlocked: block,
      ),
    );
  }

  /// Get blocked users list
  Future<List<Map<String, dynamic>>> getBlockedUsers({
    int offset = 0,
    int limit = 50,
  }) async {
    if (_clientId == 0) return [];
    tdSend(_clientId, GetBlockedMessageSenders(offset: offset, limit: limit));
    // Wait for response
    await Future.delayed(const Duration(milliseconds: 500));
    return _blockedUsers;
  }

  final List<Map<String, dynamic>> _blockedUsers = [];

  /// Import phone contacts to Telegram
  Future<void> importContacts(List<Map<String, String>> phoneContacts) async {
    if (_clientId == 0) return;
    final contacts = phoneContacts
        .map(
          (c) => Contact(
            phoneNumber: c['phone'] ?? '',
            firstName: c['firstName'] ?? '',
            lastName: c['lastName'] ?? '',
            vcard: '',
            userId: 0,
          ),
        )
        .toList();

    tdSend(_clientId, ImportContacts(contacts: contacts));
    // Reload contacts after import
    await Future.delayed(const Duration(milliseconds: 500));
    await loadContacts();
  }

  /// Add a single contact
  Future<void> addContact({
    required String phoneNumber,
    required String firstName,
    String lastName = '',
  }) async {
    if (_clientId == 0) return;
    tdSend(
      _clientId,
      AddContact(
        contact: Contact(
          phoneNumber: phoneNumber,
          firstName: firstName,
          lastName: lastName,
          vcard: '',
          userId: 0,
        ),
        sharePhoneNumber: false,
      ),
    );
    await Future.delayed(const Duration(milliseconds: 500));
    await loadContacts();
  }

  /// Remove a contact
  Future<void> removeContact(int userId) async {
    if (_clientId == 0) return;
    tdSend(_clientId, RemoveContacts(userIds: [userId]));
    await Future.delayed(const Duration(milliseconds: 300));
    await loadContacts();
  }

  /// Get user's full info (bio, etc.) - synchronous from cache
  Map<String, dynamic>? getUserFullInfo(int userId) {
    return _userFullInfoCache[userId];
  }

  /// Set username
  Future<void> setUsername(String username) async {
    if (_clientId == 0) return;
    tdSend(_clientId, SetUsername(username: username));
  }

  /// Set phone number (for changing phone)
  Future<void> changePhoneNumber(String newPhoneNumber) async {
    if (_clientId == 0) return;
    tdSend(
      _clientId,
      SetAuthenticationPhoneNumber(
        phoneNumber: newPhoneNumber,
        settings: const PhoneNumberAuthenticationSettings(
          allowFlashCall: false,
          allowMissedCall: false,
          isCurrentPhoneNumber: false,
          allowSmsRetrieverApi: false,
          authenticationTokens: [],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2FA (Two-Step Verification) MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stream for 2FA state
  final _passwordStateController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get passwordStateStream =>
      _passwordStateController.stream;
  Map<String, dynamic>? _passwordState;
  Map<String, dynamic>? get passwordState => _passwordState;

  /// Get current 2FA password state
  Future<void> getPasswordState() async {
    if (_clientId == 0) return;
    tdSend(_clientId, const GetPasswordState());
  }

  /// Set a new 2FA password
  Future<void> setPassword({
    required String newPassword,
    String? newHint,
    String? newRecoveryEmail,
    String oldPassword = '',
  }) async {
    if (_clientId == 0) return;
    tdSend(
      _clientId,
      SetPassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
        newHint: newHint ?? '',
        setRecoveryEmailAddress: newRecoveryEmail != null,
        newRecoveryEmailAddress: newRecoveryEmail ?? '',
      ),
    );
  }

  /// Remove 2FA password
  Future<void> removePassword(String currentPassword) async {
    if (_clientId == 0) return;
    tdSend(
      _clientId,
      SetPassword(
        oldPassword: currentPassword,
        newPassword: '',
        newHint: '',
        setRecoveryEmailAddress: false,
        newRecoveryEmailAddress: '',
      ),
    );
  }

  /// Set recovery email for 2FA
  Future<void> setRecoveryEmail(String password, String email) async {
    if (_clientId == 0) return;
    tdSend(
      _clientId,
      SetRecoveryEmailAddress(
        password: password,
        newRecoveryEmailAddress: email,
      ),
    );
  }

  /// Get user photo path from cache
  String? getUserPhotoPath(int userId) {
    final user = _usersCache[userId];
    if (user?.profilePhoto == null) return null;
    final photo = user!.profilePhoto!;
    if (photo.small.local.isDownloadingCompleted) {
      return photo.small.local.path;
    }
    // Start download if needed
    if (!photo.small.local.isDownloadingActive) {
      _downloadFile(photo.small.id);
    }
    return null;
  }

  /// Get reply info for a message (for display purposes)
  TelegramMessage? getReplyMessage(int chatId, int replyToMessageId) {
    final messages = _messagesCache[chatId];
    if (messages == null) return null;
    return messages.where((m) => m.id == replyToMessageId).firstOrNull;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHAT MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create a private chat with a user - returns immediately after sending request
  Future<void> createPrivateChat(int userId) async {
    if (_clientId == 0) return;

    tdSend(_clientId, CreatePrivateChat(userId: userId, force: false));

    // Wait a moment for the chat to be created and added to cache
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Create a new basic group with users
  Future<void> createBasicGroup({
    required String title,
    required List<int> userIds,
    int messageAutoDeleteTime = 0,
  }) async {
    if (_clientId == 0) return;

    tdSend(
      _clientId,
      CreateNewBasicGroupChat(
        userIds: userIds,
        title: title,
        messageAutoDeleteTime: messageAutoDeleteTime,
      ),
    );

    // Wait a moment for the chat to be created
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Create a new supergroup or channel
  Future<void> createSupergroup({
    required String title,
    String description = '',
    bool isChannel = false,
    bool isForum = false,
    int messageAutoDeleteTime = 0,
  }) async {
    if (_clientId == 0) return;

    tdSend(
      _clientId,
      CreateNewSupergroupChat(
        title: title,
        isForum: isForum,
        isChannel: isChannel,
        description: description,
        location: null,
        messageAutoDeleteTime: messageAutoDeleteTime,
        forImport: false,
      ),
    );

    // Wait a moment for the chat to be created
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Add members to a chat
  Future<void> addChatMembers(int chatId, List<int> userIds) async {
    if (_clientId == 0) return;

    for (final userId in userIds) {
      tdSend(
        _clientId,
        AddChatMember(chatId: chatId, userId: userId, forwardLimit: 100),
      );
    }
  }

  /// Get chat member count
  Future<int> getChatMemberCount(int chatId) async {
    final chat = _chatsCache[chatId];
    if (chat == null) return 0;

    final chatType = chat.type;
    if (chatType is ChatTypeBasicGroup) {
      final group = _basicGroupsCache[chatType.basicGroupId];
      return group?.memberCount ?? 0;
    } else if (chatType is ChatTypeSupergroup) {
      final supergroup = _supergroupsCache[chatType.supergroupId];
      return supergroup?.memberCount ?? 0;
    }
    return chatType is ChatTypePrivate ? 2 : 0;
  }

  /// Set chat title
  Future<void> setChatTitle(int chatId, String title) async {
    if (_clientId == 0) return;
    tdSend(_clientId, SetChatTitle(chatId: chatId, title: title));
  }

  /// Set chat description (for supergroups/channels)
  Future<void> setChatDescription(int chatId, String description) async {
    if (_clientId == 0) return;
    tdSend(
      _clientId,
      SetChatDescription(chatId: chatId, description: description),
    );
  }

  /// Leave a chat without deleting history
  Future<void> leaveChat(int chatId) async {
    if (_clientId == 0) return;
    tdSend(_clientId, LeaveChat(chatId: chatId));
    _chatsCache.remove(chatId);
    _rawChatData.remove(chatId);
    _emitChats();
  }

  /// Delete chat history
  Future<void> deleteChatHistory(
    int chatId, {
    bool removeFromChatList = false,
    bool revoke = false,
  }) async {
    if (_clientId == 0) return;
    tdSend(
      _clientId,
      DeleteChatHistory(
        chatId: chatId,
        removeFromChatList: removeFromChatList,
        revoke: revoke,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHAT FOLDERS (FILTERS)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Cache for chat folders
  final List<TelegramChatFolder> _chatFolders = [];
  List<TelegramChatFolder> get chatFolders => List.unmodifiable(_chatFolders);

  /// Stream for chat folder updates
  final _chatFoldersController =
      StreamController<List<TelegramChatFolder>>.broadcast();
  Stream<List<TelegramChatFolder>> get chatFoldersStream =>
      _chatFoldersController.stream;

  /// Load chat folders - folders are received automatically via UpdateChatFolders
  /// This method just emits the current folders from cache
  Future<void> loadChatFolders() async {
    // Chat folders are sent automatically on connection
    // Just emit the current cached folders
    _chatFoldersController.add(_chatFolders);
  }

  /// Create a new chat folder
  Future<void> createChatFolder({
    required String title,
    String? iconName,
    List<int>? includedChatIds,
    List<int>? pinnedChatIds,
    List<int>? excludedChatIds,
    bool includeContacts = false,
    bool includeNonContacts = false,
    bool includeGroups = false,
    bool includeChannels = false,
    bool includeBots = false,
    bool excludeMuted = false,
    bool excludeRead = false,
    bool excludeArchived = false,
  }) async {
    if (_clientId == 0) return;

    final folder = ChatFolder(
      title: title,
      icon: iconName != null ? ChatFolderIcon(name: iconName) : null,
      isShareable: false,
      pinnedChatIds: pinnedChatIds ?? [],
      includedChatIds: includedChatIds ?? [],
      excludedChatIds: excludedChatIds ?? [],
      excludeMuted: excludeMuted,
      excludeRead: excludeRead,
      excludeArchived: excludeArchived,
      includeContacts: includeContacts,
      includeNonContacts: includeNonContacts,
      includeBots: includeBots,
      includeGroups: includeGroups,
      includeChannels: includeChannels,
    );

    tdSend(_clientId, CreateChatFolder(folder: folder));

    // Wait for folder to be created then reload
    await Future.delayed(const Duration(milliseconds: 500));
    loadChatFolders();
  }

  /// Edit an existing chat folder
  Future<void> editChatFolder(
    int folderId, {
    String? title,
    String? iconName,
    List<int>? includedChatIds,
    List<int>? pinnedChatIds,
    List<int>? excludedChatIds,
    bool? includeContacts,
    bool? includeNonContacts,
    bool? includeGroups,
    bool? includeChannels,
    bool? includeBots,
    bool? excludeMuted,
    bool? excludeRead,
    bool? excludeArchived,
  }) async {
    if (_clientId == 0) return;

    // Get existing folder first
    final existing = _chatFolders.firstWhere(
      (f) => f.id == folderId,
      orElse: () => throw Exception('Folder not found'),
    );

    final folder = ChatFolder(
      title: title ?? existing.title,
      icon: iconName != null
          ? ChatFolderIcon(name: iconName)
          : (existing.iconName != null
                ? ChatFolderIcon(name: existing.iconName!)
                : null),
      isShareable: false,
      pinnedChatIds: pinnedChatIds ?? existing.pinnedChatIds,
      includedChatIds: includedChatIds ?? existing.includedChatIds,
      excludedChatIds: excludedChatIds ?? existing.excludedChatIds,
      excludeMuted: excludeMuted ?? existing.excludeMuted,
      excludeRead: excludeRead ?? existing.excludeRead,
      excludeArchived: excludeArchived ?? existing.excludeArchived,
      includeContacts: includeContacts ?? existing.includeContacts,
      includeNonContacts: includeNonContacts ?? existing.includeNonContacts,
      includeBots: includeBots ?? existing.includeBots,
      includeGroups: includeGroups ?? existing.includeGroups,
      includeChannels: includeChannels ?? existing.includeChannels,
    );

    tdSend(_clientId, EditChatFolder(chatFolderId: folderId, folder: folder));

    // Reload folders after edit
    Future.delayed(const Duration(milliseconds: 500), loadChatFolders);
  }

  /// Delete a chat folder
  Future<void> deleteChatFolder(int folderId, {List<int>? leaveChatIds}) async {
    if (_clientId == 0) return;

    tdSend(
      _clientId,
      DeleteChatFolder(
        chatFolderId: folderId,
        leaveChatIds: leaveChatIds ?? [],
      ),
    );

    _chatFolders.removeWhere((f) => f.id == folderId);
    _chatFoldersController.add(_chatFolders);
  }

  /// Add a chat to a folder
  Future<void> addChatToFolder(int chatId, int folderId) async {
    final folder = _chatFolders.firstWhere(
      (f) => f.id == folderId,
      orElse: () => throw Exception('Folder not found'),
    );

    final newIncludedChatIds = [...folder.includedChatIds, chatId];
    await editChatFolder(folderId, includedChatIds: newIncludedChatIds);
  }

  /// Remove a chat from a folder
  Future<void> removeChatFromFolder(int chatId, int folderId) async {
    final folder = _chatFolders.firstWhere(
      (f) => f.id == folderId,
      orElse: () => throw Exception('Folder not found'),
    );

    final newIncludedChatIds = folder.includedChatIds
        .where((id) => id != chatId)
        .toList();
    await editChatFolder(folderId, includedChatIds: newIncludedChatIds);
  }

  /// Get chats for a specific folder
  Future<void> loadChatsForFolder(int folderId) async {
    if (_clientId == 0) return;
    tdSend(
      _clientId,
      LoadChats(chatList: ChatListFolder(chatFolderId: folderId), limit: 100),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ARCHIVE MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Cache for archived chats
  final Map<int, Chat> _archivedChatsCache = {};
  final Map<int, Map<String, dynamic>> _rawArchivedChatData = {};
  List<int> _archivedChatIds = [];

  /// Stream for archived chats
  final _archivedChatsController =
      StreamController<List<TelegramChat>>.broadcast();
  Stream<List<TelegramChat>> get archivedChatsStream =>
      _archivedChatsController.stream;

  /// Get archived chats list
  List<TelegramChat> get archivedChats {
    return _archivedChatIds
        .map((chatId) {
          final chat = _archivedChatsCache[chatId];
          if (chat == null) return null;
          // Convert Chat to TelegramChat - simplified version
          final title = chat.title;
          String? photoUrl;
          if (chat.photo != null &&
              chat.photo!.small.local.isDownloadingCompleted) {
            photoUrl = chat.photo!.small.local.path;
          }
          final lastMessageContent = chat.lastMessage?.content;
          String lastMessageText = '';
          if (lastMessageContent is MessageText) {
            lastMessageText = lastMessageContent.text.text;
          }
          final date = chat.lastMessage?.date ?? 0;
          final time = date > 0 ? _formatMessageTime(date) : '';
          return TelegramChat(
            id: chat.id,
            title: title,
            photoUrl: photoUrl,
            lastMessage: lastMessageText,
            lastMessageTime: time,
            unreadCount: chat.unreadCount,
            isRead: chat.unreadCount == 0,
            isSentByMe: chat.lastMessage?.isOutgoing ?? false,
            lastMessageDate: date,
            order: 0,
          );
        })
        .whereType<TelegramChat>()
        .toList();
  }

  /// Load archived chats
  Future<void> loadArchivedChats({int limit = 50}) async {
    if (_clientId == 0) return;
    tdSend(
      _clientId,
      LoadChats(chatList: const ChatListArchive(), limit: limit),
    );
  }

  /// Archive settings
  bool _hideArchivedChats = false;
  bool get hideArchivedChats => _hideArchivedChats;

  /// Set archive chat list settings
  Future<void> setArchiveAndMuteNewChats(bool archiveAndMute) async {
    if (_clientId == 0) return;
    tdSend(
      _clientId,
      SetArchiveChatListSettings(
        settings: ArchiveChatListSettings(
          archiveAndMuteNewChatsFromUnknownUsers: archiveAndMute,
          keepUnmutedChatsArchived: false,
          keepChatsFromFoldersArchived: false,
        ),
      ),
    );
  }

  /// Toggle hide archived chats setting (local only)
  void setHideArchivedChats(bool hide) {
    _hideArchivedChats = hide;
    _archivedChatsController.add(archivedChats);
  }

  void _emitArchivedChats() {
    _archivedChatsController.add(archivedChats);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUPERGROUP MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get supergroup full info - sends request only, response handled via updates
  Future<void> requestSupergroupFullInfo(int supergroupId) async {
    if (_clientId == 0) return;
    tdSend(_clientId, GetSupergroupFullInfo(supergroupId: supergroupId));
  }

  /// Get supergroup members - sends request only
  Future<void> requestSupergroupMembers(
    int supergroupId, {
    int offset = 0,
    int limit = 200,
  }) async {
    if (_clientId == 0) return;

    tdSend(
      _clientId,
      GetSupergroupMembers(
        supergroupId: supergroupId,
        filter: const SupergroupMembersFilterRecent(),
        offset: offset,
        limit: limit,
      ),
    );
  }

  /// Set supergroup username
  Future<void> setSupergroupUsername(int supergroupId, String username) async {
    if (_clientId == 0) return;
    tdSend(
      _clientId,
      SetSupergroupUsername(supergroupId: supergroupId, username: username),
    );
  }

  /// Toggle supergroup sign messages
  Future<void> toggleSupergroupSignMessages(
    int supergroupId,
    bool signMessages,
  ) async {
    if (_clientId == 0) return;
    tdSend(
      _clientId,
      ToggleSupergroupSignMessages(
        supergroupId: supergroupId,
        signMessages: signMessages,
      ),
    );
  }

  /// Toggle supergroup join to send messages
  Future<void> toggleSupergroupJoinToSendMessages(
    int supergroupId,
    bool joinToSendMessages,
  ) async {
    if (_clientId == 0) return;
    tdSend(
      _clientId,
      ToggleSupergroupJoinToSendMessages(
        supergroupId: supergroupId,
        joinToSendMessages: joinToSendMessages,
      ),
    );
  }

  /// Toggle supergroup join by request
  Future<void> toggleSupergroupJoinByRequest(
    int supergroupId,
    bool joinByRequest,
  ) async {
    if (_clientId == 0) return;
    tdSend(
      _clientId,
      ToggleSupergroupJoinByRequest(
        supergroupId: supergroupId,
        joinByRequest: joinByRequest,
      ),
    );
  }

  /// Toggle supergroup is all history available
  Future<void> toggleSupergroupIsAllHistoryAvailable(
    int supergroupId,
    bool isAllHistoryAvailable,
  ) async {
    if (_clientId == 0) return;
    tdSend(
      _clientId,
      ToggleSupergroupIsAllHistoryAvailable(
        supergroupId: supergroupId,
        isAllHistoryAvailable: isAllHistoryAvailable,
      ),
    );
  }

  /// Set supergroup sticker set
  Future<void> setSupergroupStickerSet(
    int supergroupId,
    int stickerSetId,
  ) async {
    if (_clientId == 0) return;
    tdSend(
      _clientId,
      SetSupergroupStickerSet(
        supergroupId: supergroupId,
        stickerSetId: stickerSetId,
      ),
    );
  }

  /// Promote/demote a member in supergroup
  Future<void> setSupergroupMemberStatus(
    int supergroupId,
    int userId, {
    bool canManageChat = false,
    bool canChangeInfo = false,
    bool canPostMessages = false,
    bool canEditMessages = false,
    bool canDeleteMessages = false,
    bool canInviteUsers = false,
    bool canRestrictMembers = false,
    bool canPinMessages = false,
    bool canPromoteMembers = false,
    bool canManageVideoChats = false,
    bool isAnonymous = false,
  }) async {
    if (_clientId == 0) return;

    final chat = _chatsCache.values.firstWhere(
      (c) =>
          c.type is ChatTypeSupergroup &&
          (c.type as ChatTypeSupergroup).supergroupId == supergroupId,
      orElse: () => throw Exception('Chat not found'),
    );

    tdSend(
      _clientId,
      SetChatMemberStatus(
        chatId: chat.id,
        memberId: MessageSenderUser(userId: userId),
        status: ChatMemberStatusAdministrator(
          customTitle: '',
          canBeEdited: true,
          rights: ChatAdministratorRights(
            canManageChat: canManageChat,
            canChangeInfo: canChangeInfo,
            canPostMessages: canPostMessages,
            canEditMessages: canEditMessages,
            canDeleteMessages: canDeleteMessages,
            canInviteUsers: canInviteUsers,
            canRestrictMembers: canRestrictMembers,
            canPinMessages: canPinMessages,
            canManageTopics: false,
            canPromoteMembers: canPromoteMembers,
            canManageVideoChats: canManageVideoChats,
            isAnonymous: isAnonymous,
          ),
        ),
      ),
    );
  }

  /// Ban a member from supergroup
  Future<void> banSupergroupMember(
    int supergroupId,
    int userId, {
    int bannedUntilDate = 0, // 0 = forever
  }) async {
    if (_clientId == 0) return;

    final chat = _chatsCache.values.firstWhere(
      (c) =>
          c.type is ChatTypeSupergroup &&
          (c.type as ChatTypeSupergroup).supergroupId == supergroupId,
      orElse: () => throw Exception('Chat not found'),
    );

    tdSend(
      _clientId,
      SetChatMemberStatus(
        chatId: chat.id,
        memberId: MessageSenderUser(userId: userId),
        status: ChatMemberStatusBanned(bannedUntilDate: bannedUntilDate),
      ),
    );
  }

  /// Unban a member from supergroup
  Future<void> unbanSupergroupMember(int supergroupId, int userId) async {
    if (_clientId == 0) return;

    final chat = _chatsCache.values.firstWhere(
      (c) =>
          c.type is ChatTypeSupergroup &&
          (c.type as ChatTypeSupergroup).supergroupId == supergroupId,
      orElse: () => throw Exception('Chat not found'),
    );

    tdSend(
      _clientId,
      SetChatMemberStatus(
        chatId: chat.id,
        memberId: MessageSenderUser(userId: userId),
        status: const ChatMemberStatusMember(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTACTS / USERS SEARCH
  // ═══════════════════════════════════════════════════════════════════════════

  /// Cached contacts
  final List<TelegramContact> _contacts = [];
  List<TelegramContact> get contacts => List.unmodifiable(_contacts);

  /// Stream for contacts
  final _contactsController =
      StreamController<List<TelegramContact>>.broadcast();
  Stream<List<TelegramContact>> get contactsStream =>
      _contactsController.stream;

  /// Load contacts
  Future<void> loadContacts() async {
    if (_clientId == 0) return;
    tdSend(_clientId, const GetContacts());
  }

  /// Search users by username or phone - returns cached results that match
  List<TelegramChat> searchPublicChats(String query) {
    if (query.isEmpty) return [];

    // Search in cached chats
    final q = query.toLowerCase();
    return chats.where((chat) {
      return chat.title.toLowerCase().contains(q);
    }).toList();
  }

  /// Search contacts in cache
  List<TelegramContact> searchContacts(String query, {int limit = 50}) {
    if (query.isEmpty) return _contacts.take(limit).toList();

    final q = query.toLowerCase();
    return _contacts
        .where((contact) {
          return contact.fullName.toLowerCase().contains(q) ||
              (contact.phone?.contains(q) ?? false) ||
              (contact.username?.toLowerCase().contains(q) ?? false);
        })
        .take(limit)
        .toList();
  }

  /// Request search from server (results come via updates)
  void requestSearchPublicChats(String query) {
    if (_clientId == 0 || query.isEmpty) return;
    tdSend(_clientId, SearchPublicChats(query: query));
  }

  /// Request contact search from server
  void requestSearchContacts(String query, {int limit = 50}) {
    if (_clientId == 0) return;
    tdSend(_clientId, SearchContacts(query: query, limit: limit));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEARCH FUNCTIONALITY
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stream for message search results
  final _searchResultsController = StreamController<SearchResults>.broadcast();
  Stream<SearchResults> get searchResultsStream =>
      _searchResultsController.stream;

  /// Stream for chat search results (separate from message search)
  final _chatSearchResultsController =
      StreamController<List<TelegramChat>>.broadcast();
  Stream<List<TelegramChat>> get chatSearchResultsStream =>
      _chatSearchResultsController.stream;

  /// Current search results cache
  SearchResults? _lastSearchResults;
  SearchResults? get lastSearchResults => _lastSearchResults;

  /// Search chats locally (in cache)
  List<TelegramChat> searchChatsLocal(String query) {
    if (query.isEmpty) return [];
    final q = query.toLowerCase();
    return chats.where((chat) {
      return chat.title.toLowerCase().contains(q) ||
          chat.lastMessage.toLowerCase().contains(q);
    }).toList();
  }

  /// Search messages globally across all chats
  Future<void> searchMessages({
    required String query,
    int limit = 50,
    String offset = '',
    SearchMessagesFilter? filter,
    int? minDate,
    int? maxDate,
  }) async {
    if (_clientId == 0 || query.isEmpty) return;

    _debugPrint('Searching messages: "$query" (limit: $limit)');

    tdSend(
      _clientId,
      SearchMessages(
        chatList: const ChatListMain(),
        query: query,
        offset: offset,
        limit: limit,
        filter: filter,
        minDate: minDate ?? 0,
        maxDate: maxDate ?? 0,
      ),
    );
  }

  /// Search messages within a specific chat
  Future<void> searchChatMessages({
    required int chatId,
    required String query,
    int limit = 50,
    int fromMessageId = 0,
    int senderId = 0,
    SearchMessagesFilter? filter,
  }) async {
    if (_clientId == 0 || query.isEmpty) return;

    _debugPrint('Searching in chat $chatId: "$query"');

    tdSend(
      _clientId,
      SearchChatMessages(
        chatId: chatId,
        query: query,
        senderId: senderId != 0 ? MessageSenderUser(userId: senderId) : null,
        fromMessageId: fromMessageId,
        offset: 0,
        limit: limit,
        filter: filter,
        messageThreadId: 0,
      ),
    );
  }

  /// Search messages by date range
  Future<void> searchMessagesByDate({
    required String query,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 50,
    SearchMessagesFilter? filter,
  }) async {
    final minDate = startDate.millisecondsSinceEpoch ~/ 1000;
    final maxDate = endDate.millisecondsSinceEpoch ~/ 1000;

    await searchMessages(
      query: query,
      limit: limit,
      minDate: minDate,
      maxDate: maxDate,
      filter: filter,
    );
  }

  /// Get messages on a specific date in a chat
  Future<void> getChatMessagesByDate({
    required int chatId,
    required DateTime date,
  }) async {
    if (_clientId == 0) return;

    final timestamp = date.millisecondsSinceEpoch ~/ 1000;
    _debugPrint('Getting messages for chat $chatId on date: $date');

    tdSend(_clientId, GetChatMessageByDate(chatId: chatId, date: timestamp));
  }

  /// Search hashtags globally
  Future<void> searchHashtag(String hashtag, {int limit = 50}) async {
    final query = hashtag.startsWith('#') ? hashtag : '#$hashtag';
    await searchMessages(query: query, limit: limit);
  }

  /// Handle search messages response
  void _handleSearchMessagesResult(FoundMessages result) {
    final messages = <SearchResultMessage>[];

    for (final msg in result.messages) {
      final converted = _convertMessageToSearchResult(msg);
      if (converted != null) {
        messages.add(converted);
      }
    }

    _lastSearchResults = SearchResults(
      messages: messages,
      totalCount: result.totalCount,
      nextOffset: result.nextOffset,
    );

    _searchResultsController.add(_lastSearchResults!);
    _debugPrint(
      'Search returned ${messages.length} messages (total: ${result.totalCount})',
    );
  }

  /// Handle chat messages search response
  void _handleChatMessagesSearchResult(int chatId, FoundChatMessages result) {
    final messages = <SearchResultMessage>[];

    for (final msg in result.messages) {
      final converted = _convertMessageToSearchResult(msg);
      if (converted != null) {
        messages.add(converted);
      }
    }

    _lastSearchResults = SearchResults(
      messages: messages,
      totalCount: result.totalCount,
      nextFromMessageId: result.nextFromMessageId,
      chatId: chatId,
    );

    _searchResultsController.add(_lastSearchResults!);
    _debugPrint(
      'Chat search returned ${messages.length} messages in chat $chatId',
    );
  }

  /// Convert TDLib message to search result
  SearchResultMessage? _convertMessageToSearchResult(Message msg) {
    try {
      final content = msg.content;
      String text = '';
      String contentType = 'unknown';

      if (content is MessageText) {
        text = content.text.text;
        contentType = 'text';
      } else if (content is MessagePhoto) {
        text = content.caption.text.isNotEmpty
            ? content.caption.text
            : '📷 Photo';
        contentType = 'photo';
      } else if (content is MessageVideo) {
        text = content.caption.text.isNotEmpty
            ? content.caption.text
            : '🎬 Video';
        contentType = 'video';
      } else if (content is MessageDocument) {
        final fileName = content.document.fileName;
        text = content.caption.text.isNotEmpty
            ? content.caption.text
            : '📄 $fileName';
        contentType = 'document';
      } else if (content is MessageVoiceNote) {
        text = content.caption.text.isNotEmpty
            ? content.caption.text
            : '🎤 Voice message';
        contentType = 'voice';
      } else if (content is MessageAudio) {
        text = content.caption.text.isNotEmpty
            ? content.caption.text
            : '🎵 Audio';
        contentType = 'audio';
      } else if (content is MessageSticker) {
        text = '${content.sticker.emoji} Sticker';
        contentType = 'sticker';
      } else if (content is MessageAnimation) {
        text = content.caption.text.isNotEmpty ? content.caption.text : 'GIF';
        contentType = 'animation';
      } else if (content is MessageLocation) {
        text = '📍 Location';
        contentType = 'location';
      } else if (content is MessageContact) {
        text = '👤 ${content.contact.firstName} ${content.contact.lastName}'
            .trim();
        contentType = 'contact';
      } else {
        text = 'Message';
        contentType = content.runtimeType.toString();
      }

      // Get sender info
      String senderName = '';
      int senderId = 0;
      final sender = msg.senderId;
      if (sender is MessageSenderUser) {
        senderId = sender.userId;
        final user = _usersCache[sender.userId];
        if (user != null) {
          senderName = '${user.firstName} ${user.lastName}'.trim();
        }
      } else if (sender is MessageSenderChat) {
        senderId = sender.chatId;
        final chat = _chatsCache[sender.chatId];
        if (chat != null) {
          senderName = chat.title;
        }
      }

      // Get chat info
      String chatTitle = '';
      final chat = _chatsCache[msg.chatId];
      if (chat != null) {
        chatTitle = chat.title;
      }

      return SearchResultMessage(
        id: msg.id,
        chatId: msg.chatId,
        chatTitle: chatTitle,
        senderId: senderId,
        senderName: senderName,
        text: text,
        contentType: contentType,
        date: msg.date,
        isOutgoing: msg.isOutgoing,
      );
    } catch (e) {
      _debugPrint('Error converting message to search result: $e');
      return null;
    }
  }

  /// Clear search results
  void clearSearchResults() {
    _lastSearchResults = null;
    _searchResultsController.add(SearchResults(messages: [], totalCount: 0));
  }

  /// Search filters
  static final searchFilterPhotos = SearchMessagesFilterPhoto();
  static final searchFilterVideos = SearchMessagesFilterVideo();
  static final searchFilterDocuments = SearchMessagesFilterDocument();
  static final searchFilterAudio = SearchMessagesFilterAudio();
  static final searchFilterVoice = SearchMessagesFilterVoiceNote();
  static final searchFilterLinks = SearchMessagesFilterUrl();
  static final searchFilterMentions = SearchMessagesFilterMention();
  static final searchFilterUnread = SearchMessagesFilterUnreadMention();
}

/// Search results container
class SearchResults {
  final List<SearchResultMessage> messages;
  final int totalCount;
  final String? nextOffset;
  final int? nextFromMessageId;
  final int? chatId;

  SearchResults({
    required this.messages,
    required this.totalCount,
    this.nextOffset,
    this.nextFromMessageId,
    this.chatId,
  });
}

/// Individual search result message
class SearchResultMessage {
  final int id;
  final int chatId;
  final String chatTitle;
  final int senderId;
  final String senderName;
  final String text;
  final String contentType;
  final int date;
  final bool isOutgoing;

  SearchResultMessage({
    required this.id,
    required this.chatId,
    required this.chatTitle,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.contentType,
    required this.date,
    required this.isOutgoing,
  });

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(date * 1000);
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPER CLASSES FOR PHASE 2
// ═══════════════════════════════════════════════════════════════════════════

/// Represents a chat folder
class TelegramChatFolder {
  final int id;
  final String title;
  final String? iconName;
  final bool isShareable;
  final List<int> pinnedChatIds;
  final List<int> includedChatIds;
  final List<int> excludedChatIds;
  final bool excludeMuted;
  final bool excludeRead;
  final bool excludeArchived;
  final bool includeContacts;
  final bool includeNonContacts;
  final bool includeBots;
  final bool includeGroups;
  final bool includeChannels;

  TelegramChatFolder({
    required this.id,
    required this.title,
    this.iconName,
    this.isShareable = false,
    this.pinnedChatIds = const [],
    this.includedChatIds = const [],
    this.excludedChatIds = const [],
    this.excludeMuted = false,
    this.excludeRead = false,
    this.excludeArchived = false,
    this.includeContacts = false,
    this.includeNonContacts = false,
    this.includeBots = false,
    this.includeGroups = false,
    this.includeChannels = false,
  });

  factory TelegramChatFolder.fromInfo(ChatFolderInfo info) {
    return TelegramChatFolder(
      id: info.id,
      title: info.title,
      iconName: info.icon?.name,
      isShareable: info.isShareable,
    );
  }

  factory TelegramChatFolder.fromFolder(int id, ChatFolder folder) {
    return TelegramChatFolder(
      id: id,
      title: folder.title,
      iconName: folder.icon?.name,
      isShareable: folder.isShareable,
      pinnedChatIds: folder.pinnedChatIds,
      includedChatIds: folder.includedChatIds,
      excludedChatIds: folder.excludedChatIds,
      excludeMuted: folder.excludeMuted,
      excludeRead: folder.excludeRead,
      excludeArchived: folder.excludeArchived,
      includeContacts: folder.includeContacts,
      includeNonContacts: folder.includeNonContacts,
      includeBots: folder.includeBots,
      includeGroups: folder.includeGroups,
      includeChannels: folder.includeChannels,
    );
  }
}

/// Represents a contact
class TelegramContact {
  final int id;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? username;
  final String? photoUrl;

  TelegramContact({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.username,
    this.photoUrl,
  });

  String get fullName => '$firstName $lastName'.trim();
}

/// Represents file download progress
class FileDownloadProgress {
  final int fileId;
  final double progress;
  final bool isCompleted;
  final String? localPath;
  final String? error;

  FileDownloadProgress({
    required this.fileId,
    required this.progress,
    required this.isCompleted,
    this.localPath,
    this.error,
  });
}

/// Represents file download state
class FileDownloadState {
  final int fileId;
  final bool isDownloading;
  final double progress;
  final String? localPath;
  final String? error;

  FileDownloadState({
    required this.fileId,
    required this.isDownloading,
    required this.progress,
    this.localPath,
    this.error,
  });
}

/// Notification settings for a specific scope (private/group/channel)
class NotificationScopeSettings {
  final String scope;
  final bool isMuted;
  final bool showPreview;
  final int soundId;
  final bool disablePinnedMessageNotifications;
  final bool disableMentionNotifications;
  final bool muteStories;
  final int storySoundId;

  NotificationScopeSettings({
    required this.scope,
    this.isMuted = false,
    this.showPreview = true,
    this.soundId = 0,
    this.disablePinnedMessageNotifications = false,
    this.disableMentionNotifications = false,
    this.muteStories = false,
    this.storySoundId = 0,
  });
}

/// Info about a saved notification sound
class NotificationSoundInfo {
  final int id;
  final String title;
  final int duration;
  final String data;

  NotificationSoundInfo({
    required this.id,
    required this.title,
    this.duration = 0,
    this.data = '',
  });
}
