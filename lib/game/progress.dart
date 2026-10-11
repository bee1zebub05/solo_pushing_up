import 'dart:convert';
import 'dart:math' as math;

import '../rep/pushup_counter.dart';
import 'labors.dart';

/// Phần thưởng sau một trận.
class BattleReward {
  const BattleReward({
    required this.xp,
    required this.levelsGained,
    this.item,
    this.unlockedLabor,
    this.unlockedStage,
    this.goldLost = 0,
  });

  final int xp;
  final int levelsGained;

  /// Vật phẩm nhận lần đầu thắng kỳ công.
  final String? item;

  /// Kỳ công vừa được mở khoá.
  final Labor? unlockedLabor;

  /// Màn vừa được mở khoá trong cùng kỳ công.
  final Stage? unlockedStage;

  /// XP bị Harpy cướp mất.
  final int goldLost;
}

/// Tiến trình người chơi, lưu bền (JSON). Số liệu tạm.
class PlayerProgress {
  PlayerProgress({
    this.xp = 0,
    this.level = 1,
    this.totalReps = 0,
    this.bestCombo = 0,
    Set<String>? completedLabors,
    Set<String>? completedStages,
    List<String>? items,
  }) : completedLabors = completedLabors ?? {},
       completedStages = completedStages ?? {},
       items = items ?? [];

  /// XP trong cấp hiện tại.
  int xp;
  int level;
  int totalReps;
  int bestCombo;
  final Set<String> completedLabors;

  /// Các màn đã thắng (id của [Stage]).
  final Set<String> completedStages;
  final List<String> items;

  static const xpPerRep = 2;
  static const victoryXp = 50;
  static const firstClearXp = 100;
  static const stageClearXp = 40;

  /// Mỗi túi vàng Harpy cướp làm mất bấy nhiêu XP thưởng.
  static const xpPerGold = 10;

  /// XP cần để lên cấp tiếp theo từ [level].
  static int xpToNext(int level) => 100 + 50 * (level - 1);

  /// Kỳ công đã mở: kỳ công 1 luôn mở, kỳ công sau mở khi thắng kỳ trước.
  bool isUnlocked(Labor labor) => switch (previousLabor(labor)) {
    null => true,
    final prev => completedLabors.contains(prev.id),
  };

  /// Màn đã thắng: màn boss tính cả khi kỳ công đã hoàn thành từ trước
  /// (người chơi cũ hạ boss trước khi có các màn).
  bool isStageDone(Stage stage) =>
      completedStages.contains(stage.id) || completedLabors.contains(stage.id);

  /// Màn đã mở: kỳ công phải mở; màn đầu mở sẵn, màn sau mở khi thắng màn
  /// trước. Kỳ công đã hoàn thành thì mở hết.
  bool isStageUnlocked(Labor labor, Stage stage) {
    if (!isUnlocked(labor)) return false;
    if (completedLabors.contains(labor.id)) return true;
    final stages = labor.allStages;
    final i = stages.indexWhere((s) => s.id == stage.id);
    return i <= 0 || isStageDone(stages[i - 1]);
  }

  /// Ghi nhận kết quả một trận (thắng hay thua đều được XP theo rep).
  BattleReward recordBattle({
    required int reps,
    required int bestCombo,
    required bool won,
    required PushupMode mode,
    Labor? labor,
    Stage? stage,
    int goldStolen = 0,
  }) {
    // Màn thường (không phải màn boss) của một kỳ công.
    final stages = labor?.allStages ?? const <Stage>[];
    final bossStage =
        stage == null || stages.isEmpty || stage.id == stages.last.id;
    if (labor != null && stage != null && !bossStage) {
      return _recordStage(
        labor: labor,
        stage: stage,
        reps: reps,
        bestCombo: bestCombo,
        won: won,
        mode: mode,
        goldStolen: goldStolen,
      );
    }
    final firstClear =
        won && labor != null && !completedLabors.contains(labor.id);
    var gained = reps * xpPerRep + (won ? victoryXp : 0);
    if (firstClear) gained += firstClearXp;
    final goldLost = math.min(gained, goldStolen * xpPerGold);
    gained -= goldLost;
    // Tân binh (chống gối) nhận ×0,7 (rules/cottruyen.md 1b).
    if (mode == PushupMode.knee) gained = (gained * 0.7).round();

    totalReps += reps;
    this.bestCombo = math.max(this.bestCombo, bestCombo);

    final levels = _addXp(gained);
    String? item;
    Labor? unlocked;
    if (firstClear) {
      completedLabors.add(labor.id);
      completedStages.add(labor.id);
      item = labor.reward;
      items.add(labor.reward);
      unlocked = nextLabor(labor);
    }
    return BattleReward(
      xp: gained,
      levelsGained: levels,
      item: item,
      unlockedLabor: unlocked,
      goldLost: goldLost,
    );
  }

  BattleReward _recordStage({
    required Labor labor,
    required Stage stage,
    required int reps,
    required int bestCombo,
    required bool won,
    required PushupMode mode,
    required int goldStolen,
  }) {
    final firstClear = won && !completedStages.contains(stage.id);
    var gained = reps * xpPerRep + (won ? victoryXp ~/ 2 : 0);
    if (firstClear) gained += stageClearXp;
    if (mode == PushupMode.knee) gained = (gained * 0.7).round();
    final goldLost = math.min(gained, goldStolen * xpPerGold);
    gained -= goldLost;
    totalReps += reps;
    this.bestCombo = math.max(this.bestCombo, bestCombo);
    final levels = _addXp(gained);
    Stage? unlocked;
    if (firstClear) {
      completedStages.add(stage.id);
      final stages = labor.allStages;
      final i = stages.indexWhere((s) => s.id == stage.id);
      if (i >= 0 && i + 1 < stages.length) unlocked = stages[i + 1];
    }
    return BattleReward(
      xp: gained,
      levelsGained: levels,
      unlockedStage: unlocked,
      goldLost: goldLost,
    );
  }

  int _addXp(int gained) {
    xp += gained;
    var levels = 0;
    while (xp >= xpToNext(level)) {
      xp -= xpToNext(level);
      level++;
      levels++;
    }
    return levels;
  }

  Map<String, Object?> toJson() => {
    'xp': xp,
    'level': level,
    'totalReps': totalReps,
    'bestCombo': bestCombo,
    'completedLabors': completedLabors.toList()..sort(),
    'completedStages': completedStages.toList()..sort(),
    'items': items,
  };

  factory PlayerProgress.fromJson(Map<String, Object?> json) => PlayerProgress(
    xp: (json['xp'] as int?) ?? 0,
    level: (json['level'] as int?) ?? 1,
    totalReps: (json['totalReps'] as int?) ?? 0,
    bestCombo: (json['bestCombo'] as int?) ?? 0,
    completedLabors: {
      ...((json['completedLabors'] as List<Object?>?) ?? const [])
          .cast<String>(),
    },
    completedStages: {
      ...((json['completedStages'] as List<Object?>?) ?? const [])
          .cast<String>(),
    },
    items: [...((json['items'] as List<Object?>?) ?? const []).cast<String>()],
  );

  String encode() => jsonEncode(toJson());

  static PlayerProgress decode(String source) =>
      PlayerProgress.fromJson(jsonDecode(source) as Map<String, Object?>);
}
