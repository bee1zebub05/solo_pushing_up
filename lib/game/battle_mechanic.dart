import '../rep/pushup_counter.dart';
import 'battle.dart';

/// Một cơ chế riêng của kẻ thù (giáp, giá lạnh, nước dâng…). [Battle] lo
/// phần chung (máu, combo, chí mạng, hết giờ, nhiều đầu) và gọi các hook
/// dưới đây; cơ chế nào chỉ ghi đè hook nó cần. Mỗi trận tạo bản mới
/// ([EnemySpec.mechanics]) nên cơ chế được giữ trạng thái riêng.
///
/// Thêm cơ chế mới: viết một lớp con trong lib/game/mechanics/, xuất nó ở
/// mechanics.dart, rồi gắn vào [EnemySpec.mechanics] của kẻ thù.
abstract class BattleMechanic {
  /// Trận bắt đầu cả khi người chơi giữ tư thế trước khi có rep nào.
  bool get startsOnHold => false;

  /// Trận vừa bắt đầu ở [t].
  void onStart(BattleHost battle, int t) {}

  /// Lời nhắc khi rep nông bị chặn; null = lời mặc định.
  String? partialRepMessage() => null;

  /// Chặn hẳn một rep đã được đếm (ví dụ da không xuyên thủng): trả lời
  /// nhắc để chặn, null = cho đánh.
  String? blockCountedRep(CountedRep rep) => null;

  /// Combo vừa đứt (rep nông/sai, hoặc rep đầu sau khi nghỉ quá lâu).
  List<BattleEvent> onComboBroken(BattleHost battle, int t) => const [];

  /// Chỉnh đòn đánh từ một rep trước khi trừ máu (hệ số, cờ hiển thị).
  void onStrike(BattleHost battle, Strike strike) {}

  /// Kẻ thù vừa hết máu. Trả sự kiện để giữ nó lại trận (đứng dậy…),
  /// null = để nó gục.
  List<BattleEvent>? onKnockedOut(BattleHost battle, int t) => null;

  /// Gọi mỗi khung hình khi trận đang diễn ra.
  List<BattleEvent> tick(BattleHost battle, int nowMs, int plankHoldMs) =>
      const [];

  /// Điền phần trạng thái của cơ chế vào [view] để màn hình vẽ. [restEndMs]:
  /// mốc kết thúc thời gian nghỉ (lúc bắt đầu hạ người, hoặc [nowMs]).
  void describe(BattleHost battle, BattleView view, int nowMs, int restEndMs) {}
}

/// Phần của trận mà cơ chế được đọc và đổi. Màn hình không thấy giao diện
/// này, chỉ thấy [Battle] và [BattleView].
abstract interface class BattleHost {
  EnemySpec get enemy;
  PushupMode get mode;
  DamageRules get rules;
  BattleStatus get status;
  int get hp;
  int get headHp;
  int get combo;
  int? get startMs;

  /// Lúc rep đánh trúng gần nhất kết thúc.
  int? get lastHitMs;

  /// Hồi máu (tối đa đầy máu); trả lượng thực sự hồi.
  int heal(int amount);

  /// Đặt lại máu (ví dụ đứng dậy sau khi bị hạ).
  void setHp(int hp);

  void breakCombo();

  /// Gây [damage] sát thương không đến từ rep (ví dụ đòn giữ tư thế).
  List<BattleEvent> strike(int t, double damage, Hit Function(int dealt) hit);

  List<BattleEvent> lose(int t, DefeatReason reason);
}

/// Một đòn từ rep, đi qua [BattleMechanic.onStrike] trước khi trừ máu.
class Strike {
  Strike(this.rep, {required this.restMs, required this.damage});

  final CountedRep rep;

  /// Thời gian nghỉ thật trước rep này (null = rep đầu trận).
  final int? restMs;
  double damage;

  /// Đòn yếu đi vì bị đóng băng ([Hit.frozen]).
  bool frozen = false;

  /// Đúng kiểu hành động đợt sóng đang đòi ([Hit.matched]).
  bool matched = false;
}
