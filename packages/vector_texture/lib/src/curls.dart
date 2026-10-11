import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_anatomy/vector_anatomy.dart';

/// Lọn tóc xoăn xếp hàng so le trong [area]: mỗi lọn một nét xoắn tối gần
/// kín vòng ([dark]) và một nét sáng ngắn phía đón nắng ([lit]). Tô trong
/// vùng cắt của khối tóc.
({Path dark, Path lit}) curlRows(
  Rect area, {
  required double radius,
  required math.Random rnd,
  double spacingX = 2,
  double spacingY = 1.9,
  double darkWidth = 1.1,
  double litWidth = 0.75,
}) {
  final dark = Path();
  final lit = Path();
  final stepX = radius * spacingX;
  final stepY = radius * spacingY;
  var row = 0;
  for (var y = area.top; y <= area.bottom; y += stepY, row++) {
    for (
      var x = area.left + (row.isOdd ? stepX / 2 : 0);
      x <= area.right;
      x += stepX
    ) {
      final p = Offset(
        x + rnd.nextDouble() * radius * 0.35,
        y + rnd.nextDouble() * radius * 0.35,
      );
      final a0 = 0.5 + rnd.nextDouble() * 0.7;
      final r = radius * (0.85 + rnd.nextDouble() * 0.3);
      List<Offset> arc(double from, double sweep, double rr) => [
        for (var k = 0; k <= 4; k++)
          p +
              Offset(
                math.cos(from + sweep * k / 4) * rr,
                math.sin(from + sweep * k / 4) * rr,
              ),
      ];
      dark.addPath(
        taperedStroke(arc(a0, 3.8, r), darkWidth, samples: 8),
        Offset.zero,
      );
      lit.addPath(
        taperedStroke(arc(a0 + 3.5, 1.7, r * 0.82), litWidth, samples: 6),
        Offset.zero,
      );
    }
  }
  return (dark: dark, lit: lit);
}
