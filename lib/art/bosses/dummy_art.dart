import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../battle_stage.dart';
import '../nemea_scene.dart';
import '../vector_style.dart';

/// Bù nhìn tập luyện (Thử thách 30 giây): bao rơm buộc dây trên cọc gỗ
/// có xà ngang làm tay, khiên gỗ cũ treo một bên, bia hồng tâm sơn trên
/// ngực; đứng ở sân tập trước thung lũng Nemea (đã sạch bụi).
class TrainingDummyArt extends BossArt {
  static const _base = Offset(318, stageGroundY);

  @override
  Vector2 get target => Vector2(_base.dx - 6, _base.dy - 92);

  @override
  Vector2 get portraitFocus => Vector2(_base.dx, _base.dy - 96);

  @override
  double get portraitView => 90;

  @override
  void paintBackdrop(Canvas canvas) => paintNemeaBackdrop(canvas);

  @override
  void paintAmbient(Canvas canvas, double time) =>
      paintNemeaAmbient(canvas, time: time);

  @override
  List<Color> get hitColors => const [
    Color(0xFFE8C97A),
    Color(0xFFFFFFFF),
    Color(0xFFB08A4A),
  ];

  /// Thân bù nhìn tĩnh: chụp sẵn; trúng đòn thì nghiêng lắc quanh chân cọc.
  static final _image = RasterLayer(
    _paintDummy,
    bounds: const Rect.fromLTRB(260, 66, 376, 226),
    resolution: 1.6,
  );

  @override
  void paintBoss(Canvas canvas, BossFrame f) {
    // Bóng tiếp đất.
    canvas.drawOval(
      Rect.fromCenter(center: _base + const Offset(4, 2), width: 54, height: 8),
      fillPaint(const Color(0x55301C10)),
    );
    // Trúng đòn: lắc lò xo tắt dần quanh chân cọc; gục: đổ nghiêng.
    final wobble = math.sin(f.time * 22) * 0.12 * f.hurt;
    final fall = f.defeat.clamp(0.0, 1.0) * 1.1;
    canvas.save();
    canvas.translate(_base.dx, _base.dy);
    canvas.rotate(wobble + fall);
    canvas.translate(-_base.dx, -_base.dy);
    _image.paint(canvas);
    // Rơm bay ra khi trúng đòn.
    if (f.hurt > 0.05) {
      final rnd = math.Random(f.time.floor());
      for (var i = 0; i < 8; i++) {
        final a = -math.pi / 2 + (rnd.nextDouble() - 0.5) * 2.4;
        final d = 10 + 26 * (1 - f.hurt);
        final p =
            _base +
            const Offset(-6, -92) +
            Offset(math.cos(a), math.sin(a)) * d;
        canvas.drawPath(
          taperedStroke(
            [p, p + Offset(math.cos(a + 1.2), math.sin(a + 1.2)) * 5],
            1,
            peak: 0.5,
          ),
          fillPaint(Color.fromRGBO(232, 201, 122, f.hurt)),
        );
      }
    }
    canvas.restore();
  }

