import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:html/parser.dart' as html_parser;

class ScrapedMedia {
  final String url;
  final String type; // 'video', 'image', or 'audio'
  final String extension; // '.mp4', '.jpg', '.mp3', etc.
  final String platform;
  final String author;
  final String id;
  final String? thumbnailUrl;

  ScrapedMedia({
    required this.url, 
    required this.type, 
    required this.extension,
    this.platform = 'unknown',
    this.author = 'user',
    this.id = '',
    this.thumbnailUrl,
  });
}

class AntiGravityEngine {
  static const String _nexrayBase = 'https://api.nexray.web.id';
  static const String _vredenBase = 'https://api.vreden.my.id';
  static const String _btchBase = 'https://backend1.tioo.eu.org';
  
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
      
      String expandedUrl = url;
      bool isSocial = url.contains('tiktok.com') || 
                      url.contains('instagram.com') || 
                      url.contains('facebook.com') || 
                      url.contains('fb.watch') || 
                      url.contains('fb.com') || 
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
            return ScrapedMedia(
              url: 'https://www.tikwm.com${res['play'] ?? res['wmplay']}',
              type: 'video', extension: '.mp4', platform: 'tiktok',
              author: author, id: res['id']?.toString() ?? _extractId(url),
              thumbnailUrl: res['cover'],
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

  static Future<List<ScrapedMedia>?> _getYoutube(String url, {String quality = 'auto'}) async {
    try {
      print("[AIO ENGINE] Fetching YouTube from Vreden (Video & Audio)...");
      final encodedUrl = Uri.encodeComponent(url);
      
      // Map quality to Vreden format
      String vQual = 'hd720';
      if (quality == 'q1080') vQual = 'hd1080';
      if (quality == 'q360') vQual = 'medium';

      final results = <ScrapedMedia>[];

      // 1. Fetch VIDEO
      try {
        final vUrl = '$_vredenBase/api/v1/download/youtube/video?url=$encodedUrl&quality=$vQual';
        final response = await http.get(Uri.parse(vUrl)).timeout(const Duration(seconds: 25));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == true && data['result'] != null) {
            final res = data['result'];
            if (res['download'] != null && res['download']['url'] != null) {
              final meta = res['metadata'];
              results.add(ScrapedMedia(
                url: res['download']['url'],
                type: 'video',
                extension: '.mp4',
                platform: 'youtube',
                author: meta?['author']?['name'] ?? 'YouTube User',
                id: meta?['videoId'] ?? _extractId(url),
                thumbnailUrl: meta?['thumbnail'],
              ));
            }
          }
        }
      } catch (e) {
        print("[AIO ENGINE] YT Video Error: $e");
      }

      // 2. Fetch AUDIO
      try {
        final aUrl = '$_vredenBase/api/v1/download/youtube/audio?url=$encodedUrl&quality=128';
        final response = await http.get(Uri.parse(aUrl)).timeout(const Duration(seconds: 25));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == true && data['result'] != null) {
            final res = data['result'];
            if (res['download'] != null && res['download']['url'] != null) {
              final meta = res['metadata'];
              results.add(ScrapedMedia(
                url: res['download']['url'],
                type: 'audio',
                extension: '.mp3',
                platform: 'youtube',
                author: meta?['author']?['name'] ?? 'YouTube User',
                id: (meta?['videoId'] ?? _extractId(url)) + "_audio",
                thumbnailUrl: meta?['thumbnail'],
              ));
            }
          }
        }
      } catch (e) {
        print("[AIO ENGINE] YT Audio Error: $e");
      }

      return results.isNotEmpty ? results : null;
    } catch (e) {
      print("[AIO ENGINE] YouTube Scraper Error: $e");
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
}
