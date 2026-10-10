import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/game/battle.dart';
import 'package:solo_pushing_up/game/labors.dart';
import 'package:solo_pushing_up/rep/pushup_counter.dart';
import 'package:solo_pushing_up/sim/pose_simulator.dart';
import 'package:solo_pushing_up/sim/synthetic_pushup.dart';

/// Chạy một kịch bản giả lập qua bộ đếm thật rồi vào trận.
List<BattleEvent> fight(String scenario, EnemySpec enemy) {
  final counter = PushupCounter();
  final battle = Battle(enemy: enemy);
  final events = <BattleEvent>[];
  final s = simScenarios.firstWhere((s) => s.name == scenario);
  for (final frame in s.frames()) {
    events.addAll(battle.apply(counter.update(frame).events));
  }
  return events;
}

void main() {
  test('rep chậm liên tiếp giữ được combo (không bị coi là nghỉ)', () {
    final hits = fight('Chậm ×3', fafnir).whereType<Hit>().toList();

    expect(hits, hasLength(3));
    expect(hits.last.combo, 3);
    expect(hits.any((h) => h.frozen), isFalse);
  });

  group('cân bằng Thuỷ Tinh', () {
    test('tập đều (nghỉ 0,5 giây giữa các rep) thì thắng', () {
      final battle = floodSession(restMs: 500);

      expect(battle.status, BattleStatus.won);
    });

    test('nghỉ 6 giây giữa các rep thì nước ngập', () {
      final battle = floodSession(restMs: 6000, seconds: 200);

      expect(battle.status, BattleStatus.lost);
      expect(battle.defeatReason, DefeatReason.flooded);
    });
  });

  test('Orochi: chuỗi rep chuẩn chém được đầu, không mọc lại', () {
    final events = fight('Chuẩn ×10', orochi);

    expect(events.whereType<HeadSevered>(), isNotEmpty);
    expect(events.whereType<HeadRegrown>(), isEmpty);
  });
}

/// Trận Thuỷ Tinh với nhịp rep đều: mỗi rep 1,5 giây rồi nghỉ [restMs].
Battle floodSession({required int restMs, int seconds = 150}) {
  final track = AngleTrack()..hold(170, 1000);
  while (track.durationMs < seconds * 1000) {
    track
      ..rep()
      ..hold(170, restMs);
  }
  final counter = PushupCounter();
  final battle = Battle(enemy: thuyTinh);
  for (final frame in track.frames()) {
    final snapshot = counter.update(frame);
    battle
      ..apply(snapshot.events)
      ..tick(frame.timestampMs, plankHoldMs: snapshot.plankHoldMs);
    if (battle.status == BattleStatus.won ||
        battle.status == BattleStatus.lost) {
      break;
    }
  }
  return battle;
}
