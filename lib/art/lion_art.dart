import 'dart:math' as math;
import 'dart:ui';

import 'vector_style.dart';

/// Bảng màu Sư tử Nemea: da vàng ánh kim (không vũ khí nào xuyên thủng),
/// bờm đỏ sẫm ngả đen ở ngọn như tranh cổ, mắt hổ phách rực.
abstract final class LionColors {
  static const outline = Color(0xFF241510);
  static const body = Color(0xFFC99140);
  static const bodyShade = Color(0xFF94652A);
  static const belly = Color(0xFFE2C08A);
  static const mane = Color(0xFF5E2210);
  static const maneMid = Color(0xFF8E3714);
  static const maneLight = Color(0xFFC0611E);
  static const nose = Color(0xFF3A1E14);
  static const mouth = Color(0xFF5C0F12);
  static const tongue = Color(0xFFB0383C);
  static const fang = Color(0xFFFFF6DE);
  static const scar = Color(0xFF8A4A2A);
}

/// Các thông số hoạt hình của sư tử tại một khung hình.
class LionState {
  const LionState({
    this.time = 0,
    this.mouth = 0,
    this.attackPhase = -1,
    this.hurt = 0,
    this.glint = -1,
    this.defeat = 0,
  });

  /// Giây trôi qua, cho các chuyển động lặp (thở, đuôi, chớp mắt).
  final double time;

  /// Há miệng 0–1 (gầm) khi không có [attackPhase].
  final double mouth;

  /// Tiến độ đòn vồ 0–1 (lấy đà, vồ, thu về); âm = không tấn công.
  final double attackPhase;

  /// Vừa trúng đòn 0–1: giật lùi, co người, loé trắng.
  final double hurt;

  /// Đòn bị bộ da chặn 0–1: khiên lục giác vàng loé lên; âm = không có.
  final double glint;

  /// Gục ngã 0–1.
  final double defeat;
}

Paint _fill(Color c) => Paint()..color = c;

