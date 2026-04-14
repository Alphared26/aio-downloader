import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/download_service.dart';

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
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    _urlController.clear();
    FocusScope.of(context).unfocus();
    context.read<DownloadService>().processUrl(url, DownloadQuality.auto);
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
        final bool isBusy = svc.isScraping || hasActive;

        return Column(
          children: [
            // Status Hero Card
            _buildStatusCard(context, svc, isBusy),
            const SizedBox(height: 12),

            // Manual URL Input
            _buildUrlInput(context, isBusy),
            const SizedBox(height: 16),

            // Active Downloads Section
            if (hasActive || svc.isScraping) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
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
              ),
              const SizedBox(height: 8),
              ...svc.activeDownloads.map((d) => _buildDownloadCard(d)),
              if (svc.isScraping && svc.activeDownloads.isEmpty)
                _buildScrapingCard(svc.scrapingStatus),
              const SizedBox(height: 16),
            ],

            // Idle Illustration
            if (!isBusy)
              Expanded(child: _buildIdleState()),
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
                  // Paste button
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
          // Download button
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
                isBusy ? Icons.hourglass_empty_rounded : Icons.download_rounded,
                color: isBusy ? Colors.white24 : Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
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
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF4D8EFF), Color(0xFFA855F7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4D8EFF).withAlpha(80),
                  blurRadius: 12, spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(
              isBusy ? Icons.downloading_rounded : Icons.cloud_download_rounded,
              color: Colors.white, size: 22,
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
                Text(
                  isBusy
                      ? '${svc.activeDownloads.where((d) => !d.isComplete).length} file berjalan'
                      : 'IG · TikTok · Facebook · YouTube',
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
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _platformColor(d.platform).withAlpha(38),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_platformIcon(d.platform),
                  color: _platformColor(d.platform), size: 18),
              ),
              const SizedBox(width: 10),
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
                Text('${(d.progress * 100).toInt()}%',
                  style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: const Color(0xFF4D8EFF),
                  ),
                ),
            ],
          ),
          if (!d.isComplete && !d.isError) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: d.progress,
                minHeight: 4,
                backgroundColor: const Color(0xFF2A2A3E),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF4D8EFF)),
              ),
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
          Text('Tempel Link atau Bagikan dari App Lain',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Instagram · TikTok · Facebook · YouTube',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white30),
          ),
        ],
      ),
    );
  }
}
