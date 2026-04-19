import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import 'history_service.dart';
import 'settings_service.dart';

/// Method channel for SAF operations
const _safChannel = MethodChannel('com.aio_downloader/saf');

class WhatsAppStatus {
  final String name;
  final String path; // Absolute file path (direct mode) or empty (SAF mode)
  final String? uri; // SAF content URI (SAF mode only)
  final String type; // 'image' or 'video'
  final int size;

  WhatsAppStatus({
    required this.name,
    required this.path,
    this.uri,
    required this.type,
    required this.size,
  });

  /// Whether this status was loaded via SAF
  bool get isSaf => uri != null && uri!.isNotEmpty;
}

enum AccessMode { none, direct, saf }

class StatusService extends ChangeNotifier {
  static final StatusService _instance = StatusService._internal();
  factory StatusService() => _instance;
  StatusService._internal();

  // Known WhatsApp status directories
  static const List<String> _statusPaths = [
    '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses',
    '/storage/emulated/0/WhatsApp/Media/.Statuses',
  ];

  List<WhatsAppStatus> images = [];
  List<WhatsAppStatus> videos = [];
  bool isLoading = false;
  bool hasPermission = false;
  AccessMode accessMode = AccessMode.none;
  String? _activeStatusDir;
  String? _safTreeUri;

  // ──────────────────────────────────────
  //  PERMISSION: Try direct first, then SAF
  // ──────────────────────────────────────

  /// Check if we already have access (direct or SAF)
  Future<bool> checkPermission() async {
    if (!Platform.isAndroid) return false;

    // 1. Check if direct file access works
    if (await _tryDirectAccess()) {
      accessMode = AccessMode.direct;
      hasPermission = true;
      notifyListeners();
      return true;
    }

    // 2. Check if we have persisted SAF permissions
    if (await _checkSafPersisted()) {
      accessMode = AccessMode.saf;
      hasPermission = true;
      notifyListeners();
      return true;
    }

    hasPermission = false;
    notifyListeners();
    return false;
  }

