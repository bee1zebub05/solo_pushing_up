import 'dart:math' as math;
import 'dart:ui';

import 'costume_art.dart';
import 'hero_pose.dart';
import 'vector_style.dart';

/// Bảng màu nhân vật người chơi.
abstract final class HeroColors {
  static const outline = VectorStyle.outline;
  static const tunic = Color(0xFFF6F0E2);
  static const trim = Color(0xFF2F6DB5);
  static const belt = Color(0xFF7A4A26);
  static const sandal = Color(0xFF8A5A30);
  static const headband = Color(0xFFD23C2E);
  static const gold = Color(0xFFE8B83A);
  static const pelt = Color(0xFFC99140);
  static const mane = Color(0xFF8E3714);
  static const lips = Color(0xFFC0584E);
  static const blush = Color(0x55FF7F7F);
  static const eyeWhite = Color(0xFFFFFDF8);
  static const iris = Color(0xFF5B3A21);
}

/// Các màu da để chọn (sáng → tối).
const skinTones = <Color>[
  Color(0xFFF6D3B8),
  Color(0xFFEDB892),
  Color(0xFFE2A77C),
  Color(0xFFC68A5E),
  Color(0xFF9C6640),
  Color(0xFF6B4329),
];

/// Các màu tóc để chọn.
const hairColors = <Color>[
  Color(0xFF1E1410),
  Color(0xFF3B2416),
  Color(0xFF7A4A26),
  Color(0xFFC98E3C),
  Color(0xFFB0472A),
  Color(0xFF9A9A9A),
];

enum HeroSex { male, female }

enum HairStyle {
  curly('Xoăn ngắn'),
  buzz('Cắt ngắn'),
  bun('Búi Hy Lạp'),
  ponytail('Đuôi ngựa'),
  long('Tóc dài');

  const HairStyle(this.label);

  final String label;
}

/// Ngoại hình nhân vật. Chỉ khác hình, chỉ số và cách chơi giống hệt nhau
/// (rules/cottruyen.md mục 2.2).
class HeroLook {
  const HeroLook({
    this.sex = HeroSex.male,
    this.skin = const Color(0xFFE2A77C),
    this.hair = const Color(0xFF3B2416),
    this.hairStyle = HairStyle.curly,
    this.fat = 0.15,
    this.height = 1,
  });

  final HeroSex sex;
  final Color skin;
  final Color hair;
  final HairStyle hairStyle;

  /// Độ đầy đặn 0 (rất gọn) – 1 (rất béo), suy ra từ tỉ lệ mỡ cơ thể.
  final double fat;

  /// Tỉ lệ chiều cao so với người 170 cm (≈ 0,85–1,15).
  final double height;

  bool get female => sex == HeroSex.female;
}

/// Đầu vẽ to hơn người thật một chút cho dễ thương (phong cách game).
const _headScale = 1.12;

/// Vẽ người kế nhiệm của Hercules theo [pose] và ngoại hình [look].
/// [cloak]: khoác Áo choàng da sư tử (phần thưởng Kỳ công 1).
/// [glow] 0–1: viền sáng khi vừa tung đòn.
/// [effort] 0–1: gắng sức (xuống càng sâu càng nghiến răng, đổ mồ hôi).
/// [joy] 0–1: vui (ăn mừng chiến thắng).
/// [shield]: Khiên vảy rồng sau lưng (phần thưởng Kỳ công 2).
/// [sword]: Kiếm Kusanagi giắt thắt lưng (phần thưởng Kỳ công 5).
/// [frost] 0–1: lạnh cóng (Fafnir): ngả xanh, mọc tinh thể băng khi gần 1.
void paintHero(
  Canvas canvas,
  HeroPose pose, {
  HeroLook look = const HeroLook(),
  bool cloak = false,
  double glow = 0,
  double effort = 0,
  double joy = 0,
  double frost = 0,
  bool shield = false,
  bool sword = false,
  double time = 0,
}) {
  // Chiều cao: phóng to/thu nhỏ quanh điểm chạm đất (mũi chân), nên tay chân
  // vẫn chạm sàn ở mọi tư thế.
  final toe = pose[HeroJoint.toe];
  if (frost > 0.02) {
    // Tách lớp để phủ màu lạnh lên cả người (chỉ tốn khi đang lạnh).
    canvas.saveLayer(
      null,
      Paint()
        ..colorFilter = ColorFilter.mode(
          const Color(0xFF9FD8FF).withValues(alpha: 0.55 * frost),
          BlendMode.srcATop,
        ),
    );
  }
  canvas.save();
  canvas.translate(toe.dx, toe.dy);
  canvas.scale(look.height);
  canvas.translate(-toe.dx, -toe.dy);

  // Bóng tiếp đất: trải từ mũi chân tới tay (chống đẩy) hoặc quanh chân.
  final ground = math.max(toe.dy, pose[HeroJoint.wrist].dy) + 1.5;
  final xs = [
    toe.dx,
    pose[HeroJoint.ankle].dx,
    pose[HeroJoint.wrist].dx,
    pose[HeroJoint.farToe].dx,
  ];
  final minX = xs.reduce(math.min) - 8;
  final maxX = xs.reduce(math.max) + 8;
  // Bóng đổ mềm lệch về phía xa nắng (nắng trên-trái → bóng ngả phải),
  // màu tím lạnh thay vì đen (Gurney: bóng ngả nhiệt độ ngược ánh sáng).
  canvas.drawOval(
    Rect.fromLTRB(minX + 4, ground - 3.5, maxX + 10, ground + 3.5),
    fillPaint(const Color(0x30402A50)),
  );
  canvas.drawOval(
    Rect.fromLTRB(minX, ground - 2.5, maxX, ground + 2.5),
    fillPaint(const Color(0x40301C30)),
  );
  // Bóng tiếp xúc (occlusion) đậm ngay chỗ chạm đất: tay, mũi chân.
  for (final j in [HeroJoint.wrist, HeroJoint.toe, HeroJoint.farToe]) {
    final p = pose[j];
    if ((p.dy - ground).abs() > 6) continue;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(p.dx, ground), width: 12, height: 3),
      fillPaint(const Color(0x66201018)),
    );
  }

  final shoulder = pose[HeroJoint.shoulder];
  final hip = pose[HeroJoint.hip];
  final bodyUp = shoulder - hip;
  final torsoLen = bodyUp.distance;
  final up = bodyUp / torsoLen;

  if (glow > 0) {
    final aura = Paint()
      ..color = HeroColors.gold.withValues(alpha: 0.5 * glow)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * glow + 2);
    canvas.drawPath(
      capsulePath(hip, shoulder, 22, 24)..addPath(
        capsulePath(shoulder, pose[HeroJoint.wrist], 10, 8),
        Offset.zero,
      ),
      aura,
    );
    // Vệt năng lượng bốc lên từ lưng (tụ lực sau mỗi rep), cao dần rồi tắt.
    final rise = 1 - glow;
    for (var i = 0; i < 3; i++) {
      final base = Offset.lerp(hip, shoulder, 0.2 + i * 0.3)!;
      final from = base + Offset(0, -14 - 10 * rise);
      final to = base + Offset(i * 2.0 - 2, -30 - 26 * rise);
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = Color.fromRGBO(255, 190, 60, 0.6 * glow)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = Color.fromRGBO(255, 248, 210, glow)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  // Tay chân phía xa: tối hơn, nằm sau thân.
  _leg(
    canvas,
    look,
    hip,
    pose[HeroJoint.farKnee],
    pose[HeroJoint.farAnkle],
    pose[HeroJoint.farToe],
    far: true,
  );
  _arm(
    canvas,
    look,
    shoulder,
    pose[HeroJoint.farElbow],
    pose[HeroJoint.farWrist],
    far: true,
    onGround: ground - pose[HeroJoint.farWrist].dy < 14,
  );

  if (cloak) {
    withFrame(canvas, hip, up, (f) => _peltBack(canvas, torsoLen, f, time));
  }
  if (shield) withFrame(canvas, hip, up, (f) => _shield(canvas, torsoLen, f));

  final head = pose[HeroJoint.head];
  final neck = pose[HeroJoint.neck];
  final headUp = (head - neck) / (head - neck).distance;
  // Tóc dài/đuôi ngựa nằm sau thân.
  if (!cloak) {
    withFrame(canvas, head, headUp, (f) {
      canvas.scale(_headScale);
      _hairBack(canvas, look, f);
    });
  }

  _leg(
    canvas,
    look,
    hip,
    pose[HeroJoint.knee],
    pose[HeroJoint.ankle],
    pose[HeroJoint.toe],
  );
  withFrame(
    canvas,
    hip,
    up,
    (f) => _torso(canvas, look, torsoLen, f, cloak: cloak),
  );
  if (sword) withFrame(canvas, hip, up, (f) => _sword(canvas, look, f));

  shadedChain(
    canvas,
    [(shoulder, neck, 5.5 + look.fat * 2, 5 + look.fat * 2)],
    look.skin,
    highlight: 0,
  );
  _cachedHead(canvas, head, headUp, look, cloak, effort, joy);

  _arm(
    canvas,
    look,
    shoulder,
    pose[HeroJoint.elbow],
    pose[HeroJoint.wrist],
    onGround: ground - pose[HeroJoint.wrist].dy < 14,
  );
  canvas.restore();
  if (frost > 0.02) {
    canvas.restore();
    if (frost > 0.5) {
      // Tinh thể băng mọc ở vai, tay, đầu.
      final k = (frost - 0.5) * 2;
      for (final j in [HeroJoint.shoulder, HeroJoint.wrist, HeroJoint.head]) {
        _iceCrystal(canvas, pose[j], 4 + 5 * k);
      }
    }
  }
}

