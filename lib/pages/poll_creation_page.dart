import 'package:flutter/material.dart';
import '../services/telegram_service.dart';
import '../theme/colors.dart';

/// Page to create and send a poll to a chat
class PollCreationPage extends StatefulWidget {
  final int chatId;
  final int? replyToMessageId;

  const PollCreationPage({
    super.key,
    required this.chatId,
    this.replyToMessageId,
  });

  @override
  State<PollCreationPage> createState() => _PollCreationPageState();
}

class _PollCreationPageState extends State<PollCreationPage> {
  final TelegramService _telegramService = TelegramService();
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [];
  final ScrollController _scrollController = ScrollController();

  bool _isAnonymous = true;
  bool _isQuiz = false;
  bool _allowMultiple = false;
  int _correctOptionIndex = -1;
  final TextEditingController _explanationController = TextEditingController();

  // Scheduling
  bool _isScheduled = false;
  DateTime? _scheduledDate;

  @override
  void initState() {
    super.initState();
    // Start with 2 empty options
    _addOption();
    _addOption();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 10) return;
    setState(() {
      _optionControllers.add(TextEditingController());
    });
    // Scroll to bottom after adding
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
      if (_correctOptionIndex == index) {
        _correctOptionIndex = -1;
      } else if (_correctOptionIndex > index) {
        _correctOptionIndex--;
      }
    });
  }

  bool get _canSend {
    final question = _questionController.text.trim();
    if (question.isEmpty) return false;
    final validOptions = _optionControllers
        .where((c) => c.text.trim().isNotEmpty)
        .toList();
    if (validOptions.length < 2) return false;
    if (_isQuiz && _correctOptionIndex < 0) return false;
    return true;
  }

  Future<void> _sendPoll() async {
    if (!_canSend) return;

    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    await _telegramService.sendPoll(
      widget.chatId,
      question: question,
      options: options,
      isAnonymous: _isAnonymous,
      allowMultipleAnswers: _allowMultiple,
      isQuiz: _isQuiz,
      correctOptionId: _isQuiz ? _correctOptionIndex : null,
      explanation: _isQuiz ? _explanationController.text.trim() : null,
      replyToMessageId: widget.replyToMessageId,
      schedulingTimestamp: _scheduledDate != null
          ? (_scheduledDate!.millisecondsSinceEpoch ~/ 1000)
          : null,
    );

    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _pickScheduleDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.blue),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.blue),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduledDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _isScheduled = true;
    });
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
        title: Text('New Poll', style: TextStyle(color: context.appBarText)),
        actions: [
          TextButton(
            onPressed: _canSend ? _sendPoll : null,
            child: Text(
              _isScheduled ? 'Schedule' : 'Send',
              style: TextStyle(
                color: _canSend ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          // Question
          _buildSectionLabel('QUESTION'),
          const SizedBox(height: 8),
          TextField(
            controller: _questionController,
            maxLength: 255,
            maxLines: null,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Ask a question...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              filled: true,
              fillColor: context.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              counterStyle: const TextStyle(color: Colors.white54),
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 24),

          // Options
          _buildSectionLabel('OPTIONS'),
          const SizedBox(height: 8),
          ...List.generate(
            _optionControllers.length,
            (i) => _buildOptionTile(i),
          ),

          if (_optionControllers.length < 10)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                label: const Text(
                  'Add Option',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Settings
          _buildSectionLabel('SETTINGS'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Anonymous Voting',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    _isAnonymous ? 'Votes are hidden' : 'Votes are visible',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  value: _isAnonymous,
                  activeColor: Colors.blue,
                  onChanged: (v) => setState(() => _isAnonymous = v),
                ),
                const Divider(height: 1, color: Colors.white12),
                SwitchListTile(
                  title: const Text(
                    'Quiz Mode',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'One correct answer required',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  value: _isQuiz,
                  activeColor: Colors.blue,
                  onChanged: (v) => setState(() {
                    _isQuiz = v;
                    if (v) {
                      _allowMultiple = false;
                    } else {
                      _correctOptionIndex = -1;
                    }
                  }),
                ),
                if (!_isQuiz) ...[
                  const Divider(height: 1, color: Colors.white12),
                  SwitchListTile(
                    title: const Text(
                      'Multiple Answers',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: _allowMultiple,
                    activeColor: Colors.blue,
                    onChanged: (v) => setState(() => _allowMultiple = v),
                  ),
                ],
              ],
            ),
          ),

          // Quiz explanation
          if (_isQuiz) ...[
            const SizedBox(height: 16),
            _buildSectionLabel('EXPLANATION (OPTIONAL)'),
            const SizedBox(height: 8),
            TextField(
              controller: _explanationController,
              maxLength: 200,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Explain why this answer is correct...',
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
          ],

          const SizedBox(height: 16),

          // Schedule option
          Container(
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(
                Icons.schedule,
                color: _isScheduled ? Colors.blue : Colors.white54,
              ),
              title: Text(
                _isScheduled
                    ? 'Scheduled: ${_formatDate(_scheduledDate!)}'
                    : 'Schedule Poll',
                style: TextStyle(
                  color: _isScheduled ? Colors.blue : Colors.white,
                ),
              ),
              trailing: _isScheduled
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => setState(() {
                        _isScheduled = false;
                        _scheduledDate = null;
                      }),
                    )
                  : const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: _pickScheduleDate,
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.blue.shade300,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildOptionTile(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (_isQuiz)
            GestureDetector(
              onTap: () => setState(() => _correctOptionIndex = index),
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _correctOptionIndex == index
                      ? Colors.green
                      : Colors.transparent,
                  border: Border.all(
                    color: _correctOptionIndex == index
                        ? Colors.green
                        : Colors.white38,
                    width: 2,
                  ),
                ),
                child: _correctOptionIndex == index
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ),
          Expanded(
            child: TextField(
              controller: _optionControllers[index],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Option ${index + 1}',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: context.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_optionControllers.length > 2)
            IconButton(
              icon: const Icon(
                Icons.remove_circle_outline,
                color: Colors.red,
                size: 20,
              ),
              onPressed: () => _removeOption(index),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, $h:$m';
  }
}
