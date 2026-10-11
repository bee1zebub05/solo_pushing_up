import 'dart:math' as math;
import 'dart:ui';

/// Bộ công cụ phong cách "game vector": viền đậm mượt, đổ bóng hai tông
/// (cel shading) phía khuất sáng, viền sáng phía có nắng. Ánh sáng chiếu từ
/// trên bên trái, giữ đúng hướng dù bộ phận đang xoay.
///
/// Hiệu năng: không dùng phép ghép hình (`Path.combine`, tốn CPU mỗi khung);
/// bóng và viền sáng làm bằng vùng cắt chồng lớp, phần nặng do GPU xử lý.
abstract final class VectorStyle {
  static const outline = Color(0xFF2B1D16);
  static const outlineWidth = 1.4;

  /// Hướng tới nguồn sáng (toạ độ màn hình): trên, lệch trái.
  static const lightWorld = Offset(-0.55, -0.83);

  /// Ánh phản xạ (rim light) ở mép khuất sáng: ánh trời lạnh hắt lại, giúp
  /// khối tách khỏi nền và bớt "phẳng".
  static const rimTint = Color(0xFF8FB8F0);
}

Color darken(Color c, [double amount = 0.22]) =>
    Color.lerp(c, const Color(0xFF000000), amount)!;

Color lighten(Color c, [double amount = 0.3]) =>
    Color.lerp(c, const Color(0xFFFFFFFF), amount)!;

/// Màu bóng: tối hơn và ngả tím chàm lạnh (bảng màu fantasy: nắng vàng
/// ấm, bóng tím lạnh — nhiệt độ tương phản, Gurney).
Color shadeOf(Color c) =>
    Color.lerp(darken(c, 0.22), const Color(0xFF3A2C6E), 0.2)!;

/// Bóng lõi (core shadow): dải tối nhất ngay trước vùng ánh phản xạ — chàm
/// tím đậm (bảng màu fantasy: nắng vàng ấm, bóng tím lạnh).
Color coreShadeOf(Color c) =>
    Color.lerp(darken(c, 0.4), const Color(0xFF241A4E), 0.26)!;

/// Vùng sáng: ngả vàng nắng thay vì trắng, giữ màu bão hoà.
Color sunlitOf(Color c) =>
    Color.lerp(lighten(c, 0.2), const Color(0xFFFFE9A8), 0.18)!;

Color rimOf(Color c) => Color.lerp(shadeOf(c), VectorStyle.rimTint, 0.38)!;

Paint fillPaint(Color c) => Paint()
  ..color = c
  ..isAntiAlias = true;

Offset rotateVec(Offset v, double rad) => Offset(
  v.dx * math.cos(rad) - v.dy * math.sin(rad),
  v.dx * math.sin(rad) + v.dy * math.cos(rad),
);

/// Hệ toạ độ cục bộ của một bộ phận (đã xoay [angle] so với màn hình).
class PartFrame {
  const PartFrame(this.angle);

  static const world = PartFrame(0);

  final double angle;

  /// Đổi một hướng trên màn hình sang hệ cục bộ.
  Offset local(Offset worldDir) => rotateVec(worldDir, -angle);

  Offset get down => local(const Offset(0, 1));
  Offset get light => local(VectorStyle.lightWorld);
}

/// Vẽ trong hệ cục bộ gốc tại [origin], trục "lên" của bộ phận là -y.
void withFrame(
  Canvas canvas,
  Offset origin,
  Offset up,
  void Function(PartFrame frame) draw,
) {
  final angle = math.atan2(up.dx, -up.dy);
  canvas.save();
  canvas.translate(origin.dx, origin.dy);
  canvas.rotate(angle);
  draw(PartFrame(angle));
  canvas.restore();
}

