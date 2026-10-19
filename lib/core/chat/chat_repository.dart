import 'dart:io';
import 'dart:typed_data';

import '../network/api_client.dart';

class HopeChatConversation {
  const HopeChatConversation({
    required this.id, required this.kind, required this.jobId,
    required this.status, required this.title, required this.otherUserName,
    this.lastMessageBody = '', this.lastMessageType = 'TEXT',
    this.lastMessageAt, this.unreadCount = 0,
    this.isPinned = false, this.isImportant = false, this.isArchived = false,
  });
  final String id, kind, jobId, status, title, otherUserName;
  final String lastMessageBody, lastMessageType;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isPinned, isImportant, isArchived;
  factory HopeChatConversation.fromMap(Map<String,dynamic> m) => HopeChatConversation(
    id: (m['id'] ?? '').toString(), kind: (m['kind'] ?? '').toString(),
    jobId: (m['jobId'] ?? '').toString(), status: (m['status'] ?? 'CLOSED').toString(),
    title: (m['title'] ?? '').toString(), otherUserName: (m['otherUserName'] ?? '').toString(),
    lastMessageBody: (m['lastMessageBody'] ?? '').toString(),
    lastMessageType: (m['lastMessageType'] ?? 'TEXT').toString(),
    lastMessageAt: DateTime.tryParse((m['lastMessageAt'] ?? '').toString()),
    unreadCount: int.tryParse((m['unreadCount'] ?? 0).toString()) ?? 0,
    isPinned: m['isPinned'] == true, isImportant: m['isImportant'] == true, isArchived: m['isArchived'] == true,
  );
}

