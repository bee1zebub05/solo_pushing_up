import '../battle.dart';

/// Rồng Fafnir — giá lạnh: nghỉ quá [freezeAfterMs] giữa hai rep thì đòn
/// sau bị đóng băng, yếu đi (dạy giữ nhịp tập đều — Kỳ công 2).
class FreezingCold extends BattleMechanic {
  FreezingCold({this.freezeAfterMs = 3000, this.frozenMultiplier = 0.5});

  final int freezeAfterMs;
  final double frozenMultiplier;

  @override
  void onStrike(BattleHost battle, Strike strike) {
    final rest = strike.restMs;
    if (rest == null || rest <= freezeAfterMs) return;
    strike
      ..frozen = true
      ..damage *= frozenMultiplier;
  }

  /// Mức lạnh 0–1: bắt đầu tăng sau 1/3 thời gian cho phép nghỉ, chạm 1
  /// đúng lúc đòn sau sẽ bị đóng băng. Để sân khấu báo trước bằng hình
  /// (nhân vật đóng băng dần).
  @override
  void describe(BattleHost battle, BattleView view, int nowMs, int restEndMs) {
    final last = battle.lastHitMs;
    if (last == null || battle.status != BattleStatus.fighting) return;
    final start = freezeAfterMs / 3;
    view.cold = ((restEndMs - last - start) / (freezeAfterMs - start)).clamp(
      0.0,
      1.0,
    );
  }
}
