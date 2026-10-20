import 'dart:math' as math;

import '../rep/pushup_counter.dart';
import 'battle_mechanic.dart';
import 'mechanics/mechanics.dart';

export 'battle_mechanic.dart';
export 'mechanics/mechanics.dart';

/// Một kẻ thù trong trận. Số liệu tạm, sẽ cân bằng lại khi có dữ liệu người
/// chơi thật (rules/cottruyen.md mục 8).
class EnemySpec {
  const EnemySpec({
    required this.id,
    required this.name,
    required this.maxHp,
    this.timeLimitMs,
    this.heads = 1,
    this.mechanics = const [],
  });

  /// Khoá cố định để tra hình, âm thanh… (không đổi khi đổi tên hiển thị).
  final String id;
  final String name;
  final int maxHp;

  /// Trận có giới hạn thời gian (null = không giới hạn).
  final int? timeLimitMs;

  /// Số đầu; máu chia đều cho mỗi đầu, chém lần lượt từng đầu, sát thương
  /// không tràn sang đầu sau.
  final int heads;

  /// Cơ chế riêng của kẻ thù (lib/game/mechanics/). Lưu hàm tạo vì cơ chế
  /// có trạng thái: mỗi trận tạo bản mới, ví dụ `[FreezingCold.new]`.
  final List<BattleMechanic Function()> mechanics;

  int get headMaxHp => (maxHp / heads).ceil();
}

