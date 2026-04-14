import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:html/parser.dart' as html_parser;

class ScrapedMedia {
  final String url;
  final String type; // 'video' or 'image'
  final String extension; // '.mp4', '.jpg', etc.
  final String platform;
  final String author;
  final String id;

  ScrapedMedia({
    required this.url, 
    required this.type, 
    required this.extension,
    this.platform = 'unknown',
    this.author = 'user',
    this.id = '',
  });
}

class AntiGravityEngine {
  static const String _nexrayBase = 'https://api.nexray.web.id';
  static const String _vredenBase = 'https://api.vreden.my.id';
  static const String _btchBase = 'https://backend1.tioo.eu.org';
  
  // Mobile User-Agent sesuai Bot WA Anda (Realme RMX2185)
  static const String _mobileUA = 'Mozilla/5.0 (Linux; Android 10; RMX2185) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.7103.60 Mobile Safari/537.36';

  /// Entry point utama
  static Future<List<ScrapedMedia>?> extractVideoData(String url) async {
    try {
      print("\n[AIO ENGINE] =====================================");
      print("[AIO ENGINE] ORIGINAL: $url");
      
      // 1. Ekspansi URL secara manual (Hanya untuk non-Instagram)
      String expandedUrl = url;
      if (!url.contains('instagram.com')) {
        expandedUrl = await _expandUrl(url);
        if (expandedUrl != url) {
          print("[AIO ENGINE] SUCCESS EXPAND! -> $expandedUrl");
        }
      } else {
        print("[AIO ENGINE] Instagram: Skip expansion as requested.");
      }

      // 2. Routing Scraper berdasarkan URL
      if (expandedUrl.contains('tiktok.com')) {
        print("[AIO ENGINE] Platform: TikTok");
        final res = await _getTiktokBtch(expandedUrl) ?? await _getTiktokClassic(expandedUrl);
        return res != null ? [res] : null;
      } 
      
      if (expandedUrl.contains('instagram.com') || url.contains('instagram.com')) {
        print("[AIO ENGINE] Platform: Instagram");
        final res = await _getInstagramMulti(url);
        if (res != null && res.isNotEmpty) return res;
      }

      if (expandedUrl.contains('facebook.com') || expandedUrl.contains('fb.watch') || expandedUrl.contains('fb.com')) {
        print("[AIO ENGINE] Platform: Facebook");
        final resBtch = await _getFacebookBtch(expandedUrl);
        if (resBtch != null) return [resBtch];
        
        final resVreden = await _getFacebookVreden(expandedUrl);
        if (resVreden != null) return [resVreden];
        
        final resNex = await _getFacebookNexray(expandedUrl);
        if (resNex != null) return [resNex];
      }

      if (expandedUrl.contains('youtube.com/') || expandedUrl.contains('youtu.be/')) {
        print("[AIO ENGINE] Platform: YouTube");
        final res = await _getYoutube(expandedUrl);
        if (res != null) return [res];
      }

      print("[AIO ENGINE] Falling back to Universal Scraper (On4t)...");
      return await _getUniversalOn4t(expandedUrl);
    } catch (e) {
      print("[AIO ENGINE] CRITICAL ERROR: $e");
      return null;
    }
  }

  /// Membongkar link share/redirect secara manual (Simulasi Browser)
  static Future<String> _expandUrl(String url) async {
    try {
      String currentUrl = url;
      for (int i = 0; i < 3; i++) {
        print("[AIO ENGINE] Unshortening Hop ${i+1}...");
        final response = await http.get(
          Uri.parse(currentUrl),
          headers: {'User-Agent': _mobileUA},
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 301 || response.statusCode == 302) {
          final location = response.headers['location'];
          if (location != null) {
            String newUrl = location.startsWith('http') ? location : 'https://www.facebook.com$location';
            if (newUrl == currentUrl) break;
            currentUrl = newUrl;
            continue;
          }
        }

        final bodyLower = response.body.toLowerCase();
        if (bodyLower.contains('http-equiv="refresh"')) {
          final match = RegExp(r'url=([^"]+)').firstMatch(bodyLower);
          if (match != null) {
            String newUrl = match.group(1)!.trim();
            if (newUrl.startsWith('/')) newUrl = 'https://www.facebook.com$newUrl';
            if (newUrl == currentUrl) break;
            currentUrl = newUrl;
            continue;
          }
        }
        break; 
      }
      
      if (currentUrl.contains('?')) {
        currentUrl = currentUrl.split('?')[0];
      }
      return currentUrl;
    } catch (e) {
      print("[AIO ENGINE] Unshorten Error: $e");
      return url;
    }
  }

