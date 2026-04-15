import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadRecord {
  final String fileName;
  final String platform;
  final String filePath;
  final int timestamp;
  final int fileSize; // in bytes
  final String type; // 'video' or 'image'

  DownloadRecord({
    required this.fileName,
    required this.platform,
    required this.filePath,
    required this.timestamp,
    required this.fileSize,
    required this.type,
  });

  Map<String, dynamic> toMap() => {
    'fileName': fileName,
    'platform': platform,
    'filePath': filePath,
    'timestamp': timestamp,
    'fileSize': fileSize,
    'type': type,
  };

  factory DownloadRecord.fromMap(Map<String, dynamic> map) => DownloadRecord(
    fileName: map['fileName'] ?? '',
    platform: map['platform'] ?? 'unknown',
    filePath: map['filePath'] ?? '',
    timestamp: map['timestamp'] ?? 0,
    fileSize: map['fileSize'] ?? 0,
    type: map['type'] ?? 'video',
  );

  String get formattedSize {
    if (fileSize <= 0) return '';
    if (fileSize > 1024 * 1024) return '${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(fileSize / 1024).toStringAsFixed(0)} KB';
  }

  String get formattedDate {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes}m lalu';
    if (diff.inDays < 1) return '${diff.inHours}j lalu';
    if (diff.inDays < 7) return '${diff.inDays}h lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class HistoryService {
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  static const String _key = 'download_history';

  Future<List<DownloadRecord>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((e) {
      try {
        return DownloadRecord.fromMap(jsonDecode(e));
      } catch (_) {
        return null;
      }
    }).whereType<DownloadRecord>().toList();
  }

  Future<void> addRecord(DownloadRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.insert(0, jsonEncode(record.toMap()));
    // Keep max 200 records
    if (raw.length > 200) raw.removeLast();
    await prefs.setStringList(_key, raw);
  }

  Future<void> deleteRecord(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    if (index >= 0 && index < raw.length) {
      // First get the record to find the file path
      try {
        final record = DownloadRecord.fromMap(jsonDecode(raw[index]));
        final file = File(record.filePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
      
      raw.removeAt(index);
      await prefs.setStringList(_key, raw);
    }
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> deleteRecordByObject(DownloadRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    
    int foundIndex = -1;
    for (int i = 0; i < raw.length; i++) {
      try {
        final r = DownloadRecord.fromMap(jsonDecode(raw[i]));
        if (r.filePath == record.filePath && r.timestamp == record.timestamp) {
          foundIndex = i;
          break;
        }
      } catch (_) {}
    }

    if (foundIndex != -1) {
      // Delete file
      try {
        final file = File(record.filePath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
      
      raw.removeAt(foundIndex);
      await prefs.setStringList(_key, raw);
    }
  }
}
