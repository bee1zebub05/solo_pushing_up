import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_anatomy/vector_anatomy.dart';

/// Lông vũ xếp ngói trong [area], ngọn chĩa theo [tipDir] (mặc định xuống):
/// mỗi lông một mép chữ V tối ([dark]) và một sống lông sáng ([lit]).
/// Hàng sau so le nửa bước. Tô trong vùng cắt của khối thân/cánh.
({Path dark, Path lit}) featherRows(
  Rect area, {
  double size = 5,
  Offset tipDir = const Offset(0, 1),
  math.Random? rnd,
}) {
  final dark = Path();
  final lit = Path();
  final dir = tipDir / tipDir.distance;
  final side = Offset(-dir.dy, dir.dx);
  final stepX = size * 0.72;
  final stepY = size;
  var row = 0;
  for (var y = area.top; y <= area.bottom; y += stepY, row++) {
    for (
      var x = area.left + (row.isOdd ? stepX / 2 : 0);
      x <= area.right;
      x += stepX
    ) {
      final j = rnd == null ? 0.0 : (rnd.nextDouble() - 0.5) * size * 0.15;
      final top = Offset(x + j, y);
      final tip = top + dir * size - side * (size * 0.12);
      dark.addPath(
        taperedStroke(
          [
            top - side * (size * 0.32) + dir * (size * 0.12),
            tip + dir * (size * 0.08),
            top + side * (size * 0.36) + dir * (size * 0.08),
          ],
          size * 0.2,
          peak: 0.5,
        ),
        Offset.zero,
      );
      lit.addPath(
        taperedStroke([
          top + dir * (size * 0.12),
          tip - dir * (size * 0.24),
        ], size * 0.14),
        Offset.zero,
      );
    }
  }
  return (dark: dark, lit: lit);
}

/// Khoảng cách tối thiểu dùng nội bộ để tránh chia cho 0.
const double _eps = 1e-6;

/// Hướng đơn vị an toàn.
Offset unitOr(Offset v, Offset fallback) {
  final d = v.distance;
  return d < _eps ? fallback : v / d;
}

/// Góc (radian) của một hướng, tiện cho [lockLine].
double angleOf(Offset v) => math.atan2(v.dy, v.dx);
