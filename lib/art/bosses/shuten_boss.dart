import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';

import '../battle_stage.dart';
import '../nemea_scene.dart' show stageGroundY, stageSize;
import '../vector_style.dart';
import 'japan_sprite_boss.dart';

/// Bảng màu Shuten-dōji (oni_boss.py): da đỏ son xăm xoáy, hakama chàm,
/// thừng rơm, da hổ, chuỳ sắt gai vàng, lửa ma đỏ cam.
abstract final class OniColors {
  static const skin = Color(0xFFB83A2C);
  static const tattoo = Color(0xFF7A2016);
  static const navy = Color(0xFF2B2E4E);
  static const apron = Color(0xFF1C1E36);
  static const rope = Color(0xFFE6DCC4);
  static const pelt = Color(0xFFE8A048);
  static const iron = Color(0xFF1C1B22);
  static const gold = Color(0xFFD8A848);
  static const mane = Color(0xFFEDEAE4);
  static const horn = Color(0xFF8A2018);
  static const eye = Color(0xFFFFC23A);
}

/// Shuten-dōji, vua oni núi Ōe (chương Nhật, kỳ công Izumo — chưa xếp màn;
/// id hình `shuten_doji`). Khổng lồ bụng phệ vác chuỳ gai trên vai phải, tay
/// trái nâng lửa ma. Đòn: giơ chuỳ cao sau đầu (lấy đà) → nện xuống trước mặt
/// (ra đòn), mặt đất nứt và sóng chấn động lan về phía người chơi.
class ShutenBossArt extends JapanSpriteBoss {
  @override
  String get spriteName => 'shuten_doji';

  @override
  String get soundKey => 'shuten';

  @override
  Offset get feet => const Offset(314, stageGroundY);

  @override
  double get shadowWidth => 120;

  @override
  Vector2 get target => Vector2(feet.dx - 6, feet.dy - 118);

  @override
  Vector2 get portraitFocus => Vector2(feet.dx - 8, feet.dy - 140);

  @override
  double get portraitView => 120;

  @override
  Color get gradeLight => const Color(0xFFE2D8F2);

  @override
  List<Color> get hitColors => const [
    Color(0xFFFF8A3A),
    Color(0xFFFFE082),
    Color(0xFFFFFFFF),
  ];

