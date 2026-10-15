import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/install_history.dart';
import '../models/xapk_info.dart';
import '../services/history_service.dart';
import '../services/xapk_service.dart';
import '../widgets/miui_guide_dialog.dart';
import '../widgets/xapk_preview_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final XapkService _xapkService = XapkService();
  final HistoryService _historyService = HistoryService();

  int _selectedTab = 0; // 0: Berkas XAPK, 1: Riwayat
  bool _isLoading = false;
  String _loadingMessage = '';
  List<File> _scannedFiles = [];
  List<InstallHistory> _histories = [];
  bool _isMiui = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final isMiui = await _xapkService.isMiuiDevice();
    final histories = await _historyService.getHistories();
    if (mounted) {
      setState(() {
        _isMiui = isMiui;
        _histories = histories;
      });
      _scanDownloads();
    }
  }

  Future<void> _scanDownloads() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Memindai folder Downloads...';
    });

    await _xapkService.requestStoragePermissions();
    final files = await _xapkService.scanDownloadFolder();

    if (mounted) {
      setState(() {
        _scannedFiles = files;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickFileManually() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xapk', 'apks', 'zip'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      _inspectAndOpenSheet(file.path);
    }
  }

  Future<void> _inspectAndOpenSheet(String filePath) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Menganalisis berkas XAPK...';
    });

    final XapkInfo? info = await _xapkService.inspectXapk(filePath);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membaca berkas XAPK. Pastikan berkas tidak korup.'),
          backgroundColor: Color(0xFFE11D48), // Rose 600
        ),
      );
      return;
    }

    XapkPreviewSheet.show(
      context: context,
      info: info,
      xapkService: _xapkService,
      historyService: _historyService,
      onInstalled: () {
        _refreshHistories();
      },
    );
  }

  Future<void> _refreshHistories() async {
    final list = await _historyService.getHistories();
    if (mounted) {
      setState(() {
        _histories = list;
      });
    }
  }

  Future<void> _clearAllHistories() async {
    await _historyService.clearHistories();
    if (mounted) {
      setState(() {
        _histories.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16), // Slate 950 deep
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A), // Slate 900
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'XAPK Installer',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF8FAFC),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981), // Emerald 500
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isMiui ? 'Redmi Note 10 (MIUI/ARM64)' : 'Perangkat Android (ARM64)',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_isMiui)
            TextButton.icon(
              onPressed: () => MiuiGuideDialog.show(context, _xapkService),
              icon: const Icon(Icons.help_outline, size: 16, color: Color(0xFF38BDF8)),
              label: const Text(
                'Panduan MIUI',
                style: TextStyle(fontSize: 12, color: Color(0xFF38BDF8), fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Underline Navigation Tabs (Enterprise Style)
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E293B)),
              ),
            ),
            child: Row(
              children: [
                _buildUnderlineTab(
                  index: 0,
                  label: 'Berkas XAPK (${_scannedFiles.length})',
                ),
                _buildUnderlineTab(
                  index: 1,
                  label: 'Riwayat (${_histories.length})',
                ),
              ],
            ),
          ),

          // Loading bar
          if (_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1E293B),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF38BDF8)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _loadingMessage,
                      style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ],
              ),
            ),

          // Tab Body
          Expanded(
            child: _selectedTab == 0 ? _buildFilesTab() : _buildHistoryTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildUnderlineTab({required int index, required String label}) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent, // Sky 400
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? const Color(0xFFF8FAFC) : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilesTab() {
    return Column(
      children: [
        // Action Buttons Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _scanDownloads,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Pindai Unduhan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B), // Slate 800
                    foregroundColor: const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFF334155)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickFileManually,
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Pilih Berkas'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7), // Sky 600
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Scanned files list
        Expanded(
          child: _scannedFiles.isEmpty
              ? _buildEmptyState(
                  title: 'Tidak Ada Berkas XAPK',
                  message: 'Tidak ditemukan berkas .xapk di folder Download. Salin berkas ke memori HP atau tekan "Pilih Berkas" untuk mencari lokasi lain.',
                  actionButton: OutlinedButton(
                    onPressed: _pickFileManually,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF38BDF8),
                      side: const BorderSide(color: Color(0xFF0284C7)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Pilih Berkas Manual'),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: _scannedFiles.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                  itemBuilder: (ctx, index) {
                    final file = _scannedFiles[index];
                    final fileName = file.path.split(Platform.pathSeparator).last;
                    final size = file.lengthSync();
                    final sizeStr = (size / (1024 * 1024)).toStringAsFixed(1);

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827), // Slate 900
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1F2937)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF38BDF8), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fileName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFF1F5F9),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$sizeStr MB • ${file.path}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => _inspectAndOpenSheet(file.path),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: const Color(0xFF38BDF8),
                              side: const BorderSide(color: Color(0xFF38BDF8)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: const Text('Pasang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_histories.isEmpty) {
      return _buildEmptyState(
        title: 'Belum Ada Riwayat',
        message: 'Aplikasi yang berhasil maupun gagal dipasang akan tercatat di sini secara otomatis.',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_histories.length} Aktivitas Tercatat',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              TextButton(
                onPressed: _clearAllHistories,
                child: const Text('Hapus Semua', style: TextStyle(fontSize: 12, color: Color(0xFFF43F5E))),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            itemCount: _histories.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 10),
            itemBuilder: (ctx, index) {
              final item = _histories[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1F2937)),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.isSuccess ? Icons.check_circle : Icons.error_outline,
                      color: item.isSuccess ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.appName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFF1F5F9)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.packageName} • v${item.versionName}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          if (item.errorMessage != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.errorMessage!,
                              style: const TextStyle(fontSize: 11, color: Color(0xFFFDA4AF)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      _formatDate(item.installedAt),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({required String title, required String message, Widget? actionButton}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.folder_open, size: 36, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFF1F5F9)),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
            ),
            if (actionButton != null) ...[
              const SizedBox(height: 20),
              actionButton,
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