double _smooth(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// Mảng có viền + đổ bóng hai tông như nhân vật.
void _shaded(
  Canvas canvas,
  Path path,
  Color c, {
  double shadow = 4,
  double width = 2,
}) => shadedPath(
  canvas,
  path,
  c,
  PartFrame.world,
  shadow: shadow,
  highlight: 1.8,
  outlineWidth: width,
);

/// Vẽ Sư tử Nemea mặt quay sang trái; gốc toạ độ ở mặt đất, giữa thân.
/// Kích thước khoảng 210×150.
void paintLion(Canvas canvas, LionState s) {
  final t = s.time;
  final breath = math.sin(t * 2.2) * 0.5 + 0.5;
  final fall = _smooth(s.defeat);

  // Đòn vồ: lấy đà (lùi, hạ thấp) rồi lao tới vung vuốt.
  var windup = 0.0, strike = 0.0;
  final p = s.attackPhase;
  if (p >= 0) {
    windup = p < 0.4
        ? _smooth(p / 0.4)
        : p < 0.55
        ? 1 - _smooth((p - 0.4) / 0.15)
        : 0;
    strike = p < 0.4
        ? 0
        : p < 0.55
        ? _smooth((p - 0.4) / 0.15)
        : 1 - _smooth((p - 0.55) / 0.45);
  }
  final roar = math.max(s.mouth, math.max(strike, windup * 0.4));

  // Bóng tiếp đất (không đi theo thân).
  // Bóng đổ tím lạnh ngả về phía xa nắng + bóng tiếp xúc dưới bàn chân.
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(16 - 10 * strike, 3),
      width: 230 - 20 * windup,
      height: 18,
    ),
    _fill(const Color(0x30402A50)),
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(4 - 10 * strike, 2),
      width: 200 - 20 * windup,
      height: 12,
    ),
    _fill(const Color(0x40301C30)),
  );
  for (final x in [-62.0, -44.0, 56.0, 72.0]) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x - 4, 1), width: 30, height: 5),
      _fill(const Color(0x55201018)),
    );
  }

  // Báo trước đòn vồ: chân sau cào đất, bụi tung (vẽ sau lưng thân).
  if (windup > 0.05) _pawDust(canvas, t, windup);

  canvas.save();
  // Gục nằm rạp: không để bờm/đầu lòi xuống dưới mặt đất.
  if (fall > 0) canvas.clipRect(const Rect.fromLTRB(-400, -400, 400, 4));
  // Rung gầm gừ khi lấy đà (báo hiệu đọc được trước đòn).
  final growl = windup * math.sin(t * 60) * 1.2;
  canvas.translate(
    10 * s.hurt + 10 * windup - 18 * strike + 10 * fall + growl,
    0,
  );
  // Trúng đòn: co người lại.
  canvas.scale(1 + 0.04 * s.hurt, 1 - 0.05 * s.hurt);

  final tint = s.hurt > 0
      ? Color.fromRGBO(255, 255, 255, 0.7 * s.hurt)
      : fall > 0
      ? Color.fromRGBO(60, 50, 64, 0.45 * fall)
      : null;
  if (tint != null) {
    canvas.saveLayer(
      null,
      Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.srcATop),
    );
  }

  // Thân hạ thấp khi lấy đà, gục thì nằm rạp.
  final drop = 6 * windup + 34 * fall;
  final lift = breath * 1.5;
  final far = Color.lerp(LionColors.body, LionColors.outline, 0.3)!;

  // Chân xa.
  _leg(
    canvas,
    hip: Offset(-30, -84 + drop),
    paw: Offset(-44 + 8 * windup - 30 * fall, 0),
    color: far,
    front: true,
  );
  _leg(
    canvas,
    hip: Offset(66, -86 + drop),
    paw: Offset(56 + 12 * fall, 0),
    color: far,
    front: false,
  );

  _tail(canvas, t, fall, drop, strike);

  final body = _bodyPath(drop, lift);
  _shaded(canvas, body, LionColors.body, shadow: 6);
  _hideDetail(canvas, body, drop, lift, s, t);

  // Chân gần: chân trước vung vuốt khi vồ.
  final swipe = strike * (1 - fall);
  _leg(
    canvas,
    hip: Offset(78, -82 + drop),
    paw: Offset(72 + 8 * fall, 0),
    color: LionColors.body,
    front: false,
  );
  final pawGround = Offset(-62 + 10 * windup - 36 * fall, 0);
  const pawSwipe = Offset(-128, -44);
  final paw = Offset.lerp(pawGround, pawSwipe, swipe)!;
  void frontLeg() => _leg(
    canvas,
    hip: Offset(-46, -80 + drop),
    paw: paw,
    color: LionColors.body,
    front: true,
    clawsOut: swipe > 0.2 || windup > 0.6,
  );
  // Đứng yên: chân trước sau bờm. Vồ: chân vung ra trước cả đầu.
  if (swipe <= 0.15) frontLeg();

  final head = Offset(
    -74 - 16 * strike + 4 * windup - 10 * fall,
    // Gục: đầu rũ xuống sát đất.
    -104 + drop + 26 * fall + 10 * windup - lift + math.sin(t * 1.1) * 1.2,
  );
  _mane(canvas, head, t, fall);
  canvas.save();
  canvas.translate(head.dx, head.dy);
  canvas.rotate(-0.32 * fall); // mõm chúi xuống
  canvas.scale(1.18);
  _head(canvas, Offset.zero, s, roar, fall, t);
  canvas.restore();
  if (swipe > 0.15) frontLeg();
  if (swipe > 0.25) _clawTrails(canvas, paw, swipe);
  if (roar > 0.5 && fall == 0) _roarWaves(canvas, head, roar, t);

  if (tint != null) canvas.restore();

  if (fall > 0.3) _stagnationLeaving(canvas, t, fall, drop);
  if (s.glint >= 0) _shieldFlash(canvas, head + const Offset(12, 14), s.glint);
  canvas.restore();
}

Path _bodyPath(double drop, double lift) {
  final y = drop - lift;
  return Path()
    ..moveTo(-60, -112 + y)
    ..cubicTo(-30, -124 + y, 8, -102 + y, 40, -104 + y)
    ..cubicTo(72, -112 + y, 98, -100 + y, 98, -78 + y)
    ..cubicTo(98, -58 + y, 86, -48 + y, 70, -50 + y)
    ..cubicTo(40, -54 + y, 22, -64 + y + lift, -6, -60 + y + lift)
    ..cubicTo(-36, -56 + y, -64, -54 + y, -72, -72 + y)
    ..cubicTo(-78, -90 + y, -72, -106 + y, -60, -112 + y)
    ..close();
}

