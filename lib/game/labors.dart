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
    this.stages = const [],
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

  /// Các màn trong kỳ công (1.1 … 1.10), màn cuối là boss. Rỗng = chỉ có
  /// trận boss.
  final List<Stage> stages;

  /// Danh sách màn thực tế: nếu không khai báo thì là một màn boss.
  List<Stage> get allStages => stages.isNotEmpty
      ? stages
      : [
          Stage(
            id: id,
            code: '$number',
            title: title,
            enemy: enemy,
            tip: mechanic,
            emoji: emoji,
          ),
        ];
}

/// Một màn trong kỳ công: một trận với một kẻ thù.
class Stage {
  const Stage({
    required this.id,
    required this.code,
    required this.title,
    required this.enemy,
    required this.tip,
    required this.emoji,
    this.lore = '',
  });

  /// Một câu kể thần thoại dẫn vào màn (giữ mạch truyện như Zombies, Run!).
  final String lore;

  /// Khoá lưu tiến trình, ví dụ 'nemea_1_3'.
  final String id;

  /// Số màn hiển thị, ví dụ '1.3'.
  final String code;
  final String title;
  final EnemySpec enemy;

  /// Điều màn này dạy người chơi.
  final String tip;
  final String emoji;
}

/// Kỳ công 1 — Hy Lạp, thung lũng Nemea (tutorial).
const nemeanLion = EnemySpec(
  name: 'Sư tử Nemea',
  maxHp: 150,
  armor: BattleArmor.impenetrableHide,
);

// Quái thường Kỳ công 1 (rules/cottruyen.md mục 3b.1). Số liệu tạm.
const stymphalianFlock = EnemySpec(name: 'Đàn chim Stymphalia', maxHp: 60);
const stymphalianSwarm = EnemySpec(name: 'Bầy chim Stymphalia', maxHp: 90);
const spartoi = EnemySpec(
  name: 'Spartoi',
  maxHp: 80,
  armor: BattleArmor.reviveOnce,
);
const stoneSoldier = EnemySpec(
  name: 'Lính đá',
  maxHp: 90,
  armor: BattleArmor.impenetrableHide,
);
const erymanthianBoar = EnemySpec(
  name: 'Lợn rừng Erymanthus',
  maxHp: 120,
  armor: BattleArmor.chargingBoar,
);
const harpy = EnemySpec(name: 'Harpy', maxHp: 90, armor: BattleArmor.goldThief);
const spartoiPack = EnemySpec(
  name: 'Chim và Spartoi',
  maxHp: 110,
  armor: BattleArmor.reviveOnce,
);
const youngHydra = EnemySpec(
  name: 'Hydra non',
  maxHp: 120,
  heads: 3,
  armor: BattleArmor.regrowingHeads,
);
const stoneGuard = EnemySpec(
  name: 'Lính đá canh hang',
  maxHp: 120,
  armor: BattleArmor.impenetrableHide,
);

/// 10 màn của Kỳ công 1: quái thường dạy dần từng kỹ năng, 1.5 tinh anh,
/// 1.8 mini-boss, 1.10 boss Sư tử Nemea.
const nemeaStages = <Stage>[
  Stage(
    id: 'nemea_1_1',
    code: '1.1',
    title: 'Đàn chim Stymphalia',
    enemy: stymphalianFlock,
    tip: 'Làm quen: mỗi lần hít đất là một đòn đánh',
    emoji: '🐦',
    lore:
        'Bìa rừng ô liu phủ bụi xám. Lũ chim lông đồng của hồ Stymphalia đã bay tới tận đây.',
  ),
  Stage(
    id: 'nemea_1_2',
    code: '1.2',
    title: 'Bầy chim kéo đến',
    enemy: stymphalianSwarm,
    tip: 'Giữ nhịp đều để combo tăng dần',
    emoji: '🐦',
    lore:
        'Tiếng cánh đồng rít như lưỡi dao: cả bầy đang kéo về phía người kế nhiệm.',
  ),
  Stage(
    id: 'nemea_1_3',
    code: '1.3',
    title: 'Spartoi',
    enemy: spartoi,
    tip: 'Ngã một lần sẽ đứng dậy: đánh dứt điểm',
    emoji: '💀',
    lore:
        'Từ răng rồng gieo xuống đất, chiến binh Spartoi trỗi dậy — và không chịu nằm yên.',
  ),
  Stage(
    id: 'nemea_1_4',
    code: '1.4',
    title: 'Lính đá',
    enemy: stoneSoldier,
    tip: 'Chỉ rep đúng form mới làm vỡ đá',
    emoji: '🗿',
    lore:
        'Tượng hoplite canh đền bị Trì Trệ nhập. Đá chỉ vỡ trước đòn đánh chuẩn.',
  ),
  Stage(
    id: 'nemea_1_5',
    code: '1.5',
    title: 'Lợn rừng Erymanthus (tinh anh)',
    enemy: erymanthianBoar,
    tip: 'Thấy mũi tên đỏ thì giữ tay thẳng để né cú húc',
    emoji: '🐗',
    lore:
        'Lợn rừng Erymanthus, kẻ Hercules từng bắt sống, đang húc đổ từng hàng ô liu.',
  ),
  Stage(
    id: 'nemea_1_6',
    code: '1.6',
    title: 'Harpy',
    enemy: harpy,
    tip: 'Nghỉ quá 4 giây là bị cướp vàng',
    emoji: '🦅',
    lore: 'Harpy lượn quanh đền, chờ kẻ nào lơ là để cướp vàng.',
  ),
  Stage(
    id: 'nemea_1_7',
    code: '1.7',
    title: 'Chim và Spartoi',
    enemy: spartoiPack,
    tip: 'Ôn lại: nhịp đều, đánh dứt điểm',
    emoji: '⚔️',
    lore: 'Chim và xương binh cùng chặn cây cầu đá cuối cùng.',
  ),
  Stage(
    id: 'nemea_1_8',
    code: '1.8',
    title: 'Hydra non (mini-boss)',
    enemy: youngHydra,
    tip: 'Đứt combo thì đầu đang chém mọc lại',
    emoji: '🐍',
    lore: 'Dưới đầm lầy, Hydra non thè ba cái lưỡi. Chém một, mọc hai.',
  ),
  Stage(
    id: 'nemea_1_9',
    code: '1.9',
    title: 'Lính đá canh hang',
    enemy: stoneGuard,
    tip: 'Màn cuối trước hang sư tử: giữ form chuẩn',
    emoji: '🗿',
    lore:
        'Trước cửa hang, lính đá cuối cùng đứng gác. Từ bóng tối, đôi mắt hổ phách đang nhìn ra.',
  ),
  Stage(
    id: 'nemea',
    code: '1.10',
    title: 'Sư tử Nemea',
    enemy: nemeanLion,
    tip: 'Da không xuyên thủng: chỉ rep đúng form mới gây sát thương',
    emoji: '🦁',
    lore:
        'Sư tử Nemea: da không vũ khí nào xuyên thủng. Chỉ sức mạnh rèn từng lần một mới hạ được nó.',
  ),
];

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
    stages: nemeaStages,
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
