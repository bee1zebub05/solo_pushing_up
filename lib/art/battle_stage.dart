import 'dart:math' as math;
import 'dart:ui' show Picture, PictureRecorder;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import 'hero_art.dart';
import 'hero_pose.dart';
import 'nemea_scene.dart';

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
  });

  final double time;

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

  /// Phần động của phông nền (mây, mưa, sóng xa…).
  void paintAmbient(Canvas canvas, double time);

  /// Boss, vẽ theo toạ độ sân khấu.
  void paintBoss(Canvas canvas, BossFrame f);

  /// Lớp phía trước nhân vật (ví dụ nước dâng). Mặc định không có.
  void paintForeground(Canvas canvas, BossFrame f) {}

  /// Tâm và bề rộng khung chân dung (thẻ kỳ công ở trang chủ): mặt boss.
  Vector2 get portraitFocus => target;
  double get portraitView => 96;

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
  final _HeroComponent _hero;
  late final _BossComponent _boss = _BossComponent(boss, battle);
  final battle = StageBattleState();
  final _random = math.Random();

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    world.addAll([
      _SceneComponent(boss),
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
    _hero.victorious = true;
    _boss.defeated = true;
    _burst(
      boss.target,
      count: 40,
      colors: const [Color(0xFFFFD54F), Color(0xFFFFF59D), Color(0xFFFF8A65)],
    );
  }

  /// Khoác Áo choàng da sư tử ngay trên sân khấu (lần đầu thắng Nemea).
  void equipCloak() {
    _hero.cloak = true;
    _burst(
      _hero.chest,
      count: 30,
      colors: const [Color(0xFFFFE082), Color(0xFFFFFFFF)],
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
      _burst(
        boss.target,
        count: 14,
        colors: const [Color(0xFFB0BEC5), Color(0xFFFFF59D)],
        bounceBack: true,
      );
      return;
    }
    _boss.hurt = 1;
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
    if (critical) {
      camera.viewfinder.add(
        MoveByEffect(
          Vector2(5, 3),
          EffectController(
            duration: 0.04,
            reverseDuration: 0.04,
            repeatCount: 3,
          ),
        ),
      );
    }
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
  _SceneComponent(this.boss);

  final BossArt boss;
  double _time = 0;

  /// Phần tĩnh vẽ một lần, mỗi khung chỉ vẽ lại phần động.
  late final Picture _backdrop = () {
    final recorder = PictureRecorder();
    boss.paintBackdrop(Canvas(recorder));
    return recorder.endRecording();
  }();

  @override
  void update(double dt) => _time += dt;

  @override
  void render(Canvas canvas) {
    canvas.drawPicture(_backdrop);
    boss.paintAmbient(canvas, _time);
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

  @override
  void render(Canvas canvas) => boss.art.paintForeground(canvas, boss.frame);
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
  );
}

/// Luồng sức mạnh bay từ người chơi tới boss.
class _Bolt extends PositionComponent {
  _Bolt({required this.critical});

  final bool critical;

  @override
  void render(Canvas canvas) {
    final r = critical ? 9.0 : 6.0;
    final color = critical ? const Color(0xFFFF7043) : const Color(0xFFFFD54F);
    canvas.drawCircle(
      Offset.zero,
      r * 2,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(Offset.zero, r, Paint()..color = color);
    canvas.drawCircle(
      Offset.zero,
      r * 0.5,
      Paint()..color = const Color(0xFFFFFFFF),
    );
  }
}
