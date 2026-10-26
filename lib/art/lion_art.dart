import 'dart:math' as math;
import 'dart:ui';

import 'sprite_atlas.dart';
import 'vector_style.dart';

/// Bảng màu Sư tử Nemea: da vàng ánh kim (không vũ khí nào xuyên thủng),
/// bờm đỏ sẫm ngả đen ở ngọn như tranh cổ, mắt hổ phách rực.
abstract final class LionColors {
  static const outline = Color(0xFF241510);
  static const body = Color(0xFFC99140);
  static const bodyShade = Color(0xFF94652A);
  static const belly = Color(0xFFE2C08A);
  static const mane = Color(0xFF5E2210);
  static const maneMid = Color(0xFF8E3714);
  static const maneLight = Color(0xFFC0611E);
  static const nose = Color(0xFF3A1E14);
  static const mouth = Color(0xFF5C0F12);
  static const tongue = Color(0xFFB0383C);
  static const fang = Color(0xFFFFF6DE);
  static const scar = Color(0xFF8A4A2A);
}

/// Các thông số hoạt hình của sư tử tại một khung hình.
class LionState {
  const LionState({
    this.time = 0,
    this.mouth = 0,
    this.attackPhase = -1,
    this.hurt = 0,
    this.glint = -1,
    this.defeat = 0,
    this.pounce = false,
    this.wrestled = -1,
  });

  /// Giây trôi qua, cho các chuyển động lặp (thở, đuôi, chớp mắt).
  final double time;

  /// Há miệng 0–1 (gầm) khi không có [attackPhase].
  final double mouth;

  /// Tiến độ đòn vồ 0–1 (lấy đà, vồ, thu về); âm = không tấn công.
  final double attackPhase;

  /// Vừa trúng đòn 0–1: giật lùi, co người, loé trắng.
  final double hurt;

  /// Đòn bị bộ da chặn 0–1: khiên lục giác vàng loé lên; âm = không có.
  final double glint;

  /// Gục ngã 0–1.
  final double defeat;

  /// Pha 2: đòn là cú nhảy vồ ([attackPhase] dùng động tác `pounce`).
  final bool pounce;

  /// Bị người chơi vật 0–1 (chồm ngửa ra sau); âm = không.
  final double wrestled;
}

Paint _fill(Color c) => Paint()..color = c;

double _smooth(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// Mảng có viền + đổ bóng hai tông như nhân vật.
void _shaded(
  Canvas canvas,
  Path path,
  Color c, {
  double shadow = 4,
  double width = 2,
}) => shadedPath(
  canvas,
  path,
  c,
  PartFrame.world,
  shadow: shadow,
  highlight: 1.8,
  outlineWidth: width,
);

/// Vẽ Sư tử Nemea mặt quay sang trái; gốc toạ độ ở mặt đất, giữa thân.
/// Kích thước khoảng 210×150.
void paintLion(Canvas canvas, LionState s) {
  final t = s.time;
  final breath = math.sin(t * 2.2) * 0.5 + 0.5;
  final fall = _smooth(s.defeat);

  // Đòn vồ: lấy đà (lùi, hạ thấp) rồi lao tới vung vuốt.
  var windup = 0.0, strike = 0.0;
  final p = s.attackPhase;
  if (p >= 0) {
    windup = p < 0.4
        ? _smooth(p / 0.4)
        : p < 0.55
        ? 1 - _smooth((p - 0.4) / 0.15)
        : 0;
    strike = p < 0.4
        ? 0
        : p < 0.55
        ? _smooth((p - 0.4) / 0.15)
        : 1 - _smooth((p - 0.55) / 0.45);
  }
  final roar = math.max(s.mouth, math.max(strike, windup * 0.4));

  // Bóng tiếp đất (không đi theo thân).
  // Bóng đổ tím lạnh ngả về phía xa nắng + bóng tiếp xúc dưới bàn chân.
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(16 - 10 * strike, 3),
      width: 230 - 20 * windup,
      height: 18,
    ),
    _fill(const Color(0x30402A50)),
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(4 - 10 * strike, 2),
      width: 200 - 20 * windup,
      height: 12,
    ),
    _fill(const Color(0x40301C30)),
  );
  for (final x in [-62.0, -44.0, 56.0, 72.0]) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x - 4, 1), width: 30, height: 5),
      _fill(const Color(0x55201018)),
    );
  }

  // Báo trước đòn vồ: chân sau cào đất, bụi tung (vẽ sau lưng thân).
  if (windup > 0.05) _pawDust(canvas, t, windup);

  canvas.save();
  // Gục nằm rạp: không để bờm/đầu lòi xuống dưới mặt đất.
  if (fall > 0) canvas.clipRect(const Rect.fromLTRB(-400, -400, 400, 4));
  // Rung gầm gừ khi lấy đà (báo hiệu đọc được trước đòn).
  final growl = windup * math.sin(t * 60) * 1.2;
  canvas.translate(
    10 * s.hurt + 10 * windup - 18 * strike + 10 * fall + growl,
    0,
  );
  // Trúng đòn: co người lại.
  canvas.scale(1 + 0.04 * s.hurt, 1 - 0.05 * s.hurt);

  final tint = s.hurt > 0
      ? Color.fromRGBO(255, 255, 255, 0.7 * s.hurt)
      : fall > 0
      ? Color.fromRGBO(60, 50, 64, 0.45 * fall)
      : null;
  if (tint != null) {
    canvas.saveLayer(
      const Rect.fromLTRB(-200, -220, 160, 30),
      Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.srcATop),
    );
  }

  _legsStatic = windup == 0 && strike == 0 && fall == 0;
  // Thân hạ thấp khi lấy đà, gục thì nằm rạp.
  final drop = 6 * windup + 34 * fall;
  final lift = breath * 1.5;
  final far = Color.lerp(LionColors.body, LionColors.outline, 0.3)!;

  // Chân xa.
  _leg(
    canvas,
    hip: Offset(-30, -84 + drop),
    paw: Offset(-44 + 8 * windup - 30 * fall, 0),
    color: far,
    front: true,
  );
  _leg(
    canvas,
    hip: Offset(66, -86 + drop),
    paw: Offset(56 + 12 * fall, 0),
    color: far,
    front: false,
  );

  _tail(canvas, t, fall, drop, strike);
  // Chân sau gần vẽ trước thân: đùi liền vào khối mông (khối cơ đùi đã
  // có trong ảnh thân), chỉ phần cẳng – khoeo – bàn lộ ra dưới bụng.
  _leg(
    canvas,
    hip: Offset(78, -82 + drop),
    paw: Offset(72 + 8 * fall, 0),
    color: LionColors.body,
    front: false,
  );

  // Thân chụp sẵn thành ảnh, chỉ dịch lên xuống (lấy đà, thở, gục).
  canvas.save();
  canvas.translate(0, drop - lift);
  _bodyImage.paint(canvas);
  _hideSheen(canvas, t);
  canvas.restore();

  // Chân gần: chân trước vung vuốt khi vồ.
  final swipe = strike * (1 - fall);
  final pawGround = Offset(-62 + 10 * windup - 36 * fall, 0);
  const pawSwipe = Offset(-128, -44);
  final paw = Offset.lerp(pawGround, pawSwipe, swipe)!;
  void frontLeg() => _leg(
    canvas,
    hip: Offset(-46, -80 + drop),
    paw: paw,
    color: LionColors.body,
    front: true,
    clawsOut: swipe > 0.2 || windup > 0.6,
  );
  // Đứng yên: chân trước sau bờm. Vồ: chân vung ra trước cả đầu.
  if (swipe <= 0.15) frontLeg();

  final head = Offset(
    -74 - 16 * strike + 4 * windup - 10 * fall,
    // Gục: đầu rũ xuống sát đất.
    -104 + drop + 26 * fall + 10 * windup - lift + math.sin(t * 1.1) * 1.2,
  );
  _mane(canvas, head, t, fall);
  canvas.save();
  canvas.translate(head.dx, head.dy);
  canvas.rotate(-0.32 * fall); // mõm chúi xuống
  canvas.scale(1.18);
  _head(canvas, Offset.zero, s, roar, fall, t);
  canvas.restore();
  if (swipe > 0.15) frontLeg();
  if (swipe > 0.25) _clawTrails(canvas, paw, swipe);
  if (roar > 0.5 && fall == 0) _roarWaves(canvas, head, roar, t);

  if (tint != null) canvas.restore();

  if (fall > 0.3) _stagnationLeaving(canvas, t, fall, drop);
  if (s.glint >= 0) _shieldFlash(canvas, head + const Offset(12, 14), s.glint);
  canvas.restore();
}

