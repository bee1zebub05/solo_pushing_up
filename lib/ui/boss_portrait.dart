import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../art/battle_stage.dart';
import '../art/bosses/boss_registry.dart';
import '../game/battle.dart';
import '../game/labors.dart';

/// Chân dung boss tròn cho thẻ kỳ công / màn: cắt hình boss trên sân khấu
/// quanh mặt, có cả bối cảnh phía sau. Kẻ thù đã dựng Blender dùng ảnh chụp
/// sẵn `assets/portraits/<id>.webp` (test/art/art_bake_test.dart) —
/// không phải nạp atlas sprite 2048² chỉ để vẽ một hình tròn nhỏ; kẻ thù
/// khác vẽ bản vector.
class BossPortrait extends StatelessWidget {
  const BossPortrait({super.key, required this.enemy, this.size = 56});

  final EnemySpec enemy;
  final double size;

  /// Kẻ thù đã có chân dung chụp sẵn: các màn chương 1 (sprite Blender).
  /// test/art/art_bake_test.dart kiểm tra tập này khớp assets/portraits.
  static final baked = {for (final s in nemea.allStages) s.enemy.id};

  static String assetFor(String enemyId) => 'assets/portraits/$enemyId.webp';

  @override
  Widget build(BuildContext context) {
    final id = enemy.id;
    final art = baked.contains(id) ? null : bossArtFor(enemy);
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: art == null
            ? Image.asset(
                assetFor(id),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              )
            : CustomPaint(painter: _PortraitPainter(art)),
      ),
    );
  }
}

/// Vẽ chân dung [art] vào ô vuông cạnh [side]: khung quanh mặt boss (mỗi boss
/// tự khai báo tâm và độ rộng), phông nền rồi boss. Dùng cho bản vector lúc
/// chạy và cho bước chụp sẵn ảnh từ sprite Blender. [stageScene]: vẽ phông
/// như trong trận (các tầng Blender đã nạp) thay cho phông vector tĩnh.
/// [focus]/[view]: khung riêng thay cho khung khai báo trong [art], và
/// [battle]: trạng thái trận để vẽ cảnh (bụi tan…).
void paintBossPortrait(
  Canvas canvas,
  BossArt art,
  double side, {
  bool stageScene = false,
  Offset? focus,
  double? view,
  StageBattleState? battle,
}) {
  view ??= art.portraitView;
  focus ??= Offset(art.portraitFocus.x, art.portraitFocus.y);
  battle ??= StageBattleState()
    ..totalHeads = 8
    ..headsLeft = 8;
  canvas.save();
  canvas.scale(side / view);
  canvas.translate(view / 2 - focus.dx, view / 2 - focus.dy);
  if (stageScene) {
    if (art.hasStageBackdrop) art.paintStageBackdrop(canvas);
    art.paintScene(canvas, 0.4, battle);
  } else {
    art.paintBackdrop(canvas);
  }
  art.paintBoss(
    canvas,
    BossFrame(
      time: 0.4,
      attack: 0.6,
      hurt: 0,
      glint: -1,
      defeat: 0,
      battle: battle,
    ),
  );
  canvas.restore();
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.art);

  final BossArt art;

  /// Ảnh chân dung đã chụp, theo loại boss và cỡ điểm ảnh. Impeller không
  /// tự cache hình vector: không có ảnh này thì mỗi khung cuộn danh sách
  /// GPU phải tô lại cả phông + boss của mọi thẻ.
  static final _cache = <(Object, int), ui.Image>{};

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    if (side <= 0) return;
    final dpr =
        ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 3;
    final px = (side * dpr).ceil();
    final image = _cache.putIfAbsent((art.artKey, px), () {
      final recorder = ui.PictureRecorder();
      paintBossPortrait(Canvas(recorder), art, px.toDouble());
      final picture = recorder.endRecording();
      final img = picture.toImageSync(px, px);
      picture.dispose();
      return img;
    });
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, side, side),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_PortraitPainter old) => old.art.artKey != art.artKey;
}
