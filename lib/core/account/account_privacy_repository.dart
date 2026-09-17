import '../network/api_client.dart';

class AccountPrivacyRepository {
  AccountPrivacyRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> exportData() async {
    final data = await _api.request('GET', '/account/export', auth: true);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> deleteAccount() async {
    await _api.request(
      'POST',
      '/account/delete',
      auth: true,
      body: const {'confirmation': 'DELETE'},
    );
  }
}