/// Sư tử bằng sprite Blender (tool/blender/lion_nemea.py, cùng gốc toạ độ
/// và nhịp đòn với [paintLion]): thân, bờm, bóng đổ đã có trong ảnh; ở đây
/// chỉ thêm phần đọc nhịp trận — bụi cào đất khi lấy đà, rung gầm gừ, vệt
/// vuốt, sóng gầm, khiên da loé khi bị chặn, Trì Trệ rời xác khi gục.
/// Điểm [key] (danh sách [x, y] từng khung trong meta atlas) tại tiến độ [p].
Offset? _spriteTrack(SpriteAtlas sprite, String key, double p) {
  final list = sprite.meta[key] as List?;
  if (list == null || list.length < 2) return null;
  Offset at(int i) {
    final t = list[i] as List;
    return Offset((t[0] as num).toDouble(), (t[1] as num).toDouble());
  }

  final pos = p.clamp(0.0, 1.0) * (list.length - 1);
  final i = math.min(pos.floor(), list.length - 2);
  return Offset.lerp(at(i), at(i + 1), pos - i)!;
}

void paintLionSprite(
  Canvas canvas,
  LionState s,
  SpriteAtlas sprite, {
  Color? tint,
}) {
  final t = s.time;
  final fall = _smooth(s.defeat);
  var windup = 0.0, strike = 0.0;
  final p = s.attackPhase;
  if (p >= 0) {
    windup = p < 0.4
        ? _smooth(p / 0.4)
        : p < 0.55
        ? 1 - _smooth((p - 0.4) / 0.15)
        : 0;
    strike = p < 0.4
        ? 0
        : p < 0.55
        ? _smooth((p - 0.4) / 0.15)
        : 1 - _smooth((p - 0.55) / 0.45);
  }
  final roar = math.max(s.mouth, math.max(strike, windup * 0.4));

  if (windup > 0.05) _pawDust(canvas, t, windup);

  canvas.save();
  final growl = windup * math.sin(t * 60) * 1.2;
  canvas.translate(10 * s.hurt + growl, 0);
  // Trúng đòn: co người lại quanh chân.
  canvas.scale(1 + 0.04 * s.hurt, 1 - 0.05 * s.hurt);
  if (s.defeat > 0 && sprite.has('defeat')) {
    sprite.draw(canvas, 'defeat', s.defeat, flash: s.hurt, tint: tint);
  } else if (s.wrestled >= 0 && sprite.has('wrestled')) {
    sprite.draw(canvas, 'wrestled', s.wrestled, flash: s.hurt, tint: tint);
  } else if (p >= 0 && sprite.has(s.pounce ? 'pounce' : 'attack')) {
    // Quanh cú vồ (0,48–0,7) không hoà hai khung kề nhau (chân thành bốn).
    sprite.draw(
      canvas,
      s.pounce ? 'pounce' : 'attack',
      p,
      flash: s.hurt,
      tint: tint,
      snap: p > 0.48 && p < 0.7,
    );
  } else {
    final period = sprite.metaDouble('idlePeriod', 3);
    sprite.draw(
      canvas,
      'idle',
      t / period,
      loop: true,
      flash: s.hurt,
      tint: tint,
    );
  }

  // Vị trí đầu và vuốt: track từng khung ghi trong atlas lúc render
  // (tracks() của tool/blender/lion_tripo.py, độ dời so với dáng chờ); atlas
  // cũ không có thì theo công thức của pose() trong lion_nemea.py.
  final shift = 10 * windup - 18 * strike + 10 * fall;
  final drop = 6 * windup + 34 * fall;
  final attacking = p >= 0 && fall == 0 && s.wrestled < 0;
  final headMove = attacking
      ? _spriteTrack(sprite, s.pounce ? 'headPounce' : 'headAttack', p)
      : null;
  final head = headMove != null
      ? const Offset(-74, -95) + headMove
      : Offset(-74 + shift - 16 * strike, -104 + drop + 26 * fall + 9);
  final swipe = strike * (1 - fall);
  if (swipe > 0.25 && !s.pounce) {
    final pawMove = attacking ? _spriteTrack(sprite, 'pawAttack', p) : null;
    final ground = Offset(-62 + 10 * windup - 36 * fall, 0);
    _clawTrails(
      canvas,
      pawMove != null
          ? const Offset(-62, 0) + pawMove
          : Offset.lerp(ground, const Offset(-120, -56), swipe)!,
      swipe,
    );
  }
  if (roar > 0.5 && fall == 0) _roarWaves(canvas, head, roar, t);
  if (fall > 0.3) _stagnationLeaving(canvas, t, fall, drop);
  if (s.glint >= 0) _shieldFlash(canvas, head + const Offset(12, 14), s.glint);
  canvas.restore();
}

