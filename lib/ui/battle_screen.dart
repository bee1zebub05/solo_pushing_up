import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../art/hero_art.dart';
import '../art/battle_stage.dart';
import '../art/bosses/boss_registry.dart';
import '../game/battle.dart';
import '../game/labors.dart';
import '../game/progress.dart';
import '../pose/pose_frame.dart';
import '../rep/pushup_counter.dart';
import '../session/workout_session.dart';
import '../sim/pose_simulator.dart';
import 'depth_bar.dart';
import 'pill.dart';
import 'pose_source_view.dart';

/// Màn chiến đấu thô (rules/congnghe.md lộ trình bước 2): mỗi rep là một đòn.
/// Hình ảnh tạm (biểu tượng), chưa có art.
/// Kết quả một trận, gửi cho màn hình gọi để ghi tiến trình.
class BattleOutcome {
  const BattleOutcome({
    required this.won,
    required this.reps,
    required this.bestCombo,
  });

  final bool won;
  final int reps;
  final int bestCombo;
}

class BattleScreen extends StatefulWidget {
  const BattleScreen({
    super.key,
    required this.enemy,
    required this.mode,
    this.emoji = '👾',
    this.victoryText,
    this.onFinished,
    this.heroCloak = false,
    this.heroShield = false,
    this.heroSword = false,
    this.heroHorse = false,
    this.heroLook = const HeroLook(),
  });

  final EnemySpec enemy;
  final PushupMode mode;

  /// Hình tạm của kẻ thù cho tới khi có art.
  final String emoji;
  final String? victoryText;

  /// Người chơi đã có Áo choàng da sư tử (vẽ lên nhân vật).
  final bool heroCloak;

  /// Đã có Khiên vảy rồng / Kiếm Kusanagi (vẽ lên nhân vật).
  final bool heroShield;
  final bool heroSword;

  /// Đã có Ngựa chín hồng mao (xuất hiện khi thắng).
  final bool heroHorse;

  /// Ngoại hình nhân vật người chơi đã tạo.
  final HeroLook heroLook;

  /// Gọi một lần khi trận kết thúc; trả về phần thưởng để hiện.
  final Future<BattleReward?> Function(BattleOutcome outcome)? onFinished;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final WorkoutSession _session = WorkoutSession(mode: widget.mode);
  late Battle _battle = Battle(enemy: widget.enemy, mode: widget.mode);

  /// Rung kẻ thù khi trúng đòn.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  BattleEvent? _lastEvent;
  int _lastEventKey = 0;
  int _nowMs = 0;

  /// Lúc người chơi bắt đầu hạ người trong rep đang làm (null = đang ở trên).
  /// Mức lạnh dừng ở mốc này, vì luật tính nghỉ tới lúc bắt đầu hạ người:
  /// rep chậm không bị coi là nghỉ.
  int? _descentStartMs;
  bool _reported = false;
  BattleReward? _reward;

  /// Sân khấu có nhân vật và hoạt hình cho các boss đã vẽ; các trận khác
  /// vẫn dùng biểu tượng tạm.
  late final BattleStageGame? _stage = switch (_bossArt()) {
    final art? => BattleStageGame(
      boss: art,
      cloak: widget.heroCloak,
      shield: widget.heroShield,
      sword: widget.heroSword,
      horse: widget.heroHorse,
      look: widget.heroLook,
    ),
    null => null,
  };

