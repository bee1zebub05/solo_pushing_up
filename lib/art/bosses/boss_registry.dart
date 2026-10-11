import '../../game/battle.dart';
import '../../game/labors.dart';
import '../battle_stage.dart';
import 'dummy_art.dart';
import 'fafnir_boss.dart';
import 'nemea_boss.dart';
import 'nemea_monster_art.dart';
import 'orochi_boss.dart';
import 'thuy_tinh_boss.dart';

/// Hình boss cho từng kẻ thù đã vẽ; null = chưa có hình (dùng biểu tượng tạm).
BossArt? bossArtFor(EnemySpec enemy) {
  if (enemy == nemeanLion) return NemeaBossArt();
  final monster = switch (enemy) {
    stymphalianFlock => NemeaMonster.birds,
    stymphalianSwarm => NemeaMonster.swarm,
    spartoi => NemeaMonster.spartoi,
    stoneSoldier => NemeaMonster.stone,
    erymanthianBoar => NemeaMonster.boar,
    harpy => NemeaMonster.harpy,
    spartoiPack => NemeaMonster.pack,
    youngHydra => NemeaMonster.hydra,
    stoneGuard => NemeaMonster.guard,
    _ => null,
  };
  if (monster != null) return NemeaMonsterArt(monster);
  if (enemy == fafnir) return FafnirBossArt();
  if (enemy == orochi) return OrochiBossArt();
  if (enemy == thuyTinh) return ThuyTinhBossArt();
  if (enemy == trainingDummy) return TrainingDummyArt();
  return null;
}
