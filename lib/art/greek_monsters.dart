import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/animation.dart' show Curves;

import 'vector_style.dart';

/// Quái thường vùng Hy Lạp (rules/cottruyen.md mục 3b.1), vẽ theo hình
/// tượng trong thần thoại: chim Stymphalia lông đồng, Spartoi mọc từ răng
/// rồng, Harpy, lợn rừng Erymanthus, Hydra non. Mọi con quay mặt sang trái,
/// gốc toạ độ ở mặt đất giữa thân (chim: tâm thân).
///
/// Tham số chung: [time] giây (thở, đập cánh), [attack] 0–1 (ra đòn),
/// [hurt] 0–1 (trúng đòn: giật lùi, loé trắng).

const _outline = VectorStyle.outline;

Paint _fill(Color c) => Paint()..color = c;

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

void _shaded(Canvas canvas, Path path, Color c, {double shadow = 3}) =>
    shadedPath(canvas, path, c, PartFrame.world, shadow: shadow);

/// Loé trắng khi trúng đòn: bọc cả con quái trong một lớp.
void _withHurt(Canvas canvas, double hurt, void Function() draw) {
  canvas.save();
  canvas.translate(6 * hurt, 0);
  if (hurt > 0) {
    canvas.saveLayer(
      const Rect.fromLTRB(-140, -180, 140, 40),
      Paint()
        ..colorFilter = ColorFilter.mode(
          Color.fromRGBO(255, 255, 255, 0.7 * hurt),
          BlendMode.srcATop,
        ),
    );
  }
  draw();
  if (hurt > 0) canvas.restore();
  canvas.restore();
}

/// Loé trắng khi trúng đòn cho ảnh chụp sẵn (thay lớp của [_withHurt]).
ColorFilter? _hurtFilter(double hurt) => hurt > 0
    ? ColorFilter.mode(
        Color.fromRGBO(255, 255, 255, 0.7 * hurt),
        BlendMode.srcATop,
      )
    : null;

/// Ảnh chụp sẵn từng khung của một con quái theo khoá (pha đập cánh, mức
/// ra đòn…), LRU 24 ảnh; bộ nhớ còn chịu [RasterBudget] chung.
class _FrameCache {
  _FrameCache(this.bounds, {this.resolution = 1});

  final Rect bounds;
  final double resolution;
  final _layers = <Object, RasterLayer>{};

  void paint(
    Canvas canvas,
    Object key,
    void Function(Canvas canvas) draw, {
    ColorFilter? colorFilter,
  }) {
    var layer = _layers.remove(key);
    if (layer == null) {
      layer = RasterLayer(draw, bounds: bounds, resolution: resolution);
      while (_layers.length >= 24) {
        _layers.remove(_layers.keys.first)?.dispose();
      }
    }
    _layers[key] = layer;
    layer.paint(canvas, colorFilter: colorFilter);
  }
}

/// Mắt phát sáng (quy ước boss/quái: mắt có quầng sáng).
void _glowEye(Canvas canvas, Offset at, double r, Color color) {
  canvas.drawCircle(
    at,
    r * 2.6,
    Paint()
      ..shader = Gradient.radial(at, r * 2.6, [
        color.withValues(alpha: 0.55),
        color.withValues(alpha: 0),
      ]),
  );
  canvas.drawCircle(at, r, _fill(color));
  canvas.drawCircle(at, r * 0.45, _fill(const Color(0xFFFFFFE0)));
}

Path _poly(List<Offset> pts) => Path()..addPolygon(pts, true);

// ---------------------------------------------------------------------------
// Chim Stymphalia: mỏ đồng, lông đồng sắc như dao (bắn lông như mũi tên).

const _bronze = Color(0xFFB0793A);
const _bronzeDark = Color(0xFF6E4520);
const _bronzeLight = Color(0xFFF0C27A);

/// [dive] 0–1: cụp cánh lao xuống mổ.
void paintStymphalianBird(
  Canvas canvas, {
  double time = 0,
  double attack = 0,
  double hurt = 0,
}) {
  final flap = math.sin(time * 9) * (1 - attack * 0.8);
  _withHurt(canvas, hurt, () {
    canvas.save();
    canvas.rotate(-0.35 * attack);

    // Cánh xa (tối).
    _wing(canvas, const Offset(4, -2), flap, far: true);

    // Đuôi: bốn lông đồng dài xoè như lưỡi dao.
    for (var i = 3; i >= 0; i--) {
      final a = 0.05 + i * 0.17;
      _blade(
        canvas,
        const Offset(12, -2),
        Offset(
          12 + math.cos(a) * (24 - i * 2),
          -2 + math.sin(a) * (24 - i * 2) - 3,
        ),
        2,
        far: i.isOdd,
      );
    }

    // Thân.
    final body = Path()
      ..moveTo(-12, -6)
      ..cubicTo(-6, -12, 10, -10, 16, -3)
      ..cubicTo(12, 4, -2, 7, -10, 3)
      ..close();
    _shaded(canvas, body, const Color(0xFF4A3A33));
    // Lông vũ xếp ngói (ngọn chĩa ra sau–xuống) + ức phủ vảy đồng sáng.
    canvas.save();
    canvas.clipPath(body);
    final plumage = featherRows(
      const Rect.fromLTRB(-12, -11, 16, 4),
      size: 3.4,
      tipDir: const Offset(1, 0.45),
    );
    canvas.drawPath(plumage.dark, _fill(const Color(0xFF241A16)));
    canvas.drawPath(plumage.lit, _fill(const Color(0x99A07A50)));
    final breast = featherRows(
      const Rect.fromLTRB(-10, -2, 6, 5),
      size: 3,
      tipDir: const Offset(0.3, 1),
    );
    canvas.drawPath(breast.dark, _fill(_bronzeDark));
    canvas.drawPath(breast.lit, _fill(_bronzeLight));
    canvas.restore();

    // Đầu chim săn mồi: sọ thuôn về trước liền với mỏ, gờ mày nhô che
    // mắt (ánh nhìn dữ), mào lông đỏ vuốt ngược ra sau, mỏ đồng hai hàm
    // (hàm dưới há khi lao mổ) với mấu móc ở chóp, da gốc mỏ và lỗ mũi.
    final crest = Paint()..color = const Color(0xFFB3261E);
    final crestDark = Paint()..color = const Color(0xFF6E140F);
    for (var i = 3; i >= 0; i--) {
      final base = Offset(-15 + i * 2.4, -14.2 + i * 0.9);
      final tip = base + Offset(11 + i * 1.5, -8 + i * 1.8);
      final blade = taperedStroke(
        [base, Offset.lerp(base, tip, 0.5)! + const Offset(0, -1.2), tip],
        3 - i * 0.3,
        peak: 0.2,
        startWidth: 0.8,
      );
      canvas.drawPath(blade, _stroke(_outline, 1.2));
      canvas.drawPath(blade, i.isOdd ? crestDark : crest);
    }
    final head = Path()
      ..moveTo(-7, -5)
      ..cubicTo(-7, -12, -10, -15.5, -15, -15.2)
      ..cubicTo(-17.5, -15, -19.5, -13.6, -20.5, -12)
      ..lineTo(-20.5, -6.5)
      ..cubicTo(-18, -4, -12, -2, -7, -5)
      ..close();
    _shaded(canvas, head, const Color(0xFF4A3A33), shadow: 2);
    // Gò má sáng nhẹ dưới mắt.
    canvas.drawPath(
      Path()
        ..moveTo(-19, -8)
        ..quadraticBezierTo(-15, -6.5, -11, -8)
        ..quadraticBezierTo(-15, -5, -19, -6.6)
        ..close(),
      _fill(const Color(0x55A07A50)),
    );
    final gape = 3.5 * attack;
    final upper = Path()
      ..moveTo(-19.5, -13)
      ..quadraticBezierTo(-30 - 4 * attack, -13.4, -35 - 4 * attack, -6.2)
      ..quadraticBezierTo(-33.5 - 4 * attack, -7.6, -31 - 4 * attack, -8.2)
      ..quadraticBezierTo(-25, -8.4, -19.5, -8)
      ..close();
    final lower = Path()
      ..moveTo(-19.5, -8)
      ..quadraticBezierTo(-25, -8 + gape * 0.4, -29.5 - 3 * attack, -7.6 + gape)
      ..quadraticBezierTo(-25, -5 + gape * 0.5, -19.5, -5.8)
      ..close();
    _shaded(canvas, lower, darken(_bronze, 0.15), shadow: 0.8);
    _shaded(canvas, upper, _bronze, shadow: 1.2);
    // Đường sống mỏ sáng + da gốc mỏ (cere) + lỗ mũi.
    canvas.drawPath(
      taperedStroke(
        [
          const Offset(-21, -12.6),
          Offset(-28 - 2 * attack, -12.2),
          Offset(-33 - 4 * attack, -7.8),
        ],
        0.9,
        peak: 0.3,
      ),
      _fill(const Color(0xCCFFF0C8)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-19.5, -13)
        ..quadraticBezierTo(-22.5, -12.8, -23, -10.4)
        ..quadraticBezierTo(-22, -8.4, -19.5, -8.2)
        ..close(),
      _fill(const Color(0xFFD9A441)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-22, -11), width: 1.6, height: 0.8),
      _fill(const Color(0xFF2A1A0E)),
    );
    _glowEye(canvas, const Offset(-15.5, -10.3), 1.5, const Color(0xFFFF3B1F));
    // Gờ mày: nét tối dày đè lên nửa trên con mắt, hất lên phía sau.
    canvas.drawPath(
      taperedStroke(
        const [
          Offset(-19.2, -11.2),
          Offset(-15.5, -12.2),
          Offset(-11.5, -13.4),
        ],
        2.2,
        peak: 0.35,
        startWidth: 0.4,
      ),
      _fill(const Color(0xFF1E1512)),
    );
    canvas.drawPath(
      taperedStroke(
        const [Offset(-18.6, -12.6), Offset(-15.5, -13.8), Offset(-12, -14.6)],
        0.6,
        peak: 0.4,
      ),
      _fill(const Color(0x99A07A50)),
    );

    // Chân chim: cẳng có đốt vảy, ba ngón quặp có vuốt đồng.
    for (final x in [-4.0, 2.0]) {
      final ankle = Offset(x - 1, 10);
      canvas.drawPath(
        taperedStroke(
          [Offset(x, 3), Offset(x - 0.4, 6.5), ankle],
          2.2,
          peak: 0.1,
          startWidth: 1,
          endWidth: 0.6,
        ),
        _fill(const Color(0xFFC9B07A)),
      );
      for (var k = 0; k < 3; k++) {
        final y = 5.0 + k * 1.6;
        canvas.drawLine(
          Offset(x - 1.6, y),
          Offset(x + 0.6, y),
          _stroke(const Color(0xFF7A6440), 0.5),
        );
      }
      for (final a in const [2.4, 1.7, 1.0]) {
        final mid = ankle + Offset(math.cos(a) * 2.6, math.sin(a) * 2.6);
        final tip =
            mid + Offset(math.cos(a + 0.9) * 2.2, math.sin(a + 0.9) * 2.2);
        canvas.drawPath(
          taperedStroke(
            [ankle, mid],
            1.3,
            peak: 0.1,
            startWidth: 1,
            endWidth: 0.7,
          ),
          _fill(const Color(0xFFC9B07A)),
        );
        canvas.drawPath(
          taperedStroke([mid, tip], 1, peak: 0.1, startWidth: 1),
          _fill(_bronze),
        );
      }
    }

    _wing(canvas, const Offset(0, -4), flap);
    canvas.restore();

    // Bắn lông đồng như mũi tên (thần thoại): ba lông dao lao chéo xuống
    // trước, có vệt sáng phía sau.
    if (attack > 0.2) {
      final k = (attack - 0.2) / 0.8;
      for (var i = 0; i < 3; i++) {
        final start = Offset(-6.0 - i * 3, 2.0 + i * 3);
        final dir = Offset(-0.85, 0.45 + i * 0.12);
        final tip = start + dir * (14 + 26 * k);
        canvas.drawLine(
          tip - dir * 26,
          tip - dir * 9,
          _stroke(Color.fromRGBO(255, 210, 140, 0.45 * k), 1.4),
        );
        _blade(canvas, tip - dir * 9, tip, 1.6);
      }
    }
  });
}

/// Chim Stymphalia trong trận: ảnh chụp sẵn theo 12 pha đập cánh × 7 mức
/// ra đòn. Đo trên máy thật: 5 con vẽ vector mỗi khung làm màn đàn chim
/// chỉ còn ~28 fps (CPU 26 ms dựng lông vũ + GPU 26 ms).
void paintStymphalianBirdFast(
  Canvas canvas, {
  double time = 0,
  double attack = 0,
  double hurt = 0,
}) {
  const period = 2 * math.pi / 9;
  final phase = (time / period * 12).floor() % 12;
  final aq = (attack.clamp(0.0, 1.0) * 6).round();
  canvas.save();
  canvas.translate(6 * hurt, 0);
  _birdImages.paint(
    canvas,
    (phase, aq),
    (c) => paintStymphalianBird(c, time: phase / 12 * period, attack: aq / 6),
    colorFilter: _hurtFilter(hurt),
  );
  canvas.restore();
}

