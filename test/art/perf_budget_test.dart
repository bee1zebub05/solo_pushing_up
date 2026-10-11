import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/art/battle_stage.dart';
import 'package:solo_pushing_up/art/bosses/fafnir_boss.dart';
import 'package:solo_pushing_up/art/bosses/nemea_boss.dart';
import 'package:solo_pushing_up/art/bosses/orochi_boss.dart';
import 'package:solo_pushing_up/art/bosses/thuy_tinh_boss.dart';
import 'package:solo_pushing_up/art/hero_art.dart';
import 'package:solo_pushing_up/art/hero_pose.dart';
import 'package:solo_pushing_up/art/lion_art.dart';

/// Ngân sách vẽ sân khấu (rules/dohoa.md): dưới 2 ms mỗi khung trên PC, để
/// điện thoại yếu còn đủ CPU cho ML Kit đếm rep. Lấy lần nhanh nhất trong 5
/// lần đo cho đỡ nhiễu khi máy đang bận.
double measureMsPerFrame(void Function(ui.Canvas canvas, int i) draw) {
  // Chạy nóng (JIT biên dịch xong) trước khi bấm giờ.
  for (var i = 0; i < 50; i++) {
    final recorder = ui.PictureRecorder();
    draw(ui.Canvas(recorder), i);
    recorder.endRecording();
  }
  var best = double.infinity;
  for (var run = 0; run < 5; run++) {
    final sw = Stopwatch()..start();
    const n = 200;
    for (var i = 0; i < n; i++) {
      final recorder = ui.PictureRecorder();
      draw(ui.Canvas(recorder), i);
      recorder.endRecording();
    }
    best = [
      best,
      sw.elapsedMicroseconds / n / 1000,
    ].reduce((a, b) => a < b ? a : b);
  }
  return best;
}

void main() {
  // Test đầu file chạy lúc cả bộ test đang biên dịch (máy bận nhất), nên
  // để sân khấu nặng nhất (Nemea) ở cuối cho số đo phản ánh đúng.
  test('sân khấu Thuỷ Tinh (mưa, sóng, nước dâng) vẽ dưới 2 ms/khung', () {
    final art = ThuyTinhBossArt();
    final recorder = ui.PictureRecorder();
    art.paintBackdrop(ui.Canvas(recorder));
    final backdrop = recorder.endRecording();
    final battle = StageBattleState();

    final ms = measureMsPerFrame((c, i) {
      battle.water = (i % 100).toDouble();
      final frame = BossFrame(
        time: i / 30,
        attack: (i % 20) / 20,
        hurt: (i % 7) / 7,
        glint: -1,
        defeat: 0,
        battle: battle,
      );
      c.drawPicture(backdrop);
      art.paintAmbient(c, i / 30);
      art.paintBoss(c, frame);
      paintHero(c, HeroPose.plank(80 + i % 90), effort: (i % 10) / 10);
      art.paintForeground(c, frame);
    });

    expect(ms, lessThan(2.0), reason: '$ms ms/khung');
  });

  test('sân khấu Orochi (8 cổ, đom đóm) vẽ dưới 2 ms/khung', () {
    final art = OrochiBossArt();
    final recorder = ui.PictureRecorder();
    art.paintBackdrop(ui.Canvas(recorder));
    final backdrop = recorder.endRecording();
    final battle = StageBattleState()..totalHeads = 8;

    final ms = measureMsPerFrame((c, i) {
      battle
        ..headsLeft = 8 - (i ~/ 30) % 8
        ..headHp = (i % 30) / 30;
      final frame = BossFrame(
        time: i / 30,
        attack: (i % 20) / 20,
        hurt: (i % 7) / 7,
        glint: -1,
        defeat: 0,
        battle: battle,
      );
      c.drawPicture(backdrop);
      art.paintAmbient(c, i / 30);
      art.paintBoss(c, frame);
      paintHero(c, HeroPose.plank(80 + i % 90), effort: (i % 10) / 10);
    });

    expect(ms, lessThan(2.0), reason: '$ms ms/khung');
  });

  test('sân khấu Fafnir (cực quang, tuyết, nhân vật lạnh cóng) dưới 2 ms', () {
    final art = FafnirBossArt();
    final recorder = ui.PictureRecorder();
    art.paintBackdrop(ui.Canvas(recorder));
    final backdrop = recorder.endRecording();
    final battle = StageBattleState();

    final ms = measureMsPerFrame((c, i) {
      battle.cold = (i % 30) / 30;
      final frame = BossFrame(
        time: i / 30,
        attack: (i % 20) / 20,
        hurt: (i % 7) / 7,
        glint: -1,
        defeat: 0,
        battle: battle,
      );
      c.drawPicture(backdrop);
      art.paintAmbient(c, i / 30);
      art.paintBoss(c, frame);
      paintHero(c, HeroPose.plank(80 + i % 90), frost: battle.cold);
    });

    expect(ms, lessThan(2.0), reason: '$ms ms/khung');
  });
  test('sân khấu Nemea (bụi Trì Trệ tan dần) vẽ dưới 2 ms/khung', () {
    final art = NemeaBossArt();
    final recorder = ui.PictureRecorder();
    art.paintStageBackdrop(ui.Canvas(recorder));
    final backdrop = recorder.endRecording();
    final battle = StageBattleState();

    final ms = measureMsPerFrame((c, i) {
      battle.bossHp = 1 - (i % 100) / 100;
      c.drawPicture(backdrop);
      art.paintScene(c, i / 30, battle);
      paintHero(
        c,
        HeroPose.plank(80 + i % 90),
        look: const HeroLook(fat: 0.5),
        cloak: i.isEven,
        effort: (i % 10) / 10,
      );
      paintLion(c, LionState(time: i / 30, hurt: (i % 7) / 7));
    });

    expect(ms, lessThan(2.0), reason: '$ms ms/khung');
  });
}
