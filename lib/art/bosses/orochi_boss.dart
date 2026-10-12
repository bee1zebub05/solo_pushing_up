import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../battle_stage.dart';
import '../nemea_scene.dart' show stageGroundY, stageSize;
import '../vector_style.dart';

/// Bảng màu Kỳ công 5 — Nhật Bản, sông Hi.
abstract final class OrochiColors {
  static const body = Color(0xFF3F5E3A);
  static const belly = Color(0xFFCDB98A);

  /// Bụng đỏ rỉ máu (Kojiki: "bụng nó lúc nào cũng đẫm máu, viêm đỏ").
  static const bloodBelly = Color(0xFFB0473A);
  static const cedar = Color(0xFF2E4A2E);
  static const moss = Color(0xFF6E8F3A);
  static const eye = Color(0xFFFF3B30);
  static const stump = Color(0xFF8E2A2A);
  static const torii = Color(0xFFD2412E);
}

/// Kỳ công 5 — Yamata no Orochi, 8 đầu (rules/cottruyen.md). Đầu đang chém
/// sáng viền và có vòng máu; đầu đã chém còn gốc cổ cụt; đứt combo thì đầu
/// mọc lại có hiệu ứng.
class OrochiBossArt extends BossArt {
  static const _heads = 8;
  static const _base = Offset(330, 196);

  int _severed = 0;
  double _lastHeadHp = 1;
  double _regrowAt = -10;

  /// Hướng (radian) và độ dài cổ của từng đầu; đầu 0 gần người chơi nhất.
  static (double, double) _neck(int i) {
    final a = math.pi * (1.05 + 0.62 * i / (_heads - 1));
    final len = 92.0 + (i % 3) * 14;
    return (a, len);
  }

  static final _neckCache = PictureCache<(int, int, bool)>(maxEntries: 400);

  Offset _headAt(int i, double time) {
    final (a, len) = _neck(i);
    final sway = math.sin(time * 1.3 + i * 0.9) * 5;
    return _base + Offset(math.cos(a) * len + sway, math.sin(a) * len * 0.9);
  }

  double _time = 0;

  @override
  Vector2 get target {
    final p = _headAt(_severed.clamp(0, _heads - 1), _time);
    return Vector2(p.dx, p.dy);
  }

  @override
  Vector2 get portraitFocus => Vector2(268, 120);

  @override
  double get portraitView => 120;

  @override
  List<Color> get hitColors => const [
    OrochiColors.stump,
    Color(0xFFFFE082),
    Color(0xFFFFFFFF),
  ];