  static String _extractId(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        return segments.last;
      }
      return DateTime.now().millisecondsSinceEpoch.toString();
    } catch (e) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  // == TIKTOK REGION ==
  static Future<ScrapedMedia?> _getTiktokBtch(String url) async {
    try {
      print("[AIO ENGINE] Trying Btch TikTok...");
      final encodedUrl = Uri.encodeComponent(url);
      final response = await http.get(
        Uri.parse('$_btchBase/ttdl?url=$encodedUrl'),
        headers: {'User-Agent': _mobileUA},
      ).timeout(const Duration(seconds: 20));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['result'] != null) {
          return ScrapedMedia(
            url: data['result']['video'], 
            type: 'video', 
            extension: '.mp4',
            platform: 'tiktok',
            author: data['result']['author'] ?? 'user',
            id: _extractId(url),
          );
        }
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<ScrapedMedia?> _getTiktokClassic(String url) async {
    try {
      final response = await http.post(
        Uri.parse('https://www.tikwm.com/api/'),
        body: {'url': url, 'hd': '1'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 0) {
          return ScrapedMedia(
            url: data['data']['hdplay'] ?? data['data']['play'], 
            type: 'video', 
            extension: '.mp4',
            platform: 'tiktok',
            author: data['data']['author']?['unique_id'] ?? 'user',
            id: data['data']['id'] ?? _extractId(url),
          );
        }
      }
      return null;
    } catch (e) { return null; }
  }

  // == INSTAGRAM REGION ==
  static Future<List<ScrapedMedia>?> _getInstagramMulti(String url) async {
    try {
      final encodedUrl = Uri.encodeComponent(url);
      
      // PRIORITAS 1: Vreden v1 (Hasil riset: ini yang paling stabil sekarang)
      print("[AIO ENGINE] Trying Vreden v1 Instagram...");
      try {
        final vRes = await http.get(
          Uri.parse('$_vredenBase/api/v1/download/instagram?url=$encodedUrl'),
          headers: {'User-Agent': _mobileUA},
        ).timeout(const Duration(seconds: 30));
        
        if (vRes.statusCode == 200) {
          final data = json.decode(vRes.body);
          if (data['status'] == true && data['result'] != null && data['result']['data'] != null) {
            final List mediaList = data['result']['data'];
            final username = data['result']['metadata']?['username'] ?? 'user';
            
            return mediaList.map((m) {
              bool isVid = m['type'] == 'video';
              return ScrapedMedia(
                url: m['url'],
                type: isVid ? 'video' : 'image',
                extension: isVid ? '.mp4' : '.jpg',
                platform: 'instagram',
                author: username,
                id: _extractId(url),
              );
            }).toList();
          }
        }
      } catch (e) { print("[AIO ENGINE] Vreden v1 Error: $e"); }

      // PRIORITAS 2: Nexray v2
      print("[AIO ENGINE] Trying Nexray Instagram...");
      try {
        final response = await http.get(
          Uri.parse('$_nexrayBase/downloader/v2/instagram?url=$encodedUrl'),
          headers: {'User-Agent': _mobileUA},
        ).timeout(const Duration(seconds: 30));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == true && data['result'] != null) {
            final List media = data['result']['media'];
            final username = data['result']['owner_username'] ?? 'user';
            final shortCode = data['result']['shortcode'] ?? _extractId(url);
            
            return media.map((m) {
              bool isVid = m['type'].toString().contains('mp4');
              return ScrapedMedia(
                url: m['url'], 
                type: isVid ? 'video' : 'image', 
                extension: isVid ? '.mp4' : '.jpg',
                platform: 'instagram',
                author: username,
                id: shortCode,
              );
            }).toList();
          }
        }
      } catch (e) { print("[AIO ENGINE] Nexray Error: $e"); }

      return null;
    } catch (e) {
      print("[AIO ENGINE] Instagram Critical Exception: $e");
      return null; 
    }
  }

  // == FACEBOOK REGION ==
  static Future<ScrapedMedia?> _getFacebookBtch(String url) async {
    try {
      print("[AIO ENGINE] Trying Btch Facebook...");
      final encodedUrl = Uri.encodeComponent(url);
      final response = await http.get(
        Uri.parse('$_btchBase/fbdown?url=$encodedUrl'),
        headers: {'User-Agent': _mobileUA},
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          final link = data['HD'] ?? data['Normal_video'];
          if (link != null) return ScrapedMedia(
            url: link, 
            type: 'video', 
            extension: '.mp4',
            platform: 'facebook',
            author: 'user',
            id: _extractId(url),
          );
        }
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<ScrapedMedia?> _getFacebookVreden(String url) async {
    try {
      final response = await http.get(Uri.parse('$_vredenBase/api/v1/download/facebook?url=$url'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 200) {
          final link = data['result']['download']['hd'] ?? data['result']['download']['sd'];
          return ScrapedMedia(
            url: link!, 
            type: 'video', 
            extension: '.mp4',
            platform: 'facebook',
            author: 'user',
            id: _extractId(url),
          );
        }
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<ScrapedMedia?> _getFacebookNexray(String url) async {
    try {
      final response = await http.get(Uri.parse('$_nexrayBase/downloader/facebook?url=$url'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          final link = data['result']['HD'] ?? data['result']['Normal_video'];
          return ScrapedMedia(
            url: link, 
            type: 'video', 
            extension: '.mp4',
            platform: 'facebook',
            author: 'user',
            id: _extractId(url),
          );
        }
      }
      return null;
    } catch (e) { return null; }
  }

  // == YOUTUBE REGION ==
  static Future<ScrapedMedia?> _getYoutube(String url) async {
    try {
      final response = await http.get(Uri.parse('$_nexrayBase/downloader/ytmp4?url=$url&resolusi=360'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) return ScrapedMedia(
          url: data['result']['url'], 
          type: 'video', 
          extension: '.mp4',
          platform: 'youtube',
          author: 'user',
          id: _extractId(url),
        );
      }
      
      final yt = YoutubeExplode();
      final video = await yt.videos.get(url);
      final manifest = await yt.videos.streamsClient.getManifest(video.id);
      final streamInfo = manifest.muxed.withHighestBitrate();
      yt.close();
      return ScrapedMedia(
        url: streamInfo.url.toString(), 
        type: 'video', 
        extension: '.mp4',
        platform: 'youtube',
        author: video.author,
        id: video.id.value,
      );
    } catch (e) { return null; }
  }

  // == UNIVERSAL (On4t) ==
  static Future<List<ScrapedMedia>?> _getUniversalOn4t(String targetUrl) async {
    try {
      const baseUrl = 'https://on4t.com/online-video-downloader';
      final initRes = await http.get(Uri.parse(baseUrl), headers: {'User-Agent': _mobileUA}).timeout(const Duration(seconds: 15));
      final document = html_parser.parse(initRes.body);
      final token = document.querySelector('meta[name="csrf-token"]')?.attributes['content'];
      final cookies = initRes.headers['set-cookie'] ?? '';
      if (token == null) return null;

      final response = await http.post(
        Uri.parse('https://on4t.com/all-video-download'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'X-Requested-With': 'XMLHttpRequest',
          'Cookie': cookies,
          'User-Agent': _mobileUA,
          'Referer': baseUrl,
        },
        body: {'_token': token, 'link[]': targetUrl},
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] != null && data['result'].isNotEmpty) {
          return (data['result'] as List).map<ScrapedMedia>((item) {
            final link = item['video_file_url'] ?? item['videoimg_file_url'] ?? item['image'];
            bool isVid = link.toString().contains('.mp4') || (item['title'] ?? '').toString().toLowerCase().contains('video');
            return ScrapedMedia(
              url: link, 
              type: isVid ? 'video' : 'image', 
              extension: isVid ? '.mp4' : '.jpg',
              platform: 'universal',
              author: 'user',
              id: _extractId(targetUrl),
            );
          }).toList();
        }
      }
      return null;
    } catch (e) { return null; }
  }
}
