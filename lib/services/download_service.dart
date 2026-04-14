import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:http/http.dart' as http;
import 'package:media_scanner/media_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../scraper_engine.dart';
import 'history_service.dart';
import 'notification_service.dart';
import 'settings_service.dart';

enum DownloadQuality { auto, q720, q1080 }

enum DownloadStatusType { success, failure, invalid }

class DownloadStatusEvent {
  final DownloadStatusType type;
  final String message;
  DownloadStatusEvent({required this.type, required this.message});
}

class ActiveDownload {
  final String id; 
  final String fileName;
  final String platform;
  final String type;
  double progress; // 0.0 - 1.0
  bool isComplete;
  bool isError;

  ActiveDownload({
    required this.id,
    required this.fileName,
    required this.platform,
    required this.type,
    this.progress = 0.0,
    this.isComplete = false,
    this.isError = false,
  });
}

class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final List<ActiveDownload> activeDownloads = [];
  bool isScraping = false;
  String scrapingStatus = '';

  // Stream for UI popup messages
  final _statusController = StreamController<DownloadStatusEvent>.broadcast();
  Stream<DownloadStatusEvent> get statusStream => _statusController.stream;

  void _emitStatus(DownloadStatusType type, String message) {
    _statusController.add(DownloadStatusEvent(type: type, message: message));
  }

  static int _notifIdCounter = 1000;

  /// Inisialisasi foreground task service
  static void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'aio_foreground',
        channelName: 'AIO Downloader Service',
        channelDescription: 'Menjaga unduhan tetap berjalan di latar belakang',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> _startForegroundService() async {
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: 200,
      notificationTitle: 'AIO Downloader',
      notificationText: 'Mengunduh media...',
      callback: startCallback,
    );
  }

  Future<void> _stopForegroundService() async {
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.stopService();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt <= 32) {
        await Permission.storage.request();
      } else {
        await Permission.manageExternalStorage.request();
        await Permission.photos.request();
        await Permission.videos.request();
      }
    }
  }

  /// Main entry: scrape + download from a shared URL
  Future<void> processUrl(String url, DownloadQuality quality) async {
    if (url.isEmpty) return;
    await _requestPermissions();

    isScraping = true;
    scrapingStatus = 'Mencari media...';
    notifyListeners();

    try {
      await _startForegroundService();

      final results = await AntiGravityEngine.extractVideoData(url);

      if (results == null || results.isEmpty) {
        isScraping = false;
        scrapingStatus = '';
        notifyListeners();
        _emitStatus(DownloadStatusType.invalid, 'Media tidak ditemukan atau URL tidak valid');
        await _stopForegroundService();
        return;
      }

      isScraping = false;
      scrapingStatus = '';
      notifyListeners();

      for (var media in results) {
        await _downloadSingle(media);
      }
    } catch (e) {
      isScraping = false;
      scrapingStatus = '';
      notifyListeners();
    } finally {
      if (activeDownloads.every((d) => d.isComplete || d.isError)) {
        await Future.delayed(const Duration(seconds: 2));
        await _stopForegroundService();
      }
    }
  }

  Future<void> _downloadSingle(ScrapedMedia media) async {
    final notifId = _notifIdCounter++;
    
    String cleanAuthor = media.author.replaceAll(RegExp(r'[^\w]'), '');
    if (cleanAuthor.isEmpty) cleanAuthor = 'user';
    final fileName = '${media.platform}_${cleanAuthor}_${media.id}${media.extension}';

    final download = ActiveDownload(
      id: fileName,
      fileName: fileName,
      platform: media.platform,
      type: media.type,
    );
    activeDownloads.insert(0, download);
    notifyListeners();

    try {
      final request = http.Request('GET', Uri.parse(media.url));
      request.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      request.headers['Referer'] = 'https://www.google.com/';

      final streamedResponse = await request.send().timeout(const Duration(minutes: 10));

      final contentLength = streamedResponse.contentLength ?? 0;
      final downloadPath = await SettingsService().getDownloadPath();
      
      Directory downloadDir = Directory(downloadPath);
      if (!await downloadDir.exists()) {
        try { await downloadDir.create(recursive: true); } catch (_) {
          final base = await getExternalStorageDirectory();
          if (base != null) downloadDir = base;
        }
      }

      final filePath = '${downloadDir.path}/$fileName';
      final file = File(filePath);
      final sink = file.openWrite();

      int downloaded = 0;
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0) {
          download.progress = downloaded / contentLength;
          notifyListeners();
          final percent = (download.progress * 100).toInt();
          await NotificationService().showProgress(notifId, fileName, percent);
        }
      }
      await sink.flush();
      await sink.close();

      // Gallery scan
      try { await MediaScanner.loadMedia(path: filePath); } catch (_) {}

      // Save to history
      await HistoryService().addRecord(DownloadRecord(
        fileName: fileName,
        platform: media.platform,
        filePath: filePath,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        fileSize: downloaded,
        type: media.type,
      ));

      download.isComplete = true;
      download.progress = 1.0;
      notifyListeners();

      final fileSize = downloaded > 0
          ? (downloaded > 1024 * 1024
              ? '${(downloaded / 1024 / 1024).toStringAsFixed(1)} MB'
              : '${(downloaded / 1024).toStringAsFixed(0)} KB')
          : '';
      await NotificationService().showComplete(notifId, fileName, fileSize);
      _emitStatus(DownloadStatusType.success, '✓ Tersimpan: $fileName${fileSize.isNotEmpty ? " · $fileSize" : ""}');
    } catch (e) {
      download.isError = true;
      notifyListeners();
      await NotificationService().showError(notifId, fileName);
      _emitStatus(DownloadStatusType.failure, '✗ Gagal mengunduh: $fileName');
    }

    // Auto-remove from active list after 5 seconds
    await Future.delayed(const Duration(seconds: 5));
    activeDownloads.removeWhere((d) => d.id == download.id);
    notifyListeners();
  }
}

/// Foreground task callback (required to be top-level)
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(AioForegroundHandler());
}

class AioForegroundHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}
