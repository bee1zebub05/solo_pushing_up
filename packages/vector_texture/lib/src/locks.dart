import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_anatomy/vector_anatomy.dart';

/// Một bộ lọn lông dựng xong: [mass] là khối chung (tô đổ bóng một lần),
/// [creases] rãnh tối dưới mỗi lọn (tách lọn này khỏi lọn kế), [strands]
/// sợi lông giữa lọn, [sheens] sợi sáng trên mép đón nắng. Ba path chi tiết
/// nên tô trong vùng cắt [mass].
class LockSet {
  LockSet(this.mass, this.creases, this.strands, this.sheens, this.lines);

  final Path mass;
  final Path creases;
  final Path strands;
  final Path sheens;

  /// Đường giữa và bề rộng từng lọn (để vẽ thêm chi tiết riêng).
  final List<(List<Offset>, double)> lines;
}

/// Đường giữa một lọn: mọc từ tâm theo góc [angle] (radian, 0 = +x), bắt đầu
/// cách tâm [r0], dài [length]; càng xa gốc càng bị kéo theo [drift] (ví dụ
/// ra sau và rủ xuống), lượn chữ S biên độ [wave].
List<Offset> lockLine(
  double angle,
  double r0,
  double length, {
  double wave = 0,
  Offset drift = const Offset(0.22, 0.22),
  int steps = 5,
}) {
  var dir = Offset(math.cos(angle), math.sin(angle));
  var p = dir * r0;
  final pts = [p];
  for (var k = 1; k <= steps; k++) {
    final u = k / steps;
    // Lực kéo tăng dần dọc lọn (gốc cứng, ngọn mềm).
    dir += Offset(drift.dx, drift.dy * (0.55 + 0.9 * u));
    dir = dir / dir.distance;
    final n = Offset(-dir.dy, dir.dx);
    p += dir * (length / steps);
    pts.add(p + n * (math.sin(u * math.pi * 1.6) * wave));
  }
  return pts;
}

/// Dựng [count] lọn quanh [center] trong cung góc [from] → [to].
///
/// [lengthAt] cho hệ số dài theo góc (ví dụ bờm: đỉnh đầu ngắn, ngực dài);
/// độ dài/bề rộng từng lọn dao động ±18 % / ±15 % theo [rnd].
LockSet buildLocks({
  required Offset center,
  required math.Random rnd,
  required double r0,
  required double length,
  required double width,
  required int count,
  required double from,
  required double to,
  double Function(double angle)? lengthAt,
  Offset drift = const Offset(0.22, 0.22),
  double wave = 5,
}) {
  final mass = Path();
  final creases = Path();
  final strands = Path();
  final sheens = Path();
  final lines = <(List<Offset>, double)>[];
  for (var i = 0; i < count; i++) {
    final a = from + (to - from) * (i + rnd.nextDouble() * 0.4) / count;
    final l =
        length * (lengthAt?.call(a) ?? 1) * (0.82 + rnd.nextDouble() * 0.36);
    final w = width * (0.85 + rnd.nextDouble() * 0.3);
    final line = [
      for (final p in lockLine(
        a,
        r0,
        l,
        wave: (rnd.nextDouble() - 0.5) * wave,
        drift: drift,
      ))
        p + center,
    ];
    lines.add((line, w));
    mass.addPath(
      taperedStroke(line, w, peak: 0.3, startWidth: 0.7, samples: 14),
      Offset.zero,
    );
    List<Offset> shifted(double k) => offsetLine(line, k, taper: 0.6);
    creases.addPath(
      taperedStroke(shifted(w * 0.42), w * 0.32, samples: 10),
      Offset.zero,
    );
    strands.addPath(
      taperedStroke(shifted(w * 0.05), w * 0.12, samples: 10),
      Offset.zero,
    );
    sheens.addPath(
      taperedStroke(shifted(-w * 0.25).sublist(0, 5), w * 0.16, samples: 8),
      Offset.zero,
    );
  }
  return LockSet(mass, creases, strands, sheens, lines);
}

/// Dời từng điểm của [line] theo pháp tuyến một khoảng [k] (dương = bên
/// phải theo chiều đi), khoảng dời giảm dần về ngọn theo [taper] (0..1).
List<Offset> offsetLine(List<Offset> line, double k, {double taper = 0}) {
  final out = <Offset>[];
  for (var j = 0; j < line.length; j++) {
    final d = line[math.min(line.length - 1, j + 1)] - line[math.max(0, j - 1)];
    final len = d.distance;
    final n = len == 0 ? Offset.zero : Offset(-d.dy, d.dx) / len;
    out.add(line[j] + n * (k * (1 - j / line.length * taper)));
  }
  return out;
}
