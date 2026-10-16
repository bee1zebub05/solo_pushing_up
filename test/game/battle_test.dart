import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/game/battle.dart';
import 'package:solo_pushing_up/game/labors.dart';
import 'package:solo_pushing_up/rep/pushup_counter.dart';

CountedRep rep(
  int t, {
  int index = 1,
  bool deep = false,
  bool formWarning = false,
}) => CountedRep(
  timestampMs: t,
  minElbowAngle: deep ? 60 : 85,
  index: index,
  durationMs: 1200,
  descentMs: 600,
  posture: Posture.standard,
  isDeep: deep,
  isFast: false,
  isSlow: false,
  formWarning: formWarning,
);

const dummy = EnemySpec(id: 'dummy', name: 'Bù nhìn', maxHp: 100);

void main() {
  test('mỗi rep gây sát thương, combo tăng dần', () {
    final battle = Battle(enemy: dummy);
    final events = battle.apply([rep(0), rep(1000), rep(2000)]);
    final hits = events.whereType<Hit>().toList();

    expect(hits.map((h) => h.combo), [1, 2, 3]);
    expect(hits.map((h) => h.damage), [10, 11, 12]);
    expect(battle.hp, 100 - 33);
    expect(battle.status, BattleStatus.fighting);
  });

  test('rep chậm không bị tính là nghỉ, vẫn giữ combo', () {
    final battle = Battle(enemy: dummy);
    // Rep sau xuống 3 giây: kết thúc sau rep trước 4,5 giây nhưng chỉ nghỉ 0,5.
    final slow = CountedRep(
      timestampMs: 5500,
      startMs: 1500,
      minElbowAngle: 85,
      index: 2,
      durationMs: 4500,
      descentMs: 3000,
      posture: Posture.standard,
      isDeep: false,
      isFast: false,
      isSlow: true,
    );
    final hits = battle.apply([rep(1000), slow]).cast<Hit>();

    expect(hits.last.combo, 2);
  });

  test('nghỉ quá lâu thì combo về 1', () {
    final battle = Battle(enemy: dummy);
    final events = battle.apply([rep(0), rep(1000), rep(10000)]);

    expect(events.whereType<Hit>().last.combo, 1);
  });

  test('rep sâu là đòn chí mạng (×2)', () {
    final battle = Battle(enemy: dummy);
    final hit = battle.apply([rep(0, deep: true)]).single as Hit;

    expect(hit.critical, isTrue);
    expect(hit.damage, 20);
  });

  test('chế độ Tân binh gây ×0,7 sát thương', () {
    final battle = Battle(enemy: dummy, mode: PushupMode.knee);
    final hit = battle.apply([rep(0)]).single as Hit;

    expect(hit.damage, 7);
  });

  test('rep nông bị chặn và mất combo', () {
    final battle = Battle(enemy: dummy);
    final events = battle.apply([
      rep(0),
      rep(1000),
      const PartialRep(1500, 130),
      rep(2000),
    ]);

    expect(events.whereType<Blocked>(), hasLength(1));
    expect(events.whereType<Hit>().last.combo, 1);
  });

  test('hạ hết máu thì thắng, rep sau đó bị bỏ qua', () {
    final battle = Battle(
      enemy: const EnemySpec(id: 'mouse', name: 'Chuột', maxHp: 25),
    );
    final events = battle.apply([rep(0), rep(500), rep(1000), rep(1500)]);

    expect(battle.status, BattleStatus.won);
    final victory = events.whereType<Victory>().single;
    expect(victory.reps, 3);
    expect(victory.durationMs, 1000);
    expect(events.whereType<Hit>(), hasLength(3));
  });

  test('trận có giới hạn thời gian: hết giờ thì thua', () {
    final battle = Battle(
      enemy: const EnemySpec(
        id: 'dragon',
        name: 'Rồng',
        maxHp: 1000,
        timeLimitMs: 30000,
      ),
    );
    battle.apply([rep(0)]);

    expect(battle.remainingMs(10000), 20000);
    expect(battle.tick(29000), isEmpty);
    expect(battle.tick(30000).single, isA<Defeat>());
    expect(battle.status, BattleStatus.lost);
  });

  group('Rồng Fafnir (giá lạnh)', () {
    test('giữ nhịp đều thì không bị đóng băng', () {
      final battle = Battle(enemy: fafnir);
      final hits = battle.apply([rep(0), rep(1500), rep(3000)]).cast<Hit>();

      expect(hits.any((h) => h.frozen), isFalse);
    });

    test('nghỉ quá 3 giây thì đòn sau bị đóng băng, sát thương giảm nửa', () {
      final battle = Battle(enemy: fafnir);
      final hits = battle.apply([rep(0), rep(5000)]).cast<Hit>().toList();

      expect(hits.last.frozen, isTrue);
      expect(hits.last.damage, 5);
    });

    test('mức lạnh tăng dần khi nghỉ, chạm 1 lúc sắp bị đóng băng', () {
      final battle = Battle(enemy: fafnir)..apply([rep(0)]);

      expect(battle.view(500).cold, 0);
      expect(battle.view(2000).cold, closeTo(0.5, 0.01));
      expect(battle.view(3000).cold, 1);
      expect(Battle(enemy: dummy).view(5000).cold, 0);
    });

    test('kẻ thù khác không có giá lạnh', () {
      final battle = Battle(enemy: dummy);
      final hits = battle.apply([rep(0), rep(5000)]).cast<Hit>().toList();

      expect(hits.last.frozen, isFalse);
      expect(hits.last.damage, 10);
    });
  });

  group('Yamata no Orochi (8 đầu)', () {
    test('chuỗi rep liền mạch chém đứt một đầu, không tràn sang đầu sau', () {
      final battle = Battle(enemy: orochi);
      // 10 + 11 + 12 = 33, rep thứ tư chỉ gây 7 (còn lại của đầu 40 HP).
      final events = battle.apply([rep(0), rep(1000), rep(2000), rep(3000)]);

      expect(events.whereType<Hit>().last.damage, 7);
      expect(events.whereType<HeadSevered>().single.headsLeft, 7);
      expect(battle.headsLeft, 7);
      expect(battle.headHp, 40);
    });

    test('đứt combo thì đầu đang chém hồi đầy máu', () {
      final battle = Battle(enemy: orochi);
      battle.apply([rep(0), rep(1000)]);
      expect(battle.headHp, 40 - 21);

      final events = battle.apply([rep(10000)]);
      expect(events.first, isA<HeadRegrown>());
      expect((events.first as HeadRegrown).healed, 21);
      expect(battle.headHp, 40 - 10);
    });

    test('rep nông cũng làm đứt combo và đầu mọc lại', () {
      final battle = Battle(enemy: orochi);
      battle.apply([rep(0)]);
      final events = battle.apply([const PartialRep(500, 130)]);

      expect(events.whereType<HeadRegrown>(), hasLength(1));
      expect(battle.headHp, 40);
    });

    test('đầu đã chém đứt không mọc lại', () {
      final battle = Battle(enemy: orochi);
      battle.apply([rep(0), rep(1000), rep(2000), rep(3000)]);
      final events = battle.apply([rep(20000)]);

      expect(events.whereType<HeadRegrown>(), isEmpty);
      expect(battle.headsLeft, 7);
    });

    test('chém đủ 8 đầu thì thắng', () {
      final battle = Battle(enemy: orochi);
      final reps = [for (var i = 0; i < 40; i++) rep(i * 1000)];
      final events = battle.apply(reps);

      expect(battle.status, BattleStatus.won);
      expect(battle.headsLeft, 0);
      expect(battle.headHp, 0);
      expect(events.whereType<HeadSevered>(), hasLength(7));
      expect(events.whereType<HeadRegrown>(), isEmpty);
    });
  });

  group('Sư tử Nemea (da không xuyên thủng)', () {
    test('rep đúng form gây sát thương', () {
      final battle = Battle(enemy: nemeanLion);
      expect(battle.apply([rep(0)]).single, isA<Hit>());
    });

    test('rep nông bị chặn với lời nhắc xuống sâu hơn', () {
      final battle = Battle(enemy: nemeanLion);
      final blocked =
          battle.apply([const PartialRep(0, 125)]).single as Blocked;

      expect(blocked.reason, contains('sâu hơn'));
      expect(battle.hp, nemeanLion.maxHp);
    });

    test('rep thân chưa thẳng cũng bị chặn hoàn toàn', () {
      final battle = Battle(enemy: nemeanLion);
      final events = battle.apply([rep(0, formWarning: true)]);

      expect(events.single, isA<Blocked>());
      expect(battle.hp, nemeanLion.maxHp);
    });

    test('kẻ thù thường: thân chưa thẳng chỉ giảm nửa sát thương', () {
      final battle = Battle(enemy: dummy);
      final hit = battle.apply([rep(0, formWarning: true)]).single as Hit;

      expect(hit.damage, 5);
    });
  });

  test('một kẻ thù ghép được nhiều cơ chế', () {
    const frostLion = EnemySpec(
      id: 'frost_lion',
      name: 'Sư tử băng',
      maxHp: 100,
      mechanics: [ImpenetrableHide.new, FreezingCold.new],
    );
    final battle = Battle(enemy: frostLion);

    expect(battle.apply([rep(0, formWarning: true)]).single, isA<Blocked>());
    final hits = battle.apply([rep(1000), rep(6000)]).cast<Hit>().toList();
    expect(hits.last.frozen, isTrue);
    // Mỗi trận có bản cơ chế riêng: trận mới chưa bị đóng băng.
    expect(Battle(enemy: frostLion).view(5000).cold, 0);
  });
}
