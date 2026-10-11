import 'dart:math' as math;
import 'dart:ui' show PlatformDispatcher;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import 'hero_art.dart';
import 'hero_pose.dart';
import 'horse_art.dart';
import 'nemea_scene.dart';
import 'vector_style.dart';

/// Trạng thái trận truyền từ logic (lib/game/battle.dart) sang hình mỗi khung,
/// để cơ chế của boss nhìn thấy được (rules/dohoa.md nguyên tắc 4).
class StageBattleState {
  /// Mực nước 0–100 (Thuỷ Tinh).
  double water = 0;

  /// Số đầu còn lại / tổng số đầu, máu đầu đang chém 0–1 (Orochi).
  int headsLeft = 1;
  int totalHeads = 1;
  double headHp = 1;

  /// Mức lạnh 0–1: tăng khi nghỉ lâu, chạm 1 là đòn sau bị đóng băng (Fafnir).
  double cold = 0;

  /// Máu boss còn lại 0–1 (bụi Trì Trệ ở Nemea tan dần theo).
  double bossHp = 1;

  /// Lợn rừng lấy đà 0–1 (1 = húc ngay).
  double charge = 0;

  /// Số lần kẻ thù đã đứng dậy (Spartoi).
  int revives = 0;

  /// Số túi vàng Harpy đã cướp.
  int goldStolen = 0;
}

/// Thông số hoạt hình của boss tại một khung.
class BossFrame {
  const BossFrame({
    required this.time,
    required this.attack,
    required this.hurt,
    required this.glint,
    required this.defeat,
    required this.battle,
    this.attackPhase = -1,
  });

  final double time;

  /// Tiến độ đòn tấn công 0–1 (lấy đà → ra đòn → thu về); âm = không đánh.
  final double attackPhase;

  /// Động tác đe doạ/tấn công 0–1 (gầm, giơ vũ khí).
  final double attack;
  final double hurt;

  /// Vệt sáng khi đòn bị chặn 0–1; âm = không có.
  final double glint;
  final double defeat;
  final StageBattleState battle;
}

/// Hình của một boss và bối cảnh của nó.
abstract class BossArt {
  /// Điểm các đòn đánh bay tới (toạ độ sân khấu 400×260).
  Vector2 get target;

  /// Phần tĩnh của phông nền (vẽ một lần thành Picture).
  void paintBackdrop(Canvas canvas);

  /// Phần tĩnh dùng trong trận. Mặc định là cả phông nền; boss có parallax
  /// (2,5D) chỉ để lại lớp xa nhất ở đây, các lớp khác vẽ trong [paintScene].
  void paintStageBackdrop(Canvas canvas) => paintBackdrop(canvas);

  /// Phần động của phông nền (mây, mưa, sóng xa…).
  void paintAmbient(Canvas canvas, double time);

  /// Phông nền đổi theo diễn biến trận (ví dụ bụi Nemea tan theo máu
  /// boss). Mặc định chỉ vẽ phần động.
  void paintScene(Canvas canvas, double time, StageBattleState battle) =>
      paintAmbient(canvas, time);

  /// Boss, vẽ theo toạ độ sân khấu.
  void paintBoss(Canvas canvas, BossFrame f);

  /// Lớp phía trước nhân vật (ví dụ nước dâng). Mặc định không có.
  void paintForeground(Canvas canvas, BossFrame f) {}

  /// Tâm và bề rộng khung chân dung (thẻ kỳ công ở trang chủ): mặt boss.
  Vector2 get portraitFocus => target;
  double get portraitView => 96;

  /// Ánh sáng chủ đạo của cảnh, phủ lên toàn sân khấu để thống nhất tông.
  Color get gradeLight => const Color(0xFFFFE3C0);

  /// Màu hạt toé ra khi trúng đòn.
  List<Color> get hitColors => const [Color(0xFFFFE082), Color(0xFFFFFFFF)];
}