final _birdImages = _FrameCache(
  const Rect.fromLTRB(-64, -44, 54, 50),
  resolution: 1.15,
);

void _wing(Canvas canvas, Offset root, double flap, {bool far = false}) {
  canvas.save();
  canvas.translate(root.dx, root.dy);
  canvas.rotate(-0.6 * flap - (far ? 0.25 : 0));
  // Cánh là dãy lông đồng hình lưỡi dao, mỗi lưỡi ánh kim riêng.
  for (var i = 5; i >= 0; i--) {
    final a = -math.pi / 2 - 0.5 + i * 0.22;
    final len = 22.0 - i * 1.6;
    final tip = Offset(math.cos(a) * len + 6, math.sin(a) * len);
    _blade(canvas, Offset(i * 2.0 - 1, -1), tip, 2.2, far: far);
  }
  // Lông bao cánh (coverts): hai hàng lông đồng ngắn phủ gốc lông bay,
  // hàng trong ngắn hơn — cánh có cấu trúc như cánh chim thật.
  for (var row = 1; row >= 0; row--) {
    for (var i = 4; i >= 0; i--) {
      final a = -math.pi / 2 - 0.42 + i * 0.26;
      final root = Offset(i * 2.2 - 1, -1);
      final len = (row == 0 ? 7.0 : 11.0) - i * 0.5;
      final tip = root + Offset(math.cos(a) * len + 2, math.sin(a) * len);
      _blade(canvas, root, tip, row == 0 ? 1.8 : 2, far: far || row == 1);
    }
  }
  canvas.restore();
}

/// Một lông đồng sắc như lưỡi dao: gốc rộng [width], thuôn nhọn tới [tip],
/// ánh kim chuyển từ sáng (gốc, mép đón nắng) tới sẫm (ngọn).
void _blade(
  Canvas canvas,
  Offset base,
  Offset tip,
  double width, {
  bool far = false,
}) {
  final d = tip - base;
  final n = Offset(-d.dy, d.dx) / d.distance;
  final blade = Path()
    ..moveTo(base.dx + n.dx * width, base.dy + n.dy * width)
    ..quadraticBezierTo(
      base.dx + d.dx * 0.6 + n.dx * width * 0.9,
      base.dy + d.dy * 0.6 + n.dy * width * 0.9,
      tip.dx,
      tip.dy,
    )
    ..lineTo(base.dx - n.dx * width, base.dy - n.dy * width)
    ..close();
  canvas.drawPath(blade, _stroke(_outline, 1.6));
  final colors = far
      ? const [_bronze, _bronzeDark, Color(0xFF3E2410)]
      : const [_bronzeLight, _bronze, _bronzeDark];
  canvas.drawPath(
    blade,
    Paint()..shader = Gradient.linear(base, tip, colors, const [0, 0.45, 1]),
  );
  // Sống lông sáng loáng.
  if (!far) {
    canvas.drawLine(
      base,
      Offset.lerp(base, tip, 0.8)!,
      _stroke(const Color(0xCCFFF0C8), 0.6),
    );
  }
}

// ---------------------------------------------------------------------------
// Spartoi: chiến binh xương mọc lên từ răng rồng.

/// [rise] 0–1: trồi lên từ đất (0 = còn dưới đất).
void paintSpartoi(
  Canvas canvas, {
  double time = 0,
  double attack = 0,
  double hurt = 0,
  double rise = 1,
}) {
  // Bóng tiếp đất, đậm dần khi trồi lên.
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(6, 1), width: 52, height: 8),
    _fill(Color.fromRGBO(48, 28, 48, 0.3 * rise)),
  );
  canvas.save();
  // Phần dưới đất bị che bằng vùng cắt.
  canvas.clipRect(const Rect.fromLTRB(-80, -140, 80, 1));
  canvas.translate(0, 78 * (1 - rise));
  // Thân chụp sẵn theo 24 pha lắc × 9 mức đâm giáo (đo trên máy thật:
  // vẽ vector mỗi khung tốn ~4 ms CPU); mắt lửa nhấp nháy vẽ riêng.
  canvas.translate(6 * hurt, 0);
  const period = 2 * math.pi / 1.8;
  final phase = (time / period * 24).floor() % 24;
  final lq = (attack.clamp(0.0, 1.0) * 8).round();
  final qSway = math.sin(phase / 24 * period * 1.8) * 1.2;
  _spartoiFrames.paint(
    canvas,
    (phase, lq),
    (c) => _spartoiBody(c, qSway, lq / 8),
    colorFilter: _hurtFilter(hurt),
  );
  final headC = Offset(-1 + qSway * 0.4 - 4 * lq / 8, -76);
  canvas.save();
  canvas.translate(headC.dx, headC.dy);
  // Hai đốm lửa ma quái trong khe mắt (nhấp nháy theo thời gian).
  final flicker = 0.85 + 0.15 * math.sin(time * 9);
  _glowEye(
    canvas,
    const Offset(-6.2, -2.2),
    1.1 * flicker,
    const Color(0xFF7CFF6B),
  );
  canvas.restore();
  canvas.restore();

  // Đất bung lên khi đang trồi.
  if (rise < 1) {
    final dirt = _fill(const Color(0xFF7A5534));
    for (var i = 0; i < 6; i++) {
      final a = math.pi + i * math.pi / 5;
      final d = 10 + 16 * rise;
      canvas.drawCircle(
        Offset(math.cos(a) * d, math.sin(a) * d * 0.6 - 2),
        2.2,
        dirt,
      );
    }
  }
}

final _spartoiFrames = _FrameCache(
  const Rect.fromLTRB(-96, -116, 52, 8),
  resolution: 1.35,
);

/// Thân Spartoi (không bóng đất, không trồi, không loé trúng đòn, không
/// mắt lửa) — phần được chụp thành ảnh.
void _spartoiBody(Canvas canvas, double sway, double lunge) {
  const bone = Color(0xFFD9D2B8);
  const bronze = Color(0xFFB98A3E);
  // Chân xương: xương đùi đầu khớp phình, cẳng chân hai xương (chày +
  // mác), bàn chân xương nhỏ.
  for (final (hip, knee, ankle, c) in [
    (
      const Offset(6, -34),
      const Offset(10, -16),
      const Offset(12, -2),
      darken(bone, 0.15),
    ),
    (
      const Offset(-4, -34),
      const Offset(-10, -16),
      const Offset(-12, -2),
      bone,
    ),
  ]) {
    _shaded(
      canvas,
      _bonePath(knee + const Offset(1.2, 1), ankle + const Offset(1.4, 0), 2.2),
      darken(c, 0.2),
      shadow: 0.8,
    );
    _shaded(canvas, _bonePath(hip, knee, 4.2), c, shadow: 1.2);
    _shaded(canvas, _bonePath(knee, ankle, 3.6), c, shadow: 1.2);
    _shaded(
      canvas,
      Path()..addRRect(
        RRect.fromLTRBR(
          ankle.dx - 6,
          ankle.dy - 1.5,
          ankle.dx + 2.5,
          ankle.dy + 2,
          const Radius.circular(1.6),
        ),
      ),
      c,
      shadow: 0.8,
    );
  }
  // Váy giáp da (pteruges).
  final skirt = Path();
  for (var i = 0; i < 5; i++) {
    skirt.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-11 + i * 4.6, -38, 4.4, 11),
        const Radius.circular(1.5),
      ),
    );
  }
  _shaded(canvas, skirt, const Color(0xFF7A3B2A), shadow: 1.5);
  // Tay cầm khiên (xa, sau thân) và khiên tròn hoplon có hình răng rồng.
  shadedChain(canvas, [
    (const Offset(10, -60), const Offset(14, -46), 3, 2.5),
  ], darken(bone, 0.15));
  // Khiên aspis: vành đồng rộng có gờ, mặt sơn đỏ bạc màu, hình răng
  // rồng trắng ngà (Spartoi mọc từ răng rồng), vết chém và đồng xỉn.
  final sc = Offset(8 + sway * 0.3, -46);
  final shield = Path()..addOval(Rect.fromCircle(center: sc, radius: 17));
  _shaded(canvas, shield, bronze, shadow: 4);
  final face = Path()..addOval(Rect.fromCircle(center: sc, radius: 13.4));
  _shaded(canvas, face, const Color(0xFF8E2A1E), shadow: 3);
  canvas.save();
  canvas.clipPath(face);
  canvas.drawCircle(sc + const Offset(5, 5), 9, _fill(const Color(0x33000000)));
  final tooth = Path()
    ..moveTo(sc.dx - 4, sc.dy - 8)
    ..quadraticBezierTo(sc.dx, sc.dy - 10, sc.dx + 4, sc.dy - 8)
    ..quadraticBezierTo(sc.dx + 2.6, sc.dy + 2, sc.dx + 0.4, sc.dy + 9)
    ..quadraticBezierTo(sc.dx - 2, sc.dy + 2, sc.dx - 4, sc.dy - 8)
    ..close();
  canvas.drawPath(tooth, _fill(const Color(0xFFE8DCC0)));
  canvas.drawLine(
    sc + const Offset(-1, -7),
    sc + const Offset(0.2, 6),
    _stroke(const Color(0xFFB8A888), 0.8),
  );
  canvas.drawLine(
    sc + const Offset(-10, 2),
    sc + const Offset(-4, 8),
    _stroke(const Color(0xFF4A160E), 1),
  );
  canvas.restore();
  canvas.drawCircle(sc, 15.2, _stroke(darken(bronze, 0.35), 0.8));
  for (final (o, r) in const [(Offset(-11, -9), 1.6), (Offset(12, 6), 2.0)]) {
    canvas.drawCircle(sc + o, r, _fill(const Color(0x664FA088)));
  }

  // Cột sống từng đốt + xương sườn cong thon lộ ra dưới giáp vỡ, khoang
  // ngực tối phía sau.
  canvas.drawPath(
    Path()
      ..moveTo(-11, -56)
      ..quadraticBezierTo(0, -60, 11, -56)
      ..quadraticBezierTo(8, -42, 0, -40)
      ..quadraticBezierTo(-8, -42, -11, -56)
      ..close(),
    _fill(const Color(0xFF1E1410)),
  );
  for (var i = 0; i < 6; i++) {
    final y = -60.0 + i * 3.8;
    _shaded(
      canvas,
      Path()..addRRect(
        RRect.fromLTRBR(-2.2, y, 2.2, y + 3, const Radius.circular(1.2)),
      ),
      bone,
      shadow: 0.6,
    );
  }
  final ribs = Path();
  for (var i = 0; i < 4; i++) {
    final y = -56.0 + i * 4.2;
    final w = 11.5 - i * 1.6;
    for (final side in [-1.0, 1.0]) {
      ribs.addPath(
        taperedStroke(
          [
            Offset(side * 1.5, y),
            Offset(side * w * 0.8, y - 1.2),
            Offset(side * w, y + 2.5),
            Offset(side * (w - 2.5), y + 5.5),
          ],
          2.1,
          peak: 0.3,
          startWidth: 0.9,
          endWidth: 0.3,
        ),
        Offset.zero,
      );
    }
  }
  _shaded(canvas, ribs, bone, shadow: 0.6);
  // Hai cánh xương chậu nhô trên váy giáp.
  for (final side in [-1.0, 1.0]) {
    _shaded(
      canvas,
      Path()
        ..moveTo(side * 1.5, -37)
        ..quadraticBezierTo(side * 4, -42, side * 8.5, -40.5)
        ..quadraticBezierTo(side * 7, -37, side * 1.5, -36)
        ..close(),
      darken(bone, 0.18),
      shadow: 0.8,
    );
  }
  // Giáp ngực đồng vỡ: chỉ còn nửa trên, mép dưới lởm chởm.
  final chest = Path()
    ..moveTo(-14, -62)
    ..quadraticBezierTo(0, -68, 14, -62)
    ..lineTo(13, -54)
    ..lineTo(9, -51)
    ..lineTo(6, -55)
    ..lineTo(1, -50)
    ..lineTo(-4, -54)
    ..lineTo(-9, -50)
    ..lineTo(-13, -54)
    ..close();
  _shaded(canvas, chest, bronze, shadow: 3);
  canvas.drawPath(
    Path()
      ..moveTo(4, -64)
      ..lineTo(1, -58)
      ..lineTo(5, -54),
    _stroke(_outline, 1.1),
  );
  // Đầu sọ trong mũ Corinth có mào lông đỏ.
  final headC = Offset(-1 + sway * 0.4 - 4 * lunge, -76);
  canvas.save();
  canvas.translate(headC.dx, headC.dy);
  _corinthianHelmet.paint(canvas);
  canvas.restore();

  // Tay cầm giáo (gần): đâm tới khi tấn công.
  final hand = Offset(-14 - 14 * lunge, -52 + 4 * lunge);
  final elbow = Offset(-14 - 6 * lunge, -52);
  _shaded(
    canvas,
    _bonePath(const Offset(-10, -60), elbow, 3.2),
    bone,
    shadow: 1,
  );
  _shaded(canvas, _bonePath(elbow, hand, 2.8), bone, shadow: 1);
  // Giáo dory cầm thấp chĩa về người chơi: cán gỗ, mũi đồng hình lá có
  // gân giữa, chuôi nhọn (sauroter) ở đuôi.
  final spearBack = hand + const Offset(30, -12);
  final spearTip = hand + Offset(-30 - 10 * lunge, 2);
  canvas.drawLine(spearBack, spearTip, _stroke(_outline, 3.4));
  canvas.drawLine(spearBack, spearTip, _stroke(const Color(0xFF7A5232), 1.8));
  final dir = (spearTip - spearBack) / (spearTip - spearBack).distance;
  final n = Offset(-dir.dy, dir.dx);
  final leaf = Path()
    ..moveTo(spearTip.dx, spearTip.dy)
    ..quadraticBezierTo(
      spearTip.dx + dir.dx * 4 + n.dx * 3.6,
      spearTip.dy + dir.dy * 4 + n.dy * 3.6,
      spearTip.dx + dir.dx * 12,
      spearTip.dy + dir.dy * 12,
    )
    ..quadraticBezierTo(
      spearTip.dx + dir.dx * 4 - n.dx * 3.6,
      spearTip.dy + dir.dy * 4 - n.dy * 3.6,
      spearTip.dx,
      spearTip.dy,
    )
    ..close();
  _shaded(canvas, leaf, bronze, shadow: 1);
  canvas.drawLine(
    spearTip,
    spearTip + dir * 10,
    _stroke(darken(bronze, 0.35), 0.6),
  );
  _shaded(
    canvas,
    _poly([spearBack + n * 1.4, spearBack - dir * 6, spearBack - n * 1.4]),
    bronze,
    shadow: 0.6,
  );
}

