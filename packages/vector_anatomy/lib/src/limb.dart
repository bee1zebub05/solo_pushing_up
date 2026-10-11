import 'dart:ui';

import 'curves.dart';

/// Toạ độ bám theo một đoạn chi từ [a] (gốc, gần thân) tới [b] (ngọn).
///
/// `t` chạy dọc chi 0 → 1; `s` là khoảng cách ngang (đơn vị vẽ), dương về
/// phía **trước** (anterior: mặt bắp tay trước, cơ tứ đầu, ống quyển, ngực
/// của con thú). Phía trước được chọn theo [facing] — hướng nhân vật nhìn —
/// nên profile viết một lần dùng được cho nhân vật quay trái hay phải, và
/// tự xoay theo tư thế.
class LimbFrame {
  factory LimbFrame(Offset a, Offset b, {Offset facing = const Offset(1, 0)}) {
    var d = b - a;
    if (d.distance < 1e-3) d = const Offset(0, 1e-3);
    final dir = d / d.distance;
    var n = Offset(-dir.dy, dir.dx);
    // Pháp tuyến cùng phía hướng nhìn; chi nằm ngang (gần vuông góc hướng
    // nhìn) thì lấy phía trên làm "trước" để không lật ngẫu nhiên.
    final dot = n.dx * facing.dx + n.dy * facing.dy;
    if (dot.abs() < 0.15) {
      if (n.dy > 0) n = -n;
    } else if (dot < 0) {
      n = -n;
    }
    return LimbFrame._(a, b, d, dir, n);
  }

  const LimbFrame._(this.a, this.b, this.delta, this.dir, this.anterior);

  final Offset a;
  final Offset b;
  final Offset delta;

  /// Hướng đơn vị gốc → ngọn.
  final Offset dir;

  /// Pháp tuyến đơn vị về phía trước.
  final Offset anterior;

  double get length => delta.distance;

  Offset at(double t, double s) => a + delta * t + anterior * s;
}

/// Một điểm trên đường bao một mặt chi: ở [t] dọc chi, nửa bề rộng [w].
typedef ContourStop = (double t, double w);

/// Rãnh tách nhóm cơ / đường chồng khối (overlap): đi qua các điểm (t, s)
/// với s là tỉ lệ bề rộng tại t (−1 mép sau, 0 trục, +1 mép trước), nên rãnh
/// co giãn theo profile. [weight] nhân độ dày nét (0–1,5). Rãnh bắt đầu từ
/// mép (|s| ≈ 1) tạo cảm giác khối này chui vào sau khối kia.
class Groove {
  const Groove(this.points, {this.weight = 1, this.peak = 0.45});

  final List<(double t, double s)> points;
  final double weight;
  final double peak;
}

/// Profile giải phẫu một đoạn chi: đường bao mặt trước và mặt sau **độc
/// lập** (đỉnh phồng ở độ cao khác nhau, một mặt gần thẳng), cùng các rãnh.
class MuscleProfile {
  const MuscleProfile({
    required this.anterior,
    required this.posterior,
    this.grooves = const [],
  });

  final List<ContourStop> anterior;
  final List<ContourStop> posterior;
  final List<Groove> grooves;

  /// Nửa bề rộng một mặt tại [t] (nội suy tuyến tính giữa các điểm).
  static double widthAt(List<ContourStop> side, double t) {
    if (t <= side.first.$1) return side.first.$2;
    for (var i = 1; i < side.length; i++) {
      final (t1, w1) = side[i];
      if (t <= t1) {
        final (t0, w0) = side[i - 1];
        final k = (t - t0) / (t1 - t0);
        return w0 + (w1 - w0) * k;
      }
    }
    return side.last.$2;
  }

  /// Nhân bề rộng (người béo/gầy, anh hùng, quái khổng lồ).
  MuscleProfile scaled(double k, {double anteriorExtra = 1}) => MuscleProfile(
    anterior: [for (final (t, w) in anterior) (t, w * k * anteriorExtra)],
    posterior: [for (final (t, w) in posterior) (t, w * k)],
    grooves: grooves,
  );
}

/// Hình học một đoạn chi đã dựng: đường bao (để tô) và các rãnh (Path kín
/// dạng nét thon, để tô màu sẫm của chính mảng — sel-line).
class LimbShape {
  const LimbShape(this.frame, this.outline, this.grooves);

  final LimbFrame frame;
  final Path outline;
  final List<Path> grooves;
}

/// Dựng đường bao + rãnh cho đoạn chi [a]→[b] theo [profile].
///
/// [grow] phình đều mọi phía (làm viền), [scale] nhân bề rộng, [grooveWidth]
/// độ dày tối đa của nét rãnh trước khi nhân [Groove.weight].
LimbShape buildLimb(
  Offset a,
  Offset b,
  MuscleProfile profile, {
  Offset facing = const Offset(1, 0),
  double scale = 1,
  double grow = 0,
  double grooveWidth = 1.6,
}) {
  final f = LimbFrame(a, b, facing: facing);
  final front = [
    for (final (t, w) in profile.anterior) f.at(t, w * scale + grow),
  ];
  final back = [
    for (final (t, w) in profile.posterior.reversed)
      f.at(t, -(w * scale + grow)),
  ];
  // Luôn đi mặt nằm bên phải hướng gốc→ngọn trước, để mọi đoạn có cùng
  // chiều vẽ: các đoạn chồng nhau ở khớp gộp liền (nonZero) thay vì khoét
  // lỗ khi phía trước của hai đoạn rơi về hai bên khác nhau.
  final rightIsFront = f.anterior.dx * -f.dir.dy + f.anterior.dy * f.dir.dx > 0;
  final first = rightIsFront ? front : back.reversed.toList();
  final second = rightIsFront ? back : front.reversed.toList();
  final path = Path()..moveTo(first.first.dx, first.first.dy);
  smoothPath(first, path: path, tension: 0.15);
  _cap(path, first.last, second.first, f.dir);
  smoothPath(second, path: path, tension: 0.15);
  _cap(path, second.last, first.first, -f.dir);
  path.close();

  final grooves = <Path>[];
  if (grow == 0) {
    for (final g in profile.grooves) {
      final pts = [
        for (final (t, s) in g.points)
          f.at(
            t,
            s >= 0
                ? s * MuscleProfile.widthAt(profile.anterior, t) * scale
                : s * MuscleProfile.widthAt(profile.posterior, t) * scale,
          ),
      ];
      grooves.add(
        taperedStroke(
          pts,
          grooveWidth * g.weight * scale.clamp(0.6, 2.4),
          peak: g.peak,
        ),
      );
    }
  }
  return LimbShape(f, path, grooves);
}

/// Bo đầu chi (≈ nửa hình tròn) đi vòng ra ngoài theo [outward].
void _cap(Path path, Offset from, Offset to, Offset outward) {
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
