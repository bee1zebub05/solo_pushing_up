import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../battle_stage.dart';
import '../nemea_scene.dart' show stageGroundY, stageSize;
import '../vector_style.dart';

/// Bảng màu Kỳ công 2 — Bắc Âu, rừng băng.
abstract final class FafnirColors {
  static const body = Color(0xFF4F7391);
  static const belly = Color(0xFFC8DCE6);
  static const wing = Color(0xFF3A5670);
  static const horn = Color(0xFFE8E2D0);
  static const eye = Color(0xFFB8F1FF);
  static const frost = Color(0xFF9FE8FF);
  static const gold = Color(0xFFE8B83A);
  static const snow = Color(0xFFF2F8FF);
}

/// Kỳ công 2 — Rồng Fafnir canh kho vàng (rules/cottruyen.md). Hơi thở băng
/// khi đe doạ; nhân vật đóng băng dần khi nghỉ lâu (StageBattleState.cold).
class FafnirBossArt extends BossArt {
  @override
  final Vector2 target = Vector2(292, 108);

  @override
  Vector2 get portraitFocus => Vector2(284, 102);

  @override
  List<Color> get hitColors => const [
    FafnirColors.frost,
    Color(0xFFFFFFFF),
    Color(0xFFFFE082),
  ];

  // ---------------------------------------------------------------- nền
  @override
  void paintBackdrop(Canvas canvas) {
    final w = stageSize.width;
    final h = stageSize.height;
    // Trời đêm Bắc Âu.
    canvas.drawRect(
      Offset.zero & stageSize,
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          const Offset(0, 200),
          const [Color(0xFF0B1630), Color(0xFF1E3550), Color(0xFF3E5C72)],
          const [0, 0.6, 1],
        ),
    );
    // Sao.
    final rnd = math.Random(11);
    for (var i = 0; i < 40; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * w, rnd.nextDouble() * 110),
        rnd.nextDouble() * 0.9 + 0.3,
        fillPaint(const Color(0xCCFFFFFF)),
      );
    }
    // Núi tuyết xa.
    final mountains = Path()
      ..moveTo(0, 175)
      ..lineTo(40, 128)
      ..lineTo(80, 158)
      ..lineTo(130, 112)
      ..lineTo(185, 160)
      ..lineTo(240, 120)
      ..lineTo(300, 165)
      ..lineTo(350, 130)
      ..lineTo(400, 160)
      ..lineTo(400, 200)
      ..lineTo(0, 200)
      ..close();
    canvas.drawPath(mountains, fillPaint(const Color(0xFF2F4A63)));
    // Đỉnh phủ tuyết.
    final caps = fillPaint(const Color(0xFFB9CFE0));
    for (final (x, y) in [
      (40.0, 128.0),
      (130.0, 112.0),
      (240.0, 120.0),
      (350.0, 130.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..lineTo(x - 11, y + 12)
          ..lineTo(x - 3, y + 9)
          ..lineTo(x + 4, y + 13)
          ..lineTo(x + 11, y + 11)
          ..close(),
        caps,
      );
    }
    // Rừng thông phủ tuyết.
    for (var i = 0; i < 12; i++) {
      final x = i * 36.0 + 10;
      final top = 150.0 + (i % 3) * 8;
      final tree = Path()
        ..moveTo(x, top)
        ..lineTo(x - 13, 206)
        ..lineTo(x + 13, 206)
        ..close();
      canvas.drawPath(tree, fillPaint(const Color(0xFF173246)));
      canvas.drawPath(
        Path()
          ..moveTo(x, top)
          ..lineTo(x - 6, top + 14)
          ..lineTo(x + 5, top + 12)
          ..close(),
        fillPaint(const Color(0xFFDCEAF5)),
      );
    }
    // Nền tuyết.
    canvas.drawRect(
      Rect.fromLTRB(0, stageGroundY - 6, w, h),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, stageGroundY),
          Offset(0, h),
          const [Color(0xFFE3EEF7), Color(0xFFA9C2D6)],
        ),
    );
    // Bia đá khắc rune phía sau người chơi.
    final stone = Path()
      ..moveTo(22, stageGroundY - 4)
      ..lineTo(18, 160)
      ..quadraticBezierTo(32, 146, 48, 158)
      ..lineTo(46, stageGroundY - 4)
      ..close();
    shadedPath(
      canvas,
      stone,
      const Color(0xFF6E7F8C),
      PartFrame.world,
      shadow: 3,
      highlight: 1.2,
    );
    final rune = Paint()
      ..color = const Color(0xFF8FE3FF)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(30, 168), const Offset(30, 190), rune);
    canvas.drawLine(const Offset(30, 172), const Offset(37, 166), rune);
    canvas.drawLine(const Offset(30, 180), const Offset(37, 174), rune);
  }

  @override
  void paintAmbient(Canvas canvas, double time) {
    // Cực quang uốn lượn.
    for (final (y, color, speed) in [
      (40.0, const Color(0x4434F5B0), 0.4),
      (58.0, const Color(0x33A06BFF), 0.3),
    ]) {
      final path = Path()..moveTo(-10, y);
      for (var x = -10.0; x <= 410; x += 20) {
        path.lineTo(x, y + math.sin(x / 50 + time * speed) * 10);
      }
      for (var x = 410.0; x >= -10; x -= 20) {
        path.lineTo(x, y + 24 + math.sin(x / 45 + time * speed + 1) * 8);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    // Tuyết rơi.
    final flake = fillPaint(const Color(0xDDFFFFFF));
    final rnd = math.Random(9);
    for (var i = 0; i < 40; i++) {
      final speed = 18 + rnd.nextDouble() * 22;
      final x0 = rnd.nextDouble() * 400;
      final y = (rnd.nextDouble() * 280 + time * speed) % 280 - 10;
      final x = x0 + math.sin(time * 0.8 + i) * 6;
      canvas.drawCircle(Offset(x, y), 0.8 + rnd.nextDouble() * 1.2, flake);
    }
  }

  // ---------------------------------------------------------------- boss
  @override
  void paintBoss(Canvas canvas, BossFrame f) {
    final breathe = math.sin(f.time * 1.5) * 2;
    final tint = f.hurt > 0
        ? Color.fromRGBO(255, 255, 255, 0.7 * f.hurt)
        : f.defeat > 0
        ? Color.fromRGBO(30, 40, 60, 0.5 * f.defeat)
        : null;
    if (tint != null) {
      canvas.saveLayer(
        null,
        Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.srcATop),
      );
    }
    _gold(canvas, f);
    canvas.save();
    // Gục: đầu và cổ hạ xuống đống vàng.
    canvas.translate(0, f.defeat * 30);
    _wing(canvas, f, breathe);
    _tail(canvas, f);
    _body(canvas, breathe);
    _neckAndHead(canvas, f, breathe);
    canvas.restore();
    if (tint != null) canvas.restore();
    if (f.attack > 0.05 && f.defeat == 0) _frostBreath(canvas, f);
  }

  void _gold(Canvas canvas, BossFrame f) {
    final pile = Path()
      ..moveTo(258, stageGroundY + 4)
      ..quadraticBezierTo(330, 178, 410, stageGroundY + 4)
      ..close();
    canvas.drawPath(
      pile,
      Paint()
        ..color = VectorStyle.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawPath(pile, goldPaint(pile.getBounds()));
    // Đồng xu và ánh lấp lánh.
    final coin = fillPaint(const Color(0xFFFFE27A));
    final rnd = math.Random(2);
    for (var i = 0; i < 14; i++) {
      final x = 275 + rnd.nextDouble() * 120;
      final y = 206 + rnd.nextDouble() * 14;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 6, height: 3),
        coin,
      );
    }
    for (var i = 0; i < 3; i++) {
      final phase = (f.time * 0.7 + i * 0.33) % 1;
      if (phase < 0.25) {
        final at = Offset(290 + i * 38.0, 200 - i * 4.0);
        final s = math.sin(phase / 0.25 * math.pi) * 5;
        final p = Paint()
          ..color = const Color(0xFFFFFFFF)
          ..strokeWidth = 1.2;
        canvas.drawLine(at - Offset(s, 0), at + Offset(s, 0), p);
        canvas.drawLine(at - Offset(0, s), at + Offset(0, s), p);
      }
    }
  }

  void _wing(Canvas canvas, BossFrame f, double breathe) {
    final lift = 10 * f.attack;
    final wing = Path()
      ..moveTo(340, 150)
      ..lineTo(352, 60 - lift)
      ..lineTo(370, 84 - lift)
      ..lineTo(384, 66 - lift)
      ..lineTo(396, 96 - lift)
      ..lineTo(410, 88 - lift)
      ..lineTo(404, 150)
      ..close();
    shadedPath(
      canvas,
      wing,
      FafnirColors.wing,
      PartFrame.world,
      shadow: 4,
      highlight: 1.4,
    );
    // Xương cánh.
    final bone = Paint()
      ..color = darken(FafnirColors.wing, 0.35)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final tip in [Offset(370, 84 - lift), Offset(396, 96 - lift)]) {
      canvas.drawLine(const Offset(350, 140), tip, bone);
    }
  }

  void _tail(Canvas canvas, BossFrame f) {
    final sway = math.sin(f.time * 1.2) * 6;
    final tail = Path()
      ..moveTo(372, 184)
      ..quadraticBezierTo(410, 170 + sway, 404, 140 + sway);
    for (final (width, color) in [
      (13.0, VectorStyle.outline),
      (9.0, FafnirColors.body),
    ]) {
      canvas.drawPath(
        tail,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _body(Canvas canvas, double breathe) {
    final body = Path()
      ..moveTo(298, 200)
      ..cubicTo(296, 168 - breathe, 330, 144 - breathe, 360, 150 - breathe)
      ..cubicTo(386, 156, 392, 186, 380, 204)
      ..close();
    shadedPath(
      canvas,
      body,
      FafnirColors.body,
      PartFrame.world,
      shadow: 5,
      highlight: 1.8,
    );
    // Bụng sọc sáng.
    final belly = Paint()
      ..color = FafnirColors.belly
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final y = 176.0 + i * 7;
      canvas.drawLine(
        Offset(302 + i * 2.0, y),
        Offset(318 + i * 1.0, y + 1),
        belly,
      );
    }
    // Gai lưng.
    for (var i = 0; i < 5; i++) {
      final x = 318.0 + i * 12;
      final y = 150.0 - breathe + (i - 2).abs() * 2;
      shadedPath(
        canvas,
        Path()
          ..moveTo(x - 4, y + 4)
          ..lineTo(x, y - 8)
          ..lineTo(x + 4, y + 4)
          ..close(),
        FafnirColors.horn,
        PartFrame.world,
        shadow: 1,
        highlight: 0,
        outlineWidth: 1.2,
      );
    }
    // Chân trước có vuốt bám đống vàng.
    shadedChain(canvas, [
      (const Offset(312, 186), const Offset(302, 204), 7, 6),
      (const Offset(302, 204), const Offset(294, 210), 6, 5),
    ], FafnirColors.body);
    final claw = fillPaint(FafnirColors.horn);
    for (final dx in [-6.0, -1.0, 4.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(292 + dx, 212)
          ..lineTo(289 + dx, 217)
          ..lineTo(294 + dx, 214)
          ..close(),
        claw,
      );
    }
  }

  void _neckAndHead(Canvas canvas, BossFrame f, double breathe) {
    final rear = 8 * f.attack;
    final head = Offset(292, 104 - rear + breathe);
    // Cổ cong chữ S.
    final neck = Path()
      ..moveTo(330, 160)
      ..cubicTo(342, 130, 300, 132, 312, 110 - rear)
      ..lineTo(head.dx + 10, head.dy + 2);
    for (final (width, color) in [
      (19.0, VectorStyle.outline),
      (15.0, FafnirColors.body),
    ]) {
      canvas.drawPath(
        neck,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawPath(
      neck.shift(const Offset(-3, 3)),
      Paint()
        ..color = FafnirColors.belly.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    canvas.save();
    canvas.translate(head.dx, head.dy);
    // Sừng cong ra sau.
    for (final (dx, len) in [(8.0, 22.0), (2.0, 16.0)]) {
      shadedPath(
        canvas,
        Path()
          ..moveTo(dx, -8)
          ..quadraticBezierTo(dx + len * 0.6, -18, dx + len, -14)
          ..quadraticBezierTo(dx + len * 0.5, -12, dx + 4, -4)
          ..close(),
        FafnirColors.horn,
        PartFrame.world,
        shadow: 1.4,
        highlight: 0.6,
        outlineWidth: 1.3,
      );
    }
    // Hàm dưới mở khi phun băng.
    canvas.save();
    canvas.rotate(-0.45 * f.attack);
    shadedPath(
      canvas,
      Path()
        ..moveTo(8, 2)
        ..quadraticBezierTo(-12, 10, -28, 6)
        ..lineTo(-26, 2)
        ..close(),
      FafnirColors.belly,
      PartFrame.world,
      shadow: 1.5,
      highlight: 0.6,
      outlineWidth: 1.4,
    );
    canvas.restore();
    // Đầu rồng dài, mõm hướng về người chơi.
    final skull = Path()
      ..moveTo(14, -6)
      ..cubicTo(10, -16, -10, -14, -30, -4)
      ..quadraticBezierTo(-33, 1, -27, 3)
      ..cubicTo(-12, 4, 6, 6, 16, 2)
      ..close();
    shadedPath(
      canvas,
      skull,
      FafnirColors.body,
      PartFrame.world,
      shadow: 3,
      highlight: 1.4,
    );
    // Lỗ mũi bốc hơi lạnh.
    canvas.drawCircle(
      const Offset(-25, -3),
      1.4,
      fillPaint(VectorStyle.outline),
    );
    // Mắt xanh lạnh phát sáng, mày gai.
    const eye = Offset(-8, -7);
    canvas.drawCircle(
      eye,
      5,
      Paint()
        ..color = FafnirColors.eye.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawOval(
      Rect.fromCenter(center: eye, width: 7, height: 4),
      fillPaint(FafnirColors.eye),
    );
    canvas.drawOval(
      Rect.fromCenter(center: eye, width: 1.6, height: 4),
      fillPaint(VectorStyle.outline),
    );
    canvas.drawLine(
      eye + const Offset(-6, -4),
      eye + const Offset(7, -2),
      Paint()
        ..color = VectorStyle.outline
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _frostBreath(Canvas canvas, BossFrame f) {
    // Hơi thở băng hình nón hướng về người chơi.
    const mouth = Offset(262, 106);
    final reach = 150 * f.attack;
    final cone = Path()
      ..moveTo(mouth.dx, mouth.dy)
      ..lineTo(mouth.dx - reach, mouth.dy - 26 * f.attack)
      ..quadraticBezierTo(
        mouth.dx - reach - 14,
        mouth.dy + 12,
        mouth.dx - reach,
        mouth.dy + 44 * f.attack,
      )
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = Gradient.linear(mouth, mouth - Offset(reach, 0), [
          FafnirColors.frost.withValues(alpha: 0.85),
          FafnirColors.frost.withValues(alpha: 0.05),
        ])
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    final rnd = math.Random(4);
    for (var i = 0; i < 10; i++) {
      final t = rnd.nextDouble();
      final p =
          mouth +
          Offset(-reach * t, (rnd.nextDouble() - 0.4) * 40 * t * f.attack);
      canvas.drawCircle(p, 1.4, fillPaint(const Color(0xEEFFFFFF)));
    }
  }
}
