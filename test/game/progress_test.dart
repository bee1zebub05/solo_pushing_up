import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/game/labors.dart';
import 'package:solo_pushing_up/game/progress.dart';
import 'package:solo_pushing_up/rep/pushup_counter.dart';

void main() {
  final nemea = labors.firstWhere((l) => l.id == 'nemea');
  final fafnirLabor = labors.firstWhere((l) => l.id == 'fafnir');

  test('chỉ kỳ công 1 mở lúc đầu', () {
    final progress = PlayerProgress();

    expect(progress.isUnlocked(nemea), isTrue);
    expect(progress.isUnlocked(fafnirLabor), isFalse);
  });

  test('thắng lần đầu: XP, vật phẩm, mở kỳ công tiếp theo', () {
    final progress = PlayerProgress();
    final reward = progress.recordBattle(
      reps: 12,
      bestCombo: 8,
      won: true,
      mode: PushupMode.standard,
      labor: nemea,
    );

    // 12 rep × 2 + thắng 50 + lần đầu 100.
    expect(reward.xp, 174);
    expect(reward.item, 'Áo choàng da sư tử');
    expect(reward.unlockedLabor?.id, 'fafnir');
    expect(progress.isUnlocked(fafnirLabor), isTrue);
    expect(progress.items, ['Áo choàng da sư tử']);
    expect(progress.bestCombo, 8);
  });

  test('mở khoá theo thứ tự danh sách, không theo số kỳ công', () {
    final orochiLabor = labors.firstWhere((l) => l.id == 'orochi');
    final progress = PlayerProgress();
    for (final labor in [nemea, fafnirLabor]) {
      expect(progress.isUnlocked(orochiLabor), isFalse);
      final reward = progress.recordBattle(
        reps: 20,
        bestCombo: 10,
        won: true,
        mode: PushupMode.standard,
        labor: labor,
      );
      if (labor == fafnirLabor) expect(reward.unlockedLabor, orochiLabor);
    }

    expect(progress.isUnlocked(orochiLabor), isTrue);
  });

  test('thắng lại không nhận vật phẩm lần nữa', () {
    final progress = PlayerProgress();
    for (var i = 0; i < 2; i++) {
      progress.recordBattle(
        reps: 10,
        bestCombo: 5,
        won: true,
        mode: PushupMode.standard,
        labor: nemea,
      );
    }

    expect(progress.items, hasLength(1));
  });

  test('thua vẫn được XP theo số rep', () {
    final progress = PlayerProgress();
    final reward = progress.recordBattle(
      reps: 7,
      bestCombo: 3,
      won: false,
      mode: PushupMode.standard,
    );

    expect(reward.xp, 14);
    expect(progress.totalReps, 7);
  });

  test('chế độ Tân binh nhận ×0,7 XP', () {
    final progress = PlayerProgress();
    final reward = progress.recordBattle(
      reps: 10,
      bestCombo: 3,
      won: false,
      mode: PushupMode.knee,
    );

    expect(reward.xp, 14);
  });

  test('lên nhiều cấp một lúc, XP thừa giữ lại', () {
    final progress = PlayerProgress();
    // Cần 100 (cấp 1→2) + 150 (cấp 2→3) = 250.
    final reward = progress.recordBattle(
      reps: 130,
      bestCombo: 30,
      won: false,
      mode: PushupMode.standard,
    );

    expect(reward.levelsGained, 2);
    expect(progress.level, 3);
    expect(progress.xp, 260 - 250);
  });

  test('lưu và đọc lại giữ nguyên tiến trình', () {
    final progress = PlayerProgress()
      ..recordBattle(
        reps: 20,
        bestCombo: 9,
        won: true,
        mode: PushupMode.standard,
        labor: nemea,
      );
    final restored = PlayerProgress.decode(progress.encode());

    expect(restored.level, progress.level);
    expect(restored.xp, progress.xp);
    expect(restored.totalReps, 20);
    expect(restored.bestCombo, 9);
    expect(restored.completedLabors, {'nemea'});
    expect(restored.items, ['Áo choàng da sư tử']);
  });
}
