# Brief cơ chế + đòn: Shuten-dōji và Thiên hoàng Sutoku (tengu)

> **ĐÃ CHỐT 18/10/2026** (người dùng chốt cách né ⏸ / rep sâu, cơ chế uống rượu + ấn nguyền, phạm vi làm trọn). Đã qua
> `design-gate` lần 1 (kết quả ở cuối). Số máu/tần suất là tạm, chốt bằng
> `balance-reps` sau khi có kỳ công.

## 0. Ý chung cho cả chương Nhật: "đọc đòn, chọn cách né"

Hai boss dùng chung một **từ vựng né** để người chơi học một lần dùng mãi:

| Đòn của boss | Hình báo trước (bóng) | Người chơi | Biểu tượng |
|---|---|---|---|
| Đòn **từ trên bổ xuống** (nện, bổ nhào) | Vũ khí giơ cao trên đầu | **Giữ tay thẳng** (plank) chống đỡ ≥ 0,8 s lúc chạm | ⏸ |
| Đòn **ngang** (quét, gió chéo) | Vũ khí giấu thấp / kéo ngang | **Rep sâu**: đáy rep rơi vào cửa sổ chạm (cúi rạp cho đòn lướt qua) | 💥 (rep sâu) |

Ảo tưởng: *"Tôi đọc được thế của nó — nó giơ chuỳ là tôi gồng tay đỡ, nó hạ
thấp là tôi rạp người né — rồi phản đòn."*

Kỹ năng tập: **kiểm soát thời điểm** (giữ plank đúng lúc, xuống sâu đúng lúc)
— khác Hydra (giữ chuỗi), Fafnir (không nghỉ lâu), lợn rừng (chỉ giữ plank).

## 1. Shuten-dōji — mini-boss kỳ công Izumo

Nguồn: vua oni núi Ōe nghiện rượu; Minamoto no Raikō chuốc rượu độc rồi chém
(rules/cottruyen.md mục 5). Đòn: kanabō-jutsu (đập vỡ giáp, quét chân ngựa).

**Ba hành động, lần lượt, không chồng nhau:**

1. **Nện đỉnh** (⏸): báo trước 2,5 s — thế jōdan (chuỳ giơ cao ngả sau đầu,
   tay lửa vươn ngắm), âm: gầm trầm + tiếng sắt rít lên. Chạm: chuỳ nện đất.
   - Né: `plankHoldMs ≥ 800` tại mốc chạm.
2. **Quét chân ngựa** (💥): báo trước 2,5 s — thế waki-gamae (hạ thấp, chuỳ
   giấu sau hông), âm: tiếng gió rít thấp kéo dài. Chạm: chuỳ quét ngang.
   - Né: có một rep **sâu** (`isDeep`) có đáy (`startMs + descentMs`) trong
     cửa sổ [chạm − 900 ms, chạm + 300 ms].
3. **Uống rượu** (bùng nổ): Shuten cắm chuỳ, nâng vò sake tu ừng ực trong
   5 s, hồi máu dần. Âm: tiếng ực ực + cười khà.
   - Ngắt: đủ **N rep tính** trong 5 s (N = 3 chế độ chuẩn, 2 chống gối) →
     vò vỡ, Shuten sặc rượu, **choáng 3 s**: mọi đòn ×1,5 trong lúc choáng.
   - Không ngắt: hồi 2 %/giây × 5 s = **10 % máu tối đa**.

**Hậu quả & thưởng (thiên thưởng — trụ 4):**
- Né được đòn → **Phản đòn**: rep tính kế tiếp ×2 sát thương, chữ "Phản đòn!"
  + rung nhẹ.
- Trúng đòn → **mất combo** (không mất máu người chơi, không hồi máu boss).

**Lịch:** bắt đầu sau 6 s; sau mỗi hành động nghỉ 6–8 s (ngẫu nhiên đều); thứ
tự: đòn ⏸ / đòn 💥 luân phiên, cứ sau 2 đòn thì một lần uống rượu khi máu
boss < 85 %. Lúc boss đang báo trước/uống thì không lên lịch hành động khác.

## 2. Thiên hoàng Sutoku hoá đại tengu — boss kỳ công Heian

Nguồn: Sutoku chép kinh Đại thừa gửi về kinh đô, bị trả lại, cắn lưỡi viết
lời nguyền bằng máu, hoá đại tengu (Hōgen monogatari); tengu núi Kurama dạy
võ cho Yoshitsune; tessen (quạt sắt) đỡ một tay đánh tay kia.

