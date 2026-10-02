import '../chat/chat_repository.dart';

class SendChatMessageUseCase {
  const SendChatMessageUseCase(this.repository);

  final ChatRepository repository;

  Future<String> call(String message) => repository.sendMessage(message);
}
