import 'battle.dart';

/// Một kỳ công (chương) trong hành trình 12 Kỳ Công (rules/cottruyen.md mục 3).
class Labor {
  const Labor({
    required this.number,
    required this.id,
    required this.title,
    required this.region,
    required this.emoji,
    required this.enemy,
    required this.mechanic,
    required this.reward,
  });

  final int number;
  final String id;
  final String title;
  final String region;

  /// Hình tạm cho tới khi có art.
  final String emoji;
  final EnemySpec enemy;

  /// Mô tả cơ chế để người chơi biết cách đánh.
  final String mechanic;

  /// Vật phẩm nhận được khi thắng lần đầu.
  final String reward;
}

/// Kỳ công 1 — Hy Lạp, thung lũng Nemea (tutorial).
const nemeanLion = EnemySpec(
  name: 'Sư tử Nemea',
  maxHp: 150,
  armor: BattleArmor.impenetrableHide,
);

/// Kỳ công 2 — Bắc Âu, rừng băng.
const fafnir = EnemySpec(
  name: 'Rồng Fafnir',
  maxHp: 220,
  armor: BattleArmor.freezingCold,
);

/// Kỳ công 5 — Nhật Bản, sông Hi. 8 đầu × 40 HP.
const orochi = EnemySpec(
  name: 'Yamata no Orochi',
  maxHp: 320,
  heads: 8,
  armor: BattleArmor.regrowingHeads,
);

/// Kỳ công 12 — Việt Nam, núi Tản Viên (chương cuối).
const thuyTinh = EnemySpec(
  name: 'Thuỷ Tinh',
  maxHp: 600,
  armor: BattleArmor.risingFlood,
);

/// Các kỳ công đã chơi được, theo thứ tự mở khoá (không nhất thiết liên tiếp
/// số: bản ra mắt dự kiến 1, 2, 5, 12 — rules/cottruyen.md mục 7). Số liệu tạm, cân bằng lại khi có dữ liệu thật.
const labors = <Labor>[
  Labor(
    number: 1,
    id: 'nemea',
    title: 'Sư tử Nemea',
    region: 'Hy Lạp · Thung lũng Nemea',
    emoji: '🦁',
    enemy: nemeanLion,
    mechanic: 'Da không xuyên thủng: chỉ rep đúng form mới gây sát thương',
    reward: 'Áo choàng da sư tử',
  ),
  Labor(
    number: 2,
    id: 'fafnir',
    title: 'Rồng Fafnir',
    region: 'Bắc Âu · Rừng Băng',
    emoji: '🐉',
    enemy: fafnir,
    mechanic: 'Giá lạnh: nghỉ quá 3 giây giữa hai rep thì đòn sau bị đóng băng',
    reward: 'Khiên vảy rồng',
  ),
  Labor(
    number: 5,
    id: 'orochi',
    title: 'Yamata no Orochi',
    region: 'Nhật Bản · Sông Hi',
    emoji: '🐍',
    enemy: orochi,
    mechanic:
        '8 cái đầu: chém mỗi đầu bằng một chuỗi rep liền mạch, '
        'đứt combo thì đầu đó mọc lại',
    reward: 'Kiếm Kusanagi',
  ),
  Labor(
    number: 12,
    id: 'thuy_tinh',
    title: 'Thuỷ Tinh',
    region: 'Việt Nam · Núi Tản Viên',
    emoji: '🌊',
    enemy: thuyTinh,
    mechanic:
        'Núi dâng, nước dâng: nước dâng liên tục, mỗi rep đẩy nước lùi. '
        'Làm đúng kiểu đợt sóng đang đòi (⚡ 🐢 ⏸ 💥) thì mạnh gấp rưỡi',
    reward: 'Ngựa chín hồng mao',
  ),
];

Labor get nemea => labors.first;

/// Kỳ công phải xong trước khi mở [labor] (null = mở sẵn).
Labor? previousLabor(Labor labor) {
  final i = labors.indexWhere((l) => l.id == labor.id);
  return i > 0 ? labors[i - 1] : null;
}

/// Kỳ công mở ra khi xong [labor].
Labor? nextLabor(Labor labor) {
  final i = labors.indexWhere((l) => l.id == labor.id);
  return i >= 0 && i + 1 < labors.length ? labors[i + 1] : null;
}

/// Trận luyện tập có giới hạn thời gian (không thuộc cốt truyện).
const trainingDummy = EnemySpec(
  name: 'Bù nhìn luyện tập',
  maxHp: 300,
  timeLimitMs: 30000,
);
