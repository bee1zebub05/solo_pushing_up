import 'dart:math' as math;
import 'dart:ui';

import '../../game/battle.dart' show DodgeBy;
import '../battle_stage.dart';
import '../nemea_scene.dart' show stageGroundY;
import '../sprite_atlas.dart';
import 'choreo.dart';
import 'choreo_data.dart';
import '../vector_style.dart' show fillPaint;

/// Boss hình người chương Nhật dựng bằng Blender (`tool/blender/characters/<tên>_boss.py`,
/// atlas `idle` / `attack` / `attack2` / `defeat`): chế độ 3D vẽ sprite, chế độ
/// 2.5D hoặc lúc chưa nạp vẽ bản vector [paintVector] — cùng chỗ đứng, cùng cỡ.
///
/// Hai đòn luân phiên, mỗi đòn có dấu hiệu báo trước riêng; tư thế theo biên
/// đạo chung với Blender (`choreo_data.dart` sinh từ tool/motion/choreo/*.json,
/// rules/dohoa/chuyendong.md): bản vector đọc cùng kênh (dịch hông, ngả, vặn, góc
/// tay, góc vũ khí, cánh…) tại cùng tiến độ nên đi đúng nhịp sprite.
/// Hiệu ứng đòn ([paintStrike]) vẽ ở cả hai chế độ, canh mốc `impact`.
abstract class JapanSpriteBoss extends BossArt {
  /// Tên atlas trong assets/sprites/ (cũng là khoá biên đạo).
  String get spriteName;

  /// Chân boss trên sân khấu (gốc toạ độ của sprite và bản vector).
  Offset get feet;

  /// Bề rộng bóng tiếp đất.
  double get shadowWidth;

  @override
  Offset get bodyAnchor => feet;

  /// Sprite/biên đạo đã có bước chân, dịch trọng tâm: sân khấu chỉ thêm thở
  /// và nảy khi trúng đòn, không ngả/lao thân chồng lên.
  @override
  bool get ownsAttackMotion => true;

  /// Đòn do cơ chế trận điều khiển (lib/game/mechanics/telegraphed_boss.dart).
  @override
  bool get scriptedAttacks => true;

  /// Độ dài choáng của boss (ShutenMechanic.stunMs) để chạy cử chỉ sặc.
  static const stunTotalMs = 3000;

  /// Một giây chiếu của biên đạo = độ dài đòn trên sân khấu (1,2 s).
  static const moveMs = 1200;

  @override
  Future<void> preload() => SpriteAtlas.load(spriteName);

  @override
  void dispose() => SpriteAtlas.evict(spriteName);

  late final Choreo choreo = Choreo(choreoData[spriteName]!);

  /// Kênh tư thế lúc chờ (thở) tại thời điểm [time] giây.
  Map<String, double> idleChannels(double time);

  /// Bản vector 2.5D quanh chân (gốc toạ độ = [feet], đơn vị sân khấu) theo
  /// kênh biên đạo [v] của đòn [move] (null = chờ / gục).
  void paintVector(Canvas canvas, BossFrame f, Map<String, double> v, String? move);

  /// Hiệu ứng đòn trên sân khấu; [t] = thời gian kể từ mốc chạm (tiến độ, âm
  /// = chưa chạm), [phase] = tiến độ đòn.
  void paintStrike(Canvas canvas, BossFrame f, String move, double t) {}

  /// Khung đang vẽ bản vector (không có sprite): vệt vung tính theo hình học
  /// vector, chỉ vẽ khi đúng bản đó — ở sprite nó lệch khỏi vũ khí trong ảnh.
  bool get drawingVector => _vector;
  bool _vector = true;

  /// Ép đòn (ảnh xem trước, test); null = luân phiên.
  String? forceMove;
  int _attacks = 0;
  double _lastPhase = -1;
  String _move = 'attack';