  static void _paintDummy(Canvas canvas) {
    const wood = Color(0xFF7A5634);
    const straw = Color(0xFFD9B865);
    const rope = Color(0xFF8A6A3A);
    final b = _base;
    // Cọc gỗ cắm đất + chân chống chéo.
    for (final (from, to, w) in [
      (b + const Offset(-14, 0), b + const Offset(-2, -30), 4.0),
      (b + const Offset(12, 0), b + const Offset(2, -30), 4.0),
      (b + const Offset(0, 2), b + const Offset(0, -126), 6.0),
    ]) {
      shadedPath(
        canvas,
        taperedStroke(
          [from, Offset.lerp(from, to, 0.5)!, to],
          w,
          peak: 0,
          startWidth: 1,
          endWidth: 0.85,
        ),
        wood,
        PartFrame.world,
        shadow: 1.6,
        highlight: 0.6,
        outlineWidth: 1.3,
      );
    }
    // Xà ngang làm tay, quấn rơm ở hai đầu.
    shadedPath(
      canvas,
      taperedStroke(
        [
          b + const Offset(-34, -100),
          b + const Offset(0, -102),
          b + const Offset(34, -98),
        ],
        4.6,
        peak: 0.5,
        startWidth: 0.85,
        endWidth: 0.85,
      ),
      wood,
      PartFrame.world,
      shadow: 1.4,
      highlight: 0.6,
      outlineWidth: 1.2,
    );
    for (final x in const [-33.0, 33.0]) {
      final c = b + Offset(x, -100);
      final tuft = buildLocks(
        center: c,
        rnd: math.Random(x.toInt() + 50),
        r0: 0,
        length: 9,
        width: 3.2,
        count: 6,
        from: x < 0 ? math.pi * 0.7 : -math.pi * 0.3,
        to: x < 0 ? math.pi * 1.3 : math.pi * 0.3,
        drift: const Offset(0, 0.3),
        wave: 2,
      );
      shadedPath(
        canvas,
        tuft.mass,
        straw,
        PartFrame.world,
        shadow: 1.2,
        highlight: 0.6,
        outlineWidth: 1,
      );
    }
    // Bao thân rơm: bao bố buộc dây ở eo và cổ, rơm lòi ra mép.
    final sack = smoothPath(
      [
        b + const Offset(-16, -116),
        b + const Offset(-20, -98),
        b + const Offset(-19, -78),
        b + const Offset(-14, -60),
        b + const Offset(0, -56),
        b + const Offset(14, -60),
        b + const Offset(19, -78),
        b + const Offset(20, -98),
        b + const Offset(16, -116),
        b + const Offset(0, -120),
      ],
      closed: true,
      tension: 0.1,
    );
    shadedPath(
      canvas,
      sack,
      const Color(0xFFC9B48A),
      PartFrame.world,
      shadow: 4,
      highlight: 1.4,
    );
    canvas.save();
    canvas.clipPath(sack);
    // Thớ vải bố ô dệt.
    final weave = Paint()
      ..color = const Color(0x339A7A4A)
      ..strokeWidth = 0.6;
    for (var y = -120.0; y < -56; y += 3) {
      canvas.drawLine(b + Offset(-22, y), b + Offset(22, y + 1), weave);
    }
    for (var x = -22.0; x < 22; x += 3) {
      canvas.drawLine(b + Offset(x, -120), b + Offset(x + 1, -56), weave);
    }
    // Bia hồng tâm sơn đỏ trắng trên ngực, sơn tróc.
    final center = b + const Offset(-4, -92);
    for (final (r, c) in const [
      (13.0, Color(0xFFB8322A)),
      (9.5, Color(0xFFF2E6CC)),
      (6.0, Color(0xFFB8322A)),
      (2.6, Color(0xFFF2E6CC)),
    ]) {
      canvas.drawCircle(center, r, fillPaint(c.withValues(alpha: 0.9)));
    }
    for (final (o, r) in const [(Offset(6, -6), 2.4), (Offset(-9, 5), 1.8)]) {
      canvas.drawCircle(center + o, r, fillPaint(const Color(0xFFC9B48A)));
    }
    // Vết rách vá chỉ.
    canvas.drawPath(
      taperedStroke([b + const Offset(8, -74), b + const Offset(13, -68)], 1.4),
      fillPaint(const Color(0xFF6E5638)),
    );
    for (var i = 0; i < 3; i++) {
      final p = Offset.lerp(
        b + const Offset(8, -74),
        b + const Offset(13, -68),
        (i + 0.5) / 3,
      )!;
      canvas.drawLine(
        p + const Offset(-1.5, 1.2),
        p + const Offset(1.5, -1.2),
        Paint()
          ..color = const Color(0xFF3A2A1A)
          ..strokeWidth = 0.6,
      );
    }
    canvas.restore();
    // Dây buộc cổ và eo.
    for (final y in const [-112.0, -62.0]) {
      final w = y < -100 ? 15.0 : 13.0;
      canvas.drawPath(
        taperedStroke(
          [b + Offset(-w, y + 1), b + Offset(0, y + 2.4), b + Offset(w, y + 1)],
          2.4,
          peak: 0.5,
          startWidth: 0.9,
          endWidth: 0.9,
        ),
        fillPaint(rope),
      );
    }
    // Rơm lòi ra dưới eo.
    final under = buildLocks(
      center: b + const Offset(0, -60),
      rnd: math.Random(77),
      r0: 0,
      length: 10,
      width: 3,
      count: 9,
      from: math.pi * 0.25,
      to: math.pi * 0.75,
      drift: const Offset(0, 0.25),
      wave: 2,
    );
    shadedPath(
      canvas,
      under.mass,
      straw,
      PartFrame.world,
      shadow: 1.2,
      highlight: 0.6,
      outlineWidth: 1,
    );
    // Đầu: bao nhỏ nhét rơm, mặt vẽ than (hai chấm + vạch).
    final head = Path()
      ..addOval(
        Rect.fromCenter(
          center: b + const Offset(0, -130),
          width: 22,
          height: 20,
        ),
      );
    shadedPath(
      canvas,
      head,
      const Color(0xFFC9B48A),
      PartFrame.world,
      shadow: 2.4,
      highlight: 1,
    );
    final coal = Paint()
      ..color = const Color(0xFF2A1E16)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      b + const Offset(-7, -133),
      b + const Offset(-3, -131),
      coal,
    );
    canvas.drawLine(
      b + const Offset(-7, -131),
      b + const Offset(-3, -133),
      coal,
    );
    canvas.drawLine(b + const Offset(1, -133), b + const Offset(5, -131), coal);
    canvas.drawLine(b + const Offset(1, -131), b + const Offset(5, -133), coal);
    canvas.drawLine(
      b + const Offset(-5, -125),
      b + const Offset(3, -125.5),
      coal,
    );
    final hat = buildLocks(
      center: b + const Offset(0, -138),
      rnd: math.Random(3),
      r0: 4,
      length: 8,
      width: 3,
      count: 8,
      from: -math.pi * 0.95,
      to: -math.pi * 0.05,
      drift: const Offset(0, 0.25),
      wave: 2,
    );
    shadedPath(
      canvas,
      hat.mass,
      straw,
      PartFrame.world,
      shadow: 1,
      highlight: 0.6,
      outlineWidth: 1,
    );
    // Khiên gỗ cũ treo trên tay phải xà (phía xa người chơi).
    final shieldC = b + const Offset(26, -86);
    final shield = Path()
      ..addOval(Rect.fromCircle(center: shieldC, radius: 11));
    shadedPath(
      canvas,
      shield,
      const Color(0xFF8A6A44),
      PartFrame.world,
      shadow: 2.2,
      highlight: 0.8,
    );
    canvas.save();
    canvas.clipPath(shield);
    for (var i = -2; i <= 2; i++) {
      canvas.drawLine(
        shieldC + Offset(i * 4.4, -12),
        shieldC + Offset(i * 4.4, 12),
        Paint()
          ..color = const Color(0xFF5E4428)
          ..strokeWidth = 0.8,
      );
    }
    canvas.restore();
    canvas.drawCircle(
      shieldC,
      11,
      Paint()
        ..color = const Color(0xFF6E7A82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    canvas.drawLine(
      shieldC + const Offset(0, -11),
      b + const Offset(30, -98),
      Paint()
        ..color = rope
        ..strokeWidth = 1,
    );
  }
}