/// Dáng thân mèo lớn nhìn ngang: u vai (bả vai nhô), lõm sau vai, lưng
/// võng nhẹ rồi nhô ở thắt lưng – mông, đùi sau to, eo thóp trước đùi, da
/// bụng chùng, ngực sâu.
Path _bodyPath() => Path()
  ..moveTo(-62, -112)
  ..cubicTo(-50, -120, -36, -120, -26, -114)
  ..cubicTo(-14, -108, 0, -104, 14, -105)
  ..cubicTo(36, -107, 56, -114, 76, -112)
  ..cubicTo(94, -110, 102, -96, 100, -80)
  ..cubicTo(98, -62, 90, -52, 76, -52)
  ..cubicTo(64, -52, 56, -58, 46, -60)
  ..cubicTo(30, -58, 14, -50, -4, -50)
  ..cubicTo(-24, -50, -44, -50, -58, -54)
  ..cubicTo(-72, -60, -78, -80, -74, -96)
  ..cubicTo(-72, -106, -68, -110, -62, -112)
  ..close();

final _bodyShape = _bodyPath();

final _bodyImage = RasterLayer(
  _paintBody,
  bounds: const Rect.fromLTRB(-84, -128, 108, -34),
  resolution: 1.5,
);

/// Khối cơ dưới da tô sáng–tối mềm (blur chỉ tốn một lần khi chụp ảnh):
/// bả vai đón nắng, rãnh sau vai, xương sườn lộ, eo thóp, vòm đùi sau có
/// bóng lõi phía trước-dưới; bụng sáng, ánh kim dọc sống lưng.
void _paintBody(Canvas canvas) {
  final body = _bodyShape;
  _shaded(canvas, body, LionColors.body, shadow: 6);
  canvas.save();
  canvas.clipPath(body);
  Paint soft(Color c, double blur) => Paint()
    ..color = c
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
  Paint line(Color c, double width, double blur) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
  const shade = LionColors.bodyShade;
  final lit = lighten(LionColors.body, 0.28);
  // Bụng sáng màu, mép dưới da chùng khuất tối.
  canvas.drawPath(
    Path()
      ..moveTo(-80, -64)
      ..cubicTo(-40, -67, 10, -66, 50, -61)
      ..lineTo(50, -40)
      ..lineTo(-80, -40)
      ..close(),
    soft(LionColors.belly, 3),
  );
  canvas.drawPath(
    Path()
      ..moveTo(-70, -52)
      ..cubicTo(-30, -49, 10, -47, 46, -57)
      ..lineTo(46, -40)
      ..lineTo(-70, -40)
      ..close(),
    soft(shade.withValues(alpha: 0.5), 3),
  );
  // Bả vai: khối sáng nghiêng, rãnh tối phía sau.
  canvas.save();
  canvas.translate(-42, -94);
  canvas.rotate(0.35);
  canvas.drawOval(
    Rect.fromCenter(center: Offset.zero, width: 30, height: 46),
    soft(lit.withValues(alpha: 0.6), 4),
  );
  canvas.restore();
  canvas.drawPath(
    Path()
      ..moveTo(-24, -112)
      ..quadraticBezierTo(-12, -92, -22, -66),
    line(shade.withValues(alpha: 0.65), 5, 2.5),
  );
  // Xương sườn lộ dưới da: dải tối – sáng xen kẽ.
  for (var i = 0; i < 4; i++) {
    final x = -6.0 + i * 11;
    final rib = Path()
      ..moveTo(x, -100)
      ..quadraticBezierTo(x + 8, -84, x + 2, -64);
    canvas.drawPath(rib, line(shade.withValues(alpha: 0.35), 3, 1.5));
    canvas.drawPath(
      rib.shift(const Offset(-3.5, 0)),
      line(lit.withValues(alpha: 0.35), 2, 1.2),
    );
  }
  // Eo thóp trước đùi sau.
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(46, -72), width: 22, height: 34),
    soft(shade.withValues(alpha: 0.6), 5),
  );
  // Vòm đùi sau đón nắng, bóng lõi viền trước – dưới.
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(78, -92), width: 40, height: 32),
    soft(lit.withValues(alpha: 0.6), 5),
  );
  canvas.drawArc(
    Rect.fromCenter(center: const Offset(74, -80), width: 50, height: 50),
    1.7,
    1.9,
    false,
    line(shade.withValues(alpha: 0.75), 4, 2),
  );
  // Ánh kim chạy dọc sống lưng: da cứng như giáp.
  canvas.drawPath(
    Path()
      ..moveTo(-50, -116)
      ..cubicTo(-36, -120, -26, -114, -18, -110)
      ..cubicTo(0, -103, 20, -106, 40, -108)
      ..cubicTo(60, -113, 84, -112, 96, -96),
    line(const Color(0xAAFFF0B0), 3, 1),
  );
  // Trường lông ngắn theo hướng mọc: xuôi từ vai về đuôi, rủ dần xuống
  // bụng, vòng theo vòm đùi sau; nét tối + nét sáng so le (chụp sẵn nên
  // dày bao nhiêu cũng không tốn khung hình).
  final furDark = Path();
  final furLit = Path();
  final rnd = math.Random(9);
  for (var y = -116.0; y < -44; y += 4.2) {
    for (var x = -70.0; x < 104; x += 5 + rnd.nextDouble() * 2) {
      final p = Offset(x + rnd.nextDouble() * 2, y + rnd.nextDouble() * 2.4);
      // Hướng: ra sau, xuống dần theo độ sâu thân; quanh đùi sau xoay
      // theo tiếp tuyến vòm đùi.
      var dir = Offset(1, 0.15 + (p.dy + 116) / 72 * 0.9);
      final toHip = p - const Offset(78, -88);
      final dh = toHip.distance;
      if (dh < 30) {
        final tangent = Offset(-toHip.dy, toHip.dx) / dh;
        final k = 1 - dh / 30;
        dir = dir * (1 - k) + (tangent.dy < 0 ? -tangent : tangent) * k;
      }
      final u = dir / dir.distance;
      final len = 3.2 + rnd.nextDouble() * 2.6;
      final n = Offset(-u.dy, u.dx);
      furDark
        ..moveTo(p.dx, p.dy)
        ..quadraticBezierTo(
          p.dx + u.dx * len * 0.5 + n.dx * 0.6,
          p.dy + u.dy * len * 0.5 + n.dy * 0.6,
          p.dx + u.dx * len,
          p.dy + u.dy * len,
        );
      if (rnd.nextDouble() < 0.45) {
        final q = p - n * 1.2;
        furLit
          ..moveTo(q.dx, q.dy)
          ..lineTo(q.dx + u.dx * len * 0.6, q.dy + u.dy * len * 0.6);
      }
    }
  }
  canvas.drawPath(
    furDark,
    Paint()
      ..color = LionColors.bodyShade.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawPath(
    furLit,
    Paint()
      ..color = lit.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round,
  );
  // Sẹo cũ trên hông: dấu những kẻ đã thử và thất bại.
  final scar = Paint()
    ..color = LionColors.scar
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 3; i++) {
    canvas.drawLine(Offset(20 + i * 6, -96), Offset(12 + i * 6, -80), scar);
  }
  canvas.restore();
}