/// Một xương dài: thân mảnh thắt giữa, hai đầu khớp phình hai núm (lồi
/// cầu) — đọc ra ngay là xương chứ không phải ống.
Path _bonePath(Offset a, Offset b, double w) {
  final d = b - a;
  final len = d.distance;
  if (len == 0) return Path();
  final dir = d / len;
  final n = Offset(-dir.dy, dir.dx);
  final mid = Offset.lerp(a, b, 0.5)!;
  var path = Path()
    ..addPolygon([
      a + n * (w * 0.32),
      mid + n * (w * 0.2),
      b + n * (w * 0.32),
      b - n * (w * 0.32),
      mid - n * (w * 0.2),
      a - n * (w * 0.32),
    ], true);
  for (final (end, inward) in [(a, dir), (b, -dir)]) {
    for (final side in [-1.0, 1.0]) {
      final knob = Path()
        ..addOval(
          Rect.fromCircle(
            center: end + n * (side * w * 0.22) + inward * (w * 0.12),
            radius: w * 0.34,
          ),
        );
      path = Path.combine(PathOperation.union, path, knob);
    }
  }
  return path;
}

/// Mũ Corinth bằng đồng nhìn 3/4 (quay trái): vòm tròn, chắn mũi dài,
/// hai má che kín chừa khe dọc lộ hàm xương, khe mắt hạnh nhân, gờ mày nổi,
/// mép viền sáng, gỉ đồng xanh; mào lông ngựa đỏ trên giá, rủ ra sau.
/// Tĩnh → chụp sẵn; gốc toạ độ ở tâm đầu.
final _corinthianHelmet = RasterLayer(
  (canvas) => _paintCorinthian(
    canvas,
    metal: const Color(0xFFB98A3E),
    crest: const Color(0xFFB3261E),
    crestDark: const Color(0xFF6E1410),
    crestLit: const Color(0x99FF8A70),
    mouth: const Color(0xFFD9D2B8),
    patina: const Color(0x664FA088),
  ),
  bounds: const Rect.fromLTRB(-16, -34, 32, 18),
  resolution: 2.5,
);

/// Cùng kiểu mũ nhưng tạc bằng đá cẩm thạch (lính tượng đá): mào là đá
/// tạc thành lọn, khe miệng tối, vết loang là rêu.
final _stoneHelmet = RasterLayer(
  (canvas) => _paintCorinthian(
    canvas,
    metal: const Color(0xFFD9D3C7),
    crest: const Color(0xFFB4AC9E),
    crestDark: const Color(0xFF7E7668),
    crestLit: const Color(0x99FFFFFF),
    mouth: const Color(0xFF2A2230),
    patina: const Color(0x667A9A5A),
  ),
  bounds: const Rect.fromLTRB(-16, -34, 32, 18),
  resolution: 2.5,
);

void _paintCorinthian(
  Canvas canvas, {
  required Color metal,
  required Color crest,
  required Color crestDark,
  required Color crestLit,
  required Color mouth,
  required Color patina,
}) {
  final bronze = metal;
  final bone = mouth;
  // Mào: lọn lông ngựa dọc một vòng cung, mỗi lọn rủ ra sau – xuống.
  Offset arch(double u) {
    const p0 = Offset(-9, -11);
    const p1 = Offset(2, -30);
    const p2 = Offset(17, -9);
    return p0 * ((1 - u) * (1 - u)) + p1 * (2 * u * (1 - u)) + p2 * (u * u);
  }

  final crestPath = Path();
  final creases = <List<Offset>>[];
  for (var i = 0; i <= 14; i++) {
    final u = i / 14;
    final root = arch(u);
    final len = 5 + 7 * u;
    final lock = [
      root + const Offset(-1, 1),
      root + Offset(2 + len * 0.4, -1.5 + len * 0.2),
      root + Offset(2.5 + len * 0.7, len * 0.6),
    ];
    crestPath.addPath(
      taperedStroke(lock, 4.4, peak: 0.25, startWidth: 0.9),
      Offset.zero,
    );
    creases.add(lock);
  }
  _shaded(canvas, crestPath, crest, shadow: 2);
  canvas.save();
  canvas.clipPath(crestPath);
  for (final l in creases) {
    canvas.drawPath(
      taperedStroke([for (final p in l) p + const Offset(1.2, 1)], 1.3),
      _fill(crestDark),
    );
    canvas.drawPath(
      taperedStroke([
        for (final p in l.take(2)) p + const Offset(-0.6, -0.8),
      ], 0.8),
      _fill(crestLit),
    );
  }
  canvas.restore();
  // Giá đỡ mào.
  canvas.drawPath(
    taperedStroke(
      [
        arch(0.05) + const Offset(0, 2),
        arch(0.45) + const Offset(0, 4),
        arch(0.95) + const Offset(-1, 3),
      ],
      2.2,
      peak: 0.5,
      startWidth: 0.8,
      endWidth: 0.8,
    ),
    _fill(darken(bronze, 0.3)),
  );
  // Khe dọc giữa hai má: lộ hàm và răng xương.
  canvas.drawRect(
    const Rect.fromLTRB(-6, 2, -1, 12),
    _fill(const Color(0xFF120C08)),
  );
  canvas.drawRect(const Rect.fromLTRB(-5.5, 5, -1.5, 10), _fill(bone));
  for (var i = 0; i < 3; i++) {
    canvas.drawLine(
      Offset(-5 + i * 1.4, 5),
      Offset(-5 + i * 1.4, 7.6),
      _stroke(_outline, 0.5),
    );
  }
  // Vỏ mũ: vòm + chắn mũi + má trước + má sau, gáy loe.
  final shell = Path()
    ..moveTo(-12, -4)
    ..cubicTo(-12, -14, 4, -18, 10, -9)
    ..quadraticBezierTo(13, -2, 11, 6)
    ..quadraticBezierTo(13, 11, 14, 13)
    ..lineTo(4, 13)
    ..quadraticBezierTo(0, 12, -1, 7)
    ..lineTo(-1, 2)
    ..lineTo(-6, 2)
    ..lineTo(-6, 7)
    ..quadraticBezierTo(-8, 11, -10, 12)
    ..quadraticBezierTo(-12, 6, -11, 1)
    ..lineTo(-12.5, 0.5)
    ..close();
  final eyeHole = Path()
    ..moveTo(-10.4, -2)
    ..quadraticBezierTo(-6.5, -5, -2.5, -2.8)
    ..quadraticBezierTo(-6, -0.4, -10.4, -2)
    ..close();
  final helmet = Path.combine(PathOperation.difference, shell, eyeHole);
  _shaded(canvas, helmet, bronze, shadow: 3);
  canvas.drawPath(eyeHole, _fill(const Color(0xFF120C08)));
  canvas.save();
  canvas.clipPath(helmet);
  // Gỉ đồng xanh loang ở mép dưới.
  for (final (c, r) in [
    (const Offset(9, 10), 3.0),
    (const Offset(-9, 10), 2.2),
    (const Offset(6, -12), 1.6),
  ]) {
    canvas.drawCircle(c, r, _fill(patina));
  }
  // Gờ mày nổi: đường sáng trên, tối dưới.
  canvas.drawPath(
    taperedStroke(const [
      Offset(-11, -4.6),
      Offset(-6.5, -6.6),
      Offset(-1.5, -4.4),
    ], 1.4),
    _fill(lighten(bronze, 0.45)),
  );
  canvas.drawPath(
    taperedStroke(const [
      Offset(-11.2, -3),
      Offset(-6.5, -5.4),
      Offset(-1.8, -3.2),
    ], 0.9),
    _fill(darken(bronze, 0.4)),
  );
  // Mép viền sáng quanh mũ (đường gò đồng).
  canvas.drawPath(
    Path()
      ..moveTo(10.5, -6)
      ..quadraticBezierTo(12.4, 0, 10.4, 6)
      ..quadraticBezierTo(12, 10.5, 13, 12),
    _stroke(lighten(bronze, 0.4), 0.9),
  );
  canvas.restore();
  glint(canvas, const Offset(-4, -10), 2);
}

// ---------------------------------------------------------------------------
// Harpy: mình chim mặt người, cánh thay tay, móng quắp.

/// [stealing]: đang quắp túi vàng của người chơi bay đi (cướp vàng khi
/// người chơi nghỉ quá lâu — rules/cottruyen.md mục 3b.1).
void paintHarpy(
  Canvas canvas, {
  double time = 0,
  double attack = 0,
  double hurt = 0,
  bool stealing = false,
}) {
  final hover = math.sin(time * 3) * 3;
  // Bóng mờ trên đất (đang bay): nhỏ và nhạt — báo độ cao.
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(4, 1), width: 34 - hover, height: 6),
    _fill(const Color(0x30402A50)),
  );
  canvas.save();
  canvas.translate(0, -60 + hover);
  // Thân chụp sẵn theo 12 pha đập cánh × 7 mức ra đòn (tóc, đuôi, lông
  // cổ cùng nhịp cánh nên vòng lặp liền mạch). Đo trên máy thật: vẽ
  // vector Harpy mỗi khung làm màn tụt còn ~40 fps.
  canvas.translate(6 * hurt, 0);
  const period = 2 * math.pi / 6;
  final phase = (time / period * 12).floor() % 12;
  final aq = (attack.clamp(0.0, 1.0) * 6).round();
  _harpyFrames.paint(
    canvas,
    (phase, aq),
    (c) => _harpyBody(c, phase / 12 * period, aq / 6),
    colorFilter: _hurtFilter(hurt),
  );
  paintHarpyExtras(canvas, time: time, attack: attack, stealing: stealing);
  canvas.restore();
}

/// Phần đọc nhịp của Harpy vẽ đè lên thân (dùng cho cả bản sprite Blender):
/// túi vàng quắp ở móng khi [stealing] (cướp vàng, màn 1.5) và vòng sóng
/// rít tím toả từ miệng khi vồ. Toạ độ theo thân Harpy bản vector: mặt ở
/// (-2, -26), móng chân quanh (0, 32).
void paintHarpyExtras(
  Canvas canvas, {
  double time = 0,
  double attack = 0,
  bool stealing = false,
}) {
  const face = Offset(-2, -26);
  if (stealing) _goldPouch(canvas, time);
  // Tiếng rít: vòng sóng âm toả ra từ miệng khi vồ.
  if (attack > 0.3) {
    for (var i = 0; i < 3; i++) {
      final r = 6.0 + i * 6 + (time * 30) % 6;
      canvas.drawArc(
        Rect.fromCircle(center: face + const Offset(-6, 4), radius: r),
        math.pi * 0.7,
        math.pi * 0.6,
        false,
        _stroke(Color.fromRGBO(220, 200, 255, 0.7 * attack * (1 - i / 3)), 1.2),
      );
    }
  }
}

final _harpyFrames = _FrameCache(
  const Rect.fromLTRB(-44, -80, 80, 48),
  resolution: 1.5,
);

