import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/chat/chat_repository.dart';
import '../../core/chat/chat_use_cases.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/ui/brand.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.repository});

  final ChatRepository? repository;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[];
  bool _sending = false;
  String? _error;

  ChatRepository get _repository =>
      widget.repository ?? context.read<ChatRepository>();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _controller.text.trim();
    if (message.isEmpty || _sending) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _messages.add(_ChatMessage.user(message));
      _controller.clear();
      _error = null;
      _sending = true;
    });
    _scrollToEnd();

    try {
      final answer = await SendChatMessageUseCase(_repository)(message);
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage.assistant(answer));
      });
      _scrollToEnd();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(
          error,
          fallback: _t(context, 'پاسخ دریافت نشد. دوباره تلاش کنید.',
              'The response could not be loaded. Try again.'),
        );
      });
      _scrollToEnd();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
        final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HopeMark(size: 30),
            const SizedBox(width: 10),
            Text(isEn ? 'HOPE Assistant' : 'دستیار HOPE'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? _EmptyState(isEn: isEn)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                      itemCount: _messages.length + (_error != null ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_error != null && index == _messages.length) {
                          return _ErrorBubble(message: _error!);
                        }
                        return _MessageBubble(message: _messages[index]);
                      },
                    ),
            ),
            if (_sending)
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      onSubmitted: (_) => _send(),
                      enabled: !_sending,
                      decoration: InputDecoration(
                        hintText: isEn
                            ? 'Ask HOPE anything about your work'
                            : 'درباره فرصت یا کارتان از HOPE بپرسید',
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    tooltip: isEn ? 'Send' : 'ارسال',
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _t(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;
}

class _ChatMessage {
  const _ChatMessage.user(this.text) : isUser = true;
  const _ChatMessage.assistant(this.text) : isUser = false;

  final String text;
  final bool isUser;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isEn});

  final bool isEn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HopeMark(size: 56),
            const SizedBox(height: 18),
            Text(
              isEn ? 'Ask. Explore. Get to work.' : 'بپرسید، بررسی کنید، شروع کنید.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              isEn
                  ? 'Use the assistant to explore work and opportunity ideas.'
                  : 'برای بررسی ایده‌ها و فرصت‌های کاری از دستیار استفاده کنید.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser
        ? AlignmentDirectional.centerEnd
        : AlignmentDirectional.centerStart;
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              message.text,
              textDirection: Directionality.of(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