/// Vệt sáng lấp loá chạy chậm qua da (nhắc rằng da bất khả xâm).
void _hideSheen(Canvas canvas, double t) {
  final sweep = (t * 0.35) % 1.6 - 0.3;
  if (sweep < -0.2 || sweep > 1.2) return;
  final x = -80 + 190 * sweep;
  canvas.save();
  canvas.clipPath(_bodyShape);
  canvas.drawPath(
    Path()
      ..moveTo(x, -130)
      ..lineTo(x + 10, -130)
      ..lineTo(x - 14, -40)
      ..lineTo(x - 24, -40)
      ..close(),
    _fill(const Color(0x40FFF8D8)),
  );
  canvas.restore();
}

/// Chân ba khúc (vai/hông, khuỷu/cổ chân, bàn) bằng chuỗi viên thuốc.
/// Chân đứng yên (sư tử rình, không lấy đà/vồ/gục) chụp thành ảnh: bó cơ
/// của chân tốn GPU nhiều (mỗi bó một lần clip) mà tư thế không đổi.
final _legImages = <(Offset, Offset, int, bool, bool), RasterLayer>{};

/// Sư tử đang đứng yên: chân có thể dùng ảnh chụp sẵn.
bool _legsStatic = false;

void _leg(
  Canvas canvas, {
  required Offset hip,
  required Offset paw,
  required Color color,
  required bool front,
  bool clawsOut = false,
}) {
  if (!_legsStatic) {
    _legVector(
      canvas,
      hip: hip,
      paw: paw,
      color: color,
      front: front,
      clawsOut: clawsOut,
    );
    return;
  }
  final key = (hip, paw, color.toARGB32(), front, clawsOut);
  _legImages
      .putIfAbsent(
        key,
        () => RasterLayer(
          (c) => _legVector(
            c,
            hip: hip,
            paw: paw,
            color: color,
            front: front,
            clawsOut: clawsOut,
          ),
          bounds: Rect.fromPoints(hip, paw).inflate(34),
          resolution: 0.8,
        ),
      )
      .paint(canvas);
}

void _legVector(
  Canvas canvas, {
  required Offset hip,
  required Offset paw,
  required Color color,
  required bool front,
  bool clawsOut = false,
}) {
  final pawTop = paw + const Offset(0, -8);
  final d = pawTop - hip;
  final len = d.distance;
  final n = Offset(-d.dy, d.dx) / (len == 0 ? 1 : len);
  // Chân trước: khuỷu hơi lùi sau. Chân sau: cổ chân gập ngược rõ.
  final mid =
      Offset.lerp(hip, pawTop, front ? 0.55 : 0.6)! + n * (front ? -5 : -14);
  // Giải phẫu mèo lớn: chân trước có khối vai sau dày, khuỷu nhô, cẳng
  // chân phồng phía trước; chân sau đùi + cơ đùi sau khổng lồ, cổ chân (hock)
  // thon và gập ngược.
  shadedLimb(
    canvas,
    [
      (hip, mid, front ? FelineAnatomy.foreUpper : FelineAnatomy.hindUpper),
      (mid, pawTop, front ? FelineAnatomy.foreLower : FelineAnatomy.hindLower),
    ],
    color,
    shadow: 4,
    // Chân sau mèo lớn: cẳng và khoeo dày hơn chân trước.
    scale: front ? 1 : 1.25,
    facing: const Offset(-1, 0),
    // Chân phía xa (màu tối hơn) khuất sau thân: không vẽ bó cơ cho nhẹ.
    definition: color == LionColors.body ? 0.65 : 0,
  );
  // Đường cơ bắp chân (sel-line), gân cổ chân.
  final line = Paint()
    ..color = darken(color, 0.3).withValues(alpha: 0.75)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;
  final m1 = Offset.lerp(hip, mid, 0.3)! + n * (front ? 6 : 9);
  final m2 = Offset.lerp(hip, mid, 0.95)! + n * (front ? 3 : 4);
  canvas.drawPath(
    Path()
      ..moveTo(m1.dx, m1.dy)
      ..quadraticBezierTo(
        (m1.dx + m2.dx) / 2 + n.dx * 4,
        (m1.dy + m2.dy) / 2 + n.dy * 4,
        m2.dx,
        m2.dy,
      ),
    line,
  );
  final t1 = Offset.lerp(mid, pawTop, 0.25)! - n * 3;
  final t2 = Offset.lerp(mid, pawTop, 0.8)! - n * 2.5;
  canvas.drawLine(t1, t2, line);
  _paw(canvas, paw, color, clawsOut: clawsOut);
}

/// Bàn chân mèo lớn nhìn ngang: đệm gót sau, ba ngón tròn nổi so le (ngón
/// trước thấp nhất), khe giữa các ngón, vuốt cong thò ra từ đầu ngón.
void _paw(Canvas canvas, Offset paw, Color color, {required bool clawsOut}) {
  canvas.save();
  canvas.translate(paw.dx, paw.dy);
  _pawImages
      .putIfAbsent(
        (color, clawsOut),
        () => RasterLayer(
          (c) => _paintPaw(c, color, clawsOut: clawsOut),
          bounds: const Rect.fromLTRB(-30, -17, 14, 6),
          resolution: 1.5,
        ),
      )
      .paint(canvas);
  canvas.restore();
}

/// Mỗi màu chân × thò/thu móng chụp sẵn một ảnh.
final _pawImages = <(Color, bool), RasterLayer>{};

