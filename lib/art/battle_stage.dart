import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui show Gradient;
import 'dart:ui' show PlatformDispatcher;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../game/battle.dart';
import '../game/items.dart';
import 'hero_art.dart';
import 'hero_pose.dart';
import 'hero_sprite.dart';
import 'horse_art.dart';
import 'motion.dart';
import 'nemea_scene.dart';
import 'stage_shaders.dart';
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

  /// Chép trạng thái trận vừa tính ([Battle.view]).
  void sync(BattleView view) {
    water = view.water ?? 0;
    headsLeft = view.headsLeft;
    totalHeads = view.heads;
    headHp = view.headHp / view.headMaxHp;
    cold = view.cold;
    bossHp = view.hpFraction;
    charge = view.charge;
    revives = view.revives;
    goldStolen = view.goldStolen;
  }
}

/// Tín hiệu âm thanh sân khấu gửi ra màn trận ([BattleStageGame.onCue]).
enum StageCue {
  /// Boss bắt đầu lấy đà: người chơi đang nhìn sàn phải nghe được đòn tới.
  tell,

  /// Đòn của người chơi trúng boss.
  hit,

  /// Boss sang pha cuối (máu < 40%): gầm lên.
  rage,

  /// Boss gục.
  defeat,
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

  /// `false` khi boss tự vẽ toàn bộ phông trong [paintScene] (sân khấu khỏi
  /// giữ một ảnh phông toàn màn hình thừa).
  bool get hasStageBackdrop => true;

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

  /// Khoá phân biệt hình boss/quái (bộ đệm chân dung): mặc định theo lớp;
  /// lớp vẽ nhiều loại quái phải trả khoá riêng cho từng loại.
  Object get artKey => runtimeType;
  double get portraitView => 96;

  /// Ánh sáng chủ đạo của cảnh, phủ lên toàn sân khấu để thống nhất tông.
  Color get gradeLight => const Color(0xFFFFE3C0);

  /// Điểm chân boss: tâm co–giãn khi thở/lấy đà/vồ ([BossBodyMotion]).
  Offset get bodyAnchor => Offset(target.x, 236);

  /// `true` khi hình tự diễn đòn 3 pha (sư tử): sân khấu chỉ thêm thở và
  /// nảy khi trúng đòn, không ngả/lao thân thêm.
  bool get ownsAttackMotion => false;

  /// `true` khi hình tự vẽ khói Trì Trệ rời xác lúc gục (sư tử).
  bool get ownsDefeatSmoke => false;

  /// Sương Trì Trệ (shader GPU) sát mặt đất: màu (a = độ đậm tối đa) và hệ
  /// số mật độ. Sương tan theo máu boss — vùng đất được giải phóng dần.
  Color get mistColor => const Color(0xA86A4C8C);
  double get mistAmount => 1;

  /// Màu viền cảnh khi boss sắp gục và nổi giận (pha cuối, máu < 40%).
  Color get rageColor => const Color(0xFFC62828);

  /// Nạp tài nguyên trước khi vào trận (sprite Blender…); sân khấu chờ
  /// xong rồi mới dựng cảnh, để không loé bản vector rồi mới đổi hình.
  Future<void> preload() async {}

  /// Trả tài nguyên GPU riêng của hình (lớp shader…) khi rời trận.
  void dispose() {}

  /// Tên bộ âm riêng của boss (`assets/sounds/boss_<key>_tell|hit.wav`,
  /// tạo bằng tool/gen_boss_sounds.py); null = không có.
  String? get soundKey => null;

  /// Màu hạt toé ra khi trúng đòn.
  List<Color> get hitColors => const [Color(0xFFFFE082), Color(0xFFFFFFFF)];
}

/// Sân khấu chiến đấu chạy bằng Flame: người kế nhiệm hít đất theo góc tay
/// thật của người chơi, mỗi rep phóng một luồng sức mạnh vào boss.
/// Đo thời gian ghi lệnh vẽ (CPU) từng phần sân khấu — chỉ bật trong bench
/// máy thật (lib/dev/perf_bench_main.dart) để tìm phần nào tốn.
abstract final class StageProfile {
  static bool enabled = false;
  static final micros = <String, int>{};
  static int frames = 0;
  static final _sw = Stopwatch();

  static void run(String part, void Function() draw) {
    if (!enabled) return draw();
    final start = _sw.elapsedMicroseconds;
    _sw.start();
    draw();
    micros[part] = (micros[part] ?? 0) + _sw.elapsedMicroseconds - start;
  }

