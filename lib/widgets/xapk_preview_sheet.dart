import 'package:flutter/material.dart';
import '../models/install_history.dart';
import '../models/xapk_info.dart';
import '../services/history_service.dart';
import '../services/xapk_service.dart';
import 'miui_guide_dialog.dart';

enum InstallStage { idle, inProgress, success, failed }

class XapkPreviewSheet extends StatefulWidget {
  final XapkInfo xapkInfo;
  final XapkService xapkService;
  final HistoryService historyService;
  final VoidCallback onInstalled;

  const XapkPreviewSheet({
    super.key,
    required this.xapkInfo,
    required this.xapkService,
    required this.historyService,
    required this.onInstalled,
  });

  static void show({
    required BuildContext context,
    required XapkInfo info,
    required XapkService xapkService,
    required HistoryService historyService,
    required VoidCallback onInstalled,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => XapkPreviewSheet(
        xapkInfo: info,
        xapkService: xapkService,
        historyService: historyService,
        onInstalled: onInstalled,
      ),
    );
  }

  @override
  State<XapkPreviewSheet> createState() => _XapkPreviewSheetState();
}

class _XapkPreviewSheetState extends State<XapkPreviewSheet> {
  InstallStage _stage = InstallStage.idle;
  String _statusText = 'Siap dipasang';
  double _progress = 0.0;
  String? _errorMessage;
  bool _isMiuiError = false;
  int? _deviceSdk;
  String? _deviceAndroidRelease;
  String? _deviceModel;

  @override
  void initState() {
    super.initState();
    _fetchDeviceInfo();
  }

  Future<void> _fetchDeviceInfo() async {
    final info = await widget.xapkService.getDeviceInfo();
    if (mounted) {
      setState(() {
        _deviceSdk = info['sdkInt'] as int?;
        _deviceAndroidRelease = info['release']?.toString();
        _deviceModel = info['model']?.toString();
      });
    }
  }

