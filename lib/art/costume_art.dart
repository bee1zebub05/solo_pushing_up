import 'dart:math' as math;
import 'dart:ui';

import 'vector_style.dart';

/// Trang phục và phụ kiện dùng chung (nhân vật, Hercules): dép Hy Lạp buộc
/// dây lên ống chân, vòng tay vàng ôm theo khối chi, thắt lưng da có khoá.
abstract final class CostumeColors {
  static const leather = Color(0xFF7A5232);
  static const leatherDark = Color(0xFF4E3220);
  static const sole = Color(0xFF3E2A1C);
  static const gold = Color(0xFFE8B83A);
}

// Mẫu bàn chân nhìn ngang, quay phải (X tới trước, Y xuống), gốc ở cổ chân,
// cỡ người thường: chân dài ~13, cổ chân cao ~6 so với đất.
const _templateToe = Offset(10.5, 5.6);
const _footOutline = [
  Offset(-2.6, -2.0), // sau cổ chân
  Offset(-3.7, 2.4), // gót
  Offset(-3.1, 5.8),
  Offset(2.0, 5.3), // vòm bàn chân
  Offset(7.6, 6.0), // ụ ngón
  Offset(11.2, 5.6), // đầu ngón
  Offset(10.7, 3.7),
  Offset(5.2, 1.7), // mu bàn chân
  Offset(1.6, -1.4), // trước cổ chân
];

