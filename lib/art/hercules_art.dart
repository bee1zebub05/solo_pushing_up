import 'dart:math' as math;
import 'dart:ui';

import 'vector_style.dart';

/// Hercules: linh hồn huyền thoại dẫn đường cho người kế nhiệm (cảnh mở đầu
/// Kỳ công 1). Hình tượng cổ điển: râu xoăn, vòng nguyệt quế, chuỳ gỗ ô liu
/// chống đất; khoác áo choàng đỏ viền hoa văn Hy Lạp, hào quang vàng.
///
/// Quay mặt sang trái, gốc toạ độ ở mặt đất giữa hai chân, cao khoảng 240.
/// [appear] 0–1: hiện ra từ ánh sáng. [talk] > 0: đang nói (miệng mấp máy,
/// tay đưa về phía người chơi).
void paintHercules(
  Canvas canvas, {
  double time = 0,
  double appear = 1,
  double talk = 0,
}) {
  const skin = Color(0xFFC98B5A);
  const skinFar = Color(0xFFA9714A);
  const cloth = Color(0xFFF2EBDD);
  const robe = Color(0xFF9E2B25);
  const gold = Color(0xFFE8B83A);
  final a = appear.clamp(0.0, 1.0);
  final breath = math.sin(time * 1.6);
  final gesture = math.sin(time * 3.2) * talk;

  // Hào quang: vầng sáng và tia toả sau lưng.
  final aura = const Offset(0, -140);
  canvas.drawCircle(
    aura,
    150,
    Paint()
      ..shader = Gradient.radial(
        aura,
        150,
        [
          Color.fromRGBO(255, 222, 130, 0.55 * a),
          Color.fromRGBO(255, 200, 90, 0.18 * a),
          const Color(0x00FFC85A),
        ],
        const [0, 0.5, 1],
      ),
  );
  final ray = Paint()..color = Color.fromRGBO(255, 236, 170, 0.18 * a);
  for (var i = 0; i < 12; i++) {
    final ang = i * math.pi / 6 + time * 0.12;
    canvas.drawPath(
      Path()
        ..moveTo(aura.dx, aura.dy)
        ..lineTo(
          aura.dx + math.cos(ang - 0.06) * 170,
          aura.dy + math.sin(ang - 0.06) * 170,
        )
        ..lineTo(
          aura.dx + math.cos(ang + 0.06) * 170,
          aura.dy + math.sin(ang + 0.06) * 170,
        )
        ..close(),
      ray,
    );
  }

  // Hiện dần: mờ + trồi lên từ ánh sáng.
  canvas.save();
  canvas.translate(0, 30 * (1 - a));
  canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a));

  // Chuỳ gỗ ô liu chống đất, tay xa tì lên đầu chuỳ.
  final club = Path()
    ..moveTo(40, -132)
    ..cubicTo(36, -90, 40, -50, 38, -6)
    ..cubicTo(44, 2, 66, 2, 70, -8)
    ..cubicTo(64, -50, 54, -96, 50, -134)
    ..close();
  shadedPath(canvas, club, const Color(0xFF7A5634), PartFrame.world, shadow: 5);
  // Mấu gỗ trên chuỳ.
  for (final (x, y, r) in [
    (52.0, -40.0, 4.0),
    (60.0, -20.0, 5.0),
    (44.0, -70.0, 3.0),
    (62.0, -60.0, 3.5),
  ]) {
    final knot = Path()
      ..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));
    shadedPath(
      canvas,
      knot,
      const Color(0xFF5E4026),
      PartFrame.world,
      shadow: 1.5,
    );
  }

  // Tay xa: từ vai xuống đầu chuỳ.
  shadedChain(canvas, [
    (const Offset(26, -184), const Offset(42, -152), 12, 10),
    (const Offset(42, -152), const Offset(45, -132), 10, 9),
  ], skinFar);

  // Chân: bắp chân to, dép quai đan.
  for (final (hip, knee, foot, c) in [
    (
      const Offset(12, -108),
      const Offset(20, -56),
      const Offset(22, -8),
      skinFar,
    ),
    (
      const Offset(-10, -108),
      const Offset(-20, -56),
      const Offset(-24, -8),
      skin,
    ),
  ]) {
    shadedChain(canvas, [(hip, knee, 15, 11), (knee, foot, 12, 8)], c);
    final sandal = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: foot + const Offset(-6, 5),
            width: 28,
            height: 8,
          ),
          const Radius.circular(4),
        ),
      );
    shadedPath(
      canvas,
      sandal,
      const Color(0xFF6B4A2C),
      PartFrame.world,
      shadow: 2,
    );
    final strap = Paint()
      ..color = const Color(0xFF4A3220)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        foot + Offset(-8, -6.0 - i * 8),
        foot + Offset(8, -2.0 - i * 8),
        strap,
      );
    }
  }

  // Váy chiton trắng xếp ly, viền vàng.
  final skirt = Path()
    ..moveTo(-30, -126)
    ..lineTo(30, -126)
    ..lineTo(36, -78)
    ..quadraticBezierTo(0, -70, -38, -78)
    ..close();
  shadedPath(canvas, skirt, cloth, PartFrame.world, shadow: 5);
  final pleat = Paint()
    ..color = const Color(0xFFCFC3AE)
    ..strokeWidth = 1.2;
  for (var i = 0; i < 6; i++) {
    canvas.drawLine(
      Offset(-22 + i * 9.0, -120),
      Offset(-26 + i * 11.0, -78),
      pleat,
    );
  }
  canvas.drawLine(
    const Offset(-37, -79),
    const Offset(35, -79),
    Paint()
      ..color = gold
      ..strokeWidth = 3,
  );

  // Thân trên cơ bắp, phập phồng theo nhịp thở.
  final torso = Path()
    ..moveTo(-24, -124)
    ..cubicTo(-30, -150, -44, -168, -38, -190 - breath)
    ..quadraticBezierTo(0, -200 - breath, 36, -190 - breath)
    ..cubicTo(40, -168, 28, -150, 24, -124)
    ..close();
  shadedPath(canvas, torso, skin, PartFrame.world, shadow: 6);
  final muscle = Paint()
    ..color = const Color(0xFF9A6440)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;
  // Ngực, bụng sáu múi.
  canvas.drawArc(
    Rect.fromLTWH(-34, -188 - breath, 30, 22),
    0.3,
    2.4,
    false,
    muscle,
  );
  for (var r = 0; r < 3; r++) {
    for (final x in [-12.0, -2.0]) {
      canvas.drawArc(
        Rect.fromLTWH(x, -160 + r * 11.0, 9, 9),
        0.4,
        2.2,
        false,
        muscle,
      );
    }
  }

  // Áo choàng đỏ vắt chéo vai, viền hoa văn chìa khoá Hy Lạp.
  final drape = Path()
    ..moveTo(-40, -194)
    ..quadraticBezierTo(-8, -200, 30, -192)
    ..lineTo(44, -150)
    ..quadraticBezierTo(40, -120, 34, -100)
    ..lineTo(22, -104)
    ..quadraticBezierTo(18, -140, -32, -176)
    ..close();
  shadedPath(canvas, drape, robe, PartFrame.world, shadow: 5);
  final meander = Paint()
    ..color = gold
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  final border = Path()..moveTo(-30, -178);
  for (var i = 0; i < 7; i++) {
    final p = Offset.lerp(
      const Offset(-30, -178),
      const Offset(22, -108),
      i / 7,
    )!;
    border
      ..lineTo(p.dx, p.dy)
      ..lineTo(p.dx + 4, p.dy - 2)
      ..lineTo(p.dx + 5, p.dy + 3)
      ..lineTo(p.dx + 2, p.dy + 4);
  }
  canvas.drawPath(border, meander);
  // Trâm cài vàng trên vai.
  canvas.drawCircle(
    const Offset(-30, -188),
    5,
    goldPaint(const Rect.fromLTWH(-35, -193, 10, 10)),
  );
  canvas.drawCircle(
    const Offset(-30, -188),
    5,
    Paint()
      ..color = VectorStyle.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );

  // Cổ và đầu.
  shadedChain(canvas, [
    (const Offset(-2, -192), const Offset(-4, -206), 11, 10),
  ], skin);
  _herculesHead(canvas, const Offset(-6, -222), time, talk);

  // Tay gần: giơ về phía người chơi, lòng bàn tay mở khi nói.
  final elbow = Offset(-60, -160 - 6 * talk);
  final hand = Offset(-84 - 4 * gesture, -180 - 14 * talk + 4 * gesture);
  shadedChain(canvas, [
    (const Offset(-34, -184), elbow, 14, 11),
    (elbow, hand, 11, 9),
  ], skin);
  // Vòng tay vàng.
  canvas.drawLine(
    Offset.lerp(elbow, hand, 0.55)! + const Offset(-2, -7),
    Offset.lerp(elbow, hand, 0.55)! + const Offset(4, 7),
    Paint()
      ..color = gold
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round,
  );
  final palm = Path()
    ..addOval(
      Rect.fromCenter(
        center: hand + const Offset(-6, -2),
        width: 16,
        height: 13,
      ),
    );
  shadedPath(canvas, palm, skin, PartFrame.world, shadow: 2);
  // Ngón cái.
  shadedChain(canvas, [
    (hand + const Offset(-4, -6), hand + const Offset(-10, -14), 3, 2.5),
  ], skin);

  canvas.restore();
  canvas.restore();
}

