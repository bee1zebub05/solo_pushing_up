import 'dart:math' as math;
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

  /// Bụi Trì Trệ: đậm nhất khi sư tử còn đầy máu, tan dần mỗi đòn trúng.
  static const maxDust = 0.85;

  /// Bản phủ bụi vẽ một lần; mỗi khung chỉ vẽ lại với độ đục khác.
  late final Picture _dusty = () {
    final recorder = PictureRecorder();
    paintNemeaDusty(Canvas(recorder));
    return recorder.endRecording();
  }();

  double _dust = maxDust;
  double _lastTime = 0;

  @override
  void paintScene(Canvas canvas, double time, StageBattleState battle) {
    // Tan mượt (không giật theo từng đòn).
    final dt = (time - _lastTime).clamp(0.0, 0.1);
    _lastTime = time;
    final target = maxDust * battle.bossHp.clamp(0.0, 1.0);
    _dust += (target - _dust) * (1 - math.exp(-dt * 2.5));
    if (_dust > 0.01) {
      canvas.saveLayer(
        Offset.zero & stageSize,
        Paint()..color = Color.fromRGBO(0, 0, 0, _dust),
      );
      canvas.drawPicture(_dusty);
      canvas.restore();
    }
    paintNemeaAmbient(canvas, time: time, dust: _dust);
  }

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
