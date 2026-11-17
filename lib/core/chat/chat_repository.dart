import '../network/api_client.dart';

class HopeChatConversation {
  const HopeChatConversation({required this.id, required this.kind, required this.jobId, required this.status, required this.title, required this.otherUserName});
  final String id, kind, jobId, status, title, otherUserName;
  factory HopeChatConversation.fromMap(Map<String,dynamic> m)=>HopeChatConversation(id:'${m['id']??''}',kind:'${m['kind']??''}',jobId:'${m['jobId']??''}',status:'${m['status']??'CLOSED'}',title:'${m['title']??''}',otherUserName:'${m['otherUserName']??''}');
}

class HopeChatMessage {
  const HopeChatMessage({required this.id, required this.conversationId, required this.senderId, required this.senderName, required this.body, required this.createdAt});
  final String id, conversationId, senderId, senderName, body;
  final DateTime createdAt;
  factory HopeChatMessage.fromMap(Map<String,dynamic> m)=>HopeChatMessage(id:'${m['id']??''}',conversationId:'${m['conversationId']??''}',senderId:'${m['senderId']??''}',senderName:'${m['senderName']??''}',body:'${m['body']??''}',createdAt:DateTime.tryParse('${m['createdAt']??''}')??DateTime.fromMillisecondsSinceEpoch(0));
}

class HopeChatThread {
  const HopeChatThread({required this.conversation, required this.messages});
  final HopeChatConversation conversation;
  final List<HopeChatMessage> messages;
}

abstract interface class ChatRepository {
  Future<List<HopeChatConversation>> listConversations();
  Future<HopeChatThread> getMessages(String conversationId);
  Future<HopeChatMessage> sendMessage(String conversationId, String message);
}

class ApiChatRepository implements ChatRepository {
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
}