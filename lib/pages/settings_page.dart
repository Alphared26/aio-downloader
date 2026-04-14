import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _settings = SettingsService();
  String _downloadPath = SettingsService.defaultDownloadPath;
  bool _notificationsEnabled = true;
  bool _showWatermark = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _downloadPath = await _settings.getDownloadPath();
    _notificationsEnabled = await _settings.getNotificationsEnabled();
    _showWatermark = await _settings.getShowWatermark();
    setState(() => _isLoading = false);
  }

  Future<void> _changeDownloadPath() async {
    // Show dialog with common path options
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
              _downloadPath == path ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: _downloadPath == path ? const Color(0xFF4D8EFF) : Colors.white38,
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
      
      await _settings.setDownloadPath(selected);
      setState(() => _downloadPath = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(Color(0xFF4D8EFF))));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // === Download Section ===
        _buildSectionLabel('UNDUHAN'),
        _buildCard([
          _buildPathTile(),
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
            value: _notificationsEnabled,
            onChanged: (v) async {
              await _settings.setNotificationsEnabled(v);
              setState(() => _notificationsEnabled = v);
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
        ]),

        const SizedBox(height: 24),

        // Platform support chips
        Text('Platform yang didukung',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white24)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPlatformChip('Instagram', const Color(0xFFE1306C)),
            const SizedBox(width: 8),
            _buildPlatformChip('TikTok', const Color(0xFF69C9D0)),
            const SizedBox(width: 8),
            _buildPlatformChip('Facebook', const Color(0xFF1877F2)),
            const SizedBox(width: 8),
            _buildPlatformChip('YouTube', const Color(0xFFFF4444)),
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

  Widget _buildPathTile() {
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
      subtitle: Text(_downloadPath,
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
      trailing: TextButton(
        onPressed: _changeDownloadPath,
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
        activeTrackColor: const Color(0xFF4D8EFF).withOpacity(0.3),
        inactiveThumbColor: Colors.white38,
        inactiveTrackColor: const Color(0xFF2A2A3E),
      ),
    );
  }

  Widget _buildPlatformChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
        style: GoogleFonts.inter(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