/// Sát thương và hệ số chung cho mọi trận; số của từng cơ chế nằm trong lớp
/// cơ chế đó. Chưa cân bằng: số dễ đọc để thử cảm giác chiến đấu.
class DamageRules {
  const DamageRules({
    this.baseDamage = 10,
    this.deepMultiplier = 2.0,
    this.comboStep = 0.1,
    this.maxComboMultiplier = 2.0,
    this.comboWindowMs = 2500,
    this.formWarningMultiplier = 0.5,
    this.kneeMultiplier = 0.7,
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

/// Kẻ thù bị hạ lần đầu nhưng đứng dậy ([ReviveOnce]).
final class Revived extends BattleEvent {
  const Revived(super.timestampMs, {required this.hp});

  final int hp;
}

/// Lợn rừng chuẩn bị húc: còn [inMs] nữa thì húc ([ChargingBoar]).
final class ChargeWarning extends BattleEvent {
  const ChargeWarning(super.timestampMs, {required this.inMs});

  final int inMs;
}

/// Cú húc tới: né được (đang giữ tay thẳng) hay bị húc trúng.
final class ChargeLanded extends BattleEvent {
  const ChargeLanded(
    super.timestampMs, {
    required this.dodged,
    this.healed = 0,
  });

  final bool dodged;
  final int healed;
}

/// Sư tử pha 2 chuẩn bị vồ: còn [inMs] nữa thì vồ ([LionPounce]).
final class PounceWarning extends BattleEvent {
  const PounceWarning(super.timestampMs, {required this.inMs});

  final int inMs;
}

/// Cú vồ tới: vật được (đang giữ tay thẳng, kèm một đòn [Hit]) hay bị vồ
/// trúng (sư tử hồi [healed] máu).
final class PounceLanded extends BattleEvent {
  const PounceLanded(
    super.timestampMs, {
    required this.wrestled,
    this.healed = 0,
  });

  final bool wrestled;
  final int healed;
}

/// Harpy cướp vàng vì nghỉ quá lâu ([GoldThief]).
final class GoldStolen extends BattleEvent {
  const GoldStolen(super.timestampMs, {required this.total});

  final int total;
}

enum DefeatReason { timeUp, flooded }

final class Defeat extends BattleEvent {
  const Defeat(super.timestampMs, [this.reason = DefeatReason.timeUp]);

  final DefeatReason reason;
}

enum BattleStatus { ready, fighting, won, lost }

/// Trạng thái trận tại một thời điểm, để màn hình và sân khấu vẽ. Phần chung
/// do [Battle] điền; các trường cơ chế (giá trị mặc định = không có cơ chế
/// đó) do [BattleMechanic.describe] điền lúc dựng.
class BattleView {
  BattleView({
    required this.status,
    required this.hp,
    required this.maxHp,
    required this.heads,
    required this.headsLeft,
    required this.headHp,
    required this.headMaxHp,
    required this.combo,
    required this.bestCombo,
    required this.reps,
    required this.remainingMs,
    required this.defeatReason,
  });

  final BattleStatus status;
  final int hp;
  final int maxHp;
  final int heads;

  /// Số đầu còn lại (tính cả đầu đang chém) và máu đầu đang chém.
  final int headsLeft;
  final int headHp;
  final int headMaxHp;
  final int combo;
  final int bestCombo;
  final int reps;

  /// Thời gian còn lại (ms), null nếu không giới hạn.
  final int? remainingMs;
  final DefeatReason? defeatReason;

  double get hpFraction => hp / maxHp;
  bool get finished =>
      status == BattleStatus.won || status == BattleStatus.lost;

  /// Mực nước 0–100; null = trận không có nước dâng ([RisingFlood]).
  double? water;

  /// Đợt sóng hiện tại và thời gian còn lại của nó ([RisingFlood]).
  Wave? wave;
  int waveRemainingMs = 0;

  /// Mức lạnh 0–1, chạm 1 là đòn sau bị đóng băng ([FreezingCold]).
  double cold = 0;

  /// Kẻ thù lấy đà 0–1, 1 = lao tới ngay ([ChargingBoar], [LionPounce]).
  double charge = 0;

  /// Số túi vàng đã bị cướp ([GoldThief]).
  int goldStolen = 0;

  /// Số lần kẻ thù đã đứng dậy ([ReviveOnce]).
  int revives = 0;

  /// Số lần người chơi vật được sư tử ([LionPounce]).
  int wrestles = 0;
}

/// Logic một trận: nhận [RepEvent] từ bộ đếm, trừ máu kẻ thù. Không phụ
/// thuộc Flutter để test được và dùng lại cho mọi màn chơi. Phần riêng của
/// từng kẻ thù nằm trong [mechanics].
class Battle {
  Battle({
    required this.enemy,
    this.rules = const DamageRules(),
    this.mode = PushupMode.standard,
  }) : _hp = enemy.maxHp,
       mechanics = [for (final create in enemy.mechanics) create()];

  final EnemySpec enemy;
  final DamageRules rules;
  final PushupMode mode;
  final List<BattleMechanic> mechanics;
  late final BattleHost _host = _Host(this);

  int _hp;
  BattleStatus _status = BattleStatus.ready;
  int? _startMs;
  int? _lastHitMs;
  int _combo = 0;
  int _reps = 0;
  int _bestCombo = 0;
  DefeatReason? _defeatReason;

  int get hp => _hp;
  BattleStatus get status => _status;
  int get combo => _combo;
  int get bestCombo => _bestCombo;
  int get reps => _reps;
  double get hpFraction => _hp / enemy.maxHp;
  DefeatReason? get defeatReason => _defeatReason;

  /// Cơ chế kiểu [T] của trận này, null nếu kẻ thù không có.
  T? mechanic<T extends BattleMechanic>() =>
      mechanics.whereType<T>().firstOrNull;

  /// Số đầu còn lại (tính cả đầu đang chém).
  int get headsLeft => (_hp / enemy.headMaxHp).ceil();

  /// Máu của đầu đang chém.
  int get headHp =>
      headsLeft == 0 ? 0 : _hp - (headsLeft - 1) * enemy.headMaxHp;

  /// Thời gian còn lại (ms), null nếu không giới hạn hoặc chưa bắt đầu.
  int? remainingMs(int nowMs) {
    final limit = enemy.timeLimitMs;
    final start = _startMs;
    if (limit == null || start == null) return limit;
    return math.max(0, limit - (nowMs - start));
  }

  /// Trạng thái để vẽ tại [nowMs]. [restEndMs]: lúc người chơi bắt đầu hạ
  /// người trong rep đang làm — thời gian nghỉ dừng ở mốc này (rep chậm
  /// không bị coi là nghỉ); null = vẫn đang nghỉ.
  BattleView view(int nowMs, {int? restEndMs}) {
    final view = BattleView(
      status: _status,
      hp: _hp,
      maxHp: enemy.maxHp,
      heads: enemy.heads,
      headsLeft: headsLeft,
      headHp: headHp,
      headMaxHp: enemy.headMaxHp,
      combo: _combo,
      bestCombo: _bestCombo,
      reps: _reps,
      remainingMs: remainingMs(nowMs),
      defeatReason: _defeatReason,
    );
    for (final m in mechanics) {
      m.describe(_host, view, nowMs, restEndMs ?? nowMs);
    }
    return view;
  }

  void _start(int t) {
    _status = BattleStatus.fighting;
    _startMs = t;
    for (final m in mechanics) {
      m.onStart(_host, t);
    }
  }

  /// Trừ máu; thắng nếu hết máu (trừ khi một cơ chế giữ kẻ thù lại).
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
    if (_hp > 0) return out;
    for (final m in mechanics) {
      if (m.onKnockedOut(_host, t) case final kept?) return out..addAll(kept);
    }
    _status = BattleStatus.won;
    out.add(Victory(t, reps: _reps, durationMs: t - (_startMs ?? t)));
    return out;
  }

  List<BattleEvent> _comboBroken(int t) => [
    for (final m in mechanics) ...m.onComboBroken(_host, t),
  ];

  List<BattleEvent> _lose(int t, DefeatReason reason) {
    _status = BattleStatus.lost;
    _defeatReason = reason;
    return [Defeat(t, reason)];
  }

  /// Gọi mỗi khung hình: hết giờ và phần theo thời gian của các cơ chế.
  /// [plankHoldMs] lấy từ [CounterSnapshot.plankHoldMs].
  List<BattleEvent> tick(int nowMs, {int plankHoldMs = 0}) {
    if (_status == BattleStatus.ready &&
        plankHoldMs > 0 &&
        mechanics.any((m) => m.startsOnHold)) {
      _start(nowMs);
    }
    if (_status != BattleStatus.fighting) return const [];
    if (remainingMs(nowMs) == 0) return _lose(nowMs, DefeatReason.timeUp);
    final out = <BattleEvent>[];
    for (final m in mechanics) {
      out.addAll(m.tick(_host, nowMs, plankHoldMs));
      if (_status != BattleStatus.fighting) break;
    }
    return out;
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

  List<BattleEvent> _blocked(int t, String reason) {
    _combo = 0;
    return [..._comboBroken(t), Blocked(t, reason)];
  }

  List<BattleEvent> _applyOne(RepEvent event) {
    final t = event.timestampMs;
    switch (event) {
      case PartialRep():
        final message = mechanics
            .map((m) => m.partialRepMessage())
            .nonNulls
            .firstOrNull;
        return _blocked(t, message ?? 'Chưa đủ sâu');
      case RejectedRep(:final reason):
        return _blocked(t, switch (reason) {
          RejectReason.kneelingInStandardMode => 'Duỗi thẳng chân',
          RejectReason.bodyNotStraight => 'Giữ thân thẳng',
        });
      case CountedRep():
        for (final m in mechanics) {
          if (m.blockCountedRep(event) case final reason?) {
            return _blocked(t, reason);
          }
        }
        final last = _lastHitMs;
        // Thời gian nghỉ thật: từ lúc xong rep trước tới lúc bắt đầu hạ người,
        // để rep chậm (xuống 3 giây) không bị tính là nghỉ.
        final restMs = last == null ? null : math.max(0, event.startMs - last);
        _combo = restMs != null && restMs <= rules.comboWindowMs
            ? _combo + 1
            : 1;
        final out = <BattleEvent>[if (_combo == 1) ..._comboBroken(t)];
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
        final strike = Strike(event, restMs: restMs, damage: damage);
        for (final m in mechanics) {
          m.onStrike(_host, strike);
        }

        out.addAll(
          _damage(
            t,
            math.max(1, strike.damage.round()),
            (dealt) => Hit(
              t,
              damage: dealt,
              critical: event.isDeep,
              combo: _combo,
              frozen: strike.frozen,
              matched: strike.matched,
            ),
          ),
        );
        return out;
    }
  }
}

/// Cửa cho các cơ chế đọc/đổi trận mà không lộ hàm đổi ra màn hình.
class _Host implements BattleHost {
  _Host(this._b);

  final Battle _b;

  @override
  EnemySpec get enemy => _b.enemy;
  @override
  PushupMode get mode => _b.mode;
  @override
  DamageRules get rules => _b.rules;
  @override
  BattleStatus get status => _b._status;
  @override
  int get hp => _b._hp;
  @override
  int get headHp => _b.headHp;
  @override
  int get combo => _b._combo;
  @override
  int? get startMs => _b._startMs;
  @override
  int? get lastHitMs => _b._lastHitMs;

  @override
  int heal(int amount) {
    final healed = math.min(math.max(0, amount), _b.enemy.maxHp - _b._hp);
    _b._hp += healed;
    return healed;
  }

  @override
  void setHp(int hp) => _b._hp = hp.clamp(0, _b.enemy.maxHp);

  @override
  void breakCombo() => _b._combo = 0;

  @override
  List<BattleEvent> strike(int t, double damage, Hit Function(int dealt) hit) =>
      _b._damage(t, math.max(1, damage.round()), hit);

  @override
  List<BattleEvent> lose(int t, DefeatReason reason) => _b._lose(t, reason);
}
