import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/art/battle_stage.dart';
import 'package:solo_pushing_up/art/bosses/boss_registry.dart';
import 'package:solo_pushing_up/art/bosses/nemea_boss.dart';
import 'package:solo_pushing_up/art/hero_art.dart';
import 'package:solo_pushing_up/art/home_banner_art.dart';
import 'package:solo_pushing_up/art/sprite_atlas.dart';
import 'package:solo_pushing_up/art/nemea_scene.dart';
import 'package:solo_pushing_up/art/vector_style.dart';
import 'package:solo_pushing_up/game/labors.dart';
import 'package:solo_pushing_up/ui/boss_portrait.dart';

/// Kẻ thù có chân dung chụp sẵn ([BossPortrait.baked]).
final bakedEnemies = [
  for (final s in nemea.allStages)
    if (BossPortrait.baked.contains(s.enemy.id)) s.enemy,
];

/// Cỡ ảnh chân dung: thẻ lớn nhất 64 pt × 3 (iPhone) ≈ 192 px, dư một chút.
const portraitPx = 256;

/// Khung chân dung theo sprite Blender (toạ độ sân khấu 400×260: tâm, cạnh),
/// đo trên `build/portraits/_stage_<id>.png`. Khung trong BossArt vẫn theo
/// bản vector.
const framing = <String, (double, double, double)>{
  'stymphalian_flock': (282, 108, 60),
  'stymphalian_swarm': (292, 108, 70),
  'spartoi': (310, 175, 70),
  'stone_soldier': (300, 110, 110),
  'erymanthian_boar': (205, 178, 95),
  'harpy': (303, 95, 120),
  'spartoi_pack': (295, 172, 110),
  'young_hydra': (285, 75, 130),
  'stone_guard': (300, 90, 95),
  'nemean_lion': (292, 178, 95),
};

/// Bụi Trì Trệ tan theo máu quái: chân dung lấy lúc bụi đã loãng (rõ hình,
/// vẫn còn không khí u ám).
const portraitBossHp = 0.25;