void _herculesHead(Canvas canvas, Offset c, double time, double talk) {
  const skin = Color(0xFFC98B5A);
  const hair = Color(0xFF4A3020);
  const grey = Color(0xFF9C9086);
  // Tóc xoăn phía sau đầu: chùm tròn.
  final curls = Path();
  for (final (dx, dy, r) in [
    (10.0, -16.0, 9.0),
    (18.0, -6.0, 9.0),
    (16.0, 6.0, 8.0),
    (0.0, -20.0, 9.0),
    (-12.0, -18.0, 8.0),
  ]) {
    curls.addOval(Rect.fromCircle(center: c + Offset(dx, dy), radius: r));
  }
  shadedPath(canvas, curls, hair, PartFrame.world, shadow: 3);
  // Mặt nghiêng: trán, sống mũi thẳng kiểu tượng Hy Lạp.
  final face = Path()
    ..moveTo(c.dx + 10, c.dy - 14)
    ..quadraticBezierTo(c.dx - 10, c.dy - 18, c.dx - 16, c.dy - 6)
    ..lineTo(c.dx - 22, c.dy + 4)
    ..lineTo(c.dx - 16, c.dy + 6)
    ..lineTo(c.dx - 12, c.dy + 18)
    ..quadraticBezierTo(c.dx + 4, c.dy + 22, c.dx + 14, c.dy + 8)
    ..close();
  shadedPath(canvas, face, skin, PartFrame.world, shadow: 4);
  // Râu xoăn dày điểm bạc.
  final beard = Path();
  for (final (dx, dy, r) in [
    (-12.0, 12.0, 6.0),
    (-6.0, 18.0, 7.0),
    (2.0, 20.0, 7.0),
    (10.0, 14.0, 6.0),
    (-2.0, 26.0, 6.0),
    (8.0, 24.0, 5.0),
  ]) {
    beard.addOval(Rect.fromCircle(center: c + Offset(dx, dy), radius: r));
  }
  shadedPath(canvas, beard, hair, PartFrame.world, shadow: 2.5);
  for (final (dx, dy) in [(-6.0, 18.0), (6.0, 22.0), (-2.0, 26.0)]) {
    canvas.drawArc(
      Rect.fromCircle(center: c + Offset(dx, dy), radius: 3),
      3.4,
      2.4,
      false,
      Paint()
        ..color = grey
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }
  // Miệng: mấp máy khi nói.
  final open = talk > 0 ? (0.5 + 0.5 * math.sin(time * 14)) * talk : 0.0;
  canvas.drawOval(
    Rect.fromCenter(
      center: c + const Offset(-12, 11),
      width: 6,
      height: 1.6 + 4 * open,
    ),
    Paint()..color = const Color(0xFF3A1A14),
  );
  // Ria mép.
  canvas.drawPath(
    Path()
      ..moveTo(c.dx - 18, c.dy + 9)
      ..quadraticBezierTo(c.dx - 12, c.dy + 5, c.dx - 4, c.dy + 9)
      ..quadraticBezierTo(c.dx - 10, c.dy + 8, c.dx - 18, c.dy + 9)
      ..close(),
    Paint()..color = hair,
  );
  // Mắt nghiêm nghị, mày rậm.
  final eye = c + const Offset(-10, -3);
  canvas.drawOval(
    Rect.fromCenter(center: eye, width: 6, height: 4),
    Paint()..color = const Color(0xFFFFFBF0),
  );
  canvas.drawCircle(
    eye + const Offset(-1, 0),
    1.6,
    Paint()..color = const Color(0xFF3B2A1E),
  );
  canvas.drawLine(
    eye + const Offset(-5, -4),
    eye + const Offset(5, -5),
    Paint()
      ..color = hair
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round,
  );
  // Tai.
  final ear = Path()
    ..addOval(
      Rect.fromCenter(center: c + const Offset(6, 0), width: 7, height: 10),
    );
  shadedPath(canvas, ear, skin, PartFrame.world, shadow: 1.5);
  // Vòng nguyệt quế vàng xanh quanh đầu.
  final leaf = Paint()..color = const Color(0xFF8DA548);
  final leafDark = Paint()..color = const Color(0xFF5E7A30);
  for (var i = 0; i < 8; i++) {
    final t = i / 7;
    final p =
        Offset.lerp(c + const Offset(-14, -12), c + const Offset(16, -10), t)! +
        Offset(0, -math.sin(t * math.pi) * 8);
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(0.5 * side + 0.3);
      canvas.drawOval(
        const Rect.fromLTWH(-1.6, -6, 3.2, 6),
        side < 0 ? leaf : leafDark,
      );
      canvas.restore();
    }
  }
  glint(canvas, c + const Offset(-6, -16), 2.2, alpha: 0.5);
}
