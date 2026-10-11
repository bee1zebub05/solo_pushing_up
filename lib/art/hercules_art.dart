import 'dart:math' as math;
import 'dart:ui';

import 'vector_style.dart';

/// Hercules: linh hồn huyền thoại dẫn đường cho người kế nhiệm (cảnh mở đầu
/// Kỳ công 1). Hình tượng cổ điển: râu xoăn, vòng nguyệt quế, chuỳ gỗ ô liu
/// chống đất có vắt da sư tử Nemea (theo tượng Farnese Hercules), thân cơ
/// bắp đồ sộ, hào quang vàng.
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

  // Cột sáng giáng xuống lúc xuất hiện, tắt dần khi đã hiện đủ.
  final beam = 1 - a;
  if (a < 1) {
    canvas.drawRect(
      const Rect.fromLTRB(-46, -400, 46, 0),
      Paint()
        ..shader = Gradient.linear(
          const Offset(-46, 0),
          const Offset(46, 0),
          [
            const Color(0x00FFE9A8),
            Color.fromRGBO(255, 236, 170, 0.55 * beam + 0.25 * a * (1 - a) * 4),
            const Color(0x00FFE9A8),
          ],
          const [0, 0.5, 1],
        ),
    );
  }
  // Hạt ánh vàng bay lên quanh người (thần lực), luôn lấp lánh nhẹ.
  for (var i = 0; i < 14; i++) {
    final phase = (time * 0.4 + i / 14) % 1;
    final x = -60 + (i * 37 % 120) + math.sin(time * 2 + i) * 6;
    final y = -10 - phase * 230;
    final twinkle = 0.5 + 0.5 * math.sin(time * 6 + i * 1.7);
    canvas.drawCircle(
      Offset(x, y),
      1.2 + twinkle * 1.4,
      Paint()
        ..color = Color.fromRGBO(
          255,
          232,
          150,
          (0.3 + 0.6 * (1 - a)) * twinkle * (1 - phase),
        ),
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
  // Vân gỗ dọc chuỳ.
  final grain = Paint()
    ..color = const Color(0xFF4E3620)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.9
    ..strokeCap = StrokeCap.round;
  for (final (x0, x1) in [(44.0, 46.0), (48.0, 56.0), (52.0, 64.0)]) {
    canvas.drawPath(
      Path()
        ..moveTo(x0, -124)
        ..cubicTo(x0 - 2, -80, x1 - 4, -40, x1, -8),
      grain,
    );
  }
  // Mấu cành gãy chĩa ra (gỗ ô liu sần), mặt cắt sáng màu.
  for (final (from, to) in [
    (const Offset(56, -40), const Offset(66, -46)),
    (const Offset(62, -20), const Offset(72, -22)),
    (const Offset(44, -70), const Offset(36, -76)),
    (const Offset(54, -88), const Offset(60, -96)),
  ]) {
    shadedChain(
      canvas,
      [(from, to, 3.4, 2.6)],
      const Color(0xFF6A4A2C),
      shadow: 1.5,
    );
    canvas.drawCircle(to, 2, Paint()..color = const Color(0xFFC9A577));
  }
  // Da sư tử Nemea vắt lên đầu chuỳ (như tượng Farnese Hercules).
  _peltOnClub(canvas, time);

  // Tay xa: từ vai xuống đầu chuỳ, tì lên da sư tử.
  shadedLimb(
    canvas,
    [
      (const Offset(26, -186), const Offset(40, -154), _hUpperArm),
      (const Offset(40, -154), const Offset(46, -134), _hForearm),
    ],
    skinFar,
    shadow: 4,
  );

  // Chân theo tư thế dồn trọng lượng (contrapposto): chân gần thẳng chịu
  // lực, chân xa chùng gối.
  for (final (hip, knee, ankle, c) in [
    (
      const Offset(14, -112),
      const Offset(26, -62),
      const Offset(24, -12),
      skinFar,
    ),
    (
      const Offset(-10, -112),
      const Offset(-16, -60),
      const Offset(-20, -12),
      skin,
    ),
  ]) {
    shadedLimb(
      canvas,
      [(hip, knee, _hThigh), (knee, ankle, _hShin)],
      c,
      shadow: 5,
    );
    // Xương bánh chè (sel-line).
    canvas.drawArc(
      Rect.fromCircle(center: knee + const Offset(-3, 0), radius: 5),
      2.2,
      2.0,
      false,
      Paint()
        ..color = darken(c, 0.3).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    final foot = ankle + const Offset(-4, 4);
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

  // Khố chiton ngắn trắng, viền vàng (để lộ đùi và cơ bụng).
  final skirt = Path()
    ..moveTo(-26, -128)
    ..lineTo(26, -128)
    ..lineTo(32, -96)
    ..quadraticBezierTo(0, -88, -32, -96)
    ..close();
  shadedPath(canvas, skirt, cloth, PartFrame.world, shadow: 5);
  final pleat = Paint()
    ..color = const Color(0xFFCFC3AE)
    ..strokeWidth = 1.2;
  for (var i = 0; i < 6; i++) {
    canvas.drawLine(
      Offset(-20 + i * 8.0, -124),
      Offset(-24 + i * 10.0, -96),
      pleat,
    );
  }
  canvas.drawLine(
    const Offset(-30, -128),
    const Offset(30, -128),
    Paint()
      ..color = const Color(0xFF6B4A2C)
      ..strokeWidth = 4,
  );
  canvas.drawLine(
    const Offset(-31, -97),
    const Offset(31, -97),
    Paint()
      ..color = gold
      ..strokeWidth = 2.4,
  );

  _heroicTorso(canvas, skin, breath);

  // Cổ và đầu.
  shadedChain(canvas, [
    (const Offset(-2, -194), const Offset(-4, -208), 13, 11),
  ], skin);
  // Cơ ức đòn chũm chạy chéo từ sau tai xuống hõm cổ.
  canvas.drawLine(
    const Offset(2, -210),
    const Offset(-8, -196),
    Paint()
      ..color = darken(skin, 0.28).withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round,
  );
  _herculesHead(canvas, const Offset(-6, -222), time, talk);

  // Tay gần: giơ về phía người chơi, lòng bàn tay mở khi nói.
  final elbow = Offset(-60, -160 - 6 * talk);
  final hand = Offset(-84 - 4 * gesture, -180 - 14 * talk + 4 * gesture);
  shadedLimb(
    canvas,
    [(const Offset(-34, -186), elbow, _hUpperArm), (elbow, hand, _hForearm)],
    skin,
    shadow: 4,
  );
  // Khối cơ vai tròn trùm đầu cánh tay (sel-line) + rãnh bắp tay.
  final muscleLine = Paint()
    ..color = darken(skin, 0.3).withValues(alpha: 0.7)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.3
    ..strokeCap = StrokeCap.round;
  canvas.drawArc(
    Rect.fromCircle(center: const Offset(-36, -184), radius: 13),
    1.0,
    2.4,
    false,
    muscleLine,
  );
  final upper = elbow - const Offset(-34, -186);
  final un = Offset(-upper.dy, upper.dx) / upper.distance;
  final mid = Offset.lerp(const Offset(-34, -186), elbow, 0.55)!;
  canvas.drawPath(
    Path()
      ..moveTo(
        mid.dx + un.dx * 2 - upper.dx * 0.2,
        mid.dy + un.dy * 2 - upper.dy * 0.2,
      )
      ..quadraticBezierTo(
        mid.dx + un.dx * 6,
        mid.dy + un.dy * 6,
        mid.dx + un.dx * 2 + upper.dx * 0.25,
        mid.dy + un.dy * 2 + upper.dy * 0.25,
      ),
    muscleLine,
  );
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

// Profile cơ tay chân cỡ anh hùng (t, nửa rộng trước, nửa rộng sau) — xem
// musclePath. Tượng Farnese: cơ phóng đại, khớp vẫn thắt gọn.
const _hUpperArm = <MuscleStop>[
  (0.0, 14.0, 14.0), // cơ vai
  (0.2, 14.5, 13.5),
  (0.45, 11.5, 13.5), // bắp tay sau
  (0.65, 12.5, 11.5), // bắp tay trước
  (0.9, 9.0, 9.5),
  (1.0, 8.5, 9.0), // khuỷu
];
const _hForearm = <MuscleStop>[
  (0.0, 9.0, 8.5),
  (0.22, 11.5, 10.0), // cơ cánh tay quay
  (0.5, 9.5, 8.5),
  (0.85, 7.0, 7.0),
  (1.0, 7.0, 7.0), // cổ tay
];
const _hThigh = <MuscleStop>[
  (0.0, 15.0, 15.0),
  (0.3, 16.5, 14.5), // cơ tứ đầu
  (0.7, 12.5, 11.5),
  (1.0, 10.0, 10.5), // gối
];
const _hShin = <MuscleStop>[
  (0.0, 10.0, 10.5),
  (0.28, 9.0, 12.5), // bắp chân
  (0.62, 8.0, 10.0),
  (0.9, 6.5, 6.5),
  (1.0, 6.8, 6.8), // cổ chân
];

/// Thân trên kiểu tượng Farnese: hình chữ V, cơ thang nối cổ, ngực vuông,
/// bụng 8 múi, răng cưa sườn, cơ chéo, đường chữ V ở hông.
void _heroicTorso(Canvas canvas, Color skin, double breath) {
  final b = breath;
  final torso = Path()
    ..moveTo(-30, -170)
    ..cubicTo(-34, -150, -26, -136, -22, -124)
    ..lineTo(22, -124)
    ..cubicTo(26, -136, 34, -150, 30, -170)
    ..cubicTo(36, -186, 30, -197 - b, 14, -200 - b)
    ..quadraticBezierTo(-4, -207 - b, -18, -200 - b)
    ..cubicTo(-34, -197 - b, -38, -186, -30, -170)
    ..close();
  shadedPath(canvas, torso, skin, PartFrame.world, shadow: 6);

  final sel = Paint()
    ..color = darken(skin, 0.32).withValues(alpha: 0.65)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;
  final under = Paint()..color = coreShadeOf(skin).withValues(alpha: 0.3);
  final lit = Paint()..color = sunlitOf(skin).withValues(alpha: 0.45);

  // Một khối cơ: sáng phía trên-trái, bóng lõi mép dưới-phải, sel-line viền
  // (Loomis: mỗi khối cơ là một khối tròn có mặt khuất).
  void block(Path p, {bool soft = false}) {
    canvas.save();
    canvas.clipPath(p);
    canvas.drawPath(p.shift(const Offset(-1.5, -2)), lit);
    canvas.drawPath(p.shift(const Offset(2.5, 3)), under);
    canvas.restore();
    // Khối nhỏ (múi bụng): nét mảnh, nhạt để liền mạch, không thành "viên kẹo".
    canvas.drawPath(
      p,
      soft
          ? (Paint()
              ..color = darken(skin, 0.3).withValues(alpha: 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.9)
          : sel,
    );
  }

  canvas.save();
  canvas.clipPath(torso);
  // Bóng dưới cơ ngực đổ lên bụng.
  canvas.drawPath(
    Path()
      ..moveTo(-30, -168 - b)
      ..quadraticBezierTo(-14, -158 - b, 2, -166 - b)
      ..quadraticBezierTo(16, -158 - b, 28, -168 - b)
      ..lineTo(28, -162 - b)
      ..quadraticBezierTo(16, -152 - b, 2, -160 - b)
      ..quadraticBezierTo(-14, -152 - b, -30, -162 - b)
      ..close(),
    Paint()..color = coreShadeOf(skin).withValues(alpha: 0.35),
  );
  // Cơ ngực: hai khối vuông bo, chẻ đôi ở xương ức.
  for (final (l, r) in [(-31.0, -1.0), (2.0, 29.0)]) {
    block(
      Path()
        ..moveTo(l, -192 - b)
        ..quadraticBezierTo((l + r) / 2, -196 - b, r, -190 - b)
        ..quadraticBezierTo(r + 1, -176 - b, r - 3, -168 - b)
        ..quadraticBezierTo((l + r) / 2, -162 - b, l + 2, -168 - b)
        ..quadraticBezierTo(l - 2, -180 - b, l, -192 - b)
        ..close(),
    );
  }
  // Bụng: 4 hàng × 2 múi, hẹp dần xuống dưới, đường trắng giữa.
  for (var row = 0; row < 4; row++) {
    final y = -160.0 + row * 9;
    final w = 9.0 - row * 0.8;
    for (final side in [-1.0, 1.0]) {
      final x = side < 0 ? -w - 1.2 : 1.2;
      block(
        Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w, 7.6),
            const Radius.circular(3.4),
          ),
        ),
      );
    }
  }
  // Răng cưa sườn phía gần.
  for (var i = 0; i < 3; i++) {
    final y = -164.0 + i * 6;
    block(
      Path()
        ..moveTo(-27, y)
        ..quadraticBezierTo(-22, y - 2, -18, y + 1)
        ..quadraticBezierTo(-22, y + 4, -27, y + 3)
        ..close(),
    );
  }
  // Cơ chéo bụng hai bên.
  for (final s in [-1.0, 1.0]) {
    canvas.drawPath(
      Path()
        ..moveTo(s * 20, -148)
        ..quadraticBezierTo(s * 22, -136, s * 13, -126),
      sel,
    );
  }
  // Đường chữ V ở hông dẫn xuống khố.
  canvas.drawPath(
    Path()
      ..moveTo(-19, -136)
      ..quadraticBezierTo(-12, -128, -6, -124)
      ..moveTo(19, -136)
      ..quadraticBezierTo(12, -128, 6, -124),
    sel..strokeWidth = 1.6,
  );
  // Xương đòn hai bên hõm cổ.
  canvas.drawPath(
    Path()
      ..moveTo(-26, -196 - b)
      ..quadraticBezierTo(-14, -194 - b, -5, -197 - b)
      ..moveTo(5, -197 - b)
      ..quadraticBezierTo(14, -194 - b, 24, -196 - b),
    sel..strokeWidth = 1.2,
  );
  canvas.restore();
}

/// Da sư tử Nemea vắt trên đầu chuỳ: đầu sư tử ở trên, tấm da rủ xuống,
/// chân trước có móng đung đưa nhẹ.
void _peltOnClub(Canvas canvas, double time) {
  const hide = Color(0xFFC99140);
  const mane = Color(0xFF8E3714);
  final sway = math.sin(time * 1.4) * 1.5;
  final skin = Path()
    ..moveTo(36, -138)
    ..quadraticBezierTo(48, -146, 62, -138)
    ..quadraticBezierTo(72, -110, 68 + sway, -78)
    ..lineTo(72 + sway, -62)
    ..lineTo(64 + sway, -64)
    ..lineTo(60, -76)
    ..quadraticBezierTo(52, -70, 44, -78)
    ..lineTo(40 - sway, -64)
    ..lineTo(32 - sway, -66)
    ..lineTo(36, -82)
    ..quadraticBezierTo(30, -110, 36, -138)
    ..close();
  shadedPath(canvas, skin, hide, PartFrame.world, shadow: 4);
  furStrokes(
    canvas,
    skin,
    darken(hide, 0.32),
    dir: const Offset(0.05, 1),
    count: 40,
    length: 7,
    width: 0.9,
    seed: 21,
  );
  final claw = Paint()
    ..color = const Color(0xFFFFF4DC)
    ..strokeWidth = 1.3
    ..strokeCap = StrokeCap.round;
  for (final p in [Offset(68 + sway, -62), Offset(36 - sway, -65)]) {
    for (final dx in [-2.4, 0.0, 2.4]) {
      canvas.drawLine(p + Offset(dx, 0), p + Offset(dx - 0.8, 3.6), claw);
    }
  }
  // Bờm quanh đầu sư tử trên đỉnh chuỳ.
  const c = Offset(49, -146);
  final tufts = Path();
  for (var i = 0; i < 10; i++) {
    final a = math.pi * (0.9 + 1.2 * i / 9);
    final dir = Offset(math.cos(a), math.sin(a));
    final n = Offset(-dir.dy, dir.dx);
    final base = c + dir * 9;
    final tip = base + dir * (10 + (i.isEven ? 3 : 0));
    tufts
      ..moveTo(base.dx + n.dx * 4, base.dy + n.dy * 4)
      ..quadraticBezierTo(tip.dx + n.dx, tip.dy + n.dy, tip.dx, tip.dy)
      ..quadraticBezierTo(
        base.dx - n.dx,
        base.dy - n.dy,
        base.dx - n.dx * 4,
        base.dy - n.dy * 4,
      )
      ..close();
  }
  tufts.addOval(Rect.fromCircle(center: c, radius: 10));
  shadedPath(canvas, tufts, mane, PartFrame.world, shadow: 2.5);
  // Đầu sư tử nghiêng, mắt nhắm, nanh.
  final head = Path()
    ..moveTo(40, -150)
    ..quadraticBezierTo(48, -158, 58, -152)
    ..quadraticBezierTo(62, -144, 58, -138)
    ..lineTo(44, -138)
    ..quadraticBezierTo(38, -142, 40, -150)
    ..close();
  shadedPath(canvas, head, hide, PartFrame.world, shadow: 2);
  canvas.drawPath(
    Path()
      ..moveTo(44, -148)
      ..quadraticBezierTo(47, -146.5, 50, -147.5),
    Paint()
      ..color = VectorStyle.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round,
  );
  for (final x in [47.0, 52.0]) {
    canvas.drawPath(
      Path()
        ..moveTo(x - 1.2, -138.5)
        ..lineTo(x + 1.2, -138.5)
        ..lineTo(x, -134)
        ..close(),
      Paint()..color = const Color(0xFFFFF6DE),
    );
  }
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
  // Lọn xoăn trong râu.
  final curl = Paint()
    ..color = const Color(0xFF2E1C12)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.9
    ..strokeCap = StrokeCap.round;
  for (final (dx, dy) in [
    (-12.0, 12.0),
    (-4.0, 16.0),
    (4.0, 19.0),
    (10.0, 13.0),
    (0.0, 25.0),
    (8.0, 23.0),
  ]) {
    canvas.drawArc(
      Rect.fromCircle(center: c + Offset(dx, dy), radius: 2.4),
      0.3,
      4.2,
      false,
      curl,
    );
  }
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
