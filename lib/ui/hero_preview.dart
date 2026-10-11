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
  // Không dùng `late ... ..start()`: late chỉ khởi tạo khi truy cập lần đầu
  // (lúc dispose), ticker sẽ không bao giờ chạy.
  late final Ticker _ticker = createTicker(_tick);
  double _seconds = 0;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

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
    canvas.clipRect(Offset.zero & size);
    _paintBackdrop(canvas, size);
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
    // Bệ đá cẩm thạch dưới chân: mặt trên sáng, thành bệ tối, mép viền.
    final plinthTop = Rect.fromCenter(
      center: Offset(content.center.dx, 223),
      width: content.width * 1.25,
      height: 14,
    );
    canvas.drawRect(
      Rect.fromLTRB(plinthTop.left, 223, plinthTop.right, 240),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFFB8AC98), background],
        ).createShader(Rect.fromLTRB(0, 223, 1, 240)),
    );
    canvas.drawOval(plinthTop, Paint()..color = const Color(0xFFD9CFBE));
    canvas.drawOval(
      plinthTop,
      Paint()
        ..color = const Color(0xFF8E8070)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
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
      time: seconds,
    );
    canvas.restore();
  }

  /// Phông xem trước: nền sẫm có quầng nắng ấm sau lưng nhân vật và hai
  /// cột Doric mờ hai bên (như đứng trong đền).
  void _paintBackdrop(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = background);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 0.8,
          colors: [
            const Color(0xFFE8B83A).withValues(alpha: 0.28),
            const Color(0xFFE8B83A).withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    final column = Paint()..color = const Color(0x22F3ECDC);
    final flute = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 1;
    final w = size.width * 0.07;
    for (final cx in [size.width * 0.12, size.width * 0.88]) {
      canvas.drawRect(
        Rect.fromLTWH(cx - w / 2, size.height * 0.08, w, size.height),
        column,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          cx - w * 0.75,
          size.height * 0.04,
          w * 1.5,
          size.height * 0.04,
        ),
        column,
      );
      for (var i = 1; i < 3; i++) {
        final x = cx - w / 2 + w * i / 3;
        canvas.drawLine(
          Offset(x, size.height * 0.08),
          Offset(x, size.height),
          flute,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HeroPreviewPainter old) => true;
}
