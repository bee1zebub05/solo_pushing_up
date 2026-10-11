import 'dart:math' as math;
import 'dart:ui';

import 'costume_art.dart';
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
  canvas.saveLayer(
    const Rect.fromLTRB(-120, -320, 140, 20),
    Paint()..color = Color.fromRGBO(0, 0, 0, a),
  );

  // Chuỳ gỗ ô liu dại (truyền thuyết: Hercules tự nhổ cây ô liu ở Nemea)
  // chống đất, tay xa tì lên đầu chuỳ. Chụp sẵn.
  _clubImage.paint(canvas);
  // Da sư tử Nemea vắt lên đầu chuỳ (như tượng Farnese Hercules).
  _peltOnClub(canvas, time);

  // Tay xa: từ vai xuống đầu chuỳ, tì lên da sư tử.
  shadedLimb(
    canvas,
    [
      (const Offset(26, -186), const Offset(40, -154), HumanAnatomy.upperArm),
      (const Offset(40, -154), const Offset(46, -134), HumanAnatomy.forearm),
    ],
    skinFar,
    shadow: 4,
    scale: _hScale,
    facing: _left,
    definition: 0.8,
  );
  // Bàn tay xa nắm đầu chuỳ (bọc qua da sư tử).
  shadedHand(
    canvas,
    buildHand(
      const Offset(46, -134),
      const Offset(46, -134) - const Offset(40, -154),
      pose: HandPose.grip,
      facing: _left,
      scale: 1.9,
    ),
    skinFar,
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
      [(hip, knee, HumanAnatomy.thigh), (knee, ankle, HumanAnatomy.shin)],
      c,
      shadow: 5,
      scale: _hThighScale,
      facing: _left,
      definition: 0.8,
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
    paintGreekSandal(
      canvas,
      knee: knee,
      ankle: ankle,
      facingRight: false,
      skin: c,
      scale: 1.95,
      // Dây buộc theo đúng bề rộng ống chân đã vẽ (scale chân / scale dép).
      shin: HumanAnatomy.shin.scaled(_hThighScale / 1.95),
      far: c != skin,
    );
  }

  // Khố chiton ngắn: vải xếp nếp rủ từ thắt lưng, gấu so le, viền
  // hoạ tiết meander vàng. Chụp sẵn.
  _kiltImage.paint(canvas);

  _heroicTorso(canvas, skin, breath);
  // Thắt lưng da khoá vàng ở cạp khố (đè lên mép dưới thân).
  paintBelt(canvas, const Offset(-29, -127), const Offset(29, -127), height: 6);

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
    [
      (const Offset(-34, -186), elbow, HumanAnatomy.upperArm),
      (elbow, hand, HumanAnatomy.forearm),
    ],
    skin,
    shadow: 4,
    scale: _hScale,
    facing: _left,
    definition: 0.8,
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
  // Vòng tay vàng ôm khối cẳng tay gần cổ tay.
  paintLimbBand(
    canvas,
    elbow,
    hand,
    HumanAnatomy.forearm,
    t0: 0.66,
    t1: 0.84,
    scale: _hScale,
    facing: _left,
  );
  // Bàn tay xoè khi nói (lòng tay hướng về người chơi), chỉ khi im lặng.
  shadedHand(
    canvas,
    buildHand(
      hand,
      hand - elbow,
      pose: talk > 0.3 ? HandPose.open : HandPose.point,
      facing: _left,
      scale: 1.9,
    ),
    skin,
  );
  canvas.restore();
  canvas.restore();
}

/// Hercules quay mặt sang trái; tay chân là profile người phóng to cỡ anh
/// hùng (tượng Farnese: cơ phóng đại, khớp vẫn thắt gọn).
const _left = Offset(-1, 0);
const _hScale = 2.0;
const _hThighScale = 1.75;