  BossArt? _bossArt() => bossArtFor(widget.enemy);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _session
      ..addListener(_onSessionChanged)
      ..frameListeners.add(_onFrame)
      ..init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _shake.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _session.handleLifecycle(state);

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  void _onFrame(PoseFrame frame, CounterSnapshot snapshot) {
    _nowMs = frame.timestampMs;
    final inRep =
        snapshot.phase == CounterPhase.goingDown ||
        snapshot.phase == CounterPhase.bottom;
    _descentStartMs = inRep ? (_descentStartMs ?? frame.timestampMs) : null;
    // Cơ chế boss hiện lên sân khấu: mực nước, đầu còn lại.
    _stage?.battle
      ?..water = _battle.water
      ..headsLeft = _battle.headsLeft
      ..totalHeads = widget.enemy.heads
      ..headHp = _battle.headHp / widget.enemy.headMaxHp
      ..cold = _battle.coldAt(_descentStartMs ?? frame.timestampMs);
    _stage?.updatePlayer(
      elbowAngle: snapshot.phase == CounterPhase.searching
          ? null
          : snapshot.elbowAngle,
      onKnees: snapshot.posture == Posture.knee,
    );
    final events = [
      ..._battle.apply(snapshot.events),
      ..._battle.tick(frame.timestampMs, plankHoldMs: snapshot.plankHoldMs),
    ];
    if (events.isEmpty) return;
    // Sự kiện đổi cục diện (chém đứt / mọc đầu) quan trọng hơn con số damage.
    _lastEvent =
        events.whereType<HeadSevered>().firstOrNull ??
        events.whereType<HeadRegrown>().firstOrNull ??
        events.whereType<WaveStarted>().firstOrNull ??
        events.last;
    _lastEventKey++;
    if (events.any((e) => e is Hit)) _shake.forward(from: 0);
    if (_stage case final stage?) {
      for (final e in events) {
        switch (e) {
          case Hit(:final critical):
            stage.hit(critical: critical);
          case Blocked():
            stage.blocked();
          case Victory():
            stage.victory();
          default:
        }
      }
    }
    for (final wave in events.whereType<WaveStarted>()) {
      _session.feedback.announce('Sóng mới. ${wave.wave.action.label}');
    }
    if (!_reported && events.any((e) => e is Victory || e is Defeat)) {
      _reported = true;
      _report(won: events.any((e) => e is Victory));
    }
  }

  Future<void> _report({required bool won}) async {
    final reward = await widget.onFinished?.call(
      BattleOutcome(won: won, reps: _battle.reps, bestCombo: _battle.bestCombo),
    );
    if (mounted) setState(() => _reward = reward);
    if (reward?.item == nemea.reward) _stage?.equipCloak();
    if (reward?.item == labors.last.reward) _stage?.arriveHorse();
  }

  void _restart() {
    setState(() {
      _battle = Battle(enemy: widget.enemy, mode: widget.mode);
      _lastEvent = null;
      _reported = false;
      _reward = null;
    });
    _stage?.reset();
    _session.resetCounter();
  }