void _iceCrystal(Canvas canvas, Offset at, double size) {
  final paint = Paint()
    ..color = const Color(0xFFE6F7FF)
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;
  final edge = Paint()
    ..color = const Color(0xFF3B8FCF)
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 3; i++) {
    final a = math.pi / 3 * i;
    final d = Offset(math.cos(a), math.sin(a)) * size;
    canvas.drawLine(at - d, at + d, edge);
    canvas.drawLine(at - d, at + d, paint);
  }
}

/// Tay chân to ra theo độ béo, nữ thon hơn một chút.
double _limb(HeroLook look) => (1 + look.fat * 0.8) * (look.female ? 0.92 : 1);

void _arm(
  Canvas canvas,
  HeroLook look,
  Offset shoulder,
  Offset elbow,
  Offset wrist, {
  bool far = false,
  bool onGround = false,
}) {
  final k = _limb(look);
  final skin = far ? darken(look.skin, 0.18) : look.skin;
  // Giải phẫu (Loomis): cơ vai trùm đầu cánh tay, bắp tay sau dày phía sau,
  // bắp tay trước phồng giữa, khuỷu thắt; cẳng tay to ngay dưới khuỷu (cơ
  // cánh tay quay) rồi thon dần tới cổ tay. Nắm đấm là khối riêng.
  if (far) {
    // Tay phía xa gần như khuất sau thân: ống thuôn rẻ, không cơ, không
    // vòng tay (giữ ngân sách hiệu năng).
    shadedChain(
      canvas,
      [(shoulder, elbow, 6.4 * k, 5.0 * k), (elbow, wrist, 5.2 * k, 4.0 * k)],
      skin,
      highlight: 0,
    );
    if (onGround) _flatHand(canvas, wrist, skin, 0.95 * k);
    return;
  }
  shadedLimb(
    canvas,
    [
      (shoulder, elbow, HumanAnatomy.upperArm),
      (elbow, wrist, HumanAnatomy.forearm),
    ],
    skin,
    scale: k,
    highlight: far ? 0 : 1.4,
    definition: far ? 0 : 0.55,
  );
  // Vòng tay vàng ôm khối cẳng tay gần cổ tay.
  paintLimbBand(
    canvas,
    elbow,
    wrist,
    HumanAnatomy.forearm,
    t0: 0.68,
    t1: 0.84,
    scale: k,
  );
  // Chống đẩy: bàn tay úp phẳng trên sàn, ngón hướng về trước (phía đầu);
  // đứng: nắm tay buông xuôi.
  if (onGround) {
    _flatHand(canvas, wrist, skin, 0.95 * k);
  } else {
    shadedHand(
      canvas,
      buildHand(wrist, wrist - elbow, pose: HandPose.fist, scale: 0.95 * k),
      skin,
    );
  }
}

/// Bàn tay úp phẳng trên sàn nhìn ngang (chống đẩy): gót bàn tay ngay dưới
/// cổ tay, ngón duỗi về phía đầu (+x), lòng bàn tay áp sàn; mu bàn tay hơi
/// gồ, đốt ngón nhô nhẹ, ngón cái nằm dọc mép trên.
void _flatHand(Canvas canvas, Offset wrist, Color skin, double s) {
  final floor = wrist.dy + 2.2 * s;
  Offset p(double x, double y) => Offset(wrist.dx + x * s, floor - y * s);
  final hand = smoothPath(
    [
      p(-2.4, 0.2), // gót bàn tay
      p(-2.6, 3.0),
      p(0.6, 4.6), // mu bàn tay gồ
      p(6.0, 4.0), // đốt ngón
      p(9.6, 2.6),
      p(13.0, 1.4), // đầu ngón giữa
      p(13.4, 0.3),
      p(6.0, 0.0),
    ],
    closed: true,
    tension: 0.25,
  );
  shadedPath(
    canvas,
    hand,
    skin,
    PartFrame.world,
    shadow: 1.6,
    highlight: 0.9,
    outlineWidth: 1.1,
  );
  final line = Paint()
    ..color = darken(skin, 0.33)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.7 * s.clamp(0.8, 1.6)
    ..strokeCap = StrokeCap.round;
  // Kẽ ngón chồng lên nhau và nếp đốt ngón.
  for (final y in [1.1, 2.0]) {
    canvas.drawLine(p(6.6, y), p(12.4, y * 0.55), line);
  }
  for (final x in [7.6, 10.4]) {
    canvas.drawLine(p(x, 0.6), p(x - 0.4, 2.6), line);
  }
  // Ngón cái dọc mép trên, hướng về trước.
  final thumb = smoothPath(
    [p(0.4, 3.6), p(5.2, 4.6), p(7.4, 4.0), p(5.0, 3.2)],
    closed: true,
    tension: 0.3,
  );
  shadedPath(
    canvas,
    thumb,
    skin,
    PartFrame.world,
    shadow: 1,
    highlight: 0.6,
    outlineWidth: 0.9,
  );
}

