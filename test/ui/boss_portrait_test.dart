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
        home: Row(children: [for (final art in arts) BossPortrait(art: art!)]),
      ),
    );

    expect(find.byType(BossPortrait), findsNWidgets(labors.length));
    expect(tester.takeException(), isNull);
  });
}
