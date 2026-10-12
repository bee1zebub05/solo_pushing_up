import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/art/battle_stage.dart';
import 'package:solo_pushing_up/art/bosses/fafnir_boss.dart';
import 'package:solo_pushing_up/art/bosses/nemea_boss.dart';
import 'package:solo_pushing_up/art/bosses/orochi_boss.dart';
import 'package:solo_pushing_up/art/bosses/thuy_tinh_boss.dart';

/// Chuyển động chung mọi boss trên sân khấu Flame thật: mở màn, đòn 3 pha,
/// trúng đòn có ánh sáng động, pha nổi giận, thắng. ART_PREVIEW=1 thì chụp
/// PNG vào build/art_preview/motion_*.png.
void main() {
  final bosses = <String, BossArt Function()>{
    'nemea': NemeaBossArt.new,
    'fafnir': FafnirBossArt.new,
    'orochi': OrochiBossArt.new,
    'thuy_tinh': ThuyTinhBossArt.new,
  };
  for (final MapEntry(key: name, value: make) in bosses.entries) {
    testWidgets('chuyển động sân khấu: $name', (tester) async {
      final game = BattleStageGame(boss: make());
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 800,
                height: 520,
                child: GameWidget(game: game),
              ),
            ),
          ),
        ),
      );

      Future<void> shot(String label) async {
        if (Platform.environment['ART_PREVIEW'] != '1') return;
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('build/art_preview/motion_${name}_$label.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }

      Future<void> run(int ms) async {
        for (var t = 0; t < ms; t += 16) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      }

      // Mở màn: vòng sáng đang mở.
      await run(300);
      await shot('intro');
      game.updatePlayer(elbowAngle: 160);
      // Đòn đầu của boss đến ở giây 1,5: giữa pha lấy đà và lúc ra đòn.
      await run(1500);
      await shot('windup');
      await run(300);
      await shot('strike');
      await run(600);

      game.hit(critical: true);
      await run(300);
      await shot('impact_light');
      await run(400);

      game.battle.bossHp = 0.15;
      await run(500);
      await shot('rage');

      game.victory();
      await run(150);
      await shot('victory_flash');
      await run(1200);
      await shot('victory');
    });
  }
}