void _leg(
  Canvas canvas,
  HeroLook look,
  Offset hip,
  Offset knee,
  Offset ankle,
  Offset toe, {
  bool far = false,
}) {
  final k = _limb(look);
  Color shade(Color c) => far ? darken(c, 0.18) : c;
  // Đùi: cơ tứ đầu phồng phía trước ở 1/3 trên, thắt ở gối; cẳng chân: bắp
  // chân phồng phía sau ở 1/3 trên, ống chân phía trước thẳng, cổ chân thắt.
  if (far) {
    // Chân phía xa: ống thuôn rẻ + bàn chân/đế đơn giản.
    shadedChain(
      canvas,
      [(hip, knee, 8.2 * k, 6.0 * k), (knee, ankle, 6.0 * k, 4.0 * k)],
      shade(look.skin),
      highlight: 0,
    );
    shadedChain(
      canvas,
      [(ankle, toe, 4.6, 3.8)],
      shade(CostumeColors.sole),
      shadow: 1,
      highlight: 0,
    );
    return;
  }
  shadedLimb(
    canvas,
    [
      (hip, knee, look.female ? HumanAnatomy.thighFemale : HumanAnatomy.thigh),
      (knee, ankle, HumanAnatomy.shin),
    ],
    shade(look.skin),
    scale: k,
    highlight: far ? 0 : 1.4,
    definition: far ? 0 : 0.55,
  );
  if (!far) {
    // Xương bánh chè (rãnh cơ tay chân do vector_anatomy vẽ).
    final kd = (ankle - knee) / (ankle - knee).distance;
    canvas.drawArc(
      Rect.fromCircle(center: knee + kd * 1.5, radius: 2.6 * k),
      math.atan2(kd.dy, kd.dx) + 1.9,
      2.4,
      false,
      Paint()
        ..color = darken(look.skin, 0.28).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round,
    );
  }
  // Dép Hy Lạp: bàn chân, đế, quai, dây buộc chéo lên ống chân.
  paintGreekSandal(
    canvas,
    knee: knee,
    ankle: ankle,
    toe: toe,
    facingRight: true,
    skin: look.skin,
    scale: k,
    lace: 0.38,
    far: far,
  );
}

