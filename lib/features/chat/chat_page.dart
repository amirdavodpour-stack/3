import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/chat/chat_repository.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/ui/hope_async_state.dart';
import '../../core/ui/components.dart';
import '../../core/ui/premium_components.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    this.repository,
    this.jobId,
    this.adminRoom = false,
  });

  final ChatRepository? repository;
  final String? jobId;
  final bool adminRoom;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  late final ChatRepository _repository;

  HopeChatThread? _thread;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? context.read<ChatRepository>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() => _error = null);
    }

    try {
      final items = await _repository.listConversations();
      HopeChatConversation? conversation;

      for (final item in items) {
        final matches = widget.adminRoom
            ? item.kind.toUpperCase() == 'ADMIN'
            : item.kind.toUpperCase() == 'JOB' && item.jobId == widget.jobId;
        if (matches) {
          conversation = item;
          break;
        }
      }

      if (conversation == null) {
        throw StateError('Conversation is not available');
      }

      final thread = await _repository.getMessages(conversation.id);
      if (!mounted) return;
      setState(() {
        _thread = thread;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = apiErrorMessage(
          e,
          fallback: _t(
            'گفتگو در دسترس نیست.',
            'Conversation is not available.',
          ),
        ),
      );
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final thread = _thread;
    if (text.isEmpty ||
        _busy ||
        thread == null ||
        thread.conversation.status.toUpperCase() != 'OPEN') {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    _controller.clear();

    try {
      final message = await _repository.sendMessage(
        thread.conversation.id,
        text,
      );
      if (!mounted) return;

      setState(
        () => _thread = HopeChatThread(
          conversation: thread.conversation,
          messages: [...thread.messages, message],
        ),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        if (_controller.text.isEmpty) {
          _controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }
        setState(
          () => _error = apiErrorMessage(
            e,
            fallback: _t(
              'پیام ارسال نشد.',
              'Message could not be sent.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _t(String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  String _chatStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return _t('باز', 'Open');
      case 'CLOSED':
        return _t('بسته', 'Closed');
      case 'SETTLED':
        return _t('تسویه‌شده', 'Settled');
      default:
        return _t('وضعیت گفتگو', 'Conversation status');
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _thread?.conversation;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final pageId = widget.adminRoom
        ? HopePageId.adminChat
        : (widget.jobId?.trim().isNotEmpty == true
            ? HopePageId.jobChat
            : HopePageId.chat);
    final currentUserId =
        context.read<AuthController?>()?.user?['id']?.toString();
    final title = widget.adminRoom
        ? _t('گفتگوی مدیران', 'Admin room')
        : conversation?.otherUserName.isNotEmpty == true
            ? conversation!.otherUserName
            : _t('گفتگوی این کار', 'Job chat');
    final contextLine = widget.adminRoom
        ? _t('اتاق داخلی اعضای مجاز', 'Private room for authorized members')
        : conversation?.title.trim().isNotEmpty == true
            ? conversation!.title
            : _t('گفتگوی این همکاری', 'Job conversation');
    final conversationStatus = conversation?.status.toUpperCase();
    final statusColor = conversationStatus == 'OPEN'
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final colors = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: PremiumPageFrame(
            maxWidth: 920,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              children: [
                PremiumPanel(
                  key: const ValueKey('chat-conversation-header'),
                  glass: true,
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(HopeV2Radii.md),
                              border: Border.all(color: colors.primary.withValues(alpha: .20)),
                            ),
                            child: Center(
                              child: HopeIcon(
                                widget.adminRoom ? HopeV2Icons.protectedFunds : HopeV2Icons.message,
                                size: 20,
                                color: colors.primary,
                                strokeWidth: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.adminRoom ? _t('اتاق مدیران', 'ADMIN ROOM') : _t('گفتگو', 'CONVERSATION'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .35,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  title,
                                  key: const ValueKey('chat-conversation-title'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  contextLine,
                                  key: const ValueKey('chat-conversation-context'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          PremiumIconButton(
                            icon: HopeV2Icons.close,
                            tooltip: isEn ? 'Close' : 'بستن',
                            onPressed: () => Navigator.maybePop(context),
                          ),
                        ],
                      ),
                      if (conversation != null) ...[
                        const SizedBox(height: 9),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: PremiumTag(
                            icon: HopeV2Icons.message,
                            label: _chatStatusLabel(conversation.status),
                            color: statusColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_error != null && _thread != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      key: const ValueKey('chat-send-error'),
                      decoration: BoxDecoration(
                        color: colors.errorContainer.withValues(alpha: .38),
                        borderRadius: BorderRadius.circular(HopeV2Radii.md),
                      ),
                      padding: const EdgeInsetsDirectional.only(start: 10, end: 4),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, size: 16, color: colors.error),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              _error!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              tapTargetSize: MaterialTapTargetSize.padded,
                            ),
                            onPressed: _busy ? null : _load,
                            child: Text(_t('تلاش دوباره', 'Retry')),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: _thread == null
                      ? _error != null
                          ? Center(
                              child: HopeAsyncState(
                                kind: HopeStateKind.error,
                                title: _t('گفتگو در دسترس نیست', 'Conversation unavailable'),
                                message: _error!,
                                action: FilledButton.icon(
                                  onPressed: _busy ? null : _load,
                                  icon: const HopeIcon(HopeV2Icons.refresh, size: 18),
                                  label: Text(_t('تلاش دوباره', 'Retry')),
                                ),
                              ),
                            )
                          : HopeAsyncState(
                              kind: HopeStateKind.loading,
                              title: _t('در حال بارگذاری گفتگو', 'Loading conversation'),
                              message: _t(
                                'پیام‌های این گفتگو در حال دریافت هستند.',
                                'Messages in this conversation are loading.',
                              ),
                            )
                      : _thread!.messages.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                                child: PremiumEmptyState(
                                  icon: HopeV2Icons.message,
                                  title: _t('هنوز پیامی ثبت نشده است.', 'No messages yet.'),
                                  message: _t(
                                    'پیام‌های این همکاری پس از شروع گفتگو در این بخش نمایش داده می‌شوند.',
                                    'Messages for this collaboration will appear here once the conversation starts.',
                                  ),
                                  dense: true,
                                ),
                              ),
                            )
                          : PremiumPanel(
                              key: const ValueKey('chat-message-list-panel'),
                              glass: true,
                              padding: const EdgeInsets.all(6),
                              child: ListView.builder(
                                key: const ValueKey('chat-message-list'),
                                controller: _scroll,
                                padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
                                itemCount: _thread!.messages.length,
                                itemBuilder: (context, index) {
                                  final messages = _thread!.messages;
                                  final message = messages[index];
                                  final mine = currentUserId != null && message.senderId == currentUserId;
                                  final showSender = index == 0 || messages[index - 1].senderId != message.senderId;
                                  final timestamp = MaterialLocalizations.of(context).formatTimeOfDay(
                                    TimeOfDay.fromDateTime(message.createdAt.toLocal()),
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Align(
                                      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .84),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: mine
                                                ? colors.primary.withValues(alpha: .11)
                                                : colors.surfaceContainerHighest.withValues(alpha: .52),
                                            border: Border.all(color: colors.outlineVariant.withValues(alpha: .48)),
                                            borderRadius: BorderRadiusDirectional.only(
                                              topStart: const Radius.circular(14),
                                              topEnd: const Radius.circular(14),
                                              bottomStart: Radius.circular(mine ? 14 : 4),
                                              bottomEnd: Radius.circular(mine ? 4 : 14),
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (showSender)
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          message.senderName,
                                                          key: ValueKey('chat-sender-${message.id}'),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        timestamp,
                                                        key: ValueKey('chat-message-timestamp-${message.id}'),
                                                        textDirection: TextDirection.ltr,
                                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                          color: colors.onSurfaceVariant,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                else
                                                  Align(
                                                    alignment: AlignmentDirectional.centerEnd,
                                                    child: Text(timestamp, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
                                                  ),
                                                if (showSender) const SizedBox(height: 5),
                                                Text(message.body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.42)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
                if (conversationStatus == 'OPEN')
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: PremiumPanel(
                      key: const ValueKey('chat-composer-panel'),
                      glass: true,
                      padding: const EdgeInsets.all(7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              key: const ValueKey('chat-message-input'),
                              controller: _controller,
                              minLines: 1,
                              maxLines: 4,
                              enabled: !_busy,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              decoration: InputDecoration(
                                hintText: _t('پیام خود را بنویسید', 'Write a message'),
                                isDense: true,
                                prefixIcon: null,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _controller,
                            builder: (context, value, child) => PremiumIconButton(
                              key: const ValueKey('chat-send-button'),
                              icon: isEn ? HopeV2Icons.arrowLeft : HopeV2Icons.arrowRight,
                              tooltip: _t('ارسال', 'Send'),
                              onPressed: _busy || value.text.trim().isEmpty ? null : _send,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (conversation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: PremiumPanel(
                      glass: true,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          HopeIcon(HopeV2Icons.secure, size: 18, color: colors.onSurfaceVariant, strokeWidth: 1.6),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(_t('این گفتگو بسته شده است.', 'This conversation is closed.')),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}