class HopeChatAttachment {
  const HopeChatAttachment({required this.id, required this.filename, required this.contentType, required this.size, required this.downloadPath});
  final String id, filename, contentType, downloadPath;
  final int size;
  factory HopeChatAttachment.fromMap(Map<String,dynamic> m) => HopeChatAttachment(
    id: (m['id'] ?? '').toString(), filename: (m['filename'] ?? 'attachment').toString(),
    contentType: (m['contentType'] ?? 'application/octet-stream').toString(),
    size: int.tryParse((m['size'] ?? 0).toString()) ?? 0, downloadPath: (m['downloadPath'] ?? '').toString(),
  );
}
class HopeChatReadReceipt {
  const HopeChatReadReceipt({required this.userId, required this.userName, required this.readAt});
  final String userId, userName;
  final DateTime? readAt;
  factory HopeChatReadReceipt.fromMap(Map<String,dynamic> m) => HopeChatReadReceipt(
    userId: (m['userId'] ?? '').toString(), userName: (m['userName'] ?? '').toString(),
    readAt: DateTime.tryParse((m['readAt'] ?? '').toString()),
  );
}
class HopeChatPresence {
  const HopeChatPresence({required this.userId, required this.userName, required this.online, required this.typing, this.lastSeenAt});
  final String userId, userName;
  final bool online, typing;
  final DateTime? lastSeenAt;
  factory HopeChatPresence.fromMap(Map<String,dynamic> m) => HopeChatPresence(
    userId: (m['userId'] ?? '').toString(), userName: (m['userName'] ?? '').toString(),
    online: m['online'] == true, typing: m['typing'] == true,
    lastSeenAt: DateTime.tryParse((m['lastSeenAt'] ?? '').toString()),
  );
}
class HopeChatMessage {
  const HopeChatMessage({
    required this.id, required this.conversationId, required this.senderId,
    required this.senderName, required this.body, required this.createdAt,
    this.messageType = 'TEXT', this.attachments = const [], this.readReceipts = const [],
  });
  final String id, conversationId, senderId, senderName, body;
  final DateTime createdAt;
  final String messageType;
  final List<HopeChatAttachment> attachments;
  final List<HopeChatReadReceipt> readReceipts;
  factory HopeChatMessage.fromMap(Map<String,dynamic> m) => HopeChatMessage(
    id: (m['id'] ?? '').toString(), conversationId: (m['conversationId'] ?? '').toString(),
    senderId: (m['senderId'] ?? '').toString(), senderName: (m['senderName'] ?? '').toString(),
    body: (m['body'] ?? '').toString(),
    createdAt: DateTime.tryParse((m['createdAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0),
    messageType: (m['messageType'] ?? 'TEXT').toString(),
    attachments: (m['attachments'] is List ? m['attachments'] as List : const []).whereType<Map>()
      .map((e) => HopeChatAttachment.fromMap(Map<String,dynamic>.from(e))).toList(growable:false),
    readReceipts: (m['readReceipts'] is List ? m['readReceipts'] as List : const []).whereType<Map>()
      .map((e) => HopeChatReadReceipt.fromMap(Map<String,dynamic>.from(e))).toList(growable:false),
  );
}

class HopeChatThread {
  const HopeChatThread({required this.conversation, required this.messages});
  final HopeChatConversation conversation;
  final List<HopeChatMessage> messages;
}

abstract interface class ChatCapabilitiesRepository {
  Future<HopeChatMessage> sendMessageWithAttachments(String conversationId, String message, {required String messageType, required List<Map<String, String>> attachments});
  Future<Map<String, dynamic>> uploadChatFile(File file);
  Future<Uint8List> downloadAttachment(String downloadPath);
  Future<void> markRead(String conversationId);
  Future<void> updatePresence(String conversationId, {required bool online, required bool typing});
  Future<List<HopeChatPresence>> listPresence(String conversationId);
  Future<void> updatePreferences(String conversationId, {bool? isPinned, bool? isImportant, bool? isArchived});
}
abstract interface class ChatRepository {
  Future<List<HopeChatConversation>> listConversations();
  Future<HopeChatThread> getMessages(String conversationId);
  Future<HopeChatMessage> sendMessage(String conversationId, String message);
}

class ApiChatRepository implements ChatRepository, ChatCapabilitiesRepository {
  const ApiChatRepository(this._api);
  final ApiClient _api;
  @override
  Future<List<HopeChatConversation>> listConversations() async {
    final raw=await _api.request('GET','/messaging/conversations',auth:true);
    if(raw is! Map || raw['items'] is! List) return const [];
    return (raw['items'] as List).whereType<Map>().map((e)=>HopeChatConversation.fromMap(Map<String,dynamic>.from(e))).toList(growable:false);
  }
  @override
  Future<HopeChatThread> getMessages(String conversationId) async {
    final raw=await _api.request('GET','/messaging/conversations/$conversationId',auth:true);
    if(raw is! Map || raw['conversation'] is! Map || raw['messages'] is! List) throw const FormatException('Invalid chat response');
    final conversation=HopeChatConversation.fromMap(Map<String,dynamic>.from(raw['conversation'] as Map));
    final messages=(raw['messages'] as List).whereType<Map>().map((e)=>HopeChatMessage.fromMap(Map<String,dynamic>.from(e))).toList(growable:false);
    return HopeChatThread(conversation:conversation,messages:messages);
  }
  @override
  Future<HopeChatMessage> sendMessage(String conversationId,String message) async {
    final normalized=message.trim();
    if(normalized.isEmpty) throw const FormatException('Chat message must not be empty');
    final raw=await _api.request('POST','/messaging/conversations/$conversationId',auth:true,body:{'message':normalized});
    if(raw is! Map || raw['id']==null) throw const FormatException('Invalid chat response');
    return HopeChatMessage.fromMap(Map<String,dynamic>.from(raw));
  }
  @override
  Future<HopeChatMessage> sendMessageWithAttachments(String conversationId, String message, {required String messageType, required List<Map<String, String>> attachments}) async {
    final raw = await _api.request('POST', '/messaging/conversations/$conversationId', auth: true,
      body: {'message': message.trim(), 'messageType': messageType, 'attachments': attachments});
    if (raw is! Map || raw['id'] == null) throw const FormatException('Invalid chat response');
    return HopeChatMessage.fromMap(Map<String,dynamic>.from(raw));
  }
  @override
  Future<Map<String,dynamic>> uploadChatFile(File file) async {
    final raw = await _api.uploadFile('/storage/upload', file, auth: true);
    if (raw is! Map || raw['key'] == null) throw const FormatException('Invalid attachment upload response');
    return Map<String,dynamic>.from(raw);
  }
  @override
  Future<Uint8List> downloadAttachment(String downloadPath) => _api.downloadBytes(downloadPath, auth: true);
  @override
  Future<void> markRead(String conversationId) async {
    await _api.request('POST', '/messaging/conversations/$conversationId/read', auth: true, body: const {});
  }
  @override
  Future<void> updatePresence(String conversationId, {required bool online, required bool typing}) async {
    await _api.request('POST', '/messaging/conversations/$conversationId/presence', auth: true, body: {'online': online, 'typing': typing});
  }
  @override
  Future<List<HopeChatPresence>> listPresence(String conversationId) async {
    final raw = await _api.request('GET', '/messaging/conversations/$conversationId/presence', auth: true);
    if (raw is! Map || raw['items'] is! List) return const [];
    return (raw['items'] as List).whereType<Map>().map((e) => HopeChatPresence.fromMap(Map<String,dynamic>.from(e))).toList(growable:false);
  }
  @override
  Future<void> updatePreferences(String conversationId, {bool? isPinned, bool? isImportant, bool? isArchived}) async {
    final body = <String,bool>{};
    if (isPinned != null) body['isPinned'] = isPinned;
    if (isImportant != null) body['isImportant'] = isImportant;
    if (isArchived != null) body['isArchived'] = isArchived;
    await _api.request('PATCH', '/messaging/conversations/$conversationId/preferences', auth: true, body: body);
  }
}
