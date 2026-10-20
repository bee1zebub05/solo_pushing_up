import '../../rep/pushup_counter.dart';
import '../battle.dart';

/// Sư tử Nemea pha 2 — vồ: máu dưới [phaseAt] thì cứ [pounceEveryMs] sư tử
/// lại báo trước [warnMs] rồi vồ. Giữ tay thẳng (plank) đủ [holdMs] lúc bị
/// vồ thì vật được nó (như Hercules siết cổ sư tử): một đòn [wrestleDamage]
/// sát thương. Không giữ thì nó hồi [healFraction] máu và mất combo.
///
/// Pha 2 trộn hai kỹ năng đã dạy riêng ở chương 1: đúng form (lính đá, da
/// sư tử pha 1) và giữ tay thẳng khi bị lao tới (lợn rừng).
class LionPounce extends BattleMechanic {
  LionPounce({
    this.phaseAt = 0.4,
    this.pounceEveryMs = 10000,
    this.firstPounceMs = 4000,
    this.warnMs = 2500,
    this.holdMs = 800,
    this.wrestleDamage = 30,
    this.healFraction = 0.08,
  });

  /// Tỉ lệ máu bắt đầu pha 2 (khớp lúc sân khấu diễn nổi giận).
  final double phaseAt;
  final int pounceEveryMs;

  /// Cú vồ đầu tiên sau khi vào pha 2 (đủ dài để báo trước trọn vẹn).
  final int firstPounceMs;
  final int warnMs;
  final int holdMs;
  final int wrestleDamage;
  final double healFraction;

  int? _pounceAtMs;
  bool _warned = false;
  int _wrestles = 0;

  @override
  List<BattleEvent> tick(BattleHost battle, int nowMs, int plankHoldMs) {
    if (battle.hp <= 0) return const [];
    var at = _pounceAtMs;
    if (at == null) {
      if (battle.hp > battle.enemy.maxHp * phaseAt) return const [];
      at = _pounceAtMs = nowMs + firstPounceMs;
    }
    final out = <BattleEvent>[];
    if (!_warned && at - nowMs <= warnMs) {
      _warned = true;
      out.add(PounceWarning(nowMs, inMs: at - nowMs));
    }
    if (nowMs < at) return out;

    _pounceAtMs = nowMs + pounceEveryMs;
    _warned = false;
    if (plankHoldMs >= holdMs) {
      _wrestles++;
      out.add(PounceLanded(nowMs, wrestled: true));
      out.addAll(
        battle.strike(
          nowMs,
          wrestleDamage *
              (battle.mode == PushupMode.knee ? battle.rules.kneeMultiplier : 1),
          (dealt) => Hit(
            nowMs,
            damage: dealt,
            critical: true,
            combo: battle.combo,
            held: true,
          ),
        ),
      );
      return out;
    }
    final healed = battle.heal((battle.enemy.maxHp * healFraction).round());
    battle.breakCombo();
    out.add(PounceLanded(nowMs, wrestled: false, healed: healed));
    return out;
  }

  /// Tiến độ lấy đà 0–1 (1 = vồ ngay), như lợn rừng ([BattleView.charge]).
  @override
  void describe(BattleHost battle, BattleView view, int nowMs, int restEndMs) {
    view.wrestles = _wrestles;
    final at = _pounceAtMs;
    if (at == null || battle.status != BattleStatus.fighting) return;
    final left = at - nowMs;
    if (left > warnMs) return;
    view.charge = (1 - left / warnMs).clamp(0.0, 1.0);
  }
}