/// Cơ bắp, bụng sáng, ánh kim của bộ da và đường cơ.
void _hideDetail(
  Canvas canvas,
  Path body,
  double drop,
  double lift,
  LionState s,
  double t,
) {
  final y = drop - lift;
  canvas.save();
  canvas.clipPath(body);
  // Bụng sáng màu.
  canvas.drawPath(
    Path()
      ..moveTo(-74, -66 + y)
      ..cubicTo(-40, -66 + y, 20, -70 + y, 70, -58 + y)
      ..lineTo(70, -40 + y)
      ..lineTo(-74, -40 + y)
      ..close(),
    _fill(LionColors.belly),
  );
  // Khối đùi sau và bả vai sẫm.
  canvas.drawOval(
    Rect.fromCenter(center: Offset(72, -78 + y), width: 54, height: 50),
    _fill(LionColors.bodyShade.withValues(alpha: 0.55)),
  );
  canvas.drawOval(
    Rect.fromCenter(center: Offset(-40, -86 + y), width: 44, height: 46),
    _fill(LionColors.bodyShade.withValues(alpha: 0.35)),
  );
  final muscle = Paint()
    ..color = LionColors.bodyShade
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round;
  // Bả vai, xương sườn, cơ đùi.
  canvas.drawArc(
    Rect.fromCenter(center: Offset(-38, -84 + y), width: 40, height: 44),
    -0.4,
    1.8,
    false,
    muscle,
  );
  for (var i = 0; i < 3; i++) {
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(4 + i * 12, -78 + y),
        width: 18,
        height: 30,
      ),
      0.4,
      1.2,
      false,
      muscle..strokeWidth = 1.2,
    );
  }
  canvas.drawArc(
    Rect.fromCenter(center: Offset(70, -80 + y), width: 46, height: 42),
    2.2,
    2.4,
    false,
    muscle..strokeWidth = 1.8,
  );
  // Ánh kim chạy dọc sống lưng: da cứng như giáp.
  canvas.drawPath(
    Path()
      ..moveTo(-50, -110 + y)
      ..cubicTo(-24, -118 + y, 10, -100 + y, 40, -101 + y)
      ..cubicTo(70, -108 + y, 90, -98 + y, 94, -84 + y),
    Paint()
      ..color = const Color(0xAAFFF0B0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round,
  );
  // Vệt sáng lấp loá chạy chậm qua da (luôn có, nhắc rằng da bất khả xâm).
  final sweep = (t * 0.35) % 1.6 - 0.3;
  final x = -80 + 190 * sweep;
  canvas.drawPath(
    Path()
      ..moveTo(x, -130 + y)
      ..lineTo(x + 10, -130 + y)
      ..lineTo(x - 14, -40 + y)
      ..lineTo(x - 24, -40 + y)
      ..close(),
    _fill(const Color(0x40FFF8D8)),
  );
  // Nét lông ngắn theo hướng mọc (từ đầu về đuôi, xuôi xuống bụng).
  final fur = Path();
  final rnd = math.Random(9);
  for (var i = 0; i < 34; i++) {
    final p = Offset(
      -60 + rnd.nextDouble() * 150,
      -112 + y + rnd.nextDouble() * 58,
    );
    final len = 4 + rnd.nextDouble() * 4;
    fur
      ..moveTo(p.dx, p.dy)
      ..quadraticBezierTo(
        p.dx + len * 0.6,
        p.dy + 1,
        p.dx + len,
        p.dy + len * 0.5,
      );
  }
  canvas.drawPath(
    fur,
    Paint()
      ..color = LionColors.bodyShade.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round,
  );
  // Sẹo cũ trên hông: dấu những kẻ đã thử và thất bại.
  final scar = Paint()
    ..color = LionColors.scar
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 3; i++) {
    canvas.drawLine(
      Offset(20 + i * 6, -96 + y),
      Offset(12 + i * 6, -80 + y),
      scar,
    );
  }
  canvas.restore();
}

/// Chân ba khúc (vai/hông, khuỷu/cổ chân, bàn) bằng chuỗi viên thuốc.
void _leg(
  Canvas canvas, {
  required Offset hip,
  required Offset paw,
  required Color color,
  required bool front,
  bool clawsOut = false,
}) {
  final pawTop = paw + const Offset(0, -8);
  final d = pawTop - hip;
  final len = d.distance;
  final n = Offset(-d.dy, d.dx) / (len == 0 ? 1 : len);
  // Chân trước: khuỷu hơi lùi sau. Chân sau: cổ chân gập ngược rõ.
  final mid =
      Offset.lerp(hip, pawTop, front ? 0.55 : 0.6)! + n * (front ? -5 : -14);
  // Giải phẫu mèo lớn: chân trước có khối vai sau dày, khuỷu nhô, cẳng
  // chân phồng phía trước; chân sau đùi + cơ đùi sau khổng lồ, cổ chân (hock)
  // thon và gập ngược.
  shadedLimb(
    canvas,
    [
      (hip, mid, front ? _foreUpper : _hindUpper),
      (mid, pawTop, front ? _foreLower : _hindLower),
    ],
    color,
    shadow: 4,
  );
  // Đường cơ bắp chân (sel-line), gân cổ chân.
  final line = Paint()
    ..color = darken(color, 0.3).withValues(alpha: 0.75)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;
  final m1 = Offset.lerp(hip, mid, 0.3)! + n * (front ? 6 : 9);
  final m2 = Offset.lerp(hip, mid, 0.95)! + n * (front ? 3 : 4);
  canvas.drawPath(
    Path()
      ..moveTo(m1.dx, m1.dy)
      ..quadraticBezierTo(
        (m1.dx + m2.dx) / 2 + n.dx * 4,
        (m1.dy + m2.dy) / 2 + n.dy * 4,
        m2.dx,
        m2.dy,
      ),
    line,
  );
  final t1 = Offset.lerp(mid, pawTop, 0.25)! - n * 3;
  final t2 = Offset.lerp(mid, pawTop, 0.8)! - n * 2.5;
  canvas.drawLine(t1, t2, line);
  _paw(canvas, paw, color, clawsOut: clawsOut);
}