/// Dép Hy Lạp (krepis): đế da dày, quai ngang ngón, quai chéo mu bàn chân,
/// quai gót, rồi dây buộc chéo lên ống chân tới khoảng [lace] (0–1 chiều dài
/// ống chân) kết thúc bằng nút và tua.
///
/// [ankle], [knee]: khớp chân. [toe]: mũi chân; null = đứng trên mặt đất
/// (suy từ mẫu). [facingRight]: hướng bàn chân. [scale]: 1 = người thường.
void paintGreekSandal(
  Canvas canvas, {
  required Offset knee,
  required Offset ankle,
  Offset? toe,
  required bool facingRight,
  required Color skin,
  double scale = 1,
  double lace = 0.42,
  MuscleProfile shin = HumanAnatomy.shin,
  bool far = false,
}) {
  final mirror = facingRight ? 1.0 : -1.0;
  final template = Offset(_templateToe.dx * mirror, _templateToe.dy);
  final target = (toe ?? ankle + template * scale) - ankle;
  final k = target.distance / _templateToe.distance;
  final rot =
      math.atan2(target.dy, target.dx) - math.atan2(template.dy, template.dx);
  Offset map(Offset p) {
    final q = Offset(p.dx * mirror, p.dy) * k;
    return ankle +
        Offset(
          q.dx * math.cos(rot) - q.dy * math.sin(rot),
          q.dx * math.sin(rot) + q.dy * math.cos(rot),
        );
  }

  final leather = far
      ? darken(CostumeColors.leather, 0.2)
      : CostumeColors.leather;
  final footSkin = far ? darken(skin, 0.18) : skin;

  // Đế: dày, mép sáng hơn, nhô nhẹ ra trước ngón chân.
  final sole = smoothPath(
    [
      map(const Offset(-3.9, 5.5)),
      map(const Offset(4.0, 5.3)),
      map(const Offset(11.9, 5.5)),
      map(const Offset(11.9, 7.2)),
      map(const Offset(4.0, 7.3)),
      map(const Offset(-3.7, 7.4)),
    ],
    closed: true,
    tension: 0.4,
  );
  shadedPath(
    canvas,
    sole,
    CostumeColors.sole,
    PartFrame.world,
    shadow: 1.2,
    outlineWidth: 1,
  );
  canvas.drawPath(
    Path()
      ..moveTo(map(const Offset(-3.6, 6.0)).dx, map(const Offset(-3.6, 6.0)).dy)
      ..lineTo(
        map(const Offset(11.6, 6.0)).dx,
        map(const Offset(11.6, 6.0)).dy,
      ),
    Paint()
      ..color = const Color(0x55E8C9A0)
      ..strokeWidth = 0.6 * k,
  );

  // Bàn chân.
  final foot = smoothPath(
    [for (final p in _footOutline) map(p)],
    closed: true,
    tension: 0.2,
  );
  shadedPath(
    canvas,
    foot,
    footSkin,
    PartFrame.world,
    shadow: 1.8,
    highlight: 0.8,
    outlineWidth: 1.1,
  );
  // Kẽ ngón chân + móng ngón cái.
  final toeLine = Paint()
    ..color = darken(footSkin, 0.32)
    ..strokeWidth = 0.6 * k
    ..strokeCap = StrokeCap.round;
  for (final x in [9.2, 10.2]) {
    canvas.drawLine(map(Offset(x, 4.4)), map(Offset(x + 0.4, 5.6)), toeLine);
  }
  canvas.drawLine(
    map(const Offset(10.6, 4.2)),
    map(const Offset(11.2, 4.9)),
    Paint()
      ..color = lighten(footSkin, 0.35)
      ..strokeWidth = 0.9 * k
      ..strokeCap = StrokeCap.round,
  );

  // Quai trên bàn chân: dải da có viền, bám theo khối bàn chân.
  void strap(Offset a, Offset b, double w) {
    final pa = map(a), pb = map(b);
    final band = taperedStroke(
      [pa, Offset.lerp(pa, pb, 0.5)!, pb],
      w * k,
      peak: 0.5,
      startWidth: 0.85,
      endWidth: 0.85,
    );
    canvas.drawPath(band, Paint()..color = CostumeColors.leatherDark);
    canvas.drawPath(
      band.shift(-VectorStyle.lightWorld * -0.25 * k),
      Paint()..color = leather,
    );
  }

  strap(const Offset(8.4, 2.8), const Offset(8.8, 5.8), 1.5); // ngang ngón
  strap(const Offset(4.6, 1.2), const Offset(6.0, 5.6), 1.6); // mu chân
  strap(const Offset(-3.3, 1.0), const Offset(1.6, 0.0), 1.5); // gót
  strap(const Offset(-2.7, -1.2), const Offset(1.9, -0.7), 1.7); // cổ chân

  // Dây buộc chéo lên ống chân (theo khối cơ: rộng ở bắp chân).
  final f = LimbFrame(knee, ankle, facing: Offset(mirror, 0));
  final s = scale;
  final rungs = 4;
  for (var i = 0; i < rungs; i++) {
    final t0 = 1 - lace * i / rungs;
    final t1 = 1 - lace * (i + 1) / rungs;
    final w0 = shin.halfWidthAt(t0) * s;
    final w1 = shin.halfWidthAt(t1) * s;
    // Một chữ X mỗi nấc: hai dây chéo nhau trên mặt trước ống chân.
    for (final dir in [1.0, -1.0]) {
      final a = f.at(t0, dir * w0 * 0.92);
      final b = f.at(t1, -dir * w1 * 0.92);
      final band = taperedStroke(
        [a, Offset.lerp(a, b, 0.5)!, b],
        1.25 * s,
        peak: 0.5,
        startWidth: 0.6,
        endWidth: 0.6,
      );
      canvas.drawPath(
        band,
        Paint()..color = dir > 0 ? leather : CostumeColors.leatherDark,
      );
    }
  }
  // Nút buộc + tua ở đỉnh dây.
  final top = f.at(1 - lace, shin.sideOffset(1 - lace, 0.75) * s);
  canvas.drawCircle(top, 1.4 * s, Paint()..color = CostumeColors.leatherDark);
  canvas.drawCircle(top, 1.0 * s, Paint()..color = leather);
  final tassel = Paint()
    ..color = CostumeColors.leatherDark
    ..strokeWidth = 0.7 * s
    ..strokeCap = StrokeCap.round;
  for (final dx in [-0.6, 0.6]) {
    canvas.drawLine(
      top,
      top + Offset(dx * s + mirror * 0.8 * s, 3.2 * s),
      tassel,
    );
  }
}