/// Sân khấu chiến đấu chạy bằng Flame: người kế nhiệm hít đất theo góc tay
/// thật của người chơi, mỗi rep phóng một luồng sức mạnh vào boss.
class BattleStageGame extends FlameGame {
  BattleStageGame({
    required this.boss,
    bool cloak = false,
    bool shield = false,
    bool sword = false,
    this.horse = false,
    HeroLook look = const HeroLook(),
  }) : _hero = _HeroComponent(
         cloak: cloak,
         look: look,
         shield: shield,
         sword: sword,
       ),
       super(
         camera: CameraComponent.withFixedResolution(
           width: stageSize.width,
           height: stageSize.height,
         ),
       );

  final BossArt boss;

  /// Đã có Ngựa chín hồng mao: phi vào đứng cạnh nhân vật khi thắng.
  bool horse;
  final _HeroComponent _hero;
  late final _BossComponent _boss = _BossComponent(boss, battle);
  final battle = StageBattleState();
  final _random = math.Random();

  /// Khựng hình (hitstop) còn lại, giây: thế giới gần như đứng yên vài
  /// khung khi đòn trúng để cú đánh "nặng" (game feel, Vlambeer).
  double _hitstop = 0;

  /// Độ bão hoà toàn sân khấu (màu rực kiểu fantasy).
  static const saturation = 1.25;

  @override
  void render(Canvas canvas) {
    if (!StageQuality.saturationLayer) {
      super.render(canvas);
      return;
    }
    canvas.saveLayer(null, Paint()..colorFilter = saturationFilter(saturation));
    super.render(canvas);
    canvas.restore();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Ảnh chụp sẵn lớp tĩnh khớp điểm ảnh thật của màn hình (không mờ).
    final dpr = PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1;
    final k = math.min(size.x / stageSize.width, size.y / stageSize.height);
    if (k > 0) StageQuality.rasterScale = (k * dpr).clamp(1.5, 6.0);
  }

