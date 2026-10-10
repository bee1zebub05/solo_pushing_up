import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/hero_art.dart';
import '../art/hero_pose.dart';

/// Xem trước nhân vật, có hoạt hình (thở khi đứng, hít đất liên tục).
class HeroPreview extends StatefulWidget {
  const HeroPreview({
    super.key,
    required this.look,
    this.pushups = false,
    this.cloak = false,
    this.shield = false,
    this.sword = false,
    this.background = const Color(0xFF2A2420),
  });

  final HeroLook look;
  final bool pushups;
  final bool cloak;
  final bool shield;
  final bool sword;
  final Color background;

  @override
  State<HeroPreview> createState() => _HeroPreviewState();
}

class _HeroPreviewState extends State<HeroPreview>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick)..start();
  double _seconds = 0;

  void _tick(Duration elapsed) =>
      setState(() => _seconds = elapsed.inMicroseconds / 1e6);

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _HeroPreviewPainter(
      look: widget.look,
      pushups: widget.pushups,
      cloak: widget.cloak,
      shield: widget.shield,
      sword: widget.sword,
      seconds: _seconds,
      background: widget.background,
    ),
    child: const SizedBox.expand(),
  );
}

class _HeroPreviewPainter extends CustomPainter {
  _HeroPreviewPainter({
    required this.look,
    required this.pushups,
    required this.cloak,
    required this.shield,
    required this.sword,
    required this.seconds,
    required this.background,
  });

  final HeroLook look;
  final bool pushups;
  final bool cloak;
  final bool shield;
  final bool sword;
  final double seconds;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    // Vùng nội dung trên sân khấu: đứng ở x≈110, chống đẩy trải 30–215.
    final content = pushups
        ? const Rect.fromLTRB(10, 105, 250, 230)
        : const Rect.fromLTRB(50, 8, 170, 230);
    final scale = math.min(
      size.width / content.width,
      size.height / content.height,
    );
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-content.center.dx, -content.center.dy);
    // Bóng dưới chân.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(content.center.dx, 222),
        width: content.width * 0.9,
        height: 8,
      ),
      Paint()..color = Colors.black26,
    );
    final angle = 117 + 62 * math.cos(seconds * 2 * math.pi / 1.6);
    final pose = pushups
        ? HeroPose.plank(angle)
        : HeroPose.standing(breath: seconds / 3);
    paintHero(
      canvas,
      pose,
      look: look,
      cloak: cloak,
      shield: shield,
      sword: sword,
      effort: pushups ? ((165 - angle) / 80).clamp(0.0, 1.0) : 0,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeroPreviewPainter old) => true;
}
