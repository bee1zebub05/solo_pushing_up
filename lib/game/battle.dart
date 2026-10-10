import 'dart:math' as math;

import '../rep/pushup_counter.dart';

/// Một kẻ thù trong trận. Số liệu tạm, sẽ cân bằng lại khi có dữ liệu người
/// chơi thật (rules/cottruyen.md mục 8).
class EnemySpec {
  const EnemySpec({
    required this.name,
    required this.maxHp,
    this.timeLimitMs,
    this.armor = BattleArmor.none,
    this.heads = 1,
  });

  final String name;
  final int maxHp;

  /// Trận có giới hạn thời gian (null = không giới hạn).
  final int? timeLimitMs;
  final BattleArmor armor;

  /// Số đầu; máu chia đều cho mỗi đầu, chém lần lượt từng đầu.
  final int heads;

  int get headMaxHp => (maxHp / heads).ceil();
}

/// Cơ chế phòng thủ đặc biệt của kẻ thù.
enum BattleArmor {
  none,

  /// Sư tử Nemea: da không xuyên thủng, rep nông/sai tư thế bị chặn hoàn toàn
  /// (dạy người chơi về form ngay từ tutorial — Kỳ công 1).
  impenetrableHide,

  /// Rồng Fafnir — Giá lạnh: nghỉ quá lâu giữa hai rep thì bị đóng băng, đòn
  /// tiếp theo yếu đi (dạy giữ nhịp tập đều — Kỳ công 2).
  freezingCold,

  /// Yamata no Orochi — 8 cái đầu: sát thương không tràn sang đầu sau, đứt
  /// combo thì đầu đang chém hồi đầy máu (dạy giữ chuỗi rep — Kỳ công 5).
  regrowingHeads,

  /// Thuỷ Tinh — Núi dâng, nước dâng: nước dâng liên tục, mỗi đòn hạ nước
  /// xuống; nước ngập tới đỉnh thì thua. Trận chia thành các đợt sóng, mỗi đợt
  /// đòi một kiểu hành động, đánh đúng kiểu thì mạnh hơn (Kỳ công 12).
  risingFlood,
}

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

/// Sát thương và hệ số. Chưa cân bằng: số dễ đọc để thử cảm giác chiến đấu.
class DamageRules {
  const DamageRules({
    this.baseDamage = 10,
    this.deepMultiplier = 2.0,
    this.comboStep = 0.1,
    this.maxComboMultiplier = 2.0,
    this.comboWindowMs = 2500,
    this.formWarningMultiplier = 0.5,
    this.kneeMultiplier = 0.7,
    this.freezeAfterMs = 3000,
    this.frozenMultiplier = 0.5,
    this.floodRisePerSec = 3.5,
    this.floodDrainPerHit = 8,
    this.floodDrainMatched = 16,
    this.matchedMultiplier = 1.5,
    this.holdStrikeEveryMs = 2000,
    this.holdStrikeDamage = 12,
  });

  final int baseDamage;

  /// Rep sâu = đòn chí mạng.
  final double deepMultiplier;

  /// Mỗi rep liên tiếp cộng thêm bấy nhiêu vào hệ số combo…
  final double comboStep;

  /// …tối đa tới mức này.
  final double maxComboMultiplier;

  /// Nghỉ giữa hai rep quá lâu thì combo về 0.
  final int comboWindowMs;

  /// Rep được tính nhưng thân chưa thẳng: sát thương giảm.
  final double formWarningMultiplier;

  /// Chế độ Tân binh (chống gối): XP/sát thương ×0,7 (rules/cottruyen.md 1b).
  final double kneeMultiplier;

  /// [BattleArmor.freezingCold]: nghỉ quá bấy lâu thì đòn sau bị đóng băng.
  final int freezeAfterMs;
  final double frozenMultiplier;

  /// [BattleArmor.risingFlood]: mực nước (0–100) dâng bấy nhiêu mỗi giây…
  final double floodRisePerSec;

  /// …mỗi đòn hạ xuống bấy nhiêu, đòn đúng đợt sóng hạ nhiều hơn.
  final double floodDrainPerHit;
  final double floodDrainMatched;

