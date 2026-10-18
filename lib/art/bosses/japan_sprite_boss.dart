import 'dart:math' as math;
import 'dart:ui';

import '../battle_stage.dart';
import '../motion.dart';
import '../nemea_scene.dart' show stageGroundY;
import '../sprite_atlas.dart';

/// Boss hình người chương Nhật dựng bằng Blender (`tool/blender/<tên>_boss.py`,
/// atlas `idle` / `attack` / `defeat`): chế độ 3D vẽ sprite, chế độ 2.5D hoặc
/// lúc chưa nạp vẽ bản vector [paintVector] — cùng chỗ đứng, cùng cỡ, cùng
/// nhịp đòn (AttackPose). Hiệu ứng đòn ([paintStrike]) vẽ ở cả hai chế độ.
abstract class JapanSpriteBoss extends BossArt {
  /// Tên atlas trong assets/sprites/.
  String get spriteName;

  /// Chân boss trên sân khấu (gốc toạ độ của sprite và bản vector).
  Offset get feet;

  /// Bề rộng bóng tiếp đất.
  double get shadowWidth;

  @override
  Offset get bodyAnchor => feet;

  @override
  Future<void> preload() => SpriteAtlas.load(spriteName);

  @override
  void dispose() => SpriteAtlas.evict(spriteName);

  /// Bản vector 2.5D quanh chân (gốc toạ độ = [feet], đơn vị sân khấu).
  void paintVector(Canvas canvas, BossFrame f, AttackPose pose);

  /// Hiệu ứng đòn trên sân khấu (gió, sóng chấn động) theo tiến độ đòn.
  void paintStrike(Canvas canvas, BossFrame f) {}

  @override
  void paintBoss(Canvas canvas, BossFrame f) {
    final fall = f.defeat.clamp(0.0, 1.0);
    groundShadow(
      canvas,
      feet + const Offset(6, 3),
      shadowWidth * (1 - 0.3 * fall),
      16,
    );
    canvas.save();
    if (fall > 0) {
      // Gục: chìm xuống đất và nhạt dần (khói Trì Trệ do sân khấu vẽ).
      canvas.translate(0, 10 * fall);
      canvas.saveLayer(
        Rect.fromCenter(center: feet.translate(0, -100), width: 360, height: 300),
        Paint()..color = Color.fromRGBO(0, 0, 0, 1 - fall * 0.6),
      );
    }
    canvas.save();
    canvas.translate(feet.dx + 3 * f.hurt, feet.dy);
    final sprite = SpriteAtlas.get(spriteName);
    if (sprite != null) {
      if (fall > 0 && sprite.has('defeat')) {
        sprite.draw(canvas, 'defeat', fall, flash: f.hurt);
      } else if (f.attackPhase >= 0 && sprite.has('attack')) {
        // Quanh cú ra đòn hai khung kề nhau cách xa: không hoà (bóng ma kép).
        final fast = f.attackPhase > 0.45 && f.attackPhase < 0.8;
        sprite.draw(canvas, 'attack', f.attackPhase, flash: f.hurt, snap: fast);
      } else {
        final period = sprite.metaDouble('idlePeriod', 3);
        sprite.draw(canvas, 'idle', f.time / period, loop: true, flash: f.hurt);
      }
    } else {
      if (f.hurt > 0.01) {
        canvas.saveLayer(
          const Rect.fromLTRB(-200, -260, 200, 40),
          Paint()
            ..colorFilter = ColorFilter.mode(
              Color.fromRGBO(255, 244, 220, 0.6 * f.hurt),
              BlendMode.srcATop,
            ),
        );
      }
      paintVector(canvas, f, AttackPose.at(f.attackPhase));
      if (f.hurt > 0.01) canvas.restore();
    }
    canvas.restore();
    if (fall > 0) canvas.restore();
    canvas.restore();
    if (fall < 0.5) paintStrike(canvas, f);
  }
}

/// Bóng tiếp đất mềm (bầu dục mờ dần).
void groundShadow(Canvas canvas, Offset c, double w, double h) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(1, h / w);
  canvas.drawCircle(
    Offset.zero,
    w / 2,
    Paint()
      ..shader = Gradient.radial(
        Offset.zero,
        w / 2,
        const [Color(0x88201A2A), Color(0x55201A2A), Color(0x00201A2A)],
        const [0, 0.6, 1],
      ),
  );
  canvas.restore();
}

/// Khớp khuỷu/gối 2D: hai đoạn dài [a], [b] từ [root] tới [end]; [bend] = 1
/// gập về bên trái hướng root→end (toạ độ màn hình), −1 về bên phải.
Offset joint2(Offset root, Offset end, double a, double b, double bend) {
  final d = end - root;
  final len = math.min(d.distance, a + b - 0.01);
  if (len < 0.01) return root + Offset(0, a);
  final x = (a * a - b * b + len * len) / (2 * len);
  final h = math.sqrt(math.max(0, a * a - x * x));
  final u = d / d.distance;
  final n = Offset(u.dy, -u.dx) * bend;
  return root + u * x + n * h;
}

/// Điểm trên đường tròn: góc [deg] độ (0 = phải, 90 = xuống, toạ độ màn hình).
Offset polar(Offset c, double deg, double r) {
  final a = deg * math.pi / 180;
  return c + Offset(math.cos(a), math.sin(a)) * r;
}

/// Nội suy chuỗi khoá theo các pha: [base] → lấy đà [w] → ra đòn [s] → gục [d].
double phaseLerp(
  double base,
  double windup,
  double strike,
  double defeat,
  AttackPose p,
  double d,
) {
  var v = base + (windup - base) * p.windup;
  v += (strike - v) * p.strike;
  return v + (defeat - v) * d;
}

/// Giữ đỉnh ra đòn thêm ~⅓ pha thu về (chuỳ nện nằm trên đất một nhịp rồi
/// mới nhấc) — khớp `OniMotion` trong oni_boss.py.
AttackPose holdStrike(AttackPose p, double phase) => phase > AttackPose.strikeEnd
    ? AttackPose(p.windup, math.min(1, p.strike * 1.5), p.recover)
    : p;

/// Tiến độ 0–1 của hiệu ứng chạy trong cửa sổ pha đòn [from, from + len)
/// (âm = ngoài cửa sổ). Ra đòn đạt đỉnh ở AttackPose.strikeEnd (0,65).
double phaseWindow(double phase, double from, double len) {
  if (phase < from || phase >= from + len) return -1;
  return (phase - from) / len;
}

/// Đường mây/mác dải kiểu khắc gỗ.
Path cloudBand(Offset at, double len, double thick) {
  final p = Path()..moveTo(at.dx, at.dy);
  p.quadraticBezierTo(at.dx + len * 0.5, at.dy - thick, at.dx + len, at.dy);
  p.quadraticBezierTo(at.dx + len * 0.5, at.dy + thick * 0.4, at.dx, at.dy);
  return p..close();
}

/// Mặt đất chung: dải đất có khối sẫm dần về tiền cảnh.
void paintGround(Canvas canvas, Color top, Color bottom, Color rim) {
  canvas.drawRect(
    Rect.fromLTRB(0, stageGroundY - 4, 400, 260),
    Paint()
      ..shader = Gradient.linear(
        const Offset(0, stageGroundY - 4),
        const Offset(0, 260),
        [top, bottom],
      ),
  );
  canvas.drawLine(
    const Offset(0, stageGroundY - 3.5),
    const Offset(400, stageGroundY - 3.5),
    Paint()
      ..color = rim
      ..strokeWidth = 0.8,
  );
}
