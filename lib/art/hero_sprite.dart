import 'dart:ui';

import 'hero_art.dart';
import 'sprite_atlas.dart';

/// Một khung nhân vật bằng sprite: chuỗi [anim] (`plank`, `knees`, `stand`,
/// `victory`) tại tiến độ [t] 0–1. Đang chuyển tư thế thì hoà từ khung cũ
/// [from] với tỉ lệ [blend] (1 = đã tới hẳn khung mới).
class HeroSpriteFrame {
  const HeroSpriteFrame(this.anim, this.t, {this.from, this.blend = 1});

  /// Chống đẩy với góc khuỷu [elbowDeg] (178° tay thẳng → 70° xuống sâu).
  factory HeroSpriteFrame.plank(double elbowDeg, {bool onKnees = false}) =>
      HeroSpriteFrame(
        onKnees ? 'knees' : 'plank',
        ((HeroSprites.elbowFrom - elbowDeg) /
                (HeroSprites.elbowFrom - HeroSprites.elbowTo))
            .clamp(0.0, 1.0),
      );

  final String anim;
  final double t;
  final HeroSpriteFrame? from;
  final double blend;

  HeroSpriteFrame blendFrom(HeroSpriteFrame? previous, double k) =>
      previous == null || k >= 1
      ? this
      : HeroSpriteFrame(anim, t, from: previous, blend: k);
}

/// Nhân vật người chơi dựng bằng Blender (tool/blender/hero.py), sprite TÁCH
/// LỚP: da (nhân màu da đã chọn), trang phục (giữ màu, có bóng đổ), tóc theo
/// kiểu (nhân màu tóc). Gốc toạ độ = mũi chân lúc chống đẩy, ở điểm
/// ([anchorX], 220) của sân khấu; [HeroLook.height] phóng quanh điểm đó.
///
/// Chỉ nạp khi vào trận; chưa nạp, hoặc đang mang trang bị phần thưởng (áo
/// da sư tử, khiên, kiếm — chưa có lớp Blender) thì vẽ bản vector.
abstract final class HeroSprites {
  static const elbowFrom = 178.0;
  static const elbowTo = 70.0;
  static const anchorX = 40.0;
  static const groundY = 220.0;

  static List<String> namesFor(HeroLook look) {
    final sex = look.female ? 'female' : 'male';
    return [
      'hero_${sex}_skin',
      'hero_${sex}_cloth',
      'hero_${sex}_hair_${look.hairStyle.name}',
    ];
  }

  static Future<void> load(HeroLook look) async {
    for (final name in namesFor(look)) {
      await SpriteAtlas.load(name);
    }
  }

  static void evict(HeroLook look) {
    for (final name in namesFor(look)) {
      SpriteAtlas.evict(name);
    }
  }

  static bool ready(HeroLook look) =>
      namesFor(look).every((n) => SpriteAtlas.get(n) != null);

  /// Vẽ [frame]; `false` nếu sprite chưa nạp (vẽ bản vector thay).
  static bool paint(Canvas canvas, HeroLook look, HeroSpriteFrame frame) {
    final names = namesFor(look);
    final skin = SpriteAtlas.get(names[0]);
    final cloth = SpriteAtlas.get(names[1]);
    final hair = SpriteAtlas.get(names[2]);
    if (skin == null || cloth == null || hair == null) return false;
    canvas.save();
    canvas.translate(anchorX, groundY);
    canvas.scale(look.height);
    void layers(HeroSpriteFrame f, double opacity) {
      if (opacity < 0.02) return;
      skin.draw(canvas, f.anim, f.t, opacity: opacity, tint: look.skin);
      cloth.draw(canvas, f.anim, f.t, opacity: opacity);
      hair.draw(canvas, f.anim, f.t, opacity: opacity, tint: look.hair);
    }

    final from = frame.from;
    if (from != null && frame.blend < 1) {
      layers(from, 1 - frame.blend);
      layers(frame, frame.blend);
    } else {
      layers(frame, 1);
    }
    canvas.restore();
    return true;
  }
}