  /// Đòn đúng kiểu đợt sóng đang đòi.
  final double matchedMultiplier;

  /// Đợt sóng ⏸: giữ tư thế cao mỗi bấy lâu là một đòn.
  final int holdStrikeEveryMs;
  final int holdStrikeDamage;
}

/// Điều xảy ra trong trận, để màn hình hiện hiệu ứng / âm thanh.
sealed class BattleEvent {
  const BattleEvent(this.timestampMs);

  final int timestampMs;
}

final class Hit extends BattleEvent {
  const Hit(
    super.timestampMs, {
    required this.damage,
    required this.critical,
    required this.combo,
    this.frozen = false,
    this.matched = false,
    this.held = false,
  });

  final int damage;
  final bool critical;

  /// Đòn yếu đi vì bị đóng băng (nghỉ quá lâu trước Rồng Fafnir).
  final bool frozen;

  /// Đúng kiểu hành động đợt sóng đang đòi (Thuỷ Tinh).
  final bool matched;

  /// Đòn từ việc giữ tư thế cao, không phải từ một rep.
  final bool held;

  /// Số rep liên tiếp tính tới đòn này.
  final int combo;
}

/// Rep không gây sát thương (nông / sai tư thế / bị giáp chặn).
final class Blocked extends BattleEvent {
  const Blocked(super.timestampMs, this.reason);

  final String reason;
}

/// Chém xong một đầu (kẻ thù nhiều đầu).
final class HeadSevered extends BattleEvent {
  const HeadSevered(super.timestampMs, {required this.headsLeft});

  final int headsLeft;
}

/// Đứt combo nên đầu đang chém mọc lại.
final class HeadRegrown extends BattleEvent {
  const HeadRegrown(super.timestampMs, {required this.healed});

  final int healed;
}

final class Victory extends BattleEvent {
  const Victory(
    super.timestampMs, {
    required this.reps,
    required this.durationMs,
  });

  final int reps;
  final int durationMs;
}

/// Sang đợt sóng mới (Thuỷ Tinh).
final class WaveStarted extends BattleEvent {
  const WaveStarted(super.timestampMs, this.wave);

  final Wave wave;
}

enum DefeatReason { timeUp, flooded }

final class Defeat extends BattleEvent {
  const Defeat(super.timestampMs, [this.reason = DefeatReason.timeUp]);

  final DefeatReason reason;
}

enum BattleStatus { ready, fighting, won, lost }

/// Logic một trận: nhận [RepEvent] từ bộ đếm, trừ máu kẻ thù. Không phụ
/// thuộc Flutter để test được và dùng lại cho mọi màn chơi.
class Battle {
  Battle({
    required this.enemy,
    this.rules = const DamageRules(),
    this.mode = PushupMode.standard,
  }) : _hp = enemy.maxHp;

  final EnemySpec enemy;
  final DamageRules rules;
  final PushupMode mode;

  int _hp;
  BattleStatus _status = BattleStatus.ready;
  int? _startMs;
  int? _lastHitMs;
  int _combo = 0;
  int _reps = 0;
  int _bestCombo = 0;
  double _water = 0;
  int? _waterMs;
  int _waveIndex = -1;
  int _holdStrikes = 0;
  DefeatReason? _defeatReason;

  int get hp => _hp;
  BattleStatus get status => _status;
  int get combo => _combo;
  int get bestCombo => _bestCombo;
  int get reps => _reps;
  double get hpFraction => _hp / enemy.maxHp;
  DefeatReason? get defeatReason => _defeatReason;

  bool get _flood => enemy.armor == BattleArmor.risingFlood;

  /// Mực nước 0–100 (chỉ có ở trận [BattleArmor.risingFlood]).
  double get water => _water;

  static final _cycleMs = floodWaves.fold(0, (sum, w) => sum + w.durationMs);

  /// Vị trí trong chu kỳ sóng tại [nowMs] (đợt đầu nếu chưa bắt đầu).
  (int, int) _waveAt(int nowMs) {
    final start = _startMs;
    var into = start == null ? 0 : (nowMs - start) % _cycleMs;
    for (var i = 0; i < floodWaves.length; i++) {
      final d = floodWaves[i].durationMs;
      if (into < d) return (i, d - into);
      into -= d;
    }
    return (0, floodWaves.first.durationMs);
  }

