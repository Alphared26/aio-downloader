import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:html/parser.dart' as html_parser;

class ScrapedMedia {
  final String url;
  final String type; // 'video', 'image', or 'audio'
  final String extension; // '.mp4', '.jpg', '.mp3', etc.
  final String platform;
  final String author;
  final String id;
  final String? thumbnailUrl;
  final String? title;
  int? fileSize; // estimated file size in bytes (mutable, filled by HEAD request)

  ScrapedMedia({
    required this.url, 
    required this.type, 
    required this.extension,
    this.platform = 'unknown',
    this.author = 'user',
    this.id = '',
    this.thumbnailUrl,
    this.title,
    this.fileSize,
  });
}

class AntiGravityEngine {
  static const String _nexrayBase = 'https://api.nexray.web.id';
  static const String _vredenBase = 'https://api.vreden.my.id';
  static const String _azbryBase = 'https://api.azbry.com';
  static const String _btchBase = 'https://backend1.tioo.eu.org';
  static const String _chocomilkBase = 'https://chocomilk.amira.us.kg';
  
  static const String _mobileUA = 'Mozilla/5.0 (Linux; Android 10; RMX2185) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.7103.60 Mobile Safari/537.36';

  static Future<List<ScrapedMedia>?> extractVideoData(String rawUrl, {String quality = 'auto'}) async {
    try {
      print("\n[AIO ENGINE] =====================================");
      print("[AIO ENGINE] INPUT: $rawUrl");
      
      // Extract actual URL from mixed text (e.g. from share strings)
      String url = rawUrl;
      final urlMatch = RegExp(r'(https?://[^\s]+)').firstMatch(rawUrl);
      if (urlMatch != null) {
        url = urlMatch.group(0)!;
      }
      
      print("[AIO ENGINE] CLEANED URL: $url");
      
      // Check Twitter/X FIRST before URL expansion (x.com returns 200 confusing the expander)
      if (url.contains('twitter.com') || url.contains('x.com')) {
        print("[AIO ENGINE] Detected Twitter/X URL, skipping expansion");
        final res = await _getTwitter(url);
        if (res != null) return res;
        return null;
      }

      String expandedUrl = url;
      bool isSocial = url.contains('tiktok.com') || 
                      url.contains('instagram.com') || 
                      url.contains('facebook.com') || 
                      url.contains('fb.watch') || 
                      url.contains('fb.com') || 
                      url.contains('threads.net') ||
                      url.contains('threads.com') ||
                      url.contains('youtube.com/') || 
                      url.contains('youtu.be/');
      
      bool isFullYoutube = url.contains('youtube.com/watch') || url.contains('youtube.com/shorts');
      
      if (!isSocial && !isFullYoutube) {
        expandedUrl = await _expandUrl(url);
        if (expandedUrl != url) {
          print("[AIO ENGINE] SUCCESS EXPAND! -> $expandedUrl");
        }
      }

      if (expandedUrl.contains('tiktok.com')) {
        final resMulti = await _getTiktokMulti(url);
        if (resMulti != null) return resMulti;
        
        final res = await _getTiktokBtch(expandedUrl) ?? await _getTiktokClassic(expandedUrl);
        return res != null ? [res] : null;
      } 
      
      if (expandedUrl.contains('instagram.com') || url.contains('instagram.com')) {
        final res = await _getInstagramMulti(url);
        if (res != null && res.isNotEmpty) return res;
      }

      if (url.contains('facebook.com') || url.contains('fb.watch') || url.contains('fb.com')) {
        final resVreden = await _getFacebookVreden(url, quality: quality);
        if (resVreden != null) return [resVreden];
        
        final resNexCheck = await _getFacebookNexray(url);
        if (resNexCheck != null) return [resNexCheck];
        
        final resBtch = await _getFacebookBtch(url);
        if (resBtch != null) return [resBtch];
      }

      if (expandedUrl.contains('youtube.com/') || expandedUrl.contains('youtu.be/')) {
        final res = await _getYoutube(expandedUrl, quality: quality);
        if (res != null) return res;
      }
      
      if (expandedUrl.contains('threads.net') || expandedUrl.contains('threads.com')) {
        final res = await _getThreads(expandedUrl);
        if (res != null) return res;
      }

      return await _getUniversalOn4t(expandedUrl);
    } catch (e) {
      print("[AIO ENGINE] CRITICAL ERROR: $e");
      return null;
    }
  }

