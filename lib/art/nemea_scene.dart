import 'dart:math' as math;
import 'dart:ui';

/// Kích thước sân khấu chiến đấu (đơn vị vẽ); widget co giãn theo màn hình.
const stageSize = Size(400, 260);
const stageGroundY = 220.0;

/// Phông nền Thung lũng Nemea: trời chiều, đồi xa, hang sư tử hai cửa,
/// cột đá Hy Lạp đổ, mặt đất đất son, mây trôi và cỏ lay.
void paintNemeaScene(Canvas canvas, {double time = 0}) {
  paintNemeaBackdrop(canvas);
  paintNemeaAmbient(canvas, time: time);
}

/// Phần tĩnh của phông nền: vẽ một lần rồi giữ lại (Picture) để mỗi khung
/// không phải vẽ lại.
void paintNemeaBackdrop(Canvas canvas) {
  final w = stageSize.width;
  final h = stageSize.height;

  canvas.drawRect(
    Offset.zero & stageSize,
    Paint()
      ..shader = Gradient.linear(Offset.zero, Offset(0, stageGroundY), const [
        Color(0xFF6FA8DC),
        Color(0xFFF6D7A7),
      ]),
  );
  // Mặt trời chiều.
  canvas.drawCircle(
    const Offset(300, 70),
    26,
    Paint()
      ..color = const Color(0x55FFF3C4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
  );
  canvas.drawCircle(
    const Offset(300, 70),
    16,
    Paint()..color = const Color(0xFFFFF0B8),
  );

  _hills(canvas, base: 175, amp: 18, freq: 1.6, color: const Color(0xFF9DB07A));
  // Hang sư tử hai cửa trong núi phía sau con sư tử.
  final mountain = Path()
    ..moveTo(230, stageGroundY)
    ..quadraticBezierTo(300, 60, 400, 90)
    ..lineTo(400, stageGroundY)
    ..close();
  canvas.drawPath(mountain, Paint()..color = const Color(0xFF8C7A5B));
  for (final (x, r) in [(312.0, 30.0), (372.0, 20.0)]) {
    canvas.drawPath(
      Path()
        ..moveTo(x - r, stageGroundY)
        ..arcToPoint(Offset(x + r, stageGroundY), radius: Radius.circular(r))
        ..close(),
      Paint()..color = const Color(0xFF2E2418),
    );
  }
  _hills(canvas, base: 200, amp: 10, freq: 2.4, color: const Color(0xFF7E9A5C));

  // Cột đá đổ bên trái.
  final stone = Paint()..color = const Color(0xFFE8E0CC);
  final stoneShade = Paint()..color = const Color(0xFFBDB49C);
  canvas.drawRect(const Rect.fromLTWH(8, 120, 14, 100), stone);
  canvas.drawRect(const Rect.fromLTWH(17, 120, 5, 100), stoneShade);
  canvas.drawRect(const Rect.fromLTWH(4, 114, 22, 8), stone);
  canvas.drawRect(const Rect.fromLTWH(30, 196, 14, 24), stone);

  // Mặt đất.
  canvas.drawRect(
    Rect.fromLTRB(0, stageGroundY - 4, w, h),
    Paint()
      ..shader = Gradient.linear(Offset(0, stageGroundY), Offset(0, h), const [
        Color(0xFFC9A26A),
        Color(0xFF9C7745),
      ]),
  );
}

void _hills(
  Canvas canvas, {
  required double base,
  required double amp,
  required double freq,
  required Color color,
}) {
  final path = Path()..moveTo(0, stageGroundY);
  for (var x = 0.0; x <= stageSize.width; x += 8) {
    path.lineTo(
      x,
      base -
          amp *
              (0.5 + 0.5 * math.sin(x / stageSize.width * math.pi * freq + 1)),
    );
  }
  path
    ..lineTo(stageSize.width, stageGroundY)
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}

/// Phần động của phông nền: mây trôi, cỏ lay theo [time] (giây).
void paintNemeaAmbient(Canvas canvas, {double time = 0}) {
  final w = stageSize.width;
  // Mây trôi chậm.
  final cloud = Paint()..color = const Color(0xCCFFFFFF);
  for (final (x0, y, s) in [(40.0, 40.0, 1.0), (220.0, 28.0, 0.7)]) {
    final x = (x0 + time * 4 * s) % (w + 80) - 40;
    for (final (dx, dy, r) in [
      (0.0, 0.0, 12.0),
      (14.0, -5.0, 15.0),
      (30.0, 0.0, 11.0),
    ]) {
      canvas.drawCircle(Offset(x + dx * s, y + dy * s), r * s, cloud);
    }
  }

  final grass = Paint()
    ..color = const Color(0xFF6E8B45)
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;
  final rnd = math.Random(7);
  for (var i = 0; i < 26; i++) {
    final x = rnd.nextDouble() * w;
    final sway = math.sin(time * 1.5 + i) * 1.5;
    canvas.drawLine(
      Offset(x, stageGroundY - 3),
      Offset(x - 2 + sway, stageGroundY - 9),
      grass,
    );
    canvas.drawLine(
      Offset(x + 2, stageGroundY - 3),
      Offset(x + 4 + sway, stageGroundY - 8),
      grass,
    );
  }
}