  static void reset() {
    micros.clear();
    frames = 0;
  }
}

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

  /// Sân khấu với nhân vật mang các vật phẩm người chơi đã có.
  factory BattleStageGame.equipped({
    required BossArt boss,
    required Iterable<Item> items,
    HeroLook look = const HeroLook(),
  }) {
    bool has(Item item) => items.any((i) => i.id == item.id);
    return BattleStageGame(
      boss: boss,
      cloak: has(nemeanPelt),
      shield: has(dragonScaleShield),
      sword: has(kusanagi),
      horse: has(nineManeHorse),
      look: look,
    );
  }

  final BossArt boss;

  /// Đã có Ngựa chín hồng mao: phi vào đứng cạnh nhân vật khi thắng.
  bool horse;
  final _HeroComponent _hero;
  late final _BossComponent _boss = _BossComponent(
    boss,
    battle,
    onAttackStart: () => onCue?.call(StageCue.tell),
    onStrike: _struck,
  );

  /// Đòn của boss chạm tới: nhân vật giật lùi (lò xo) + rung khung nhẹ.
  void _struck() {
    _hero.struck();
    camera.viewfinder.add(
      MoveByEffect(
        Vector2(-3, 2),
        EffectController(duration: 0.05, reverseDuration: 0.07),
      ),
    );
  }

  /// Nhận tín hiệu âm thanh (báo đòn, trúng đòn) để màn trận phát tiếng.
  void Function(StageCue cue)? onCue;
  final battle = StageBattleState();
  final _random = math.Random();

  /// Khựng hình (hitstop) còn lại, giây: thế giới gần như đứng yên vài
  /// khung khi đòn trúng để cú đánh "nặng" (game feel, Vlambeer).
  double _hitstop = 0;

  /// Độ bão hoà toàn sân khấu (màu rực kiểu fantasy).
  static const saturation = 1.25;

  @override
  void render(Canvas canvas) {
    StageProfile.frames++;
    final layer = StageQuality.saturationLayer;
    // Khoanh lớp đúng vùng sân khấu: `null` để engine tự tính giới hạn, có
    // thể thành cả màn hình (đo trên máy: tốn thêm 2–4 ms/khung).
    if (layer) {
      canvas.saveLayer(
        Offset.zero & canvasSize.toSize(),
        Paint()..colorFilter = saturationFilter(saturation),
      );
    }
    StageProfile.run('render', () => super.render(canvas));
    if (layer) canvas.restore();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Ảnh chụp sẵn lớp tĩnh khớp điểm ảnh thật của màn hình (không mờ).
    final dpr = PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1;
    final k = math.min(size.x / stageSize.width, size.y / stageSize.height);
    if (k > 0) RasterBudget.shared.scale = (k * dpr).clamp(1.5, 6.0);
  }

  @override
  void onRemove() {
    // Rời trận: Flame chỉ gọi onRemove của game, không gỡ cây component —
    // phải tự gỡ để onRemove của từng phần chạy (trả sprite, lớp shader,
    // phông chụp sẵn), nếu không mỗi trận giữ lại atlas của quái trước.
    dispose();
    // Trả bộ nhớ GPU của mọi ảnh chụp sẵn (vào trận sau chụp lại).
    RasterBudget.shared.purge();
    super.onRemove();
  }

  /// Đã vào pha nổi giận (máu < 40%) — chỉ diễn khoảnh khắc chuyển pha một lần.
  bool _raging = false;

  @override
  void update(double dt) {
    final raging = battle.bossHp < 0.4 && battle.bossHp > 0 && !_boss.defeated;
    if (raging && !_raging) _enrage();
    _raging = raging;
    if (_hitstop > 0) {
      _hitstop -= dt;
      super.update(dt * 0.08);
      return;
    }
    super.update(dt);
  }

  @override
  Future<void> onLoad() async {
    await StageShaders.load();
    await boss.preload();
    // Không chờ: chưa nạp xong thì nhân vật vẽ bản vector vài khung đầu.
    unawaited(HeroSprites.load(_hero.look));
    camera.viewfinder.anchor = Anchor.topLeft;
    world.addAll([
      _SceneComponent(boss, battle),
      _boss,
      _hero,
      _ForegroundComponent(_boss),
      _transition,
    ]);
  }

  late final _transition = _TransitionComponent();

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
    _transition.victory();
    onCue?.call(StageCue.defeat);
    if (horse) world.add(_HorseComponent());
    _burst(
      boss.target,
      count: 40,
      colors: const [Color(0xFFFFD54F), Color(0xFFFFF59D), Color(0xFFFF8A65)],
    );
  }

  /// Vừa nhận [item] (lần đầu qua kỳ công): diễn ngay trên sân khấu nếu
  /// vật phẩm có hiệu ứng riêng.
  void receive(Item item) {
    if (item.id == nemeanPelt.id) {
      equipCloak();
    } else if (item.id == nineManeHorse.id) {
      arriveHorse();
    }
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

  /// Khoảnh khắc chuyển pha: boss gầm, thân phồng lên, khung rung mạnh, màn
  /// loé đỏ — người chơi biết trận đã sang hồi cuối.
  void _enrage() {
    onCue?.call(StageCue.rage);
    _boss.motion.enrage();
    _transition.rage();
    camera.viewfinder.add(
      MoveByEffect(
        Vector2(4, 2),
        EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 5),
      ),
    );
  }

  /// Cho boss ra đòn ngay (demo/quay video có kịch bản, test).
  void triggerAttack() => _boss.triggerAttack();

  void reset() {
    _raging = false;
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
    onCue?.call(StageCue.hit);
    world.add(_ImpactFlash(critical: critical)..position = boss.target.clone());
    // Ánh sáng động: đòn trúng soi sáng thân boss và nền quanh đó.
    world.add(
      _ImpactLight(
        critical: critical,
        color: critical ? const Color(0xFFFF8A50) : boss.hitColors.first,
      )..position = boss.target.clone(),
    );
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
    // Giật lùi bằng lò xo (nảy rồi về chỗ) thay cho dời cứng.
    _boss.motion.hit(critical: critical);
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

  final _mist = ShaderLayer(StageShaders.mist, width: 200, height: 130);

  /// Mật độ sương hiện tại: đuổi theo máu boss trong ~1 giây (tan mượt).
  double _mistDensity = -1;

  @override
  void update(double dt) {
    _time += dt;
    final target = battle.bossHp.clamp(0.0, 1.0) * boss.mistAmount;
    _mistDensity = _mistDensity < 0
        ? target
        : _mistDensity + (target - _mistDensity) * math.min(1, dt * 2.5);
  }

  @override
  void render(Canvas canvas) {
    StageProfile.run('backdrop', () {
      if (boss.hasStageBackdrop) _backdrop.paint(canvas);
    });
    StageProfile.run('scene', () => boss.paintScene(canvas, _time, battle));
    if (StageQuality.mist && _mistDensity > 0.01) {
      StageProfile.run(
        'mist',
        () => _mist.paint(
          canvas,
          Offset.zero & stageSize,
          time: _time,
          uniforms: (s) {
            s.setFloat(3, _mistDensity);
            setColorUniform(s, 4, boss.mistColor);
          },
        ),
      );
    }
  }

  @override
  void onRemove() {
    _mist.dispose();
    boss.dispose();
    _backdrop.dispose();
    super.onRemove();
  }
}