void _paintPaw(Canvas canvas, Color color, {required bool clawsOut}) {
  // Móng: thò dài và cong khi vồ, chỉ nhú ra khi đứng (vẽ trước để ngón
  // che gốc móng).
  final claw = _fill(LionColors.fang);
  final clawLine = Paint()
    ..color = LionColors.outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;
  final reach = clawsOut ? 8.0 : 2.5;
  for (final (x, y) in [(-17.0, -3.0), (-11.5, -5.0), (-5.5, -6.5)]) {
    final path = Path()
      ..moveTo(x + 2, y - 2)
      ..quadraticBezierTo(x - reach * 0.8, y - 1.5, x - reach, y + reach * 0.6)
      ..quadraticBezierTo(x - reach * 0.3, y + 0.5, x + 2, y + 1)
      ..close();
    canvas.drawPath(path, claw);
    canvas.drawPath(path, clawLine);
  }
  final shape = smoothPath(
    const [
      Offset(8, -13),
      Offset(11, -6),
      Offset(8, -0.5),
      Offset(-4, 0.6),
      Offset(-15, 0),
      Offset(-19, -3),
      Offset(-16.5, -7.5),
      Offset(-12.5, -6.8),
      Offset(-10, -10),
      Offset(-6.2, -9.2),
      Offset(-3, -11.5),
      Offset(3, -13),
    ],
    closed: true,
    tension: 0.15,
  );
  _shaded(canvas, shape, color, shadow: 3, width: 1.8);
  // Khe giữa các ngón: nét thon từ mép trên xuống, mờ dần.
  final gap = Paint()..color = darken(color, 0.42);
  for (final (top, bottom) in [
    (const Offset(-12.6, -6.6), const Offset(-12, -2.2)),
    (const Offset(-6.3, -9), const Offset(-5.8, -3.6)),
  ]) {
    canvas.drawPath(taperedStroke([top, bottom], 1.5, peak: 0.2), gap);
  }
  // Sáng trên lưng từng ngón, nếp gót.
  final lit = Paint()..color = lighten(color, 0.35).withValues(alpha: 0.8);
  for (final c in const [
    Offset(-15.5, -6),
    Offset(-9.5, -8.6),
    Offset(-3, -10.4),
  ]) {
    canvas.drawPath(
      taperedStroke([
        c + const Offset(-1.6, 0.6),
        c,
        c + const Offset(1.8, 0.2),
      ], 1.1),
      lit,
    );
  }
  canvas.drawPath(
    taperedStroke(const [Offset(7.5, -9), Offset(6, -5), Offset(6.5, -2)], 1.2),
    gap,
  );
}

