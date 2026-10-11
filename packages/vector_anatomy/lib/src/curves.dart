import 'dart:math' as math;
import 'dart:ui';

/// Đường cong mượt qua mọi điểm (Catmull-Rom → Bézier bậc ba). Khác nối
/// cong bậc hai qua điểm giữa: đi đúng qua điểm, độ cong thay đổi liên tục
/// nên hình hữu cơ hơn. [tension] 0 = tròn đầy, 1 = gần đường gấp khúc.
///
/// Nếu [path] được truyền, nối tiếp vào đó (không moveTo điểm đầu).
Path smoothPath(
  List<Offset> pts, {
  bool closed = false,
  double tension = 0,
  Path? path,
}) {
  final out = path ?? Path();
  if (pts.isEmpty) return out;
  if (path == null) out.moveTo(pts.first.dx, pts.first.dy);
  if (pts.length == 1) return out;
  final n = pts.length;
  Offset p(int i) {
    if (closed) return pts[(i % n + n) % n];
    return pts[i.clamp(0, n - 1)];
  }

  final k = (1 - tension) / 6;
  final last = closed ? n : n - 1;
  for (var i = 0; i < last; i++) {
    final p0 = p(i - 1), p1 = p(i), p2 = p(i + 1), p3 = p(i + 2);
    final c1 = p1 + (p2 - p0) * k;
    final c2 = p2 - (p3 - p1) * k;
    out.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  if (closed) out.close();
  return out;
}

/// Lấy mẫu đều [count] điểm trên đường Catmull-Rom qua [pts] (mở).
List<Offset> sampleSmooth(List<Offset> pts, int count) {
  if (pts.length < 2) return List.of(pts);
  final n = pts.length;
  Offset p(int i) => pts[i.clamp(0, n - 1)];
  final out = <Offset>[];
  for (var j = 0; j < count; j++) {
    final u = j / (count - 1) * (n - 1);
    final i = math.min(u.floor(), n - 2);
    final t = u - i;
    final p0 = p(i - 1), p1 = p(i), p2 = p(i + 1), p3 = p(i + 2);
    final t2 = t * t, t3 = t2 * t;
    out.add(
      (p1 * 2 +
              (p2 - p0) * t +
              (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 +
              (p1 * 3 - p0 - p2 * 3 + p3) * t3) *
          0.5,
    );
  }
  return out;
}

/// Nét mực thon hai đầu dọc theo các điểm [pts]: dày nhất ở [peak] (0–1 dọc
/// nét), mảnh dần về hai đầu — như nét bút lông, khác nét đều của bút bi.
/// Trả về một Path kín để tô (fill), không phải stroke.
Path taperedStroke(
  List<Offset> pts,
  double width, {
  double peak = 0.45,
  double startWidth = 0.08,
  double endWidth = 0.0,
  int samples = 18,
}) {
  final path = Path();
  if (pts.length < 2 || width <= 0) return path;
  final line = sampleSmooth(pts, samples);
  final left = <Offset>[], right = <Offset>[];
  for (var i = 0; i < line.length; i++) {
    final t = i / (line.length - 1);
    final prev = line[math.max(0, i - 1)];
    final next = line[math.min(line.length - 1, i + 1)];
    var d = next - prev;
    if (d.distance < 1e-6) d = const Offset(1, 0);
    final nrm = Offset(-d.dy, d.dx) / d.distance;
    // Bề rộng: dốc lên tới peak rồi xuống, dạng sin cho mượt.
    final double f;
    if (t <= peak) {
      f = startWidth + (1 - startWidth) * math.sin(t / peak * math.pi / 2);
    } else {
      f =
          endWidth +
          (1 - endWidth) * math.cos((t - peak) / (1 - peak) * math.pi / 2);
    }
    final w = width * f / 2;
    left.add(line[i] + nrm * w);
    right.add(line[i] - nrm * w);
  }
  path.moveTo(left.first.dx, left.first.dy);
  for (final q in left.skip(1)) {
    path.lineTo(q.dx, q.dy);
  }
  for (final q in right.reversed) {
    path.lineTo(q.dx, q.dy);
  }
  return path..close();
}
