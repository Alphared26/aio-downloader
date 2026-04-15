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
  final ScrapedMedia sourceMedia;
  double progress; // 0.0 - 1.0
  int downloadedBytes;
  int totalBytes;
  bool isComplete;
  bool isError;
  bool isPaused;
  bool isCanceled;

  ActiveDownload({
    required this.id,
    required this.fileName,
    required this.platform,
    required this.type,
    required this.sourceMedia,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.isComplete = false,
    this.isError = false,
    this.isPaused = false,
    this.isCanceled = false,
  });
}

class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  bool _isStartingService = false;
  final List<ActiveDownload> activeDownloads = [];
  bool isScraping = false;
  String scrapingStatus = '';

  // Results for preview
  List<ScrapedMedia>? lastScrapedResults;
  Set<int> selectedMediaIndices = {};

  // Track active stream subscriptions
  final Map<String, StreamSubscription> _subscriptions = {};

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
    if (_isStartingService) return;
    if (await FlutterForegroundTask.isRunningService) return;
    
    _isStartingService = true;
    try {
      await FlutterForegroundTask.startService(
        serviceId: 200,
        notificationTitle: 'AIO Downloader',
        notificationText: 'Mengunduh media...',
        callback: startCallback,
      );
    } finally {
      _isStartingService = false;
    }
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

  void clearResults() {
    lastScrapedResults = null;
    selectedMediaIndices = {};
    notifyListeners();
  }

  void toggleSelection(int index) {
    if (selectedMediaIndices.contains(index)) {
      selectedMediaIndices.remove(index);
    } else {
      selectedMediaIndices.add(index);
    }
    notifyListeners();
  }

  void selectAll() {
    if (lastScrapedResults == null) return;
    for (int i = 0; i < lastScrapedResults!.length; i++) {
      selectedMediaIndices.add(i);
    }
    notifyListeners();
  }

  void deselectAll() {
    selectedMediaIndices.clear();
    notifyListeners();
  }

  /// Refactored: Scrape only, with optional auto-download
  Future<void> scrapeUrl(String url, DownloadQuality quality, {bool silentAutoDownload = false}) async {
    if (url.isEmpty) return;
    await _requestPermissions();

    isScraping = true;
    scrapingStatus = 'Mencari media...';
    lastScrapedResults = null;
    selectedMediaIndices = {};
    notifyListeners();

    try {
      String qualityStr = 'auto';
      if (quality == DownloadQuality.q720) qualityStr = 'q720';
      if (quality == DownloadQuality.q1080) qualityStr = 'q1080';

      final results = await AntiGravityEngine.extractVideoData(url, quality: qualityStr);

      if (results == null || results.isEmpty) {
        isScraping = false;
        scrapingStatus = '';
        notifyListeners();
        _emitStatus(DownloadStatusType.invalid, 'Media tidak ditemukan atau URL tidak valid');
        return;
      }

      lastScrapedResults = results;
      
      // Select all found results by default
      for (int i = 0; i < results.length; i++) {
        selectedMediaIndices.add(i);
      }

      // AUTO DOWNLOAD LOGIC: 
      // Only triggered if it's a share intent (silentAutoDownload: true)
      // and it's a single item (as per user preference).
      if (silentAutoDownload && results.length == 1) {
        isScraping = false;
        scrapingStatus = '';
        notifyListeners();
        _emitStatus(DownloadStatusType.success, 'Mulai mengunduh otomatis...');
        await downloadSelected();
        return;
      }
      
      isScraping = false;
      scrapingStatus = '';
      notifyListeners();
    } catch (e) {
      isScraping = false;
      scrapingStatus = '';
      notifyListeners();
      _emitStatus(DownloadStatusType.failure, 'Terjadi kesalahan saat mencari media');
    }
  }

  Future<void> downloadSelected() async {
    if (lastScrapedResults == null || selectedMediaIndices.isEmpty) return;
    
    final toDownload = selectedMediaIndices
        .map((i) => lastScrapedResults![i])
        .toList();
    
    // Clear results so UI goes back to download list
    lastScrapedResults = null;
    selectedMediaIndices = {};
    notifyListeners();

    await _startForegroundService();
    
    for (var media in toDownload) {
      await _downloadSingle(media);
    }
  }


  void pauseDownload(String id) {
    final download = activeDownloads.firstWhere((d) => d.id == id);
    download.isPaused = true;
    _subscriptions[id]?.cancel();
    _subscriptions.remove(id);
    notifyListeners();
  }

  Future<void> cancelDownload(String id) async {
    final download = activeDownloads.firstWhere((d) => d.id == id);
    download.isCanceled = true;
    _subscriptions[id]?.cancel();
    _subscriptions.remove(id);
    
    // Clean up partial file
    try {
      final downloadPath = await SettingsService().getDownloadPath();
      final file = File('${downloadPath}/${download.fileName}');
      if (await file.exists()) await file.delete();
    } catch (_) {}

    activeDownloads.removeWhere((d) => d.id == id);
    notifyListeners();
    
    if (activeDownloads.where((d) => !d.isComplete && !d.isError && !d.isPaused).isEmpty) {
      await _stopForegroundService();
    }
  }

  Future<void> resumeDownload(String id) async {
    final download = activeDownloads.firstWhere((d) => d.id == id);
    if (!download.isPaused) return;
    
    download.isPaused = false;
    download.isError = false;
    notifyListeners();
    
    await _startForegroundService();
    await _downloadSingle(download.sourceMedia, existingDownload: download);
  }


  Future<void> _downloadSingle(ScrapedMedia media, {ActiveDownload? existingDownload}) async {
    final notifId = _notifIdCounter++;
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2,'0')}-${now.month.toString().padLeft(2,'0')}-${now.year}';
    
    String cleanAuthor = media.author.replaceAll(RegExp(r'[^\w]'), '');
    if (cleanAuthor.isEmpty) cleanAuthor = 'user';
    
    // Check if it's a multi-item (has index suffix in ID like _1, _2)
    String fileName;
    if (media.id.contains('_')) {
      final parts = media.id.split('_');
      final index = parts.last;
      fileName = '${media.platform}_${cleanAuthor}_${index}_$dateStr${media.extension}';
    } else {
      fileName = '${media.platform}_${cleanAuthor}_$dateStr${media.extension}';
    }

    ActiveDownload download;
    if (existingDownload != null) {
      download = existingDownload;
    } else {
      download = ActiveDownload(
        id: fileName,
        fileName: fileName,
        platform: media.platform,
        type: media.type,
        sourceMedia: media,
      );
      activeDownloads.insert(0, download);
    }
    
    notifyListeners();

    try {
      final request = http.Request('GET', Uri.parse(media.url));
      request.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
      request.headers['Referer'] = 'https://www.google.com/';

      // Handle Resuming
      if (download.downloadedBytes > 0) {
        request.headers['Range'] = 'bytes=${download.downloadedBytes}-';
      }

      final streamedResponse = await request.send().timeout(const Duration(minutes: 10));

      // 206 means Partial Content (Success resume)
      // 200 means Server doesn't support Range or it's a new download
      if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 206) {
        throw Exception('Server returned ${streamedResponse.statusCode}');
      }

      bool isResume = streamedResponse.statusCode == 206;
      if (!isResume) {
        download.downloadedBytes = 0;
      }

      if (streamedResponse.contentLength != null) {
        download.totalBytes = isResume 
            ? download.downloadedBytes + streamedResponse.contentLength!
            : streamedResponse.contentLength!;
      }

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
      final sink = file.openWrite(mode: isResume ? FileMode.append : FileMode.write);

      final Completer<void> completer = Completer<void>();
      
      final subscription = streamedResponse.stream.listen(
        (chunk) async {
          sink.add(chunk);
          download.downloadedBytes += chunk.length;
          
          if (download.totalBytes > 0) {
            download.progress = download.downloadedBytes / download.totalBytes;
            notifyListeners();
            final percent = (download.progress * 100).toInt();
            await NotificationService().showProgress(notifId, fileName, percent);
          }
        },
        onError: (e) {
          sink.close();
          completer.completeError(e);
        },
        onDone: () async {
          await sink.flush();
          await sink.close();
          completer.complete();
        },
        cancelOnError: true,
      );

      _subscriptions[download.id] = subscription;

      await completer.future;
      _subscriptions.remove(download.id);

      if (download.isCanceled) return;

      // Gallery scan
      try { await MediaScanner.loadMedia(path: filePath); } catch (_) {}

      // Save to history
      await HistoryService().addRecord(DownloadRecord(
        fileName: fileName,
        platform: media.platform,
        filePath: filePath,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        fileSize: download.downloadedBytes,
        type: media.type,
      ));


      download.isComplete = true;
      download.progress = 1.0;
      notifyListeners();

      final fileSize = download.downloadedBytes > 0
          ? (download.downloadedBytes > 1024 * 1024
              ? '${(download.downloadedBytes / 1024 / 1024).toStringAsFixed(1)} MB'
              : '${(download.downloadedBytes / 1024).toStringAsFixed(0)} KB')
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
