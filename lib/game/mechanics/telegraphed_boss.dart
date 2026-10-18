import 'dart:math' as math;

import '../../rep/pushup_counter.dart';
import '../battle.dart';

/// Một đòn có báo trước: khoá đòn trong biên đạo (`tool/blender/choreo/<id>.json`)
/// và cách né.
class BossAttack {
  const BossAttack(this.move, this.dodge);

  final String move;
  final DodgeBy dodge;
}

/// Boss đánh có báo trước (chương Nhật — rules/thietke/boss-nhat-shuten-sutoku.md):
/// báo [warnMs] rồi chạm. Né đòn từ trên bằng giữ tay thẳng ≥ [holdDodgeMs]
/// lúc chạm; né đòn ngang bằng một rep sâu có đáy trong cửa sổ
/// [chạm − duckBeforeMs, chạm + duckAfterMs]. Né được → rep tính kế tiếp phản
/// đòn ×[counterMultiplier]; trúng → mất combo; camera mất người lúc chạm →
/// huỷ đòn (không phạt vì lỗi máy). Dạy kỹ năng kiểm soát thời điểm.
///
/// Lớp con thêm hành động riêng ([startSpecial], [tickSpecial],
/// [onSpecialStrike]) — một hành động một lúc, không báo hai đòn cùng lúc.
abstract class TelegraphedBoss extends BattleMechanic {
  TelegraphedBoss({
    required this.attacks,
    this.warnMs = 2500,
    this.holdDodgeMs = 800,
    this.duckBeforeMs = 900,
    this.duckAfterMs = 300,
    this.firstActionMs = 6000,
    this.gapMinMs = 6000,
    this.gapMaxMs = 8000,
    this.counterMultiplier = 2,
    this.maxMultiplier = 4,
    math.Random? random,
  }) : random = random ?? math.Random();

  final List<BossAttack> attacks;
  final int warnMs;
  final int holdDodgeMs;
  final int duckBeforeMs;
  final int duckAfterMs;
  final int firstActionMs;
  final int gapMinMs;
  final int gapMaxMs;
  final double counterMultiplier;

  /// Trần nhân sát thương của cơ chế cho một rep (chống đột biến khi phản
  /// đòn + choáng + hoá giải chồng nhau).
  final double maxMultiplier;
  final math.Random random;

  /// Rep sâu cần thêm chừng này sau cửa sổ để kịp đẩy lên (rep chỉ được đếm
  /// khi lên tới đỉnh) trước khi chấm né.
  static const _repFinishMs = 1200;

  int? _nextAt;
  _Pending? _current;
  _Pending? _last;
  final _deepBottoms = <int>[];
  bool _counter = false;
  int _attackIndex = 0;

  /// Số đòn đã ra kể từ hành động riêng gần nhất.
  int attacksSinceSpecial = 0;

  /// Hành động riêng đang diễn (uống rượu…): không lên lịch đòn.
  bool get specialBusy => false;

  /// Thử bắt đầu hành động riêng thay cho đòn ở lượt này; true = đã bắt đầu.
  bool startSpecial(BattleHost battle, int t, List<BattleEvent> out) => false;

  /// Phần theo thời gian của hành động riêng (gọi mỗi khung).
  void tickSpecial(BattleHost battle, int nowMs, List<BattleEvent> out) {}

  /// Chỉnh đòn từ rep theo hành động riêng (choáng, ấn nguyền…).
  void onSpecialStrike(BattleHost battle, Strike strike) {}

  /// Lên lịch hành động kế tiếp sau một khoảng nghỉ.
  void scheduleNext(int t) =>
      _nextAt = t + gapMinMs + random.nextInt(gapMaxMs - gapMinMs + 1);

  @override
  void onStart(BattleHost battle, int t) => _nextAt = t + firstActionMs;

