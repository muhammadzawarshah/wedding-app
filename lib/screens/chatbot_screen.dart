import 'package:flutter/material.dart';

import '../data/mock_wedding_data.dart';
import '../models/wedding_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/passport_background.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _messageController = TextEditingController();
  final List<ChatMessage> _messages = const [
    ChatMessage(
      text:
          'Hi! I am the wedding assistant. Ask me anything about the wedding — venue, timings, events, family, gifts, live stream and more. If I am unsure, I will forward your question to the admin.',
      isGuest: false,
    ),
  ].toList();

  bool _sending = false;

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    _messageController.clear();
    setState(() {
      _messages.add(ChatMessage(text: text, isGuest: true));
      _sending = true;
    });

    final reply = await _answerFor(text);
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(text: reply, isGuest: false));
      _sending = false;
    });
  }

  /// Asks the shared backend FAQ assistant (so unanswered questions land in the
  /// same organiser handoff queue as the website). When the server is
  /// unreachable the question is queued locally for an admin to answer — no
  /// canned/dummy answers are returned.
  Future<String> _answerFor(String question) async {
    final remote = await ApiService.instance.askChatbot(question);
    if (remote != null) {
      if (!remote.answered) AppState.addQuestion(question);
      return remote.answer;
    }

    AppState.addQuestion(question);
    return 'I do not have a confirmed answer yet. I sent this to the organiser dashboard, and an admin can reply.';
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PassportBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('AI Assistant')),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return Align(
                      alignment: message.isGuest
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 320),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: message.isGuest
                              ? AppColors.deepInk
                              : AppColors.warmWhite.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          message.text,
                          style: TextStyle(
                            color: message.isGuest
                                ? Colors.white
                                : AppColors.deepInk,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Ask about wedding info...',
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
