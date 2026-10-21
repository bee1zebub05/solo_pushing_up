# Chương 2 — Nhật Bản: Izumo (5) và Kinh đô Heian (5b), mỗi kỳ công 8 màn

> Chia màn 21/10/2026 (skill level-spec), theo khuôn chương 1
> ([chuong1-nemea.md](chuong1-nemea.md)). Code: `izumoStages`, `heianStages`
> trong `lib/game/labors.dart`. Cân bằng: `test/game/chapter2_balance_test.dart`.
> Cơ chế boss: [boss-nhat-shuten-sutoku.md](boss-nhat-shuten-sutoku.md).
> Liên quan: [../cottruyen.md](../cottruyen.md) Kỳ công 5 và mục 3b.5.

## Quyết định

- **8 màn mỗi kỳ công**, không phải 10 như cốt truyện ghi ngày 14/10: chương 1 đã
  rút 10 → 8 ngày 18/10, hai chương giữ cùng nhịp.
- Hai kỳ công theo cốt truyện đã chốt: **Izumo** (thời thần thoại, boss Orochi) rồi
  **Heian** (thời lịch sử, boss Sutoku). Heian chưa có số trong danh sách 12 →
  hiển thị "5b" (`Labor.numberLabel`); id lưu tiến trình `heian`, `heian_1…7`.
- **Từ vựng né học một lần, dùng cả chương**: ⏸ giữ tay thẳng đỡ đòn bổ, 💥 rep sâu
  né đòn quét, 🐢 rep chậm đốt ấn. Mỗi cách né được dạy riêng ở một màn thường
  trước khi boss trộn chúng.
- Quái thường dùng chung `TelegraphedFoe` (cùng luật báo trước 2,5 s, phản đòn ×2,
  trúng = mất combo, camera mất người = huỷ đòn) — không thêm hệ cơ chế mới.

## Izumo — kỳ công 5 (rừng tuyết tùng, torii, sông Hi; sáng → hoàng hôn)

| Màn | Loại | Kẻ thù (máu) | Cơ chế mới | Rep chuẩn / người mới |
|---|---|---|---|---|
| 5.1 | thường | Oni con (130) | ⏸ một đòn bổ: đọc thế, giữ tay, phản đòn ×2 | 9 / 12 |
| 5.2 | thường | Kappa (130) | 💥 một đòn quét: rep sâu đúng lúc (kappa cúi chào là đổ nước, mất sức) | 9 / 13 |
| 5.3 | thường | Oni và kappa (160) | Không. Trộn ⏸ / 💥 luân phiên | 10 / 15 |
| 5.4 | **tinh anh** | Susanoo cuồng nộ (250) | Không mới; dồn dập hơn (báo 2,2 s, nghỉ 5–6,5 s) | 14 / 21 |
| 5.5 | thường (thung) | Yūrei bên sông (110) | Không mới. Ôn "đứng dậy một lần" (chương 1) | 12 / 15 |
| 5.6 | **mini-boss** | Shuten-dōji (320) | Uống rượu: dồn 3 rep (gối: 2) trong 5 s → vỡ vò, choáng ×1,5 | 18 / 25 |
| 5.7 | thường (thung) | Hai đầu Orochi (160) | Không mới. Ôn combo mỗi đầu (Hydra chương 1) | 12 / 15 |
| 5.8 | **boss** | Yamata no Orochi (320, 8 đầu) | 8 đầu, đứt combo thì đầu đang chém mọc lại | 20 / 27 |

Truyện: Susanoo bị đuổi khỏi Takamagahara, cuồng nộ (5.4); nguôi giận, dẫn đường
(5.5); tám vò rượu ủ tám lần bày sẵn, hai đầu đầu tiên thò xuống (5.7); kiếm
Kusanagi trong đuôi Orochi (5.8, thưởng).

## Heian — kỳ công 5b (cung điện, cổng Rashōmon, núi Shiramine; hoàng hôn → đêm)

