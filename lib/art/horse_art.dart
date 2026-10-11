import 'dart:math' as math;
import 'dart:ui';

import 'vector_style.dart';

/// Màu Ngựa chín hồng mao.
abstract final class HorseColors {
  static const coat = Color(0xFFF4EFE6);
  static const mane = Color(0xFFD7372C);
  static const hoof = Color(0xFF4A4038);
  static const muzzle = Color(0xFFD9C9BE);
}

/// Ngựa chín hồng mao (lễ vật Sơn Tinh dâng vua Hùng; phần thưởng Kỳ công
/// 12): ngựa trắng, bờm đỏ chín chùm. Gốc toạ độ ở mặt đất giữa bốn chân,
/// mặt quay sang phải. [gallop] 0–1 là nhịp phi (0 = đứng yên).
///
/// Dựng theo giải phẫu ngựa: thân thùng (vai, u vai, lưng võng nhẹ, mông
/// tròn, bụng), chân trước khuỷu → cẳng → gối → ống → cổ chân → cổ móng →
/// móng; chân sau đùi → khoeo gập ngược → ống; cổ cong, đầu dài hình nêm.
/// Đứng yên thì vẽ ảnh chụp sẵn (chỉ thở); đang phi thì vẽ vector.
void paintHorse(Canvas canvas, {double time = 0, double gallop = 0}) {
  if (gallop < 0.02) {
    final breathe = math.sin(time * 1.6) * 0.6;
    canvas.save();
    canvas.translate(0, -breathe);
    _standing.paint(canvas);
    canvas.restore();
    // Đuôi phe phẩy (vẽ riêng, nhẹ).
    return;
  }
  _paintHorse(canvas, time: time, gallop: gallop);
}

final _standing = RasterLayer(
  (c) => _paintHorse(c, time: 0, gallop: 0),
  bounds: const Rect.fromLTRB(-66, -122, 92, 8),
  resolution: 1.6,
);

