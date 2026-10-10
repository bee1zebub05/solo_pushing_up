import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../battle_stage.dart';
import '../nemea_scene.dart' show stageGroundY, stageSize;
import '../vector_style.dart';

/// Bảng màu Kỳ công 12 — Việt Nam, núi Tản Viên.
abstract final class ThuyTinhColors {
  static const skin = Color(0xFF3E9FB0);
  static const water = Color(0xFF2A8FA6);
  static const waterDeep = Color(0xFF155A70);
  static const foam = Color(0xFFE9FBFF);
  static const hair = Color(0xFFAEEBF2);
  static const gold = Color(0xFFE8B83A);
  static const coral = Color(0xFFE5674A);
  static const glow = Color(0xFF7FF6FF);
}

/// Kỳ công 12 — Thuỷ Tinh dâng nước đánh Sơn Tinh (rules/cottruyen.md).
/// Nước dâng vẽ phía trước nhân vật, cao đúng theo mực nước của trận.
class ThuyTinhBossArt extends BossArt {
  @override
  final Vector2 target = Vector2(318, 112);

  @override
  List<Color> get hitColors => const [
    ThuyTinhColors.foam,
    ThuyTinhColors.glow,
    Color(0xFFFFE082),
  ];

  // ---------------------------------------------------------------- nền
  @override
  void paintBackdrop(Canvas canvas) {
    final w = stageSize.width;
    final h = stageSize.height;
    // Trời giông chiều.
    canvas.drawRect(
      Offset.zero & stageSize,
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          const Offset(0, 175),
          const [Color(0xFF1F2B44), Color(0xFF4E6478), Color(0xFF8BA3AE)],
          const [0, 0.6, 1],
        ),
    );
    // Mây giông nặng.
    final cloud = fillPaint(const Color(0xFF2B3850).withValues(alpha: 0.85));
    for (final (x, y, rx, ry) in [
      (60.0, 30.0, 90.0, 22.0),
      (210.0, 18.0, 120.0, 26.0),
      (360.0, 36.0, 80.0, 20.0),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2),
        cloud,
      );
    }

    // Núi Tản Viên ba đỉnh (phe Sơn Tinh) phía sau người chơi.
    final far = Path()
      ..moveTo(0, 175)
      ..lineTo(0, 120)
      ..quadraticBezierTo(30, 100, 55, 92)
      ..quadraticBezierTo(75, 86, 95, 98)
      ..quadraticBezierTo(115, 70, 135, 66)
      ..quadraticBezierTo(158, 70, 172, 92)
      ..quadraticBezierTo(195, 84, 215, 100)
      ..quadraticBezierTo(240, 120, 262, 175)
      ..close();
    canvas.drawPath(far, fillPaint(const Color(0xFF4F6E6A)));
    // Mặt khuất sáng của núi.
    canvas.drawPath(
      Path()
        ..moveTo(135, 66)
        ..quadraticBezierTo(158, 70, 172, 92)
        ..quadraticBezierTo(195, 84, 215, 100)
        ..quadraticBezierTo(240, 120, 262, 175)
        ..lineTo(150, 175)
        ..close(),
      fillPaint(const Color(0xFF3F5B57)),
    );
    // Sương vắt ngang sườn núi.
    canvas.drawOval(
      const Rect.fromLTWH(20, 118, 210, 14),
      fillPaint(const Color(0x33FFFFFF)),
    );

    // Biển động phía Thuỷ Tinh.
    canvas.drawRect(
      Rect.fromLTRB(200, 168, w, h),
      Paint()
        ..shader = Gradient.linear(const Offset(0, 168), Offset(0, h), const [
          Color(0xFF3A7F8E),
          Color(0xFF194B5A),
        ]),
    );

    // Đồi đất người chơi đứng, dốc xuống biển bên phải.
    final hill = Path()
      ..moveTo(0, stageGroundY - 4)
      ..lineTo(232, stageGroundY - 4)
      ..quadraticBezierTo(258, stageGroundY, 280, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      hill,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, stageGroundY),
          Offset(0, h),
          const [Color(0xFF6E8B3D), Color(0xFF4C5E2A)],
        ),
    );
    // Ruộng bậc thang dưới chân đồi.
    final terrace = Paint()
      ..color = const Color(0xFF8FAF55)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 4; i++) {
      final y = stageGroundY + 8 + i * 9.0;
      canvas.drawPath(
        Path()
          ..moveTo(0, y)
          ..quadraticBezierTo(120, y - 4, 240 - i * 6.0, y + 2),
        terrace,
      );
    }
  }

  @override
  void paintAmbient(Canvas canvas, double time) {
    // Chớp xa thỉnh thoảng loé.
    final cycle = time % 7.3;
    if (cycle < 0.18) {
      canvas.drawRect(
        Offset.zero & stageSize,
        fillPaint(
          const Color(0xFFFFFFFF).withValues(alpha: 0.18 * (1 - cycle / 0.18)),
        ),
      );
      canvas.drawPath(
        Path()
          ..moveTo(250, 0)
          ..lineTo(240, 30)
          ..lineTo(252, 34)
          ..lineTo(236, 70),
        Paint()
          ..color = const Color(0xFFF4FBFF)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
    // Sóng biển xa chạy ngang.
    final wave = Paint()
      ..color = const Color(0x66E9FBFF)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var row = 0; row < 3; row++) {
      final y = 176.0 + row * 12;
      for (var i = 0; i < 4; i++) {
        final x = 205 + ((i * 55 + time * (14 + row * 6)) % 200);
        canvas.drawArc(
          Rect.fromLTWH(x, y, 14, 6),
          math.pi,
          math.pi,
          false,
          wave,
        );
      }
    }
    // Mưa xiên.
    final rain = Paint()
      ..color = const Color(0x55DDEFFF)
      ..strokeWidth = 1;
    final rnd = math.Random(3);
    for (var i = 0; i < 46; i++) {
      final x0 = rnd.nextDouble() * 460;
      final speed = 180 + rnd.nextDouble() * 80;
      final y = (rnd.nextDouble() * 300 + time * speed) % 300 - 20;
      final x = x0 - y * 0.35;
      canvas.drawLine(Offset(x, y), Offset(x - 4, y + 11), rain);
    }
  }

  // ---------------------------------------------------------------- boss
  @override
  void paintBoss(Canvas canvas, BossFrame f) {
    final sink = f.defeat * 110;
    final bob = math.sin(f.time * 1.4) * 3 + sink;
    final tint = f.hurt > 0
        ? Color.fromRGBO(255, 255, 255, 0.7 * f.hurt)
        : f.defeat > 0
        ? Color.fromRGBO(30, 60, 80, 0.5 * f.defeat)
        : null;
    if (tint != null) {
      canvas.saveLayer(
        null,
        Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.srcATop),
      );
    }
    canvas.save();
    // Chìm xuống dưới mặt sóng khi thua.
    canvas.clipRect(const Rect.fromLTRB(200, -40, 420, 240));
    canvas.translate(0, bob);
    _hairBack(canvas, f);
    _trident(canvas, f);
    _torso(canvas, f);
    _head(canvas, f);
    _frontArm(canvas, f);
    canvas.restore();
    _waveThrone(canvas, f);
    if (tint != null) canvas.restore();
  }

  void _hairBack(Canvas canvas, BossFrame f) {
    // Tóc nước bay về phía sau (phải), các lọn uốn theo thời gian.
    for (var i = 0; i < 4; i++) {
      final sway = math.sin(f.time * 2 + i) * 6;
      final y = 50.0 + i * 12;
      final path = Path()
        ..moveTo(330, y)
        ..cubicTo(355, y - 10 + sway, 375, y + 12, 395 + i * 3, y + 4 + sway)
        ..cubicTo(378, y + 20, 358, y + 8 - sway * 0.5, 332, y + 14)
        ..close();
      shadedPath(
        canvas,
        path,
        i.isEven ? ThuyTinhColors.hair : lighten(ThuyTinhColors.water, 0.2),
        PartFrame.world,
        shadow: 2,
        highlight: 1,
        outlineWidth: 1.4,
      );
    }
  }

  void _trident(Canvas canvas, BossFrame f) {
    final lift = -12 * f.attack;
    final top = Offset(374, 22 + lift);
    final bottom = Offset(380, 210 + lift);
    final shaft = Paint()
      ..color = VectorStyle.outline
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(top, bottom, shaft);
    canvas.drawLine(
      top,
      bottom,
      Paint()
        ..shader = Gradient.linear(
          top,
          bottom,
          const [Color(0xFFFFF1A8), ThuyTinhColors.gold, Color(0xFFB07A14)],
          const [0, 0.5, 1],
        )
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round,
    );
    // Ba mũi đinh ba.
    final prongs = Path()
      ..moveTo(top.dx - 14, top.dy + 4)
      ..quadraticBezierTo(top.dx - 14, top.dy + 16, top.dx, top.dy + 16)
      ..quadraticBezierTo(top.dx + 14, top.dy + 16, top.dx + 14, top.dy + 4)
      ..lineTo(top.dx + 16, top.dy - 10)
      ..lineTo(top.dx + 10, top.dy + 4)
      ..quadraticBezierTo(top.dx + 9, top.dy + 11, top.dx + 2, top.dy + 11)
      ..lineTo(top.dx + 2, top.dy - 16)
      ..lineTo(top.dx, top.dy - 24)
      ..lineTo(top.dx - 2, top.dy - 16)
      ..lineTo(top.dx - 2, top.dy + 11)
      ..quadraticBezierTo(top.dx - 9, top.dy + 11, top.dx - 10, top.dy + 4)
      ..lineTo(top.dx - 16, top.dy - 10)
      ..close();
    shadedPath(
      canvas,
      prongs,
      ThuyTinhColors.gold,
      PartFrame.world,
      shadow: 1.6,
      highlight: 1,
      outlineWidth: 1.4,
    );
    // Ánh nước toả ra khi đe doạ.
    if (f.attack > 0.05) {
      canvas.drawCircle(
        top,
        14 + 10 * f.attack,
        Paint()
          ..color = ThuyTinhColors.glow.withValues(alpha: 0.45 * f.attack)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    // Tay phải nắm cán.
    shadedChain(canvas, [
      (const Offset(358, 104), Offset(372, 84 + lift * 0.6), 8, 7),
      (Offset(372, 84 + lift * 0.6), Offset(377, 66 + lift), 7, 8),
    ], ThuyTinhColors.skin);
  }

  void _torso(Canvas canvas, BossFrame f) {
    final body = Path()
      ..moveTo(296, 182)
      ..cubicTo(292, 150, 284, 118, 290, 98)
      ..quadraticBezierTo(318, 86, 360, 96)
      ..cubicTo(368, 120, 360, 150, 352, 182)
      ..close();
    shadedPath(
      canvas,
      body,
      ThuyTinhColors.skin,
      PartFrame.world,
      shadow: 6,
      highlight: 2,
    );
    final line = Paint()
      ..color = darken(ThuyTinhColors.skin, 0.3)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // Cơ ngực và bụng.
    canvas.drawPath(
      Path()
        ..moveTo(300, 118)
        ..quadraticBezierTo(314, 128, 326, 118)
        ..moveTo(326, 118)
        ..quadraticBezierTo(340, 128, 352, 116)
        ..moveTo(326, 132)
        ..lineTo(326, 170)
        ..moveTo(314, 145)
        ..lineTo(338, 145)
        ..moveTo(315, 158)
        ..lineTo(337, 158),
      line,
    );
    // Chuỗi ngọc trai vắt chéo ngực.
    for (var i = 0; i < 8; i++) {
      final t = i / 7;
      final p = Offset(296 + 56 * t, 100 + 26 * t + math.sin(t * math.pi) * 4);
      canvas.drawCircle(p, 3.2, fillPaint(VectorStyle.outline));
      canvas.drawCircle(p, 2.4, fillPaint(const Color(0xFFFFFAF0)));
      glint(canvas, p + const Offset(-0.8, -0.8), 1, alpha: 0.9);
    }
    // Giáp vai san hô.
    final coral = Path();
    for (var i = 0; i <= 8; i++) {
      final a = math.pi * (1.0 + i / 8);
      final r = i.isEven ? 18.0 : 11.0;
      final p = Offset(352 + math.cos(a) * r, 100 + math.sin(a) * r * 0.8);
      i == 0 ? coral.moveTo(p.dx, p.dy) : coral.lineTo(p.dx, p.dy);
    }
    coral.close();
    shadedPath(
      canvas,
      coral,
      ThuyTinhColors.coral,
      PartFrame.world,
      shadow: 2.5,
      highlight: 1.2,
    );
  }

  void _head(Canvas canvas, BossFrame f) {
    const c = Offset(318, 68);
    // Râu nước dài chảy xuống ngực.
    final sway = math.sin(f.time * 1.8) * 4;
    final beard = Path()
      ..moveTo(300, 74)
      ..cubicTo(296, 98, 304 + sway, 120, 316 + sway, 134)
      ..cubicTo(322, 122, 326, 104, 336, 78)
      ..close();
    shadedPath(
      canvas,
      beard,
      ThuyTinhColors.hair,
      PartFrame.world,
      shadow: 3,
      highlight: 1.4,
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(306 + i * 7.0 + sway * 0.5, 100 + i * 8.0),
          radius: 5,
        ),
        0.3,
        2.4,
        false,
        Paint()
          ..color = darken(ThuyTinhColors.hair, 0.25)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );
    }
    // Mặt (quay sang trái về phía người chơi).
    final face = Path()
      ..moveTo(332, 50)
      ..cubicTo(320, 44, 302, 48, 297, 60)
      ..lineTo(290, 66)
      ..lineTo(297, 70)
      ..cubicTo(298, 80, 310, 86, 326, 82)
      ..cubicTo(336, 76, 338, 58, 332, 50)
      ..close();
    shadedPath(
      canvas,
      face,
      ThuyTinhColors.skin,
      PartFrame.world,
      shadow: 3.5,
      highlight: 1.4,
    );
    // Mắt phát sáng, mày giận.
    final eye = c + const Offset(-8, -6);
    canvas.drawCircle(
      eye,
      6,
      Paint()
        ..color = ThuyTinhColors.glow.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawOval(
      Rect.fromCenter(center: eye, width: 7, height: 4.5),
      fillPaint(const Color(0xFFE8FFFF)),
    );
    canvas.drawLine(
      eye + const Offset(-6, -5),
      eye + const Offset(6, -2),
      Paint()
        ..color = VectorStyle.outline
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    // Miệng: há ra khi đe doạ.
    final open = 2 + 6 * f.attack;
    final mouth = Path()
      ..moveTo(296, 74)
      ..quadraticBezierTo(303, 74 + open, 310, 73)
      ..quadraticBezierTo(303, 72, 296, 74)
      ..close();
    canvas.drawPath(mouth, fillPaint(const Color(0xFF14323C)));
    // Vương miện vàng có ngọc trai.
    final crown = Path()
      ..moveTo(300, 50)
      ..lineTo(302, 34)
      ..lineTo(309, 44)
      ..lineTo(316, 28)
      ..lineTo(323, 42)
      ..lineTo(331, 32)
      ..lineTo(334, 50)
      ..quadraticBezierTo(317, 45, 300, 50)
      ..close();
    canvas.drawPath(
      crown,
      Paint()
        ..color = VectorStyle.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(crown, goldPaint(crown.getBounds()));
    canvas.drawCircle(
      const Offset(316, 40),
      2.6,
      fillPaint(const Color(0xFFFFFAF0)),
    );
    glint(canvas, const Offset(306, 44), 1.4);
  }

  void _frontArm(Canvas canvas, BossFrame f) {
    // Tay trái chỉ về phía người chơi, lòng bàn tay toả nước khi đe doạ.
    final reach = 6 * f.attack;
    final hand = Offset(262 - reach, 132 - reach);
    shadedChain(canvas, [
      (const Offset(294, 104), const Offset(276, 124), 8.5, 7.5),
      (const Offset(276, 124), hand, 7.5, 7),
      (hand, hand, 8, 8),
    ], ThuyTinhColors.skin);
    if (f.attack > 0.05) {
      canvas.drawCircle(
        hand + const Offset(-8, 0),
        10 * f.attack + 3,
        Paint()
          ..color = ThuyTinhColors.glow.withValues(alpha: 0.6 * f.attack)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  void _waveThrone(Canvas canvas, BossFrame f) {
    // Con sóng cuộn ôm lấy thân dưới; dâng cao khi đe doạ.
    final surge = 10 * f.attack;
    final t = f.time;
    final wave = Path()
      ..moveTo(246, 240)
      ..cubicTo(250, 210 - surge, 262, 182 - surge, 290, 170 - surge)
      ..quadraticBezierTo(306, 162 - surge, 314, 172 - surge)
      ..quadraticBezierTo(304, 170 - surge, 300, 180 - surge)
      ..cubicTo(318, 186, 350, 176 + math.sin(t * 2) * 3, 372, 172)
      ..cubicTo(390, 168, 404, 176, 410, 178)
      ..lineTo(410, 240)
      ..close();
    canvas.drawPath(
      wave,
      Paint()
        ..color = VectorStyle.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      wave,
      Paint()
        ..shader = Gradient.linear(
          const Offset(0, 160),
          const Offset(0, 240),
          const [ThuyTinhColors.water, ThuyTinhColors.waterDeep],
        ),
    );
    // Bọt trắng dọc ngọn sóng.
    final foam = fillPaint(ThuyTinhColors.foam);
    for (var i = 0; i < 9; i++) {
      final x = 262 + i * 15.0;
      final y = i < 3
          ? 196 - i * 10.0 - surge
          : 176 + math.sin(t * 2 + i) * 2.5 + (i == 3 ? -4 - surge : 0);
      canvas.drawCircle(Offset(x, y), 4 + (i % 3), foam);
    }
    // Vân nước bên trong sóng.
    final streak = Paint()
      ..color = lighten(ThuyTinhColors.water, 0.35).withValues(alpha: 0.6)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final y = 200.0 + i * 12;
      canvas.drawPath(
        Path()
          ..moveTo(280 + i * 10.0, y)
          ..quadraticBezierTo(320, y - 6 + math.sin(t + i) * 2, 360, y),
        streak,
      );
    }
  }

  // ------------------------------------------------------- nước dâng
  @override
  void paintForeground(Canvas canvas, BossFrame f) {
    final level = f.battle.water.clamp(0.0, 100.0);
    if (level <= 0.5) return;
    final w = stageSize.width;
    final h = stageSize.height;
    // 0% sát mặt đất; khoảng 90% thì nước chạm đầu người đang chống đẩy.
    final surface = 236 - level / 100 * 95;
    final t = f.time;
    final path = Path()..moveTo(0, h);
    for (var x = 0.0; x <= w; x += 10) {
      path.lineTo(x, surface + math.sin(x * 0.05 + t * 2.2) * 2.5);
    }
    path
      ..lineTo(w, h)
      ..close();
    final danger = level > 75;
    canvas.drawPath(
      path,
      Paint()
        ..shader = Gradient.linear(Offset(0, surface), Offset(0, h), [
          (danger ? const Color(0xFF3A86A6) : ThuyTinhColors.water).withValues(
            alpha: 0.62,
          ),
          ThuyTinhColors.waterDeep.withValues(alpha: 0.85),
        ]),
    );
    // Viền bọt trên mặt nước.
    final crest = Path();
    for (var x = 0.0; x <= w; x += 10) {
      final y = surface + math.sin(x * 0.05 + t * 2.2) * 2.5;
      x == 0 ? crest.moveTo(x, y) : crest.lineTo(x, y);
    }
    canvas.drawPath(
      crest,
      Paint()
        ..color = ThuyTinhColors.foam.withValues(alpha: 0.9)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke,
    );
    // Vệt sáng trôi trên mặt nước.
    final shine = Paint()
      ..color = const Color(0x66FFFFFF)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final x = (i * 70 + t * 18) % (w + 40) - 20;
      final y = surface + 8 + (i % 3) * 7;
      if (y < h) canvas.drawLine(Offset(x, y), Offset(x + 14, y), shine);
    }
  }
}
