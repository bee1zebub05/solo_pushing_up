import 'dart:math' as math;
import 'dart:ui';

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
      null,
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
    // Ức có vảy đồng.
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(-6 + i * 5.0, 0), width: 6, height: 5),
        0,
        math.pi,
        false,
        _stroke(_bronze, 1.2),
      );
    }

    // Đầu, mào gai, mỏ đồng dài và cong.
    final head = Path()
      ..addOval(Rect.fromCircle(center: const Offset(-14, -9), radius: 6));
    _shaded(canvas, head, const Color(0xFF4A3A33), shadow: 2);
    final crest = Path();
    for (var i = 0; i < 3; i++) {
      crest.addPath(
        _poly([
          Offset(-12 + i * 3.0, -14),
          Offset(-6 + i * 4.0, -21 + i * 2.0),
          Offset(-9 + i * 3.0, -13),
        ]),
        Offset.zero,
      );
    }
    _shaded(canvas, crest, const Color(0xFFB3261E), shadow: 1);
    final beak = Path()
      ..moveTo(-18, -11)
      ..quadraticBezierTo(-30 - 4 * attack, -11, -34 - 4 * attack, -4)
      ..quadraticBezierTo(-28, -7, -18, -6)
      ..close();
    _shaded(canvas, beak, _bronze, shadow: 1.2);
    glint(canvas, const Offset(-25, -10), 1.6);
    _glowEye(canvas, const Offset(-15, -10), 1.6, const Color(0xFFFF3B1F));

    // Móng quặp thò xuống.
    for (final x in [-4.0, 2.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, 4)
          ..lineTo(x - 1, 10)
          ..lineTo(x - 4, 12),
        _stroke(const Color(0xFFE8D9B0), 1.4),
      );
    }

    _wing(canvas, const Offset(0, -4), flap);
    canvas.restore();
  });
}

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
  const bone = Color(0xFFD9D2B8);
  const bronze = Color(0xFFB98A3E);
  final sway = math.sin(time * 1.8) * 1.2;
  final lunge = attack;

  canvas.save();
  // Phần dưới đất bị che bằng vùng cắt.
  canvas.clipRect(const Rect.fromLTRB(-80, -140, 80, 1));
  canvas.translate(0, 78 * (1 - rise));
  _withHurt(canvas, hurt, () {
    // Chân xương.
    shadedChain(canvas, [
      (const Offset(6, -34), const Offset(10, -16), 4, 3),
      (const Offset(10, -16), const Offset(12, 0), 3, 3),
    ], darken(bone, 0.15));
    shadedChain(canvas, [
      (const Offset(-4, -34), const Offset(-10, -16), 4, 3),
      (const Offset(-10, -16), const Offset(-12, 0), 3, 3),
    ], bone);
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
    // Lồng ngực + giáp ngực đồng nứt vỡ.
    final chest = Path()
      ..moveTo(-12, -38)
      ..lineTo(-14, -62)
      ..quadraticBezierTo(0, -68, 14, -62)
      ..lineTo(12, -38)
      ..close();
    _shaded(canvas, chest, bronze, shadow: 3);
    canvas.drawPath(
      Path()
        ..moveTo(2, -64)
        ..lineTo(-2, -54)
        ..lineTo(4, -48)
        ..lineTo(0, -40),
      _stroke(_outline, 1.2),
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(-9, -58 + i * 6.0),
        Offset(-3, -56 + i * 6.0),
        _stroke(const Color(0xFF7A5A28), 1),
      );
    }

    // Tay cầm khiên (xa) và khiên tròn hoplon có hình răng rồng.
    shadedChain(canvas, [
      (const Offset(10, -60), const Offset(14, -46), 3, 2.5),
    ], darken(bone, 0.15));
    final shield = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(8 + sway * 0.3, -46), radius: 17),
      );
    _shaded(canvas, shield, const Color(0xFF8E2A1E), shadow: 4);
    canvas.drawCircle(Offset(8 + sway * 0.3, -46), 17, _stroke(bronze, 2.4));
    canvas.drawPath(
      _poly([
        Offset(4 + sway * 0.3, -54),
        Offset(12 + sway * 0.3, -54),
        Offset(8 + sway * 0.3, -36),
      ]),
      _fill(bone),
    );

    // Đầu sọ trong mũ Corinth có mào lông đỏ.
    final headC = Offset(-1 + sway * 0.4 - 4 * lunge, -76);
    final crest = Path()
      ..moveTo(headC.dx - 10, headC.dy - 10)
      ..quadraticBezierTo(headC.dx, headC.dy - 26, headC.dx + 16, headC.dy - 8)
      ..quadraticBezierTo(
        headC.dx + 4,
        headC.dy - 14,
        headC.dx - 10,
        headC.dy - 10,
      )
      ..close();
    _shaded(canvas, crest, const Color(0xFFB3261E), shadow: 2);
    final helmet = Path()
      ..moveTo(headC.dx - 10, headC.dy + 10)
      ..lineTo(headC.dx - 11, headC.dy - 6)
      ..quadraticBezierTo(headC.dx, headC.dy - 14, headC.dx + 10, headC.dy - 6)
      ..lineTo(headC.dx + 9, headC.dy + 10)
      ..lineTo(headC.dx + 2, headC.dy + 8)
      ..lineTo(headC.dx + 1, headC.dy + 2)
      ..lineTo(headC.dx - 3, headC.dy + 2)
      ..lineTo(headC.dx - 4, headC.dy + 10)
      ..close();
    // Hàm xương lộ ra dưới mũ.
    canvas.drawRect(
      Rect.fromLTWH(headC.dx - 4, headC.dy + 3, 6, 6),
      _fill(bone),
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(headC.dx - 3 + i * 2.0, headC.dy + 5),
        Offset(headC.dx - 3 + i * 2.0, headC.dy + 8),
        _stroke(_outline, 0.6),
      );
    }
    _shaded(canvas, helmet, bronze, shadow: 3);
    // Khe mắt tối với hai đốm lửa xanh ma quái.
    canvas.drawRect(
      Rect.fromLTWH(headC.dx - 9, headC.dy - 3, 9, 3.4),
      _fill(const Color(0xFF120C08)),
    );
    for (final dx in [-7.0, -2.5]) {
      _glowEye(
        canvas,
        Offset(headC.dx + dx, headC.dy - 1.4),
        1.1,
        const Color(0xFF7CFF6B),
      );
    }
    glint(canvas, Offset(headC.dx - 5, headC.dy - 8), 2);

    // Tay cầm giáo (gần): đâm tới khi tấn công.
    final hand = Offset(-14 - 14 * lunge, -52 + 4 * lunge);
    shadedChain(canvas, [
      (const Offset(-10, -60), Offset(-14 - 6 * lunge, -52), 3, 2.5),
      (Offset(-14 - 6 * lunge, -52), hand, 2.5, 2.5),
    ], bone);
    final spearBack = hand + const Offset(30, -30);
    final spearTip = hand + Offset(-30 - 10 * lunge, 30 * 0 - 6);
    canvas.drawLine(spearBack, spearTip, _stroke(_outline, 3.4));
    canvas.drawLine(spearBack, spearTip, _stroke(const Color(0xFF7A5232), 1.8));
    final dir = (spearTip - spearBack) / (spearTip - spearBack).distance;
    final n = Offset(-dir.dy, dir.dx);
    final head = _poly([
      spearTip - n * 3,
      spearTip + dir * 10,
      spearTip + n * 3,
    ]);
    _shaded(canvas, head, const Color(0xFFCFC6B0), shadow: 1);
  });
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

