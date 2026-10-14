import '../battle.dart';

/// Harpy — cướp vàng: nghỉ quá [stealAfterMs] giữa hai rep thì bị cướp một
/// túi vàng, cứ thêm bấy lâu nữa lại mất thêm (trừ XP thưởng cuối trận).
class GoldThief extends BattleMechanic {
  GoldThief({this.stealAfterMs = 4000});

  final int stealAfterMs;
  int _stolen = 0;
  int? _lastStealMs;

  /// Số túi vàng đã bị cướp trong trận.
  int get stolen => _stolen;

  @override
  void onStrike(BattleHost battle, Strike strike) => _lastStealMs = null;

  @override
  List<BattleEvent> tick(BattleHost battle, int nowMs, int plankHoldMs) {
    final since = _lastStealMs ?? battle.lastHitMs ?? battle.startMs ?? nowMs;
    if (nowMs - since < stealAfterMs) return const [];
    _stolen++;
    _lastStealMs = nowMs;
    return [GoldStolen(nowMs, total: _stolen)];
  }

  @override
  void describe(BattleHost battle, BattleView view, int nowMs, int restEndMs) =>
      view.goldStolen += _stolen;
}
