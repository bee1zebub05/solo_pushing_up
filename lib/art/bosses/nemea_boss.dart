import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../battle_stage.dart';
import '../greek_monsters.dart';
import '../lion_art.dart';
import '../nemea_backdrop.dart';
import '../nemea_scene.dart';
import '../sprite_atlas.dart';
import '../vector_style.dart' show RasterLayer, StageQuality;

/// Vị trí và tỉ lệ Sư tử Nemea trên sân khấu 400×260.
const lionX = 350.0;

/// Sư tử to hẳn so với nhân vật (boss chương 1): 0,72 → 1,2; dời phải
/// (335 → 350) để mõm không chạm nhân vật lúc đứng chờ.
const lionScale = 1.2;

/// Kỳ công 1 — Sư tử Nemea ở thung lũng Nemea.
class NemeaBossArt extends BossArt {
  @override
  String get soundKey => 'nemea';

  /// Sư tử tự diễn đòn vồ 3 pha (lion_art.dart).
  @override
  bool get ownsAttackMotion => true;

  @override
  bool get ownsDefeatSmoke => true;

  /// Đòn quái chương 1 chậm, rõ thế hơn (1,2 s trông vội trên sân khấu).
  @override
  double get attackSeconds => 1.6;

  @override
  final Vector2 target = Vector2(
    lionX - 72 * lionScale,
    stageGroundY - 96 * lionScale,
  );

  /// Chân dung: đầu sư tử (mõm nhô sang trái) và một phần bờm.
  @override
  Vector2 get portraitFocus =>
      Vector2(lionX - 88 * lionScale, stageGroundY - 104 * lionScale);

  @override
  double get portraitView => 104 * lionScale / 0.72; // khung đo ở lionScale 0,72

  @override
  void paintBackdrop(Canvas canvas) => paintNemeaBackdrop(canvas);

  @override
  void paintAmbient(Canvas canvas, double time) => paintNemeaAmbient(
    canvas,
    time: time,
    realistic: NemeaStageBackdrop.ready || NemeaBackdrop.ready,
  );

  /// Phông vẽ của màn (`assets/backdrops/nemea_stage_<màn>.webp`): đúng cảnh
  /// ở điểm màn trên bản đồ. Boss 1.8 = cửa hang sư tử.
  String get backdropScene => '1_8';

  /// Phông vẽ trôi theo camera bằng một hệ số (tranh một lớp, không tách
  /// tầng — tách thì vách đá, cây kéo dài từ trời xuống đất bị xé).
  static const paintedParallax = 0.3;

  /// Ánh sáng của phông vẽ từng màn: (phủ màu toàn cảnh, nhân màu sprite
  /// quái) — bình minh vàng nhạt → trưa trắng → u ám xám tím (đầm) → chiều
  /// vàng → hoàng hôn cam ở hang. Sprite quái render ánh sáng trung tính nên
  /// phải nhân màu mới ăn tông với tranh.
  static const sceneLight = <String, (Color, Color)>{
    '1_1': (Color(0xFFFFE2B8), Color(0xFFFFF0DC)),
    '1_2': (Color(0xFFE6EAF2), Color(0xFFEEEEF2)),
    '1_3': (Color(0xFFFFF4E0), Color(0xFFFFFFFF)),
    '1_4': (Color(0xFFFFEFCC), Color(0xFFFFF8E6)),
    '1_5': (Color(0xFFEEF0F4), Color(0xFFF2F2F2)),
    '1_6': (Color(0xFFC8C0DA), Color(0xFFD6D0DE)),
    '1_7': (Color(0xFFFFD49A), Color(0xFFFFE4BE)),
    '1_8': (Color(0xFFFFB27A), Color(0xFFFFCCA4)),
  };

  /// Nhân màu sprite quái theo ánh sáng phông vẽ (null = giữ nguyên).
  Color? get spriteTint =>
      NemeaStageBackdrop.ready ? sceneLight[backdropScene]?.$2 : null;

  @override
  Color get gradeLight => NemeaStageBackdrop.ready
      ? sceneLight[backdropScene]!.$1
      : const Color(0xFFFFE3C0);

  /// Bụi Trì Trệ: đậm nhất khi sư tử còn đầy máu, tan dần mỗi đòn trúng.
  static const maxDust = 0.85;

  /// Trời nằm trong các lớp của Nemea (để phủ bụi được), nên sân khấu
  /// không cần chụp phông nền riêng.
  @override
  bool get hasStageBackdrop => false;

  /// Mỗi lớp chiều sâu chụp sẵn thành ảnh một lần (vẽ lại vector mỗi khung
  /// tốn GPU điện thoại ~20 ms). Bản phủ bụi = cùng ảnh vẽ qua
  /// [nemeaDustFilter], không giữ ảnh thứ hai. Trời và núi xa chụp thô hơn
  /// (xa thì mềm — phối cảnh không khí) để bớt bộ nhớ.
  static final _layers = [
    for (final l in NemeaLayer.values)
      (
        l,
        RasterLayer(
          (c) => paintNemeaLayer(c, l),
          resolution: switch (l) {
            NemeaLayer.sky => 0.6,
            NemeaLayer.far => 0.8,
            _ => 1,
          },
        ),
      ),
  ];

