import 'dart:math' as math;
import 'dart:ui';

import 'vector_style.dart';

/// Kích thước bản đồ Thung lũng Nemea (đơn vị vẽ).
const nemeaMapSize = Size(400, 300);

/// Vị trí 10 điểm màn trên bản đồ: từ bìa rừng ô liu (dưới trái) men theo
/// đường mòn lên đồi đền, qua cầu đá, tới hang sư tử (trên phải).
const nemeaMapNodes = <Offset>[
  Offset(48, 262),
  Offset(104, 240),
  Offset(84, 196),
  Offset(140, 170),
  Offset(204, 188),
  Offset(250, 228),
  Offset(304, 200),
  Offset(276, 148),
  Offset(318, 104),
  Offset(352, 62),
];

/// Trạng thái một điểm màn trên bản đồ.
enum MapNodeState { locked, open, done }

/// Vẽ bản đồ thung lũng kiểu nhìn chéo từ trên (Kingdom Rush): đồi, rừng
/// ô liu, sông, đền, hang sư tử; đường mòn nối 10 điểm, đoạn đã đi sáng
/// màu, điểm kế tiếp nhấp nháy. [time] cho nước chảy và điểm nhấp nháy.
void paintNemeaMap(
  Canvas canvas,
  List<MapNodeState> states, {
  double time = 0,
}) {
  final w = nemeaMapSize.width;
  final h = nemeaMapSize.height;
  // Phần tĩnh chụp sẵn thành ảnh; mỗi khung chỉ vẽ sông, đường, các điểm.
  _mapGround.paint(canvas);
  _river(canvas, time);
  _mapProps.paint(canvas);
  _path(canvas, states);
  for (var i = 0; i < nemeaMapNodes.length; i++) {
    _node(
      canvas,
      nemeaMapNodes[i],
      i + 1,
      states[i],
      boss: i == nemeaMapNodes.length - 1,
      elite: i == 4 || i == 7,
      time: time,
    );
  }
  // Viền giấy cũ (vignette nâu) cho cảm giác bản đồ.
  canvas.drawRect(
    Offset.zero & nemeaMapSize,
    Paint()
      ..shader = Gradient.radial(
        Offset(w / 2, h / 2),
        w * 0.62,
        const [Color(0x00000000), Color(0x00000000), Color(0x664A3018)],
        const [0, 0.7, 1],
      ),
  );
}

Path _poly(List<Offset> pts) => Path()..addPolygon(pts, true);

/// Nền đất, đồi, núi đá (dưới sông).
final _mapGround = RasterLayer((canvas) {
  // Nền đất cỏ, sáng dần lên phía trên (xa) như phối cảnh không khí.
  canvas.drawRect(
    Offset.zero & nemeaMapSize,
    Paint()
      ..shader = Gradient.linear(
        Offset.zero,
        Offset(0, nemeaMapSize.height),
        const [Color(0xFFB9BD86), Color(0xFF8FA25E), Color(0xFF7C9150)],
        const [0, 0.5, 1],
      ),
  );
  _fieldSpecks(canvas);
  _hills(canvas);
}, bounds: Offset.zero & nemeaMapSize);

/// Rừng, đền, hang (trên sông).
final _mapProps = RasterLayer((canvas) {
  _forest(canvas);
  _temple(canvas, const Offset(196, 128));
  _cave(canvas, const Offset(356, 50));
}, bounds: Offset.zero & nemeaMapSize);

