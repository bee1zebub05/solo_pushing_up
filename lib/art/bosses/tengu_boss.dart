import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../battle_stage.dart';
import '../motion.dart';
import '../nemea_scene.dart' show stageGroundY, stageSize;
import '../vector_style.dart';
import 'japan_sprite_boss.dart';

/// Bảng màu Sutoku hoá đại tengu (tengu_boss.py, model Tripo): mặt đỏ mũi
/// dài, tóc xám bù, kimono lục hoa tròn vàng, hakama lam, đai lam nhạt, cánh
/// đại bàng nâu, quạt lông sẫm.
abstract final class TenguColors {
  static const skin = Color(0xFFC8442E);
  static const kimono = Color(0xFF3E8A5A);
  static const collar = Color(0xFFD8E8D0);
  static const hakama = Color(0xFF2E5E86);
  static const sash = Color(0xFF9CC8C8);
  static const mon = Color(0xFFD8B060);
  static const hair = Color(0xFF7A7878);
  static const feather = Color(0xFF6A4A2A);
  static const featherLight = Color(0xFFB08A58);
  static const fan = Color(0xFF241C1A);
  static const gold = Color(0xFFD8A848);
}

/// Thiên hoàng Sutoku hoá đại tengu (chương Nhật, kỳ công Heian — chưa xếp
/// màn; id hình `tengu_sutoku`). Đòn: giơ quạt lông hauchiwa cao sau đầu,
/// cánh dựng xoè (lấy đà) → quạt quất tới, cánh đập (ra đòn), luồng gió xoáy
/// cuốn lá phong bay về phía người chơi.
class TenguBossArt extends JapanSpriteBoss {
  @override
  String get spriteName => 'tengu_sutoku';

  @override
  Offset get feet => const Offset(316, stageGroundY);

  @override
  double get shadowWidth => 110;

  @override
  Vector2 get target => Vector2(feet.dx - 6, feet.dy - 108);

  @override
  Vector2 get portraitFocus => Vector2(feet.dx - 10, feet.dy - 134);

  @override
  double get portraitView => 110;

  @override
  Color get gradeLight => const Color(0xFFF2D4DA);

  @override
  Color get mistColor => const Color(0xA8604070);

  @override
  List<Color> get hitColors => const [
    Color(0xFFB08A58),
    Color(0xFFFFE082),
    Color(0xFFFFFFFF),
  ];

