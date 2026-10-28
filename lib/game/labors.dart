import 'battle.dart';
import 'items.dart';

export 'items.dart';

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
    this.numberLabel,
  });

  final int number;

  /// Số hiển thị khi khác [number] — kỳ công Heian chưa xếp vào danh sách 12
  /// (rules/cottruyen.md, Kỳ công 5) nên hiện "5b".
  final String? numberLabel;
  String get label => numberLabel ?? '$number';
  final String id;
  final String title;
  final String region;

  /// Hình tạm cho tới khi có art.
  final String emoji;
  final EnemySpec enemy;

  /// Mô tả cơ chế để người chơi biết cách đánh.
  final String mechanic;

  /// Vật phẩm nhận được khi thắng lần đầu.
  final Item reward;

  /// Các màn trong kỳ công (ví dụ 1.1 … 1.8), màn cuối là boss. Rỗng = chỉ có
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

/// Kỳ công 1 — Hy Lạp, thung lũng Nemea (tutorial). Đặc tả 8 màn:
/// rules/thietke/chuong1-nemea.md. Máu chỉnh theo rep mục tiêu, kiểm bằng
/// test/game/chapter1_balance_test.dart.
///
/// Pha 1: da không xuyên thủng. Pha 2 (máu < 40%): vồ, giữ tay thẳng để vật.
const nemeanLion = EnemySpec(
  id: 'nemean_lion',
  name: 'Sư tử Nemea',
  maxHp: 300,
  mechanics: [ImpenetrableHide.new, LionPounce.new],
);

// Quái Kỳ công 1 (rules/cottruyen.md mục 3b.1).
const stymphalianFlock = EnemySpec(
  id: 'stymphalian_flock',
  name: 'Đàn chim Stymphalia',
  maxHp: 80,
);
const spartoi = EnemySpec(
  id: 'spartoi',
  name: 'Spartoi',
  maxHp: 90,
  mechanics: [ReviveOnce.new],
);
const stoneSoldier = EnemySpec(
  id: 'stone_soldier',
  name: 'Lính đá',
  maxHp: 150,
  mechanics: [ImpenetrableHide.new],
);
const erymanthianBoar = EnemySpec(
  id: 'erymanthian_boar',
  name: 'Lợn rừng Erymanthus',
  maxHp: 180,
  mechanics: [ChargingBoar.new],
);
const harpy = EnemySpec(
  id: 'harpy',
  name: 'Harpy',
  maxHp: 120,
  mechanics: [GoldThief.new],
);
const youngHydra = EnemySpec(
  id: 'young_hydra',
  name: 'Hydra non',
  maxHp: 240,
  heads: 3,
  mechanics: [RegrowingHeads.new],
);

/// Ôn tập trước boss: đá chặn rep sai (1.3) và ráp lại một lần (1.2).
const stoneGuard = EnemySpec(
  id: 'stone_guard',
  name: 'Lính đá canh hang',
  maxHp: 110,
  mechanics: [ImpenetrableHide.new, ReviveOnce.new],
);