  @override
  List<BattleEvent> tick(BattleHost battle, int nowMs, int plankHoldMs) {
    if (battle.status != BattleStatus.fighting) return const [];
    final out = <BattleEvent>[];
    tickSpecial(battle, nowMs, out);
    final cur = _current;
    if (cur != null) {
      if (cur.seenAtImpact == null && nowMs >= cur.impactAt) {
        final seen = battle.lastSeenMs;
        cur.seenAtImpact = seen != null && seen >= cur.impactAt - 1000;
        cur.holdAtImpact = plankHoldMs;
      }
      final resolveAt = cur.attack.dodge == DodgeBy.hold
          ? cur.impactAt
          : cur.impactAt + duckAfterMs + _repFinishMs;
      if (nowMs >= resolveAt && cur.seenAtImpact != null) {
        final cancelled = !cur.seenAtImpact!;
        final dodged = !cancelled &&
            switch (cur.attack.dodge) {
              DodgeBy.hold => cur.holdAtImpact >= holdDodgeMs,
              DodgeBy.duck => _deepBottoms.any(
                (b) => b >= cur.impactAt - duckBeforeMs && b <= cur.impactAt + duckAfterMs,
              ),
            };
        if (dodged) _counter = true;
        if (!cancelled && !dodged) battle.breakCombo();
        out.add(BossStruck(nowMs, move: cur.attack.move, dodged: dodged, cancelled: cancelled));
        _last = cur;
        _current = null;
        _deepBottoms.clear();
        scheduleNext(nowMs);
      }
    } else if (!specialBusy && nowMs >= (_nextAt ?? nowMs)) {
      if (startSpecial(battle, nowMs, out)) {
        attacksSinceSpecial = 0;
        _nextAt = null;
      } else {
        final attack = attacks[_attackIndex++ % attacks.length];
        attacksSinceSpecial++;
        _current = _Pending(attack, nowMs + warnMs);
        _deepBottoms.clear();
        out.add(BossTell(nowMs, move: attack.move, dodge: attack.dodge, inMs: warnMs));
      }
    }
    return out;
  }

  @override
  void onStrike(BattleHost battle, Strike strike) {
    final entry = strike.damage;
    final rep = strike.rep;
    if (rep.isDeep && _current != null) {
      _deepBottoms.add(rep.startMs + rep.descentMs);
    }
    if (_counter) {
      _counter = false;
      strike
        ..damage *= counterMultiplier
        ..countered = true;
    }
    onSpecialStrike(battle, strike);
    strike.damage = math.min(strike.damage, entry * maxMultiplier);
  }

  @override
  void describe(BattleHost battle, BattleView view, int nowMs, int restEndMs) {
    view.counterReady = _counter;
    // Giữ đòn vừa chạm thêm một lúc để sân khấu diễn nốt pha thu về.
    final shown = _current ?? _last;
    if (shown == null || nowMs - shown.impactAt > 1500) return;
    view
      ..bossMove = shown.attack.move
      ..bossDodge = shown.attack.dodge
      ..bossWarnMs = warnMs
      ..bossTellMs = shown.impactAt - nowMs;
  }
}

class _Pending {
  _Pending(this.attack, this.impactAt);

  final BossAttack attack;
  final int impactAt;
  bool? seenAtImpact;
  int holdAtImpact = 0;
}

/// Shuten-dōji (mini-boss kỳ công Izumo): Nện đỉnh (⏸) / Quét chân ngựa (rep
/// sâu) luân phiên; cứ sau 2 đòn, nếu máu < [drinkBelow], **uống rượu**
/// [drinkMs] hồi [drinkHealPerSec]/giây — đủ [breakReps] rep tính trong lúc
/// uống thì ngắt: vò vỡ, choáng [stunMs], mọi đòn ×[stunMultiplier]
/// (truyền thuyết: Raikō chuốc rượu rồi chém). Dạy bùng nổ đúng lúc.
class ShutenMechanic extends TelegraphedBoss {
  ShutenMechanic({
    super.random,
    this.drinkMs = 5000,
    this.drinkHealPerSec = 0.02,
    this.drinkBelow = 0.85,
    this.breakReps = 3,
    this.breakRepsKnee = 2,
    this.stunMs = 3000,
    this.stunMultiplier = 1.5,
  }) : super(
         attacks: const [
           BossAttack('attack', DodgeBy.hold),
           BossAttack('attack2', DodgeBy.duck),
         ],
       );

  final int drinkMs;
  final double drinkHealPerSec;
  final double drinkBelow;
  final int breakReps;
  final int breakRepsKnee;
  final int stunMs;
  final double stunMultiplier;

  int? _drinkStart;
  int _drinkReps = 0;
  int _healed = 0;
  int _stunUntil = 0;
  int? _interruptedAt;

  int _needed(BattleHost b) => b.mode == PushupMode.knee ? breakRepsKnee : breakReps;

  @override
  bool get specialBusy => _drinkStart != null;

  @override
  bool startSpecial(BattleHost battle, int t, List<BattleEvent> out) {
    if (attacksSinceSpecial < 2 || battle.hp >= battle.enemy.maxHp * drinkBelow) return false;
    _drinkStart = t;
    _drinkReps = 0;
    _healed = 0;
    out.add(SakeDrinking(t, reps: _needed(battle), inMs: drinkMs));
    return true;
  }

