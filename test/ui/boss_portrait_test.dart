import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/art/bosses/boss_registry.dart';
import 'package:solo_pushing_up/game/labors.dart';
import 'package:solo_pushing_up/ui/boss_portrait.dart';

void main() {
  testWidgets('mọi kỳ công đều có chân dung boss và vẽ không lỗi', (
    tester,
  ) async {
    final arts = [for (final labor in labors) bossArtFor(labor.enemy)];
    expect(arts, everyElement(isNotNull));

    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            for (final labor in labors) BossPortrait(enemy: labor.enemy),
          ],
        ),
      ),
    );

    expect(find.byType(BossPortrait), findsNWidgets(labors.length));
    expect(tester.takeException(), isNull);
  });

  test('mỗi loại quái có khoá chân dung riêng (bộ đệm không lẫn hình)', () {
    final stages = labors.firstWhere((l) => l.id == 'nemea').allStages;
    final keys = {
      for (final s in stages)
        if (bossArtFor(s.enemy) case final art?) s.enemy.name: art.artKey,
    };
    // Khác loại quái → khác khoá.
    expect(keys.values.toSet().length, keys.length);
  });
}
