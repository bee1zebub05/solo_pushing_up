import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/art/battle_stage.dart';
import 'package:solo_pushing_up/art/bosses/nemea_boss.dart';
import 'package:solo_pushing_up/art/hero_art.dart';
import 'package:solo_pushing_up/art/hero_pose.dart';
import 'package:solo_pushing_up/art/nemea_scene.dart';
import 'package:solo_pushing_up/art/vector_style.dart';

/// Bản thử: cùng một khung trận Nemea ở dạng vector và dạng "pixel" (vẽ ở độ
/// phân giải thấp rồi phóng to giữ hạt, có/không giảm màu). Chỉ để so sánh
/// phong cách — chạy với ART_PREVIEW=1, ảnh ở build/art_preview/pixel_*.png.
void main() {
  testWidgets('so sánh vector và pixel', (tester) async {
    if (Platform.environment['ART_PREVIEW'] != '1') return;

    final art = NemeaBossArt();
    final battle = StageBattleState()..bossHp = 0.5;
    for (var t = 0.0; t < 3; t += 1 / 30) {
      art.paintScene(ui.Canvas(ui.PictureRecorder()), t, battle);
    }
    final frame = BossFrame(
      time: 3,
      attack: 0,
      hurt: 0,
      glint: -1,
      defeat: 0,
      battle: battle,
      attackPhase: 0.55,
    );
    void scene(ui.Canvas c) {
      art.paintStageBackdrop(c);
      art.paintScene(c, 3, battle);
      art.paintBoss(c, frame);
      paintHero(c, HeroPose.plank(110), effort: 0.6, cloak: true, time: 3);
      art.paintForeground(c, frame);
      paintStageGrade(c, Offset.zero & stageSize, light: art.gradeLight);
    }

    const outW = 800, outH = 520;

    Future<ui.Image> draw(double scale) async {
      final r = ui.PictureRecorder();
      final c = ui.Canvas(r)..scale(scale);
      scene(c);
      return r.endRecording().toImage(
        (stageSize.width * scale).round(),
        (stageSize.height * scale).round(),
      );
    }

    /// Giảm màu: mỗi kênh còn [levels] mức (gần với bảng màu giới hạn).
    Future<ui.Image> posterize(ui.Image src, int levels) async {
      final data = (await src.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final px = Uint8List.fromList(data.buffer.asUint8List());
      final step = 255 / (levels - 1);
      for (var i = 0; i < px.length; i += 4) {
        for (var k = 0; k < 3; k++) {
          px[i + k] = ((px[i + k] / step).round() * step).round().clamp(0, 255);
        }
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(px);
      final desc = ui.ImageDescriptor.raw(
        buffer,
        width: src.width,
        height: src.height,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final codec = await desc.instantiateCodec();
      return (await codec.getNextFrame()).image;
    }

    /// Phóng to giữ hạt (nearest neighbor) lên cỡ ảnh so sánh.
    Future<void> save(String name, ui.Image img) async {
      final r = ui.PictureRecorder();
      final c = ui.Canvas(r);
      c.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        const Rect.fromLTWH(0, 0, outW + 0.0, outH + 0.0),
        Paint()..filterQuality = FilterQuality.none,
      );
      final out = await r.endRecording().toImage(outW, outH);
      final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
      File('build/art_preview/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    }

    await tester.runAsync(() async {
      await save('pixel_0_vector', await draw(2));
      await save('pixel_1_half', await draw(0.5));
      await save('pixel_2_third', await draw(1 / 3));
      await save(
        'pixel_3_third_palette',
        await posterize(await draw(1 / 3), 6),
      );
    });
  });
}
