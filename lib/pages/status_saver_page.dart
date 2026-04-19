import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/status_service.dart';

/// Method channel for native video thumbnail extraction
const _thumbnailChannel = MethodChannel('com.aio_downloader/thumbnail');
const _safChannel = MethodChannel('com.aio_downloader/saf');

/// In-memory cache for video thumbnails
final Map<String, Uint8List> _thumbnailCache = {};

class StatusSaverPage extends StatefulWidget {
  const StatusSaverPage({super.key});

  @override
  State<StatusSaverPage> createState() => _StatusSaverPageState();
}

class _StatusSaverPageState extends State<StatusSaverPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasPermission = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    setState(() => _isChecking = true);
    final svc = context.read<StatusService>();
    final has = await svc.checkPermission();
    setState(() {
      _hasPermission = has;
      _isChecking = false;
    });
    if (has) {
      svc.fetchStatuses();
    }
  }

  Future<void> _requestPermission() async {
    final svc = context.read<StatusService>();
    final success = await svc.requestPermission();
    if (success) {
      setState(() => _hasPermission = true);
      svc.fetchStatuses();
    }
  }

  Future<void> _requestSafPermission() async {
    final svc = context.read<StatusService>();
    final success = await svc.requestSafPermission();
    if (success) {
      setState(() => _hasPermission = true);
      svc.fetchStatuses();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StatusService>(
      builder: (context, svc, _) {
        return Column(
          children: [
            _buildTabHeader(),
            Expanded(
              child: _isChecking 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF4D8EFF)))
                : !_hasPermission 
                  ? _buildPermissionGate()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildStatusGrid(svc.images, 'image', svc),
                        _buildStatusGrid(svc.videos, 'video', svc),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF111120),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A3E), width: 1),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [Color(0xFF4D8EFF), Color(0xFFA855F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white24,
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
        tabs: const [
          Tab(text: 'Foto'),
          Tab(text: 'Video'),
        ],
      ),
    );
  }

  Widget _buildPermissionGate() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF25D366).withOpacity(0.15),
                    const Color(0xFF25D366).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3)),
              ),
              child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 56),
            ),
            const SizedBox(height: 24),
            Text('Status Saver',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              'Simpan foto & video dari\nstatus WhatsApp temanmu',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white38, height: 1.5),
            ),
            const SizedBox(height: 28),
            
            // ── Option 1: Direct Access ──
            _buildPermissionCard(
              icon: Icons.security_rounded,
              iconColor: const Color(0xFF4D8EFF),
              title: 'Izin Akses Semua File',
              subtitle: 'Direkomendasikan — akses otomatis',
              buttonText: 'Beri Izin',
              buttonColor: const Color(0xFF25D366),
              onPressed: _requestPermission,
            ),

            const SizedBox(height: 12),

            // Divider with "atau"
            Row(
              children: [
                Expanded(child: Container(height: 1, color: const Color(0xFF2A2A3E))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('atau', 
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white24)),
                ),
                Expanded(child: Container(height: 1, color: const Color(0xFF2A2A3E))),
              ],
            ),

            const SizedBox(height: 12),

            // ── Option 2: SAF Picker (Backup) ──
            _buildPermissionCard(
              icon: Icons.folder_open_rounded,
              iconColor: const Color(0xFFFFA726),
              title: 'Pilih Folder Manual',
              subtitle: 'Arahkan ke folder WhatsApp Media',
              buttonText: 'Pilih Folder',
              buttonColor: const Color(0xFFFFA726),
              onPressed: _requestSafPermission,
              isSecondary: true,
            ),

            const SizedBox(height: 20),

            // Hint text
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF111120),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1A1A2E)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.white24, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Jika opsi pertama tidak berhasil, pilih folder manual:\nAndroid > media > com.whatsapp > WhatsApp > Media',
                      style: GoogleFonts.inter(fontSize: 10, color: Colors.white24, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String buttonText,
    required Color buttonColor,
    required VoidCallback onPressed,
    bool isSecondary = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111120),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSecondary ? const Color(0xFF2A2A3E) : iconColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isSecondary ? buttonColor.withOpacity(0.15) : buttonColor,
                foregroundColor: isSecondary ? buttonColor : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(buttonText, 
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusGrid(List<WhatsAppStatus> list, String type, StatusService svc) {
    if (list.isEmpty) {
      if (svc.isLoading) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFF4D8EFF)));
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(type == 'image' ? Icons.photo_library_outlined : Icons.video_library_outlined, 
              size: 50, color: Colors.white10),
            const SizedBox(height: 16),
            Text('Tidak ada status ditemukan', 
              style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Buka WhatsApp dan lihat status teman',
              style: GoogleFonts.inter(color: Colors.white12, fontSize: 11)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => svc.fetchStatuses(),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text('Segarkan', style: GoogleFonts.inter(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => svc.fetchStatuses(),
      color: const Color(0xFF4D8EFF),
      backgroundColor: const Color(0xFF1A1A2E),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: list.length,
        itemBuilder: (context, index) => _buildStatusCard(list[index], svc),
      ),
    );
  }

  Widget _buildStatusCard(WhatsAppStatus item, StatusService svc) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111120),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A3E), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Preview
            _buildPreview(item, svc),
            
            // Type Badge
            Positioned(
              top: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.type == 'video' ? Icons.videocam_rounded : Icons.image_rounded,
                      color: Colors.white70, size: 12,
                    ),
                    if (item.size > 0) ...[
                      const SizedBox(width: 4),
                      Text(_formatSize(item.size),
                        style: GoogleFonts.inter(fontSize: 9, color: Colors.white54, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom overlay with save button
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 20, 8, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 10, color: Colors.white60),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _saveButton(item, svc),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the appropriate preview widget based on access mode
  Widget _buildPreview(WhatsAppStatus item, StatusService svc) {
    if (item.type == 'image') {
      if (item.isSaf) {
        // SAF mode: load image bytes via channel
        return _safImagePreview(item, svc);
      } else {
        // Direct mode: load from file
        return Image.file(File(item.path), fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(item));
      }
    } else {
      // Video: show thumbnail
      return _videoThumbnail(item, svc);
    }
  }

  /// Image preview for SAF items
  Widget _safImagePreview(WhatsAppStatus item, StatusService svc) {
    final cacheKey = 'img_${item.uri}';
    if (_thumbnailCache.containsKey(cacheKey)) {
      return Image.memory(_thumbnailCache[cacheKey]!, fit: BoxFit.cover);
    }

    return FutureBuilder<Uint8List?>(
      future: svc.readSafFile(item.uri!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          _thumbnailCache[cacheKey] = snapshot.data!;
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }
        return _placeholder(item);
      },
    );
  }

  /// Video thumbnail for both direct and SAF modes
  Widget _videoThumbnail(WhatsAppStatus item, StatusService svc) {
    final cacheKey = item.isSaf ? 'vid_${item.uri}' : 'vid_${item.path}';
    
    if (_thumbnailCache.containsKey(cacheKey)) {
      return _videoThumbWithOverlay(_thumbnailCache[cacheKey]!);
    }

    return FutureBuilder<Uint8List?>(
      future: item.isSaf 
        ? svc.getVideoThumbnailFromUri(item.uri!)
        : _getVideoThumbnail(item.path),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          _thumbnailCache[cacheKey] = snapshot.data!;
          return _videoThumbWithOverlay(snapshot.data!);
        }
        return Container(
          color: const Color(0xFF0A0A15),
          child: const Center(
            child: Icon(Icons.play_circle_filled_rounded, color: Colors.white24, size: 44),
          ),
        );
      },
    );
  }

  Widget _videoThumbWithOverlay(Uint8List bytes) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(bytes, fit: BoxFit.cover),
        Center(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  Widget _placeholder(WhatsAppStatus item) {
    return Container(
      color: const Color(0xFF0A0A15),
      child: Center(
        child: Icon(
          item.type == 'video' ? Icons.play_circle_outline : Icons.image_outlined,
          color: Colors.white12, size: 36,
        ),
      ),
    );
  }

  Future<Uint8List?> _getVideoThumbnail(String path) async {
    try {
      final result = await _thumbnailChannel.invokeMethod('getVideoThumbnail', {'path': path});
      if (result != null && result is Uint8List) {
        return result;
      }
    } catch (e) {
      debugPrint('[StatusSaver] Thumbnail error: $e');
    }
    return null;
  }

  Widget _saveButton(WhatsAppStatus item, StatusService svc) {
    return GestureDetector(
      onTap: () async {
        final success = await svc.saveStatus(item);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    success ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: Colors.white, size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(success ? 'Berhasil disimpan!' : 'Gagal menyimpan',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
                ],
              ),
              backgroundColor: success ? const Color(0xFF1A3A2A) : const Color(0xFF3A1A1A),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4D8EFF), Color(0xFFA855F7)],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.download_rounded, color: Colors.white, size: 16),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes > 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}