  @override
  void tickSpecial(BattleHost battle, int nowMs, List<BattleEvent> out) {
    if (_interruptedAt case final t?) {
      _interruptedAt = null;
      out.add(SakeInterrupted(t, stunMs: stunMs));
    }
    final start = _drinkStart;
    if (start == null) return;
    final elapsed = math.min(nowMs - start, drinkMs);
    final due = (battle.enemy.maxHp * drinkHealPerSec * elapsed / 1000).floor();
    if (due > _healed) _healed += battle.heal(due - _healed);
    if (nowMs - start >= drinkMs) {
      _drinkStart = null;
      out.add(SakeFinished(nowMs, healed: _healed));
      scheduleNext(nowMs);
    }
  }

  @override
  void onSpecialStrike(BattleHost battle, Strike strike) {
    final t = strike.rep.timestampMs;
    if (_drinkStart != null && ++_drinkReps >= _needed(battle)) {
      _drinkStart = null;
      _stunUntil = t + stunMs;
      _interruptedAt = t;
      scheduleNext(t);
    }
    if (t < _stunUntil) strike.damage *= stunMultiplier;
  }

  @override
  void describe(BattleHost battle, BattleView view, int nowMs, int restEndMs) {
    super.describe(battle, view, nowMs, restEndMs);
    if (_drinkStart case final s?) {
      view
        ..drinking = ((nowMs - s) / drinkMs).clamp(0.0, 1.0)
        ..drinkReps = _drinkReps
        ..drinkRepsNeeded = _needed(battle);
    }
    view.stunMs = math.max(0, _stunUntil - nowMs);
  }
}

/// Thiên hoàng Sutoku hoá đại tengu (boss kỳ công Heian): Phong kesa (rep
/// sâu) / Thiên cẩu phi (⏸) luân phiên; máu < [curseBelow] thì viết **ấn
/// nguyền**: còn ấn thì mọi đòn ×[curseMultiplier]; một rep chậm ("chép kinh
/// từng nét") đốt ấn và đánh ×[purgeMultiplier]; ấn tự tan sau [curseLifeMs],
/// ấn sau cách ≥ [curseGapMs]. Dạy rep chậm có kiểm soát.
class SutokuMechanic extends TelegraphedBoss {
  SutokuMechanic({
    super.random,
    this.curseBelow = 0.6,
    this.curseMultiplier = 0.75,
    this.purgeMultiplier = 2,
    this.curseLifeMs = 15000,
    this.curseGapMs = 12000,
    this.firstCurseDelayMs = 2000,
  }) : super(
         attacks: const [
           BossAttack('attack', DodgeBy.duck),
           BossAttack('attack2', DodgeBy.hold),
         ],
       );

  final double curseBelow;
  final double curseMultiplier;
  final double purgeMultiplier;
  final int curseLifeMs;
  final int curseGapMs;
  final int firstCurseDelayMs;

  int? _nextCurse;
  int? _curseUntil;
  int? _purgedAt;

  @override
  void tickSpecial(BattleHost battle, int nowMs, List<BattleEvent> out) {
    if (_purgedAt case final t?) {
      _purgedAt = null;
      out.add(CurseLifted(t, purged: true));
    }
    final until = _curseUntil;
    if (until != null) {
      if (nowMs >= until) {
        _curseUntil = null;
        _nextCurse = nowMs + curseGapMs;
        out.add(CurseLifted(nowMs, purged: false));
      }
      return;
    }
    if (battle.hp >= battle.enemy.maxHp * curseBelow) return;
    final next = _nextCurse ??= nowMs + firstCurseDelayMs;
    if (nowMs >= next) {
      _curseUntil = nowMs + curseLifeMs;
      out.add(CurseCast(nowMs));
    }
  }

  @override
  void onSpecialStrike(BattleHost battle, Strike strike) {
    if (_curseUntil == null) return;
    if (strike.rep.isSlow) {
      final t = strike.rep.timestampMs;
      _curseUntil = null;
      _nextCurse = t + curseGapMs;
      _purgedAt = t;
      strike.damage *= purgeMultiplier;
    } else {
      strike.damage *= curseMultiplier;
    }
  }

  @override
  void describe(BattleHost battle, BattleView view, int nowMs, int restEndMs) {
    super.describe(battle, view, nowMs, restEndMs);
    if (_curseUntil case final u?) {
      view.curse = ((u - nowMs) / curseLifeMs).clamp(0.0, 1.0);
    }
  }
}
