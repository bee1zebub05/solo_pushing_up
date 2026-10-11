/// Hình học giải phẫu cho đồ hoạ vector vẽ bằng code.
///
/// - [smoothPath], [taperedStroke]: đường cong hữu cơ và nét mực thon hai đầu.
/// - [LimbFrame]: toạ độ (t dọc chi, s ngang chi) bám theo tư thế.
/// - [MuscleProfile], [Groove], [buildLimb]: đường bao chi theo giải phẫu và
///   các rãnh tách nhóm cơ.
/// - [HumanAnatomy], [FelineAnatomy]: bộ profile dựng sẵn.
///
/// Nguyên tắc vẽ (Loomis; luyện vẽ dáng người): mỗi chi có một mặt gần thẳng,
/// mặt kia cong; khối phồng hai mặt đặt lệch độ cao (không đối xứng gương);
/// chi thon dần về đầu mút; các khối cơ chồng lên nhau từ khớp trở xuống.
library;

export 'src/curves.dart';
export 'src/hand.dart';
export 'src/limb.dart';
export 'src/presets.dart';