class _BossComponent extends PositionComponent {
  _BossComponent(this.art, this.battle, {this.onAttackStart, this.onStrike});

  final void Function()? onAttackStart;

  /// Mốc trúng của đòn (tiến độ 0–1): sư tử và [AttackPose] đều chạm ở ~0,55.
  static const strikePhase = 0.55;
  final void Function()? onStrike;

  final BossArt art;
  final StageBattleState battle;
  double _time = 0;
  double hurt = 0;
  double glint = -1;
  double _attack = 0;
  double _defeat = 0;
  bool defeated = false;

  /// Thở, lấy đà ngả thân, vồ tới, nảy khi trúng đòn — chung mọi boss.
  final motion = BossBodyMotion();
  late final Offset _anchor = art.bodyAnchor;

  /// Đếm ngược tới lần đe doạ tiếp theo; [_attackAge] là thời gian đã diễn.
  double _nextAttack = 1.5;
  double _attackAge = _attackLength;
  static const _attackLength = 1.2;
  final _random = math.Random();

  void triggerAttack() {
    if (!defeated) _nextAttack = 0;
  }

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
    final before = _attackAge / _attackLength;
    _attackAge += dt;
    final after = _attackAge / _attackLength;
    if (!defeated && before < strikePhase && after >= strikePhase) {
      onStrike?.call();
    }
    if (_nextAttack <= 0 && !defeated) {
      _nextAttack = 7 + _random.nextDouble() * 5;
      _attackAge = 0;
      onAttackStart?.call();
    }
    _attack = !defeated && _attackAge < _attackLength
        ? math.sin(math.pi * _attackAge / _attackLength)
        : 0;
    motion.update(
      dt,
      attackPhase: art.ownsAttackMotion ? -1 : frame.attackPhase,
      defeated: defeated,
    );
  }

  @override
  void render(Canvas canvas) {
    if (!StageQuality.boss) return;
    StageProfile.run('boss', () {
      canvas.save();
      motion.apply(canvas, _anchor, breathe: 1 - _defeat);
      art.paintBoss(canvas, frame);
      canvas.restore();
      if (_defeat > 0.3 && !art.ownsDefeatSmoke) {
        _stagnationLeaving(
          canvas,
          // Bốc từ thân boss (không theo đầu/điểm trúng, có thể đã chìm).
          _anchor.translate(0, -70),
          _time,
          ((_defeat - 0.3) / 0.7).clamp(0.0, 1.0),
        );
      }
    });
  }
}

