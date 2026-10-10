import 'dart:math' as math;
import 'dart:ui';

import 'vector_style.dart';

/// Bảng màu Sư tử Nemea.
abstract final class LionColors {
  static const outline = Color(0xFF2B1D16);
  static const body = Color(0xFFE0A93E);
  static const bodyShade = Color(0xFFC08A2A);
  static const belly = Color(0xFFF2CF84);
  static const mane = Color(0xFF9C4F17);
  static const maneLight = Color(0xFFC0702A);
  static const nose = Color(0xFF4A2A1A);
  static const mouth = Color(0xFF7A1E1E);
  static const fang = Color(0xFFFFF8E7);
  static const eye = Color(0xFFFFD34D);
}

/// Các thông số hoạt hình của sư tử tại một khung hình.
class LionState {
  const LionState({
    this.time = 0,
    this.mouth = 0,
    this.hurt = 0,
    this.glint = -1,
    this.defeat = 0,
  });

  /// Giây trôi qua, cho các chuyển động lặp (thở, đuôi).
  final double time;

  /// Há miệng 0–1 (gầm).
  final double mouth;

  /// Vừa trúng đòn 0–1: giật lùi và loé trắng.
  final double hurt;

  /// Tia sáng quét qua bộ da không xuyên thủng, 0–1; âm = không có.
  final double glint;

  /// Gục ngã 0–1.
  final double defeat;
}

const _ow = 1.8;

Paint _fill(Color c) => Paint()..color = c;

/// Mảng có viền + đổ bóng hai tông như nhân vật (phong cách game vector).
void _outlined(Canvas canvas, Path path, Color c, {double width = _ow}) =>
    shadedPath(
      canvas,
      path,
      c,
      PartFrame.world,
      shadow: 4,
      highlight: 1.8,
      outlineWidth: width,
    );

void _leg(
  Canvas canvas,
  Offset top,
  double length,
  Color c, {
  double bend = 0,
}) {
  final knee = top + Offset(bend * 0.5, length * 0.55);
  final paw = top + Offset(bend, length);
  final path = Path()
    ..moveTo(top.dx - 9, top.dy)
    ..quadraticBezierTo(knee.dx - 9, knee.dy, paw.dx - 7, paw.dy - 6)
    ..lineTo(paw.dx + 7, paw.dy - 6)
    ..quadraticBezierTo(knee.dx + 8, knee.dy, top.dx + 10, top.dy)
    ..close();
  _outlined(canvas, path, c);
  // Bàn chân.
  _outlined(
    canvas,
    Path()..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: paw + const Offset(-3, -3),
          width: 20,
          height: 8,
        ),
        const Radius.circular(4),
      ),
    ),
    c,
  );
  // Móng vuốt.
  final claw = _fill(const Color(0xFFFFF4DC));
  for (final dx in [-11.0, -6.0, -1.0]) {
    canvas.drawPath(
      Path()
        ..moveTo(paw.dx + dx, paw.dy - 2)
        ..lineTo(paw.dx + dx - 3, paw.dy + 0.5)
        ..lineTo(paw.dx + dx + 1, paw.dy - 0.5)
        ..close(),
      claw,
    );
  }
}

