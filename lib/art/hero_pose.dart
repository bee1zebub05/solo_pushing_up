import 'dart:math' as math;
import 'dart:ui';

/// Kích thước các đoạn cơ thể nhân vật người chơi (đơn vị: điểm trên sân
/// khấu 400×260). Đầu to hơn người thật một chút cho dễ thương, dễ nhìn.
abstract final class HeroBody {
  static const upperArm = 30.0;
  static const forearm = 28.0;
  static const torso = 62.0;
  static const thigh = 44.0;
  static const shin = 42.0;
  static const neck = 9.0;
  static const headRadius = 16.5;
  static const foot = 13.0;
}

/// Các khớp của nhân vật nhìn nghiêng, mặt quay sang phải. "far" là tay/chân
/// phía xa camera, vẽ tối hơn và nằm sau thân.
enum HeroJoint {
  head,
  neck,
  shoulder,
  elbow,
  wrist,
  hip,
  knee,
  ankle,
  toe,
  farElbow,
  farWrist,
  farKnee,
  farAnkle,
  farToe,
}

/// Một tư thế = vị trí mọi khớp. Hoạt hình = nội suy giữa các tư thế.
class HeroPose {
  const HeroPose(this.joints);

  final Map<HeroJoint, Offset> joints;

  Offset operator [](HeroJoint j) => joints[j]!;

  static HeroPose lerp(HeroPose a, HeroPose b, double t) => HeroPose({
    for (final j in HeroJoint.values) j: Offset.lerp(a[j], b[j], t)!,
  });

  HeroPose translate(Offset by) =>
      HeroPose({for (final e in joints.entries) e.key: e.value + by});

  /// Tư thế chống đẩy với góc khuỷu tay [elbowDeg] (180 = tay thẳng).
  ///
  /// Tính đúng hình học: bàn tay và mũi chân (hoặc đầu gối) cố định trên sàn,
  /// thân thẳng quay quanh điểm tựa, vai cách cổ tay đúng độ dài hai đoạn tay
  /// theo định lý cos. Nhờ vậy góc tay của người chơi điều khiển thẳng nhân vật.
  static HeroPose plank(
    double elbowDeg, {
    bool onKnees = false,
    double groundY = 220,
    double footX = 30,
  }) {
    const a = HeroBody.upperArm;
    const b = HeroBody.forearm;
    final theta = elbowDeg.clamp(55.0, 180.0) * math.pi / 180;

    final Offset pivot;
    final double length;
    if (onKnees) {
      pivot = Offset(footX + HeroBody.shin + 4, groundY - 4);
      length = HeroBody.thigh + HeroBody.torso;
    } else {
      pivot = Offset(footX + 6, groundY - 6);
      length = HeroBody.shin + HeroBody.thigh + HeroBody.torso;
    }

    // Tay thẳng thì vai nằm ngay trên cổ tay.
    final wristY = groundY - 3;
    final rise = pivot.dy - (wristY - (a + b));
    final wrist = Offset(
      pivot.dx + math.sqrt(length * length - rise * rise),
      wristY,
    );
    final reach = math.sqrt(a * a + b * b - 2 * a * b * math.cos(theta));
    final shoulder = _intersect(pivot, length, wrist, reach, upper: true);
    // Khuỷu tay chĩa về phía chân, như khi chống đẩy đúng kỹ thuật.
    final elbow = _intersect(wrist, b, shoulder, a, upper: false, back: true);

    final u = (shoulder - pivot) / length;
    final Offset knee, hip, ankle, toe;
    if (onKnees) {
      knee = pivot;
      hip = knee + u * HeroBody.thigh;
      ankle = Offset(knee.dx - HeroBody.shin * 0.92, groundY - 16);
      toe = ankle + const Offset(-9, -5);
    } else {
      ankle = pivot;
      knee = ankle + u * HeroBody.shin;
      hip = knee + u * HeroBody.thigh;
      toe = Offset(ankle.dx + 4, groundY);
    }

    // Đầu ngẩng lên nhìn về phía trước một chút.
    final headDir = _rotate(u, -0.35);
    final neck = shoulder + headDir * (HeroBody.neck * 0.7);
    final head = shoulder + headDir * (HeroBody.neck + HeroBody.headRadius);

    const far = Offset(5, -2);
    return HeroPose({
      HeroJoint.head: head,
      HeroJoint.neck: neck,
      HeroJoint.shoulder: shoulder,
      HeroJoint.elbow: elbow,
      HeroJoint.wrist: wrist,
      HeroJoint.hip: hip,
      HeroJoint.knee: knee,
      HeroJoint.ankle: ankle,
      HeroJoint.toe: toe,
      HeroJoint.farElbow: elbow + far,
      HeroJoint.farWrist: wrist + far,
      HeroJoint.farKnee: knee + far,
      HeroJoint.farAnkle: ankle + far,
      HeroJoint.farToe: toe + far,
    });
  }