/// Vòng kim loại ôm quanh chi từ [t0] tới [t1] (tỉ lệ dọc đoạn [a]→[b]):
/// mép cong theo hình trụ (cong về phía ngọn chi), ánh kim, mép dưới tối,
/// chấm loá. Dùng cho vòng tay, vòng bắp tay.
void paintLimbBand(
  Canvas canvas,
  Offset a,
  Offset b,
  MuscleProfile profile, {
  required double t0,
  required double t1,
  double scale = 1,
  Offset facing = const Offset(1, 0),
  Color metal = CostumeColors.gold,
}) {
  final f = LimbFrame(a, b, facing: facing);
  Path edge(double t, double bulge) {
    final wa = MuscleProfile.widthAt(profile.anterior, t) * scale * 1.06;
    final wp = MuscleProfile.widthAt(profile.posterior, t) * scale * 1.06;
    return Path()
      ..moveTo(f.at(t, wa).dx, f.at(t, wa).dy)
      ..quadraticBezierTo(
        f.at(t + bulge, 0).dx,
        f.at(t + bulge, 0).dy,
        f.at(t, -wp).dx,
        f.at(t, -wp).dy,
      );
  }

  final curve = 0.08;
  final top = edge(t0, curve);
  final bottom = edge(t1, curve);
  final m0 = top.computeMetrics().first;
  final m1 = bottom.computeMetrics().first;
  final pts = <Offset>[];
  for (var i = 0; i <= 8; i++) {
    pts.add(m0.getTangentForOffset(m0.length * i / 8)!.position);
  }
  for (var i = 8; i >= 0; i--) {
    pts.add(m1.getTangentForOffset(m1.length * i / 8)!.position);
  }
  final band = Path()..addPolygon(pts, true);
  canvas.drawPath(
    band,
    Paint()
      ..color = VectorStyle.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.drawPath(band, goldPaint(band.getBounds()));
  // Dải phản chiếu sắc giữa vòng + mép dưới tối (kim loại hình trụ).
  canvas.save();
  canvas.clipPath(band);
  canvas.drawPath(
    edge(t1, curve),
    Paint()
      ..color = darken(metal, 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (t1 - t0).abs() * f.length * 0.5,
  );
  canvas.drawPath(
    edge((t0 + t1) / 2 - 0.01, curve),
    Paint()
      ..color = const Color(0xCCFFF6D0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9,
  );
  canvas.restore();
  glint(
    canvas,
    f.at(
      (t0 + t1) / 2,
      MuscleProfile.widthAt(profile.anterior, t0) * scale * 0.5,
    ),
    1.6 * scale.clamp(1, 2),
  );
}

/// Thắt lưng da ngang hông từ [left] tới [right], dày [height], có khoá tròn
/// bằng vàng ở [buckleAt] (0–1 dọc thắt lưng).
void paintBelt(
  Canvas canvas,
  Offset left,
  Offset right, {
  double height = 5,
  double buckleAt = 0.45,
  double sag = 1.5,
}) {
  final mid = Offset.lerp(left, right, 0.5)! + Offset(0, sag);
  final up = Offset(0, -height / 2), down = Offset(0, height / 2);
  final belt = Path()
    ..moveTo((left + up).dx, (left + up).dy)
    ..quadraticBezierTo(
      (mid + up).dx,
      (mid + up).dy,
      (right + up).dx,
      (right + up).dy,
    )
    ..lineTo((right + down).dx, (right + down).dy)
    ..quadraticBezierTo(
      (mid + down).dx,
      (mid + down).dy,
      (left + down).dx,
      (left + down).dy,
    )
    ..close();
  shadedPath(
    canvas,
    belt,
    CostumeColors.leather,
    PartFrame.world,
    shadow: 1.6,
    outlineWidth: 1.1,
  );
  // Đường chỉ khâu chạy dọc thắt lưng.
  final stitch = Paint()
    ..color = const Color(0xAAE8C9A0)
    ..strokeWidth = 0.6;
  for (var i = 0; i < 18; i++) {
    final t = (i + 0.5) / 18;
    final p =
        Offset.lerp(left, right, t)! +
        Offset(0, sag * 4 * t * (1 - t) - height * 0.28);
    canvas.drawLine(p, p + const Offset(1.4, 0), stitch);
  }
  final c =
      Offset.lerp(left, right, buckleAt)! +
      Offset(0, sag * 4 * buckleAt * (1 - buckleAt));
  final r = height * 0.85;
  canvas.drawCircle(c, r + 1, Paint()..color = VectorStyle.outline);
  canvas.drawCircle(c, r, goldPaint(Rect.fromCircle(center: c, radius: r)));
  canvas.drawCircle(
    c,
    r * 0.55,
    Paint()
      ..color = darken(CostumeColors.gold, 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9,
  );
  glint(canvas, c + Offset(-r * 0.35, -r * 0.35), r * 0.45);
}
