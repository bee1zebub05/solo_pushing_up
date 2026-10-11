import 'dart:math' as math;
import 'dart:ui';

import 'limb.dart';

/// Tư thế bàn tay.
enum HandPose {
  /// Xoè, lòng bàn tay hướng ra trước (ra hiệu, nói chuyện).
  open,

  /// Chỉ: ngón trỏ duỗi, các ngón còn lại co.
  point,

  /// Nắm chặt (đấm, cầm chuỳ).
  fist,

  /// Bao quanh một cán tròn nằm ngang trục tay (cầm chuỳ, cầm giáo).
  grip,

  /// Úp phẳng nhìn ngang (chống đẩy, chống tay xuống đất): các ngón duỗi
  /// thẳng chồng lên nhau, ngón cái nằm dọc mép lòng bàn tay.
  flat,
}

/// Hình học một bàn tay: mỗi phần một Path để tô riêng (lòng bàn tay, từng
/// ngón theo thứ tự xa → gần), cùng các nếp đốt ngón (nét mảnh).
class HandShape {
  const HandShape(this.palm, this.fingers, this.thumb, this.creases);

  final Path palm;

  /// Bốn ngón (út → trỏ, vẽ theo thứ tự này để ngón trỏ nằm trên cùng).
  final List<Path> fingers;
  final Path thumb;

  /// Nếp đốt ngón / khớp, dạng điểm đầu-cuối để vẽ nét mảnh.
  final List<(Offset, Offset)> creases;
}

/// Dựng bàn tay tại cổ tay [wrist], trục tay hướng [dir] (từ khuỷu tới cổ
/// tay). [facing] như [LimbFrame]: phía ngón cái là phía trước.
///
/// Tỉ lệ (Loomis): bàn tay dài ≈ mặt (cằm → chân tóc); lòng bàn tay ≈ ngón
/// giữa; ngón giữa dài nhất, ngón út ngắn nhất; khớp đốt ngón xếp theo một
/// cung (không thẳng hàng). Kích thước theo [scale] (1 = cỡ người thường,
/// lòng bàn tay dài ~9).
HandShape buildHand(
  Offset wrist,
  Offset dir, {
  HandPose pose = HandPose.open,
  Offset facing = const Offset(1, 0),
  double scale = 1,
}) {
  final f = LimbFrame(wrist, wrist + dir, facing: facing);
  final u = f.dir; // dọc tay
  final n = f.anterior; // phía ngón cái
  Offset at(double along, double side) =>
      wrist + u * (along * scale) + n * (side * scale);

  // Lòng bàn tay: hình thang bo, rộng ở đốt ngón, có ụ cơ ngón cái.
  const palmLen = 9.0;
  final palmPts = [
    at(0, 3.2),
    at(3.5, 4.6), // ụ ngón cái
    at(palmLen, 4.4),
    at(palmLen + 0.6, 0.6),
    at(palmLen, -3.8),
    at(palmLen * 0.5, -4.2),
    at(0, -3.0),
  ];
  final palm = Path()..addPolygon(palmPts, true);
  _roundPolygon(palm, palmPts);

  // Đốt ngón (gốc ngón) theo cung: trỏ, giữa, nhẫn, út.
  const knuckles = [
    (palmLen + 0.4, 3.1),
    (palmLen + 1.0, 1.0),
    (palmLen + 0.6, -1.1),
    (palmLen - 0.2, -3.0),
  ];
  const lengths = [6.8, 7.6, 7.0, 5.6]; // trỏ, giữa, nhẫn, út
  const widths = [1.6, 1.7, 1.6, 1.35];

  final fingers = <Path>[];
  final creases = <(Offset, Offset)>[];
  for (var i = 3; i >= 0; i--) {
    final (ka, ks0) = knuckles[i];
    // Úp phẳng nhìn ngang: các ngón chồng lên nhau (bề ngang bị ép dẹt).
    final ks = pose == HandPose.flat ? ks0 * 0.3 : ks0;
    final base = at(ka, ks);
    final len = lengths[i];
    final w = widths[i] * scale;
    final curled = switch (pose) {
      HandPose.open || HandPose.flat => false,
      HandPose.point => i != 0,
      HandPose.fist || HandPose.grip => true,
    };
    final sign = _bendSign(u, n);
    final pts = <Offset>[base];
    if (!curled) {
      // Duỗi, hơi cong tự nhiên; xoè như nan quạt khi mở.
      final splay = pose == HandPose.open ? (1.5 - i) * 0.12 : 0.0;
      final relax = pose == HandPose.flat ? 0.0 : 0.12;
      var d = _rotate(u, splay);
      var p = base;
      for (final seg in const [0.45, 0.32, 0.23]) {
        d = _rotate(d, -relax * sign);
        p = p + d * (len * seg * scale);
        pts.add(p);
      }
    } else {
      // Nhìn ngang nắm tay: chỉ thấy đốt gần đi tới khớp, rồi đốt giữa gập
      // gần vuông góc về phía ngón cái (đầu ngón khuất trong lòng bàn tay) —
      // hàng đốt ngón thành một mặt phẳng vuông vức. Cầm cán: gập vừa phải
      // để chừa chỗ cho cán.
      final fold = pose == HandPose.grip ? 1.35 : 1.6;
      final p1 = base + u * (len * 0.4 * scale);
      final p2 = p1 + _rotate(u, fold * sign) * (len * 0.32 * scale);
      pts
        ..add(p1)
        ..add(p2);
    }
    fingers.add(_capsuleChain(pts, w));
    if (pose == HandPose.open || (pose == HandPose.point && i == 0)) {
      for (var k = 1; k < pts.length - 1; k++) {
        final tg = pts[k + 1] - pts[k - 1];
        final nn = Offset(-tg.dy, tg.dx) / math.max(tg.distance, 1e-3);
        creases.add((pts[k] + nn * w * 0.55, pts[k] - nn * w * 0.55));
      }
    }
  }

  // Ngón cái: mọc từ ụ cơ, hai đốt ngắn. Mở: chĩa chéo ra trước; nắm:
  // nằm vắt ngang trước các đốt ngón giữa.
  final sign = _bendSign(u, n);
  final tBase = at(3.0, 3.6);
  final (Offset d1, Offset d2, double l1, double l2) = switch (pose) {
    HandPose.flat => (
      _rotate(u, 0.15 * sign),
      _rotate(u, 0.05 * sign),
      3.6,
      2.8,
    ),
    HandPose.open => (
      _rotate(u, 0.55 * sign),
      _rotate(u, 0.3 * sign),
      3.6,
      2.8,
    ),
    HandPose.grip => (
      _rotate(u, 0.35 * sign),
      _rotate(u, 1.1 * sign),
      3.4,
      2.6,
    ),
    HandPose.point ||
    HandPose.fist => (_rotate(u, 0.2 * sign), _rotate(u, 1.5 * sign), 3.6, 3.0),
  };
  final t1 = tBase + d1 * (l1 * scale);
  final t2 = t1 + d2 * (l2 * scale);
  final thumb = _capsuleChain([tBase, t1, t2], 1.8 * scale);
  return HandShape(palm, fingers, thumb, creases);
}