/// Đốm cỏ và mảng đất trống rải trên đồng (chất liệu bản đồ vẽ tay).
void _fieldSpecks(Canvas canvas) {
  final rnd = math.Random(4);
  for (var i = 0; i < 26; i++) {
    final c = Offset(rnd.nextDouble() * 400, 20 + rnd.nextDouble() * 280);
    canvas.drawOval(
      Rect.fromCenter(
        center: c,
        width: 14 + rnd.nextDouble() * 26,
        height: 5 + rnd.nextDouble() * 8,
      ),
      Paint()
        ..color = (i.isEven
            ? const Color(0x22F2E3A0)
            : const Color(0x1A3E4A20)),
    );
  }
  final tuft = Paint()..color = const Color(0x665E7034);
  for (var i = 0; i < 140; i++) {
    final p = Offset(rnd.nextDouble() * 400, rnd.nextDouble() * 300);
    for (final a in const [-0.5, 0.0, 0.5]) {
      canvas.drawPath(
        taperedStroke(
          [p, p + Offset(math.sin(a) * 2.2, -2.6 + a.abs())],
          0.7,
          peak: 0.1,
          startWidth: 1,
        ),
        tuft,
      );
    }
  }
}

void _hills(Canvas canvas) {
  // Các gò đồi: mặt đón nắng (trái-trên) sáng, mặt khuất tối.
  for (final (c, rx, ry) in [
    (const Offset(70, 90), 70.0, 34.0),
    (const Offset(200, 110), 90.0, 40.0),
    (const Offset(330, 70), 80.0, 50.0),
    (const Offset(150, 260), 60.0, 22.0),
  ]) {
    final r = Rect.fromCenter(center: c, width: rx * 2, height: ry * 2);
    canvas.drawOval(r, Paint()..color = const Color(0xFF8E9E5C));
    canvas.drawOval(
      r.shift(Offset(-rx * 0.12, -ry * 0.18)).deflate(ry * 0.2),
      Paint()..color = const Color(0xFFA9B577),
    );
    // Đường đồng mức gạch bóng ở sườn khuất (phải – dưới), kiểu bản đồ.
    canvas.save();
    canvas.clipPath(Path()..addOval(r));
    final contour = Paint()
      ..color = const Color(0x553E4A22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var k = 1; k <= 3; k++) {
      final rr = r
          .deflate(ry * 0.22 * k)
          .shift(Offset(rx * 0.04 * k, ry * 0.05 * k));
      canvas.drawArc(rr, -0.3, 2.0, false, contour);
    }
    canvas.restore();
  }
  // Núi đá sau hang.
  final cliff = _poly(const [
    Offset(290, 0),
    Offset(400, 0),
    Offset(400, 110),
    Offset(372, 92),
    Offset(340, 98),
    Offset(316, 70),
    Offset(300, 40),
  ]);
  canvas.drawPath(cliff, Paint()..color = const Color(0xFFA58C66));
  canvas.drawPath(
    _poly(const [Offset(300, 40), Offset(316, 70), Offset(340, 30)]),
    Paint()..color = const Color(0xFFC6AE86),
  );
  canvas.drawPath(
    _poly(const [Offset(372, 92), Offset(400, 110), Offset(400, 40)]),
    Paint()..color = const Color(0xFF7E6A4C),
  );
  // Chất đá: vân nghiêng đứt quãng và vệt mưa.
  canvas.save();
  canvas.clipPath(cliff);
  final rnd = math.Random(8);
  final seam = Paint()..color = const Color(0x665E4A30);
  for (var i = 0; i < 14; i++) {
    final x = 296 + rnd.nextDouble() * 100;
    final y = 6 + rnd.nextDouble() * 96;
    final len = 10 + rnd.nextDouble() * 18;
    canvas.drawPath(
      taperedStroke(
        [
          Offset(x, y),
          Offset(x + len * 0.5, y - len * 0.12),
          Offset(x + len, y - len * 0.1),
        ],
        1.2,
        peak: 0.5,
      ),
      seam,
    );
  }
  final streak = Paint()..color = const Color(0x445E4A30);
  for (var i = 0; i < 12; i++) {
    final x = 300 + rnd.nextDouble() * 96;
    final y = rnd.nextDouble() * 60;
    canvas.drawPath(
      taperedStroke(
        [Offset(x, y), Offset(x + 0.6, y + 10), Offset(x, y + 22)],
        1.4,
        peak: 0.2,
      ),
      streak,
    );
  }
  canvas.restore();
}

