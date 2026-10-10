import '../../game/battle.dart';
import '../../game/labors.dart';
import '../battle_stage.dart';
import 'fafnir_boss.dart';
import 'nemea_boss.dart';
import 'orochi_boss.dart';
import 'thuy_tinh_boss.dart';

/// Hình boss cho từng kẻ thù đã vẽ; null = chưa có hình (dùng biểu tượng tạm).
BossArt? bossArtFor(EnemySpec enemy) {
  if (enemy == nemeanLion) return NemeaBossArt();
  if (enemy == fafnir) return FafnirBossArt();
  if (enemy == orochi) return OrochiBossArt();
  if (enemy == thuyTinh) return ThuyTinhBossArt();
  return null;
}
