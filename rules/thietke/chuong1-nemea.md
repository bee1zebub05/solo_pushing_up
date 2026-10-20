# Chương 1 — Thung lũng Nemea (8 màn)

> Chốt 18/10/2026 (rút từ 10 màn xuống 8). Chủ đề: Hy Lạp cổ đại.
> Code: `nemeaStages` trong `lib/game/labors.dart`. Cân bằng:
> `test/game/chapter1_balance_test.dart`. Liên quan: [tru-cot.md](tru-cot.md),
> [../cottruyen.md](../cottruyen.md) mục 3 và 3b.1, [../dohoa.md](../dohoa.md).

## Truyện

Người kế nhiệm đi dọc Thung lũng Nemea, từ bìa rừng ô liu vào hang sư tử.
Mỗi màn thường dạy một kỹ năng hít đất; boss kiểm lại hai kỹ năng chính
(đúng form, giữ tay thẳng khi bị lao tới).

Ánh sáng đi theo một ngày: sáng sớm → trưa → chiều → hoàng hôn → hang tối.

**Nhân vật phụ (chỉ trong lời kể và thoại, chưa có hình riêng):**

| Nhân vật | Vai trò | Gốc thần thoại |
|---|---|---|
| Hercules | Người thầy, cảnh mở đầu | Kỳ công 1 của Hercules |
| Molorchus | Ông lão xứ Cleonae, kể chuyện thung lũng (1.1) | Người nông dân nghèo cho Hercules trú nhờ trước khi săn sư tử; con trai ông bị sư tử giết |
| Atalanta | Nữ thợ săn, chỉ cách né lợn rừng (1.4); đặt nền cho trang phục Atalanta | Nữ thợ săn Arcadia, nổi tiếng ở cuộc săn lợn rừng Calydon (không phải lợn Erymanthus — không viết sai) |
| Kẻ Ru Ngủ | Sứ giả Trì Trệ, báo trước chương 2 sau khi thắng boss | Nhân vật của game (cottruyen mục 13) |

## 8 màn

| Màn | Loại | Kẻ thù (máu) | Bối cảnh, ánh sáng | Cơ chế mới | Rep mục tiêu |
|---|---|---|---|---|---|
| 1.1 | thường | Đàn chim Stymphalia (80) | Bìa rừng ô liu, sáng sớm | Không. Rep = đòn; combo tăng khi giữ nhịp | 6–8 |
| 1.2 | thường | Spartoi (90) | Ruộng đá cạn, gần trưa | Đứng dậy một lần (`ReviveOnce`) | 8–12 |
| 1.3 | thường | Lính đá (150) | Đền Zeus đổ nát, giữa trưa | Đúng form (`ImpenetrableHide`) — dạy trước kỹ năng 1 của boss | 10–12 |
| 1.4 | **tinh anh** | Lợn rừng Erymanthus (180) | Rừng ô liu bị húc đổ, đầu chiều | Giữ tay thẳng để né húc (`ChargingBoar`) — dạy trước kỹ năng 2 của boss | 12–16 |
| 1.5 | thường (thung) | Harpy (120) | Mái đền, vách đá, chiều gió | Nghỉ quá 4 s bị cướp vàng (`GoldThief`) | 8–10 |
| 1.6 | **mini-boss** | Hydra non, 3 đầu (240) | Đầm lầy cuối thung lũng, hoàng hôn | Đứt combo thì đầu đang chém mọc lại (`RegrowingHeads`) | 14–18 |
| 1.7 | thường (thung trước boss) | Lính đá canh hang (110) | Cửa hang, chạng vạng; mắt hổ phách trong bóng tối | Không mới. Ôn: form + đứng dậy một lần | 10–12 |
| 1.8 | **boss** | Sư tử Nemea (300) | Trong hang, tối, ánh lửa | Pha 2 (máu < 40%): vồ, giữ tay thẳng để vật (`LionPounce`) | 18–22 |

Răng cưa: đỉnh 1.4, 1.6, 1.8; thung ngay sau (1.5, 1.7). Mỗi màn tối đa một
cơ chế mới; hai kỹ năng boss đòi đều đã dạy riêng (1.3, 1.4).

