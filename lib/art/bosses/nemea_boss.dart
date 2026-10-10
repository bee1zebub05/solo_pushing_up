import 'dart:ui';

import 'package:flame/components.dart';

import '../battle_stage.dart';
import '../lion_art.dart';
import '../nemea_scene.dart';

/// Vị trí và tỉ lệ Sư tử Nemea trên sân khấu 400×260.
const lionX = 335.0;
const lionScale = 0.72;

/// Kỳ công 1 — Sư tử Nemea ở thung lũng Nemea.
class NemeaBossArt extends BossArt {
  @override
  final Vector2 target = Vector2(
    lionX - 72 * lionScale,
    stageGroundY - 96 * lionScale,
  );

  @override
  void paintBackdrop(Canvas canvas) => paintNemeaBackdrop(canvas);

  @override
  void paintAmbient(Canvas canvas, double time) =>
      paintNemeaAmbient(canvas, time: time);

  @override
  void paintBoss(Canvas canvas, BossFrame f) {
    canvas.save();
    canvas.translate(lionX, stageGroundY);
    canvas.scale(lionScale);
    paintLion(
      canvas,
      LionState(
        time: f.time,
        mouth: f.attack,
        hurt: f.hurt,
        glint: f.glint,
        defeat: f.defeat,
      ),
    );
    canvas.restore();
  }
}
