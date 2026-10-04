# 📱 QuickScan PDF (Auto Document Scanner & PDF Maker)

An automated Android document scanner app built with Flutter and powered by **Google ML Kit Document Scanner API**.

## ✨ Features
- 📸 **Auto Edge Detection**: Automatically identifies paper/document borders in real-time.
- ⚡ **Auto-Capture**: Snaps pages automatically as soon as the camera is steady.
- 📐 **Perspective Crop & Shadow Removal**: Straightens tilted documents and cleans shadows.
- 📄 **Multi-Page Scanning**: Scan continuous pages into a single document.
- 🎨 **Image Enhancement Filters**: Auto, Color, and Grayscale filters.
- 📑 **Instant PDF Creation**: Compiles scanned pages into standard A4 PDF files.
- 🔍 **In-App PDF Viewer**: Built-in viewer with zoom, print, and share capabilities.
- 📤 **One-Tap Share & Save**: Share instantly via WhatsApp, Gmail, Telegram, Bluetooth, etc.
- 📂 **Offline Document Manager**: Search, rename, and manage all your saved PDFs offline.

---

## 🚀 How to Build the APK

### Method 1: Instant Cloud Build (No Installation Needed on PC)
1. Push this project to your GitHub account (public or private).
2. Go to the **Actions** tab on GitHub.
3. The build runs automatically on every push, or you can click **Run workflow**.
4. Once finished (~3 minutes), download the ready-to-install `QuickScan_PDF_Release_APK` from the **Artifacts** section!

### Method 2: Local Build
1. Install Flutter SDK and Java 17.
2. Run:
   ```bash
   flutter pub get
   flutter build apk --release
   ```
3. Your compiled APK will be located at:
   `build/app/outputs/flutter-apk/app-release.apk`
