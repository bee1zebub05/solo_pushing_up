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
import 'greek_ui.dart';
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
    this.goldStolen = 0,
  });

  final bool won;
  final int reps;
  final int bestCombo;

  /// Túi vàng bị Harpy cướp trong trận.
  final int goldStolen;
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
      ..cold = _battle.coldAt(_descentStartMs ?? frame.timestampMs)
      ..bossHp = _battle.hpFraction
      ..charge = _battle.chargeAt(frame.timestampMs)
      ..goldStolen = _battle.goldStolen;
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
        events.whereType<ChargeWarning>().firstOrNull ??
        events.whereType<ChargeLanded>().firstOrNull ??
        events.whereType<Revived>().firstOrNull ??
        events.whereType<GoldStolen>().firstOrNull ??
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
          case Revived():
            stage.battle.revives++;
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
      BattleOutcome(
        won: won,
        reps: _battle.reps,
        bestCombo: _battle.bestCombo,
        goldStolen: _battle.goldStolen,
      ),
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
    if (_stage case final stage?) {
      return _guardExit(finished, _buildStaged(stage, finished));
    }
    return _guardExit(
      finished,
      Scaffold(
        backgroundColor: GreekUi.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => _buildPlain(box, finished),
          ),
        ),
      ),
    );
  }

  /// Chặn thoát trận ngoài ý muốn: trên iPhone, vuốt từ mép trái là quay
  /// lại — dễ chạm phải khi chỉnh máy giữa trận. Đang đánh thì tắt cử chỉ
  /// vuốt; nút quay lại của Android hỏi lại trước khi rời. Nút ✕ vẫn rời ngay.
  Widget _guardExit(bool finished, Widget child) {
    return PopScope(
      canPop: finished || _battle.status == BattleStatus.ready,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Rời trận?'),
            content: const Text(
              'Trận đang diễn ra. Rời bây giờ sẽ mất tiến độ của trận này.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Ở lại'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Rời trận'),
              ),
            ],
          ),
        );
        if (leave == true && mounted) Navigator.of(context).pop();
      },
      child: child,
    );
  }

  /// Bố cục không có sân khấu: camera mờ làm nền, kẻ thù và thanh máu đè lên.
  Widget _buildPlain(BoxConstraints box, bool finished) {
    // Màn ngang (iPhone nằm ngang chỉ còn ~350 pt chiều cao): kéo kẻ thù và
    // thanh độ sâu lên cao, không để vị trí cố định cho màn dọc bị âm.
    final landscape = box.maxWidth > box.maxHeight;
    final flood = widget.enemy.armor == BattleArmor.risingFlood;
    return Stack(
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
          top: landscape ? (flood ? 150 : 96) : (flood ? 190 : 120),
          left: 0,
          right: 0,
          child: _buildEnemy(),
        ),
        Positioned(left: 16, right: 16, bottom: 24, child: _buildStatus()),
        Positioned(
          right: 12,
          top: landscape ? 96 : 260,
          bottom: landscape ? 72 : 90,
          child: DepthBar(snapshot: _session.snapshot),
        ),
        if (finished) Positioned.fill(child: _buildResult()),
      ],
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
                  color: GreekUi.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  shadows: [Shadow(color: Color(0xCC000000), blurRadius: 4)],
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
        // Thanh máu khung đồng: viền vàng, rãnh tối, máu chuyển đỏ→vàng→lục
        // có vệt sáng trên (khối trụ), vạch chia mỗi 10 %.
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: GreekUi.gold, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x88000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _battle.hpFraction),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, _) => SizedBox(
                height: 18,
                width: double.infinity,
                child: CustomPaint(painter: _HpBarPainter(value)),
              ),
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

  /// Bố cục có sân khấu. Dọc (mặc định trên iPhone): trên là trận đấu hoạt
  /// hình, dưới là camera. Ngang: sân khấu bên trái, camera bên phải — cột
  /// dọc sẽ tràn vì sân khấu 400:260 cao hơn cả màn hình khi nằm ngang.
  Widget _buildStaged(BattleStageGame stage, bool finished) {
    final stageView = AspectRatio(
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
    );
    final cameraView = Stack(
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
        Positioned(left: 16, right: 16, bottom: 16, child: _buildStatus()),
        Positioned(
          right: 12,
          top: 12,
          bottom: 72,
          child: DepthBar(snapshot: _session.snapshot),
        ),
        // Kết quả chỉ che phần camera, để sân khấu vẫn thấy cảnh ăn mừng
        // và khoác áo choàng.
        if (finished) Positioned.fill(child: _buildResult()),
      ],
    );
    final topBar = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: _buildTopBar(),
    );
    return Scaffold(
      backgroundColor: GreekUi.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth > box.maxHeight) {
              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        topBar,
                        Expanded(child: Center(child: stageView)),
                      ],
                    ),
                  ),
                  Expanded(flex: 2, child: cameraView),
                ],
              );
            }
            return Column(
              children: [
                topBar,
                stageView,
                Expanded(child: cameraView),
              ],
            );
          },
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
    Revived(:final hp) => Pill(
      text: '💀 Spartoi đứng dậy! +$hp HP — đánh dứt điểm',
      color: Colors.brown.shade700,
    ),
    ChargeWarning() => Pill(
      text: '🐗 Lợn rừng sắp húc! GIỮ TAY THẲNG để né',
      color: Colors.red.shade800,
    ),
    ChargeLanded(:final dodged, :final healed) => Pill(
      text: dodged
          ? '🐗 Né được cú húc!'
          : '🐗 Bị húc! Lợn rừng hồi +$healed HP',
      color: dodged ? Colors.green.shade700 : Colors.red.shade800,
    ),
    GoldStolen(:final total) => Pill(
      text: '🪙 Harpy cướp vàng! (mất $total túi) — đừng nghỉ lâu',
      color: Colors.amber.shade900,
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
    final accent = won ? GreekUi.gold : const Color(0xFFE57373);
    final title = won
        ? 'CHIẾN THẮNG'
        : _battle.defeatReason == DefeatReason.flooded
        ? 'NƯỚC NGẬP NÚI'
        : 'HẾT GIỜ';
    // Bảng kết quả kiểu bia đá trong đền: nền gỗ sẫm, viền vàng, dải
    // meander trên dưới tựa, chữ ngà; thưởng xếp thành các dòng có biểu
    // tượng. Nền sau mờ để sân khấu (cảnh ăn mừng) vẫn thấy.
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: GreekPanel(
              highlight: won,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 7,
                    width: double.infinity,
                    child: CustomPaint(painter: MeanderPainter(color: accent)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: accent,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      shadows: const [
                        Shadow(color: Color(0xCC000000), blurRadius: 6),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 7,
                    width: double.infinity,
                    child: CustomPaint(painter: MeanderPainter(color: accent)),
                  ),
                  if (won && widget.victoryText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.victoryText!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: GreekUi.ink,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _resultRow(
                    Icons.fitness_center,
                    '${_battle.reps} rep',
                    'combo cao nhất ×${_battle.bestCombo}',
                  ),
                  if (_reward case final reward?) ...[
                    _resultRow(
                      Icons.auto_awesome,
                      '+${reward.xp} XP',
                      reward.levelsGained > 0 ? 'LÊN CẤP!' : null,
                      color: Colors.lightGreenAccent,
                    ),
                    if (reward.item case final item?)
                      _resultRow(Icons.card_giftcard, item, 'phần thưởng'),
                    if (reward.unlockedLabor case final next?)
                      _resultRow(
                        Icons.lock_open,
                        'Kỳ công ${next.number}: ${next.title}',
                        'đã mở khoá',
                        color: GreekUi.gold,
                      ),
                  ],
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: GreekUi.gold,
                          foregroundColor: const Color(0xFF2B211A),
                        ),
                        onPressed: _restart,
                        icon: const Icon(Icons.replay),
                        label: const Text('Đánh lại'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: GreekUi.ink,
                          side: const BorderSide(color: GreekUi.goldDim),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.home),
                        label: const Text('Về'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultRow(
    IconData icon,
    String main,
    String? sub, {
    Color color = GreekUi.ink,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, color: GreekUi.gold, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: main,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (sub != null)
                  TextSpan(
                    text: '  ·  $sub',
                    style: const TextStyle(color: GreekUi.inkDim, fontSize: 14),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _HpBarPainter extends CustomPainter {
  _HpBarPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(r, Paint()..color = const Color(0xFF241A14));
    final v = value.clamp(0.0, 1.0);
    final fill = Rect.fromLTWH(0, 0, size.width * v, size.height);
    final base = v > 0.5
        ? Color.lerp(
            const Color(0xFFE8B83A),
            const Color(0xFF7CB342),
            (v - 0.5) * 2,
          )!
        : Color.lerp(const Color(0xFFD32F2F), const Color(0xFFE8B83A), v * 2)!;
    canvas.drawRect(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(base, Colors.white, 0.35)!,
            base,
            Color.lerp(base, Colors.black, 0.35)!,
          ],
          stops: const [0, 0.45, 1],
        ).createShader(r),
    );
    final tick = Paint()
      ..color = const Color(0x66000000)
      ..strokeWidth = 1;
    for (var i = 1; i < 10; i++) {
      final x = size.width * i / 10;
      canvas.drawLine(
        Offset(x, size.height * 0.25),
        Offset(x, size.height * 0.75),
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(_HpBarPainter old) => old.value != value;
}
