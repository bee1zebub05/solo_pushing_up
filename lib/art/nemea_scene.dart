import 'dart:math' as math;
import 'dart:ui';

import 'vector_style.dart';

/// Kích thước sân khấu chiến đấu (đơn vị vẽ); widget co giãn theo màn hình.
const stageSize = Size(400, 260);
const stageGroundY = 220.0;

/// Phông nền Thung lũng Nemea: trời chiều, núi xa, đồi ô liu có đền đá
/// trắng, vách đá với hang sư tử, cây ô liu già phía trước, đất son có sỏi
/// và hoa anh túc. Ánh sáng từ trên bên trái như mọi nhân vật.
void paintNemeaScene(Canvas canvas, {double time = 0, double dust = 0}) {
  paintNemeaBackdrop(canvas);
  if (dust > 0) {
    canvas.saveLayer(
      Offset.zero & stageSize,
      Paint()..color = Color.fromRGBO(0, 0, 0, dust.clamp(0.0, 1.0)),
    );
    paintNemeaDusty(canvas);
    canvas.restore();
  }
  paintNemeaAmbient(canvas, time: time, dust: dust);
}

// Bảng màu chung của cảnh.
const _marble = Color(0xFFF3ECDC);
const _rock = Color(0xFFB59A72);
const _olive = Color(0xFF6E8A48);
const _oliveLit = Color(0xFFA6BD6A);
const _oliveDark = Color(0xFF3E5236);
const _bark = Color(0xFF6E5B4A);

/// Các lớp chiều sâu của phông nền (2,5D): lớp xa dịch nhiều hơn khi
/// camera trôi, lớp gần (nơi nhân vật đứng) đứng yên.
enum NemeaLayer {
  /// Trời, mặt trời.
  sky(0),

  /// Núi xa.
  far(0.7),

  /// Đồi ô liu, đền.
  mid(0.4),

  /// Vách hang, đồi gần, đất, cây ô liu, đá đổ.
  near(0);

  const NemeaLayer(this.parallax);

  /// Tỉ lệ dịch so với độ trôi camera.
  final double parallax;
}

/// Phần tĩnh của phông nền: vẽ một lần rồi giữ lại (Picture) để mỗi khung
/// không phải vẽ lại.
void paintNemeaBackdrop(Canvas canvas) {
  for (final layer in NemeaLayer.values) {
    paintNemeaLayer(canvas, layer);
  }
}

void paintNemeaLayer(Canvas canvas, NemeaLayer layer) {
  switch (layer) {
    case NemeaLayer.sky:
      _sky(canvas);
    case NemeaLayer.far:
      _farMountains(canvas);
    case NemeaLayer.mid:
      _midHills(canvas);
      _temple(canvas, const Offset(196, 147), 1);
    case NemeaLayer.near:
      _cliff(canvas);
      _nearHill(canvas);
      _ground(canvas);
      _bigOlive(canvas);
      _ruins(canvas);
  }
}

/// Cùng phông nền nhưng bị Trì Trệ phủ bụi: mất màu, xám tím, mạng nhện
/// trên đền. Vẽ chồng lên phông nền thật với độ đục = lượng bụi, nên khi
/// boss mất máu bụi tan dần và màu thật hiện ra.
void paintNemeaDusty(Canvas canvas) {
  for (final layer in NemeaLayer.values) {
    paintNemeaDustyLayer(canvas, layer);
  }
}

/// Một lớp phông nền phủ bụi (để chồng đúng lên lớp tương ứng khi parallax).
void paintNemeaDustyLayer(Canvas canvas, NemeaLayer layer) {
  const s = 0.18; // độ bão hoà còn lại
  const r = 0.2126 * (1 - s), g = 0.7152 * (1 - s), b = 0.0722 * (1 - s);
  canvas.saveLayer(
    const Rect.fromLTRB(-20, -20, 420, 280),
    Paint()
      ..colorFilter = const ColorFilter.matrix([
        r + s, g, b, 0, -8, //
        r, g + s, b, 0, -10,
        r, g, b + s, 0, -2,
        0, 0, 0, 1, 0,
      ]),
  );
  paintNemeaLayer(canvas, layer);
  canvas.restore();

  switch (layer) {
    case NemeaLayer.sky:
      break;
    case NemeaLayer.far:
      break;
    case NemeaLayer.mid:
      // Màn sương xám đặc dần về phía chân trời.
      canvas.drawRect(
        Offset.zero & stageSize,
        Paint()
          ..shader = Gradient.linear(
            const Offset(0, 40),
            Offset(0, stageGroundY),
            [const Color(0x405E5868), const Color(0x8C77707E)],
          ),
      );
      // Mạng nhện giăng trên đền.
      _cobweb(canvas, const Offset(166, 129), 14, math.pi * 0.05);
      _cobweb(canvas, const Offset(226, 129), 12, math.pi * 0.55);
    case NemeaLayer.near:
      _cobweb(canvas, const Offset(304, 152), 16, math.pi * 0.1);
      // Bụi đọng thành đống dưới chân cột.
      final heap = Paint()..color = const Color(0xFF8A8590);
      for (final (x, w) in [(30.0, 46.0), (150.0, 30.0), (238.0, 40.0)]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, stageGroundY + 1),
            width: w,
            height: 7,
          ),
          heap,
        );
      }
  }
}

void _cobweb(Canvas canvas, Offset corner, double size, double rot) {
  final p = Paint()
    ..color = const Color(0xAADCD8E2)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.6;
  canvas.save();
  canvas.translate(corner.dx, corner.dy);
  canvas.rotate(rot);
  const spokes = 5;
  for (var i = 0; i < spokes; i++) {
    final a = math.pi / 2 * i / (spokes - 1);
    canvas.drawLine(Offset.zero, Offset(math.cos(a), math.sin(a)) * size, p);
  }
  for (var ring = 1; ring <= 3; ring++) {
    final rr = size * ring / 3.4;
    final path = Path()..moveTo(rr, 0);
    for (var i = 1; i < spokes; i++) {
      final a = math.pi / 2 * i / (spokes - 1);
      final mid = math.pi / 2 * (i - 0.5) / (spokes - 1);
      path.quadraticBezierTo(
        math.cos(mid) * rr * 0.82,
        math.sin(mid) * rr * 0.82,
        math.cos(a) * rr,
        math.sin(a) * rr,
      );
    }
    canvas.drawPath(path, p);
  }
  canvas.restore();
}

Path _poly(List<Offset> pts) => Path()..addPolygon(pts, true);

