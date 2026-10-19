import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/hercules_art.dart';
import '../art/hero_art.dart';
import '../art/hero_pose.dart';
import '../art/hero_sprite.dart';
import '../art/nemea_backdrop.dart';
import '../art/nemea_scene.dart';
import '../art/sprite_atlas.dart';

/// Atlas Hercules dựng Blender (tool/blender/characters/hercules.py).
const herculesSprite = 'hercules';

/// Nạp phông, nhân vật, Hercules bằng Blender cho cảnh mở đầu (chưa có thì
/// cảnh vẽ bản vector).
Future<void> preloadNemeaIntro(HeroLook look) async {
  await NemeaBackdrop.load();
  await HeroSprites.load(look);
  await SpriteAtlas.load(herculesSprite);
}

/// Lời Hercules ở cảnh mở đầu Kỳ công 1 (rules/cottruyen.md mục 3).
const nemeaIntroLines = [
  'Người kế nhiệm... ta đã chờ ngươi. Trì Trệ đã phủ bụi xám lên cả '
      'thung lũng Nemea.',
  'Con sư tử trong hang kia có bộ da không vũ khí nào xuyên thủng. Chỉ '
      'những lần hít đất đúng form mới làm nó đau.',
  'Sức mạnh không được ban cho. Nó được rèn ra từng lần một.',
];

/// Vẽ cảnh mở đầu tại giây [time]: thung lũng phủ bụi, người chơi đứng
/// bên trái, Hercules hiện ra trong ánh vàng bên phải.
void paintNemeaIntro(
  Canvas canvas, {
  required double time,
  HeroLook look = const HeroLook(),
  double talk = 0,
  bool talking = false,
}) {
  final blender = NemeaBackdrop.ready;
  if (blender) {
    // Phông Blender phủ bụi Trì Trệ (thung lũng chưa được giải phóng).
    final dust = nemeaDustFilterAt(0.85);
    for (final layer in NemeaLayer.values) {
      NemeaBackdrop.paintLayer(canvas, layer, filter: dust);
      if (layer == NemeaLayer.mid) paintNemeaDustMist(canvas, opacity: 0.85);
    }
    paintNemeaAmbient(canvas, time: time, dust: 0.85, realistic: true);
  } else {
    paintNemeaSceneCached(canvas, time: time, dust: 0.85);
  }
  canvas.save();
  canvas.translate(110, stageGroundY);
  canvas.scale(0.82);
  canvas.translate(-110, -stageGroundY);
  if (!HeroSprites.paint(canvas, look, const HeroSpriteFrame('stand', 0))) {
    paintHero(canvas, HeroPose.standing(x: 110, breath: time / 3), look: look);
  }
  canvas.restore();
  canvas.save();
  canvas.translate(300, stageGroundY);
  final hercules = SpriteAtlas.get(herculesSprite);
  if (hercules != null) {
    // Bản Blender cao hơn bản vector: thu nhỏ để đầu không chạm mép trên.
    canvas.scale(0.76);
    paintHerculesSprite(
      canvas,
      hercules,
      time: time,
      appear: math.min(1, time / 1.6),
      talk: talk,
      talking: talking,
    );
  } else {
    canvas.scale(0.78);
    paintHercules(
      canvas,
      time: time,
      appear: math.min(1, time / 1.6),
      talk: talk,
    );
  }
  canvas.restore();
  if (blender) {
    NemeaBackdrop.paintForeground(canvas, filter: nemeaDustFilterAt(0.85));
  }
}

/// Cảnh mở đầu trước trận Nemea đầu tiên. Chạm để sang câu tiếp; hết lời
/// thì [onDone] (vào trận).
class NemeaIntroScreen extends StatefulWidget {
  const NemeaIntroScreen({super.key, required this.look, required this.onDone});

  final HeroLook look;
  final VoidCallback onDone;

  @override
  State<NemeaIntroScreen> createState() => _NemeaIntroScreenState();
}

