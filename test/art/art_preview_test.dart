import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/art/greek_monsters.dart';
import 'package:solo_pushing_up/art/hercules_art.dart';
import 'package:solo_pushing_up/art/hero_art.dart';
import 'package:solo_pushing_up/art/hero_pose.dart';
import 'package:solo_pushing_up/art/hero_sprite.dart';
import 'package:solo_pushing_up/art/home_banner_art.dart';
import 'package:solo_pushing_up/art/horse_art.dart';
import 'package:solo_pushing_up/art/lion_art.dart';
import 'package:solo_pushing_up/art/nemea_map_art.dart';
import 'package:solo_pushing_up/art/nemea_backdrop.dart';
import 'package:solo_pushing_up/art/nemea_scene.dart';
import 'package:solo_pushing_up/art/sprite_atlas.dart';
import 'package:solo_pushing_up/art/vector_style.dart';
import 'package:solo_pushing_up/art/battle_stage.dart';
import 'package:solo_pushing_up/art/bosses/dummy_art.dart';
import 'package:solo_pushing_up/art/bosses/fafnir_boss.dart';
import 'package:solo_pushing_up/art/bosses/nemea_boss.dart';
import 'package:solo_pushing_up/art/bosses/nemea_monster_art.dart';
import 'package:solo_pushing_up/art/bosses/orochi_boss.dart';
import 'package:solo_pushing_up/art/bosses/thuy_tinh_boss.dart';
import 'package:solo_pushing_up/ui/nemea_intro_screen.dart';