  /// Đòn đang diễn: mỗi lần tiến độ quay về đầu là một đòn mới, A rồi B luân phiên.
  String moveFor(double phase) {
    if (phase >= 0 && (_lastPhase < 0 || phase < _lastPhase - 0.3)) {
      _attacks++;
      _move = _attacks.isOdd || !choreo.moves.containsKey('attack2') ? 'attack' : 'attack2';
    }
    _lastPhase = phase;
    return forceMove ?? _move;
  }

  double impactOf(String move) => choreo.moves[move]?.events['impact'] ?? 0.62;

  /// Tiến độ biên đạo khi còn [tellMs] tới lúc chạm (âm = đã chạm), báo
  /// trước dài [warnMs]: lấy đà theo tốc độ thật tới thế (`hold_from`), GIỮ
  /// thế và nén dần tới `hold_to` suốt phần báo trước còn lại, rồi ra đòn
  /// theo tốc độ thật để chạm đúng mốc `impact` của cơ chế.
  double phaseFromTell(String move, int tellMs, int warnMs) {
    final ev = choreo.moves[move]!.events;
    final hit = ev['impact'] ?? 0.62;
    final hf = ev['hold_from'] ?? 0.38, ht = ev['hold_to'] ?? 0.48;
    if (tellMs <= 0) return math.min(1, hit - tellMs / moveMs);
    final lead = (hit - ht) * moveMs;
    if (tellMs <= lead) return hit - tellMs / moveMs;
    final e = warnMs - tellMs;
    final reach = hf * moveMs;
    if (e < reach) return e / moveMs;
    final u = ((e - reach) / math.max(1, warnMs - reach - lead)).clamp(0.0, 1.0);
    return hf + (ht - hf) * (0.5 - 0.5 * math.cos(math.pi * u));
  }

  double? _curseAt;
  double _lastCurse = 0;

  /// (đòn/cử chỉ, tiến độ) theo trạng thái cơ chế; null = không có (chờ).
  (String, double)? scriptedMove(BossFrame f) {
    final b = f.battle;
    final moves = choreo.moves;
    if (b.curse > 0 && _lastCurse == 0) _curseAt = f.time;
    _lastCurse = b.curse;
    if (b.drinking > 0 && moves.containsKey('drink')) return ('drink', b.drinking);
    if (b.stunMs > 0 && moves.containsKey('stagger')) {
      return ('stagger', (1 - b.stunMs / stunTotalMs).clamp(0.0, 1.0));
    }
    if (_curseAt case final at? when moves.containsKey('write') && f.time - at < 1.6) {
      return ('write', (f.time - at) / 1.6);
    }
    final m = b.bossMove;
    if (m == null || !moves.containsKey(m)) return null;
    return (m, phaseFromTell(m, b.bossTellMs, b.bossWarnMs));
  }

