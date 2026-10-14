import '../battle.dart';

/// Spartoi — mọc lại từ răng rồng: lần đầu bị hạ thì đứng dậy với
/// [reviveFraction] máu (dạy đánh dứt điểm — Kỳ công 1).
class ReviveOnce extends BattleMechanic {
  ReviveOnce({this.reviveFraction = 0.5});

  final double reviveFraction;
  bool _revived = false;

  @override
  List<BattleEvent>? onKnockedOut(BattleHost battle, int t) {
    if (_revived) return null;
    _revived = true;
    battle.setHp((battle.enemy.maxHp * reviveFraction).round());
    return [Revived(t, hp: battle.hp)];
  }

  @override
  void describe(BattleHost battle, BattleView view, int nowMs, int restEndMs) {
    if (_revived) view.revives++;
  }
}
