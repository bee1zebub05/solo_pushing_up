import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/game/battle.dart';
import 'package:solo_pushing_up/game/labors.dart';
import 'package:solo_pushing_up/rep/pushup_counter.dart';

CountedRep rep(int t, {bool fast = false, bool slow = false}) => CountedRep(
  timestampMs: t,
  startMs: t - 900,
  minElbowAngle: 85,
  index: 1,
  durationMs: fast ? 800 : 1500,
  descentMs: slow ? 3000 : 500,
  posture: Posture.standard,
  isDeep: false,
  isFast: fast,
  isSlow: slow,
);

void main() {
  group('Thuỷ Tinh (núi dâng, nước dâng)', () {
    test('không đánh thì nước dâng tới đỉnh và thua', () {
      final battle = Battle(enemy: thuyTinh)..apply([rep(0)]);
      battle.tick(20000);
      // Rep đầu ở giây 0 không hạ được nước đang ở 0.
      expect(battle.mechanic<RisingFlood>()!.water, closeTo(70, 0.01));

      final events = battle.tick(40000);
      expect(events.whereType<Defeat>().single.reason, DefeatReason.flooded);
      expect(battle.status, BattleStatus.lost);
      expect(battle.defeatReason, DefeatReason.flooded);
    });

    test('mỗi rep đẩy nước lùi', () {
      final battle = Battle(enemy: thuyTinh)..apply([rep(0)]);
      battle.tick(10000);
      final before = battle.mechanic<RisingFlood>()!.water;
      battle.apply([rep(10500)]);

      expect(battle.mechanic<RisingFlood>()!.water, closeTo(before - 8, 0.01));
    });

    test('đúng kiểu đợt sóng: sát thương ×1,5 và đẩy nước nhiều hơn', () {
      final battle = Battle(enemy: thuyTinh)..apply([rep(0)]);
      battle.tick(8000);
      final before = battle.mechanic<RisingFlood>()!.water;
      // 12 giây đầu là đợt ⚡; rep thường không khớp, rep nhanh thì khớp.
      final hit = battle.apply([rep(8000, fast: true)]).single as Hit;

      expect(hit.matched, isTrue);
      expect(hit.damage, 15);
      expect(battle.mechanic<RisingFlood>()!.water, closeTo(before - 16, 0.01));
    });

    test('rep chậm chỉ khớp ở đợt 🐢', () {
      final battle = Battle(enemy: thuyTinh)..apply([rep(0)]);
      expect(battle.view(13000).wave!.action, WaveAction.slow);

      final hit = battle.apply([rep(13000, slow: true)]).single as Hit;
      expect(hit.matched, isTrue);
    });

    test('báo đợt sóng mới khi đổi đợt', () {
      final battle = Battle(enemy: thuyTinh)..apply([rep(0)]);
      // Khung hình đầu tiên của trận báo đợt đầu.
      final first = battle.tick(100).whereType<WaveStarted>().single;
      expect(first.wave.action, WaveAction.fast);
      expect(battle.tick(11000).whereType<WaveStarted>(), isEmpty);

      final started = battle.tick(12000).whereType<WaveStarted>().single;
      expect(started.wave.action, WaveAction.slow);
    });

    test('giữ tư thế chỉ gây sát thương ở đợt ⏸', () {
      final battle = Battle(enemy: thuyTinh)..apply([rep(0)]);
      // Đợt ⚡: giữ 4 giây không gây gì.
      expect(battle.tick(5000, plankHoldMs: 4000).whereType<Hit>(), isEmpty);
      battle.tick(6000);

      // Đợt ⏸ là giây 27–37: giữ 4,1 giây = 2 đòn.
      battle.tick(28000);
      final hits = battle
          .tick(32100, plankHoldMs: 4100)
          .whereType<Hit>()
          .toList();
      expect(hits, hasLength(2));
      expect(hits.every((h) => h.held && h.matched), isTrue);
      expect(hits.first.damage, 12);
    });

    test('giữ tư thế trước khi rep cũng bắt đầu trận', () {
      final battle = Battle(enemy: thuyTinh);
      battle.tick(1000, plankHoldMs: 500);

      expect(battle.status, BattleStatus.fighting);
    });

    test('kẻ thù khác không có nước dâng', () {
      final battle = Battle(enemy: nemeanLion)..apply([rep(0)]);
      expect(battle.tick(60000), isEmpty);
      expect(battle.view(60000).wave, isNull);
    });
  });
}