/// 8 màn của Kỳ công 1: mỗi màn thường dạy một kỹ năng, 1.4 tinh anh,
/// 1.6 mini-boss, 1.8 boss Sư tử Nemea. Id giữ theo bản 10 màn cũ để không
/// mất tiến trình đã lưu (id ≠ số màn hiển thị).
const nemeaStages = <Stage>[
  Stage(
    id: 'nemea_1_1',
    code: '1.1',
    title: 'Đàn chim Stymphalia',
    enemy: stymphalianFlock,
    tip: 'Mỗi lần hít đất là một đòn. Giữ nhịp đều để combo tăng dần',
    emoji: '🐦',
    lore:
        'Ông lão Molorchus xứ Cleonae chỉ về phía thung lũng: '
        '"Từ ngày bụi xám đổ xuống, cả lũ chim lông đồng hồ Stymphalia '
        'cũng bay tới đây."',
  ),
  Stage(
    id: 'nemea_1_3',
    code: '1.2',
    title: 'Spartoi',
    enemy: spartoi,
    tip: 'Ngã một lần sẽ đứng dậy: đánh dứt điểm',
    emoji: '💀',
    lore:
        'Ai đó đã gieo răng rồng xuống ruộng đá. Chiến binh Spartoi trỗi '
        'dậy từ đất — và không chịu nằm yên.',
  ),
  Stage(
    id: 'nemea_1_4',
    code: '1.3',
    title: 'Lính đá',
    enemy: stoneSoldier,
    tip: 'Chỉ rep đúng form mới làm vỡ đá',
    emoji: '🗿',
    lore:
        'Nắng sáng trên đồi đền thần Zeus: tượng hoplite bị Trì Trệ nhập. '
        'Đá chỉ vỡ trước đòn đánh chuẩn.',
  ),
  Stage(
    id: 'nemea_1_5',
    code: '1.4',
    title: 'Lợn rừng Erymanthus (tinh anh)',
    enemy: erymanthianBoar,
    tip: 'Thấy mũi tên đỏ thì giữ tay thẳng để né cú húc',
    emoji: '🐗',
    lore:
        'Nữ thợ săn Atalanta kéo căng dây cung: "Lợn rừng không biết rẽ. '
        'Đứng vững, để nó tự lao qua."',
  ),
  Stage(
    id: 'nemea_1_6',
    code: '1.5',
    title: 'Harpy',
    enemy: harpy,
    tip: 'Nghỉ quá 4 giây là bị cướp vàng',
    emoji: '🦅',
    lore:
        'Gió rít qua cây cầu đá cổ bắc ngang sông. Harpy lượn vòng, chờ kẻ '
        'nào lơ là để cướp vàng.',
  ),
  Stage(
    id: 'nemea_1_8',
    code: '1.6',
    title: 'Hydra non (mini-boss)',
    enemy: youngHydra,
    tip: 'Đứt combo thì đầu đang chém mọc lại',
    emoji: '🐍',
    lore:
        'Trời sầm lại trên đầm lầy độc giữa thung lũng: Hydra non, con của '
        'quái vật xứ Lerna, thè ba cái lưỡi. Chém một, mọc hai.',
  ),
  Stage(
    id: 'nemea_1_9',
    code: '1.7',
    title: 'Lính đá canh hang',
    enemy: stoneGuard,
    tip: 'Ôn lại: rep đúng form, và đánh dứt điểm khi đá ráp lại',
    emoji: '🗿',
    lore:
        'Nắng chiều đổ dài trên vách đá dẫn lên hang. Lính canh bằng đá vỡ '
        'rồi lại ráp lại — và trên kia, đôi mắt hổ phách đang chờ.',
  ),
  Stage(
    id: 'nemea',
    code: '1.8',
    title: 'Sư tử Nemea',
    enemy: nemeanLion,
    tip:
        'Da không xuyên thủng: chỉ rep đúng form mới gây sát thương. '
        'Khi nó nổi giận và vồ: giữ tay thẳng để vật nó',
    emoji: '🦁',
    lore:
        'Đôi mắt hổ phách là của Sư tử Nemea: da không vũ khí nào xuyên '
        'thủng. Hercules đã vật nó bằng tay không — sức mạnh rèn từng lần một.',
  ),
];

/// Kỳ công 2 — Bắc Âu, rừng băng.
const fafnir = EnemySpec(
  id: 'fafnir',
  name: 'Rồng Fafnir',
  maxHp: 220,
  mechanics: [FreezingCold.new],
);

/// Kỳ công 5 — Nhật Bản, sông Hi. 8 đầu × 40 HP.
const orochi = EnemySpec(
  id: 'orochi',
  name: 'Yamata no Orochi',
  maxHp: 320,
  heads: 8,
  mechanics: [RegrowingHeads.new],
);

/// Chương Nhật — mini-boss Izumo (màn 5.6) và boss Heian (5b.8).
/// Cơ chế: rules/thietke/boss-nhat-shuten-sutoku.md; máu chốt bằng mô phỏng
/// test/game/chapter2_balance_test.dart (rules/thietke/chuong2-nhat.md).
final shutenDoji = EnemySpec(
  id: 'shuten_doji',
  name: 'Shuten-dōji',
  maxHp: 320,
  mechanics: [ShutenMechanic.new],
);

final sutokuTengu = EnemySpec(
  id: 'tengu_sutoku',
  name: 'Thiên hoàng Sutoku',
  maxHp: 360,
  mechanics: [SutokuMechanic.new],
);

// Quái thường hai kỳ công Nhật (rules/thietke/chuong2-nhat.md). Chưa có hình:
// trận hiện biểu tượng tạm. Đòn có báo trước dùng chung TelegraphedFoe:
// ⏸ = đòn bổ từ trên (giữ tay thẳng), duck = đòn quét ngang (rep sâu).
const _hold = BossAttack('attack', DodgeBy.hold);
const _duck = BossAttack('attack2', DodgeBy.duck);

