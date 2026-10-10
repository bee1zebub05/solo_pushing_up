import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/rep/pushup_counter.dart';
import 'package:solo_pushing_up/ui/depth_bar.dart';

CounterSnapshot snap(double? angle, {CounterPhase phase = CounterPhase.top}) =>
    CounterSnapshot(
      count: 0,
      phase: phase,
      posture: Posture.standard,
      trackingLost: false,
      events: const [],
      topThreshold: 135,
      bottomThreshold: 100,
      calibrated: false,
      elbowAngle: angle,
    );

void main() {
  test('tay thẳng thì rỗng, chạm ngưỡng đủ sâu thì đầy', () {
    expect(DepthBar.fillOf(snap(180)), 0);
    expect(DepthBar.fillOf(snap(140)), closeTo(0.5, 0.001));
    expect(DepthBar.fillOf(snap(100)), 1);
    expect(DepthBar.fillOf(snap(60)), 1);
  });

  test('chưa vào tư thế thì không hiện độ sâu', () {
    expect(DepthBar.fillOf(snap(90, phase: CounterPhase.searching)), 0);
    expect(DepthBar.fillOf(snap(null)), 0);
  });
}