  Future<void> _openSimulator() async {
    final scenario = await showModalBottomSheet<SimScenario>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        children: [
          const ListTile(
            title: Text('Đánh bằng người ảo'),
            subtitle: Text('Để thử trận đấu khi không tiện hít đất'),
          ),
          for (final s in simScenarios)
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text(s.name),
              subtitle: Text(s.expectation),
              onTap: () => Navigator.of(context).pop(s),
            ),
        ],
      ),
    );
    if (scenario == null || !mounted) return;
    _session.playScenario(scenario, keepCount: true);
  }

  @override
  Widget build(BuildContext context) {
    final finished =
        _battle.status == BattleStatus.won ||
        _battle.status == BattleStatus.lost;
    if (_stage case final stage?) return _buildStaged(stage, finished);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera mờ đi làm nền, để kẻ thù và thanh máu nổi bật.
            Positioned.fill(
              child: Opacity(
                opacity: 0.55,
                child: PoseSourceView(
                  session: _session,
                  onOpenSimulator: _openSimulator,
                ),
              ),
            ),
            Positioned(top: 8, left: 8, right: 8, child: _buildTopBar()),
            Positioned(
              // Trận Thuỷ Tinh có thêm thanh nước và đợt sóng ở trên.
              top: widget.enemy.armor == BattleArmor.risingFlood ? 190 : 120,
              left: 0,
              right: 0,
              child: _buildEnemy(),
            ),
            Positioned(left: 16, right: 16, bottom: 24, child: _buildStatus()),
            Positioned(
              right: 12,
              top: 260,
              bottom: 90,
              child: DepthBar(snapshot: _session.snapshot),
            ),
            if (finished) Positioned.fill(child: _buildResult()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final remaining = _battle.remainingMs(_nowMs);
    return Column(
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: 'Rời trận',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.enemy.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (remaining != null)
              Pill(
                text: '${(remaining / 1000).ceil()}s',
                color: remaining < 10000 ? Colors.red.shade700 : Colors.black54,
              ),
            IconButton.filledTonal(
              tooltip: 'Đánh bằng người ảo',
              onPressed: _openSimulator,
              icon: const Icon(Icons.smart_toy_outlined),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: _battle.hpFraction),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 18,
              backgroundColor: Colors.white12,
              color: Color.lerp(Colors.red, Colors.lightGreen, value),
            ),
          ),
        ),
        if (_battle.currentWave(_nowMs) case final wave?) ...[
          const SizedBox(height: 6),
          _buildFlood(wave),
        ],
        const SizedBox(height: 4),
        Text(
          widget.enemy.heads > 1
              ? 'Đầu ${math.min(widget.enemy.heads, widget.enemy.heads - _battle.headsLeft + 1)}'
                    '/${widget.enemy.heads} · '
                    'HP đầu ${_battle.headHp}/${widget.enemy.headMaxHp}'
              : 'HP ${_battle.hp}/${widget.enemy.maxHp}',
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  /// Thuỷ Tinh: mực nước và đợt sóng đang đòi hành động gì.
  Widget _buildFlood(Wave wave) {
    final water = _battle.water;
    final waveLeft = (_battle.waveRemainingMs(_nowMs) / 1000).ceil();
    return Column(
      children: [
        Row(
          children: [
            const Text('🌊', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: water / 100,
                  minHeight: 12,
                  backgroundColor: Colors.white12,
                  color: water > 75 ? Colors.redAccent : Colors.blueAccent,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Nước ${water.round()}%',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Pill(
          text: _battle.status == BattleStatus.ready
              ? 'Đợt đầu: ${wave.action.icon} ${wave.action.label}'
              : '${wave.action.icon} ${wave.action.label} · ${waveLeft}s',
          color: Colors.blue.shade800,
        ),
      ],
    );
  }

  /// Bố cục có sân khấu: trên là trận đấu hoạt hình, dưới là camera.
  Widget _buildStaged(BattleStageGame stage, bool finished) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: _buildTopBar(),
                ),
                AspectRatio(
                  aspectRatio: 400 / 260,
                  child: Stack(
                    children: [
                      Positioned.fill(child: GameWidget(game: stage)),
                      Positioned(
                        top: 44,
                        left: 0,
                        right: 0,
                        child: Center(child: _buildEventLabel()),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.8,
                          child: PoseSourceView(
                            session: _session,
                            onOpenSimulator: _openSimulator,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: _buildStatus(),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        bottom: 72,
                        child: DepthBar(snapshot: _session.snapshot),
                      ),
                      // Kết quả chỉ che phần camera, để sân khấu vẫn thấy
                      // cảnh ăn mừng và khoác áo choàng.
                      if (finished) Positioned.fill(child: _buildResult()),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Số sát thương / thông báo bay lên, chạy lại mỗi sự kiện.
  Widget _buildEventLabel() {
    final event = _lastEvent;
    if (event == null) return const SizedBox.shrink();
    return TweenAnimationBuilder<double>(
      key: ValueKey(_lastEventKey),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      builder: (context, t, child) => Opacity(
        opacity: 1 - t * 0.6,
        child: Transform.translate(offset: Offset(0, -30 * t), child: child),
      ),
      child: _eventLabel(event),
    );
  }

  Widget _buildEnemy() {
    final event = _lastEvent;
    return Column(
      children: [
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(math.sin(_shake.value * math.pi * 6) * 12, 0),
            child: child,
          ),
          child: Text(
            widget.emoji,
            style: TextStyle(
              fontSize: 120,
              color: Colors.white.withValues(
                alpha: _battle.status == BattleStatus.won ? 0.3 : 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Key đổi theo sự kiện để hiệu ứng chạy lại mỗi đòn.
        if (event != null)
          TweenAnimationBuilder<double>(
            key: ValueKey(_lastEventKey),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            builder: (context, t, child) => Opacity(
              opacity: 1 - t * 0.6,
              child: Transform.translate(
                offset: Offset(0, -30 * t),
                child: child,
              ),
            ),
            child: _eventLabel(event),
          ),
      ],
    );
  }

  Widget _eventLabel(BattleEvent event) => switch (event) {
    Hit(
      :final damage,
      :final critical,
      :final frozen,
      :final matched,
      :final held,
    ) =>
      Text(
        [
          if (frozen) '❄',
          if (held) '⏸',
          '-$damage',
          if (critical) 'CHÍ MẠNG!',
          if (frozen) 'ĐÓNG BĂNG',
          if (matched) 'ĐÚNG SÓNG!',
        ].join(' '),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: frozen
              ? Colors.lightBlueAccent
              : matched
              ? Colors.cyanAccent
              : critical
              ? Colors.amberAccent
              : Colors.white,
          fontSize: critical ? 40 : 34,
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(blurRadius: 8)],
        ),
      ),
    Blocked(:final reason) => Pill(
      text: '🛡 $reason',
      color: Colors.blueGrey.shade700,
    ),
    HeadSevered(:final headsLeft) => Text(
      '⚔ CHÉM ĐỨT 1 ĐẦU! Còn $headsLeft',
      style: const TextStyle(
        color: Colors.amberAccent,
        fontSize: 26,
        fontWeight: FontWeight.w900,
        shadows: [Shadow(blurRadius: 8)],
      ),
    ),
    HeadRegrown(:final healed) => Pill(
      text: '🐍 Đứt combo, đầu mọc lại +$healed HP',
      color: Colors.purple.shade700,
    ),
    WaveStarted(:final wave) => Pill(
      text: '🌊 Đợt sóng mới: ${wave.action.icon} ${wave.action.label}',
      color: Colors.blue.shade800,
    ),
    Victory() || Defeat() => const SizedBox.shrink(),
  };

  Widget _buildStatus() {
    final snapshot = _session.snapshot;
    final hint = switch (snapshot?.phase) {
      null || CounterPhase.searching =>
        _battle.status == BattleStatus.ready
            ? 'Vào tư thế chống đẩy để bắt đầu'
            : 'Vào lại tư thế chống đẩy',
      CounterPhase.top => 'Xuống!',
      CounterPhase.goingDown => 'Xuống sâu…',
      CounterPhase.bottom => 'Đẩy lên!',
    };
    return Row(
      children: [
        Pill(text: hint),
        const Spacer(),
        if (_battle.combo >= 2)
          Pill(text: 'COMBO ×${_battle.combo}', color: Colors.deepOrange),
        const SizedBox(width: 8),
        Pill(text: '${_battle.reps} rep', color: Colors.black87),
      ],
    );
  }

  Widget _buildResult() {
    final won = _battle.status == BattleStatus.won;
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              won
                  ? 'CHIẾN THẮNG'
                  : _battle.defeatReason == DefeatReason.flooded
                  ? 'NƯỚC NGẬP NÚI'
                  : 'HẾT GIỜ',
              style: TextStyle(
                color: won ? Colors.amberAccent : Colors.redAccent,
                fontSize: 40,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            if (won && widget.victoryText != null)
              Text(
                widget.victoryText!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            const SizedBox(height: 16),
            Text(
              '${_battle.reps} rep · combo cao nhất ×${_battle.bestCombo}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            if (_reward case final reward?) ...[
              const SizedBox(height: 12),
              Text(
                '+${reward.xp} XP'
                '${reward.levelsGained > 0 ? ' · LÊN CẤP!' : ''}',
                style: const TextStyle(
                  color: Colors.lightGreenAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (reward.item != null)
                Text(
                  '🎁 ${reward.item}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              if (reward.unlockedLabor case final next?)
                Text(
                  '🔓 Mở khoá Kỳ công ${next.number}: ${next.title}',
                  style: const TextStyle(color: Colors.amberAccent),
                ),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.replay),
                  label: const Text('Đánh lại'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.home),
                  label: const Text('Về'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