  // ---------------------------------------------------------------- nền
  @override
  void paintBackdrop(Canvas canvas) {
    final w = stageSize.width;
    final h = stageSize.height;
    // Hoàng hôn đỏ tím trên Izumo.
    canvas.drawRect(
      Offset.zero & stageSize,
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          const Offset(0, 190),
          const [Color(0xFF3A2350), Color(0xFFB0434A), Color(0xFFF2A65A)],
          const [0, 0.55, 1],
        ),
    );
    // Mặt trời lặn có quầng; mây dải ngang kiểu khắc gỗ, mép dưới hắt nắng.
    const sun = Offset(230, 150);
    canvas.drawCircle(
      sun,
      90,
      Paint()
        ..shader = Gradient.radial(sun, 90, const [
          Color(0x66FFD08A),
          Color(0x00FFD08A),
        ]),
    );
    canvas.drawCircle(
      sun,
      34,
      fillPaint(const Color(0xFFFFD08A).withValues(alpha: 0.95)),
    );
    for (final (x, y, len, thick) in const [
      (40.0, 58.0, 150.0, 7.0),
      (210.0, 44.0, 170.0, 6.0),
      (120.0, 92.0, 190.0, 8.0),
      (280.0, 110.0, 130.0, 5.0),
      (20.0, 124.0, 110.0, 5.0),
    ]) {
      final band = taperedStroke(
        [Offset(x, y), Offset(x + len * 0.4, y - 2), Offset(x + len, y + 1)],
        thick,
        peak: 0.4,
        startWidth: 0.2,
        endWidth: 0.1,
      );
      canvas.drawPath(band, fillPaint(const Color(0xFF5A2E50)));
      canvas.drawPath(
        taperedStroke(
          [
            Offset(x + len * 0.1, y + thick * 0.35),
            Offset(x + len * 0.5, y + thick * 0.3),
            Offset(x + len * 0.9, y + thick * 0.4),
          ],
          thick * 0.3,
          peak: 0.5,
        ),
        fillPaint(const Color(0xCCFFB070)),
      );
    }
    // Núi xa nhiều lớp, sương thung lũng giữa các lớp, cây li ti trên sống.
    final ridgeTrees = math.Random(6);
    for (final (base, color, phase) in [
      (150.0, const Color(0xFF6A3A55), 0.0),
      (172.0, const Color(0xFF4A2A44), 1.7),
    ]) {
      final ridge = <Offset>[];
      for (var x = 0.0; x <= w; x += 10) {
        ridge.add(
          Offset(x, base - 22 * (0.5 + 0.5 * math.sin(x / 55 + phase)).abs()),
        );
      }
      final path = Path()..moveTo(0, h);
      for (final p in ridge) {
        path.lineTo(p.dx, p.dy);
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, fillPaint(color));
      for (final p in ridge) {
        for (var k = 0; k < 2; k++) {
          final t = p + Offset(ridgeTrees.nextDouble() * 10, 1);
          final th = 3 + ridgeTrees.nextDouble() * 3;
          canvas.drawPath(
            Path()
              ..moveTo(t.dx, t.dy - th)
              ..lineTo(t.dx - th * 0.35, t.dy + 1)
              ..lineTo(t.dx + th * 0.35, t.dy + 1)
              ..close(),
            fillPaint(color),
          );
        }
      }
      canvas.drawRect(
        Rect.fromLTRB(0, base - 6, w, base + 14),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, base - 6),
            Offset(0, base + 14),
            const [Color(0x00F2A0A0), Color(0x55F2B090), Color(0x00F2A0A0)],
            const [0, 0.5, 1],
          ),
      );
    }
    // Rừng tuyết tùng (sugi) ngược sáng, mép trái hắt nắng hoàng hôn.
    for (var i = 0; i < 14; i++) {
      final x = i * 31.0 + (i.isEven ? 4 : 0);
      if (x > 240) continue; // phía boss bị thân Orochi che
      _sugi(canvas, Offset(x, 196), 46.0 + (i % 4) * 9);
    }
    // Sông Hi: nước phản chiếu trời, vệt mặt trời lấp lánh.
    canvas.drawRect(
      const Rect.fromLTRB(0, 192, 400, 208),
      Paint()
        ..shader = Gradient.linear(
          const Offset(0, 192),
          const Offset(0, 208),
          const [Color(0xFFF0B27A), Color(0xFF7A4A6A)],
        ),
    );
    final glitter = math.Random(4);
    for (var i = 0; i < 18; i++) {
      final y = 194 + glitter.nextDouble() * 12;
      final half = 3 + (12 - (y - 194)) * 0.8 + glitter.nextDouble() * 4;
      final x = sun.dx + (glitter.nextDouble() - 0.5) * 40;
      canvas.drawLine(
        Offset(x - half, y),
        Offset(x + half, y),
        Paint()
          ..color = const Color(0xCCFFE2A8)
          ..strokeWidth = 0.9,
      );
    }
    for (var i = 0; i < 7; i++) {
      final y = 196.0 + i * 1.8;
      canvas.drawLine(
        Offset(10 + i * 37.0, y),
        Offset(30 + i * 37.0, y),
        Paint()
          ..color = const Color(0x55FFFFFF)
          ..strokeWidth = 0.6,
      );
    }
    // Bờ đất người chơi đứng: đá cuội, cỏ.
    canvas.drawRect(
      Rect.fromLTRB(0, stageGroundY - 4, w, h),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, stageGroundY),
          Offset(0, h),
          const [Color(0xFF5A4636), Color(0xFF3A2C24)],
        ),
    );
    final pebbles = math.Random(12);
    for (var i = 0; i < 30; i++) {
      final c = Offset(
        pebbles.nextDouble() * w,
        stageGroundY + 4 + pebbles.nextDouble() * (h - stageGroundY - 6),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: c,
          width: 3 + pebbles.nextDouble() * 4,
          height: 1.6 + pebbles.nextDouble() * 1.4,
        ),
        fillPaint(const Color(0xFF6E5A48)),
      );
    }
    _torii(canvas);
  }

  /// Cây tuyết tùng Nhật (sugi): thân thẳng, tán nhọn nhiều tầng răng cưa;
  /// ngược sáng nên tối, mép trái hắt nắng cam.
  static void _sugi(Canvas canvas, Offset base, double h) {
    const dark = Color(0xFF2B1E33);
    canvas.drawRect(
      Rect.fromLTWH(base.dx - 1.4, base.dy - h * 0.3, 2.8, h * 0.3),
      fillPaint(const Color(0xFF241826)),
    );
    final crown = Path()..moveTo(base.dx, base.dy - h);
    for (var t = 0; t <= 6; t++) {
      final y = base.dy - h + h * 0.8 * t / 6;
      final w = h * 0.06 + h * 0.2 * t / 6;
      crown
        ..lineTo(base.dx + w, y + h * 0.05)
        ..lineTo(base.dx + w * 0.6, y + h * 0.07);
    }
    for (var t = 6; t >= 0; t--) {
      final y = base.dy - h + h * 0.8 * t / 6;
      final w = h * 0.06 + h * 0.2 * t / 6;
      crown
        ..lineTo(base.dx - w * 0.6, y + h * 0.07)
        ..lineTo(base.dx - w, y + h * 0.05);
    }
    crown.close();
    canvas.drawPath(crown, fillPaint(dark));
    canvas.save();
    canvas.clipPath(crown);
    canvas.drawRect(
      Rect.fromLTWH(base.dx - h * 0.3, base.dy - h, h * 0.22, h),
      Paint()
        ..shader = Gradient.linear(
          Offset(base.dx - h * 0.3, 0),
          Offset(base.dx - h * 0.08, 0),
          const [Color(0x88FF9A5A), Color(0x00FF9A5A)],
        ),
    );
    canvas.restore();
  }

  /// Cổng torii đúng cấu trúc: xà trên (kasagi) cong vểnh hai đầu đen,
  /// xà phụ (shimaki), xà ngang (nuki) xuyên qua cột, trụ giữa (gakuzuka),
  /// cột đỏ có chân đen (nemaki); vân gỗ và bóng một phía.
  static void _torii(Canvas canvas) {
    const red = OrochiColors.torii;
    for (final x in [24.0, 78.0]) {
      final post = Path()
        ..moveTo(x - 0.5, 116)
        ..lineTo(x + 6.5, 116)
        ..lineTo(x + 7.5, 218)
        ..lineTo(x - 1.5, 218)
        ..close();
      shadedPath(
        canvas,
        post,
        red,
        PartFrame.world,
        shadow: 2,
        highlight: 0.8,
        outlineWidth: 1.4,
      );
      shadedPath(
        canvas,
        Path()..addRect(Rect.fromLTWH(x - 2.5, 208, 11, 10)),
        const Color(0xFF241A1E),
        PartFrame.world,
        shadow: 1,
        highlight: 0.4,
        outlineWidth: 1.2,
      );
    }
    // Nuki xuyên ngang hai cột.
    shadedPath(
      canvas,
      Path()..addRect(const Rect.fromLTWH(14, 128, 78, 6)),
      red,
      PartFrame.world,
      shadow: 1.5,
      highlight: 0.6,
      outlineWidth: 1.3,
    );
    // Gakuzuka (trụ giữa) + bảng tên.
    shadedPath(
      canvas,
      Path()..addRect(const Rect.fromLTWH(49, 114, 6, 14)),
      red,
      PartFrame.world,
      shadow: 1,
      highlight: 0.5,
      outlineWidth: 1.1,
    );
    shadedPath(
      canvas,
      Path()..addRect(const Rect.fromLTWH(46, 116, 12, 9)),
      const Color(0xFF2B1E33),
      PartFrame.world,
      shadow: 0.6,
      highlight: 0.3,
      outlineWidth: 1,
    );
    // Shimaki (đỏ) và kasagi (đen) cong vểnh hai đầu.
    shadedPath(
      canvas,
      Path()
        ..moveTo(13, 108)
        ..quadraticBezierTo(53, 111, 93, 108)
        ..lineTo(93, 114)
        ..quadraticBezierTo(53, 117, 13, 114)
        ..close(),
      red,
      PartFrame.world,
      shadow: 1.5,
      highlight: 0.6,
      outlineWidth: 1.3,
    );
    shadedPath(
      canvas,
      Path()
        ..moveTo(4, 99)
        ..quadraticBezierTo(53, 108, 102, 99)
        ..lineTo(101, 104)
        ..quadraticBezierTo(53, 112, 5, 104)
        ..close(),
      const Color(0xFF241A1E),
      PartFrame.world,
      shadow: 1.5,
      highlight: 0.8,
      outlineWidth: 1.3,
    );
    // Viền nắng chiều (bên phải) trên mép cột + bóng xà đổ xuống cột.
    final rim = Paint()
      ..color = const Color(0xAAFFC27A)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (final x in [24.0, 78.0]) {
      canvas.drawLine(Offset(x + 6, 136), Offset(x + 6.9, 206), rim);
      canvas.drawRect(
        Rect.fromLTWH(x - 0.4, 134, 7, 6),
        fillPaint(const Color(0x55301018)),
      );
      // Vân gỗ sơn bong: vài vệt dọc sẫm.
      for (final (dx, y0, len) in const [
        (1.6, 150.0, 18.0),
        (3.8, 172.0, 22.0),
      ]) {
        canvas.drawLine(
          Offset(x + dx, y0),
          Offset(x + dx + 0.2, y0 + len),
          Paint()
            ..color = const Color(0x55601A14)
            ..strokeWidth = 0.6,
        );
      }
    }
    canvas.drawLine(
      const Offset(15, 114.5),
      const Offset(91, 114.5),
      rim..color = const Color(0x88FFC27A),
    );
    // Shimenawa: dây thừng rơm xoắn võng giữa hai cột dưới nuki, giấy
    // shide gấp zigzag trắng rủ xuống.
    final rope = Path()
      ..moveTo(31, 140)
      ..quadraticBezierTo(53, 152, 78, 140);
    canvas.drawPath(
      rope,
      Paint()
        ..color = VectorStyle.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      rope,
      Paint()
        ..color = const Color(0xFFC9A75E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    // Thớ xoắn của dây.
    for (var k = 0; k < 12; k++) {
      final t = (k + 0.5) / 12;
      final x = 31 + 47 * t;
      final y = 140 + 24 * t * (1 - t);
      canvas.drawLine(
        Offset(x - 1, y - 1.2),
        Offset(x + 0.8, y + 1.2),
        Paint()
          ..color = const Color(0xFF8C6E36)
          ..strokeWidth = 0.6,
      );
    }
    for (final t in const [0.25, 0.5, 0.75]) {
      final x = 31 + 47 * t;
      final y = 140 + 24 * t * (1 - t) + 1.5;
      final shide = Path()
        ..moveTo(x - 1.6, y)
        ..lineTo(x + 1.6, y)
        ..lineTo(x + 1.6, y + 3.4)
        ..lineTo(x - 0.4, y + 3.4)
        ..lineTo(x - 0.4, y + 6.8)
        ..lineTo(x + 1.6, y + 6.8)
        ..lineTo(x + 1.6, y + 10.2)
        ..lineTo(x - 1.6, y + 10.2)
        ..lineTo(x - 1.6, y + 7.4)
        ..lineTo(x + 0.4, y + 7.4)
        ..lineTo(x + 0.4, y + 4)
        ..lineTo(x - 1.6, y + 4)
        ..close();
      canvas.drawPath(
        shide,
        Paint()
          ..color = VectorStyle.outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(shide, fillPaint(const Color(0xFFF4EEE2)));
    }
  }

  @override
  void paintAmbient(Canvas canvas, double time) {
    // Sương trôi trên sông.
    for (var i = 0; i < 3; i++) {
      final x = (i * 160 + time * (8 + i * 3)) % 560 - 120;
      canvas.drawOval(
        Rect.fromLTWH(x, 182 + i * 6.0, 150, 12),
        fillPaint(const Color(0x33FFE6D0)),
      );
    }
    // Đom đóm.
    final rnd = math.Random(5);
    for (var i = 0; i < 12; i++) {
      final x = rnd.nextDouble() * 400 + math.sin(time * 0.7 + i) * 8;
      final y = 120 + rnd.nextDouble() * 90 + math.cos(time * 0.9 + i) * 6;
      final a = 0.4 + 0.4 * math.sin(time * 3 + i * 1.7);
      canvas.drawCircle(
        Offset(x, y),
        1.6,
        fillPaint(const Color(0xFFFFF3A0).withValues(alpha: a.clamp(0, 1))),
      );
    }
  }

  // ---------------------------------------------------------------- boss
  @override
  void paintBoss(Canvas canvas, BossFrame f) {
    _time = f.time;
    final b = f.battle;
    final total = b.totalHeads > 1 ? b.totalHeads : _heads;
    _severed = (total - b.headsLeft).clamp(0, _heads);
    // Đầu đang chém hồi đầy máu = mọc lại (đứt combo).
    if (b.headHp > _lastHeadHp + 0.05) _regrowAt = f.time;
    _lastHeadHp = b.headHp;
    final regrow = ((f.time - _regrowAt) / 0.6).clamp(0.0, 1.0);

    final tint = f.hurt > 0
        ? Color.fromRGBO(255, 255, 255, 0.7 * f.hurt)
        : f.defeat > 0
        ? Color.fromRGBO(40, 30, 50, 0.5 * f.defeat)
        : null;
    if (tint != null) {
      canvas.saveLayer(
        const Rect.fromLTRB(150, -60, 440, 280),
        Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.srcATop),
      );
    }
    canvas.save();
    canvas.translate(0, f.defeat * 40);

    _groundShadow(canvas, const Offset(334, stageGroundY + 4), 190, 22);
    // Cổ và đầu phía xa vẽ trước (đầu số lớn ở xa hơn).
    for (var i = _heads - 1; i >= 0; i--) {
      final head = _headAt(i, f.time) + Offset(0, f.defeat * 30 * (i % 3));
      final severed = i < _severed || f.defeat > 0.5;
      final current = i == _severed && f.defeat == 0;
      // Cổ chỉ phụ thuộc vị trí đầu (lắc ngang ±5): ghi sẵn theo vị trí
      // làm tròn 0,5 — đầu vẽ đè lên che chỗ lệch nhỏ ở đỉnh cổ. Đo trên
      // máy thật: dựng 8 cổ mỗi khung tốn ~3 ms CPU.
      final qx = (head.dx * 2).round(), qy = (head.dy * 2).round();
      _neckCache.draw(canvas, (
        qx,
        qy,
        severed,
      ), (c) => _neckPath(c, Offset(qx / 2, qy / 2), severed: severed));
      if (severed) {
        _stump(canvas, head);
      } else {
        final grow = current && regrow < 1 ? 0.5 + 0.5 * regrow : 1.0;
        _head(canvas, head, f, current: current, grow: grow);
        if (current) {
          _hpRing(canvas, head, b.headHp);
          if (regrow < 1) _regrowSparkle(canvas, head, regrow);
        }
      }
    }
    _bodyMound(canvas, f);
    canvas.restore();
    if (tint != null) canvas.restore();
  }

  /// Cổ thon dần từ thân lên đầu, dải vảy bụng sáng chia đốt ở mặt dưới,
  /// sống lưng sẫm ở mặt trên (ít mẫu vì vẽ mỗi khung, 8 cổ).
  void _neckPath(Canvas canvas, Offset head, {required bool severed}) {
    final end = severed ? Offset.lerp(_base, head, 0.55)! : head;
    final mid = Offset.lerp(_base, end, 0.5)! + const Offset(14, -6);
    final pts = [_base, mid, end];
    const width = 16.0;
    final neck = taperedStroke(
      pts,
      width,
      peak: 0,
      startWidth: 1,
      endWidth: severed ? 0.85 : 0.62,
      samples: 12,
    );
    shadedPath(
      canvas,
      neck,
      OrochiColors.body,
      PartFrame.world,
      shadow: 3,
      highlight: 1.2,
      outlineWidth: 1.6,
    );
    // Mặt bụng là phía pháp tuyến hướng xuống đất.
    final d = end - _base;
    final n = Offset(-d.dy, d.dx);
    final bellySide = n.dy > 0 ? 1.0 : -1.0;
    final under = offsetLine(pts, width * 0.27 * bellySide, taper: 0.4);
    canvas.drawPath(
      taperedStroke(
        under,
        width * 0.34,
        peak: 0,
        startWidth: 1,
        endWidth: 0.6,
        samples: 12,
      ),
      fillPaint(OrochiColors.belly),
    );
    final plate = Paint()
      ..color = darken(OrochiColors.belly, 0.35)
      ..strokeWidth = 0.9;
    final line = sampleSmooth(under, 9);
    for (var i = 1; i < line.length - 1; i++) {
      final dd = line[i + 1] - line[i - 1];
      final nn = Offset(-dd.dy, dd.dx) / dd.distance * (width * 0.15);
      canvas.drawLine(line[i] - nn, line[i] + nn, plate);
    }
    canvas.drawPath(
      taperedStroke(
        offsetLine(pts, -width * 0.28 * bellySide, taper: 0.4),
        width * 0.16,
        peak: 0,
        startWidth: 1,
        endWidth: 0.4,
        samples: 12,
      ),
      fillPaint(darken(OrochiColors.body, 0.32)),
    );
  }

  /// Gốc cổ bị chém: mặt cắt nghiêng (ellipse) có vành da vảy sẫm, lớp
  /// thịt đỏ, đốt sống trắng ở giữa; máu sẫm rỉ xuống cổ.
  void _stump(Canvas canvas, Offset head) {
    final at = Offset.lerp(_base, head, 0.55)!;
    final d = head - _base;
    final angle = math.atan2(d.dy, d.dx);
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(angle + math.pi / 2);
    const cut = Rect.fromLTRB(-8.5, -4.5, 8.5, 4.5);
    canvas.drawOval(cut.inflate(1.2), fillPaint(VectorStyle.outline));
    canvas.drawOval(cut, fillPaint(darken(OrochiColors.body, 0.25)));
    canvas.drawOval(cut.deflate(1.6), fillPaint(OrochiColors.stump));
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-1.5, -1), width: 9, height: 3),
      fillPaint(lighten(OrochiColors.stump, 0.25)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0.5, 0.3), width: 4.4, height: 2.6),
      fillPaint(const Color(0xFFF2E6D0)),
    );
    canvas.drawCircle(
      const Offset(0.5, 0.3),
      0.9,
      fillPaint(const Color(0xFF8E2A2A)),
    );
    canvas.restore();
    // Máu rỉ xuống thân cổ (đường thon theo hướng về gốc).
    final dir = (_base - at) / (_base - at).distance;
    canvas.drawPath(
      taperedStroke(
        [
          at + const Offset(2, 2),
          at + dir * 8 + const Offset(3, 3),
          at + dir * 14 + const Offset(2, 4),
        ],
        2.2,
        peak: 0.15,
        startWidth: 1,
      ),
      fillPaint(const Color(0xFF6E1A1A)),
    );
  }

  void _head(
    Canvas canvas,
    Offset at,
    BossFrame f, {
    required bool current,
    required double grow,
  }) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(grow);
    if (current) {
      // Viền sáng cho đầu đang bị chém.
      canvas.drawCircle(
        Offset.zero,
        26,
        Paint()
          ..shader = Gradient.radial(Offset.zero, 26, const [
            Color(0x73FFE082),
            Color(0x00FFE082),
          ]),
      );
    }
    final open = f.attack * 0.5;
    if (open < 0.02) {
      // Ngậm miệng: 8 đầu giống hệt nhau → vẽ ảnh chụp sẵn.
      _headIdle.paint(canvas);
      canvas.restore();
      return;
    }
    _paintHead(canvas, open);
    canvas.restore();
  }

  static final _headIdle = RasterLayer(
    (c) => _paintHead(c, 0),
    bounds: const Rect.fromLTRB(-34, -26, 30, 14),
    resolution: 2,
  );

  /// Đầu rồng-rắn tại gốc toạ độ, hàm mở [open] (radian).
  static void _paintHead(Canvas canvas, double open) {
    // Hàm dưới.
    canvas.save();
    canvas.rotate(-open);
    final jaw = Path()
      ..moveTo(4, 2)
      ..quadraticBezierTo(-10, 8, -22, 4)
      ..lineTo(-20, 1)
      ..close();
    shadedPath(
      canvas,
      jaw,
      OrochiColors.belly,
      PartFrame.world,
      shadow: 1.5,
      highlight: 0.6,
      outlineWidth: 1.4,
    );
    canvas.restore();
    // Sừng cong vuốt ra sau (vẽ trước để sọ che gốc).
    for (final (pts, w) in const [
      ([Offset(0, -9), Offset(9, -17), Offset(19, -19)], 3.4),
      ([Offset(5, -8), Offset(13, -12), Offset(21, -11)], 2.6),
    ]) {
      shadedPath(
        canvas,
        taperedStroke(pts, w, peak: 0.1, startWidth: 1),
        const Color(0xFFE8DCC0),
        PartFrame.world,
        shadow: 1,
        highlight: 0,
        outlineWidth: 1.1,
      );
    }
    // Sọ rồng-rắn hướng về người chơi (trái): mõm dài hơi hếch, gờ mày
    // nặng, má bạnh phía sau.
    final skull = smoothPath(
      const [
        Offset(-27, -1),
        Offset(-24, -5),
        Offset(-15, -8),
        Offset(-9, -12),
        Offset(0, -12.5),
        Offset(9, -9),
        Offset(13, -2),
        Offset(11, 4),
        Offset(0, 5),
        Offset(-14, 3.5),
        Offset(-25, 2.5),
      ],
      closed: true,
      tension: 0.1,
    );
    shadedPath(
      canvas,
      skull,
      OrochiColors.body,
      PartFrame.world,
      shadow: 2.5,
      highlight: 1.2,
    );
    canvas.save();
    canvas.clipPath(skull);
    // Vảy sọ: hai hàng cung nhỏ + môi sáng dọc hàm.
    final plates = Paint()
      ..color = darken(OrochiColors.body, 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var i = 0; i < 6; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(8 - i * 4.0, -8 + i * 0.6), radius: 2.4),
        0.2,
        2.6,
        false,
        plates,
      );
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(6 - i * 4.0, -3.5 + i * 0.4),
          radius: 2.2,
        ),
        0.2,
        2.6,
        false,
        plates,
      );
    }
    canvas.drawPath(
      taperedStroke(
        const [Offset(-26, 1), Offset(-12, 2.6), Offset(4, 3), Offset(11, 1.5)],
        2.6,
        peak: 0.3,
        startWidth: 0.6,
      ),
      fillPaint(OrochiColors.belly),
    );
    canvas.restore();
    // Lỗ mũi.
    canvas.drawOval(
      const Rect.fromLTWH(-26, -3.6, 2.2, 1.3),
      fillPaint(const Color(0xFF1A2414)),
    );
    if (open > 0.05) {
      // Răng nanh khi há miệng.
      for (final x in [-18.0, -12.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(x, 1)
            ..lineTo(x + 2.5, 1)
            ..lineTo(x + 1.2, 6)
            ..close(),
          fillPaint(const Color(0xFFFFF8E7)),
        );
      }
    }
    // Mắt đỏ rực.
    const eye = Offset(-8, -6.5);
    // Mắt đỏ như quả hōzuki: quầng sáng gradient (không blur mỗi khung).
    canvas.drawCircle(
      eye,
      8,
      Paint()
        ..shader = Gradient.radial(eye, 8, [
          OrochiColors.eye.withValues(alpha: 0.7),
          OrochiColors.eye.withValues(alpha: 0),
        ]),
    );
    canvas.drawOval(
      Rect.fromCenter(center: eye, width: 6, height: 4),
      fillPaint(const Color(0xFFFF8A65)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: eye, width: 1.6, height: 4),
      fillPaint(VectorStyle.outline),
    );
    // Gờ mày sụp che nửa trên mắt: ánh nhìn hằm hằm.
    shadedPath(
      canvas,
      Path()
        ..moveTo(-14, -6.5)
        ..quadraticBezierTo(-8, -12.5, -1, -10.5)
        ..lineTo(-2.5, -7.4)
        ..quadraticBezierTo(-8, -8.6, -14, -6.5)
        ..close(),
      darken(OrochiColors.body, 0.2),
      PartFrame.world,
      shadow: 0.8,
      highlight: 0.6,
      outlineWidth: 1,
    );
  }

  void _hpRing(Canvas canvas, Offset head, double hp) {
    final rect = Rect.fromCircle(
      center: head + const Offset(-6, -26),
      radius: 7,
    );
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = const Color(0x88000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * hp.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = Color.lerp(
          const Color(0xFFFF5252),
          const Color(0xFF9CCC65),
          hp,
        )!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Đầu mọc lại: các sợi gân thịt đỏ vươn ra từ cổ, xoắn quanh đầu non
  /// rồi rút vào; máu nhỏ giọt; hơi đỏ toả mờ.
  void _regrowSparkle(Canvas canvas, Offset head, double t) {
    final k = 1 - t;
    canvas.drawCircle(
      head,
      26,
      Paint()
        ..shader = Gradient.radial(head, 26, [
          Color.fromRGBO(200, 40, 40, 0.35 * k),
          const Color.fromRGBO(200, 40, 40, 0),
        ]),
    );
    final sinew = Paint()..color = Color.fromRGBO(170, 40, 40, 0.9 * k);
    final lit = Paint()..color = Color.fromRGBO(255, 150, 140, 0.7 * k);
    for (var i = 0; i < 5; i++) {
      final a = math.pi * 2 * i / 5 + t * 3;
      final reach = 8 + 14 * math.sin(t * math.pi);
      final mid =
          head + Offset(math.cos(a + 0.8), math.sin(a + 0.8)) * reach * 0.6;
      final tip = head + Offset(math.cos(a), math.sin(a)) * reach;
      final pts = [
        head + Offset(math.cos(a - 0.5), math.sin(a - 0.5)) * 3,
        mid,
        tip,
      ];
      canvas.drawPath(
        taperedStroke(pts, 2.4 * k + 0.6, peak: 0.1, startWidth: 1),
        sinew,
      );
      canvas.drawPath(taperedStroke(pts.sublist(0, 2), 0.8 * k + 0.2), lit);
    }
    final drip = (t * 2) % 1;
    canvas.drawCircle(
      head + Offset(2, 10 + 10 * drip),
      1.4 * k,
      fillPaint(Color.fromRGBO(120, 20, 20, k)),
    );
  }

  /// Thân khổng lồ (tĩnh) chụp sẵn: thở chỉ dời ảnh lên xuống.
  static final _bodyImage = RasterLayer(
    _paintBody,
    bounds: const Rect.fromLTRB(236, 120, 436, 252),
    resolution: 1.2,
  );

  void _bodyMound(Canvas canvas, BossFrame f) {
    final breathe = math.sin(f.time * 1.6) * 2;
    canvas.save();
    canvas.translate(0, -breathe * 0.6);
    _bodyImage.paint(canvas);
    canvas.restore();
  }

  /// Ba vòng thân rắn chồng nhau phủ vảy (vòng sau tối hơn), bụng đỏ rỉ
  /// máu, đuôi thòi ra bên phải; trên lưng rêu và tuyết tùng mọc (Kojiki).
  static void _paintBody(Canvas canvas) {
    void coil(
      List<Offset> pts,
      double width,
      Color color, {
      bool belly = true,
      double start = 0.8,
      double end = 0.8,
    }) {
      final b = buildScaleBody(
        pts,
        width,
        startWidth: start,
        endWidth: end,
        belly: belly,
      );
      shadedPath(
        canvas,
        b.body,
        color,
        PartFrame.world,
        shadow: 6,
        highlight: 2,
      );
      canvas.save();
      canvas.clipPath(b.body);
      canvas.drawPath(
        b.scaleDark,
        Paint()
          ..color = darken(color, 0.38).withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      canvas.drawPath(
        b.scaleLit,
        Paint()
          ..color = lighten(color, 0.3).withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
      canvas.drawPath(
        b.spine,
        fillPaint(darken(color, 0.3).withValues(alpha: 0.8)),
      );
      if (belly) {
        canvas.drawPath(b.belly, fillPaint(OrochiColors.bloodBelly));
        canvas.drawPath(
          b.plates,
          Paint()
            ..color = darken(OrochiColors.bloodBelly, 0.35)
            ..strokeWidth = 1,
        );
      }
      canvas.restore();
    }

    final far = darken(OrochiColors.body, 0.18);
    // Đuôi phía sau thòi ra bên phải, cong lên.
    for (final pts in const [
      [Offset(380, 214), Offset(404, 200), Offset(422, 182), Offset(418, 162)],
      [Offset(392, 228), Offset(416, 222), Offset(430, 206)],
    ]) {
      coil(pts, 12, far, belly: false, start: 1, end: 0);
    }
    coil(
      const [
        Offset(262, 230),
        Offset(276, 196),
        Offset(316, 176),
        Offset(360, 178),
        Offset(396, 198),
        Offset(408, 230),
      ],
      34,
      far,
      belly: false,
    );
    coil(
      const [
        Offset(252, 238),
        Offset(272, 214),
        Offset(312, 202),
        Offset(354, 206),
        Offset(390, 220),
        Offset(408, 240),
      ],
      26,
      OrochiColors.body,
    );
    coil(
      const [
        Offset(244, 246),
        Offset(284, 234),
        Offset(334, 232),
        Offset(378, 238),
        Offset(414, 248),
      ],
      20,
      OrochiColors.body,
      start: 0.6,
      end: 0.3,
    );
    // Rêu bám dọc sống lưng vòng sau.
    final moss = math.Random(5);
    for (var i = 0; i < 18; i++) {
      final x = 282 + i * 6.5 + moss.nextDouble() * 3;
      final y =
          178 + math.pow((x - 336) / 60, 2) * 14 - 2 + moss.nextDouble() * 3;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: 7 + moss.nextDouble() * 5,
          height: 3.5,
        ),
        fillPaint(
          i.isEven ? OrochiColors.moss : darken(OrochiColors.moss, 0.2),
        ),
      );
    }
    // Tuyết tùng mọc trên lưng: thân gỗ + các tầng tán răng cưa, tối dần
    // xuống dưới (ánh sáng chiều từ trên–trái).
    for (final (x, h) in const [
      (300.0, 22.0),
      (330.0, 30.0),
      (352.0, 24.0),
      (380.0, 18.0),
    ]) {
      final baseY = 178 + math.pow((x - 336) / 60, 2) * 14;
      canvas.drawRect(
        Rect.fromLTWH(x - 1.2, baseY - h * 0.3, 2.4, h * 0.3 + 2),
        fillPaint(const Color(0xFF4A3424)),
      );
      for (var t = 0; t < 4; t++) {
        final w = h * (0.42 - t * 0.08);
        final top = baseY - h * (0.25 + t * 0.2) - h * 0.22;
        final bottom = top + h * 0.3;
        final tier = Path()
          ..moveTo(x, top)
          ..lineTo(x + w * 0.5, bottom - h * 0.06)
          ..lineTo(x + w * 0.3, bottom - h * 0.08)
          ..lineTo(x + w * 0.62, bottom)
          ..lineTo(x - w * 0.62, bottom)
          ..lineTo(x - w * 0.3, bottom - h * 0.08)
          ..lineTo(x - w * 0.5, bottom - h * 0.06)
          ..close();
        shadedPath(
          canvas,
          tier,
          Color.lerp(OrochiColors.cedar, OrochiColors.moss, t * 0.12)!,
          PartFrame.world,
          shadow: 1.5,
          highlight: 0.8,
          outlineWidth: 1.1,
        );
      }
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