/// Ba vệt cào sáng theo sau móng vuốt.
void _clawTrails(Canvas canvas, Offset paw, double swipe) {
  final a = ((swipe - 0.25) / 0.75).clamp(0.0, 1.0);
  for (var i = 0; i < 3; i++) {
    final o = Offset(-6.0 * i, 6.0 * i);
    final trail = Path()
      ..moveTo(paw.dx + 40 + o.dx, paw.dy - 30 + o.dy)
      ..quadraticBezierTo(
        paw.dx - 6 + o.dx,
        paw.dy - 20 + o.dy,
        paw.dx - 26 + o.dx,
        paw.dy + 24 + o.dy,
      );
    canvas.drawPath(
      trail,
      Paint()
        ..color = Color.fromRGBO(255, 120, 60, 0.35 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      trail,
      Paint()
        ..color = Color.fromRGBO(255, 244, 214, 0.9 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }
}

void _tail(
  Canvas canvas,
  double time,
  double fall,
  double drop,
  double strike,
) {
  final sway = math.sin(time * 1.6) * 10 * (1 - fall);
  // Đuôi quất mạnh khi vồ.
  final lash = strike * 18;
  final base = Offset(94, -92 + drop);
  final ctrl = Offset(132 + lash * 0.5, -70 + drop + 20 * fall);
  final tip = Offset(122 + sway * 0.4 + lash, -132 + sway - lash + 70 * fall);
  // Đuôi thon dần từ gốc tới ngọn (cơ đuôi dày ở gốc), tô khối.
  Offset q(double u) =>
      base * ((1 - u) * (1 - u)) + ctrl * (2 * u * (1 - u)) + tip * (u * u);
  final tail = taperedStroke(
    [for (var k = 0; k <= 4; k++) q(k / 4)],
    8.5,
    peak: 0,
    startWidth: 1,
    endWidth: 0.55,
    samples: 12,
  );
  _shaded(canvas, tail, LionColors.body, shadow: 2.5, width: 1.8);
  // Chùm lông cuối đuôi: búi lọn sẫm rủ theo hướng đuôi.
  final dir = tip - q(0.9);
  final angle = math.atan2(dir.dy, dir.dx);
  canvas.save();
  canvas.translate(tip.dx, tip.dy);
  canvas.rotate(angle + sway * 0.02);
  _tuftImage.paint(canvas);
  canvas.restore();
}

/// Búi lông đuôi (hướng +x), chụp sẵn; mỗi khung chỉ xoay theo đuôi.
final _tuftImage = RasterLayer(
  (canvas) => _lockLayer(
    canvas,
    Offset.zero,
    math.Random(3),
    1,
    22,
    7,
    LionColors.mane,
    8,
    -0.7,
    0.7,
    outline: 1.4,
  ),
  bounds: const Rect.fromLTRB(-8, -24, 36, 30),
  resolution: 1.5,
);

/// Bờm sư tử thật: hàng trăm lọn lông dày, thon, chảy ra sau gáy rồi rủ
/// xuống ngực theo trọng lực (không toả đều như mặt trời). Ba lớp: lớp
/// sau dài và sẫm (gần đen ở ngọn), lớp giữa nâu đỏ, viền quanh mặt ngắn
/// và sáng. Mỗi lọn có khe tối bên dưới và sợi sáng chạy dọc phía trên.
/// Hình rất nặng nên chụp sẵn thành ảnh; mỗi khung chỉ xoay, phồng nhẹ.
void _mane(Canvas canvas, Offset head, double t, double fall) {
  final c = head + const Offset(14, 4);
  final live = 1 - fall;
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(math.sin(t * 2.6) * 0.035 * live);
  final puff = 1 + math.sin(t * 2.2) * 0.02 * live;
  canvas.scale(puff, puff);
  _maneImage.paint(canvas);
  canvas.restore();
}

final _maneImage = RasterLayer(
  _paintMane,
  bounds: const Rect.fromLTRB(-62, -78, 92, 92),
  resolution: 1.6,
);

void _paintMane(Canvas canvas) {
  final rnd = math.Random(11);
  for (final (r0, len, width, color, count, from, to) in [
    (22.0, 40.0, 13.0, LionColors.mane, 19, -2.45, 2.3),
    (19.0, 31.0, 11.0, LionColors.maneMid, 17, -2.35, 2.15),
    (15.0, 19.0, 8.5, LionColors.maneLight, 15, -2.25, 1.95),
  ]) {
    _lockLayer(
      canvas,
      Offset.zero,
      rnd,
      r0,
      len,
      width,
      color,
      count,
      from,
      to,
    );
  }
}

/// Một lớp lọn lông mọc quanh [center] trong cung góc [from]→[to]
/// (`vector_texture`): khối chung tô đổ bóng, rồi khe tối / sợi lông / sợi
/// sáng trên từng lọn trong vùng cắt khối.
void _lockLayer(
  Canvas canvas,
  Offset center,
  math.Random rnd,
  double r0,
  double len,
  double width,
  Color color,
  int count,
  double from,
  double to, {
  double outline = 1.6,
}) {
  final locks = buildLocks(
    center: center,
    rnd: rnd,
    r0: r0,
    length: len,
    width: width,
    count: count,
    from: from,
    to: to,
    // Đỉnh đầu ngắn, gáy dài, ngực dài nhất (bờm rủ).
    lengthAt: (a) => a < -1.2
        ? 0.75
        : a > 1.0
        ? 1.3
        : 1.0 + 0.15 * math.sin(a),
  );
  _shaded(canvas, locks.mass, color, shadow: 3, width: outline);
  canvas.save();
  canvas.clipPath(locks.mass);
  canvas.drawPath(
    locks.creases,
    Paint()..color = darken(color, 0.5).withValues(alpha: 0.85),
  );
  canvas.drawPath(
    locks.strands,
    Paint()..color = darken(color, 0.28).withValues(alpha: 0.7),
  );
  canvas.drawPath(
    locks.sheens,
    Paint()..color = lighten(color, 0.38).withValues(alpha: 0.75),
  );
  canvas.restore();
}

/// Lông má (ruff) ôm sau mặt, sáng màu, chảy ra sau nối vào bờm: che mép
/// tròn sau gáy để đầu liền với bờm. Tĩnh so với đầu → vẽ sẵn.
final _ruffImage = RasterLayer(
  (canvas) {
    final rnd = math.Random(5);
    _lockLayer(
      canvas,
      const Offset(4, -1),
      rnd,
      12,
      21,
      5.8,
      LionColors.maneLight,
      15,
      -1.95,
      1.75,
      outline: 1,
    );
    _lockLayer(
      canvas,
      const Offset(0, 1),
      rnd,
      10,
      14,
      4.6,
      Color.lerp(LionColors.maneLight, LionColors.body, 0.55)!,
      12,
      -1.6,
      1.6,
      outline: 0.8,
    );
  },
  bounds: const Rect.fromLTRB(-24, -46, 52, 44),
  resolution: 1.8,
);

void _head(
  Canvas canvas,
  Offset c,
  LionState s,
  double roar,
  double fall,
  double t,
) {
  canvas.save();
  canvas.translate(c.dx, c.dy);

  // Hàm dưới xoay mở quanh khớp má.
  const pivot = Offset(-10, 12);
  final open = 0.55 * roar;
  // Lòng miệng (vẽ trước hàm để hàm che mép dưới).
  if (open > 0.03) {
    final mouth = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..lineTo(-40, 12)
      ..lineTo(
        pivot.dx + math.cos(math.pi + open) * 30,
        pivot.dy - math.sin(math.pi + open) * 30,
      )
      ..close();
    canvas.drawPath(mouth, _fill(LionColors.mouth));
    canvas.drawOval(
      Rect.fromCenter(
        center: pivot + Offset(-20, 8 * open / 0.55),
        width: 18,
        height: 6,
      ),
      _fill(LionColors.tongue),
    );
    // Hàng răng cửa nhỏ giữa hai nanh.
    for (var i = 0; i < 4; i++) {
      final x = -33.0 + i * 3;
      canvas.drawPath(
        Path()
          ..moveTo(x, 12.5)
          ..lineTo(x + 2.4, 12.5)
          ..lineTo(x + 1.2, 15.5)
          ..close(),
        _fill(LionColors.fang),
      );
    }
  }
  canvas.save();
  canvas.translate(pivot.dx, pivot.dy);
  canvas.rotate(-open);
  final jaw = Path()
    ..moveTo(2, -2)
    ..cubicTo(-6, 10, -22, 12, -30, 6)
    ..lineTo(-28, 0)
    ..close();
  // Nanh dưới.
  for (final x in [-25.0, -15.0]) {
    canvas.drawPath(
      Path()
        ..moveTo(x, 1)
        ..lineTo(x + 3.5, 1)
        ..lineTo(x + 1.5, -6 - 2 * roar)
        ..close(),
      _fill(LionColors.fang),
    );
  }
  _shaded(canvas, jaw, LionColors.belly, shadow: 2);
  // Chùm râu cằm sẫm.
  canvas.drawPath(
    Path()
      ..moveTo(-8, 8)
      ..quadraticBezierTo(-12, 18, -18, 14)
      ..quadraticBezierTo(-16, 10, -20, 8)
      ..close(),
    _fill(LionColors.maneMid),
  );
  canvas.restore();

  // Hộp sọ: trán gồ, sống mũi dài, má bạnh.
  final skull = Path()
    ..moveTo(12, -20)
    ..cubicTo(-2, -28, -20, -24, -28, -14)
    ..cubicTo(-34, -11, -44, -9, -47, -1)
    ..cubicTo(-48, 6, -45, 12, -38, 13)
    ..lineTo(-12, 15)
    ..cubicTo(2, 22, 14, 18, 18, 6)
    ..cubicTo(22, -4, 20, -14, 12, -20)
    ..close();
  _shaded(canvas, skull, LionColors.body, shadow: 4);
  canvas.save();
  canvas.clipPath(skull);
  // Mõm sáng màu.
  canvas.drawOval(const Rect.fromLTWH(-48, 0, 30, 16), _fill(LionColors.belly));
  // Mặt phẳng (Loomis): sống mũi đón nắng sáng, má dưới mắt khuất tối.
  canvas.drawPath(
    Path()
      ..moveTo(-26, -15)
      ..quadraticBezierTo(-38, -10, -46, -4)
      ..lineTo(-42, -1)
      ..quadraticBezierTo(-34, -7, -22, -11)
      ..close(),
    _fill(lighten(LionColors.body, 0.22)),
  );
  canvas.drawPath(
    Path()
      ..moveTo(-12, -2)
      ..quadraticBezierTo(-6, 6, -10, 14)
      ..lineTo(4, 14)
      ..quadraticBezierTo(8, 2, 2, -6)
      ..close(),
    _fill(coreShadeOf(LionColors.body).withValues(alpha: 0.35)),
  );
  // Hai đệm râu phồng, chấm chân râu.
  for (final (cx, cy) in [(-37.0, 6.0), (-28.0, 8.0)]) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 13, height: 9),
      _fill(lighten(LionColors.belly, 0.12)),
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy), width: 13, height: 9),
      0.3,
      2.4,
      false,
      Paint()
        ..color = darken(LionColors.belly, 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }
  // Nếp nhăn sống mũi khi gầm (mặt dữ).
  final wrinkle = Paint()
    ..color = LionColors.bodyShade
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.3
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 2 + (roar > 0.3 ? 2 : 0); i++) {
    canvas.drawArc(
      Rect.fromCenter(center: Offset(-34 + i * 4.0, -8), width: 6, height: 5),
      math.pi * 1.1,
      math.pi * 0.8,
      false,
      wrinkle,
    );
  }
  // Hốc mắt sâu dưới gờ mày (mắt nhìn ra từ bóng tối — đáng sợ hơn).
  const eyeAt = Offset(-20, -9);
  canvas.drawCircle(
    eyeAt + const Offset(1, -1),
    12,
    Paint()
      ..shader = Gradient.radial(eyeAt + const Offset(1, -1), 12, [
        coreShadeOf(LionColors.body).withValues(alpha: 0.75),
        coreShadeOf(LionColors.body).withValues(alpha: 0),
      ]),
  );
  // Mảng lông sáng dưới mắt và góc mắt trong (dấu nhận diện sư tử thật).
  final pale = _fill(lighten(LionColors.belly, 0.35));
  canvas.drawPath(
    taperedStroke(
      [
        eyeAt + const Offset(-8, 2),
        eyeAt + const Offset(-1, 5.5),
        eyeAt + const Offset(7, 2),
      ],
      3.2,
      peak: 0.4,
    ),
    pale,
  );
  canvas.drawPath(
    taperedStroke(
      [
        eyeAt + const Offset(-6, -2),
        eyeAt + const Offset(-9.5, 1.5),
        eyeAt + const Offset(-11, 6),
      ],
      2,
      peak: 0.3,
    ),
    pale,
  );
  // Viền môi trên sẫm từ dưới mũi cong xuống khoé miệng.
  canvas.drawPath(
    taperedStroke(
      const [
        Offset(-45, 3),
        Offset(-43, 9),
        Offset(-34, 12.5),
        Offset(-14, 13),
      ],
      2.2,
      peak: 0.3,
      startWidth: 0.5,
    ),
    _fill(LionColors.nose),
  );
  // Ba vết sẹo vuốt chéo qua mắt.
  final scar = Paint()
    ..color = LionColors.scar
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 3; i++) {
    canvas.drawLine(Offset(-14 + i * 4.0, -22), Offset(-24 + i * 4.0, 0), scar);
  }
  canvas.restore();
  _ruffImage.paint(canvas);
  // Tai tròn của sư tử nhìn nghiêng: vành tai dày, lòng tai lông nhạt
  // mọc từ đáy, mép sau viền sẫm; khi gầm tai cụp nằm rạp ra sau.
  canvas.save();
  canvas.translate(10, -21);
  canvas.rotate(0.15 + 0.9 * roar);
  canvas.scale(1, 1 - 0.35 * roar);
  final ear = Path()
    ..moveTo(-6, 3)
    ..cubicTo(-7, -5, -2, -10, 3, -9)
    ..cubicTo(8, -8, 9, -1, 7, 3)
    ..close();
  _shaded(canvas, ear, LionColors.body, shadow: 2);
  canvas.save();
  canvas.clipPath(ear);
  canvas.drawPath(
    Path()
      ..moveTo(-3, 3)
      ..cubicTo(-4, -3, 0, -6, 2.5, -5.5)
      ..cubicTo(5, -4, 5, 0, 4, 3)
      ..close(),
    _fill(darken(LionColors.body, 0.35)),
  );
  // Lông trong tai: các sợi sáng mọc từ đáy lên.
  for (final dx in const [-2.0, 0.0, 2.0]) {
    canvas.drawPath(
      taperedStroke(
        [Offset(dx, 3), Offset(dx + 0.5, -1), Offset(dx + 1.2, -3.5)],
        1.2,
        peak: 0.2,
        startWidth: 1,
      ),
      _fill(const Color(0xFFF0DDB8)),
    );
  }
  // Mép sau tai sẫm (sư tử có vệt đen sau tai).
  canvas.drawPath(
    taperedStroke(
      const [Offset(3, -9), Offset(7.5, -5), Offset(7, 2)],
      2,
      peak: 0.4,
    ),
    _fill(LionColors.mane),
  );
  canvas.restore();
  canvas.restore();

  // Mũi da sẫm có chấm bóng.
  final nose = Path()
    ..moveTo(-49, -4)
    ..quadraticBezierTo(-44, -8, -38, -5)
    ..quadraticBezierTo(-40, 1, -45, 2)
    ..quadraticBezierTo(-50, 0, -49, -4)
    ..close();
  canvas.drawPath(nose, _fill(LionColors.nose));
  glint(canvas, const Offset(-44, -5), 1.6, alpha: 0.6);
  // Chấm râu.
  for (final (x, y) in [(-38.0, 5.0), (-33.0, 7.0), (-36.0, 9.0)]) {
    canvas.drawCircle(Offset(x, y), 0.8, _fill(LionColors.outline));
  }
  // Sợi râu trắng mảnh, cong xuống.
  final whisker = Paint()
    ..color = const Color(0xCCFFF8EA)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.6
    ..strokeCap = StrokeCap.round;
  for (final (y, bend) in [(4.0, 2.0), (7.0, 5.0), (10.0, 8.0)]) {
    canvas.drawPath(
      Path()
        ..moveTo(-38, y)
        ..quadraticBezierTo(-50, y - 1 + bend * 0.3, -60, y + bend),
      whisker,
    );
  }
  // Nanh trên lòi ra ngoài cả khi ngậm miệng.
  for (final (x, len) in [(-36.0, 7.0), (-24.0, 9.0)]) {
    final fang = Path()
      ..moveTo(x, 12)
      ..lineTo(x + 4.5, 12)
      ..quadraticBezierTo(x + 3, 12 + len * 0.7, x + 1, 12 + len + 3 * roar)
      ..close();
    canvas.drawPath(fang, _fill(LionColors.fang));
    canvas.drawPath(
      fang,
      Paint()
        ..color = LionColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }
  // Nước dãi khi gầm.
  if (roar > 0.6 && fall == 0) {
    final drip = 4 + 6 * math.sin(t * 5).abs();
    canvas.drawLine(
      const Offset(-30, 14),
      Offset(-31, 14 + drip),
      Paint()
        ..color = const Color(0xAAE6F2FF)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  _eye(canvas, const Offset(-20, -9), s, roar, fall, t);
  canvas.restore();
}

void _eye(
  Canvas canvas,
  Offset eye,
  LionState s,
  double roar,
  double fall,
  double t,
) {
  final brow = Paint()
    ..color = LionColors.outline
    ..strokeCap = StrokeCap.round;
  if (fall > 0.5) {
    // Gục: mắt nhắm nghiền.
    canvas.drawArc(
      Rect.fromCenter(center: eye, width: 10, height: 6),
      0.2,
      math.pi - 0.4,
      false,
      brow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    return;
  }
  final blink = (t % 4.3) < 0.12;
  if (s.hurt > 0.3 || blink) {
    // Nhăn mặt vì đau / chớp mắt.
    canvas.drawLine(
      eye + const Offset(-5, 0),
      eye + const Offset(5, -1),
      brow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
  } else {
    // Quầng sáng: mắt rực khi gầm (quy ước boss: mắt phát sáng).
    canvas.drawCircle(
      eye,
      9 + 4 * roar,
      Paint()
        ..shader = Gradient.radial(eye, 9 + 4 * roar, [
          Color.fromRGBO(255, 170, 40, math.min(1, 0.35 + 0.6 * roar)),
          const Color(0x00FF8A00),
        ]),
    );
    // Mắt xếch hình hạnh nhân.
    final almond = Path()
      ..moveTo(eye.dx - 6, eye.dy + 1)
      ..quadraticBezierTo(eye.dx - 1, eye.dy - 5, eye.dx + 6, eye.dy - 2)
      ..quadraticBezierTo(eye.dx + 1, eye.dy + 4, eye.dx - 6, eye.dy + 1)
      ..close();
    canvas.drawPath(
      almond,
      Paint()
        ..shader = Gradient.radial(
          eye,
          6,
          const [Color(0xFFFFF3A0), Color(0xFFFFB020), Color(0xFFD45A10)],
          const [0, 0.5, 1],
        ),
    );
    // Con ngươi dọc, co lại khi gầm.
    canvas.drawOval(
      Rect.fromCenter(
        center: eye + const Offset(-1.2, -0.4),
        width: 2.4 - roar,
        height: 6,
      ),
      _fill(LionColors.outline),
    );
    canvas.drawCircle(
      eye + const Offset(-3, -1.5),
      0.9,
      _fill(const Color(0xFFFFFFFF)),
    );
    canvas.drawPath(
      almond,
      Paint()
        ..color = LionColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }
  // Gờ mày nặng, chau xuống phía mũi: lúc nào cũng hằm hằm.
  canvas.drawPath(
    Path()
      ..moveTo(eye.dx - 10, eye.dy + 1 - 2 * roar)
      ..quadraticBezierTo(eye.dx - 2, eye.dy - 9, eye.dx + 9, eye.dy - 6)
      ..lineTo(eye.dx + 9, eye.dy - 9)
      ..quadraticBezierTo(eye.dx - 2, eye.dy - 13, eye.dx - 11, eye.dy - 2)
      ..close(),
    _fill(LionColors.bodyShade),
  );
  // Nét mày thon: đậm ở đầu mày phía mũi, mảnh dần ra đuôi.
  canvas.drawPath(
    taperedStroke(
      [
        eye + Offset(-11, 1.5 - 2 * roar),
        eye + const Offset(-3, -5.5),
        eye + const Offset(8, -7.5),
      ],
      3,
      peak: 0.2,
      startWidth: 0.8,
    ),
    brow..style = PaintingStyle.fill,
  );
}

/// Sóng gầm toả ra từ miệng.
void _roarWaves(Canvas canvas, Offset head, double roar, double t) {
  final mouth = head + const Offset(-46, 12);
  final a = (roar - 0.5) * 2;
  for (var i = 0; i < 3; i++) {
    final r = 12.0 + i * 12 + (t * 60) % 12;
    canvas.drawArc(
      Rect.fromCircle(center: mouth, radius: r),
      math.pi * 0.75,
      math.pi * 0.5,
      false,
      Paint()
        ..color = Color.fromRGBO(255, 236, 200, 0.55 * a * (1 - i / 3))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }
}

/// Đòn bị chặn: khiên lục giác vàng loé lên trên bộ da rồi tan.
void _shieldFlash(Canvas canvas, Offset at, double g) {
  final fade = 1 - g;
  final radius = 26 + 30 * _smooth(g);
  // Lưới lục giác.
  final hex = Paint()
    ..color = Color.fromRGBO(255, 226, 120, 0.85 * fade)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4;
  canvas.save();
  canvas.clipPath(Path()..addOval(Rect.fromCircle(center: at, radius: radius)));
  const size = 8.0;
  final w = size * math.sqrt(3);
  for (var row = -5; row <= 5; row++) {
    for (var col = -5; col <= 5; col++) {
      final cx = at.dx + col * w + (row.isOdd ? w / 2 : 0);
      final cy = at.dy + row * size * 1.5;
      final path = Path();
      for (var k = 0; k < 6; k++) {
        final a = math.pi / 3 * k + math.pi / 6;
        final pt = Offset(cx + math.cos(a) * size, cy + math.sin(a) * size);
        k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      canvas.drawPath(path, hex);
    }
  }
  canvas.restore();
  // Vòng sáng ngoài + lõi loé.
  canvas.drawCircle(
    at,
    radius,
    Paint()
      ..color = Color.fromRGBO(255, 240, 170, 0.9 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3,
  );
  canvas.drawCircle(
    at,
    radius * 0.5,
    Paint()
      ..shader = Gradient.radial(at, radius * 0.5, [
        Color.fromRGBO(255, 255, 230, 0.8 * fade),
        const Color(0x00FFF0B0),
      ]),
  );
}

/// Gục ngã: làn khói Trì Trệ tím xám bốc lên rời khỏi xác sư tử (sức mạnh
/// tà ác bị đánh bật), cuộn xoắn rồi tan.
void _stagnationLeaving(Canvas canvas, double t, double fall, double drop) {
  final a = ((fall - 0.3) / 0.7).clamp(0.0, 1.0);
  for (var i = 0; i < 6; i++) {
    final phase = (t * 0.35 + i / 6) % 1;
    final x = -40 + i * 22.0 + math.sin(t * 1.3 + i * 2) * 8 * phase;
    final y = -90 + drop - phase * 90;
    final r = 6 + phase * 12;
    canvas.drawCircle(
      Offset(x, y),
      r,
      Paint()
        ..shader = Gradient.radial(Offset(x, y), r + 4, [
          Color.fromRGBO(120, 100, 150, 0.5 * a * (1 - phase)),
          const Color.fromRGBO(120, 100, 150, 0),
        ]),
    );
    // Lõi xoắn tối hơn.
    canvas.drawArc(
      Rect.fromCircle(center: Offset(x, y), radius: r * 0.55),
      t * 2 + i,
      3.2,
      false,
      Paint()
        ..color = Color.fromRGBO(70, 56, 92, 0.6 * a * (1 - phase))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }
}

/// Bụi đất tung lên sau chân sau khi sư tử cào đất lấy đà.
void _pawDust(Canvas canvas, double t, double windup) {
  for (var i = 0; i < 7; i++) {
    final phase = (t * 1.6 + i / 7) % 1;
    final x = 84 + i * 7.0 + phase * 50;
    final y = -2 - phase * 22 - (i % 3) * 3;
    canvas.drawCircle(
      Offset(x, y),
      4 + phase * 8,
      Paint()
        ..color = Color.fromRGBO(196, 160, 110, 0.75 * windup * (1 - phase)),
    );
  }
}
