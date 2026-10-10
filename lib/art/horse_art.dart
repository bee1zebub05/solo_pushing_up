import 'dart:math' as math;
import 'dart:ui';

import 'vector_style.dart';

/// Ngựa chín hồng mao (lễ vật Sơn Tinh dâng vua Hùng; phần thưởng Kỳ công
/// 12): ngựa trắng, bờm đỏ chín chùm. Gốc toạ độ ở mặt đất giữa bốn chân,
/// mặt quay sang phải. [gallop] 0–1 là nhịp phi (0 = đứng yên).
void paintHorse(Canvas canvas, {double time = 0, double gallop = 0}) {
  const coat = Color(0xFFF4EFE6);
  const mane = Color(0xFFD7372C);
  final bob = math.sin(time * 9) * 2.5 * gallop;
  final swing = math.sin(time * 9) * 0.5 * gallop;

  // Chân: hai chân xa trước, hai chân gần sau; vung theo nhịp phi.
  void leg(double x, double phase, {required bool far}) {
    final a = swing * (phase.isNegative ? -1 : 1);
    final top = Offset(x, -38 + bob);
    final knee = top + Offset(math.sin(a) * 10, 18);
    final hoof = knee + Offset(math.sin(a * 1.6) * 8, 18);
    shadedChain(
      canvas,
      [(top, knee, 5.5, 4.2), (knee, hoof, 4.2, 3.6)],
      far ? darken(coat, 0.15) : coat,
      highlight: far ? 0 : 1,
    );
    canvas.drawOval(
      Rect.fromCenter(center: hoof + const Offset(1, 2), width: 9, height: 5),
      fillPaint(VectorStyle.outline),
    );
  }

  leg(-18, -1, far: true);
  leg(20, 1, far: true);

  // Đuôi đỏ.
  final tail = Path()
    ..moveTo(-34, -52 + bob)
    ..quadraticBezierTo(-52, -44 + swing * 10, -48, -24 + bob)
    ..quadraticBezierTo(-40, -36, -30, -46 + bob)
    ..close();
  shadedPath(canvas, tail, mane, PartFrame.world, shadow: 2, highlight: 1);

  // Thân.
  final body = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-36, -66 + bob, 72, 32),
        const Radius.circular(16),
      ),
    );
  shadedPath(canvas, body, coat, PartFrame.world, shadow: 4, highlight: 1.6);

  // Cổ và đầu.
  final neck = Path()
    ..moveTo(18, -60 + bob)
    ..lineTo(36, -92 + bob)
    ..lineTo(48, -88 + bob)
    ..lineTo(36, -50 + bob)
    ..close();
  shadedPath(canvas, neck, coat, PartFrame.world, shadow: 3, highlight: 1.2);
  final head = Path()
    ..moveTo(34, -96 + bob)
    ..quadraticBezierTo(46, -104 + bob, 58, -86 + bob)
    ..quadraticBezierTo(62, -80 + bob, 56, -78 + bob)
    ..quadraticBezierTo(46, -80 + bob, 38, -84 + bob)
    ..close();
  shadedPath(canvas, head, coat, PartFrame.world, shadow: 2.5, highlight: 1);
  // Tai, mắt, lỗ mũi.
  shadedPath(
    canvas,
    Path()
      ..moveTo(38, -98 + bob)
      ..lineTo(40, -108 + bob)
      ..lineTo(44, -99 + bob)
      ..close(),
    coat,
    PartFrame.world,
    shadow: 1,
    highlight: 0,
    outlineWidth: 1.2,
  );
  canvas.drawCircle(Offset(46, -92 + bob), 1.8, fillPaint(VectorStyle.outline));
  glint(canvas, Offset(45.4, -92.8 + bob), 0.8);
  canvas.drawCircle(Offset(57, -81 + bob), 1, fillPaint(VectorStyle.outline));

  // Chín chùm bờm đỏ dọc cổ, bay theo nhịp phi.
  for (var i = 0; i < 9; i++) {
    final t = i / 8;
    final root = Offset.lerp(Offset(38, -97 + bob), Offset(20, -62 + bob), t)!;
    final flow = Offset(-8 - gallop * 6, 4 + math.sin(time * 6 + i) * 2);
    shadedPath(
      canvas,
      Path()
        ..moveTo(root.dx + 2, root.dy - 2)
        ..quadraticBezierTo(
          root.dx + flow.dx * 0.6,
          root.dy + flow.dy - 6,
          root.dx + flow.dx,
          root.dy + flow.dy,
        )
        ..lineTo(root.dx + 1, root.dy + 3)
        ..close(),
      i.isEven ? mane : darken(mane, 0.12),
      PartFrame.world,
      shadow: 1,
      highlight: 0.6,
      outlineWidth: 1.1,
    );
  }

  leg(-24, 1, far: false);
  leg(26, -1, far: false);
}