  /// Tiền cảnh (cỏ, đá góc dưới) chụp sẵn: chỉ dải dưới sân khấu.
  static final _foreground = RasterLayer(
    paintNemeaForeground,
    bounds: const Rect.fromLTRB(-40, 120, 440, 280),
  );

  double _drift = 0;

  @override
  void paintForeground(Canvas canvas, BossFrame f) {
    // Tiền cảnh trôi ngược chiều, mạnh hơn các lớp xa (gần máy quay hơn).
    canvas.save();
    canvas.translate(-_drift * 0.6, 0);
    if (NemeaStageBackdrop.ready) {
      // Tranh vẽ đã có tiền cảnh của nó.
    } else if (NemeaBackdrop.ready) {
      NemeaBackdrop.paintForeground(canvas, filter: _dustFilter);
    } else {
      _foreground.paint(canvas);
    }
    canvas.restore();
  }

  ColorFilter? _dustFilter;

  double _dust = maxDust;
  double _lastTime = 0;

  @override
  void paintScene(Canvas canvas, double time, StageBattleState battle) {
    // Tan mượt (không giật theo từng đòn).
    final dt = (time - _lastTime).clamp(0.0, 0.1);
    _lastTime = time;
    final target = maxDust * battle.bossHp.clamp(0.0, 1.0);
    _dust += (target - _dust) * (1 - math.exp(-dt * 2.5));
    // Camera trôi chậm: lớp càng xa càng lệch so với nhân vật (2,5D).
    final drift = math.sin(time * 0.21) * 5 + math.sin(time * 0.083) * 3;
    _drift = drift;
    // Bụi: mỗi tầng vẽ ảnh sạch MỘT lần qua bộ lọc mất màu nội suy theo
    // lượng bụi, thêm sương/mạng nhện vẽ thẳng.
    final dust = StageQuality.dust && _dust > 0.01 ? _dust : 0.0;
    if (NemeaStageBackdrop.ready) {
      // Phông vẽ của màn: một lớp qua bộ lọc bụi + màn sương Trì Trệ. Tranh
      // đã có không khí riêng (sương đầm, hoàng hôn): bụi nhẹ hơn phông cũ để
      // không che mất cảnh lúc quái còn nhiều máu.
      final paintedDust = dust * 0.5;
      _dustFilter = paintedDust > 0 ? nemeaDustFilterAt(paintedDust) : null;
      canvas.save();
      canvas.translate(drift * paintedParallax, 0);
      NemeaStageBackdrop.paint(canvas, filter: _dustFilter);
      if (paintedDust > 0) paintNemeaDustMist(canvas, opacity: paintedDust);
      canvas.restore();
      paintNemeaAmbient(canvas, time: time, dust: _dust, realistic: true);
      _paintCleansing(canvas, time);
      _paintFlock(canvas, time, battle.bossHp);
      return;
    }
    if (NemeaBackdrop.ready) {
      // Phông Blender: ảnh từng tầng qua bộ lọc bụi; phần bụi vẽ thêm chỉ
      // còn màn sương (mạng nhện, đống bụi khớp hình bản vector).
      final filter = dust > 0 ? nemeaDustFilterAt(dust) : null;
      _dustFilter = filter;
      for (final layer in NemeaLayer.values) {
        canvas.save();
        canvas.translate(drift * layer.parallax, 0);
        NemeaBackdrop.paintLayer(canvas, layer, filter: filter);
        if (dust > 0 && layer == NemeaLayer.mid) {
          paintNemeaDustMist(canvas, opacity: dust);
        }
        canvas.restore();
      }
      paintNemeaAmbient(canvas, time: time, dust: _dust, realistic: true);
      _paintCleansing(canvas, time);
      _paintFlock(canvas, time, battle.bossHp);
      return;
    }
    _dustFilter = null;
    for (final (layer, image) in _layers) {
      canvas.save();
      canvas.translate(drift * layer.parallax, 0);
      if (dust > 0) {
        image.paint(canvas, colorFilter: nemeaDustFilterAt(dust));
        paintNemeaDustExtras(canvas, layer, opacity: dust);
      } else {
        image.paint(canvas);
      }
      canvas.restore();
    }
    paintNemeaAmbient(canvas, time: time, dust: _dust);
    _paintCleansing(canvas, time);
    _paintFlock(canvas, time, battle.bossHp);
  }

  /// Lúc bụi vừa tan hết: vòng ánh sáng vàng nở ra từ đền (thung lũng được
  /// giải phóng). Chỉ diễn một lần mỗi trận.
  double? _cleansedAt;

