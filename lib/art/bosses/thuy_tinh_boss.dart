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
  Vector2 get portraitFocus => Vector2(320, 72);

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
    // Mây giông nặng: khối nhiều thuỳ, đáy tối phẳng, đỉnh hắt ánh xám bạc;
    // màn mưa xiên rủ từ đáy mây xuống biển.
    for (final (x, y, s) in const [
      (60.0, 30.0, 1.0),
      (210.0, 20.0, 1.35),
      (360.0, 38.0, 0.9),
    ]) {
      _stormCloud(canvas, Offset(x, y), s);
    }
    for (var i = 0; i < 4; i++) {
      final x = 250.0 + i * 38;
      canvas.drawPath(
        Path()
          ..moveTo(x, 52)
          ..lineTo(x + 26, 52)
          ..lineTo(x + 6, 170)
          ..lineTo(x - 20, 170)
          ..close(),
        Paint()
          ..shader = Gradient.linear(
            const Offset(0, 52),
            const Offset(0, 170),
            const [Color(0x332B3850), Color(0x002B3850)],
          ),
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
    // Rừng phủ sườn Tản Viên: tán tròn li ti, sáng phía trái.
    canvas.save();
    canvas.clipPath(far);
    final forest = math.Random(8);
    for (var i = 0; i < 320; i++) {
      final x = forest.nextDouble() * 262;
      final y = 80 + forest.nextDouble() * 95;
      final r = 1.3 + forest.nextDouble() * 1.4;
      final shaded = x > 150 + (y - 66) * 0.5;
      canvas.drawCircle(
        Offset(x, y),
        r,
        fillPaint(shaded ? const Color(0xFF42605B) : const Color(0xFF557566)),
      );
      canvas.drawCircle(
        Offset(x - r * 0.3, y - r * 0.3),
        r * 0.5,
        fillPaint(shaded ? const Color(0xFF4A6963) : const Color(0xFF628473)),
      );
    }
    canvas.restore();
    // Đền thờ Sơn Tinh trên đỉnh giữa: mái cong đầu đao.
    canvas.drawRect(
      const Rect.fromLTWH(129, 62, 12, 6),
      fillPaint(const Color(0xFF8A6A4A)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(124, 63)
        ..quadraticBezierTo(126, 60, 128, 59)
        ..lineTo(142, 59)
        ..quadraticBezierTo(144, 60, 146, 63)
        ..quadraticBezierTo(140, 61, 135, 56)
        ..quadraticBezierTo(130, 61, 124, 63)
        ..close(),
      fillPaint(const Color(0xFF7A3A2A)),
    );
    // Sương vắt ngang sườn núi (hai dải mỏng).
    for (final (y, a) in const [(118.0, 0x33), (136.0, 0x26)]) {
      canvas.drawRect(
        Rect.fromLTRB(0, y - 6, 262, y + 6),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, y - 6),
            Offset(0, y + 6),
            [
              const Color(0x00FFFFFF),
              Color.fromARGB(a, 255, 255, 255),
              const Color(0x00FFFFFF),
            ],
            const [0, 0.5, 1],
          ),
      );
    }

    // Biển động phía Thuỷ Tinh.
    canvas.drawRect(
      Rect.fromLTRB(200, 168, w, h),
      Paint()
        ..shader = Gradient.linear(const Offset(0, 168), Offset(0, h), const [
          Color(0xFF3A7F8E),
          Color(0xFF194B5A),
        ]),
    );
    // Sóng lừng xa: dải tối – sáng xen kẽ, bọt trắng ở đỉnh.
    for (var i = 0; i < 6; i++) {
      final y = 172.0 + i * 9;
      final pts = [
        for (var x = 200.0; x <= w + 10; x += 22)
          Offset(x, y + math.sin(x * 0.09 + i * 1.7) * 2),
      ];
      canvas.drawPath(
        taperedStroke(
          pts,
          2.4 + i * 0.4,
          peak: 0.5,
          startWidth: 0.3,
          endWidth: 0.3,
        ),
        fillPaint(const Color(0x4410303C)),
      );
      canvas.drawPath(
        taperedStroke(
          [for (final p in pts) p - const Offset(0, 1.6)],
          1 + i * 0.2,
          peak: 0.5,
          startWidth: 0.2,
          endWidth: 0.2,
        ),
        fillPaint(const Color(0x88E9FBFF)),
      );
    }

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
    // Ruộng bậc thang ngập nước: mỗi thửa một mặt nước phản chiếu trời
    // giông, bờ đất sáng mép trên, mạ xanh lấm tấm.
    final seedling = math.Random(31);
    for (var i = 0; i < 4; i++) {
      final y = stageGroundY + 6 + i * 9.0;
      final right = 236 - i * 6.0;
      final paddy = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(120, y - 4, right, y + 2)
        ..lineTo(right - 2, y + 7)
        ..quadraticBezierTo(120, y + 3, 0, y + 7)
        ..close();
      canvas.drawPath(
        paddy,
        Paint()
          ..shader = Gradient.linear(Offset(0, y), Offset(0, y + 7), const [
            Color(0xFF8BA3AE),
            Color(0xFF5E7A80),
          ]),
      );
      canvas.drawPath(
        Path()
          ..moveTo(0, y)
          ..quadraticBezierTo(120, y - 4, right, y + 2),
        Paint()
          ..color = const Color(0xFF9DB862)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
      for (var k = 0; k < 26; k++) {
        final x = seedling.nextDouble() * (right - 6);
        final yy = y + 3 + seedling.nextDouble() * 3 - x / right * 1.5;
        canvas.drawLine(
          Offset(x, yy),
          Offset(x + 0.6, yy - 2),
          Paint()
            ..color = const Color(0xFF7FB04A)
            ..strokeWidth = 0.8,
        );
      }
    }
  }

  /// Mây giông: nhiều thuỳ chồng nhau, đáy phẳng tối, đỉnh thuỳ hắt ánh
  /// xám bạc (mặt trời sau mây), bóng lõi giữa khối.
  static void _stormCloud(Canvas canvas, Offset c, double s) {
    var mass = Path();
    for (final (o, r) in const [
      (Offset(-62, 6), 16.0),
      (Offset(-40, -4), 22.0),
      (Offset(-12, -10), 26.0),
      (Offset(18, -6), 24.0),
      (Offset(46, 2), 18.0),
      (Offset(66, 8), 12.0),
    ]) {
      mass = Path.combine(
        PathOperation.union,
        mass,
        Path()..addOval(Rect.fromCircle(center: c + o * s, radius: r * s)),
      );
    }
    mass = Path.combine(
      PathOperation.intersect,
      mass,
      Path()..addRect(
        Rect.fromLTRB(
          c.dx - 100 * s,
          c.dy - 60 * s,
          c.dx + 100 * s,
          c.dy + 14 * s,
        ),
      ),
    );
    canvas.drawPath(mass, fillPaint(const Color(0xFF2B3850)));
    canvas.save();
    canvas.clipPath(mass);
    canvas.drawPath(
      mass.shift(Offset(-3 * s, 5 * s)),
      fillPaint(const Color(0xFF46566E)),
    );
    canvas.drawPath(
      mass.shift(Offset(-1 * s, 9 * s)),
      fillPaint(const Color(0xFF2B3850)),
    );
    canvas.drawRect(
      Rect.fromLTRB(
        c.dx - 100 * s,
        c.dy + 4 * s,
        c.dx + 100 * s,
        c.dy + 14 * s,
      ),
      fillPaint(const Color(0xFF1C263A)),
    );
    canvas.restore();
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
        const Rect.fromLTRB(150, -60, 440, 280),
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

  static const _left = Offset(-1, 0);

  // Phần tĩnh chụp sẵn: tóc, thân, râu (mỗi khung chỉ xoay nhẹ / dời).
  static final _hairImage = RasterLayer(
    _paintHair,
    bounds: const Rect.fromLTRB(300, 10, 430, 140),
    resolution: 1.3,
  );
  static final _torsoImage = RasterLayer(
    _paintTorso,
    bounds: const Rect.fromLTRB(262, 70, 384, 196),
    resolution: 1.3,
  );
  static final _beardImage = RasterLayer(
    _paintBeard,
    bounds: const Rect.fromLTRB(276, 58, 350, 156),
    resolution: 1.5,
  );

  void _hairBack(Canvas canvas, BossFrame f) {
    // Tóc nước bay ra sau: cả khối lọn xoay nhẹ theo nhịp sóng.
    const pivot = Offset(330, 58);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(math.sin(f.time * 2) * 0.04);
    canvas.translate(-pivot.dx, -pivot.dy);
    _hairImage.paint(canvas);
    canvas.restore();
  }

  /// Tóc như dòng nước: hai lớp lọn dài chảy ra sau (phải) và rủ xuống,
  /// lớp sau sẫm (nước sâu), lớp trước sáng (bọt), ngọn tan thành giọt.
  static void _paintHair(Canvas canvas) {
    final rnd = math.Random(17);
    for (final (r0, len, width, color, count) in [
      (8.0, 66.0, 13.0, ThuyTinhColors.water, 9),
      (6.0, 52.0, 10.0, ThuyTinhColors.hair, 8),
    ]) {
      final locks = buildLocks(
        center: const Offset(330, 58),
        rnd: rnd,
        r0: r0,
        length: len,
        width: width,
        count: count,
        from: -0.9,
        to: 0.9,
        drift: const Offset(0.35, 0.16),
        wave: 9,
      );
      shadedPath(
        canvas,
        locks.mass,
        color,
        PartFrame.world,
        shadow: 2.5,
        highlight: 1.2,
        outlineWidth: 1.3,
      );
      canvas.save();
      canvas.clipPath(locks.mass);
      canvas.drawPath(
        locks.creases,
        fillPaint(darken(color, 0.4).withValues(alpha: 0.7)),
      );
      canvas.drawPath(
        locks.sheens,
        fillPaint(lighten(color, 0.45).withValues(alpha: 0.85)),
      );
      canvas.restore();
      // Ngọn tóc tan thành giọt nước.
      for (final (line, w) in locks.lines) {
        final tip = line.last;
        canvas.drawCircle(tip + const Offset(5, 2), w * 0.16, fillPaint(color));
        canvas.drawCircle(
          tip + const Offset(10, 5),
          w * 0.1,
          fillPaint(color.withValues(alpha: 0.8)),
        );
      }
    }
  }

  // Tư thế nghỉ (không ra đòn) của đinh ba + tay và tay trước chụp sẵn:
  // bó cơ, bàn tay giải phẫu tốn CPU nếu tính lại mỗi khung.
  static final _tridentIdle = RasterLayer(
    (c) => _paintTrident(c, 0),
    bounds: const Rect.fromLTRB(340, -12, 404, 216),
    resolution: 1.3,
  );
  static final _frontArmIdle = RasterLayer(
    (c) => _paintFrontArm(c, 0),
    bounds: const Rect.fromLTRB(236, 92, 306, 152),
    resolution: 1.4,
  );

  void _trident(Canvas canvas, BossFrame f) => f.attack < 0.02
      ? _tridentIdle.paint(canvas)
      : _paintTrident(canvas, f.attack);

  static void _paintTrident(Canvas canvas, double attack) {
    final lift = -12 * attack;
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
    if (attack > 0.05) {
      final r = 18 + 14 * attack;
      canvas.drawCircle(
        top,
        r,
        Paint()
          ..shader = Gradient.radial(top, r, [
            ThuyTinhColors.glow.withValues(alpha: 0.55 * attack),
            ThuyTinhColors.glow.withValues(alpha: 0),
          ]),
      );
    }
    // Tay phải nắm cán: cánh tay + cẳng tay có bó cơ, bàn tay nắm.
    final elbow = Offset(372, 84 + lift * 0.6);
    final wrist = Offset(376, 68 + lift);
    shadedLimb(
      canvas,
      [
        (const Offset(356, 106), elbow, HumanAnatomy.upperArm),
        (elbow, wrist, HumanAnatomy.forearm),
      ],
      ThuyTinhColors.skin,
      shadow: 3,
      scale: 1.35,
      facing: _left,
      definition: 0.8,
    );
    shadedHand(
      canvas,
      buildHand(
        wrist,
        wrist - elbow,
        pose: HandPose.grip,
        facing: _left,
        scale: 1.25,
      ),
      ThuyTinhColors.skin,
    );
  }

  void _torso(Canvas canvas, BossFrame f) => _torsoImage.paint(canvas);

  /// Thân thần nước dựng từ bó cơ (TorsoAnatomy, như tượng Hercules): ngực,
  /// bụng, cơ chéo; bóng đổ dưới ngực; chuỗi ngọc trai vắt chéo; giáp vai
  /// san hô nhiều nhánh.
  static void _paintTorso(Canvas canvas) {
    const skin = ThuyTinhColors.skin;
    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(250, 80, 390, 186));
    shadedLimb(
      canvas,
      [(const Offset(325, 92), const Offset(323, 182), TorsoAnatomy.front)],
      skin,
      scale: 1.95,
      facing: _left,
      shadow: 4,
      definition: 1.3,
    );
    canvas.restore();
    canvas.drawPath(
      Path()
        ..moveTo(296, 122)
        ..quadraticBezierTo(311, 134, 325, 128)
        ..quadraticBezierTo(339, 134, 354, 121)
        ..lineTo(354, 126)
        ..quadraticBezierTo(339, 139, 325, 133)
        ..quadraticBezierTo(311, 139, 296, 127)
        ..close(),
      fillPaint(coreShadeOf(skin).withValues(alpha: 0.35)),
    );
    // Chuỗi ngọc trai vắt chéo ngực.
    for (var i = 0; i < 9; i++) {
      final t = i / 8;
      final p = Offset(296 + 58 * t, 100 + 28 * t + math.sin(t * math.pi) * 5);
      canvas.drawCircle(
        p + const Offset(0.6, 1.2),
        3,
        fillPaint(coreShadeOf(skin).withValues(alpha: 0.4)),
      );
      canvas.drawCircle(p, 3.2, fillPaint(VectorStyle.outline));
      canvas.drawCircle(p, 2.4, fillPaint(const Color(0xFFFFFAF0)));
      glint(canvas, p + const Offset(-0.8, -0.8), 1, alpha: 0.9);
    }
    // Giáp vai san hô trên vai xa: các nhánh thon mọc hướng lên, phân
    // nhánh, đầu nhánh tròn; lỗ san hô lấm tấm.
    const root = Offset(360, 92);
    final branches = Path()
      ..addOval(Rect.fromCenter(center: root, width: 20, height: 12));
    for (var i = 0; i < 5; i++) {
      final a = -2.5 + i * 0.42;
      final dir = Offset(math.cos(a), math.sin(a));
      final from = root + dir * 4;
      final len = 12.0 + (i % 2) * 5;
      final tip = from + dir * len + const Offset(1.5, 0);
      final mid = Offset.lerp(from, tip, 0.55)!;
      branches
        ..addPath(
          taperedStroke(
            [from, mid, tip],
            4,
            peak: 0.2,
            startWidth: 1,
            endWidth: 0.6,
          ),
          Offset.zero,
        )
        ..addOval(Rect.fromCircle(center: tip, radius: 2.1));
      // Nhánh con.
      final side = Offset(-dir.dy, dir.dx) * (i.isEven ? 1 : -1);
      final twig = mid + dir * 3 + side * 6;
      branches
        ..addPath(
          taperedStroke(
            [mid, twig],
            2.6,
            peak: 0.2,
            startWidth: 1,
            endWidth: 0.6,
          ),
          Offset.zero,
        )
        ..addOval(Rect.fromCircle(center: twig, radius: 1.6));
    }
    shadedPath(
      canvas,
      branches,
      ThuyTinhColors.coral,
      PartFrame.world,
      shadow: 2.5,
      highlight: 1.2,
      outlineWidth: 1.2,
    );
    final pores = fillPaint(darken(ThuyTinhColors.coral, 0.35));
    final rnd = math.Random(3);
    for (var i = 0; i < 10; i++) {
      canvas.drawCircle(
        root + Offset(rnd.nextDouble() * 16 - 8, rnd.nextDouble() * 8 - 4),
        0.8,
        pores,
      );
    }
  }

  /// Râu như thác nước: lọn dài chảy thẳng xuống ngực, ngọn tan thành giọt.
  static void _paintBeard(Canvas canvas) {
    final rnd = math.Random(23);
    for (final (r0, len, width, color, count) in [
      (4.0, 58.0, 10.0, ThuyTinhColors.water, 7),
      (3.0, 46.0, 8.0, ThuyTinhColors.hair, 7),
    ]) {
      final locks = buildLocks(
        center: const Offset(316, 72),
        rnd: rnd,
        r0: r0,
        length: len,
        width: width,
        count: count,
        from: 1.15,
        to: 2.35,
        drift: const Offset(-0.02, 0.32),
        wave: 6,
      );
      shadedPath(
        canvas,
        locks.mass,
        color,
        PartFrame.world,
        shadow: 2.5,
        highlight: 1.2,
        outlineWidth: 1.2,
      );
      canvas.save();
      canvas.clipPath(locks.mass);
      canvas.drawPath(
        locks.creases,
        fillPaint(darken(color, 0.4).withValues(alpha: 0.7)),
      );
      canvas.drawPath(
        locks.sheens,
        fillPaint(lighten(color, 0.45).withValues(alpha: 0.85)),
      );
      canvas.restore();
      for (final (line, w) in locks.lines) {
        canvas.drawCircle(
          line.last + const Offset(0, 5),
          w * 0.15,
          fillPaint(color),
        );
      }
    }
  }

  void _head(Canvas canvas, BossFrame f) {
    const c = Offset(318, 68);
    // Râu nước chảy xuống ngực, đung đưa quanh cằm.
    const chin = Offset(316, 76);
    canvas.save();
    canvas.translate(chin.dx, chin.dy);
    canvas.rotate(math.sin(f.time * 1.8) * 0.05);
    canvas.translate(-chin.dx, -chin.dy);
    _beardImage.paint(canvas);
    canvas.restore();
    // Mặt (quay sang trái về phía người chơi).
    // Mặt nghiêng quay trái: trán, gờ mày dô, sống mũi thẳng kiểu tượng,
    // gò má, hàm vuông.
    final face = smoothPath(
      const [
        Offset(334, 48),
        Offset(322, 43),
        Offset(307, 45),
        Offset(300, 51),
        Offset(299, 56),
        Offset(290, 66),
        Offset(296, 69),
        Offset(296, 75),
        Offset(299, 84),
        Offset(310, 89),
        Offset(324, 86),
        Offset(334, 74),
        Offset(338, 60),
      ],
      closed: true,
      tension: 0.08,
    );
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
    // Gò má và hốc mắt (mặt phẳng Loomis), quầng mắt phát sáng gradient.
    canvas.save();
    canvas.clipPath(face);
    final core = coreShadeOf(ThuyTinhColors.skin);
    // Bóng dưới gò má xuống góc hàm, gờ mày dô, rãnh mũi–má, cơ thái dương.
    canvas.drawPath(
      taperedStroke(const [
        Offset(306, 72),
        Offset(316, 78),
        Offset(328, 76),
      ], 3.4),
      fillPaint(core.withValues(alpha: 0.38)),
    );
    canvas.drawPath(
      taperedStroke(
        const [Offset(300, 55), Offset(309, 52), Offset(318, 55)],
        2.6,
        peak: 0.4,
      ),
      fillPaint(lighten(ThuyTinhColors.skin, 0.3).withValues(alpha: 0.7)),
    );
    canvas.drawPath(
      taperedStroke(
        const [Offset(298, 66), Offset(301, 72), Offset(301, 78)],
        1.2,
        peak: 0.3,
      ),
      fillPaint(core.withValues(alpha: 0.6)),
    );
    canvas.drawPath(
      taperedStroke(
        const [Offset(328, 56), Offset(332, 64), Offset(330, 72)],
        3,
        peak: 0.5,
      ),
      fillPaint(core.withValues(alpha: 0.25)),
    );
    // Vảy cá li ti ở thái dương và má (thần biển).
    for (var i = 0; i < 6; i++) {
      final c0 = Offset(
        322 + (i % 3) * 4.0,
        60 + (i ~/ 3) * 5.0 + (i.isOdd ? 2 : 0),
      );
      canvas.drawArc(
        Rect.fromCircle(center: c0, radius: 1.8),
        0.2,
        2.7,
        false,
        Paint()
          ..color = core.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    }
    canvas.drawCircle(
      eye + const Offset(1, -1),
      7,
      Paint()
        ..shader = Gradient.radial(eye + const Offset(1, -1), 7, [
          coreShadeOf(ThuyTinhColors.skin).withValues(alpha: 0.6),
          coreShadeOf(ThuyTinhColors.skin).withValues(alpha: 0),
        ]),
    );
    canvas.restore();
    canvas.drawCircle(
      eye,
      9,
      Paint()
        ..shader = Gradient.radial(eye, 9, [
          ThuyTinhColors.glow.withValues(alpha: 0.6),
          ThuyTinhColors.glow.withValues(alpha: 0),
        ]),
    );
    // Mắt hạnh nhân xếch, hẹp (nhìn hằm hằm), tròng sáng như ánh nước.
    final almond = Path()
      ..moveTo(eye.dx - 4, eye.dy + 0.8)
      ..quadraticBezierTo(eye.dx - 0.5, eye.dy - 2.6, eye.dx + 4, eye.dy - 1)
      ..quadraticBezierTo(eye.dx + 0.5, eye.dy + 2, eye.dx - 4, eye.dy + 0.8)
      ..close();
    canvas.drawPath(almond, fillPaint(const Color(0xFF0E3440)));
    canvas.save();
    canvas.clipPath(almond);
    canvas.drawCircle(
      eye + const Offset(-0.6, -0.2),
      2,
      fillPaint(const Color(0xFFB8FFFF)),
    );
    canvas.drawCircle(
      eye + const Offset(-0.6, -0.2),
      0.8,
      fillPaint(const Color(0xFFFFFFFF)),
    );
    canvas.restore();
    canvas.drawPath(
      taperedStroke(
        [
          eye + const Offset(-7, -3.5),
          eye + const Offset(-1, -6),
          eye + const Offset(7, -4),
        ],
        3,
        peak: 0.2,
        startWidth: 0.8,
      ),
      fillPaint(VectorStyle.outline),
    );
    // Miệng: há ra khi đe doạ.
    final open = 2 + 6 * f.attack;
    final mouth = Path()
      ..moveTo(296, 74)
      ..quadraticBezierTo(303, 74 + open, 310, 73)
      ..quadraticBezierTo(303, 72, 296, 74)
      ..close();
    canvas.drawPath(mouth, fillPaint(const Color(0xFF14323C)));
    // Ria như hai dòng nước chảy rủ từ dưới mũi qua khoé miệng.
    for (final (pts, w) in [
      (
        const [
          Offset(298, 70),
          Offset(302, 74),
          Offset(300, 82),
          Offset(294, 90),
        ],
        3.2,
      ),
      (
        const [
          Offset(300, 70),
          Offset(306, 73),
          Offset(308, 80),
          Offset(306, 88),
        ],
        2.6,
      ),
    ]) {
      final m = taperedStroke(pts, w, peak: 0.2, startWidth: 0.6);
      canvas.drawPath(m, fillPaint(ThuyTinhColors.hair));
      canvas.drawPath(
        taperedStroke(
          [for (final p in pts) p + const Offset(-0.6, -0.6)],
          w * 0.35,
          peak: 0.2,
        ),
        fillPaint(const Color(0xCCFFFFFF)),
      );
    }
    // Vương miện thuỷ thần: vành vàng ôm trán, trên là ba ngọn sóng vàng
    // cuộn ra sau (sóng cao nhất ở giữa), đính ngọc trai ở chân sóng và
    // hạt ngọc lục giữa trán.
    final band = Path()
      ..moveTo(299, 50)
      ..quadraticBezierTo(318, 44, 337, 49)
      ..lineTo(337, 54)
      ..quadraticBezierTo(318, 49, 299, 55)
      ..close();
    Path wave(Offset base, double h, double w) => Path()
      ..moveTo(base.dx - w * 0.5, base.dy)
      ..cubicTo(
        base.dx - w * 0.6,
        base.dy - h * 0.7,
        base.dx + w * 0.1,
        base.dy - h * 1.1,
        base.dx + w * 0.55,
        base.dy - h * 0.8,
      )
      ..cubicTo(
        base.dx + w * 0.75,
        base.dy - h * 0.62,
        base.dx + w * 0.55,
        base.dy - h * 0.38,
        base.dx + w * 0.3,
        base.dy - h * 0.48,
      )
      ..cubicTo(
        base.dx + w * 0.2,
        base.dy - h * 0.3,
        base.dx + w * 0.4,
        base.dy - h * 0.1,
        base.dx + w * 0.5,
        base.dy,
      )
      ..close();
    final waves = Path()
      ..addPath(wave(const Offset(306, 49), 12, 12), Offset.zero)
      ..addPath(wave(const Offset(318, 47), 18, 14), Offset.zero)
      ..addPath(wave(const Offset(330, 49), 12, 12), Offset.zero);
    final crown = Path.combine(PathOperation.union, band, waves);
    canvas.drawPath(
      crown,
      Paint()
        ..color = VectorStyle.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(crown, goldPaint(crown.getBounds()));
    // Rãnh khắc dọc ngọn sóng.
    canvas.save();
    canvas.clipPath(waves);
    for (final c0 in const [
      Offset(306, 43),
      Offset(318, 38),
      Offset(330, 43),
    ]) {
      canvas.drawArc(
        Rect.fromCircle(center: c0, radius: 3.4),
        3.4,
        3.6,
        false,
        Paint()
          ..color = const Color(0xFF8A6418)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
    canvas.restore();
    for (final p in const [
      Offset(304, 51.5),
      Offset(311, 50.5),
      Offset(325, 50.5),
      Offset(332, 51.5),
    ]) {
      canvas.drawCircle(p, 1.5, fillPaint(const Color(0xFFFFFAF0)));
    }
    canvas.drawCircle(
      const Offset(318, 49.5),
      2.4,
      fillPaint(VectorStyle.outline),
    );
    canvas.drawCircle(
      const Offset(318, 49.5),
      1.8,
      fillPaint(const Color(0xFF2EC4A6)),
    );
    glint(canvas, const Offset(317.4, 48.8), 0.9);
    glint(canvas, const Offset(316, 34), 1.4);
  }

  void _frontArm(Canvas canvas, BossFrame f) => f.attack < 0.02
      ? _frontArmIdle.paint(canvas)
      : _paintFrontArm(canvas, f.attack);

  /// Tay trái chỉ về phía người chơi, bàn tay xoè; lòng bàn tay toả nước
  /// khi đe doạ.
  static void _paintFrontArm(Canvas canvas, double attack) {
    final reach = 6 * attack;
    final wrist = Offset(264 - reach, 130 - reach);
    const elbow = Offset(278, 122);
    shadedLimb(
      canvas,
      [
        (const Offset(296, 104), elbow, HumanAnatomy.upperArm),
        (elbow, wrist, HumanAnatomy.forearm),
      ],
      ThuyTinhColors.skin,
      shadow: 3,
      scale: 1.4,
      facing: _left,
      definition: 0.9,
    );
    shadedHand(
      canvas,
      buildHand(
        wrist,
        wrist - elbow,
        pose: HandPose.open,
        facing: _left,
        scale: 1.3,
      ),
      ThuyTinhColors.skin,
    );
    if (attack > 0.05) {
      final c = wrist + const Offset(-12, 0);
      final r = 14 * attack + 4;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = Gradient.radial(c, r, [
            ThuyTinhColors.glow.withValues(alpha: 0.7 * attack),
            ThuyTinhColors.glow.withValues(alpha: 0),
          ]),
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
    canvas.save();
    canvas.clipPath(wave);
    // Lòng sóng cuộn tối; nước mỏng gần ngọn sáng (ánh sáng xuyên qua).
    canvas.drawCircle(
      Offset(300, 190 - surge),
      26,
      Paint()
        ..shader = Gradient.radial(Offset(300, 190 - surge), 26, [
          ThuyTinhColors.waterDeep.withValues(alpha: 0.85),
          ThuyTinhColors.waterDeep.withValues(alpha: 0),
        ]),
    );
    Offset crest(double x) => x < 300
        ? Offset(x, 214 - (x - 252) / 48 * 44 - surge)
        : Offset(x, 176 + math.sin(t * 2 + x * 0.08) * 2.5);
    final crestLine = [for (var x = 256.0; x <= 410; x += 14) crest(x)];
    canvas.drawPath(
      taperedStroke(
        offsetLine(crestLine, -7),
        12,
        peak: 0.5,
        startWidth: 0.5,
        endWidth: 0.5,
      ),
      fillPaint(lighten(ThuyTinhColors.water, 0.3).withValues(alpha: 0.55)),
    );
    // Lưới bọt trên mặt sóng: các vệt trắng mảnh lượn theo dòng chảy.
    final lace = fillPaint(ThuyTinhColors.foam.withValues(alpha: 0.35));
    for (var i = 0; i < 5; i++) {
      final y = 192.0 + i * 9;
      final pts = [
        for (var k = 0; k < 6; k++)
          Offset(
            272 + i * 6 + k * 24.0,
            y + math.sin(t * 1.4 + k * 1.3 + i) * 2.5,
          ),
      ];
      canvas.drawPath(taperedStroke(pts, 1.6, peak: 0.5, samples: 12), lace);
    }
    canvas.restore();
    // Mép bọt liền dọc ngọn sóng + lọn bọt vươn về phía người chơi.
    final foam = fillPaint(ThuyTinhColors.foam);
    canvas.drawPath(
      taperedStroke(
        crestLine,
        6,
        peak: 0.3,
        startWidth: 0.6,
        endWidth: 0.4,
        samples: 24,
      ),
      foam,
    );
    for (var i = 0; i < crestLine.length; i++) {
      final base = crestLine[i];
      final curl = lockLine(
        -2.3 + math.sin(t * 2 + i) * 0.2,
        0,
        7 + (i % 3) * 2.5,
        drift: const Offset(-0.4, 0.3),
      );
      canvas.drawPath(
        taperedStroke(
          [for (final p in curl) p + base],
          3.2,
          peak: 0.2,
          startWidth: 1,
        ),
        foam,
      );
    }
    // Bụi nước bắn lên khi sóng dâng.
    if (surge > 1) {
      final rnd = math.Random(9);
      for (var i = 0; i < 10; i++) {
        final p =
            crest(258 + rnd.nextDouble() * 50) +
            Offset(rnd.nextDouble() * -16, -6 - rnd.nextDouble() * surge * 1.6);
        canvas.drawCircle(
          p,
          0.8 + rnd.nextDouble() * 1.2,
          fillPaint(ThuyTinhColors.foam.withValues(alpha: 0.8)),
        );
      }
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
    // Vân sáng khúc xạ dưới nước (caustics): mạng lưới đường lượn sáng mờ
    // trôi chậm, dày ở gần mặt nước, nhạt dần xuống sâu.
    canvas.save();
    canvas.clipPath(path);
    for (var row = 0; row < 5; row++) {
      final y0 = surface + 10 + row * 14;
      if (y0 > h) break;
      final a = 0.22 * (1 - row / 5);
      final pts = [
        for (var x = -10.0; x <= w + 10; x += 16)
          Offset(x, y0 + math.sin(x * 0.07 + t * 1.6 + row * 1.9) * 4),
      ];
      canvas.drawPath(
        taperedStroke(
          pts,
          1.6,
          peak: 0.5,
          startWidth: 0.4,
          endWidth: 0.4,
          samples: 30,
        ),
        fillPaint(Color.fromRGBO(220, 250, 255, a)),
      );
    }
    // Cột sáng xiên xuyên qua nước.
    for (var i = 0; i < 3; i++) {
      final x = 60.0 + i * 120 + math.sin(t * 0.4 + i) * 10;
      canvas.drawPath(
        Path()
          ..moveTo(x, surface)
          ..lineTo(x + 18, surface)
          ..lineTo(x - 12, h)
          ..lineTo(x - 30, h)
          ..close(),
        Paint()
          ..shader = Gradient.linear(Offset(0, surface), Offset(0, h), const [
            Color(0x33E9FBFF),
            Color(0x00E9FBFF),
          ]),
      );
    }
    // Bọt khí li ti nổi lên.
    for (var i = 0; i < 14; i++) {
      final phase = (t * 0.35 + i / 14) % 1;
      final x = (i * 29.0) % w + math.sin(t * 2 + i) * 3;
      final y = h - phase * (h - surface);
      canvas.drawCircle(
        Offset(x, y),
        0.8 + (i % 3) * 0.5,
        Paint()
          ..color = Color.fromRGBO(233, 251, 255, 0.6 * (1 - phase * 0.5))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    }
    canvas.restore();
    // Gợn sóng nhỏ và vệt sáng trôi trên mặt nước.
    final shine = Paint()
      ..color = const Color(0x88FFFFFF)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 10; i++) {
      final x = (i * 43 + t * 18) % (w + 40) - 20;
      final y = surface + 3 + (i % 3) * 4;
      if (y < h) {
        canvas.drawPath(
          taperedStroke(
            [Offset(x, y), Offset(x + 7, y - 1.2), Offset(x + 14, y)],
            1.4,
            peak: 0.5,
          ),
          shine,
        );
      }
    }
  }
}