void _paintHorse(
  Canvas canvas, {
  required double time,
  required double gallop,
}) {
  const coat = HorseColors.coat;
  final far = darken(coat, 0.16);
  final phase = time * 9;
  final bob = math.sin(phase * 2) * 2.2 * gallop;

  canvas.save();
  canvas.translate(0, bob);

  // Chân xa (trước, sau) vẽ trước thân, lệch pha.
  _foreLeg(
    canvas,
    const Offset(20, -48),
    phase + math.pi,
    gallop,
    far,
    -bob,
    near: false,
  );
  _hindLeg(
    canvas,
    const Offset(-24, -50),
    phase,
    gallop,
    far,
    -bob,
    near: false,
  );

  _tail(canvas, time, gallop);
  // Chân gần: vẽ trước thân để thân phủ gốc chân (vai, mông liền khối).
  _foreLeg(
    canvas,
    const Offset(28, -46),
    phase,
    gallop,
    coat,
    -bob,
    near: true,
  );
  _hindLeg(
    canvas,
    const Offset(-32, -50),
    phase + math.pi,
    gallop,
    coat,
    -bob,
    near: true,
  );

  // Thân thùng: ngực sâu, u vai, lưng võng nhẹ, mông tròn, bụng thon về sau.
  final body = smoothPath(
    const [
      Offset(38, -50),
      Offset(30, -62),
      Offset(18, -68),
      Offset(2, -63),
      Offset(-16, -64),
      Offset(-34, -66),
      Offset(-44, -56),
      Offset(-42, -42),
      Offset(-30, -36),
      Offset(-10, -34),
      Offset(12, -35),
      Offset(30, -38),
    ],
    closed: true,
    tension: 0.12,
  );
  shadedPath(canvas, body, coat, PartFrame.world, shadow: 4, highlight: 1.6);
  canvas.save();
  canvas.clipPath(body);
  final core = coreShadeOf(coat);
  // Khối cơ vai (xương bả vai nghiêng) và mông: sáng phía trên, bóng lõi
  // viền dưới–sau; rãnh sau vai; bóng bụng.
  canvas.drawPath(
    taperedStroke(
      const [Offset(22, -64), Offset(26, -52), Offset(30, -40)],
      7,
      peak: 0.4,
    ),
    fillPaint(lighten(coat, 0.5).withValues(alpha: 0.5)),
  );
  canvas.drawPath(
    taperedStroke(
      const [Offset(14, -62), Offset(12, -50), Offset(16, -38)],
      3.4,
      peak: 0.5,
    ),
    fillPaint(core.withValues(alpha: 0.28)),
  );
  canvas.drawArc(
    const Rect.fromLTRB(-46, -66, -14, -36),
    1.2,
    1.9,
    false,
    Paint()
      ..color = core.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3,
  );
  canvas.drawPath(
    taperedStroke(
      const [Offset(-26, -37), Offset(0, -35), Offset(24, -37)],
      6,
      peak: 0.5,
    ),
    fillPaint(core.withValues(alpha: 0.25)),
  );
  // Xương sườn mờ.
  for (var i = 0; i < 3; i++) {
    final x = -2.0 + i * 6;
    canvas.drawPath(
      taperedStroke(
        [Offset(x, -52), Offset(x + 2, -44), Offset(x + 1, -38)],
        1.2,
        peak: 0.5,
      ),
      fillPaint(core.withValues(alpha: 0.18)),
    );
  }
  canvas.restore();

  // Cổ cong và đầu.
  final nod = math.sin(phase * 2 + 0.6) * 2.5 * gallop;
  final neck = smoothPath(
    [
      const Offset(18, -66),
      const Offset(30, -78),
      Offset(42, -94 + nod),
      Offset(52, -100 + nod),
      Offset(58, -90 + nod),
      Offset(54, -76 + nod),
      const Offset(48, -58),
      const Offset(40, -44),
      const Offset(28, -52),
    ],
    closed: true,
    tension: 0.1,
  );
  shadedPath(canvas, neck, coat, PartFrame.world, shadow: 3, highlight: 1.4);
  canvas.save();
  canvas.clipPath(neck);
  // Cơ cổ: dải sáng dưới bờm, rãnh tĩnh mạch cảnh.
  canvas.drawPath(
    taperedStroke(
      [
        const Offset(34, -60),
        Offset(44, -76 + nod * 0.6),
        Offset(52, -88 + nod),
      ],
      2.2,
      peak: 0.5,
    ),
    fillPaint(core.withValues(alpha: 0.22)),
  );
  canvas.restore();
  _head(canvas, Offset(54, -96 + nod), gallop);
  _mane(canvas, nod, time, gallop);

  // Chân gần.
  _foreLeg(
    canvas,
    const Offset(28, -46),
    phase,
    gallop,
    coat,
    -bob,
    near: true,
  );
  _hindLeg(
    canvas,
    const Offset(-32, -50),
    phase + math.pi,
    gallop,
    coat,
    -bob,
    near: true,
  );
  canvas.restore();
}

/// Đường bao một chân liền khối qua các khớp [joints] (điểm, bề rộng):
/// hai mép dời theo pháp tuyến rồi nối mượt — không đứt đoạn ở khớp.
Path _limb(List<(Offset, double)> joints) {
  final left = <Offset>[], right = <Offset>[];
  for (var i = 0; i < joints.length; i++) {
    final prev = joints[math.max(0, i - 1)].$1;
    final next = joints[math.min(joints.length - 1, i + 1)].$1;
    final d = next - prev;
    final n = Offset(-d.dy, d.dx) / d.distance;
    final (p, w) = joints[i];
    left.add(p + n * (w / 2));
    right.add(p - n * (w / 2));
  }
  return smoothPath([...left, ...right.reversed], closed: true, tension: 0.05);
}

/// Móng: hình thang tối, vành lông trắng mép trên.
void _hoof(Canvas canvas, Offset top, Offset dir, Color coat) {
  final n = Offset(-dir.dy, dir.dx);
  final bottom = top + dir * 6;
  final path = Path()
    ..moveTo(top.dx - n.dx * 3.2, top.dy - n.dy * 3.2)
    ..lineTo(top.dx + n.dx * 3.2, top.dy + n.dy * 3.2)
    ..lineTo(bottom.dx + n.dx * 4.4 + dir.dx, bottom.dy + n.dy * 4.4)
    ..lineTo(bottom.dx - n.dx * 4.8, bottom.dy - n.dy * 4.8)
    ..close();
  shadedPath(
    canvas,
    path,
    HorseColors.hoof,
    PartFrame.world,
    shadow: 1.2,
    highlight: 0.6,
    outlineWidth: 1.2,
  );
  canvas.drawPath(
    taperedStroke(
      [top - n * 3.6, top + dir * 0.8, top + n * 3.6],
      2,
      peak: 0.5,
    ),
    fillPaint(darken(coat, 0.06)),
  );
}

