import 'package:flutter/material.dart';
import '../services/telegram_service.dart';
import '../theme/colors.dart';
import 'chat_detail_page.dart';

/// Saved Messages page - redirects to user's own chat
class SavedMessagesPage extends StatefulWidget {
  const SavedMessagesPage({super.key});

  @override
  State<SavedMessagesPage> createState() => _SavedMessagesPageState();
}

class _SavedMessagesPageState extends State<SavedMessagesPage> {
  final TelegramService _telegramService = TelegramService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _openSavedMessages();
  }

  Future<void> _openSavedMessages() async {
    final chatId = await _telegramService.openSavedMessages();
    if (chatId != null && chatId != 0 && mounted) {
      // Try to find the chat in existing list
      final chats = _telegramService.chats;
      final existingChat = chats.where((c) => c.id == chatId).firstOrNull;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(
            chat: existingChat,
            name: 'Saved Messages',
            actualChatId: chatId,
          ),
        ),
      );
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.appBarBg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.appBarText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Saved Messages',
          style: TextStyle(color: context.appBarText),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bookmark,
                      color: Colors.blue,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Saved Messages',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Forward messages here to save them',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _openSavedMessages,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
