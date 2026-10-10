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
import 'lion_art.dart';
import 'nemea_scene.dart';

/// Vị trí và tỉ lệ Sư tử Nemea trên sân khấu 400×260.
const lionX = 335.0;
const lionScale = 0.72;

/// Đầu sư tử (toạ độ sân khấu) — đích của các đòn đánh.
final _lionHead = Vector2(
  lionX - 72 * lionScale,
  stageGroundY - 96 * lionScale,
);

/// Sân khấu Kỳ công 1 chạy bằng Flame: người kế nhiệm hít đất theo góc tay
/// thật của người chơi, mỗi rep phóng một luồng sức mạnh vào Sư tử Nemea.
class NemeaStageGame extends FlameGame {
  NemeaStageGame({bool cloak = false, HeroLook look = const HeroLook()})
    : _hero = _HeroComponent(cloak: cloak, look: look),
      super(
        camera: CameraComponent.withFixedResolution(
          width: stageSize.width,
          height: stageSize.height,
        ),
      );

  final _HeroComponent _hero;
  final _lion = _LionComponent();
  final _random = math.Random();

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    world.addAll([_SceneComponent(), _lion, _hero]);
  }

  /// Cập nhật theo bộ đếm mỗi khung hình. [elbowAngle] null = đang đứng
  /// (chưa vào tư thế); có giá trị = đang chống đẩy với góc đó.
  void updatePlayer({double? elbowAngle, bool onKnees = false}) {
    _hero
      ..elbowAngle = elbowAngle
      ..onKnees = onKnees;
  }

  /// Rep được tính: luồng sức mạnh bay tới sư tử.
  void hit({bool critical = false}) {
    _hero.glow = 1;
    _launch(critical: critical, blocked: false);
  }

  /// Rep bị da không xuyên thủng chặn: luồng sức mạnh dội ra.
  void blocked() => _launch(critical: false, blocked: true);

  void victory() {
    _hero.victorious = true;
    _lion.defeated = true;
    _burst(
      _lionHead,
      count: 40,
      colors: const [Color(0xFFFFD54F), Color(0xFFFFF59D), Color(0xFFFF8A65)],
    );
  }

  /// Khoác Áo choàng da sư tử ngay trên sân khấu (lần đầu thắng).
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
    _lion.defeated = false;
  }

  void _launch({required bool critical, required bool blocked}) {
    final from = _hero.chest;
    final bolt = _Bolt(critical: critical, blocked: blocked)..position = from;
    world.add(bolt);
    bolt.add(
      MoveToEffect(
        _lionHead +
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
      _lion.glint = 0;
      _burst(
        _lionHead,
        count: 14,
        colors: const [Color(0xFFB0BEC5), Color(0xFFFFF59D)],
        bounceBack: true,
      );
      return;
    }
    _lion.hurt = 1;
    _lion.add(
      MoveByEffect(
        Vector2(critical ? 10 : 6, 0),
        EffectController(duration: 0.06, reverseDuration: 0.12),
      ),
    );
    _burst(
      _lionHead,
      count: critical ? 36 : 16,
      colors: critical
          ? const [Color(0xFFFF7043), Color(0xFFFFD54F), Color(0xFFFFFFFF)]
          : const [Color(0xFFFFE082), Color(0xFFFFFFFF)],
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
  double _time = 0;

  /// Phần tĩnh vẽ một lần, mỗi khung chỉ vẽ lại mây và cỏ.
  late final Picture _backdrop = () {
    final recorder = PictureRecorder();
    paintNemeaBackdrop(Canvas(recorder));
    return recorder.endRecording();
  }();

  @override
  void update(double dt) => _time += dt;

  @override
  void render(Canvas canvas) {
    canvas.drawPicture(_backdrop);
    paintNemeaAmbient(canvas, time: _time);
  }

  @override
  void onRemove() {
    _backdrop.dispose();
    super.onRemove();
  }
}

class _LionComponent extends PositionComponent {
  _LionComponent()
    : super(
        position: Vector2(lionX, stageGroundY),
        scale: Vector2.all(lionScale),
      );

  double _time = 0;
  double hurt = 0;
  double glint = -1;
  double _mouth = 0;
  double _defeat = 0;
  bool defeated = false;

  /// Đếm ngược tới lần gầm tiếp theo; [_roarAge] là thời gian đã gầm.
  double _nextRoar = 1.5;
  double _roarAge = _roarLength;
  static const _roarLength = 1.2;
  final _random = math.Random();

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

    // Gầm đe doạ định kỳ khi còn chiến đấu.
    _nextRoar -= dt;
    _roarAge += dt;
    if (_nextRoar <= 0 && !defeated) {
      _nextRoar = 7 + _random.nextDouble() * 5;
      _roarAge = 0;
    }
    _mouth = !defeated && _roarAge < _roarLength
        ? math.sin(math.pi * _roarAge / _roarLength)
        : 0;
  }

  @override
  void render(Canvas canvas) => paintLion(
    canvas,
    LionState(
      time: _time,
      mouth: _mouth,
      hurt: hurt,
      glint: glint,
      defeat: _defeat,
    ),
  );
}

enum _HeroMode { standing, plank, victory }

class _HeroComponent extends Component {
  _HeroComponent({required this.cloak, required this.look});

  bool cloak;
  final HeroLook look;
  double? elbowAngle;
  bool onKnees = false;
  bool victorious = false;
  double glow = 0;

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
  void render(Canvas canvas) =>
      paintHero(canvas, _shown, look: look, cloak: cloak, glow: glow);
}

/// Luồng sức mạnh bay từ người chơi tới sư tử.
class _Bolt extends PositionComponent {
  _Bolt({required this.critical, required this.blocked});

  final bool critical;
  final bool blocked;

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