/// Chụp chân dung tròn cho [bakedEnemies]:
///
///     ART_BAKE=1 flutter test test/art/art_bake_test.dart
///     python tool/sprites_webp.py --portraits
///
/// → `build/portraits/<id>.png` → `assets/portraits/<id>.webp`. Không đặt biến
/// môi trường thì chỉ kiểm tra chân dung trong assets/ khớp kẻ thù.
void main() {
  final bake = Platform.environment['ART_BAKE'] == '1';

  test('chân dung trong assets/portraits ứng với đúng kẻ thù', () {
    final dir = Directory('assets/portraits');
    if (!dir.existsSync()) return;
    final files = {
      for (final f in dir.listSync().whereType<File>())
        if (f.path.endsWith('.webp'))
          f.uri.pathSegments.last.replaceAll('.webp', ''),
    };
    expect(files, {for (final e in bakedEnemies) e.id});
  });

  testWidgets('chụp chân dung từ sprite Blender', (tester) async {
    for (final enemy in bakedEnemies) {
      final art = bossArtFor(enemy)!;
      await tester.runAsync(art.preload);
      final battle = _settledBattle(art);
      final (x, y, side) = framing[enemy.id]!;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      // Cùng độ bão hoà như sân khấu (BattleStageGame.saturation).
      canvas.saveLayer(
        null,
        ui.Paint()..colorFilter = saturationFilter(BattleStageGame.saturation),
      );
      paintBossPortrait(
        canvas,
        art,
        portraitPx.toDouble(),
        stageScene: true,
        focus: ui.Offset(x, y),
        view: side,
        battle: battle,
      );
      canvas.restore();
      final picture = recorder.endRecording();
      if (bake) {
        await tester.runAsync(() async {
          final image = await picture.toImage(portraitPx, portraitPx);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('build/portraits/${enemy.id}.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
      picture.dispose();
      if (bake) await _stageWithGrid(tester, art, enemy.id, battle);
      art.dispose();
    }
  }, skip: !bake);

  testWidgets('chụp khung trang chủ: cảnh có sư tử và các lớp nhân vật', (
    tester,
  ) async {
    const k = HomeBannerArt.pxPerUnit;
    for (final freed in [false, true]) {
      final art = NemeaBossArt();
      await tester.runAsync(art.preload);
      final battle = _settledBattle(art, bossHp: freed ? 0 : 1);
      final recorder = ui.PictureRecorder();
      final c = ui.Canvas(recorder)..scale(k);
      c.saveLayer(
        null,
        ui.Paint()..colorFilter = saturationFilter(BattleStageGame.saturation),
      );
      art.paintScene(c, 4, battle);
      final frame = BossFrame(
        time: 1.2,
        attack: 0,
        hurt: 0,
        glint: -1,
        defeat: 0,
        battle: battle,
      );
      art.paintBoss(c, frame);
      art.paintForeground(c, frame);
      c.restore();
      await _save(
        tester,
        recorder.endRecording(),
        (stageSize.width * k).round(),
        (stageSize.height * k).round(),
        'build/banner/scene_${freed ? 'clear' : 'dust'}.png',
      );
      art.dispose();
    }

    final box = HomeBannerArt.heroBox;
    for (final sex in HeroSex.values) {
      const styles = HairStyle.values;
      for (final layer in [
        'skin',
        'cloth',
        for (final h in styles) 'hair_${h.name}',
        'pelt',
      ]) {
        final name = 'hero_${sex.name}_$layer';
        final atlas = (await tester.runAsync(() => SpriteAtlas.load(name)))!;
        final recorder = ui.PictureRecorder();
        final c = ui.Canvas(recorder)
          ..scale(k)
          ..translate(-box.left, -box.top);
        atlas.draw(c, 'stand', 0);
        await _save(
          tester,
          recorder.endRecording(),
          (box.width * k).round(),
          (box.height * k).round(),
          'build/banner/hero_${sex.name}_$layer.png',
        );
        SpriteAtlas.evict(name);
      }
    }
  }, skip: !bake);
}

Future<void> _save(
  WidgetTester tester,
  ui.Picture picture,
  int width,
  int height,
  String path,
) async {
  await tester.runAsync(() async {
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
  picture.dispose();
}

/// Cảnh vẽ tan bụi mượt theo thời gian: vẽ nháp vài giây cho bụi lắng ở mức
/// [portraitBossHp].
StageBattleState _settledBattle(BossArt art, {double bossHp = portraitBossHp}) {
  final battle = StageBattleState()
    ..totalHeads = 8
    ..headsLeft = 8
    ..bossHp = bossHp;
  final scratch = ui.Canvas(ui.PictureRecorder());
  for (var t = 0.0; t < 4; t += 0.1) {
    art.paintScene(scratch, t, battle);
  }
  return battle;
}

/// Cả sân khấu kèm lưới mỗi 20 đơn vị (`build/portraits/_stage_<id>.png`), để
/// đọc toạ độ mặt quái khi chỉnh khung chân dung.
Future<void> _stageWithGrid(
  WidgetTester tester,
  BossArt art,
  String id,
  StageBattleState battle,
) async {
  const k = 3.0;
  final recorder = ui.PictureRecorder();
  final c = ui.Canvas(recorder)..scale(k);
  if (art.hasStageBackdrop) art.paintStageBackdrop(c);
  art.paintScene(c, 0.4, battle);
  art.paintBoss(
    c,
    BossFrame(
      time: 0.4,
      attack: 0.6,
      hurt: 0,
      glint: -1,
      defeat: 0,
      battle: battle,
    ),
  );
  final line = ui.Paint()
    ..color = const ui.Color(0x88FF00FF)
    ..strokeWidth = 0.3;
  for (var x = 0.0; x <= stageSize.width; x += 20) {
    c.drawLine(ui.Offset(x, 0), ui.Offset(x, stageSize.height), line);
  }
  for (var y = 0.0; y <= stageSize.height; y += 20) {
    c.drawLine(ui.Offset(0, y), ui.Offset(stageSize.width, y), line);
  }
  final picture = recorder.endRecording();
  await tester.runAsync(() async {
    final image = await picture.toImage(
      (stageSize.width * k).round(),
      (stageSize.height * k).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(
      'build/portraits/_stage_$id.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
  picture.dispose();
}
