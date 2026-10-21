import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../battle_stage.dart';
import '../greek_monsters.dart';
import '../nemea_scene.dart';
import '../nemea_backdrop.dart';
import '../sprite_atlas.dart';
import '../vector_style.dart' show fillPaint;
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

  /// Lính đá trồi từ dưới đất (động tác `rise`, tool/blender/stone_tripo.py).
  static const stoneRiseSeconds = 2.6;

  @override
  double get introSeconds =>
      kind == NemeaMonster.stone || kind == NemeaMonster.guard
      ? stoneRiseSeconds
      : 0;

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
        // Trồi lên từ dưới đất: lúc mở màn (1.3 và 1.7), và khi lính đá canh
        // hang (1.7) vỡ rồi ráp lại.
        final rebuilt = (f.time - _reviveAt) / stoneRiseSeconds;
        final riseT = kind == NemeaMonster.guard && rebuilt >= 0 && rebuilt < 1
            ? rebuilt
            : f.time / stoneRiseSeconds;
        final rising = riseT >= 0 && riseT < 1 && fall == 0;
        if (rising) _risingEarth(canvas, riseT, scale / 1.35, front: false);
        if (_sprite(
          canvas,
          'stone_soldier',
          f,
          _x,
          scale / 1.35,
          anim: rising ? 'rise' : null,
          animT: riseT.clamp(0.0, 1.0),
          snapStrike: true,
        )) {
          if (rising) {
            _risingEarth(canvas, riseT, scale / 1.35, front: true);
          } else {
            _spearGlint(canvas, f, scale / 1.35);
          }
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
        if (_sprite(
          canvas,
          'harpy',
          f,
          _x,
          1.3,
          attackPhase: phase,
          snapStrike: true,
        )) {
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
          snapStrike: true,
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
    bool snapStrike = false,
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
        snapStrike: snapStrike,
      );
    }
    canvas.restore();
    return true;
  }

  /// Đất quanh chân lính đá lúc trồi lên (tiến độ [t] 0–1 của `rise`): rung,
  /// nứt toả ra, mở hố tối; đất đá văng lên rơi xuống theo trọng lực, bụi
  /// tung; ụ đất mép trước che chân. [front] = lớp vẽ sau sprite (nứt, ụ, đá
  /// văng, bụi); lớp sau (hố) vẽ trước sprite. Đơn vị sân khấu quanh chân.
  void _risingEarth(
    Canvas canvas,
    double t,
    double scale, {
    required bool front,
  }) {
    double ease(double x) {
      final u = x.clamp(0.0, 1.0);
      return u * u * (3 - 2 * u);
    }

    final open = ease((t - 0.06) / 0.16) * (1 - ease((t - 0.86) / 0.14));
    canvas.save();
    canvas.translate(_x, stageGroundY);
    canvas.scale(scale);
    const c = Offset(-4, 1);
    if (!front) {
      if (open > 0) {
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.scale(1, 0.22);
        canvas.drawCircle(
          Offset.zero,
          36 * open,
          Paint()
            ..shader = Gradient.radial(
              Offset.zero,
              36 * open,
              [
                Color.fromRGBO(22, 16, 12, 0.95 * open),
                Color.fromRGBO(60, 44, 30, 0.7 * open),
                const Color(0x003C2C1E),
              ],
              const [0, 0.7, 1],
            ),
        );
        canvas.restore();
      }
      canvas.restore();
      return;
    }
    // Nứt toả ra trước khi mũi giáo ló lên.
    final crack = ease(t / 0.16) * (1 - ease((t - 0.5) / 0.3));
    if (crack > 0) {
      final ink = Paint()
        ..color = Color.fromRGBO(30, 22, 16, 0.8 * crack)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k < 6; k++) {
        final a = k * math.pi / 3 + 0.4;
        final len = 14 + 30 * ease(t / 0.16) + 6 * (k % 2);
        final d = Offset(math.cos(a), 0.22 * math.sin(a));
        final mid = c + d * len * 0.5 + Offset(-d.dy * 8, d.dx * 2);
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy)
            ..lineTo(mid.dx, mid.dy)
            ..lineTo(c.dx + d.dx * len, c.dy + d.dy * len),
          ink,
        );
      }
    }
    // Ụ đất mép trước (che chân đang trồi).
    if (open > 0) {
      // Một gò đất liền, mép trên lổn nhổn (không phải chuỗi hạt tròn).
      const bumps = [5.0, 8.0, 6.0, 9.0, 7.0, 8.5, 5.5];
      final half = 40 * open;
      final base = c.dy + 5;
      final mound = Path()..moveTo(c.dx - half, base);
      for (var k = 0; k < bumps.length; k++) {
        final x0 = c.dx - half + 2 * half * k / bumps.length;
        final x1 = c.dx - half + 2 * half * (k + 1) / bumps.length;
        mound.quadraticBezierTo(
          (x0 + x1) / 2,
          base - bumps[k] * 1.6 * open,
          x1,
          base - (k == bumps.length - 1 ? 0 : 2.5 * open),
        );
      }
      mound.close();
      canvas.drawPath(
        mound,
        Paint()
          ..shader = Gradient.linear(
            Offset(0, base - 14 * open),
            Offset(0, base),
            const [Color(0xFF8C7558), Color(0xFF4E3B2A)],
          ),
      );
      // Vài hòn đá vỡ nằm trên gò.
      for (final (dx, dy, r) in const [
        (-22.0, -6.0, 2.6),
        (-4.0, -9.0, 2.0),
        (14.0, -7.0, 3.0),
        (27.0, -3.0, 1.8),
      ]) {
        final q = r * open;
        canvas.drawPath(
          Path()
            ..moveTo(c.dx + dx * open - q, base + dy * open + 0.5 * q)
            ..lineTo(c.dx + dx * open - 0.3 * q, base + dy * open - 0.7 * q)
            ..lineTo(c.dx + dx * open + q, base + dy * open - 0.2 * q)
            ..lineTo(c.dx + dx * open + 0.6 * q, base + dy * open + 0.6 * q)
            ..close(),
          fillPaint(const Color(0xFF9C9078)),
        );
      }
    }
    // Đất đá văng: mỗi cục bật lên ở một lúc trong pha phá đất, rơi theo
    // trọng lực rồi mất khi chạm đất.
    final rnd = math.Random(7);
    final sec = t * stoneRiseSeconds;
    for (var k = 0; k < 22; k++) {
      final t0 = (0.1 + 0.5 * rnd.nextDouble()) * stoneRiseSeconds;
      final vx = (rnd.nextDouble() - 0.5) * 90;
      final vy = -(60 + 70 * rnd.nextDouble());
      final r = 0.9 + 1.6 * rnd.nextDouble();
      final stone = rnd.nextBool();
      final spin = (rnd.nextDouble() - 0.5) * 14;
      final x0 = (rnd.nextDouble() - 0.5) * 40;
      final age = sec - t0;
      if (age < 0) continue;
      final y = c.dy - 4 + vy * age + 0.5 * 300 * age * age;
      if (y > c.dy + 2) continue;
      final x = c.dx + x0 + vx * age;
      // Mảnh vụn góc cạnh xoay theo đà bay.
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(spin * age);
      canvas.drawPath(
        Path()
          ..moveTo(-r, -0.4 * r)
          ..lineTo(0.2 * r, -r)
          ..lineTo(r, -0.1 * r)
          ..lineTo(0.4 * r, 0.8 * r)
          ..lineTo(-0.7 * r, 0.6 * r)
          ..close(),
        fillPaint(stone ? const Color(0xFFB8AC96) : const Color(0xFF5E4836)),
      );
      canvas.restore();
    }
    // Bụi tung theo nhịp phá đất (mũi giáo, bàn tay, vai).
    for (final b in const [0.12, 0.24, 0.5]) {
      final u = (t - b) / 0.45;
      if (u < 0 || u > 1) continue;
      final r = 14 + 46 * ease(u);
      final dust = Offset(c.dx, c.dy - 4 - 10 * u);
      canvas.drawCircle(
        dust,
        r,
        Paint()
          ..shader = Gradient.radial(dust, r, [
            Color.fromRGBO(196, 182, 160, 0.4 * (1 - u)),
            const Color(0x00C4B6A0),
          ]),
      );
    }
    canvas.restore();
  }

  /// Điểm theo từng khung đòn ghi trong atlas [atlas] (khoá [key]: danh sách
  /// [x, y] đơn vị sân khấu, sinh lúc render Blender), nội suy tại tiến độ
  /// [phase] như khung ảnh; null nếu chưa nạp / không có.
  Offset? _track(String atlas, String key, double phase) {
    final list = SpriteAtlas.get(atlas)?.meta[key] as List?;
    if (list == null || list.length < 2 || phase < 0) return null;
    Offset at(int i) {
      final t = list[i] as List;
      return Offset((t[0] as num).toDouble(), (t[1] as num).toDouble());
    }

    final pos = phase.clamp(0.0, 1.0) * (list.length - 1);
    final i = math.min(pos.floor(), list.length - 2);
    return Offset.lerp(at(i), at(i + 1), pos - i)!;
  }

  /// Báo trước cú đâm của lính đá bản sprite: mũi giáo loé sao tím (màu Trì
  /// Trệ) lúc lấy đà — bản vector tự vẽ trong hình. Mũi giáo từng khung đòn
  /// ghi trong atlas (`spearTip`, đơn vị sân khấu quanh chân — spear_tips()
  /// của tool/blender/stone_tripo.py), nội suy theo tiến độ như khung ảnh.
  void _spearGlint(Canvas canvas, BossFrame f, double scale) {
    final p = f.attackPhase;
    if (p <= 0.05 || p >= 0.55) return;
    final tip = _track('stone_soldier', 'spearTip', p);
    if (tip == null) return;
    final k = math.sin((p - 0.05) / 0.5 * math.pi);
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
    // Độ dời đầu từng khung đòn (`headTrack`, head_track() của harpy_tripo.py).
    final d = _track('harpy', 'headTrack', phase) ?? Offset.zero;
    canvas.save();
    canvas.translate(_x, stageGroundY);
    canvas.scale(scale);
    canvas.translate(-8.8 + d.dx, -100.9 + d.dy);
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

  /// Lúc cú húc thật vừa chạm (charge tự về 0 ngay khi cơ chế chấm húc):
  /// diễn nốt pha thu về và lùi về chỗ cũ.
  double _boarHitAt = -10;
  double _boarCharge = 0;

  void _boar(Canvas canvas, BossFrame f) {
    final charge = f.battle.charge;
    if (charge == 0 && _boarCharge > 0.9) _boarHitAt = f.time;
    _boarCharge = charge;
    // Báo húc (charge 0 → 1 trong 2,5 s): lấy đà chậm (pha 0–0,49 trong 74%
    // đầu, cào đất, lùi dồn sức), rồi bật lao đúng nhịp đòn (0,49 → 0,6) để
    // chạm đúng lúc cơ chế chấm húc; sau đó thu về 0,7 s. Lao trên sân khấu
    // (55 đơn vị, cộng bước lao trong sprite: nanh dừng trước nhân vật) đi mượt
    // theo pha, không nhảy cóc.
    final after = (f.time - _boarHitAt) / 0.7;
    double phase;
    double lunge;
    double backUp;
    if (charge > 0) {
      phase = charge < 0.74
          ? 0.49 * charge / 0.74
          : 0.49 + 0.11 * (charge - 0.74) / 0.26;
      final u = ((phase - 0.5) / 0.1).clamp(0.0, 1.0);
      lunge = u * u * (3 - 2 * u);
      backUp = math.min(1.0, charge / 0.74) * (1 - lunge);
    } else if (after >= 0 && after < 1) {
      phase = 0.6 + 0.4 * after;
      final u = 1 - after;
      lunge = u * u * (3 - 2 * u);
      backUp = 0;
    } else {
      phase = f.attackPhase;
      lunge = 0;
      backUp = 0;
    }
    final x = _x + 14 * backUp - 55 * lunge;
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
      snapStrike: true,
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
    bool snapStrike = false,
  }) {
    final flash = f.hurt;
    if (f.defeat > 0 && sprite.has('defeat')) {
      sprite.draw(canvas, 'defeat', f.defeat, flash: flash);
    } else if (attackPhase >= 0 && sprite.has(attack)) {
      // [snapStrike]: quanh pha ra đòn (0,48–0,7) không hoà hai khung kề
      // nhau — vũ khí lao nhanh, hoà thì thành hai cây chồng nhau.
      sprite.draw(
        canvas,
        attack,
        attackPhase,
        flash: flash,
        snap: snapStrike && attackPhase > 0.48 && attackPhase < 0.7,
      );
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