  /// Đứng chờ; [breath] 0–1 theo nhịp thở.
  static HeroPose standing({
    double breath = 0,
    double groundY = 220,
    double x = 110,
  }) {
    final rise = math.sin(breath * 2 * math.pi) * 1.2;
    final ankle = Offset(x, groundY - 5);
    final knee = ankle + const Offset(2, -HeroBody.shin);
    final hip = knee + const Offset(-1, -HeroBody.thigh);
    final shoulder = hip + Offset(2, -HeroBody.torso - rise);
    final up = Offset(0.05, -1);
    final neck = shoulder + up * (HeroBody.neck * 0.7);
    final head = shoulder + up * (HeroBody.neck + HeroBody.headRadius);
    final elbow = shoulder + const Offset(4, HeroBody.upperArm);
    final wrist = elbow + Offset(6, HeroBody.forearm - 2 + rise * 0.5);
    return HeroPose({
      HeroJoint.head: head,
      HeroJoint.neck: neck,
      HeroJoint.shoulder: shoulder,
      HeroJoint.elbow: elbow,
      HeroJoint.wrist: wrist,
      HeroJoint.hip: hip,
      HeroJoint.knee: knee,
      HeroJoint.ankle: ankle,
      HeroJoint.toe: ankle + const Offset(HeroBody.foot, 5),
      HeroJoint.farElbow: shoulder + const Offset(-5, HeroBody.upperArm),
      HeroJoint.farWrist: shoulder + Offset(-6, HeroBody.upperArm + 27),
      HeroJoint.farKnee: knee + const Offset(-8, 1),
      HeroJoint.farAnkle: ankle + const Offset(-12, 0),
      HeroJoint.farToe: ankle + const Offset(-12 + HeroBody.foot, 5),
    });
  }

  /// Ăn mừng: giơ tay phía gần lên trời, tay xa chống hông.
  static HeroPose victory({
    double pump = 0,
    double groundY = 220,
    double x = 110,
  }) {
    final base = standing(groundY: groundY, x: x);
    final lift = math.sin(pump * 2 * math.pi).abs() * 6;
    final shoulder = base[HeroJoint.shoulder] + Offset(0, -lift * 0.3);
    // Giơ chếch về phía trước để không che mặt.
    final elbow = shoulder + Offset(20, -HeroBody.upperArm * 0.7 - lift * 0.5);
    final wrist = elbow + Offset(12, -HeroBody.forearm * 0.92 - lift * 0.5);
    final up = Offset(0.12, -1);
    return HeroPose({
      ...base.joints,
      HeroJoint.shoulder: shoulder,
      HeroJoint.neck: shoulder + up * (HeroBody.neck * 0.7),
      HeroJoint.head: shoulder + up * (HeroBody.neck + HeroBody.headRadius),
      HeroJoint.elbow: elbow,
      HeroJoint.wrist: wrist,
      HeroJoint.farElbow: shoulder + const Offset(-16, 22),
      HeroJoint.farWrist: shoulder + const Offset(-4, 46),
    });
  }

  /// Giao điểm hai đường tròn (tâm [c1] bán kính [r1], tâm [c2] bán kính
  /// [r2]). Nếu không cắt nhau thì lấy điểm gần nhất trên đường nối tâm.
  static Offset _intersect(
    Offset c1,
    double r1,
    Offset c2,
    double r2, {
    required bool upper,
    bool back = false,
  }) {
    final d = (c2 - c1).distance;
    final dir = (c2 - c1) / d;
    if (d >= r1 + r2 || d <= (r1 - r2).abs()) return c1 + dir * r1;
    final along = (d * d + r1 * r1 - r2 * r2) / (2 * d);
    final h = math.sqrt(math.max(0, r1 * r1 - along * along));
    final mid = c1 + dir * along;
    final normal = Offset(-dir.dy, dir.dx);
    final p1 = mid + normal * h;
    final p2 = mid - normal * h;
    if (back) return p1.dx < p2.dx ? p1 : p2;
    final higher = p1.dy < p2.dy ? p1 : p2;
    final lower = identical(higher, p1) ? p2 : p1;
    return upper ? higher : lower;
  }

  static Offset _rotate(Offset v, double rad) => Offset(
    v.dx * math.cos(rad) - v.dy * math.sin(rad),
    v.dx * math.sin(rad) + v.dy * math.cos(rad),
  );
}
