import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/game/battle.dart';
import 'package:solo_pushing_up/game/labors.dart';
import 'package:solo_pushing_up/game/progress.dart';
import 'package:solo_pushing_up/rep/pushup_counter.dart';

import 'battle_test.dart' show rep;

void main() {
  final nemea = labors.firstWhere((l) => l.id == 'nemea');

  group('8 màn Kỳ công 1', () {
    test('đủ 8 màn 1.1 → 1.8, màn cuối là Sư tử Nemea', () {
      expect(nemea.stages.map((s) => s.code), [
        for (var i = 1; i <= 8; i++) '1.$i',
      ]);
      expect(nemea.stages.last.enemy, nemeanLion);
      expect(nemea.stages.last.id, nemea.id);
    });

    test('lúc đầu chỉ mở màn 1.1; thắng màn nào mở màn kế', () {
      final p = PlayerProgress();
      expect(p.isStageUnlocked(nemea, nemea.stages[0]), isTrue);
      expect(p.isStageUnlocked(nemea, nemea.stages[1]), isFalse);

      final reward = p.recordBattle(
        reps: 10,
        bestCombo: 5,
        won: true,
        mode: PushupMode.standard,
        labor: nemea,
        stage: nemea.stages[0],
      );
      expect(reward.unlockedStage?.code, '1.2');
      expect(reward.item, isNull);
      expect(p.isStageUnlocked(nemea, nemea.stages[1]), isTrue);
      // Thắng màn thường không hoàn thành kỳ công.
      expect(p.completedLabors, isEmpty);
    });

    test('thắng màn boss 1.8 mới nhận áo choàng và mở Kỳ công 2', () {
      final p = PlayerProgress(
        completedStages: {for (final s in nemea.stages.take(7)) s.id},
      );
      expect(p.isStageUnlocked(nemea, nemea.stages.last), isTrue);
      final reward = p.recordBattle(
        reps: 12,
        bestCombo: 8,
        won: true,
        mode: PushupMode.standard,
        labor: nemea,
        stage: nemea.stages.last,
      );
      expect(reward.item, nemeanPelt);
      expect(reward.unlockedLabor?.id, 'fafnir');
    });

    test('người chơi cũ đã hạ sư tử: mở hết các màn', () {
      final p = PlayerProgress(completedLabors: {'nemea'});
      for (final s in nemea.stages) {
        expect(p.isStageUnlocked(nemea, s), isTrue, reason: s.code);
      }
      expect(p.isStageDone(nemea.stages.last), isTrue);
    });

    test('lưu và đọc lại giữ các màn đã thắng', () {
      final p = PlayerProgress(completedStages: {'nemea_1_1', 'nemea_1_2'});
      final back = PlayerProgress.decode(p.encode());
      expect(back.completedStages, {'nemea_1_1', 'nemea_1_2'});
    });

    test('vàng bị Harpy cướp trừ vào XP thưởng', () {
      final p = PlayerProgress();
      final reward = p.recordBattle(
        reps: 10,
        bestCombo: 5,
        won: true,
        mode: PushupMode.standard,
        labor: nemea,
        stage: nemea.stages.firstWhere((s) => s.enemy == harpy),
        goldStolen: 2,
      );
      // 10 rep × 2 + thắng 25 + lần đầu 40 − 2 túi × 10.
      expect(reward.xp, 65);
      expect(reward.goldLost, 20);
    });
  });

  group('Spartoi: đứng dậy một lần', () {
    test('lần đầu hết máu thì đứng dậy với nửa máu, lần sau mới thắng', () {
      final battle = Battle(enemy: spartoi);
      final events = <BattleEvent>[];
      var t = 0;
      while (battle.status != BattleStatus.won && t < 60000) {
        events.addAll(battle.apply([rep(t, deep: true)]));
        t += 1000;
      }
      final revived = events.whereType<Revived>().toList();
      expect(revived, hasLength(1));
      expect(revived.single.hp, spartoi.maxHp ~/ 2);
      expect(events.whereType<Victory>(), hasLength(1));
    });
  });

  group('Lợn rừng: húc', () {
    test('báo trước rồi húc; không giữ tay thẳng thì bị húc, nó hồi máu', () {
      final battle = Battle(enemy: erymanthianBoar);
      battle.apply([rep(0), rep(1000)]);
      final hpBefore = battle.hp;
      final events = <BattleEvent>[];
      for (var t = 1000; t <= 9500; t += 100) {
        events.addAll(battle.tick(t));
      }
      expect(events.whereType<ChargeWarning>(), hasLength(1));
      final landed = events.whereType<ChargeLanded>().single;
      expect(landed.dodged, isFalse);
      expect(battle.hp, greaterThan(hpBefore));
      expect(battle.combo, 0);
    });

    test('giữ tay thẳng lúc bị húc thì né được', () {
      final battle = Battle(enemy: erymanthianBoar);
      battle.apply([rep(0)]);
      final events = <BattleEvent>[];
      for (var t = 0; t <= 9500; t += 100) {
        events.addAll(battle.tick(t, plankHoldMs: t >= 7000 ? t - 7000 : 0));
      }
      expect(events.whereType<ChargeLanded>().single.dodged, isTrue);
    });

    test('mức lấy đà tăng dần trong lúc báo trước', () {
      final battle = Battle(enemy: erymanthianBoar);
      battle.apply([rep(0)]);
      expect(battle.view(1000).charge, 0);
      expect(battle.view(7900).charge, closeTo(0.56, 0.05));
      expect(battle.view(9000).charge, 1);
    });
  });

  group('Sư tử Nemea pha 2: vồ', () {
    /// Đánh sư tử tới dưới 40% máu bằng rep đều, trả mốc thời gian kế tiếp.
    int toPhaseTwo(Battle battle) {
      var t = 0;
      while (battle.hpFraction > 0.4) {
        battle.apply([rep(t)]);
        t += 1000;
      }
      return t;
    }

    test('máu trên 40% thì không vồ', () {
      final battle = Battle(enemy: nemeanLion);
      battle.apply([rep(0)]);
      final events = <BattleEvent>[];
      for (var t = 0; t <= 30000; t += 100) {
        events.addAll(battle.tick(t));
      }
      expect(events.whereType<PounceWarning>(), isEmpty);
    });

    test('dưới 40%: báo trước rồi vồ; không giữ thì sư tử hồi máu', () {
      final battle = Battle(enemy: nemeanLion);
      final start = toPhaseTwo(battle);
      final hpBefore = battle.hp;
      final events = <BattleEvent>[];
      for (var t = start; t <= start + 4500; t += 100) {
        events.addAll(battle.tick(t));
      }
      expect(events.whereType<PounceWarning>(), hasLength(1));
      final landed = events.whereType<PounceLanded>().single;
      expect(landed.wrestled, isFalse);
      expect(battle.hp, hpBefore + landed.healed);
      expect(battle.combo, 0);
    });

    test('giữ tay thẳng lúc bị vồ thì vật được, gây sát thương', () {
      final battle = Battle(enemy: nemeanLion);
      final start = toPhaseTwo(battle);
      final hpBefore = battle.hp;
      final events = <BattleEvent>[];
      for (var t = start; t <= start + 4500; t += 100) {
        final hold = t - (start + 2000);
        events.addAll(battle.tick(t, plankHoldMs: hold > 0 ? hold : 0));
      }
      expect(events.whereType<PounceLanded>().single.wrestled, isTrue);
      expect(events.whereType<Hit>().single.held, isTrue);
      expect(battle.hp, lessThan(hpBefore));
      // Sân khấu đếm số lần vật để diễn động tác `wrestled`.
      expect(battle.view(start + 4500).wrestles, 1);
    });

    test('da vẫn chặn rep sai form ở pha 2', () {
      final battle = Battle(enemy: nemeanLion);
      final t = toPhaseTwo(battle);
      final events = battle.apply([rep(t, formWarning: true)]);
      expect(events.whereType<Blocked>(), hasLength(1));
    });
  });

  group('Harpy: cướp vàng', () {
    test('tập đều thì không mất vàng', () {
      final battle = Battle(enemy: harpy);
      final events = <BattleEvent>[];
      for (var t = 0; t < 20000; t += 1500) {
        events.addAll(battle.apply([rep(t)]));
        events.addAll(battle.tick(t + 700));
      }
      expect(events.whereType<GoldStolen>(), isEmpty);
    });

    test('nghỉ quá 4 giây thì bị cướp, nghỉ tiếp mất thêm', () {
      final battle = Battle(enemy: harpy);
      battle.apply([rep(0)]);
      final events = <BattleEvent>[];
      for (var t = 0; t <= 9000; t += 100) {
        events.addAll(battle.tick(t));
      }
      expect(events.whereType<GoldStolen>().map((e) => e.total), [1, 2]);
      expect(battle.mechanic<GoldThief>()!.stolen, 2);
    });
  });
}
