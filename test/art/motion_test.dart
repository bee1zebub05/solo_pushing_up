import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/art/motion.dart';

void main() {
  test('đòn 1,2 giây: pha lấy đà kéo dài ≥ 0,6 giây (trụ cột 3)', () {
    const length = 1.2;
    expect(AttackPose.windupEnd * length, greaterThanOrEqualTo(0.6));
    // Đang lấy đà: chưa ra đòn.
    final mid = AttackPose.at(0.3);
    expect(mid.windup, greaterThan(0.5));
    expect(mid.strike, 0);
    // Ra đòn ngay sau mốc lấy đà.
    expect(AttackPose.at(0.62).strike, greaterThan(0.8));
    expect(AttackPose.at(-1).windup, 0);
  });

  test('lò xo: đòn trúng đẩy boss ra xa người chơi rồi về chỗ cũ', () {
    final motion = BossBodyMotion()..hit(critical: true);
    var maxSway = 0.0;
    for (var i = 0; i < 20; i++) {
      motion.update(1 / 60, attackPhase: -1);
      if (motion.sway > maxSway) maxSway = motion.sway;
    }
    expect(maxSway, greaterThan(4));
    for (var i = 0; i < 180; i++) {
      motion.update(1 / 60, attackPhase: -1);
    }
    expect(motion.sway.abs(), lessThan(0.3));
  });

  test('lấy đà ngả ra sau, ra đòn lao về phía người chơi', () {
    final motion = BossBodyMotion();
    var phase = 0.0;
    var back = 0.0;
    var forward = 0.0;
    while (phase < 1) {
      motion.update(1 / 60, attackPhase: phase);
      if (phase < AttackPose.windupEnd && motion.sway > back) {
        back = motion.sway;
      }
      if (motion.sway < forward) forward = motion.sway;
      phase += 1 / 60 / 1.2;
    }
    expect(back, greaterThan(3));
    expect(forward, lessThan(-6));
  });
}
