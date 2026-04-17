import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'download_service.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _keyDownloadPath = 'download_path';
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyShowWatermark = 'show_watermark';
  static const String _keyQuality = 'download_quality';
  static const String _keyAutoDownloadShare = 'auto_download_share';

  static const String defaultDownloadPath = '/storage/emulated/0/Download';
  static const String githubUrl = 'https://github.com/Alphared26/aio-downloader';
  static const String appVersion = '2.5.0';

  DownloadQuality _quality = DownloadQuality.auto;
  DownloadQuality get quality => _quality;

  bool _autoDownloadShare = true;
  bool get autoDownloadShare => _autoDownloadShare;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final qStr = prefs.getString(_keyQuality) ?? 'auto';
    _quality = DownloadQuality.values.firstWhere(
      (e) => e.name == qStr, 
      orElse: () => DownloadQuality.auto
    );
    _autoDownloadShare = prefs.getBool(_keyAutoDownloadShare) ?? true;
    notifyListeners();
  }

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
    notifyListeners();
  }

  Future<void> setQuality(DownloadQuality q) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyQuality, q.name);
    _quality = q;
    notifyListeners();
  }

  Future<void> setAutoDownloadShare(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoDownloadShare, enabled);
    _autoDownloadShare = enabled;
    notifyListeners();
  }
}
