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
  static const outlineWidth = 1.8;

  /// Hướng tới nguồn sáng (toạ độ màn hình): trên, lệch trái.
  static const lightWorld = Offset(-0.55, -0.83);
}

Color darken(Color c, [double amount = 0.22]) =>
    Color.lerp(c, const Color(0xFF000000), amount)!;

Color lighten(Color c, [double amount = 0.3]) =>
    Color.lerp(c, const Color(0xFFFFFFFF), amount)!;

/// Màu bóng: tối hơn và ngả ấm/tím một chút cho có hồn (thay vì chỉ xám).
Color shadeOf(Color c) =>
    Color.lerp(darken(c, 0.2), const Color(0xFF5A2E4A), 0.12)!;

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
    canvas.drawPaint(fillPaint(lighten(base, 0.25)));
    canvas.clipPath(path.shift(light * -highlight));
  }
  if (shadow > 0) {
    canvas.drawPaint(fillPaint(shadeOf(base)));
    canvas.drawPath(path.shift(light * shadow), fillPaint(base));
  } else {
    canvas.drawPaint(fillPaint(base));
  }
  canvas.restore();
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
