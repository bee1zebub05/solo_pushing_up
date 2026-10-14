import '../../rep/pushup_counter.dart';
import '../battle_mechanic.dart';

/// Sư tử Nemea / lính đá — da không xuyên thủng: rep nông hoặc thân chưa
/// thẳng bị chặn hoàn toàn (dạy người chơi về form ngay từ tutorial —
/// Kỳ công 1).
class ImpenetrableHide extends BattleMechanic {
  @override
  String? partialRepMessage() => 'Bị chặn! Xuống sâu hơn';

  @override
  String? blockCountedRep(CountedRep rep) =>
      rep.formWarning ? 'Bị chặn! Giữ thân thẳng' : null;
}