  // ------------------------------------------------------------ nền: núi Ōe
  @override
  void paintBackdrop(Canvas canvas) {
    final w = stageSize.width;
    canvas.drawRect(
      Offset.zero & stageSize,
      Paint()
        ..shader = Gradient.linear(
          Offset.zero,
          const Offset(0, 200),
          const [Color(0xFF12122E), Color(0xFF34285A), Color(0xFF7A3E5A)],
          const [0, 0.6, 1],
        ),
    );
    final stars = math.Random(3);
    for (var i = 0; i < 40; i++) {
      canvas.drawCircle(
        Offset(stars.nextDouble() * w, stars.nextDouble() * 110),
        0.4 + stars.nextDouble() * 0.6,
        fillPaint(Color.fromRGBO(240, 236, 255, 0.3 + stars.nextDouble() * 0.5)),
      );
    }
    // Trăng tròn có quầng, mây dải kiểu khắc gỗ vắt ngang.
    const moon = Offset(112, 62);
    canvas.drawCircle(
      moon,
      70,
      Paint()
        ..shader = Gradient.radial(moon, 70, const [
          Color(0x55F2E6C8),
          Color(0x00F2E6C8),
        ]),
    );
    canvas.drawCircle(moon, 22, fillPaint(const Color(0xFFF2E8CC)));
    canvas.drawCircle(
      moon.translate(5, 3),
      19,
      fillPaint(const Color(0x22B8A890)),
    );
    for (final (x, y, len, t) in const [
      (60.0, 70.0, 120.0, 6.0),
      (150.0, 48.0, 140.0, 5.0),
      (240.0, 84.0, 150.0, 7.0),
      (10.0, 104.0, 110.0, 5.0),
    ]) {
      canvas.drawPath(cloudBand(Offset(x, y), len, t), fillPaint(const Color(0xFF2A2048)));
      canvas.drawPath(
        cloudBand(Offset(x + len * 0.15, y - t * 0.25), len * 0.6, t * 0.35),
        fillPaint(const Color(0x66F2E6C8)),
      );
    }
    // Ba lớp núi, tuyết tùng trên sống, sương giữa các lớp.
    final trees = math.Random(9);
    for (final (base, amp, color, phase) in [
      (150.0, 34.0, const Color(0xFF2E2650), 0.4),
      (170.0, 26.0, const Color(0xFF221C3E), 2.1),
      (192.0, 18.0, const Color(0xFF17132C), 4.0),
    ]) {
      final ridge = <Offset>[
        for (var x = 0.0; x <= w; x += 8)
          Offset(
            x,
            base -
                amp * (0.55 + 0.45 * math.sin(x / 47 + phase)) -
                amp * 0.25 * math.sin(x / 13 + phase * 2).abs(),
          ),
      ];
      final path = Path()..moveTo(0, 260);
      for (final p in ridge) {
        path.lineTo(p.dx, p.dy);
      }
      path
        ..lineTo(w, 260)
        ..close();
      canvas.drawPath(path, fillPaint(color));
      for (final p in ridge) {
        if (trees.nextDouble() < 0.5) continue;
        final th = 4 + trees.nextDouble() * 5;
        canvas.drawPath(
          Path()
            ..moveTo(p.dx, p.dy - th)
            ..lineTo(p.dx - th * 0.3, p.dy + 1)
            ..lineTo(p.dx + th * 0.3, p.dy + 1)
            ..close(),
          fillPaint(color),
        );
      }
      canvas.drawRect(
        Rect.fromLTRB(0, base - 4, w, base + 12),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, base - 4),
            Offset(0, base + 12),
            const [Color(0x00B090C0), Color(0x40B090C0), Color(0x00B090C0)],
            const [0, 0.5, 1],
          ),
      );
    }
    // Sào huyệt oni trên sườn núi: đuốc đỏ li ti.
    for (final p in const [
      Offset(268, 150),
      Offset(281, 146),
      Offset(296, 152),
      Offset(352, 158),
    ]) {
      canvas.drawCircle(
        p,
        6,
        Paint()
          ..shader = Gradient.radial(p, 6, const [
            Color(0x88FF7A3A),
            Color(0x00FF7A3A),
          ]),
      );
      canvas.drawCircle(p, 1, fillPaint(const Color(0xFFFFC27A)));
    }
    paintGround(
      canvas,
      const Color(0xFF3A2E34),
      const Color(0xFF1C1418),
      const Color(0x66C8B0E0),
    );
    // Đá, rơm vương, chén sake vỡ.
    final rocks = math.Random(21);
    for (var i = 0; i < 26; i++) {
      final c = Offset(
        rocks.nextDouble() * w,
        stageGroundY + 4 + rocks.nextDouble() * 34,
      );
      final s = 2 + rocks.nextDouble() * 4;
      final r = Rect.fromCenter(center: c, width: s * 1.6, height: s * 0.7);
      canvas.drawOval(r.shift(const Offset(0.6, 0.8)), fillPaint(const Color(0x66100810)));
      canvas.drawOval(r, fillPaint(const Color(0xFF4A3E48)));
      canvas.drawArc(
        r.deflate(0.3),
        math.pi * 1.1,
        math.pi * 0.7,
        false,
        Paint()
          ..color = const Color(0x88C8B8E8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
      );
    }
    _sakeBarrels(canvas);
  }

  /// Thùng rượu sake (taru) bọc chiếu rơm buộc thừng, tem đỏ — Shuten-dōji
  /// nghiện rượu (truyền thuyết: bị chuốc rượu độc).
  static void _sakeBarrels(Canvas canvas) {
    for (final (x, y, s) in const [
      // Giữa người chơi và boss (sau lưng nhân vật thì bị che, dưới tay thì rối).
      (228.0, stageGroundY + 1, 0.9),
      (246.0, stageGroundY + 5, 0.75),
      (216.0, stageGroundY + 7, 0.6),
    ]) {
      final w = 20 * s, h = 22 * s;
      final body = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - w / 2, y - h, w, h),
            Radius.circular(3 * s),
          ),
        );
      shadedPath(
        canvas,
        body,
        const Color(0xFFB89A68),
        PartFrame.world,
        shadow: 3 * s,
        highlight: 1,
        outlineWidth: 1.1,
      );
      canvas.drawOval(
        Rect.fromLTWH(x - w / 2, y - h - 2.5 * s, w, 5 * s),
        fillPaint(const Color(0xFF5A3E28)),
      );
      final band = Paint()
        ..color = const Color(0xFF3A2A1C)
        ..strokeWidth = 1.4 * s;
      for (final t in const [0.2, 0.8]) {
        canvas.drawLine(
          Offset(x - w / 2, y - h * t),
          Offset(x + w / 2, y - h * t),
          band,
        );
      }
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x - w * 0.08, y - h * 0.5), width: w * 0.38, height: h * 0.42),
        fillPaint(const Color(0xFFB0302A)),
      );
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x - w * 0.08, y - h * 0.5), width: w * 0.12, height: h * 0.26),
        fillPaint(const Color(0xFF1C1414)),
      );
    }
  }

  @override
  void paintAmbient(Canvas canvas, double time) {
    // Sương đêm trôi chậm sát chân núi.
    for (var i = 0; i < 3; i++) {
      final x = (i * 170 + time * (6 + i * 2)) % 580 - 140;
      canvas.drawOval(
        Rect.fromLTWH(x, 178 + i * 8.0, 170, 12),
        fillPaint(const Color(0x22D8C8F0)),
      );
    }
    // Tàn lửa đỏ bốc lên từ sào huyệt.
    for (var i = 0; i < 10; i++) {
      final ph = (time * 0.12 + i / 10) % 1;
      final x = 230 + (i * 37) % 160 + math.sin(time + i) * 6;
      final y = 200 - ph * 150;
      canvas.drawCircle(
        Offset(x, y),
        0.9,
        fillPaint(Color.fromRGBO(255, 150, 70, 0.8 * (1 - ph))),
      );
    }
  }

  // ------------------------------------------------------------ boss (2.5D)
  /// Hông dưới (hakama, tạp dề, thừng, khoá) và thân trên (bụng, ngực, da
  /// hổ, chuỗi hạt, đầu) ghi một lần; mỗi khung chỉ biến đổi chúng theo kênh
  /// biên đạo và vẽ động hai bàn chân, hai tay, chuỳ, lửa.
  Picture? _lower, _upper;

  @override
  void dispose() {
    _lower?.dispose();
    _upper?.dispose();
    _lower = _upper = null;
    super.dispose();
  }

  /// Đơn vị sân khấu cho 1 đơn vị kênh (m × S của oni_boss.py, 48 đơn vị/m).
  static const _k = 1.45 * 48;

  /// Hông (tâm xoay khi ngả người), vai phải (xa, gốc vung chuỳ), vai trái.
  static const _hip = Offset(-4, -92);
  static const _shoulder = Offset(-26, -144);
  static const _nearShoulder = Offset(40, -142);

  @override
  Map<String, double> idleChannels(double time) {
    final w = 2 * math.pi * time / 3.4;
    final r = choreo.ready;
    return {
      ...r,
      'drop': 0.012 * (1 - math.cos(w)),
      'lean': 1.2 * math.sin(w),
      'hand': r['hand']! + 2.5 * math.sin(w),
      'aim': 0.06 * math.sin(w),
    };
  }

  /// Thân trên theo kênh: dịch hông rồi xoay quanh hông khi ngả.
  Offset _body(Map<String, double> v, Offset p) {
    final bo = Offset(-0.8 * v['shift']! * _k, v['drop']! * _k);
    // Trong 3D lưng cong dần qua nhiều đốt; xoay cứng cả thân trên quanh hông
    // bằng đúng góc ngả thì gãy gập → chỉ ~55%.
    final a = -v['lean']! * 0.55 * math.pi / 180;
    final q = p - _hip;
    return _hip + bo + Offset(q.dx * math.cos(a) - q.dy * math.sin(a), q.dx * math.sin(a) + q.dy * math.cos(a));
  }

  /// (vai, tay nắm, hướng chuỳ trên màn hình — dài < 1 khi chĩa về máy quay).
  (Offset, Offset, Offset) _club(Map<String, double> v) {
    final sh = _body(v, _shoulder.translate(-v['twist']! * 0.25, 0));
    final sweep = v['sweep']!;
    final hand = sh +
        planeDir(v['hand']!, sweep) * v['reach']! * _k +
        const Offset(-0.6, -0.15) * v['side']! * _k * 0.5;
    var dir = planeDir(v['club']!, sweep);
    if (dir.distance < 0.35) dir = dir / dir.distance * 0.35;
    return (sh, hand, dir);
  }

  @override
  void paintVector(Canvas canvas, BossFrame f, Map<String, double> v, String? move) {
    final d = f.defeat.clamp(0.0, 1.0);
    final (sh, hand, dir) = _club(v);
    // Chuỳ chĩa ra sau (sang phải màn hình) và cao: nằm sau thân.
    final behind = dir.dx > 0.25 && hand.dy < sh.dy + 10;
    if (behind) _clubArm(canvas, sh, hand, dir);
    _feet(canvas, v);
    // Hông dưới: thắt lưng theo hông, gấu váy nằm yên trên đất (vải co/nghiêng).
    final bo = Offset(-0.8 * v['shift']! * _k, v['drop']! * _k);
    canvas.save();
    canvas.transform(Float64List.fromList([
      1, 0, 0, 0, //
      -bo.dx / 92, (92 - bo.dy) / 92, 0, 0, //
      0, 0, 1, 0, //
      0, 0, 0, 1,
    ]));
    canvas.drawPicture(_lower ??= _record(_paintLower));
    canvas.restore();
    canvas.save();
    final c = _hip + bo;
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-v['lean']! * 0.55 * math.pi / 180);
    canvas.translate(-_hip.dx, -_hip.dy);
    canvas.drawPicture(_upper ??= _record(_paintUpper));
    canvas.restore();
    _wisps(canvas, f.time, 1 - d);
    _fireArm(canvas, v, f.time, d, move);
    if (!behind) _clubArm(canvas, sh, hand, dir);
  }

  /// Hai bàn chân trần, vuốt đen: chân trái (gần) bám đất, chân phải (xa) bước tới.
  void _feet(Canvas canvas, Map<String, double> v) {
    for (final (x, step) in [
      (-18.0, Offset(-0.8 * v['step']! * _k, -v['lift']! * _k)),
      (20.0, Offset.zero),
    ]) {
      canvas.save();
      canvas.translate(step.dx, step.dy);
      final foot = Path()
        ..moveTo(x - 9, 0)
        ..quadraticBezierTo(x - 10, -7, x - 2, -8)
        ..lineTo(x + 8, -7)
        ..quadraticBezierTo(x + 9, -2, x + 7, 0)
        ..close();
      shadedPath(canvas, foot, OniColors.skin, PartFrame.world, shadow: 2, highlight: 0.8, outlineWidth: 1.1);
      for (var k = 0; k < 4; k++) {
        final c = Offset(x - 8 + k * 2.6, -0.6);
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy)
            ..lineTo(c.dx - 2.4, c.dy + 0.4)
            ..lineTo(c.dx + 0.4, c.dy - 1.2)
            ..close(),
          fillPaint(const Color(0xFF141012)),
        );
      }
      canvas.restore();
    }
  }

  /// Tay trái (gần) nâng lửa: chìa ra trước (chờ) → vươn thẳng ngắm đích
  /// (aim 1, lấy đà) → kéo về sát sườn (aim âm, ra đòn) → buông (gục).
  void _fireArm(Canvas canvas, Map<String, double> v, double time, double d, String? move) {
    final aim = v['aim']!;
    final drink = v['drink'] ?? 0, face = v['face'] ?? 0;
    final sh = _body(v, _nearShoulder);
    var hand = _body(v, const Offset(46, -118));
    if (aim > 0) hand = Offset.lerp(hand, _body(v, const Offset(-6, -138)), aim)!;
    if (aim < 0) hand = Offset.lerp(hand, _body(v, const Offset(32, -110)), -aim)!;
    hand = Offset.lerp(hand, _body(v, const Offset(46, -94)), d)!;
    // Uống: vò lên miệng; sặc: bàn tay bịt miệng.
    final mouth = _body(v, const Offset(-20, -150));
    if (drink > 0) hand = Offset.lerp(hand, mouth.translate(4, -4), drink)!;
    if (face > 0) hand = Offset.lerp(hand, mouth, face)!;
    final el = joint2(sh, hand, 24, 22, -1);
    final arm = chainPath([(sh, el, 9.5, 8), (el, hand, 8, 6.5)]);
    shadedPath(canvas, arm, OniColors.skin, PartFrame.world, shadow: 4, highlight: 1.4, outlineWidth: 1.4);
    final mid = Offset.lerp(el, hand, 0.45)!;
    final fa = (hand - el) / math.max(0.01, (hand - el).distance);
    final band = Paint()
      ..color = OniColors.iron
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(mid - fa * 4, mid + fa * 4, band);
    canvas.drawLine(mid - fa * 4, mid + fa * 4, Paint()..color = OniColors.gold..strokeWidth = 1.2);
    canvas.drawPath(
      capsulePath(Offset.lerp(sh, el, 0.4)!, Offset.lerp(sh, el, 0.6)!, 9.8, 9.4),
      fillPaint(OniColors.gold),
    );
    canvas.drawCircle(hand, 5.6, fillPaint(OniColors.skin));
    if (move == 'drink' && drink > 0.05) {
      _jar(canvas, hand, drink);
    } else if (d < 0.6 && move != 'stagger') {
      _fire(canvas, hand.translate(0, -6), time);
    }
  }

  /// Vò sake sứ trắng vành chàm, nghiêng rót vào miệng theo [tilt] 0–1.
  static void _jar(Canvas canvas, Offset hand, double tilt) {
    canvas.save();
    canvas.translate(hand.dx, hand.dy);
    canvas.rotate(-0.9 * tilt);
    final body = Path()
      ..moveTo(-5, 0)
      ..quadraticBezierTo(-9, -8, -6, -14)
      ..lineTo(-2.4, -19)
      ..lineTo(-3, -22)
      ..lineTo(3, -22)
      ..lineTo(2.4, -19)
      ..lineTo(6, -14)
      ..quadraticBezierTo(9, -8, 5, 0)
      ..close();
    shadedPath(canvas, body, const Color(0xFFEDE6D6), PartFrame.world, shadow: 1.6, highlight: 0.8, outlineWidth: 1);
    canvas.drawLine(const Offset(-8, -9), const Offset(8, -9), Paint()..color = const Color(0xFF26346E)..strokeWidth = 2);
    canvas.restore();
  }

  // Lúc vò vỡ (uống → choáng): toé mảnh sứ + rượu; sao choáng quanh đầu.
  double? _shatterAt;
  bool _wasDrinking = false;

  @override
  void paintMechanic(Canvas canvas, BossFrame f) {
    final b = f.battle;
    if (_wasDrinking && b.drinking == 0 && b.stunMs > 0) _shatterAt = f.time;
    _wasDrinking = b.drinking > 0;
    final head = feet.translate(-12, -158);
    if (_shatterAt case final at? when f.time - at < 0.7) {
      final u = (f.time - at) / 0.7;
      for (var k = 0; k < 12; k++) {
        final a = -math.pi * (0.1 + 0.8 * k / 11);
        final p = head + Offset(math.cos(a) * 46 * u - 8, math.sin(a) * 30 * u + 60 * u * u);
        canvas.drawRect(
          Rect.fromCenter(center: p, width: 3, height: 2),
          fillPaint(Color.fromRGBO(240, 234, 220, 1 - u)),
        );
        canvas.drawCircle(p.translate(4, 3), 1.2, fillPaint(Color.fromRGBO(220, 230, 255, 0.7 * (1 - u))));
      }
    }
    if (b.stunMs > 0 && f.defeat == 0) {
      for (var k = 0; k < 3; k++) {
        final a = f.time * 4 + k * 2 * math.pi / 3;
        final p = head.translate(4, -26) + Offset(math.cos(a) * 16, math.sin(a) * 5);
        _star(canvas, p, 3.2, const Color(0xFFFFE27A));
      }
    }
  }

  static void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), fillPaint(color));
  }

  static Picture _record(void Function(Canvas) draw) {
    final r = PictureRecorder();
    draw(Canvas(r));
    return r.endRecording();
  }

  void _paintLower(Canvas canvas) {
    // Hakama chàm rủ thẳng như váy, vân sóng nhạt, viền vàng ở gấu.
    final hakama = Path()
      ..moveTo(-36, -90)
      ..quadraticBezierTo(-44, -50, -46, -6)
      ..lineTo(48, -6)
      ..quadraticBezierTo(46, -50, 42, -90)
      ..close();
    shadedPath(canvas, hakama, OniColors.navy, PartFrame.world, shadow: 6, highlight: 1.4, outlineWidth: 1.6);
    canvas.save();
    canvas.clipPath(hakama);
    final wave = Paint()
      ..color = const Color(0x5548508A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    for (var y = -84.0; y < -10; y += 9) {
      final path = Path()..moveTo(-50, y);
      for (var x = -50.0; x < 52; x += 8) {
        path.quadraticBezierTo(x + 2, y - 3 + (x % 16 == 0 ? 2 : 0), x + 8, y);
      }
      canvas.drawPath(path, wave);
    }
    // Nếp xếp li dọc (bóng sẫm).
    final pleat = Paint()
      ..color = const Color(0x661A1C30)
      ..strokeWidth = 1.2;
    for (final x in const [-26.0, -8.0, 12.0, 30.0]) {
      canvas.drawLine(Offset(x, -84), Offset(x * 1.12, -8), pleat);
    }
    canvas.drawRect(const Rect.fromLTRB(-50, -11, 52, -6), fillPaint(OniColors.gold));
    canvas.restore();
    // Tạp dề chàm sẫm phía trước, viền vàng, chữ 鬼 cách điệu.
    final apron = Path()..addRect(const Rect.fromLTRB(-24, -90, -2, -36));
    shadedPath(canvas, apron, OniColors.apron, PartFrame.world, shadow: 2, highlight: 0.6, outlineWidth: 1.1);
    canvas.drawPath(
      apron,
      Paint()
        ..color = OniColors.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
    final kanji = Paint()
      ..color = OniColors.gold
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-16, -62), const Offset(-10, -62), kanji);
    canvas.drawRect(
      const Rect.fromLTRB(-16, -60, -10, -55),
      Paint()
        ..color = OniColors.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawLine(const Offset(-13, -55), const Offset(-16, -49), kanji);
    canvas.drawLine(const Offset(-12, -55), const Offset(-9, -49), kanji);
    // Thừng shimenawa ngang hông (bụng chờm lên trên).
    final rope = Path()
      ..moveTo(-40, -92)
      ..quadraticBezierTo(2, -84, 44, -92);
    canvas.drawPath(
      rope,
      Paint()
        ..color = VectorStyle.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      rope,
      Paint()
        ..color = OniColors.rope
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.4
        ..strokeCap = StrokeCap.round,
    );
    for (var k = 0; k < 14; k++) {
      final t = k / 13;
      final x = -40 + 84 * t;
      final y = -92 + 16 * t * (1 - t);
      canvas.drawLine(
        Offset(x - 1.6, y - 2.6),
        Offset(x + 1.6, y + 2.6),
        Paint()
          ..color = const Color(0xFFA89878)
          ..strokeWidth = 0.8,
      );
    }
    // Khoá đai mặt quỷ vàng treo trên đầu tạp dề.
    final buckle = Path()..addOval(Rect.fromCircle(center: const Offset(-13, -84), radius: 6));
    shadedPath(canvas, buckle, OniColors.gold, PartFrame.world, shadow: 1.6, highlight: 0.8, outlineWidth: 1);
    canvas.drawCircle(const Offset(-15, -85), 1, fillPaint(const Color(0xFFB080FF)));
    canvas.drawCircle(const Offset(-11, -85), 1, fillPaint(const Color(0xFFB080FF)));
  }

  void _paintUpper(Canvas canvas) {
    // Thân trên: vai rộng, ngực xệ, bụng phệ chờm qua thừng.
    final torso = Path()
      ..moveTo(-34, -96)
      ..quadraticBezierTo(-40, -128, -30, -146)
      ..quadraticBezierTo(-12, -152, 4, -150)
      ..quadraticBezierTo(28, -152, 40, -144)
      ..quadraticBezierTo(48, -118, 42, -94)
      ..close();
    shadedPath(canvas, torso, OniColors.skin, PartFrame.world, shadow: 6, highlight: 1.6, outlineWidth: 1.6);
    final belly = Path()..addOval(Rect.fromCenter(center: const Offset(-8, -104), width: 86, height: 46));
    shadedPath(canvas, belly, OniColors.skin, PartFrame.world, shadow: 6, highlight: 2, outlineWidth: 1.6);
    final sel = Paint()
      ..color = darken(OniColors.skin, 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    // Ngực xệ, rốn, hình xăm xoáy (sel-line, không đen).
    canvas.drawArc(Rect.fromCenter(center: const Offset(-16, -134), width: 26, height: 12), 0.2, 2.6, false, sel);
    canvas.drawArc(Rect.fromCenter(center: const Offset(10, -134), width: 22, height: 11), 0.4, 2.4, false, sel);
    canvas.drawArc(Rect.fromCenter(center: const Offset(-12, -100), width: 5, height: 4), 0, math.pi * 2, false, sel);
    final tattoo = Paint()
      ..color = OniColors.tattoo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (final (c, r) in const [
      (Offset(-32, -110), 6.0),
      (Offset(14, -98), 7.0),
      (Offset(-2, -118), 5.0),
      (Offset(24, -122), 5.0),
    ]) {
      final spiral = Path()..moveTo(c.dx + r, c.dy);
      for (var a = 0.0; a < math.pi * 3; a += 0.3) {
        final rr = r * (1 - a / (math.pi * 3.4));
        spiral.lineTo(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr * 0.7);
      }
      canvas.drawPath(spiral, tattoo);
    }
    // Da hổ vắt vai trái (phía gần): cam sọc đen, viền lông kem.
    final pelt = Path()
      ..moveTo(10, -150)
      ..quadraticBezierTo(30, -156, 44, -146)
      ..lineTo(44, -124)
      ..quadraticBezierTo(28, -112, 12, -116)
      ..quadraticBezierTo(-4, -124, -10, -132)
      ..close();
    shadedPath(canvas, pelt, OniColors.pelt, PartFrame.world, shadow: 3, highlight: 1.2, outlineWidth: 1.2);
    canvas.save();
    canvas.clipPath(pelt);
    for (final (a, b) in const [
      (Offset(0, -136), Offset(10, -124)),
      (Offset(14, -146), Offset(20, -122)),
      (Offset(26, -150), Offset(30, -120)),
      (Offset(38, -148), Offset(40, -126)),
    ]) {
      canvas.drawPath(
        taperedStroke([a, Offset.lerp(a, b, 0.5)! + const Offset(2, 0), b], 3, peak: 0.5),
        fillPaint(const Color(0xFF1A1210)),
      );
    }
    canvas.restore();
    canvas.drawPath(
      Path()
        ..moveTo(-10, -132)
        ..quadraticBezierTo(-4, -124, 12, -116)
        ..quadraticBezierTo(28, -112, 44, -124),
      Paint()
        ..color = const Color(0xFFF2E8D4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    // Chuỗi hạt đen to quanh cổ, mặt đồng vàng giữa ngực.
    for (var k = 0; k < 11; k++) {
      final a = math.pi * (0.05 + 0.9 * k / 10);
      final c = const Offset(-6, -146) + Offset(math.cos(a) * 20, math.sin(a) * 9);
      canvas.drawCircle(c, 3.6, fillPaint(VectorStyle.outline));
      canvas.drawCircle(c, 3, fillPaint(const Color(0xFF16141A)));
      glint(canvas, c + const Offset(-1, -1), 1, alpha: 0.6);
    }
    final pendant = Path()..addOval(Rect.fromCircle(center: const Offset(-7, -135), radius: 4.6));
    shadedPath(canvas, pendant, OniColors.gold, PartFrame.world, shadow: 1.4, highlight: 0.8, outlineWidth: 1);
    _head(canvas);
  }

  /// Đầu: quay ¾ sang trái, hàm bạnh, nanh chìa, mắt vàng như mặt Hannya,
  /// mày trắng rậm, bờm trắng dựng ngược, hai sừng đỏ sẫm có gờ.
  void _head(Canvas canvas) {
    const c = Offset(-8, -158);
    // Bờm sau đầu: lọn nhọn toả ra sau.
    final mane = Path();
    for (var k = 0; k < 9; k++) {
      final a = -math.pi * (0.95 - 0.95 * k / 8) - 0.2;
      final root = c + Offset(math.cos(a), math.sin(a)) * 10 + const Offset(6, 0);
      final tip = c + Offset(math.cos(a) * 26 + 10, math.sin(a) * 20 + (k > 5 ? 10 : 0));
      mane.addPath(taperedStroke([root, Offset.lerp(root, tip, 0.5)! + const Offset(2, -2), tip], 7, peak: 0.2, startWidth: 1, endWidth: 0), Offset.zero);
    }
    shadedPath(canvas, mane, OniColors.mane, PartFrame.world, shadow: 2.5, highlight: 1, outlineWidth: 1.1);
    // Sừng.
    for (final (root, tip, w) in const [
      (Offset(-14, -168), Offset(-20, -186), 4.2),
      (Offset(-1, -170), Offset(4, -188), 3.8),
    ]) {
      final horn = taperedStroke([root, Offset.lerp(root, tip, 0.5)! + const Offset(3, 0), tip], w * 2, peak: 0, startWidth: 1, endWidth: 0.05);
      shadedPath(canvas, horn, OniColors.horn, PartFrame.world, shadow: 1.6, highlight: 0.6, outlineWidth: 1);
      for (final t in const [0.25, 0.45]) {
        final p = Offset.lerp(root, tip, t)!;
        canvas.drawLine(p.translate(-w * 0.8, 0.5), p.translate(w * 0.8, -0.5), Paint()..color = darken(OniColors.horn, 0.3)..strokeWidth = 0.7);
      }
    }
    // Sọ + hàm bạnh hướng sang trái.
    final head = Path()
      ..moveTo(c.dx + 10, c.dy - 10)
      ..quadraticBezierTo(c.dx - 6, c.dy - 16, c.dx - 14, c.dy - 6)
      ..lineTo(c.dx - 17, c.dy + 2)
      ..quadraticBezierTo(c.dx - 18, c.dy + 12, c.dx - 8, c.dy + 15)
      ..quadraticBezierTo(c.dx + 6, c.dy + 16, c.dx + 11, c.dy + 6)
      ..quadraticBezierTo(c.dx + 14, c.dy - 4, c.dx + 10, c.dy - 10)
      ..close();
    shadedPath(canvas, head, OniColors.skin, PartFrame.world, shadow: 3, highlight: 1.2, outlineWidth: 1.3);
    final sel = Paint()
      ..color = darken(OniColors.skin, 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round;
    // Mũi bè, nếp má, miệng gầm.
    canvas.drawPath(Path()..moveTo(c.dx - 13, c.dy - 1)..quadraticBezierTo(c.dx - 18, c.dy + 3, c.dx - 13, c.dy + 4), sel);
    canvas.drawPath(Path()..moveTo(c.dx - 4, c.dy + 2)..quadraticBezierTo(c.dx - 8, c.dy + 8, c.dx - 12, c.dy + 8), sel);
    final mouth = Path()
      ..moveTo(c.dx - 16, c.dy + 8)
      ..quadraticBezierTo(c.dx - 11, c.dy + 12.5, c.dx - 4, c.dy + 9)
      ..lineTo(c.dx - 6, c.dy + 7)
      ..close();
    canvas.drawPath(mouth, fillPaint(const Color(0xFF3A0806)));
    for (final x in const [-15.0, -7.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx + x, c.dy + 10)
          ..lineTo(c.dx + x - 1.2, c.dy + 4)
          ..lineTo(c.dx + x + 1.4, c.dy + 9.5)
          ..close(),
        fillPaint(const Color(0xFFF2E2B8)),
      );
    }
    // Mắt vàng phát sáng trong hốc tối, mày trắng rậm chau.
    for (final e in const [Offset(-14, -2), Offset(-4, -3)]) {
      final p = c + e;
      canvas.drawOval(Rect.fromCenter(center: p, width: 6.5, height: 4), fillPaint(const Color(0xFF3A0806)));
      canvas.drawOval(Rect.fromCenter(center: p, width: 4.6, height: 2.6), fillPaint(OniColors.eye));
      canvas.drawCircle(p.translate(-0.6, 0), 0.9, fillPaint(const Color(0xFF140404)));
    }
    final brow = Paint()
      ..color = OniColors.mane
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c + const Offset(-18, -7), c + const Offset(-10, -4.5), brow);
    canvas.drawLine(c + const Offset(-7, -5), c + const Offset(1, -8), brow);
  }

  /// Tay phải (phía xa) nắm chuỳ: khuỷu gập xuống; chuỳ sắt bát giác đầu
  /// phình, đai vàng, gai vàng, tua đỏ. [dir] hướng chuỳ trên màn hình (độ
  /// dài < 1 = chĩa về phía máy quay, chuỳ ngắn lại).
  void _clubArm(Canvas canvas, Offset sh, Offset hand, Offset dir) {
    final elbow = joint2(sh, hand, 26, 24, hand.dx < sh.dx ? 1 : -1);
    final butt = hand - dir * 12;
    final head = hand + dir * 104;
    final u = dir / dir.distance;
    final n = Offset(-u.dy, u.dx);
    final club = Path()
      ..moveTo(butt.dx + n.dx * 2.6, butt.dy + n.dy * 2.6)
      ..lineTo(hand.dx + dir.dx * 30 + n.dx * 3.4, hand.dy + dir.dy * 30 + n.dy * 3.4)
      ..lineTo(head.dx - dir.dx * 6 + n.dx * 7.5, head.dy - dir.dy * 6 + n.dy * 7.5)
      ..lineTo(head.dx + n.dx * 5, head.dy + n.dy * 5)
      ..lineTo(head.dx - n.dx * 5, head.dy - n.dy * 5)
      ..lineTo(head.dx - dir.dx * 6 - n.dx * 7.5, head.dy - dir.dy * 6 - n.dy * 7.5)
      ..lineTo(hand.dx + dir.dx * 30 - n.dx * 3.4, hand.dy + dir.dy * 30 - n.dy * 3.4)
      ..lineTo(butt.dx - n.dx * 2.6, butt.dy - n.dy * 2.6)
      ..close();
    // Tua đỏ treo ở đuôi chuỳ (luôn rủ xuống).
    canvas.drawLine(butt, butt + const Offset(0, 9), Paint()..color = OniColors.gold..strokeWidth = 0.8);
    canvas.drawPath(
      Path()
        ..moveTo(butt.dx - 1.5, butt.dy + 9)
        ..lineTo(butt.dx + 1.5, butt.dy + 9)
        ..lineTo(butt.dx + 2.5, butt.dy + 18)
        ..lineTo(butt.dx - 2.5, butt.dy + 18)
        ..close(),
      fillPaint(const Color(0xFFC0281E)),
    );
    // Gai vàng hai bên phần đầu.
    for (var t = 0.42; t < 0.96; t += 0.075) {
      final p = Offset.lerp(hand, head, t)!;
      final r = 3.4 + 4 * ((t - 0.3) / 0.7).clamp(0.0, 1.0);
      for (final s in const [1.0, -1.0]) {
        final base = p + n * r * s;
        canvas.drawPath(
          Path()
            ..moveTo(base.dx - dir.dx * 1.4, base.dy - dir.dy * 1.4)
            ..lineTo(base.dx + n.dx * s * 3.6, base.dy + n.dy * s * 3.6)
            ..lineTo(base.dx + dir.dx * 1.4, base.dy + dir.dy * 1.4)
            ..close(),
          fillPaint(OniColors.gold),
        );
      }
    }
    final frame = PartFrame(math.atan2(dir.dx, -dir.dy));
    shadedPath(canvas, club, OniColors.iron, frame, shadow: 2.4, highlight: 1, outlineWidth: 1.3);
    final gold = Paint()
      ..color = OniColors.gold
      ..strokeWidth = 2.2;
    for (final (t, r) in const [(0.14, 3.6), (0.95, 5.6)]) {
      final p = Offset.lerp(hand, head, t)!;
      canvas.drawLine(p - n * r, p + n * r, gold);
    }
    // Cánh tay.
    final arm = chainPath([(sh, elbow, 9, 8), (elbow, hand, 8, 6.5)]);
    shadedPath(canvas, arm, OniColors.skin, PartFrame.world, shadow: 3.5, highlight: 1.2, outlineWidth: 1.4);
    canvas.drawPath(
      capsulePath(Offset.lerp(sh, elbow, 0.45)!, Offset.lerp(sh, elbow, 0.6)!, 9.4, 9),
      fillPaint(OniColors.gold),
    );
    final fist = Path()..addOval(Rect.fromCircle(center: hand, radius: 6.4));
    shadedPath(canvas, fist, OniColors.skin, PartFrame.world, shadow: 2, highlight: 0.8, outlineWidth: 1.2);
  }

  /// Lửa ma đỏ cam trên lòng bàn tay: vài lưỡi lửa giọt nước lay theo thời gian.
  static void _fire(Canvas canvas, Offset base, double time) {
    canvas.drawCircle(
      base.translate(0, -4),
      16,
      Paint()
        ..shader = Gradient.radial(base.translate(0, -4), 16, const [
          Color(0x66FF8A3A),
          Color(0x00FF8A3A),
        ]),
    );
    for (var k = 0; k < 4; k++) {
      final sway = math.sin(time * 6 + k * 1.7) * 2.2;
      final h = 14.0 - k * 2.4 + math.sin(time * 9 + k) * 1.6;
      final x = base.dx + (k - 1.5) * 2.6;
      final tongue = Path()
        ..moveTo(x - 3.6, base.dy)
        ..quadraticBezierTo(x - 3.4, base.dy - h * 0.6, x + sway, base.dy - h)
        ..quadraticBezierTo(x + 3.4, base.dy - h * 0.5, x + 3.6, base.dy)
        ..close();
      canvas.drawPath(tongue, fillPaint(k.isEven ? const Color(0xFFFF6A2A) : const Color(0xFFFF9A3A)));
    }
    canvas.drawOval(
      Rect.fromCenter(center: base.translate(0, -3), width: 6, height: 7),
      fillPaint(const Color(0xFFFFE6A0)),
    );
  }

  /// Ma trơi bay quanh thân (bản sprite có sẵn trong ảnh).
  static void _wisps(Canvas canvas, double time, double alpha) {
    if (alpha <= 0.05) return;
    for (final (x, y, ph) in const [
      (-78.0, -150.0, 0.0),
      (64.0, -96.0, 1.7),
      (-58.0, -188.0, 3.1),
      (72.0, -168.0, 4.4),
    ]) {
      final p = Offset(x, y + math.sin(time * 1.6 + ph) * 4);
      canvas.drawCircle(
        p,
        8,
        Paint()
          ..shader = Gradient.radial(p, 8, [
            Color.fromRGBO(255, 140, 60, 0.5 * alpha),
            const Color(0x00FF8C3C),
          ]),
      );
      canvas.drawCircle(p, 2.6, fillPaint(Color.fromRGBO(255, 214, 140, alpha)));
      canvas.drawPath(
        taperedStroke([p, p.translate(3, -5), p.translate(1, -11)], 4, peak: 0, startWidth: 1, endWidth: 0),
        fillPaint(Color.fromRGBO(255, 120, 50, 0.8 * alpha)),
      );
    }
  }

  // ------------------------------------------------------------ hiệu ứng đòn
  /// Vệt vung theo cung đầu chuỳ ngay trước lúc chạm; rồi nện đỉnh: nứt đất,
  /// sóng chấn động, bụi, đá văng tại chỗ đầu chuỳ chạm đất; quét chân: vệt
  /// quét thấp ngang gối, bụi cuốn theo hướng quét.
  @override
  void paintStrike(Canvas canvas, BossFrame f, String move, double t) {
    if (drawingVector && t > -0.07 && t < 0.03) {
      final m = choreo.moves[move]!;
      final arc = <Offset>[];
      for (var k = 0; k <= 8; k++) {
        final v = m.at(f.attackPhase - 0.07 + 0.07 * k / 8);
        final (_, hand, dir) = _club(v);
        arc.add(feet + hand + dir * 100);
      }
      smearArc(canvas, arc, 10, const Color(0x88FFE6C8));
    }
    if (t < 0 || t > 0.36) return;
    final u = t / 0.36;
    final fade = 1 - u;
    if (move == 'attack2') {
      final c = feet.translate(-96, -18);
      canvas.drawArc(
        Rect.fromCenter(center: c, width: 150, height: 34),
        math.pi * 0.35,
        math.pi * (0.5 + 0.4 * u),
        false,
        Paint()
          ..color = Color.fromRGBO(255, 230, 200, 0.6 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * fade + 1
          ..strokeCap = StrokeCap.round,
      );
      _dust(canvas, feet.translate(-110 + 50 * u, 0), u, fade, 1.3);
      return;
    }
    final hit = Offset(feet.dx - 116, stageGroundY + 2);
    final crack = Paint()
      ..color = Color.fromRGBO(20, 10, 14, 0.85 * fade)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final glow = Paint()
      ..color = Color.fromRGBO(255, 120, 50, 0.7 * fade)
      ..strokeWidth = 0.7;
    for (var k = 0; k < 7; k++) {
      final a = math.pi * (0.95 + 1.1 * k / 6);
      final len = 26.0 + (k * 13) % 20;
      final mid = hit + Offset(math.cos(a) * len * 0.5 + 3, math.sin(a).abs() * 4 + 1);
      final end = hit + Offset(math.cos(a) * len, math.sin(a).abs() * 7 + 2);
      canvas.drawLine(hit, mid, crack);
      canvas.drawLine(mid, end, crack);
      canvas.drawLine(hit, mid, glow);
    }
    for (final lag in const [0.0, 0.18]) {
      final r = 12 + 150 * (u - lag).clamp(0.0, 1.0);
      final a = (1 - (u - lag).clamp(0.0, 1.0)) * 0.7;
      canvas.drawOval(
        Rect.fromCenter(center: hit, width: r * 2, height: r * 0.34),
        Paint()
          ..color = Color.fromRGBO(255, 214, 160, a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * fade + 0.5,
      );
    }
    _dust(canvas, hit, u, fade, 1);
    for (var k = 0; k < 8; k++) {
      final vx = (k - 3.5) * 9.0;
      final vy = -50.0 - (k * 17) % 30;
      final p = hit + Offset(vx * u * 1.4, vy * u + 90 * u * u);
      if (p.dy > stageGroundY + 4) continue;
      canvas.drawRect(
        Rect.fromCenter(center: p, width: 2.4, height: 2),
        fillPaint(Color.fromRGBO(70, 56, 64, fade)),
      );
    }
  }

  static void _dust(Canvas canvas, Offset at, double u, double fade, double spread) {
    for (var k = 0; k < 6; k++) {
      final dx = (k - 2.5) * 12.0 * (0.4 + u) * spread;
      final p = at + Offset(dx, -6 - 26 * u * (0.6 + (k % 3) * 0.3));
      final r = 6 + 12 * u;
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..shader = Gradient.radial(p, r, [
            Color.fromRGBO(120, 96, 100, 0.5 * fade),
            const Color(0x00786064),
          ]),
      );
    }
  }
}