/// Thân Harpy (không bóng đất, không lơ lửng, không loé trúng đòn) — phần
/// được chụp thành ảnh theo pha đập cánh.
void _harpyBody(Canvas canvas, double time, double attack) {
  const feather = Color(0xFF5B4A66);
  const skin = Color(0xFFB9B3A2);
  final flap = math.sin(time * 6);
  // Cánh xa.
  _harpyWing(canvas, const Offset(6, -16), flap, darken(feather, 0.25));
  // Đuôi lông rách tả tơi.
  final tail = Path();
  for (var i = 0; i < 5; i++) {
    final root = Offset(2 + i * 1.8, 10);
    final tip = Offset(9 + i * 4.5, 31 - i * 2.4 + math.sin(time * 6 + i));
    tail.addPath(
      taperedStroke(
        [root, Offset.lerp(root, tip, 0.5)! + const Offset(1.5, 0), tip],
        4,
        peak: 0.35,
        startWidth: 0.7,
      ),
      Offset.zero,
    );
  }
  _shaded(canvas, tail, darken(feather, 0.1), shadow: 1.5);
  // Thân lông chim.
  final body = Path()
    ..moveTo(-8, -18)
    ..cubicTo(-14, -6, -10, 10, 0, 14)
    ..cubicTo(10, 12, 14, -2, 8, -18)
    ..close();
  _shaded(canvas, body, feather, shadow: 3);
  // Lông vũ xếp lớp như ngói, ngọn chĩa xuống: mép dưới tối, sống lông
  // sáng; lông ngực sáng hơn lông lưng.
  canvas.save();
  canvas.clipPath(body);
  final rowDark = _fill(darken(feather, 0.38));
  final rowLit = _fill(lighten(feather, 0.28).withValues(alpha: 0.8));
  for (var row = 0; row < 6; row++) {
    final y = -16.0 + row * 5;
    for (var col = -3; col <= 3; col++) {
      final x = col * 3.6 + (row.isOdd ? 1.8 : 0);
      final top = Offset(x, y);
      final tip = Offset(x - 0.6, y + 5.2);
      canvas.drawPath(
        taperedStroke(
          [
            top + const Offset(-1.6, 0.6),
            tip + const Offset(0, 0.4),
            top + const Offset(1.8, 0.4),
          ],
          1,
          peak: 0.5,
        ),
        rowDark,
      );
      canvas.drawPath(
        taperedStroke([
          top + const Offset(0, 0.6),
          tip - const Offset(0.2, 1.2),
        ], 0.7),
        rowLit,
      );
    }
  }
  canvas.restore();
  // Chân chim săn mồi: "quần" lông phủ đùi, cẳng vàng có đốt vảy, bốn
  // ngón (ba trước, một sau) với vuốt đen cong dài, vươn ra khi vồ.
  for (final x in [-4.0, 4.0]) {
    final knee = Offset(x - 2 * attack, 16);
    final foot = Offset(x - 8 * attack, 24 + 4 * attack);
    shadedPath(
      canvas,
      Path()
        ..addOval(Rect.fromCenter(center: Offset(x, 13), width: 7, height: 8)),
      darken(feather, 0.1),
      PartFrame.world,
      shadow: 1.2,
      highlight: 0.4,
      outlineWidth: 1,
    );
    shadedPath(
      canvas,
      taperedStroke(
        [knee, Offset.lerp(knee, foot, 0.5)!, foot],
        2.8,
        peak: 0,
        startWidth: 1,
        endWidth: 0.75,
      ),
      const Color(0xFFC9A85A),
      PartFrame.world,
      shadow: 0.8,
      highlight: 0.4,
      outlineWidth: 0.9,
    );
    for (var k = 1; k < 4; k++) {
      final p = Offset.lerp(knee, foot, k / 4)!;
      canvas.drawLine(
        p - const Offset(1.4, 0),
        p + const Offset(1.4, 0),
        _stroke(const Color(0xFF7A6430), 0.5),
      );
    }
    for (final (a, len) in const [
      (2.6, 4.5),
      (1.9, 5.5),
      (1.2, 4.8),
      (-0.6, 3.6),
    ]) {
      final mid = foot + Offset(math.cos(a), math.sin(a)) * len * 0.55;
      final end = foot + Offset(math.cos(a), math.sin(a)) * len;
      canvas.drawPath(
        taperedStroke(
          [foot, mid, end],
          1.6,
          peak: 0.1,
          startWidth: 1,
          endWidth: 0.7,
        ),
        _fill(const Color(0xFFC9A85A)),
      );
      final claw = end + Offset(math.cos(a + 1.1), math.sin(a + 1.1)) * 3;
      canvas.drawPath(
        taperedStroke(
          [
            end,
            Offset.lerp(end, claw, 0.5)! +
                Offset(math.cos(a), math.sin(a)) * 0.8,
            claw,
          ],
          1.3,
          peak: 0.1,
          startWidth: 1,
        ),
        _fill(const Color(0xFF1E1410)),
      );
    }
  }
  // Cánh gần vẽ trước cổ áo và đầu để tóc + lông cổ đè lên gốc cánh.
  _harpyWing(canvas, const Offset(-2, -16), flap, feather);
  // Cổ gầy da nhăn + cổ áo lông xù tả tơi (ranh giới người – chim):
  // lông nhọn toả xuống hai lớp, lớp trong tối, lớp ngoài có sống sáng.
  _shaded(
    canvas,
    taperedStroke(
      const [Offset(-3.5, -24), Offset(-2.5, -20), Offset(-1, -16)],
      5,
      peak: 0.5,
      startWidth: 0.8,
      endWidth: 1,
    ),
    const Color(0xFFA39C8A),
    shadow: 1.2,
  );
  for (final (layer, r, w) in const [(0, 11.0, 3.4), (1, 8.5, 2.8)]) {
    final ruff = Path();
    final ruffLit = Path();
    for (var i = 0; i < 9; i++) {
      final a = 0.25 + i * (math.pi - 0.5) / 8 + layer * 0.17;
      final root =
          const Offset(-1, -18) +
          Offset(math.cos(a) * 5.5, math.sin(a) * 1.6 - 1);
      final len = r + ((i * 5 + layer * 3) % 4) * 1.1;
      final tip =
          root +
          Offset(math.cos(a) * len * 0.75, math.sin(a) * len * 0.55 + 2.5) +
          Offset(math.sin(time * 6 + i) * 0.6, 0);
      final pts = [
        root,
        Offset.lerp(root, tip, 0.5)! + const Offset(0.6, 0.4),
        tip,
      ];
      ruff.addPath(
        taperedStroke(pts, w, peak: 0.25, startWidth: 0.9),
        Offset.zero,
      );
      if (layer == 1) {
        ruffLit.addPath(taperedStroke(pts.sublist(0, 2), 0.6), Offset.zero);
      }
    }
    _shaded(
      canvas,
      ruff,
      layer == 0 ? darken(feather, 0.3) : lighten(feather, 0.05),
      shadow: 1.2,
    );
    canvas.drawPath(ruffLit, _fill(lighten(feather, 0.4)));
  }
  // Đầu: mặt hốc hác, tóc rối bay.
  const face = Offset(-2, -26);
  // Tóc rối bết từng lọn dài bay ra sau, lượn theo gió cánh.
  final hair = Path();
  final hairLit = Path();
  for (var i = 0; i < 9; i++) {
    final a = -math.pi * 0.9 + i * 0.26;
    final root = face + Offset(math.cos(a) * 5.5 + 1.5, math.sin(a) * 6);
    final len = 20 + (i * 7 % 5) * 2.0;
    final wave = math.sin(time * 6 + i * 0.9) * 2.2;
    final pts = [
      root,
      root + Offset(len * 0.35, -2 + wave * 0.4),
      root + Offset(len * 0.7, 1 + wave),
      root + Offset(len, 4 + wave * 1.4 + i * 0.6),
    ];
    hair.addPath(
      taperedStroke(pts, 3.4, peak: 0.25, startWidth: 0.8),
      Offset.zero,
    );
    hairLit.addPath(taperedStroke(pts.sublist(0, 3), 0.9), Offset.zero);
  }
  _shaded(canvas, hair, const Color(0xFF6E6878), shadow: 2);
  canvas.drawPath(hairLit, _fill(const Color(0xAAC9C2D2)));
  // Mặt mụ hốc hác nhìn nghiêng: trán dô, gờ mày sâu, mũi khoằm, má hóp,
  // cằm nhọn chìa ra.
  final head = smoothPath(
    [
      face + const Offset(6, -6),
      face + const Offset(1, -10),
      face + const Offset(-5, -8.5),
      face + const Offset(-7.6, -4.2),
      face + const Offset(-7, -2.4),
      face + const Offset(-10.4, 1.2),
      face + const Offset(-7.6, 1.8),
      face + const Offset(-8.2, 4),
      face + const Offset(-8, 7.6),
      face + const Offset(-6, 9.4),
      face + const Offset(0, 8),
      face + const Offset(5, 3),
    ],
    closed: true,
    tension: 0.12,
  );
  _shaded(canvas, head, skin, shadow: 2);
  canvas.save();
  canvas.clipPath(head);
  // Hốc mắt trũng tối và má hóp.
  canvas.drawCircle(
    face + const Offset(-4, -2.4),
    4,
    Paint()
      ..shader = Gradient.radial(face + const Offset(-4, -2.4), 4, const [
        Color(0xEE2A1A26),
        Color(0x002A1A26),
      ]),
  );
  canvas.drawPath(
    taperedStroke([
      face + const Offset(-3.4, 1.4),
      face + const Offset(-1, 4),
      face + const Offset(-2.4, 7),
    ], 1.8),
    _fill(darken(skin, 0.35).withValues(alpha: 0.7)),
  );
  // Nếp nhăn trán.
  for (var i = 0; i < 2; i++) {
    canvas.drawPath(
      taperedStroke([
        face + Offset(-5.5 + i, -6.6 + i * 1.4),
        face + Offset(-3.0 + i, -7.2 + i * 1.4),
        face + Offset(-0.5 + i, -6.6 + i * 1.4),
      ], 0.6),
      _fill(darken(skin, 0.4)),
    );
  }
  canvas.restore();
  _glowEye(canvas, face + const Offset(-4.4, -2.2), 1, const Color(0xFFFF4A3A));
  // Miệng há rít, răng nhọn lởm chởm hai hàm.
  final scream = 2 + 4 * attack;
  final mouthC = face + const Offset(-6.4, 4.6);
  final mouth = Path()
    ..addOval(Rect.fromCenter(center: mouthC, width: 4.6, height: scream));
  canvas.drawPath(mouth, _fill(const Color(0xFF3A0E12)));
  canvas.save();
  canvas.clipPath(mouth);
  final tooth = _fill(const Color(0xFFF2EAD8));
  for (var i = 0; i < 4; i++) {
    final x = mouthC.dx - 2 + i * 1.2;
    canvas.drawPath(
      _poly([
        Offset(x - 0.5, mouthC.dy - scream / 2),
        Offset(x + 0.5, mouthC.dy - scream / 2),
        Offset(x, mouthC.dy - scream / 2 + 1.4),
      ]),
      tooth,
    );
    canvas.drawPath(
      _poly([
        Offset(x + 0.1, mouthC.dy + scream / 2),
        Offset(x + 1.1, mouthC.dy + scream / 2),
        Offset(x + 0.6, mouthC.dy + scream / 2 - 1.2),
      ]),
      tooth,
    );
  }
  canvas.restore();
}