void _river(Canvas canvas, double time) {
  final river = Path()
    ..moveTo(0, 150)
    ..cubicTo(60, 140, 120, 220, 190, 216)
    ..cubicTo(250, 212, 260, 260, 300, 300)
    ..lineTo(326, 300)
    ..cubicTo(284, 250, 270, 200, 190, 202)
    ..cubicTo(126, 206, 70, 128, 0, 136)
    ..close();
  canvas.drawPath(river, Paint()..color = const Color(0xFF5E93B8));
  canvas.save();
  canvas.clipPath(river);
  // Gợn nước trôi.
  final ripple = Paint()
    ..color = const Color(0x88D8EEFA)
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 14; i++) {
    final x = (i * 29 + time * 12) % 340;
    final y = 140.0 + i * 11 % 160;
    canvas.drawLine(Offset(x, y), Offset(x + 6, y + 1), ripple);
  }
  canvas.restore();
  // Bờ sông đậm.
  canvas.drawPath(
    river,
    Paint()
      ..color = const Color(0x664A6A3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
  // Cầu đá qua sông ở chỗ đường mòn cắt ngang.
  final bridge = RRect.fromRectAndRadius(
    Rect.fromCenter(center: const Offset(232, 210), width: 26, height: 12),
    const Radius.circular(3),
  );
  canvas.drawRRect(bridge.inflate(1.4), Paint()..color = VectorStyle.outline);
  canvas.drawRRect(bridge, Paint()..color = const Color(0xFFD9CFB8));
  for (var x = -10.0; x <= 10; x += 5) {
    canvas.drawLine(
      Offset(232 + x, 205),
      Offset(232 + x, 215),
      Paint()
        ..color = const Color(0xFFA89C82)
        ..strokeWidth = 0.8,
    );
  }
}

void _forest(Canvas canvas) {
  final rnd = math.Random(4);
  // Rừng ô liu dưới trái + rải rác; cây bách đứng thẳng.
  for (var i = 0; i < 46; i++) {
    final cluster = i % 3;
    final c = switch (cluster) {
      0 => const Offset(30, 210),
      1 => const Offset(170, 280),
      _ => const Offset(140, 60),
    };
    final p =
        c + Offset(rnd.nextDouble() * 80 - 40, rnd.nextDouble() * 40 - 20);
    if (_nearPath(p, 14)) continue;
    _tree(canvas, p, 0.8 + rnd.nextDouble() * 0.4, cypress: i % 7 == 0);
  }
}

bool _nearPath(Offset p, double r) {
  for (final n in nemeaMapNodes) {
    if ((n - p).distance < r) return true;
  }
  return false;
}

void _tree(Canvas canvas, Offset base, double s, {bool cypress = false}) {
  canvas.drawOval(
    Rect.fromCenter(
      center: base + Offset(3 * s, 1),
      width: 12 * s,
      height: 4 * s,
    ),
    Paint()..color = const Color(0x44302010),
  );
  if (cypress) {
    final p = Path()
      ..moveTo(base.dx, base.dy - 20 * s)
      ..quadraticBezierTo(
        base.dx + 5 * s,
        base.dy - 8 * s,
        base.dx + 3 * s,
        base.dy,
      )
      ..lineTo(base.dx - 3 * s, base.dy)
      ..quadraticBezierTo(
        base.dx - 5 * s,
        base.dy - 8 * s,
        base.dx,
        base.dy - 20 * s,
      )
      ..close();
    canvas.drawPath(p, Paint()..color = const Color(0xFF3F5A3C));
    return;
  }
  canvas.drawLine(
    base,
    base + Offset(0, -5 * s),
    Paint()
      ..color = const Color(0xFF5E4C3C)
      ..strokeWidth = 1.6 * s,
  );
  canvas.drawCircle(
    base + Offset(0, -9 * s),
    6.5 * s,
    Paint()..color = VectorStyle.outline,
  );
  canvas.drawCircle(
    base + Offset(0, -9 * s),
    5.5 * s,
    Paint()..color = const Color(0xFF5E7444),
  );
  canvas.drawCircle(
    base + Offset(-1.6 * s, -10.6 * s),
    3 * s,
    Paint()..color = const Color(0xFF93A56A),
  );
}

void _temple(Canvas canvas, Offset c) {
  final outline = Paint()
    ..color = VectorStyle.outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final base = Rect.fromCenter(center: c, width: 40, height: 6);
  canvas.drawRect(base, Paint()..color = const Color(0xFFEDE4CF));
  canvas.drawRect(base, outline);
  for (var i = 0; i < 6; i++) {
    final x = c.dx - 16 + i * 6.4;
    final col = Rect.fromLTWH(x - 1.6, c.dy - 18, 3.2, 15);
    canvas.drawRect(col, Paint()..color = const Color(0xFFF3ECDC));
    canvas.drawRect(
      Rect.fromLTWH(x + 0.4, c.dy - 18, 1.2, 15),
      Paint()..color = const Color(0xFFC9BCA8),
    );
  }
  final roof = _poly([
    Offset(c.dx - 22, c.dy - 18),
    Offset(c.dx, c.dy - 30),
    Offset(c.dx + 22, c.dy - 18),
  ]);
  canvas.drawPath(roof, Paint()..color = const Color(0xFFEDE4CF));
  canvas.drawPath(roof, outline);
}

void _cave(Canvas canvas, Offset c) {
  final mouth = Path()
    ..moveTo(c.dx - 18, c.dy + 12)
    ..cubicTo(c.dx - 18, c.dy - 8, c.dx + 18, c.dy - 8, c.dx + 18, c.dy + 12)
    ..close();
  canvas.drawPath(
    mouth.shift(const Offset(0, 1)),
    Paint()..color = VectorStyle.outline,
  );
  canvas.drawPath(mouth, Paint()..color = const Color(0xFF1E140C));
  // Mắt sư tử đỏ rực trong bóng tối hang.
  for (final dx in [-5.0, 5.0]) {
    canvas.drawCircle(
      c + Offset(dx, 4),
      3.2,
      Paint()..color = const Color(0x66FF6A1A),
    );
    canvas.drawCircle(
      c + Offset(dx, 4),
      1.4,
      Paint()..color = const Color(0xFFFFB347),
    );
  }
}

void _path(Canvas canvas, List<MapNodeState> states) {
  Path segment(int from, int to) {
    final p = Path()..moveTo(nemeaMapNodes[from].dx, nemeaMapNodes[from].dy);
    for (var i = from + 1; i <= to; i++) {
      final a = nemeaMapNodes[i - 1];
      final b = nemeaMapNodes[i];
      final mid =
          Offset.lerp(a, b, 0.5)! +
          Offset((b.dy - a.dy) * 0.25, (a.dx - b.dx) * 0.25);
      p.quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
    }
    return p;
  }

  final all = segment(0, nemeaMapNodes.length - 1);
  // Đường mòn đất: viền tối, thân sáng.
  canvas.drawPath(
    all,
    Paint()
      ..color = const Color(0xFF6E5232)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.drawPath(
    all,
    Paint()
      ..color = const Color(0xFFD9BC88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
  // Đoạn đã đi: chấm vàng dọc đường.
  final reached = states.lastIndexWhere((s) => s != MapNodeState.locked);
  if (reached > 0) {
    final walked = segment(0, reached);
    for (final metric in walked.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        final t = metric.getTangentForOffset(d);
        if (t == null) continue;
        canvas.drawCircle(
          t.position,
          1.4,
          Paint()..color = const Color(0xFFFFE08A),
        );
      }
    }
  }
}

void _node(
  Canvas canvas,
  Offset at,
  int number,
  MapNodeState state, {
  required bool boss,
  required bool elite,
  required double time,
}) {
  final r = boss
      ? 15.0
      : elite
      ? 12.0
      : 10.0;
  // Điểm kế tiếp: vầng sáng nhấp nháy mời chơi.
  if (state == MapNodeState.open) {
    final pulse = 0.5 + 0.5 * math.sin(time * 4);
    canvas.drawCircle(
      at,
      r + 5 + 4 * pulse,
      Paint()..color = Color.fromRGBO(255, 226, 120, 0.25 + 0.3 * pulse),
    );
  }
  // Bóng đổ.
  canvas.drawOval(
    Rect.fromCenter(
      center: at + const Offset(2, 3),
      width: r * 2.1,
      height: r * 1.2,
    ),
    Paint()..color = const Color(0x55301C10),
  );
  // Khiên tròn: vàng (boss), bạc (tinh anh), đồng (thường); khoá thì xám.
  final face = switch (state) {
    MapNodeState.locked => const Color(0xFF8C8A84),
    _ when boss => const Color(0xFFE8B83A),
    _ when elite => const Color(0xFFCAD1D8),
    _ => const Color(0xFFC08A4A),
  };
  canvas.drawCircle(at, r + 1.6, Paint()..color = VectorStyle.outline);
  canvas.drawCircle(at, r, Paint()..color = face);
  canvas.drawCircle(
    at + Offset(-r * 0.2, -r * 0.25),
    r * 0.6,
    Paint()..color = lighten(face, 0.25),
  );
  canvas.drawCircle(
    at,
    r * 0.78,
    Paint()
      ..color = darken(face, 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1,
  );
  if (state == MapNodeState.done) {
    // Dấu tích xanh.
    canvas.drawPath(
      Path()
        ..moveTo(at.dx - r * 0.45, at.dy)
        ..lineTo(at.dx - r * 0.1, at.dy + r * 0.38)
        ..lineTo(at.dx + r * 0.5, at.dy - r * 0.4),
      Paint()
        ..color = const Color(0xFF2E7D32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  } else if (state == MapNodeState.locked) {
    // Ổ khoá nhỏ.
    final body = Rect.fromCenter(
      center: at + const Offset(0, 1.5),
      width: r * 0.8,
      height: r * 0.6,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: at + Offset(0, -r * 0.1),
        width: r * 0.55,
        height: r * 0.7,
      ),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = const Color(0xFF4A4844)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawRect(body, Paint()..color = const Color(0xFF4A4844));
  } else if (boss) {
    // Đầu sư tử cách điệu: bờm răng cưa.
    final mane = Path();
    for (var k = 0; k <= 16; k++) {
      final a = k * math.pi / 8;
      final rr = k.isEven ? r * 0.62 : r * 0.42;
      final p = at + Offset(math.cos(a) * rr, math.sin(a) * rr);
      k == 0 ? mane.moveTo(p.dx, p.dy) : mane.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(mane..close(), Paint()..color = const Color(0xFF8E3714));
    canvas.drawCircle(at, r * 0.32, Paint()..color = const Color(0xFFD99A34));
  } else {
    // Gươm chéo: biểu tượng trận đánh.
    final sword = Paint()
      ..color = VectorStyle.outline
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      at + Offset(-r * 0.45, -r * 0.45),
      at + Offset(r * 0.45, r * 0.45),
      sword,
    );
    canvas.drawLine(
      at + Offset(r * 0.45, -r * 0.45),
      at + Offset(-r * 0.45, r * 0.45),
      sword,
    );
  }
  // Số màn trên dải băng nhỏ phía dưới.
  final label = '1.$number';
  final tp =
      ParagraphBuilder(
          ParagraphStyle(
            textAlign: TextAlign.center,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        )
        ..pushStyle(TextStyle(color: const Color(0xFF2B1D16)))
        ..addText(label);
  final para = tp.build()..layout(const ParagraphConstraints(width: 30));
  final band = RRect.fromRectAndRadius(
    Rect.fromCenter(center: at + Offset(0, r + 7), width: 22, height: 10),
    const Radius.circular(3),
  );
  canvas.drawRRect(band.inflate(1), Paint()..color = VectorStyle.outline);
  canvas.drawRRect(band, Paint()..color = const Color(0xFFF2E6C4));
  canvas.drawParagraph(para, at + Offset(-15, r + 2));
}
