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
