import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/settings_service.dart';
import '../services/download_service.dart';
import '../services/update_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // === Download Section ===
        _buildSectionLabel('UNDUHAN'),
        _buildCard([
          _buildPathTile(context, settings, settings.downloadPath),
          const Divider(height: 1, color: Color(0xFF2A2A3E), indent: 16),
          _buildQualityTile(context, settings),
          const Divider(height: 1, color: Color(0xFF2A2A3E), indent: 16),
          _buildSwitchTile(
            icon: Icons.auto_awesome_rounded,
            iconColor: Colors.cyanAccent,
            title: 'Unduh Otomatis',
            subtitle: 'Langsung unduh saat link dibagikan',
            value: settings.autoDownloadShare,
            onChanged: (v) => settings.setAutoDownloadShare(v),
          ),
        ]),

        const SizedBox(height: 16),

        // === Notifications Section ===
        _buildSectionLabel('NOTIFIKASI'),
        _buildCard([
          _buildSwitchTile(
            icon: Icons.notifications_rounded,
            iconColor: const Color(0xFFFFA726),
            title: 'Notifikasi Progres',
            subtitle: 'Tampilkan notifikasi saat mengunduh',
            value: settings.notificationsEnabled,
            onChanged: (v) async {
              if (v) {
                // Request permission when enabling
                final status = await Permission.notification.request();
                if (!status.isGranted) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Izin notifikasi ditolak. Aktifkan di Pengaturan Sistem.', 
                          style: GoogleFonts.inter(fontSize: 12)),
                        backgroundColor: const Color(0xFF3A1A1A),
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                  return; // Don't enable
                }
              }
              settings.setNotificationsEnabled(v);
            },
          ),
        ]),

        const SizedBox(height: 16),

            // === About / Watermark Section ===
            _buildSectionLabel('TENTANG'),
            _buildCard([
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4D8EFF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.code_rounded, color: Color(0xFF4D8EFF), size: 18),
                ),
                title: Text('Developer',
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text('github.com/Alphared26',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF4D8EFF))),
                trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white24),
                onTap: () => launchUrl(Uri.parse(SettingsService.githubUrl),
                  mode: LaunchMode.externalApplication),
              ),
              const Divider(height: 1, color: Color(0xFF2A2A3E), indent: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.info_outline_rounded, color: Colors.purpleAccent, size: 18),
                ),
                title: Text('Versi',
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text('AIO Downloader v${SettingsService.appVersion}',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white38)),
              ),
              const Divider(height: 1, color: Color(0xFF2A2A3E), indent: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.update_rounded, color: Colors.orangeAccent, size: 18),
                ),
                title: Text('Periksa Update',
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text('Cek rilis terbaru di GitHub',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white24),
                onTap: () => UpdateService.checkForUpdate(context, showToast: true),
              ),
            ]),

            const SizedBox(height: 24),

            // Platform support chips
            Text('Platform yang didukung',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white24)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildPlatformChip('Instagram', const Color(0xFFE1306C)),
                _buildPlatformChip('TikTok', const Color(0xFF69C9D0)),
                _buildPlatformChip('Facebook', const Color(0xFF1877F2)),
                _buildPlatformChip('YouTube', const Color(0xFFFF4444)),
                _buildPlatformChip('X', Colors.white),
                _buildPlatformChip('WhatsApp', const Color(0xFF25D366)),
                _buildPlatformChip('Threads', const Color(0xFF9B6DFF)),
              ],
            ),
            const SizedBox(height: 32),
          ],
        );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label,
        style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w700,
          letterSpacing: 1.2, color: const Color(0xFF4D8EFF),
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111120),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A3E), width: 1),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildPathTile(BuildContext context, SettingsService settings, String path) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.greenAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.folder_rounded, color: Colors.greenAccent, size: 18),
      ),
      title: Text('Folder Download',
        style: GoogleFonts.inter(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(path,
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
      trailing: TextButton(
        onPressed: () => _changeDownloadPath(context, settings, path),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF4D8EFF),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          backgroundColor: const Color(0xFF4D8EFF).withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text('Ubah', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildQualityTile(BuildContext context, SettingsService settings) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.high_quality_rounded, color: Colors.blueAccent, size: 18),
      ),
      title: Text('Kualitas Video',
        style: GoogleFonts.inter(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text('Resolusi default untuk unduh otomatis',
        style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
      trailing: DropdownButton<DownloadQuality>(
        value: settings.quality,
        dropdownColor: const Color(0xFF1A1A2E),
        underline: const SizedBox(),
        items: DownloadQuality.values.map((q) {
          String label = 'Auto';
          if (q == DownloadQuality.q720) label = '720p';
          if (q == DownloadQuality.q1080) label = '1080p';
          return DropdownMenuItem(
            value: q,
            child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
          );
        }).toList(),
        onChanged: (v) {
          if (v != null) settings.setQuality(v);
        },
      ),
    );
  }

  Future<void> _changeDownloadPath(BuildContext context, SettingsService settings, String currentPath) async {
    final options = [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Movies',
      '/storage/emulated/0/Pictures',
      '/storage/emulated/0/DCIM',
    ];

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Pilih Folder Download',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((path) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              currentPath == path ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: currentPath == path ? const Color(0xFF4D8EFF) : Colors.white38,
              size: 20,
            ),
            title: Text(path.split('/').last,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
            subtitle: Text(path,
              style: GoogleFonts.inter(fontSize: 10, color: Colors.white38)),
            onTap: () => Navigator.pop(ctx, path),
          )).toList(),
        ),
      ),
    );

    if (selected != null) {
      try {
        await Directory(selected).create(recursive: true);
      } catch (_) {}
      await settings.setDownloadPath(selected);
    }
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(title,
        style: GoogleFonts.inter(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
        style: GoogleFonts.inter(fontSize: 12, color: Colors.white38)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF4D8EFF),
        activeTrackColor: const Color(0xFF4D8EFF).withAlpha(77),
        inactiveThumbColor: Colors.white38,
        inactiveTrackColor: const Color(0xFF2A2A3E),
      ),
    );
  }

  Widget _buildPlatformChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(label,
        style: GoogleFonts.inter(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