  /// Request MANAGE_EXTERNAL_STORAGE permission (primary method)
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 30) {
      final status = await Permission.manageExternalStorage.request();
      if (status.isGranted) {
        final dir = await _findStatusDirectory();
        if (dir != null) {
          _activeStatusDir = dir;
          accessMode = AccessMode.direct;
          hasPermission = true;
          notifyListeners();
          return true;
        }
      }
    } else {
      final status = await Permission.storage.request();
      if (status.isGranted) {
        final dir = await _findStatusDirectory();
        if (dir != null) {
          _activeStatusDir = dir;
          accessMode = AccessMode.direct;
          hasPermission = true;
          notifyListeners();
          return true;
        }
      }
    }

    return false;
  }

  /// Request SAF folder access (backup method — user manually picks folder)
  Future<bool> requestSafPermission() async {
    try {
      final result = await _safChannel.invokeMethod('openDocumentTree');
      if (result != null && result is String) {
        _safTreeUri = result;
        accessMode = AccessMode.saf;
        hasPermission = true;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[StatusService] SAF request error: $e');
    }
    return false;
  }

  // ──────────────────────────────────────
  //  INTERNAL PERMISSION HELPERS
  // ──────────────────────────────────────

  Future<bool> _tryDirectAccess() async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    bool granted;
    if (sdkInt >= 30) {
      granted = await Permission.manageExternalStorage.isGranted;
    } else {
      granted = await Permission.storage.isGranted;
    }

    if (granted) {
      final dir = await _findStatusDirectory();
      if (dir != null) {
        _activeStatusDir = dir;
        return true;
      }
    }
    return false;
  }

  Future<bool> _checkSafPersisted() async {
    try {
      final result = await _safChannel.invokeMethod('getPersistedPermissions');
      if (result != null && result is List) {
        for (final uri in result) {
          if (uri.toString().contains('com.whatsapp') || 
              uri.toString().contains('WhatsApp')) {
            _safTreeUri = uri.toString();
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('[StatusService] SAF persisted check error: $e');
    }
    return false;
  }

  Future<String?> _findStatusDirectory() async {
    for (final path in _statusPaths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        debugPrint('[StatusService] Found status dir: $path');
        return path;
      }
    }
    return null;
  }

  // ──────────────────────────────────────
  //  FETCH STATUSES
  // ──────────────────────────────────────

  Future<void> fetchStatuses() async {
    if (!hasPermission) return;

    isLoading = true;
    notifyListeners();

    images.clear();
    videos.clear();

    try {
      if (accessMode == AccessMode.direct) {
        await _fetchDirect();
      } else if (accessMode == AccessMode.saf) {
        await _fetchSaf();
      }
      debugPrint('[StatusService] Found ${images.length} images, ${videos.length} videos (mode: $accessMode)');
    } catch (e) {
      debugPrint('[StatusService] Error fetching statuses: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch using direct file system access
  Future<void> _fetchDirect() async {
    _activeStatusDir ??= await _findStatusDirectory();
    if (_activeStatusDir == null) return;

    final dir = Directory(_activeStatusDir!);
    if (!await dir.exists()) return;

    final entities = await dir.list().toList();
    final List<MapEntry<WhatsAppStatus, DateTime>> sorted = [];

    for (var entity in entities) {
      if (entity is File) {
        final name = entity.path.split('/').last;
        if (name.startsWith('.')) continue;

        final stat = await entity.stat();
        final isImage = name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png');
        final isVideo = name.endsWith('.mp4');

        if (isImage || isVideo) {
          final status = WhatsAppStatus(
            name: name,
            path: entity.path,
            type: isImage ? 'image' : 'video',
            size: stat.size,
          );
          sorted.add(MapEntry(status, stat.modified));
        }
      }
    }

    // Sort newest first
    sorted.sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sorted) {
      if (entry.key.type == 'image') {
        images.add(entry.key);
      } else {
        videos.add(entry.key);
      }
    }
  }

  /// Fetch using SAF (Storage Access Framework)
  Future<void> _fetchSaf() async {
    if (_safTreeUri == null) return;

    try {
      final result = await _safChannel.invokeMethod('listFiles', {'uri': _safTreeUri});
      if (result != null && result is List) {
        for (final item in result) {
          final map = Map<String, dynamic>.from(item);
          final status = WhatsAppStatus(
            name: map['name'] ?? '',
            path: '', // No direct path in SAF mode
            uri: map['uri'],
            type: map['type'] ?? 'image',
            size: (map['size'] ?? 0).toInt(),
          );

          if (status.type == 'image') {
            images.add(status);
          } else {
            videos.add(status);
          }
        }
      }
    } catch (e) {
      debugPrint('[StatusService] SAF fetch error: $e');
    }
  }

  // ──────────────────────────────────────
  //  READ FILE (for SAF preview)
  // ──────────────────────────────────────

  /// Read file bytes from SAF URI
  Future<Uint8List?> readSafFile(String uri) async {
    try {
      final result = await _safChannel.invokeMethod('readFile', {'uri': uri});
      if (result != null && result is Uint8List) {
        return result;
      }
    } catch (e) {
      debugPrint('[StatusService] SAF read error: $e');
    }
    return null;
  }

  /// Get video thumbnail from SAF URI
  Future<Uint8List?> getVideoThumbnailFromUri(String uri) async {
    try {
      final result = await _safChannel.invokeMethod('getVideoThumbnailFromUri', {'uri': uri});
      if (result != null && result is Uint8List) {
        return result;
      }
    } catch (e) {
      debugPrint('[StatusService] SAF thumbnail error: $e');
    }
    return null;
  }

  // ──────────────────────────────────────
  //  SAVE STATUS
  // ──────────────────────────────────────

  Future<bool> saveStatus(WhatsAppStatus status) async {
    try {
      Uint8List? bytes;

      if (status.isSaf) {
        // SAF mode: read bytes via method channel
        bytes = await readSafFile(status.uri!);
        if (bytes == null || bytes.isEmpty) return false;
      } else {
        // Direct mode: read from file
        final sourceFile = File(status.path);
        if (!await sourceFile.exists()) return false;
        bytes = await sourceFile.readAsBytes();
      }

      // Determine save directory
      final settings = SettingsService();
      final downloadPath = await settings.getDownloadPath();
      final saveDir = Directory('$downloadPath/WhatsApp Status');
      if (!await saveDir.exists()) await saveDir.create(recursive: true);

      // Build unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = status.name.contains('.') ? status.name.split('.').last : 'jpg';
      final fileName = 'WA_Status_$timestamp.$ext';
      final destPath = '${saveDir.path}/$fileName';

      // Write file
      final file = File(destPath);
      await file.writeAsBytes(bytes);

      // Scan into gallery
      MediaScanner.loadMedia(path: destPath);

      // Add to HistoryService
      final record = DownloadRecord(
        fileName: fileName,
        platform: 'whatsapp',
        filePath: destPath,
        timestamp: timestamp,
        fileSize: bytes.length,
        type: status.type,
      );
      await HistoryService().addRecord(record);

      return true;
    } catch (e) {
      debugPrint('[StatusService] Error saving status: $e');
    }
    return false;
  }
}