Offset _at(Offset from, double len, double angle) =>
    from + Offset(math.sin(angle), math.cos(angle)) * len;

void _foreLeg(
  Canvas canvas,
  Offset shoulder,
  double phase,
  double gallop,
  Color c,
  double lift, {
  required bool near,
}) {
  // Phi: đưa chân ra trước, gập gối khi nhấc.
  final s = math.sin(phase);
  final reach = s * 0.55 * gallop;
  final fold = math.max(0, math.cos(phase)) * 1.4 * gallop;
  final elbow = _at(shoulder, 14, reach * 0.6 - 0.05);
  final knee = _at(elbow, 15, reach);
  final fetlock = _at(knee, 14, reach - fold);
  final pastern = _at(fetlock, 5.5, reach - fold * 0.6 - 0.45);
  // Cẳng tay vạm vỡ thon về gối; gối (cổ tay ngựa) gồ nhẹ; ống mảnh;
  // cổ chân phình; cổ móng.
  final leg = _limb([
    (shoulder, 16),
    (elbow, 11),
    (Offset.lerp(elbow, knee, 0.55)!, 7.2),
    (knee, 7.4),
    (Offset.lerp(knee, fetlock, 0.5)!, 5),
    (fetlock, 6.6),
    (pastern, 4.6),
  ]);
  shadedPath(
    canvas,
    leg,
    c,
    PartFrame.world,
    shadow: 2.2,
    highlight: near ? 1 : 0,
    outlineWidth: 1.4,
  );
  _hoof(canvas, pastern, (pastern - fetlock) / (pastern - fetlock).distance, c);
  if (near) {
    canvas.save();
    canvas.clipPath(leg);
    final core = coreShadeOf(c);
    // Gân sau ống + rãnh cơ cẳng tay.
    canvas.drawPath(
      taperedStroke(
        [knee + const Offset(-2.4, 2), fetlock + const Offset(-2.6, -2)],
        1.1,
        peak: 0.5,
      ),
      fillPaint(core.withValues(alpha: 0.45)),
    );
    canvas.drawPath(
      taperedStroke(
        [
          elbow + const Offset(2, 2),
          Offset.lerp(elbow, knee, 0.7)! + const Offset(1, 0),
        ],
        1.6,
        peak: 0.4,
      ),
      fillPaint(core.withValues(alpha: 0.3)),
    );
    canvas.restore();
  }
}

void _hindLeg(
  Canvas canvas,
  Offset hip,
  double phase,
  double gallop,
  Color c,
  double lift, {
  required bool near,
}) {
  final s = math.sin(phase);
  final drive = s * 0.5 * gallop;
  final fold = math.max(0, -math.cos(phase)) * 1.1 * gallop;
  // Đùi chéo ra trước tới khớp gối (stifle), cẳng chéo ra sau tới khoeo,
  // ống gần thẳng đứng.
  final stifle = _at(hip, 18, 0.42 + drive);
  final hock = _at(stifle, 17, -0.62 + drive - fold);
  final fetlock = _at(hock, 15, 0.06 + drive * 0.6 - fold * 0.4);
  final pastern = _at(fetlock, 5.5, 0.45 + drive * 0.3 - fold * 0.3);
  final leg = _limb([
    (hip, 24),
    (stifle, 16),
    (Offset.lerp(stifle, hock, 0.5)!, 10),
    (hock, 7.6),
    (Offset.lerp(hock, fetlock, 0.5)!, 5.2),
    (fetlock, 6.6),
    (pastern, 4.6),
  ]);
  shadedPath(
    canvas,
    leg,
    c,
    PartFrame.world,
    shadow: 2.2,
    highlight: near ? 1 : 0,
    outlineWidth: 1.4,
  );
  _hoof(canvas, pastern, (pastern - fetlock) / (pastern - fetlock).distance, c);
  if (near) {
    canvas.save();
    canvas.clipPath(leg);
    final core = coreShadeOf(c);
    // Mỏm khoeo nhô sau + rãnh cơ đùi sau.
    canvas.drawPath(
      taperedStroke(
        [
          Offset.lerp(stifle, hock, 0.4)! + const Offset(-3, 0),
          hock + const Offset(-3.4, 0),
        ],
        1.6,
        peak: 0.6,
      ),
      fillPaint(core.withValues(alpha: 0.4)),
    );
    canvas.drawPath(
      taperedStroke(
        [hip + const Offset(-6, 4), stifle + const Offset(-4, -2)],
        2,
        peak: 0.4,
      ),
      fillPaint(core.withValues(alpha: 0.25)),
    );
    canvas.restore();
  }
}