// ---------------------------------------------------------------------------
// Harpy: mình chim mặt người, cánh thay tay, móng quắp.

void paintHarpy(
  Canvas canvas, {
  double time = 0,
  double attack = 0,
  double hurt = 0,
}) {
  const feather = Color(0xFF5B4A66);
  const skin = Color(0xFFB9B3A2);
  final flap = math.sin(time * 6);
  final hover = math.sin(time * 3) * 3;
  canvas.save();
  canvas.translate(0, -60 + hover);
  _withHurt(canvas, hurt, () {
    // Cánh xa.
    _harpyWing(canvas, const Offset(6, -16), flap, darken(feather, 0.25));
    // Đuôi lông rách tả tơi.
    final tail = Path();
    for (var i = 0; i < 4; i++) {
      tail.addPath(
        _poly([
          Offset(2 + i * 2.0, 10),
          Offset(10 + i * 5.0, 30 - i * 2.0),
          Offset(6 + i * 3.0, 12),
        ]),
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
    // Vạt lông xếp lớp.
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(0, -6 + i * 7.0), width: 14, height: 8),
        0.2,
        math.pi - 0.4,
        false,
        _stroke(darken(feather, 0.3), 1),
      );
    }
    // Chân chim, móng quắp vươn ra khi vồ.
    for (final x in [-4.0, 4.0]) {
      final foot = Offset(x - 8 * attack, 24 + 4 * attack);
      canvas.drawLine(Offset(x, 12), foot, _stroke(_outline, 3.4));
      canvas.drawLine(
        Offset(x, 12),
        foot,
        _stroke(const Color(0xFFC9A85A), 1.8),
      );
      for (final a in [2.2, 1.6, 1.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(foot.dx, foot.dy)
            ..quadraticBezierTo(
              foot.dx + math.cos(a) * 4,
              foot.dy + math.sin(a) * 4,
              foot.dx + math.cos(a + 0.6) * 6,
              foot.dy + math.sin(a + 0.6) * 6,
            ),
          _stroke(const Color(0xFF2B1D16), 1.4),
        );
      }
    }
    // Đầu: mặt hốc hác, tóc rối bay.
    const face = Offset(-2, -26);
    final hair = Path();
    for (var i = 0; i < 7; i++) {
      final a = -math.pi * 0.95 + i * 0.32;
      final wave = math.sin(time * 4 + i) * 2;
      hair.addPath(
        _poly([
          face + Offset(math.cos(a) * 6, math.sin(a) * 6),
          face +
              Offset(math.cos(a + 0.2) * 16 + 8, math.sin(a + 0.2) * 14 + wave),
          face + Offset(math.cos(a + 0.4) * 6, math.sin(a + 0.4) * 6),
        ]),
        Offset.zero,
      );
    }
    _shaded(canvas, hair, const Color(0xFF2C2433), shadow: 2);
    final head = Path()
      ..moveTo(face.dx - 7, face.dy - 4)
      ..quadraticBezierTo(face.dx - 6, face.dy - 10, face.dx + 2, face.dy - 9)
      ..quadraticBezierTo(face.dx + 7, face.dy - 4, face.dx + 4, face.dy + 6)
      ..quadraticBezierTo(face.dx - 2, face.dy + 10, face.dx - 7, face.dy + 4)
      ..close();
    _shaded(canvas, head, skin, shadow: 2);
    // Hốc mắt trũng tối, đồng tử đỏ.
    canvas.drawOval(
      Rect.fromCenter(center: face + const Offset(-3, -2), width: 5, height: 4),
      _fill(const Color(0xFF3A2A33)),
    );
    _glowEye(canvas, face + const Offset(-3.4, -2), 1, const Color(0xFFFF4A3A));
    // Miệng há rít, răng nhọn.
    final scream = 2 + 4 * attack;
    canvas.drawOval(
      Rect.fromCenter(
        center: face + const Offset(-4, 4),
        width: 4,
        height: scream,
      ),
      _fill(const Color(0xFF3A0E12)),
    );
    canvas.drawLine(
      face + Offset(-5.5, 4 - scream / 2),
      face + Offset(-2.5, 4 - scream / 2),
      _stroke(const Color(0xFFF2EAD8), 0.8),
    );
    _harpyWing(canvas, const Offset(-2, -16), flap, feather);
  });
  canvas.restore();
}

