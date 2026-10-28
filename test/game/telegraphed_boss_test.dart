import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/game/battle.dart';
import 'package:solo_pushing_up/rep/pushup_counter.dart';

/// Rep kết thúc lúc [end], đáy tại [end] − ([duration] − [descent]).
CountedRep rep(
  int end, {
  bool deep = true,
  int duration = 1200,
  int descent = 600,
  bool slow = false,
}) => CountedRep(
  timestampMs: end,
  minElbowAngle: deep ? 60 : 95,
  index: 1,
  durationMs: duration,
  descentMs: descent,
  posture: Posture.standard,
  isDeep: deep,
  isFast: duration < 1000,
  isSlow: slow,
);

EnemySpec shuten({int hp = 260, int seed = 1}) => EnemySpec(
  id: 'shuten_doji',
  name: 'Shuten',
  maxHp: hp,
  mechanics: [() => ShutenMechanic(random: math.Random(seed))],
);

EnemySpec sutoku({int hp = 420, int seed = 1}) => EnemySpec(
  id: 'tengu_sutoku',
  name: 'Sutoku',
  maxHp: hp,
  mechanics: [() => SutokuMechanic(random: math.Random(seed))],
);

/// Chạy trận tới khi có sự kiện [T] (tick 100 ms), không rep; trả sự kiện.
T runUntil<T extends BattleEvent>(Battle b, int from, {int plank = 0, int limit = 60000}) {
  for (var t = from; t < from + limit; t += 100) {
    final e = b.tick(t, plankHoldMs: plank).whereType<T>().firstOrNull;
    if (e != null) return e;
  }
  throw StateError('Không có $T');
}

/// Kiểu người chơi trong mô phỏng.
enum Bot { smart, naive, plankOnly, shallow }