/// Tô một mảng có viền, đổ bóng và viền sáng.
///
/// Trong vùng cắt [path]: tô màu sáng, cắt tiếp bằng bản sao dịch ra xa
/// ánh sáng (chừa lại viền sáng phía có nắng), tô màu bóng, rồi tô màu gốc
/// bằng bản sao dịch về phía sáng (chừa lại mảng bóng phía khuất).
/// [outlineShape]: hình phình to sẵn làm viền (cho chuỗi nhiều đoạn chồng
/// nhau, tránh vẽ viền ở chỗ nối); null thì vẽ viền bằng nét.
void shadedPath(
  Canvas canvas,
  Path path,
  Color base,
  PartFrame frame, {
  double shadow = 3,
  double highlight = 1.4,
  double outlineWidth = VectorStyle.outlineWidth,
  bool outline = true,
  Path? outlineShape,
  bool rimLight = true,
}) {
  final light = frame.light;
  if (outline) {
    // Viền dày hơn ở phía khuất sáng: thêm một bản viền lệch về phía bóng.
    final heavy = -light * (outlineWidth * 0.7);
    if (outlineShape != null) {
      canvas.drawPath(outlineShape, fillPaint(VectorStyle.outline));
      canvas.drawPath(
        outlineShape.shift(heavy),
        fillPaint(VectorStyle.outline),
      );
    } else {
      canvas.drawPath(path.shift(heavy), fillPaint(VectorStyle.outline));
      canvas.drawPath(
        path,
        Paint()
          ..color = VectorStyle.outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = outlineWidth * 2
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }
  canvas.save();
  canvas.clipPath(path);
  if (highlight > 0) {
    canvas.drawPaint(fillPaint(sunlitOf(base)));
    canvas.clipPath(path.shift(light * -highlight));
  }
  if (shadow > 0) {
    // Từ mép khuất vào trong: ánh phản xạ → bóng lõi → bóng → màu gốc.
    final rim = shadow * 0.28;
    final core = shadow * 0.55;
    if (rimLight) {
      canvas.drawPaint(fillPaint(rimOf(base)));
      canvas.drawPath(path.shift(light * rim), fillPaint(coreShadeOf(base)));
      canvas.drawPath(path.shift(light * core), fillPaint(shadeOf(base)));
    } else {
      canvas.drawPaint(fillPaint(shadeOf(base)));
    }
    canvas.drawPath(path.shift(light * shadow), _basePaint(path, base));
  } else {
    canvas.drawPaint(fillPaint(base));
  }
  canvas.restore();
}

/// Màu gốc chuyển nhẹ từ sáng (trên) xuống sẫm (dưới) cho có khối.
Paint _basePaint(Path path, Color base) {
  final b = path.getBounds();
  if (b.height < 6) return fillPaint(base);
  return Paint()
    ..isAntiAlias = true
    ..shader = Gradient.linear(b.topCenter, b.bottomCenter, [
      lighten(base, 0.06),
      darken(base, 0.07),
    ]);
}

/// Nét lông/sợi trong vùng [path]: [count] nét cong ngắn theo hướng [dir],
/// đậm ở gốc. Dùng cho lông thú, bờm, cỏ khô.
void furStrokes(
  Canvas canvas,
  Path path,
  Color color, {
  Offset dir = const Offset(0.4, 1),
  int count = 24,
  double length = 7,
  double width = 1.1,
  int seed = 1,
}) {
  final b = path.getBounds();
  final rnd = math.Random(seed);
  final d = dir / dir.distance;
  final n = Offset(-d.dy, d.dx);
  final stroke = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;
  final strokes = Path();
  for (var i = 0; i < count; i++) {
    final p = Offset(
      b.left + rnd.nextDouble() * b.width,
      b.top + rnd.nextDouble() * b.height,
    );
    final len = length * (0.6 + rnd.nextDouble() * 0.6);
    final bend = (rnd.nextDouble() - 0.5) * len * 0.5;
    final end = p + d * len;
    final mid = Offset.lerp(p, end, 0.5)! + n * bend;
    strokes
      ..moveTo(p.dx, p.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);
  }
  canvas.save();
  canvas.clipPath(path);
  canvas.drawPath(strokes, stroke);
  canvas.restore();
}

/// Gạch bóng song song (kiểu khắc gỗ/tranh truyện) trong vùng [path].
void hatch(
  Canvas canvas,
  Path path,
  Color color, {
  double spacing = 3,
  double angle = 0.9,
  double width = 0.7,
}) {
  final b = path.getBounds();
  final d = Offset(math.cos(angle), math.sin(angle));
  final n = Offset(-d.dy, d.dx);
  final reach = b.longestSide;
  final lines = Path();
  for (var k = -reach; k <= reach; k += spacing) {
    final c = b.center + n * k;
    lines
      ..moveTo(c.dx - d.dx * reach, c.dy - d.dy * reach)
      ..lineTo(c.dx + d.dx * reach, c.dy + d.dy * reach);
  }
  canvas.save();
  canvas.clipPath(path);
  canvas.drawPath(
    lines,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width,
  );
  canvas.restore();
}

/// Chỉnh màu toàn cảnh, vẽ sau cùng: phủ ánh sáng cảnh [light] (nhân màu
/// nhẹ để thống nhất tông) và vignette tối bốn góc kéo mắt vào giữa.
void paintStageGrade(
  Canvas canvas,
  Rect stage, {
  Color light = const Color(0xFFFFE3C0),
  double vignette = 0.42,
}) {
  canvas.drawRect(
    stage,
    Paint()
      ..color = light.withValues(alpha: 0.24)
      ..blendMode = BlendMode.multiply,
  );
  // Tách tông kiểu fantasy: trên ánh vàng nắng (screen), dưới chàm lạnh
  // (multiply) — vùng sáng ấm, vùng tối lạnh (Gurney: nhiệt độ tương phản).
  canvas.drawRect(
    stage,
    Paint()
      ..blendMode = BlendMode.softLight
      ..shader = Gradient.linear(
        stage.topCenter,
        stage.bottomCenter,
        const [Color(0x66FFD27A), Color(0x00808080), Color(0x553A3A8A)],
        const [0, 0.5, 1],
      ),
  );
  // Ánh nắng loá nhẹ từ góc trên trái (nguồn sáng của cảnh).
  canvas.drawRect(
    stage,
    Paint()
      ..blendMode = BlendMode.screen
      ..shader = Gradient.radial(
        stage.topLeft + Offset(stage.width * 0.38, stage.height * 0.1),
        stage.longestSide * 0.55,
        const [Color(0x40FFE6A8), Color(0x00000000)],
      ),
  );
  canvas.drawRect(
    stage,
    Paint()
      ..shader = Gradient.radial(
        stage.center,
        stage.longestSide * 0.62,
        [
          const Color(0x00000000),
          const Color(0x00000000),
          Color.fromRGBO(24, 12, 40, vignette),
        ],
        const [0, 0.62, 1],
      ),
  );
}

/// Ma trận tăng độ bão hoà [s] (1 = giữ nguyên) — bọc cả sân khấu để màu
/// rực kiểu fantasy mà không phải đổi từng màu một.
ColorFilter saturationFilter(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  return ColorFilter.matrix([
    r * (1 - s) + s, g * (1 - s), b * (1 - s), 0, 0, //
    r * (1 - s), g * (1 - s) + s, b * (1 - s), 0, 0,
    r * (1 - s), g * (1 - s), b * (1 - s) + s, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}

/// Viên thuốc thon dần từ [a] (bán kính [ra]) tới [b] (bán kính [rb]),
/// một đường viền liền (không tự chồng), cùng chiều với mọi viên khác nên
/// gộp nhiều viên vào một Path vẫn tô kín.
Path capsulePath(Offset a, Offset b, double ra, double rb) {
  var d = b - a;
  if (d.distance < 0.01) d = const Offset(0.01, 0);
  final len = d.distance;
  final n = Offset(-d.dy, d.dx) / len;
  return Path()
    ..moveTo(a.dx + n.dx * ra, a.dy + n.dy * ra)
    ..lineTo(b.dx + n.dx * rb, b.dy + n.dy * rb)
    ..arcToPoint(
      b - n * rb,
      radius: Radius.circular(rb),
      largeArc: true,
      clockwise: false,
    )
    ..lineTo(a.dx - n.dx * ra, a.dy - n.dy * ra)
    ..arcToPoint(
      a + n * ra,
      radius: Radius.circular(ra),
      largeArc: true,
      clockwise: false,
    )
    ..close();
}

/// Nhiều viên thuốc (cánh tay, chân) thành một Path.
Path chainPath(
  List<(Offset, Offset, double, double)> parts, [
  double grow = 0,
]) {
  final path = Path();
  for (final (a, b, ra, rb) in parts) {
    path.addPath(capsulePath(a, b, ra + grow, rb + grow), Offset.zero);
  }
  return path;
}

/// Một điểm trên profile cơ của một đoạn chi: ở tỉ lệ [t] (0 = gốc, 1 =
/// ngọn), nửa bề rộng phía trước [front] và phía sau [back]. Phía trước là
/// bên phải hướng đi từ gốc tới ngọn (ví dụ bắp tay khi tay buông xuôi,
/// nhân vật quay phải).
typedef MuscleStop = (double t, double front, double back);

/// Đường bao một đoạn chi theo profile cơ (Loomis: chi không phải ống trụ —
/// cơ phồng lệch trước/sau, khớp thắt lại). Hai đầu bo tròn để nối liền với
/// đoạn kế. [grow] phình đều (làm viền), [scale] nhân bề rộng (béo/gầy).
Path musclePath(
  Offset a,
  Offset b,
  List<MuscleStop> profile, {
  double grow = 0,
  double scale = 1,
}) {
  var d = b - a;
  if (d.distance < 0.01) d = const Offset(0, 0.01);
  final dir = d / d.distance;
  // Phía trước = bên phải của hướng đi (toạ độ màn hình, y hướng xuống).
  final front = Offset(-dir.dy, dir.dx);
  Offset at(MuscleStop s, double side) {
    final w = (side > 0 ? s.$2 : s.$3) * scale + grow;
    return a + d * s.$1 + front * (side * w);
  }

  final fronts = [for (final s in profile) at(s, 1)];
  final backs = [for (final s in profile.reversed) at(s, -1)];
  final path = Path()..moveTo(fronts.first.dx, fronts.first.dy);
  void smooth(List<Offset> pts) {
    for (var i = 1; i < pts.length - 1; i++) {
      final mid = Offset.lerp(pts[i], pts[i + 1], 0.5)!;
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
  }

  smooth(fronts);
  // Bo đầu bằng cubic (≈ nửa hình tròn) đi vòng ra ngoài đầu đoạn, không
  // dùng arcToPoint: chiều cung dễ ngược, tạo lỗ khi các đoạn chồng nhau.
  void cap(Offset from, Offset to, Offset outward) {
    final r = (to - from).distance / 2;
    path.cubicTo(
      from.dx + outward.dx * r * 1.33,
      from.dy + outward.dy * r * 1.33,
      to.dx + outward.dx * r * 1.33,
      to.dy + outward.dy * r * 1.33,
      to.dx,
      to.dy,
    );
  }

  cap(fronts.last, backs.first, dir);
  smooth(backs);
  cap(backs.last, fronts.first, -dir);
  return path..close();
}

/// Chi nhiều đoạn có khối cơ: tô liền một mảng (đổ bóng 6 vùng), viền là bản
/// phình to nên chỗ nối khớp không lộ.
void shadedLimb(
  Canvas canvas,
  List<(Offset, Offset, List<MuscleStop>)> segments,
  Color base, {
  double scale = 1,
  double shadow = 3,
  double highlight = 1.4,
}) {
  final body = Path();
  final outline = Path();
  for (final (a, b, profile) in segments) {
    body.addPath(musclePath(a, b, profile, scale: scale), Offset.zero);
    outline.addPath(
      musclePath(a, b, profile, scale: scale, grow: VectorStyle.outlineWidth),
      Offset.zero,
    );
  }
  shadedPath(
    canvas,
    body,
    base,
    PartFrame.world,
    shadow: shadow,
    highlight: highlight,
    outlineShape: outline,
  );
}

/// Chuỗi đoạn liền (tay, chân): viền là bản phình to nên không lộ chỗ nối.
void shadedChain(
  Canvas canvas,
  List<(Offset, Offset, double, double)> parts,
  Color base, {
  double shadow = 3,
  double highlight = 1.4,
}) => shadedPath(
  canvas,
  chainPath(parts),
  base,
  PartFrame.world,
  shadow: shadow,
  highlight: highlight,
  outlineShape: chainPath(parts, VectorStyle.outlineWidth),
);

/// Kim loại vàng: gradient ánh kim.
Paint goldPaint(Rect bounds) => Paint()
  ..shader = Gradient.linear(
    bounds.topLeft,
    bounds.bottomRight,
    const [Color(0xFFFFF1A8), Color(0xFFE8B83A), Color(0xFFB07A14)],
    const [0, 0.45, 1],
  );

/// Chấm bóng loáng nhỏ (tóc, kim loại, má) để có cảm giác khối.
void glint(Canvas canvas, Offset at, double size, {double alpha = 0.75}) {
  canvas.drawOval(
    Rect.fromCenter(center: at, width: size * 1.6, height: size),
    fillPaint(const Color(0xFFFFFFFF).withValues(alpha: alpha)),
  );
}
