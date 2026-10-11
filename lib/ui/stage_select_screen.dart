import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../art/nemea_map_art.dart';
import '../art/bosses/boss_registry.dart';
import '../game/labors.dart';
import '../game/progress.dart';
import 'boss_portrait.dart';
import 'greek_ui.dart';

/// Chọn màn trong một kỳ công (1.1 … 1.10): màn đã thắng có dấu tích, màn
/// kế tiếp sáng lên, màn chưa mở bị khoá. Màn cuối là boss.
class StageSelectScreen extends StatelessWidget {
  const StageSelectScreen({
    super.key,
    required this.labor,
    required this.progress,
    required this.onPlay,
  });

  final Labor labor;
  final PlayerProgress progress;

  /// Mở trận của màn; trả về khi trận kết thúc để làm mới danh sách.
  final Future<void> Function(Stage stage) onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stages = labor.allStages;
    final done = stages.where(progress.isStageDone).length;
    return Scaffold(
      backgroundColor: GreekUi.background,
      appBar: AppBar(
        backgroundColor: GreekUi.background,
        foregroundColor: GreekUi.ink,
        title: Text('Kỳ công ${labor.number} — ${labor.title}'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(8),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 6,
              child: CustomPaint(
                painter: MeanderPainter(color: GreekUi.goldDim),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ),
      // SafeArea: padding tự đặt làm ListView bỏ phần chừa thanh Home của
      // iPhone; nằm ngang thì chừa cả tai thỏ / Dynamic Island hai bên.
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(labor.region, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: done / stages.length,
              color: GreekUi.gold,
              backgroundColor: const Color(0xFF4A3C2C),
            ),
            const SizedBox(height: 4),
            Text(
              '$done/${stages.length} màn',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (stages.length == nemeaMapNodes.length) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: nemeaMapSize.width / nemeaMapSize.height,
                  child: _StageMap(
                    states: [
                      for (final s in stages)
                        progress.isStageDone(s)
                            ? MapNodeState.done
                            : progress.isStageUnlocked(labor, s)
                            ? MapNodeState.open
                            : MapNodeState.locked,
                    ],
                    onTap: (i) => onPlay(stages[i]),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            for (final (i, stage) in stages.indexed)
              _StageTile(
                stage: stage,
                boss: i == stages.length - 1,
                done: progress.isStageDone(stage),
                unlocked: progress.isStageUnlocked(labor, stage),
                onTap: () => onPlay(stage),
              ),
          ],
        ),
      ),
    );
  }
}

class _StageTile extends StatelessWidget {
  const _StageTile({
    required this.stage,
    required this.boss,
    required this.done,
    required this.unlocked,
    required this.onTap,
  });

  final Stage stage;
  final bool boss;
  final bool done;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final art = unlocked ? bossArtFor(stage.enemy) : null;
    return GreekPanel(
      padding: EdgeInsets.zero,
      dimmed: !unlocked,
      highlight: boss || (unlocked && !done),
      child: ListTile(
        enabled: unlocked,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: art != null
            ? BossPortrait(art: art, size: boss ? 64 : 52)
            : SizedBox.square(
                dimension: 52,
                child: Center(
                  child: Text(
                    unlocked ? stage.emoji : '🔒',
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
        title: Text(
          '${stage.code}  ${stage.title}',
          style:
              (boss ? theme.textTheme.titleMedium : theme.textTheme.titleSmall)
                  ?.copyWith(
                    color: unlocked ? GreekUi.ink : GreekUi.inkDim,
                    fontWeight: boss ? FontWeight.w800 : FontWeight.w600,
                  ),
        ),
        subtitle: unlocked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stage.lore.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        stage.lore,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: GreekUi.inkDim,
                        ),
                      ),
                    ),
                  Text(
                    '🎯 ${stage.tip}',
                    style: const TextStyle(color: GreekUi.ink),
                  ),
                ],
              )
            : const Text('Thắng màn trước để mở'),
        trailing: done
            ? const Icon(Icons.check_circle, color: Colors.lightGreen)
            : unlocked
            ? const Icon(Icons.play_arrow)
            : null,
        onTap: unlocked ? onTap : null,
      ),
    );
  }
}

/// Bản đồ thung lũng có hoạt hình (nước chảy, điểm kế tiếp nhấp nháy);
/// chạm vào điểm màn đã mở để chơi.
class _StageMap extends StatefulWidget {
  const _StageMap({required this.states, required this.onTap});

  final List<MapNodeState> states;
  final void Function(int index) onTap;

  @override
  State<_StageMap> createState() => _StageMapState();
}

class _StageMapState extends State<_StageMap>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(
    (e) => setState(() => _seconds = e.inMicroseconds / 1e6),
  );
  double _seconds = 0;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = box.maxWidth / nemeaMapSize.width;
      return GestureDetector(
        onTapUp: (d) {
          final p = d.localPosition / scale;
          for (var i = 0; i < nemeaMapNodes.length; i++) {
            if ((nemeaMapNodes[i] - p).distance < 18 &&
                widget.states[i] != MapNodeState.locked) {
              widget.onTap(i);
              return;
            }
          }
        },
        child: CustomPaint(
          size: Size(box.maxWidth, box.maxWidth / nemeaMapSize.aspectRatio),
          painter: _MapPainter(widget.states, _seconds),
        ),
      );
    },
  );
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.states, this.seconds);

  final List<MapNodeState> states;
  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / nemeaMapSize.width);
    paintNemeaMap(canvas, states, time: seconds);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MapPainter old) => true;
}
