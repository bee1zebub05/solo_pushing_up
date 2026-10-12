import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../battle_stage.dart';
import '../greek_monsters.dart';
import '../lion_art.dart';
import '../nemea_scene.dart';
import '../vector_style.dart' show RasterLayer, StageQuality;

/// Vị trí và tỉ lệ Sư tử Nemea trên sân khấu 400×260.
const lionX = 335.0;
const lionScale = 0.72;

/// Kỳ công 1 — Sư tử Nemea ở thung lũng Nemea.
class NemeaBossArt extends BossArt {
  @override
  String get soundKey => 'nemea';

  /// Sư tử tự diễn đòn vồ 3 pha (lion_art.dart).
  @override
  bool get ownsAttackMotion => true;

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
  double get portraitView => 104;

  @override
  void paintBackdrop(Canvas canvas) => paintNemeaBackdrop(canvas);

  @override
  void paintAmbient(Canvas canvas, double time) =>
      paintNemeaAmbient(canvas, time: time);

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
    _foreground.paint(canvas);
    canvas.restore();
  }

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
    paintBirdSprite(
      canvas,
      at,
      time + i * 0.3,
      size: 0.55 + (i % 2) * 0.1,
      facingRight: -math.sin(a) > 0,
      fall: fall,
    );
  }

  @override
  void paintBoss(Canvas canvas, BossFrame f) {
    canvas.save();
    canvas.translate(lionX, stageGroundY);
    canvas.scale(lionScale);
    paintLion(
      canvas,
      LionState(
        time: f.time,
        attackPhase: f.attackPhase,
        // Không có đòn vồ (chân dung, xem trước): attack chỉ là há miệng gầm.
        mouth: f.attackPhase < 0 ? f.attack : 0,
        hurt: f.hurt,
        glint: f.glint,
        defeat: f.defeat,
      ),
    );
    canvas.restore();
  }
}