  @override
  void paintBoss(Canvas canvas, BossFrame f) {
    final fall = f.defeat.clamp(0.0, 1.0);
    // Cơ chế điều khiển đòn; không có (ảnh xem trước, test) thì theo tiến độ
    // sân khấu và luân phiên A/B.
    final scripted = fall > 0 ? null : scriptedMove(f);
    final phase = scripted?.$2 ?? f.attackPhase;
    final move = scripted?.$1 ?? moveFor(phase);
    groundShadow(
      canvas,
      feet + const Offset(6, 3),
      shadowWidth * (1 - 0.3 * fall),
      16,
    );
    canvas.save();
    if (fall > 0) {
      // Gục: nhạt dần (khói Trì Trệ do sân khấu vẽ).
      canvas.saveLayer(
        Rect.fromCenter(center: feet.translate(0, -100), width: 400, height: 320),
        Paint()..color = Color.fromRGBO(0, 0, 0, 1 - fall * 0.45),
      );
    }
    canvas.save();
    canvas.translate(feet.dx + 3 * f.hurt, feet.dy);
    final sprite = SpriteAtlas.get(spriteName);
    _vector = sprite == null;
    final attacking = fall == 0 && phase >= 0;
    if (sprite != null) {
      if (fall > 0 && sprite.has('defeat')) {
        sprite.draw(canvas, 'defeat', fall, flash: f.hurt);
      } else if (attacking && sprite.has(move)) {
        // Quanh cú chạm hai khung kề nhau cách xa: không hoà (bóng ma kép).
        final hit = impactOf(move);
        final fast = move.startsWith('attack') && phase > hit - 0.1 && phase < hit + 0.1;
        sprite.draw(canvas, move, phase, flash: f.hurt, snap: fast);
      } else {
        final period = sprite.metaDouble('idlePeriod', 3);
        sprite.draw(canvas, 'idle', f.time / period, loop: true, flash: f.hurt);
      }
    } else {
      if (f.hurt > 0.01) {
        canvas.saveLayer(
          const Rect.fromLTRB(-220, -280, 220, 40),
          Paint()
            ..colorFilter = ColorFilter.mode(
              Color.fromRGBO(255, 244, 220, 0.6 * f.hurt),
              BlendMode.srcATop,
            ),
        );
      }
      final v = fall > 0
          ? choreo.moves['defeat']!.at(fall)
          : attacking
          ? choreo.moves[move]!.at(phase)
          : idleChannels(f.time);
      paintVector(canvas, f, v, attacking ? move : null);
      if (f.hurt > 0.01) canvas.restore();
    }
    canvas.restore();
    if (fall > 0) canvas.restore();
    canvas.restore();
    if (attacking && move.startsWith('attack')) {
      paintStrike(canvas, f, move, phase - impactOf(move));
    }
    paintMechanic(canvas, f);
    final b = f.battle;
    if (fall == 0 && b.bossMove != null && b.bossTellMs > 0) {
      paintTell(canvas, b.bossDodge, 1 - b.bossTellMs / b.bossWarnMs);
    }
  }

  /// Phần cơ chế riêng vẽ trên sân khấu (ấn nguyền…), cả hai chế độ.
  void paintMechanic(Canvas canvas, BossFrame f) {}

  /// Báo đòn (game feel, trụ "đọc được khi hít đất"): viền đỏ đậm dần tới
  /// lúc chạm + biểu tượng cách né ngay trên đầu nhân vật (chỗ mắt người
  /// chơi liếc tới): hai tay thẳng = giữ plank, mũi tên xuống = rep sâu.
  static void paintTell(Canvas canvas, DodgeBy? dodge, double urgency) {
    final u = urgency.clamp(0.0, 1.0);
    final pulse = 0.75 + 0.25 * math.sin(u * math.pi * (6 + 10 * u));
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 400, 260),
      Paint()
        ..shader = Gradient.radial(
          const Offset(200, 130),
          260,
          [const Color(0x00C62828), Color.fromRGBO(198, 40, 40, 0.45 * u * pulse)],
          const [0.55, 1],
        ),
    );
    const c = Offset(98, 58);
    final r = 15 + 3 * pulse;
    canvas.drawCircle(c, r + 3, fillPaint(Color.fromRGBO(120, 14, 14, 0.75)));
    canvas.drawCircle(
      c,
      r + 3,
      Paint()
        ..color = Color.fromRGBO(255, 210, 200, 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    final ink = Paint()
      ..color = const Color(0xFFFFF4EC)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (dodge == DodgeBy.hold) {
      // Hai tay thẳng chống sàn đỡ một thanh ngang (đòn từ trên).
      canvas.drawLine(c.translate(-9, -6), c.translate(9, -6), ink);
      canvas.drawLine(c.translate(-6, -6), c.translate(-6, 8), ink);
      canvas.drawLine(c.translate(6, -6), c.translate(6, 8), ink);
    } else {
      // Hai mũi tên xuống (rạp người: rep sâu).
      for (final dy in const [-6.0, 1.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 7, c.dy + dy)
            ..lineTo(c.dx, c.dy + dy + 6)
            ..lineTo(c.dx + 7, c.dy + dy),
          ink,
        );
      }
    }
  }
}