/// Thân trên kiểu tượng Farnese dựng từ bó cơ (`TorsoAnatomy.front`):
/// cơ thang, lưng xô, răng cưa sườn, cơ chéo, 8 múi bụng, ngực — mỗi bó là
/// một khối đổ bóng riêng, chồng từ sâu ra nông. Phồng nhẹ theo nhịp thở.
void _heroicTorso(Canvas canvas, Color skin, double breath) {
  // Trục thân: hõm cổ → xương chậu; phía "trước" của profile = bên phải
  // khung hình (vai xa, hẹp hơn trong góc 3/4).
  // Thân dừng ở cạp khố (phần bo dưới không trùm lên khố).
  canvas.save();
  canvas.clipRect(const Rect.fromLTRB(-80, -260, 80, -127));
  shadedLimb(
    canvas,
    [(Offset(-2, -206 - breath), const Offset(0, -118), TorsoAnatomy.front)],
    skin,
    scale: 2.05 + breath * 0.01,
    facing: const Offset(1, 0),
    shadow: 3.5,
    definition: 1.35,
  );
  canvas.restore();
  // Bóng đổ dưới cơ ngực lên bụng (cast shadow) — mặt dưới ngực khuất sáng.
  canvas.drawPath(
    Path()
      ..moveTo(-32, -182 - breath)
      ..quadraticBezierTo(-16, -168 - breath, -1, -174 - breath)
      ..quadraticBezierTo(12, -168 - breath, 28, -182 - breath)
      ..lineTo(28, -177 - breath)
      ..quadraticBezierTo(12, -163 - breath, -1, -169 - breath)
      ..quadraticBezierTo(-16, -163 - breath, -32, -177 - breath)
      ..close(),
    Paint()..color = coreShadeOf(skin).withValues(alpha: 0.38),
  );
}

/// Lọn tóc / râu xoăn: các nét thon hình chữ C xếp so le trong vùng [mass]
/// quanh [center], sáng ở mép trên lọn (bắt nắng), tối ở lòng lọn.
void _curlRows(
  Canvas canvas,
  Path mass,
  Offset center,
  double radius,
  Color hair,
) {
  final dark = Paint()..color = darken(hair, 0.45);
  final lit = Paint()..color = lighten(hair, 0.32).withValues(alpha: 0.8);
  canvas.save();
  canvas.clipPath(mass);
  final rnd = math.Random(7);
  for (var row = -2; row <= 2; row++) {
    for (var col = -2; col <= 2; col++) {
      final p =
          center +
          Offset(
            col * radius * 0.42 + (row.isOdd ? radius * 0.21 : 0),
            row * radius * 0.38,
          ) +
          Offset(rnd.nextDouble() * 1.4, rnd.nextDouble() * 1.4);
      const r = 3.2;
      final a0 = 0.6 + rnd.nextDouble() * 0.6;
      List<Offset> arc(double from, double sweep, double rr) => [
        for (var k = 0; k <= 4; k++)
          p +
              Offset(
                math.cos(from + sweep * k / 4) * rr,
                math.sin(from + sweep * k / 4) * rr,
              ),
      ];
      canvas.drawPath(taperedStroke(arc(a0, 3.6, r), 1.3, samples: 8), dark);
      canvas.drawPath(
        taperedStroke(arc(a0 + 3.4, 1.6, r * 0.9), 0.9, samples: 6),
        lit,
      );
    }
  }
  canvas.restore();
}

final _clubImage = RasterLayer(
  _paintClub,
  bounds: const Rect.fromLTRB(26, -140, 82, 6),
  resolution: 1.6,
);

