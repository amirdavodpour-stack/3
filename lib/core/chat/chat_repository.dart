import '../network/api_client.dart';

abstract interface class ChatRepository {
  Future<String> sendMessage(String message);
}

class ApiChatRepository implements ChatRepository {
  const ApiChatRepository(this._api);

  final ApiClient _api;

  @override
  Future<String> sendMessage(String message) async {
    final normalized = message.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Chat message must not be empty');
    }

    final data = await _api.request(
      'POST',
      '/chat',
      auth: true,
      body: {'message': normalized},
    );

    if (data is! Map || data['answer'] is! String) {
      throw const FormatException('Invalid chat response');
    }

    final answer = (data['answer'] as String).trim();
    if (answer.isEmpty) {
      throw const FormatException('Chat response was empty');
    }
    return answer;
  }
}