// Profile cơ chân sư tử (t, nửa rộng phía trước/mặt, nửa rộng phía sau).
const _foreUpper = <MuscleStop>[
  (0.0, 17.0, 17.0),
  (0.3, 15.0, 18.5), // khối cơ tam đầu sau vai
  (0.75, 12.0, 12.5),
  (1.0, 11.0, 12.0), // khuỷu
];
const _foreLower = <MuscleStop>[
  (0.0, 11.0, 12.0),
  (0.25, 12.5, 10.0), // cẳng chân trước phồng
  (0.8, 9.0, 9.0),
  (1.0, 10.0, 10.0), // cổ chân
];
const _hindUpper = <MuscleStop>[
  (0.0, 21.0, 21.0),
  (0.3, 21.5, 22.5), // đùi + cơ đùi sau
  (0.65, 14.0, 14.5),
  (1.0, 8.5, 9.5), // cổ chân sau (hock)
];
const _hindLower = <MuscleStop>[
  (0.0, 8.5, 10.0),
  (0.4, 8.0, 8.0),
  (1.0, 8.5, 8.5),
];

void _paw(Canvas canvas, Offset paw, Color color, {required bool clawsOut}) {
  // Bàn chân vẽ thẳng (không cắt vùng) cho nhẹ: viền, nền, mảng bóng dưới.
  final r = Rect.fromCenter(
    center: paw + const Offset(-4, -5),
    width: 26,
    height: 12,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(r.inflate(2), const Radius.circular(8)),
    _fill(LionColors.outline),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(r, const Radius.circular(6)),
    _fill(shadeOf(color)),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTRB(r.left, r.top, r.right - 2, r.bottom - 3),
      const Radius.circular(5),
    ),
    _fill(color),
  );
  // Ngón chân.
  final toe = Paint()
    ..color = LionColors.outline
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;
  for (final dx in [-12.0, -6.0, 0.0]) {
    canvas.drawLine(paw + Offset(dx, -7), paw + Offset(dx, -2), toe);
  }
  // Móng: thò dài và cong khi vồ, chỉ nhú ra khi đứng.
  final claw = _fill(LionColors.fang);
  final clawLine = Paint()
    ..color = LionColors.outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;
  final reach = clawsOut ? 8.0 : 3.0;
  for (final dx in [-15.0, -9.0, -3.0]) {
    final base = paw + Offset(dx, -2);
    final path = Path()
      ..moveTo(base.dx, base.dy - 2)
      ..quadraticBezierTo(
        base.dx - reach * 0.7,
        base.dy - 1,
        base.dx - reach,
        base.dy + reach * 0.5,
      )
      ..quadraticBezierTo(base.dx - reach * 0.3, base.dy, base.dx + 2, base.dy)
      ..close();
    canvas.drawPath(path, claw);
    canvas.drawPath(path, clawLine);
  }
}