final oniCub = EnemySpec(
  id: 'oni_cub',
  name: 'Oni con',
  maxHp: 130,
  mechanics: [() => TelegraphedFoe(attacks: const [_hold])],
);
final kappa = EnemySpec(
  id: 'kappa',
  name: 'Kappa',
  maxHp: 130,
  mechanics: [() => TelegraphedFoe(attacks: const [_duck])],
);
final oniKappa = EnemySpec(
  id: 'oni_kappa',
  name: 'Oni và kappa',
  maxHp: 160,
  mechanics: [() => TelegraphedFoe(attacks: const [_hold, _duck])],
);
final susanoo = EnemySpec(
  id: 'susanoo',
  name: 'Susanoo cuồng nộ',
  maxHp: 250,
  // Thần bão dồn dập hơn: báo 2,2 s, nghỉ 5–6,5 s (không dưới 2 s: kịp xuống rep sâu).
  mechanics: [
    () => TelegraphedFoe(
      attacks: const [_hold, _duck],
      warnMs: 2200,
      gapMinMs: 5000,
      gapMaxMs: 6500,
    ),
  ],
);
const riverYurei = EnemySpec(
  id: 'river_yurei',
  name: 'Yūrei bên sông',
  maxHp: 110,
  mechanics: [ReviveOnce.new],
);
const orochiTwin = EnemySpec(
  id: 'orochi_twin',
  name: 'Hai đầu Orochi',
  maxHp: 160,
  heads: 2,
  mechanics: [RegrowingHeads.new],
);

final karasuTengu = EnemySpec(
  id: 'karasu_tengu',
  name: 'Tengu quạ',
  maxHp: 130,
  mechanics: [() => TelegraphedFoe(attacks: const [_duck])],
);
final karasuScribe = EnemySpec(
  id: 'karasu_scribe',
  name: 'Tengu quạ chép ấn',
  maxHp: 120,
  // Chỉ viết ấn, từ đầu trận: dạy rep chậm (kỹ năng Sutoku đòi) riêng lẻ.
  mechanics: [
    () => SutokuMechanic(
      attacks: const [],
      curseBelow: 1.01,
      firstCurseDelayMs: 3000,
    ),
  ],
);
final rashomonOni = EnemySpec(
  id: 'rashomon_oni',
  name: 'Oni cổng Rashōmon',
  maxHp: 160,
  mechanics: [() => TelegraphedFoe(attacks: const [_hold, _duck])],
);
final tsuchigumo = EnemySpec(
  id: 'tsuchigumo',
  name: 'Tsuchigumo',
  maxHp: 250,
  mechanics: [
    () => TelegraphedFoe(
      attacks: const [_duck, _hold],
      warnMs: 2200,
      gapMinMs: 5000,
      gapMaxMs: 6500,
    ),
  ],
);
const courtYurei = EnemySpec(
  id: 'court_yurei',
  name: 'Hồn ma cung nữ',
  maxHp: 110,
  mechanics: [ReviveOnce.new],
);
const tamamo = EnemySpec(
  id: 'tamamo',
  name: 'Tamamo-no-Mae',
  maxHp: 225,
  heads: 9, // chín đuôi: đứt nhịp thì đuôi đang chém mọc lại
  mechanics: [RegrowingHeads.new],
);
final karasuFlock = EnemySpec(
  id: 'karasu_flock',
  name: 'Đàn tengu quạ',
  maxHp: 170,
  mechanics: [
    () => SutokuMechanic(attacks: const [_duck], curseBelow: 0.7),
  ],
);

