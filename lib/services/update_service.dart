import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'settings_service.dart';

class UpdateService {
  static const String _owner = 'Alphared26';
  static const String _repo = 'aio-downloader';
  static const String _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// Check GitHub for latest release and show dialog if newer version exists
  static Future<void> checkForUpdate(BuildContext context, {bool showToast = false}) async {
    try {
      if (showToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Memeriksa update...', style: GoogleFonts.inter(fontSize: 12)),
            backgroundColor: const Color(0xFF1A1A2E),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }

      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('[UpdateService] Update check failed with status: ${response.statusCode}');
        return;
      }

      final data = json.decode(response.body);
      final latestTag = data['tag_name']?.toString() ?? '';
      final releaseName = data['name']?.toString() ?? latestTag;
      final body = data['body']?.toString() ?? '';
      final htmlUrl = data['html_url']?.toString() ?? '';

      // Extract version number
      String latestVersion = latestTag.replaceFirst(RegExp(r'^v'), '');
      String currentVersion = SettingsService.appVersion;

      debugPrint('[UpdateService] Checking for updates: Current v$currentVersion, Latest v$latestVersion');

      if (_isNewer(latestVersion, currentVersion) && context.mounted) {
        debugPrint('[UpdateService] New version found! Showing dialog.');
        _showUpdateDialog(context, releaseName, latestVersion, body, htmlUrl);
      } else {
        debugPrint('[UpdateService] App is up to date.');
        if (showToast && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Aplikasi sudah versi terbaru (v$currentVersion)', 
                style: GoogleFonts.inter(fontSize: 12)),
              backgroundColor: const Color(0xFF1A3E2A),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[UpdateService] Check failed: $e');
      if (showToast && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memeriksa update. Cek koneksi Anda.', 
              style: GoogleFonts.inter(fontSize: 12)),
            backgroundColor: const Color(0xFF3A1A1A),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  /// Compare semantic versions: returns true if remote > current
  static bool _isNewer(String remote, String current) {
    try {
      // 1. Helper to extract numeric parts: "2.8.0 Beta" -> [2, 8, 0]
      List<int> getNumbers(String v) {
        final clean = v.toLowerCase().replaceFirst(RegExp(r'^v'), '');
        final parts = clean.split('.');
        return parts.map((p) {
          final match = RegExp(r'^\d+').firstMatch(p);
          return match != null ? int.parse(match.group(0)!) : 0;
        }).toList();
      }

      // 2. Helper to get release priority (Pre-release ranking)
      int getPriority(String v) {
        final low = v.toLowerCase();
        if (low.contains('rc')) return 3;
        if (low.contains('beta')) return 2;
        if (low.contains('alpha')) return 1;
        // If it contains dots/numbers but no pre-release labels, it's likely stable
        return 4; 
      }

      // 3. Helper to get numeric suffix: "Beta 2" -> 2
      int getSuffixNumber(String v) {
        final match = RegExp(r'(\d+)$').firstMatch(v.trim());
        return match != null ? int.parse(match.group(0)!) : 0;
      }

      final rNums = getNumbers(remote);
      final cNums = getNumbers(current);
      
      // Compare main numeric segments (Major.Minor.Patch)
      final maxLen = rNums.length > cNums.length ? rNums.length : cNums.length;
      for (int i = 0; i < maxLen; i++) {
        final r = i < rNums.length ? rNums[i] : 0;
        final c = i < cNums.length ? cNums[i] : 0;
        if (r > c) return true;
        if (r < c) return false;
      }

      // If numeric segments are identical, check priorities: Stable > RC > Beta > Alpha
      final rPri = getPriority(remote);
      final cPri = getPriority(current);
      if (rPri > cPri) return true;
      if (rPri < cPri) return false;

      // If priorities are same (e.g. both are Beta), check for suffix numbers (Beta 2 vs Beta 1)
      if (rPri == cPri) {
        final rSuf = getSuffixNumber(remote);
        final cSuf = getSuffixNumber(current);
        if (rSuf > cSuf) return true;
      }

      return false;
    } catch (e) {
      debugPrint('[UpdateService] Version comparison error: $e');
      return false;
    }
  }

  static void _showUpdateDialog(
    BuildContext context,
    String releaseName,
    String version,
    String changelog,
    String htmlUrl,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111120),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF2A2A3E)),
        ),
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4D8EFF), Color(0xFFA855F7)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.system_update_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Update Tersedia!',
                    style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text('v${SettingsService.appVersion} → v$version',
                    style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF4D8EFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (changelog.isNotEmpty) ...[
              Text('Apa yang baru:',
                style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2A2A3E)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    changelog.length > 500 ? '${changelog.substring(0, 500)}...' : changelog,
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white54, height: 1.5),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Nanti',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white38, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(Uri.parse(htmlUrl), mode: LaunchMode.externalApplication);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4D8EFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text('Download',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