1. **Phong kesa** (💥): báo trước 2,5 s — thế hassō (quạt dựng cạnh đầu, tay
   trái giơ đỡ, cánh dựng), âm: tiếng cánh vỗ + gió cuộn. Chạm: luồng gió
   chéo. Né: rep sâu trong cửa sổ như Quét chân ngựa.
2. **Thiên cẩu phi** (⏸): báo trước 2,5 s — thu người, cánh dựng, bật lên
   lơ lửng; âm: một tiếng vỗ cánh lớn rồi tiếng rít rơi xuống. Chạm: bổ quạt
   khi đáp. Né: `plankHoldMs ≥ 800` tại mốc chạm.
3. **Lời nguyền chép kinh** (từ khi máu < 60 %): một **ấn nguyền** (chữ máu
   lơ lửng trước nhân vật) xuất hiện; khi ấn còn, mọi đòn ×0,75 (bản đầu ×0,6: mô phỏng cho thấy người không đốt ấn tốn +64 % rep — phạt quá nặng, trụ 4). Hoá giải: một
   **rep chậm** (`isSlow`, xuống ≥ 2,5 s theo bộ đếm — "chép kinh từng nét") → ấn cháy, rep
   đó ×2. Ấn tự tan sau 15 s nếu không hoá giải. Tối đa 1 ấn cùng lúc; lần
   tiếp theo ≥ 12 s sau khi ấn trước tan. Âm: tiếng tụng kinh trầm khi ấn hiện.

Thưởng/hậu quả như Shuten (Phản đòn ×2 / mất combo).
**Lịch:** như Shuten; ấn nguyền không đếm vào "đòn" — trong lúc có ấn vẫn có
đòn, nên tối đa **2 thứ** cùng đòi người chơi (ấn + một đòn đang báo).

## 3. Công thức

| Biến | Kiểu | Khoảng | Ý nghĩa |
|---|---|---|---|
| `warnMs` | int | 2000–3500 (2500) | độ dài báo trước đòn |
| `holdDodgeMs` | int | 500–1200 (800) | plank tối thiểu tại mốc chạm |
| `duckBefore`/`duckAfter` | int | 600–1200 / 200–500 (900 / 300) | cửa sổ đáy rep sâu |
| `gapMs` | int | 6000–8000 | nghỉ giữa hai hành động |
| `counterMul` | double | 1,5–2,5 (2) | phản đòn |
| `drinkMs`, `drinkHealPerSec` | int, % | 5000, 2 % | uống rượu |
| `drinkBreakReps` | int | 3 (chống gối 2) | rep để ngắt |
| `stunMs`, `stunMul` | int, double | 3000, 1,5 | choáng sau khi ngắt |
| `curseMul`, `purgeMul` | double | 0,75 / 2 | ấn nguyền / rep hoá giải |
| `curseLifeMs`, `curseGapMs` | int | 15000 / 12000 | ấn tự tan / khoảng cách |

Sát thương một rep = gốc (Battle) × combo × [counterMul nếu phản đòn] ×
[stunMul nếu đang choáng] × [curseMul nếu có ấn] × [purgeMul nếu là rep hoá giải]
(ấn và hoá giải loại trừ nhau: rep hoá giải xoá ấn trước khi nhân).
Đầu ra: ×0,6 … ×(2 × 1,5 × 2 = 6) — trần ×4 cho một rep để chống đột biến.

## 4. Edge case

- **Camera mất người lúc chạm** (không có khung tư thế trong 1 s trước chạm):
  **huỷ đòn** — không trúng, không né (không phạt người chơi vì lỗi máy; trụ 4).
- **Rep sâu đáy rơi đúng cửa sổ nhưng rep bị từ chối (sai form):** không né.
- **Hai đòn liên tiếp quá gần:** lịch bảo đảm ≥ `gapMs`; không bao giờ báo
  trước hai đòn cùng lúc.
- **Boss hết máu giữa lúc báo trước/uống:** huỷ hành động, không chạm.
- **Hạ boss bằng phản đòn trong lúc choáng:** bình thường (Victory một lần).
- **Uống rượu lúc máu ≥ 85 %:** không uống (bỏ qua, chọn đòn).
- **Chống gối:** né plank dùng plank gối (cùng `plankHoldMs`); `drinkBreakReps = 2`.
- **Người chơi chỉ giữ plank cả trận:** né được đòn ⏸ nhưng không gây sát
  thương, trúng đòn 💥 → không thắng mà không tập (trụ 1 giữ).

## 5. Núm chỉnh + nghiệm thu

- `warnMs` tăng → dễ đọc hơn, trận chậm hơn; giảm dưới 2 s → không kịp xuống
  rep sâu (đo: tỉ lệ né đòn 💥).
