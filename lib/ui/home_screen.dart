import 'package:flutter/material.dart';

import '../art/bosses/boss_registry.dart';
import '../art/hero_art.dart';
import '../game/battle.dart';
import '../game/labors.dart';
import '../game/progress.dart';
import '../game/player_profile.dart';
import '../game/profile_store.dart';
import '../game/progress_store.dart';
import '../rep/pushup_counter.dart';
import 'battle_screen.dart';
import 'boss_portrait.dart';
import 'character_creator_screen.dart';
import 'counter_screen.dart';
import 'hero_preview.dart';

/// Màn hình chính tạm: tiến trình, chọn chế độ, các kỳ công, luyện tập,
/// và màn hình đếm (debug).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PushupMode _mode = PushupMode.standard;
  PlayerProgress? _progress;
  PlayerProfile? _profile;

  @override
  void initState() {
    super.initState();
    ProgressStore.load().then((p) {
      if (mounted) setState(() => _progress = p);
    });
    ProfileStore.load().then((profile) {
      if (!mounted) return;
      if (profile == null) {
        // Lần đầu mở app: tạo nhân vật trước.
        _editCharacter();
      } else {
        setState(() => _profile = profile);
      }
    });
  }

  bool get _hasCloak => _progress?.items.contains(nemea.reward) ?? false;

  bool _hasReward(String laborId) =>
      _progress?.items.contains(
        labors.firstWhere((l) => l.id == laborId).reward,
      ) ??
      false;
  bool get _hasShield => _hasReward('fafnir');
  bool get _hasSword => _hasReward('orochi');
  bool get _hasHorse => _hasReward('thuy_tinh');

  Future<void> _editCharacter() async {
    final saved = await Navigator.of(context).push<PlayerProfile>(
      MaterialPageRoute(
        fullscreenDialog: _profile == null,
        builder: (_) =>
            CharacterCreatorScreen(initial: _profile, cloak: _hasCloak),
      ),
    );
    if (saved != null && mounted) setState(() => _profile = saved);
  }

  Future<BattleReward?> _recordOutcome(
    BattleOutcome outcome, {
    Labor? labor,
  }) async {
    final progress = _progress;
    if (progress == null) return null;
    final reward = progress.recordBattle(
      reps: outcome.reps,
      bestCombo: outcome.bestCombo,
      won: outcome.won,
      mode: _mode,
      labor: labor,
    );
    await ProgressStore.save(progress);
    if (mounted) setState(() {});
    return reward;
  }

  void _openBattle({
    required EnemySpec enemy,
    required String emoji,
    Labor? labor,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BattleScreen(
          enemy: enemy,
          mode: _mode,
          emoji: emoji,
          victoryText: labor == null
              ? null
              : 'Kỳ công ${labor.number} hoàn thành',
          onFinished: (outcome) => _recordOutcome(outcome, labor: labor),
          heroCloak: _hasCloak,
          heroShield: _hasShield,
          heroSword: _hasSword,
          heroHorse: _hasHorse,
          heroLook: _profile?.look ?? const HeroLook(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _progress;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('12 Kỳ Công', style: theme.textTheme.displaySmall),
            const SizedBox(height: 4),
            Text(
              'Người kế nhiệm của Hercules',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            if (_profile case final profile?) ...[
              _CharacterCard(
                profile: profile,
                mode: _mode,
                cloak: _hasCloak,
                shield: _hasShield,
                sword: _hasSword,
                onEdit: _editCharacter,
              ),
              const SizedBox(height: 12),
            ],
            if (progress != null) _ProgressCard(progress: progress),
            const SizedBox(height: 24),
            Text('Chế độ', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<PushupMode>(
              segments: const [
                ButtonSegment(
                  value: PushupMode.knee,
                  label: Text('Tân binh'),
                  icon: Icon(Icons.accessibility_new),
                ),
                ButtonSegment(
                  value: PushupMode.standard,
                  label: Text('Chiến binh'),
                  icon: Icon(Icons.fitness_center),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.single),
            ),
            const SizedBox(height: 4),
            Text(
              _mode == PushupMode.knee
                  ? 'Chống gối · sát thương và XP ×0,7'
                  : 'Push-up chuẩn · sát thương và XP đầy đủ',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            Text('Hành trình', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final labor in labors) _laborCard(labor, progress),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(Icons.timer_outlined, size: 40),
                title: const Text('Thử thách 30 giây'),
                subtitle: const Text('Hạ bù nhìn 300 HP trước khi hết giờ'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openBattle(enemy: trainingDummy, emoji: '🎯'),
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CounterScreen()),
              ),
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('Chế độ đếm (debug, ghi dữ liệu test)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _laborCard(Labor labor, PlayerProgress? progress) {
    final unlocked = progress?.isUnlocked(labor) ?? labor.number == 1;
    final done = progress?.completedLabors.contains(labor.id) ?? false;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        enabled: unlocked,
        contentPadding: const EdgeInsets.all(16),
        leading: switch (unlocked ? bossArtFor(labor.enemy) : null) {
          final art? => BossPortrait(art: art),
          null => Text(
            unlocked ? labor.emoji : '🔒',
            style: const TextStyle(fontSize: 40),
          ),
        },
        title: Text('Kỳ công ${labor.number} — ${labor.title}'),
        subtitle: Text(
          unlocked
              ? '${labor.region}\n${labor.mechanic}'
              : 'Hoàn thành Kỳ công ${previousLabor(labor)?.number} để mở',
        ),
        isThreeLine: unlocked,
        trailing: done
            ? const Icon(Icons.check_circle, color: Colors.lightGreen)
            : const Icon(Icons.chevron_right),
        onTap: unlocked
            ? () => _openBattle(
                enemy: labor.enemy,
                emoji: labor.emoji,
                labor: labor,
              )
            : null,
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.profile,
    required this.mode,
    required this.cloak,
    required this.shield,
    required this.sword,
    required this.onEdit,
  });

  final PlayerProfile profile;
  final PushupMode mode;
  final bool cloak;
  final bool shield;
  final bool sword;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 120,
              child: HeroPreview(
                look: profile.look,
                cloak: cloak,
                shield: shield,
                sword: sword,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name.isEmpty ? 'Người kế nhiệm' : profile.name,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.heightCm.round()} cm · '
                      '${profile.weightKg.round()} kg · '
                      'BMI ${profile.bmi.toStringAsFixed(1)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      'Mỗi rep đẩy ~${profile.liftPerRepKg(mode).round()} kg',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});

  final PlayerProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toNext = PlayerProgress.xpToNext(progress.level);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Cấp ${progress.level}',
                  style: theme.textTheme.titleLarge,
                ),
                const Spacer(),
                Text('${progress.xp}/$toNext XP'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.xp / toNext,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            Text(
              'Tổng ${progress.totalReps} rep · combo cao nhất '
              '×${progress.bestCombo}',
              style: theme.textTheme.bodyMedium,
            ),
            if (progress.items.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final item in progress.items)
                    Chip(
                      avatar: const Text('🎁'),
                      label: Text(item),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
