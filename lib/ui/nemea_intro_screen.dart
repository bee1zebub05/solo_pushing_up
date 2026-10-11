import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/hercules_art.dart';
import '../art/hero_art.dart';
import '../art/hero_pose.dart';
import '../art/nemea_scene.dart';

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
  bool talking = false,
}) {
  paintNemeaScene(canvas, time: time, dust: 0.85);
  canvas.save();
  canvas.translate(110, stageGroundY);
  canvas.scale(0.82);
  canvas.translate(-110, -stageGroundY);
  paintHero(canvas, HeroPose.standing(x: 110, breath: time / 3), look: look);
  canvas.restore();
  canvas.save();
  canvas.translate(300, stageGroundY);
  canvas.scale(0.78);
  paintHercules(
    canvas,
    time: time,
    appear: math.min(1, time / 1.6),
    talk: talking ? 1 : 0,
  );
  canvas.restore();
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
  late final Ticker _ticker = createTicker(_tick)..start();
  double _seconds = 0;
  int _line = 0;
  double _lineStart = 1.6;

  /// Số chữ hiện ra mỗi giây (hiệu ứng gõ chữ).
  static const _charsPerSecond = 32.0;

  void _tick(Duration elapsed) =>
      setState(() => _seconds = elapsed.inMicroseconds / 1e6);

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
                child: Center(
                  child: AspectRatio(
                    aspectRatio: stageSize.width / stageSize.height,
                    child: CustomPaint(
                      painter: _IntroPainter(
                        seconds: _seconds,
                        look: widget.look,
                        talking: talking,
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
                    Text(
                      'HERCULES',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: const Color(0xFFE8B83A),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      text,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFF6EEDD),
                        height: 1.4,
                      ),
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
    required this.talking,
  });

  final double seconds;
  final HeroLook look;
  final bool talking;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / stageSize.width);
    paintNemeaIntro(canvas, time: seconds, look: look, talking: talking);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IntroPainter old) => true;
}
