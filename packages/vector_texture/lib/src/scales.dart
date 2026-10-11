import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_anatomy/vector_anatomy.dart';

import 'locks.dart';

/// Thân rắn/rồng dọc một đường cong, chia vai trò ánh sáng:
/// [body] khối thân (tô đổ bóng), [scaleDark] mép vảy chữ U, [scaleLit]
/// vệt sáng trên vảy, [spine] dải sống lưng, [belly] dải vảy bụng, [plates]
/// vạch chia đốt vảy bụng. Chi tiết tô trong vùng cắt [body].
class ScaleBody {
  ScaleBody(
    this.body,
    this.scaleDark,
    this.scaleLit,
    this.spine,
    this.belly,
    this.plates,
  );

  final Path body;
  final Path scaleDark;
  final Path scaleLit;
  final Path spine;
  final Path belly;
  final Path plates;
}

/// Bề rộng tương đối của nét thon tại t (khớp `taperedStroke`).
double taperProfile(
  double t, {
  double peak = 0.35,
  double startWidth = 0.08,
  double endWidth = 0,
}) {
  if (t <= peak && peak > 0) {
    return startWidth + (1 - startWidth) * math.sin(t / peak * math.pi / 2);
  }
  return endWidth +
      (1 - endWidth) * math.cos((t - peak) / (1 - peak) * math.pi / 2);
}

/// Dựng thân có vảy dọc [pts] (đường giữa), rộng tối đa [width].
///
/// Bụng là phía pháp tuyến hướng xuống (+y màn hình); thân uốn chữ S (cổ
/// rồng) đặt [bellySide] = +1/-1 để cố định bụng ở một phía pháp tuyến dọc
/// cả thân. [rows] hàng vảy mỗi bên đường giữa; [samples] số mẫu dọc thân.
ScaleBody buildScaleBody(
  List<Offset> pts,
  double width, {
  double peak = 0.35,
  double startWidth = 0.75,
  double endWidth = 0.12,
  bool belly = true,
  int samples = 60,
  int rows = 2,
  double? bellySide,
}) {
  final body = taperedStroke(
    pts,
    width,
    peak: peak,
    startWidth: startWidth,
    endWidth: endWidth,
    samples: 40,
  );
  double half(double t) =>
      width *
      taperProfile(t, peak: peak, startWidth: startWidth, endWidth: endWidth) /
      2;
  final line = sampleSmooth(pts, samples);
  Offset normalAt(int i) {
    final d = line[math.min(line.length - 1, i + 1)] - line[math.max(0, i - 1)];
    final len = d.distance;
    return len == 0 ? const Offset(0, 1) : Offset(-d.dy, d.dx) / len;
  }

  // Phía bụng: cố định theo [bellySide] nếu có, không thì phía hướng xuống.
  Offset downAt(int i) {
    final n = normalAt(i);
    if (bellySide != null) return n * bellySide.sign;
    return n.dy >= 0 ? n : -n;
  }

  final scaleDark = Path();
  final scaleLit = Path();
  for (var i = 1; i < line.length - 1; i++) {
    final t = i / (line.length - 1);
    final d = line[i + 1] - line[i - 1];
    final dir = d / d.distance;
    final n = normalAt(i);
    final down = downAt(i);
    final h = half(t);
    for (var row = -rows; row <= rows; row++) {
      if (i.isOdd == row.isEven) continue;
      final k = row / (rows + 0.6);
      // Phía bụng đã có dải vảy bụng riêng.
      if (belly && k > 0.35 && down == n) continue;
      if (belly && k < -0.35 && down == -n) continue;
      final c = line[i] + n * (h * k);
      final r = math.max(1.2, h * 0.24);
      final a0 = math.atan2(dir.dy, dir.dx) - math.pi / 2;
      scaleDark.addArc(Rect.fromCircle(center: c, radius: r), a0, math.pi);
      scaleLit.addArc(
        Rect.fromCircle(center: c - dir * 0.6 - down * 0.6, radius: r * 0.7),
        a0 + 0.3,
        math.pi * 0.6,
      );
    }
  }
  // Sống lưng: dải thon sát mép trên.
  final spineLine = [
    for (var i = 0; i < line.length; i++)
      () {
        final up = -downAt(i);
        return line[i] + up * (half(i / (line.length - 1)) * 0.62);
      }(),
  ];
  final spine = taperedStroke(
    spineLine,
    width * 0.22,
    peak: peak,
    startWidth: 0.6,
    endWidth: 0.1,
  );
  final bellyPath = Path();
  final plates = Path();
  if (belly) {
    final under = <Offset>[];
    final halves = <double>[];
    for (var i = 0; i < line.length; i++) {
      final down = downAt(i);
      final h = half(i / (line.length - 1));
      under.add(line[i] + down * (h * 0.72));
      halves.add(h);
    }
    bellyPath.addPath(
      taperedStroke(
        under,
        width * 0.42,
        peak: peak,
        startWidth: 0.7,
        endWidth: 0.1,
        samples: 40,
      ),
      Offset.zero,
    );
    for (var i = 2; i < under.length - 6; i += 2) {
      final d = under[i + 1] - under[i - 1];
      final n = Offset(-d.dy, d.dx) / d.distance;
      final hh = halves[i] * 0.42;
      plates
        ..moveTo((under[i] - n * hh).dx, (under[i] - n * hh).dy)
        ..lineTo((under[i] + n * hh).dx, (under[i] + n * hh).dy);
    }
  }
  return ScaleBody(body, scaleDark, scaleLit, spine, bellyPath, plates);
}

/// Dải song song với đường giữa [pts] lệch [k] lần nửa bề rộng (dải bụng /
/// sống lưng cho cổ rắn vẽ mỗi khung).
List<Offset> sideLine(List<Offset> pts, double halfWidth, double k) =>
    offsetLine(pts, halfWidth * k);