void _harpyWing(Canvas canvas, Offset root, double flap, Color color) {
  canvas.save();
  canvas.translate(root.dx, root.dy);
  canvas.rotate(-0.7 * flap + 0.2);
  // Xương cánh (cánh thay tay): từ vai tới khớp có móng.
  const wrist = Offset(30, -28);
  // Lông sơ cấp dài, mép rách tả tơi, xếp từ ngoài vào trong.
  for (var i = 0; i < 6; i++) {
    final base = Offset.lerp(const Offset(6, -8), wrist, 0.35 + i * 0.12)!;
    final ang = 0.35 + i * 0.16;
    final len = 22.0 - i * 1.5;
    final tip = base + Offset(math.cos(ang) * len, math.sin(ang) * len);
    // Lông thon cong nhẹ, ngọn hơi tù; cuống lông sẫm chạy dọc.
    final bend = Offset(-(tip - base).dy, (tip - base).dx) * 0.06;
    final mid = Offset.lerp(base, tip, 0.5)! + bend;
    final feather = taperedStroke(
      [base, mid, tip],
      6 - i * 0.35,
      peak: 0.3,
      startWidth: 0.8,
      endWidth: 0.18,
    );
    _shaded(canvas, feather, darken(color, 0.12 + i * 0.02), shadow: 1.4);
    canvas.drawPath(
      taperedStroke([base, mid, Offset.lerp(base, tip, 0.88)!], 0.8),
      _fill(darken(color, 0.45)),
    );
    // Mép rách: khía nhỏ gần ngọn.
    if (i.isEven) {
      final notch = Offset.lerp(base, tip, 0.8)! + bend * 0.5;
      canvas.drawPath(
        taperedStroke([notch, notch + (tip - base) * 0.08 + bend * 1.5], 1.4),
        _fill(darken(color, 0.5)),
      );
    }
  }
  // Lông thứ cấp + lông bao phủ phần gốc cánh.
  final coverts = Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(14, -26, wrist.dx + 2, wrist.dy)
    ..quadraticBezierTo(26, -18, 22, -10)
    ..lineTo(18, -6)
    ..lineTo(16, -1)
    ..lineTo(10, 1)
    ..lineTo(8, 6)
    ..close();
  _shaded(canvas, coverts, color, shadow: 3);
  // Lông bao xếp ngói hai hàng dọc xương cánh: mép dưới tối, sống sáng.
  canvas.save();
  canvas.clipPath(coverts);
  final dark = _fill(darken(color, 0.38));
  final lit = _fill(lighten(color, 0.25).withValues(alpha: 0.8));
  for (var row = 0; row < 2; row++) {
    for (var k = 0; k < 7; k++) {
      final p = Offset.lerp(
        Offset(4 + row * 2.0, -4 + row * 4.0),
        Offset(26 + row * 1.0, -24 + row * 5.0),
        k / 6,
      )!;
      canvas.drawPath(
        taperedStroke(
          [
            p + const Offset(-1.8, -0.6),
            p + const Offset(0.6, 2.6),
            p + const Offset(2.2, -0.8),
          ],
          1,
          peak: 0.5,
        ),
        dark,
      );
      canvas.drawPath(taperedStroke([p, p + const Offset(0.4, 1.8)], 0.7), lit);
    }
  }
  canvas.restore();
  // Móng ở khớp cánh.
  canvas.drawPath(
    Path()
      ..moveTo(wrist.dx + 2, wrist.dy)
      ..quadraticBezierTo(
        wrist.dx + 8,
        wrist.dy - 2,
        wrist.dx + 8,
        wrist.dy + 4,
      ),
    _stroke(const Color(0xFFE8D9B0), 1.6),
  );
  canvas.restore();
}

// ---------------------------------------------------------------------------
// Lợn rừng Erymanthus (tinh anh): bờm gai dựng, nanh cong khổng lồ.

/// [charge] 0–1: cúi đầu lao húc (người chơi phải ngồi xuống để né).
final _boarHead = RasterLayer(
  _paintBoarHead,
  bounds: const Rect.fromLTRB(-46, -34, 20, 18),
  resolution: 2.2,
);

void _paintBoarHead(Canvas canvas) {
  const hide = Color(0xFF5A4134);
  final head = smoothPath(
    const [
      Offset(10, -18),
      Offset(0, -20),
      Offset(-12, -15),
      Offset(-24, -8),
      Offset(-31, -4),
      Offset(-33, 3),
      Offset(-27, 6),
      Offset(-14, 9),
      Offset(0, 12),
      Offset(12, 8),
    ],
    closed: true,
    tension: 0.08,
  );
  _shaded(canvas, head, hide, shadow: 4);
  canvas.save();
  canvas.clipPath(head);
  // Má bạnh lông dày: nét lông xuôi ra sau, sẫm phía dưới.
  final fur = Path();
  for (var i = 0; i < 26; i++) {
    final x = -18 + (i % 7) * 5.0 + ((i ~/ 7).isOdd ? 2.5 : 0.0);
    final y = -10 + (i ~/ 7) * 5.0;
    fur.addPath(
      taperedStroke(
        [Offset(x, y), Offset(x + 3, y + 1.2), Offset(x + 5.5, y + 2.6)],
        1.1,
        peak: 0.3,
        startWidth: 0.8,
        samples: 5,
      ),
      Offset.zero,
    );
  }
  canvas.drawPath(fur, _fill(const Color(0xAA2E211B)));
  // Sống mũi sáng, nếp nhăn mõm.
  canvas.drawPath(
    taperedStroke(
      const [Offset(-4, -17), Offset(-16, -12.5), Offset(-27, -6)],
      2.4,
      peak: 0.4,
    ),
    _fill(const Color(0x887D5E4A)),
  );
  for (var i = 0; i < 3; i++) {
    final x = -22.0 + i * 3;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(x, -6 + i * 0.6), width: 4, height: 5),
      -1.2,
      2.2,
      false,
      _stroke(const Color(0xFF2E211B), 0.7),
    );
  }
  canvas.restore();
  // Đĩa mõm: mặt phẳng hồng xám, hai lỗ mũi, viền ướt sáng.
  final snout = Path()
    ..addOval(
      Rect.fromCenter(center: const Offset(-32, 0.5), width: 7, height: 12),
    );
  _shaded(canvas, snout, const Color(0xFF9C6E5E), shadow: 1.5);
  for (final dy in [-2.4, 3.2]) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-33, dy), width: 2.2, height: 3),
      _fill(const Color(0xFF241812)),
    );
  }
  canvas.drawArc(
    Rect.fromCenter(center: const Offset(-32, 0.5), width: 7, height: 12),
    3.6,
    1.8,
    false,
    _stroke(const Color(0xAAFFE8E0), 0.7),
  );
  // Nanh: ngà cong vút có vân, gốc sẫm trong môi.
  for (final (x, s) in [(-18.0, 1.0), (-12.0, 0.72)]) {
    final pts = [
      Offset(x, 6),
      Offset(x - 9 * s, 5),
      Offset(x - 15 * s, -2 * s),
      Offset(x - 16 * s, -12 * s),
    ];
    final tusk = taperedStroke(
      pts,
      6 * s,
      peak: 0.05,
      startWidth: 1,
      samples: 12,
    );
    _shaded(canvas, tusk, const Color(0xFFF2E6C4), shadow: 1.5);
    canvas.drawPath(
      taperedStroke(
        [for (final p in pts.take(3)) p + const Offset(0.6, -0.8)],
        1.2 * s,
        peak: 0.3,
      ),
      _fill(const Color(0xCCFFFFFF)),
    );
    for (var k = 1; k < 3; k++) {
      final p = Offset.lerp(pts[0], pts[2], k / 3)!;
      canvas.drawLine(
        p - Offset(0, 1.6 * s),
        p + Offset(0, 1.6 * s),
        _stroke(const Color(0xFFC9B48A), 0.6),
      );
    }
  }
  // Tai dựng nhọn có lông viền, lòng tai sẫm.
  final ear = _poly(const [Offset(2, -18), Offset(14, -30), Offset(11, -14)]);
  _shaded(canvas, ear, darken(hide, 0.1), shadow: 1.5);
  canvas.drawPath(
    _poly(const [Offset(5, -18), Offset(12.5, -26.5), Offset(10, -16)]),
    _fill(const Color(0xFF3A2620)),
  );
  // Mắt nhỏ sâu dưới gờ mày, đỏ rực; mày chau.
  _glowEye(canvas, const Offset(-10, -10), 1.6, const Color(0xFFFF2A1A));
  canvas.drawPath(
    taperedStroke(
      const [Offset(-16, -14.5), Offset(-10, -13.6), Offset(-4, -11)],
      2.6,
      peak: 0.3,
      startWidth: 0.6,
    ),
    _fill(_outline),
  );
}

/// Lớp lông lợn rừng (cố định theo khung thân) ghi sẵn một lần.
final _boarCoat = PictureCache<int>(maxEntries: 1);

/// Báo trước cú húc của lợn rừng (bảng dấu hiệu, rules/dohoa.md): mũi tên
/// đỏ chớp trên đất chỉ hướng lao (né = giữ tay thẳng), vệt tốc độ, bụi tung
/// sau lưng. Toạ độ như [paintErymanthianBoar] (gốc ở chân giữa thân);
/// bản sprite Blender cũng vẽ lớp này. [charge] 0–1: mức lấy đà.
void paintBoarChargeTell(Canvas canvas, {double time = 0, double charge = 0}) {
  final attack = charge;
  if (attack > 0.05) {
    final blink = 0.55 + 0.45 * math.sin(time * 14);
    final arrow = _fill(Color.fromRGBO(230, 40, 30, 0.6 * attack * blink));
    for (var i = 0; i < 3; i++) {
      final x = -70.0 - i * 18;
      canvas.drawPath(
        _poly([
          Offset(x + 8, -6),
          Offset(x, 0),
          Offset(x + 8, 6),
          Offset(x + 12, 6),
          Offset(x + 4, 0),
          Offset(x + 12, -6),
        ]),
        arrow,
      );
    }
    // Vệt tốc độ + bụi tung sau lưng.
    final streak = _stroke(Color.fromRGBO(255, 240, 220, 0.5 * attack), 1.4);
    for (var i = 0; i < 4; i++) {
      final y = -60.0 + i * 12;
      canvas.drawLine(Offset(58, y), Offset(80 + i * 6.0, y + 2), streak);
    }
    for (var i = 0; i < 5; i++) {
      final ph = (time * 2 + i / 5) % 1;
      canvas.drawCircle(
        Offset(50 + ph * 40, -4 - ph * 14),
        3 + ph * 6,
        _fill(Color.fromRGBO(190, 155, 110, 0.6 * attack * (1 - ph))),
      );
    }
  }
}

