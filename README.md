# XAPK & Split APK Installer (Flutter)

A modern, lightweight, and robust Android package installer built with **Flutter** and **Kotlin**, specifically optimized for devices like the **Xiaomi Redmi Note 10 (Snapdragon 678, ARM64-v8a)** running MIUI / HyperOS.

---

## 🌟 Key Features

- **XAPK & APKS Support**: Automatically extracts and installs multi-split APKs (base APK + config APKs for ABI, screen density, and languages).
- **Native PackageInstaller Session Engine**: Uses Android's official `PackageInstaller.Session` API via Kotlin platform channels for seamless installation.
- **MIUI Optimization Intelligence**: Detects Xiaomi/Redmi devices and guides users with step-by-step instructions when MIUI's internal verification blocks split APK installations.
- **Android 11+ Scoped Storage & OBB Handling**: Features integrated Storage Access Framework (SAF) to copy game `.obb` assets to `/sdcard/Android/obb/<package_name>/`.
- **Auto-Scanner & File Picker**: One-tap quick scan for `.xapk` / `.apks` files in `/sdcard/Download`, plus a manual file selector for any storage location.
- **Rich Package Inspection**: Previews app name, package name, version, icon, total extraction size, split architecture, and Android SDK compatibility (`minSdkVersion` vs device SDK).
- **Install Activity Log**: Persists installation history locally using SharedPreferences.
- **Enterprise Dark Slate UI**: Follows modern Craft 2026 guidelines (typography-first, neutral Slate/Sky palette, zero AI neon clutter).

---

## 📱 Hardware & OS Compatibility

- **Target Device**: Xiaomi Redmi Note 10 (`M2101K7AG`)
- **Processor**: Qualcomm Snapdragon 678 (64-bit `arm64-v8a`)
- **Supported OS**: Android 11 (API 30), Android 12 (API 31), Android 13+ (API 33+)

---

## 🏗️ Architecture

```text
lib/
├── main.dart                      # Theme configuration & app bootstrap
├── models/
│   ├── xapk_info.dart             # Parsed XAPK manifest & split attributes
│   └── install_history.dart       # Installation history data model
├── screens/
│   └── dashboard_screen.dart      # Main dashboard with scanner & tabs
├── services/
│   ├── history_service.dart       # SharedPreferences persistence layer
│   └── xapk_service.dart          # ZIP stream decoder & platform channel caller
└── widgets/
    ├── miui_guide_dialog.dart     # Troubleshooting guide for MIUI Optimization
    └── xapk_preview_sheet.dart    # Package details & realtime progress indicator

android/
└── app/src/main/kotlin/.../
    └── MainActivity.kt            # Native PackageInstaller.Session & SAF OBB copier
```

---

## 🚀 Building & Running

### Prerequisites
- Flutter SDK 3.24+ (Dart 3.5+)
- Android SDK (API 31+)
- Connected Android device with USB Debugging enabled

### Steps

1. **Clone repository**:
   ```bash
   git clone https://github.com/IsnantoBudi/xapk_Installer.git
   cd xapk_Installer
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run on device**:
   ```bash
   flutter run -d <device-id>
   ```

4. **Build Release APK**:
   ```bash
   flutter build apk --release
   ```
   The output APK will be generated at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📄 License
MIT License. Created by Isnanto Budi Nurrahman.
