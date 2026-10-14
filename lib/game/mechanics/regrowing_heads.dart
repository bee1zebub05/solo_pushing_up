import '../battle.dart';

/// Yamata no Orochi / Hydra — đầu mọc lại: đứt combo thì đầu đang chém hồi
/// đầy máu (dạy giữ chuỗi rep — Kỳ công 5). Dùng cùng [EnemySpec.heads] > 1;
/// phần "không tràn sát thương sang đầu sau" do [Battle] lo.
class RegrowingHeads extends BattleMechanic {
  @override
  List<BattleEvent> onComboBroken(BattleHost battle, int t) {
    if (battle.hp == 0) return const [];
    final healed = battle.heal(battle.enemy.headMaxHp - battle.headHp);
    if (healed <= 0) return const [];
    return [HeadRegrown(t, healed: healed)];
  }
}
