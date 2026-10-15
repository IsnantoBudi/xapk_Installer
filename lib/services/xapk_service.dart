import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/xapk_info.dart';

class XapkInstallResult {
  final bool isSuccess;
  final String message;
  final bool isMiuiOptimizationError;

  const XapkInstallResult({
    required this.isSuccess,
    required this.message,
    this.isMiuiOptimizationError = false,
  });
}

class XapkService {
  static const MethodChannel _channel = MethodChannel('com.xapk.installer/channel');

  Completer<XapkInstallResult>? _installCompleter;

  XapkService() {
    _channel.setMethodCallHandler(_handleNativeCallback);
  }

  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    if (call.method == 'onInstallResult') {
      final status = call.arguments['status'] as String? ?? 'FAILED';
      final message = call.arguments['message'] as String? ?? '';
      final isMiui = call.arguments['isMiui'] as bool? ?? false;

      final isSuccess = status == 'SUCCESS';
      final isMiuiOpt = !isSuccess && isMiui &&
          (message.toLowerCase().contains('miui') ||
              message.toLowerCase().contains('verification') ||
              message.toLowerCase().contains('internal'));

      if (_installCompleter != null && !_installCompleter!.isCompleted) {
        _installCompleter!.complete(XapkInstallResult(
          isSuccess: isSuccess,
          message: message,
          isMiuiOptimizationError: isMiuiOpt,
        ));
      }
    }
  }

  /// Cek izin pemasangan paket dari sumber tak dikenal
  Future<bool> canRequestPackageInstalls() async {
    try {
      final allowed = await _channel.invokeMethod<bool>('canRequestPackageInstalls');
      return allowed ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Buka pengaturan izin instalasi paket tak dikenal
  Future<void> openInstallPermissionSettings() async {
    try {
      await _channel.invokeMethod('openInstallPermissionSettings');
    } catch (_) {}
  }

  /// Deteksi apakah perangkat adalah Xiaomi/Redmi (MIUI/HyperOS)
  Future<bool> isMiuiDevice() async {
    try {
      final isMiui = await _channel.invokeMethod<bool>('isMiuiDevice');
      return isMiui ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Membaca informasi sistem perangkat (SDK int, release version, model)
  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      final info = await _channel.invokeMapMethod<String, dynamic>('getDeviceInfo');
      return info ?? {};
    } catch (_) {
      return {};
    }
  }

  /// Buka Opsi Pengembang untuk mematikan MIUI Optimization
  Future<void> openDeveloperSettings() async {
    try {
      await _channel.invokeMethod('openDeveloperSettings');
    } catch (_) {}
  }

  /// Meminta izin penyimpanan Android dasar
  Future<bool> requestStoragePermissions() async {
    if (Platform.isAndroid) {
      try {
        final res = await _channel.invokeMethod<bool>('requestStoragePermission');
        return res ?? true;
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  /// Pindai folder Downloads untuk mencari file berekstensi .xapk atau .apks
  Future<List<File>> scanDownloadFolder() async {
    final List<File> results = [];
    try {
      final downloadDir = Directory('/sdcard/Download');
      if (await downloadDir.exists()) {
        final entities = downloadDir.listSync(followLinks: false);
        for (final entity in entities) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (ext == '.xapk' || ext == '.apks') {
              results.add(entity);
            }
          }
        }
      }
    } catch (_) {
      // Fallback path_provider jika direct sdcard path terproteksi
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final parent = extDir.parent.parent.parent.parent;
          final altDownload = Directory(p.join(parent.path, 'Download'));
          if (await altDownload.exists()) {
            final entities = altDownload.listSync(followLinks: false);
            for (final entity in entities) {
              if (entity is File) {
                final ext = p.extension(entity.path).toLowerCase();
                if (ext == '.xapk' || ext == '.apks') {
                  results.add(entity);
                }
              }
            }
          }
        }
      } catch (_) {}
    }
    // Urutkan berdasarkan waktu modifikasi terbaru
    results.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return results;
  }

  /// Membaca header dan manifest berkas XAPK tanpa memakan memori berlebih
  Future<XapkInfo?> inspectXapk(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final fileSize = await file.length();
    final fileName = p.basename(filePath);

    final inputStream = InputFileStream(filePath);
    final archive = ZipDecoder().decodeStream(inputStream);

    Map<String, dynamic>? manifestJson;
    Uint8List? iconData;
    final List<String> splitApks = [];
    final List<String> obbFiles = [];

    for (final entry in archive) {
      final name = entry.name;
      if (entry.isFile) {
        if (name == 'manifest.json' || name == 'info.json') {
          final content = entry.content as List<int>;
          try {
            manifestJson = json.decode(utf8.decode(content)) as Map<String, dynamic>;
          } catch (_) {}
        } else if (name == 'icon.png') {
          iconData = Uint8List.fromList(entry.content as List<int>);
        } else if (name.toLowerCase().endsWith('.apk')) {
          splitApks.add(name);
        } else if (name.toLowerCase().endsWith('.obb') || name.contains('Android/obb/')) {
          obbFiles.add(name);
        }
      }
    }

    String appName = p.basenameWithoutExtension(filePath);
    String packageName = 'unknown.package';
    String versionName = '1.0.0';
    int versionCode = 1;
    int? minSdk;
    int? targetSdk;
    List<String> supportedAbis = [];

    if (manifestJson != null) {
      appName = manifestJson['name'] as String? ?? manifestJson['app_name'] as String? ?? appName;
      packageName = manifestJson['package_name'] as String? ?? packageName;
      versionName = manifestJson['version_name'] as String? ?? versionName;
      versionCode = int.tryParse(manifestJson['version_code']?.toString() ?? '1') ?? 1;
      minSdk = int.tryParse(manifestJson['min_sdk_version']?.toString() ?? '');
      targetSdk = int.tryParse(manifestJson['target_sdk_version']?.toString() ?? '');

      if (manifestJson['split_apks'] is List) {
        final splits = manifestJson['split_apks'] as List;
        for (final s in splits) {
          if (s is Map && s['file'] != null) {
            final fileName = s['file'].toString();
            if (!splitApks.contains(fileName)) {
              splitApks.add(fileName);
            }
            final id = s['id']?.toString() ?? '';
            if (id.startsWith('config.') && !supportedAbis.contains(id)) {
              supportedAbis.add(id.replaceAll('config.', ''));
            }
          }
        }
      }
    } else {
      // Format alternatif: cari file base.apk atau package name dari nama apk
      for (final apk in splitApks) {
        if (!apk.startsWith('config.') && apk.endsWith('.apk')) {
          packageName = p.basenameWithoutExtension(apk);
          break;
        }
      }
    }

    return XapkInfo(
      filePath: filePath,
      fileName: fileName,
      fileSize: fileSize,
      appName: appName,
      packageName: packageName,
      versionName: versionName,
      versionCode: versionCode,
      iconBytes: iconData,
      splitApkEntries: splitApks,
      obbEntries: obbFiles,
      minSdkVersion: minSdk,
      targetSdkVersion: targetSdk,
      supportedAbis: supportedAbis,
    );
  }

  /// Ekstraksi split APK dan berkas OBB lalu picu instalasi session
  Future<XapkInstallResult> installXapk({
    required XapkInfo info,
    String? obbTreeUri,
    required Function(String status, double progress) onProgress,
  }) async {
    _installCompleter = Completer<XapkInstallResult>();

    try {
      onProgress('Menyiapkan ruang kerja instalasi...', 0.1);
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory(p.join(tempDir.path, 'xapk_extracted', info.packageName));
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
      await cacheDir.create(recursive: true);

      onProgress('Mengekstrak paket APK...', 0.25);
      final inputStream = InputFileStream(info.filePath);
      final archive = ZipDecoder().decodeStream(inputStream);

      final List<String> extractedApkPaths = [];
      final List<File> extractedObbFiles = [];

      int processedEntries = 0;
      final totalEntries = archive.length;

      for (final entry in archive) {
        processedEntries++;
        final progressVal = 0.25 + (processedEntries / (totalEntries == 0 ? 1 : totalEntries)) * 0.45;
        onProgress('Mengekstrak: ${entry.name}...', progressVal.clamp(0.25, 0.70));

        if (entry.isFile) {
          final entryName = entry.name;
          if (entryName.toLowerCase().endsWith('.apk')) {
            final destPath = p.join(cacheDir.path, p.basename(entryName));
            final destFile = File(destPath);
            final data = entry.content as List<int>;
            await destFile.writeAsBytes(data, flush: true);
            extractedApkPaths.add(destPath);
          } else if (entryName.toLowerCase().endsWith('.obb')) {
            final destPath = p.join(cacheDir.path, p.basename(entryName));
            final destFile = File(destPath);
            final data = entry.content as List<int>;
            await destFile.writeAsBytes(data, flush: true);
            extractedObbFiles.add(destFile);
          }
        }
      }

      if (extractedApkPaths.isEmpty) {
        return const XapkInstallResult(
          isSuccess: false,
          message: 'Berkas XAPK tidak memuat berkas APK yang valid.',
        );
      }

      // Penanganan berkas OBB jika ada
      if (extractedObbFiles.isNotEmpty) {
        onProgress('Menyalin data OBB ke Android/obb...', 0.75);
        for (final obb in extractedObbFiles) {
          final obbName = p.basename(obb.path);
          try {
            await _channel.invokeMethod('copyObbFile', {
              'sourcePath': obb.path,
              'packageName': info.packageName,
              'obbFileName': obbName,
              'treeUri': obbTreeUri,
            });
          } catch (_) {
            // Lanjutkan instalasi APK meskipun copy OBB gagal
          }
        }
      }

      onProgress('Memulai sesi PackageInstaller native...', 0.85);

      // Jalankan instalasi multi-split via platform channel
      await _channel.invokeMethod('installSplitApks', {
        'paths': extractedApkPaths,
      });

      onProgress('Menunggu konfirmasi pengguna...', 0.95);

      // Tunggu konfirmasi instalasi dari BroadcastReceiver Kotlin
      return await _installCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => const XapkInstallResult(
          isSuccess: false,
          message: 'Batas waktu instalasi berakhir.',
        ),
      );
    } catch (e) {
      return XapkInstallResult(
        isSuccess: false,
        message: 'Terjadi kesalahan: $e',
      );
    }
  }
}
