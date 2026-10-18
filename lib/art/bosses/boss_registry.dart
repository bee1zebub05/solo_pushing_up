import '../../game/battle.dart';
import '../battle_stage.dart';
import 'dummy_art.dart';
import 'fafnir_boss.dart';
import 'nemea_boss.dart';
import 'nemea_monster_art.dart';
import 'orochi_boss.dart';
import 'shuten_boss.dart';
import 'tengu_boss.dart';
import 'thuy_tinh_boss.dart';

/// Hình của từng kẻ thù đã vẽ, theo [EnemySpec.id]. Mỗi lần gọi tạo bản
/// mới vì hình giữ tài nguyên riêng (sprite, shader) và được trả khi rời trận.
final Map<String, BossArt Function()> _bossArts = {
  'nemean_lion': NemeaBossArt.new,
  'stymphalian_flock': () => NemeaMonsterArt(NemeaMonster.birds),
  'stymphalian_swarm': () => NemeaMonsterArt(NemeaMonster.swarm),
  'spartoi': () => NemeaMonsterArt(NemeaMonster.spartoi),
  'stone_soldier': () => NemeaMonsterArt(NemeaMonster.stone),
  'erymanthian_boar': () => NemeaMonsterArt(NemeaMonster.boar),
  'harpy': () => NemeaMonsterArt(NemeaMonster.harpy),
  'spartoi_pack': () => NemeaMonsterArt(NemeaMonster.pack),
  'young_hydra': () => NemeaMonsterArt(NemeaMonster.hydra),
  'stone_guard': () => NemeaMonsterArt(NemeaMonster.guard),
  'fafnir': FafnirBossArt.new,
  'orochi': OrochiBossArt.new,
  // Chương Nhật (rules/cottruyen.md mục 3b.5): hình đã có, chưa có EnemySpec
  // / màn — kỳ công Izumo (Shuten-dōji) và Heian (Sutoku) dùng đúng id này.
  'shuten_doji': ShutenBossArt.new,
  'tengu_sutoku': TenguBossArt.new,
  'thuy_tinh': ThuyTinhBossArt.new,
  'training_dummy': TrainingDummyArt.new,
};

/// Hình boss cho kẻ thù đã vẽ; null = chưa có hình (dùng biểu tượng tạm).
BossArt? bossArtFor(EnemySpec enemy) => _bossArts[enemy.id]?.call();