Id lưu tiến trình giữ theo bản 10 màn cũ (`nemea_1_1`, `nemea_1_3`, `nemea_1_4`,
`nemea_1_5`, `nemea_1_6`, `nemea_1_8`, `nemea_1_9`, `nemea`) — **id khác số
màn hiển thị**, đừng "sửa cho khớp" vì người chơi cũ sẽ mất tiến trình.

## Boss: Sư tử Nemea hai pha

- **Pha 1**: da không xuyên thủng. Rep nông hoặc thân chưa thẳng bị chặn
  ("Bị chặn!").
- **Pha 2** (máu < 40%, trùng lúc sân khấu diễn nổi giận): cú vồ đầu sau
  4 s, sau đó mỗi 10 s. Báo trước 2,5 s bằng chữ, giọng đọc "Sư tử vồ. Giữ
  tay thẳng" và tiếng báo đòn; sư tử diễn đòn vồ sao cho cú chạm trùng lúc
  vồ tới.
  - Giữ tay thẳng ≥ 0,8 s lúc vồ tới: **vật được**, một đòn 30 sát thương
    (Tân binh ×0,7). Thưởng, không chỉ né — theo trụ cột 4.
  - Không giữ: sư tử hồi 8% máu, mất combo.
- Thần thoại: Hercules hạ sư tử bằng tay không (siết cổ) vì da không xuyên
  thủng — pha 2 là khoảnh khắc đó.

## Cân bằng (mô phỏng 18/10/2026)

Người chuẩn: 1 rep/giây, né mọi đòn báo trước. Người mới: chống gối, 1 rep
mỗi 3 giây.

| Màn | 1.1 | 1.2 | 1.3 | 1.4 | 1.5 | 1.6 | 1.7 | 1.8 |
|---|---|---|---|---|---|---|---|---|
| Người chuẩn | 7 | 10 | 11 | ≤16 | 9 | 16 | 12 | 19 |
| Người mới (giới hạn 30) | 9 | 14 | 14 | ≤27 | 12 | 21 | 15 | 22 |

Boss: vật được sư tử thì thắng nhanh hơn không vật (19 so với 21 rep).

## Nghiệm thu

1. `flutter test test/game/chapter1_balance_test.dart` qua: mỗi màn trong rep
   mục tiêu, người mới ≤ 30 rep, đường răng cưa đúng.
2. Pha 2 sư tử đọc được không cần nhìn chữ: có giọng đọc và tiếng báo đòn
   trước ≥ 0,6 s (thực tế 2,5 s).
3. Chơi thử trên máy thật: một lượt chương 1 dưới khoảng 15 phút tập
   (chưa đo).

## Còn mở (UNRESOLVED)

- **Harpy (1.5)** trừ XP khi nghỉ lâu, ngược trụ cột 4. Chưa quyết: đổi sang
  phạt trong trận (Harpy hồi máu) hay ghi là ngoại lệ có chủ đích.
- **Sư tử (19/10/2026)**: mô hình Tripo3D gắn xương (`tool/blender/lion_tripo.py`),
  đủ `idle`, `attack`, `defeat`, `pounce` (pha 2), `wrestled` (vật được).
  Chưa có hình nhân vật vật nhau với sư tử (nhân vật chỉ giữ plank).
- **Lợn rừng (19/10/2026)**: mô hình Tripo3D gắn xương (`tool/blender/boar_tripo.py`),
  `idle` + `attack` cùng nhịp bản cũ. Bản Blender giờ cũng vẽ mũi tên đỏ báo
  húc (trước đây chỉ bản vector có).
- **Hình còn thiếu**: lính đá chưa có chuỗi `rise` (ráp lại) trong Blender
  (`hoplite.py`); chân dung Molorchus,
  Atalanta, Kẻ Ru Ngủ; phông đầm lầy (1.6) và trong hang (1.8) — hiện dùng
  chung phông thung lũng.
- Thoại kết chương (Kẻ Ru Ngủ) chưa có màn hình.
- Sprite và nhánh vẽ của "Bầy chim" và "Chim và Spartoi" (`NemeaMonster.swarm`,
  `.pack` trong `nemea_monster_art.dart`, `boss_registry.dart`) không còn màn
  nào dùng — giữ lại để tái dùng hoặc xoá sau.