  /// Đợt sóng hiện tại, null nếu không phải trận Thuỷ Tinh.
  Wave? currentWave(int nowMs) => _flood ? floodWaves[_waveAt(nowMs).$1] : null;

  int waveRemainingMs(int nowMs) => _waveAt(nowMs).$2;

  void _start(int t) {
    _status = BattleStatus.fighting;
    _startMs = t;
    _waterMs = t;
  }

  /// Trừ máu; thắng nếu hết máu.
  List<BattleEvent> _damage(int t, int dealt, Hit Function(int) hit) {
    final out = <BattleEvent>[];
    var amount = dealt;
    // Nhiều đầu: không tràn sát thương sang đầu sau.
    if (enemy.heads > 1) amount = math.min(amount, headHp);
    final headsBefore = headsLeft;
    _hp = math.max(0, _hp - amount);
    out.add(hit(amount));
    if (enemy.heads > 1 && _hp > 0 && headsLeft < headsBefore) {
      out.add(HeadSevered(t, headsLeft: headsLeft));
    }
    if (_hp == 0) {
      _status = BattleStatus.won;
      out.add(Victory(t, reps: _reps, durationMs: t - (_startMs ?? t)));
    }
    return out;
  }

  /// Số đầu còn lại (tính cả đầu đang chém).
  int get headsLeft => (_hp / enemy.headMaxHp).ceil();

  /// Máu của đầu đang chém.
  int get headHp =>
      headsLeft == 0 ? 0 : _hp - (headsLeft - 1) * enemy.headMaxHp;

  bool get _regrows => enemy.armor == BattleArmor.regrowingHeads;

  /// Đứt combo: đầu đang chém (nếu đã bị thương) hồi đầy máu.
  List<BattleEvent> _regrow(int t) {
    if (!_regrows || _hp == 0) return const [];
    final healed = enemy.headMaxHp - headHp;
    if (healed <= 0) return const [];
    _hp += healed;
    return [HeadRegrown(t, healed: healed)];
  }

  /// Thời gian còn lại (ms), null nếu không giới hạn hoặc chưa bắt đầu.
  int? remainingMs(int nowMs) {
    final limit = enemy.timeLimitMs;
    final start = _startMs;
    if (limit == null || start == null) return limit;
    return math.max(0, limit - (nowMs - start));
  }

  /// Gọi mỗi khung hình: hết giờ, nước dâng, đợt sóng, đòn giữ tư thế.
  /// [plankHoldMs] lấy từ [CounterSnapshot.plankHoldMs].
  List<BattleEvent> tick(int nowMs, {int plankHoldMs = 0}) {
    // Trận Thuỷ Tinh bắt đầu cả khi người chơi giữ tư thế trước.
    if (_status == BattleStatus.ready && _flood && plankHoldMs > 0) {
      _start(nowMs);
    }
    if (_status != BattleStatus.fighting) return const [];
    if (remainingMs(nowMs) == 0) return _lose(nowMs, DefeatReason.timeUp);
    if (!_flood) return const [];

    final out = <BattleEvent>[];
    final (index, _) = _waveAt(nowMs);
    if (index != _waveIndex) {
      _waveIndex = index;
      out.add(WaveStarted(nowMs, floodWaves[index]));
    }

    if (plankHoldMs == 0) _holdStrikes = 0;
    final strikes = plankHoldMs ~/ rules.holdStrikeEveryMs;
    while (_holdStrikes < strikes && _status == BattleStatus.fighting) {
      _holdStrikes++;
      // Giữ tư thế chỉ là đòn khi đúng đợt sóng ⏸.
      if (floodWaves[index].action != WaveAction.hold) continue;
      _drain(rules.floodDrainMatched);
      var damage = rules.holdStrikeDamage.toDouble();
      if (mode == PushupMode.knee) damage *= rules.kneeMultiplier;
      out.addAll(
        _damage(
          nowMs,
          math.max(1, damage.round()),
          (dealt) => Hit(
            nowMs,
            damage: dealt,
            critical: false,
            combo: _combo,
            matched: true,
            held: true,
          ),
        ),
      );
    }
    if (_status != BattleStatus.fighting) return out;

    final last = _waterMs ?? nowMs;
    _water = math.min(
      100,
      _water + rules.floodRisePerSec * (nowMs - last) / 1000,
    );
    _waterMs = nowMs;
    if (_water >= 100) out.addAll(_lose(nowMs, DefeatReason.flooded));
    return out;
  }

