import 'package:flutter/material.dart';
import '../services/xapk_service.dart';

class MiuiGuideDialog extends StatelessWidget {
  final XapkService xapkService;

  const MiuiGuideDialog({
    super.key,
    required this.xapkService,
  });

  static Future<void> show(BuildContext context, XapkService service) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => MiuiGuideDialog(xapkService: service),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Panduan MIUI Optimization',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF8FAFC), // Slate 50
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B), // Slate 800
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)), // Slate 700
            ),
            child: const Text(
              'Redmi Note 10 (MIUI/HyperOS) memiliki sistem keamanan yang secara bawaan membatasi pemasangan Split APK pihak ketiga. Untuk mengizinkan instalasi, nonaktifkan opsi ini sementara.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFFCBD5E1), // Slate 300
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Langkah Penyesuaian di Opsi Pengembang:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFFF1F5F9),
            ),
          ),
          const SizedBox(height: 12),
          _buildStep(
            number: '1',
            title: 'Buka Opsi Pengembang',
            description: 'Tekan tombol di bawah untuk langsung menuju halaman Developer Options.',
          ),
          const SizedBox(height: 10),
          _buildStep(
            number: '2',
            title: 'Gulir ke Paling Bawah',
            description: 'Temukan toggle bertuliskan "Turn on MIUI optimization" atau "Hidupkan optimasi MIUI".',
          ),
          const SizedBox(height: 10),
          _buildStep(
            number: '3',
            title: 'Matikan Toggle Optimasi',
            description: 'Ubah statusnya menjadi Tidak Aktif (Off). Jika toggle tidak muncul, ketuk "Reset to default values" sebanyak 4-5 kali.',
          ),
          const SizedBox(height: 10),
          _buildStep(
            number: '4',
            title: 'Kembali & Pasang Ulang',
            description: 'Buka kembali aplikasi ini dan ulangi proses pemasangan XAPK.',
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF94A3B8),
                    side: const BorderSide(color: Color(0xFF334155)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Tutup'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    xapkService.openDeveloperSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7), // Sky 600
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Buka Opsi Pengembang',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF334155), // Slate 700
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF8FAFC),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE2E8F0),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8), // Slate 400
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
