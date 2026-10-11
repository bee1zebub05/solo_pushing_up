import 'package:flutter/material.dart';

import '../art/bosses/boss_registry.dart';
import '../game/labors.dart';
import '../game/progress.dart';
import 'boss_portrait.dart';

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
      appBar: AppBar(title: Text('Kỳ công ${labor.number} — ${labor.title}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(labor.region, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: done / stages.length),
          const SizedBox(height: 4),
          Text('$done/${stages.length} màn', style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
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
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: boss
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE8B83A), width: 2),
            )
          : null,
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
          style: boss
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                )
              : null,
        ),
        subtitle: Text(unlocked ? stage.tip : 'Thắng màn trước để mở'),
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
