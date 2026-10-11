import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../art/battle_stage.dart';

/// Chân dung boss tròn cho thẻ kỳ công: cắt hình boss trên sân khấu quanh
/// điểm trúng đòn (đầu), có cả bối cảnh phía sau. Vẽ một lần, không hoạt hình.
class BossPortrait extends StatelessWidget {
  const BossPortrait({super.key, required this.art, this.size = 56});

  final BossArt art;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: ClipOval(child: CustomPaint(painter: _PortraitPainter(art))),
  );
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
      _paintPortrait(Canvas(recorder), px.toDouble());
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

  void _paintPortrait(Canvas canvas, double side) {
    // Khung vuông quanh mặt boss (mỗi boss tự khai báo tâm và độ rộng).
    final view = art.portraitView;
    final scale = side / view;
    final focus = art.portraitFocus;
    canvas.save();
    canvas.scale(scale);
    canvas.translate(view / 2 - focus.x, view / 2 - focus.y);
    art.paintBackdrop(canvas);
    art.paintBoss(
      canvas,
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
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PortraitPainter old) => old.art.artKey != art.artKey;
}
