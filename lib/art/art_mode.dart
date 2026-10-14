import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kiểu đồ hoạ người chơi chọn ở trang chủ.
enum ArtMode {
  /// Vẽ vector bằng code (lib/art/), phông nhiều lớp parallax.
  vector('2.5D'),

  /// Sprite, phông và ảnh chụp sẵn dựng bằng Blender (assets/).
  blender('3D');

  const ArtMode(this.label);

  final String label;
}

/// Công tắc 2.5D ↔ 3D. Các chỗ nạp tài nguyên Blender (SpriteAtlas,
/// NemeaBackdrop, NemeaMapImage, HomeBannerArt, BossPortrait) coi như CHƯA
/// có ảnh khi đang ở [ArtMode.vector], nên tự rơi về bản vector như lúc
/// thiếu tài nguyên — không cần nhánh riêng ở từng hình.
abstract final class ArtModeSetting {
  static const _key = 'art_mode_v1';

  static final notifier = ValueNotifier<ArtMode>(ArtMode.blender);

  static ArtMode get mode => notifier.value;

  static bool get blender => notifier.value == ArtMode.blender;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_key);
    notifier.value = ArtMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ArtMode.blender,
    );
  }

  static Future<void> set(ArtMode mode) async {
    notifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