  void _drain(double amount) => _water = math.max(0, _water - amount);

  List<BattleEvent> _lose(int t, DefeatReason reason) {
    _status = BattleStatus.lost;
    _defeatReason = reason;
    return [Defeat(t, reason)];
  }

  /// Áp dụng các rep vừa kết thúc từ bộ đếm.
  List<BattleEvent> apply(List<RepEvent> repEvents) {
    final out = <BattleEvent>[];
    for (final event in repEvents) {
      if (_status == BattleStatus.won || _status == BattleStatus.lost) break;
      if (_status == BattleStatus.ready) _start(event.timestampMs);
      out.addAll(_applyOne(event));
    }
    return out;
  }

  List<BattleEvent> _applyOne(RepEvent event) {
    final t = event.timestampMs;
    switch (event) {
      case PartialRep():
        _combo = 0;
        return [
          ..._regrow(t),
          Blocked(
            t,
            enemy.armor == BattleArmor.impenetrableHide
                ? 'Bị chặn! Xuống sâu hơn'
                : 'Chưa đủ sâu',
          ),
        ];
      case RejectedRep(:final reason):
        _combo = 0;
        return [
          ..._regrow(t),
          Blocked(t, switch (reason) {
            RejectReason.kneelingInStandardMode => 'Duỗi thẳng chân',
            RejectReason.bodyNotStraight => 'Giữ thân thẳng',
          }),
        ];
      case CountedRep():
        if (enemy.armor == BattleArmor.impenetrableHide && event.formWarning) {
          _combo = 0;
          return [Blocked(t, 'Bị chặn! Giữ thân thẳng')];
        }
        final last = _lastHitMs;
        // Thời gian nghỉ thật: từ lúc xong rep trước tới lúc bắt đầu hạ người,
        // để rep chậm (xuống 3 giây) không bị tính là nghỉ.
        final restMs = last == null ? null : math.max(0, event.startMs - last);
        final frozen =
            enemy.armor == BattleArmor.freezingCold &&
            restMs != null &&
            restMs > rules.freezeAfterMs;
        _combo = restMs != null && restMs <= rules.comboWindowMs
            ? _combo + 1
            : 1;
        final out = <BattleEvent>[if (_combo == 1) ..._regrow(t)];
        _lastHitMs = t;
        _reps++;
        _bestCombo = math.max(_bestCombo, _combo);

        final comboMultiplier = math.min(
          1 + rules.comboStep * (_combo - 1),
          rules.maxComboMultiplier,
        );
        var damage = rules.baseDamage * comboMultiplier;
        if (event.isDeep) damage *= rules.deepMultiplier;
        if (event.formWarning) damage *= rules.formWarningMultiplier;
        if (mode == PushupMode.knee) damage *= rules.kneeMultiplier;
        if (frozen) damage *= rules.frozenMultiplier;
        final matched = _flood && _matches(currentWave(t)!.action, event);
        if (matched) damage *= rules.matchedMultiplier;
        if (_flood) {
          _drain(matched ? rules.floodDrainMatched : rules.floodDrainPerHit);
        }

        out.addAll(
          _damage(
            t,
            math.max(1, damage.round()),
            (dealt) => Hit(
              t,
              damage: dealt,
              critical: event.isDeep,
              combo: _combo,
              frozen: frozen,
              matched: matched,
            ),
          ),
        );
        return out;
    }
  }

  static bool _matches(WaveAction action, CountedRep rep) => switch (action) {
    WaveAction.fast => rep.isFast,
    WaveAction.slow => rep.isSlow,
    WaveAction.deep => rep.isDeep,
    // Đợt ⏸ thưởng cho việc giữ tư thế (xem [tick]), rep vẫn đánh thường.
    WaveAction.hold => false,
  };
}