void _sky(Canvas canvas) {
  canvas.drawRect(
    Offset.zero & stageSize,
    Paint()
      ..shader = Gradient.linear(
        Offset.zero,
        const Offset(0, stageGroundY),
        const [
          Color(0xFF2E6FC4),
          Color(0xFF6FB0E6),
          Color(0xFFFBD99A),
          Color(0xFFF9B26B),
        ],
        const [0, 0.38, 0.72, 1],
      ),
  );
  // Mặt trời phía trên bên trái (cùng hướng nguồn sáng của nhân vật).
  const sun = Offset(172, 34);
  canvas.drawCircle(
    sun,
    90,
    Paint()
      ..shader = Gradient.radial(sun, 90, const [
        Color(0x66FFF4D0),
        Color(0x00FFF4D0),
      ]),
  );
  // Tia nắng chéo xuống phải.
  final ray = Paint()..color = const Color(0x16FFF8E1);
  for (final (a, w) in [(0.35, 0.07), (0.62, 0.05), (0.9, 0.09), (1.2, 0.05)]) {
    canvas.drawPath(
      _poly([
        sun,
        sun + Offset(math.cos(a - w), math.sin(a - w)) * 320,
        sun + Offset(math.cos(a + w), math.sin(a + w)) * 320,
      ]),
      ray,
    );
  }
  canvas.drawCircle(sun, 19, Paint()..color = const Color(0xFFFFF3C9));
  canvas.drawCircle(sun, 14, Paint()..color = const Color(0xFFFFFBEA));
}

void _farMountains(Canvas canvas) {
  // Lớp xa nhất: xanh tím nhạt (phối cảnh không khí).
  _ridge(
    canvas,
    const [
      Offset(-10, 150),
      Offset(30, 118),
      Offset(62, 128),
      Offset(104, 96),
      Offset(140, 120),
      Offset(170, 112),
      Offset(214, 132),
      Offset(260, 104),
      Offset(300, 116),
      Offset(410, 98),
    ],
    const Color(0xFF9AA9D6),
    const Color(0xFF7D86BE),
    floor: 175,
  );
  _ridge(
    canvas,
    const [
      Offset(-10, 160),
      Offset(40, 140),
      Offset(88, 150),
      Offset(120, 134),
      Offset(160, 152),
      Offset(230, 146),
      Offset(270, 132),
      Offset(410, 150),
    ],
    const Color(0xFF86A79A),
    const Color(0xFF6A8784),
    floor: 185,
  );
}

/// Dãy núi cel-shading: sườn đón nắng (trái) sáng, sườn khuất (phải) tối.
void _ridge(
  Canvas canvas,
  List<Offset> peaks,
  Color lit,
  Color shade, {
  required double floor,
}) {
  final body = Path()..moveTo(peaks.first.dx, floor);
  for (final p in peaks) {
    body.lineTo(p.dx, p.dy);
  }
  body
    ..lineTo(peaks.last.dx, floor)
    ..close();
  canvas.drawPath(body, Paint()..color = lit);
  // Mảng bóng: từ mỗi đỉnh đổ xuống sườn phải.
  final dark = Paint()..color = shade;
  for (var i = 1; i < peaks.length - 1; i++) {
    final p = peaks[i];
    final next = peaks[i + 1];
    if (next.dy <= p.dy) continue;
    canvas.drawPath(
      _poly([
        p,
        next,
        Offset(next.dx, floor),
        Offset(p.dx + (next.dx - p.dx) * 0.25, floor),
      ]),
      dark,
    );
  }
}

void _midHills(Canvas canvas) {
  // Đồi giữa nhô lên ở chỗ đền.
  final hill = Path()
    ..moveTo(-10, 182)
    ..cubicTo(60, 170, 120, 150, 196, 150)
    ..cubicTo(250, 150, 280, 170, 330, 176)
    ..lineTo(330, stageGroundY)
    ..lineTo(-10, stageGroundY)
    ..close();
  canvas.drawPath(
    hill,
    Paint()
      ..shader = Gradient.linear(const Offset(0, 150), const Offset(0, 210), [
        const Color(0xFFB9C46E),
        const Color(0xFF7F9A4C),
      ]),
  );
  // Sườn khuất bên phải đồi.
  canvas.drawPath(
    Path()
      ..moveTo(212, 151)
      ..cubicTo(250, 152, 280, 170, 330, 176)
      ..lineTo(330, 200)
      ..cubicTo(280, 190, 240, 170, 212, 151)
      ..close(),
    Paint()..color = const Color(0x22301E40),
  );
  // Ruộng bậc thang ô liu: hàng cây nhỏ theo đường đồng mức.
  final rnd = math.Random(11);
  for (final (y0, from, to, step) in [
    (172.0, 0.0, 140.0, 11.0),
    (164.0, 70.0, 160.0, 10.0),
    (180.0, 10.0, 200.0, 12.0),
    (170.0, 236.0, 300.0, 10.0),
    (190.0, 0.0, 260.0, 13.0),
  ]) {
    // Đường bờ ruộng.
    canvas.drawLine(
      Offset(from - 4, y0 + 4),
      Offset(to + 4, y0 + 4 + (to - from) * 0.01),
      Paint()
        ..color = const Color(0x33503A20)
        ..strokeWidth = 1,
    );
    for (var x = from; x <= to; x += step) {
      final s = 0.8 + rnd.nextDouble() * 0.4;
      _tinyOlive(canvas, Offset(x + rnd.nextDouble() * 3, y0), s);
    }
  }
  // Cây bách (cypress) dựng thẳng, đặc trưng Địa Trung Hải.
  for (final (x, y, h) in [
    (132.0, 162.0, 26.0),
    (140.0, 164.0, 20.0),
    (252.0, 162.0, 24.0),
    (60.0, 176.0, 22.0),
  ]) {
    _cypress(canvas, Offset(x, y), h);
  }
}

void _tinyOlive(Canvas canvas, Offset base, double s) {
  // Cây ô liu xa: thân xoắn ngắn, tán xoè thấp lệch (không phải kẹo mút).
  canvas.drawLine(
    base,
    base + Offset(0.8 * s, -3 * s),
    Paint()
      ..color = const Color(0xFF5E4C3C)
      ..strokeWidth = 1.1,
  );
  final dark = Paint()..color = const Color(0xFF66744A);
  final lit = Paint()..color = const Color(0xFF96A374);
  for (final (dx, dy, w, h) in [
    (-2.2, -4.2, 5.6, 3.6),
    (1.8, -5.0, 6.0, 4.2),
    (0.2, -6.4, 4.4, 3.0),
  ]) {
    canvas.drawOval(
      Rect.fromCenter(
        center: base + Offset(dx * s, dy * s),
        width: w * s,
        height: h * s,
      ),
      dark,
    );
  }
  canvas.drawOval(
    Rect.fromCenter(
      center: base + Offset(-1.2 * s, -6 * s),
      width: 4.2 * s,
      height: 2.2 * s,
    ),
    lit,
  );
}

