import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../battle_stage.dart';
import '../motion.dart' show AttackPose;
import '../stage_shaders.dart';
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
/// Cổ Fafnir đã ghi theo (độ chồm, nhịp thở) làm tròn.
final _neckCache = PictureCache<(int, int)>(maxEntries: 40);

class FafnirBossArt extends BossArt {
  @override
  String get soundKey => 'fafnir';

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
    // Dải Ngân Hà chéo trời: dày sao nhỏ, quầng mờ.
    final rnd = math.Random(11);
    canvas.save();
    canvas.translate(200, 60);
    canvas.rotate(-0.35);
    // Quầng Ngân Hà mờ dần hai mép (gradient ngang dải, không mép cứng).
    canvas.drawRect(
      const Rect.fromLTRB(-300, -22, 300, 22),
      Paint()
        ..shader = Gradient.linear(
          const Offset(0, -22),
          const Offset(0, 22),
          const [Color(0x00B8C8F0), Color(0x2EB8C8F0), Color(0x00B8C8F0)],
          const [0, 0.5, 1],
        ),
    );
    for (var i = 0; i < 160; i++) {
      final x = (rnd.nextDouble() - 0.5) * 500;
      final y = (rnd.nextDouble() + rnd.nextDouble() - 1) * 16;
      canvas.drawCircle(
        Offset(x, y),
        rnd.nextDouble() * 0.45 + 0.15,
        fillPaint(Color.fromRGBO(230, 238, 255, 0.4 + rnd.nextDouble() * 0.5)),
      );
    }
    canvas.restore();
    for (var i = 0; i < 40; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * w, rnd.nextDouble() * 110),
        rnd.nextDouble() * 0.9 + 0.3,
        fillPaint(const Color(0xCCFFFFFF)),
      );
    }
    // Trăng khuyết có quầng.
    const moon = Offset(84, 40);
    canvas.drawCircle(
      moon,
      34,
      Paint()
        ..shader = Gradient.radial(moon, 34, const [
          Color(0x40DCEBFF),
          Color(0x00DCEBFF),
        ]),
    );
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: moon, radius: 11)),
        Path()..addOval(
          Rect.fromCircle(center: moon + const Offset(5, -3), radius: 10),
        ),
      ),
      fillPaint(const Color(0xFFEAF2FF)),
    );
    // Hai dãy núi tuyết: xa (nhạt, sương) và gần (đậm).
    _snowRidge(
      canvas,
      const [
        Offset(-10, 160),
        Offset(30, 122),
        Offset(70, 146),
        Offset(118, 104),
        Offset(170, 142),
        Offset(226, 112),
        Offset(286, 150),
        Offset(340, 118),
        Offset(410, 146),
      ],
      rock: const Color(0xFF3B5770),
      floor: 196,
      seed: 3,
    );
    _snowRidge(
      canvas,
      const [
        Offset(-10, 178),
        Offset(52, 148),
        Offset(96, 168),
        Offset(150, 140),
        Offset(214, 172),
        Offset(262, 150),
        Offset(320, 176),
        Offset(372, 152),
        Offset(410, 170),
      ],
      rock: const Color(0xFF263F55),
      floor: 206,
      seed: 7,
    );
    // Rừng thông phủ tuyết: hàng xa nhỏ, nhạt; hàng gần to, đậm.
    final trees = math.Random(5);
    for (var i = 0; i < 16; i++) {
      _fir(
        canvas,
        Offset(i * 27.0 + trees.nextDouble() * 8, 196),
        22 + trees.nextDouble() * 8,
        const Color(0xFF29465C),
      );
    }
    for (var i = 0; i < 11; i++) {
      final x = i * 38.0 + trees.nextDouble() * 12;
      if (x > 250 && x < 420) continue; // chừa chỗ đống vàng và rồng
      _fir(
        canvas,
        Offset(x, 210),
        34 + trees.nextDouble() * 12,
        const Color(0xFF173246),
      );
    }
    // Nền tuyết: luống tuyết gió thổi, bóng xanh lạnh, đốm lấp lánh.
    canvas.drawRect(
      Rect.fromLTRB(0, stageGroundY - 6, w, h),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, stageGroundY),
          Offset(0, h),
          const [Color(0xFFE3EEF7), Color(0xFFA9C2D6)],
        ),
    );
    for (var i = 0; i < 6; i++) {
      final x = i * 72.0 - 10;
      final y = stageGroundY + 6 + (i % 3) * 8.0;
      canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..quadraticBezierTo(x + 30, y - 7, x + 64, y)
          ..quadraticBezierTo(x + 30, y - 2, x, y)
          ..close(),
        fillPaint(const Color(0x668FAAC4)),
      );
    }
    // Luống tuyết gió thổi có khối: sườn đón trăng sáng, mép sau sắc tối
    // (sastrugi), xếp so le theo chiều sâu.
    final drift = math.Random(21);
    for (var i = 0; i < 9; i++) {
      final x = drift.nextDouble() * (w + 40) - 20;
      final y =
          stageGroundY + 10 + drift.nextDouble() * (h - stageGroundY - 14);
      final depth = (y - stageGroundY) / (h - stageGroundY);
      final len = 26 + depth * 40;
      final hh = 2 + depth * 3;
      canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..quadraticBezierTo(x + len * 0.55, y - hh * 1.6, x + len, y)
          ..quadraticBezierTo(x + len * 0.7, y + hh * 0.4, x, y)
          ..close(),
        fillPaint(const Color(0xFFF4F9FF)),
      );
      canvas.drawPath(
        Path()
          ..moveTo(x + len * 0.55, y - hh * 0.8)
          ..quadraticBezierTo(x + len * 0.8, y - hh * 0.4, x + len, y)
          ..quadraticBezierTo(
            x + len * 0.75,
            y + hh * 0.5,
            x + len * 0.5,
            y + 0.4,
          )
          ..close(),
        fillPaint(const Color(0x887E9CBA)),
      );
    }
    // Đá đen nhô khỏi tuyết, mũ tuyết trên đỉnh.
    for (final (c, rw) in const [
      (Offset(40, 248.0), 10.0),
      (Offset(176, 238.0), 7.0),
      (Offset(236, 256.0), 12.0),
    ]) {
      final rock = Path()
        ..moveTo(c.dx - rw, c.dy)
        ..lineTo(c.dx - rw * 0.6, c.dy - rw * 0.55)
        ..lineTo(c.dx + rw * 0.2, c.dy - rw * 0.7)
        ..lineTo(c.dx + rw, c.dy - rw * 0.2)
        ..lineTo(c.dx + rw * 0.9, c.dy)
        ..close();
      canvas.drawPath(rock, fillPaint(const Color(0xFF3A4656)));
      canvas.drawPath(
        Path()
          ..moveTo(c.dx + rw * 0.2, c.dy - rw * 0.7)
          ..lineTo(c.dx + rw, c.dy - rw * 0.2)
          ..lineTo(c.dx + rw * 0.9, c.dy)
          ..lineTo(c.dx + rw * 0.1, c.dy)
          ..close(),
        fillPaint(const Color(0xFF283240)),
      );
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - rw * 0.7, c.dy - rw * 0.5)
          ..lineTo(c.dx + rw * 0.2, c.dy - rw * 0.75)
          ..lineTo(c.dx + rw * 0.8, c.dy - rw * 0.3)
          ..quadraticBezierTo(
            c.dx + rw * 0.1,
            c.dy - rw * 0.35,
            c.dx - rw * 0.7,
            c.dy - rw * 0.5,
          )
          ..close(),
        fillPaint(const Color(0xFFF4F9FF)),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: c + Offset(rw * 0.4, 1),
          width: rw * 2.4,
          height: 3,
        ),
        fillPaint(const Color(0x557E9CBA)),
      );
    }
    final sparkle = math.Random(13);
    for (var i = 0; i < 40; i++) {
      canvas.drawCircle(
        Offset(
          sparkle.nextDouble() * w,
          stageGroundY + sparkle.nextDouble() * (h - stageGroundY),
        ),
        0.5,
        fillPaint(const Color(0xCCFFFFFF)),
      );
    }
    _runestone(canvas);
  }

  /// Dãy núi tuyết: đá lộ ở sườn dốc, tuyết phủ sườn đón sáng (trái) và
  /// đọng thành vệt trong khe xói; sương lạnh phủ chân núi.
  static void _snowRidge(
    Canvas canvas,
    List<Offset> peaks, {
    required Color rock,
    required double floor,
    required int seed,
  }) {
    final rnd = math.Random(seed);
    final body = Path()..moveTo(peaks.first.dx, floor);
    for (final p in peaks) {
      body.lineTo(p.dx, p.dy);
    }
    body
      ..lineTo(peaks.last.dx, floor)
      ..close();
    canvas.drawPath(body, fillPaint(rock));
    canvas.save();
    canvas.clipPath(body);
    final snowLit = fillPaint(const Color(0xFFD5E4F0));
    final snowShade = fillPaint(const Color(0xFF7F9BB4));
    for (var i = 1; i < peaks.length - 1; i++) {
      final p = peaks[i];
      if (p.dy > peaks[i - 1].dy || p.dy > peaks[i + 1].dy) continue;
      final hgt = floor - p.dy;
      final l = peaks[i - 1], r = peaks[i + 1];
      // Mũ tuyết hai sườn, mép dưới răng cưa (tuyết bám theo gờ đá).
      for (final (side, paint) in [(l, snowLit), (r, snowShade)]) {
        final dir = (side - p) / (side - p).distance;
        canvas.drawPath(
          Path()
            ..moveTo(p.dx, p.dy)
            ..lineTo(p.dx + dir.dx * hgt * 0.6, p.dy + dir.dy * hgt * 0.6)
            ..lineTo(p.dx + dir.dx * hgt * 0.35, p.dy + hgt * 0.42)
            ..close(),
          paint,
        );
      }
      // Vệt tuyết trong khe xói chảy xuống.
      for (var k = 0; k < 2; k++) {
        final x0 = p.dx + (k - 0.5) * hgt * 0.3;
        final top = Offset(x0, p.dy + hgt * 0.35 + rnd.nextDouble() * 6);
        final end =
            top + Offset((k - 0.5) * 4, hgt * (0.14 + rnd.nextDouble() * 0.1));
        canvas.drawPath(
          taperedStroke(
            [top, Offset.lerp(top, end, 0.5)! + const Offset(1, 0), end],
            2.2,
            peak: 0.2,
            startWidth: 1,
          ),
          k == 0 ? snowLit : snowShade,
        );
      }
    }
    // Sương lạnh chân núi.
    final top = peaks.map((p) => p.dy).reduce(math.min);
    canvas.drawRect(
      Rect.fromLTRB(-20, top, 420, floor),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, top + (floor - top) * 0.4),
          Offset(0, floor),
          const [Color(0x00B8CCE0), Color(0x66B8CCE0)],
        ),
    );
    canvas.restore();
  }

  /// Cây thông phủ tuyết: thân, 5 tầng cành răng cưa thu nhỏ dần lên ngọn,
  /// tuyết đọng thành dải trên mép trên mỗi tầng.
  static void _fir(Canvas canvas, Offset base, double h, Color color) {
    canvas.drawRect(
      Rect.fromLTWH(base.dx - h * 0.04, base.dy - h * 0.18, h * 0.08, h * 0.2),
      fillPaint(const Color(0xFF2A2420)),
    );
    for (var t = 0; t < 5; t++) {
      final w = h * (0.46 - t * 0.075);
      final bottom = base.dy - h * (0.12 + t * 0.17);
      final top = bottom - h * 0.3;
      final tier = Path()
        ..moveTo(base.dx, top)
        ..lineTo(base.dx + w * 0.55, bottom - h * 0.05)
        ..lineTo(base.dx + w * 0.35, bottom - h * 0.06)
        ..lineTo(base.dx + w * 0.7, bottom)
        ..lineTo(base.dx - w * 0.7, bottom)
        ..lineTo(base.dx - w * 0.35, bottom - h * 0.06)
        ..lineTo(base.dx - w * 0.55, bottom - h * 0.05)
        ..close();
      canvas.drawPath(
        tier,
        fillPaint(
          Color.lerp(color, const Color(0xFF0B1A26), 0.15 * (4 - t) / 4)!,
        ),
      );
      // Tuyết đọng mép trên tầng cành (nghiêng sáng phía trái).
      canvas.drawPath(
        taperedStroke(
          [
            Offset(base.dx - w * 0.6, bottom - h * 0.02),
            Offset(base.dx - w * 0.2, bottom - h * 0.1),
            Offset(base.dx + w * 0.1, bottom - h * 0.12),
            Offset(base.dx + w * 0.45, bottom - h * 0.05),
          ],
          h * 0.06,
          peak: 0.35,
          startWidth: 0.3,
          endWidth: 0.1,
        ),
        fillPaint(const Color(0xFFDCEAF5)),
      );
    }
  }

  /// Bia đá rune kiểu khắc đá Ramsund (Thuỵ Điển, cảnh Sigurd giết Fafnir):
  /// dải thân rắn mang chữ rune chạy vòng theo mép bia, phát sáng lạnh;
  /// địa y, vết nứt, tuyết đọng trên đỉnh.
  static void _runestone(Canvas canvas) {
    final stone = Path()
      ..moveTo(18, stageGroundY - 2)
      ..lineTo(14, 164)
      ..quadraticBezierTo(16, 146, 34, 142)
      ..quadraticBezierTo(52, 146, 54, 166)
      ..lineTo(52, stageGroundY - 2)
      ..close();
    shadedPath(
      canvas,
      stone,
      const Color(0xFF6E7F8C),
      PartFrame.world,
      shadow: 3,
      highlight: 1.2,
    );
    canvas.save();
    canvas.clipPath(stone);
    // Dải rắn chạy theo mép bia (vòng chữ U ngược), viền khắc sâu.
    final band = smoothPath(const [
      Offset(20, 232),
      Offset(19, 186),
      Offset(22, 158),
      Offset(34, 150),
      Offset(46, 158),
      Offset(48, 186),
      Offset(46, 222),
    ]);
    canvas.drawPath(
      band,
      Paint()
        ..color = const Color(0xFF4A5864)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.5,
    );
    canvas.drawPath(
      band,
      Paint()
        ..color = const Color(0xFF8A9AA6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    // Chữ rune dọc dải rắn, sáng lạnh.
    final glyph = Paint()
      ..color = const Color(0xFF8FE3FF)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    final line = sampleSmooth(const [
      Offset(20, 230),
      Offset(19, 186),
      Offset(22, 158),
      Offset(34, 150),
      Offset(46, 158),
      Offset(48, 186),
      Offset(46, 222),
    ], 22);
    for (var i = 1; i < line.length - 1; i++) {
      final d = line[i + 1] - line[i - 1];
      final dir = d / d.distance;
      final n = Offset(-dir.dy, dir.dx);
      final c = line[i];
      canvas.drawLine(c - n * 1.8, c + n * 1.8, glyph);
      final k = i % 3;
      if (k == 0) canvas.drawLine(c - n * 1.8, c + dir * 1.4, glyph);
      if (k == 1) canvas.drawLine(c, c + dir * 1.4 + n * 1.4, glyph);
      if (k == 2) canvas.drawLine(c + n * 1.8, c + dir * 1.4 - n * 0.6, glyph);
    }
    // Đầu rắn ở cuối dải và hình Sigurd đâm kiếm từ dưới lên (nét khắc).
    canvas.drawPath(
      taperedStroke(
        const [Offset(46, 222), Offset(42, 230), Offset(36, 232)],
        5,
        peak: 0.3,
      ),
      fillPaint(const Color(0xFF8A9AA6)),
    );
    final carve = Paint()
      ..color = const Color(0xFF4A5864)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(30, 214)
        ..lineTo(33, 200)
        ..moveTo(33, 200)
        ..lineTo(38, 176)
        ..moveTo(30, 206)
        ..lineTo(36, 204)
        ..addOval(Rect.fromCircle(center: const Offset(32, 197), radius: 2)),
      carve,
    );
    // Địa y và vết nứt.
    final lichen = math.Random(21);
    for (var i = 0; i < 12; i++) {
      canvas.drawCircle(
        Offset(16 + lichen.nextDouble() * 36, 150 + lichen.nextDouble() * 80),
        0.6 + lichen.nextDouble() * 1.2,
        fillPaint(const Color(0x88B8C27A)),
      );
    }
    canvas.drawPath(
      taperedStroke(const [
        Offset(40, 168),
        Offset(43, 178),
        Offset(41, 190),
      ], 1.2),
      fillPaint(const Color(0xFF45525C)),
    );
    canvas.restore();
    // Tuyết đọng trên đỉnh bia.
    canvas.drawPath(
      Path()
        ..moveTo(15, 160)
        ..quadraticBezierTo(16, 143, 34, 140)
        ..quadraticBezierTo(53, 144, 54, 162)
        ..quadraticBezierTo(46, 154, 40, 158)
        ..quadraticBezierTo(32, 150, 24, 157)
        ..quadraticBezierTo(18, 156, 15, 160)
        ..close(),
      fillPaint(const Color(0xFFE6F0F8)),
    );
  }

  /// Cực quang bằng shader GPU (rèm tia sáng chuyển động); máy không nạp
  /// được shader thì vẽ bản vector bên dưới.
  final _aurora = ShaderLayer(StageShaders.aurora, width: 200, height: 70);

  @override
  void dispose() => _aurora.dispose();

  @override
  void paintAmbient(Canvas canvas, double time) {
    if (_aurora.ready) {
      _aurora.paint(
        canvas,
        const Rect.fromLTWH(0, 0, 400, 140),
        time: time,
        blendMode: BlendMode.plus,
      );
    } else {
      _vectorAurora(canvas, time);
    }
    _snow(canvas, time);
  }

  /// Cực quang vector (dự phòng): rèm sáng dọc mờ dần ở mép trên và dưới
  /// bằng gradient — không blur mỗi khung (rất đắt trên GPU).
  void _vectorAurora(Canvas canvas, double time) {
    for (final (y, color, speed) in [
      (40.0, const Color(0xFF34F5B0), 0.4),
      (58.0, const Color(0xFFA06BFF), 0.3),
    ]) {
      final path = Path()..moveTo(-10, y);
      for (var x = -10.0; x <= 410; x += 20) {
        path.lineTo(x, y + math.sin(x / 50 + time * speed) * 10);
      }
      for (var x = 410.0; x >= -10; x -= 20) {
        path.lineTo(x, y + 30 + math.sin(x / 45 + time * speed + 1) * 8);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = Gradient.linear(
            Offset(0, y - 10),
            Offset(0, y + 38),
            [
              color.withValues(alpha: 0),
              color.withValues(alpha: 0.3),
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0),
            ],
            const [0, 0.3, 0.7, 1],
          ),
      );
      // Tia rèm dọc lung linh.
      for (var i = 0; i < 14; i++) {
        final x = i * 30.0 + 8 + math.sin(time * speed * 2 + i) * 4;
        final top = y + math.sin(x / 50 + time * speed) * 10;
        final a = 0.08 + 0.06 * math.sin(time * 1.3 + i * 1.7);
        canvas.drawLine(
          Offset(x, top),
          Offset(x, top + 26),
          Paint()
            ..color = color.withValues(alpha: a.clamp(0.0, 1.0))
            ..strokeWidth = 3,
        );
      }
    }
  }

  void _snow(Canvas canvas, double time) {
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
        const Rect.fromLTRB(150, -60, 440, 280),
        Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.srcATop),
      );
    }
    _groundShadow(canvas, const Offset(334, stageGroundY + 6), 180, 20);
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
    // Hơi băng chỉ phun lúc ra đòn; pha lấy đà chỉ ngóc đầu (báo trước).
    final striking = f.attackPhase < 0 || f.attackPhase >= AttackPose.windupEnd;
    if (f.attack > 0.05 && f.defeat == 0 && striking) _frostBreath(canvas, f);
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
    // Màng mỏng sát mép: ánh cực quang xanh lục xuyên qua (dải sáng trong
    // mép, chỉ nửa trong lộ ra nhờ vùng cắt).
    canvas.drawPath(
      membrane,
      Paint()
        ..color = const Color(0x2E7CF2C0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9,
    );
    canvas.drawPath(
      membrane,
      Paint()
        ..color = const Color(0x337CF2C0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    canvas.restore();
    // Vết rách cũ ở mép màng (rồng già) + sương giá đọng dọc mép. Điểm
    // giữa mép cong bậc hai = trung điểm + nửa độ lõm vào.
    final notch = fillPaint(const Color(0xFF0F1828));
    for (var i = 0; i < tips.length; i++) {
      final b = i + 1 < tips.length ? tips[i + 1] : root;
      final mid = Offset.lerp(tips[i], b, 0.5)!;
      final edge = mid + (wrist - mid) * (i == tips.length - 1 ? 0.14 : 0.16);
      if (i.isOdd) {
        final d = (wrist - edge) / (wrist - edge).distance;
        final n = Offset(-d.dy, d.dx);
        canvas.drawPath(
          Path()
            ..moveTo(edge.dx - n.dx * 2.2, edge.dy - n.dy * 2.2)
            ..lineTo(edge.dx + d.dx * 5, edge.dy + d.dy * 5)
            ..lineTo(edge.dx + n.dx * 1.6, edge.dy + n.dy * 1.6)
            ..close(),
          notch,
        );
      }
      final frost = fillPaint(FafnirColors.frost.withValues(alpha: 0.8));
      for (final t in const [0.2, 0.45, 0.7]) {
        canvas.drawCircle(
          Offset.lerp(tips[i], edge, t)! + const Offset(0, -0.8),
          0.9,
          frost,
        );
      }
    }
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
    // Mặt hông khuất dưới vòm lưng: vảy nhỏ xếp ngói, tối dần xuống đất
    // (thân tự che bóng) — không để mảng phẳng.
    canvas.save();
    canvas.clipPath(mass);
    final flank = Paint()
      ..color = darken(FafnirColors.body, 0.42).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final flankLit = Paint()
      ..color = lighten(FafnirColors.body, 0.25).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    for (var r = 0; r < 16; r++) {
      final y = 158.0 + r * 3.8;
      for (var x = 294.0 + (r.isOdd ? 2.6 : 0); x < 398; x += 5.2) {
        final cell = Rect.fromCenter(
          center: Offset(x, y),
          width: 5.2,
          height: 4.4,
        );
        canvas.drawArc(cell, 0.15, math.pi - 0.3, false, flank);
        canvas.drawArc(
          cell.shift(const Offset(-0.4, -0.9)),
          math.pi + 0.5,
          1.2,
          false,
          flankLit,
        );
      }
    }
    canvas.drawRect(
      const Rect.fromLTRB(288, 150, 400, 218),
      Paint()
        ..shader = Gradient.linear(
          const Offset(0, 176),
          const Offset(0, 218),
          const [Color(0x0010182A), Color(0x9910182A)],
        ),
    );
    canvas.restore();
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
    // Khúc đuôi cuộn vòng trước bụng, nằm trên vàng: phá khối vòm, thân
    // rắn quấn quanh kho báu.
    final coil = buildScaleBody(
      const [
        Offset(402, 213),
        Offset(380, 203),
        Offset(352, 205),
        Offset(328, 213),
      ],
      15,
      peak: 0.25,
      startWidth: 1,
      endWidth: 0.5,
    );
    shadedPath(
      canvas,
      coil.body,
      FafnirColors.body,
      PartFrame.world,
      shadow: 3,
      highlight: 1.2,
    );
    canvas.save();
    canvas.clipPath(coil.body);
    canvas.drawPath(coil.belly, fillPaint(FafnirColors.belly));
    canvas.drawPath(
      coil.plates,
      Paint()
        ..color = darken(FafnirColors.belly, 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
    canvas.drawPath(
      coil.scaleDark,
      Paint()
        ..color = darken(FafnirColors.body, 0.38).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
    canvas.drawPath(
      coil.scaleLit,
      Paint()
        ..color = lighten(FafnirColors.body, 0.35).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
    canvas.restore();
    // Ngực trước: đốt vảy bụng nhạt xếp theo đường cong ngực (nối dải bụng
    // của cổ), hẹp dần xuống dưới.
    for (var i = 0; i < 6; i++) {
      final t = i / 5;
      final y = 167.0 + i * 7.4;
      final x = 304.0 - math.sin(t * math.pi) * 4 - t * 2;
      final w = 7.4 - t * 1.6;
      final plate = Path()
        ..moveTo(x - w, y + 1)
        ..quadraticBezierTo(x, y - 1.6, x + w, y + 1)
        ..lineTo(x + w * 0.92, y + 5.6)
        ..quadraticBezierTo(x, y + 7.6, x - w * 0.92, y + 5.6)
        ..close();
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
    // Chân trước: vai bắp to, khuỷu gập ra sau, cẳng thon có đai vảy,
    // bàn bốn ngón quặp vuốt sừng bám đống vàng.
    const shoulder = Offset(316, 176);
    const elbow = Offset(325, 197);
    const wrist = Offset(307, 209);
    const foot = Offset(299, 213);
    shadedChain(canvas, [
      (shoulder, elbow, 13, 8),
      (elbow, wrist, 8, 5.4),
      (wrist, foot, 5.4, 5),
    ], FafnirColors.body);
    // Bắp vai: mảng sáng + rãnh cơ.
    canvas.drawPath(
      taperedStroke(
        const [Offset(313, 177), Offset(317, 186), Offset(322, 194)],
        3.4,
        peak: 0.4,
      ),
      fillPaint(lighten(FafnirColors.body, 0.18).withValues(alpha: 0.6)),
    );
    canvas.drawPath(
      taperedStroke(
        const [Offset(321, 180), Offset(325, 189), Offset(326, 196)],
        1.2,
        peak: 0.5,
      ),
      fillPaint(darken(FafnirColors.body, 0.4)),
    );
    // Đai vảy ngang trên cẳng.
    for (var k = 1; k < 5; k++) {
      final p = Offset.lerp(elbow, wrist, k / 5)!;
      canvas.drawArc(
        Rect.fromCircle(center: p + const Offset(1.4, 0.8), radius: 3.6),
        -2.2,
        1.9,
        false,
        Paint()
          ..color = darken(FafnirColors.body, 0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7,
      );
    }
    // Gai cựa sau khuỷu.
    shadedPath(
      canvas,
      taperedStroke(
        [elbow + const Offset(2, -1), elbow + const Offset(8, 2)],
        2.6,
        peak: 0.1,
        startWidth: 1,
      ),
      FafnirColors.horn,
      PartFrame.world,
      shadow: 0.6,
      highlight: 0.3,
      outlineWidth: 0.9,
    );
    // Ngón + vuốt: đốt ngón ngắn rồi vuốt sừng cong cắm xuống vàng.
    for (final (dx, len) in const [
      (-9.0, 4.0),
      (-4.5, 5.0),
      (0.0, 4.6),
      (4.0, 3.4),
    ]) {
      final knuckle = foot + Offset(dx, 1.6);
      final tipToe = knuckle + Offset(-len * 0.7, 2.2);
      shadedPath(
        canvas,
        taperedStroke(
          [foot + Offset(dx * 0.5, 0), knuckle, tipToe],
          3,
          peak: 0.2,
          startWidth: 1,
          endWidth: 0.7,
        ),
        FafnirColors.body,
        PartFrame.world,
        shadow: 0.8,
        highlight: 0.4,
        outlineWidth: 0.9,
      );
      shadedPath(
        canvas,
        taperedStroke(
          [
            tipToe,
            tipToe + const Offset(-1.8, 1.4),
            tipToe + const Offset(-1.6, 4),
          ],
          2,
          peak: 0.1,
          startWidth: 1,
        ),
        FafnirColors.horn,
        PartFrame.world,
        shadow: 0.5,
        highlight: 0.3,
        outlineWidth: 0.8,
      );
    }
  }

  void _neckAndHead(Canvas canvas, BossFrame f, double breathe) {
    final rear = 8 * f.attack;
    final head = Offset(292, 104 - rear + breathe);
    // Cổ cong chữ S phủ vảy, dải vảy bụng chia đốt ở mặt dưới. Hình cổ
    // chỉ phụ thuộc tư thế (làm tròn 1 đơn vị) → ghi sẵn bằng PictureCache.
    final rq = rear.round();
    final bq = breathe.round();
    _neckCache.draw(canvas, (rq, bq), (c) {
      final hq = Offset(292, 104.0 - rq + bq);
      final pts = [
        const Offset(330, 162),
        const Offset(338, 136),
        Offset(310, 122 - rq * 0.5),
        hq + const Offset(10, 2),
      ];
      final b = buildScaleBody(
        pts,
        20,
        peak: 0,
        startWidth: 1,
        endWidth: 0.6,
        samples: 24,
        rows: 2,
        bellySide: -1,
      );
      shadedPath(
        c,
        b.body,
        FafnirColors.body,
        PartFrame.world,
        shadow: 3,
        highlight: 1.3,
        outlineWidth: 1.6,
      );
      c.save();
      c.clipPath(b.body);
      c.drawPath(
        b.scaleDark,
        Paint()
          ..color = darken(FafnirColors.body, 0.38).withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
      c.drawPath(
        b.scaleLit,
        Paint()
          ..color = lighten(FafnirColors.body, 0.35).withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7,
      );
      c.drawPath(
        b.spine,
        fillPaint(darken(FafnirColors.body, 0.3).withValues(alpha: 0.8)),
      );
      c.drawPath(b.belly, fillPaint(FafnirColors.belly));
      c.drawPath(
        b.plates,
        Paint()
          ..color = darken(FafnirColors.belly, 0.3)
          ..strokeWidth = 0.9,
      );
      c.restore();
    });

    canvas.save();
    canvas.translate(head.dx, head.dy);
    canvas.scale(1.25);
    // Đầu chỉ phụ thuộc độ há hàm → ghi sẵn theo 9 mức (đo trên máy thật:
    // dựng đầu mỗi khung tốn ~3 ms CPU); hơi lạnh ở mũi vẽ riêng.
    final aq = (f.attack.clamp(0.0, 1.0) * 8).round();
    _headCache.draw(canvas, aq, (c) => _paintHead(c, aq / 8));
    final puff = (f.time * 0.9) % 1;
    canvas.drawCircle(
      Offset(-36 - 8 * puff, -6 - 6 * puff),
      2 + 4 * puff,
      fillPaint(FafnirColors.snow.withValues(alpha: 0.5 * (1 - puff))),
    );
    canvas.restore();
  }

  static final _headCache = PictureCache<int>(maxEntries: 9);

  /// Đầu Fafnir trong hệ toạ độ đầu (đã dời + phóng 1,25): sừng, hàm dưới
  /// há theo [attack], sọ, nanh, lỗ mũi, mắt.
  void _paintHead(Canvas canvas, double attack) {
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
    canvas.rotate(-0.45 * attack);
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
    if (attack > 0.1) {
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
    // Tấm vảy sọ dọc sống mũi (mặt trên đón sáng, mép sau tối).
    final plateLit = fillPaint(lighten(FafnirColors.body, 0.16));
    for (final (c, w) in const [
      (Offset(-26, -6.2), 3.6),
      (Offset(-21, -8), 4.2),
      (Offset(-15.5, -10.4), 4.6),
      (Offset(-4, -13), 5),
      (Offset(3, -13), 5),
      (Offset(9.5, -10.4), 4.4),
    ]) {
      final p = Path()
        ..moveTo(c.dx - w / 2, c.dy + 0.8)
        ..lineTo(c.dx - w / 2 + 0.8, c.dy - 1)
        ..lineTo(c.dx + w / 2 - 0.4, c.dy - 1.1)
        ..lineTo(c.dx + w / 2, c.dy + 1)
        ..close();
      canvas.drawPath(p, plateLit);
      canvas.drawPath(p, plate);
    }
    // Gờ má xương: khối cơ hàm dưới mắt (bóng dưới gờ), vảy nhỏ li ti.
    canvas.drawPath(
      taperedStroke(
        const [Offset(-16, -2.4), Offset(-6, -1.6), Offset(6, -3.4)],
        3.2,
        peak: 0.5,
      ),
      fillPaint(darken(FafnirColors.body, 0.28).withValues(alpha: 0.6)),
    );
    canvas.drawPath(
      taperedStroke(
        const [Offset(-15, -3.8), Offset(-5, -3.2), Offset(6, -5)],
        1,
        peak: 0.5,
      ),
      fillPaint(lighten(FafnirColors.body, 0.3).withValues(alpha: 0.7)),
    );
    final dot = fillPaint(darken(FafnirColors.body, 0.32));
    for (var k = 0; k < 14; k++) {
      canvas.drawCircle(
        Offset(-2 + (k % 7) * 2.4 + (k ~/ 7) * 1.2, -1 + (k ~/ 7) * 2.2),
        0.55,
        dot,
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
    // Nanh trên lộ ra mép môi cả khi ngậm miệng.
    for (final (x, len) in const [(-27.0, 4.5), (-18.0, 6.0), (-9.0, 3.8)]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, 2.4)
          ..lineTo(x + 2.4, 2.4)
          ..quadraticBezierTo(x + 1.6, 2.4 + len * 0.6, x + 0.6, 2.4 + len)
          ..close(),
        fillPaint(const Color(0xFFF5F9FF)),
      );
    }
    // Lỗ mũi bốc hơi lạnh.
    canvas.drawOval(
      const Rect.fromLTWH(-31, -4.4, 2.6, 1.4),
      fillPaint(VectorStyle.outline),
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

/// Bóng tiếp đất mềm (gradient tròn dẹt, lạnh) dưới boss.
void _groundShadow(Canvas canvas, Offset c, double w, double h) {
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