void _harpyWing(Canvas canvas, Offset root, double flap, Color color) {
  canvas.save();
  canvas.translate(root.dx, root.dy);
  canvas.rotate(-0.7 * flap + 0.2);
  final wing = Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(14, -26, 34, -30)
    ..lineTo(30, -22)
    ..lineTo(34, -16)
    ..lineTo(26, -12)
    ..lineTo(28, -4)
    ..lineTo(18, -2)
    ..lineTo(16, 6)
    ..close();
  _shaded(canvas, wing, color, shadow: 3);
  // Móng ở khớp cánh (cánh thay tay).
  canvas.drawPath(
    Path()
      ..moveTo(32, -30)
      ..quadraticBezierTo(38, -32, 38, -26),
    _stroke(const Color(0xFFE8D9B0), 1.4),
  );
  canvas.restore();
}

// ---------------------------------------------------------------------------
// Lợn rừng Erymanthus (tinh anh): bờm gai dựng, nanh cong khổng lồ.

/// [charge] 0–1: cúi đầu lao húc (người chơi phải ngồi xuống để né).
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
    // Chân ngắn, móng guốc.
    for (final (x, far) in [
      (-26.0, true),
      (34.0, true),
      (-36.0, false),
      (26.0, false),
    ]) {
      final c = far ? darken(hide, 0.3) : hide;
      shadedChain(canvas, [(Offset(x, -30), Offset(x - 2, -6), 8, 5.5)], c);
      canvas.drawPath(
        _poly([
          Offset(x - 8, 0),
          Offset(x - 7, -7),
          Offset(x + 3, -7),
          Offset(x + 4, 0),
        ]),
        _fill(const Color(0xFF241812)),
      );
    }
    // Thân to, lưng gù.
    final body = Path()
      ..moveTo(-44, -30 + dip)
      ..cubicTo(-46, -60 + dip, -10, -72 - breath, 22, -64)
      ..cubicTo(48, -58, 58, -40, 52, -24)
      ..cubicTo(40, -14, -20, -12, -44, -30 + dip)
      ..close();
    _shaded(canvas, body, hide, shadow: 6);
    // Lông cứng phủ khắp thân, xuôi từ gáy về mông.
    furStrokes(
      canvas,
      body,
      const Color(0xFF2E211B),
      dir: const Offset(1, 0.5),
      count: 60,
      length: 6,
      width: 1,
      seed: 5,
    );
    // Vằn lông.
    canvas.save();
    canvas.clipPath(body);
    for (var i = 0; i < 6; i++) {
      canvas.drawLine(
        Offset(-20 + i * 12.0, -60),
        Offset(-26 + i * 12.0, -36),
        _stroke(hideLight, 1.4),
      );
    }
    canvas.restore();
    // Bờm gai dựng dọc sống lưng (dựng cao hơn khi húc).
    final bristles = Path();
    for (var i = 0; i < 11; i++) {
      final x = -38 + i * 7.0;
      final top = -66 - (i < 6 ? i * 1.0 : (10 - i) * 1.2) - breath;
      final h = 12 + 6 * attack + (i.isEven ? 4 : 0);
      bristles.addPath(
        _poly([
          Offset(x - 4, top + 8 + (i < 2 ? dip : 0)),
          Offset(x + 2, top - h + (i < 2 ? dip : 0)),
          Offset(x + 5, top + 8),
        ]),
        Offset.zero,
      );
    }
    _shaded(canvas, bristles, const Color(0xFF2E211B), shadow: 2);

    // Đầu cúi, mõm dài, nanh cong lên.
    canvas.save();
    canvas.translate(-42, -38 + dip);
    canvas.rotate(0.25 * attack);
    final head = Path()
      ..moveTo(8, -18)
      ..cubicTo(-6, -22, -20, -14, -30, -6)
      ..lineTo(-32, 6)
      ..cubicTo(-20, 10, -4, 12, 10, 8)
      ..close();
    _shaded(canvas, head, hide, shadow: 4);
    // Đĩa mõm.
    final snout = Path()
      ..addOval(
        Rect.fromCenter(center: const Offset(-32, 0), width: 8, height: 14),
      );
    _shaded(canvas, snout, const Color(0xFF9C6E5E), shadow: 1.5);
    for (final dy in [-3.0, 3.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(-33, dy), width: 2.4, height: 3),
        _fill(const Color(0xFF241812)),
      );
    }
    // Nanh: to, cong vút, ngà vàng.
    for (final (x, s) in [(-18.0, 1.0), (-12.0, 0.7)]) {
      final tusk = Path()
        ..moveTo(x, 6)
        ..quadraticBezierTo(x - 14 * s, 6, x - 16 * s, -12 * s)
        ..quadraticBezierTo(x - 9 * s, -2, x + 4, 2)
        ..close();
      _shaded(canvas, tusk, const Color(0xFFF2E6C4), shadow: 1.5);
    }
    // Tai nhọn cụp ra sau, mắt đỏ nhỏ dữ tợn.
    final ear = _poly(const [Offset(2, -18), Offset(14, -28), Offset(10, -14)]);
    _shaded(canvas, ear, darken(hide, 0.1), shadow: 1.5);
    _glowEye(canvas, const Offset(-10, -10), 1.6, const Color(0xFFFF2A1A));
    canvas.drawLine(
      const Offset(-15, -15),
      const Offset(-4, -11),
      _stroke(_outline, 2.2),
    );
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

