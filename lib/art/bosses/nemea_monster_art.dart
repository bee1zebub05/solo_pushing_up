import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../battle_stage.dart';
import '../greek_monsters.dart';
import '../nemea_scene.dart';
import '../nemea_backdrop.dart';
import '../sprite_atlas.dart';
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

  /// Chỉ nạp sprite khi vào trận (chân dung ở màn chọn màn vẫn vẽ vector,
  /// không giữ ảnh 2048² của mọi quái trong bộ nhớ).
  @override
  Future<void> preload() async {
    await NemeaBackdrop.load();
    await SpriteAtlas.load(NemeaBossArt.birdSprite);
    for (final name in _spritesOf(kind)) {
      await SpriteAtlas.load(name);
    }
  }

  @override
  void dispose() {
    for (final name in _spritesOf(kind)) {
      SpriteAtlas.evict(name);
    }
    super.dispose();
  }

  /// Sprite Blender (assets/sprites/) mà mỗi loại quái dùng.
  static List<String> _spritesOf(NemeaMonster kind) => switch (kind) {
    NemeaMonster.birds || NemeaMonster.swarm => const ['stymphalian_bird'],
    NemeaMonster.spartoi => const ['spartoi'],
    NemeaMonster.stone || NemeaMonster.guard => const ['stone_soldier'],
    NemeaMonster.boar => const ['erymanthian_boar'],
    NemeaMonster.harpy => const ['harpy'],
    NemeaMonster.pack => const ['spartoi', 'stymphalian_bird'],
    NemeaMonster.hydra => const ['young_hydra'],
  };

  /// Nạp mọi sprite quái chương 1 (xem trước, kiểm thử).
  static Future<void> preloadSprites() async {
    for (final kind in NemeaMonster.values) {
      for (final name in _spritesOf(kind)) {
        await SpriteAtlas.load(name);
      }
    }
  }

  final NemeaMonster kind;

  /// Vị trí đứng của quái (giữa thân, mặt đất).
  static const _x = 318.0;

  /// Quái to hơn nhân vật cho ra dáng quái vật thần thoại: mọi hình của quái
  /// (kể cả dấu hiệu báo đòn, đàn chim) phóng [grow] quanh [_pivot].
  /// Hydra đã cao gần chạm trời: giữ cỡ (phóng thêm thì đầu ra khỏi khung).
  double get grow => switch (kind) {
    NemeaMonster.hydra => 1.0,
    NemeaMonster.harpy => 1.2,
    _ => 1.25,
  };

  /// Quái đứng phóng quanh chân. Chim phóng quanh tâm vùng bay; Harpy phóng
  /// quanh mép trên rồi hạ xuống [_drop] để cánh không ra khỏi khung.
  Offset get _pivot => switch (kind) {
    NemeaMonster.birds || NemeaMonster.swarm => const Offset(_x, 120),
    NemeaMonster.harpy => const Offset(_x, 0),
    _ => const Offset(_x, stageGroundY),
  };

  double get _drop => kind == NemeaMonster.harpy ? 18 : 0;

  @override
  Vector2 get target {
    final t = switch (kind) {
      NemeaMonster.birds || NemeaMonster.swarm => const Offset(_x - 10, 110),
      NemeaMonster.harpy => const Offset(_x - 6, 120),
      NemeaMonster.boar => const Offset(_x - 70, stageGroundY - 60),
      NemeaMonster.hydra => const Offset(_x - 40, stageGroundY - 110),
      _ => const Offset(_x - 8, stageGroundY - 70),
    };
    final p = _pivot + (t - _pivot) * grow;
    return Vector2(p.dx, p.dy + _drop);
  }

  /// Ánh sáng đổi theo hành trình: 1.1 sáng sớm trong, 1.9 hoàng hôn đỏ
  /// cam — càng gần hang sư tử trời càng về chiều (màn boss giữ ánh chiều).
  @override
  Color get gradeLight {
    final t = kind.index / (NemeaMonster.values.length - 1);
    return Color.lerp(const Color(0xFFE6F0FF), const Color(0xFFFFB27A), t)!;
  }

  @override
  Vector2 get portraitFocus => target;

  @override
  Object get artKey => (runtimeType, kind);

  @override
  double get portraitView => 110 * grow;

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
    final pivot = _pivot;
    canvas
      ..translate(pivot.dx, pivot.dy + _drop)
      ..scale(grow)
      ..translate(-pivot.dx, -pivot.dy);
    if (fall > 0) {
      canvas.translate(0, 16 * fall);
      canvas.saveLayer(
        const Rect.fromLTRB(150, -60, 440, 280),
        Paint()..color = Color.fromRGBO(0, 0, 0, 1 - fall * 0.85),
      );
    }
    switch (kind) {
      case NemeaMonster.birds:
        _birds(canvas, f, 3);
      case NemeaMonster.swarm:
        _birds(canvas, f, 5);
      case NemeaMonster.spartoi:
        _spartoiAt(canvas, f, _x, 1.35);
      case NemeaMonster.stone:
      case NemeaMonster.guard:
        final scale = kind == NemeaMonster.guard ? 1.5 : 1.35;
        // Lính đá canh hang (1.7) vỡ rồi ráp lại: trồi lên từ đống đá.
        final rebuilt = (f.time - _reviveAt) / 1.4;
        final rising =
            kind == NemeaMonster.guard && rebuilt >= 0 && rebuilt < 1;
        if (_sprite(
          canvas,
          'stone_soldier',
          f,
          _x,
          scale / 1.35,
          anim: rising ? 'rise' : null,
          animT: rebuilt.clamp(0.0, 1.0),
        )) {
          if (!rising) _spearGlint(canvas, f, scale / 1.35);
          break;
        }
        _at(
          canvas,
          _x,
          scale,
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
        // Vừa cướp vàng: diễn lại đòn quắp dù không tới lượt đe doạ.
        final steal = (f.time - _stealAt) / 1.5;
        final phase = f.attackPhase >= 0
            ? f.attackPhase
            : steal >= 0 && steal < 1
            ? steal
            : -1.0;
        // Sprite Harpy nhỏ hơn bản vector một chút: phóng cho cân với nhân vật.
        if (_sprite(canvas, 'harpy', f, _x, 1.3, attackPhase: phase)) {
          _harpyExtras(canvas, f, phase, 1.3);
          break;
        }
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
        _spartoiAt(canvas, f, _x + 10, 1.3);
        _birds(canvas, f, 2, offset: const Offset(-70, -38));
      case NemeaMonster.hydra:
        final heads = math.max(1, b.headsLeft).clamp(1, 3);
        if (SpriteAtlas.get('young_hydra') != null) {
          // Vũng độc báo đòn (bản vector tự vẽ trong thân).
          _at(
            canvas,
            _x,
            1.25,
            () => paintHydraPoisonTell(canvas, time: f.time, attack: f.attack),
          );
        }
        if (_sprite(
          canvas,
          'young_hydra',
          f,
          _x,
          1,
          idle: 'idle_h$heads',
          attack: 'attack_h$heads',
        )) {
          break;
        }
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

  /// Vẽ quái [name] bằng sprite Blender tại ([x], mặt đất), phóng [scale] so
  /// với cỡ đã render; `false` khi sprite chưa nạp (vẽ bản vector thay).
  bool _sprite(
    Canvas canvas,
    String name,
    BossFrame f,
    double x,
    double scale, {
    double? attackPhase,
    String idle = 'idle',
    String attack = 'attack',
    String? anim,
    double animT = 0,
  }) {
    final sprite = SpriteAtlas.get(name);
    if (sprite == null) return false;
    canvas.save();
    canvas.translate(x + 4 * f.hurt, stageGroundY);
    canvas.scale(scale);
    if (anim != null && sprite.has(anim)) {
      sprite.draw(canvas, anim, animT, flash: f.hurt);
    } else {
      _spriteMonster(
        canvas,
        sprite,
        f,
        time: f.time,
        attackPhase: attackPhase ?? f.attackPhase,
        idle: idle,
        attack: attack,
      );
    }
    canvas.restore();
    return true;
  }

  /// Báo trước cú đâm của lính đá bản sprite: mũi giáo loé sao tím (màu Trì
  /// Trệ) lúc lấy đà — bản vector tự vẽ trong hình. Vị trí mũi giáo lúc đứng
  /// và lúc giương hết đà theo pose() của tool/blender/stone_tripo.py (đơn
  /// vị sân khấu quanh chân).
  void _spearGlint(Canvas canvas, BossFrame f, double scale) {
    final p = f.attackPhase;
    if (p <= 0.05 || p >= 0.55) return;
    final k = math.sin((p - 0.05) / 0.5 * math.pi);
    final u = (p / 0.5).clamp(0.0, 1.0);
    final w = u * u * (3 - 2 * u);
    final tip = Offset.lerp(
      const Offset(-16, -143),
      const Offset(-31, -129),
      w,
    )!;
    canvas.save();
    canvas.translate(_x, stageGroundY);
    canvas.scale(scale);
    final r = 9 * k;
    final c = tip + const Offset(-4, 0);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r * 0.2, c.dy - r * 0.2)
        ..lineTo(c.dx + r, c.dy)
        ..lineTo(c.dx + r * 0.2, c.dy + r * 0.2)
        ..lineTo(c.dx, c.dy + r)
        ..lineTo(c.dx - r * 0.2, c.dy + r * 0.2)
        ..lineTo(c.dx - r, c.dy)
        ..lineTo(c.dx - r * 0.2, c.dy - r * 0.2)
        ..close(),
      Paint()..color = Color.fromRGBO(230, 216, 255, k),
    );
    canvas.restore();
  }

  /// Túi vàng (đang cướp) và sóng rít của Harpy bản sprite. Hệ toạ độ thân
  /// bản vector (mặt (-2, -26), móng (0, 32)) đặt khớp mặt (-12, -143) và
  /// móng (-12, -49) của sprite (pose() trong tool/blender/harpy_tripo.py,
  /// đơn vị sân khấu quanh chân); lúc sà xuống thân lao trái và hạ thấp.
  void _harpyExtras(Canvas canvas, BossFrame f, double phase, double scale) {
    final dive = phase < 0.45 || phase > 1
        ? 0.0
        : phase < 0.6
        ? (phase - 0.45) / 0.15
        : 1 - (phase - 0.6) / 0.4;
    canvas.save();
    canvas.translate(_x, stageGroundY);
    canvas.scale(scale);
    canvas.translate(-8.8 - 26 * dive, -100.9 + 20 * dive);
    canvas.scale(1.62);
    paintHarpyExtras(
      canvas,
      time: f.time,
      attack: math.max(f.attack, _recent(f.time, _stealAt, 1.5)),
      stealing: f.time - _stealAt < 2.5,
    );
    canvas.restore();
  }

  /// Trồi lên từ đất lúc mở màn và mỗi lần đứng dậy (0–1).
  double _rise(BossFrame f) {
    final sinceRevive = f.time - _reviveAt;
    return sinceRevive < 1.4
        ? (sinceRevive / 1.4).clamp(0.0, 1.0)
        : (f.time / 1.2).clamp(0.0, 1.0);
  }

  void _spartoiAt(Canvas canvas, BossFrame f, double x, double scale) {
    final rise = _rise(f);
    if (_sprite(
      canvas,
      'spartoi',
      f,
      x,
      scale / 1.35,
      anim: rise < 1 ? 'rise' : null,
      animT: rise,
    )) {
      return;
    }
    _at(canvas, x, scale, () => _spartoi(canvas, f));
  }

  void _spartoi(Canvas canvas, BossFrame f) {
    final rise = _rise(f);
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
    // Sprite: lấy đà = nửa đầu chuỗi ra đòn, lao húc = khung ra đòn.
    final phase = f.attackPhase >= 0
        ? f.attackPhase
        : lunge > 0
        ? 0.6
        : charge > 0.05
        ? 0.5 * charge
        : -1.0;
    // Thân sprite dài hơn bản vector: thu nhỏ, lùi vào trong khung.
    if (SpriteAtlas.get('erymanthian_boar') != null) {
      // Mũi tên đỏ báo húc (bản vector tự vẽ trong thân): chỉ theo cú húc
      // thật của cơ chế, không theo động tác doạ.
      _at(
        canvas,
        x,
        1.25,
        () => paintBoarChargeTell(canvas, time: f.time, charge: charge),
      );
    }
    if (_sprite(
      canvas,
      'erymanthian_boar',
      f,
      x - 22,
      0.82,
      attackPhase: phase,
    )) {
      return;
    }
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
      final scale = i == 0 ? 1.15 : 0.9 - i * 0.04;
      final sprite = SpriteAtlas.get('stymphalian_bird');
      if (sprite != null) {
        // Sprite tính sẵn theo đơn vị sân khấu, ứng với con đầu đàn (1,15).
        canvas.scale(scale / 1.15);
        _spriteMonster(
          canvas,
          sprite,
          f,
          time: f.time + i * 0.37,
          attackPhase: i == 0 ? f.attackPhase : -1,
        );
        canvas.restore();
        continue;
      }
      canvas.scale(scale);
      paintStymphalianBirdFast(
        canvas,
        time: f.time + i * 0.37,
        attack: i == 0 ? f.attack : f.attack * 0.4,
        hurt: f.hurt,
      );
      canvas.restore();
    }
  }

  /// Vẽ quái bằng sprite Blender: đang ra đòn thì theo tiến độ đòn
  /// ([attackPhase] 0–1), gục thì chuỗi `defeat` (nếu có), còn lại lặp `idle`
  /// theo chu kỳ ghi trong atlas. [idle] đổi tên chuỗi chờ (biến thể).
  void _spriteMonster(
    Canvas canvas,
    SpriteAtlas sprite,
    BossFrame f, {
    required double time,
    double attackPhase = -1,
    String idle = 'idle',
    String attack = 'attack',
  }) {
    final flash = f.hurt;
    if (f.defeat > 0 && sprite.has('defeat')) {
      sprite.draw(canvas, 'defeat', f.defeat, flash: flash);
    } else if (attackPhase >= 0 && sprite.has(attack)) {
      sprite.draw(canvas, attack, attackPhase, flash: flash);
    } else {
      final period = sprite.metaDouble('idlePeriod', 2.4);
      sprite.draw(canvas, idle, time / period, loop: true, flash: flash);
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