  static Future<String> _expandUrl(String url) async {
    try {
      String currentUrl = url;
      final client = http.Client();
      
      try {
        for (int i = 0; i < 5; i++) { // Increase hops to 5 for deep redirects
          print("[AIO ENGINE] Unshortening Hop ${i + 1}: $currentUrl");
          
          final request = http.Request('GET', Uri.parse(currentUrl))
            ..followRedirects = false
            ..headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
            
          final response = await client.send(request).timeout(const Duration(seconds: 10));
          print("[AIO ENGINE] Hop ${i + 1} Status: ${response.statusCode}");
          
          if (response.statusCode >= 300 && response.statusCode < 400) {
            String? location = response.headers['location'] ?? response.headers['Location'];
            if (location != null) {
              String newUrl = location;
              if (!newUrl.startsWith('http')) {
                final baseUri = Uri.parse(currentUrl);
                newUrl = '${baseUri.scheme}://${baseUri.host}$location';
              }
              if (newUrl == currentUrl) break;
              currentUrl = newUrl;
              continue;
            }
          }
          
          // If 200, check for meta refresh as a secondary fallback
          if (response.statusCode == 200) {
            final body = await response.stream.bytesToString();
            final bodyLower = body.toLowerCase();
            if (bodyLower.contains('http-equiv="refresh"')) {
              final match = RegExp(r'url=([^";>]+)').firstMatch(bodyLower);
              if (match != null) {
                String newUrl = match.group(1)!.trim();
                newUrl = newUrl.replaceAll(RegExp("['\"]"), ''); // Strip quotes
                if (!newUrl.startsWith('http')) {
                  final baseUri = Uri.parse(currentUrl);
                  newUrl = '${baseUri.scheme}://${baseUri.host}$newUrl';
                }
                if (newUrl == currentUrl) break;
                currentUrl = newUrl;
                continue;
              }
            }
          }
          
          break; // No more redirects
        }
      } finally {
        client.close();
      }

      if (currentUrl != url) {
        print("[AIO ENGINE] SUCCESS EXPAND! -> $currentUrl");
      }
      
      // Strip query parameters for cleanup (except for YouTube)
      if (currentUrl.contains('?') && !currentUrl.contains('youtube.com/') && !currentUrl.contains('youtu.be/')) {
        currentUrl = currentUrl.split('?')[0];
      }
      return currentUrl;
    } catch (e) {
      print("[AIO ENGINE] Expand Error: $e");
      return url;
    }
  }