/// Mô phỏng một trận: tick 100 ms, rep chuẩn (sâu) mỗi 2 s. [Bot.smart] né
/// đúng (⏸: dừng rep giữ plank qua lúc chạm; rep sâu: canh đáy đúng lúc
/// chạm), ngắt uống rượu bằng rep dồn, đốt ấn bằng rep chậm. Trả (thắng?, số rep).
(bool, int) simulate(EnemySpec enemy, Bot bot, {int limitMs = 900000}) {
  final b = Battle(enemy: enemy);
  var next = 1200; // lúc rep kế tiếp kết thúc
  var plankSince = -1;
  int? impact;
  DodgeBy? dodge;
  var drinking = false;
  var cursed = false;
  for (var t = 0; t < limitMs && b.status != BattleStatus.won; t += 100) {
    var plank = 0;
    final reps = <RepEvent>[];
    if (bot == Bot.plankOnly) {
      plank = t;
    } else {
      // Giữ plank quanh đòn ⏸ (bot thông minh): ngừng rep 1,2 s trước chạm.
      final holding = bot == Bot.smart && impact != null && dodge == DodgeBy.hold &&
          t >= impact - 1200 && t <= impact + 200;
      if (holding) {
        if (plankSince < 0) plankSince = t;
        plank = t - plankSince;
        next = math.max(next, impact + 1400);
      } else {
        plankSince = -1;
        if (t >= next) {
          if (bot == Bot.shallow) {
            reps.add(rep(t, deep: false, duration: 900, descent: 400));
            next = t + 1200;
          } else if (bot == Bot.smart && cursed) {
            reps.add(rep(t, duration: 3800, descent: 2600, slow: true));
            next = t + 2000;
          } else {
            reps.add(rep(t));
            next = t + (bot == Bot.smart && drinking ? 1300 : 2000);
          }
        }
      }
      // Rep sâu canh đáy đúng lúc chạm (đòn ngang).
      if (bot == Bot.smart && impact != null && dodge == DodgeBy.duck && next > impact + 600 && next - 2000 < impact) {
        next = impact + 600;
      }
    }
    final events = [...b.apply(reps), ...b.tick(t, plankHoldMs: plank)];
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
  return (b.status == BattleStatus.won, b.reps);
}

void main() {
  group('đòn có báo trước', () {
    test('đòn ⏸: giữ tay thẳng lúc chạm thì né, rep sau phản đòn ×2', () {
      final b = Battle(enemy: shuten());
      b.apply([rep(1200)]);
      final tell = runUntil<BossTell>(b, 1300);
      expect(tell.dodge, DodgeBy.hold);
      final struck = runUntil<BossStruck>(b, tell.timestampMs + 100, plank: 900);
      expect(struck.dodged, isTrue);
      final hit = b.apply([rep(struck.timestampMs + 1500)]).whereType<Hit>().single;
      expect(hit.countered, isTrue);
      expect(hit.damage, 40); // 10 × sâu 2 × phản đòn 2 (combo về 1 vì nghỉ lâu)
    });

    test('đòn ⏸: không giữ plank thì trúng, mất combo', () {
      final b = Battle(enemy: shuten());
      b.apply([rep(1200), rep(2400), rep(3600)]);
      expect(b.combo, 3);
      final struck = runUntil<BossStruck>(b, 3700);
      expect(struck.dodged, isFalse);
      expect(b.combo, 0);
    });

    test('đòn ngang: rep sâu có đáy trong cửa sổ chạm thì né; rep nông không né', () {
      for (final deep in [true, false]) {
        final b = Battle(enemy: shuten());
        b.apply([rep(1200)]);
        runUntil<BossStruck>(b, 1300, plank: 900); // đòn 1 (⏸) né xong
        final tell = runUntil<BossTell>(b, 1400);
        expect(tell.dodge, DodgeBy.duck);
        final impact = tell.timestampMs + tell.inMs;
        // Đáy rep đúng lúc chạm: kết thúc 600 ms sau.
        for (var t = tell.timestampMs + 100; t < impact + 600; t += 100) {
          b.tick(t);
        }
        b.apply([rep(impact + 600, deep: deep)]);
        final struck = runUntil<BossStruck>(b, impact + 700);
        expect(struck.dodged, deep, reason: 'deep=$deep');
      }
    });

    test('camera mất người lúc chạm: huỷ đòn, không mất combo', () {
      final b = Battle(enemy: shuten());
      b.apply([rep(1200), rep(2400)]);
      final tell = runUntil<BossTell>(b, 2500);
      BossStruck? struck;
      for (var t = tell.timestampMs + 100; struck == null; t += 100) {
        struck = b.tick(t, tracking: t < tell.timestampMs + 1000).whereType<BossStruck>().firstOrNull;
      }
      expect(struck.cancelled, isTrue);
      expect(b.combo, 2);
    });

    test('không báo hai đòn cùng lúc, nghỉ ≥ 6 s giữa hai hành động', () {
      final b = Battle(enemy: shuten(hp: 100000));
      b.apply([rep(0)]);
      final tells = <int>[];
      final ends = <int>[];
      for (var t = 100; t < 120000; t += 100) {
        for (final e in b.tick(t, plankHoldMs: 900)) {
          if (e is BossTell) tells.add(t);
          if (e is BossStruck) ends.add(t);
        }
      }
      expect(tells.length, greaterThan(5));
      for (var i = 1; i < tells.length; i++) {
        expect(tells[i] - ends[i - 1], greaterThanOrEqualTo(6000));
      }
    });
  });

  group('Shuten uống rượu', () {
    /// Đưa trận tới lúc Shuten uống (máu < 85 %, sau 2 đòn).
    (Battle, SakeDrinking) toDrink() {
      final b = Battle(enemy: shuten(hp: 200));
      b.apply([rep(1000), rep(2000)]); // 20 + 22 → còn 79 % < 85 %
      for (var t = 2100; ; t += 100) {
        final e = b.tick(t, plankHoldMs: 900).whereType<SakeDrinking>().firstOrNull;
        if (e != null) return (b, e);
      }
    }

    test('không ngắt: hồi 10 % máu tối đa', () {
      final (b, d) = toDrink();
      final hp = b.hp;
      final done = runUntil<SakeFinished>(b, d.timestampMs + 100);
      expect(done.healed, 20); // 10 % của 200
      expect(b.hp, hp + 20);
    });

    test('3 rep trong lúc uống thì ngắt, choáng: đòn ×1,5', () {
      final (b, d) = toDrink();
      final t0 = d.timestampMs;
      b.apply([rep(t0 + 1200), rep(t0 + 2400), rep(t0 + 3600)]);
      expect(runUntil<SakeInterrupted>(b, t0 + 3700).stunMs, 3000);
      final hit = b.apply([rep(t0 + 4800)]).whereType<Hit>().single;
      // 10 × combo × sâu 2 × choáng 1,5.
      expect(hit.damage, (10 * (1 + 0.1 * (hit.combo - 1)) * 2 * 1.5).round());
      expect(b.view(t0 + 4800).stunMs, greaterThan(0));
    });
  });

  group('Sutoku ấn nguyền', () {
    (Battle, int) toCurse() {
      final b = Battle(enemy: sutoku(hp: 150));
      b.apply([rep(1000), rep(2000), rep(3000)]); // 20 + 22 + 24 → còn 56 % < 60 %
      final cast = runUntil<CurseCast>(b, 2100, plank: 900);
      return (b, cast.timestampMs);
    }

    test('còn ấn thì đòn ×0,75; rep chậm đốt ấn và đánh ×2', () {
      final (b, t0) = toCurse();
      double base(Hit h) => 10 * (1 + 0.1 * (h.combo - 1)) * 2;
      final weak = b.apply([rep(t0 + 1500)]).whereType<Hit>().single;
      expect(weak.damage, (base(weak) * 0.75).round());
      final purge = b.apply([rep(t0 + 5300, duration: 3800, descent: 2600, slow: true)]).whereType<Hit>().single;
      expect(purge.damage, (base(purge) * 2).round());
      expect(runUntil<CurseLifted>(b, t0 + 5400, plank: 900).purged, isTrue);
    });

    test('không hoá giải: ấn tự tan sau 15 s', () {
      final (b, t0) = toCurse();
      final lifted = runUntil<CurseLifted>(b, t0 + 100, plank: 900);
      expect(lifted.purged, isFalse);
      expect(lifted.timestampMs - t0, inInclusiveRange(15000, 15100));
    });
  });

  group('nghiệm thu brief (mô phỏng)', () {
    for (final (name, make) in [('Shuten', shuten), ('Sutoku', sutoku)]) {
      test('$name: né đúng thắng; không né vẫn thắng ≤ 1,7× rep; chỉ plank không thắng; rep nông kém hơn', () {
        final (smartWon, smartReps) = simulate(make(), Bot.smart);
        final (naiveWon, naiveReps) = simulate(make(), Bot.naive);
        final (plankWon, _) = simulate(make(), Bot.plankOnly, limitMs: 600000);
        final (shallowWon, shallowReps) = simulate(make(), Bot.shallow);
        // ignore: avoid_print
        print('$name: né đúng $smartReps rep, không né $naiveReps rep, rep nông $shallowReps rep');
        expect(smartWon, isTrue);
        expect(naiveWon, isTrue);
        // Chênh chủ yếu là THƯỞNG (phản đòn ×2, giữ combo), không phải phạt.
        expect(naiveReps, lessThanOrEqualTo((smartReps * 1.7).ceil()));
        expect(plankWon, isFalse);
        expect(shallowWon, isTrue);
        expect(shallowReps, greaterThan(naiveReps));
      });
    }
  });
}