/// Vẽ thử các khung hình nhân vật. Mặc định chỉ kiểm tra vẽ không lỗi;
/// đặt biến môi trường ART_PREVIEW=1 để ghi PNG vào build/art_preview/.
Future<void> render(
  WidgetTester tester,
  String name,
  void Function(ui.Canvas) draw, {
  double scale = 2,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(scale);
  draw(canvas);
  final picture = recorder.endRecording();
  if (Platform.environment['ART_PREVIEW'] != '1') return;
  await tester.runAsync(() async {
    final image = await picture.toImage(
      (stageSize.width * scale).round(),
      (stageSize.height * scale).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/art_preview/$name.png')
      ..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void scene(
  ui.Canvas canvas,
  HeroPose hero, {
  bool cloak = false,
  LionState lion = const LionState(),
  double effort = 0,
}) {
  paintNemeaScene(canvas);
  canvas.save();
  canvas.translate(lionX, stageGroundY);
  canvas.scale(lionScale);
  paintLion(canvas, lion);
  canvas.restore();
  paintHero(canvas, hero, cloak: cloak, effort: effort);
}

/// Nhân vật trên sân khấu trận: thu nhỏ như _HeroComponent (heroStageScale).
void paintStageHero(Canvas c, HeroPose pose, {double effort = 0}) {
  c.save();
  c.translate(heroStagePivot.dx, heroStagePivot.dy);
  c.scale(heroStageScale);
  c.translate(-heroStagePivot.dx, -heroStagePivot.dy);
  paintHero(c, pose, effort: effort);
  c.restore();
}

void main() {
  testWidgets('chống đẩy: tay thẳng, giữa chừng, xuống sâu', (tester) async {
    for (final angle in [180.0, 120.0, 70.0]) {
      await render(
        tester,
        'plank_${angle.round()}',
        (c) => scene(c, HeroPose.plank(angle)),
      );
    }
  });

  testWidgets('chống gối và khoác áo da sư tử', (tester) async {
    await render(
      tester,
      'knee_90',
      (c) => scene(c, HeroPose.plank(90, onKnees: true)),
    );
    await render(
      tester,
      'cloak_plank',
      (c) => scene(c, HeroPose.plank(100), cloak: true),
    );
  });

  testWidgets('phông Nemea: phủ bụi Trì Trệ, bụi tan một nửa, sạch', (
    tester,
  ) async {
    for (final (name, dust) in [
      ('nemea_dust_full', 0.85),
      ('nemea_dust_half', 0.4),
      ('nemea_clean', 0.0),
    ]) {
      await render(
        tester,
        name,
        (c) => paintNemeaScene(c, time: 3, dust: dust),
      );
    }
  });

  testWidgets('Sư tử Nemea: rình, lấy đà, vồ, trúng đòn, bị chặn, gục', (
    tester,
  ) async {
    for (final (name, lion) in [
      ('lion_idle', const LionState(time: 1)),
      ('lion_windup', const LionState(time: 1, attackPhase: 0.38)),
      ('lion_strike', const LionState(time: 1, attackPhase: 0.55)),
      ('lion_hurt', const LionState(time: 1, hurt: 0.8)),
      ('lion_blocked', const LionState(time: 1, glint: 0.3)),
      ('lion_defeat', const LionState(time: 1, defeat: 1)),
    ]) {
      await render(tester, name, (c) {
        paintNemeaScene(c, time: 1);
        c.save();
        c.translate(250, stageGroundY);
        paintLion(c, lion);
        c.restore();
      });
    }
  });

  testWidgets('quái Hy Lạp: bình thường và ra đòn', (tester) async {
    for (final (name, attack) in [
      ('monsters', 0.0),
      ('monsters_attack', 1.0),
    ]) {
      await render(tester, name, (c) {
        paintNemeaScene(c, time: 2);
        void at(double x, double y, double s, void Function() draw) {
          c.save();
          c.translate(x, y);
          c.scale(s);
          draw();
          c.restore();
        }

        at(
          60,
          70,
          1.6,
          () => paintStymphalianBird(c, time: 0.3, attack: attack),
        );
        at(130, 50, 1.2, () => paintStymphalianBird(c, time: 0.5));
        at(
          70,
          stageGroundY,
          1.1,
          () => paintSpartoi(c, time: 1, attack: attack),
        );
        at(
          150,
          stageGroundY,
          1.1,
          () => paintHarpy(c, time: 1, attack: attack),
        );
        at(
          250,
          stageGroundY,
          1.0,
          () => paintErymanthianBoar(c, time: 1, attack: attack),
        );
        at(
          350,
          stageGroundY,
          1.0,
          () => paintYoungHydra(c, time: 1, attack: attack),
        );
      });
    }
    await render(tester, 'bird_zoom', (c) {
      paintNemeaScene(c, time: 2);
      for (final (x, t, attack) in [(110.0, 0.0, 0.0), (290.0, 0.17, 1.0)]) {
        c.save();
        c.translate(x, 120);
        c.scale(4);
        paintStymphalianBird(c, time: t, attack: attack);
        c.restore();
      }
    });
    await render(tester, 'monsters_zoom', (c) {
      paintNemeaScene(c, time: 2);
      for (final (x, s, draw) in <(double, double, void Function())>[
        (70, 2.0, () => paintHarpy(c, time: 1, attack: 0.6, stealing: true)),
        (210, 1.5, () => paintErymanthianBoar(c, time: 1)),
        (340, 1.4, () => paintYoungHydra(c, time: 1, attack: 0.5)),
      ]) {
        c.save();
        c.translate(x, stageGroundY + 20);
        c.scale(s);
        draw();
        c.restore();
      }
    });
    await render(tester, 'spartoi_zoom', (c) {
      paintNemeaScene(c, time: 2);
      for (final (x, attack) in [(110.0, 0.0), (290.0, 1.0)]) {
        c.save();
        c.translate(x, stageGroundY + 10);
        c.scale(2.2);
        paintSpartoi(c, time: 1, attack: attack);
        c.restore();
      }
    });
    await render(tester, 'hydra_regrow', (c) {
      paintNemeaScene(c, time: 2);
      for (final (x, g) in [(110.0, 0.3), (300.0, 1.0)]) {
        c.save();
        c.translate(x, stageGroundY + 60);
        c.scale(1.8);
        paintYoungHydra(c, time: 1, regrow: g);
        c.restore();
      }
    });
    await render(tester, 'stone_soldier', (c) {
      paintNemeaScene(c, time: 2, dust: 0.6);
      for (final (x, attack) in [(120.0, 0.3), (280.0, 1.0)]) {
        c.save();
        c.translate(x, stageGroundY);
        c.scale(1.5);
        paintStoneSoldier(c, time: 1.3, attack: attack);
        c.restore();
      }
    });
    await render(tester, 'spartoi_rise', (c) {
      paintNemeaScene(c, time: 2);
      c.save();
      c.translate(200, stageGroundY);
      c.scale(1.4);
      paintSpartoi(c, rise: 0.5);
      c.restore();
    });
  });

  testWidgets('trận Nemea đầy đủ: bụi, đàn chim, sư tử, nhân vật', (
    tester,
  ) async {
    for (final (name, hp, phase) in [
      ('nemea_stage_start', 1.0, 0.55),
      ('nemea_stage_half', 0.45, -1.0),
      ('nemea_stage_clear', 0.02, 0.3),
    ]) {
      final art = NemeaBossArt();
      final battle = StageBattleState()..bossHp = hp;
      // Chạy vài khung để bụi đạt mức theo máu.
      for (var i = 0; i < 120; i++) {
        art.paintScene(ui.Canvas(ui.PictureRecorder()), i / 30, battle);
      }
      final frame = BossFrame(
        time: 4,
        attack: 0,
        hurt: 0,
        glint: -1,
        defeat: 0,
        battle: battle,
        attackPhase: phase,
      );
      await render(tester, name, (c) {
        // Như trong game: cả sân khấu qua lớp tăng bão hoà.
        c.saveLayer(
          null,
          Paint()..colorFilter = saturationFilter(BattleStageGame.saturation),
        );
        art.paintStageBackdrop(c);
        art.paintScene(c, 4, battle);
        art.paintBoss(c, frame);
        paintStageHero(c, HeroPose.plank(110), effort: 0.6);
        art.paintForeground(c, frame);
        paintStageGrade(c, Offset.zero & stageSize, light: art.gradeLight);
        c.restore();
      });
    }
  });

  testWidgets('cảnh mở đầu bằng Blender: phông, nhân vật, Hercules', (
    tester,
  ) async {
    const look = HeroLook();
    await tester.runAsync(() => preloadNemeaIntro(look));
    expect(SpriteAtlas.get(herculesSprite), isNotNull);
    for (final (name, time, talking) in [
      ('appear', 0.8, false),
      ('idle', 3.0, false),
      ('talk', 3.0, true),
    ]) {
      await render(
        tester,
        'intro_blender_$name',
        (c) => paintNemeaIntro(
          c,
          time: time,
          talk: time > 1.6 ? 1 : 0,
          talking: talking,
        ),
      );
    }
    NemeaBackdrop.evict();
    HeroSprites.evict(look);
    SpriteAtlas.evict(herculesSprite);
  });

  testWidgets('cảnh mở đầu: Hercules hiện ra và dặn dò', (tester) async {
    await render(tester, 'intro_appear', (c) => paintNemeaIntro(c, time: 0.8));
    await render(
      tester,
      'intro_talk',
      (c) => paintNemeaIntro(c, time: 3, talk: 1, talking: true),
    );
    await render(tester, 'hands_sheet', (c) {
      c.drawRect(
        const Rect.fromLTWH(0, 0, 400, 260),
        Paint()..color = const Color(0xFFEDE3CF),
      );
      for (final (i, pose) in HandPose.values.indexed) {
        for (final (j, dir, facing) in [
          (0, const Offset(0, 1), const Offset(-1, 0)),
          (1, const Offset(-0.7, -1), const Offset(-1, 0)),
          (2, const Offset(1, 0), const Offset(0, -1)),
        ]) {
          final wrist = Offset(40.0 + i * 76, 40.0 + j * 80);
          shadedHand(
            c,
            buildHand(wrist, dir, pose: pose, facing: facing, scale: 2.6),
            const Color(0xFFC98B5A),
          );
        }
      }
    });
    await render(tester, 'hercules_full', (c) {
      paintNemeaScene(c, time: 1);
      c.translate(200, 252);
      c.scale(0.95);
      paintHercules(c, time: 1);
    });
    await render(tester, 'hercules_head_zoom', (c) {
      paintNemeaScene(c, time: 1);
      c.translate(200, 870);
      c.scale(3.6);
      paintHercules(c, time: 1, talk: 1);
    });
    await render(tester, 'hercules_feet_zoom', (c) {
      paintNemeaScene(c, time: 1);
      c.translate(200, 150);
      c.scale(2.6);
      paintHercules(c, time: 1);
    });
    await render(tester, 'hercules_torso_zoom', (c) {
      paintNemeaScene(c, time: 1);
      c.translate(200, 520);
      c.scale(2.3);
      paintHercules(c, time: 1);
    });
    await render(tester, 'hercules_closeup', (c) {
      paintNemeaScene(c, time: 1);
      c.save();
      c.translate(200, stageGroundY + 40);
      paintHercules(c, time: 1, talk: 1);
      c.restore();
    });
  });

  testWidgets('chân dung boss trên thẻ kỳ công', (tester) async {
    final arts = <BossArt>[
      NemeaBossArt(),
      FafnirBossArt(),
      OrochiBossArt(),
      ThuyTinhBossArt(),
    ];
    await render(tester, 'portraits', (c) {
      c.drawRect(
        const Rect.fromLTWH(0, 0, 400, 260),
        Paint()..color = const Color(0xFF2A2420),
      );
      for (var i = 0; i < arts.length; i++) {
        final art = arts[i];
        const size = 90.0;
        c.save();
        c.translate(10 + i * 98.0, 80);
        c.clipPath(Path()..addOval(const Rect.fromLTWH(0, 0, size, size)));
        final view = art.portraitView;
        c.scale(size / view);
        c.translate(
          view / 2 - art.portraitFocus.x,
          view / 2 - art.portraitFocus.y,
        );
        art.paintBackdrop(c);
        art.paintBoss(
          c,
          BossFrame(
            time: 0.4,
            attack: 0.6,
            hurt: 0,
            glint: -1,
            defeat: 0,
            battle: StageBattleState()
              ..totalHeads = 8
              ..headsLeft = 8,
          ),
        );
        c.restore();
      }
    });
  });

  testWidgets('cận mặt sư tử và nhân vật (soát chi tiết)', (tester) async {
    await render(tester, 'lion_face_zoom', (c) {
      paintNemeaScene(c, time: 1);
      // Đầu sư tử (toạ độ cục bộ ~(-74, -104)) vào giữa khung.
      c.scale(2.6);
      c.translate(151, 154);
      paintLion(c, const LionState(time: 1, mouth: 0.7));
    });
    await render(tester, 'hero_zoom', (c) {
      paintNemeaScene(c, time: 1);
      c.scale(2.2);
      c.translate(-40, -110);
      paintStageHero(c, HeroPose.plank(110), effort: 0.6);
    });
    await render(tester, 'hero_glow', (c) {
      paintNemeaScene(c, time: 1);
      paintHero(c, HeroPose.plank(160), glow: 0.5, effort: 0.2);
    });
  });

  testWidgets('Nemea: thung lũng được giải phóng (vòng sáng từ đền)', (
    tester,
  ) async {
    final art = NemeaBossArt();
    final battle = StageBattleState()..bossHp = 0;
    var t = 0.0;
    // Bụi tan hết sau ~1,2 giây; chụp lúc vòng sáng đang nở.
    for (; t < 1.6; t += 1 / 30) {
      art.paintScene(ui.Canvas(ui.PictureRecorder()), t, battle);
    }
    await render(tester, 'nemea_cleansing', (c) {
      art.paintStageBackdrop(c);
      art.paintScene(c, t + 0.0, battle);
      paintHero(c, HeroPose.victory(), cloak: true, joy: 1);
    });
  });

  testWidgets('9 màn quái Kỳ công 1 (1.1 → 1.9)', (tester) async {
    for (final (i, kind) in NemeaMonster.values.indexed) {
      final art = NemeaMonsterArt(kind);
      final battle = StageBattleState()
        ..bossHp = 0.7
        ..totalHeads = 3
        ..headsLeft = 3
        ..charge = kind == NemeaMonster.boar ? 0.7 : 0
        ..goldStolen = 0;
      final frame = BossFrame(
        time: 2.5,
        attack: 0.3,
        hurt: 0,
        glint: -1,
        defeat: 0,
        battle: battle,
      );
      for (var t = 0.0; t < 2.5; t += 1 / 30) {
        art.paintScene(ui.Canvas(ui.PictureRecorder()), t, battle);
      }
      await render(tester, 'stage_1_${i + 1}', (c) {
        art.paintStageBackdrop(c);
        art.paintScene(c, 2.5, battle);
        art.paintBoss(c, frame);
        paintStageHero(c, HeroPose.plank(120), effort: 0.5);
        art.paintForeground(c, frame);
        paintStageGrade(c, Offset.zero & stageSize, light: art.gradeLight);
      });
    }
  });

  testWidgets('màn quái Kỳ công 1 bằng sprite Blender', (tester) async {
    await tester.runAsync(NemeaMonsterArt.preloadSprites);
    await tester.runAsync(NemeaBackdrop.load);
    expect(NemeaBackdrop.ready, isTrue, reason: 'phông Blender Nemea');
    // Thiếu/hỏng trang ảnh thì sân khấu lặng lẽ vẽ bản vector — bắt ở đây.
    for (final name in [
      'stymphalian_bird',
      'spartoi',
      'stone_soldier',
      'erymanthian_boar',
      'harpy',
      'young_hydra',
    ]) {
      expect(SpriteAtlas.get(name), isNotNull, reason: name);
    }
    for (final (i, kind) in NemeaMonster.values.indexed) {
      final art = NemeaMonsterArt(kind);
      final battle = StageBattleState()
        ..bossHp = 0.7
        ..totalHeads = 3
        ..headsLeft = 3
        ..charge = kind == NemeaMonster.boar ? 0.7 : 0;
      for (final (tag, phase) in [
        ('idle', -1.0),
        ('windup', 0.4),
        ('strike', 0.58),
      ]) {
        final frame = BossFrame(
          time: 2.5,
          attack: phase < 0 ? 0 : 0.9,
          hurt: 0,
          glint: -1,
          defeat: 0,
          battle: battle,
          attackPhase: phase,
        );
        await render(tester, 'sprite_1_${i + 1}_$tag', (c) {
          art.paintStageBackdrop(c);
          art.paintScene(c, 2.5, battle);
          art.paintBoss(c, frame);
          paintStageHero(c, HeroPose.plank(120), effort: 0.5);
          art.paintForeground(c, frame);
          paintStageGrade(c, Offset.zero & stageSize, light: art.gradeLight);
        });
      }
    }
  });

  testWidgets('boss 1.10 Sư tử Nemea bằng sprite Blender', (tester) async {
    final art = NemeaBossArt();
    await tester.runAsync(art.preload);
    expect(SpriteAtlas.get(NemeaBossArt.lionSprite), isNotNull);
    expect(NemeaBackdrop.ready, isTrue);
    final battle = StageBattleState()..bossHp = 0.6;
    for (final (tag, phase, defeat, glint) in [
      ('idle', -1.0, 0.0, -1.0),
      ('windup', 0.3, 0.0, -1.0),
      ('strike', 0.56, 0.0, -1.0),
      ('blocked', -1.0, 0.0, 0.3),
      ('defeat', -1.0, 1.0, -1.0),
    ]) {
      final frame = BossFrame(
        time: 2.5,
        attack: phase < 0 ? 0 : 0.9,
        hurt: 0,
        glint: glint,
        defeat: defeat,
        battle: battle,
        attackPhase: phase,
      );
      await render(tester, 'sprite_1_10_$tag', (c) {
        art.paintStageBackdrop(c);
        art.paintScene(c, 2.5, battle);
        art.paintBoss(c, frame);
        paintStageHero(c, HeroPose.plank(120), effort: 0.5);
        art.paintForeground(c, frame);
        paintStageGrade(c, Offset.zero & stageSize, light: art.gradeLight);
      });
    }
    // Pha 2 (máu < 40%): nhảy vồ; vật được thì chồm ngửa ra sau.
    final rage = StageBattleState()..bossHp = 0.3;
    BossFrame at(double time, {double phase = -1}) => BossFrame(
      time: time,
      attack: phase < 0 ? 0 : 0.9,
      hurt: 0,
      glint: -1,
      defeat: 0,
      battle: rage,
      attackPhase: phase,
    );
    void scene(Canvas c, BossFrame frame) {
      art.paintStageBackdrop(c);
      art.paintScene(c, frame.time, rage);
      art.paintBoss(c, frame);
      paintStageHero(c, HeroPose.plank(178), effort: 0.8);
      art.paintForeground(c, frame);
      paintStageGrade(c, Offset.zero & stageSize, light: art.gradeLight);
    }

    await render(
      tester,
      'sprite_1_10_pounce',
      (c) => scene(c, at(3, phase: 0.56)),
    );
    rage.wrestles = 1;
    art.paintBoss(Canvas(ui.PictureRecorder()), at(3.5));
    await render(tester, 'sprite_1_10_wrestled', (c) => scene(c, at(4)));
    art.dispose();
  });

  testWidgets('nhân vật bằng sprite Blender tách lớp (da, áo, tóc)', (
    tester,
  ) async {
    final art = NemeaBossArt();
    await tester.runAsync(art.preload);
    final looks = [
      const HeroLook(),
      HeroLook(skin: skinTones[0], hair: hairColors[3]),
      HeroLook(skin: skinTones[5], hair: hairColors[0], height: 1.08),
      HeroLook(
        sex: HeroSex.female,
        hairStyle: HairStyle.ponytail,
        skin: skinTones[1],
        hair: hairColors[1],
        height: 0.94,
      ),
      HeroLook(
        sex: HeroSex.female,
        hairStyle: HairStyle.long,
        skin: skinTones[3],
        hair: hairColors[4],
      ),
    ];
    for (final look in looks) {
      await tester.runAsync(() => HeroSprites.load(look));
      expect(HeroSprites.ready(look), isTrue, reason: '${look.sex}');
    }
    final battle = StageBattleState()..bossHp = 0.0;
    final frame = BossFrame(
      time: 2.5,
      attack: 0,
      hurt: 0,
      glint: -1,
      defeat: 0,
      battle: battle,
    );
    for (final (i, look) in looks.indexed) {
      for (final (tag, f) in [
        ('top', HeroSpriteFrame.plank(178)),
        ('mid', HeroSpriteFrame.plank(120)),
        ('bottom', HeroSpriteFrame.plank(72)),
        ('knees', HeroSpriteFrame.plank(90, onKnees: true)),
        ('stand', const HeroSpriteFrame('stand', 0)),
        ('victory', const HeroSpriteFrame('victory', 0)),
      ]) {
        await render(tester, 'hero_sprite_${i}_$tag', (c) {
          art.paintStageBackdrop(c);
          art.paintScene(c, 2.5, battle);
          HeroSprites.paint(c, look, f);
          art.paintForeground(c, frame);
        });
      }
    }
    // Áo da Sư tử Nemea (phần thưởng Kỳ công 1) cho cả nam và nữ.
    for (final i in [0, 3]) {
      final look = looks[i];
      expect(HeroSprites.peltReady(look), isTrue, reason: '${look.sex}');
      for (final (tag, f) in [
        ('top', HeroSpriteFrame.plank(178)),
        ('bottom', HeroSpriteFrame.plank(72)),
        ('knees', HeroSpriteFrame.plank(90, onKnees: true)),
        ('stand', const HeroSpriteFrame('stand', 0)),
        ('victory', const HeroSpriteFrame('victory', 0)),
      ]) {
        await render(tester, 'hero_pelt_${i}_$tag', (c) {
          art.paintStageBackdrop(c);
          art.paintScene(c, 2.5, battle);
          HeroSprites.paint(c, look, f, pelt: true);
          art.paintForeground(c, frame);
        });
      }
    }
    art.dispose();
  });

  testWidgets('khung trang chủ bằng ảnh Blender chụp sẵn', (tester) async {
    final variants = [
      ('dust', const HeroLook(), false, false),
      (
        'pelt_female',
        HeroLook(
          sex: HeroSex.female,
          hairStyle: HairStyle.ponytail,
          skin: skinTones[4],
          hair: hairColors[0],
        ),
        true,
        true,
      ),
      (
        'pelt_male_dark',
        HeroLook(skin: skinTones[5], hairStyle: HairStyle.buzz, height: 1.1),
        true,
        false,
      ),
    ];
    for (final (name, look, cloak, freed) in variants) {
      await tester.runAsync(
        () => HomeBannerArt.load(look, cloak: cloak, freed: freed),
      );
      expect(HomeBannerArt.ready(look, cloak: cloak, freed: freed), isTrue);
      await render(
        tester,
        'home_banner_$name',
        (c) => HomeBannerArt.paint(c, look, cloak: cloak, freed: freed),
        scale: 3,
      );
    }
  });

  testWidgets('bản đồ Thung lũng Nemea: 3 màn xong, màn 4 mở', (tester) async {
    await tester.runAsync(NemeaMapImage.load);
    expect(NemeaMapImage.image, isNotNull, reason: 'bản đồ Blender');
    await render(tester, 'nemea_map', (c) {
      c.scale(400 / nemeaMapSize.width, 260 / nemeaMapSize.height);
      paintNemeaMap(c, [
        for (var i = 0; i < 10; i++)
          i < 3
              ? MapNodeState.done
              : i == 3
              ? MapNodeState.open
              : MapNodeState.locked,
      ], time: 1);
    });
  });

  testWidgets('đứng chờ, ăn mừng, sư tử gầm / trúng đòn / gục', (tester) async {
    await render(
      tester,
      'standing',
      (c) => scene(c, HeroPose.standing(), lion: const LionState(mouth: 1)),
    );
    await render(
      tester,
      'victory',
      (c) => scene(
        c,
        HeroPose.victory(),
        cloak: true,
        lion: const LionState(defeat: 1),
      ),
    );
    await render(
      tester,
      'lion_hurt_scene',
      (c) => scene(
        c,
        HeroPose.plank(170),
        lion: const LionState(hurt: 0.8, glint: 0.4),
      ),
    );
  });

  testWidgets('đủ kiểu nhân vật: nam/nữ, gầy/béo, tóc, da, cao/thấp', (
    tester,
  ) async {
    const looks = [
      HeroLook(),
      HeroLook(fat: 0.9, skin: Color(0xFFC68A5E), hairStyle: HairStyle.buzz),
      HeroLook(
        sex: HeroSex.female,
        hairStyle: HairStyle.ponytail,
        skin: Color(0xFFF6D3B8),
        height: 0.92,
      ),
      HeroLook(
        sex: HeroSex.female,
        fat: 0.85,
        hairStyle: HairStyle.bun,
        hair: Color(0xFFB0472A),
      ),
      HeroLook(
        sex: HeroSex.female,
        hairStyle: HairStyle.long,
        skin: Color(0xFF6B4329),
        height: 1.08,
      ),
      HeroLook(fat: 0.4, hair: Color(0xFF9A9A9A), height: 1.1),
    ];
    await render(tester, 'lineup', (c) {
      c.drawRect(
        const Rect.fromLTWH(0, 0, 400, 260),
        Paint()..color = const Color(0xFFEDE3CF),
      );
      for (var i = 0; i < looks.length; i++) {
        paintHero(c, HeroPose.standing(x: 30.0 + i * 65), look: looks[i]);
      }
    });
    await render(tester, 'plank_looks', (c) {
      paintNemeaScene(c);
      paintHero(c, HeroPose.plank(110), look: looks[3]);
      c.save();
      c.translate(190, -90);
      paintHero(c, HeroPose.plank(150), look: looks[4]);
      c.restore();
    });
  });

  testWidgets('biểu cảm: bình thường, gắng sức, ăn mừng (phóng to)', (
    tester,
  ) async {
    await render(tester, 'expressions', (c) {
      c.drawRect(
        const Rect.fromLTWH(0, 0, 400, 260),
        Paint()..color = const Color(0xFFEDE3CF),
      );
      c.scale(2.4);
      c.translate(-35, -30);
      final looks = [
        (const HeroLook(), 0.0, 0.0),
        (
          const HeroLook(sex: HeroSex.female, hairStyle: HairStyle.ponytail),
          1.0,
          0.0,
        ),
        (const HeroLook(fat: 0.6, hairStyle: HairStyle.buzz), 0.0, 1.0),
      ];
      for (var i = 0; i < looks.length; i++) {
        final (look, effort, joy) = looks[i];
        paintHero(
          c,
          HeroPose.standing(x: 75.0 + i * 50),
          look: look,
          effort: effort,
          joy: joy,
        );
      }
    });
    await render(
      tester,
      'plank_effort',
      (c) => scene(c, HeroPose.plank(75), effort: 1),
    );
  });

  testWidgets('Thuỷ Tinh: nước dâng 0%, 50%, 90%; đe doạ; gục', (tester) async {
    final art = ThuyTinhBossArt();
    for (final (name, water, attack, defeat, angle) in [
      ('thuy_tinh_0', 0.0, 0.0, 0.0, 170.0),
      ('thuy_tinh_50', 50.0, 1.0, 0.0, 100.0),
      ('thuy_tinh_90', 90.0, 0.0, 0.0, 120.0),
      ('thuy_tinh_defeat', 20.0, 0.0, 0.7, 170.0),
    ]) {
      final battle = StageBattleState()..water = water;
      final frame = BossFrame(
        time: 1.3,
        attack: attack,
        hurt: 0,
        glint: -1,
        defeat: defeat,
        battle: battle,
      );
      await render(tester, name, (c) {
        art.paintBackdrop(c);
        art.paintAmbient(c, 0.5);
        art.paintBoss(c, frame);
        paintHero(
          c,
          defeat > 0 ? HeroPose.victory() : HeroPose.plank(angle),
          look: const HeroLook(sex: HeroSex.female, hairStyle: HairStyle.long),
          joy: defeat > 0 ? 1 : 0,
        );
        art.paintForeground(c, frame);
      });
    }
  });

  testWidgets('Orochi: 8 đầu, đã chém 3, đầu mọc lại, gục', (tester) async {
    for (final (name, left, hp, attack, defeat, regrow) in [
      ('orochi_8', 8, 1.0, 0.0, 0.0, false),
      ('orochi_5', 5, 0.4, 1.0, 0.0, false),
      ('orochi_regrow', 5, 1.0, 0.0, 0.0, true),
      ('orochi_defeat', 0, 0.0, 0.0, 1.0, false),
    ]) {
      final art = OrochiBossArt();
      final battle = StageBattleState()
        ..totalHeads = 8
        ..headsLeft = left
        ..headHp = regrow ? 0.3 : hp;
      BossFrame frame(double time) => BossFrame(
        time: time,
        attack: attack,
        hurt: 0,
        glint: -1,
        defeat: defeat,
        battle: battle,
      );
      if (regrow) {
        // Khung trước máu thấp, khung sau hồi đầy = đầu mọc lại.
        art.paintBoss(ui.Canvas(ui.PictureRecorder()), frame(1.0));
        battle.headHp = hp;
      }
      await render(tester, name, (c) {
        art.paintBackdrop(c);
        art.paintAmbient(c, 1);
        art.paintBoss(c, frame(1.25));
        paintHero(
          c,
          defeat > 0 ? HeroPose.victory() : HeroPose.plank(110),
          look: const HeroLook(hairStyle: HairStyle.bun),
          joy: defeat > 0 ? 1 : 0,
          effort: defeat > 0 ? 0 : 0.7,
        );
      });
    }
  });

  testWidgets('Fafnir: bình thường, phun băng + nhân vật lạnh cóng, gục', (
    tester,
  ) async {
    final art = FafnirBossArt();
    for (final (name, attack, cold, defeat) in [
      ('fafnir_idle', 0.0, 0.0, 0.0),
      ('fafnir_breath_cold', 1.0, 0.9, 0.0),
      ('fafnir_defeat', 0.0, 0.0, 1.0),
    ]) {
      final battle = StageBattleState()..cold = cold;
      final frame = BossFrame(
        time: 2,
        attack: attack,
        hurt: 0,
        glint: -1,
        defeat: defeat,
        battle: battle,
      );
      await render(tester, name, (c) {
        art.paintBackdrop(c);
        art.paintAmbient(c, 2);
        art.paintBoss(c, frame);
        paintHero(
          c,
          defeat > 0 ? HeroPose.victory() : HeroPose.plank(165),
          look: const HeroLook(fat: 0.4, hairStyle: HairStyle.buzz),
          frost: cold,
          joy: defeat > 0 ? 1 : 0,
        );
      });
    }
  });

  testWidgets('trang bị: áo choàng + khiên vảy rồng + kiếm Kusanagi', (
    tester,
  ) async {
    await render(tester, 'gear', (c) {
      paintNemeaScene(c);
      paintHero(
        c,
        HeroPose.standing(x: 60),
        cloak: true,
        shield: true,
        sword: true,
      );
      paintHero(
        c,
        HeroPose.plank(110).translate(const Offset(150, 0)),
        look: const HeroLook(sex: HeroSex.female, hairStyle: HairStyle.bun),
        shield: true,
        sword: true,
        effort: 0.7,
      );
    });
  });

  testWidgets('Ngựa chín hồng mao đứng cạnh nhân vật ăn mừng', (tester) async {
    final art = ThuyTinhBossArt();
    await render(tester, 'horse_victory', (c) {
      art.paintBackdrop(c);
      art.paintAmbient(c, 0.5);
      c.save();
      c.translate(210, stageGroundY);
      c.scale(1.15);
      paintHorse(c, time: 1);
      c.restore();
      paintHero(
        c,
        HeroPose.victory(),
        cloak: true,
        shield: true,
        sword: true,
        joy: 1,
      );
    });
  });

  testWidgets('bù nhìn tập luyện (thử thách 30 giây)', (tester) async {
    final art = TrainingDummyArt();
    for (final (name, hurt) in [('dummy_idle', 0.0), ('dummy_hit', 0.8)]) {
      await render(tester, name, (c) {
        art.paintBackdrop(c);
        art.paintAmbient(c, 1);
        art.paintBoss(
          c,
          BossFrame(
            time: 1,
            attack: 0,
            hurt: hurt,
            glint: -1,
            defeat: 0,
            battle: StageBattleState(),
          ),
        );
        paintStageHero(c, HeroPose.plank(110), effort: 0.5);
      });
    }
  });

  test('IK chống đẩy giữ đúng độ dài tay', () {
    for (final angle in [180.0, 140.0, 100.0, 60.0]) {
      final p = HeroPose.plank(angle);
      final upper = (p[HeroJoint.elbow] - p[HeroJoint.shoulder]).distance;
      final fore = (p[HeroJoint.wrist] - p[HeroJoint.elbow]).distance;
      expect(upper, closeTo(HeroBody.upperArm, 0.5), reason: 'góc $angle');
      expect(fore, closeTo(HeroBody.forearm, 0.5), reason: 'góc $angle');
    }
  });

  test('xuống sâu thì vai thấp hơn', () {
    final top = HeroPose.plank(175)[HeroJoint.shoulder].dy;
    final bottom = HeroPose.plank(70)[HeroJoint.shoulder].dy;
    expect(bottom, greaterThan(top + 20));
  });
}
