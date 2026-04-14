import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';

import '../services/history_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _historyService = HistoryService();
  List<DownloadRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    _records = await _historyService.getHistory();
    setState(() => _isLoading = false);
  }

  Color _platformColor(String platform) {
    switch (platform) {
      case 'instagram': return const Color(0xFFE1306C);
      case 'tiktok': return const Color(0xFF69C9D0);
      case 'facebook': return const Color(0xFF1877F2);
      case 'youtube': return const Color(0xFFFF0000);
      default: return const Color(0xFF4D8EFF);
    }
  }

  IconData _platformIcon(String platform) {
    switch (platform) {
      case 'instagram': return Icons.camera_alt_rounded;
      case 'tiktok': return Icons.music_note_rounded;
      case 'facebook': return Icons.facebook_rounded;
      case 'youtube': return Icons.play_circle_rounded;
      default: return Icons.download_rounded;
    }
  }

  Future<void> _deleteRecord(int index) async {
    await _historyService.deleteRecord(index);
    await _loadHistory();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Semua Riwayat',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('Tindakan ini tidak dapat dibatalkan.',
          style: GoogleFonts.inter(color: Colors.white54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.inter(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text('Hapus Semua', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _historyService.clearAll();
      await _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
          child: Row(
            children: [
              Text('${_records.length} File',
                style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.white38,
                )),
              const Spacer(),
              if (_records.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: Text('Hapus Semua', style: GoogleFonts.inter(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF4D8EFF))))
              : _records.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      color: const Color(0xFF4D8EFF),
                      backgroundColor: const Color(0xFF1A1A2E),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _records.length,
                        itemBuilder: (ctx, i) => _buildItem(i),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildItem(int index) {
    final r = _records[index];

    void openFile() async {
      final file = File(r.filePath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text('File tidak ditemukan di: ${r.filePath}',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white))),
                ],
              ),
              backgroundColor: const Color(0xFF3A2A1A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(12),
            ),
          );
        }
        return;
      }
      final result = await OpenFile.open(r.filePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak ada aplikasi untuk membuka file ini',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
            backgroundColor: const Color(0xFF2A2A2A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(12),
          ),
        );
      }
    }

    return Dismissible(
      key: Key('$index-${r.fileName}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.redAccent.withAlpha(38),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent.withAlpha(80)),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 22),
      ),
      onDismissed: (_) => _deleteRecord(index),
      child: GestureDetector(
        onTap: openFile,
        child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF111120),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A2A3E), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _platformColor(r.platform).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_platformIcon(r.platform),
                color: _platformColor(r.platform), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.fileName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(r.formattedDate,
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
                      if (r.formattedSize.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(width: 3, height: 3,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: Colors.white24)),
                        const SizedBox(width: 8),
                        Text(r.formattedSize,
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              r.type == 'video' ? Icons.videocam_rounded : Icons.image_rounded,
              color: Colors.white24, size: 16,
            ),
          ],
        ),
      ),      // Container
      ),      // GestureDetector
    );        // Dismissible
  }


  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, size: 64, color: Colors.white12),
          const SizedBox(height: 16),
          Text('Belum Ada Riwayat',
            style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white30)),
          const SizedBox(height: 8),
          Text('File yang berhasil diunduh akan muncul di sini',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white24)),
        ],
      ),
    );
  }
}
