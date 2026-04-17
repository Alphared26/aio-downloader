import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'services/download_service.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'services/update_service.dart';
import 'pages/home_page.dart';
import 'pages/history_page.dart';
import 'pages/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  DownloadService.initForegroundTask();
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('NotificationService init error: $e');
  }
  await SettingsService().init();

  // Lock portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, DeviceOrientation.portraitDown,
  ]);

  // Dark status/nav bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF08080F),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DownloadService()),
        ChangeNotifierProvider(create: (_) => SettingsService()),
      ],
      child: const AIODownloaderApp(),
    ),
  );
}

class AIODownloaderApp extends StatelessWidget {
  const AIODownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AIO Downloader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF08080F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4D8EFF),
          secondary: Color(0xFFA855F7),
          surface: Color(0xFF111120),
          onSurface: Colors.white,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedTab = 0;
  late StreamSubscription _intentSub;
  late StreamSubscription _statusSub;


  @override
  void initState() {
    super.initState();

    // Listen to download status events and show popups
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _statusSub = context.read<DownloadService>().statusStream.listen(_showStatusMessage);
      // Check for app updates from GitHub
      UpdateService.checkForUpdate(context);
    });

    final svc = context.read<DownloadService>();

    final settings = context.read<SettingsService>();

    // Handle intent when app is cold-started
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        setState(() => _selectedTab = 0);
        final doAuto = settings.autoDownloadShare;
        svc.scrapeUrl(value.first.path, settings.quality, silentAutoDownload: doAuto);
      }
    });

    // Handle intent while app is running
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        setState(() => _selectedTab = 0);
        final doAuto = settings.autoDownloadShare;
        svc.scrapeUrl(value.first.path, settings.quality, silentAutoDownload: doAuto);
      }
    });
  }

  @override
  void dispose() {
    _intentSub.cancel();
    _statusSub.cancel();
    super.dispose();
  }

  void _showStatusMessage(DownloadStatusEvent event) {
    if (!mounted) return;
    final Color bgColor;
    final IconData icon;
    switch (event.type) {
      case DownloadStatusType.success:
        bgColor = const Color(0xFF1A3A2A);
        icon = Icons.check_circle_rounded;
        break;
      case DownloadStatusType.failure:
        bgColor = const Color(0xFF3A1A1A);
        icon = Icons.error_rounded;
        break;
      case DownloadStatusType.invalid:
        bgColor = const Color(0xFF2A2A1A);
        icon = Icons.warning_rounded;
        break;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(event.message,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        backgroundColor: const Color(0xFF08080F),
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar
              _buildTopBar(),
              // Page Content
              Expanded(child: _buildPage()),
            ],
          ),
        ),
        // Bottom Navigation
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1A1A2E), width: 1)),
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [Color(0xFF4D8EFF), Color(0xFFA855F7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.cloud_download_rounded,
              color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AIO Downloader',
                style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w800,
                  color: Colors.white,
                )),
              Text('by Alphared26',
                style: GoogleFonts.inter(
                  fontSize: 10, color: Colors.white38,
                )),
            ],
          ),
          const Spacer(),
          // Page title badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4D8EFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF4D8EFF).withOpacity(0.3)),
            ),
            child: Text(
              _selectedTab == 0 ? 'Unduhan' : _selectedTab == 1 ? 'Riwayat' : 'Setelan',
              style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: const Color(0xFF4D8EFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage() {
    switch (_selectedTab) {
      case 0: return const HomePage();
      case 1: return const HistoryPage();
      case 2: return const SettingsPage();
      default: return const HomePage();
    }
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D19),
        border: Border(top: BorderSide(color: Color(0xFF1A1A2E), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              _navItem(0, Icons.download_rounded, Icons.download_rounded, 'Unduhan'),
              _navItem(1, Icons.history_rounded, Icons.history_rounded, 'Riwayat'),
              _navItem(2, Icons.settings_rounded, Icons.settings_rounded, 'Setelan'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label) {
    final bool isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isActive ? const Color(0xFF4D8EFF).withOpacity(0.1) : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  color: isActive ? const Color(0xFF4D8EFF) : Colors.white24,
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(label,
                style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: isActive ? const Color(0xFF4D8EFF) : Colors.white24,
                )),
            ],
          ),
        ),
      ),
    );
  }
}