/// Thân + áo chiton, vẽ trong hệ cục bộ gốc ở hông (+x là phía ngực).
void _torso(
  Canvas canvas,
  HeroLook look,
  double len,
  PartFrame f, {
  required bool cloak,
}) {
  final fat = look.fat;
  final female = look.female;
  // Vai nam rộng hơn, hông nữ rộng hơn; bụng nhô ra theo độ béo.
  final back = 9 + fat * 7;
  final shoulderBack = female ? 9.0 : 10.5;
  final chest = (female ? 11.0 : 12.0) + fat * 7;
  final belly = 9 + fat * 26;
  final hipFront = (female ? 10.5 : 9.0) + fat * 10;
  // Vải rủ theo trọng lực: khi mặt trước thân hướng xuống đất (chống đẩy),
  // phần áo giữa ngực và thắt lưng võng xuống — không ôm thân như tấm bìa.
  final g = f.down;
  final sagK = g.dx.clamp(0.0, 1.0);
  final sag = g * ((5 + fat * 3) * sagK);
  final body = Path()
    ..moveTo(-back, 2)
    ..cubicTo(
      -back - 2,
      -len * 0.4,
      -shoulderBack - 3,
      -len * 0.8,
      -shoulderBack,
      -len - 3,
    )
    ..quadraticBezierTo(0, -len - 8, 9, -len + 1)
    // Ngực xuống tới eo, rồi bụng tròn ở nửa dưới thân (béo thì nhô xa).
    ..cubicTo(chest + 1, -len * 0.85, chest, -len * 0.7, chest, -len * 0.6)
    ..cubicTo(
      belly + 3 + sag.dx,
      -len * 0.45 + sag.dy,
      belly + 3 + sag.dx * 0.8,
      -len * 0.04 + sag.dy * 0.5,
      hipFront,
      2,
    )
    ..close();
  shadedPath(canvas, body, HeroColors.tunic, f, shadow: 5, highlight: 2);

  canvas.save();
  canvas.clipPath(body);
  // Dây áo chéo qua vai (kiểu chiton) và nếp gấp vải.
  canvas.drawLine(
    Offset(-shoulderBack, -len + 2),
    Offset(chest, -len * 0.45),
    Paint()
      ..color = HeroColors.trim
      ..strokeWidth = 3.4,
  );
  final fold = Paint()
    ..color = shadeOf(HeroColors.tunic)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  // Nếp căng toả từ thắt lưng lên dây vai (vải bị kéo), nếp chữ V nhỏ.
  canvas.drawPath(
    Path()
      ..moveTo(-2, -len * 0.35)
      ..quadraticBezierTo(2, -len * 0.2, 0, -10)
      ..moveTo(5, -len * 0.3)
      ..quadraticBezierTo(7, -len * 0.18, 6, -11)
      ..moveTo(-6, -len * 0.62)
      ..quadraticBezierTo(-4, -len * 0.4, -6, -12)
      ..moveTo(9, -len * 0.46)
      ..quadraticBezierTo(11, -len * 0.3, 10, -12),
    fold,
  );
  canvas.drawPath(
    Path()
      ..moveTo(-1, -14)
      ..lineTo(2, -10)
      ..lineTo(5, -14)
      ..moveTo(6, -16)
      ..lineTo(8.5, -12)
      ..lineTo(11, -15),
    fold..strokeWidth = 0.8,
  );
  fold.strokeWidth = 1.2;
  if (sagK > 0.25) {
    // Nếp rủ: từ chỗ vải tì lên ngực/bụng chảy theo hướng trọng lực vào bụng
    // võng; mỗi nếp một rãnh tối và một sống sáng song song.
    final crease = Paint()
      ..color = shadeOf(HeroColors.tunic).withValues(alpha: 0.75 * sagK);
    final ridge = Paint()
      ..color = lighten(HeroColors.tunic, 0.5).withValues(alpha: 0.7 * sagK);
    for (final (t, w) in const [(0.52, 1.0), (0.36, 0.8), (0.2, 0.9)]) {
      final top = Offset(chest - 3, -len * t);
      final drop = sag.distance + 3;
      final end = top + g * drop + Offset(0, len * 0.04);
      final mid = Offset.lerp(top, end, 0.5)! + Offset(0, len * 0.015);
      canvas.drawPath(
        taperedStroke([top, mid, end], 1.5 * w, peak: 0.6, samples: 6),
        crease,
      );
      canvas.drawPath(
        taperedStroke(
          [top + const Offset(0, -1.6), mid + const Offset(0, -1.6), end],
          1 * w,
          peak: 0.6,
          samples: 6,
        ),
        ridge,
      );
    }
  }
  // Bóng đổ của dây vai lên vải.
  canvas.drawLine(
    Offset(-shoulderBack + 1.5, -len + 5),
    Offset(chest + 1.5, -len * 0.45 + 3),
    Paint()
      ..color = shadeOf(HeroColors.tunic).withValues(alpha: 0.6)
      ..strokeWidth = 2,
  );
  canvas.restore();

  // Váy áo phủ xuống đùi (nữ dài tới gối), viền hoạ tiết Hy Lạp.
  final hem = female ? 30.0 : 17.0;
  final flare = female ? 4.0 : 0.0;
  final skirtFront = hipFront + 2 + fat * 2;
  final skirt = Path()
    ..moveTo(-back - 1, -6)
    ..lineTo(hipFront, -6)
    ..lineTo(skirtFront + flare, hem)
    ..lineTo(-back - 3 - flare, hem)
    ..close();
  shadedPath(canvas, skirt, HeroColors.tunic, f, shadow: 4, highlight: 1.5);
  final hemRect = Rect.fromLTRB(
    -back - 3.5 - flare,
    hem - 5,
    skirtFront + flare,
    hem,
  );
  canvas.save();
  canvas.clipPath(skirt);
  canvas.drawRect(hemRect, fillPaint(HeroColors.trim));
  // Hoạ tiết vuông kiểu "meander" đơn giản.
  final key = fillPaint(lighten(HeroColors.trim, 0.55));
  for (var x = hemRect.left + 1.5; x < hemRect.right - 1; x += 5) {
    canvas.drawRect(Rect.fromLTWH(x, hem - 3.8, 2.4, 2.4), key);
  }
  // Váy xếp ly: dải sáng–tối xen kẽ, loe dần xuống gấu.
  final pleatDark = fillPaint(
    shadeOf(HeroColors.tunic).withValues(alpha: 0.45),
  );
  final pleatLit = fillPaint(
    lighten(HeroColors.tunic, 0.4).withValues(alpha: 0.6),
  );
  final left = -back - 1;
  final width = hipFront - left;
  for (var i = 0; i < 5; i++) {
    final x0 = left + width * (i + 0.5) / 5;
    final x1 = x0 + (x0 - (left + width / 2)) * 0.25 + flare * (i - 2) * 0.3;
    canvas.drawPath(
      Path()
        ..moveTo(x0, -5)
        ..lineTo(x0 + 1.2, -5)
        ..lineTo(x1 + 2, hem - 5)
        ..lineTo(x1, hem - 5)
        ..close(),
      i.isEven ? pleatDark : pleatLit,
    );
  }
  canvas.restore();

  // Thắt lưng da, khoá vàng.
  shadedPath(
    canvas,
    Path()..addRRect(
      RRect.fromLTRBR(
        -back - 1,
        -9,
        hipFront + 1,
        -4,
        const Radius.circular(2),
      ),
    ),
    HeroColors.belt,
    f,
    shadow: 1.5,
    highlight: 0.8,
    outlineWidth: 1.2,
  );
  final buckle = Rect.fromCircle(
    center: Offset(hipFront - 1, -6.5),
    radius: 2.4,
  );
  canvas.drawOval(buckle, goldPaint(buckle));

  if (cloak) {
    // Hai chân trước của tấm da sư tử buộc thành nút trước ngực.
    final knot = Offset(chest - 3, -len + 12);
    shadedPath(
      canvas,
      Path()
        ..moveTo(-6, -len - 2)
        ..quadraticBezierTo(4, -len + 2, knot.dx, knot.dy)
        ..lineTo(knot.dx - 3, knot.dy + 3)
        ..quadraticBezierTo(0, -len + 6, -8, -len + 3)
        ..close(),
      HeroColors.pelt,
      f,
      shadow: 1.5,
      highlight: 0.8,
      outlineWidth: 1.2,
    );
    shadedPath(
      canvas,
      Path()..addOval(Rect.fromCircle(center: knot, radius: 3.2)),
      darken(HeroColors.pelt, 0.1),
      f,
      shadow: 1.2,
      highlight: 0.6,
      outlineWidth: 1,
    );
  }
}

/// Khiên vảy rồng đeo sau lưng, vẽ trong hệ cục bộ gốc ở hông.
void _shield(Canvas canvas, double len, PartFrame f) {
  final center = Offset(-17, -len * 0.58);
  const r = 14.0;
  final disc = Path()..addOval(Rect.fromCircle(center: center, radius: r));
  shadedPath(
    canvas,
    disc,
    const Color(0xFF4F7391),
    f,
    shadow: 3,
    highlight: 1.4,
  );
  // Vảy rồng xếp lớp.
  canvas.save();
  canvas.clipPath(disc);
  final scale = Paint()
    ..color = const Color(0xFF8FB8D2)
    ..strokeWidth = 1.1
    ..style = PaintingStyle.stroke;
  for (var row = -2; row <= 2; row++) {
    for (var col = -2; col <= 2; col++) {
      final c = center + Offset(col * 6.0 + (row.isOdd ? 3 : 0), row * 5.0);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: 3.4),
        0,
        math.pi,
        false,
        scale,
      );
    }
  }
  canvas.restore();
  // Viền vàng và núm giữa.
  canvas.drawCircle(
    center,
    r - 1,
    Paint()
      ..shader = Gradient.linear(
        center - const Offset(r, r),
        center + const Offset(r, r),
        const [Color(0xFFFFF1A8), Color(0xFFE8B83A), Color(0xFFB07A14)],
        const [0, 0.45, 1],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6,
  );
  final boss = Rect.fromCircle(center: center, radius: 3.6);
  canvas.drawOval(boss.inflate(1), fillPaint(HeroColors.outline));
  canvas.drawOval(boss, goldPaint(boss));
  glint(canvas, center + const Offset(-6, -6), 2);
}

