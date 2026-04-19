# Changelog v2.8.0

## What's New
*   **Threads Downloader Support**: Full media download support for Threads (threads.com/net) using a 3-tier failover engine (Threadsmate, Vreden, Nexray). 🧵
*   **Media Thumbnails in History**: Download history now features rich media previews (thumbnails) instead of generic icons for a better visual experience. 📸
*   **History Action Menu**: Added a three-dot menu for each history item with options to **Share** (Bagikan), **Open In** (Buka di...), and **Delete**. 🔘
*   **WhatsApp Status Saver**: New dedicated tab for saving WhatsApp statuses (Photos & Videos) directly to your gallery. 🟢
*   **SAF Backup Solution**: Added "Manual Folder Selection" via Storage Access Framework (SAF) if direct storage permissions are denied. 📂

## Improvements & UX
*   **Robust File Sharing**: Implemented temporary file buffering to ensure "Share" functionality works seamlessly across all Android apps. 🚀
*   **Intelligent Size Estimation**: Enhanced `Content-Length` fetching with custom headers and Range-request fallback for strict servers (Threads/FB). ⚡
*   **History Stabilization**: Limited history to 100 items and added deep safety-checks for SharedPreferences to prevent app crashes. 🧱
*   **Native Video Thumbnails**: WhatsApp Status previews are now instant using native `MediaMetadataRetriever` via Android Method Channel. 🎬
*   **4-Tab Navigation**: Updated bottom navigation: Downloads, Status Saver, History, and Settings. 🧭
*   **Reactive Settings**: Refactored settings to be fully reactive; toggles for Auto-Download and Notifications now update instantly. ⚡
*   **UI Cleanup**: Modernized history layout and cleaned up HomePage header for a more premium look. ✨

---

# Changelog v2.0.0

## What's New
*   **Batch Downloading**: Simultaneous multi-file downloads are now supported. 📥
*   **TikTok Slideshow Support**: Full carousel-style selection and download for TikTok photo posts. 📸
*   **Intelligent Filename Formatting**: Standardized as `platform_author_index_date`. 🏷️
*   **Enhanced Metadata**: Highly accurate profile extraction for Instagram, TikTok, and Facebook. 👤

## Improvements & UX
*   **Twitter/X Download Support**: Full support for video and image posts from `twitter.com` and `x.com` via the Chocomilk API. 🐦
*   **New Azbry API Integration**: YouTube videos and audio now use the Azbry API as a robust fallback when primary sources are slow. 📡
*   **Faster YouTube Failover**: Reduced Nexray timeout to 30 seconds to trigger the Azbry fallback quicker, ensuring a smooth user experience. ⚡
*   **YouTube API Cleanup**: Removed Vreden YouTube sources and the experimental YTDL endpoint for a cleaner, more reliable engine. 🧹
*   **Quality Picker di Halaman Unduhan**: Pilih resolusi (Auto/720p/1080p) langsung di halaman hasil scraping. 🎬
*   **Auto-Check Update**: Aplikasi otomatis cek GitHub Releases saat dibuka. Jika ada versi baru, akan muncul dialog dengan changelog dan tombol download. 🔔
*   **YouTube Audio-First**: Audio YouTube langsung tampil ~5 detik. Video di-fetch di background (pindah otomatis ke Azbry jika Nexray lama). 🎵
*   **Updated History UI**: Clearer item differentiation with Video and Image specific icons. 🎥🖼️
*   **Undo Delete**: A 5-second window to restore accidentally deleted history records. ⏳
*   **Automatic Storage Cleanup**: Physical files are removed alongside history entries for privacy and storage efficiency. 🧹
*   **Smart URL Extractor**: Directly share posts with full captions, and the app will intelligently find the link. 🔗

## Settings
*   Added **Auto-Download** toggle for shared links. ⚙️

## Size
*   Compressing and deleting unnecessary files to make the app size smaller