| Màn | Loại | Kẻ thù (máu) | Cơ chế mới | Rep chuẩn / người mới |
|---|---|---|---|---|
| 5b.1 | thường | Tengu quạ (130) | Không mới. Ôn 💥 rep sâu (gió chéo) | 9 / 13 |
| 5b.2 | thường | Tengu quạ chép ấn (120) | 🐢 rep chậm (xuống ≥ 2,5 s) đốt ấn nguyền, rep đó ×2 | 9 / 12 |
| 5b.3 | thường | Oni cổng Rashōmon (160) | Không. Ôn ⏸ / 💥 | 10 / 15 |
| 5b.4 | **tinh anh** | Tsuchigumo (250) | Không mới; dồn dập (báo 2,2 s) | 14 / 20 |
| 5b.5 | thường (thung) | Hồn ma cung nữ (110) | Không mới. Ôn "đứng dậy một lần" | 12 / 15 |
| 5b.6 | **mini-boss** | Tamamo-no-Mae (225, 9 đuôi) | Không mới. Chín đuôi mọc lại khi đứt combo | 19 / 21 |
| 5b.7 | thường (thung) | Đàn tengu quạ (170) | Không mới. 💥 + 🐢 cùng trận (dọn đường cho Sutoku) | 12 / 14 |
| 5b.8 | **boss** | Thiên hoàng Sutoku (360) | Trộn ⏸ / 💥 / 🐢 (máu < 60 % viết ấn) | 20 / 29 |

Thần thoại: Watanabe no Tsuna chém tay oni ở Rashōmon (5b.3); Minamoto no Raikō
hạ tsuchigumo (5b.4); Tamamo bị âm dương sư vạch mặt, chạy về Nasu (5b.6); lăng
Sutoku ở Shiramine, Sanuki (5b.7–8). Thưởng: Quạt lông tengu.

Răng cưa: đỉnh ở màn 4, 6, 8 mỗi kỳ công; thung ngay sau (5, 7). Kỹ năng boss đòi
đã dạy riêng: Sutoku cần ⏸ (5.1), 💥 (5.2, 5b.1), 🐢 (5b.2); Orochi cần combo
(1.6 Hydra, 5.7).

## Cân bằng (mô phỏng 21/10/2026)

Người chuẩn: 1 rep/giây, né mọi đòn báo trước (giữ tay từ 1,2 s trước chạm; rep
sâu canh đáy), dồn rep khi Shuten uống, rep chậm khi có ấn. Người mới: chống gối,
3 s/rep (combo luôn đứt vì cửa sổ combo 2,5 s). Khoảng nghỉ giữa đòn ngẫu nhiên
→ test đặt hạt cố định (`TelegraphedBoss.newRandom`).

- Boss Sutoku sát trần người mới (29/30): tăng máu hoặc giảm phản đòn là vượt.
- Tamamo không giảm dưới 19 rep khi hạ máu (mỗi đuôi một chuỗi combo) — vẫn
  thấp hơn boss Sutoku (20).

## Nghiệm thu

1. `flutter test test/game/chapter2_balance_test.dart` qua: mỗi màn trong rep mục
   tiêu, người mới ≤ 30 rep, răng cưa đúng ở cả hai kỳ công.
2. Mỗi đòn báo trước đọc được không cần nhìn chữ: giọng đọc "Giữ tay!" / "Xuống
   sâu!" (có sẵn) + âm báo riêng cho từng loại đòn (21/10, `boss_tell_hold` /
   `boss_tell_duck`).
3. Chơi thử trên máy thật: một lượt mỗi kỳ công dưới ~15 phút tập (chưa đo).

## Còn mở (UNRESOLVED)

- **Hình**: chỉ Shuten, Sutoku (sprite 3D) và Orochi (vector) có hình. Oni con,
  kappa, Susanoo, yūrei, tengu quạ, tsuchigumo, Tamamo hiện biểu tượng tạm.
- **Cơ chế riêng chưa làm**: yūrei "tàng hình xen kẽ", tsuchigumo "giăng tơ giảm
  combo", kappa "cúi chào" thật (hiện là đòn quét né bằng rep sâu), Tamamo "ảo ảnh"
  (hiện mượn cơ chế đầu mọc lại cho chín đuôi), Susanoo (gợi ý bão / gió đẩy lùi).
- Số kỳ công cho Heian trong danh sách 12 (đang "5b").
- Tiến trình chương 1 nhánh này còn bản 10 màn; nhánh chương 1 đã 8 màn — gộp
  nhánh sẽ đụng `labors.dart`.
- Phông riêng cho Izumo và Heian (hiện dùng phông chung).