  @override
  void update(double dt) {
    if (_hitstop > 0) {
      _hitstop -= dt;
      super.update(dt * 0.08);
      return;
    }
    super.update(dt);
  }

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    world.addAll([
      _SceneComponent(boss, battle),
      _boss,
      _hero,
      _ForegroundComponent(_boss),
    ]);
  }

  /// Cập nhật theo bộ đếm mỗi khung hình. [elbowAngle] null = đang đứng
  /// (chưa vào tư thế); có giá trị = đang chống đẩy với góc đó.
  void updatePlayer({double? elbowAngle, bool onKnees = false}) {
    _hero
      ..elbowAngle = elbowAngle
      ..onKnees = onKnees
      ..cold = battle.cold;
  }

  /// Rep được tính: luồng sức mạnh bay tới boss.
  void hit({bool critical = false}) {
    _hero.glow = 1;
    _launch(critical: critical, blocked: false);
  }

  /// Rep bị chặn: luồng sức mạnh dội ra.
  void blocked() => _launch(critical: false, blocked: true);

  void victory() {
    battle.bossHp = 0;
    _hero.victorious = true;
    _boss.defeated = true;
    if (horse) world.add(_HorseComponent());
    _burst(
      boss.target,
      count: 40,
      colors: const [Color(0xFFFFD54F), Color(0xFFFFF59D), Color(0xFFFF8A65)],
    );
  }

  /// Lần đầu nhận Ngựa chín hồng mao: cho ngựa phi vào ngay.
  void arriveHorse() {
    if (horse) return;
    horse = true;
    world.add(_HorseComponent());
  }

  /// Khoác Áo choàng da sư tử ngay trên sân khấu (lần đầu thắng Nemea):
  /// bộ da bay từ xác sư tử theo vòng cung tới vai nhân vật rồi khoác lên.
  void equipCloak() {
    world.add(
      _PeltFlight(
        from: boss.target.clone(),
        to: _hero.chest,
        onArrive: () {
          _hero.cloak = true;
          _burst(
            _hero.chest,
            count: 30,
            colors: const [Color(0xFFFFE082), Color(0xFFFFFFFF)],
          );
          world.add(_RewardBanner('ÁO CHOÀNG DA SƯ TỬ'));
        },
      ),
    );
  }

  void reset() {
    _hero.victorious = false;
    _boss.defeated = false;
  }

  void _launch({required bool critical, required bool blocked}) {
    final bolt = _Bolt(critical: critical)..position = _hero.chest;
    world.add(bolt);
    bolt.add(
      MoveToEffect(
        boss.target +
            Vector2(_random.nextDouble() * 8, _random.nextDouble() * 10),
        EffectController(duration: 0.22, curve: Curves.easeIn),
        onComplete: () {
          bolt.removeFromParent();
          _impact(critical: critical, blocked: blocked);
        },
      ),
    );
  }

  void _impact({required bool critical, required bool blocked}) {
    if (blocked) {
      _boss.glint = 0;
      world.add(_BlockedBadge()..position = boss.target + Vector2(-30, -38));
      _burst(
        boss.target,
        count: 14,
        colors: const [Color(0xFFB0BEC5), Color(0xFFFFF59D)],
        bounceBack: true,
      );
      return;
    }
    _boss.hurt = 1;
    world.add(_ImpactFlash(critical: critical)..position = boss.target.clone());
    // Hạt sức mạnh bay ngược về người chơi (cảm giác mạnh lên sau mỗi rep).
    for (var i = 0; i < (critical ? 6 : 3); i++) {
      world.add(
        _PowerMote(
          from: boss.target.clone(),
          to: _hero.chest,
          delay: i * 0.06,
          seed: _random.nextDouble(),
        ),
      );
    }
    _boss.add(
      MoveByEffect(
        Vector2(critical ? 10 : 6, 0),
        EffectController(duration: 0.06, reverseDuration: 0.12),
      ),
    );
    _burst(
      boss.target,
      count: critical ? 36 : 16,
      colors: critical
          ? const [Color(0xFFFF7043), Color(0xFFFFD54F), Color(0xFFFFFFFF)]
          : boss.hitColors,
    );
    _hitstop = critical ? 0.09 : 0.05;
    // Rung khung: đòn thường rung nhẹ một nhịp, chí mạng rung mạnh 3 nhịp.
    camera.viewfinder.add(
      MoveByEffect(
        critical ? Vector2(5, 3) : Vector2(2, 1),
        EffectController(
          duration: 0.04,
          reverseDuration: 0.04,
          repeatCount: critical ? 3 : 1,
        ),
      ),
    );
  }

  /// Hạt toé ra từ [at] (hệ thống hạt của Flame).
  void _burst(
    Vector2 at, {
    required int count,
    required List<Color> colors,
    bool bounceBack = false,
  }) {
    world.add(
      ParticleSystemComponent(
        position: at.clone(),
        particle: Particle.generate(
          count: count,
          lifespan: 0.7,
          generator: (i) {
            final angle = bounceBack
                ? math.pi + (_random.nextDouble() - 0.5) * 1.6
                : _random.nextDouble() * math.pi * 2;
            final speed = 60 + _random.nextDouble() * 120;
            final color = colors[i % colors.length];
            final radius = 1.5 + _random.nextDouble() * 2;
            return AcceleratedParticle(
              speed: Vector2(math.cos(angle), math.sin(angle)) * speed,
              acceleration: Vector2(0, 220),
              child: ComputedParticle(
                renderer: (canvas, particle) => canvas.drawCircle(
                  Offset.zero,
                  radius * (1 - particle.progress * 0.5),
                  Paint()
                    ..color = color.withValues(alpha: 1 - particle.progress),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SceneComponent extends Component {
  _SceneComponent(this.boss, this.battle);

  final BossArt boss;
  final StageBattleState battle;
  double _time = 0;

  /// Phần tĩnh chụp sẵn thành ảnh một lần, mỗi khung chỉ vẽ ảnh + phần động.
  late final _backdrop = RasterLayer(
    boss.paintStageBackdrop,
    bounds: Offset.zero & stageSize,
  );

  @override
  void update(double dt) => _time += dt;

  @override
  void render(Canvas canvas) {
    _backdrop.paint(canvas);
    boss.paintScene(canvas, _time, battle);
  }

  @override
  void onRemove() {
    _backdrop.dispose();
    super.onRemove();
  }
}

class _BossComponent extends PositionComponent {
  _BossComponent(this.art, this.battle);

  final BossArt art;
  final StageBattleState battle;
  double _time = 0;
  double hurt = 0;
  double glint = -1;
  double _attack = 0;
  double _defeat = 0;
  bool defeated = false;

  /// Đếm ngược tới lần đe doạ tiếp theo; [_attackAge] là thời gian đã diễn.
  double _nextAttack = 1.5;
  double _attackAge = _attackLength;
  static const _attackLength = 1.2;
  final _random = math.Random();

  BossFrame get frame => BossFrame(
    time: _time,
    attack: _attack,
    hurt: hurt,
    glint: glint,
    defeat: _defeat,
    battle: battle,
    attackPhase: !defeated && _attackAge < _attackLength
        ? _attackAge / _attackLength
        : -1,
  );

  @override
  void update(double dt) {
    _time += dt;
    hurt = math.max(0, hurt - dt / 0.35);
    if (glint >= 0) {
      glint += dt / 0.45;
      if (glint > 1) glint = -1;
    }
    _defeat = defeated
        ? math.min(1, _defeat + dt / 0.9)
        : math.max(0, _defeat - dt / 0.5);

    _nextAttack -= dt;
    _attackAge += dt;
    if (_nextAttack <= 0 && !defeated) {
      _nextAttack = 7 + _random.nextDouble() * 5;
      _attackAge = 0;
    }
    _attack = !defeated && _attackAge < _attackLength
        ? math.sin(math.pi * _attackAge / _attackLength)
        : 0;
  }

  @override
  void render(Canvas canvas) => art.paintBoss(canvas, frame);
}

class _ForegroundComponent extends Component {
  _ForegroundComponent(this.boss);

  final _BossComponent boss;

  /// Lớp chỉnh màu toàn cảnh tĩnh → chụp sẵn thành ảnh (một lần vẽ ảnh/khung).
  late final _grade = RasterLayer(
    (c) => paintStageGrade(c, Offset.zero & stageSize, light: boss.art.gradeLight),
    bounds: Offset.zero & stageSize,
  );

  @override
  void onRemove() {
    _grade.dispose();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    boss.art.paintForeground(canvas, boss.frame);
    if (!StageQuality.grade) return;
    _grade.paint(canvas);
  }
}

enum _HeroMode { standing, plank, victory }

class _HeroComponent extends Component {
  _HeroComponent({
    required this.cloak,
    required this.look,
    this.shield = false,
    this.sword = false,
  });

  bool cloak;
  final bool shield;
  final bool sword;
  final HeroLook look;
  double? elbowAngle;
  bool onKnees = false;
  bool victorious = false;
  double glow = 0;
  double cold = 0;

  double _time = 0;
  double _angle = 175;
  _HeroMode _mode = _HeroMode.standing;
  HeroPose _shown = HeroPose.standing();
  HeroPose? _from;
  double _blend = 1;

  /// Ngực nhân vật: điểm xuất phát của đòn đánh, điểm khoác áo.
  Vector2 get chest {
    final p = Offset.lerp(
      _shown[HeroJoint.shoulder],
      _shown[HeroJoint.head],
      0.4,
    )!;
    return Vector2(p.dx, p.dy);
  }

  @override
  void update(double dt) {
    _time += dt;
    glow = math.max(0, glow - dt / 0.4);
    final target = elbowAngle;
    if (target != null) {
      // Làm mượt vì camera chỉ ~20 khung hình/giây.
      _angle += (target - _angle) * (1 - math.exp(-dt * 18));
    }

    final mode = victorious
        ? _HeroMode.victory
        : target != null
        ? _HeroMode.plank
        : _HeroMode.standing;
    if (mode != _mode) {
      _mode = mode;
      _from = _shown;
      _blend = 0;
    }

    final pose = switch (_mode) {
      _HeroMode.standing => HeroPose.standing(breath: _time / 3),
      _HeroMode.plank => HeroPose.plank(_angle, onKnees: onKnees),
      _HeroMode.victory => HeroPose.victory(pump: _time / 1.2),
    };
    final from = _from;
    if (from != null && _blend < 1) {
      _blend = math.min(1, _blend + dt / 0.45);
      _shown = HeroPose.lerp(from, pose, Curves.easeInOut.transform(_blend));
    } else {
      _shown = pose;
    }
  }

  @override
  void render(Canvas canvas) => paintHero(
    canvas,
    _shown,
    look: look,
    cloak: cloak,
    glow: glow,
    // Xuống càng sâu càng gắng sức; thắng thì cười tươi.
    effort: _mode == _HeroMode.plank
        ? ((165 - _angle) / 80).clamp(0.0, 1.0)
        : 0,
    joy: _mode == _HeroMode.victory ? 1 : 0,
    frost: _mode == _HeroMode.victory ? 0 : cold,
    shield: shield,
    sword: sword,
    time: _time,
  );
}

/// Ngựa chín hồng mao phi từ ngoài vào đứng cạnh nhân vật ăn mừng.
class _HorseComponent extends Component {
  double _time = 0;

  @override
  void update(double dt) => _time += dt;

  @override
  void render(Canvas canvas) {
    const arrive = 1.4;
    final t = (_time / arrive).clamp(0.0, 1.0);
    final x = -70 + (210 - -70) * Curves.easeOut.transform(t);
    canvas.save();
    canvas.translate(x, stageGroundY);
    canvas.scale(1.15);
    paintHorse(canvas, time: _time, gallop: 1 - t);
    canvas.restore();
  }
}

/// Luồng sức mạnh bay từ người chơi tới boss: sao chổi năng lượng có đuôi
/// theo hướng bay, lõi trắng, tia lấp lánh (chí mạng: lửa cam).
class _Bolt extends PositionComponent {
  _Bolt({required this.critical});

  final bool critical;
  final _trail = <Offset>[];
  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    _trail.add(Offset(position.x, position.y));
    if (_trail.length > 8) _trail.removeAt(0);
  }

  @override
  void render(Canvas canvas) {
    final r = critical ? 8.0 : 5.5;
    final color = critical ? const Color(0xFFFF7043) : const Color(0xFFFFD54F);
    // Đuôi: vẽ theo toạ độ cục bộ (vị trí cũ trừ vị trí hiện tại).
    final here = Offset(position.x, position.y);
    if (_trail.length > 1) {
      final tail = Path()..moveTo(0, 0);
      for (var i = _trail.length - 1; i >= 0; i--) {
        final p = _trail[i] - here;
        tail.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        tail,
        Paint()
          ..color = color.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 1.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawPath(
        tail,
        Paint()
          ..color = const Color(0xCCFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.5
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(
      Offset.zero,
      r * 2.2,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(Offset.zero, r, Paint()..color = color);
    canvas.drawCircle(
      Offset.zero,
      r * 0.55,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    // Tia lấp lánh bốn cánh xoay.
    canvas.save();
    canvas.rotate(_age * 9);
    final spark = Paint()..color = const Color(0xEEFFFFFF);
    for (var i = 0; i < 4; i++) {
      canvas.rotate(math.pi / 2);
      canvas.drawPath(
        Path()
          ..moveTo(-1.2, 0)
          ..lineTo(0, -r * 2.1)
          ..lineTo(1.2, 0)
          ..close(),
        spark,
      );
    }
    canvas.restore();
  }
}

/// Huy hiệu "BỊ CHẶN!" bật lên khi rep sai form bị da boss chặn: khiên
/// thép viền vàng + chữ đậm có viền, phóng to nảy rồi bay lên và mờ dần.
class _BlockedBadge extends PositionComponent {
  static const _life = 1.1;
  double _age = 0;

  static final TextPainter _label = TextPainter(
    text: const TextSpan(
      text: 'BỊ CHẶN!',
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
        color: Color(0xFFFFF3C4),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  static final TextPainter _labelOutline = TextPainter(
    text: TextSpan(
      text: 'BỊ CHẶN!',
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF2B1D16),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = _age / _life;
    final pop = Curves.elasticOut.transform((t / 0.35).clamp(0.0, 1.0));
    final alpha = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
    canvas.save();
    canvas.translate(0, -14 * t);
    canvas.rotate(-0.12);
    canvas.scale(0.4 + 0.6 * pop);
    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0)),
    );
    // Khiên thép.
    final shield = Path()
      ..moveTo(-12, -12)
      ..lineTo(12, -12)
      ..lineTo(12, 0)
      ..quadraticBezierTo(10, 10, 0, 15)
      ..quadraticBezierTo(-10, 10, -12, 0)
      ..close();
    final dx = -(_label.width + 30) / 2;
    canvas.translate(dx + 12, 0);
    canvas.drawPath(
      shield,
      Paint()
        ..color = const Color(0xFF2B1D16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      shield,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE3E9EE), Color(0xFF8D9AA6)],
        ).createShader(const Rect.fromLTRB(-12, -12, 12, 15)),
    );
    canvas.drawPath(
      shield,
      Paint()
        ..color = const Color(0xFFE8B83A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    // Vết đòn dội ra trên khiên.
    canvas.drawLine(
      const Offset(-5, -5),
      const Offset(5, 6),
      Paint()
        ..color = const Color(0xFF5A6570)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
    final textAt = Offset(16, -_label.height / 2);
    _labelOutline.paint(canvas, textAt);
    _label.paint(canvas, textAt);
    canvas.restore();
    canvas.restore();
  }
}

/// Bộ da sư tử bay từ boss tới nhân vật: phấp phới, kéo vệt sáng vàng.
class _PeltFlight extends Component {
  _PeltFlight({required this.from, required this.to, required this.onArrive});

  final Vector2 from;
  final Vector2 to;
  final void Function() onArrive;
  static const _duration = 1.4;
  double _age = 0;
  final _trail = <Offset>[];

  Offset _at(double t) {
    final e = Curves.easeInOut.transform(t);
    final p = Offset.lerp(Offset(from.x, from.y), Offset(to.x, to.y), e)!;
    return p + Offset(0, -70 * math.sin(math.pi * e));
  }

  @override
  void update(double dt) {
    _age += dt;
    _trail.add(_at((_age / _duration).clamp(0.0, 1.0)));
    if (_trail.length > 14) _trail.removeAt(0);
    if (_age >= _duration) {
      onArrive();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / _duration).clamp(0.0, 1.0);
    for (var i = 0; i < _trail.length; i++) {
      final k = i / _trail.length;
      canvas.drawCircle(
        _trail[i],
        2 + 6 * k,
        Paint()..color = Color.fromRGBO(255, 214, 110, 0.35 * k),
      );
    }
    final at = _at(t);
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(math.sin(_age * 9) * 0.25);
    canvas.scale(0.9 - 0.3 * t);
    canvas.drawCircle(
      Offset.zero,
      34,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x88FFE9A0), Color(0x00FFE9A0)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 34)),
    );
    _paintPelt(canvas, _age);
    canvas.restore();
  }
}

/// Bộ da sư tử bay phấp phới: tấm da rủ có bốn vạt chân và móng, bờm
/// ngọn lửa, đầu nghiêng với nanh trên (không phải mặt tròn hoạt hình).
void _paintPelt(Canvas canvas, double time) {
  const hide = Color(0xFFC99140);
  const mane = Color(0xFF8E3714);
  final wave = math.sin(time * 12);
  // Tấm da: mép dưới gợn sóng, hai vạt chân trước/sau rủ xuống.
  final skin = Path()
    ..moveTo(-16, -4)
    ..quadraticBezierTo(-4, -10, 14, -6)
    ..quadraticBezierTo(22, 2, 20 + wave * 2, 16)
    ..lineTo(24 + wave * 3, 28)
    ..lineTo(17, 26)
    ..lineTo(12, 20)
    ..quadraticBezierTo(4, 24 - wave * 2, -4, 20)
    ..lineTo(-8, 30 - wave * 3)
    ..lineTo(-14, 28)
    ..lineTo(-12, 18)
    ..quadraticBezierTo(-20, 8, -16, -4)
    ..close();
  shadedPath(canvas, skin, hide, PartFrame.world, shadow: 3);
  furStrokes(
    canvas,
    skin,
    darken(hide, 0.32),
    dir: const Offset(0.1, 1),
    count: 34,
    length: 6,
    width: 0.9,
    seed: 11,
  );
  // Móng ở hai vạt chân.
  final claw = Paint()
    ..color = const Color(0xFFFFF4DC)
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;
  for (final p in [Offset(22 + wave * 3, 28), Offset(-11, 29 - wave * 3)]) {
    for (final dx in [-2.0, 0.0, 2.0]) {
      canvas.drawLine(p + Offset(dx, 0), p + Offset(dx - 0.8, 3), claw);
    }
  }
  // Bờm ngọn lửa quanh cổ.
  final tufts = Path();
  for (var i = 0; i < 9; i++) {
    final a = math.pi * (0.85 + 1.0 * i / 8);
    final dir = Offset(math.cos(a), math.sin(a));
    final n = Offset(-dir.dy, dir.dx);
    final base = const Offset(-6, -8) + dir * 8;
    final tip = base + dir * (9 + (i.isEven ? 3 : 0)) + const Offset(2, -1);
    tufts
      ..moveTo(base.dx + n.dx * 3.5, base.dy + n.dy * 3.5)
      ..quadraticBezierTo(tip.dx + n.dx, tip.dy + n.dy, tip.dx, tip.dy)
      ..quadraticBezierTo(
        base.dx - n.dx,
        base.dy - n.dy,
        base.dx - n.dx * 3.5,
        base.dy - n.dy * 3.5,
      )
      ..close();
  }
  tufts.addOval(Rect.fromCircle(center: const Offset(-6, -8), radius: 9));
  shadedPath(canvas, tufts, mane, PartFrame.world, shadow: 2.5);
  // Đầu nghiêng: mõm dài, mắt nhắm, nanh trên.
  final head = Path()
    ..moveTo(-12, -12)
    ..quadraticBezierTo(-4, -18, 6, -14)
    ..quadraticBezierTo(14, -12, 15, -7)
    ..lineTo(8, -4)
    ..quadraticBezierTo(-4, -2, -12, -12)
    ..close();
  shadedPath(canvas, head, hide, PartFrame.world, shadow: 2);
  canvas.drawPath(
    Path()
      ..moveTo(-1, -12)
      ..quadraticBezierTo(2, -10.5, 5, -11.5),
    Paint()
      ..color = VectorStyle.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round,
  );
  for (final x in [9.0, 12.0]) {
    canvas.drawPath(
      Path()
        ..moveTo(x - 1, -5.5)
        ..lineTo(x + 1, -5.5)
        ..lineTo(x, -1.5)
        ..close(),
      Paint()..color = const Color(0xFFFFF6DE),
    );
  }
  canvas.drawCircle(
    const Offset(14.5, -8.5),
    1.4,
    Paint()..color = VectorStyle.outline,
  );
}

/// Dải băng phần thưởng bung ra giữa trời rồi mờ dần.
class _RewardBanner extends Component {
  _RewardBanner(String text)
    : _label = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: Color(0xFF3A1E0C),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  final TextPainter _label;
  static const _life = 3.2;
  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final open = Curves.easeOutBack.transform((_age / 0.5).clamp(0.0, 1.0));
    final fade = _age < _life - 0.6 ? 1.0 : (_life - _age) / 0.6;
    final w = (_label.width + 40) * open;
    const h = 24.0;
    final c = Offset(stageSize.width / 2, 34);
    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(0, 0, 0, fade.clamp(0.0, 1.0)),
    );
    // Hai đuôi băng gấp.
    for (final side in [-1.0, 1.0]) {
      final x = c.dx + side * w / 2;
      final tail = Path()
        ..moveTo(x, c.dy - h / 2 + 4)
        ..lineTo(x + side * 18, c.dy - h / 2 + 4)
        ..lineTo(x + side * 12, c.dy + 4)
        ..lineTo(x + side * 18, c.dy + h / 2 + 4)
        ..lineTo(x, c.dy + h / 2 + 4)
        ..close();
      canvas.drawPath(tail, Paint()..color = const Color(0xFF9A6A12));
    }
    final band = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: w, height: h),
      const Radius.circular(3),
    );
    canvas.drawRRect(band.inflate(2), Paint()..color = const Color(0xFF2B1D16));
    canvas.drawRRect(
      band,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE9A0), Color(0xFFE8B83A)],
        ).createShader(band.outerRect),
    );
    if (open > 0.8) {
      _label.paint(canvas, c - Offset(_label.width / 2, _label.height / 2));
    }
    canvas.restore();
  }
}

/// Khoảnh khắc trúng đòn (impact frame): vòng chấn động nở ra và các tia
/// sáng toả quanh điểm trúng; chí mạng to hơn, màu lửa.
class _ImpactFlash extends PositionComponent {
  _ImpactFlash({required this.critical});

  final bool critical;
  static const _life = 0.28;
  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / _life).clamp(0.0, 1.0);
    final e = Curves.easeOut.transform(t);
    final size = critical ? 46.0 : 30.0;
    final color = critical ? const Color(0xFFFF8A50) : const Color(0xFFFFF3C4);
    final fade = 1 - t;
    // Vòng chấn động.
    canvas.drawCircle(
      Offset.zero,
      size * (0.3 + 0.9 * e),
      Paint()
        ..color = color.withValues(alpha: 0.9 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * fade + 0.5,
    );
    // Lõi loé trắng (chỉ vài khung đầu).
    if (t < 0.35) {
      canvas.drawCircle(
        Offset.zero,
        size * 0.45 * (1 - t),
        Paint()..color = Color.fromRGBO(255, 255, 255, 0.9 * (1 - t / 0.35)),
      );
    }
    // Tia sáng toả nhọn.
    final ray = Paint()..color = color.withValues(alpha: fade);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + 0.3;
      final dir = Offset(math.cos(a), math.sin(a));
      final n = Offset(-dir.dy, dir.dx);
      final inner = dir * size * (0.35 + 0.6 * e);
      final outer = dir * size * (0.6 + (i.isEven ? 0.9 : 0.6) * e);
      canvas.drawPath(
        Path()
          ..moveTo(inner.dx + n.dx * 2, inner.dy + n.dy * 2)
          ..lineTo(outer.dx, outer.dy)
          ..lineTo(inner.dx - n.dx * 2, inner.dy - n.dy * 2)
          ..close(),
        ray,
      );
    }
  }
}

/// Hạt sáng vàng bay theo đường cong từ boss về ngực người chơi.
class _PowerMote extends Component {
  _PowerMote({
    required this.from,
    required this.to,
    required this.delay,
    required this.seed,
  });

  final Vector2 from;
  final Vector2 to;
  final double delay;
  final double seed;
  static const _flight = 0.6;
  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= delay + _flight) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = ((_age - delay) / _flight).clamp(0.0, 1.0);
    if (_age < delay) return;
    final e = Curves.easeInCubic.transform(t);
    final a = Offset(from.x, from.y);
    final b = Offset(to.x, to.y);
    final lift = -40 - 40 * seed;
    final p = Offset.lerp(a, b, e)! + Offset(0, lift * math.sin(math.pi * e));
    final r = 2.4 * (1 - t * 0.5);
    canvas.drawCircle(
      p,
      r * 3,
      Paint()..color = Color.fromRGBO(255, 214, 90, 0.3 * (1 - t * 0.5)),
    );
    canvas.drawCircle(p, r, Paint()..color = const Color(0xFFFFF3C4));
  }
}
