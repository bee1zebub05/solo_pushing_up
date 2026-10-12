import 'dart:math' as math;
import 'dart:ui';

/// Chuyển động procedural dùng chung cho mọi boss (kiểu David Rosen: vài tư
/// thế chính + lò xo), để hình đã vẽ "sống" mà không cần Spine hay hoạ sĩ.

/// Lò xo một chiều tắt dần: vị trí đuổi theo [target], vượt quá rồi nảy về.
/// Dùng cho chuyển động theo sau (follow-through): thân nảy sau cú vồ, giật
/// khi trúng đòn.
class Spring {
  Spring({this.stiffness = 180, this.damping = 14});

  /// Độ cứng (càng lớn càng nảy nhanh) và độ tắt (càng lớn càng ít nảy).
  final double stiffness;
  final double damping;
  double value = 0;
  double velocity = 0;

  /// Cộng thẳng vào vận tốc (cú đẩy tức thời, ví dụ đòn trúng).
  void kick(double impulse) => velocity += impulse;

  void update(double target, double dt) {
    // Chia bước nhỏ để ổn định khi khung bị giật (dt lớn).
    var left = math.min(dt, 0.1);
    while (left > 0) {
      final h = math.min(left, 1 / 120);
      final force = stiffness * (target - value) - damping * velocity;
      velocity += force * h;
      value += velocity * h;
      left -= h;
    }
  }
}

/// Ba pha của một đòn trên thang tiến độ 0–1 ([BossFrame.attackPhase]):
/// lấy đà (đọc được, ≥0,6 giây với đòn 1,2 giây) → ra đòn (nhanh) → thu về.
class AttackPose {
  const AttackPose(this.windup, this.strike, this.recover);

  /// Mỗi giá trị 0–1: mức của pha tương ứng tại thời điểm này.
  final double windup;
  final double strike;
  final double recover;

  static const none = AttackPose(0, 0, 0);

  /// Mốc chia pha: hết lấy đà ở 0,5, hết ra đòn ở 0,65.
  static const windupEnd = 0.5;
  static const strikeEnd = 0.65;

  factory AttackPose.at(double phase) {
    if (phase < 0 || phase > 1) return none;
    if (phase < windupEnd) {
      // Lấy đà chậm dần về cuối (ease-out): người chơi kịp nhìn thấy.
      final t = phase / windupEnd;
      return AttackPose(1 - (1 - t) * (1 - t), 0, 0);
    }
    if (phase < strikeEnd) {
      final t = (phase - windupEnd) / (strikeEnd - windupEnd);
      return AttackPose(1 - t, math.sin(t * math.pi / 2), 0);
    }
    final t = (phase - strikeEnd) / (1 - strikeEnd);
    return AttackPose(0, 1 - t, math.sin(t * math.pi));
  }
}

/// Dáng thân boss tại một khung: thở, lấy đà ngả ra sau, vồ tới trước, nảy
/// khi trúng đòn. Áp lên canvas quanh chân boss ([anchor]) trước khi vẽ boss.
class BossBodyMotion {
  BossBodyMotion();

  /// Nảy ngang (giật lùi khi trúng đòn, vượt đà sau cú vồ).
  final _sway = Spring(stiffness: 140, damping: 9);

  /// Co–giãn dọc (squash & stretch).
  final _squash = Spring(stiffness: 220, damping: 12);

  double _time = 0;
  AttackPose pose = AttackPose.none;

  /// Gọi khi đòn của người chơi trúng boss.
  void hit({bool critical = false}) {
    _sway.kick(critical ? 260 : 160);
    _squash.kick(critical ? -2.4 : -1.4);
  }

  /// Boss nổi giận (sang pha cuối): phồng người rồi nảy.
  void enrage() {
    _squash.kick(3.2);
    _sway.kick(-120);
  }

  void update(double dt, {required double attackPhase, bool defeated = false}) {
    _time += dt;
    pose = defeated ? AttackPose.none : AttackPose.at(attackPhase);
    // Đích của lò xo: lấy đà = lùi ra sau (sang phải, xa người chơi), ra đòn
    // = lao tới (sang trái). Lò xo tự tạo độ trễ và vượt đà khi thu về.
    final reach = pose.windup * 7 - pose.strike * 16;
    _sway.update(reach, dt);
    _squash.update(pose.windup * -0.05 + pose.strike * 0.04, dt);
  }

  /// Áp biến đổi lên [canvas] quanh điểm chân [anchor] (boss nhìn sang trái).
  void apply(Canvas canvas, Offset anchor, {double breathe = 1}) {
    // Thở: chu kỳ ~3,4 giây, phồng ngực nhẹ (chỉ dọc, chân giữ nguyên).
    final breath = math.sin(_time * math.pi * 2 / 3.4) * 0.012 * breathe;
    final sy = 1 + breath + _squash.value;
    final sx = 1 - _squash.value * 0.5;
    canvas
      ..translate(anchor.dx + _sway.value, anchor.dy)
      // Nghiêng theo cú lao: ngả về hướng chuyển động.
      ..rotate(-_sway.value * 0.0035)
      ..scale(sx, sy)
      ..translate(-anchor.dx, -anchor.dy);
  }

  double get sway => _sway.value;
}
