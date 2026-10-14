import '../battle.dart';

/// Lợn rừng Erymanthus — lao húc: cứ [chargeEveryMs] lại báo trước
/// [chargeWarnMs] rồi húc; giữ tay thẳng (plank) đủ [chargeDodgeHoldMs] lúc
/// bị húc thì né được, không thì nó hồi [chargeHealFraction] máu và mất combo.
class ChargingBoar extends BattleMechanic {
  ChargingBoar({
    this.chargeEveryMs = 9000,
    this.chargeWarnMs = 2500,
    this.chargeDodgeHoldMs = 800,
    this.chargeHealFraction = 0.1,
  });

  final int chargeEveryMs;
  final int chargeWarnMs;
  final int chargeDodgeHoldMs;
  final double chargeHealFraction;

  int? _chargeAtMs;
  bool _warned = false;

  @override
  void onStart(BattleHost battle, int t) => _chargeAtMs = t + chargeEveryMs;

  @override
  List<BattleEvent> tick(BattleHost battle, int nowMs, int plankHoldMs) {
    final at = _chargeAtMs;
    if (at == null) return const [];
    final out = <BattleEvent>[];
    if (!_warned && at - nowMs <= chargeWarnMs) {
      _warned = true;
      out.add(ChargeWarning(nowMs, inMs: at - nowMs));
    }
    if (nowMs >= at) {
      final dodged = plankHoldMs >= chargeDodgeHoldMs;
      var healed = 0;
      if (!dodged) {
        healed = battle.heal((battle.enemy.maxHp * chargeHealFraction).round());
        battle.breakCombo();
      }
      out.add(ChargeLanded(nowMs, dodged: dodged, healed: healed));
      _chargeAtMs = nowMs + chargeEveryMs;
      _warned = false;
    }
    return out;
  }

  /// Tiến độ báo trước cú húc 0–1 (1 = húc ngay), 0 nếu chưa tới lúc báo.
  /// Để sân khấu vẽ lợn rừng lấy đà.
  @override
  void describe(BattleHost battle, BattleView view, int nowMs, int restEndMs) {
    final at = _chargeAtMs;
    if (at == null || battle.status != BattleStatus.fighting) return;
    final left = at - nowMs;
    if (left > chargeWarnMs) return;
    view.charge = (1 - left / chargeWarnMs).clamp(0.0, 1.0);
  }
}