void _cypress(Canvas canvas, Offset base, double h) {
  final w = h * 0.22;
  final shape = Path()
    ..moveTo(base.dx, base.dy - h)
    ..quadraticBezierTo(
      base.dx + w,
      base.dy - h * 0.55,
      base.dx + w * 0.6,
      base.dy,
    )
    ..lineTo(base.dx - w * 0.6, base.dy)
    ..quadraticBezierTo(base.dx - w, base.dy - h * 0.55, base.dx, base.dy - h)
    ..close();
  canvas.drawPath(shape, Paint()..color = const Color(0xFF3F5A3C));
  canvas.save();
  canvas.clipPath(shape);
  canvas.drawRect(
    Rect.fromLTRB(base.dx - w, base.dy - h, base.dx - w * 0.1, base.dy),
    Paint()..color = const Color(0xFF5D7A4E),
  );
  canvas.restore();
}

/// Đền đá trắng kiểu Doric trên đỉnh đồi; một cột gãy, mái tam giác sứt.
void _temple(Canvas canvas, Offset base, double s) {
  canvas.save();
  canvas.translate(base.dx, base.dy);
  canvas.scale(s);
  const shadeC = Color(0xFFC9BCA8);
  const line = Color(0xFF8E8070);
  final outline = Paint()
    ..color = line
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8
    ..strokeJoin = StrokeJoin.round;

  // Bậc nền ba tầng.
  for (var i = 0; i < 3; i++) {
    final top = -8.0 + i * 2.7;
    final r = Rect.fromLTRB(-36.0 - i * 3, top, 36.0 + i * 3, top + 2.7);
    canvas.drawRect(r, Paint()..color = _marble);
    canvas.drawRect(
      Rect.fromLTRB(r.left, r.bottom - 0.9, r.right, r.bottom),
      Paint()..color = shadeC,
    );
    canvas.drawRect(r, outline);
  }

  // Bóng tối trong lòng đền (sau hàng cột).
  canvas.drawRect(
    const Rect.fromLTRB(-30, -40, 30, -8),
    Paint()..color = const Color(0xFF7D6F66),
  );
  canvas.drawRect(
    const Rect.fromLTRB(-30, -40, 30, -34),
    Paint()..color = const Color(0xFF5E524C),
  );

  // Hàng cột có rãnh, bóng phía phải mỗi cột.
  const cols = 7;
  for (var i = 0; i < cols; i++) {
    final x = -30 + i * 10.0;
    final broken = i == cols - 2;
    final top = broken ? -22.0 : -40.0;
    final col = Rect.fromLTRB(x - 2.6, top, x + 2.6, -8);
    canvas.drawRect(col, Paint()..color = _marble);
    canvas.drawRect(
      Rect.fromLTRB(x + 0.9, top, x + 2.6, -8),
      Paint()..color = shadeC,
    );
    canvas.drawLine(
      Offset(x - 0.8, top + 1),
      Offset(x - 0.8, -9),
      Paint()
        ..color = const Color(0x55A89A88)
        ..strokeWidth = 0.4,
    );
    if (broken) {
      // Mặt gãy lởm chởm và khúc cột đổ dưới chân.
      canvas.drawPath(
        _poly([
          Offset(x - 2.6, top),
          Offset(x - 1, top - 3),
          Offset(x + 0.4, top - 1),
          Offset(x + 1.6, top - 4),
          Offset(x + 2.6, top),
        ]),
        Paint()..color = _marble,
      );
      canvas.drawRect(Rect.fromLTRB(x - 2.6, top - 4, x + 2.6, -8), outline);
    } else {
      canvas.drawRect(col, outline);
      // Đầu cột (capital).
      canvas.drawRect(
        Rect.fromLTRB(x - 3.6, top - 2, x + 3.6, top),
        Paint()..color = _marble,
      );
      canvas.drawRect(Rect.fromLTRB(x - 3.6, top - 2, x + 3.6, top), outline);
    }
  }

  // Dầm ngang (entablature) có hoa văn triglyph.
  final beam = const Rect.fromLTRB(-35, -48, 30, -42);
  canvas.drawRect(beam, Paint()..color = _marble);
  canvas.drawRect(
    const Rect.fromLTRB(-35, -43.5, 30, -42),
    Paint()..color = shadeC,
  );
  for (var x = -32.0; x < 28; x += 5) {
    canvas.drawRect(
      Rect.fromLTWH(x, -47, 1.6, 3),
      Paint()..color = const Color(0xFFB9AC98),
    );
  }
  canvas.drawRect(beam, outline);

  // Mái tam giác, sứt góc phải (để lộ trời).
  final pediment = _poly(const [
    Offset(-37, -48),
    Offset(-3, -62),
    Offset(16, -55),
    Offset(19, -51),
    Offset(24, -52),
    Offset(26, -48),
  ]);
  canvas.drawPath(pediment, Paint()..color = _marble);
  canvas.drawPath(
    _poly(const [
      Offset(-29, -49.5),
      Offset(-3, -59.5),
      Offset(14, -53),
      Offset(14, -49.5),
    ]),
    Paint()..color = const Color(0xFFE2D7C2),
  );
  canvas.drawPath(pediment, outline);
  // Viên đá rơi dưới chân đền.
  canvas.drawRect(const Rect.fromLTWH(38, -4, 7, 4), Paint()..color = _marble);
  canvas.drawRect(const Rect.fromLTWH(38, -4, 7, 4), outline);
  canvas.restore();
}

