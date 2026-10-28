import 'dart:math' as math;
import 'dart:ui';

import 'sprite_atlas.dart';

/// Thư viện phát chuyển động mượt cho sprite Blender — dùng chung mọi quái /
/// nhân vật / chương (khung render bằng tool/blender/motion_kit.py; hướng
/// dẫn: rules/chuyendong.md). Gom các luật đã duyệt ở chương 1:
///
/// * Đứng chờ lặp theo `idlePeriod` của atlas, hoà hai khung kề nhau.
/// * Đòn đọc `phases` (khung dồn dày quanh cú đánh); trong vùng cú đánh
///   [strikeFrom]–[strikeTo] chỉ vẽ khung gần nhất (hoà thì vũ khí / thân lao
///   nhanh hiện bóng kép).
/// * Đầu và cuối đòn hoà với dáng đứng chờ ([idleBlend]): vòng đứng chờ đang
///   ở pha bất kỳ nên chuyển thẳng sang khung đầu / khỏi khung cuối bị giật.
/// * Điểm bám theo từng khung đòn (mũi giáo, đầu, vuốt — meta atlas) nội suy
///   cùng tiến độ với khung ảnh ([track]).
abstract final class SpriteMotion {
  /// Vùng cú đánh (tiến độ đòn) không hoà khung — khớp `STRIKE` của
  /// motion_kit (0,46–0,70) trừ mép để khung dày đã phủ kín.
  static const strikeFrom = 0.48;
  static const strikeTo = 0.7;

  /// Phần đầu / cuối đòn hoà với dáng đứng chờ.
  static const fade = 0.1;

  static bool inStrike(double p) => p > strikeFrom && p < strikeTo;

  /// Độ đậm (0–1) của dáng chờ vẽ đè lên đòn ở tiến độ [p]: đầu đòn tan dần
  /// từ dáng chờ, cuối đòn hiện dần lại.
  static double idleBlend(double p, {double fade = fade}) {
    final w = p < fade
        ? 1 - p / fade
        : p > 1 - fade
        ? (p - (1 - fade)) / fade
        : 0.0;
    final c = w.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  /// Vòng đứng chờ [anim] tại thời điểm [time] (giây).
  static void idle(
    Canvas canvas,
    SpriteAtlas sprite,
    String anim,
    double time, {
    double opacity = 1,
    double flash = 0,
    Color? tint,
    double fallbackPeriod = 2.4,
  }) {
    sprite.draw(
      canvas,
      anim,
      time / sprite.metaDouble('idlePeriod', fallbackPeriod),
      loop: true,
      opacity: opacity,
      flash: flash,
      tint: tint,
    );
  }

  /// Một đòn [anim] tại tiến độ [p] (0–1): [snapStrike] = chỉ vẽ khung gần
  /// nhất trong vùng cú đánh; đầu / cuối đòn hoà với vòng đứng chờ [idleAnim]
  /// ở thời điểm [time].
  static void action(
    Canvas canvas,
    SpriteAtlas sprite,
    String anim,
    double p, {
    required String idleAnim,
    required double time,
    bool snapStrike = true,
    double flash = 0,
    Color? tint,
    double fallbackPeriod = 2.4,
  }) {
    sprite.draw(
      canvas,
      anim,
      p,
      flash: flash,
      tint: tint,
      snap: snapStrike && inStrike(p),
    );
    final blend = idleBlend(p);
    if (blend > 0.01 && sprite.has(idleAnim)) {
      idle(
        canvas,
        sprite,
        idleAnim,
        time,
        opacity: blend,
        flash: flash,
        tint: tint,
        fallbackPeriod: fallbackPeriod,
      );
    }
  }

  /// Điểm [key] (danh sách [x, y] từng khung của đòn [anim] trong meta atlas,
  /// sinh lúc render) tại tiến độ [p], nội suy như khung ảnh; null nếu không có.
  static Offset? track(
    SpriteAtlas sprite,
    String key,
    double p, {
    String anim = 'attack',
  }) {
    final list = sprite.meta[key] as List?;
    if (list == null || list.length < 2 || p < 0) return null;
    Offset at(int i) {
      final t = list[i] as List;
      return Offset((t[0] as num).toDouble(), (t[1] as num).toDouble());
    }

    final phases = sprite.phasesOf(anim);
    final q = p.clamp(0.0, 1.0);
    final pos = phases != null && phases.length == list.length
        ? SpriteAtlas.positionOf(phases, q)
        : q * (list.length - 1);
    final i = math.min(pos.floor(), list.length - 2);
    return Offset.lerp(at(i), at(i + 1), pos - i)!;
  }
}
