import 'dart:math' as math;
import 'dart:ui';

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
  canvas.drawOval(
    Rect.fromLTRB(minX, ground - 3, maxX, ground + 3),
    fillPaint(const Color(0x40000000)),
  );

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
  );

  if (cloak) withFrame(canvas, hip, up, (f) => _peltBack(canvas, torsoLen, f));
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
  withFrame(canvas, head, headUp, (f) {
    canvas.scale(_headScale);
    _head(canvas, look, f, cloak: cloak, effort: effort, joy: joy);
  });

  _arm(canvas, look, shoulder, pose[HeroJoint.elbow], pose[HeroJoint.wrist]);
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
}) {
  final k = _limb(look);
  final skin = far ? darken(look.skin, 0.18) : look.skin;
  shadedChain(
    canvas,
    [
      (shoulder, elbow, 6.2 * k, 5.6 * k),
      (elbow, wrist, 6.4 * k, 5.2 * k),
      (wrist, wrist, 6.8, 6.8),
    ],
    skin,
    highlight: far ? 0 : 1.4,
  );
  if (!far) {
    // Đường cơ (sel-line màu da sẫm): bắp tay, cơ cẳng tay.
    _muscle(canvas, shoulder, elbow, 0.2, 0.85, 3.2 * k, 1.6, look.skin);
    _muscle(canvas, elbow, wrist, 0.08, 0.5, -3 * k, 1.4, look.skin);
  }
  // Vòng tay vàng ánh kim gần cổ tay.
  final band = capsulePath(
    Offset.lerp(elbow, wrist, 0.72)!,
    Offset.lerp(elbow, wrist, 0.84)!,
    5.2 * k,
    4.9 * k,
  );
  canvas.drawPath(
    band,
    Paint()
      ..color = HeroColors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4,
  );
  canvas.drawPath(band, goldPaint(band.getBounds()));
  glint(canvas, Offset.lerp(elbow, wrist, 0.76)! + const Offset(-1.5, -2), 1.6);
  // Khớp ngón tay trên nắm đấm.
  final knuckle = Paint()
    ..color = darken(far ? darken(look.skin, 0.18) : look.skin, 0.35)
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.round;
  final dir = (wrist - elbow) / (wrist - elbow).distance;
  final side = Offset(-dir.dy, dir.dx);
  for (final t in [-2.4, 0.0, 2.4]) {
    final p = wrist + dir * 3.5 + side * t;
    canvas.drawLine(p, p + dir * 2, knuckle);
  }
}

/// Đường viền khối cơ dọc đoạn [a]→[b] (từ tỉ lệ [from] tới [to]), lệch
/// sang một bên [offset] và phồng [bulge]: nét màu da sẫm, không dùng đen
/// (sel-line), để tay chân có cơ thay vì ống tròn trơn.
void _muscle(
  Canvas canvas,
  Offset a,
  Offset b,
  double from,
  double to,
  double offset,
  double bulge,
  Color skin,
) {
  final d = b - a;
  if (d.distance < 1) return;
  final n = Offset(-d.dy, d.dx) / d.distance;
  final p0 = Offset.lerp(a, b, from)! + n * offset;
  final p1 = Offset.lerp(a, b, to)! + n * offset;
  final mid = Offset.lerp(p0, p1, 0.5)! + n * bulge * offset.sign;
  canvas.drawPath(
    Path()
      ..moveTo(p0.dx, p0.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, p1.dx, p1.dy),
    Paint()
      ..color = darken(skin, 0.28).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round,
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
  shadedChain(
    canvas,
    [
      (hip, knee, 8 * k * (look.female ? 1.08 : 1), 6.5 * k),
      (knee, ankle, 6.5 * k, 4.5 * k),
    ],
    shade(look.skin),
    highlight: far ? 0 : 1.4,
  );
  if (!far) {
    // Cơ đùi trước, bắp chân sau, xương bánh chè.
    _muscle(canvas, hip, knee, 0.25, 0.85, 3.8 * k, 1.8, look.skin);
    _muscle(canvas, knee, ankle, 0.1, 0.55, -3.2 * k, 1.8, look.skin);
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
  // Dây sandal quấn chéo ống chân.
  final strap = Paint()
    ..color = shade(darken(HeroColors.sandal, 0.1))
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;
  final d = ankle - knee;
  final n = Offset(-d.dy, d.dx) / d.distance;
  for (final t in [0.58, 0.72, 0.86]) {
    final p = Offset.lerp(knee, ankle, t)!;
    canvas.drawLine(p + n * 5.2 * k, p - n * 5.2 * k + d * 0.07, strap);
  }
  shadedChain(
    canvas,
    [(ankle, toe, 5.4, 4.6)],
    shade(HeroColors.sandal),
    shadow: 1.6,
    highlight: 0.8,
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
    ..cubicTo(belly + 3, -len * 0.45, belly + 3, -len * 0.04, hipFront, 2)
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
  canvas.drawPath(
    Path()
      ..moveTo(-2, -len * 0.35)
      ..quadraticBezierTo(2, -len * 0.2, 0, -10)
      ..moveTo(5, -len * 0.3)
      ..quadraticBezierTo(7, -len * 0.18, 6, -11),
    fold,
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
  // Nếp gấp váy.
  canvas.drawLine(
    Offset(-2, -4),
    Offset(-3 - flare * 0.5, hem - 5),
    fold..strokeWidth = 1,
  );
  canvas.drawLine(Offset(5, -4), Offset(6 + flare * 0.5, hem - 5), fold);
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
void _peltBack(Canvas canvas, double len, PartFrame f) {
  final pelt = Path()
    ..moveTo(-6, -len - 6)
    ..cubicTo(-20, -len * 0.75, -22, -len * 0.3, -17, 8)
    // Mép dưới răng cưa như lông thú.
    ..lineTo(-12, 4)
    ..lineTo(-9, 11)
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
      for (final c in const [
        Offset(-13, -2),
        Offset(-10, -9),
        Offset(-4, -13),
        Offset(3, -13.5),
        Offset(9, -10.5),
      ]) {
        shadedPath(
          canvas,
          Path()..addOval(Rect.fromCircle(center: c, radius: 5)),
          hair,
          f,
          shadow: 1.8,
          highlight: 1.2,
          outlineWidth: 1,
        );
      }
      glint(canvas, const Offset(-5, -15), 2.2);
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
  // Băng đô đỏ, đuôi bay phía sau.
  final band = Paint()
    ..color = HeroColors.headband
    ..strokeWidth = 3.4
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  canvas.drawArc(
    Rect.fromCircle(center: const Offset(-1, 0), radius: r),
    -math.pi * 0.95,
    math.pi * 0.72,
    false,
    band,
  );
  canvas.drawPath(
    Path()
      ..moveTo(-14, -5)
      ..quadraticBezierTo(-21, -6, -25, -1)
      ..moveTo(-14, -5)
      ..quadraticBezierTo(-20, -2, -22, 4),
    band..strokeWidth = 2.6,
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