/// Dấu xoay để "co về phía lòng bàn tay" nhất quán bất kể hướng chi.
double _bendSign(Offset u, Offset n) =>
    (u.dx * n.dy - u.dy * n.dx) >= 0 ? 1 : -1;

Offset _rotate(Offset v, double a) => Offset(
  v.dx * math.cos(a) - v.dy * math.sin(a),
  v.dx * math.sin(a) + v.dy * math.cos(a),
);

/// Chuỗi đốt ngón thon nhẹ về đầu ngón, hai đầu bo tròn.
Path _capsuleChain(List<Offset> pts, double w) {
  final path = Path();
  for (var i = 0; i < pts.length - 1; i++) {
    final a = pts[i], b = pts[i + 1];
    final ra = w * (1 - i * 0.08), rb = w * (1 - (i + 1) * 0.08);
    var d = b - a;
    if (d.distance < 1e-3) d = const Offset(0, 1e-3);
    final n = Offset(-d.dy, d.dx) / d.distance;
    path
      ..moveTo(a.dx + n.dx * ra, a.dy + n.dy * ra)
      ..lineTo(b.dx + n.dx * rb, b.dy + n.dy * rb)
      ..arcToPoint(b - n * rb, radius: Radius.circular(rb), clockwise: false)
      ..lineTo(a.dx - n.dx * ra, a.dy - n.dy * ra)
      ..arcToPoint(a + n * ra, radius: Radius.circular(ra), clockwise: false)
      ..close();
  }
  return path;
}

void _roundPolygon(Path path, List<Offset> pts) {
  path.reset();
  final n = pts.length;
  final m0 = Offset.lerp(pts[n - 1], pts[0], 0.5)!;
  path.moveTo(m0.dx, m0.dy);
  for (var i = 0; i < n; i++) {
    final p = pts[i];
    final m = Offset.lerp(p, pts[(i + 1) % n], 0.5)!;
    path.quadraticBezierTo(p.dx, p.dy, m.dx, m.dy);
  }
  path.close();
}
