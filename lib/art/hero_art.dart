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
  // Làm tròn khớp tới 0,5 đơn vị (≈ 1 px) để các khung có tư thế gần như
  // nhau dùng lại hình đã ghi (xem [_cachedPart]).
  pose = _quantize(pose);
  // Chiều cao: phóng to/thu nhỏ quanh điểm chạm đất (mũi chân), nên tay chân
  // vẫn chạm sàn ở mọi tư thế.
  final toe = pose[HeroJoint.toe];
  if (frost > 0.02) {
    // Tách lớp để phủ màu lạnh lên cả người (chỉ tốn khi đang lạnh).
    // Khoanh lớp quanh nhân vật (null = engine có thể lấy cả màn hình).
    final xs = [for (final p in pose.joints.values) p.dx];
    final ys = [for (final p in pose.joints.values) p.dy];
    canvas.saveLayer(
      Rect.fromLTRB(
        xs.reduce(math.min) - 40,
        ys.reduce(math.min) - 50,
        xs.reduce(math.max) + 40,
        ys.reduce(math.max) + 20,
      ),
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
  // Bóng dưới ngực khi chống đẩy: ngực càng sát đất bóng càng đậm, gọn;
  // đẩy lên cao thì nhạt và loang (ánh sáng môi trường lọt vào).
  final chestH = ground - shoulder.dy;
  if (chestH < 40 && (hip.dy - ground).abs() < 40) {
    final k = (1 - chestH / 40).clamp(0.0, 1.0);
    final cx = shoulder.dx * 0.7 + hip.dx * 0.3;
    final w = (hip - shoulder).distance * (0.9 - 0.25 * k);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, ground),
        width: w,
        height: 3 + 3 * (1 - k),
      ),
      Paint()
        ..shader = Gradient.radial(Offset(cx, ground), w / 2, [
          Color.fromRGBO(32, 16, 24, 0.15 + 0.35 * k),
          const Color.fromRGBO(32, 16, 24, 0),
        ]),
    );
  }
  final bodyUp = shoulder - hip;
  final torsoLen = bodyUp.distance;
  final up = bodyUp / torsoLen;

  if (glow > 0) {
    // Hào quang: viền vàng nhiều lớp mờ dần (giả blur, không dùng
    // MaskFilter.blur mỗi khung — rất đắt trên GPU điện thoại).
    final auraShape = capsulePath(hip, shoulder, 22, 24)
      ..addPath(
        capsulePath(shoulder, pose[HeroJoint.wrist], 10, 8),
        Offset.zero,
      );
    for (final (w, a) in const [(14.0, 0.2), (8.0, 0.3), (3.0, 0.5)]) {
      canvas.drawPath(
        auraShape,
        Paint()
          ..color = HeroColors.gold.withValues(alpha: a * glow)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * (0.6 + glow * 0.4)
          ..strokeJoin = StrokeJoin.round,
      );
    }
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
          ..color = Color.fromRGBO(255, 190, 60, 0.35 * glow)
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
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

  final poseKey = _poseKey(pose);
  final lookKey = _lookKey(look);
  // Tay chân phía xa: tối hơn, nằm sau thân.
  _cachedPart(canvas, 'far|$lookKey|$poseKey', (canvas) {
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
  });

  if (cloak) {
    withFrame(canvas, hip, up, (f) => _peltBack(canvas, torsoLen, f, time));
  }
  if (shield) withFrame(canvas, hip, up, (f) => _shield(canvas, torsoLen, f));

  final effortKey = (effort.clamp(0.0, 1.0) * 4).round();
  // Phần còn lại (tóc sau, chân gần, thân, cổ, đầu, tay gần) chỉ phụ thuộc
  // tư thế + ngoại hình + trang bị + biểu cảm (đã làm tròn).
  _cachedPart(
    canvas,
    'near|$lookKey|$poseKey|$cloak|$sword|$effortKey|${joy > 0.5}',
    (canvas) {
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
      // Tay giơ cao (ăn mừng) nằm sau đầu theo chiều sâu: vẽ trước đầu để
      // không che khuôn mặt; các tư thế khác tay gần vẽ sau cùng.
      final raised = pose[HeroJoint.wrist].dy < shoulder.dy - 10;
      void nearArm() => _arm(
        canvas,
        look,
        shoulder,
        pose[HeroJoint.elbow],
        pose[HeroJoint.wrist],
        onGround: ground - pose[HeroJoint.wrist].dy < 14,
      );
      if (raised) nearArm();
      _cachedHead(canvas, head, headUp, look, cloak, effort, joy);
      if (!raised) nearArm();
    },
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

HeroPose _quantize(HeroPose pose) => HeroPose({
  for (final e in pose.joints.entries)
    e.key: Offset(
      (e.value.dx * 2).roundToDouble() / 2,
      (e.value.dy * 2).roundToDouble() / 2,
    ),
});

String _poseKey(HeroPose pose) => [
  for (final j in HeroJoint.values)
    '${(pose[j].dx * 2).round()},${(pose[j].dy * 2).round()}',
].join(';');

String _lookKey(HeroLook look) =>
    '${look.sex.index}/${look.skin.toARGB32()}/${look.hair.toARGB32()}/'
    '${look.hairStyle.index}/${look.fat.toStringAsFixed(2)}';

/// Hình đã ghi của từng phần nhân vật theo khoá (tư thế làm tròn + ngoại
/// hình + trang bị + biểu cảm). Chống đẩy lặp lại cùng dải tư thế nên từ rep
/// thứ hai gần như mọi khung đều trúng: bỏ được việc dựng lại bó cơ, nếp
/// áo… mỗi khung (đo trên CPH2159: phần tốn CPU nhất của khung hình).
final _partCache = PictureCache<String>(maxEntries: 240);

void _cachedPart(Canvas canvas, String key, void Function(Canvas) draw) =>
    _partCache.draw(canvas, key, draw);

/// Cụm tinh thể băng mọc trên người: 4–5 khối lăng trụ thon nhọn toả ra,
/// mỗi khối có mặt sáng (đón sáng) và mặt tối, viền xanh lạnh, chấm loá.
void _iceCrystal(Canvas canvas, Offset at, double size) {
  const angles = [-1.9, -1.35, -0.8, -2.5, -0.3];
  for (var i = 0; i < angles.length; i++) {
    final a = angles[i];
    final len = size * (i.isEven ? 1.3 : 0.9);
    final w = size * 0.32;
    final dir = Offset(math.cos(a), math.sin(a));
    final n = Offset(-dir.dy, dir.dx);
    final base = at + dir * (size * 0.1);
    final shoulder = base + dir * (len * 0.72);
    final tip = base + dir * len;
    final left = Path()
      ..moveTo(base.dx, base.dy)
      ..lineTo(base.dx + n.dx * w, base.dy + n.dy * w)
      ..lineTo(shoulder.dx + n.dx * w, shoulder.dy + n.dy * w)
      ..lineTo(tip.dx, tip.dy)
      ..close();
    final right = Path()
      ..moveTo(base.dx, base.dy)
      ..lineTo(base.dx - n.dx * w, base.dy - n.dy * w)
      ..lineTo(shoulder.dx - n.dx * w, shoulder.dy - n.dy * w)
      ..lineTo(tip.dx, tip.dy)
      ..close();
    final outline = Path()
      ..addPath(left, Offset.zero)
      ..addPath(right, Offset.zero);
    canvas.drawPath(
      outline,
      Paint()
        ..color = const Color(0xFF2E6E9E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(left, Paint()..color = const Color(0xEEE9F8FF));
    canvas.drawPath(right, Paint()..color = const Color(0xDD9FD3F2));
    canvas.drawLine(
      base,
      tip,
      Paint()
        ..color = const Color(0xAAFFFFFF)
        ..strokeWidth = 0.6,
    );
  }
  glint(canvas, at + Offset(-size * 0.3, -size * 0.9), size * 0.3);
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
    // Bàn chân + dép thật (nhân vật đã cache theo tư thế nên không tốn
    // mỗi khung), tối hơn vì khuất.
    paintGreekSandal(
      canvas,
      knee: knee,
      ankle: ankle,
      toe: toe,
      facingRight: true,
      skin: shade(look.skin),
      scale: k,
      lace: 0.3,
      far: true,
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
  // Ánh bóng sơn mài chạy dọc vỏ, đai đồng (kurikata) và dây sageo đỏ.
  final sd = (scabbardEnd - guard) / (scabbardEnd - guard).distance;
  final sn = Offset(-sd.dy, sd.dx);
  canvas.drawPath(
    taperedStroke(
      [guard + sd * 4 - sn * 0.9, scabbardEnd - sd * 4 - sn * 0.9],
      0.8,
      peak: 0.5,
    ),
    fillPaint(const Color(0xAAFFFFFF)),
  );
  final kuri = guard + sd * 8;
  canvas.drawLine(
    kuri - sn * 2.8,
    kuri + sn * 2.8,
    Paint()
      ..color = HeroColors.gold
      ..strokeWidth = 1.6,
  );
  canvas.drawPath(
    taperedStroke(
      [kuri + sn * 2.4, kuri + sn * 3.6 + sd * 5, kuri + sn * 2 + sd * 10],
      1.1,
      peak: 0.2,
      startWidth: 1,
    ),
    fillPaint(const Color(0xFFB8322A)),
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
  // Dây quấn chéo hai chiều tạo các ô thoi lộ da cá đuối trắng.
  for (var t = 0.18; t < 0.95; t += 0.2) {
    final p = Offset.lerp(guard, hiltEnd, t)!;
    canvas.drawLine(p - n * 2 - d, p + n * 2 + d, wrap);
    canvas.drawLine(p + n * 2 - d, p - n * 2 + d, wrap);
  }
  // Núm chuôi (kashira) đồng.
  final kashira = Rect.fromCircle(center: hiltEnd, radius: 1.8);
  canvas.drawOval(kashira.inflate(0.6), fillPaint(HeroColors.outline));
  canvas.drawOval(kashira, goldPaint(kashira));
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
    ..cubicTo(-22, -len * 0.75, -25 + w1 * 0.4, -len * 0.3, -19 + w1, 6)
    ..quadraticBezierTo(-12 + w2, 9, -5, 4)
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
  // Tua lông ở mép dưới tấm da: lọn thon rủ theo trọng lực (f.down), bay
  // nhẹ theo nhịp — thay mép răng cưa.
  final down = f.down;
  final fringe = Path();
  for (var i = 0; i < 6; i++) {
    final t = i / 5;
    final root =
        Offset.lerp(Offset(-19 + w1, 4), const Offset(-6, 2), t)! +
        Offset(0, math.sin(t * math.pi) * 3);
    final sway = math.sin(time * 3.1 + i) * 0.15;
    final dir = Offset(down.dx + sway, down.dy);
    final len2 = 5 + (i % 3) * 1.6;
    final pts = [
      root,
      root + dir * (len2 * 0.5) + Offset(-0.6, 0),
      root + dir * len2,
    ];
    fringe.addPath(
      taperedStroke(pts, 2.6, peak: 0.2, startWidth: 0.9, samples: 6),
      Offset.zero,
    );
  }
  shadedPath(
    canvas,
    fringe,
    darken(HeroColors.pelt, 0.08),
    f,
    shadow: 1,
    highlight: 0.4,
    outlineWidth: 1,
  );
  shadedPath(canvas, pelt, HeroColors.pelt, f, shadow: 4, highlight: 1.5);
  // Nếp da rủ dọc tấm áo choàng.
  canvas.save();
  canvas.clipPath(pelt);
  for (final x in const [-14.0, -9.0]) {
    canvas.drawPath(
      taperedStroke(
        [
          Offset(x + 4, -len * 0.8),
          Offset(x, -len * 0.3),
          Offset(x + w1 * 0.4, 4),
        ],
        1.6,
        peak: 0.6,
      ),
      fillPaint(darken(HeroColors.pelt, 0.32).withValues(alpha: 0.7)),
    );
  }
  canvas.restore();
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
  // Rủ theo trọng lực: trục lọn hướng xuống đất trong hệ cục bộ của đầu.
  final angle = math.atan2(down.dy, down.dx);
  void locks(
    Offset center,
    double length,
    double width,
    int count,
    double spread,
  ) {
    final set = buildLocks(
      center: center,
      rnd: math.Random(look.hairStyle.index * 13 + 5),
      r0: 0,
      length: length,
      width: width,
      count: count,
      from: angle - spread,
      to: angle + spread,
      drift: Offset(-0.08, 0.02) + down * 0.08,
      wave: 2.5,
    );
    shadedPath(
      canvas,
      set.mass,
      hair,
      f,
      shadow: 2.5,
      highlight: 1.2,
      outlineWidth: 1.2,
    );
    canvas.save();
    canvas.clipPath(set.mass);
    canvas.drawPath(
      set.creases,
      fillPaint(darken(hair, 0.42).withValues(alpha: 0.85)),
    );
    canvas.drawPath(
      set.sheens,
      fillPaint(lighten(hair, 0.38).withValues(alpha: 0.8)),
    );
    canvas.restore();
  }

  switch (look.hairStyle) {
    case HairStyle.ponytail:
      const root = Offset(-14, -6);
      // Đuôi ngựa: chùm lọn gom ở dây buộc, xoè nhẹ rồi thon ở ngọn.
      locks(root, 24, 5.2, 5, 0.22);
      // Dây buộc tóc.
      canvas.drawCircle(root, 2.8, fillPaint(HeroColors.outline));
      canvas.drawCircle(root, 2.2, fillPaint(HeroColors.headband));
    case HairStyle.long:
      // Tóc dài: lọn rủ từ sau đầu xuống quá vai.
      locks(const Offset(-6, -4), 32, 7, 7, 0.32);
    case HairStyle.curly || HairStyle.buzz || HairStyle.bun:
      break;
  }
}

/// Đầu, vẽ trong hệ cục bộ gốc ở tâm đầu, mặt hướng +x.
/// Đầu vẽ sẵn thành Picture theo (ngoại hình, mũ, góc nghiêng làm tròn 5°,
/// mức gắng sức làm tròn 1/4, cười): mỗi khung chỉ vẽ lại hình đã có thay
/// vì dựng lại hàng chục Path tóc, mặt, mắt. Góc làm tròn nên hướng sáng
/// lệch tối đa 2,5° — không nhận ra.
final _headCache = PictureCache<String>(maxEntries: 160);

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
  final picture = _headCache.get(key, (c) {
    c
      ..rotate(angle)
      ..scale(_headScale);
    _head(c, look, PartFrame(angle), cloak: cloak, effort: e, joy: j);
  });
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
  // Mặt dưới gờ mày khuất (hốc mắt) và bóng dưới gò má xuống góc hàm.
  canvas.drawPath(
    taperedStroke(
      const [Offset(4, -4.6), Offset(9, -5.4), Offset(13.5, -4)],
      2.2,
      peak: 0.4,
    ),
    fillPaint(coreShadeOf(look.skin).withValues(alpha: 0.3)),
  );
  canvas.drawPath(
    taperedStroke(
      [const Offset(5, 6), Offset(4, 10 + c * 0.3), Offset(0, 13 + c * 0.5)],
      2.4,
      peak: 0.4,
    ),
    fillPaint(coreShadeOf(look.skin).withValues(alpha: 0.22)),
  );
  // Nếp mũi–má (rãnh nhân trung bên) khi gắng sức hoặc cười.
  if (effort > 0.4 || joy > 0.5) {
    canvas.drawPath(
      taperedStroke(
        const [Offset(12.8, 4.2), Offset(11.2, 6.6), Offset(11, 8.6)],
        0.9,
        peak: 0.3,
      ),
      fillPaint(darken(look.skin, 0.32)),
    );
  }
  // Đường hàm dưới (ánh phản xạ lạnh viền dưới cằm).
  canvas.drawPath(
    taperedStroke(
      [Offset(13, 12), Offset(9, 15.6 + c * 0.5), Offset(2, 15 + c * 0.6)],
      1.2,
      peak: 0.5,
    ),
    fillPaint(lighten(look.skin, 0.18).withValues(alpha: 0.6)),
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
  // Ửng đỏ trên gò má: nhạt khi nghỉ, đậm dần khi gắng sức (máu dồn lên
  // mặt) — không phải chấm má hồng cố định kiểu hoạt hình thiếu nhi.
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(8, 4.6 + cheeks * 0.5),
      width: 7,
      height: 3.2,
    ),
    Paint()
      ..shader = Gradient.radial(Offset(8, 4.6 + cheeks * 0.5), 3.5, [
        HeroColors.blush.withValues(alpha: 0.12 + effort * 0.3),
        HeroColors.blush.withValues(alpha: 0),
      ]),
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
  // Lông mày nét thon: đậm ở đầu mày (phía mũi), mảnh dần ra đuôi.
  canvas.drawPath(
    taperedStroke(
      [
        eye + Offset(-4.2, -6.3 - effort * 1.5),
        eye + Offset(0, -7.2 + effort * 0.2),
        eye + Offset(4.2, -5 + effort * 2.2),
      ],
      look.female ? 1.7 : 2.5,
      peak: 0.25,
      startWidth: 0.35,
      endWidth: 0.6,
    ),
    fillPaint(darken(hair, 0.1)),
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
    canvas.drawRRect(teeth, fillPaint(const Color(0xFFF4EEE4)));
    canvas.save();
    canvas.clipRRect(teeth);
    // Răng xa (phía má) chìm trong bóng; khe răng thon, mờ dần.
    canvas.drawRect(
      Rect.fromLTRB(8.6, mouthY - 1.6, 10, mouthY + 1.8),
      fillPaint(const Color(0x55402820)),
    );
    final gap = fillPaint(darken(look.skin, 0.45).withValues(alpha: 0.7));
    canvas.drawPath(
      taperedStroke(
        [Offset(8.8, mouthY + 0.15), Offset(14, mouthY)],
        0.7,
        peak: 0.5,
      ),
      gap,
    );
    for (final x in [10.3, 11.9, 13.2]) {
      canvas.drawPath(
        taperedStroke(
          [Offset(x, mouthY - 1.5), Offset(x + 0.1, mouthY + 1.7)],
          0.55,
          peak: 0.5,
        ),
        gap,
      );
    }
    canvas.restore();
    // Môi kéo căng hai bên khi nghiến.
    canvas.drawPath(
      taperedStroke(
        [
          Offset(8.2, mouthY + 2.4),
          Offset(11.4, mouthY + 2.8),
          Offset(14.4, mouthY + 2.2),
        ],
        1,
        peak: 0.5,
      ),
      fillPaint(darken(look.skin, 0.3)),
    );
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
      // Tóc chải mượt ra sau, mái lệch: khối tóc + các sợi chảy từ đường
      // ngôi ra sau gáy (rãnh tối + sợi sáng), vệt bóng tóc rộng.
      final sleek = Path()
        ..moveTo(-15, 2)
        ..cubicTo(-18, -16, 2, -22, 13, -9)
        ..quadraticBezierTo(4, -11, -2, -6)
        ..quadraticBezierTo(-9, -3, -15, 2)
        ..close();
      shadedPath(canvas, sleek, hair, f, shadow: 2.5, highlight: 1.2);
      canvas.save();
      canvas.clipPath(sleek);
      final strandDark = Paint()..color = darken(hair, 0.4);
      final strandLit = Paint()
        ..color = lighten(hair, 0.32).withValues(alpha: 0.8);
      for (var i = 0; i < 6; i++) {
        final k = i / 5;
        // Từ trán (phải) chải vòng ra sau gáy (trái–dưới).
        final pts = [
          Offset(11 - k * 4, -10 - k * 4),
          Offset(2 - k * 2, -15 + k * 3),
          Offset(-8 - k, -12 + k * 6),
          Offset(-14 + k, -2 + k * 4),
        ];
        canvas.drawPath(
          taperedStroke(pts, 1.1, peak: 0.4, samples: 10),
          strandDark,
        );
        if (i.isEven) {
          canvas.drawPath(
            taperedStroke(
              [for (final p in pts.take(3)) p + const Offset(0.5, -1)],
              0.8,
              peak: 0.4,
              samples: 8,
            ),
            strandLit,
          );
        }
      }
      canvas.drawPath(
        taperedStroke(
          const [Offset(-9, -13), Offset(-1, -16.5), Offset(6, -14)],
          2.4,
          peak: 0.45,
        ),
        Paint()..color = lighten(hair, 0.45).withValues(alpha: 0.8),
      );
      canvas.restore();
      if (look.hairStyle == HairStyle.bun) {
        const bc = Offset(-13, -13);
        final bun = Path()..addOval(Rect.fromCircle(center: bc, radius: 6.5));
        shadedPath(canvas, bun, hair, f, shadow: 2, highlight: 1.2);
        // Búi Hy Lạp: tóc quấn vòng xoắn ốc quanh búi.
        canvas.save();
        canvas.clipPath(bun);
        for (var i = 0; i < 3; i++) {
          final r0 = 2.0 + i * 1.6;
          canvas.drawArc(
            Rect.fromCircle(center: bc + Offset(0.4 * i, -0.3 * i), radius: r0),
            0.6 + i,
            4.2,
            false,
            Paint()
              ..color = darken(hair, 0.4)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.9,
          );
        }
        canvas.drawArc(
          Rect.fromCircle(center: bc, radius: 4.6),
          3.6,
          1.3,
          false,
          Paint()
            ..color = lighten(hair, 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        canvas.restore();
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
  // Bờm hai lớp bằng lọn lông chảy ra sau gáy và rủ xuống (cùng kiểu bờm
  // Sư tử Nemea — vector_texture), lớp sau sẫm, lớp trước sáng.
  final rnd = math.Random(19);
  for (final (r0, len, w, color, count) in [
    (10.0, 17.0, 6.0, darken(HeroColors.mane, 0.25), 11),
    (8.5, 12.0, 5.2, HeroColors.mane, 10),
  ]) {
    final locks = buildLocks(
      center: const Offset(-4, -1),
      rnd: rnd,
      r0: r0,
      length: len,
      width: w,
      count: count,
      from: math.pi * 0.7,
      to: math.pi * 1.62,
      drift: const Offset(-0.6, 0.42),
      wave: 2.5,
    );
    shadedPath(
      canvas,
      locks.mass,
      color,
      f,
      shadow: 2.2,
      highlight: 1,
      outlineWidth: 1.1,
    );
    canvas.save();
    canvas.clipPath(locks.mass);
    canvas.drawPath(
      locks.creases,
      fillPaint(darken(color, 0.45).withValues(alpha: 0.8)),
    );
    canvas.drawPath(
      locks.sheens,
      fillPaint(lighten(color, 0.38).withValues(alpha: 0.75)),
    );
    canvas.restore();
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