/// Chất liệu vách đá (nằm trong lớp chụp sẵn nên chi tiết không tốn mỗi
/// khung): vân trầm tích nghiêng có mép sáng, vệt nước mưa chảy dọc, địa
/// y, lấm tấm sỏi, bóng tối sát chân vách, búi cỏ trên gờ.
void _rockTexture(Canvas canvas, Path body) {
  final rnd = math.Random(21);
  canvas.save();
  canvas.clipPath(body);
  // Vân trầm tích: dải gợn nghiêng nhẹ, mép dưới tối, mép trên sáng.
  final seam = Paint()..color = darken(_rock, 0.35).withValues(alpha: 0.55);
  final ledge = Paint()..color = lighten(_rock, 0.35).withValues(alpha: 0.5);
  for (var i = 0; i < 26; i++) {
    final y = 80.0 + (i % 9) * 15 + rnd.nextDouble() * 6;
    final x0 = 252 + rnd.nextDouble() * 140;
    final len = 16 + rnd.nextDouble() * 32;
    final pts = [
      for (var k = 0; k <= 3; k++)
        () {
          final x = x0 + len * k / 3;
          return Offset(x, y - (x - 250) * 0.09 + math.sin(x * 0.11 + i) * 1.6);
        }(),
    ];
    final w = 1.0 + rnd.nextDouble() * 1.1;
    canvas.drawPath(taperedStroke(pts, w, peak: 0.5), seam);
    canvas.drawPath(
      taperedStroke(
        [for (final p in pts) p - const Offset(0, 1.5)],
        w * 0.6,
        peak: 0.5,
      ),
      ledge,
    );
  }
  // Vệt nước mưa tối chảy dọc từ các gờ trên xuống.
  final streak = Paint()..color = darken(_rock, 0.3).withValues(alpha: 0.28);
  for (var i = 0; i < 22; i++) {
    final x = 258 + rnd.nextDouble() * 150;
    final top = 70 + rnd.nextDouble() * 80;
    final len = 14 + rnd.nextDouble() * 36;
    canvas.drawPath(
      taperedStroke(
        [
          Offset(x, top),
          Offset(x + 0.8, top + len * 0.5),
          Offset(x, top + len),
        ],
        1.4 + rnd.nextDouble() * 1.8,
        peak: 0.2,
        startWidth: 0.6,
      ),
      streak,
    );
  }
  // Địa y: cụm chấm vàng – xanh xám.
  for (var i = 0; i < 9; i++) {
    final c = Offset(262 + rnd.nextDouble() * 145, 80 + rnd.nextDouble() * 110);
    final color = i.isEven ? const Color(0x99C9B25A) : const Color(0x8890A070);
    for (var j = 0; j < 7; j++) {
      canvas.drawCircle(
        c + Offset(rnd.nextDouble() * 8 - 4, rnd.nextDouble() * 5 - 2.5),
        0.6 + rnd.nextDouble() * 1.3,
        Paint()..color = color,
      );
    }
  }
  // Lấm tấm sỏi sáng / tối.
  for (var i = 0; i < 90; i++) {
    final p = Offset(250 + rnd.nextDouble() * 162, 66 + rnd.nextDouble() * 160);
    canvas.drawCircle(
      p,
      0.35 + rnd.nextDouble() * 0.5,
      Paint()
        ..color = (i.isEven ? lighten(_rock, 0.4) : darken(_rock, 0.4))
            .withValues(alpha: 0.6),
    );
  }
  // Bóng tối tụ sát chân vách (ambient occlusion).
  canvas.drawRect(
    const Rect.fromLTRB(240, stageGroundY - 34, 420, stageGroundY + 2),
    Paint()
      ..shader = Gradient.linear(
        const Offset(0, stageGroundY - 34),
        const Offset(0, stageGroundY),
        [const Color(0x00281A10), const Color(0x66281A10)],
      ),
  );
  canvas.restore();
  // Búi cỏ khô mọc trên các gờ đá.
  final grass = Paint()..color = const Color(0xFF8A8A3A);
  final grassLit = Paint()..color = const Color(0xFFC2B65A);
  for (final base in const [
    Offset(276, 151),
    Offset(306, 97),
    Offset(353, 71),
    Offset(285, 120),
  ]) {
    for (var j = 0; j < 5; j++) {
      final a = -math.pi / 2 + (j - 2) * 0.32;
      final len = 5 + (j * 37 % 5).toDouble();
      final tip = base + Offset(math.cos(a), math.sin(a)) * len;
      canvas.drawPath(
        taperedStroke(
          [base, Offset.lerp(base, tip, 0.5)! + const Offset(0.8, 0), tip],
          1.3,
          peak: 0.1,
          startWidth: 1,
        ),
        j.isEven ? grass : grassLit,
      );
    }
  }
}

/// Vách đá hang sư tử bên phải, các mặt đá xếp cạnh (cel-shading theo mặt).
void _cliff(Canvas canvas) {
  const outlineC = VectorStyle.outline;
  final body = _poly(const [
    Offset(246, stageGroundY),
    Offset(262, 168),
    Offset(276, 150),
    Offset(284, 118),
    Offset(306, 96),
    Offset(332, 88),
    Offset(352, 70),
    Offset(380, 66),
    Offset(410, 74),
    Offset(410, stageGroundY),
  ]);
  canvas.drawPath(
    body.shift(const Offset(1.4, 1.4)),
    Paint()..color = outlineC,
  );
  canvas.drawPath(
    body,
    Paint()
      ..color = outlineC
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.drawPath(body, Paint()..color = _rock);

  // Mặt đá: sáng (hướng trái/trên) và tối (hướng phải/dưới).
  final lit = Paint()..color = lighten(_rock, 0.28);
  final dark = Paint()..color = shadeOf(_rock);
  final crack = Paint()
    ..color = const Color(0xFF6E5638)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..strokeJoin = StrokeJoin.round;
  for (final facet in [
    [const Offset(262, 168), const Offset(276, 150), const Offset(282, 176)],
    [const Offset(284, 118), const Offset(306, 96), const Offset(300, 126)],
    [const Offset(332, 88), const Offset(352, 70), const Offset(350, 98)],
    [const Offset(380, 66), const Offset(400, 72), const Offset(388, 90)],
  ]) {
    canvas.drawPath(_poly(facet), lit);
  }
  for (final facet in [
    [const Offset(282, 176), const Offset(300, 126), const Offset(296, 186)],
    [const Offset(300, 126), const Offset(332, 88), const Offset(326, 118)],
    [const Offset(350, 98), const Offset(388, 90), const Offset(374, 122)],
    [const Offset(388, 90), const Offset(410, 82), const Offset(410, 130)],
  ]) {
    canvas.drawPath(_poly(facet), dark);
  }
  for (final c in [
    [const Offset(282, 176), const Offset(300, 126), const Offset(326, 118)],
    [const Offset(350, 98), const Offset(374, 122), const Offset(410, 130)],
    [const Offset(270, 196), const Offset(282, 176)],
  ]) {
    canvas.drawPath(Path()..addPolygon(c, false), crack);
  }

  _rockTexture(canvas, body);

  // Cửa hang: vòm tối sâu dần, mép đá dày.
  final mouth = Path()
    ..moveTo(292, stageGroundY)
    ..cubicTo(292, 160, 312, 138, 342, 138)
    ..cubicTo(374, 138, 396, 160, 398, stageGroundY)
    ..close();
  canvas.drawPath(
    mouth,
    Paint()
      ..color = outlineC
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5,
  );
  canvas.drawPath(
    mouth,
    Paint()
      ..shader = Gradient.radial(const Offset(345, 200), 70, const [
        Color(0xFF120C08),
        Color(0xFF3A2A1A),
      ]),
  );
  // Đá vòm xếp quanh miệng hang: mặt trái/trên đón nắng.
  const arch = Offset(345, 182);
  for (var i = 0; i < 7; i++) {
    final a = -math.pi + 0.28 + i * (math.pi - 0.56) / 6;
    Offset at(double ang, double rx, double ry) =>
        arch + Offset(math.cos(ang) * rx, math.sin(ang) * ry);
    final block = _poly([
      at(a - 0.2, 50, 42),
      at(a - 0.2, 60, 52),
      at(a + 0.2, 60, 52),
      at(a + 0.2, 50, 42),
    ]);
    canvas.drawPath(
      block,
      Paint()
        ..color = outlineC
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
    final sunny = a < -math.pi / 2;
    canvas.drawPath(block, Paint()..color = sunny ? lit.color : _rock);
    canvas.drawPath(
      _poly([
        at(a + 0.05, 51, 43),
        at(a + 0.05, 59, 51),
        at(a + 0.2, 60, 52),
        at(a + 0.2, 50, 42),
      ]),
      Paint()..color = sunny ? _rock : dark.color,
    );
  }
  // Dây thường xuân rủ trên miệng hang.
  final ivy = Paint()..color = const Color(0xFF55703F);
  final ivyLit = Paint()..color = const Color(0xFF7E9A58);
  final rnd = math.Random(5);
  for (var i = 0; i < 6; i++) {
    final x = 306 + i * 14 + rnd.nextDouble() * 4;
    final len = 10 + rnd.nextDouble() * 16;
    final y0 = 140 + (x - 345).abs() * 0.32;
    canvas.drawLine(
      Offset(x, y0),
      Offset(x + 2, y0 + len),
      Paint()
        ..color = const Color(0xFF4A5E36)
        ..strokeWidth = 0.8,
    );
    for (var y = y0 + 3; y < y0 + len; y += 4) {
      final side = ((y - y0) ~/ 4).isEven ? -1.6 : 1.6;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x + 1 + side + (y - y0) / len * 2, y),
          width: 3.6,
          height: 2.6,
        ),
        side < 0 ? ivyLit : ivy,
      );
    }
  }
  // Xương con mồi trước hang: điềm báo sư tử.
  final bone = Paint()..color = const Color(0xFFEDE4CF);
  final boneLine = Paint()
    ..color = const Color(0xFF6D5D48)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.7;
  for (final (a, b) in [
    (const Offset(272, 216), const Offset(286, 212)),
    (const Offset(398, 214), const Offset(386, 218)),
  ]) {
    final path = capsulePath(a, b, 1.2, 1.2);
    canvas.drawPath(path, bone);
    canvas.drawPath(path, boneLine);
    for (final end in [a, b]) {
      canvas.drawCircle(end, 1.8, bone);
      canvas.drawCircle(end, 1.8, boneLine);
    }
  }
}