void paintErymanthianBoar(
  Canvas canvas, {
  double time = 0,
  double attack = 0,
  double hurt = 0,
}) {
  const hide = Color(0xFF5A4134);
  const hideLight = Color(0xFF7D5E4A);
  final breath = math.sin(time * 2.4);
  final dip = 8 * attack;
  _withHurt(canvas, hurt, () {
    paintBoarChargeTell(canvas, time: time, charge: attack);
    // Hào quang tinh anh: vầng đỏ dưới chân.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 0), width: 130, height: 14),
      Paint()
        ..shader = Gradient.radial(const Offset(0, 0), 65, const [
          Color(0x66FF3D1F),
          Color(0x00FF3D1F),
        ]),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 1), width: 110, height: 10),
      _fill(const Color(0x55301C10)),
    );
    // Chân ngắn, móng guốc. Chân trước: cánh tay → khuỷu sát thân → cẳng
    // thẳng → cổ tay → cổ chân ngắn. Chân sau: đùi bắp to → gối → cẳng
    // chéo ra sau → khớp cổ chân (hock) gập → cổ chân dốc về trước.
    for (final (x, far, hind) in [
      (-26.0, true, false),
      (34.0, true, true),
      (-36.0, false, false),
      (26.0, false, true),
    ]) {
      final c = far ? darken(hide, 0.3) : hide;
      if (hind) {
        shadedChain(canvas, [
          (Offset(x - 2, -44), Offset(x + 2, -26), 15, 9),
          (Offset(x + 2, -26), Offset(x + 6, -13), 8, 4.6),
          (Offset(x + 6, -13), Offset(x - 2.5, -6), 4.6, 3.6),
        ], c);
        // Gân gót (Achilles) sáng mảnh sau cẳng.
        canvas.drawLine(
          Offset(x + 6, -24),
          Offset(x + 7.6, -14),
          _stroke(lighten(c, 0.18).withValues(alpha: 0.7), 0.9),
        );
      } else {
        shadedChain(canvas, [
          (Offset(x + 1, -44), Offset(x + 2, -26), 13, 7.5),
          (Offset(x + 2, -26), Offset(x - 0.5, -12), 6.5, 4.6),
          (Offset(x - 0.5, -12), Offset(x - 2.5, -6), 4.6, 3.6),
        ], c);
        // Mặt sau cẳng trước: rãnh gân.
        canvas.drawLine(
          Offset(x + 3.4, -24),
          Offset(x + 1.6, -13),
          _stroke(darken(c, 0.3), 0.8),
        );
      }
      const hoof = Color(0xFF241812);
      canvas.drawPath(
        _poly([
          Offset(x - 8.5, 0),
          Offset(x - 6, -6.5),
          Offset(x + 0.5, -6.5),
          Offset(x + 1.5, 0),
        ]),
        _fill(hoof),
      );
      canvas.drawLine(
        Offset(x - 3.5, -5.5),
        Offset(x - 4, 0),
        _stroke(lighten(hoof, 0.3), 0.9),
      );
      // Móng huyền phía sau gót.
      canvas.drawCircle(Offset(x + 1.5, -5), 1.4, _fill(hoof));
    }
    // Thân lợn rừng: nửa trước nặng, u vai cao, lưng dốc xuống mông nhỏ,
    // bụng thon dần ra sau.
    final body = Path()
      ..moveTo(-44, -28 + dip)
      ..cubicTo(-52, -40 + dip, -46, -62 + dip, -30, -72 - breath + dip * 0.5)
      ..cubicTo(-16, -80 - breath, 4, -72, 22, -64)
      ..cubicTo(40, -58, 56, -50, 54, -34)
      ..cubicTo(52, -22, 40, -20, 30, -22)
      ..cubicTo(10, -18, -24, -14, -44, -28 + dip)
      ..close();
    _shaded(canvas, body, hide, shadow: 6);
    canvas.save();
    canvas.clipPath(body);
    // Lông cứng dày phủ khắp thân, xuôi từ gáy về mông và rủ xuống bụng:
    // nét thon tối + nét sáng ngắn so le (ghi sẵn một Path, vẽ 2 lần).
    _boarCoat.draw(canvas, 0, (c) {
      final dark = Path(), lit = Path();
      final rnd = math.Random(5);
      for (var row = 0; row < 9; row++) {
        for (var col = 0; col < 16; col++) {
          final x =
              -46 + col * 6.4 + (row.isOdd ? 3.2 : 0) + rnd.nextDouble() * 2;
          final y = -74 + row * 6.6 + rnd.nextDouble() * 2;
          // Hướng lông: ra sau, càng xuống bụng càng rủ; quanh mông lông
          // vòng xuống theo khối đùi sau.
          final ham = ((x - 14) / 30).clamp(0.0, 1.0);
          final dir = Offset(1 - ham * 0.6, 0.25 + row * 0.08 + ham * 0.9);
          final u = dir / dir.distance;
          final len = 5 + rnd.nextDouble() * 5 + (row < 3 ? 2 : 0);
          final p = Offset(x, y);
          dark.addPath(
            taperedStroke(
              [p, p + u * len * 0.5 + Offset(0, 0.6), p + u * len],
              1.5,
              peak: 0.25,
              startWidth: 0.8,
              samples: 5,
            ),
            Offset.zero,
          );
          if (rnd.nextDouble() < 0.5) {
            lit.addPath(
              taperedStroke(
                [
                  p + const Offset(1, -1.4),
                  p + u * len * 0.6 + const Offset(1, -1.4),
                ],
                0.8,
                samples: 4,
              ),
              Offset.zero,
            );
          }
        }
      }
      c.drawPath(dark, _fill(const Color(0xCC2E211B)));
      c.drawPath(lit, _fill(const Color(0x667D5E4A)));
    });
    // Khối vai đón sáng, bóng lõi sau vai và trước đùi sau.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-28, -54 + dip * 0.5),
        width: 34,
        height: 30,
      ),
      _fill(hideLight.withValues(alpha: 0.55)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-8, -70)
        ..quadraticBezierTo(0, -48, -10, -22),
      _stroke(darken(hide, 0.35).withValues(alpha: 0.7), 4),
    );
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(38, -38), width: 36, height: 34),
      1.9,
      1.7,
      false,
      _stroke(darken(hide, 0.35).withValues(alpha: 0.7), 3.5),
    );
    canvas.restore();
    // Bờm lông cứng dọc sống lưng: sợi thon dài nhất ở u vai, chĩa lên và
    // ra sau; dựng cao hơn khi húc.
    Offset spine(double u) {
      final p0 = Offset(-44, -58 + dip);
      final p1 = Offset(-22, -88 - breath);
      final p2 = const Offset(40, -58);
      return p0 * ((1 - u) * (1 - u)) + p1 * (2 * u * (1 - u)) + p2 * (u * u);
    }

    final bristles = Path();
    final sheen = Path();
    for (var i = 0; i < 17; i++) {
      final u = (i + 0.5) / 17;
      final base = spine(u);
      final d = spine(math.min(1, u + 0.02)) - spine(math.max(0, u - 0.02));
      final n = Offset(d.dy, -d.dx) / d.distance;
      final hump = math.sin(math.min(1, u * 1.6) * math.pi * 0.95);
      final len = (7 + 15 * hump) * (i.isEven ? 1 : 0.78) + 7 * attack * hump;
      final dir = n + const Offset(0.55, 0) + Offset(0, -0.25 * attack);
      final unit = dir / dir.distance;
      final tip = base + unit * len;
      final mid =
          Offset.lerp(base, tip, 0.5)! + Offset(-unit.dy, unit.dx) * 1.5;
      bristles.addPath(
        taperedStroke(
          [base - unit * 4, mid, tip],
          4.2,
          peak: 0.25,
          startWidth: 0.9,
        ),
        Offset.zero,
      );
      sheen.addPath(
        taperedStroke([
          Offset.lerp(base, tip, 0.15)!,
          Offset.lerp(base, tip, 0.6)!,
        ], 1.1),
        Offset.zero,
      );
    }
    _shaded(canvas, bristles, const Color(0xFF2E211B), shadow: 2);
    canvas.drawPath(sheen, _fill(const Color(0x88A88A72)));

    // Đầu cúi, mõm dài, nanh cong lên.
    canvas.save();
    canvas.translate(-42, -38 + dip);
    canvas.rotate(0.25 * attack);
    // Đầu lợn rừng nhìn nghiêng: trán dốc thẳng xuống mõm dài, má bạnh
    // phủ lông dày, mõm thon tới đĩa mũi. Chụp sẵn (tĩnh trong khung đầu).
    _boarHead.paint(canvas);
    canvas.restore();

    // Hơi thở phì ra từ mõm.
    final puff = (time * 1.2) % 1;
    canvas.drawCircle(
      Offset(-80 - 14 * puff, -38 + dip - 4 * puff),
      3 + 5 * puff,
      _fill(Color.fromRGBO(240, 236, 230, 0.5 * (1 - puff))),
    );
  });
}

// ---------------------------------------------------------------------------
// Hydra non (mini-boss): thân rắn, nhiều cổ, mỗi đầu thè lưỡi chẻ, nọc độc.

/// Báo trước phun độc của Hydra non (bảng dấu hiệu, rules/dohoa.md): vũng
/// độc xanh sủi bọt trên đất phía trước. Toạ độ như [paintYoungHydra] (gốc
/// ở chân giữa vòng thân); bản sprite Blender cũng vẽ lớp này.
void paintHydraPoisonTell(Canvas canvas, {double time = 0, double attack = 0}) {
  if (attack > 0.05) {
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(-70, 0),
        width: 70 * attack,
        height: 10 * attack,
      ),
      _fill(Color.fromRGBO(140, 230, 70, 0.45 * attack)),
    );
    for (var i = 0; i < 4; i++) {
      final ph = (time * 1.5 + i / 4) % 1;
      canvas.drawCircle(
        Offset(-86 + i * 10.0, -2 - ph * 10),
        1.4 + ph * 2,
        _stroke(Color.fromRGBO(190, 255, 120, attack * (1 - ph)), 0.8),
      );
    }
  }
}

void paintYoungHydra(
  Canvas canvas, {
  double time = 0,
  double attack = 0,
  double hurt = 0,
  int heads = 3,
  double regrow = -1,
}) {
  const scale = Color(0xFF3F7A4A);
  _withHurt(canvas, hurt, () {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(4, 1), width: 110, height: 12),
      _fill(const Color(0x55301C10)),
    );
    // Vòng cuộn phía sau (khuất, tối hơn) nằm sau các cổ.
    _hydraBackCoil.paint(canvas);
    // Cổ: mỗi cổ một đường cong lắc lư theo pha riêng.
    final necks = <(Offset, Offset)>[];
    for (var i = 0; i < heads; i++) {
      final f = heads == 1 ? 0.5 : i / (heads - 1);
      final base = Offset(-10 + f * 24, -30);
      final sway = math.sin(time * 1.8 + i * 1.3) * 6;
      final strikeI = attack * (i == heads ~/ 2 ? 1 : 0.4);
      final tip = Offset(
        -34 + f * 34 + sway - 30 * strikeI,
        -84 - (i.isEven ? 12 : 0) + sway * 0.5 + 18 * strikeI,
      );
      necks.add((base, tip));
    }
    // Bóng tiếp giáp nơi cổ mọc ra từ thân (cổ chìm vào khối thân).
    for (final (base, _) in necks) {
      canvas.drawOval(
        Rect.fromCenter(
          center: base + const Offset(0, 2),
          width: 20,
          height: 7,
        ),
        _fill(const Color(0x66142014)),
      );
    }
    for (final (base, tip) in necks) {
      final mid = Offset.lerp(base, tip, 0.5)! + const Offset(10, 0);
      shadedChain(canvas, [(base, mid, 8, 6), (mid, tip, 6, 5)], scale);
      // Dải vảy bụng sáng ở mặt trước cổ, sống lưng tối ở mặt sau.
      List<Offset> side(double k) => [
        for (final (p, w) in [(base, 8.0), (mid, 6.0), (tip, 5.0)])
          p + Offset(k * w, 0),
      ];
      canvas.drawPath(
        taperedStroke(
          side(-0.62),
          4.2,
          peak: 0.2,
          startWidth: 1,
          endWidth: 0.6,
        ),
        _fill(_hydraBelly),
      );
      canvas.drawPath(
        taperedStroke(side(0.6), 2.4, peak: 0.2, startWidth: 1, endWidth: 0.5),
        _fill(darken(scale, 0.3)),
      );
    }
    // Vòng cuộn phía trước, đuôi thon vắt lên.
    _hydraFrontCoil.paint(canvas);
    paintHydraPoisonTell(canvas, time: time, attack: attack);
    // Đầu rắn.
    for (var i = 0; i < necks.length; i++) {
      final (_, tip) = necks[i];
      final open =
          attack * (i == heads ~/ 2 ? 1 : 0.4) +
          0.15 * (0.5 + 0.5 * math.sin(time * 2.2 + i));
      // [regrow] ≥ 0: cổ giữa vừa bị chém, hai đầu non nhú ra từ vết cụt
      // (chém một mọc hai, như Hydra xứ Lerna).
      if (regrow < 0 || i != heads ~/ 2) {
        _hydraHead(canvas, tip, open, time + i);
      }
    }
    if (regrow >= 0) {
      final (base, tip) = necks[heads ~/ 2];
      _hydraStump(canvas, base, tip, regrow, time);
    }
  });
}

const _hydraScale = Color(0xFF3F7A4A);
const _hydraBelly = Color(0xFFD8C978);

final _hydraBackCoil = RasterLayer(
  (c) {
    _serpentCoil(
      c,
      const [
        Offset(-26, -12),
        Offset(-20, -30),
        Offset(2, -40),
        Offset(28, -36),
        Offset(42, -20),
        Offset(30, -8),
      ],
      22,
      darken(_hydraScale, 0.1),
      startWidth: 0.85,
      endWidth: 0.85,
      belly: false,
    );
    // Khối thân chung giữa vòng cuộn — nơi các cổ mọc ra (không để cổ cắm
    // xuống một lỗ trống): bướu thân tròn phủ vảy, ngực sáng ở giữa.
    final trunk = Path()
      ..moveTo(-24, -6)
      ..cubicTo(-26, -24, -14, -38, 2, -38)
      ..cubicTo(20, -38, 32, -26, 30, -6)
      ..close();
    shadedPath(
      c,
      trunk,
      _hydraScale,
      PartFrame.world,
      shadow: 4,
      highlight: 1.2,
    );
    c.save();
    c.clipPath(trunk);
    final cell = Paint()
      ..color = darken(_hydraScale, 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (var r = 0; r < 9; r++) {
      for (var k = 0; k < 14; k++) {
        final x = -26 + k * 4.4 + (r.isOdd ? 2.2 : 0);
        final y = -38 + r * 3.8;
        c.drawArc(
          Rect.fromCenter(center: Offset(x, y), width: 4.4, height: 3.8),
          0.2,
          math.pi - 0.4,
          false,
          cell,
        );
      }
    }
    c.drawRect(
      const Rect.fromLTRB(-30, -40, 34, -4),
      Paint()
        ..shader = Gradient.linear(
          const Offset(0, -20),
          const Offset(0, -4),
          const [Color(0x00142014), Color(0x99142014)],
        ),
    );
    c.restore();
  },
  bounds: const Rect.fromLTRB(-46, -60, 62, 8),
  resolution: 2,
);

final _hydraFrontCoil = RasterLayer(
  (c) => _serpentCoil(
    c,
    const [
      Offset(-8, -30),
      Offset(-30, -24),
      Offset(-34, -10),
      Offset(-14, -1),
      Offset(18, -2),
      Offset(44, -6),
      Offset(60, -14),
      Offset(68, -30),
    ],
    21,
    _hydraScale,
    startWidth: 0.75,
    endWidth: 0.12,
    belly: true,
  ),
  bounds: const Rect.fromLTRB(-52, -48, 82, 10),
  resolution: 2,
);

/// Một khúc thân rắn dọc đường [pts] (`vector_texture.buildScaleBody`):
/// khối tô đổ bóng, vảy chữ U so le, sống lưng sẫm; nếu [belly] thì dải
/// vảy bụng sáng chia đốt ngang.
void _serpentCoil(
  Canvas canvas,
  List<Offset> pts,
  double width,
  Color color, {
  required double startWidth,
  required double endWidth,
  required bool belly,
}) {
  final s = buildScaleBody(
    pts,
    width,
    startWidth: startWidth,
    endWidth: endWidth,
    belly: belly,
  );
  _shaded(canvas, s.body, color, shadow: 5);
  canvas.save();
  canvas.clipPath(s.body);
  canvas.drawPath(
    s.scaleDark,
    _stroke(darken(color, 0.35).withValues(alpha: 0.8), 0.9),
  );
  canvas.drawPath(
    s.scaleLit,
    _stroke(lighten(color, 0.3).withValues(alpha: 0.7), 0.7),
  );
  canvas.drawPath(s.spine, _fill(darken(color, 0.3).withValues(alpha: 0.75)));
  if (belly) {
    canvas.drawPath(s.belly, _fill(_hydraBelly));
    canvas.drawPath(s.plates, _stroke(darken(_hydraBelly, 0.3), 0.9));
  }
  canvas.restore();
}

void _hydraStump(
  Canvas canvas,
  Offset base,
  Offset tip,
  double grow,
  double time,
) {
  final d = tip - base;
  final dir = d / d.distance;
  final n = Offset(-dir.dy, dir.dx);
  // Hai đầu non mọc ra, toả hai bên.
  final g = Curves.easeOutBack.transform(grow.clamp(0.0, 1.0));
  for (final side in [-1.0, 1.0]) {
    final sprout = tip + (dir * 14 + n * side * 16) * g;
    shadedChain(canvas, [(tip, sprout, 5, 4)], const Color(0xFF4C8E56));
    if (g > 0.2) {
      canvas.save();
      canvas.translate(sprout.dx, sprout.dy);
      canvas.scale(0.5 * g);
      canvas.translate(-sprout.dx, -sprout.dy);
      _hydraHead(canvas, sprout, 0.3, time + side);
      canvas.restore();
    }
  }
  // Vết cụt: mặt cắt nghiêng theo cổ — vành da vảy, thịt đỏ, đốt sống
  // trắng; rỉ máu xanh độc (máu Hydra có độc).
  canvas.save();
  canvas.translate(tip.dx, tip.dy);
  canvas.rotate(math.atan2(dir.dy, dir.dx) + math.pi / 2);
  const cut = Rect.fromLTRB(-8.5, -4.5, 8.5, 4.5);
  canvas.drawOval(cut.inflate(1.2), _fill(_outline));
  canvas.drawOval(cut, _fill(const Color(0xFF2E5A36)));
  canvas.drawOval(cut.deflate(1.6), _fill(const Color(0xFF8E2A2A)));
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(-1.5, -1), width: 9, height: 3),
    _fill(const Color(0xFFB04848)),
  );
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(0.5, 0.3), width: 4.4, height: 2.6),
    _fill(const Color(0xFFF2E6D0)),
  );
  canvas.restore();
  final drip = (time * 1.2) % 1;
  canvas.drawCircle(
    tip + Offset(2, 4 + 8 * drip),
    1.2,
    _fill(Color.fromRGBO(120, 200, 80, 1 - drip)),
  );
}

