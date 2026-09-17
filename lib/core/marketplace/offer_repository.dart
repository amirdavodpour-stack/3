import '../network/api_client.dart';
import 'application.dart';

abstract interface class OfferRepository {
  Future<List<HopeOffer>> listForJob(String jobId);
  Future<List<HopeOffer>> listMine();
  Future<HopeOffer> get(String offerId);
  Future<HopeOffer> submit(String jobId, {required String price, String message = ''});
  Future<Map<String, dynamic>> accept(String offerId);
}

class ApiOfferRepository implements OfferRepository {
  const ApiOfferRepository(this._api);
  final ApiClient _api;

  List<HopeOffer> _items(dynamic raw) {
    final value = raw is Map && raw['items'] is List ? raw['items'] : raw;
    if (value is! List) return const [];
    return value.whereType<Map>().map((m) => HopeOffer.fromMap(Map<String,dynamic>.from(m))).toList(growable:false);
  }

  @override
  Future<List<HopeOffer>> listForJob(String jobId) async =>
      _items(await _api.request('GET', '/offers?jobId=${Uri.encodeQueryComponent(jobId)}', auth:true));

  @override
  Future<List<HopeOffer>> listMine() async =>
      _items(await _api.request('GET', '/offers/mine', auth:true));

  @override
  Future<HopeOffer> get(String offerId) async =>
      HopeOffer.fromMap(Map<String,dynamic>.from(await _api.request('GET', '/offers/${Uri.encodeComponent(offerId)}', auth:true) as Map));

  @override
  Future<HopeOffer> submit(String jobId, {required String price, String message=''}) async =>
      HopeOffer.fromMap(Map<String,dynamic>.from(await _api.request('POST','/offers',auth:true,body:{
        'jobId':jobId,'price':price.trim(),'message':message.trim()
      }) as Map));

  @override
  Future<Map<String,dynamic>> accept(String offerId) async =>
      Map<String,dynamic>.from(await _api.request('POST','/offers/${Uri.encodeComponent(offerId)}/accept',auth:true) as Map);
}
