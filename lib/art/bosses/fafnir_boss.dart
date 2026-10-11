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

  // Phần tĩnh chụp sẵn: kho vàng, thân + chân trước, cánh (xoay quanh vai).
  static final _hoardImage = RasterLayer(
    _paintHoard,
    bounds: const Rect.fromLTRB(250, 168, 420, 246),
    resolution: 1.3,
  );
  static final _bodyImage = RasterLayer(
    _paintBody,
    bounds: const Rect.fromLTRB(276, 116, 420, 222),
    resolution: 1.3,
  );
  static final _wingImage = RasterLayer(
    _paintWing,
    bounds: const Rect.fromLTRB(326, 36, 426, 162),
    resolution: 1.2,
  );
  static const _shoulder = Offset(346, 150);

  void _gold(Canvas canvas, BossFrame f) {
    _hoardImage.paint(canvas);
    // Ánh lấp lánh chạy trên đống vàng.
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

  /// Kho báu của Fafnir: núi đồng xu (mỗi đồng có vành tối, mặt sáng), chén
  /// vàng, chuôi kiếm cắm nghiêng, mũ trụ Bắc Âu lăn bên chân.
  static void _paintHoard(Canvas canvas) {
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
    canvas.save();
    canvas.clipPath(pile);
    final rnd = math.Random(2);
    final rim = fillPaint(const Color(0xFF9A6A14));
    final face = fillPaint(const Color(0xFFFFD55A));
    final shine = fillPaint(const Color(0xFFFFF4C0));
    for (var i = 0; i < 90; i++) {
      final x = 262 + rnd.nextDouble() * 144;
      // Mặt đống vàng: parabol, đồng xu rải từ đỉnh xuống chân.
      final t = (x - 258) / 152;
      final top =
          stageGroundY + 4 - 4 * t * (1 - t) * (stageGroundY + 4 - 178) * 0.5;
      final y = top + 2 + rnd.nextDouble() * (stageGroundY - top);
      final w = 5.0 + rnd.nextDouble() * 2.5;
      final c = Offset(x, y);
      canvas.drawOval(
        Rect.fromCenter(
          center: c + const Offset(0, 0.8),
          width: w,
          height: w * 0.45,
        ),
        rim,
      );
      canvas.drawOval(
        Rect.fromCenter(center: c, width: w, height: w * 0.42),
        face,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: c + Offset(-w * 0.15, -w * 0.06),
          width: w * 0.4,
          height: w * 0.12,
        ),
        shine,
      );
    }
    canvas.restore();
    // Chuôi kiếm cắm nghiêng: lưỡi, chắn tay, cán quấn da, núm.
    canvas.save();
    canvas.translate(286, 206);
    canvas.rotate(-0.35);
    shadedPath(
      canvas,
      Path()..addRect(const Rect.fromLTWH(-1.6, -4, 3.2, 10)),
      const Color(0xFFCFD8DC),
      PartFrame.world,
      shadow: 1,
      highlight: 0.5,
      outlineWidth: 1,
    );
    shadedPath(
      canvas,
      Path()..addRRect(
        RRect.fromLTRBR(-8, -6.5, 8, -4, const Radius.circular(1.2)),
      ),
      FafnirColors.gold,
      PartFrame.world,
      shadow: 1,
      highlight: 0.5,
      outlineWidth: 1,
    );
    shadedPath(
      canvas,
      Path()..addRect(const Rect.fromLTWH(-1.8, -17, 3.6, 10.5)),
      const Color(0xFF5A3A22),
      PartFrame.world,
      shadow: 1,
      highlight: 0.4,
      outlineWidth: 1,
    );
    shadedPath(
      canvas,
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(0, -18.5), radius: 2.6)),
      FafnirColors.gold,
      PartFrame.world,
      shadow: 0.8,
      highlight: 0.5,
      outlineWidth: 1,
    );
    canvas.restore();
    // Chén vàng nằm nghiêng.
    canvas.save();
    canvas.translate(374, 199);
    canvas.rotate(0.5);
    final cup = Path()
      ..moveTo(-6, -7)
      ..quadraticBezierTo(-6, 2, 0, 3)
      ..quadraticBezierTo(6, 2, 6, -7)
      ..close()
      ..addRect(const Rect.fromLTWH(-1, 3, 2, 4))
      ..addOval(
        Rect.fromCenter(center: const Offset(0, 7.5), width: 8, height: 2.4),
      );
    shadedPath(
      canvas,
      cup,
      FafnirColors.gold,
      PartFrame.world,
      shadow: 1.5,
      highlight: 0.8,
      outlineWidth: 1.1,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -7), width: 12, height: 3),
      fillPaint(const Color(0xFF7A4E0E)),
    );
    canvas.restore();
    // Mũ trụ Bắc Âu (mũ tròn có che mũi) lăn bên chân đống vàng.
    canvas.save();
    canvas.translate(398, 224);
    canvas.rotate(-0.3);
    final helm = Path()
      ..moveTo(-8, 3)
      ..cubicTo(-8, -8, 8, -8, 8, 3)
      ..close();
    shadedPath(
      canvas,
      helm,
      const Color(0xFF8D9AA3),
      PartFrame.world,
      shadow: 2,
      highlight: 1,
      outlineWidth: 1.2,
    );
    canvas.drawRect(
      const Rect.fromLTWH(-1.2, -1, 2.4, 7),
      fillPaint(const Color(0xFF6E7A82)),
    );
    canvas.drawLine(
      const Offset(-8, 1.5),
      const Offset(8, 1.5),
      Paint()
        ..color = const Color(0xFF5E6870)
        ..strokeWidth = 1.4,
    );
    canvas.restore();
  }

  void _wing(Canvas canvas, BossFrame f, double breathe) {
    // Đập cánh khi phun băng: xoay cả cánh (ảnh chụp sẵn) quanh vai.
    canvas.save();
    canvas.translate(_shoulder.dx, _shoulder.dy);
    canvas.rotate(-0.12 * f.attack + math.sin(f.time * 1.5) * 0.015);
    canvas.translate(-_shoulder.dx, -_shoulder.dy);
    _wingImage.paint(canvas);
    canvas.restore();
  }

  /// Cánh dơi thật: xương cánh tay tới khớp cổ tay, 4 xương ngón toả ra,
  /// màng căng giữa các ngón, mép sau lõm cong (võng giữa hai ngón), gân
  /// màng mảnh, màng tối dần về phía thân; móng nhỏ ở khớp cổ tay.
  static void _paintWing(Canvas canvas) {
    const wrist = Offset(360, 86);
    const tips = [
      Offset(350, 52),
      Offset(376, 58),
      Offset(400, 80),
      Offset(416, 112),
    ];
    const root = Offset(404, 150);
    final membrane = Path()
      ..moveTo(_shoulder.dx, _shoulder.dy)
      ..lineTo(wrist.dx, wrist.dy)
      ..lineTo(tips[0].dx, tips[0].dy);
    for (var i = 1; i < tips.length; i++) {
      final a = tips[i - 1], b = tips[i];
      final mid = Offset.lerp(a, b, 0.5)!;
      final inward = (wrist - mid) * 0.32;
      membrane.quadraticBezierTo(
        mid.dx + inward.dx,
        mid.dy + inward.dy,
        b.dx,
        b.dy,
      );
    }
    final lastMid = Offset.lerp(tips.last, root, 0.5)!;
    final lastIn = (wrist - lastMid) * 0.28;
    membrane
      ..quadraticBezierTo(
        lastMid.dx + lastIn.dx,
        lastMid.dy + lastIn.dy,
        root.dx,
        root.dy,
      )
      ..close();
    shadedPath(
      canvas,
      membrane,
      FafnirColors.wing,
      PartFrame.world,
      shadow: 4,
      highlight: 1.4,
    );
    canvas.save();
    canvas.clipPath(membrane);
    // Màng tối dần về phía thân (dày hơn, khuất sáng).
    canvas.drawPath(
      membrane,
      Paint()
        ..shader = Gradient.radial(_shoulder, 90, [
          darken(FafnirColors.wing, 0.35).withValues(alpha: 0.7),
          darken(FafnirColors.wing, 0.35).withValues(alpha: 0),
        ]),
    );
    // Gân màng: nét mảnh cong giữa các ngón.
    final vein = Paint()
      ..color = darken(FafnirColors.wing, 0.3).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    for (var i = 0; i < tips.length; i++) {
      final b = i + 1 < tips.length ? tips[i + 1] : root;
      final mid = Offset.lerp(tips[i], b, 0.5)!;
      for (final k in const [0.35, 0.65]) {
        final from = Offset.lerp(wrist, mid, 0.2)!;
        final to = Offset.lerp(wrist, mid, 0.95)!;
        final ctrl =
            Offset.lerp(from, to, 0.5)! + (tips[i] - mid) * (k - 0.5) * 0.6;
        canvas.drawPath(
          Path()
            ..moveTo(from.dx, from.dy)
            ..quadraticBezierTo(ctrl.dx, ctrl.dy, to.dx, to.dy),
          vein,
        );
      }
    }
    canvas.restore();
    // Xương: cánh tay + các ngón (thon dần), khớp nổi.
    final bone = darken(FafnirColors.wing, 0.42);
    shadedPath(
      canvas,
      taperedStroke(
        [
          _shoulder,
          Offset.lerp(_shoulder, wrist, 0.5)! + const Offset(-3, 0),
          wrist,
        ],
        5,
        peak: 0.3,
        startWidth: 0.9,
        endWidth: 0.6,
      ),
      bone,
      PartFrame.world,
      shadow: 1.2,
      highlight: 0.6,
      outlineWidth: 1.1,
    );
    for (final t in tips) {
      shadedPath(
        canvas,
        taperedStroke(
          [wrist, Offset.lerp(wrist, t, 0.5)! + const Offset(1, -1), t],
          3,
          peak: 0.1,
          startWidth: 1,
          endWidth: 0.15,
        ),
        bone,
        PartFrame.world,
        shadow: 0.8,
        highlight: 0.4,
        outlineWidth: 1,
      );
    }
    shadedPath(
      canvas,
      Path()..addOval(Rect.fromCircle(center: wrist, radius: 3.2)),
      bone,
      PartFrame.world,
      shadow: 1,
      highlight: 0.6,
      outlineWidth: 1,
    );
    // Móng ở khớp cổ tay.
    shadedPath(
      canvas,
      taperedStroke(
        [
          wrist + const Offset(-1, -2),
          wrist + const Offset(-6, -7),
          wrist + const Offset(-6, -11),
        ],
        2.2,
        peak: 0.1,
        startWidth: 1,
      ),
      FafnirColors.horn,
      PartFrame.world,
      shadow: 0.6,
      highlight: 0,
      outlineWidth: 0.9,
    );
  }

  void _tail(Canvas canvas, BossFrame f) {
    final sway = math.sin(f.time * 1.2) * 6;
    final pts = [
      const Offset(376, 188),
      Offset(406, 178 + sway * 0.5),
      Offset(412, 152 + sway),
      Offset(402, 136 + sway),
    ];
    shadedPath(
      canvas,
      taperedStroke(
        pts,
        13,
        peak: 0,
        startWidth: 1,
        endWidth: 0.25,
        samples: 14,
      ),
      FafnirColors.body,
      PartFrame.world,
      shadow: 2.5,
      highlight: 1,
      outlineWidth: 1.6,
    );
    // Mũi đuôi hình mũi giáo.
    final tip = pts.last;
    final dir = (tip - pts[2]) / (tip - pts[2]).distance;
    final n = Offset(-dir.dy, dir.dx);
    shadedPath(
      canvas,
      Path()
        ..moveTo(tip.dx - n.dx * 5, tip.dy - n.dy * 5)
        ..lineTo(tip.dx + dir.dx * 11, tip.dy + dir.dy * 11)
        ..lineTo(tip.dx + n.dx * 5, tip.dy + n.dy * 5)
        ..lineTo(tip.dx - dir.dx * 2, tip.dy - dir.dy * 2)
        ..close(),
      FafnirColors.horn,
      PartFrame.world,
      shadow: 1,
      highlight: 0.5,
      outlineWidth: 1.1,
    );
  }

  void _body(Canvas canvas, double breathe) {
    canvas.save();
    canvas.translate(0, -breathe * 0.6);
    _bodyImage.paint(canvas);
    canvas.restore();
  }

  /// Thân rồng-rắn (lindworm) phủ vảy cuộn trên đống vàng, bụng nhạt chia
  /// đốt, hàng gai sừng dọc sống lưng có sương giá đóng ở ngọn, chân trước
  /// bám vàng bằng vuốt.
  static void _paintBody(Canvas canvas) {
    const spinePts = [
      Offset(298, 210),
      Offset(302, 178),
      Offset(326, 156),
      Offset(356, 152),
      Offset(382, 166),
      Offset(390, 200),
    ];
    // Khối thân đặc dưới vòm lưng (không để thân thành vòm rỗng).
    final mass = smoothPath([
      const Offset(296, 216),
      ...spinePts.sublist(1, 5).map((p) => p + const Offset(0, 6)),
      const Offset(394, 216),
    ], tension: 0.1)..close();
    shadedPath(
      canvas,
      mass,
      darken(FafnirColors.body, 0.12),
      PartFrame.world,
      shadow: 6,
      highlight: 1,
    );
    final b = buildScaleBody(
      spinePts,
      40,
      startWidth: 0.9,
      endWidth: 0.7,
      rows: 3,
      belly: false,
    );
    shadedPath(
      canvas,
      b.body,
      FafnirColors.body,
      PartFrame.world,
      shadow: 5,
      highlight: 1.8,
    );
    canvas.save();
    canvas.clipPath(b.body);
    canvas.drawPath(
      b.scaleDark,
      Paint()
        ..color = darken(FafnirColors.body, 0.38).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawPath(
      b.scaleLit,
      Paint()
        ..color = lighten(FafnirColors.body, 0.35).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    canvas.drawPath(
      b.spine,
      fillPaint(darken(FafnirColors.body, 0.3).withValues(alpha: 0.8)),
    );
    canvas.restore();
    // Ngực trước: các đốt vảy bụng nhạt xếp chồng (nối dải bụng của cổ).
    for (var i = 0; i < 6; i++) {
      final y = 168.0 + i * 7.4;
      final x = 304.0 - i * 0.8;
      final plate = Path()
        ..addRRect(
          RRect.fromLTRBR(x - 7, y, x + 7, y + 6.6, const Radius.circular(3)),
        );
      shadedPath(
        canvas,
        plate,
        FafnirColors.belly,
        PartFrame.world,
        shadow: 1.2,
        highlight: 0.6,
        outlineWidth: 1,
      );
    }
    // Gai sừng dọc sống lưng, ngọn đóng sương giá.
    final line = sampleSmooth(spinePts, 40);
    for (var i = 9; i < 34; i += 3) {
      final d = line[i + 1] - line[i - 1];
      var n = Offset(-d.dy, d.dx) / d.distance;
      if (n.dy > 0) n = -n;
      final base = line[i] + n * 15;
      final h = 9 + 4 * math.sin((i - 9) / 25 * math.pi);
      final tip = base + n * h + const Offset(4, 0);
      shadedPath(
        canvas,
        taperedStroke(
          [base - n * 3, Offset.lerp(base, tip, 0.5)!, tip],
          6,
          peak: 0.1,
          startWidth: 1,
        ),
        FafnirColors.horn,
        PartFrame.world,
        shadow: 1,
        highlight: 0.3,
        outlineWidth: 1.1,
      );
      canvas.drawPath(
        taperedStroke(
          [Offset.lerp(base, tip, 0.55)!, tip],
          2.6,
          peak: 0.1,
          startWidth: 1,
        ),
        fillPaint(FafnirColors.snow),
      );
    }
    // Sương giá bám trên lưng: cụm tinh thể nhỏ.
    final frost = fillPaint(FafnirColors.frost.withValues(alpha: 0.75));
    final rnd = math.Random(8);
    for (var i = 0; i < 26; i++) {
      final p =
          line[8 + rnd.nextInt(26)] +
          Offset(rnd.nextDouble() * 4 - 2, -9 - rnd.nextDouble() * 5);
      canvas.drawCircle(p, 0.6 + rnd.nextDouble() * 0.9, frost);
    }
    // Chân trước: bắp to, cẳng thon, vuốt bám vàng.
    shadedPath(
      canvas,
      taperedStroke(
        const [Offset(314, 182), Offset(304, 200), Offset(296, 212)],
        12,
        peak: 0.2,
        startWidth: 1,
        endWidth: 0.5,
      ),
      FafnirColors.body,
      PartFrame.world,
      shadow: 2,
      highlight: 1,
      outlineWidth: 1.4,
    );
    for (final dx in [-7.0, -2.0, 3.0]) {
      shadedPath(
        canvas,
        taperedStroke(
          [Offset(294 + dx, 211), Offset(290 + dx, 215), Offset(291 + dx, 219)],
          2.4,
          peak: 0.1,
          startWidth: 1,
        ),
        FafnirColors.horn,
        PartFrame.world,
        shadow: 0.6,
        highlight: 0,
        outlineWidth: 0.9,
      );
    }
  }

  void _neckAndHead(Canvas canvas, BossFrame f, double breathe) {
    final rear = 8 * f.attack;
    final head = Offset(292, 104 - rear + breathe);
    // Cổ cong chữ S, thon dần lên đầu; dải bụng nhạt ở mặt dưới.
    final pts = [
      const Offset(330, 162),
      const Offset(338, 136),
      Offset(310, 122 - rear * 0.5),
      head + const Offset(10, 2),
    ];
    shadedPath(
      canvas,
      taperedStroke(
        pts,
        20,
        peak: 0,
        startWidth: 1,
        endWidth: 0.6,
        samples: 14,
      ),
      FafnirColors.body,
      PartFrame.world,
      shadow: 3,
      highlight: 1.3,
      outlineWidth: 1.6,
    );
    canvas.drawPath(
      taperedStroke(
        offsetLine(pts, -5.5, taper: 0.4),
        6.5,
        peak: 0,
        startWidth: 1,
        endWidth: 0.6,
        samples: 14,
      ),
      fillPaint(FafnirColors.belly),
    );
    canvas.drawPath(
      taperedStroke(
        offsetLine(pts, 5.5, taper: 0.4),
        3.2,
        peak: 0,
        startWidth: 1,
        endWidth: 0.4,
        samples: 14,
      ),
      fillPaint(darken(FafnirColors.body, 0.3)),
    );

    canvas.save();
    canvas.translate(head.dx, head.dy);
    // Sừng cong vuốt ra sau, diềm gai sau má.
    for (final (pts, w) in const [
      ([Offset(4, -9), Offset(14, -18), Offset(27, -17)], 4.0),
      ([Offset(9, -7), Offset(18, -11), Offset(28, -8)], 3.0),
    ]) {
      shadedPath(
        canvas,
        taperedStroke(pts, w, peak: 0.1, startWidth: 1),
        FafnirColors.horn,
        PartFrame.world,
        shadow: 1.2,
        highlight: 0.5,
        outlineWidth: 1.2,
      );
    }
    for (final (pts, w) in const [
      ([Offset(10, 2), Offset(17, 5), Offset(23, 4)], 3.0),
      ([Offset(9, -1), Offset(16, 0), Offset(22, -2)], 2.6),
    ]) {
      shadedPath(
        canvas,
        taperedStroke(pts, w, peak: 0.1, startWidth: 1),
        darken(FafnirColors.wing, 0.1),
        PartFrame.world,
        shadow: 0.8,
        highlight: 0.4,
        outlineWidth: 1,
      );
    }
    // Hàm dưới mở khi phun băng.
    canvas.save();
    canvas.rotate(-0.45 * f.attack);
    shadedPath(
      canvas,
      Path()
        ..moveTo(8, 2)
        ..quadraticBezierTo(-12, 10, -30, 6)
        ..lineTo(-28, 2)
        ..close(),
      FafnirColors.belly,
      PartFrame.world,
      shadow: 1.5,
      highlight: 0.6,
      outlineWidth: 1.4,
    );
    if (f.attack > 0.1) {
      for (final x in [-24.0, -16.0, -8.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(x, 3)
            ..lineTo(x + 2.6, 3)
            ..lineTo(x + 1.3, -2)
            ..close(),
          fillPaint(const Color(0xFFF5F9FF)),
        );
      }
    }
    canvas.restore();
    // Sọ rồng dài, mõm hướng về người chơi, gờ mày nặng.
    final skull = smoothPath(
      const [
        Offset(-33, -1),
        Offset(-29, -6),
        Offset(-18, -9),
        Offset(-10, -13),
        Offset(2, -13.5),
        Offset(12, -9),
        Offset(16, -2),
        Offset(13, 4),
        Offset(0, 5),
        Offset(-16, 3.6),
        Offset(-31, 3),
      ],
      closed: true,
      tension: 0.1,
    );
    shadedPath(
      canvas,
      skull,
      FafnirColors.body,
      PartFrame.world,
      shadow: 3,
      highlight: 1.4,
    );
    canvas.save();
    canvas.clipPath(skull);
    final plate = Paint()
      ..color = darken(FafnirColors.body, 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var i = 0; i < 7; i++) {
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(10 - i * 4.4, -9 + i * 0.7),
          radius: 2.5,
        ),
        0.2,
        2.6,
        false,
        plate,
      );
    }
    canvas.drawPath(
      taperedStroke(
        const [
          Offset(-32, 1),
          Offset(-14, 2.8),
          Offset(4, 3.2),
          Offset(14, 1.5),
        ],
        2.8,
        peak: 0.3,
        startWidth: 0.6,
      ),
      fillPaint(FafnirColors.belly),
    );
    canvas.restore();
    // Lỗ mũi bốc hơi lạnh.
    canvas.drawOval(
      const Rect.fromLTWH(-31, -4.4, 2.6, 1.4),
      fillPaint(VectorStyle.outline),
    );
    final puff = (f.time * 0.9) % 1;
    canvas.drawCircle(
      Offset(-36 - 8 * puff, -6 - 6 * puff),
      2 + 4 * puff,
      fillPaint(FafnirColors.snow.withValues(alpha: 0.5 * (1 - puff))),
    );
    // Mắt xanh lạnh phát sáng (gradient, không blur), gờ mày sụp.
    const eye = Offset(-9, -7);
    canvas.drawCircle(
      eye,
      8,
      Paint()
        ..shader = Gradient.radial(eye, 8, [
          FafnirColors.eye.withValues(alpha: 0.7),
          FafnirColors.eye.withValues(alpha: 0),
        ]),
    );
    canvas.drawOval(
      Rect.fromCenter(center: eye, width: 7, height: 4),
      fillPaint(FafnirColors.eye),
    );
    canvas.drawOval(
      Rect.fromCenter(center: eye, width: 1.6, height: 4),
      fillPaint(VectorStyle.outline),
    );
    shadedPath(
      canvas,
      Path()
        ..moveTo(-16, -7)
        ..quadraticBezierTo(-9, -14, -1, -11.5)
        ..lineTo(-2.5, -8.2)
        ..quadraticBezierTo(-9, -9.4, -16, -7)
        ..close(),
      darken(FafnirColors.body, 0.2),
      PartFrame.world,
      shadow: 0.8,
      highlight: 0.6,
      outlineWidth: 1,
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
        ]),
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