/// Kỳ công 5 — Izumo, thời thần thoại: 8 màn (rules/thietke/chuong2-nhat.md).
final izumoStages = <Stage>[
  Stage(
    id: 'orochi_5_1',
    code: '5.1',
    title: 'Oni con',
    enemy: oniCub,
    tip: 'Oni giơ chuỳ cao: giữ tay thẳng đỡ đòn, rep sau phản đòn ×2',
    emoji: '👹',
    lore:
        'Rừng tuyết tùng xứ Izumo. Trì Trệ đánh thức lũ oni con, chuỳ sắt kéo lê trên tuyết.',
  ),
  Stage(
    id: 'orochi_5_2',
    code: '5.2',
    title: 'Kappa',
    enemy: kappa,
    tip: 'Kappa lao tới thấp: xuống một rep thật sâu đúng lúc nó tới',
    emoji: '💧',
    lore:
        'Dưới cổng torii ven sông Hi, kappa ngoi lên. Truyền rằng ai cúi chào, kappa cúi theo, nước trên đĩa đầu đổ hết, mất sức.',
  ),
  Stage(
    id: 'orochi_5_3',
    code: '5.3',
    title: 'Oni và kappa',
    enemy: oniKappa,
    tip: 'Đọc thế: chuỳ giơ cao thì giữ tay, lao thấp thì rep sâu',
    emoji: '👹',
    lore:
        'Oni và kappa cùng chặn bến đò: một đứa bổ từ trên, một đứa quét ngang.',
  ),
  Stage(
    id: 'orochi_5_4',
    code: '5.4',
    title: 'Susanoo cuồng nộ (tinh anh)',
    enemy: susanoo,
    tip: 'Bão quật xuống thì giữ tay, kiếm quét ngang thì rep sâu',
    emoji: '⛈️',
    lore:
        'Thần bão Susanoo bị đuổi khỏi Takamagahara, cơn giận chưa nguôi. Gió quật từ trên, kiếm Totsuka quét ngang.',
  ),
  Stage(
    id: 'orochi_5_5',
    code: '5.5',
    title: 'Yūrei bên sông',
    enemy: riverYurei,
    tip: 'Hồn ma tan rồi tụ lại một lần: đánh dứt điểm',
    emoji: '👻',
    lore:
        'Susanoo nguôi giận, dẫn đường. Bên bờ sông, hồn những người con gái bị Orochi nuốt hiện về.',
  ),
  Stage(
    id: 'orochi_5_6',
    code: '5.6',
    title: 'Shuten-dōji (mini-boss)',
    enemy: shutenDoji,
    tip: 'Hắn nâng vò rượu: dồn 3 rep để đánh vỡ vò, hắn choáng',
    emoji: '🍶',
    lore:
        'Vua oni núi Ōe say khướt bên vò rượu. Như Minamoto no Raikō năm xưa, chờ lúc hắn nâng vò.',
  ),
  Stage(
    id: 'orochi_5_7',
    code: '5.7',
    title: 'Hai đầu Orochi',
    enemy: orochiTwin,
    tip: 'Ôn lại: chém mỗi đầu bằng một chuỗi rep liền',
    emoji: '🐍',
    lore:
        'Tám vò rượu ủ tám lần đã bày sẵn. Hai cái đầu đầu tiên thò xuống uống.',
  ),
  Stage(
    id: 'orochi',
    code: '5.8',
    title: 'Yamata no Orochi',
    enemy: orochi,
    tip: '8 cái đầu: mỗi đầu một chuỗi rep liền, đứt combo thì đầu đó mọc lại',
    emoji: '🐍',
    lore:
        'Rắn tám đầu tám đuôi, say rượu ủ tám lần. Trong đuôi nó là thanh kiếm Kusanagi.',
  ),
];