  Future<void> _startInstall() async {
    // 1. Cek izin install unknown apps
    final canInstall = await widget.xapkService.canRequestPackageInstalls();
    if (!canInstall && mounted) {
      final shouldOpen = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Izin Pemasangan Dibutuhkan', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: const Text(
            'Android memerlukan izin "Instal aplikasi tidak dikenal" untuk melanjutkan proses instalasi paket split APK.',
            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
              child: const Text('Buka Pengaturan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (shouldOpen == true) {
        await widget.xapkService.openInstallPermissionSettings();
      }
      return;
    }

    setState(() {
      _stage = InstallStage.inProgress;
      _statusText = 'Menyiapkan pemasangan...';
      _progress = 0.05;
      _errorMessage = null;
      _isMiuiError = false;
    });

    final result = await widget.xapkService.installXapk(
      info: widget.xapkInfo,
      onProgress: (status, progress) {
        if (mounted) {
          setState(() {
            _statusText = status;
            _progress = progress;
          });
        }
      },
    );

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _stage = InstallStage.success;
        _statusText = 'Aplikasi berhasil dipasang!';
        _progress = 1.0;
      });
      await widget.historyService.addHistory(
        InstallHistory(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          appName: widget.xapkInfo.appName,
          packageName: widget.xapkInfo.packageName,
          versionName: widget.xapkInfo.versionName,
          installedAt: DateTime.now(),
          isSuccess: true,
        ),
      );
      widget.onInstalled();
    } else {
      setState(() {
        _stage = InstallStage.failed;
        _errorMessage = result.message;
        _isMiuiError = result.isMiuiOptimizationError;
      });
      await widget.historyService.addHistory(
        InstallHistory(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          appName: widget.xapkInfo.appName,
          packageName: widget.xapkInfo.packageName,
          versionName: widget.xapkInfo.versionName,
          installedAt: DateTime.now(),
          isSuccess: false,
          errorMessage: result.message,
        ),
      );
      widget.onInstalled();
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.xapkInfo;

    return Padding(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info aplikasi
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B), // Slate 800
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                clipBehavior: Clip.antiAlias,
                child: info.iconBytes != null
                    ? Image.memory(
                        info.iconBytes!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Text(
                            info.appName.isNotEmpty ? info.appName[0].toUpperCase() : 'A',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF8FAFC),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          info.appName.isNotEmpty ? info.appName[0].toUpperCase() : 'A',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF8FAFC),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.appName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF8FAFC),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      info.packageName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8), // Slate 400
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildBadge(
                          'v${info.versionName}',
                          const Color(0xFF334155),
                          const Color(0xFFE2E8F0),
                        ),
                        const SizedBox(width: 6),
                        _buildBadge(
                          info.formattedSize,
                          const Color(0xFF1E293B),
                          const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Badge kompatibilitas Redmi Note 10 (ARM64)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: info.isArm64Supported
                  ? const Color(0xFF064E3B).withValues(alpha: 0.3)
                  : const Color(0xFF78350F).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: info.isArm64Supported
                    ? const Color(0xFF059669) // Emerald 600
                    : const Color(0xFFD97706), // Amber 600
              ),
            ),
            child: Row(
              children: [
                Icon(
                  info.isArm64Supported ? Icons.check_circle_outline : Icons.info_outline,
                  color: info.isArm64Supported ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    info.isArm64Supported
                        ? 'Kompatibel dengan CPU Redmi Note 10 (Snapdragon 678, arm64-v8a)'
                        : 'Arsitektur khusus: pastikan CPU perangkat didukung',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: info.isArm64Supported ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Banner Validasi Versi Android OS
          if (_deviceSdk != null && info.minSdkVersion != null && !info.isSdkCompatible(_deviceSdk!)) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF78350F).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD97706)), // Amber 600
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Versi Android Tidak Kompatibel',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFEF3C7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Aplikasi ini membutuhkan minimal ${XapkInfo.getAndroidVersionName(info.minSdkVersion)}, sedangkan HP Anda (${_deviceModel ?? 'Redmi Note 10'}) menjalankan Android ${_deviceAndroidRelease ?? '12'} (API $_deviceSdk).\nInstalasi kemungkinan besar akan ditolak oleh Android OS.',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: Color(0xFFFDE68A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ] else if (_deviceSdk != null && info.minSdkVersion != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF064E3B).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF059669)), // Emerald 600
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Versi OS Cocok: Butuh ${XapkInfo.getAndroidVersionName(info.minSdkVersion)} (HP Anda: Android ${_deviceAndroidRelease ?? '12'})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFD1FAE5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Detail berkas APK & OBB
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              children: [
                _buildInfoRow('Tipe Paket', info.isSplitApk ? 'Split APK (${info.splitApkEntries.length} berkas)' : 'Single Base APK'),
                const Divider(color: Color(0xFF334155), height: 16),
                _buildInfoRow('Data OBB', info.hasObb ? '${info.obbEntries.length} berkas terdeteksi' : 'Tidak ada data OBB'),
                const Divider(color: Color(0xFF334155), height: 16),
                _buildInfoRow(
                  'Syarat Min. Android',
                  info.minSdkVersion != null
                      ? XapkInfo.getAndroidVersionName(info.minSdkVersion)
                      : 'Universal (Semua versi)',
                ),
                if (_deviceSdk != null) ...[
                  const Divider(color: Color(0xFF334155), height: 16),
                  _buildInfoRow(
                    'Android Perangkat Anda',
                    '${_deviceModel != null ? '$_deviceModel • ' : ''}Android ${_deviceAndroidRelease ?? ''} (API $_deviceSdk)',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Indikator Progress saat instalasi berlangsung
          if (_stage == InstallStage.inProgress) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _statusText,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF38BDF8)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: const Color(0xFF334155),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 6,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Pesan Error jika gagal
          if (_stage == InstallStage.failed && _errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF881337).withValues(alpha: 0.3), // Rose 900
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE11D48)), // Rose 600
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFFECDD3)),
                  ),
                  if (_isMiuiError) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        MiuiGuideDialog.show(context, widget.xapkService);
                      },
                      child: const Text(
                        'Pelajari cara mematikan MIUI Optimization →',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF38BDF8), // Sky 400
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Status Sukses
          if (_stage == InstallStage.success) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF064E3B).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF059669)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pemasangan paket selesai. Anda dapat langsung membuka aplikasi dari launcher.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFD1FAE5)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _stage == InstallStage.inProgress ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF94A3B8),
                    side: const BorderSide(color: Color(0xFF334155)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(_stage == InstallStage.success ? 'Selesai' : 'Batal'),
                ),
              ),
              const SizedBox(width: 12),
              if (_stage != InstallStage.success) ...[
                Builder(
                  builder: (context) {
                    final isSdkIncompatible = _deviceSdk != null &&
                        info.minSdkVersion != null &&
                        !info.isSdkCompatible(_deviceSdk!);
                    final buttonColor = isSdkIncompatible ? const Color(0xFFD97706) : const Color(0xFF0284C7);
                    final buttonText = _stage == InstallStage.failed
                        ? 'Coba Pasang Lagi'
                        : isSdkIncompatible
                            ? 'Tetap Pasang Aplikasi'
                            : 'Pasang Aplikasi';

                    return Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _stage == InstallStage.inProgress ? null : _startInstall,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF334155),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          buttonText,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: text),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFE2E8F0)),
        ),
      ],
    );
  }
}