/// Chuỳ gỗ ô liu: thân phình dần xuống đầu nặng, thớ gỗ xoắn (ô liu xoắn
/// theo năm tháng) có khe tối và sống sáng, mắt gỗ, mấu cành gãy có mặt
/// cắt vòng năm, vỏ bong lộ lõi sáng; đầu chuỳ dưới đất sứt mẻ.
void _paintClub(Canvas canvas) {
  const wood = Color(0xFF7A5634);
  final club = Path()
    ..moveTo(40, -132)
    ..cubicTo(36, -90, 40, -50, 38, -6)
    ..cubicTo(44, 2, 66, 2, 70, -8)
    ..cubicTo(64, -50, 54, -96, 50, -134)
    ..close();
  shadedPath(canvas, club, wood, PartFrame.world, shadow: 5);
  canvas.save();
  canvas.clipPath(club);
  // Thớ xoắn: các dải lượn chéo dọc thân, khe tối + sống sáng.
  for (var i = 0; i < 7; i++) {
    final x0 = 38.0 + i * 5;
    final pts = [
      for (var k = 0; k <= 6; k++)
        Offset(x0 + k * 2.2 - 6 + math.sin(k * 0.9 + i) * 2.2, -132.0 + k * 22),
    ];
    canvas.drawPath(
      taperedStroke(pts, 1.4, peak: 0.5, samples: 20),
      fillPaint(const Color(0xFF4A3220)),
    );
    canvas.drawPath(
      taperedStroke(
        [for (final p in pts) p + const Offset(-1.4, 0)],
        0.9,
        peak: 0.5,
        samples: 20,
      ),
      fillPaint(const Color(0x88B08A5E)),
    );
  }
  // Vỏ bong lộ lõi gỗ sáng.
  for (final (c, w, h) in const [
    (Offset(46, -60), 5.0, 9.0),
    (Offset(58, -24), 6.0, 7.0),
  ]) {
    canvas.drawOval(
      Rect.fromCenter(center: c, width: w, height: h),
      fillPaint(const Color(0xFFB8925E)),
    );
    canvas.drawArc(
      Rect.fromCenter(center: c, width: w, height: h),
      3.4,
      2.6,
      false,
      Paint()
        ..color = const Color(0xFF4A3220)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }
  // Mắt gỗ.
  for (final c in const [Offset(50, -100), Offset(60, -44)]) {
    canvas.drawPath(
      taperedStroke(
        [c - const Offset(3, -1), c, c + const Offset(3, 1)],
        2.2,
        peak: 0.5,
      ),
      fillPaint(const Color(0xFF3A2618)),
    );
  }
  canvas.restore();
  // Mấu cành gãy chĩa ra, mặt cắt sáng có vòng năm.
  for (final (from, to) in const [
    (Offset(56, -40), Offset(66, -46)),
    (Offset(62, -20), Offset(72, -22)),
    (Offset(44, -70), Offset(36, -76)),
    (Offset(54, -88), Offset(60, -96)),
  ]) {
    shadedPath(
      canvas,
      taperedStroke(
        [from, Offset.lerp(from, to, 0.5)!, to],
        5.6,
        peak: 0,
        startWidth: 1,
        endWidth: 0.75,
      ),
      const Color(0xFF6A4A2C),
      PartFrame.world,
      shadow: 1.5,
      highlight: 0.6,
      outlineWidth: 1.1,
    );
    canvas.drawCircle(to, 2.1, fillPaint(const Color(0xFFC9A577)));
    canvas.drawCircle(
      to,
      1.2,
      Paint()
        ..color = const Color(0xFF8E6A40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }
}

final _kiltImage = RasterLayer(
  _paintKilt,
  bounds: const Rect.fromLTRB(-40, -134, 40, -84),
  resolution: 1.6,
);

/// Khố chiton (perizoma) vải lanh trắng: nếp xếp toả từ thắt lưng xuống,
/// gấu so le chữ V, bóng nếp sâu, viền meander vàng ở gấu.
void _paintKilt(Canvas canvas) {
  const cloth = Color(0xFFF3ECDC);
  const gold = Color(0xFFE8B83A);
  final hem = <Offset>[
    for (var i = 0; i <= 8; i++)
      Offset(
        -32 + i * 8.0,
        -96 + (i.isEven ? 0 : 3.5) + ((i - 4).abs() * -0.6),
      ),
  ];
  final skirt = Path()
    ..moveTo(-26, -128)
    ..lineTo(26, -128);
  for (final p in hem.reversed) {
    skirt.lineTo(p.dx, p.dy);
  }
  skirt.close();
  shadedPath(canvas, skirt, cloth, PartFrame.world, shadow: 5);
  canvas.save();
  canvas.clipPath(skirt);
  // Nếp xếp: dải tối – sáng xen kẽ toả ra từ thắt lưng.
  for (var i = 0; i < 8; i++) {
    final top = Offset(-22 + i * 6.3, -127);
    final bottom = hem[i] + const Offset(4, 0);
    canvas.drawPath(
      taperedStroke(
        [top, Offset.lerp(top, bottom, 0.5)!, bottom],
        3.2,
        peak: 0.85,
        startWidth: 0.2,
      ),
      fillPaint(const Color(0x55A89880)),
    );
    canvas.drawPath(
      taperedStroke(
        [top + const Offset(-2.6, 0), bottom + const Offset(-3, 0)],
        1.4,
        peak: 0.85,
        startWidth: 0.2,
      ),
      fillPaint(const Color(0xAAFFFFFF)),
    );
  }
  // Viền vàng hoạ tiết ở gấu.
  final band = <Offset>[for (final p in hem) p + const Offset(0, -3)];
  canvas.drawPath(
    taperedStroke(
      band,
      3.4,
      peak: 0.5,
      startWidth: 1,
      endWidth: 1,
      samples: 24,
    ),
    fillPaint(gold),
  );
  for (var i = 0; i < band.length - 1; i++) {
    final c = Offset.lerp(band[i], band[i + 1], 0.5)!;
    canvas.drawRect(
      Rect.fromCenter(center: c, width: 2.2, height: 1.6),
      fillPaint(const Color(0xFF8A6418)),
    );
  }
  canvas.restore();
}

/// Da sư tử Nemea vắt trên đầu chuỳ: đầu sư tử ở trên, tấm da rủ xuống,
/// chân trước có móng đung đưa nhẹ.
void _peltOnClub(Canvas canvas, double time) {
  final sway = math.sin(time * 1.4) * 1.5;
  // Da sư tử vắt trên chuỳ: chụp sẵn, mỗi khung chỉ đung đưa quanh đỉnh.
  const pivot = Offset(49, -146);
  canvas.save();
  canvas.translate(pivot.dx, pivot.dy);
  canvas.rotate(sway * 0.012);
  canvas.translate(-pivot.dx, -pivot.dy);
  _peltImage.paint(canvas);
  canvas.restore();
}

final _peltImage = RasterLayer(
  _paintPelt,
  bounds: const Rect.fromLTRB(14, -176, 86, -52),
  resolution: 1.6,
);

/// Tấm da Sư tử Nemea vắt qua đầu chuỳ (tượng Farnese): da rủ thành nếp
/// võng theo trọng lực giữa hai chân trước buông thõng, lông chảy dọc;
/// đầu sư tử gục trên đỉnh chuỳ, bờm bằng lọn lông (vector_texture).
void _paintPelt(Canvas canvas) {
  const hide = Color(0xFFC99140);
  const mane = Color(0xFF8E3714);
  final skin = Path()
    ..moveTo(36, -138)
    ..quadraticBezierTo(48, -146, 62, -138)
    ..quadraticBezierTo(72, -110, 68, -78)
    ..lineTo(72, -62)
    ..lineTo(64, -64)
    ..lineTo(60, -76)
    ..quadraticBezierTo(52, -70, 44, -78)
    ..lineTo(40, -64)
    ..lineTo(32, -66)
    ..lineTo(36, -82)
    ..quadraticBezierTo(30, -110, 36, -138)
    ..close();
  shadedPath(canvas, skin, hide, PartFrame.world, shadow: 4);
  canvas.save();
  canvas.clipPath(skin);
  // Nếp rủ: da võng giữa hai điểm treo (đỉnh chuỳ) → các nếp chữ U chảy
  // xuống; rãnh tối + sống sáng.
  final crease = Paint()..color = darken(hide, 0.35).withValues(alpha: 0.8);
  final ridge = Paint()..color = lighten(hide, 0.3).withValues(alpha: 0.75);
  for (final (x, top, len) in const [
    (41.0, -128.0, 46.0),
    (49.0, -132.0, 54.0),
    (58.0, -128.0, 44.0),
    (64.0, -118.0, 30.0),
  ]) {
    final pts = [
      Offset(x, top),
      Offset(x - 1.5, top + len * 0.5),
      Offset(x + 0.5, top + len),
    ];
    canvas.drawPath(taperedStroke(pts, 2.6, peak: 0.55), crease);
    canvas.drawPath(
      taperedStroke(
        [for (final p in pts) p + const Offset(-2.4, 0)],
        1.6,
        peak: 0.55,
      ),
      ridge,
    );
  }
  // Mặt trong da (sẫm, lộ ra ở mép võng giữa hai chân).
  canvas.drawPath(
    Path()
      ..moveTo(44, -78)
      ..quadraticBezierTo(52, -70, 60, -76)
      ..quadraticBezierTo(52, -74, 44, -78)
      ..close(),
    fillPaint(const Color(0xFF7A4A2A)),
  );
  canvas.restore();
  furStrokes(
    canvas,
    skin,
    darken(hide, 0.32),
    dir: const Offset(0.05, 1),
    count: 60,
    length: 7,
    width: 0.9,
    seed: 21,
  );
  // Chân trước buông thõng: bàn chân có đệm, móng cong.
  for (final p in const [Offset(68, -62), Offset(36, -65)]) {
    shadedPath(
      canvas,
      Path()..addOval(
        Rect.fromCenter(center: p + const Offset(0, -1), width: 10, height: 6),
      ),
      hide,
      PartFrame.world,
      shadow: 1.5,
      highlight: 0.6,
      outlineWidth: 1.1,
    );
    for (final dx in [-3.0, 0.0, 3.0]) {
      canvas.drawPath(
        taperedStroke(
          [
            p + Offset(dx, 1),
            p + Offset(dx - 0.6, 4),
            p + Offset(dx - 1.6, 5.4),
          ],
          1.4,
          peak: 0.1,
          startWidth: 1,
        ),
        fillPaint(const Color(0xFFFFF4DC)),
      );
    }
  }
  // Bờm quanh đầu sư tử trên đỉnh chuỳ: lọn lông rủ xuống hai bên.
  const c = Offset(49, -146);
  final locks = buildLocks(
    center: c,
    rnd: math.Random(41),
    r0: 6,
    length: 16,
    width: 6,
    count: 14,
    from: math.pi * 0.85,
    to: math.pi * 2.15,
    drift: const Offset(0, 0.3),
    wave: 3,
  );
  shadedPath(
    canvas,
    locks.mass,
    mane,
    PartFrame.world,
    shadow: 2.5,
    outlineWidth: 1.4,
  );
  canvas.save();
  canvas.clipPath(locks.mass);
  canvas.drawPath(
    locks.creases,
    fillPaint(darken(mane, 0.45).withValues(alpha: 0.8)),
  );
  canvas.drawPath(
    locks.sheens,
    fillPaint(lighten(mane, 0.38).withValues(alpha: 0.75)),
  );
  canvas.restore();
  // Đầu sư tử gục, mắt nhắm, nanh trắng; mõm và mũi sẫm.
  final head = Path()
    ..moveTo(40, -150)
    ..quadraticBezierTo(48, -158, 58, -152)
    ..quadraticBezierTo(62, -144, 58, -138)
    ..lineTo(44, -138)
    ..quadraticBezierTo(38, -142, 40, -150)
    ..close();
  shadedPath(canvas, head, hide, PartFrame.world, shadow: 2);
  canvas.drawOval(
    const Rect.fromLTWH(44, -143, 10, 5),
    fillPaint(const Color(0xFFE2C08A)),
  );
  canvas.drawOval(
    const Rect.fromLTWH(47, -144, 4, 2.2),
    fillPaint(const Color(0xFF3A1E14)),
  );
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
  // Tóc: một khối liền ôm sọ (không phải chùm tròn rời), mép dưới gáy và
  // mép trán gợn theo lọn; bên trong là lọn xoăn nét thon xếp hàng.
  final hairMass = smoothPath(
    [
      c + const Offset(-14, -10),
      c + const Offset(-12, -20),
      c + const Offset(-2, -27),
      c + const Offset(12, -25),
      c + const Offset(22, -15),
      c + const Offset(24, -2),
      c + const Offset(20, 9),
      c + const Offset(12, 10),
      c + const Offset(10, -4),
      c + const Offset(0, -13),
      c + const Offset(-8, -13),
    ],
    closed: true,
    tension: 0.1,
  );
  shadedPath(canvas, hairMass, hair, PartFrame.world, shadow: 3.5);
  _curlRows(canvas, hairMass, c + const Offset(5, -8), 14, hair);
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
  // Mặt phẳng kiểu tượng (Loomis): gờ mày dô bắt sáng, hốc mắt sâu tối,
  // mặt bên má khuất, sống mũi sáng, cánh mũi, nếp trán.
  canvas.save();
  canvas.clipPath(face);
  final core = coreShadeOf(skin);
  canvas.drawPath(
    Path()
      ..moveTo(c.dx - 2, c.dy - 6)
      ..quadraticBezierTo(c.dx + 6, c.dy + 2, c.dx + 2, c.dy + 18)
      ..lineTo(c.dx + 16, c.dy + 18)
      ..lineTo(c.dx + 16, c.dy - 8)
      ..close(),
    fillPaint(core.withValues(alpha: 0.25)),
  );
  canvas.drawCircle(
    c + const Offset(-9, -2.5),
    6,
    Paint()
      ..shader = Gradient.radial(c + const Offset(-9, -2.5), 6, [
        core.withValues(alpha: 0.65),
        core.withValues(alpha: 0),
      ]),
  );
  canvas.drawPath(
    taperedStroke(
      [
        c + const Offset(-16, -8),
        c + const Offset(-9, -10),
        c + const Offset(-2, -8),
      ],
      2.8,
      peak: 0.4,
    ),
    fillPaint(lighten(skin, 0.3).withValues(alpha: 0.8)),
  );
  canvas.drawPath(
    taperedStroke(
      [
        c + const Offset(-17, -6),
        c + const Offset(-20, 0),
        c + const Offset(-21, 4),
      ],
      1.6,
      peak: 0.5,
    ),
    fillPaint(lighten(skin, 0.35).withValues(alpha: 0.8)),
  );
  canvas.drawPath(
    taperedStroke(
      [
        c + const Offset(-18, 4),
        c + const Offset(-15, 6),
        c + const Offset(-14, 3),
      ],
      1.2,
      peak: 0.5,
    ),
    fillPaint(darken(skin, 0.4)),
  );
  for (var i = 0; i < 2; i++) {
    canvas.drawPath(
      taperedStroke([
        c + Offset(-12, -13.5 + i * 2.2),
        c + Offset(-6, -14.5 + i * 2.2),
        c + Offset(0, -13.5 + i * 2.2),
      ], 0.7),
      fillPaint(darken(skin, 0.3).withValues(alpha: 0.6)),
    );
  }
  canvas.restore();
  // Râu: khối liền từ tóc mai, ôm hàm, nhọn ở cằm (râu tượng cổ), điểm
  // bạc ở cằm; lọn xoăn nét thon xếp hàng theo dòng chảy xuống.
  final beard = smoothPath(
    [
      c + const Offset(12, 6),
      c + const Offset(14, 14),
      c + const Offset(10, 24),
      c + const Offset(1, 32),
      c + const Offset(-6, 30),
      c + const Offset(-12, 22),
      c + const Offset(-15, 13),
      c + const Offset(-10, 9),
      c + const Offset(-2, 13),
      c + const Offset(6, 6),
    ],
    closed: true,
    tension: 0.1,
  );
  shadedPath(canvas, beard, hair, PartFrame.world, shadow: 3);
  _curlRows(canvas, beard, c + const Offset(0, 20), 12, hair);
  // Sợi bạc ở cằm.
  final greyStroke = Paint()..color = grey.withValues(alpha: 0.85);
  for (final (x, y) in [(-4.0, 24.0), (2.0, 27.0), (6.0, 20.0)]) {
    canvas.drawPath(
      taperedStroke(
        [
          c + Offset(x, y),
          c + Offset(x + 1.5, y + 2.4),
          c + Offset(x + 0.6, y + 4.4),
        ],
        1.3,
        samples: 6,
      ),
      greyStroke,
    );
  }
  // Miệng: mấp máy khi nói.
  final open = talk > 0 ? (0.5 + 0.5 * math.sin(time * 14)) * talk : 0.0;
  // Môi dưới đầy (khối sáng) + khe miệng mảnh, mở ra khi nói.
  canvas.drawPath(
    taperedStroke(
      [
        c + const Offset(-15, 12.4),
        c + const Offset(-11.5, 13.6),
        c + const Offset(-8, 12.2),
      ],
      2.2,
      peak: 0.5,
    ),
    fillPaint(const Color(0xFFB0705A)),
  );
  canvas.drawPath(
    Path()
      ..moveTo(c.dx - 16, c.dy + 11)
      ..quadraticBezierTo(
        c.dx - 12,
        c.dy + 11 + 3.5 * open,
        c.dx - 8,
        c.dy + 10.6,
      )
      ..quadraticBezierTo(c.dx - 12, c.dy + 10.4, c.dx - 16, c.dy + 11)
      ..close(),
    Paint()..color = const Color(0xFF3A1A14),
  );
  canvas.drawPath(
    taperedStroke(
      [
        c + const Offset(-16, 11),
        c + const Offset(-12, 11.2),
        c + const Offset(-8, 10.6),
      ],
      0.9,
      peak: 0.5,
    ),
    fillPaint(const Color(0xFF3A1A14)),
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
  // Mắt nhìn nghiêng: hạnh nhân nhỏ trong hốc, mí trên dày đổ bóng xuống
  // lòng trắng, tròng nâu có chấm sáng, mí dưới mảnh.
  final almond = Path()
    ..moveTo(eye.dx - 3.4, eye.dy + 0.2)
    ..quadraticBezierTo(eye.dx - 0.5, eye.dy - 2.4, eye.dx + 2.8, eye.dy - 0.4)
    ..quadraticBezierTo(eye.dx, eye.dy + 1.8, eye.dx - 3.4, eye.dy + 0.2)
    ..close();
  canvas.drawPath(almond, Paint()..color = const Color(0xFFF2E8D8));
  canvas.save();
  canvas.clipPath(almond);
  canvas.drawCircle(
    eye + const Offset(-1.4, -0.2),
    1.6,
    Paint()..color = const Color(0xFF4A3220),
  );
  canvas.drawCircle(
    eye + const Offset(-1.4, -0.2),
    0.8,
    Paint()..color = const Color(0xFF1A120C),
  );
  canvas.drawRect(
    Rect.fromLTWH(eye.dx - 4, eye.dy - 3, 8, 1.6),
    Paint()..color = const Color(0x55402820),
  );
  canvas.restore();
  canvas.drawCircle(
    eye + const Offset(-1.9, -0.8),
    0.45,
    Paint()..color = const Color(0xFFFFFFFF),
  );
  canvas.drawPath(
    taperedStroke(
      [
        eye + const Offset(-3.8, 0.4),
        eye + const Offset(-0.5, -2.6),
        eye + const Offset(3, -0.6),
      ],
      1.3,
      peak: 0.4,
    ),
    fillPaint(const Color(0xFF2A1A12)),
  );
  canvas.drawPath(
    taperedStroke(
      [
        eye + const Offset(-6, -4.4),
        eye + const Offset(-0.5, -6.4),
        eye + const Offset(5, -5),
      ],
      2.8,
      peak: 0.25,
      startWidth: 0.5,
    ),
    fillPaint(hair),
  );
  // Tai.
  final ear = smoothPath(
    [
      c + const Offset(4, -5),
      c + const Offset(8, -6),
      c + const Offset(10, -1),
      c + const Offset(8.5, 4),
      c + const Offset(6, 6),
      c + const Offset(3.5, 3),
    ],
    closed: true,
    tension: 0.1,
  );
  shadedPath(canvas, ear, skin, PartFrame.world, shadow: 1.5);
  // Vành tai trong (xoắn tai) và lỗ tai.
  canvas.drawPath(
    taperedStroke(
      [
        c + const Offset(6, -3.5),
        c + const Offset(8.2, -1),
        c + const Offset(7, 3),
      ],
      1,
      peak: 0.4,
    ),
    fillPaint(darken(skin, 0.35)),
  );
  canvas.drawCircle(
    c + const Offset(5.4, 0.6),
    0.9,
    fillPaint(darken(skin, 0.5)),
  );
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