/// Kỳ công 5b — Kinh đô Heian, thời lịch sử: 8 màn.
final heianStages = <Stage>[
  Stage(
    id: 'heian_1',
    code: '5b.1',
    title: 'Tengu quạ',
    enemy: karasuTengu,
    tip: 'Tengu quạ quạt gió chéo: rep sâu đúng lúc gió tới',
    emoji: '🪶',
    lore:
        'Kinh đô Heian, hoàng hôn trên mái cung điện. Tengu quạ, tay sai của oan hồn Sutoku, quạt gió chéo xuống.',
  ),
  Stage(
    id: 'heian_2',
    code: '5b.2',
    title: 'Tengu quạ chép ấn',
    enemy: karasuScribe,
    tip: 'Ấn nguyền làm đòn yếu đi: một rep thật chậm (xuống 3 giây) đốt ấn',
    emoji: '🪶',
    lore:
        'Một con tengu quạ vạch ấn nguyền trong không trung. Ấn chỉ cháy trước nét chép chậm rãi, cẩn trọng.',
  ),
  Stage(
    id: 'heian_3',
    code: '5b.3',
    title: 'Oni cổng Rashōmon',
    enemy: rashomonOni,
    tip: 'Ôn lại: giữ tay đỡ đòn bổ, rep sâu né đòn quét',
    emoji: '👹',
    lore:
        'Cổng Rashōmon đổ nát, nơi Watanabe no Tsuna từng chém đứt tay một con oni. Nó quay lại đòi tay.',
  ),
  Stage(
    id: 'heian_4',
    code: '5b.4',
    title: 'Tsuchigumo (tinh anh)',
    enemy: tsuchigumo,
    tip: 'Nhện đất ra đòn dồn dập hơn: đọc thế sớm',
    emoji: '🕷️',
    lore:
        'Nhện đất khổng lồ, kẻ Minamoto no Raikō từng hạ, giăng tơ kín ngôi đền bỏ hoang.',
  ),
  Stage(
    id: 'heian_5',
    code: '5b.5',
    title: 'Hồn ma cung nữ',
    enemy: courtYurei,
    tip: 'Hồn ma tan rồi hiện lại một lần: đánh dứt điểm',
    emoji: '👻',
    lore:
        'Hành lang cung điện về đêm. Hồn ma cung nữ lướt qua, tan đi rồi lại hiện.',
  ),
  Stage(
    id: 'heian_6',
    code: '5b.6',
    title: 'Tamamo-no-Mae (mini-boss)',
    enemy: tamamo,
    tip: 'Chín đuôi: chém mỗi đuôi bằng một chuỗi rep liền',
    emoji: '🦊',
    lore:
        'Mỹ nhân được Thiên hoàng Toba sủng ái hoá ra hồ ly chín đuôi. Bị âm dương sư vạch mặt, nó chạy về đồng Nasu.',
  ),
  Stage(
    id: 'heian_7',
    code: '5b.7',
    title: 'Đàn tengu quạ',
    enemy: karasuFlock,
    tip: 'Ôn trước boss: rep sâu né gió, rep chậm đốt ấn',
    emoji: '🪶',
    lore:
        'Núi Shiramine, Sanuki. Đàn tengu quạ bao quanh lăng mộ, vừa quạt gió vừa viết ấn.',
  ),
  Stage(
    id: 'heian',
    code: '5b.8',
    title: 'Thiên hoàng Sutoku',
    enemy: sutokuTengu,
    tip: 'Đọc thế: rep sâu né gió, giữ tay đỡ cú bổ, rep chậm đốt ấn',
    emoji: '👺',
    lore:
        'Thiên hoàng Sutoku bị đày sang Sanuki. Kinh ông chép gửi về bị trả lại; ông cắn lưỡi viết lời nguyền bằng máu, hoá đại tengu.',
  ),
];

/// Kỳ công 12 — Việt Nam, núi Tản Viên (chương cuối).
const thuyTinh = EnemySpec(
  id: 'thuy_tinh',
  name: 'Thuỷ Tinh',
  maxHp: 600,
  mechanics: [RisingFlood.new],
);

/// Các kỳ công đã chơi được, theo thứ tự mở khoá (không nhất thiết liên tiếp
/// số: bản ra mắt dự kiến 1, 2, 5, 12 — rules/cottruyen.md mục 7). Số liệu tạm, cân bằng lại khi có dữ liệu thật.
final labors = <Labor>[
  Labor(
    number: 1,
    id: 'nemea',
    title: 'Sư tử Nemea',
    region: 'Hy Lạp · Thung lũng Nemea',
    emoji: '🦁',
    enemy: nemeanLion,
    mechanic:
        'Da không xuyên thủng: chỉ rep đúng form mới gây sát thương; '
        'khi nó vồ, giữ tay thẳng để vật nó',
    reward: nemeanPelt,
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
    reward: dragonScaleShield,
  ),
  Labor(
    number: 5,
    id: 'orochi',
    title: 'Yamata no Orochi',
    region: 'Nhật Bản · Izumo, sông Hi',
    emoji: '🐍',
    enemy: orochi,
    mechanic:
        '8 cái đầu: chém mỗi đầu bằng một chuỗi rep liền mạch, '
        'đứt combo thì đầu đó mọc lại',
    reward: kusanagi,
    stages: izumoStages,
  ),
  Labor(
    number: 5,
    numberLabel: '5b',
    id: 'heian',
    title: 'Thiên hoàng Sutoku',
    region: 'Nhật Bản · Kinh đô Heian',
    emoji: '👺',
    enemy: sutokuTengu,
    mechanic:
        'Đọc thế đòn: rep sâu né gió, giữ tay đỡ cú bổ; rep chậm đốt ấn nguyền',
    reward: tenguFan,
    stages: heianStages,
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
    reward: nineManeHorse,
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
  id: 'training_dummy',
  name: 'Bù nhìn luyện tập',
  maxHp: 300,
  timeLimitMs: 30000,
);
