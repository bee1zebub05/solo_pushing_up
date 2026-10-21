import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/game/battle.dart';
import 'package:solo_pushing_up/game/labors.dart';
import 'package:solo_pushing_up/rep/pushup_counter.dart';

/// Rep mục tiêu hai kỳ công Nhật cho người chơi chuẩn
/// (rules/thietke/chuong2-nhat.md, skill balance-reps).
const _targets = {
  '5.1': (8, 11),
  '5.2': (8, 11),
  '5.3': (10, 13),
  '5.4': (14, 18),
  '5.5': (9, 12),
  '5.6': (17, 22),
  '5.7': (11, 14),
  '5.8': (20, 26),
  '5b.1': (8, 11),
  '5b.2': (9, 12),
  '5b.3': (10, 13),
  '5b.4': (14, 18),
  '5b.5': (9, 12),
  '5b.6': (17, 22),
  '5b.7': (12, 15),
  '5b.8': (20, 26),
};

/// Rep kết thúc lúc [end]; đáy ở end − duration + descent.
CountedRep _rep(int end, {bool deep = false, bool slow = false}) => CountedRep(
  timestampMs: end,
  minElbowAngle: deep ? 60 : 85,
  index: 1,
  durationMs: slow ? 3800 : 1200,
  descentMs: slow ? 2600 : 600,
  posture: Posture.standard,
  isDeep: deep,
  isFast: false,
  isSlow: slow,
);

/// Người chơi mô phỏng: một rep thường mỗi [cadenceMs]. Thấy báo đòn ⏸ thì
/// ngừng rep, giữ tay thẳng từ 1,2 s trước lúc chạm; đòn quét thì canh một rep
/// sâu có đáy ngay trước lúc chạm. Shuten uống rượu thì dồn rep (1,3 s/rep);
/// có ấn nguyền thì một rep chậm. Trả số rep để thắng (null = thua / quá 15 phút).
int? simulate(
  EnemySpec enemy, {
  PushupMode mode = PushupMode.standard,
  int cadenceMs = 1000,
}) {
  final battle = Battle(enemy: enemy, mode: mode);
  var nextRep = 0;
  int? impact;
  DodgeBy? dodge;
  int? holdFrom;
  var drinking = false;
  var cursed = false;
  for (var t = 0; t < 900000; t += 50) {
    final holding = impact != null && dodge == DodgeBy.hold && t >= impact - 1200 && t <= impact + 200;
    if (holding) {
      holdFrom ??= t;
    } else {
      holdFrom = null;
    }
    final reps = <CountedRep>[];
    if (!holding && t >= nextRep) {
      final duckAt = impact != null && dodge == DodgeBy.duck ? impact + 300 : null;
      if (duckAt != null && t >= duckAt - cadenceMs && t < duckAt) {
        nextRep = duckAt; // nhịn rep thường, chờ rep sâu canh đáy
      } else if (duckAt != null && t >= duckAt && t < duckAt + 100) {
        reps.add(_rep(t, deep: true));
        nextRep = t + cadenceMs;
      } else if (cursed) {
        reps.add(_rep(t, slow: true));
        cursed = false;
        nextRep = t + cadenceMs;
      } else {
        reps.add(_rep(t));
        nextRep = t + (drinking ? math.min(cadenceMs, 1300) : cadenceMs);
      }
      // Rep chậm kéo dài 3,8 s: lần rep kế tiếp sau đó.
      if (reps.isNotEmpty && reps.last.isSlow) nextRep = t + 3800;
    }
    if (holding) nextRep = math.max(nextRep, impact + 400);
    final events = [
      ...battle.apply(reps),
      ...battle.tick(t, plankHoldMs: holdFrom == null ? 0 : t - holdFrom),
    ];
    if (battle.status == BattleStatus.won) return battle.reps;
    if (battle.status == BattleStatus.lost) return null;
    for (final e in events) {
      switch (e) {
        case BossTell(:final inMs, dodge: final d):
          impact = t + inMs;
          dodge = d;
        case BossStruck():
          impact = null;
          dodge = null;
        case SakeDrinking():
          drinking = true;
        case SakeInterrupted() || SakeFinished():
          drinking = false;
        case CurseCast():
          cursed = true;
        case CurseLifted():
          cursed = false;
        default:
      }
    }
  }
  return null;
}

void main() {
  // Khoảng nghỉ giữa các đòn ngẫu nhiên: hạt cố định cho mô phỏng lặp lại được.
  setUp(() => TelegraphedBoss.newRandom = () => math.Random(7));
  tearDown(() => TelegraphedBoss.newRandom = math.Random.new);

  final chapter = [
    for (final id in ['orochi', 'heian']) labors.firstWhere((l) => l.id == id),
  ];

  test('mỗi màn có rep mục tiêu', () {
    final codes = {for (final l in chapter) ...l.stages.map((s) => s.code)};
    expect(codes, _targets.keys.toSet());
  });

  for (final labor in chapter) {
    for (final stage in labor.stages) {
      test('${stage.code} ${stage.title}: người chuẩn trong mục tiêu', () {
        final (lo, hi) = _targets[stage.code]!;
        expect(simulate(stage.enemy), inInclusiveRange(lo, hi));
      });

      test('${stage.code}: người mới (chống gối, 3 s/rep) thắng trong 30 rep', () {
        final reps = simulate(stage.enemy, mode: PushupMode.knee, cadenceMs: 3000);
        expect(reps, isNotNull);
        expect(reps, lessThanOrEqualTo(30));
      });
    }

    test('${labor.label}: răng cưa — tinh anh, mini-boss, boss cao hơn màn kề', () {
      final reps = [for (final s in labor.stages) simulate(s.enemy)!];
      for (final peak in [3, 5]) {
        expect(reps[peak], greaterThan(reps[peak - 1]), reason: 'trước ${labor.stages[peak].code}');
        expect(reps[peak], greaterThan(reps[peak + 1]), reason: 'sau ${labor.stages[peak].code}');
      }
      expect(reps.last, greaterThan(reps[reps.length - 2]));
    });
  }

  test('bảng rep (in ra để chỉnh máu)', () {
    for (final labor in chapter) {
      for (final s in labor.stages) {
        final std = simulate(s.enemy);
        final knee = simulate(s.enemy, mode: PushupMode.knee, cadenceMs: 3000);
        // ignore: avoid_print
        print('${s.code.padRight(5)} ${s.enemy.maxHp.toString().padLeft(4)} HP  chuẩn $std  mới $knee  ${s.title}');
      }
    }
  });
}
