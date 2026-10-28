import 'dart:math' as math;
import 'dart:ui';

import '../sprite_atlas.dart';

/// Track tư thế của một boss: khớp chính chiếu qua máy quay sân khấu (đơn vị
/// sân khấu quanh chân, y xuống), ghi lúc nướng chuyển động (tool/motion/bake.py)
/// — cùng chuyển động với sprite. Bản vector 2.5D lấy độ lệch so với dáng chờ
/// thay cho kênh biên đạo, nên thân đi theo mocap võ học như bản 3D.
class PoseTrack {
  const PoseTrack({required this.weaponLen, required this.ready, required this.anims});

  /// Thứ tự khớp trong mỗi khung (x, y liền nhau).
  static const names = [
    'pelvis', 'chest', 'head', 'shoulder_r', 'hand_r', 'hand_l', 'foot_l', 'foot_r', 'weapon_tip', //
  ];

  /// Độ dài vũ khí lớn nhất trên màn hình (ngắn hơn = đang chĩa về máy quay).
  final double weaponLen;
  final List<double> ready;
  final Map<String, PoseAnim> anims;

  PoseFrame get readyFrame => PoseFrame(ready);

  /// Khung tại tiến độ [phase] của đòn [move] (nội suy giữa hai khung kề), hoặc null.
  PoseFrame? at(String move, double phase) {
    final a = anims[move];
    if (a == null || a.frames.isEmpty) return null;
    final pos = SpriteAtlas.positionOf(a.phases, phase);
    final i = pos.floor().clamp(0, a.frames.length - 1);
    final j = math.min(i + 1, a.frames.length - 1);
    final t = pos - pos.floor();
    final fi = a.frames[i], fj = a.frames[j];
    return PoseFrame([for (var k = 0; k < fi.length; k++) fi[k] + (fj[k] - fi[k]) * t]);
  }
}

class PoseAnim {
  const PoseAnim(this.phases, this.frames);
  final List<double> phases;
  final List<List<double>> frames;
}

class PoseFrame {
  const PoseFrame(this.xy);
  final List<double> xy;

  Offset operator [](String name) {
    final i = PoseTrack.names.indexOf(name);
    return Offset(xy[2 * i], xy[2 * i + 1]);
  }

  /// Góc thân (ngực − hông) trên màn hình, radian, y xuống.
  double get torso {
    final d = this['chest'] - this['pelvis'];
    return math.atan2(d.dy, d.dx);
  }
}
