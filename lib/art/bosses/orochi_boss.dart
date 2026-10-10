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
    // Mặt trời lặn.
    canvas.drawCircle(
      const Offset(230, 150),
      34,
      fillPaint(const Color(0xFFFFD08A).withValues(alpha: 0.9)),
    );
    // Núi xa nhiều lớp.
    for (final (base, color, phase) in [
      (150.0, const Color(0xFF6A3A55), 0.0),
      (172.0, const Color(0xFF4A2A44), 1.7),
    ]) {
      final path = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 10) {
        path.lineTo(
          x,
          base - 22 * (0.5 + 0.5 * math.sin(x / 55 + phase)).abs(),
        );
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, fillPaint(color));
    }
    // Rặng tuyết tùng.
    final cedar = fillPaint(const Color(0xFF2B1E33));
    for (var i = 0; i < 14; i++) {
      final x = i * 31.0 + (i.isEven ? 4 : 0);
      final top = 150.0 - (i % 4) * 9;
      canvas.drawPath(
        Path()
          ..moveTo(x, top)
          ..lineTo(x - 10, 196)
          ..lineTo(x + 10, 196)
          ..close(),
        cedar,
      );
    }
    // Sông Hi chảy ngang.
    canvas.drawRect(
      const Rect.fromLTRB(0, 192, 400, 208),
      Paint()
        ..shader = Gradient.linear(
          const Offset(0, 192),
          const Offset(0, 208),
          const [Color(0xFFF0B27A), Color(0xFF7A4A6A)],
        ),
    );
    // Bờ đất người chơi đứng.
    canvas.drawRect(
      Rect.fromLTRB(0, stageGroundY - 4, w, h),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, stageGroundY),
          Offset(0, h),
          const [Color(0xFF5A4636), Color(0xFF3A2C24)],
        ),
    );
    // Cổng torii đỏ phía sau người chơi.
    final torii = fillPaint(OrochiColors.torii);
    final ink = fillPaint(VectorStyle.outline);
    for (final x in [24.0, 78.0]) {
      canvas.drawRect(Rect.fromLTWH(x - 1.5, 112, 9, 106), ink);
      canvas.drawRect(Rect.fromLTWH(x, 114, 6, 104), torii);
    }
    canvas.drawRect(const Rect.fromLTWH(12, 104, 82, 9), ink);
    canvas.drawRect(
      const Rect.fromLTWH(13, 105, 80, 7),
      fillPaint(const Color(0xFF2B1E33)),
    );
    canvas.drawRect(const Rect.fromLTWH(16, 122, 74, 7), ink);
    canvas.drawRect(const Rect.fromLTWH(17, 123, 72, 5), torii);
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
        null,
        Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.srcATop),
      );
    }
    canvas.save();
    canvas.translate(0, f.defeat * 40);

    // Cổ và đầu phía xa vẽ trước (đầu số lớn ở xa hơn).
    for (var i = _heads - 1; i >= 0; i--) {
      final head = _headAt(i, f.time) + Offset(0, f.defeat * 30 * (i % 3));
      final severed = i < _severed || f.defeat > 0.5;
      final current = i == _severed && f.defeat == 0;
      _neckPath(canvas, head, severed: severed);
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

  void _neckPath(Canvas canvas, Offset head, {required bool severed}) {
    final end = severed ? Offset.lerp(_base, head, 0.55)! : head;
    final mid = Offset.lerp(_base, end, 0.5)! + const Offset(14, -6);
    final neck = Path()
      ..moveTo(_base.dx, _base.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);
    for (final (width, color) in [
      (17.0, VectorStyle.outline),
      (13.0, OrochiColors.body),
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
    // Sọc bụng sáng chạy dọc cổ.
    canvas.drawPath(
      neck.shift(const Offset(2, 3)),
      Paint()
        ..color = OrochiColors.belly.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _stump(Canvas canvas, Offset head) {
    final at = Offset.lerp(_base, head, 0.55)!;
    canvas.drawOval(
      Rect.fromCenter(center: at, width: 15, height: 10),
      fillPaint(VectorStyle.outline),
    );
    canvas.drawOval(
      Rect.fromCenter(center: at, width: 12, height: 7),
      fillPaint(OrochiColors.stump),
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
        20,
        Paint()
          ..color = const Color(0xFFFFE082).withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    final open = f.attack * 0.5;
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
    // Đầu rắn hướng về người chơi (trái).
    final skull = Path()
      ..moveTo(10, -6)
      ..cubicTo(6, -14, -12, -14, -24, -4)
      ..quadraticBezierTo(-26, 1, -20, 2)
      ..cubicTo(-8, 4, 6, 6, 12, 2)
      ..close();
    shadedPath(
      canvas,
      skull,
      OrochiColors.body,
      PartFrame.world,
      shadow: 2.5,
      highlight: 1.2,
    );
    // Sừng nhỏ.
    shadedPath(
      canvas,
      Path()
        ..moveTo(2, -10)
        ..lineTo(10, -20)
        ..lineTo(7, -9)
        ..close(),
      const Color(0xFFE8DCC0),
      PartFrame.world,
      shadow: 1,
      highlight: 0,
      outlineWidth: 1.2,
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
    const eye = Offset(-10, -6);
    canvas.drawCircle(
      eye,
      5,
      Paint()
        ..color = OrochiColors.eye.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawOval(
      Rect.fromCenter(center: eye, width: 6, height: 4),
      fillPaint(const Color(0xFFFF8A65)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: eye, width: 1.6, height: 4),
      fillPaint(VectorStyle.outline),
    );
    canvas.restore();
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

  void _regrowSparkle(Canvas canvas, Offset head, double t) {
    final paint = fillPaint(const Color(0xFFB9F6CA).withValues(alpha: 1 - t));
    for (var i = 0; i < 6; i++) {
      final a = math.pi * 2 * i / 6 + t * 2;
      canvas.drawCircle(
        head + Offset(math.cos(a), math.sin(a)) * (10 + 16 * t),
        2.4 * (1 - t) + 0.6,
        paint,
      );
    }
  }

  void _bodyMound(Canvas canvas, BossFrame f) {
    final breathe = math.sin(f.time * 1.6) * 2;
    final body = Path()
      ..moveTo(262, stageGroundY + 2)
      ..cubicTo(262, 180 - breathe, 300, 168 - breathe, 335, 170 - breathe)
      ..cubicTo(372, 172 - breathe, 404, 186, 410, stageGroundY + 2)
      ..close();
    shadedPath(
      canvas,
      body,
      OrochiColors.body,
      PartFrame.world,
      shadow: 6,
      highlight: 2,
    );
    // Vảy hình cung.
    final scale = Paint()
      ..color = darken(OrochiColors.body, 0.3)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    for (var row = 0; row < 3; row++) {
      for (var i = 0; i < 7; i++) {
        final x = 282 + i * 16.0 + (row.isOdd ? 8 : 0);
        final y = 184.0 + row * 10 - breathe;
        canvas.drawArc(Rect.fromLTWH(x, y, 14, 9), 0, math.pi, false, scale);
      }
    }
    // Rêu và cây nhỏ mọc trên lưng (như truyền thuyết).
    for (final (x, s) in [(300.0, 1.0), (340.0, 1.3), (378.0, 0.9)]) {
      final top = Offset(x, 168 - breathe - 10 * s);
      canvas.drawRect(
        Rect.fromLTWH(x - 1.2, top.dy, 2.4, 10 * s),
        fillPaint(const Color(0xFF4A3424)),
      );
      shadedPath(
        canvas,
        Path()..addOval(Rect.fromCircle(center: top, radius: 6 * s)),
        OrochiColors.moss,
        PartFrame.world,
        shadow: 1.5,
        highlight: 0.8,
        outlineWidth: 1.2,
      );
    }
  }
}