/// Gục ngã (chung mọi boss, cùng kiểu sư tử): làn khói Trì Trệ tím xám bốc
/// lên rời khỏi xác — sức mạnh tà ác bị đánh bật — cuộn xoắn rồi tan.
void _stagnationLeaving(Canvas canvas, Offset origin, double t, double a) {
  for (var i = 0; i < 7; i++) {
    final phase = (t * 0.35 + i / 7) % 1;
    final x = origin.dx - 54 + i * 18.0 + math.sin(t * 1.3 + i * 2) * 8 * phase;
    final y = origin.dy + 20 - phase * 100;
    final r = 6 + phase * 13;
    canvas.drawCircle(
      Offset(x, y),
      r,
      Paint()
        ..shader = ui.Gradient.radial(Offset(x, y), r + 4, [
          Color.fromRGBO(120, 100, 150, 0.68 * a * (1 - phase)),
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
        ..color = Color.fromRGBO(70, 56, 92, 0.75 * a * (1 - phase))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }
}

class _ForegroundComponent extends Component {
  _ForegroundComponent(this.boss);

  final _BossComponent boss;

  /// Lớp chỉnh màu toàn cảnh tĩnh → chụp sẵn thành ảnh (một lần vẽ ảnh/khung).
  late final _grade = RasterLayer(
    (c) =>
        paintStageGrade(c, Offset.zero & stageSize, light: boss.art.gradeLight),
    bounds: Offset.zero & stageSize,
  );

  @override
  void onRemove() {
    _grade.dispose();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    StageProfile.run(
      'foreground',
      () => boss.art.paintForeground(canvas, boss.frame),
    );
    _paintRage(canvas);
    if (!StageQuality.grade) return;
    _grade.paint(canvas);
  }

  double _time = 0;

  @override
  void update(double dt) => _time += dt;

  /// Pha cuối của boss (máu < 40%): viền cảnh đỏ đập theo nhịp tim, mạnh dần
  /// khi máu cạn — người chơi biết sắp thắng mà không cần nhìn thanh máu.
  void _paintRage(Canvas canvas) {
    final hp = boss.battle.bossHp;
    if (hp >= 0.4 || boss.defeated) return;
    final k = ((0.4 - hp) / 0.3).clamp(0.0, 1.0);
    // Nhịp tim đôi (thịch–thịch) ~1,1 giây.
    final beat = math.pow(math.sin(_time * math.pi / 0.55).abs(), 6);
    final a = (0.22 + 0.26 * beat) * k;
    final rect = Offset.zero & stageSize;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          rect.center,
          rect.width * 0.62,
          [const Color(0x00000000), boss.art.rageColor.withValues(alpha: a)],
          const [0.4, 1.0],
        ),
    );
  }
}

/// Ánh sáng động khi đòn trúng: quầng sáng cộng màu (BlendMode.plus) toả từ
/// điểm trúng, tắt trong ~0,3 giây.
class _ImpactLight extends PositionComponent {
  _ImpactLight({required this.critical, required this.color});

  final bool critical;
  final Color color;
  static const _life = 0.3;
  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= _life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / _life).clamp(0.0, 1.0);
    final fade = (1 - t) * (1 - t);
    final r = (critical ? 150.0 : 105.0) * (0.75 + 0.25 * t);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(
          Offset.zero,
          r,
          [
            color.withValues(alpha: (critical ? 0.55 : 0.38) * fade),
            color.withValues(alpha: 0.12 * fade),
            const Color(0x00000000),
          ],
          const [0, 0.45, 1],
        ),
    );
  }
}

