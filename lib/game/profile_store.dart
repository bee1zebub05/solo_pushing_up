import 'package:shared_preferences/shared_preferences.dart';

import 'player_profile.dart';

/// Lưu/đọc hồ sơ người chơi trên máy (không gửi đi đâu).
class ProfileStore {
  static const _key = 'player_profile_v1';

  /// null = chưa tạo nhân vật (lần đầu mở app).
  static Future<PlayerProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return PlayerProfile.decode(raw);
    } on FormatException {
      return null;
    }
  }

  static Future<void> save(PlayerProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, profile.encode());
  }
}
