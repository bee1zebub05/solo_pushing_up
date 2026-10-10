import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/rep/pushup_counter.dart';
import 'package:solo_pushing_up/sim/pose_simulator.dart';

/// Số rep mong đợi của từng kịch bản (Chiến binh, Tân binh),
/// khớp với dòng "Mong đợi" hiện trong app.
const _expected = {
  'Chuẩn ×10': (10, 10),
  'Nhanh ×8': (8, 8),
  'Chậm ×3': (3, 3),
  'Sâu ×5': (5, 5),
  'Nông ×5': (0, 0),
  'Quỳ gối ×5 (máy ngang)': (0, 5),
  'Võng hông ×5 (máy ngang)': (0, 0),
  'Rung nhiễu ×10': (10, 10),
  'Mất dấu giữa set': (6, 6),
  'Chuẩn bị lộn xộn': (3, 3),
  'Giữ plank 5s': (0, 0),
};

int countOf(SimScenario scenario, PushupMode mode) {
  final counter = PushupCounter(mode: mode);
  for (final frame in scenario.frames()) {
    counter.update(frame);
  }
  return counter.count;
}

void main() {
  test('mọi kịch bản đều có số rep mong đợi', () {
    expect(simScenarios.map((s) => s.name).toSet(), _expected.keys.toSet());
  });

  for (final scenario in simScenarios) {
    test('kịch bản ${scenario.name}', () {
      final (standard, knee) = _expected[scenario.name]!;
      expect(countOf(scenario, PushupMode.standard), standard);
      expect(countOf(scenario, PushupMode.knee), knee);
    });
  }
}