/// Chuyển cảnh: vào trận thì vòng sáng mở từ giữa sân khấu ra (iris); thắng
/// thì loé ấm một nhịp rồi tắt.
class _TransitionComponent extends Component {
  static const _introLength = 0.9;
  double _intro = 0;
  double _victory = -1;
  double _rage = -1;

  void victory() => _victory = 0;
  void rage() => _rage = 0;

  @override
  void update(double dt) {
    if (_intro < 1) _intro = math.min(1, _intro + dt / _introLength);
    if (_victory >= 0) {
      _victory += dt / 0.6;
      if (_victory > 1) _victory = -1;
    }
    if (_rage >= 0) {
      _rage += dt / 0.5;
      if (_rage > 1) _rage = -1;
    }
  }

  @override
  void render(Canvas canvas) {
    final rect = Offset.zero & stageSize;
    if (_intro < 1) {
      final e = Curves.easeOutCubic.transform(_intro);
      final r = 8 + e * rect.width * 0.75;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            rect.center,
            r,
            [
              const Color(0x00000000),
              const Color(0x00000000),
              Color.fromRGBO(6, 4, 10, 1 - e * e),
            ],
            const [0, 0.7, 1],
          ),
      );
    }
    if (_rage >= 0) {
      canvas.drawRect(
        rect,
        Paint()..color = Color.fromRGBO(200, 30, 20, 0.35 * (1 - _rage)),
      );
    }
    if (_victory >= 0) {
      final a = _victory < 0.15
          ? _victory / 0.15
          : 1 - (_victory - 0.15) / 0.85;
      canvas.drawRect(
        rect,
        Paint()..color = Color.fromRGBO(255, 236, 190, 0.55 * a),
      );
    }
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

  /// Giật lùi khi bị boss đánh trúng (lò xo: lùi rồi nảy về).
  final _recoil = Spring(stiffness: 170, damping: 11);

  void struck() => _recoil.kick(-150);

  double _time = 0;
  double _angle = 175;
  _HeroMode _mode = _HeroMode.standing;
  HeroPose _shown = HeroPose.standing();
  HeroPose? _from;
  double _blend = 1;
  Object? _poseKey;
  HeroSpriteFrame _sprite = const HeroSpriteFrame('stand', 0);
  HeroSpriteFrame? _spriteFrom;

  @override
  void onRemove() {
    HeroSprites.evict(look);
    super.onRemove();
  }

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
    _recoil.update(0, dt);
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
      _spriteFrom = _sprite;
      _blend = 0;
    }

    // Tư thế làm tròn (góc khuỷu bước 2°; thở / ăn mừng 16–20 pha) để
    // ảnh chụp sẵn của nhân vật được dùng lại qua các rep.
    final qAngle = (_angle / 2).round() * 2.0;
    final breath = ((_time / 3) % 1 * 12).floor();
    final pump = ((_time / 1.2) % 1 * 16).floor();
    final pose = switch (_mode) {
      _HeroMode.standing => HeroPose.standing(breath: breath / 12),
      _HeroMode.plank => HeroPose.plank(qAngle, onKnees: onKnees),
      _HeroMode.victory => HeroPose.victory(pump: pump / 16),
    };
    _poseKey = switch (_mode) {
      _HeroMode.standing => ('s', breath),
      _HeroMode.plank => ('p', qAngle, onKnees),
      _HeroMode.victory => ('v', pump),
    };
    final sprite = switch (_mode) {
      _HeroMode.standing => const HeroSpriteFrame('stand', 0),
      _HeroMode.plank => HeroSpriteFrame.plank(_angle, onKnees: onKnees),
      _HeroMode.victory => const HeroSpriteFrame('victory', 0),
    };
    final from = _from;
    if (from != null && _blend < 1) {
      _blend = math.min(1, _blend + dt / 0.45);
      final k = Curves.easeInOut.transform(_blend);
      _shown = HeroPose.lerp(from, pose, k);
      if (_mode == _HeroMode.plank) {
        // Xuống thế chống đẩy: chống tay xuống sàn trước rồi mới hạ người
        // (không để bàn tay lơ lửng giữa chừng).
        final hands = Curves.easeOut.transform(math.min(1, _blend * 2));
        _shown = HeroPose({
          ..._shown.joints,
          for (final j in const [HeroJoint.wrist, HeroJoint.farWrist])
            j: Offset.lerp(from[j], pose[j], hands)!,
        });
      }
    } else {
      _shown = pose;
    }
    _sprite = sprite.blendFrom(
      _spriteFrom,
      Curves.easeInOut.transform(_blend.clamp(0.0, 1.0)),
    );
  }

  /// Sprite Blender chưa có lớp cho khiên, kiếm và lớp băng giá (áo da sư tử
  /// thì có): khi đó vẽ bản vector.
  bool get _spriteOk =>
      (!cloak || HeroSprites.peltReady(look)) &&
      !shield &&
      !sword &&
      cold < 0.02;

  @override
  void render(Canvas canvas) {
    if (!StageQuality.hero) return;
    StageProfile.run('hero', () {
      // Biến đổi đặt lên ảnh chụp sẵn của nhân vật: không phá bộ đệm tư thế.
      final r = _recoil.value;
      if (r.abs() < 0.05) return _paint(canvas);
      canvas
        ..save()
        ..translate(r, 0)
        ..translate(90, 220)
        ..rotate(r * 0.004)
        ..translate(-90, -220);
      _paint(canvas);
      canvas.restore();
    });
  }

  void _paint(Canvas canvas) {
    if (_spriteOk && HeroSprites.ready(look)) {
      paintHeroGlow(canvas, _shown, look: look, glow: glow);
      // Ăn mừng: nảy theo nhịp nắm tay giơ lên.
      final bob = _mode == _HeroMode.victory
          ? -(math.sin(_time / 1.2 * 2 * math.pi)).abs() * 3
          : 0.0;
      canvas.save();
      canvas.translate(0, bob);
      HeroSprites.paint(canvas, look, _sprite, pelt: cloak);
      canvas.restore();
      return;
    }
    _paintVector(canvas);
  }

  void _paintVector(Canvas canvas) => paintHero(
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
    // Đang chuyển tư thế thì tư thế không lặp lại: vẽ vector.
    cacheKey: _blend >= 1 ? _poseKey : null,
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
          ..color = color.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        tail,
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 1.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
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
        ..shader = ui.Gradient.radial(Offset.zero, r * 2.6, [
          color.withValues(alpha: 0.45),
          color.withValues(alpha: 0),
        ]),
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
      Rect.fromLTRB(-_label.width - 60, -60, _label.width + 60, 60),
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
  // Da gợn sóng khi bay: nếp tối + sống sáng chạy dọc, lắc theo nhịp.
  canvas.save();
  canvas.clipPath(skin);
  for (final (x, len) in const [(-8.0, 30.0), (2.0, 26.0), (12.0, 30.0)]) {
    final pts = [
      Offset(x, -4),
      Offset(x + wave * 1.5, 8),
      Offset(x - wave, len - 4),
    ];
    canvas.drawPath(
      taperedStroke(pts, 2.4, peak: 0.6),
      fillPaint(darken(hide, 0.35).withValues(alpha: 0.75)),
    );
    canvas.drawPath(
      taperedStroke(
        [for (final p in pts) p + const Offset(-2.2, 0)],
        1.4,
        peak: 0.6,
      ),
      fillPaint(lighten(hide, 0.3).withValues(alpha: 0.7)),
    );
  }
  canvas.restore();
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
  // Bờm lọn lông quanh cổ (cùng kiểu bờm sư tử), bay ngược chiều bay.
  final locks = buildLocks(
    center: const Offset(-6, -8),
    rnd: math.Random(31),
    r0: 6,
    length: 13,
    width: 5.6,
    count: 13,
    from: math.pi * 0.8,
    to: math.pi * 1.95,
    drift: Offset(-0.35, 0.18 + wave * 0.04),
    wave: 2.5,
  );
  shadedPath(
    canvas,
    locks.mass,
    mane,
    PartFrame.world,
    shadow: 2.5,
    outlineWidth: 1.3,
  );
  canvas.save();
  canvas.clipPath(locks.mass);
  canvas.drawPath(
    locks.creases,
    fillPaint(darken(mane, 0.45).withValues(alpha: 0.8)),
  );
  canvas.drawPath(
    locks.sheens,
    fillPaint(lighten(mane, 0.38).withValues(alpha: 0.75)),
  );
  canvas.restore();
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
      Rect.fromCenter(center: c, width: w + 80, height: h + 40),
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