void _nearHill(Canvas canvas) {
  final hill = Path()
    ..moveTo(-10, 206)
    ..cubicTo(60, 196, 140, 202, 210, 206)
    ..cubicTo(240, 208, 260, 210, 270, stageGroundY)
    ..lineTo(-10, stageGroundY)
    ..close();
  canvas.drawPath(hill, Paint()..color = const Color(0xFF86A04A));
  canvas.drawPath(
    Path()
      ..moveTo(-10, 206)
      ..cubicTo(60, 196, 140, 202, 210, 206)
      ..lineTo(210, 209)
      ..cubicTo(140, 205, 60, 199, -10, 209)
      ..close(),
    Paint()..color = const Color(0xFFA9C062),
  );
  // Bụi cây thấp trên đồi gần.
  for (final (x, s) in [(118.0, 1.0), (176.0, 0.8), (230.0, 1.1)]) {
    _bush(canvas, Offset(x, 208), s);
  }
}

void _bush(Canvas canvas, Offset base, double s) {
  final blobs = [
    (const Offset(-6, -3), 5.0),
    (const Offset(0, -6), 6.0),
    (const Offset(6, -3), 4.5),
  ];
  for (final (o, r) in blobs) {
    canvas.drawCircle(
      base + o * s,
      (r + 0.9) * s,
      Paint()..color = const Color(0xFF3B3A22),
    );
  }
  for (final (o, r) in blobs) {
    canvas.drawCircle(base + o * s, r * s, Paint()..color = _olive);
  }
  for (final (o, r) in blobs) {
    canvas.drawCircle(
      base + (o + const Offset(-1.2, -1.4)) * s,
      r * 0.6 * s,
      Paint()..color = _oliveLit,
    );
  }
}

void _ground(Canvas canvas) {
  final w = stageSize.width;
  final h = stageSize.height;
  canvas.drawRect(
    Rect.fromLTRB(0, stageGroundY - 4, w, h),
    Paint()
      ..shader = Gradient.linear(
        const Offset(0, stageGroundY),
        Offset(0, h),
        const [Color(0xFFD2AA70), Color(0xFFB38652), Color(0xFF8E6538)],
        const [0, 0.5, 1],
      ),
  );
  // Mép cỏ nhô ra trên mặt đất.
  final edge = Path()..moveTo(0, stageGroundY - 4);
  for (var x = 0.0; x <= w; x += 6) {
    edge.lineTo(x + 3, stageGroundY - 1 + (x % 18 == 0 ? 2 : 0));
    edge.lineTo(x + 6, stageGroundY - 4);
  }
  edge
    ..lineTo(w, stageGroundY - 6)
    ..lineTo(0, stageGroundY - 6)
    ..close();
  canvas.drawPath(edge, Paint()..color = const Color(0xFF6F8E3C));
  // Lối mòn sáng hơn từ người chơi tới hang.
  canvas.drawPath(
    Path()
      ..moveTo(0, 236)
      ..cubicTo(120, 226, 220, 236, 400, 226)
      ..lineTo(400, 238)
      ..cubicTo(220, 250, 120, 240, 0, 252)
      ..close(),
    Paint()..color = const Color(0x40FFF1D0),
  );
  // Vết nứt đất.
  final crack = Paint()
    ..color = const Color(0x667A5530)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;
  for (final pts in [
    [const Offset(150, 246), const Offset(158, 242), const Offset(170, 244)],
    [const Offset(250, 250), const Offset(256, 245), const Offset(266, 246)],
    [const Offset(40, 240), const Offset(48, 236)],
  ]) {
    canvas.drawPath(Path()..addPolygon(pts, false), crack);
  }
  // Sỏi có bóng đổ.
  final rnd = math.Random(23);
  for (var i = 0; i < 22; i++) {
    final x = rnd.nextDouble() * w;
    final y = stageGroundY + 6 + rnd.nextDouble() * 34;
    final r = 1.2 + rnd.nextDouble() * 2.2 * (y - stageGroundY) / 30;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x + 0.8, y + 0.8),
        width: r * 2.4,
        height: r * 1.2,
      ),
      Paint()..color = const Color(0x55603E1C),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: r * 2.2, height: r * 1.4),
      Paint()..color = const Color(0xFFC9B593),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x - r * 0.3, y - r * 0.25),
        width: r,
        height: r * 0.5,
      ),
      Paint()..color = const Color(0xFFEDE1C6),
    );
  }
  // Hoa anh túc đỏ và cúc trắng ven lối.
  for (var i = 0; i < 14; i++) {
    final x = rnd.nextDouble() * w;
    final y = stageGroundY - 2 + rnd.nextDouble() * 6;
    final poppy = i % 3 != 0;
    canvas.drawLine(
      Offset(x, y),
      Offset(x, y - 5),
      Paint()
        ..color = const Color(0xFF5E7A3A)
        ..strokeWidth = 0.8,
    );
    canvas.drawCircle(
      Offset(x, y - 5.5),
      poppy ? 1.9 : 1.5,
      Paint()
        ..color = poppy ? const Color(0xFFD9452B) : const Color(0xFFFFFBEF),
    );
    canvas.drawCircle(
      Offset(x, y - 5.5),
      0.6,
      Paint()
        ..color = poppy ? const Color(0xFF2B1D16) : const Color(0xFFF2C14E),
    );
  }
}