/// Ba vệt cào sáng theo sau móng vuốt.
void _clawTrails(Canvas canvas, Offset paw, double swipe) {
  final a = ((swipe - 0.25) / 0.75).clamp(0.0, 1.0);
  for (var i = 0; i < 3; i++) {
    final o = Offset(-6.0 * i, 6.0 * i);
    final trail = Path()
      ..moveTo(paw.dx + 40 + o.dx, paw.dy - 30 + o.dy)
      ..quadraticBezierTo(
        paw.dx - 6 + o.dx,
        paw.dy - 20 + o.dy,
        paw.dx - 26 + o.dx,
        paw.dy + 24 + o.dy,
      );
    canvas.drawPath(
      trail,
      Paint()
        ..color = Color.fromRGBO(255, 120, 60, 0.35 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      trail,
      Paint()
        ..color = Color.fromRGBO(255, 244, 214, 0.9 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }
}

void _tail(
  Canvas canvas,
  double time,
  double fall,
  double drop,
  double strike,
) {
  final sway = math.sin(time * 1.6) * 10 * (1 - fall);
  // Đuôi quất mạnh khi vồ.
  final lash = strike * 18;
  final base = Offset(94, -92 + drop);
  final ctrl = Offset(132 + lash * 0.5, -70 + drop + 20 * fall);
  final tip = Offset(122 + sway * 0.4 + lash, -132 + sway - lash + 70 * fall);
  final path = Path()
    ..moveTo(base.dx, base.dy)
    ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy);
  canvas.drawPath(
    path,
    Paint()
      ..color = LionColors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawPath(
    path,
    Paint()
      ..color = LionColors.body
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round,
  );
  // Chùm lông cuối đuôi: ngọn lửa đen đỏ.
  final tuft = Path();
  for (var i = 0; i < 5; i++) {
    final a = -math.pi / 2 + (i - 2) * 0.45 + sway * 0.02;
    _addTuft(tuft, tip, a, 3, 13, 5, const Offset(1, 0));
  }
  _shaded(canvas, tuft, LionColors.mane, shadow: 2);
}

/// Một chùm lông hình ngọn lửa mọc từ tâm [c] theo hướng [angle].
void _addTuft(
  Path path,
  Offset c,
  double angle,
  double r0,
  double len,
  double width,
  Offset sweep,
) {
  final dir = Offset(math.cos(angle), math.sin(angle));
  final n = Offset(-dir.dy, dir.dx);
  final base = c + dir * r0;
  final tip = base + dir * len + sweep * (len * 0.35);
  final mid = Offset.lerp(base, tip, 0.5)! + sweep * (len * 0.12);
  path
    ..moveTo(base.dx + n.dx * width, base.dy + n.dy * width)
    ..quadraticBezierTo(
      mid.dx + n.dx * width * 0.7,
      mid.dy + n.dy * width * 0.7,
      tip.dx,
      tip.dy,
    )
    ..quadraticBezierTo(
      mid.dx - n.dx * width * 0.5,
      mid.dy - n.dy * width * 0.5,
      base.dx - n.dx * width,
      base.dy - n.dy * width,
    )
    ..close();
}

/// Bờm ba lớp như ngọn lửa, dài xuống ngực; ngọn sẫm, gốc cam.
/// Bờm ba lớp như ngọn lửa, dài xuống ngực; ngọn sẫm, gốc cam. Hình bờm
/// nặng (nhiều chùm, cắt vùng đổ bóng) nên vẽ sẵn một lần thành Picture;
/// mỗi khung chỉ xoay và phồng nhẹ cho bờm rung.
void _mane(Canvas canvas, Offset head, double t, double fall) {
  final c = head + const Offset(14, 4);
  final live = 1 - fall;
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(math.sin(t * 2.6) * 0.035 * live);
  final puff = 1 + math.sin(t * 2.2) * 0.02 * live;
  canvas.scale(puff, puff);
  canvas.drawPicture(_manePicture);
  canvas.restore();
}

final Picture _manePicture = () {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  const sweep = Offset(1.3, 0.45);
  for (final (r0, len, width, color, count, spread) in [
    (26.0, 28.0, 13.0, LionColors.mane, 14, 0.0),
    (22.0, 21.0, 11.0, LionColors.maneMid, 12, 0.2),
    (18.0, 14.0, 8.0, LionColors.maneLight, 10, 0.4),
  ]) {
    final path = Path();
    for (var i = 0; i < count; i++) {
      // Từ trên trán vòng qua sau gáy xuống ngực (chừa phía mõm).
      final a = -2.35 + (4.5 * i / (count - 1)) + spread;
      // Chùm dài ngắn so le cho tự nhiên; phần ngực dài hơn (bờm rủ).
      final jitter = (i * 7 % 5 - 2) * 1.2;
      final chest = a > 0.8 ? 1.35 : 1.0;
      _addTuft(path, Offset.zero, a, r0, (len + jitter) * chest, width, sweep);
    }
    _shaded(canvas, path, color, shadow: 3, width: 1.8);
    // Sợi lông chạy dọc mỗi chùm (chất liệu, không tô phẳng).
    furStrokes(
      canvas,
      path,
      darken(color, 0.35),
      dir: const Offset(1, 0.3),
      count: 70,
      length: 10,
      width: 0.9,
      seed: count,
    );
  }
  return recorder.endRecording();
}();

void _head(
  Canvas canvas,
  Offset c,
  LionState s,
  double roar,
  double fall,
  double t,
) {
  canvas.save();
  canvas.translate(c.dx, c.dy);

  // Tai nhỏ, tròn, cụp ra sau khi gầm.
  canvas.save();
  canvas.translate(10, -22);
  canvas.rotate(0.5 * roar);
  _shaded(
    canvas,
    Path()
      ..addOval(Rect.fromCenter(center: Offset.zero, width: 14, height: 12)),
    LionColors.body,
    shadow: 2,
  );
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(-1, 1), width: 7, height: 6),
    _fill(LionColors.nose),
  );
  canvas.restore();

  // Hàm dưới xoay mở quanh khớp má.
  const pivot = Offset(-10, 12);
  final open = 0.55 * roar;
  // Lòng miệng (vẽ trước hàm để hàm che mép dưới).
  if (open > 0.03) {
    final mouth = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..lineTo(-40, 12)
      ..lineTo(
        pivot.dx + math.cos(math.pi + open) * 30,
        pivot.dy - math.sin(math.pi + open) * 30,
      )
      ..close();
    canvas.drawPath(mouth, _fill(LionColors.mouth));
    canvas.drawOval(
      Rect.fromCenter(
        center: pivot + Offset(-20, 8 * open / 0.55),
        width: 18,
        height: 6,
      ),
      _fill(LionColors.tongue),
    );
    // Hàng răng cửa nhỏ giữa hai nanh.
    for (var i = 0; i < 4; i++) {
      final x = -33.0 + i * 3;
      canvas.drawPath(
        Path()
          ..moveTo(x, 12.5)
          ..lineTo(x + 2.4, 12.5)
          ..lineTo(x + 1.2, 15.5)
          ..close(),
        _fill(LionColors.fang),
      );
    }
  }
  canvas.save();
  canvas.translate(pivot.dx, pivot.dy);
  canvas.rotate(-open);
  final jaw = Path()
    ..moveTo(2, -2)
    ..cubicTo(-6, 10, -22, 12, -30, 6)
    ..lineTo(-28, 0)
    ..close();
  // Nanh dưới.
  for (final x in [-25.0, -15.0]) {
    canvas.drawPath(
      Path()
        ..moveTo(x, 1)
        ..lineTo(x + 3.5, 1)
        ..lineTo(x + 1.5, -6 - 2 * roar)
        ..close(),
      _fill(LionColors.fang),
    );
  }
  _shaded(canvas, jaw, LionColors.belly, shadow: 2);
  // Chùm râu cằm sẫm.
  canvas.drawPath(
    Path()
      ..moveTo(-8, 8)
      ..quadraticBezierTo(-12, 18, -18, 14)
      ..quadraticBezierTo(-16, 10, -20, 8)
      ..close(),
    _fill(LionColors.maneMid),
  );
  canvas.restore();

  // Hộp sọ: trán gồ, sống mũi dài, má bạnh.
  final skull = Path()
    ..moveTo(12, -20)
    ..cubicTo(-2, -28, -20, -24, -28, -14)
    ..cubicTo(-34, -11, -44, -9, -47, -1)
    ..cubicTo(-48, 6, -45, 12, -38, 13)
    ..lineTo(-12, 15)
    ..cubicTo(2, 22, 14, 18, 18, 6)
    ..cubicTo(22, -4, 20, -14, 12, -20)
    ..close();
  _shaded(canvas, skull, LionColors.body, shadow: 4);
  canvas.save();
  canvas.clipPath(skull);
  // Mõm sáng màu.
  canvas.drawOval(const Rect.fromLTWH(-48, 0, 30, 16), _fill(LionColors.belly));
  // Mặt phẳng (Loomis): sống mũi đón nắng sáng, má dưới mắt khuất tối.
  canvas.drawPath(
    Path()
      ..moveTo(-26, -15)
      ..quadraticBezierTo(-38, -10, -46, -4)
      ..lineTo(-42, -1)
      ..quadraticBezierTo(-34, -7, -22, -11)
      ..close(),
    _fill(lighten(LionColors.body, 0.22)),
  );
  canvas.drawPath(
    Path()
      ..moveTo(-12, -2)
      ..quadraticBezierTo(-6, 6, -10, 14)
      ..lineTo(4, 14)
      ..quadraticBezierTo(8, 2, 2, -6)
      ..close(),
    _fill(coreShadeOf(LionColors.body).withValues(alpha: 0.35)),
  );
  // Hai đệm râu phồng, chấm chân râu.
  for (final (cx, cy) in [(-37.0, 6.0), (-28.0, 8.0)]) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 13, height: 9),
      _fill(lighten(LionColors.belly, 0.12)),
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: 13, height: 9),
      0.3,
      2.4,
      false,
      Paint()
        ..color = darken(LionColors.belly, 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }
  // Lông má lởm chởm ở mép sau mặt, nối vào bờm.
  final cheekFur = Path()..moveTo(8, -18);
  for (var i = 0; i < 6; i++) {
    final y = -14.0 + i * 6;
    cheekFur
      ..lineTo(14 - (i.isEven ? 0 : 3), y - 2)
      ..lineTo(8 - (i.isEven ? 4 : 1), y + 1);
  }
  cheekFur
    ..lineTo(22, 20)
    ..lineTo(24, -20)
    ..close();
  canvas.drawPath(cheekFur, _fill(LionColors.bodyShade));
  // Nếp nhăn sống mũi khi gầm (mặt dữ).
  final wrinkle = Paint()
    ..color = LionColors.bodyShade
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.3
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 2 + (roar > 0.3 ? 2 : 0); i++) {
    canvas.drawArc(
      Rect.fromCenter(center: Offset(-34 + i * 4.0, -8), width: 6, height: 5),
      math.pi * 1.1,
      math.pi * 0.8,
      false,
      wrinkle,
    );
  }
  // Ba vết sẹo vuốt chéo qua mắt.
  final scar = Paint()
    ..color = LionColors.scar
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 3; i++) {
    canvas.drawLine(Offset(-14 + i * 4.0, -22), Offset(-24 + i * 4.0, 0), scar);
  }
  canvas.restore();

  // Mũi da sẫm có chấm bóng.
  final nose = Path()
    ..moveTo(-49, -4)
    ..quadraticBezierTo(-44, -8, -38, -5)
    ..quadraticBezierTo(-40, 1, -45, 2)
    ..quadraticBezierTo(-50, 0, -49, -4)
    ..close();
  canvas.drawPath(nose, _fill(LionColors.nose));
  glint(canvas, const Offset(-44, -5), 1.6, alpha: 0.6);
  // Chấm râu.
  for (final (x, y) in [(-38.0, 5.0), (-33.0, 7.0), (-36.0, 9.0)]) {
    canvas.drawCircle(Offset(x, y), 0.8, _fill(LionColors.outline));
  }
  // Sợi râu trắng mảnh, cong xuống.
  final whisker = Paint()
    ..color = const Color(0xCCFFF8EA)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.6
    ..strokeCap = StrokeCap.round;
  for (final (y, bend) in [(4.0, 2.0), (7.0, 5.0), (10.0, 8.0)]) {
    canvas.drawPath(
      Path()
        ..moveTo(-38, y)
        ..quadraticBezierTo(-50, y - 1 + bend * 0.3, -60, y + bend),
      whisker,
    );
  }
  // Nanh trên lòi ra ngoài cả khi ngậm miệng.
  for (final (x, len) in [(-36.0, 7.0), (-24.0, 9.0)]) {
    final fang = Path()
      ..moveTo(x, 12)
      ..lineTo(x + 4.5, 12)
      ..quadraticBezierTo(x + 3, 12 + len * 0.7, x + 1, 12 + len + 3 * roar)
      ..close();
    canvas.drawPath(fang, _fill(LionColors.fang));
    canvas.drawPath(
      fang,
      Paint()
        ..color = LionColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }
  // Nước dãi khi gầm.
  if (roar > 0.6 && fall == 0) {
    final drip = 4 + 6 * math.sin(t * 5).abs();
    canvas.drawLine(
      const Offset(-30, 14),
      Offset(-31, 14 + drip),
      Paint()
        ..color = const Color(0xAAE6F2FF)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  _eye(canvas, const Offset(-20, -9), s, roar, fall, t);
  canvas.restore();
}

void _eye(
  Canvas canvas,
  Offset eye,
  LionState s,
  double roar,
  double fall,
  double t,
) {
  final brow = Paint()
    ..color = LionColors.outline
    ..strokeCap = StrokeCap.round;
  if (fall > 0.5) {
    // Gục: mắt nhắm nghiền.
    canvas.drawArc(
      Rect.fromCenter(center: eye, width: 10, height: 6),
      0.2,
      math.pi - 0.4,
      false,
      brow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    return;
  }
  final blink = (t % 4.3) < 0.12;
  if (s.hurt > 0.3 || blink) {
    // Nhăn mặt vì đau / chớp mắt.
    canvas.drawLine(
      eye + const Offset(-5, 0),
      eye + const Offset(5, -1),
      brow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
  } else {
    // Quầng sáng: mắt rực khi gầm (quy ước boss: mắt phát sáng).
    canvas.drawCircle(
      eye,
      9 + 4 * roar,
      Paint()
        ..shader = Gradient.radial(eye, 9 + 4 * roar, [
          Color.fromRGBO(255, 170, 40, math.min(1, 0.35 + 0.6 * roar)),
          const Color(0x00FF8A00),
        ]),
    );
    // Mắt xếch hình hạnh nhân.
    final almond = Path()
      ..moveTo(eye.dx - 6, eye.dy + 1)
      ..quadraticBezierTo(eye.dx - 1, eye.dy - 5, eye.dx + 6, eye.dy - 2)
      ..quadraticBezierTo(eye.dx + 1, eye.dy + 4, eye.dx - 6, eye.dy + 1)
      ..close();
    canvas.drawPath(
      almond,
      Paint()
        ..shader = Gradient.radial(
          eye,
          6,
          const [Color(0xFFFFF3A0), Color(0xFFFFB020), Color(0xFFD45A10)],
          const [0, 0.5, 1],
        ),
    );
    // Con ngươi dọc, co lại khi gầm.
    canvas.drawOval(
      Rect.fromCenter(
        center: eye + const Offset(-1.2, -0.4),
        width: 2.4 - roar,
        height: 6,
      ),
      _fill(LionColors.outline),
    );
    canvas.drawCircle(
      eye + const Offset(-3, -1.5),
      0.9,
      _fill(const Color(0xFFFFFFFF)),
    );
    canvas.drawPath(
      almond,
      Paint()
        ..color = LionColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }
  // Gờ mày nặng, chau xuống phía mũi: lúc nào cũng hằm hằm.
  canvas.drawPath(
    Path()
      ..moveTo(eye.dx - 10, eye.dy + 1 - 2 * roar)
      ..quadraticBezierTo(eye.dx - 2, eye.dy - 9, eye.dx + 9, eye.dy - 6)
      ..lineTo(eye.dx + 9, eye.dy - 9)
      ..quadraticBezierTo(eye.dx - 2, eye.dy - 13, eye.dx - 11, eye.dy - 2)
      ..close(),
    _fill(LionColors.bodyShade),
  );
  canvas.drawLine(
    eye + Offset(-10, 1 - 2 * roar),
    eye + const Offset(8, -7),
    brow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6,
  );
}

/// Sóng gầm toả ra từ miệng.
void _roarWaves(Canvas canvas, Offset head, double roar, double t) {
  final mouth = head + const Offset(-46, 12);
  final a = (roar - 0.5) * 2;
  for (var i = 0; i < 3; i++) {
    final r = 12.0 + i * 12 + (t * 60) % 12;
    canvas.drawArc(
      Rect.fromCircle(center: mouth, radius: r),
      math.pi * 0.75,
      math.pi * 0.5,
      false,
      Paint()
        ..color = Color.fromRGBO(255, 236, 200, 0.55 * a * (1 - i / 3))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }
}

/// Đòn bị chặn: khiên lục giác vàng loé lên trên bộ da rồi tan.
void _shieldFlash(Canvas canvas, Offset at, double g) {
  final fade = 1 - g;
  final radius = 26 + 30 * _smooth(g);
  // Lưới lục giác.
  final hex = Paint()
    ..color = Color.fromRGBO(255, 226, 120, 0.85 * fade)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  canvas.save();
  canvas.clipPath(Path()..addOval(Rect.fromCircle(center: at, radius: radius)));
  const size = 8.0;
  final w = size * math.sqrt(3);
  for (var row = -5; row <= 5; row++) {
    for (var col = -5; col <= 5; col++) {
      final cx = at.dx + col * w + (row.isOdd ? w / 2 : 0);
      final cy = at.dy + row * size * 1.5;
      final path = Path();
      for (var k = 0; k < 6; k++) {
        final a = math.pi / 3 * k + math.pi / 6;
        final pt = Offset(cx + math.cos(a) * size, cy + math.sin(a) * size);
        k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(path, hex);
    }
  }
  canvas.restore();
  // Vòng sáng ngoài + lõi loé.
  canvas.drawCircle(
    at,
    radius,
    Paint()
      ..color = Color.fromRGBO(255, 240, 170, 0.9 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3,
  );
  canvas.drawCircle(
    at,
    radius * 0.5,
    Paint()
      ..shader = Gradient.radial(at, radius * 0.5, [
        Color.fromRGBO(255, 255, 230, 0.8 * fade),
        const Color(0x00FFF0B0),
      ]),
  );
}

/// Gục ngã: làn khói Trì Trệ tím xám bốc lên rời khỏi xác sư tử (sức mạnh
/// tà ác bị đánh bật), cuộn xoắn rồi tan.
void _stagnationLeaving(Canvas canvas, double t, double fall, double drop) {
  final a = ((fall - 0.3) / 0.7).clamp(0.0, 1.0);
  for (var i = 0; i < 6; i++) {
    final phase = (t * 0.35 + i / 6) % 1;
    final x = -40 + i * 22.0 + math.sin(t * 1.3 + i * 2) * 8 * phase;
    final y = -90 + drop - phase * 90;
    final r = 6 + phase * 12;
    canvas.drawCircle(
      Offset(x, y),
      r,
      Paint()
        ..color = Color.fromRGBO(120, 100, 150, 0.5 * a * (1 - phase))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Lõi xoắn tối hơn.
    canvas.drawArc(
      Rect.fromCircle(center: Offset(x, y), radius: r * 0.55),
      t * 2 + i,
      3.2,
      false,
      Paint()
        ..color = Color.fromRGBO(70, 56, 92, 0.6 * a * (1 - phase))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }
}

/// Bụi đất tung lên sau chân sau khi sư tử cào đất lấy đà.
void _pawDust(Canvas canvas, double t, double windup) {
  for (var i = 0; i < 7; i++) {
    final phase = (t * 1.6 + i / 7) % 1;
    final x = 84 + i * 7.0 + phase * 50;
    final y = -2 - phase * 22 - (i % 3) * 3;
    canvas.drawCircle(
      Offset(x, y),
      4 + phase * 8,
      Paint()
        ..color = Color.fromRGBO(196, 160, 110, 0.75 * windup * (1 - phase)),
    );
  }
}
