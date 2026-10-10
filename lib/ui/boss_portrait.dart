import 'dart:math' as math;

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

  @override
  void paint(Canvas canvas, Size size) {
    // Khung vuông quanh mặt boss (mỗi boss tự khai báo tâm và độ rộng).
    final view = art.portraitView;
    final scale = math.min(size.width, size.height) / view;
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
  bool shouldRepaint(_PortraitPainter old) =>
      old.art.runtimeType != art.runtimeType;
}