/// Dải "vệt vung" (smear) theo cung của đầu vũ khí: các điểm [arc] từ cũ tới
/// mới, dày dần và đục dần về phía vũ khí — mắt người đọc được tốc độ.
void smearArc(Canvas canvas, List<Offset> arc, double width, Color color) {
  if (arc.length < 2) return;
  for (var i = 1; i < arc.length; i++) {
    final u = i / (arc.length - 1);
    canvas.drawLine(
      arc[i - 1],
      arc[i],
      Paint()
        ..color = color.withValues(alpha: color.a * u)
        ..strokeWidth = width * (0.25 + 0.75 * u)
        ..strokeCap = StrokeCap.round,
    );
  }
}

/// Toạ độ màn hình của hướng trong mặt phẳng trước–lên của boss quay ¾ sang
/// trái: góc [deg] (0 = trước, 90 = lên), [sweep] xoay quanh trục đứng (+ =
/// sang trái nhân vật, tức về phía máy quay / phải màn hình).
Offset planeDir(double deg, [double sweep = 0]) {
  final a = deg * math.pi / 180, s = sweep * math.pi / 180;
  // Trước = trái màn hình (rút ngắn ¾), trái nhân vật = phải màn hình, hơi xuống.
  final fwd = Offset(-0.8 * math.cos(s) + 0.6 * math.sin(s), 0.15 * math.sin(s));
  return fwd * math.cos(a) + const Offset(0, -1) * math.sin(a);
}

/// Bóng tiếp đất mềm (bầu dục mờ dần).
void groundShadow(Canvas canvas, Offset c, double w, double h) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(1, h / w);
  canvas.drawCircle(
    Offset.zero,
    w / 2,
    Paint()
      ..shader = Gradient.radial(
        Offset.zero,
        w / 2,
        const [Color(0x88201A2A), Color(0x55201A2A), Color(0x00201A2A)],
        const [0, 0.6, 1],
      ),
  );
  canvas.restore();
}

/// Khớp khuỷu/gối 2D: hai đoạn dài [a], [b] từ [root] tới [end]; [bend] = 1
/// gập về bên trái hướng root→end (toạ độ màn hình), −1 về bên phải.
Offset joint2(Offset root, Offset end, double a, double b, double bend) {
  final d = end - root;
  final len = math.min(d.distance, a + b - 0.01);
  if (len < 0.01) return root + Offset(0, a);
  final x = (a * a - b * b + len * len) / (2 * len);
  final h = math.sqrt(math.max(0, a * a - x * x));
  final u = d / d.distance;
  final n = Offset(u.dy, -u.dx) * bend;
  return root + u * x + n * h;
}

/// Điểm trên đường tròn: góc [deg] độ (0 = phải, 90 = xuống, toạ độ màn hình).
Offset polar(Offset c, double deg, double r) {
  final a = deg * math.pi / 180;
  return c + Offset(math.cos(a), math.sin(a)) * r;
}

/// Đường mây/mác dải kiểu khắc gỗ.
Path cloudBand(Offset at, double len, double thick) {
  final p = Path()..moveTo(at.dx, at.dy);
  p.quadraticBezierTo(at.dx + len * 0.5, at.dy - thick, at.dx + len, at.dy);
  p.quadraticBezierTo(at.dx + len * 0.5, at.dy + thick * 0.4, at.dx, at.dy);
  return p..close();
}

/// Mặt đất chung: dải đất có khối sẫm dần về tiền cảnh.
void paintGround(Canvas canvas, Color top, Color bottom, Color rim) {
  canvas.drawRect(
    Rect.fromLTRB(0, stageGroundY - 4, 400, 260),
    Paint()
      ..shader = Gradient.linear(
        const Offset(0, stageGroundY - 4),
        const Offset(0, 260),
        [top, bottom],
      ),
  );
  canvas.drawLine(
    const Offset(0, stageGroundY - 3.5),
    const Offset(400, stageGroundY - 3.5),
    Paint()
      ..color = rim
      ..strokeWidth = 0.8,
  );
}
