import 'chat_repository.dart';

class SendChatMessageUseCase {
  const SendChatMessageUseCase(this.repository);
  final ChatRepository repository;
  Future<HopeChatMessage> call(String conversationId, String message) =>
      repository.sendMessage(conversationId, message);
}