/// Cây ô liu già phía trái: thân xoắn, tán bạc xanh nhiều chùm.
void _bigOlive(Canvas canvas) {
  const outlineC = VectorStyle.outline;
  // Thân xoắn hai nhánh.
  final trunk = Path()
    ..moveTo(4, stageGroundY + 2)
    ..cubicTo(14, 196, 2, 170, 14, 140)
    ..cubicTo(18, 128, 30, 112, 44, 96)
    ..lineTo(50, 100)
    ..cubicTo(36, 118, 28, 134, 28, 150)
    ..cubicTo(30, 170, 26, 200, 34, stageGroundY + 2)
    ..close();
  final branch = Path()
    ..moveTo(16, 142)
    ..cubicTo(10, 122, 0, 110, -6, 98)
    ..lineTo(-1, 95)
    ..cubicTo(6, 106, 16, 118, 22, 132)
    ..close();
  for (final p in [trunk, branch]) {
    canvas.drawPath(
      p,
      Paint()
        ..color = outlineC
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeJoin = StrokeJoin.round,
    );
  }
  for (final p in [trunk, branch]) {
    shadedPath(canvas, p, _bark, PartFrame.world, shadow: 4, outline: false);
  }
  // Vân vỏ cây xoắn.
  final grain = Paint()
    ..color = const Color(0xFF4B3D31)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;
  canvas.drawPath(
    Path()
      ..moveTo(12, 210)
      ..cubicTo(18, 190, 12, 170, 20, 150)
      ..moveTo(24, 214)
      ..cubicTo(22, 196, 24, 172, 30, 130),
    grain,
  );
  // Hốc cây.
  canvas.drawOval(
    const Rect.fromLTWH(15, 172, 6, 9),
    Paint()..color = const Color(0xFF2E241B),
  );

  final clusters = [
    (const Offset(-4, 84), 20.0),
    (const Offset(22, 72), 22.0),
    (const Offset(50, 84), 19.0),
    (const Offset(70, 96), 14.0),
    (const Offset(8, 100), 15.0),
    (const Offset(38, 100), 14.0),
    (const Offset(30, 54), 15.0),
  ];
  // Mỗi chùm lá: mép răng cưa không đều (lá ô liu thuôn), không phải
  // hình bầu dục trơn.
  Path clump(Offset c, double r, double grow, int seed) {
    final rnd = math.Random(seed);
    final path = Path();
    const n = 22;
    for (var i = 0; i <= n; i++) {
      final a = math.pi * 2 * i / n;
      final rr =
          (i.isEven ? r : r * 0.86) * (0.92 + rnd.nextDouble() * 0.16) + grow;
      final p = c + Offset(math.cos(a) * rr * 1.1, math.sin(a) * rr * 0.8);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  // Viền ngoài chung cho cả tán.
  final outlinePaint = Paint()..color = outlineC;
  for (var i = 0; i < clusters.length; i++) {
    final (c, r) = clusters[i];
    canvas.drawPath(clump(c, r, 2, i), outlinePaint);
  }
  // Ba tầng lá: tối (lõi khuất) → giữa → sáng (đón nắng trên-trái).
  final all = Path();
  for (var i = 0; i < clusters.length; i++) {
    final (c, r) = clusters[i];
    all.addPath(clump(c, r, 0, i), Offset.zero);
  }
  canvas.drawPath(all, Paint()..color = _oliveDark);
  canvas.save();
  canvas.clipPath(all);
  for (var i = 0; i < clusters.length; i++) {
    final (c, r) = clusters[i];
    canvas.drawPath(
      clump(c + Offset(-r * 0.16, -r * 0.2), r * 0.82, 0, i + 20),
      Paint()..color = _olive,
    );
    canvas.drawPath(
      clump(c + Offset(-r * 0.36, -r * 0.38), r * 0.48, 0, i + 40),
      Paint()..color = _oliveLit,
    );
  }
  // Ánh phản xạ lạnh ở mép dưới tán (Gurney: bóng ngả lạnh dưới nắng ấm).
  for (final (c, r) in clusters) {
    canvas.drawArc(
      Rect.fromCenter(center: c, width: r * 2.1, height: r * 1.5),
      0.4,
      2.0,
      false,
      Paint()
        ..color = const Color(0x557C98A8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }
  canvas.restore();
  // Lá thuôn bạc mặt dưới, xanh xám mặt trên (lá ô liu hai màu).
  furStrokes(
    canvas,
    all,
    const Color(0xFFCAD3A8),
    dir: const Offset(1, -0.4),
    count: 90,
    length: 4,
    width: 1.2,
    seed: 3,
  );
  furStrokes(
    canvas,
    all,
    const Color(0xFF3C4A2C),
    dir: const Offset(-1, -0.5),
    count: 70,
    length: 4,
    width: 1,
    seed: 4,
  );
  // Quả ô liu tím đen.
  final rnd = math.Random(3);
  final fruit = Paint()..color = const Color(0xFF3A2C3E);
  for (var i = 0; i < 12; i++) {
    final (c, r) = clusters[i % clusters.length];
    final a = rnd.nextDouble() * math.pi * 2;
    final d = rnd.nextDouble() * r * 0.7;
    canvas.drawCircle(
      c + Offset(math.cos(a) * d * 1.1, math.sin(a) * d * 0.7),
      1.3,
      fruit,
    );
  }
}

/// Đá đổ nát: khúc cột nằm, đầu cột vỡ, cột đứng gãy cạnh lối.
void _ruins(Canvas canvas) {
  // Khúc cột nằm ngang (trống cột) gần chân cây.
  final drum = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(38, 208, 30, 12),
        const Radius.circular(2),
      ),
    );
  shadedPath(canvas, drum, _marble, PartFrame.world, shadow: 3);
  for (var x = 43.0; x < 66; x += 5) {
    canvas.drawLine(
      Offset(x, 209),
      Offset(x, 219),
      Paint()
        ..color = const Color(0x55A89A88)
        ..strokeWidth = 0.6,
    );
  }
  // Mặt cắt tròn của trống cột.
  shadedPath(
    canvas,
    Path()..addOval(const Rect.fromLTWH(64, 207, 9, 14)),
    const Color(0xFFE6DCC6),
    PartFrame.world,
    shadow: 1.6,
  );
  // Rêu bám trên đá.
  canvas.drawOval(
    const Rect.fromLTWH(40, 207, 10, 3),
    Paint()..color = const Color(0xFF8DA05A),
  );

  // Cột gãy đứng bên phải lối, trước vách đá.
  final stump = _poly(const [
    Offset(236, stageGroundY),
    Offset(236, 184),
    Offset(239, 181),
    Offset(242, 185),
    Offset(246, 179),
    Offset(250, 183),
    Offset(250, stageGroundY),
  ]);
  shadedPath(canvas, stump, _marble, PartFrame.world, shadow: 3.5);
  for (final x in [240.0, 244.0]) {
    canvas.drawLine(
      Offset(x, 186),
      Offset(x, stageGroundY - 1),
      Paint()
        ..color = const Color(0x66A89A88)
        ..strokeWidth = 0.6,
    );
  }
  canvas.drawRect(
    const Rect.fromLTWH(232, 216, 22, 4),
    Paint()..color = const Color(0xFFD8CDB8),
  );
}

/// Phần động của phông nền theo [time] (giây): mây trôi, đàn chim xa,
/// lá ô liu đung đưa, cỏ lay. [dust] 0–1: hạt bụi xám Trì Trệ trôi lơ lửng;
/// bụi tan thì thay bằng hạt nắng vàng lấp lánh.
void paintNemeaAmbient(Canvas canvas, {double time = 0, double dust = 0}) {
  final w = stageSize.width;
  // Mây cel-shading: đáy phẳng tối, đỉnh sáng.
  for (final (x0, y, s) in [
    (30.0, 30.0, 1.0),
    (230.0, 22.0, 0.75),
    (330.0, 44.0, 0.55),
  ]) {
    final x = (x0 + time * 4 * s) % (w + 90) - 45;
    _cloud(canvas, Offset(x, y), s);
  }

  // Đàn chim Stymphalia lượn xa trên núi (báo hiệu quái của vùng).
  final bird = Paint()
    ..color = const Color(0xAA4A4038)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 4; i++) {
    final a = time * 0.25 + i * 0.5;
    final c = Offset(
      250 + math.cos(a) * 30 + i * 6,
      70 + math.sin(a * 1.3) * 8 + i * 3,
    );
    final flap = math.sin(time * 7 + i * 1.7) * 2;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 4, c.dy - flap)
        ..quadraticBezierTo(c.dx - 2, c.dy - 2, c.dx, c.dy)
        ..quadraticBezierTo(c.dx + 2, c.dy - 2, c.dx + 4, c.dy - flap),
      bird,
    );
  }

  // Lá ô liu lấp lánh khi gió thổi qua tán.
  final shimmer = Paint()..color = const Color(0xFFE4EAC8);
  for (var i = 0; i < 6; i++) {
    final phase = math.sin(time * 1.8 + i * 2.1);
    if (phase < 0.55) continue;
    final p = Offset(-2 + i * 13.0, 70 + (i % 3) * 12.0);
    canvas.drawOval(
      Rect.fromCenter(center: p, width: 3.6, height: 1.2),
      shimmer..color = Color.fromRGBO(228, 234, 200, (phase - 0.55) * 2.2),
    );
  }

  final grass = Paint()
    ..color = const Color(0xFF6E8B45)
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;
  final rnd = math.Random(7);
  for (var i = 0; i < 26; i++) {
    final x = rnd.nextDouble() * w;
    final sway = math.sin(time * 1.5 + i) * 1.5;
    canvas.drawLine(
      Offset(x, stageGroundY - 3),
      Offset(x - 2 + sway, stageGroundY - 9),
      grass,
    );
    canvas.drawLine(
      Offset(x + 2, stageGroundY - 3),
      Offset(x + 4 + sway, stageGroundY - 8),
      grass,
    );
  }

  // Sương Trì Trệ rỉ ra từ cửa hang, bò sát đất về phía thung lũng.
  if (dust > 0.05) {
    for (var i = 0; i < 5; i++) {
      final phase = (time * 0.07 + i / 5) % 1;
      final x = 330 - phase * 200;
      final y = stageGroundY - 8 - math.sin(phase * math.pi) * 10;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: 50 + phase * 60,
          height: 14 + phase * 8,
        ),
        Paint()
          ..color = Color.fromRGBO(
            82,
            68,
            104,
            0.5 * dust * math.sin(phase * math.pi),
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  // Cột nắng rọi xuống khi bụi tan: lung linh chậm, mạnh dần khi thắng.
  final clear = (1 - dust * 1.15).clamp(0.0, 1.0);
  if (clear > 0) {
    const sun = Offset(172, 34);
    for (var i = 0; i < 4; i++) {
      final a = 0.55 + i * 0.32 + math.sin(time * 0.3 + i) * 0.03;
      final w = 0.05 + 0.02 * math.sin(time * 0.7 + i * 2);
      final pulse = 0.5 + 0.5 * math.sin(time * 0.9 + i * 1.7);
      canvas.drawPath(
        Path()
          ..moveTo(sun.dx, sun.dy)
          ..lineTo(
            sun.dx + math.cos(a - w) * 300,
            sun.dy + math.sin(a - w) * 300,
          )
          ..lineTo(
            sun.dx + math.cos(a + w) * 300,
            sun.dy + math.sin(a + w) * 300,
          )
          ..close(),
        Paint()
          ..color = Color.fromRGBO(255, 240, 200, 0.07 * clear * (0.6 + pulse)),
      );
    }
  }

  // Đền sạch bụi lấp lánh: tia sao bốn cánh nhấp nháy trên mái và cột.
  final shine = ((clear - 0.6) / 0.4).clamp(0.0, 1.0);
  if (shine > 0) {
    for (final (i, p) in const [
      (0, Offset(193, 86)),
      (1, Offset(166, 98)),
      (2, Offset(222, 104)),
      (3, Offset(180, 118)),
    ]) {
      final tw = math.sin(time * 2.4 + i * 1.9);
      if (tw < 0.3) continue;
      final r = 5 * (tw - 0.3) / 0.7 * shine;
      final star = Paint()..color = Color.fromRGBO(255, 250, 225, 0.9 * shine);
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy - r)
          ..lineTo(p.dx + r * 0.18, p.dy - r * 0.18)
          ..lineTo(p.dx + r, p.dy)
          ..lineTo(p.dx + r * 0.18, p.dy + r * 0.18)
          ..lineTo(p.dx, p.dy + r)
          ..lineTo(p.dx - r * 0.18, p.dy + r * 0.18)
          ..lineTo(p.dx - r, p.dy)
          ..lineTo(p.dx - r * 0.18, p.dy - r * 0.18)
          ..close(),
        star,
      );
    }
  }

  // Hạt lơ lửng: bụi xám (Trì Trệ) hoặc hạt nắng vàng.
  final mote = Paint();
  for (var i = 0; i < 18; i++) {
    final speed = 4 + (i % 5) * 1.5;
    final x = (i * 53.0 + time * speed) % (w + 20) - 10;
    final y = 60 + (i * 37.0) % 150 + math.sin(time * 0.8 + i) * 6;
    final grey = i / 18 < dust;
    final twinkle = 0.5 + 0.5 * math.sin(time * 2.4 + i * 1.3);
    mote.color = grey
        ? Color.fromRGBO(120, 114, 130, 0.35 + 0.25 * twinkle)
        : Color.fromRGBO(255, 236, 170, 0.15 + 0.45 * twinkle);
    canvas.drawCircle(Offset(x, y), grey ? 1.8 : 1.1, mote);
  }
}