class _NemeaIntroScreenState extends State<NemeaIntroScreen>
    with SingleTickerProviderStateMixin {
  // Không dùng `late ... ..start()`: late chỉ khởi tạo khi truy cập lần đầu
  // (lúc dispose), ticker sẽ không bao giờ chạy.
  late final Ticker _ticker = createTicker(_tick);
  double _seconds = 0;

  /// Mức giơ tay của Hercules 0–1: lên dần khi bắt đầu thoại, giữ suốt
  /// đoạn thoại (không giật lên xuống theo từng câu).
  double _talk = 0;
  int _line = 0;
  double _lineStart = 1.6;

  /// Số chữ hiện ra mỗi giây (hiệu ứng gõ chữ).
  static const _charsPerSecond = 32.0;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    preloadNemeaIntro(widget.look);
  }

  void _tick(Duration elapsed) => setState(() {
    final now = elapsed.inMicroseconds / 1e6;
    final dt = (now - _seconds).clamp(0.0, 0.1);
    _seconds = now;
    final target = _seconds >= 1.6 ? 1.0 : 0.0;
    _talk += (target - _talk) * (1 - math.exp(-dt * 4));
  });

  int get _shownChars => ((_seconds - _lineStart) * _charsPerSecond)
      .floor()
      .clamp(0, nemeaIntroLines[_line].length);

  bool get _lineDone => _shownChars >= nemeaIntroLines[_line].length;

  void _advance() {
    if (_seconds < _lineStart) return;
    if (!_lineDone) {
      // Chạm khi đang gõ: hiện hết câu.
      _lineStart = -1000;
      return;
    }
    if (_line + 1 < nemeaIntroLines.length) {
      setState(() {
        _line++;
        _lineStart = _seconds;
      });
    } else {
      widget.onDone();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final talking = _seconds >= _lineStart && !_lineDone;
    final text = _seconds < 1.6
        ? ''
        : nemeaIntroLines[_line].substring(0, _shownChars);
    return Scaffold(
      backgroundColor: const Color(0xFF1C1612),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _advance,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.onDone,
                  child: const Text('Bỏ qua'),
                ),
              ),
              Expanded(
                // Màn dọc (iPhone): trời kéo lên trên, đất kéo xuống dưới
                // cảnh, cùng màu đã phủ bụi — không để dải đen trống.
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: const [
                        Color(0xFF2A3350),
                        Color(0xFF606C8C),
                        Color(0xFF72645C),
                        Color(0xFF2E2620),
                      ],
                      stops: const [0, 0.5, 0.5, 1],
                    ),
                  ),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: stageSize.width / stageSize.height,
                      child: CustomPaint(
                        painter: _IntroPainter(
                          seconds: _seconds,
                          look: widget.look,
                          talk: _talk,
                          talking: talking,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                constraints: const BoxConstraints(minHeight: 120),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B211A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8B83A), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      height: 8,
                      width: double.infinity,
                      child: CustomPaint(painter: _MeanderPainter()),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE8B83A),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: CustomPaint(
                              painter: _HerculesPortraitPainter(
                                seconds: _seconds,
                                talking: talking,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'HERCULES',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: const Color(0xFFE8B83A),
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                text,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFFF6EEDD),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_lineDone && _seconds >= 1.6)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          _line + 1 < nemeaIntroLines.length
                              ? 'Chạm để tiếp ▸'
                              : 'Chạm để vào trận ⚔',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: const Color(0xFFBFAF90),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroPainter extends CustomPainter {
  _IntroPainter({
    required this.seconds,
    required this.look,
    required this.talk,
    required this.talking,
  });

  final double seconds;
  final HeroLook look;
  final double talk;
  final bool talking;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / stageSize.width);
    paintNemeaIntro(
      canvas,
      time: seconds,
      look: look,
      talk: talk,
      talking: talking,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IntroPainter old) => true;
}

/// Chân dung Hercules trong khung thoại: cắt quanh đầu, miệng theo lời nói.
class _HerculesPortraitPainter extends CustomPainter {
  _HerculesPortraitPainter({required this.seconds, required this.talking});

  final double seconds;
  final bool talking;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFE9A8), Color(0xFFB9822E)],
        ).createShader(Offset.zero & size),
    );
    if (SpriteAtlas.get(herculesSprite) case final sprite?) {
      paintHerculesSpritePortrait(canvas, sprite, size);
      return;
    }
    const view = 72.0;
    canvas.save();
    canvas.scale(size.width / view);
    canvas.translate(view / 2 + 6, view / 2 + 214);
    paintHercules(canvas, time: seconds, talk: talking ? 1 : 0);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HerculesPortraitPainter old) => true;
}

/// Dải hoa văn chìa khoá Hy Lạp (meander) vàng làm viền khung thoại.
class _MeanderPainter extends CustomPainter {
  const _MeanderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final paint = Paint()
      ..color = const Color(0xFFE8B83A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.miter;
    final path = Path()..moveTo(0, h);
    for (var x = 0.0; x + h * 1.5 <= size.width; x += h * 1.5) {
      path
        ..lineTo(x, 0)
        ..lineTo(x + h, 0)
        ..lineTo(x + h, h * 0.66)
        ..lineTo(x + h * 0.5, h * 0.66)
        ..lineTo(x + h * 0.5, h * 0.33)
        ..moveTo(x + h, h)
        ..lineTo(x + h * 1.5, h);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MeanderPainter old) => false;
}