- `gapMs` giảm → dồn dập, vượt ngân sách chú ý.
- **Nghiệm thu đo được** (test mô phỏng `test/game/`):
  1. Bot rep chuẩn 2 s/rep, né đúng 100 % → thắng Shuten trong ≤ ngân sách rep màn (balance-reps).
  2. Bot không bao giờ né → vẫn thắng, tốn ≤ 1,7× rep (không bị khoá thắng). Ngưỡng đầu +35 % quá chặt: mô phỏng 18/10 cho thấy chênh chủ yếu là THƯỞNG (phản đòn ×2, giữ combo) — Shuten 10 vs 11 rep, Sutoku 11 vs 18 (ấn nguyền chỉ góp ~2 rep).
  3. Bot chỉ giữ plank → không bao giờ thắng.
  4. Bot rep nông nhanh không gây hơn bot rep chuẩn.
- Playtest (`playtest-debrief`): sau 2 lần gặp, người chơi né đúng ≥ 60 % mà
  không nhìn màn hình liên tục (dựa âm thanh).

## 6. Hình / đòn (nối biên đạo)

- Choreo JSON thêm pha **giữ thế báo trước**: sân khấu chạy lấy đà tới thế
  (jōdan / waki / hassō / thu người) rồi GIỮ thế (thở nặng, rung nhẹ, lớp đỏ
  tăng dần) cho tới 0,5 s trước chạm, rồi ra đòn — thời điểm do cơ chế điều
  khiển (như `charge` của lợn rừng), không còn đòn ngẫu nhiên 7–12 s.
- Thêm cử chỉ: Shuten **uống rượu** (cắm chuỳ, nâng vò) + **sặc/choáng**;
  Sutoku **viết ấn** (cắn ngón, vạch chữ máu trong không trung).
- Phản hồi chạm: hitstop 0,1 s + rung khung + loé (trúng) / chữ "Né!" + tiếng
  keng (né được) / "Phản đòn!" ở rep sau.

## 7. Kết quả `design-gate` lần 1 (18/10/2026)

| Mục | Kết luận | Ghi chú |
|---|---|---|
| Đầu vào (tóm tắt, luật, công thức, edge, núm, nghiệm thu) | APPROVE | Đủ 5 mục; số máu để `balance-reps` |
| Trụ 1 — mồ hôi thật | APPROVE | Né = hành động thể chất (plank / rep sâu); chỉ giữ plank không thắng được |
| Trụ 2 — boss là bài tập | APPROVE | Kỹ năng: kiểm soát thời điểm plank / độ sâu; rep chậm (Sutoku); bùng nổ (Shuten) |
| Trụ 3 — đọc được khi hít đất | CONCERNS → đã sửa 21/10 | Âm báo theo **cách né**, chung mọi quái: `dodge_hold` (hai tiếng trống trầm, rung mạnh) / `dodge_duck` (tiếng vút trượt xuống, rung hai nhịp nhẹ) + tích đếm ngược 1 s và 0,5 s trước chạm (`count_tick`) — `RepFeedback.dodgeCue`, `BattleController._countdown` |
| Trụ 4 — tôn trọng cơ thể | CONCERNS → đã sửa | Camera mất người → huỷ đòn (trước là phạt); ngắt rượu nới 4 → 5 s, chống gối 2 rep |
| Vòng lặp / chú ý | APPROVE | Vòng màn; tối đa 2 thứ cùng lúc (ấn nguyền + một đòn) |
| Phá cho hỏng | APPROVE | Rep đều tự né đòn 💥 ~60 % — chấp nhận (rep chuẩn luôn có lợi), đòn ⏸ vẫn bắt dừng lại; trần ×4 mỗi rep |
| Kịch bản: hạ boss lúc đang uống / báo trước | APPROVE | Huỷ hành động, Victory một lần |
| Kịch bản: camera mất người / đứng dậy nghỉ | APPROVE (sau sửa) | Huỷ đòn; nghỉ thì combo đứt như thường |
| Kịch bản: hai cơ chế cùng lúc | APPROVE | Ấn nguyền + đòn: một rep chậm-sâu xử lý được cả hai |
| Hệ sân khấu | **CONCERNS** (M) | Đòn hiện ngẫu nhiên 7–12 s ở `battle_stage`; phải để cơ chế điều khiển thời điểm (như `charge` lợn rừng) + thế báo trước giữ được độ dài tuỳ ý |

**Tổng: CONCERNS** — quy mô sửa M (âm thanh từng đòn + nối sân khấu với cơ
chế). Ta sẽ biết quyết định đúng nếu: playtest né đúng ≥ 60 % sau 2 lần gặp,
và người chơi kể lại được "giơ chuỳ thì gồng, hạ thấp thì rạp" mà không cần
nhìn HUD.
