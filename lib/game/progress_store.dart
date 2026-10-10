import 'package:shared_preferences/shared_preferences.dart';

import 'progress.dart';

/// Lưu/đọc tiến trình người chơi trên máy.
class ProgressStore {
  static const _key = 'player_progress_v1';

  static Future<PlayerProgress> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return PlayerProgress();
    try {
      return PlayerProgress.decode(raw);
    } on FormatException {
      // Dữ liệu hỏng thì bắt đầu lại thay vì làm app không mở được.
      return PlayerProgress();
    }
  }

  static Future<void> save(PlayerProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, progress.encode());
  }
}