void _hydraHead(Canvas canvas, Offset at, double open, double time) {
  const scale = Color(0xFF4C8E56);
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.scale(1.7);
  // Hàm dưới.
  canvas.save();
  canvas.rotate(-0.75 * open);
  final jaw = Path()
    ..moveTo(4, 1)
    ..quadraticBezierTo(-6, 2.5, -14, 2)
    ..quadraticBezierTo(-13, 5.5, -8, 5.5)
    ..lineTo(4, 5)
    ..close();
  _shaded(canvas, jaw, const Color(0xFFD8C978), shadow: 1);
  canvas.restore();
  if (open > 0.2) {
    canvas.drawPath(
      _poly([
        const Offset(4, 1),
        const Offset(-13, 0),
        Offset(-12, 2 + 8 * open),
      ]),
      _fill(const Color(0xFF5C0F12)),
    );
    // Lưỡi chẻ.
    final flick = math.sin(time * 14) * 2;
    canvas.drawPath(
      Path()
        ..moveTo(-8, 2)
        ..lineTo(-20, 3 + flick)
        ..moveTo(-20, 3 + flick)
        ..lineTo(-24, 1 + flick)
        ..moveTo(-20, 3 + flick)
        ..lineTo(-24, 5 + flick),
      _stroke(const Color(0xFFD0384A), 1),
    );
  }
  // Sừng cong vuốt ra sau (vẽ trước để sọ che gốc).
  const horn = Color(0xFF2A3A26);
  for (final (pts, w) in [
    (const [Offset(-3, -7), Offset(4, -11.5), Offset(12, -13)], 2.6),
    (const [Offset(2, -6.5), Offset(8, -9), Offset(15, -8.5)], 2.1),
  ]) {
    final h = taperedStroke(pts, w, peak: 0.1, startWidth: 1);
    _shaded(canvas, h, horn, shadow: 0.8);
    canvas.drawPath(
      taperedStroke([pts[0], pts[1]], w * 0.35),
      _fill(lighten(horn, 0.35)),
    );
  }
  // Sọ rắn lục: má bạnh to phía sau (túi nọc), đỉnh đầu phẳng, mõm thuôn
  // ngắn hơi hếch.
  final head = smoothPath(
    const [
      Offset(-17, -0.6),
      Offset(-15.4, -3.2),
      Offset(-9, -5.8),
      Offset(0, -7.8),
      Offset(7.5, -7.4),
      Offset(11, -2.6),
      Offset(9.5, 2.8),
      Offset(3, 4),
      Offset(-12, 2.4),
      Offset(-16.5, 1.2),
    ],
    closed: true,
    tension: 0.1,
  );
  _shaded(canvas, head, scale, shadow: 2);
  canvas.save();
  canvas.clipPath(head);
  // Vảy lớn trên đỉnh đầu (tấm sừng xếp như ngói, mép sau tối, mặt
  // trên đón sáng) — mặt trên phẳng đặc trưng của rắn lục.
  final plateDark = _stroke(darken(scale, 0.35), 0.5);
  final plateLit = _fill(lighten(scale, 0.18));
  for (final (c, w) in const [
    (Offset(-12.5, -4.6), 3.0),
    (Offset(-8.5, -6.2), 3.6),
    (Offset(-4, -7.2), 4.0),
    (Offset(1, -7.6), 4.2),
    (Offset(6, -7.2), 3.8),
  ]) {
    final plate = _poly([
      c + Offset(-w / 2, 0.9),
      c + Offset(-w / 2 + 0.6, -0.7),
      c + Offset(w / 2 - 0.4, -0.9),
      c + Offset(w / 2, 1.1),
    ]);
    canvas.drawPath(plate, plateLit);
    canvas.drawPath(plate, plateDark);
  }
  // Sọc tối sau mắt chạy xuống góc hàm (vằn rắn lục).
  canvas.drawPath(
    taperedStroke(
      const [Offset(-5.5, -3.6), Offset(1, -1.6), Offset(9, 0.6)],
      2.2,
      peak: 0.45,
      startWidth: 0.6,
    ),
    _fill(darken(scale, 0.42).withValues(alpha: 0.75)),
  );
  // Vảy hàm trên (labial): vạch ngắn đều dọc môi.
  for (var k = 0; k < 7; k++) {
    final x = -14.5 + k * 3.2;
    canvas.drawLine(
      Offset(x, 0.4 + k * 0.12),
      Offset(x + 0.5, 2.4 + k * 0.1),
      _stroke(darken(scale, 0.3), 0.5),
    );
  }
  canvas.drawPath(
    taperedStroke(
      const [Offset(-17, 1.2), Offset(-8, 2.4), Offset(2, 2.6), Offset(8, 1.4)],
      2.4,
      peak: 0.3,
      startWidth: 0.6,
    ),
    _fill(const Color(0xFFBFC27A)),
  );
  canvas.restore();
  // Lỗ mũi, hố cảm nhiệt giữa mũi và mắt.
  canvas.drawOval(
    const Rect.fromLTWH(-16, -2.6, 1.6, 1),
    _fill(const Color(0xFF1A2A1C)),
  );
  canvas.drawCircle(
    const Offset(-11.5, -1.6),
    0.7,
    _fill(const Color(0xFF1A2A1C)),
  );
  // Nanh dài cong, rỉ nọc độc.
  final fangLen = 5.5 + 3 * open;
  canvas.drawPath(
    taperedStroke(
      [
        const Offset(-11.5, 1.6),
        Offset(-12.3, 1.6 + fangLen * 0.6),
        Offset(-11.2, 1.6 + fangLen),
      ],
      1.6,
      peak: 0.1,
      startWidth: 1,
    ),
    _fill(const Color(0xFFFFF6DE)),
  );
  final drip = (time * 0.8) % 1;
  canvas.drawCircle(
    Offset(-11.2, 2.6 + fangLen + 6 * drip),
    1.1,
    _fill(Color.fromRGBO(170, 255, 90, 1 - drip)),
  );
  // Mắt nhỏ, con ngươi dọc mảnh; vảy mày sụp che nửa trên → nhìn hằm hằm.
  const eye = Offset(-6.5, -4.2);
  _glowEye(canvas, eye, 1.4, const Color(0xFFD8F020));
  canvas.drawOval(
    Rect.fromCenter(center: eye, width: 0.55, height: 2.5),
    _fill(_outline),
  );
  final brow = Path()
    ..moveTo(-11.5, -4.4)
    ..quadraticBezierTo(-7, -8.6, -1, -7.6)
    ..lineTo(-2.2, -5.2)
    ..quadraticBezierTo(-6.5, -5.6, -11.5, -4.4)
    ..close();
  _shaded(canvas, brow, const Color(0xFF2E5A36), shadow: 0.8);
  canvas.drawPath(
    taperedStroke(const [
      Offset(-11.5, -4.4),
      Offset(-6.5, -5.5),
      Offset(-2.2, -5.2),
    ], 0.9),
    _fill(_outline),
  );
  canvas.restore();
}

/// Đàn chim Stymphalia bay vòng (phông nền động): mỗi con vẽ từ 8 khung đập
/// cánh dựng sẵn thành Picture, nên cả đàn rất nhẹ.
final List<Picture> _birdFrames = List.generate(8, (k) {
  final recorder = PictureRecorder();
  paintStymphalianBird(Canvas(recorder), time: k / 8 * (2 * math.pi / 9));
  return recorder.endRecording();
});

/// Một con chim của đàn tại [at], cỡ [size]; [facingRight] lật hình.
/// [fall] 0–1: bị hạ, xoay tròn rơi xuống và mờ dần.
void paintBirdSprite(
  Canvas canvas,
  Offset at,
  double time, {
  double size = 0.6,
  bool facingRight = false,
  double fall = 0,
}) {
  final frame = _birdFrames[((time * 9 / (2 * math.pi)) * 8).floor() % 8];
  canvas.save();
  canvas.translate(at.dx, at.dy + 120 * fall * fall);
  if (fall > 0) canvas.rotate(fall * 7);
  canvas.scale(facingRight ? -size : size, size);
  if (fall > 0) {
    canvas.saveLayer(
      const Rect.fromLTRB(-60, -60, 60, 60),
      Paint()..color = Color.fromRGBO(0, 0, 0, 1 - fall),
    );
    canvas.drawPicture(frame);
    canvas.restore();
  } else {
    canvas.drawPicture(frame);
  }
  canvas.restore();
}

// ---------------------------------------------------------------------------
// Lính đá: tượng hoplite cẩm thạch bị Trì Trệ nhập, khe nứt rỉ ánh tím xám.