void _cloud(Canvas canvas, Offset at, double s) {
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.scale(s);
  canvas.drawPicture(_cloudPicture);
  canvas.restore();
}

/// Mây chiều: dẹt, nhiều thuỳ không đều, đáy phẳng ngả tím lạnh (bóng),
/// đỉnh vàng ấm đón nắng — vẽ sẵn một lần.
final Picture _cloudPicture = () {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  final lobes = [
    (const Offset(-6, 0), 9.0),
    (const Offset(6, -6), 12.0),
    (const Offset(20, -9), 14.0),
    (const Offset(34, -4), 11.0),
    (const Offset(46, 0), 8.0),
    (const Offset(28, 2), 10.0),
    (const Offset(12, 2), 9.0),
  ];
  final body = Path();
  for (final (o, r) in lobes) {
    body.addOval(Rect.fromCircle(center: o, radius: r));
  }
  canvas.save();
  canvas.clipRect(const Rect.fromLTRB(-30, -40, 70, 6));
  // Đáy và mặt khuất: tím lạnh.
  canvas.drawPath(body, Paint()..color = const Color(0xFFC7C3D9));
  // Thân: trắng ngà, lệch lên trên-trái.
  canvas.drawPath(
    body.shift(const Offset(-1.5, -3)),
    Paint()..color = const Color(0xFFF4F1EC),
  );
  // Đỉnh đón nắng: vàng ấm.
  canvas.save();
  canvas.clipPath(body.shift(const Offset(-1.5, -3)));
  for (final (o, r) in lobes) {
    canvas.drawCircle(
      o + const Offset(-3, -5),
      r * 0.62,
      Paint()..color = const Color(0xFFFFF4DA),
    );
  }
  canvas.restore();
  // Đáy phẳng: dải tím đậm hơn, chỉ trong thân mây.
  canvas.clipPath(body);
  canvas.drawRect(
    const Rect.fromLTRB(-20, 1, 60, 6),
    Paint()..color = const Color(0xFFB2ADC9),
  );
  canvas.restore();
  return recorder.endRecording();
}();