  static String _extractId(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.queryParameters.containsKey('v')) return uri.queryParameters['v']!;
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty) return segments.last;
      return DateTime.now().millisecondsSinceEpoch.toString();
    } catch (e) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  static Future<ScrapedMedia?> _getTiktokBtch(String url) async {
    try {
      print("[AIO ENGINE] Trying Btch/Tioo TikTok...");
      final encodedUrl = Uri.encodeComponent(url);
      final response = await http.get(
        Uri.parse('$_btchBase/ttdl?url=$encodedUrl'),
        headers: {'User-Agent': _mobileUA},
      ).timeout(const Duration(seconds: 20));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['result'] != null) {
          final res = data['result'];
          // Flexible parsing for different Btch/Tioo layouts
          final videoUrl = res['video'] ?? res['no_watermark'] ?? res['url'] ?? res['video_no_watermark'];
          final thumb = res['cover'] ?? res['thumbnail'] ?? res['origin_cover'];
          
          if (videoUrl != null) {
            String author = res['author']?['fullname'] ?? res['author']?['nickname'] ?? res['author']?['username'] ?? res['nickname'] ?? 'user';
            return ScrapedMedia(
              url: videoUrl,
              type: 'video', extension: '.mp4', platform: 'tiktok',
              author: author, 
              id: _extractId(url),
              thumbnailUrl: thumb ?? await _getFallbackThumbnail(url),
            );
          }
        }
      }
      return null;
    } catch (e) { print("[AIO ENGINE] TikTok Btch Error: $e"); return null; }
  }

  static Future<ScrapedMedia?> _getTiktokClassic(String url) async {
    try {
      final encodedUrl = Uri.encodeComponent(url);
      try {
        final response = await http.get(Uri.parse('$_nexrayBase/api/downloader/aio?url=$encodedUrl')).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == true && data['result'] != null && data['result']['url'] != null) {
            return ScrapedMedia(
              url: data['result']['url'], type: 'video', extension: '.mp4', platform: 'tiktok',
              author: data['result']['metadata']?['author'] ?? 'user', id: _extractId(url),
              thumbnailUrl: data['result']['metadata']?['thumbnail'] ?? await _getFallbackThumbnail(url),
            );
          }
        }
      } catch (_) {}
      
      try {
        final response = await http.get(Uri.parse('$_vredenBase/api/v1/download/tiktok?url=$encodedUrl')).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == true && data['result'] != null) {
            final res = data['result'];
            String author = res['author']?['fullname'] ?? res['author']?['nickname'] ?? res['metadata']?['author'] ?? res['nickname'] ?? 'user';
            return ScrapedMedia(
              url: res['download']?['nowm'] ?? res['download']?['wm'] ?? res['url'],
              type: 'video', extension: '.mp4', platform: 'tiktok',
              author: author, id: _extractId(url),
              thumbnailUrl: res['metadata']?['cover'] ?? await _getFallbackThumbnail(url),
            );
          }
        }
      } catch (_) {}

      // PRIORITAS 3: TikWm (Sangat stabil)
      print("[AIO ENGINE] Trying TikWm TikTok...");
      try {
        final tikRes = await http.post(
          Uri.parse('https://www.tikwm.com/api/'),
          body: {'url': url, 'count': '1', 'cursor': '0'},
        ).timeout(const Duration(seconds: 15));
        
        if (tikRes.statusCode == 200) {
          final data = json.decode(tikRes.body);
          if (data['code'] == 0 && data['data'] != null) {
            final res = data['data'];
            String author = res['author']?['fullname'] ?? res['author']?['nickname'] ?? 'user';
            final sizeNowm = res['size_nowm'] ?? res['size'];
            return ScrapedMedia(
              url: 'https://www.tikwm.com${res['play'] ?? res['wmplay']}',
              type: 'video', extension: '.mp4', platform: 'tiktok',
              author: author, id: res['id']?.toString() ?? _extractId(url),
              thumbnailUrl: res['cover'],
              fileSize: sizeNowm is int ? sizeNowm : null,
            );
          }
        }
      } catch (e) { print("[AIO ENGINE] TikWm Error: $e"); }

      return null;
    } catch (_) { return null; }
  }
  static Future<List<ScrapedMedia>?> _getTiktokMulti(String url) async {
    try {
      final encodedUrl = Uri.encodeComponent(url);
      final response = await http.get(Uri.parse('$_vredenBase/api/v1/download/tiktok?url=$encodedUrl')).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['result'] != null && data['result']['data'] != null) {
          final res = data['result'];
          print("[AIO ENGINE] TIKTOK JSON: ${json.encode(res)}");
          final mediaList = res['data'] as List;
          final isSlideshow = mediaList.any((m) => m['type'] == 'photo');
          
          // Single video with size info
          if (!isSlideshow && mediaList.isNotEmpty) {
            final author = res['author']?['fullname'] ?? res['author']?['full_name'] ?? res['author']?['nickname'] ?? res['metadata']?['author'] ?? 'user';
            final firstVideo = mediaList.firstWhere((m) => m['type'] != 'photo', orElse: () => mediaList.first);
            final sizeNowm = res['size_nowm'];
            return [
              ScrapedMedia(
                url: firstVideo['url'], type: 'video', extension: '.mp4', platform: 'tiktok',
                author: author, id: _extractId(url),
                thumbnailUrl: res['cover'] ?? res['metadata']?['cover'] ?? await _getFallbackThumbnail(url),
                fileSize: sizeNowm is int ? sizeNowm : null,
              ),
            ];
          }

          if (isSlideshow) {
            final author = res['author']?['fullname'] ?? res['author']?['full_name'] ?? res['author']?['nickname'] ?? res['metadata']?['author'] ?? 'user';
            final id = _extractId(url);
            final thumbFallback = res['metadata']?['cover'] ?? await _getFallbackThumbnail(url);
            
            return mediaList.where((m) => m['type'] == 'photo').toList().asMap().entries.map((entry) {
              final index = entry.key;
              final m = entry.value;
              return ScrapedMedia(
                url: m['url'], type: 'image', extension: '.jpg', platform: 'tiktok',
                author: author, id: '${id}_${index + 1}',
                thumbnailUrl: m['url'] ?? thumbFallback,
              );
            }).toList();
          }
        }
      }
      return null;
    } catch (e) { return null; }
  }
  static Future<List<ScrapedMedia>?> _getInstagramMulti(String url) async {
    try {
      final encodedUrl = Uri.encodeComponent(url);
      try {
        final vRes = await http.get(Uri.parse('$_vredenBase/api/v1/download/instagram?url=$encodedUrl'), headers: {'User-Agent': _mobileUA}).timeout(const Duration(seconds: 30));
        if (vRes.statusCode == 200) {
          final data = json.decode(vRes.body);
          if (data['status'] == true && data['result'] != null && data['result']['data'] != null) {
            print("[AIO ENGINE] INSTAGRAM JSON: ${json.encode(data['result'])}");
            final mediaList = data['result']['data'] as List;
            final res = data['result'];
            final username = res['profile']?['username'] ?? res['metadata']?['username'] ?? res['username'] ?? 'user';
            final thumbFallback = await _getFallbackThumbnail(url);
            return Future.wait(mediaList.asMap().entries.map((entry) async {
              final int index = entry.key;
              final m = entry.value;
              bool isVid = m['type'] == 'video';
              return ScrapedMedia(
                url: m['url'], type: isVid ? 'video' : 'image', extension: isVid ? '.mp4' : '.jpg',
                platform: 'instagram', author: username, id: '${_extractId(url)}_${index + 1}',
                thumbnailUrl: m['thumb'] ?? m['thumbnail'] ?? m['url'] ?? thumbFallback,
              );
            }));
          }
        }
      } catch (_) {}

      try {
        final response = await http.get(Uri.parse('$_nexrayBase/downloader/v2/instagram?url=$encodedUrl'), headers: {'User-Agent': _mobileUA}).timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == true && data['result'] != null) {
            final media = data['result']['media'] as List;
            final username = data['result']['owner_username'] ?? 'user';
            final shortCode = data['result']['shortcode'] ?? _extractId(url);
            final thumbFallback = await _getFallbackThumbnail(url);
            return Future.wait(media.asMap().entries.map((entry) async {
              final int index = entry.key;
              final m = entry.value;
              bool isVid = m['type'].toString().contains('mp4');
              return ScrapedMedia(
                url: m['url'], type: isVid ? 'video' : 'image', extension: isVid ? '.mp4' : '.jpg',
                platform: 'instagram', author: username, id: '${shortCode}_${index + 1}',
                thumbnailUrl: m['thumbnail'] ?? m['url'] ?? thumbFallback,
              );
            }));
          }
        }
      } catch (_) {}
      return null;
    } catch (e) { return null; }
  }

  static Future<ScrapedMedia?> _getFacebookBtch(String url) async {
    try {
      final encodedUrl = Uri.encodeComponent(url);
      final response = await http.get(Uri.parse('$_btchBase/fbdown?url=$encodedUrl'), headers: {'User-Agent': _mobileUA}).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['result'] != null) {
          final res = data['result'];
          return ScrapedMedia(
            url: res['download']?['hd'] ?? res['download']?['sd'] ?? res['url'],
            type: 'video', extension: '.mp4', platform: 'facebook',
            author: res['metadata']?['author'] ?? 'user', id: _extractId(url),
            thumbnailUrl: res['metadata']?['thumbnail'],
          );
        }
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<ScrapedMedia?> _getFacebookVreden(String url, {String quality = 'auto'}) async {
    try {
      final response = await http.get(Uri.parse('$_vredenBase/api/v1/download/facebook?url=$url')).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Corrected status check based on boolean 'status' field or 'status_code' 200
        if (data['status'] == true || data['status_code'] == 200) {
          final res = data['result'];
          final hd = res['download']['hd'];
          final sd = res['download']['sd'];
          
          // Quality Aware Selection
          String? link;
          if (quality == 'q1080' || quality == 'auto') {
            link = hd ?? sd;
          } else {
            link = sd ?? hd;
          }

          if (link == null) return null;

          return ScrapedMedia(
            url: link, type: 'video', extension: '.mp4', platform: 'facebook',
            author: res['title'] ?? 'Facebook User', id: _extractId(url),
            thumbnailUrl: res['thumbnail'],
          );
        }
      }
      return null;
    } catch (_) { return null; }
  }

  static Future<ScrapedMedia?> _getFacebookNexray(String url) async {
    try {
      final response = await http.get(Uri.parse('$_nexrayBase/downloader/facebook?url=$url')).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['result'] != null) {
          final res = data['result'];
          return ScrapedMedia(
            url: res['HD'] ?? res['Normal_video'], type: 'video', extension: '.mp4', platform: 'facebook',
            author: res['title'] ?? res['metadata']?['author'] ?? 'Facebook User', id: _extractId(url),
            thumbnailUrl: res['thumbnail'] ?? res['metadata']?['thumbnail'],
          );
        }
      }
      return null;
    } catch (_) { return null; }
  }

  /// YouTube: Fetch AUDIO only (fast, returns quickly)
  /// Video is fetched separately via getYoutubeVideoOnly()
  static Future<List<ScrapedMedia>?> _getYoutube(String url, {String quality = 'auto'}) async {
    try {
      print("[AIO ENGINE] Fetching YouTube Audio...");
      final encodedUrl = Uri.encodeComponent(url);
      final results = <ScrapedMedia>[];

      // 1. Try Nexray for AUDIO (30s)
      bool audioSuccess = false;
      try {
        print("[AIO ENGINE] Trying Nexray Audio...");
        final nUrl = '$_nexrayBase/downloader/ytmp3?url=$encodedUrl';
        final response = await http.get(Uri.parse(nUrl)).timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == true && data['result'] != null) {
            final res = data['result'];
            results.add(ScrapedMedia(
              url: res['url'],
              type: 'audio',
              extension: '.mp3',
              platform: 'youtube',
              author: 'YouTube User',
              id: _extractId(url) + "_audio",
              thumbnailUrl: null,
              title: res['title'],
            ));
            audioSuccess = true;
          }
        }
      } catch (e) {
        print("[AIO ENGINE] YT Nexray Audio Error: $e");
      }

      // 2. Fallback to Azbry for AUDIO (60s)
      if (!audioSuccess) {
        try {
          print("[AIO ENGINE] Nexray Audio failed, trying Azbry...");
          final aUrl = '$_azbryBase/api/download/ytmp3?url=$encodedUrl';
          final response = await http.get(Uri.parse(aUrl)).timeout(const Duration(seconds: 60));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['status'] == true && data['result'] != null) {
              final res = data['result'];
              if (res['download'] != null && res['download'] != "Waiting...") {
                results.add(ScrapedMedia(
                  url: res['download'],
                  type: 'audio',
                  extension: '.mp3',
                  platform: 'youtube',
                  author: 'YouTube User',
                  id: _extractId(url) + "_audio",
                  thumbnailUrl: res['thumbnail'],
                  title: res['title'],
                ));
              }
            }
          }
        } catch (e) {
          print("[AIO ENGINE] YT Azbry Audio Error: $e");
        }
      }

      return results.isNotEmpty ? results : null;
    } catch (e) {
      print("[AIO ENGINE] YouTube Audio Scraper Error: $e");
      return null;
    }
  }

  /// YouTube: Fetch VIDEO only (slow, 120s timeout per API)
  /// Called separately in background by download_service
  static Future<ScrapedMedia?> getYoutubeVideoOnly(String url, {String quality = 'auto'}) async {
    try {
      print("[AIO ENGINE] Fetching YouTube Video (Nexray Primary, 30s)...");
      final encodedUrl = Uri.encodeComponent(url);
      
      String vQual = '720';
      if (quality == 'q1080') vQual = '1080';
      if (quality == 'q360') vQual = '360';

      // 1. Try Nexray Video (30s timeout here to switch fast to Azbry)
      try {
        print("[AIO ENGINE] Trying Nexray Ytmp4 (30s)...");
        final nUrl = '$_nexrayBase/downloader/ytmp4?url=$encodedUrl&resolusi=$vQual';
        final response = await http.get(Uri.parse(nUrl)).timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == true && data['result'] != null) {
            final res = data['result'];
            print("[AIO ENGINE] ✅ YouTube Video found via Nexray Ytmp4!");
            return ScrapedMedia(
              url: res['url'],
              type: 'video',
              extension: '.mp4',
              platform: 'youtube',
              author: 'YouTube User',
              id: _extractId(url),
              thumbnailUrl: res['thumbnail'],
              title: res['title'],
            );
          }
        }
      } catch (e) {
        print("[AIO ENGINE] YT Nexray Ytmp4 Error (30s): $e");
      }

      // 2. Fallback to Azbry Video (120s timeout)
      try {
        print("[AIO ENGINE] Nexray slow/failed, trying Azbry (120s)...");
        final aUrl = '$_azbryBase/api/download/ytmp4?url=$encodedUrl';
        final response = await http.get(Uri.parse(aUrl)).timeout(const Duration(seconds: 120));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == true && data['result'] != null) {
            final res = data['result'];
            if (res['download'] != null && res['download'] != "Waiting...") {
              print("[AIO ENGINE] ✅ YouTube Video found via Azbry!");
              return ScrapedMedia(
                url: res['download'],
                type: 'video',
                extension: '.mp4',
                platform: 'youtube',
                author: 'YouTube User',
                id: _extractId(url),
                thumbnailUrl: res['thumbnail'],
                title: res['title'],
              );
            }
          }
        }
      } catch (e) {
        print("[AIO ENGINE] YT Azbry Video Error: $e");
      }

      print("[AIO ENGINE] ❌ YouTube Video: all APIs failed");
      return null;
    } catch (e) {
      print("[AIO ENGINE] YouTube Video Scraper Error: $e");
      return null;
    }
  }

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
          final resList = data['result'] as List;
          return Future.wait(resList.asMap().entries.map<Future<ScrapedMedia>>((entry) async {
            final int index = entry.key;
            final item = entry.value;
            final link = item['video_file_url'] ?? item['videoimg_file_url'] ?? item['image'];
            bool isVid = link.toString().contains('.mp4') || (item['title'] ?? '').toString().toLowerCase().contains('video');
            return ScrapedMedia(
              url: link, type: isVid ? 'video' : 'image', extension: isVid ? '.mp4' : '.jpg',
              platform: 'universal', author: 'user', id: '${_extractId(targetUrl)}_${index + 1}',
              thumbnailUrl: item['thumbnail'] ?? item['image'] ?? item['videoimg_file_url'] ?? await _getFallbackThumbnail(targetUrl),
            );
          }));
        }
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<List<ScrapedMedia>?> _getTwitter(String url) async {
    try {
      print("[AIO ENGINE] Fetching Twitter/X Content...");
      final encodedUrl = Uri.encodeComponent(url);
      final apiUrl = '$_chocomilkBase/v1/download/twitter?url=$encodedUrl';
      print("[AIO ENGINE] Twitter API URL: $apiUrl");
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 30));

      print("[AIO ENGINE] Twitter API Status: ${response.statusCode}");
      print("[AIO ENGINE] Twitter API Body (first 500): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // API returns success: true (boolean field)
        bool isSuccess = data['success'] == true || data['status'] == 'success' || data['code'] == 200;
        print("[AIO ENGINE] Twitter isSuccess: $isSuccess, data!=null: ${data['data'] != null}");
        
        if (isSuccess && data['data'] != null) {
          final tweetData = data['data'];
          final author = tweetData['author']?['name'] ?? tweetData['author']?['screen_name'] ?? 'Twitter User';
          final title = tweetData['caption'] ?? tweetData['content'] ?? '';
          final tweetId = tweetData['id'] ?? _extractId(url);
          final media = tweetData['media'];
          print("[AIO ENGINE] Twitter author: $author, tweetId: $tweetId");
          print("[AIO ENGINE] Twitter media: $media");
          print("[AIO ENGINE] Twitter media type: ${media.runtimeType}");
          
          final results = <ScrapedMedia>[];
          
          if (media != null && media is Map) {
            // Handle Videos
            final videos = media['videos'];
            print("[AIO ENGINE] Twitter videos field: $videos (type: ${videos.runtimeType})");
            if (videos != null && videos is List && videos.isNotEmpty) {
              for (int i = 0; i < videos.length; i++) {
                final vid = videos[i];
                if (vid == null || vid['url'] == null) continue;
                print("[AIO ENGINE] Twitter video $i: ${vid['url']}");
                results.add(ScrapedMedia(
                  url: vid['url'],
                  type: 'video',
                  extension: '.mp4',
                  platform: 'twitter',
                  author: author,
                  id: '${tweetId}_video_$i',
                  thumbnailUrl: vid['thumbnail_url'],
                  title: title,
                ));
              }
            }
            
            // Handle Photos
            final photos = media['photos'];
            print("[AIO ENGINE] Twitter photos field: $photos (type: ${photos.runtimeType})");
            if (photos != null && photos is List && photos.isNotEmpty) {
              for (int i = 0; i < photos.length; i++) {
                final img = photos[i];
                if (img == null || img['url'] == null) continue;
                print("[AIO ENGINE] Twitter photo $i: ${img['url']}");
                results.add(ScrapedMedia(
                  url: img['url'],
                  type: 'image',
                  extension: '.jpg',
                  platform: 'twitter',
                  author: author,
                  id: '${tweetId}_photo_$i',
                  thumbnailUrl: img['url'],
                  title: title,
                ));
              }
            }
          }
          
          print("[AIO ENGINE] Twitter results count: ${results.length}");
          return results.isNotEmpty ? results : null;
        }
      }
    } catch (e) {
      print("[AIO ENGINE] Twitter Scraper Error: $e");
    }
    return null;
  }

  static Future<String?> _getFallbackThumbnail(String targetUrl) async {
    try {
      // Use "facebookexternalhit" to bypass login walls for metadata
      const scraperUA = 'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)';
      
      final res = await http.get(
        Uri.parse(targetUrl), 
        headers: {
          'User-Agent': scraperUA,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
        }
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        // Method 1: HTML Parsing (Standard)
        final doc = html_parser.parse(res.body);
        final metaImg = doc.querySelector('meta[property="og:image"]')?.attributes['content'] ??
                        doc.querySelector('meta[name="twitter:image"]')?.attributes['content'] ??
                        doc.querySelector('meta[property="og:image:secure_url"]')?.attributes['content'] ??
                        doc.querySelector('meta[name="thumbnail"]')?.attributes['content'] ??
                        doc.querySelector('link[rel="image_src"]')?.attributes['href'];
        
        if (metaImg != null) return metaImg;

        // Method 2: Regex extraction (Fallback if parser fails)
        final ogMatch = RegExp(r'property="og:image"\s+content="([^"]+)"').firstMatch(res.body);
        if (ogMatch != null) return ogMatch.group(1);

        final twitterMatch = RegExp(r'name="twitter:image"\s+content="([^"]+)"').firstMatch(res.body);
        if (twitterMatch != null) return twitterMatch.group(1);
      }
    } catch (_) {}
    return null;
  }

  static Future<List<ScrapedMedia>?> _getThreads(String url) async {
    try {
      print("[AIO ENGINE] Fetching Threads Content...");
      final expandedUrl = await _expandUrl(url);
      final encodedUrl = Uri.encodeComponent(expandedUrl);
      
      // Pre-fetch fallback thumbnail from metadata
      final fallbackThumb = await _getFallbackThumbnail(expandedUrl);
      
      // 1. Try Threadsmate (Direct Scraping per User Request)
      try {
        print("[AIO ENGINE] Trying Threadsmate Scraper...");
        final res = await _getThreadsThreadsmate(expandedUrl, fallbackThumb: fallbackThumb);
        if (res != null && res.isNotEmpty) return res;
      } catch (e) {
        print("[AIO ENGINE] Threadsmate Error: $e");
      }

      // 2. Try Vreden (Robust Fallback)
      try {
        print("[AIO ENGINE] Trying Vreden Threads...");
        final vUrl = '$_vredenBase/api/v1/download/threads?url=$encodedUrl';
        final response = await http.get(Uri.parse(vUrl)).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == true && data['result'] != null) {
            final res = data['result'];
            final mediaList = res['data'] as List;
            final username = res['profile']?['username'] ?? res['metadata']?['username'] ?? 'threads_user';
            final id = _extractId(url);
            
            if (mediaList.isNotEmpty) {
              return mediaList.asMap().entries.map((entry) {
                final index = entry.key;
                final m = entry.value;
                bool isVid = m['type'] == 'video' || (m['url'] ?? '').toString().contains('.mp4');
                return ScrapedMedia(
                  url: m['url'], 
                  type: isVid ? 'video' : 'image', 
                  extension: isVid ? '.mp4' : '.jpg',
                  platform: 'threads', 
                  author: username, 
                  id: '${id}_${index + 1}',
                  thumbnailUrl: m['thumbnail'] ?? m['url'] ?? fallbackThumb,
                );
              }).toList();
            }
          }
        }
      } catch (e) {
        print("[AIO ENGINE] Threads Vreden Error: $e");
      }

      // 3. Try Nexray (Fallback)
      try {
        print("[AIO ENGINE] Trying Nexray Threads...");
        final nUrl = '$_nexrayBase/downloader/threads?url=$encodedUrl';
        final response = await http.get(Uri.parse(nUrl)).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == true && data['result'] != null) {
            final res = data['result'];
            final mediaList = res['media'] as List;
            final username = res['username'] ?? 'threads_user';
            final id = _extractId(url);
            
            if (mediaList.isNotEmpty) {
              return mediaList.asMap().entries.map((entry) {
                final index = entry.key;
                final m = entry.value;
                bool isVid = m['type'] == 'video' || (m['url'] ?? '').toString().contains('.mp4');
                return ScrapedMedia(
                  url: m['url'], 
                  type: isVid ? 'video' : 'image', 
                  extension: isVid ? '.mp4' : '.jpg',
                  platform: 'threads', 
                  author: username, 
                  id: '${id}_${index + 1}',
                  thumbnailUrl: m['thumbnail'] ?? m['url'] ?? fallbackThumb,
                );
              }).toList();
            }
          }
        }
      } catch (e) {
        print("[AIO ENGINE] Threads Nexray Error: $e");
      }

      return null;
    } catch (e) {
      print("[AIO ENGINE] Threads Scraper Error: $e");
      return null;
    }
  }

  static Future<List<ScrapedMedia>?> _getThreadsThreadsmate(String url, {String? fallbackThumb}) async {
    try {
      const baseUrl = 'https://threadsmate.com';
      final client = http.Client();
      
      try {
        // Step 1: Get landing page to extract dynamic token name and value
        final response = await client.get(Uri.parse('$baseUrl/id'), headers: {'User-Agent': _mobileUA}).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) return null;
        
        // Find token (e.g. <input type="hidden" name="_ykxeE" value="...">)
        final doc = html_parser.parse(response.body);
        final hiddenInput = doc.querySelector('form#form-action input[type="hidden"]');
        if (hiddenInput == null) return null;
        
        final tokenName = hiddenInput.attributes['name'];
        final tokenValue = hiddenInput.attributes['value'];
        if (tokenName == null || tokenValue == null) return null;
        
        // Step 2: POST to action
        final postRes = await client.post(
          Uri.parse('$baseUrl/action'),
          headers: {
            'User-Agent': _mobileUA,
            'Referer': '$baseUrl/id',
            'X-Requested-With': 'XMLHttpRequest',
          },
          body: {
            'url': url,
            'lang': 'id',
            tokenName: tokenValue,
          },
        ).timeout(const Duration(seconds: 20));
        
        if (postRes.statusCode != 200) return null;
        
        // Result is usually HTML snippet in "result" field or direct HTML
        String htmlResult = postRes.body;
        try {
          final data = json.decode(postRes.body);
          if (data['status'] == true && data['result'] != null) {
            htmlResult = data['result'];
          }
        } catch (_) {}
        
        final resDoc = html_parser.parse(htmlResult);
        final author = resDoc.querySelector('.author-name')?.text.trim() ?? 'threads_user';
        final id = _extractId(url);
        
        final items = <ScrapedMedia>[];
        
        // Video items
        final videoBtn = resDoc.querySelector('a.download-btn[href*="video"]');
        if (videoBtn != null) {
          items.add(ScrapedMedia(
            url: videoBtn.attributes['href']!,
            type: 'video', extension: '.mp4', platform: 'threads',
            author: author, id: id,
            thumbnailUrl: fallbackThumb
          ));
        }
        
        // Image items (if any, often in carousel)
        final images = resDoc.querySelectorAll('a.download-btn[href*="image"], a.download-btn[href*="static"]');
        for (int i = 0; i < images.length; i++) {
          final imgUrl = images[i].attributes['href']!;
          items.add(ScrapedMedia(
            url: imgUrl,
            type: 'image', extension: '.jpg', platform: 'threads',
            author: author, id: '${id}_$i',
            thumbnailUrl: imgUrl.contains('threadsmate.com') ? fallbackThumb : imgUrl
          ));
        }
        
        // Fallback for general buttons if specific type detection failed
        if (items.isEmpty) {
          final allBtns = resDoc.querySelectorAll('a.download-btn');
          for (int i = 0; i < allBtns.length; i++) {
            final link = allBtns[i].attributes['href'];
            if (link == null || link.startsWith('#')) continue;
            bool isVid = link.contains('.mp4') || link.contains('video');
            items.add(ScrapedMedia(
              url: link,
              type: isVid ? 'video' : 'image',
              extension: isVid ? '.mp4' : '.jpg',
              platform: 'threads',
              author: author, id: '${id}_$i',
              thumbnailUrl: fallbackThumb
            ));
          }
        }
        
        return items.isNotEmpty ? items : null;
      } finally {
        client.close();
      }
    } catch (e) {
      print("[AIO ENGINE] Threadsmate Scraper Detailed Error: $e");
      return null;
    }
  }
}
