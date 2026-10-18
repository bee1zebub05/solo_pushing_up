import 'dart:math' as math;
import 'dart:ui';

import '../battle_stage.dart';
import '../nemea_scene.dart' show stageGroundY;
import '../sprite_atlas.dart';
import 'choreo.dart';
import 'choreo_data.dart';

/// Boss hình người chương Nhật dựng bằng Blender (`tool/blender/<tên>_boss.py`,
/// atlas `idle` / `attack` / `attack2` / `defeat`): chế độ 3D vẽ sprite, chế độ
/// 2.5D hoặc lúc chưa nạp vẽ bản vector [paintVector] — cùng chỗ đứng, cùng cỡ.
///
/// Hai đòn luân phiên, mỗi đòn có dấu hiệu báo trước riêng; tư thế theo biên
/// đạo chung với Blender (`choreo_data.dart` sinh từ tool/blender/choreo/*.json,
/// rules/dohoa.md mục 14): bản vector đọc cùng kênh (dịch hông, ngả, vặn, góc
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

  @override
  void paintBoss(Canvas canvas, BossFrame f) {
    final fall = f.defeat.clamp(0.0, 1.0);
    final phase = f.attackPhase;
    final move = moveFor(phase);
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
        final fast = phase > hit - 0.1 && phase < hit + 0.1;
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
    if (attacking) paintStrike(canvas, f, move, phase - impactOf(move));
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