  void _paintCleansing(Canvas canvas, double time) {
    if (_dust < 0.04) _cleansedAt ??= time;
    if (_dust > 0.3) _cleansedAt = null; // trận mới
    final t0 = _cleansedAt;
    if (t0 == null) return;
    final t = (time - t0) / 1.6;
    if (t > 1) return;
    const temple = Offset(196, 118);
    final fade = 1 - t;
    canvas.drawCircle(
      temple,
      20 + 260 * t,
      Paint()
        ..color = Color.fromRGBO(255, 236, 170, 0.8 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * fade + 1,
    );
    canvas.drawCircle(
      temple,
      30 + 60 * t,
      Paint()
        ..shader = Gradient.radial(temple, 30 + 60 * t, [
          Color.fromRGBO(255, 250, 220, 0.6 * fade),
          const Color(0x00FFF0C0),
        ]),
    );
  }

  /// Đàn chim Stymphalia canh hang sư tử: mỗi phần tư máu sư tử mất đi thì
  /// một con bị hạ, xoay tròn rơi xuống.
  static const flockSize = 4;
  int _birds = flockSize;
  final _falling = <(int, double)>[];

  void _paintFlock(Canvas canvas, double time, double hp) {
    final alive = (hp.clamp(0.0, 1.0) * flockSize).ceil();
    while (_birds > alive) {
      _birds--;
      _falling.add((_birds, time));
    }
    if (alive > _birds) _birds = alive; // trận mới
    _falling.removeWhere((f) => time - f.$2 > 1.2);
    for (var i = 0; i < _birds; i++) {
      _bird(canvas, i, time, 0);
    }
    for (final (i, t0) in _falling) {
      _bird(canvas, i, time, (time - t0) / 1.2);
    }
  }

  void _bird(Canvas canvas, int i, double time, double fall) {
    // Mỗi con bay một vòng elip riêng quanh khoảng trời trên hang.
    final a = time * (0.5 + i * 0.08) + i * 1.7;
    final at = Offset(
      290 + math.cos(a) * (40 + i * 8),
      58 + i * 12 + math.sin(a) * 14,
    );
    final size = 0.55 + (i % 2) * 0.1;
    final sprite = SpriteAtlas.get(birdSprite);
    if (sprite != null) {
      // Chim Blender (cùng atlas quái 1.1): sprite tính theo con đầu đàn ×1,15.
      final s = size / 1.15;
      canvas.save();
      canvas.translate(at.dx, at.dy + 120 * fall * fall);
      if (fall > 0) canvas.rotate(fall * 7);
      canvas.scale(-math.sin(a) > 0 ? -s : s, s);
      if (fall > 0 && sprite.has('defeat')) {
        sprite.draw(
          canvas,
          'defeat',
          fall,
          opacity: 1 - fall,
          tint: spriteTint,
        );
      } else {
        final period = sprite.metaDouble('idlePeriod', 0.7);
        sprite.draw(
          canvas,
          'idle',
          (time + i * 0.3) / period,
          loop: true,
          tint: spriteTint,
        );
      }
      canvas.restore();
      return;
    }
    paintBirdSprite(
      canvas,
      at,
      time + i * 0.3,
      size: size,
      facingRight: -math.sin(a) > 0,
      fall: fall,
    );
  }

  /// Sprite Blender chỉ nạp khi vào trận (chân dung ở màn chọn vẫn vẽ
  /// vector), trả lại khi rời trận.
  @override
  Future<void> preload() async {
    await NemeaStageBackdrop.load(backdropScene);
    await SpriteAtlas.load(lionSprite);
    await SpriteAtlas.load(birdSprite);
  }

  @override
  void dispose() {
    SpriteAtlas.evict(lionSprite);
    SpriteAtlas.evict(birdSprite);
    NemeaStageBackdrop.evict();
    NemeaBackdrop.evict();
    super.dispose();
  }

  static const lionSprite = 'nemea_lion';

  /// Đàn chim Stymphalia canh hang (cùng atlas quái màn 1.1).
  static const birdSprite = 'stymphalian_bird';

  /// Lần vật được sư tử gần nhất (giây sân khấu) — diễn `wrestled` 1,2 s.
  int _wrestles = 0;
  double _wrestledAt = -10;
  static const _wrestledLength = 1.2;

  @override
  void paintBoss(Canvas canvas, BossFrame f) {
    final b = f.battle;
    if (b.wrestles != _wrestles) {
      if (b.wrestles > _wrestles) _wrestledAt = f.time;
      _wrestles = b.wrestles;
    }
    final sinceWrestled = (f.time - _wrestledAt) / _wrestledLength;
    canvas.save();
    canvas.translate(lionX, stageGroundY);
    canvas.scale(lionScale);
    final state = LionState(
      // Pha 2 (máu < 40%, LionPounce): đòn là cú nhảy vồ.
      pounce: b.bossHp < 0.4,
      wrestled: sinceWrestled >= 0 && sinceWrestled < 1 ? sinceWrestled : -1,
      time: f.time,
      attackPhase: f.attackPhase,
      // Không có đòn vồ (chân dung, xem trước): attack chỉ là há miệng gầm.
      mouth: f.attackPhase < 0 ? f.attack : 0,
      hurt: f.hurt,
      glint: f.glint,
      defeat: f.defeat,
    );
    final sprite = SpriteAtlas.get(lionSprite);
    if (sprite != null) {
      paintLionSprite(canvas, state, sprite, tint: spriteTint);
    } else {
      paintLion(canvas, state);
    }
    canvas.restore();
  }
}