/// Kiếm Kusanagi trong vỏ giắt ở thắt lưng: chuôi chĩa ra trước-lên, vỏ
/// nằm dọc theo đùi, hơi chếch ra sau. Vẽ trong hệ cục bộ gốc ở hông.
void _sword(Canvas canvas, HeroLook look, PartFrame f) {
  final front = (look.female ? 10.5 : 9.0) + look.fat * 10;
  final guard = Offset(front - 6, -7);
  final scabbardEnd = guard + const Offset(-12, 34);
  final hiltEnd = guard + const Offset(7, -9);
  // Vỏ sơn mài đen, đầu vỏ bịt vàng.
  shadedChain(
    canvas,
    [(guard, scabbardEnd, 2.6, 2.4)],
    const Color(0xFF26201E),
    shadow: 1,
    highlight: 0.6,
  );
  final tip = Rect.fromCircle(center: scabbardEnd, radius: 2.6);
  canvas.drawOval(tip, goldPaint(tip));
  // Chuôi quấn dây hình thoi.
  shadedChain(
    canvas,
    [(guard, hiltEnd, 2.4, 2.2)],
    const Color(0xFF6B2E2E),
    shadow: 0.8,
    highlight: 0.5,
  );
  final wrap = Paint()
    ..color = const Color(0xFFE8DCC0)
    ..strokeWidth = 0.9;
  final d = (hiltEnd - guard) / (hiltEnd - guard).distance;
  final n = Offset(-d.dy, d.dx);
  for (var t = 0.2; t < 0.95; t += 0.22) {
    final p = Offset.lerp(guard, hiltEnd, t)!;
    canvas.drawLine(p - n * 2 - d, p + n * 2 + d, wrap);
  }
  // Đốc kiếm (tsuba) vàng.
  final tsuba = Rect.fromCenter(center: guard, width: 4, height: 9);
  canvas.save();
  canvas.translate(guard.dx, guard.dy);
  canvas.rotate(math.atan2(d.dy, d.dx));
  canvas.translate(-guard.dx, -guard.dy);
  canvas.drawRRect(
    RRect.fromRectAndRadius(tsuba.inflate(0.9), const Radius.circular(2)),
    fillPaint(HeroColors.outline),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(tsuba, const Radius.circular(1.6)),
    goldPaint(tsuba),
  );
  canvas.restore();
}

/// Tấm da sư tử phủ sau lưng, vẽ trong hệ cục bộ gốc ở hông.
void _peltBack(Canvas canvas, double len, PartFrame f, double time) {
  // Vạt dưới phấp phới theo gió (chuyển động theo sau).
  final w1 = math.sin(time * 3.1) * 2.5;
  final w2 = math.sin(time * 3.1 + 1.3) * 2;
  final pelt = Path()
    ..moveTo(-6, -len - 6)
    ..cubicTo(-20, -len * 0.75, -22 + w1 * 0.4, -len * 0.3, -17 + w1, 8)
    // Mép dưới răng cưa như lông thú.
    ..lineTo(-12 + w2 * 0.5, 4)
    ..lineTo(-9 + w2, 11)
    ..lineTo(-5, 4)
    ..cubicTo(-8, -len * 0.3, -6, -len * 0.7, 4, -len - 2)
    ..close();
  // Chân trước sư tử rủ xuống sau lưng, móng còn nguyên.
  final paw = chainPath([
    (Offset(-14, -len * 0.2), const Offset(-17, 14), 3, 2.6),
  ]);
  shadedPath(canvas, paw, darken(HeroColors.pelt, 0.12), f, shadow: 1.6);
  final claw = Paint()
    ..color = const Color(0xFFFFF4DC)
    ..strokeWidth = 1.1
    ..strokeCap = StrokeCap.round;
  for (final dx in [-1.5, 0.5, 2.5]) {
    canvas.drawLine(Offset(-19 + dx, 15), Offset(-20 + dx, 18), claw);
  }
  shadedPath(canvas, pelt, HeroColors.pelt, f, shadow: 4, highlight: 1.5);
  // Lông xuôi theo trọng lực.
  furStrokes(
    canvas,
    pelt,
    darken(HeroColors.pelt, 0.3),
    dir: const Offset(-0.2, 1),
    count: 26,
    length: 6,
    width: 0.9,
    seed: 7,
  );
}

/// Phần tóc nằm sau thân (đuôi ngựa, tóc dài), rủ theo trọng lực.
void _hairBack(Canvas canvas, HeroLook look, PartFrame f) {
  final down = f.down;
  final hair = look.hair;
  switch (look.hairStyle) {
    case HairStyle.ponytail:
      const root = Offset(-13, -6);
      final tip = root + const Offset(-6, 0) + down * 24;
      final mid = root + const Offset(-8, -2) + down * 10;
      shadedPath(
        canvas,
        Path()
          ..moveTo(root.dx, root.dy - 4)
          ..quadraticBezierTo(mid.dx - 4, mid.dy, tip.dx, tip.dy)
          ..quadraticBezierTo(mid.dx + 4, mid.dy + 2, root.dx + 2, root.dy + 4)
          ..close(),
        hair,
        f,
        shadow: 2.5,
        highlight: 1.2,
      );
      // Dây buộc tóc.
      canvas.drawCircle(
        root + const Offset(-2, 0),
        2.6,
        fillPaint(HeroColors.headband),
      );
    case HairStyle.long:
      final tip = const Offset(-6, 4) + down * 30;
      shadedPath(
        canvas,
        Path()
          ..moveTo(-4, -16)
          ..quadraticBezierTo(-22, -10, tip.dx - 8, tip.dy)
          ..lineTo(tip.dx + 6, tip.dy + 2)
          ..quadraticBezierTo(-4, 6, 2, -6)
          ..close(),
        hair,
        f,
        shadow: 3,
        highlight: 1.4,
      );
    case HairStyle.curly || HairStyle.buzz || HairStyle.bun:
      break;
  }
}

/// Đầu, vẽ trong hệ cục bộ gốc ở tâm đầu, mặt hướng +x.
/// Đầu vẽ sẵn thành Picture theo (ngoại hình, mũ, góc nghiêng làm tròn 5°,
/// mức gắng sức làm tròn 1/4, cười): mỗi khung chỉ vẽ lại hình đã có thay
/// vì dựng lại hàng chục Path tóc, mặt, mắt. Góc làm tròn nên hướng sáng
/// lệch tối đa 2,5° — không nhận ra.
final _headCache = <String, Picture>{};

void _cachedHead(
  Canvas canvas,
  Offset head,
  Offset up,
  HeroLook look,
  bool cloak,
  double effort,
  double joy,
) {
  const step = math.pi / 36;
  final angle = (math.atan2(up.dx, -up.dy) / step).round() * step;
  final e = (effort.clamp(0.0, 1.0) * 4).round() / 4;
  final j = joy > 0.5 ? 1.0 : 0.0;
  final key = [
    look.sex.index,
    look.skin.toARGB32(),
    look.hair.toARGB32(),
    look.hairStyle.index,
    look.fat.toStringAsFixed(2),
    cloak,
    (angle / step).round(),
    e,
    j,
  ].join('|');
  var picture = _headCache[key];
  if (picture == null) {
    if (_headCache.length > 160) {
      _headCache.remove(_headCache.keys.first)?.dispose();
    }
    final recorder = PictureRecorder();
    final c = Canvas(recorder)
      ..rotate(angle)
      ..scale(_headScale);
    _head(c, look, PartFrame(angle), cloak: cloak, effort: e, joy: j);
    picture = _headCache[key] = recorder.endRecording();
  }
  canvas.save();
  canvas.translate(head.dx, head.dy);
  canvas.drawPicture(picture);
  canvas.restore();
}