/// Vẽ Sư tử Nemea mặt quay sang trái; gốc toạ độ ở mặt đất, giữa thân.
/// Kích thước khoảng 210×150.
void paintLion(Canvas canvas, LionState s) {
  final breath = math.sin(s.time * 2.2) * 0.5 + 0.5;
  final fall = _easeInOut(s.defeat);

  canvas.save();
  // Trúng đòn: giật lùi sang phải. Gục ngã: nghiêng và hạ xuống.
  canvas.translate(10 * s.hurt + 14 * fall, 0);
  // Gục đầu về phía trước, thân hạ xuống đất.
  canvas.rotate(-0.08 * fall);
  canvas.translate(0, 6 * fall);

  // Tách lớp để loé trắng / tối màu áp lên cả con sư tử.
  final tint = s.hurt > 0
      ? Color.fromRGBO(255, 255, 255, 0.75 * s.hurt)
      : fall > 0
      ? Color.fromRGBO(70, 60, 70, 0.45 * fall)
      : null;
  if (tint != null) {
    canvas.saveLayer(
      null,
      Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.srcATop),
    );
  }

  final legLen = 52 - 22 * fall;
  // Chân phía xa (tối hơn).
  final far = Color.lerp(LionColors.body, LionColors.outline, 0.25)!;
  _leg(canvas, Offset(-38, -legLen), legLen, far, bend: -4);
  _leg(canvas, Offset(52, -legLen), legLen, far, bend: 3);

  _tail(canvas, s.time, fall);

  // Thân: phập phồng theo nhịp thở.
  final bodyRect = Rect.fromCenter(
    center: Offset(8, -legLen - 22 - breath * 1.5),
    width: 150,
    height: 62 + breath * 3,
  );
  final body = Path()
    ..addRRect(RRect.fromRectAndRadius(bodyRect, const Radius.circular(30)));
  _outlined(canvas, body, LionColors.body);
  canvas.save();
  canvas.clipPath(body);
  canvas.drawOval(
    Rect.fromCenter(
      center: bodyRect.bottomCenter + const Offset(-6, -4),
      width: 120,
      height: 34,
    ),
    _fill(LionColors.belly),
  );
  // Cơ bắp đùi sau và vai (khối cơ nhìn rõ hơn).
  canvas.drawOval(
    Rect.fromCenter(
      center: bodyRect.centerRight + const Offset(-26, 4),
      width: 52,
      height: 50,
    ),
    _fill(LionColors.bodyShade.withValues(alpha: 0.7)),
  );
  canvas.drawArc(
    Rect.fromCenter(
      center: bodyRect.centerLeft + const Offset(30, 6),
      width: 40,
      height: 44,
    ),
    -0.6,
    1.6,
    false,
    Paint()
      ..color = LionColors.bodyShade
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round,
  );
  // Tia sáng quét qua bộ da không xuyên thủng.
  if (s.glint >= 0) {
    final x = bodyRect.left - 40 + (bodyRect.width + 80) * s.glint;
    canvas.drawPath(
      Path()
        ..moveTo(x, bodyRect.top - 10)
        ..lineTo(x + 22, bodyRect.top - 10)
        ..lineTo(x - 8, bodyRect.bottom + 10)
        ..lineTo(x - 30, bodyRect.bottom + 10)
        ..close(),
      _fill(const Color(0xCCFFFBE0)),
    );
  }
  canvas.restore();

  // Chân phía gần.
  _leg(canvas, Offset(-52, -legLen), legLen, LionColors.body, bend: -6);
  _leg(canvas, Offset(38, -legLen), legLen, LionColors.body, bend: 2);

  _head(canvas, Offset(-72, -legLen - 44 - breath * 1.5), s, fall);

  if (tint != null) canvas.restore();
  canvas.restore();
}

