import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/game/battle.dart';
import 'package:solo_pushing_up/game/labors.dart';
import 'package:solo_pushing_up/rep/pushup_counter.dart';

import 'battle_test.dart' show rep;

/// Rep mục tiêu của từng màn chương 1 cho người chơi chuẩn
/// (rules/thietke/chuong1-nemea.md, skill balance-reps).
const _targets = {
  '1.1': (6, 8),
  '1.2': (8, 12),
  '1.3': (10, 12),
  '1.4': (12, 16),
  '1.5': (8, 10),
  '1.6': (14, 18),
  '1.7': (10, 12),
  '1.8': (18, 22),
};

/// Người chơi mô phỏng: một rep mỗi [cadenceMs]; thấy báo húc/vồ thì ngừng
/// rep, giữ tay thẳng tới khi đòn tới rồi tập tiếp. Trả số rep để thắng
/// (null = không thắng trong 10 phút).
int? simulate(
  EnemySpec enemy, {
  PushupMode mode = PushupMode.standard,
  int cadenceMs = 1000,
  bool dodge = true,
}) {
  final battle = Battle(enemy: enemy, mode: mode);
  var nextRep = 0;
  int? holdFrom;
  for (var t = 0; t < 600000; t += 50) {
    final hold = holdFrom == null ? 0 : t - holdFrom;
    final events = [
      ...battle.tick(t, plankHoldMs: hold),
      if (holdFrom == null && t >= nextRep) ...battle.apply([rep(t)]),
    ];
    if (holdFrom == null && t >= nextRep) nextRep = t + cadenceMs;
    if (battle.status == BattleStatus.won) return battle.reps;
    if (battle.status == BattleStatus.lost) return null;
    for (final e in events) {
      if (dodge && (e is ChargeWarning || e is PounceWarning)) holdFrom = t;
      if (e is ChargeLanded || e is PounceLanded) {
        holdFrom = null;
        nextRep = t + cadenceMs;
      }
    }
  }
  return null;
}

void main() {
  final stages = labors.firstWhere((l) => l.id == 'nemea').stages;

  test('mỗi màn có rep mục tiêu', () {
    expect(stages.map((s) => s.code).toSet(), _targets.keys.toSet());
  });

  for (final stage in stages) {
    test('${stage.code} ${stage.title}: người chuẩn trong mục tiêu', () {
      final (lo, hi) = _targets[stage.code]!;
      final reps = simulate(stage.enemy);
      expect(reps, isNotNull);
      expect(reps, inInclusiveRange(lo, hi));
    });

    test(
      '${stage.code}: người mới (chống gối, 3 s/rep) thắng trong 30 rep',
      () {
        final reps = simulate(
          stage.enemy,
          mode: PushupMode.knee,
          cadenceMs: 3000,
        );
        expect(reps, isNotNull);
        expect(reps, lessThanOrEqualTo(30));
      },
    );
  }

  test('răng cưa: tinh anh, mini-boss, boss cao hơn màn ngay trước và sau', () {
    final reps = [for (final s in stages) simulate(s.enemy)!];
    for (final peak in [3, 5]) {
      expect(reps[peak], greaterThan(reps[peak - 1]), reason: 'trước $peak');
      expect(reps[peak], greaterThan(reps[peak + 1]), reason: 'sau $peak');
    }
    expect(reps.last, greaterThan(reps[reps.length - 2]));
  });
}