void _head(Canvas canvas, Offset poll, double gallop) {
  canvas.save();
  canvas.translate(poll.dx, poll.dy);
  // Tai dựng (vẽ trước để đầu che gốc).
  for (final (dx, tilt, c) in [
    (-1.5, -0.25, darken(HorseColors.coat, 0.15)),
    (1.5, 0.1, HorseColors.coat),
  ]) {
    canvas.save();
    canvas.translate(dx, -1);
    canvas.rotate(tilt);
    final ear = Path()
      ..moveTo(-2.4, 1)
      ..quadraticBezierTo(-2.6, -6, 0, -9)
      ..quadraticBezierTo(2.6, -6, 2.4, 1)
      ..close();
    shadedPath(
      canvas,
      ear,
      c,
      PartFrame.world,
      shadow: 1,
      highlight: 0.4,
      outlineWidth: 1.1,
    );
    canvas.drawPath(
      taperedStroke(const [Offset(0, 0), Offset(0, -6)], 1.4, peak: 0.3),
      fillPaint(const Color(0xFFD9A8A0)),
    );
    canvas.restore();
  }
  // Đầu hình nêm dài: trán phẳng, sống mũi thẳng, mõm tròn, má (hàm dưới)
  // tròn to phía sau.
  final head = smoothPath(
    const [
      Offset(-2, 0),
      Offset(6, -2),
      Offset(16, 5),
      Offset(24, 13),
      Offset(27, 18),
      Offset(25, 22),
      Offset(19, 22),
      Offset(14, 19),
      Offset(6, 16),
      Offset(-2, 12),
      Offset(-5, 6),
    ],
    closed: true,
    tension: 0.1,
  );
  shadedPath(
    canvas,
    head,
    HorseColors.coat,
    PartFrame.world,
    shadow: 2.5,
    highlight: 1.2,
  );
  canvas.save();
  canvas.clipPath(head);
  // Mõm sẫm hồng xám, má tròn bóng lõi, xương gò má.
  canvas.drawOval(
    const Rect.fromLTWH(16, 13, 13, 11),
    fillPaint(HorseColors.muzzle),
  );
  canvas.drawArc(
    const Rect.fromLTWH(-4, 3, 14, 14),
    0.4,
    2.2,
    false,
    Paint()
      ..color = coreShadeOf(HorseColors.coat).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  canvas.drawPath(
    taperedStroke(
      const [Offset(4, 4), Offset(12, 8), Offset(18, 12)],
      1.2,
      peak: 0.5,
    ),
    fillPaint(coreShadeOf(HorseColors.coat).withValues(alpha: 0.3)),
  );
  canvas.restore();
  // Lỗ mũi, miệng, mắt có mí và lông mi, chòm lông trán đỏ.
  canvas.drawPath(
    taperedStroke(
      const [Offset(23, 15.5), Offset(25, 17.5), Offset(24.5, 19.5)],
      1.4,
      peak: 0.4,
    ),
    fillPaint(const Color(0xFF5A4440)),
  );
  canvas.drawPath(
    taperedStroke(
      const [Offset(26, 21.5), Offset(22, 21), Offset(19, 20)],
      0.9,
      peak: 0.5,
    ),
    fillPaint(const Color(0xFF5A4440)),
  );
  const eye = Offset(5.5, 4.5);
  canvas.drawOval(
    Rect.fromCenter(center: eye, width: 4.4, height: 3.2),
    fillPaint(const Color(0xFF2A1E1A)),
  );
  canvas.drawCircle(
    eye + const Offset(-0.6, -0.6),
    0.7,
    fillPaint(const Color(0xCCFFFFFF)),
  );
  canvas.drawPath(
    taperedStroke(
      [
        eye + const Offset(-2.6, -1.2),
        eye + const Offset(0, -2.6),
        eye + const Offset(2.8, -1),
      ],
      1,
      peak: 0.5,
    ),
    fillPaint(darken(HorseColors.coat, 0.35)),
  );
  final forelock = buildLocks(
    center: const Offset(0, -1),
    rnd: math.Random(5),
    r0: 0,
    length: 9,
    width: 3.4,
    count: 4,
    from: -0.4,
    to: 0.5,
    drift: const Offset(0.1, 0.35),
    wave: 1.5,
  );
  shadedPath(
    canvas,
    forelock.mass,
    HorseColors.mane,
    PartFrame.world,
    shadow: 1.2,
    highlight: 0.6,
    outlineWidth: 1,
  );
  canvas.restore();
}

/// Bờm đỏ "chín hồng mao": chín chùm lọn dài mọc dọc mào cổ, rủ xuống
/// phía bên kia cổ và bay ra sau khi phi.
void _mane(Canvas canvas, double nod, double time, double gallop) {
  final rnd = math.Random(9);
  final crest = [
    const Offset(20, -68),
    const Offset(28, -76),
    Offset(36, -86 + nod * 0.5),
    Offset(44, -95 + nod),
    Offset(50, -100 + nod),
  ];
  final line = sampleSmooth(crest, 9);
  final blow = gallop * 0.5 + math.sin(time * 3) * 0.05;
  final mass = Path();
  final creases = Path();
  final sheens = Path();
  for (var i = 0; i < line.length; i++) {
    final root = line[i];
    final len = 16 + (i * 7 % 5) * 2.0 + (i < 3 ? 4 : 0);
    // Rủ xuống phía trước–dưới (bên kia cổ), gió đẩy ra sau khi phi.
    final pts = [
      for (final p in lockLine(
        -0.4 - blow,
        0,
        len,
        drift: Offset(-0.15 - blow * 0.4, 0.4),
        wave: (rnd.nextDouble() - 0.5) * 3,
      ))
        p + root,
    ];
    const w = 6.5;
    mass.addPath(
      taperedStroke(pts, w, peak: 0.3, startWidth: 0.7, samples: 10),
      Offset.zero,
    );
    creases.addPath(
      taperedStroke(offsetLine(pts, w * 0.4, taper: 0.6), w * 0.3, samples: 8),
      Offset.zero,
    );
    sheens.addPath(
      taperedStroke(
        offsetLine(pts, -w * 0.25, taper: 0.6).sublist(0, 4),
        w * 0.16,
        samples: 6,
      ),
      Offset.zero,
    );
  }
  shadedPath(
    canvas,
    mass,
    HorseColors.mane,
    PartFrame.world,
    shadow: 2,
    highlight: 0.8,
    outlineWidth: 1.2,
  );
  canvas.save();
  canvas.clipPath(mass);
  canvas.drawPath(
    creases,
    fillPaint(darken(HorseColors.mane, 0.4).withValues(alpha: 0.8)),
  );
  canvas.drawPath(
    sheens,
    fillPaint(lighten(HorseColors.mane, 0.4).withValues(alpha: 0.8)),
  );
  canvas.restore();
}

/// Đuôi đỏ: chùm lọn dài từ gốc đuôi, rủ xuống, bay ngang khi phi.
void _tail(Canvas canvas, double time, double gallop) {
  const root = Offset(-42, -58);
  final lift = gallop * 0.9;
  final locks = buildLocks(
    center: root,
    rnd: math.Random(13),
    r0: 0,
    length: 38,
    width: 6,
    count: 7,
    from: math.pi * 0.62 + lift * 0.6,
    to: math.pi * 0.82 + lift * 0.6,
    drift: Offset(-0.05 - lift * 0.2, 0.3 - lift * 0.25),
    wave: 4 + math.sin(time * 4) * 2,
  );
  shadedPath(
    canvas,
    locks.mass,
    HorseColors.mane,
    PartFrame.world,
    shadow: 2,
    highlight: 0.8,
    outlineWidth: 1.2,
  );
  canvas.save();
  canvas.clipPath(locks.mass);
  canvas.drawPath(
    locks.creases,
    fillPaint(darken(HorseColors.mane, 0.4).withValues(alpha: 0.8)),
  );
  canvas.drawPath(
    locks.sheens,
    fillPaint(lighten(HorseColors.mane, 0.4).withValues(alpha: 0.8)),
  );
  canvas.restore();
  // Gốc đuôi phủ lông trắng.
  shadedPath(
    canvas,
    Path()..addOval(
      Rect.fromCircle(center: root + const Offset(1, 1), radius: 4.5),
    ),
    HorseColors.coat,
    PartFrame.world,
    shadow: 1,
    highlight: 0.5,
    outlineWidth: 1.1,
  );
}
