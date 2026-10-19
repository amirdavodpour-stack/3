import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/chat/chat_repository.dart';
import '../../core/chat/chat_voice_bridge.dart';
import '../../core/network/api_error_presenter.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/ui/hope_async_state.dart';
import '../../core/ui/components.dart';
import '../../core/ui/premium_components.dart';

String _normalizeChatSearchText(String input) {
  var value = input.toLowerCase();
  const letterMap = {
    'ي': 'ی',
    'ك': 'ک',
    'ة': 'ه',
    'ؤ': 'و',
    'إ': 'ا',
    'أ': 'ا',
    'آ': 'ا',
    'ۀ': 'ه',
  };
  letterMap.forEach((from, to) => value = value.replaceAll(from, to));
  value = value
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u200f]'), ' ')
      .replaceAll('\u200c', '');
  const digitMap = {
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
  };
  digitMap.forEach((from, to) => value = value.replaceAll(from, to));
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    this.repository,
    this.jobId,
    this.conversationId,
    this.adminRoom = false,
  });

  final ChatRepository? repository;
  final String? jobId;
  final String? conversationId;
  final bool adminRoom;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  late final ChatRepository _repository;

  HopeChatThread? _thread;
  List<HopeChatConversation> _conversations = const [];
  List<HopeChatPresence> _presence = const [];
  bool _busy = false;
  bool _loadingInbox = true;
  bool _typing = false;
  bool _recordingVoice = false;
  String? _pendingVoicePath;
  String? _playingVoiceMessageId;
  StreamSubscription<void>? _voicePlaybackSubscription;
  String? _error;
  String _searchQuery = '';
  String _inboxFilter = 'ALL';
  Timer? _liveTimer;
  Timer? _typingTimer;
  bool _pollingLive = false;
  final List<Directory> _voiceTempDirs = [];

  bool get _isInbox => widget.conversationId == null && widget.jobId == null && !widget.adminRoom;
  ChatCapabilitiesRepository? get _capabilities =>
      _repository is ChatCapabilitiesRepository ? _repository as ChatCapabilitiesRepository : null;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? context.read<ChatRepository>();
    _voicePlaybackSubscription = HopeChatVoiceBridge.playbackCompleted.listen((_) {
      if (!mounted || _playingVoiceMessageId == null) return;
      setState(() => _playingVoiceMessageId = null);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _typingTimer?.cancel();
    final voicePlaybackSubscription = _voicePlaybackSubscription;
    if (voicePlaybackSubscription != null) unawaited(voicePlaybackSubscription.cancel());
    final thread = _thread;
    final capabilities = _capabilities;
    if (thread != null && capabilities != null) {
      unawaited(capabilities.updatePresence(thread.conversation.id, online: false, typing: false).catchError((Object _) {}));
    }
    unawaited(HopeChatVoiceBridge.stopPlayback().catchError((Object _) {}));
    if (_recordingVoice) unawaited(_discardActiveRecording());
    final pendingVoice = _pendingVoicePath;
    if (!_recordingVoice && pendingVoice != null) {
      unawaited(File(pendingVoice).delete().catchError((Object _) => File(pendingVoice)));
    }
    for (final directory in _voiceTempDirs) {
      unawaited(_deleteVoiceTempDirectory(directory));
    }
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _deleteVoiceTempDirectory(Directory directory) async {
    try { await directory.delete(recursive: true); } catch (_) {}
  }

  Future<void> _discardActiveRecording() async {
    try {
      final path = await HopeChatVoiceBridge.stopRecording();
      await File(path).delete();
    } catch (_) {}
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent && mounted) setState(() { _loadingInbox = true; _error = null; });
    try {
      final items = await _repository.listConversations();
      if (!mounted) return;
      setState(() { _conversations = items; _loadingInbox = false; _error = null; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingInbox = false;
        _error = apiErrorMessage(e, fallback: _t('فهرست گفتگوها بارگذاری نشد.', 'Could not load conversations.'));
      });
    }
  }

  Future<void> _load() async {
    if (_isInbox) { await _loadConversations(); return; }
    if (mounted) setState(() => _error = null);
    try {
      final items = await _repository.listConversations();
      HopeChatConversation? conversation;
      for (final item in items) {
        final matches = widget.conversationId != null
            ? item.id == widget.conversationId
            : widget.adminRoom
                ? item.kind.toUpperCase() == 'ADMIN'
                : item.kind.toUpperCase() == 'JOB' && item.jobId == widget.jobId;
        if (matches) { conversation = item; break; }
      }
      if (conversation == null) throw StateError('Conversation is not available');
      final thread = await _repository.getMessages(conversation.id);
      if (!mounted) return;
      setState(() { _thread = thread; _error = null; });
      _startLiveUpdates();
      final capabilities = _capabilities;
      if (capabilities != null) {
        try {
          await capabilities.markRead(conversation.id);
          await capabilities.updatePresence(conversation.id, online: true, typing: false);
          final presence = await capabilities.listPresence(conversation.id);
          if (mounted) setState(() => _presence = presence);
        } catch (_) {
          // The conversation itself remains readable if an optional presence
          // capability is temporarily unavailable.
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e, fallback: _t('گفتگو در دسترس نیست.', 'Conversation is not available.')));
    }
  }

  void _startLiveUpdates() {
    _liveTimer?.cancel();
    if (_capabilities != null && _thread != null) {
      _liveTimer = Timer.periodic(const Duration(seconds: 6), (_) => _pollLive());
    }
  }

  Future<void> _pollLive() async {
    final thread = _thread;
    final capabilities = _capabilities;
    if (!mounted || _pollingLive || thread == null || capabilities == null) return;
    _pollingLive = true;
    try {
      final next = await _repository.getMessages(thread.conversation.id);
      final userId = context.read<AuthController?>()?.user?['id']?.toString();
      final unreadIncoming = next.messages.any((message) =>
        message.senderId != userId && !message.readReceipts.any((receipt) => receipt.userId == userId));
      // A live GET may have started before a successful send or another
      // thread refresh. Do not let that older snapshot replace newer UI state.
      if (mounted && identical(_thread, thread)) {
        setState(() => _thread = next);
      }
      if (unreadIncoming) await capabilities.markRead(thread.conversation.id);
      final presence = await capabilities.listPresence(thread.conversation.id);
      await capabilities.updatePresence(thread.conversation.id, online: true, typing: _typing);
      if (mounted) setState(() => _presence = presence);
    } catch (_) {
      // Poll failures are transient; keep already loaded history visible.
    } finally {
      _pollingLive = false;
    }
  }

  void _onComposerChanged(String value) {
    final thread = _thread;
    final capabilities = _capabilities;
    if (thread == null || capabilities == null) return;
    _typingTimer?.cancel();
    final nextTyping = value.trim().isNotEmpty;
    final typingChanged = nextTyping != _typing;
    _typing = nextTyping;
    if (typingChanged) {
      unawaited(capabilities.updatePresence(
        thread.conversation.id, online: true, typing: nextTyping,
      ).catchError((Object _) {}));
    }
    if (nextTyping) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _typing = false;
        unawaited(capabilities.updatePresence(thread.conversation.id, online: true, typing: false).catchError((Object _) {}));
      });
    }
  }

  Future<void> _setPreference(HopeChatConversation conversation, String action) async {
    final capabilities = _capabilities;
    if (capabilities == null) return;
    try {
      switch (action) {
        case 'pin':
          await capabilities.updatePreferences(conversation.id, isPinned: !conversation.isPinned);
          break;
        case 'important':
          await capabilities.updatePreferences(conversation.id, isImportant: !conversation.isImportant);
          break;
        case 'archive':
          await capabilities.updatePreferences(conversation.id, isArchived: !conversation.isArchived);
          break;
      }
      await _loadConversations(silent: true);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, fallback: _t('تغییر گفتگو ذخیره نشد.', 'Could not update conversation.')));
    }
  }

  Future<void> _pickAndSendAttachments() async {
    if (_capabilities == null || _busy) return;
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: true, type: FileType.custom,
        allowedExtensions: const ['pdf','png','jpg','jpeg','webp','txt','m4a','mp3','wav'],
      );
      if (picked == null) return;
      if (picked.files.length > 5) {
        setState(() => _error = _t('در هر پیام حداکثر ۵ فایل مجاز است.', 'You can attach up to five files per message.'));
        return;
      }
      final files = picked.files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
      if (files.isNotEmpty) await _sendFiles(files, messageType: 'ATTACHMENT');
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, fallback: _t('انتخاب فایل انجام نشد.', 'Could not select files.')));
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (_busy || _capabilities == null) return;
    if (!_recordingVoice) {
      try {
        final path = await HopeChatVoiceBridge.startRecording();
        if (!mounted) {
          try { await HopeChatVoiceBridge.stopRecording(); } catch (_) {}
          try { await File(path).delete(); } catch (_) {}
          return;
        }
        setState(() { _pendingVoicePath = path; _recordingVoice = true; _error = null; });
      } catch (e) {
        if (mounted) setState(() => _error = apiErrorMessage(e, fallback: _t('ضبط صدا ممکن نشد. مجوز میکروفون را بررسی کنید.', 'Could not record audio. Check microphone permission.')));
      }
      return;
    }
    try {
      final path = await HopeChatVoiceBridge.stopRecording();
      if (!mounted) { try { await File(path).delete(); } catch (_) {} return; }
      setState(() { _recordingVoice = false; _pendingVoicePath = path; });
      await _sendFiles([File(path)], messageType: 'VOICE', removeSourcesOnSuccess: true);
    } catch (e) {
      if (mounted) setState(() { _recordingVoice = false; _error = apiErrorMessage(e, fallback: _t('پیام صوتی آماده نشد.', 'Voice message could not be prepared.')); });
    }
  }

  Future<void> _sendFiles(List<File> files, {required String messageType, bool removeSourcesOnSuccess = false}) async {
    final capabilities = _capabilities;
    final thread = _thread;
    if (capabilities == null || thread == null || _busy || files.isEmpty) return;
    setState(() { _busy = true; _error = null; });
    try {
      final uploaded = <Map<String,String>>[];
      for (final file in files) {
        final result = await capabilities.uploadChatFile(file);
        uploaded.add({'key': result['key'].toString(), 'filename': (result['filename'] ?? file.uri.pathSegments.last).toString()});
      }
      final message = await capabilities.sendMessageWithAttachments(
        thread.conversation.id, _controller.text,
        messageType: messageType, attachments: uploaded,
      );
      if (!mounted) return;
      _mergeSentMessage(thread, message);
      _controller.clear();
      if (removeSourcesOnSuccess) {
        for (final file in files) { try { await file.delete(); } catch (_) {} }
        if (messageType == 'VOICE' && mounted) setState(() => _pendingVoicePath = null);
      }
      _scrollToLatest();
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, fallback: _t('پیوست ارسال نشد.', 'Attachment could not be sent.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds:180), curve: Curves.easeOut);
    });
  }

  Future<void> _retryPendingVoiceMessage() async {
    final path = _pendingVoicePath;
    if (path == null || _busy || _recordingVoice) return;
    final file = File(path);
    if (!await file.exists()) {
      if (mounted) setState(() { _pendingVoicePath = null; _error = _t('فایل ضبط‌شده پیدا نشد؛ دوباره ضبط کنید.', 'The recorded voice file is missing. Please record again.'); });
      return;
    }
    await _sendFiles([file], messageType: 'VOICE', removeSourcesOnSuccess: true);
  }

  Future<void> _saveAttachment(HopeChatAttachment attachment) async {
    final capabilities = _capabilities;
    if (capabilities == null) return;
    try {
      final bytes = await capabilities.downloadAttachment(attachment.downloadPath);
      await FilePicker.platform.saveFile(fileName: attachment.filename, bytes: bytes);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, fallback: _t('دریافت فایل ناموفق بود.', 'Could not download attachment.')));
    }
  }

  Future<void> _playVoiceMessage(HopeChatMessage message) async {
    final capabilities = _capabilities;
    if (capabilities == null || message.attachments.isEmpty) return;
    if (_playingVoiceMessageId == message.id) {
      await HopeChatVoiceBridge.stopPlayback();
      if (mounted) setState(() => _playingVoiceMessageId = null);
      return;
    }
    try {
      final attachment = message.attachments.first;
      final bytes = await capabilities.downloadAttachment(attachment.downloadPath);
      final directory = await Directory.systemTemp.createTemp('hope-chat-voice-');
      _voiceTempDirs.add(directory);
      final extension = attachment.filename.contains('.') ? attachment.filename.split('.').last : 'm4a';
      final file = File('${directory.path}/voice.$extension');
      await file.writeAsBytes(bytes, flush: true);
      // Set the active ID before starting native playback so an extremely short
      // clip cannot finish and emit playbackCompleted before the state is set.
      if (mounted) setState(() { _playingVoiceMessageId = message.id; _error = null; });
      await HopeChatVoiceBridge.playFile(file.path);
    } catch (e) {
      if (mounted) setState(() {
        if (_playingVoiceMessageId == message.id) _playingVoiceMessageId = null;
        _error = apiErrorMessage(e, fallback: _t('پخش پیام صوتی ممکن نشد.', 'Could not play voice message.'));
      });
    }
  }

  Widget _buildInbox(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final query = _normalizeChatSearchText(_searchQuery);
    final visible = _conversations.where((conversation) {
      if (_inboxFilter == 'ARCHIVED') {
        if (!conversation.isArchived) return false;
      } else if (conversation.isArchived) {
        return false;
      }
      final haystack = _normalizeChatSearchText(
        '${conversation.otherUserName} ${conversation.title} ${conversation.lastMessageBody}',
      );
      if (query.isNotEmpty && !haystack.contains(query)) return false;
      switch (_inboxFilter) {
        case 'UNREAD': return conversation.unreadCount > 0;
        case 'IMPORTANT': return conversation.isImportant;
        case 'PROJECTS': return conversation.kind.toUpperCase() == 'JOB';
        case 'ARCHIVED': return true;
        default: return true;
      }
    }).toList(growable:false);
    return Scaffold(
      backgroundColor: HopeV2Colors.darkBackground,
      body: SafeArea(child: PremiumPageFrame(
        maxWidth: 920, padding: const EdgeInsets.fromLTRB(12,12,12,8),
        child: Column(crossAxisAlignment:CrossAxisAlignment.stretch, children:[
          Row(children:[
            Container(width:42,height:42,decoration:BoxDecoration(
              color:colors.primary.withValues(alpha:.13),borderRadius:BorderRadius.circular(HopeV2Radii.md),
              border:Border.all(color:colors.primary.withValues(alpha:.26))),
              child:Center(child:HopeIcon(HopeV2Icons.message,color:colors.primary,size:21))),
            const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(_t('گفتگوها','Chats'),style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),
              Text(_t('فضای امن همکاری‌های HOPE','Your HOPE collaboration space'),style:Theme.of(context).textTheme.bodySmall?.copyWith(color:colors.onSurfaceVariant)),
            ])),
            PremiumIconButton(icon:HopeV2Icons.close,tooltip:_t('بستن','Close'),onPressed:()=>Navigator.maybePop(context)),
          ]),
          const SizedBox(height:16),
          TextField(key:const ValueKey('chat-inbox-search'),onChanged:(value)=>setState(()=>_searchQuery=value),
            decoration:InputDecoration(prefixIcon:const HopeIcon(HopeV2Icons.search,size:19),
              hintText:_t('جست‌وجوی نام، پروژه یا آخرین پیام','Search people, projects or latest message'),
              filled:true,fillColor:HopeV2Colors.darkSurface,border:OutlineInputBorder(borderRadius:BorderRadius.circular(15)),isDense:true)),
          const SizedBox(height:10),
          SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
            _inboxChip(_t('همه','All'),'ALL'),const SizedBox(width:7),
            _inboxChip(_t('خوانده‌نشده','Unread'),'UNREAD'),const SizedBox(width:7),
            _inboxChip(_t('مهم','Important'),'IMPORTANT'),const SizedBox(width:7),
            _inboxChip(_t('پروژه‌ها','Projects'),'PROJECTS'),const SizedBox(width:7),
            _inboxChip(_t('بایگانی','Archived'),'ARCHIVED'),
          ])),
          const SizedBox(height:10),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('chat-inbox-retry'),
                    onPressed: _loadingInbox ? null : () => _loadConversations(),
                    icon: const HopeIcon(HopeV2Icons.refresh, size: 18),
                    label: Text(_t('تلاش دوباره', 'Retry')),
                  ),
                ],
              ),
            ),
          Expanded(child:_loadingInbox
            ? const Center(child:CircularProgressIndicator())
            : visible.isEmpty
              ? Center(child:Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,children:[
                  HopeIcon(HopeV2Icons.empty,size:36,color:colors.onSurfaceVariant),const SizedBox(height:12),
                  Text(
                    _error != null
                        ? _t('بارگیری گفتگوها ناموفق بود.', 'Could not load conversations.')
                        : query.isEmpty
                            ? _t('گفتگویی برای نمایش نیست.', 'No conversations to show.')
                            : _t('نتیجه‌ای پیدا نشد.', 'No matching conversations.'),
                    textAlign: TextAlign.center,
                  ),
                ])))
              : RefreshIndicator(onRefresh:()=>_loadConversations(),child:ListView.separated(
                key:const ValueKey('chat-inbox-list'),padding:const EdgeInsets.only(bottom:18),itemCount:visible.length,
                separatorBuilder:(_,__)=>const SizedBox(height:8),
                itemBuilder: (context, index) {
                  final item = visible[index];
                  final name = item.otherUserName.trim().isNotEmpty
                      ? item.otherUserName
                      : (item.kind.toUpperCase() == 'ADMIN'
                          ? _t('اتاق مدیران', 'Admin room')
                          : item.title);
                  final preview = item.lastMessageType.toUpperCase() == 'VOICE'
                      ? _t('پیام صوتی', 'Voice message')
                      : item.lastMessageType.toUpperCase() == 'ATTACHMENT'
                          ? _t('پیوست', 'Attachment')
                          : (item.lastMessageBody.trim().isNotEmpty
                              ? item.lastMessageBody
                              : _t('هنوز پیامی ارسال نشده است.', 'No messages yet.'));
                  final isAdmin = item.kind.toUpperCase() == 'ADMIN';
                  final hasContext = item.title.trim().isNotEmpty &&
                      item.title.trim().toLowerCase() != name.trim().toLowerCase();
                  final timeLabel = _formatConversationTime(context, item.lastMessageAt);
                  final unread = item.unreadCount > 0;
                  final cardAccent = unread
                      ? colors.primary
                      : item.isPinned
                          ? HopeV2Colors.secondaryDark
                          : colors.outlineVariant.withValues(alpha: .28);
                  return Container(
                    key: ValueKey('chat-inbox-card-${item.id}'),
                    decoration: BoxDecoration(
                      color: HopeV2Colors.darkCard,
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(
                        color: cardAccent.withValues(alpha: unread || item.isPinned ? .72 : .30),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(19),
                        onTap: () async {
                          await Navigator.push(context, HopeRoutes.chatConversation(item.id));
                          if (mounted) await _loadConversations(silent: true);
                        },
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 7, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: .13),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: colors.primary.withValues(alpha: .27)),
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    Text(
                                      name.isNotEmpty ? name.characters.first.toUpperCase() : 'H',
                                      style: TextStyle(
                                        color: colors.primary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    if (unread)
                                      PositionedDirectional(
                                        end: -3,
                                        top: -3,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: HopeV2Colors.secondaryDark,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: HopeV2Colors.darkCard, width: 2),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            isAdmin ? _t('تیم HOPE', 'HOPE TEAM') : _t('گفتگوی پروژه', 'PROJECT CHAT'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: colors.secondary,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: .8,
                                            ),
                                          ),
                                        ),
                                        if (timeLabel.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            timeLabel,
                                            key: ValueKey('chat-inbox-time-${item.id}'),
                                            textDirection: TextDirection.ltr,
                                            maxLines: 1,
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: colors.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            key: ValueKey('chat-inbox-name-${item.id}'),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              height: 1.15,
                                            ),
                                          ),
                                        ),
                                        if (item.isPinned)
                                          Padding(
                                            padding: const EdgeInsetsDirectional.only(start: 4, top: 2),
                                            child: Tooltip(
                                              message: _t('گفتگوی سنجاق‌شده', 'Pinned conversation'),
                                              child: HopeIcon(HopeV2Icons.save, size: 14, color: colors.primary),
                                            ),
                                          ),
                                        if (item.isImportant)
                                          Padding(
                                            padding: const EdgeInsetsDirectional.only(start: 4, top: 2),
                                            child: Tooltip(
                                              message: _t('گفتگوی مهم', 'Important conversation'),
                                              child: HopeIcon(HopeV2Icons.featured, size: 14, color: HopeV2Colors.secondaryDark),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (hasContext) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        item.title,
                                        key: ValueKey('chat-inbox-context-${item.id}'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: colors.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: HopeV2Colors.darkSurface,
                                        borderRadius: BorderRadius.circular(11),
                                        border: Border.all(color: HopeV2Colors.darkBorder),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 3,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: unread ? colors.primary : colors.secondary.withValues(alpha: .8),
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              preview,
                                              key: ValueKey('chat-inbox-preview-${item.id}'),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: unread ? colors.onSurface : colors.onSurfaceVariant,
                                                fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                                                height: 1.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 7,
                                      runSpacing: 5,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: item.status.toUpperCase() == 'OPEN'
                                                ? HopeV2Colors.success.withValues(alpha: .15)
                                                : colors.onSurfaceVariant.withValues(alpha: .10),
                                            borderRadius: BorderRadius.circular(7),
                                          ),
                                          child: Text(
                                            item.status.toUpperCase() == 'OPEN'
                                                ? _t('باز', 'OPEN')
                                                : _t('بسته', 'CLOSED'),
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: item.status.toUpperCase() == 'OPEN'
                                                  ? HopeV2Colors.successDark
                                                  : colors.onSurfaceVariant,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: .45,
                                            ),
                                          ),
                                        ),
                                        if (item.isPinned)
                                          Text(_t('سنجاق‌شده', 'PINNED'),
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: colors.primary, fontWeight: FontWeight.w800)),
                                        if (item.isImportant)
                                          Text(_t('مهم', 'IMPORTANT'),
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: HopeV2Colors.secondaryDark, fontWeight: FontWeight.w800)),
                                        if (unread)
                                          Container(
                                            key: ValueKey('chat-inbox-unread-${item.id}'),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: HopeV2Colors.primaryAction,
                                              borderRadius: BorderRadius.circular(7),
                                            ),
                                            child: Text(
                                              _t('${item.unreadCount} خوانده‌نشده', '${item.unreadCount} UNREAD'),
                                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                color: Colors.white, fontWeight: FontWeight.w900),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                tooltip: _t('سازمان‌دهی گفتگو', 'Organize conversation'),
                                icon: HopeIcon(HopeV2Icons.menu, size: 18, color: colors.onSurfaceVariant),
                                onSelected: (action) => _setPreference(item, action),
                                itemBuilder: (_) => [
                                  PopupMenuItem(value: 'pin', child: Text(item.isPinned ? _t('برداشتن سنجاق', 'Unpin') : _t('سنجاق گفتگو', 'Pin conversation'))),
                                  PopupMenuItem(value: 'important', child: Text(item.isImportant ? _t('حذف از مهم‌ها', 'Remove importance') : _t('علامت‌گذاری مهم', 'Mark important'))),
                                  PopupMenuItem(value: 'archive', child: Text(item.isArchived ? _t('از بایگانی خارج کن', 'Unarchive conversation') : _t('بایگانی گفتگو', 'Archive conversation'))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              )),
          ),
        ]),
      )),
    );
  }

  String _formatConversationTime(BuildContext context, DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
    return sameDay
        ? MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(local))
        : MaterialLocalizations.of(context).formatShortDate(local);
  }

  Widget _inboxChip(String label,String filter) {
    final selected=_inboxFilter==filter;
    return ChoiceChip(label:Text(label),selected:selected,onSelected:(_)=>setState(()=>_inboxFilter=filter),
      selectedColor:HopeV2Colors.primaryAction,backgroundColor:HopeV2Colors.darkSurface,
      labelStyle:TextStyle(color:selected?Colors.white:HopeV2Colors.darkText,fontWeight:FontWeight.w700),
      side:BorderSide(color:selected?HopeV2Colors.primaryDark:HopeV2Colors.darkBorderStrong));
  }


  void _mergeSentMessage(
    HopeChatThread requestThread,
    HopeChatMessage sentMessage,
  ) {
    final current = _thread;
    if (!mounted ||
        current == null ||
        current.conversation.id != requestThread.conversation.id) {
      return;
    }

    // Polling can apply newer inbound messages while a send request is pending.
    // Merge into the current same-conversation snapshot, not the pre-await one.
    final messages = <HopeChatMessage>[
      ...current.messages.where((message) => message.id != sentMessage.id),
      sentMessage,
    ];
    setState(() {
      _thread = HopeChatThread(
        conversation: current.conversation,
        messages: messages,
      );
      _error = null;
    });
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

      _mergeSentMessage(thread, message);

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

  String _formatBytes(int size) {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

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

  ThemeData _indigoTheme(BuildContext context) {
    final base = Theme.of(context);
    final scheme = base.colorScheme.copyWith(
      brightness: Brightness.dark, primary: HopeV2Colors.primaryDark,
      secondary: HopeV2Colors.secondaryDark, surface: HopeV2Colors.darkSurface,
      surfaceContainerHighest: HopeV2Colors.darkCard, error: HopeV2Colors.dangerDark,
    );
    return base.copyWith(
      brightness: Brightness.dark, colorScheme: scheme,
      scaffoldBackgroundColor: HopeV2Colors.darkBackground,
      dividerColor: HopeV2Colors.darkBorder,
      textTheme: base.textTheme.apply(bodyColor: HopeV2Colors.darkText, displayColor: HopeV2Colors.darkText),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _indigoTheme(context);
    if (_isInbox) return Theme(data: theme, child: Builder(builder: _buildInbox));
    return Theme(data: theme, child: Builder(builder: _buildConversation));
  }

  Widget _buildConversation(BuildContext context) {
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
    final expandableHeaderText =
        MediaQuery.sizeOf(context).width < 380 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2;

    return Directionality(
      textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: PremiumPageFrame(
            maxWidth: 920,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Column(
              children: [
                PremiumPanel(
                  key: const ValueKey('chat-conversation-header'),
                  glass: true,
                  padding: EdgeInsets.fromLTRB(
                    12,
                    expandableHeaderText ? 4 : 10,
                    8,
                    expandableHeaderText ? 4 : 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: expandableHeaderText ? 32 : 42,
                            height: expandableHeaderText ? 32 : 42,
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
                                if (!expandableHeaderText) ...[
                                  Text(
                                    widget.adminRoom
                                        ? _t('اتاق مدیران', 'ADMIN ROOM')
                                        : _t('گفتگو', 'CONVERSATION'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: .35,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                ],
                                Text(
                                  title,
                                  key: const ValueKey('chat-conversation-title'),
                                  maxLines: expandableHeaderText ? null : 1,
                                  softWrap: true,
                                  overflow: expandableHeaderText
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  contextLine,
                                  key: const ValueKey('chat-conversation-context'),
                                  maxLines: expandableHeaderText ? null : 1,
                                  softWrap: true,
                                  overflow: expandableHeaderText
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (_presence.any((person) => person.online))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      _presence.any((person) => person.typing)
                                          ? _t('در حال نوشتن…', 'Typing…')
                                          : _t('آنلاین', 'Online'),
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: HopeV2Colors.secondaryDark,
                                      ),
                                    ),
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
                        SizedBox(height: expandableHeaderText ? 4 : 9),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final compactBanner = constraints.maxWidth < 340 ||
                                    MediaQuery.textScalerOf(context).scale(1) > 1.2;
                                final errorIcon = Icon(
                                  HopeV2Icons.error,
                                  size: 16,
                                  color: colors.error,
                                );
                                final errorText = Text(
                                  _error!,
                                  key: const ValueKey('chat-send-error-message'),
                                  maxLines: compactBanner ? null : 1,
                                  softWrap: true,
                                  overflow: compactBanner
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                );
                                final retryAction = TextButton(
                                  key: const ValueKey('chat-send-error-retry'),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    tapTargetSize: MaterialTapTargetSize.padded,
                                  ),
                                  onPressed: _busy ? null : _load,
                                  child: Text(_t('تلاش دوباره', 'Retry')),
                                );

                                if (compactBanner) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          errorIcon,
                                          const SizedBox(width: 7),
                                          Expanded(child: errorText),
                                        ],
                                      ),
                                      Align(
                                        alignment: AlignmentDirectional.centerEnd,
                                        child: retryAction,
                                      ),
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    errorIcon,
                                    const SizedBox(width: 7),
                                    Expanded(child: errorText),
                                    retryAction,
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      SizedBox(height: expandableHeaderText ? 4 : 8),
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
                                ? LayoutBuilder(
                                    builder: (context, constraints) {
                                      return SingleChildScrollView(
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minHeight: constraints.maxHeight,
                                          ),
                                          child: Center(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 18,
                                              ),
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
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : PremiumPanel(
                                    key: const ValueKey('chat-message-list-panel'),
                                    quiet: true,
                                    padding: const EdgeInsets.all(4),
                                    child: ListView.builder(
                                      key: const ValueKey('chat-message-list'),
                                      controller: _scroll,
                                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                                      itemCount: _thread!.messages.length,
                                      itemBuilder: (context, index) {
                                        final messages = _thread!.messages;
                                        final message = messages[index];
                                        final mine = currentUserId != null && message.senderId == currentUserId;
                                        final showSender = index == 0 || messages[index - 1].senderId != message.senderId;
                                        final timestamp = MaterialLocalizations.of(context).formatTimeOfDay(
                                          TimeOfDay.fromDateTime(message.createdAt.toLocal()),
                                        );
                                        final senderNameText = Text(
                                          message.senderName,
                                          key: ValueKey('chat-sender-${message.id}'),
                                          maxLines: expandableHeaderText ? null : 1,
                                          softWrap: true,
                                          overflow: expandableHeaderText
                                              ? TextOverflow.visible
                                              : TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        );
                                        final timestampText = Text(
                                          timestamp,
                                          key: ValueKey('chat-message-timestamp-${message.id}'),
                                          textDirection: TextDirection.ltr,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: colors.onSurfaceVariant,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        );
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Align(
                                            alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .84),
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  color: mine
                                                      ? colors.primary.withValues(alpha: .11)
                                                      : colors.surfaceContainerHighest.withValues(alpha: .38),
                                                  border: Border.all(color: colors.outlineVariant.withValues(alpha: .26)),
                                                  borderRadius: BorderRadiusDirectional.only(
                                                    topStart: const Radius.circular(14),
                                                    topEnd: const Radius.circular(14),
                                                    bottomStart: Radius.circular(mine ? 14 : 4),
                                                    bottomEnd: Radius.circular(mine ? 4 : 14),
                                                  ),
                                                ),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      if (showSender)
                                                        if (expandableHeaderText)
                                                          Column(
                                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                                            children: [
                                                              senderNameText,
                                                              const SizedBox(height: 3),
                                                              Align(
                                                                alignment: AlignmentDirectional.centerEnd,
                                                                child: timestampText,
                                                              ),
                                                            ],
                                                          )
                                                        else
                                                          Row(
                                                            children: [
                                                              Expanded(child: senderNameText),
                                                              const SizedBox(width: 8),
                                                              timestampText,
                                                            ],
                                                          )
                                                      else
                                                        Align(
                                                          alignment: AlignmentDirectional.centerEnd,
                                                          child: Text(
                                                            timestamp,
                                                            textDirection: TextDirection.ltr,
                                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                                  color: colors.onSurfaceVariant,
                                                                ),
                                                          ),
                                                        ),
                                                      if (showSender) const SizedBox(height: 5),
                                                      if (message.body.trim().isNotEmpty && message.body != 'Attachment' && message.body != 'Voice message')
                                                        Text(message.body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.42)),
                                                      if (message.messageType.toUpperCase() == 'VOICE' && message.attachments.isNotEmpty)
                                                        Align(
                                                          alignment: AlignmentDirectional.centerStart,
                                                          child: TextButton.icon(
                                                            key: ValueKey('chat-voice-${message.id}'),
                                                            onPressed: () => _playVoiceMessage(message),
                                                            icon: HopeIcon(_playingVoiceMessageId == message.id ? HopeV2Icons.pause : HopeV2Icons.play, size:18),
                                                            label: Text(_t('پیام صوتی', 'Voice message')),
                                                          ),
                                                        ),
                                                      for (final attachment in message.attachments)
                                                        if (message.messageType.toUpperCase() != 'VOICE')
                                                          Padding(
                                                            padding: const EdgeInsets.only(top: 5),
                                                            child: OutlinedButton.icon(
                                                              key: ValueKey('chat-attachment-${attachment.id}'),
                                                              onPressed: () => _saveAttachment(attachment),
                                                              icon: HopeIcon(HopeV2Icons.download, size:16),
                                                              label: Text('${attachment.filename} · ${_formatBytes(attachment.size)}', maxLines:2, overflow:TextOverflow.ellipsis),
                                                            ),
                                                          ),
                                                      if (mine && message.readReceipts.any((receipt) => receipt.userId != currentUserId))
                                                        Align(
                                                          alignment: AlignmentDirectional.centerEnd,
                                                          child: Text(_t('خوانده شد', 'Seen'),
                                                            key: ValueKey('chat-read-${message.id}'),
                                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: HopeV2Colors.secondaryDark)),
                                                        ),
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
                    ],
                  ),
                ),
                if (conversationStatus == 'OPEN')
                  Padding(
                    padding: EdgeInsets.only(
                      top: expandableHeaderText ? 4 : 8,
                      bottom: expandableHeaderText ? 2 : 4,
                    ),
                    child: PremiumPanel(
                      key: const ValueKey('chat-composer-panel'),
                      quiet: true,
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
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
                              onChanged: _onComposerChanged,
                              decoration: InputDecoration(
                                hintText: _t('پیام خود را بنویسید', 'Write a message'),
                                isDense: true,
                                prefixIcon: null,
                                constraints: const BoxConstraints(minHeight: 48),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          if (_repository is ChatCapabilitiesRepository)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Row(
                                children: [
                                  IconButton(
                                    key: const ValueKey('chat-attachment-button'),
                                    tooltip: _t('افزودن فایل', 'Attach files'),
                                    onPressed: _busy ? null : _pickAndSendAttachments,
                                    icon: HopeIcon(HopeV2Icons.attachment, color: colors.secondary, size:20),
                                    constraints: const BoxConstraints(minWidth:48,minHeight:48),
                                  ),
                                  IconButton(
                                    key: const ValueKey('chat-voice-record-button'),
                                    tooltip: _recordingVoice ? _t('پایان ضبط', 'Finish recording') : _t('ضبط پیام صوتی', 'Record voice message'),
                                    onPressed: _busy ? null : _toggleVoiceRecording,
                                    icon: HopeIcon(_recordingVoice ? HopeV2Icons.pause : HopeV2Icons.activity, color: _recordingVoice ? colors.error : colors.secondary, size:20),
                                    constraints: const BoxConstraints(minWidth:48,minHeight:48),
                                  ),
                                  if (_recordingVoice)
                                    Expanded(child: Text(_t('در حال ضبط… برای ارسال دوباره بزنید.', 'Recording… tap to send.'), maxLines:2, style:Theme.of(context).textTheme.labelSmall?.copyWith(color:colors.error))),
                                  if (_pendingVoicePath != null && !_recordingVoice)
                                    IconButton(
                                      key: const ValueKey('chat-retry-voice-button'),
                                      tooltip: _t('ارسال دوباره پیام صوتی', 'Retry voice send'),
                                      onPressed: _busy ? null : _retryPendingVoiceMessage,
                                      icon: HopeIcon(HopeV2Icons.upload, color: colors.secondary, size: 20),
                                      constraints: const BoxConstraints(minWidth:48,minHeight:48),
                                    ),
                                  if (_busy)
                                    const Padding(padding: EdgeInsetsDirectional.only(start:8), child:SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2))),
                                ],
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
                      quiet: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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