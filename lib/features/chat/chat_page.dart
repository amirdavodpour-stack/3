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
    final currentUserId =
        context.read<AuthController?>()?.user?['id']?.toString();

    final title = widget.adminRoom
        ? _t('گفتگوی مدیران', 'Admin room')
        : conversation?.otherUserName.isNotEmpty == true
            ? conversation!.otherUserName
            : _t('گفتگوی این کار', 'Job chat');

    final conversationStatus = conversation?.status.toUpperCase();
    final statusColor = conversationStatus == 'OPEN'
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: PremiumPageFrame(
            maxWidth: 920,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                PremiumHeader(
                  page: widget.adminRoom
                      ? HopePageId.adminChat
                      : HopePageId.jobChat,
                  domain: widget.adminRoom
                      ? HopeProductDomain.control
                      : HopeProductDomain.collaboration,
                  eyebrow: widget.adminRoom
                      ? _t('مدیریت', 'ADMIN')
                      : _t('همکاری', 'WORK'),
                  title: title,
                  subtitle: widget.adminRoom
                      ? _t(
                          'گفتگوی داخلی مدیران؛ فقط اعضای مجاز این اتاق آن را می‌بینند.',
                          'Internal admin conversation visible only to authorized members of this room.',
                        )
                      : _t(
                          'گفتگوی این همکاری تا پایان کار و تسویه در دسترس است.',
                          'This collaboration chat stays available through completion and settlement.',
                        ),
                  trailing: PremiumIconButton(
                    icon: HopeV2Icons.close,
                    tooltip: isEn ? 'Close' : 'بستن',
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
                if (conversation != null) ...[
                  const SizedBox(height: HopeV2Spacing.sm),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: PremiumTag(
                      icon: HopeV2Icons.message,
                      label: _chatStatusLabel(conversation.status),
                      color: statusColor,
                    ),
                  ),
                ],
                const SizedBox(height: HopeV2Spacing.md),
                if (_error != null && _thread != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: HopeV2Spacing.sm),
                    child: HopeAsyncState(
                      kind: HopeStateKind.error,
                      title: _t(
                        'گفتگو در دسترس نیست',
                        'Conversation unavailable',
                      ),
                      message: _error!,
                      action: FilledButton.icon(
                        onPressed: _busy ? null : _load,
                        icon: HopeIcon(
                          HopeV2Icons.refresh,
                          size: 19,
                        ),
                        label: Text(_t('تلاش دوباره', 'Retry')),
                      ),
                    ),
                  ),
                Expanded(
                  child: _thread == null
                      ? _error != null
                          ? HopeAsyncState(
                              kind: HopeStateKind.error,
                              title: _t(
                                'گفتگو در دسترس نیست',
                                'Conversation unavailable',
                              ),
                              message: _error!,
                              action: FilledButton.icon(
                                onPressed: _busy ? null : _load,
                                icon: HopeIcon(
                                  HopeV2Icons.refresh,
                                  size: 19,
                                ),
                                label: Text(_t('تلاش دوباره', 'Retry')),
                              ),
                            )
                          : HopeAsyncState(
                              kind: HopeStateKind.loading,
                              title: _t(
                                'در حال بارگذاری گفتگو',
                                'Loading conversation',
                              ),
                              message: _t(
                                'پیام‌های این گفتگو در حال دریافت هستند.',
                                'Messages in this conversation are loading.',
                              ),
                            )
                      : _thread!.messages.isEmpty
                          ? PremiumPanel(
                              glass: true,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      HopeIcon(
                                        HopeV2Icons.message,
                                        size: 38,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _t(
                                          'هنوز پیامی ثبت نشده است.',
                                          'No messages yet.',
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : PremiumPanel(
                              glass: true,
                              padding: const EdgeInsets.all(
                                HopeV2Spacing.md,
                              ),
                              child: ListView.builder(
                                controller: _scroll,
                                padding: const EdgeInsets.fromLTRB(
                                  HopeV2Spacing.sm,
                                  HopeV2Spacing.xs,
                                  HopeV2Spacing.sm,
                                  HopeV2Spacing.md,
                                ),
                                itemCount: _thread!.messages.length,
                                itemBuilder: (context, index) {
                                  final message = _thread!.messages[index];
                                  final mine = currentUserId != null &&
                                      message.senderId == currentUserId;
                                  final timestamp =
                                      MaterialLocalizations.of(context)
                                          .formatTimeOfDay(
                                    TimeOfDay.fromDateTime(
                                      message.createdAt.toLocal(),
                                    ),
                                  );

                                  return Align(
                                    alignment: mine
                                        ? AlignmentDirectional.centerEnd
                                        : AlignmentDirectional.centerStart,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 680,
                                      ),
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: PremiumPanel(
                                          highlight: mine,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 11,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      message.senderName,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    timestamp,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(message.body),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
                const SizedBox(height: HopeV2Spacing.md),
                if (conversationStatus == 'OPEN')
                  SafeArea(
                    top: false,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            maxLines: 4,
                            minLines: 1,
                            enabled: !_busy,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: _t(
                                'پیام خود را بنویسید',
                                'Write a message',
                              ),
                              prefixIcon: HopeIcon(
                                HopeV2Icons.message,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: HopeV2Spacing.sm),
                        PremiumIconButton(
                          icon: isEn
                              ? HopeV2Icons.arrowLeft
                              : HopeV2Icons.arrowRight,
                          tooltip: _t('ارسال', 'Send'),
                          onPressed: _busy ? null : _send,
                        ),
                      ],
                    ),
                  )
                else if (conversation != null)
                  PremiumPanel(
                    glass: true,
                    child: Row(
                      children: [
                        HopeIcon(HopeV2Icons.secure, size: 20),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _t(
                              'این گفتگو بسته شده است.',
                              'This conversation is closed.',
                            ),
                          ),
                        ),
                      ],
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
