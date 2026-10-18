import 'package:flutter/foundation.dart';

import '../game/battle.dart';
import '../game/progress.dart';
import '../pose/pose_frame.dart';
import '../rep/pushup_counter.dart';
import 'workout_session.dart';

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

/// Điều phối một trận: mỗi khung của [session] → [Battle] → [view] và sự kiện
/// cho màn hình, giọng báo đợt sóng, báo kết quả một lần khi trận xong.
/// Màn hình chỉ đọc [view], [headline], [reward] và diễn [onEvents].
class BattleController extends ChangeNotifier {
  BattleController({
    required this.enemy,
    required this.mode,
    required this.session,
    this.onFinished,
  }) {
    session.frameListeners.add(_onFrame);
  }

  final EnemySpec enemy;
  final PushupMode mode;
  final WorkoutSession session;

  /// Gọi một lần khi trận kết thúc; trả về phần thưởng để hiện.
  final Future<BattleReward?> Function(BattleOutcome outcome)? onFinished;

  /// Các sự kiện của một khung (để sân khấu diễn đòn, rung kẻ thù…).
  void Function(List<BattleEvent> events)? onEvents;

  /// Phần thưởng vừa về (để sân khấu diễn vật phẩm mới).
  void Function(BattleReward reward)? onReward;

  late Battle _battle = Battle(enemy: enemy, mode: mode);
  late BattleView _view = _battle.view(0);
  int _nowMs = 0;

  /// Lúc người chơi bắt đầu hạ người trong rep đang làm (null = đang ở trên).
  /// Mức lạnh dừng ở mốc này, vì luật tính nghỉ tới lúc bắt đầu hạ người:
  /// rep chậm không bị coi là nghỉ.
  int? _descentStartMs;

  BattleEvent? _headline;
  int _headlineKey = 0;
  bool _reported = false;
  BattleReward? _reward;
  bool _disposed = false;

  BattleView get view => _view;

  /// Sự kiện nổi bật nhất của khung gần nhất có sự kiện.
  BattleEvent? get headline => _headline;

  /// Tăng mỗi lần có [headline] mới, để hiệu ứng chữ bay chạy lại.
  int get headlineKey => _headlineKey;
  BattleReward? get reward => _reward;

  void _onFrame(PoseFrame frame, CounterSnapshot snapshot) {
    _nowMs = frame.timestampMs;
    final inRep =
        snapshot.phase == CounterPhase.goingDown ||
        snapshot.phase == CounterPhase.bottom;
    _descentStartMs = inRep ? (_descentStartMs ?? _nowMs) : null;
    final events = [
      ..._battle.apply(snapshot.events),
      ..._battle.tick(
        _nowMs,
        plankHoldMs: snapshot.plankHoldMs,
        tracking: !snapshot.trackingLost,
      ),
    ];
    _view = _battle.view(_nowMs, restEndMs: _descentStartMs);
    if (events.isNotEmpty) _handle(events);
    notifyListeners();
  }

  void _handle(List<BattleEvent> events) {
    _headline = _pickHeadline(events);
    _headlineKey++;
    for (final wave in events.whereType<WaveStarted>()) {
      session.feedback.announce('Sóng mới. ${wave.wave.action.label}');
    }
    // Người chơi đang nhìn sàn: đòn báo trước phải nghe được (trụ 3).
    for (final e in events) {
      switch (e) {
        case BossTell(:final dodge):
          session.feedback.announce(dodge == DodgeBy.hold ? 'Giữ tay!' : 'Xuống sâu!');
        case SakeDrinking():
          session.feedback.announce('Ngắt! Đánh liên tục');
        case CurseCast():
          session.feedback.announce('Ấn nguyền. Xuống chậm');
        default:
      }
    }
    onEvents?.call(events);
    if (!_reported && events.any((e) => e is Victory || e is Defeat)) {
      _reported = true;
      _report(won: events.any((e) => e is Victory));
    }
  }

  /// Sự kiện đổi cục diện (húc, đứng dậy, chém đứt / mọc đầu…) quan trọng
  /// hơn con số sát thương.
  static BattleEvent _pickHeadline(List<BattleEvent> events) =>
      events.whereType<BossTell>().firstOrNull ??
      events.whereType<BossStruck>().firstOrNull ??
      events.whereType<SakeDrinking>().firstOrNull ??
      events.whereType<SakeInterrupted>().firstOrNull ??
      events.whereType<SakeFinished>().firstOrNull ??
      events.whereType<CurseCast>().firstOrNull ??
      events.whereType<CurseLifted>().firstOrNull ??
      events.whereType<ChargeWarning>().firstOrNull ??
      events.whereType<ChargeLanded>().firstOrNull ??
      events.whereType<Revived>().firstOrNull ??
      events.whereType<GoldStolen>().firstOrNull ??
      events.whereType<HeadSevered>().firstOrNull ??
      events.whereType<HeadRegrown>().firstOrNull ??
      events.whereType<WaveStarted>().firstOrNull ??
      events.last;

  Future<void> _report({required bool won}) async {
    final battle = _battle;
    final reward = await onFinished?.call(
      BattleOutcome(
        won: won,
        reps: battle.reps,
        bestCombo: battle.bestCombo,
        goldStolen: _view.goldStolen,
      ),
    );
    // Đã đánh lại hoặc rời trận trong lúc chờ lưu: bỏ kết quả cũ.
    if (_disposed || reward == null || !identical(battle, _battle)) return;
    _reward = reward;
    onReward?.call(reward);
    notifyListeners();
  }

  /// Đánh lại từ đầu với kẻ thù cũ.
  void restart() {
    _battle = Battle(enemy: enemy, mode: mode);
    _view = _battle.view(_nowMs);
    _descentStartMs = null;
    _headline = null;
    _reported = false;
    _reward = null;
    session.resetCounter();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    session.frameListeners.remove(_onFrame);
    super.dispose();
  }
}
