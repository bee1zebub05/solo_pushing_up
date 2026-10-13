import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/art/battle_stage.dart';
import 'package:solo_pushing_up/art/bosses/nemea_boss.dart';

/// Chạy sân khấu Flame thật: đòn trúng, đòn bị chặn, thắng + khoác áo.
/// Kiểm tra các hiệu ứng không lỗi; ART_PREVIEW=1 thì chụp PNG vào
/// build/art_preview/.
void main() {
  testWidgets('sân khấu Nemea: đòn đánh, BỊ CHẶN, thắng và trao áo', (
    tester,
  ) async {
    final game = BattleStageGame(boss: NemeaBossArt());
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
    await tester.pump(const Duration(milliseconds: 100));
    game.updatePlayer(elbowAngle: 100);

    Future<void> shot(String name) async {
      if (Platform.environment['ART_PREVIEW'] != '1') return;
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('build/art_preview/$name.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    Future<void> run(Duration d) async {
      for (
        var t = Duration.zero;
        t < d;
        t += const Duration(milliseconds: 16)
      ) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    game.hit(critical: true);
    await run(const Duration(milliseconds: 120));
    await shot('stage_bolt');
    await run(const Duration(milliseconds: 150));
    await shot('stage_impact');
    await run(const Duration(milliseconds: 300));
    await shot('stage_motes');
    await run(const Duration(milliseconds: 300));

    game.blocked();
    await run(const Duration(milliseconds: 330));
    await shot('stage_blocked');
    await run(const Duration(milliseconds: 1200));

    game.battle.bossHp = 0;
    game.victory();
    game.equipCloak();
    await run(const Duration(milliseconds: 700));
    await shot('stage_pelt_flight');
    await run(const Duration(milliseconds: 1000));
    await shot('stage_cloak_banner');
    await run(const Duration(seconds: 4));

    expect(tester.takeException(), isNull);
  });

  testWidgets('rời trận: boss được dispose (trả sprite, lớp shader)', (
    tester,
  ) async {
    final art = _DisposeProbeArt();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 800,
          height: 520,
          child: GameWidget(game: BattleStageGame(boss: art)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(art.disposed, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(art.disposed, isTrue);
  });
}

class _DisposeProbeArt extends NemeaBossArt {
  bool disposed = false;

  /// Không nạp phông/sprite thật (tải tài nguyên không chạy trong fake async).
  @override
  Future<void> preload() async {}

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