void paintStoneSoldier(
  Canvas canvas, {
  double time = 0,
  double attack = 0,
  double hurt = 0,
}) {
  const marble = Color(0xFFD9D3C7);
  const marbleDark = Color(0xFFB4AC9E);
  const stagnation = Color(0xFF9C7CC9);
  // Tượng cử động giật cục (đá cứng): lượng tử hoá chuyển động.
  final step = (time * 3).floor() / 3;
  final sway = math.sin(step * 2) * 1.5;
  final lunge = (attack * 4).floor() / 4;
  _withHurt(canvas, hurt, () {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 1), width: 56, height: 8),
      _fill(const Color(0x55301C10)),
    );
    // Bệ tượng vỡ dưới chân.
    final plinth = _poly(const [
      Offset(-22, 0),
      Offset(-20, -8),
      Offset(-4, -10),
      Offset(2, -7),
      Offset(20, -9),
      Offset(22, 0),
    ]);
    _shaded(canvas, plinth, marbleDark, shadow: 2);
    // Chân đá tạc theo giải phẫu (tượng Hy Lạp): đùi, gối, bắp chân.
    for (final (x, c, near) in [
      (6.0, marbleDark, false),
      (-6.0, marble, true),
    ]) {
      shadedLimb(
        canvas,
        [
          (Offset(x, -44), Offset(x * 1.2, -26), HumanAnatomy.thigh),
          (Offset(x * 1.2, -26), Offset(x * 1.3, -9), HumanAnatomy.shin),
        ],
        c,
        scale: 0.62,
        facing: const Offset(-1, 0),
        highlight: near ? 1.4 : 0,
        definition: near ? 0.55 : 0,
      );
    }
    // Khiên ở tay phía xa: nằm sau thân.
    // Khiên đá tròn có vết nứt.
    final shieldC = Offset(17 + sway * 0.4, -56);
    final shield = Path()
      ..addOval(Rect.fromCircle(center: shieldC, radius: 15));
    _shaded(canvas, shield, marbleDark, shadow: 4);
    canvas.drawCircle(shieldC, 10, _stroke(const Color(0xFF8E8676), 1.2));

    // Thân giáp cơ bắp tạc đá (chụp sẵn): vai rộng, eo thắt, váy giáp.
    _stoneTorso.paint(canvas);
    // Đầu đội mũ Corinth bằng đá, mào đá.
    final head = Offset(-1 + sway * 0.3 - 3 * lunge, -86);
    canvas.save();
    canvas.translate(head.dx, head.dy);
    canvas.scale(0.92);
    _stoneHelmet.paint(canvas);
    _glowEye(canvas, const Offset(-6.2, -2.2), 1.05, stagnation);
    canvas.restore();

    // Tay đá cầm giáo: vai tròn, bắp tay, khuỷu gập ra sau sát hông,
    // cẳng tay đưa giáo ra trước; duỗi thẳng khi đâm.
    final hand = Offset(-16 - 14 * lunge, -58);
    final elbow = Offset(-5 - 8 * lunge, -55 + 1 * lunge);
    shadedChain(canvas, [
      (const Offset(-12, -68), elbow, 6.4, 5.2),
      (elbow, hand, 5, 4.2),
    ], marble);
    // Rãnh cơ nhị đầu + nếp khuỷu tạc trên đá.
    canvas.drawPath(
      taperedStroke(
        [
          const Offset(-12, -66),
          Offset.lerp(const Offset(-12, -68), elbow, 0.7)!,
        ],
        0.9,
        peak: 0.5,
      ),
      _fill(marbleDark.withValues(alpha: 0.7)),
    );
    final back = hand + const Offset(28, -10);
    final tip = hand + Offset(-28 - 8 * lunge, 2);
    canvas.drawLine(back, tip, _stroke(_outline, 3.4));
    canvas.drawLine(back, tip, _stroke(marbleDark, 1.8));
    final dir = (tip - back) / (tip - back).distance;
    final n = Offset(-dir.dy, dir.dx);
    _shaded(
      canvas,
      _poly([tip - n * 3, tip + dir * 9, tip + n * 3]),
      marbleDark,
      shadow: 1,
    );
    // Nắm tay đá quanh cán giáo (vẽ sau giáo để ngón đè lên cán).
    _shaded(
      canvas,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: hand, width: 5.6, height: 5.2),
          const Radius.circular(2.6),
        ),
      ),
      marble,
      shadow: 1,
    );
    for (var k = 0; k < 3; k++) {
      canvas.drawLine(
        hand + Offset(-1.8 + k * 1.5, -2),
        hand + Offset(-2.1 + k * 1.5, 0.5),
        _stroke(marbleDark, 0.6),
      );
    }
    // Báo trước cú đâm: mũi giáo loé sao tím (màu Trì Trệ) lúc lấy đà.
    if (attack > 0.02 && attack < 0.6) {
      final k = math.sin(attack / 0.6 * math.pi);
      final r = 7 * k;
      final p = tip + dir * 9;
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy - r)
          ..lineTo(p.dx + r * 0.2, p.dy - r * 0.2)
          ..lineTo(p.dx + r, p.dy)
          ..lineTo(p.dx + r * 0.2, p.dy + r * 0.2)
          ..lineTo(p.dx, p.dy + r)
          ..lineTo(p.dx - r * 0.2, p.dy + r * 0.2)
          ..lineTo(p.dx - r, p.dy)
          ..lineTo(p.dx - r * 0.2, p.dy - r * 0.2)
          ..close(),
        _fill(Color.fromRGBO(230, 216, 255, k)),
      );
    }

    // Khe nứt rỉ ánh Trì Trệ, nhấp nháy chậm.
    final pulse = 0.55 + 0.45 * math.sin(time * 2.2);
    final crackPath = Path()
      ..moveTo(-10, -70)
      ..lineTo(-4, -62)
      ..lineTo(-8, -54)
      ..lineTo(-2, -46)
      ..moveTo(6, -66)
      ..lineTo(10, -58)
      ..moveTo(shieldC.dx - 6, shieldC.dy - 10)
      ..lineTo(shieldC.dx, shieldC.dy - 2)
      ..lineTo(shieldC.dx - 3, shieldC.dy + 6);
    canvas.drawPath(
      crackPath,
      _stroke(stagnation.withValues(alpha: 0.45 * pulse), 4),
    );
    canvas.drawPath(crackPath, _stroke(const Color(0xFF2A2230), 1.2));
    canvas.drawPath(
      crackPath,
      _stroke(const Color(0xFFE6D8FF).withValues(alpha: pulse), 0.6),
    );
    // Rêu bám vai và bệ.
    final moss = _fill(const Color(0xFF7E9150));
    canvas.drawOval(const Rect.fromLTWH(-16, -74, 8, 3), moss);
    canvas.drawOval(const Rect.fromLTWH(10, -9, 9, 3), moss);
  });

  // Bụi đá rơi lả tả khi cử động.
  final dust = _fill(const Color(0xAAB4AC9E));
  for (var i = 0; i < 4; i++) {
    final t = (time * 0.8 + i * 0.25) % 1;
    canvas.drawCircle(
      Offset(-10 + i * 7.0, -70 + t * 66),
      1.1 * (1 - t) + 0.3,
      dust,
    );
  }
}

/// Giáp ngực đúc kiểu "cuirass cơ bắp" tạc đá cẩm thạch: khối ngực, sáu
/// múi bụng, cơ chéo nổi khối (mỗi khối sáng trên–trái, bóng dưới–phải),
/// viền giáp cổ và nách, hai hàng váy giáp (pteruges) tạc rời, vân đá,
/// vết nứt rỉ ánh tím Trì Trệ, rêu bám nách. Tĩnh → chụp sẵn.
final _stoneTorso = RasterLayer(
  (canvas) {
    const marble = Color(0xFFD9D3C7);
    const marbleDark = Color(0xFFB4AC9E);
    // Váy giáp: hai hàng dải tạc, hàng sau tối hơn.
    for (final (y, len, c) in const [
      (-44.0, 13.0, Color(0xFFA49C8E)),
      (-42.0, 10.0, marbleDark),
    ]) {
      for (var i = 0; i < 6; i++) {
        final x = -13.5 + i * 4.8;
        final strip = Path()
          ..addRRect(
            RRect.fromLTRBR(x, y, x + 4.2, y + len, const Radius.circular(1.2)),
          );
        shadedPath(
          canvas,
          strip,
          c,
          PartFrame.world,
          shadow: 1.2,
          highlight: 0.5,
          outlineWidth: 1,
        );
        canvas.drawLine(
          Offset(x + 0.6, y + len - 2.4),
          Offset(x + 3.6, y + len - 2.4),
          _stroke(darken(c, 0.25), 0.6),
        );
      }
    }
    final body = Path()
      ..moveTo(-13, -42)
      ..cubicTo(-15, -52, -18, -62, -18, -70)
      ..quadraticBezierTo(-12, -78, 0, -78)
      ..quadraticBezierTo(12, -78, 18, -70)
      ..cubicTo(18, -62, 15, -52, 13, -42)
      ..quadraticBezierTo(0, -38, -13, -42)
      ..close();
    shadedPath(
      canvas,
      body,
      marble,
      PartFrame.world,
      shadow: 4,
      highlight: 1.6,
    );
    canvas.save();
    canvas.clipPath(body);
    // Khối cơ đúc nổi: sáng phía trên–trái, bóng lõi dưới–phải.
    void relief(Path p) {
      canvas.drawPath(
        p.shift(const Offset(0.9, 1.1)),
        fillPaint(darken(marble, 0.22).withValues(alpha: 0.9)),
      );
      canvas.drawPath(p, fillPaint(marble));
      canvas.drawPath(
        p.shift(const Offset(-0.5, -0.6)),
        fillPaint(lighten(marble, 0.5).withValues(alpha: 0.5)),
      );
      canvas.drawPath(p, fillPaint(marble.withValues(alpha: 0.6)));
    }

    for (final side in [-1.0, 1.0]) {
      relief(
        Path()
          ..moveTo(0, -70)
          ..quadraticBezierTo(side * 8, -73, side * 14, -68)
          ..quadraticBezierTo(side * 13, -61, side * 6, -60)
          ..quadraticBezierTo(side * 1.5, -60, 0, -63)
          ..close(),
      );
    }
    for (var r = 0; r < 3; r++) {
      for (final side in [-1.0, 1.0]) {
        final y = -57.5 + r * 5;
        relief(
          Path()..addRRect(
            RRect.fromLTRBR(
              side < 0 ? -5.6 : 0.6,
              y,
              side < 0 ? -0.6 : 5.6,
              y + 4.2,
              const Radius.circular(1.8),
            ),
          ),
        );
      }
    }
    for (final side in [-1.0, 1.0]) {
      relief(
        Path()
          ..moveTo(side * 7, -58)
          ..quadraticBezierTo(side * 12, -52, side * 11, -44)
          ..quadraticBezierTo(side * 8, -46, side * 6.5, -52)
          ..close(),
      );
    }
    // Rãnh giữa (linea alba) và mép giáp cổ/nách.
    canvas.drawLine(
      const Offset(0, -63),
      const Offset(0, -42),
      _stroke(darken(marble, 0.3), 0.8),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-6, -77)
        ..quadraticBezierTo(0, -74, 6, -77),
      _stroke(darken(marble, 0.35), 1.2),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-17, -68)
        ..quadraticBezierTo(-14, -64, -15, -59)
        ..moveTo(17, -68)
        ..quadraticBezierTo(14, -64, 15, -59),
      _stroke(darken(marble, 0.3), 1),
    );
    // Vân đá chạy chéo.
    for (final (a, b) in const [
      (Offset(-16, -66), Offset(-4, -48)),
      (Offset(4, -76), Offset(16, -58)),
    ]) {
      canvas.drawPath(
        taperedStroke([
          a,
          Offset.lerp(a, b, 0.5)! + const Offset(2, 0),
          b,
        ], 0.8),
        fillPaint(const Color(0x55807868)),
      );
    }
    // Vết nứt rỉ ánh tím Trì Trệ.
    final crack = [
      const Offset(9, -74),
      const Offset(6, -66),
      const Offset(9, -60),
      const Offset(5, -52),
    ];
    canvas.drawPath(
      taperedStroke(crack, 3.2, peak: 0.3),
      fillPaint(const Color(0x669C7CC9)),
    );
    canvas.drawPath(
      taperedStroke(crack, 1.2, peak: 0.3),
      fillPaint(const Color(0xFF2A2230)),
    );
    // Rêu bám nách và eo.
    for (final (c, r) in const [
      (Offset(-16, -60), 2.4),
      (Offset(-12, -44), 2.0),
      (Offset(15, -47), 1.6),
    ]) {
      canvas.drawCircle(c, r, fillPaint(const Color(0xAA6E8A48)));
    }
    canvas.restore();
  },
  bounds: const Rect.fromLTRB(-22, -82, 22, -28),
  resolution: 2.4,
);

/// Túi vàng quắp dưới móng Harpy, đồng xu rơi lả tả.
void _goldPouch(Canvas canvas, double time) {
  const at = Offset(0, 32);
  final sway = math.sin(time * 3) * 0.15;
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.rotate(sway);
  final pouch = Path()
    ..moveTo(-4, -4)
    ..quadraticBezierTo(-11, 2, -8, 9)
    ..quadraticBezierTo(0, 13, 8, 9)
    ..quadraticBezierTo(11, 2, 4, -4)
    ..close();
  _shaded(canvas, pouch, const Color(0xFF8A5A2E), shadow: 2);
  // Dây buộc miệng túi + vàng lấp ló.
  canvas.drawLine(
    const Offset(-4, -3),
    const Offset(4, -3),
    _stroke(const Color(0xFFE8B83A), 1.6),
  );
  canvas.drawOval(
    const Rect.fromLTWH(-3, -7, 6, 3.4),
    goldPaint(const Rect.fromLTWH(-3, -7, 6, 3.4)),
  );
  glint(canvas, const Offset(-1, -6), 1.2);
  canvas.restore();
  // Đồng xu rơi xoay.
  for (var i = 0; i < 4; i++) {
    final ph = (time * 0.9 + i / 4) % 1;
    final p = at + Offset(-4 + i * 3.0, 10 + ph * 50);
    final w = 4 * math.cos(time * 8 + i).abs() + 0.8;
    final coin = Rect.fromCenter(center: p, width: w, height: 4);
    canvas.drawOval(coin, _fill(Color.fromRGBO(43, 29, 22, 1 - ph)));
    canvas.drawOval(
      coin.deflate(0.6),
      _fill(Color.fromRGBO(240, 196, 70, 1 - ph)),
    );
  }
}