  // ------------------------------------------------------- nền: Shiramine
  @override
  void paintBackdrop(Canvas canvas) {
    final w = stageSize.width;
    canvas.drawRect(
      Offset.zero & stageSize,
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          const Offset(0, 200),
          const [Color(0xFF241A34), Color(0xFF5A3656), Color(0xFFC0646A)],
          const [0, 0.55, 1],
        ),
    );
    // Mây giông cuộn khối, mép dưới hắt đỏ hoàng hôn.
    final rnd = math.Random(14);
    for (var i = 0; i < 9; i++) {
      final c = Offset(i * 50.0 + rnd.nextDouble() * 20, 28 + rnd.nextDouble() * 40);
      final r = 22 + rnd.nextDouble() * 18;
      for (var k = 0; k < 4; k++) {
        final p = c + Offset((k - 1.5) * r * 0.6, (k.isEven ? 0 : -r * 0.25));
        canvas.drawCircle(p.translate(0, 3), r * 0.62, fillPaint(const Color(0x66E07070)));
        canvas.drawCircle(p, r * 0.62, fillPaint(const Color(0xFF2C2038)));
      }
    }
    for (final (x, y, len, t) in const [
      (20.0, 96.0, 140.0, 6.0),
      (200.0, 108.0, 170.0, 7.0),
    ]) {
      canvas.drawPath(cloudBand(Offset(x, y), len, t), fillPaint(const Color(0xFF3A2440)));
    }
    // Núi xa nhiều lớp, sương đỏ giữa các lớp.
    for (final (base, amp, color, phase) in [
      (158.0, 30.0, const Color(0xFF4A2C4A), 1.2),
      (182.0, 22.0, const Color(0xFF33203A), 3.3),
    ]) {
      final path = Path()..moveTo(0, 260);
      for (var x = 0.0; x <= w; x += 8) {
        path.lineTo(
          x,
          base - amp * (0.5 + 0.5 * math.sin(x / 41 + phase)) - 6 * math.sin(x / 9 + phase).abs(),
        );
      }
      path
        ..lineTo(w, 260)
        ..close();
      canvas.drawPath(path, fillPaint(color));
      canvas.drawRect(
        Rect.fromLTRB(0, base - 2, w, base + 12),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, base - 2),
            Offset(0, base + 12),
            const [Color(0x00F08080), Color(0x44F09080), Color(0x00F08080)],
            const [0, 0.5, 1],
          ),
      );
    }
    paintGround(
      canvas,
      const Color(0xFF4A3C46),
      const Color(0xFF221A22),
      const Color(0x88F0A090),
    );
    // Giữa người chơi và boss (sau lưng nhân vật thì bị che khuất).
    _pine(canvas, const Offset(236, stageGroundY - 2));
    _lantern(canvas, const Offset(212, stageGroundY + 1));
    // Đá lát vỡ, lá phong rụng.
    final stones = math.Random(31);
    for (var i = 0; i < 24; i++) {
      final c = Offset(stones.nextDouble() * w, stageGroundY + 5 + stones.nextDouble() * 32);
      final s = 2.4 + stones.nextDouble() * 3.6;
      final r = Rect.fromCenter(center: c, width: s * 1.8, height: s * 0.7);
      canvas.drawOval(r.shift(const Offset(0.5, 0.7)), fillPaint(const Color(0x66140C14)));
      canvas.drawOval(r, fillPaint(const Color(0xFF5A4C56)));
    }
    for (var i = 0; i < 18; i++) {
      final c = Offset(stones.nextDouble() * w, stageGroundY + 3 + stones.nextDouble() * 34);
      _leaf(canvas, c, stones.nextDouble() * math.pi, 2.2, const Color(0xFFB0382A));
    }
  }

  /// Cây thông già (matsu) trên mỏm đá: thân xoắn ngả, tán dẹt từng tầng.
  static void _pine(Canvas canvas, Offset base) {
    final rock = Path()
      ..moveTo(base.dx - 26, base.dy + 2)
      ..quadraticBezierTo(base.dx - 20, base.dy - 14, base.dx - 2, base.dy - 16)
      ..quadraticBezierTo(base.dx + 18, base.dy - 12, base.dx + 24, base.dy + 2)
      ..close();
    shadedPath(canvas, rock, const Color(0xFF5A4A58), PartFrame.world, shadow: 3, highlight: 1, outlineWidth: 1.2);
    final trunkLine = [
      base.translate(-2, -14),
      base.translate(-14, -44),
      base.translate(4, -76),
      base.translate(-10, -104),
    ];
    final trunk = taperedStroke(trunkLine, 9, peak: 0, startWidth: 1, endWidth: 0.4);
    shadedPath(canvas, trunk, const Color(0xFF4A3028), PartFrame.world, shadow: 2.5, highlight: 0.8, outlineWidth: 1.2);
    final branch = taperedStroke([base.translate(-10, -58), base.translate(-40, -64), base.translate(-62, -58)], 5, peak: 0, startWidth: 1, endWidth: 0.3);
    shadedPath(canvas, branch, const Color(0xFF4A3028), PartFrame.world, shadow: 2, highlight: 0.6, outlineWidth: 1.1);
    for (final (c, rw, rh) in [
      (base.translate(-62, -64), 32.0, 9.0),
      (base.translate(-12, -108), 40.0, 11.0),
      (base.translate(8, -82), 34.0, 9.0),
      (base.translate(-34, -72), 26.0, 8.0),
    ]) {
      final crown = Path()..addOval(Rect.fromCenter(center: c, width: rw, height: rh));
      shadedPath(canvas, crown, const Color(0xFF243A30), PartFrame.world, shadow: 3, highlight: 1.2, outlineWidth: 1.1);
      final needle = Paint()
        ..color = const Color(0x6688B098)
        ..strokeWidth = 0.6;
      for (var k = 0; k < 7; k++) {
        final x = c.dx - rw * 0.4 + rw * 0.8 * k / 6;
        canvas.drawLine(Offset(x, c.dy - rh * 0.3), Offset(x - 1.5, c.dy - rh * 0.05), needle);
      }
    }
  }

  /// Đèn đá (tōrō) rêu phong — lăng mộ Shiramine.
  static void _lantern(Canvas canvas, Offset base) {
    for (final (rect, color) in [
      (Rect.fromLTWH(base.dx - 7, base.dy - 4, 14, 4), const Color(0xFF6A6068)),
      (Rect.fromLTWH(base.dx - 2.5, base.dy - 22, 5, 18), const Color(0xFF6A6068)),
      (Rect.fromLTWH(base.dx - 6, base.dy - 30, 12, 8), const Color(0xFF746A72)),
    ]) {
      shadedPath(canvas, Path()..addRect(rect), color, PartFrame.world, shadow: 1.5, highlight: 0.6, outlineWidth: 1);
    }
    canvas.drawRect(Rect.fromLTWH(base.dx - 2.5, base.dy - 28, 5, 4), fillPaint(const Color(0xFFFFB060)));
    final roof = Path()
      ..moveTo(base.dx - 11, base.dy - 30)
      ..quadraticBezierTo(base.dx, base.dy - 40, base.dx + 11, base.dy - 30)
      ..close();
    shadedPath(canvas, roof, const Color(0xFF5A5058), PartFrame.world, shadow: 1.5, highlight: 0.6, outlineWidth: 1);
  }

  static void _leaf(Canvas canvas, Offset c, double a, double s, Color color) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(a);
    final leaf = Path();
    for (var k = 0; k < 5; k++) {
      final ang = -math.pi / 2 + (k - 2) * 0.6;
      final tip = Offset(math.cos(ang), math.sin(ang)) * s * (k == 2 ? 1.4 : 1.1);
      leaf
        ..moveTo(0, 0)
        ..lineTo(tip.dx + math.cos(ang + 1.3) * s * 0.35, tip.dy + math.sin(ang + 1.3) * s * 0.35)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(tip.dx + math.cos(ang - 1.3) * s * 0.35, tip.dy + math.sin(ang - 1.3) * s * 0.35)
        ..close();
    }
    canvas.drawPath(leaf, fillPaint(color));
    canvas.restore();
  }

  @override
  void paintAmbient(Canvas canvas, double time) {
    // Chớp giông xa: loé ngắn mỗi ~7 giây, tia sét gãy khúc sau mây.
    final cycle = time % 7.3;
    if (cycle < 0.35) {
      final a = (cycle < 0.1 ? cycle / 0.1 : 1 - (cycle - 0.1) / 0.25).clamp(0.0, 1.0);
      canvas.drawRect(
        const Rect.fromLTRB(0, 0, 400, 200),
        fillPaint(Color.fromRGBO(240, 220, 255, 0.18 * a)),
      );
      final bolt = Path()..moveTo(262, 40);
      for (final p in const [
        Offset(254, 70),
        Offset(266, 92),
        Offset(250, 122),
        Offset(258, 140),
      ]) {
        bolt.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        bolt,
        Paint()
          ..color = Color.fromRGBO(250, 240, 255, 0.9 * a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
    // Lá phong đỏ bay theo gió từ phải sang trái.
    for (var i = 0; i < 9; i++) {
      final ph = (time * (0.07 + (i % 3) * 0.02) + i / 9) % 1;
      final x = 420 - ph * 460;
      final y = 60 + (i * 23) % 140 + math.sin(time * 2 + i) * 8;
      _leaf(canvas, Offset(x, y), time * 3 + i, 2, const Color(0xCCC0402A));
    }
  }

  // ------------------------------------------------------------ boss (2.5D)
  /// Thân tĩnh (chân, hakama, kimono, tay trái, đầu) ghi một lần.
  Picture? _body;

  @override
  void dispose() {
    _body?.dispose();
    _body = null;
    super.dispose();
  }

  static const _shoulder = Offset(-18, -124);

  @override
  void paintVector(Canvas canvas, BossFrame f, AttackPose p) {
    final d = f.defeat.clamp(0.0, 1.0);
    final breath = math.sin(f.time * 2 * math.pi / 3.2);
    // Cánh: + = dựng lên. Lấy đà dựng xoè, ra đòn đập xuống, gục rũ cụp.
    final raise = 26 * p.windup - 34 * p.strike - 50 * d + 3 * breath;
    _wing(canvas, const Offset(-4, -122), -1, raise, 0.86);
    _wing(canvas, const Offset(10, -124), 1, raise, 1);
    canvas.drawPicture(_body ??= _record(_paintBody));
    // Chờ: quạt dựng ở ngang hông phía trước (cao hơn thì che mặt).
    final handAng = phaseLerp(125, 285, 175, 100, p, d);
    final handR = phaseLerp(34, 40, 38, 32, p, d);
    final fanAng = phaseLerp(-80, 10, -160, 60, p, d);
    _fanArm(canvas, handAng, handR, fanAng);
  }

  static Picture _record(void Function(Canvas) draw) {
    final r = PictureRecorder();
    draw(Canvas(r));
    return r.endRecording();
  }

  /// Cánh đại bàng dựng theo khung cục bộ (gốc ở vai, cánh vươn ra +x):
  /// xương cánh → lông bay sơ cấp xoè từ cổ tay → lông thứ cấp rủ dọc cánh →
  /// lông phủ xếp vảy. [side] −1 = cánh xa (bên trái màn hình, nhỏ hơn).
  static void _wing(Canvas canvas, Offset root, double side, double raise, double size) {
    canvas.save();
    canvas.translate(root.dx, root.dy);
    canvas.scale(side * size, size);
    canvas.rotate((-28 - raise) * math.pi / 180);
    const frame = PartFrame.world;
    // Lông bay sơ cấp từ cổ tay xoè xuống.
    for (var i = 6; i >= 0; i--) {
      final a = (8 + i * 13) * math.pi / 180;
      final base = Offset(40 + i * 1.5, -4 + i * 1.2);
      final tip = base + Offset(math.cos(a), math.sin(a)) * (44 - i * 2.6);
      final feather = taperedStroke([base, Offset.lerp(base, tip, 0.5)! + const Offset(0, -2), tip], 8, peak: 0.35, startWidth: 0.7, endWidth: 0.15);
      shadedPath(canvas, feather, i.isEven ? TenguColors.feather : darken(TenguColors.feather, 0.1), frame, shadow: 1.6, highlight: 0.6, outlineWidth: 0.9);
      canvas.drawLine(base, Offset.lerp(base, tip, 0.85)!, Paint()..color = TenguColors.featherLight..strokeWidth = 0.5);
    }
    // Lông thứ cấp rủ dọc cánh tay.
    for (var i = 7; i >= 0; i--) {
      final base = Offset(4 + i * 4.8, -2 + i * -0.4);
      final tip = base + Offset(-4 + i * 1.2, 30 - i * 0.6);
      final feather = taperedStroke([base, tip], 8, peak: 0.4, startWidth: 0.8, endWidth: 0.3);
      shadedPath(canvas, feather, i.isEven ? TenguColors.feather : lighten(TenguColors.feather, 0.08), frame, shadow: 1.4, highlight: 0.5, outlineWidth: 0.9);
    }
    // Xương cánh + lông phủ vảy sáng hơn.
    final arm = Path()
      ..moveTo(-2, 4)
      ..quadraticBezierTo(18, -14, 44, -6)
      ..lineTo(46, 2)
      ..quadraticBezierTo(22, 12, -2, 12)
      ..close();
    shadedPath(canvas, arm, TenguColors.featherLight, frame, shadow: 2, highlight: 0.8, outlineWidth: 1);
    final scale = Paint()
      ..color = darken(TenguColors.featherLight, 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    for (var row = 0; row < 2; row++) {
      for (var k = 0; k < 7; k++) {
        final c = Offset(4 + k * 5.6 + row * 2.8, -2 + row * 5 + k * -0.2);
        canvas.drawArc(Rect.fromCircle(center: c, radius: 2.6), 0.2, math.pi - 0.4, false, scale);
      }
    }
    canvas.restore();
  }

  void _paintBody(Canvas canvas) {
    // Cẳng chân + bàn chân trần đỏ.
    for (final (top, foot) in const [
      (Offset(-12, -34), Offset(-15, -3)),
      (Offset(13, -34), Offset(15, -3)),
    ]) {
      final leg = capsulePath(top, foot, 5.6, 4.2);
      shadedPath(canvas, leg, TenguColors.skin, PartFrame.world, shadow: 2, highlight: 0.8, outlineWidth: 1.1);
      final f = Path()
        ..moveTo(foot.dx + 4, foot.dy - 2)
        ..quadraticBezierTo(foot.dx - 4, foot.dy - 4, foot.dx - 10, foot.dy + 1)
        ..lineTo(foot.dx + 5, foot.dy + 3)
        ..close();
      shadedPath(canvas, f, TenguColors.skin, PartFrame.world, shadow: 1.5, highlight: 0.6, outlineWidth: 1);
    }
    // Hakama lam phồng, bó ống ở bắp chân.
    final hakama = Path()
      ..moveTo(-24, -66)
      ..quadraticBezierTo(-34, -48, -20, -30)
      ..lineTo(-6, -32)
      ..lineTo(0, -46)
      ..lineTo(6, -32)
      ..lineTo(22, -30)
      ..quadraticBezierTo(36, -48, 26, -66)
      ..close();
    shadedPath(canvas, hakama, TenguColors.hakama, PartFrame.world, shadow: 4, highlight: 1.2, outlineWidth: 1.3);
    for (final c in const [Offset(-18, -46), Offset(16, -44), Offset(-2, -58)]) {
      _mon(canvas, c, 5);
    }
    // Kimono lục: thân, vạt loe, cổ áo chữ V màu nhạt.
    final kimono = Path()
      ..moveTo(-22, -128)
      ..quadraticBezierTo(-4, -134, 22, -128)
      ..quadraticBezierTo(28, -96, 32, -58)
      ..quadraticBezierTo(2, -52, -30, -58)
      ..quadraticBezierTo(-26, -96, -22, -128)
      ..close();
    shadedPath(canvas, kimono, TenguColors.kimono, PartFrame.world, shadow: 5, highlight: 1.4, outlineWidth: 1.4);
    for (final c in const [
      Offset(-14, -112),
      Offset(12, -114),
      Offset(-20, -70),
      Offset(4, -68),
      Offset(24, -72),
    ]) {
      _mon(canvas, c, 5.4);
    }
    final collar = Path()
      ..moveTo(-14, -130)
      ..lineTo(-4, -104)
      ..lineTo(2, -104)
      ..lineTo(6, -130)
      ..lineTo(1, -130)
      ..lineTo(-1, -110)
      ..lineTo(-9, -130)
      ..close();
    canvas.drawPath(collar, fillPaint(TenguColors.collar));
    // Đai lam nhạt thắt nơ, hai dải buông.
    final sash = Path()..addRect(const Rect.fromLTRB(-26, -92, 28, -84));
    shadedPath(canvas, sash, TenguColors.sash, PartFrame.world, shadow: 1.6, highlight: 0.6, outlineWidth: 1);
    final bow = Path()
      ..addOval(Rect.fromCenter(center: const Offset(-8, -88), width: 9, height: 7))
      ..addPath(taperedStroke(const [Offset(-8, -86), Offset(-11, -76), Offset(-10, -66)], 3, peak: 0), Offset.zero)
      ..addPath(taperedStroke(const [Offset(-7, -86), Offset(-3, -76), Offset(-4, -68)], 3, peak: 0), Offset.zero);
    shadedPath(canvas, bow, TenguColors.sash, PartFrame.world, shadow: 1.2, highlight: 0.5, outlineWidth: 0.9);
    // Tay trái (phía gần): ống tay áo rộng rủ, bàn tay đỏ xoè.
    final sleeve = Path()
      ..moveTo(14, -128)
      ..quadraticBezierTo(30, -122, 34, -96)
      ..lineTo(26, -82)
      ..quadraticBezierTo(18, -96, 12, -110)
      ..close();
    shadedPath(canvas, sleeve, TenguColors.kimono, PartFrame.world, shadow: 3, highlight: 1, outlineWidth: 1.2);
    _mon(canvas, const Offset(25, -106), 4.4);
    final hand = chainPath([(const Offset(30, -90), const Offset(32, -78), 3.6, 3)]);
    shadedPath(canvas, hand, TenguColors.skin, PartFrame.world, shadow: 1.6, highlight: 0.6, outlineWidth: 1);
    _head(canvas);
  }

  /// Hoa tròn vàng (mon) trên vải.
  static void _mon(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = TenguColors.mon
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    for (var k = 0; k < 5; k++) {
      final a = k * 2 * math.pi / 5 - math.pi / 2;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r * 0.45, r * 0.28, fillPaint(TenguColors.mon));
    }
  }

  /// Đầu: mặt đỏ quay ¾ trái, mũi dài chĩa về người chơi, mày chau, tóc xám
  /// bù xù toả ra sau, búi tóc đen nhỏ.
  void _head(Canvas canvas) {
    const c = Offset(-6, -140);
    final hair = Path();
    for (var k = 0; k < 10; k++) {
      final a = -math.pi * (0.9 - 1.15 * k / 9);
      final root = c + Offset(math.cos(a), math.sin(a)) * 8 + const Offset(3, 0);
      final tip = c + Offset(math.cos(a) * 20 + 7, math.sin(a) * 15 + 6);
      hair.addPath(taperedStroke([root, Offset.lerp(root, tip, 0.5)! + const Offset(1, -2), tip], 5.5, peak: 0.2, startWidth: 1, endWidth: 0), Offset.zero);
    }
    shadedPath(canvas, hair, TenguColors.hair, PartFrame.world, shadow: 2, highlight: 0.8, outlineWidth: 1);
    final face = Path()
      ..moveTo(c.dx + 8, c.dy - 8)
      ..quadraticBezierTo(c.dx - 4, c.dy - 13, c.dx - 10, c.dy - 4)
      ..lineTo(c.dx - 11, c.dy + 4)
      ..quadraticBezierTo(c.dx - 8, c.dy + 11, c.dx, c.dy + 11)
      ..quadraticBezierTo(c.dx + 8, c.dy + 9, c.dx + 9, c.dy + 1)
      ..close();
    shadedPath(canvas, face, TenguColors.skin, PartFrame.world, shadow: 2.6, highlight: 1, outlineWidth: 1.2);
    // Mũi dài đặc trưng tengu.
    final nose = taperedStroke([c + const Offset(-8, -1), c + const Offset(-17, 1), c + const Offset(-25, 4)], 6, peak: 0, startWidth: 1, endWidth: 0.35);
    shadedPath(canvas, nose, TenguColors.skin, PartFrame.world, shadow: 1.4, highlight: 0.6, outlineWidth: 1);
    // Búi tóc đen (tokin) trên đỉnh.
    final cap = Path()..addOval(Rect.fromCenter(center: c + const Offset(1, -13), width: 9, height: 7));
    shadedPath(canvas, cap, const Color(0xFF1C1A1E), PartFrame.world, shadow: 1.2, highlight: 0.5, outlineWidth: 0.9);
    // Mắt trắng đồng tử nhỏ, mày xám chau, miệng mím trễ.
    for (final e in const [Offset(-7, -4), Offset(1, -5)]) {
      final p = c + e;
      canvas.drawOval(Rect.fromCenter(center: p, width: 4.6, height: 2.6), fillPaint(const Color(0xFFF2EEE6)));
      canvas.drawCircle(p.translate(-0.8, 0), 0.9, fillPaint(const Color(0xFF141012)));
    }
    final brow = Paint()
      ..color = const Color(0xFF3A3436)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c + const Offset(-10, -8), c + const Offset(-4, -6), brow);
    canvas.drawLine(c + const Offset(-1, -7), c + const Offset(5, -9.5), brow);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 9, c.dy + 7)
        ..quadraticBezierTo(c.dx - 5, c.dy + 5.5, c.dx - 1, c.dy + 7.5),
      Paint()
        ..color = darken(TenguColors.skin, 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  /// Tay phải (phía xa) cầm quạt hauchiwa: ống tay áo rộng, cẳng tay đỏ,
  /// quạt lông sẫm đầu vàng.
  void _fanArm(Canvas canvas, double handAng, double handR, double fanAng) {
    final hand = polar(_shoulder, handAng, handR);
    final elbow = joint2(_shoulder, hand, 20, 20, hand.dx < _shoulder.dx ? -1 : 1);
    final dir = polar(Offset.zero, fanAng, 1);
    final top = hand + dir * 11;
    // Quạt: lông xoè quanh đầu cán, cán sơn đen, nắp vàng.
    final n = Offset(-dir.dy, dir.dx);
    final fan = Path();
    for (var k = 0; k < 11; k++) {
      final a = -1.35 + 2.7 * k / 10;
      final d = dir * math.cos(a) + n * math.sin(a);
      final tip = top + d * 15;
      final side = Offset(-d.dy, d.dx) * 2.6;
      fan
        ..moveTo(top.dx, top.dy)
        ..lineTo(tip.dx + side.dx, tip.dy + side.dy)
        ..lineTo(tip.dx + d.dx * 2, tip.dy + d.dy * 2)
        ..lineTo(tip.dx - side.dx, tip.dy - side.dy)
        ..close();
    }
    shadedPath(canvas, fan, TenguColors.fan, PartFrame(math.atan2(dir.dx, -dir.dy)), shadow: 2, highlight: 1, outlineWidth: 0.9);
    canvas.drawLine(hand - dir * 3, top, Paint()..color = const Color(0xFF0C0A0C)..strokeWidth = 2.2..strokeCap = StrokeCap.round);
    canvas.drawCircle(top, 2.2, fillPaint(TenguColors.gold));
    // Ống tay áo (phần trên) + cẳng tay.
    final sleeve = Path()
      ..addPath(capsulePath(_shoulder, elbow, 8, 9), Offset.zero)
      ..addPath(capsulePath(elbow, elbow + const Offset(2, 12), 8, 6), Offset.zero);
    shadedPath(canvas, sleeve, TenguColors.kimono, PartFrame.world, shadow: 2.6, highlight: 1, outlineWidth: 1.2);
    final forearm = capsulePath(elbow, hand, 3.6, 3.2);
    shadedPath(canvas, forearm, TenguColors.skin, PartFrame.world, shadow: 1.6, highlight: 0.6, outlineWidth: 1);
    canvas.drawCircle(hand, 3.6, fillPaint(TenguColors.skin));
  }

  // ------------------------------------------------------------ đòn quạt
  /// Quạt quất: ba vòng gió lưỡi liềm cuốn lá phong bay về phía người chơi.
  @override
  void paintStrike(Canvas canvas, BossFrame f) {
    final t = phaseWindow(f.attackPhase, 0.55, 0.42);
    if (t < 0) return;
    final from = feet + const Offset(-60, -120);
    const to = Offset(120, 170);
    for (var k = 0; k < 3; k++) {
      final u = (t * 1.3 - k * 0.15).clamp(0.0, 1.0);
      if (u <= 0 || u >= 1) continue;
      final c = Offset.lerp(from, to, u)! + Offset(0, (k - 1) * 18.0);
      final r = 10 + 26 * u;
      final a = (1 - u) * 0.75;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        math.pi * 0.62,
        math.pi * 0.76,
        false,
        Paint()
          ..color = Color.fromRGBO(220, 240, 236, a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - u) + 0.8
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawArc(
        Rect.fromCircle(center: c.translate(4, 0), radius: r * 0.7),
        math.pi * 0.7,
        math.pi * 0.6,
        false,
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, a * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    for (var k = 0; k < 7; k++) {
      final u = (t * 1.2 - k * 0.05).clamp(0.0, 1.0);
      final p = Offset.lerp(from, to, u)! + Offset(math.sin(k * 2.1 + t * 9) * 14, math.cos(k * 1.7 + t * 7) * 18);
      _leaf(canvas, p, t * 12 + k, 2.4, Color.fromRGBO(200, 64, 42, 1 - u * 0.7));
    }
  }
}
