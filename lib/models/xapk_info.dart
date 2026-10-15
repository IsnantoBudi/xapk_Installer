import 'dart:typed_data';

/// Model metadata informasi berkas XAPK / APKS
class XapkInfo {
  final String filePath;
  final String fileName;
  final int fileSize;
  final String appName;
  final String packageName;
  final String versionName;
  final int versionCode;
  final Uint8List? iconBytes;
  final List<String> splitApkEntries;
  final List<String> obbEntries;
  final int? minSdkVersion;
  final int? targetSdkVersion;
  final List<String> supportedAbis;

  const XapkInfo({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.appName,
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    this.iconBytes,
    required this.splitApkEntries,
    required this.obbEntries,
    this.minSdkVersion,
    this.targetSdkVersion,
    this.supportedAbis = const [],
  });

  /// Mengecek apakah berkas XAPK mendukung arsitektur arm64-v8a (Redmi Note 10)
  bool get isArm64Supported {
    if (supportedAbis.isEmpty) return true; // Standar universal
    return supportedAbis.any((abi) =>
        abi.toLowerCase().contains('arm64') ||
        abi.toLowerCase().contains('v8a') ||
        abi.toLowerCase().contains('universal'));
  }

  /// Memeriksa apakah berkas memiliki data OBB (game/aplikasi besar)
  bool get hasObb => obbEntries.isNotEmpty;

  /// Memeriksa apakah berkas merupakan format multi-split APK
  bool get isSplitApk => splitApkEntries.length > 1;

  /// Mengecek apakah versi Android perangkat mencukupi syarat minimal berkas
  bool isSdkCompatible(int deviceSdk) {
    if (minSdkVersion == null) return true;
    return deviceSdk >= minSdkVersion!;
  }

  /// Format nama versi Android berdasarkan SDK int (API Level)
  static String getAndroidVersionName(int? sdkInt) {
    if (sdkInt == null) return 'Universal / Unknown';
    switch (sdkInt) {
      case 21:
        return 'Android 5.0 (API 21)';
      case 22:
        return 'Android 5.1 (API 22)';
      case 23:
        return 'Android 6.0 (API 23)';
      case 24:
        return 'Android 7.0 (API 24)';
      case 25:
        return 'Android 7.1 (API 25)';
      case 26:
        return 'Android 8.0 (API 26)';
      case 27:
        return 'Android 8.1 (API 27)';
      case 28:
        return 'Android 9 (API 28)';
      case 29:
        return 'Android 10 (API 29)';
      case 30:
        return 'Android 11 (API 30)';
      case 31:
        return 'Android 12 (API 31)';
      case 32:
        return 'Android 12L (API 32)';
      case 33:
        return 'Android 13 (API 33)';
      case 34:
        return 'Android 14 (API 34)';
      case 35:
        return 'Android 15 (API 35)';
      default:
        return sdkInt > 35 ? 'Android $sdkInt+ (API $sdkInt)' : 'API $sdkInt';
    }
  }

  /// Format ukuran berkas manusiawi (MB / GB)
  String get formattedSize {
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}