/// Tiền cảnh (vẽ đè lên nhân vật, góc dưới hai bên): cỏ cao và tảng đá
/// tối ngược sáng. Trôi ngược chiều camera nên tạo khoảng sâu giữa máy quay
/// và nhân vật (2,5D). Tránh vùng giữa để không che trận đấu.
void paintNemeaForeground(Canvas canvas) {
  const dark = Color(0xFF3B3424);
  const darker = Color(0xFF2A2419);
  // Tảng đá góc phải dưới.
  final rock = Path()
    ..moveTo(352, 262)
    ..lineTo(360, 244)
    ..lineTo(378, 236)
    ..lineTo(398, 240)
    ..lineTo(412, 262)
    ..close();
  canvas.drawPath(rock, Paint()..color = darker);
  canvas.drawPath(
    Path()
      ..moveTo(360, 244)
      ..lineTo(378, 236)
      ..lineTo(384, 246)
      ..lineTo(366, 252)
      ..close(),
    Paint()..color = const Color(0xFF4A4232),
  );
  // Viền sáng ấm trên mép đá (ánh chiều hắt).
  canvas.drawPath(
    Path()
      ..moveTo(360, 244)
      ..lineTo(378, 236)
      ..lineTo(398, 240),
    Paint()
      ..color = const Color(0x88F2C27A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );
  // Bụi cỏ cao hai góc: lá thon cong, tối ngược sáng, mép sáng ấm.
  final rnd = math.Random(17);
  for (final (x0, x1, h) in [(-10.0, 40.0, 34.0), (330.0, 410.0, 26.0)]) {
    for (var i = 0; i < 16; i++) {
      final x = x0 + rnd.nextDouble() * (x1 - x0);
      final len = h * (0.5 + rnd.nextDouble() * 0.6);
      final lean = (rnd.nextDouble() - 0.4) * len * 0.6;
      final blade = Path()
        ..moveTo(x - 2, 262)
        ..quadraticBezierTo(
          x + lean * 0.3,
          262 - len * 0.6,
          x + lean,
          262 - len,
        )
        ..quadraticBezierTo(x + lean * 0.4 + 2, 262 - len * 0.5, x + 2, 262)
        ..close();
      canvas.drawPath(blade, Paint()..color = i.isEven ? dark : darker);
      canvas.drawPath(
        Path()
          ..moveTo(x - 1, 262 - len * 0.2)
          ..quadraticBezierTo(
            x + lean * 0.3,
            262 - len * 0.6,
            x + lean,
            262 - len,
          ),
        Paint()
          ..color = const Color(0x66E8C27A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    }
  }
}
