import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/download_service.dart';
import '../services/settings_service.dart';
import '../scraper_engine.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _urlController = TextEditingController();

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

  String _platformLabel(String platform) {
    switch (platform) {
      case 'instagram': return 'Instagram';
      case 'tiktok': return 'TikTok';
      case 'facebook': return 'Facebook';
      case 'youtube': return 'YouTube';
      default: return 'Media';
    }
  }

  void _startDownload(BuildContext context) {
    if (_urlController.text.trim().isEmpty) return;
    final svc = context.read<DownloadService>();
    final quality = context.read<SettingsService>().quality;
    svc.scrapeUrl(_urlController.text.trim(), quality);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadService>(
      builder: (context, svc, _) {
        final bool hasActive = svc.activeDownloads.isNotEmpty;
        final bool isBusy = svc.isScraping; // Only block search during active scraping
        final bool isActive = svc.isScraping || hasActive; // For status card display

        return Column(
          children: [
            // Status Hero Card (pinned at top)
            _buildStatusCard(context, svc, isActive),
            const SizedBox(height: 12),

            // Manual URL Input (pinned at top)
            _buildUrlInput(context, isBusy),
            const SizedBox(height: 16),

            // Scrollable content area
            Expanded(
              child: (!isActive && svc.lastScrapedResults == null && svc.activeDownloads.isEmpty)
                ? _buildIdleState()
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        // Scrape Results (Multi-select)
                        if (svc.lastScrapedResults != null) ...[
                          _buildScrapeResultsHeader(svc),
                          _buildScrapeResultsView(svc),
                          const SizedBox(height: 20),
                        ],

                        // Active Downloads
                        if (hasActive || svc.isScraping) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  Container(
                                    width: 3, height: 14,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4D8EFF),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  Text('SEDANG BERJALAN',
                                    style: GoogleFonts.inter(
                                      fontSize: 11, fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2, color: const Color(0xFF4D8EFF),
                                    ),
                                  ),
                                ]),
                                if (svc.activeDownloads.any((d) => d.isComplete || d.isError))
                                  TextButton(
                                    onPressed: () {
                                      svc.activeDownloads.removeWhere((d) => d.isComplete || d.isError);
                                    },
                                    child: Text('Bersihkan', 
                                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...svc.activeDownloads.map((d) => _buildDownloadCard(d)),
                          if (svc.isScraping && svc.activeDownloads.isEmpty)
                            _buildScrapingCard(svc.scrapingStatus),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUrlInput(BuildContext context, bool isBusy) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF111120),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2A2A3E), width: 1),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.link_rounded, color: Colors.white38, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Tempel link video di sini...',
                        hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.white24),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _startDownload(context),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        _urlController.text = data!.text!;
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A3E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Tempel',
                        style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: isBusy ? null : () => _startDownload(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48, height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: isBusy
                    ? const LinearGradient(colors: [Color(0xFF2A2A3E), Color(0xFF2A2A3E)])
                    : const LinearGradient(
                        colors: [Color(0xFF4D8EFF), Color(0xFFA855F7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                boxShadow: isBusy ? [] : [
                  BoxShadow(
                    color: const Color(0xFF4D8EFF).withAlpha(80),
                    blurRadius: 12, spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                isBusy ? Icons.hourglass_empty_rounded : Icons.search_rounded,
                color: isBusy ? Colors.white24 : Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes > 1024 * 1024) return '~${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    if (bytes > 1024) return '~${(bytes / 1024).toStringAsFixed(0)} KB';
    return '~$bytes B';
  }

  String _displayFileName(ScrapedMedia media) {
    if (media.title != null && media.title!.isNotEmpty) return media.title!;
    final typeLabel = media.type == 'video' ? 'Video' : media.type == 'audio' ? 'Audio' : 'Foto';
    return '$typeLabel · ${_platformLabel(media.platform)}';
  }

  Widget _buildScrapeResultsHeader(DownloadService svc) {
    final count = svc.lastScrapedResults?.length ?? 0;
    final selectedCount = svc.selectedMediaIndices.length;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MEDIA DITEMUKAN',
                    style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      letterSpacing: 1.2, color: const Color(0xFFA855F7),
                    ),
                  ),
                  Text('$count item · $selectedCount dipilih',
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.white38)),
                ],
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => svc.clearResults(),
                    child: Text('Batal', style: GoogleFonts.inter(fontSize: 12, color: Colors.redAccent)),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    onPressed: selectedCount > 0 ? () => svc.downloadSelected() : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4D8EFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Unduh Pilihan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Quality picker row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2A2A3E)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.high_quality_rounded, size: 14, color: Color(0xFF4D8EFF)),
                    const SizedBox(width: 6),
                    DropdownButton<DownloadQuality>(
                      value: svc.scrapeQuality,
                      dropdownColor: const Color(0xFF1A1A2E),
                      underline: const SizedBox(),
                      isDense: true,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                      items: DownloadQuality.values.map((q) {
                        String label = 'Auto';
                        if (q == DownloadQuality.q720) label = '720p';
                        if (q == DownloadQuality.q1080) label = '1080p';
                        return DropdownMenuItem(value: q, child: Text(label));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) svc.setScrapeQuality(v);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('Kualitas unduhan', style: GoogleFonts.inter(fontSize: 10, color: Colors.white30)),
            ],
          ),
          // YouTube video loading indicator
          if (svc.isFetchingVideo) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFF6B00).withAlpha(50)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6B00)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Mencari video YouTube...',
                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFFF6B00), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScrapeResultsView(DownloadService svc) {
    final results = svc.lastScrapedResults!;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              _ActionButton(
                label: 'Pilih Semua',
                icon: Icons.select_all_rounded,
                onTap: () => svc.selectAll(),
              ),
              const SizedBox(width: 8),
              _ActionButton(
                label: 'Hapus Semua',
                icon: Icons.deselect_rounded,
                onTap: () => svc.deselectAll(),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final media = results[index];
              final isSelected = svc.selectedMediaIndices.contains(index);
              final sizeStr = _formatFileSize(media.fileSize);
              
              return GestureDetector(
                onTap: () => svc.toggleSelection(index),
                child: Container(
                  width: 150,
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111120),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF4D8EFF) : const Color(0xFF2A2A3E),
                      width: 2,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(color: const Color(0xFF4D8EFF).withAlpha(40), blurRadius: 8)
                    ] : [],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Thumbnail area
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (media.type == 'audio')
                                Container(
                                  color: const Color(0xFF1A1A2E),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.music_note_rounded, color: Color(0xFF4D8EFF), size: 50),
                                )
                              else if (media.thumbnailUrl != null)
                                CachedNetworkImage(
                                  imageUrl: media.thumbnailUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: Colors.white10),
                                  errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white12),
                                )
                              else
                                Container(
                                  color: const Color(0xFF1A1A2E),
                                  child: const Icon(Icons.movie_rounded, color: Colors.white12, size: 40),
                                ),
                              
                              // Checkmark
                              Positioned(
                                top: 6, right: 6,
                                child: Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                                  color: isSelected ? const Color(0xFF4D8EFF) : Colors.white54,
                                  size: 22,
                                ),
                              ),
                              
                              // Type badge + size
                              Positioned(
                                bottom: 6, left: 6, right: 6,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withAlpha(170),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            media.type == 'video' ? Icons.play_arrow_rounded : 
                                            media.type == 'audio' ? Icons.audiotrack_rounded : Icons.image_rounded,
                                            color: Colors.white, size: 12,
                                          ),
                                          if (sizeStr.isNotEmpty) ...[
                                            const SizedBox(width: 4),
                                            Text(sizeStr, style: GoogleFonts.inter(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w600)),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // File info text below thumbnail
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                        child: Text(
                          _displayFileName(media),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w500,
                            color: Colors.white60,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(BuildContext context, DownloadService svc, bool isBusy) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isBusy
              ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
              : [const Color(0xFF0F0F1A), const Color(0xFF1A1A2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isBusy
              ? const Color(0xFF4D8EFF).withAlpha(100)
              : const Color(0xFF2A2A3E),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.white.withOpacity(0.05),
              image: const DecorationImage(
                image: AssetImage('assets/icons/logo2.png'),
                fit: BoxFit.contain,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4D8EFF).withAlpha(30),
                  blurRadius: 15, spreadRadius: 0,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBusy ? 'Sedang Mengunduh' : 'AIO Downloader',
                  style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                if (isBusy)
                  Text(
                    '${svc.activeDownloads.where((d) => !d.isComplete).length} file berjalan',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
                  ),
              ],
            ),
          ),
          if (isBusy)
            SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF4D8EFF)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDownloadCard(ActiveDownload d) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111120),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: d.isComplete
              ? Colors.greenAccent.withAlpha(80)
              : d.isError
                  ? Colors.redAccent.withAlpha(80)
                  : const Color(0xFF2A2A3E),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: _platformColor(d.platform).withAlpha(38),
                  ),
                  child: d.type == 'audio'
                    ? const Icon(Icons.music_note_rounded, color: Color(0xFF4D8EFF), size: 28)
                    : (d.sourceMedia.thumbnailUrl != null 
                        ? CachedNetworkImage(
                            imageUrl: d.sourceMedia.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => Icon(_platformIcon(d.platform),
                              color: _platformColor(d.platform), size: 20),
                          )
                        : Icon(_platformIcon(d.platform),
                            color: _platformColor(d.platform), size: 20)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.fileName,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(_platformLabel(d.platform),
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
                  ],
                ),
              ),
              if (d.isComplete)
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20)
              else if (d.isError)
                const Icon(Icons.error_rounded, color: Colors.redAccent, size: 20)
              else
                Text(d.isPaused ? 'Dijeda' : '${(d.progress * 100).toInt()}%',
                  style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: d.isPaused ? Colors.orangeAccent : const Color(0xFF4D8EFF),
                  ),
                ),
            ],
          ),
          if (!d.isComplete && !d.isError) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: d.progress,
                minHeight: 4,
                backgroundColor: const Color(0xFF2A2A3E),
                valueColor: AlwaysStoppedAnimation(d.isPaused ? Colors.orangeAccent : const Color(0xFF4D8EFF)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Pause / Resume Button
                GestureDetector(
                  onTap: () {
                    final svc = context.read<DownloadService>();
                    if (d.isPaused) {
                      svc.resumeDownload(d.id);
                    } else {
                      svc.pauseDownload(d.id);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (d.isPaused ? Colors.orangeAccent : Colors.blueAccent).withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: (d.isPaused ? Colors.orangeAccent : Colors.blueAccent).withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        Icon(d.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, 
                          size: 16, color: d.isPaused ? Colors.orangeAccent : Colors.blueAccent),
                        const SizedBox(width: 6),
                        Text(d.isPaused ? 'Lanjut' : 'Jeda', 
                          style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.bold,
                            color: d.isPaused ? Colors.orangeAccent : Colors.blueAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Cancel Button
                GestureDetector(
                  onTap: () => context.read<DownloadService>().cancelDownload(d.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                        const SizedBox(width: 6),
                        Text('Batal', 
                          style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],

      ),
    );
  }

  Widget _buildScrapingCard(String status) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111120),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A3E), width: 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF4D8EFF)),
            ),
          ),
          const SizedBox(width: 12),
          Text(status.isEmpty ? 'Mencari media...' : status,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _buildIdleState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4D8EFF).withAlpha(38),
                  const Color(0xFFA855F7).withAlpha(38),
                ],
              ),
            ),
            child: const Icon(Icons.share_rounded, size: 40, color: Color(0xFF4D8EFF)),
          ),
          const SizedBox(height: 16),
          Text('Tempel Link atau Bagikan dari Sosmed Lain',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
            ),
          )
        ],
      ),
    );
  }
}
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2A2A3E)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.white54),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
