<div align="center">

<img src="/icon.png" width="96" alt="AIO Downloader Icon"/>

# AIO Downloader
### Download video & foto dari mana saja

[![Release](https://img.shields.io/github/v/release/Alphared26/aio-downloader?style=flat-square&color=4D8EFF)](https://github.com/Alphared26/aio-downloader/releases)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=flat-square&logo=android)](https://github.com/Alphared26/aio-downloader/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-54C5F8?style=flat-square&logo=flutter)](https://flutter.dev)

</div>

---

## ✨ Fitur

| Fitur | Keterangan |
|---|---|
| 📥 Multi-Platform | Instagram, TikTok, Facebook, YouTube |
| 🔗 Share Intent | Bagikan link dari app lain → langsung unduh |
| 📊 Progress Real-time | Progress bar + notifikasi persentase |
| 🔔 Background Download | Download tetap berjalan walau app di-minimize |
| 📂 Custom Folder | Pilih folder penyimpanan sendiri |
| 🗂️ Riwayat | Lihat semua file yang pernah diunduh |
| 🖼️ Buka File | Tap riwayat → buka langsung di galeri |

## 📲 Download

Lihat di halaman **[Releases](https://github.com/Alphared26/aio-downloader/releases)** untuk download APK terbaru.

## 🛠️ Build

```bash
# Clone repo
git clone https://github.com/Alphared26/aio-downloader.git
cd aio-downloader

# Install dependencies
flutter pub get

# Run (debug)
flutter run

# Build APK release
flutter build apk --release --split-per-abi
```

## 📡 API Backend

| Platform | API |
|---|---|
| Instagram | Vreden v1 (primary) + Nexray v2 (fallback) |
| TikTok | Tioo/Btch + TikWM fallback |
| Facebook | Tioo/Btch + Vreden + Nexray |
| YouTube | Nexray + youtube_explode_dart |

## 📁 Struktur Project

```
lib/
├── main.dart              # Entry point + UI shell
├── scraper_engine.dart    # Engine scraping semua platform
├── services/
│   ├── download_service.dart    # Background download + progress
│   ├── history_service.dart     # Riwayat unduhan
│   ├── notification_service.dart # Notifikasi sistem
│   └── settings_service.dart    # Pengaturan app
└── pages/
    ├── home_page.dart     # Halaman utama (download)
    ├── history_page.dart  # Riwayat unduhan
    └── settings_page.dart # Pengaturan
```

## 👤 Developer

**Alphared26** — [github.com/Alphared26](https://github.com/Alphared26)

---

<div align="center">
<sub>AIO Downloader v2.0.0 · Built with Flutter</sub>
</div>
