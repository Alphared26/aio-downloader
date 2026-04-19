# Changelog v2.8.0

## What's New
*   **WhatsApp Status Saver**: Tab baru khusus untuk menyimpan status WhatsApp (Foto & Video) langsung ke galeri. 🟢
*   **SAF Backup Solution**: Menambahkan opsi "Pilih Folder Manual" menggunakan Storage Access Framework (SAF) jika izin direct storage ditolak. 📂
*   **Native Video Thumbnails**: Preview video status WhatsApp kini tampil instan menggunakan native `MediaMetadataRetriever` via Android Method Channel. 🎬
*   **4-Tab Navigation**: Navigasi bawah diperbarui menjadi 4 bagian: Unduhan, Status Saver, Riwayat, dan Setelan. 🧭

## Improvements & UX
*   **Reactive Settings**: Me-refactor sistem pengaturan menjadi reaktif; perubahan toggle (Unduh Otomatis & Notifikasi) kini berubah secara instan. ⚡
*   **Notification Permission Gate**: Toggle "Notifikasi Progres" kini mengecek izin sistem terlebih dahulu sebelum diaktifkan untuk menghindari error. 🔔
*   **Twitter/X Detection**: Deteksi URL `twitter.com` dan `x.com` dioptimalkan agar lebih cepat dan akurat. 🐦
*   **Dynamic Size Estimation**: Estimasi ukuran file kini berubah secara cerdas saat Anda mengganti resolusi (720p/1080p). ⚡
*   **UI Cleanup (Home)**: Tampilan header HomePage lebih bersih dengan menghapus daftar teks platform statis. ✨
*   **Expanded Platform List**: "X" dan "WhatsApp" kini resmi terdaftar di daftar Platform yang Didukung pada halaman Setelan. 🛠️
*   **Under-the-Hood Fixes**: Menghapus library SAF pihak ketiga yang tidak stabil dan menggantinya dengan akses file langsung serta native method channels untuk performa lebih handal. 🧱

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
