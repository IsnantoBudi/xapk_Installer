import 'package:shared_preferences/shared_preferences.dart';
import '../models/install_history.dart';

class HistoryService {
  static const String _prefKey = 'xapk_install_history';

  Future<List<InstallHistory>> getHistories() async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList(_prefKey) ?? [];
    final histories = items.map((raw) => InstallHistory.fromJson(raw)).toList();
    histories.sort((a, b) => b.installedAt.compareTo(a.installedAt));
    return histories;
  }

  Future<void> addHistory(InstallHistory history) async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList(_prefKey) ?? [];
    items.insert(0, history.toJson());
    // Batasi maksimum 50 catatan riwayat
    if (items.length > 50) {
      items.removeRange(50, items.length);
    }
    await prefs.setStringList(_prefKey, items);
  }

  Future<void> clearHistories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}
