---
name: boss-mechanic
description: Thiết kế và dựng một cơ chế / đòn đánh (cử chỉ) boss cho Solo Pushing Up sao cho KHÔNG ngô nghê — mỗi đòn có dấu hiệu báo trước đọc được, có cách hoá giải, ra đòn theo nhịp lấy đà→chạm→thu; nối code cơ chế (lib/game/mechanics/ + BattleMechanic), biên đạo (choreo.json) và phản hồi game feel. Dùng khi thêm/sửa boss, dựng hành vi/cử chỉ một boss mới, hay khi được bảo "làm đòn boss đỡ ngố".
---

# Dựng cơ chế & đòn đánh boss (chống "ngô nghê")

Rút từ CCGS (`rules/thamkhao/ccgs/agents/systems-designer.md`, `gates/cd-*`)
+ bài học thật ở `rules/dohoa/chuyendong.md`. Skill này **không** dạy lại biên đạo
(đã có `boss-motion`) và **không** chấm số cân bằng (đã có
`balance-reps`) — nó lo phần khiến một boss "có hồn": tạo quyết định cho người
chơi + đòn đọc được.

## 0. Vì sao boss ra ngô nghê (đọc trước)

Ba lỗi gốc — tránh cả ba:
1. **Cơ chế chỉ là một con số** ("+30% máu", "đánh mạnh hơn") → không tạo
   QUYẾT ĐỊNH nào cho người chơi. Cơ chế hay = một bài học kỹ năng: người chơi
   phải ĐỔI cách hít đất (giữ chuỗi, nghỉ đúng lúc, xuống sâu, ra đòn khớp…).
2. **Đòn không có nhịp** — chỉ A→B tuyến tính, thân đứng yên. Đòn thật = lấy đà
   (anticipation) → báo trước đọc được ở bóng → chạm (khựng + lực) → thu
   (zanshin, phần phụ trễ). Xem `rules/dohoa/chuyendong.md` và `vector-game-art` mục 1
   (§hoạt hình: 12 nguyên lý Disney).
3. **Tự nghĩ, không tra nguồn** → ra đòn generic. Như biên đạo chương Nhật đã tra kiếm đạo /
   kanabō / tessen: mỗi đòn phải truy được về một nguồn hoặc nguyên lý thật.
   Tốt nhất: lấy cơ học thân từ **mocap võ thật** (skill `boss-motion`,
   `rules/dohoa/chuyendong.md`) — boss quay về Hercules, thân/chân/ngón từ võ sinh,
   tay vũ khí theo biên đạo.

## 1. Brief trước khi code (xin người dùng chốt)

Một cơ chế = một bài học. Viết và chốt trước khi gõ dòng code nào:
- **Kỳ công / boss nào, dạy kỹ năng gì?** (nối `lib/game/labors.dart`).
- **Dấu hiệu báo trước (telegraph):** hình + màu (đỏ = sắp đánh, theo art-bible
  ở `vector-game-art` mục 7), đọc được ≥ 0,6 s, và KHÁC các đòn khác của chính
  boss đó.
- **Cách hoá giải (counterplay):** người chơi làm gì để né/giảm? Luôn có cửa thắng.
- **Hậu quả khi trượt:** mất gì (combo, máu, vàng, thời gian…).
- **Nguồn tham khảo** cho tư thế/đòn (võ thuật, thần thoại).
→ Đưa qua `design-gate` trước khi viết code.

## 2. Dựng cơ chế (BattleMechanic)

- Một lớp con `BattleMechanic` trong `lib/game/mechanics/<tên>.dart`, export ở
  `lib/game/mechanics/mechanics.dart`, rồi gắn vào `EnemySpec.mechanics` của kẻ thù.
- Chỉ ghi đè hook cần (xem `lib/game/battle_mechanic.dart`): `onStart`,
  `blockCountedRep`, `onComboBroken`, `onStrike`, `tick`, `onKnockedOut`,
  `describe`. `Battle` lo phần chung (máu, combo, chí mạng, nhiều đầu); mỗi trận
  tạo một bản cơ chế mới nên được giữ trạng thái riêng.
- Mẫu gọn nhất: `regrowing_heads.dart` (đứt combo → đầu đang chém hồi đầy máu,
  dạy giữ chuỗi). Cơ chế = một ý tưởng rõ một dòng, không rải rác khắp file.
- Trạng thái cơ chế muốn hiện lên màn hình: điền qua `describe(... BattleView ...)`.

## 3. Biên đạo đòn (cử chỉ) — giao cho phòng Chuyển động

Phần hình của đòn do skill `boss-motion` lo (biên đạo `tool/motion/choreo/<id>.json`,
mocap võ học, tấm tư thế khoá) — đưa nó brief mục 1. Yêu cầu tối thiểu phía
cơ chế: mỗi boss ≥ 2 đòn, dấu hiệu báo trước KHÁC nhau, mốc `impact` trong JSON
khớp thời điểm cơ chế tính trúng/né.

## 4. Game feel lúc chạm (nối cơ chế ↔ hình)

Mỗi đòn trúng phải có (xem `vector-game-art` mục 6, `rules/dohoa/vaogame.md`): hitstop
(khựng ~0,1 s) + loé trắng + giật lùi + rung khung + hạt. Telegraph của boss:
lớp đỏ + rung TRƯỚC mốc `impact` trong JSON; mốc `impact` canh đúng khung hiệu ứng.

## 5. Cổng chống "ngô nghê" (bắt buộc)

- **Tự soát:** đòn có đủ lấy đà / báo trước / chạm / thu? Telegraph đọc được ở
  bóng? Cơ chế tạo một quyết định thật, không chỉ là số?
- **Critic mắt-lạ:** xuất khung đòn (tấm tư thế khoá + video từ `render-export`,
  và/hoặc `ART_PREVIEW=1 flutter test test/art` cho bản vector) rồi gọi agent
  `critic` MỚI (tool Agent, `subagent_type: critic`), đưa ảnh + brief mục 1, **không nói mình vừa
  làm**. Hỏi: "Đòn này đọc ra là đòn gì không? Trông như robot trượt A→B hay
  như một cú đánh thật? Liệt kê ≥ 5 chỗ ngố." Sửa → xuất lại → critic mới, lặp
  tới khi đạt.
- **Mô phỏng + chơi thử:** test ở `test/game/` (combo / nhiều đầu / đóng băng…);
  rồi chạy `playtest-debrief` trên buổi tập thật — telegraph có kịp đọc khi
  đang hít đất, mắt nhìn sàn không?

## 6. Nghiệm thu

- `flutter analyze`, `flutter test` (gồm `test/game/` + `test/art/choreo_test.dart`).
- Commit riêng từng hạng mục: cơ chế / biên đạo / hiệu ứng.
- Bài học cơ chế / game feel → `rules/dohoa/vaogame.md`; bài học đòn → `rules/dohoa/chuyendong.md`.
- Ghi `baocao_dohoa.html` kèm video từng đòn nhúng thẳng vào HTML (skill `render-export`).