void paintYoungHydra(
  Canvas canvas, {
  double time = 0,
  double attack = 0,
  double hurt = 0,
  int heads = 3,
}) {
  const scale = Color(0xFF3F7A4A);
  const belly = Color(0xFFD8C978);
  _withHurt(canvas, hurt, () {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(4, 1), width: 110, height: 12),
      _fill(const Color(0x55301C10)),
    );
    // Đuôi cuộn.
    shadedChain(canvas, [
      (const Offset(30, -14), const Offset(56, -10), 12, 7),
      (const Offset(56, -10), const Offset(66, -26), 7, 3),
    ], darken(scale, 0.1));
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
    for (final (base, tip) in necks) {
      final mid = Offset.lerp(base, tip, 0.5)! + const Offset(10, 0);
      shadedChain(canvas, [(base, mid, 8, 6), (mid, tip, 6, 5)], scale);
    }
    // Thân.
    final body = Path()..addOval(const Rect.fromLTRB(-30, -40, 40, 0));
    _shaded(canvas, body, scale, shadow: 5);
    canvas.save();
    canvas.clipPath(body);
    canvas.drawOval(const Rect.fromLTRB(-26, -16, 34, 6), _fill(belly));
    for (var i = 0; i < 5; i++) {
      canvas.drawLine(
        Offset(-18 + i * 11.0, -14),
        Offset(-20 + i * 11.0, 0),
        _stroke(darken(belly, 0.2), 1),
      );
    }
    // Vảy trên lưng.
    for (var i = 0; i < 6; i++) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(-14 + i * 9.0, -30),
          width: 8,
          height: 6,
        ),
        0,
        math.pi,
        false,
        _stroke(lighten(scale, 0.25), 1),
      );
    }
    canvas.restore();
    // Đầu rắn.
    for (var i = 0; i < necks.length; i++) {
      final (_, tip) = necks[i];
      final open =
          attack * (i == heads ~/ 2 ? 1 : 0.4) +
          0.15 * (0.5 + 0.5 * math.sin(time * 2.2 + i));
      _hydraHead(canvas, tip, open, time + i);
    }
  });
}

