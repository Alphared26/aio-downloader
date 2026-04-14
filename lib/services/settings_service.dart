import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _keyDownloadPath = 'download_path';
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyShowWatermark = 'show_watermark';

  static const String defaultDownloadPath = '/storage/emulated/0/Download';
  static const String githubUrl = 'https://github.com/Alphared26';
  static const String appVersion = '2.0.0';

  Future<String> getDownloadPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDownloadPath) ?? defaultDownloadPath;
  }

  Future<void> setDownloadPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDownloadPath, path);
  }

  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationsEnabled) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationsEnabled, enabled);
  }

  Future<bool> getShowWatermark() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShowWatermark) ?? true;
  }

  Future<void> setShowWatermark(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowWatermark, show);
  }
}
