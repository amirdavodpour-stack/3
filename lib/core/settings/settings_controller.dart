import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LocationFailureReason {
  serviceDisabled,
  permissionDenied,
  positionUnavailable,
  unsupportedPlatform,
}

class HopeSettingsController extends ChangeNotifier {
  static const _languageKey = 'language';
  static const _themeKey = 'theme';
  static const _cityKey = 'city';
  static const _locationKey = 'locationEnabled';
  static const _notificationsKey = 'notifications';
  static const _recommendationsKey = 'personalizedRecommendations';
  static const _quietKey = 'quietHours';
  static const _compactKey = 'compactCards';
  static const _latitudeKey = 'locationLatitude';
  static const _longitudeKey = 'locationLongitude';

  SharedPreferences? _prefs;
  String _language = 'fa';
  String _theme = 'dark';
  String _city = 'تهران';
  bool _locationEnabled = false;
  bool _notifications = true;
  bool _personalizedRecommendations = true;
  bool _quietHours = false;
  bool _compactCards = false;
  double? _latitude;
  double? _longitude;
  bool _loading = true;
  bool _locationBusy = false;
  int _locationRequestId = 0;
  LocationFailureReason? _lastLocationFailure;

  Future<void> Function(LocationFailureReason reason, Object? error,
      StackTrace? stack)? onLocationFailure;

  bool get isLoading => _loading;
  String get language => _language;
  String get theme => _theme;
  String get city => _city;
  bool get locationEnabled => _locationEnabled;
  bool get notifications => _notifications;
  bool get personalizedRecommendations => _personalizedRecommendations;
  bool get quietHours => _quietHours;
  bool get compactCards => _compactCards;
  bool get locationBusy => _locationBusy;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  LocationFailureReason? get lastLocationFailure => _lastLocationFailure;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _language = _prefs!.getString(_languageKey) ?? 'fa';
    _theme = _prefs!.getString(_themeKey) ?? 'dark';
    _city = _prefs!.getString(_cityKey) ?? 'تهران';
    _locationEnabled = _prefs!.getBool(_locationKey) ?? false;
    _notifications = _prefs!.getBool(_notificationsKey) ?? true;
    _personalizedRecommendations = _prefs!.getBool(_recommendationsKey) ?? true;
    _quietHours = _prefs!.getBool(_quietKey) ?? false;
    _compactCards = _prefs!.getBool(_compactKey) ?? false;
    _latitude = _prefs!.getDouble(_latitudeKey);
    _longitude = _prefs!.getDouble(_longitudeKey);
    _loading = false;
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    _language = value == 'en' ? 'en' : 'fa';
    await _prefs?.setString(_languageKey, _language);
    notifyListeners();
  }

  Future<void> setTheme(String value) async {
    _theme = {'system', 'light', 'dark'}.contains(value) ? value : 'system';