void _head(
  Canvas canvas,
  HeroLook look,
  PartFrame f, {
  required bool cloak,
  double effort = 0,
  double joy = 0,
}) {
  const r = 15.0;
  final hair = look.hair;
  final cheeks = look.fat * 2.5;

  // Tóc phía sau đầu (dưới mũ trùm nếu có).
  if (!cloak && look.hairStyle != HairStyle.buzz) {
    shadedPath(
      canvas,
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(-3, -2), radius: r + 1)),
      hair,
      f,
      highlight: 0,
    );
  }
  // Mặt dựng theo Loomis (quả cầu + khối hàm): trán, gờ mày, sống mũi,
  // cằm, góc hàm; má bạnh theo độ béo.
  final c = cheeks;
  final face = Path()
    ..moveTo(-13, -10)
    ..quadraticBezierTo(-6, -16, 6, -14.5)
    ..quadraticBezierTo(12, -12, 13, -6)
    ..lineTo(13.4, -2)
    ..quadraticBezierTo(13.6, 4, 14, 7)
    ..quadraticBezierTo(13.4, 11, 12.6, 13)
    ..quadraticBezierTo(11, 16.5 + c * 0.4, 6, 16.5 + c * 0.6)
    ..quadraticBezierTo(-1 - c, 15 + c, -4 - c * 0.6, 11 + c * 0.4)
    ..quadraticBezierTo(-10, 7, -12, 2)
    ..quadraticBezierTo(-15, -4, -13, -10)
    ..close();
  shadedPath(canvas, face, look.skin, f, shadow: 3.5, highlight: 1.2);
  // Các mặt phẳng: mặt bên má/hàm tối hơn mặt trước, hốc mắt trũng.
  canvas.save();
  canvas.clipPath(face);
  canvas.drawPath(
    Path()
      ..moveTo(3, -4)
      ..quadraticBezierTo(7, 3, 5, 12)
      ..lineTo(-5, 12 + c)
      ..lineTo(-6, -2)
      ..close(),
    fillPaint(coreShadeOf(look.skin).withValues(alpha: 0.22)),
  );
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(9, -2.5), width: 9, height: 6),
    fillPaint(coreShadeOf(look.skin).withValues(alpha: 0.28)),
  );
  // Gò má sáng.
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(9, 3.5), width: 6, height: 3),
    fillPaint(lighten(look.skin, 0.12).withValues(alpha: 0.7)),
  );
  canvas.restore();
  if (look.hairStyle == HairStyle.buzz && !cloak) {
    // Tóc cắt sát: một lớp mỏng trên đỉnh và gáy.
    canvas.save();
    canvas.clipPath(face);
    canvas.drawPath(
      Path()
        ..moveTo(-18, 10)
        ..lineTo(-18, -18)
        ..lineTo(12, -18)
        ..quadraticBezierTo(4, -9, -4, -7)
        ..quadraticBezierTo(-8, 0, -5, 10)
        ..close(),
      fillPaint(hair),
    );
    canvas.restore();
  }
  // Má hồng.
  canvas.drawOval(
    Rect.fromCenter(center: Offset(7, 5 + cheeks * 0.5), width: 6, height: 3.5),
    fillPaint(HeroColors.blush.withValues(alpha: 0.35)),
  );
  // Mũi.
  shadedPath(
    canvas,
    Path()
      ..moveTo(13.5, -1)
      ..quadraticBezierTo(19, 3, 14.5, 5)
      ..close(),
    look.skin,
    f,
    shadow: 1,
    highlight: 0,
    outlineWidth: 1,
  );
  // Mắt: lòng trắng, tròng, con ngươi, chấm sáng. Gắng sức thì nheo lại,
  // vui thì cong thành hình trăng khuyết.
  const eye = Offset(8.5, -1);
  final ink = Paint()
    ..color = HeroColors.outline
    ..strokeWidth = 1.3
    ..strokeCap = StrokeCap.round;
  if (joy > 0.5) {
    canvas.drawPath(
      Path()
        ..moveTo(eye.dx - 3, eye.dy + 1)
        ..quadraticBezierTo(eye.dx, eye.dy - 3.5, eye.dx + 3, eye.dy + 1),
      ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    ink
      ..style = PaintingStyle.fill
      ..strokeWidth = 1.3;
  } else {
    // Mắt hạnh nhân nhỏ (không tròn to kiểu trẻ con), mí trên đậm.
    final open = 4.6 - effort * 2.4;
    final white = Path()
      ..moveTo(eye.dx - 3, eye.dy + 0.4)
      ..quadraticBezierTo(eye.dx, eye.dy - open * 0.75, eye.dx + 3.2, eye.dy)
      ..quadraticBezierTo(
        eye.dx,
        eye.dy + open * 0.45,
        eye.dx - 3,
        eye.dy + 0.4,
      )
      ..close();
    canvas.drawPath(white, fillPaint(HeroColors.eyeWhite));
    canvas.save();
    canvas.clipPath(white);
    canvas.drawCircle(eye + const Offset(1, 0), 2, fillPaint(HeroColors.iris));
    canvas.drawCircle(
      eye + const Offset(1.2, 0),
      1,
      fillPaint(HeroColors.outline),
    );
    canvas.drawCircle(
      eye + const Offset(0.5, -0.8),
      0.55,
      fillPaint(const Color(0xFFFFFFFF)),
    );
    // Bóng mí trên đổ xuống lòng trắng.
    canvas.drawRect(
      Rect.fromLTWH(eye.dx - 4, eye.dy - 4, 8, 1.6 + open * 0.25),
      fillPaint(const Color(0x33402820)),
    );
    canvas.restore();
    // Mí trên đậm, mí dưới mảnh.
    canvas.drawPath(
      Path()
        ..moveTo(eye.dx - 3.4, eye.dy + 0.6)
        ..quadraticBezierTo(eye.dx, eye.dy - open * 0.8, eye.dx + 3.6, eye.dy),
      Paint()
        ..color = HeroColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(eye.dx - 2, eye.dy + 1.2)
        ..quadraticBezierTo(
          eye.dx + 0.5,
          eye.dy + open * 0.5,
          eye.dx + 2.8,
          eye.dy + 0.6,
        ),
      Paint()
        ..color = darken(look.skin, 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
  }
  // Hàng mi (ẩn khi nheo mắt gắng sức hoặc cười, kẻo chồng lên lông mày).
  if (look.female && effort < 0.45 && joy <= 0.5) {
    canvas.drawLine(
      eye + const Offset(2.5, -2.6),
      eye + const Offset(4.6, -4.2),
      ink,
    );
    canvas.drawLine(
      eye + const Offset(1, -3.3),
      eye + const Offset(2.4, -5.4),
      ink,
    );
  }
  // Lông mày: gắng sức thì chau xuống phía mũi.
  canvas.drawLine(
    eye + Offset(-4, -6.5 - effort * 1.5),
    eye + Offset(4, -5 + effort * 2.2),
    Paint()
      ..color = darken(hair, 0.1)
      ..strokeWidth = look.female ? 1.6 : 2.3
      ..strokeCap = StrokeCap.round,
  );
  final mouthY = 8.6 + cheeks * 0.4;
  if (joy > 0.5) {
    // Cười tươi há miệng.
    final mouth = Path()
      ..moveTo(8.5, mouthY - 1)
      ..quadraticBezierTo(11.5, mouthY + 5, 14.5, mouthY - 1.5)
      ..close();
    canvas.drawPath(
      mouth,
      Paint()
        ..color = HeroColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(mouth, fillPaint(const Color(0xFF7A2626)));
    canvas.drawRect(
      Rect.fromLTRB(9.3, mouthY - 1, 13.8, mouthY + 0.4),
      fillPaint(const Color(0xFFFFFFFF)),
    );
  } else if (effort > 0.55) {
    // Nghiến răng: hàm răng trắng có kẽ.
    final teeth = RRect.fromLTRBR(
      8.6,
      mouthY - 1.6,
      14.2,
      mouthY + 1.8,
      const Radius.circular(1.2),
    );
    canvas.drawRRect(
      teeth,
      Paint()
        ..color = HeroColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    canvas.drawRRect(teeth, fillPaint(const Color(0xFFFFFFFF)));
    final gap = Paint()
      ..color = darken(look.skin, 0.4)
      ..strokeWidth = 0.6;
    canvas.drawLine(Offset(8.8, mouthY + 0.1), Offset(14, mouthY + 0.1), gap);
    for (final x in [10.4, 12.2]) {
      canvas.drawLine(Offset(x, mouthY - 1.4), Offset(x, mouthY + 1.6), gap);
    }
  } else {
    // Miệng cười nhẹ.
    canvas.drawPath(
      Path()
        ..moveTo(9.5, mouthY)
        ..quadraticBezierTo(11.5, mouthY + 1.4, 13.5, mouthY - 0.6),
      Paint()
        ..color = look.female ? HeroColors.lips : darken(look.skin, 0.45)
        ..strokeWidth = look.female ? 1.8 : 1.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }
  // Mồ hôi khi gắng sức nhiều.
  if (effort > 0.6) {
    final drop = Path()
      ..moveTo(-1, -12)
      ..quadraticBezierTo(-4, -7, -1, -6)
      ..quadraticBezierTo(2, -7, -1, -12)
      ..close();
    canvas.drawPath(
      drop,
      Paint()
        ..color = const Color(0xFF2E6FA8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawPath(drop, fillPaint(const Color(0xFFBFE6FF)));
  }
  // Tai: vành tai thuôn (trên rộng, dái tai nhỏ) và nếp trong.
  shadedPath(
    canvas,
    Path()
      ..moveTo(-1, -2.5)
      ..quadraticBezierTo(-6, -3.5, -5.5, 1.5)
      ..quadraticBezierTo(-5, 5.5, -1.5, 5.5)
      ..quadraticBezierTo(-0.5, 2, -1, -2.5)
      ..close(),
    look.skin,
    f,
    shadow: 1.2,
    highlight: 0,
    outlineWidth: 1,
  );
  canvas.drawPath(
    Path()
      ..moveTo(-2, -1)
      ..quadraticBezierTo(-4.5, -1, -4, 1.8)
      ..quadraticBezierTo(-3.5, 3.4, -2.2, 3.2),
    Paint()
      ..color = darken(look.skin, 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round,
  );

  if (cloak) {
    _lionHood(canvas, f);
    return;
  }

  switch (look.hairStyle) {
    case HairStyle.curly:
      // Một khối tóc liền (hợp các búp, mép ngoài gồ lượn) thay cho các
      // vòng tròn rời; bên trong là các hàng lọn xoăn nét thon so le.
      var mass = Path();
      for (final (c, rr) in const [
        (Offset(-13, -2), 5.2),
        (Offset(-11.5, -8.5), 5.6),
        (Offset(-6.5, -12.5), 5.6),
        (Offset(0, -14), 5.4),
        (Offset(6, -12.5), 5.0),
        (Offset(10, -9.5), 4.2),
        (Offset(-6, -6), 6.5),
        (Offset(1, -8), 6.0),
      ]) {
        mass = Path.combine(
          PathOperation.union,
          mass,
          Path()..addOval(Rect.fromCircle(center: c, radius: rr)),
        );
      }
      shadedPath(
        canvas,
        mass,
        hair,
        f,
        shadow: 2.2,
        highlight: 1.2,
        outlineWidth: 1.1,
      );
      canvas.save();
      canvas.clipPath(mass);
      final curls = curlRows(
        const Rect.fromLTRB(-15, -16, 12, -3),
        radius: 2.3,
        rnd: math.Random(look.hairStyle.index * 7 + 3),
      );
      canvas.drawPath(curls.dark, Paint()..color = darken(hair, 0.45));
      canvas.drawPath(
        curls.lit,
        Paint()..color = lighten(hair, 0.32).withValues(alpha: 0.85),
      );
      canvas.restore();
      glint(canvas, const Offset(-5, -15), 1.6, alpha: 0.5);
    case HairStyle.buzz:
      break;
    case HairStyle.bun || HairStyle.ponytail || HairStyle.long:
      // Tóc chải mượt ra sau, mái lệch, vệt bóng tóc.
      shadedPath(
        canvas,
        Path()
          ..moveTo(-15, 2)
          ..cubicTo(-18, -16, 2, -22, 13, -9)
          ..quadraticBezierTo(4, -11, -2, -6)
          ..quadraticBezierTo(-9, -3, -15, 2)
          ..close(),
        hair,
        f,
        shadow: 2.5,
        highlight: 1.2,
      );
      canvas.drawPath(
        Path()
          ..moveTo(-8, -12)
          ..quadraticBezierTo(-1, -16, 5, -14),
        Paint()
          ..color = lighten(hair, 0.4)
          ..strokeWidth = 1.6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      if (look.hairStyle == HairStyle.bun) {
        shadedPath(
          canvas,
          Path()..addOval(
            Rect.fromCircle(center: const Offset(-13, -13), radius: 6.5),
          ),
          hair,
          f,
          shadow: 2,
          highlight: 1.2,
        );
      }
  }
  // Băng đô đỏ: viền + vệt sáng, nút thắt sau gáy, hai đuôi băng thon.
  final arcRect = Rect.fromCircle(center: const Offset(-1, 0), radius: r);
  Paint bandStroke(Color c, double w) => Paint()
    ..color = c
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  // Đuôi băng (vẽ trước để nút thắt che gốc).
  for (final (tip, ctrl, wid) in [
    (const Offset(-26, -2), const Offset(-21, -8), 2.2),
    (const Offset(-23, 6), const Offset(-21, 0), 1.8),
  ]) {
    const root = Offset(-14, -5);
    final d = tip - root;
    final n = Offset(-d.dy, d.dx) / d.distance;
    final tail = Path()
      ..moveTo(root.dx + n.dx * wid, root.dy + n.dy * wid)
      ..quadraticBezierTo(
        ctrl.dx + n.dx * wid,
        ctrl.dy + n.dy * wid,
        tip.dx,
        tip.dy,
      )
      ..quadraticBezierTo(
        ctrl.dx - n.dx * wid,
        ctrl.dy - n.dy * wid,
        root.dx - n.dx * wid,
        root.dy - n.dy * wid,
      )
      ..close();
    shadedPath(
      canvas,
      tail,
      HeroColors.headband,
      f,
      shadow: 1.2,
      highlight: 0.6,
      outlineWidth: 1,
    );
  }
  canvas.drawArc(
    arcRect,
    -math.pi * 0.95,
    math.pi * 0.72,
    false,
    bandStroke(HeroColors.outline, 5.4),
  );
  canvas.drawArc(
    arcRect,
    -math.pi * 0.95,
    math.pi * 0.72,
    false,
    bandStroke(HeroColors.headband, 3.4),
  );
  canvas.drawArc(
    Rect.fromCircle(center: const Offset(-1, -0.8), radius: r),
    -math.pi * 0.85,
    math.pi * 0.5,
    false,
    bandStroke(lighten(HeroColors.headband, 0.35), 0.9),
  );
  // Nút thắt.
  shadedPath(
    canvas,
    Path()..addOval(
      Rect.fromCenter(center: const Offset(-14, -5), width: 5, height: 4.4),
    ),
    darken(HeroColors.headband, 0.08),
    f,
    shadow: 1,
    highlight: 0.5,
    outlineWidth: 1,
  );
}

/// Mũ trùm đầu sư tử Nemea (như tượng Hercules cổ đại).
void _lionHood(Canvas canvas, PartFrame f) {
  // Bờm hai lớp hình ngọn lửa, ngọn sẫm (khớp bờm Sư tử Nemea).
  for (final (rr, len, color) in [
    (13.0, 9.0, darken(HeroColors.mane, 0.25)),
    (11.0, 6.0, HeroColors.mane),
  ]) {
    final mane = Path();
    const n = 9;
    for (var i = 0; i < n; i++) {
      final a = math.pi * (0.72 + 0.9 * i / (n - 1));
      final dir = Offset(math.cos(a), math.sin(a));
      final nrm = Offset(-dir.dy, dir.dx);
      final base = const Offset(-4, -1) + dir * rr;
      final tip = base + dir * len + const Offset(-2.5, 1.5);
      mane
        ..moveTo(base.dx + nrm.dx * 4, base.dy + nrm.dy * 4)
        ..quadraticBezierTo(
          base.dx + dir.dx * len * 0.6 + nrm.dx * 2.5,
          base.dy + dir.dy * len * 0.6 + nrm.dy * 2.5,
          tip.dx,
          tip.dy,
        )
        ..quadraticBezierTo(
          base.dx + dir.dx * len * 0.5 - nrm.dx * 2,
          base.dy + dir.dy * len * 0.5 - nrm.dy * 2,
          base.dx - nrm.dx * 4,
          base.dy - nrm.dy * 4,
        )
        ..close();
    }
    // Lấp phần chân bờm: chỉ dải vòng cung sau đầu (không che mặt).
    mane.addPolygon([
      for (var i = 0; i <= 12; i++)
        const Offset(-4, -1) +
            Offset(
                  math.cos(math.pi * (0.72 + 0.9 * i / 12)),
                  math.sin(math.pi * (0.72 + 0.9 * i / 12)),
                ) *
                (rr + 1),
    ], true);
    shadedPath(canvas, mane, color, f, shadow: 2.5, highlight: 1);
    furStrokes(
      canvas,
      mane,
      darken(color, 0.35),
      dir: const Offset(-1, 0.4),
      count: 30,
      length: 5,
      width: 0.8,
      seed: rr.round(),
    );
  }

  // Đầu sư tử úp lên đỉnh đầu, mõm nhô ra trước trán.
  final hood = Path()
    ..moveTo(-15, 3)
    ..cubicTo(-17, -14, -2, -22, 10, -15)
    ..quadraticBezierTo(18, -12, 20, -7)
    ..lineTo(14, -4.5)
    ..quadraticBezierTo(4, -9, -6, -3)
    ..quadraticBezierTo(-10, 2, -15, 3)
    ..close();
  shadedPath(canvas, hood, HeroColors.pelt, f, shadow: 3, highlight: 1.4);
  canvas.save();
  canvas.clipPath(hood);
  // Mõm sáng, gờ mày sẫm, ba vết sẹo vuốt.
  canvas.drawOval(
    const Rect.fromLTWH(9, -12, 12, 7),
    fillPaint(const Color(0xFFE2C08A)),
  );
  canvas.drawPath(
    Path()
      ..moveTo(1, -17)
      ..quadraticBezierTo(7, -19, 12, -15)
      ..lineTo(11, -13)
      ..quadraticBezierTo(6, -16, 1, -15)
      ..close(),
    fillPaint(darken(HeroColors.pelt, 0.3)),
  );
  final scar = Paint()
    ..color = const Color(0xFF8A4A2A)
    ..strokeWidth = 0.8
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 3; i++) {
    canvas.drawLine(Offset(-2 + i * 2.0, -19), Offset(-5 + i * 2.0, -11), scar);
  }
  canvas.restore();
  // Tai sư tử.
  shadedPath(
    canvas,
    Path()..addOval(
      Rect.fromCenter(center: const Offset(-4, -17), width: 7, height: 6),
    ),
    HeroColors.pelt,
    f,
    shadow: 1.2,
    highlight: 0.6,
    outlineWidth: 1.2,
  );
  // Mắt sư tử nhắm (bộ da đã thuần).
  canvas.drawPath(
    Path()
      ..moveTo(4, -14)
      ..quadraticBezierTo(7, -12.5, 10, -13.5),
    Paint()
      ..color = HeroColors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round,
  );
  // Ba nanh trên phủ xuống trán người đội.
  for (final (x, l) in [(11.0, 4.0), (15.0, 5.0), (18.5, 3.5)]) {
    final fang = Path()
      ..moveTo(x - 1.6, -5.5)
      ..lineTo(x + 1.6, -5)
      ..lineTo(x, -5 + l)
      ..close();
    canvas.drawPath(fang, fillPaint(const Color(0xFFFFF6DE)));
    canvas.drawPath(
      fang,
      Paint()
        ..color = HeroColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
  }
  // Da mũi.
  canvas.drawPath(
    Path()
      ..moveTo(18, -10)
      ..quadraticBezierTo(21.5, -10.5, 21, -7.5)
      ..quadraticBezierTo(19, -7, 18, -10)
      ..close(),
    fillPaint(const Color(0xFF3A1E14)),
  );
}
