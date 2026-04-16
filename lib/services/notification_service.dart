import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'settings_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String _channelId = 'aio_downloads';
  static const String _channelName = 'AIO Downloader';
  static const String _channelDesc = 'Notifikasi unduhan AIO Downloader';

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
          ));
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  Future<bool> _isEnabled() async => await SettingsService().getNotificationsEnabled();

  /// Tampilkan notifikasi progres download (0-100)
  Future<void> showProgress(int id, String fileName, int progress) async {
    if (!await _isEnabled()) return;
    await _plugin.show(
      id,
      'Mengunduh...',
      '$fileName · $progress%',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.low,
          priority: Priority.low,
          showProgress: true,
          maxProgress: 100,
          progress: progress,
          onlyAlertOnce: true,
          ongoing: true,
          enableVibration: false,
        ),
      ),
    );
  }

  /// Notifikasi selesai download
  Future<void> showComplete(int id, String fileName, String fileSize) async {
    if (!await _isEnabled()) return;
    await _plugin.show(
      id,
      '✓ Unduhan Selesai',
      '$fileName${fileSize.isNotEmpty ? ' · $fileSize' : ''}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          enableVibration: true,
        ),
      ),
    );
  }

  /// Notifikasi error
  Future<void> showError(int id, String fileName) async {
    if (!await _isEnabled()) return;
    await _plugin.show(
      id,
      '✗ Gagal Mengunduh',
      fileName,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Hapus notifikasi
  Future<void> cancel(int id) async => await _plugin.cancel(id);
  Future<void> cancelAll() async => await _plugin.cancelAll();
}
