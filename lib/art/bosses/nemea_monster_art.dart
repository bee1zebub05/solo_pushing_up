import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../battle_stage.dart';
import '../greek_monsters.dart';
import '../nemea_scene.dart';
import 'nemea_boss.dart';

/// Loại quái của các màn thường Kỳ công 1.
enum NemeaMonster {
  birds,
  swarm,
  spartoi,
  stone,
  boar,
  harpy,
  pack,
  hydra,
  guard,
}

/// Màn quái thường ở Thung lũng Nemea: cùng phông, bụi Trì Trệ, đàn chim
/// như trận sư tử, nhưng kẻ thù là quái của màn ([NemeaMonster]). Cơ chế
/// hiện lên hình: Spartoi trồi dậy, lợn rừng lấy đà, Harpy quắp vàng.
class NemeaMonsterArt extends NemeaBossArt {
  NemeaMonsterArt(this.kind);

  final NemeaMonster kind;

  /// Vị trí đứng của quái (giữa thân, mặt đất).
  static const _x = 318.0;

  @override
  Vector2 get target => switch (kind) {
    NemeaMonster.birds || NemeaMonster.swarm => Vector2(_x - 10, 110),
    NemeaMonster.harpy => Vector2(_x - 6, 120),
    NemeaMonster.boar => Vector2(_x - 70, stageGroundY - 60),
    NemeaMonster.hydra => Vector2(_x - 40, stageGroundY - 110),
    _ => Vector2(_x - 8, stageGroundY - 70),
  };

  @override
  Vector2 get portraitFocus => target;

  @override
  double get portraitView => 110;

  // Theo dõi thay đổi để diễn hoạt cảnh (Spartoi trồi lại, Harpy vừa cướp).
  int _revives = 0;
  double _reviveAt = -10;
  int _gold = 0;
  double _stealAt = -10;
  double _headHp = 1;
  double _regrowAt = -10;

  @override
  void paintBoss(Canvas canvas, BossFrame f) {
    final b = f.battle;
    if (b.revives != _revives) {
      _revives = b.revives;
      _reviveAt = f.time;
    }
    if (b.goldStolen != _gold) {
      _gold = b.goldStolen;
      _stealAt = f.time;
    }
    // Đầu đang chém hồi máu (đứt combo) = mọc lại.
    if (b.headHp > _headHp + 0.2) _regrowAt = f.time;
    _headHp = b.headHp;
    final fall = f.defeat.clamp(0.0, 1.0);
    // Gục: chìm xuống đất và mờ dần.
    canvas.save();
    if (fall > 0) {
      canvas.translate(0, 16 * fall);
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, 1 - fall * 0.85),
      );
    }
    switch (kind) {
      case NemeaMonster.birds:
        _birds(canvas, f, 3);
      case NemeaMonster.swarm:
        _birds(canvas, f, 5);
      case NemeaMonster.spartoi:
        _at(canvas, _x, 1.35, () => _spartoi(canvas, f));
      case NemeaMonster.stone:
      case NemeaMonster.guard:
        _at(
          canvas,
          _x,
          kind == NemeaMonster.guard ? 1.5 : 1.35,
          () => paintStoneSoldier(
            canvas,
            time: f.time,
            attack: f.attack,
            hurt: f.hurt,
          ),
        );
      case NemeaMonster.boar:
        _boar(canvas, f);
      case NemeaMonster.harpy:
        _at(
          canvas,
          _x,
          1.5,
          () => paintHarpy(
            canvas,
            time: f.time,
            attack: math.max(f.attack, _recent(f.time, _stealAt, 1.5)),
            hurt: f.hurt,
            stealing: f.time - _stealAt < 2.5,
          ),
        );
      case NemeaMonster.pack:
        _at(canvas, _x + 10, 1.3, () => _spartoi(canvas, f));
        _birds(canvas, f, 2, offset: const Offset(-40, -10));
      case NemeaMonster.hydra:
        _at(
          canvas,
          _x,
          1.25,
          () => paintYoungHydra(
            canvas,
            time: f.time,
            attack: f.attack,
            hurt: f.hurt,
            heads: math.max(1, b.headsLeft),
            regrow: f.time - _regrowAt < 1.5 ? (f.time - _regrowAt) / 1.5 : -1,
          ),
        );
    }
    if (fall > 0) canvas.restore();
    canvas.restore();
    if (f.glint >= 0) _blockFlash(canvas, f.glint);
  }

  double _recent(double now, double at, double len) {
    final t = (now - at) / len;
    return t < 0 || t > 1 ? 0 : math.sin(t * math.pi);
  }

  void _at(Canvas canvas, double x, double scale, void Function() draw) {
    canvas.save();
    canvas.translate(x, stageGroundY);
    canvas.scale(scale);
    draw();
    canvas.restore();
  }

  void _spartoi(Canvas canvas, BossFrame f) {
    // Trồi lên từ đất lúc mở màn và mỗi lần đứng dậy.
    final sinceRevive = f.time - _reviveAt;
    final rise = sinceRevive < 1.4
        ? (sinceRevive / 1.4).clamp(0.0, 1.0)
        : (f.time / 1.2).clamp(0.0, 1.0);
    paintSpartoi(
      canvas,
      time: f.time,
      attack: f.attack,
      hurt: f.hurt,
      rise: rise,
    );
  }

  void _boar(Canvas canvas, BossFrame f) {
    final charge = f.battle.charge;
    // Lấy đà: lùi dần; tới 1 thì lao về phía người chơi rồi quay lại.
    final lunge = charge >= 0.98 ? 1.0 : 0.0;
    final x = _x + 14 * charge - 120 * lunge;
    _at(
      canvas,
      x,
      1.25,
      () => paintErymanthianBoar(
        canvas,
        time: f.time,
        attack: math.max(f.attack, charge),
        hurt: f.hurt,
      ),
    );
  }

  void _birds(
    Canvas canvas,
    BossFrame f,
    int count, {
    Offset offset = Offset.zero,
  }) {
    final t = target;
    for (var i = 0; i < count; i++) {
      final a = f.time * (0.9 + i * 0.13) + i * 2.1;
      final at =
          Offset(t.x, t.y) +
          offset +
          Offset(math.cos(a) * (18 + i * 6), math.sin(a * 1.4) * (10 + i * 3));
      canvas.save();
      canvas.translate(at.dx + 6 * f.hurt, at.dy);
      canvas.scale(i == 0 ? 1.15 : 0.9 - i * 0.04);
      paintStymphalianBird(
        canvas,
        time: f.time + i * 0.37,
        attack: i == 0 ? f.attack : f.attack * 0.4,
        hurt: f.hurt,
      );
      canvas.restore();
    }
  }

  /// Rep sai form ở màn lính đá: khiên lục giác như trận sư tử.
  void _blockFlash(Canvas canvas, double g) {
    final at = Offset(target.x, target.y);
    final fade = 1 - g;
    final r = 22 + 26 * g;
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..color = Color.fromRGBO(220, 200, 255, 0.9 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    for (var k = 0; k < 6; k++) {
      final a = k * math.pi / 3;
      canvas.drawLine(
        at + Offset(math.cos(a), math.sin(a)) * r * 0.5,
        at + Offset(math.cos(a), math.sin(a)) * r,
        Paint()
          ..color = Color.fromRGBO(240, 230, 255, 0.8 * fade)
          ..strokeWidth = 1.6,
      );
    }
  }
}