void _hydraHead(Canvas canvas, Offset at, double open, double time) {
  const scale = Color(0xFF4C8E56);
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.scale(1.7);
  // Hàm dưới.
  canvas.save();
  canvas.rotate(-0.6 * open);
  final jaw = _poly(const [
    Offset(4, 1),
    Offset(-14, 2),
    Offset(-12, 5),
    Offset(4, 5),
  ]);
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
  // Đầu dẹt hình tam giác, gờ mày gai.
  final head = Path()
    ..moveTo(6, -6)
    ..quadraticBezierTo(-4, -10, -16, -2)
    ..lineTo(-14, 2)
    ..lineTo(6, 3)
    ..close();
  _shaded(canvas, head, scale, shadow: 2);
  canvas.drawPath(
    _poly(const [Offset(-2, -7), Offset(4, -14), Offset(4, -6)]),
    _fill(const Color(0xFF2E5A36)),
  );
  // Nanh rỉ nọc độc.
  canvas.drawPath(
    _poly([
      const Offset(-12, 1),
      const Offset(-10, 1),
      Offset(-11, 5 + 2 * open),
    ]),
    _fill(const Color(0xFFFFF6DE)),
  );
  final drip = (time * 0.8) % 1;
  canvas.drawCircle(
    Offset(-11, 7 + 2 * open + 6 * drip),
    1.1,
    _fill(Color.fromRGBO(170, 255, 90, 1 - drip)),
  );
  _glowEye(canvas, const Offset(-6, -4), 1.2, const Color(0xFFFFD21F));
  canvas.drawLine(
    const Offset(-9, -6),
    const Offset(-2, -6.5),
    _stroke(_outline, 1.4),
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
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, 1 - fall));
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
    // Chân đá.
    for (final (x, c) in [(6.0, marbleDark), (-6.0, marble)]) {
      shadedChain(canvas, [
        (Offset(x, -44), Offset(x * 1.2, -26), 6, 5),
        (Offset(x * 1.2, -26), Offset(x * 1.3, -9), 5, 4.5),
      ], c);
    }
    // Thân giáp cơ bắp (giáp đúc kiểu cuirass).
    final body = Path()
      ..moveTo(-14, -42)
      ..lineTo(-16, -72)
      ..quadraticBezierTo(0, -80, 16, -72)
      ..lineTo(14, -42)
      ..quadraticBezierTo(0, -38, -14, -42)
      ..close();
    _shaded(canvas, body, marble, shadow: 4);
    canvas.save();
    canvas.clipPath(body);
    // Cơ ngực, bụng đúc trên giáp.
    final carve = _stroke(marbleDark, 1);
    canvas.drawArc(
      const Rect.fromLTWH(-12, -72, 12, 9),
      0.3,
      2.4,
      false,
      carve,
    );
    canvas.drawArc(const Rect.fromLTWH(0, -72, 12, 9), 0.3, 2.4, false, carve);
    for (var r = 0; r < 2; r++) {
      canvas.drawLine(
        Offset(-6, -58 + r * 7.0),
        Offset(6, -58 + r * 7.0),
        carve,
      );
    }
    // Vân đá (gạch bóng mảnh) ở nửa khuất.
    canvas.clipRect(const Rect.fromLTRB(2, -80, 20, -38));
    hatch(
      canvas,
      body,
      const Color(0x44706858),
      spacing: 2.2,
      angle: 1.2,
      width: 0.6,
    );
    canvas.restore();

    // Khiên đá tròn có vết nứt.
    final shieldC = Offset(10 + sway * 0.4, -54);
    final shield = Path()
      ..addOval(Rect.fromCircle(center: shieldC, radius: 15));
    _shaded(canvas, shield, marbleDark, shadow: 4);
    canvas.drawCircle(shieldC, 10, _stroke(const Color(0xFF8E8676), 1.2));

    // Đầu đội mũ Corinth bằng đá, mào đá.
    final head = Offset(-1 + sway * 0.3 - 3 * lunge, -86);
    final crest = Path()
      ..moveTo(head.dx - 9, head.dy - 9)
      ..quadraticBezierTo(head.dx, head.dy - 22, head.dx + 14, head.dy - 7)
      ..quadraticBezierTo(head.dx + 3, head.dy - 12, head.dx - 9, head.dy - 9)
      ..close();
    _shaded(canvas, crest, marbleDark, shadow: 2);
    final helmet = Path()
      ..moveTo(head.dx - 9, head.dy + 9)
      ..lineTo(head.dx - 10, head.dy - 5)
      ..quadraticBezierTo(head.dx, head.dy - 12, head.dx + 9, head.dy - 5)
      ..lineTo(head.dx + 8, head.dy + 9)
      ..close();
    _shaded(canvas, helmet, marble, shadow: 3);
    canvas.drawRect(
      Rect.fromLTWH(head.dx - 8, head.dy - 2, 8, 3),
      _fill(const Color(0xFF2A2230)),
    );
    for (final dx in [-6.0, -2.0]) {
      _glowEye(canvas, Offset(head.dx + dx, head.dy - 0.6), 1, stagnation);
    }

    // Tay đá cầm giáo, đâm tới khi tấn công.
    final hand = Offset(-16 - 14 * lunge, -58);
    shadedChain(canvas, [
      (const Offset(-12, -70), Offset(-18 - 4 * lunge, -62), 4.5, 4),
      (Offset(-18 - 4 * lunge, -62), hand, 4, 4),
    ], marble);
    final back = hand + const Offset(26, -28);
    final tip = hand + Offset(-26 - 8 * lunge, -2);
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
