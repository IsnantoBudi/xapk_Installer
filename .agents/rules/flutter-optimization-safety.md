# Flutter & Android Native Engineering Best Practices

## 1. Dynamic Media & Archive Safety
- **Selalu Gunakan `errorBuilder` pada `Image.memory`**:
  Saat merender `Uint8List` yang bersumber dari arsip eksternal (ZIP, XAPK, APKS) atau respons API, jangan pernah memanggil `Image.memory(bytes)` tanpa fallback `errorBuilder`. Format gambar corrupt atau webp tak berstandar akan memicu unhandled runtime error di engine Flutter (`Exception: Invalid image data`, `E/FlutterJNI: Failed to decode image`).
  ```dart
  Image.memory(
    iconBytes,
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => DefaultFallbackWidget(),
  )
  ```

## 2. Validasi Kompatibilitas Versi OS Android
- **Pra-validasi `minSdkVersion` Sebelum Instalasi Paket**:
  Pada fungsionalitas pengelola aplikasi atau `PackageInstaller.Session`, Android OS firmware secara mutlak menolak pemasangan paket dengan error `INSTALL_FAILED_OLDER_SDK` jika `minSdkVersion` paket > `Build.VERSION.SDK_INT` OS perangkat.
- Selalu ekspos `Build.VERSION.SDK_INT` melalui platform channel untuk memvalidasi versi OS perangkat sebelum proses ekstraksi/instalasi native dijalankan.

## 3. Strategi Optimasi Ukuran File APK (Size Reduction)
- **Eliminasi Font yang Tidak Terpakai**:
  Hapus paket `cupertino_icons` dari `pubspec.yaml` jika aplikasi hanya menargetkan platform Android atau hanya menggunakan Material Icons, untuk menghemat ~300 KB font asset.
- **R8 Minification & Resource Shrinking**:
  Aktifkan di `android/app/build.gradle.kts`:
  ```kotlin
  buildTypes {
      release {
          isMinifyEnabled = true
          isShrinkResources = true
          proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
      }
  }
  ```
- **Kompilasi Per-Arsitektur (`--split-per-abi`)**:
  Kompilasi bawaan menghasilkan fat APK (~43 MB) karena library uncompressed 3 CPU architecture. Untuk perangkat fisik modern (arm64), gunakan:
  ```bash
  flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/app/outputs/symbols
  ```
  Ini memangkas ukuran APK hingga ~65% (menjadi ~15.1 MB).
