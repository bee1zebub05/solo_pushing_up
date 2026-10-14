import 'dart:math' as math;

import '../../rep/pushup_counter.dart';
import '../battle.dart';

/// Kiểu hành động mà một đợt sóng đòi hỏi (rules/cottruyen.md mục 1b).
enum WaveAction {
  fast('⚡', 'Rep nhanh'),
  slow('🐢', 'Rep chậm, xuống 3 giây'),
  hold('⏸', 'Giữ tay thẳng, thân thẳng'),
  deep('💥', 'Rep sâu');

  const WaveAction(this.icon, this.label);

  final String icon;
  final String label;
}

/// Một đợt sóng: hành động được thưởng và độ dài.
class Wave {
  const Wave(this.action, this.durationMs);

  final WaveAction action;
  final int durationMs;
}

/// Thứ tự các đợt sóng của Thuỷ Tinh, lặp lại tới hết trận.
const floodWaves = <Wave>[
  Wave(WaveAction.fast, 12000),
  Wave(WaveAction.slow, 15000),
  Wave(WaveAction.hold, 10000),
  Wave(WaveAction.deep, 12000),
];

/// Thuỷ Tinh — núi dâng, nước dâng: nước (0–100) dâng liên tục, mỗi đòn hạ
/// nước xuống; ngập tới đỉnh thì thua. Trận chia thành các đợt sóng, mỗi đợt
/// đòi một kiểu hành động, đánh đúng kiểu thì mạnh hơn (Kỳ công 12).
class RisingFlood extends BattleMechanic {
  RisingFlood({
    this.risePerSec = 3.5,
    this.drainPerHit = 8,
    this.drainMatched = 16,
    this.matchedMultiplier = 1.5,
    this.holdStrikeEveryMs = 2000,
    this.holdStrikeDamage = 12,
  });

  /// Mực nước dâng bấy nhiêu mỗi giây…
  final double risePerSec;

  /// …mỗi đòn hạ xuống bấy nhiêu, đòn đúng đợt sóng hạ nhiều hơn.
  final double drainPerHit;
  final double drainMatched;

  /// Đòn đúng kiểu đợt sóng đang đòi.
  final double matchedMultiplier;

  /// Đợt sóng ⏸: giữ tư thế cao mỗi bấy lâu là một đòn.
  final int holdStrikeEveryMs;
  final int holdStrikeDamage;

  double _water = 0;
  int? _waterMs;
  int _waveIndex = -1;
  int _holdStrikes = 0;

  double get water => _water;

  static final _cycleMs = floodWaves.fold(0, (sum, w) => sum + w.durationMs);

  /// Vị trí trong chu kỳ sóng tại [nowMs] (đợt đầu nếu chưa bắt đầu):
  /// chỉ số đợt và thời gian còn lại của đợt.
  static (int, int) _waveAt(int? startMs, int nowMs) {
    var into = startMs == null ? 0 : (nowMs - startMs) % _cycleMs;
    for (var i = 0; i < floodWaves.length; i++) {
      final d = floodWaves[i].durationMs;
      if (into < d) return (i, d - into);
      into -= d;
    }
    return (0, floodWaves.first.durationMs);
  }

  @override
  bool get startsOnHold => true;

  @override
  void onStart(BattleHost battle, int t) => _waterMs = t;

  @override
  void onStrike(BattleHost battle, Strike strike) {
    final (index, _) = _waveAt(battle.startMs, strike.rep.timestampMs);
    strike.matched = _matches(floodWaves[index].action, strike.rep);
    if (strike.matched) strike.damage *= matchedMultiplier;
    _drain(strike.matched ? drainMatched : drainPerHit);
  }

  @override
  List<BattleEvent> tick(BattleHost battle, int nowMs, int plankHoldMs) {
    final out = <BattleEvent>[];
    final (index, _) = _waveAt(battle.startMs, nowMs);
    if (index != _waveIndex) {
      _waveIndex = index;
      out.add(WaveStarted(nowMs, floodWaves[index]));
    }

    if (plankHoldMs == 0) _holdStrikes = 0;
    final strikes = plankHoldMs ~/ holdStrikeEveryMs;
    while (_holdStrikes < strikes && battle.status == BattleStatus.fighting) {
      _holdStrikes++;
      // Giữ tư thế chỉ là đòn khi đúng đợt sóng ⏸.
      if (floodWaves[index].action != WaveAction.hold) continue;
      _drain(drainMatched);
      var damage = holdStrikeDamage.toDouble();
      if (battle.mode == PushupMode.knee) {
        damage *= battle.rules.kneeMultiplier;
      }
      out.addAll(
        battle.strike(
          nowMs,
          damage,
          (dealt) => Hit(
            nowMs,
            damage: dealt,
            critical: false,
            combo: battle.combo,
            matched: true,
            held: true,
          ),
        ),
      );
    }
    if (battle.status != BattleStatus.fighting) return out;

    final last = _waterMs ?? nowMs;
    _water = math.min(100, _water + risePerSec * (nowMs - last) / 1000);
    _waterMs = nowMs;
    if (_water >= 100) out.addAll(battle.lose(nowMs, DefeatReason.flooded));
    return out;
  }

  @override
  void describe(BattleHost battle, BattleView view, int nowMs, int restEndMs) {
    final (index, left) = _waveAt(battle.startMs, nowMs);
    view
      ..water = _water
      ..wave = floodWaves[index]
      ..waveRemainingMs = left;
  }

  void _drain(double amount) => _water = math.max(0, _water - amount);

  static bool _matches(WaveAction action, CountedRep rep) => switch (action) {
    WaveAction.fast => rep.isFast,
    WaveAction.slow => rep.isSlow,
    WaveAction.deep => rep.isDeep,
    // Đợt ⏸ thưởng cho việc giữ tư thế (xem [tick]), rep vẫn đánh thường.
    WaveAction.hold => false,
  };
}
