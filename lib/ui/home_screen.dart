import 'package:flutter/material.dart';

import '../art/bosses/boss_registry.dart';
import '../art/bosses/dummy_art.dart';
import '../art/bosses/nemea_boss.dart' show lionScale, lionX;
import '../art/hero_art.dart';
import '../art/hero_pose.dart';
import '../art/lion_art.dart';
import '../art/nemea_scene.dart';
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
import 'greek_ui.dart';
import 'hero_preview.dart';
import 'nemea_intro_screen.dart';
import 'stage_select_screen.dart';

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
    Stage? stage,
  }) async {
    final progress = _progress;
    if (progress == null) return null;
    final reward = progress.recordBattle(
      reps: outcome.reps,
      bestCombo: outcome.bestCombo,
      won: outcome.won,
      mode: _mode,
      labor: labor,
      stage: stage,
      goldStolen: outcome.goldStolen,
    );
    await ProgressStore.save(progress);
    if (mounted) setState(() {});
    return reward;
  }

  Future<void> _openBattle({
    required EnemySpec enemy,
    required String emoji,
    Labor? labor,
    Stage? stage,
  }) async {
    final boss = labor != null && stage?.id == labor.allStages.last.id;
    final battle = MaterialPageRoute<void>(
      builder: (_) => BattleScreen(
        enemy: enemy,
        mode: _mode,
        emoji: emoji,
        victoryText: labor == null
            ? null
            : boss || stage == null
            ? 'Kỳ công ${labor.number} hoàn thành'
            : 'Màn ${stage.code} hoàn thành',
        onFinished: (outcome) =>
            _recordOutcome(outcome, labor: labor, stage: stage),
        heroCloak: _hasCloak,
        heroShield: _hasShield,
        heroSword: _hasSword,
        heroHorse: _hasHorse,
        heroLook: _profile?.look ?? const HeroLook(),
      ),
    );
    // Lần đầu vào Kỳ công 1 (màn 1.1): Hercules xuất hiện dặn dò trước trận.
    final progress = _progress;
    final firstNemea =
        labor?.id == nemea.id &&
        stage?.id == nemea.allStages.first.id &&
        progress != null &&
        !progress.isStageDone(nemea.allStages.first) &&
        !progress.completedLabors.contains(nemea.id);
    if (!firstNemea) {
      await Navigator.of(context).push(battle);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => NemeaIntroScreen(
          look: _profile?.look ?? const HeroLook(),
          onDone: () => Navigator.of(context).pushReplacement(battle),
        ),
      ),
    );
  }

  /// Kỳ công có nhiều màn: mở danh sách màn; chỉ một màn thì vào trận luôn.
  void _openLabor(Labor labor) {
    final progress = _progress;
    if (progress == null) return;
    final stages = labor.allStages;
    if (stages.length == 1) {
      _openBattle(
        enemy: labor.enemy,
        emoji: labor.emoji,
        labor: labor,
        stage: stages.single,
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => StatefulBuilder(
          builder: (context, setInner) => StageSelectScreen(
            labor: labor,
            progress: progress,
            onPlay: (stage) async {
              await _openBattle(
                enemy: stage.enemy,
                emoji: stage.emoji,
                labor: labor,
                stage: stage,
              );
              setInner(() {});
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _progress;
    final nemeaDone = progress?.completedLabors.contains('nemea') ?? false;
    return Scaffold(
      backgroundColor: GreekUi.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _HomeBanner(
              look: _profile?.look ?? const HeroLook(),
              cloak: _hasCloak,
              valleyFreed: nemeaDone,
            ),
            const SizedBox(height: 12),
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
            const GreekHeading('Chế độ'),
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
            const GreekHeading('Hành trình'),
            for (final labor in labors) _laborCard(labor, progress),
            const GreekHeading('Luyện tập'),
            GreekPanel(
              padding: EdgeInsets.zero,
              onTap: () => _openBattle(enemy: trainingDummy, emoji: '🎯'),
              child: ListTile(
                contentPadding: EdgeInsets.all(16),
                leading: BossPortrait(art: TrainingDummyArt()),
                title: Text('Thử thách 30 giây'),
                subtitle: Text('Hạ bù nhìn 300 HP trước khi hết giờ'),
                trailing: Icon(Icons.chevron_right),
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
    return GreekPanel(
      padding: EdgeInsets.zero,
      dimmed: !unlocked,
      highlight: unlocked && !done,
      onTap: unlocked ? () => _openLabor(labor) : null,
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
        title: Text(
          'Kỳ công ${labor.number} — ${labor.title}',
          style: TextStyle(
            color: unlocked ? GreekUi.ink : GreekUi.inkDim,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          unlocked
              ? '${labor.region}\n${labor.mechanic}'
              : 'Hoàn thành Kỳ công ${previousLabor(labor)?.number} để mở',
          style: const TextStyle(color: GreekUi.inkDim, height: 1.35),
        ),
        isThreeLine: unlocked,
        trailing: done
            ? const Icon(Icons.check_circle, color: Colors.lightGreen)
            : const Icon(Icons.chevron_right),
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
    return GreekPanel(
      padding: EdgeInsets.zero,
      onTap: onEdit,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
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
    return GreekPanel(
      child: Padding(
        padding: EdgeInsets.zero,
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
              color: GreekUi.gold,
              backgroundColor: const Color(0xFF4A3C2C),
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

/// Tranh đầu trang: thung lũng Nemea (phủ bụi Trì Trệ cho tới khi thắng sư
/// tử), người kế nhiệm đứng trước hang, sư tử rình; tựa game khắc chữ vàng
/// trên trời. Vẽ tĩnh (không hoạt hình) — phông là ảnh chụp sẵn.
class _HomeBanner extends StatelessWidget {
  const _HomeBanner({
    required this.look,
    required this.cloak,
    required this.valleyFreed,
  });

  final HeroLook look;
  final bool cloak;
  final bool valleyFreed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = theme.textTheme.headlineMedium?.copyWith(
      color: GreekUi.ink,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.5,
      shadows: const [
        Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 2)),
      ],
    );
    // Tựa là một phần của tranh: không phóng theo cỡ chữ hệ thống (chữ to
    // sẽ che nhân vật và sư tử); cỡ chữ theo bề rộng tranh.
    return MediaQuery.withNoTextScaling(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: GreekUi.gold, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: AspectRatio(
            aspectRatio: stageSize.width / stageSize.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _BannerPainter(
                    look: look,
                    cloak: cloak,
                    dust: valleyFreed ? 0 : 0.85,
                  ),
                ),
                // Tựa ở góc trời trên–phải (trên đầu sư tử, không che nhân
                // vật): nền tối mờ dần từ góc để chữ đọc được.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment(0.1, 0.1),
                      colors: [Color(0xCC1C1612), Color(0x001C1612)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 14, 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('12 Kỳ Công', style: title),
                      Text(
                        'Người kế nhiệm của Hercules',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: GreekUi.gold,
                          letterSpacing: 1.2,
                          shadows: const [
                            Shadow(color: Color(0xCC000000), blurRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerPainter extends CustomPainter {
  _BannerPainter({required this.look, required this.cloak, required this.dust});

  final HeroLook look;
  final bool cloak;
  final double dust;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / stageSize.width);
    paintNemeaSceneCached(canvas, time: 2, dust: dust);
    canvas.save();
    canvas.translate(lionX, stageGroundY);
    canvas.scale(lionScale);
    paintLion(canvas, const LionState(time: 1.2));
    canvas.restore();
    canvas.save();
    canvas.translate(120, stageGroundY);
    canvas.scale(0.82);
    canvas.translate(-120, -stageGroundY);
    paintHero(
      canvas,
      HeroPose.standing(x: 120, breath: 0.4),
      look: look,
      cloak: cloak,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BannerPainter old) =>
      old.look != look || old.cloak != cloak || old.dust != dust;
}
