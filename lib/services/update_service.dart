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
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      final latestTag = data['tag_name']?.toString() ?? '';
      final releaseName = data['name']?.toString() ?? latestTag;
      final body = data['body']?.toString() ?? '';
      final htmlUrl = data['html_url']?.toString() ?? '';

      // Extract version number (strip 'v' prefix if present)
      String latestVersion = latestTag.replaceFirst(RegExp(r'^v'), '');
      String currentVersion = SettingsService.appVersion;

      if (_isNewer(latestVersion, currentVersion) && context.mounted) {
        _showUpdateDialog(context, releaseName, latestVersion, body, htmlUrl);
      }
    } catch (e) {
      debugPrint('[UpdateService] Check failed: $e');
    }
  }

  /// Compare semantic versions: returns true if remote > current
  static bool _isNewer(String remote, String current) {
    try {
      final r = remote.split('.').map(int.parse).toList();
      final c = current.split('.').map(int.parse).toList();
      
      // Pad to same length
      while (r.length < 3) r.add(0);
      while (c.length < 3) c.add(0);
      
      for (int i = 0; i < 3; i++) {
        if (r[i] > c[i]) return true;
        if (r[i] < c[i]) return false;
      }
      return false; // equal
    } catch (_) {
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
