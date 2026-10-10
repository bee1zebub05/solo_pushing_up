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
  });

  final int xp;
  final int levelsGained;

  /// Vật phẩm nhận lần đầu thắng kỳ công.
  final String? item;

  /// Kỳ công vừa được mở khoá.
  final Labor? unlockedLabor;
}

/// Tiến trình người chơi, lưu bền (JSON). Số liệu tạm.
class PlayerProgress {
  PlayerProgress({
    this.xp = 0,
    this.level = 1,
    this.totalReps = 0,
    this.bestCombo = 0,
    Set<String>? completedLabors,
    List<String>? items,
  }) : completedLabors = completedLabors ?? {},
       items = items ?? [];

  /// XP trong cấp hiện tại.
  int xp;
  int level;
  int totalReps;
  int bestCombo;
  final Set<String> completedLabors;
  final List<String> items;

  static const xpPerRep = 2;
  static const victoryXp = 50;
  static const firstClearXp = 100;

  /// XP cần để lên cấp tiếp theo từ [level].
  static int xpToNext(int level) => 100 + 50 * (level - 1);

  /// Kỳ công đã mở: kỳ công 1 luôn mở, kỳ công sau mở khi thắng kỳ trước.
  bool isUnlocked(Labor labor) => switch (previousLabor(labor)) {
    null => true,
    final prev => completedLabors.contains(prev.id),
  };

  /// Ghi nhận kết quả một trận (thắng hay thua đều được XP theo rep).
  BattleReward recordBattle({
    required int reps,
    required int bestCombo,
    required bool won,
    required PushupMode mode,
    Labor? labor,
  }) {
    final firstClear =
        won && labor != null && !completedLabors.contains(labor.id);
    var gained = reps * xpPerRep + (won ? victoryXp : 0);
    if (firstClear) gained += firstClearXp;
    // Tân binh (chống gối) nhận ×0,7 (rules/cottruyen.md 1b).
    if (mode == PushupMode.knee) gained = (gained * 0.7).round();

    totalReps += reps;
    this.bestCombo = math.max(this.bestCombo, bestCombo);

    xp += gained;
    var levels = 0;
    while (xp >= xpToNext(level)) {
      xp -= xpToNext(level);
      level++;
      levels++;
    }

    String? item;
    Labor? unlocked;
    if (firstClear) {
      completedLabors.add(labor.id);
      item = labor.reward;
      items.add(labor.reward);
      unlocked = nextLabor(labor);
    }
    return BattleReward(
      xp: gained,
      levelsGained: levels,
      item: item,
      unlockedLabor: unlocked,
    );
  }

  Map<String, Object?> toJson() => {
    'xp': xp,
    'level': level,
    'totalReps': totalReps,
    'bestCombo': bestCombo,
    'completedLabors': completedLabors.toList()..sort(),
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
    items: [...((json['items'] as List<Object?>?) ?? const []).cast<String>()],
  );

  String encode() => jsonEncode(toJson());

  static PlayerProgress decode(String source) =>
      PlayerProgress.fromJson(jsonDecode(source) as Map<String, Object?>);
}