void _tail(Canvas canvas, double time, double fall) {
  final sway = math.sin(time * 1.6) * 10 * (1 - fall);
  final base = Offset(78, -84 + 30 * fall);
  final tip = Offset(108 + sway * 0.4, -126 + sway + 50 * fall);
  canvas.drawPath(
    Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(112, -70 + 20 * fall, tip.dx, tip.dy),
    Paint()
      ..color = LionColors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawPath(
    Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(112, -70 + 20 * fall, tip.dx, tip.dy),
    Paint()
      ..color = LionColors.body
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round,
  );
  // Chùm lông cuối đuôi.
  _outlined(
    canvas,
    Path()..addOval(Rect.fromCenter(center: tip, width: 15, height: 19)),
    LionColors.mane,
  );
}

void _head(Canvas canvas, Offset c, LionState s, double fall) {
  // Bờm hai lớp, răng cưa, khẽ rung theo thời gian.
  for (final (radius, color, phase) in [
    (46.0, LionColors.mane, 0.0),
    (37.0, LionColors.maneLight, 0.5),
  ]) {
    final mane = Path();
    const n = 16;
    for (var i = 0; i <= n * 2; i++) {
      final a = math.pi * 2 * i / (n * 2) + phase * 0.2;
      final wobble = math.sin(s.time * 3 + i) * 1.2;
      final r = (i.isEven ? radius : radius - 11) + wobble;
      final p = c + Offset(math.cos(a) * r + 8, math.sin(a) * r);
      i == 0 ? mane.moveTo(p.dx, p.dy) : mane.lineTo(p.dx, p.dy);
    }
    mane.close();
    _outlined(canvas, mane, color);
  }
  // Vệt lông bờm toả ra.
  final fur = Paint()
    ..color = darken(LionColors.mane, 0.25)
    ..strokeWidth = 1.6
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 12; i++) {
    final a = math.pi * 2 * i / 12 + 0.3;
    final from = c + Offset(math.cos(a) * 30 + 8, math.sin(a) * 30);
    final to = c + Offset(math.cos(a + 0.12) * 40 + 8, math.sin(a + 0.12) * 40);
    canvas.drawLine(from, to, fur);
  }

  // Tai.
  _outlined(
    canvas,
    Path()..addOval(
      Rect.fromCenter(center: c + const Offset(4, -27), width: 15, height: 13),
    ),
    LionColors.body,
  );

  // Hàm dưới xoay mở khi gầm.
  final jawPivot = c + const Offset(-4, 10);
  canvas.save();
  canvas.translate(jawPivot.dx, jawPivot.dy);
  canvas.rotate(-0.5 * s.mouth);
  final jaw = Path()
    ..moveTo(4, -4)
    ..quadraticBezierTo(-14, 8, -30, 2)
    ..lineTo(-28, -4)
    ..close();
  if (s.mouth > 0.05) {
    // Lòng miệng và răng dưới.
    canvas.drawPath(
      Path()
        ..moveTo(4, -6)
        ..lineTo(-30, -8)
        ..lineTo(-28, 0)
        ..close(),
      _fill(LionColors.mouth),
    );
    for (final x in [-24.0, -16.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, -2)
          ..lineTo(x + 3, -2)
          ..lineTo(x + 1.5, -8)
          ..close(),
        _fill(LionColors.fang),
      );
    }
  }
  _outlined(canvas, jaw, LionColors.belly);
  canvas.restore();

  // Đầu và mõm.
  _outlined(
    canvas,
    Path()..addOval(Rect.fromCircle(center: c, radius: 25)),
    LionColors.body,
  );
  final muzzle = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c + const Offset(-24, 5),
          width: 34,
          height: 22,
        ),
        const Radius.circular(11),
      ),
    );
  _outlined(canvas, muzzle, LionColors.belly);
  if (s.mouth > 0.05) {
    // Răng nanh trên.
    for (final x in [-34.0, -24.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx + x, c.dy + 13)
          ..lineTo(c.dx + x + 4, c.dy + 13)
          ..lineTo(c.dx + x + 2, c.dy + 13 + 7 * s.mouth)
          ..close(),
        _fill(LionColors.fang),
      );
    }
  }
  // Mũi.
  canvas.drawPath(
    Path()
      ..moveTo(c.dx - 42, c.dy - 3)
      ..lineTo(c.dx - 33, c.dy - 4)
      ..lineTo(c.dx - 38, c.dy + 3)
      ..close(),
    _fill(LionColors.nose),
  );

  // Mắt: giận dữ khi đánh, nhắm (gạch chéo) khi gục.
  final eye = c + const Offset(-12, -7);
  if (fall > 0.5) {
    final p = Paint()
      ..color = LionColors.outline
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(eye + const Offset(-4, -4), eye + const Offset(4, 4), p);
    canvas.drawLine(eye + const Offset(-4, 4), eye + const Offset(4, -4), p);
  } else {
    // Mắt vàng hổ phách, con ngươi dọc, chấm sáng.
    final eyeRect = Rect.fromCenter(center: eye, width: 10, height: 8);
    canvas.drawOval(
      eyeRect,
      Paint()
        ..color = LionColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawOval(
      eyeRect,
      Paint()
        ..shader = Gradient.radial(eye, 6, const [
          Color(0xFFFFE680),
          Color(0xFFE09A1A),
        ]),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: eye + const Offset(-1.5, 0.3),
        width: 2.6,
        height: 6.4,
      ),
      _fill(LionColors.outline),
    );
    canvas.drawCircle(
      eye + const Offset(-2.6, -1.6),
      1.1,
      _fill(const Color(0xFFFFFFFF)),
    );
    canvas.drawLine(
      eye + const Offset(-7, -8),
      eye + const Offset(7, -3),
      Paint()
        ..color = LionColors.outline
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }
}

double _easeInOut(double t) {
  final x = t.clamp(0.0, 1.0);
  return x < 0.5 ? 2 * x * x : 1 - math.pow(-2 * x + 2, 2) / 2;
}
