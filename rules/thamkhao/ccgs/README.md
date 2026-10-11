# Tham khảo: Claude Code Game Studios (CCGS)

Nguồn: https://github.com/Donchitos/Claude-Code-Game-Studios — giấy phép MIT
(xem `LICENSE`, commit gốc trong `NGUON.txt`). Chép nguyên văn ngày 11/10/2026
để học **tư duy thiết kế**; phần riêng Godot/Unity/Unreal và quản lý studio
(sprint, release, phân quyền agent) không dùng.

Cách dùng trong dự án: các skill ở `.claude/skills/` (design-gate,
balance-reps, level-spec, workout-hud, playtest-debrief, vector-game-art)
đã viết lại cho Flutter/Canvas và trỏ về đây khi cần chi tiết.

## Cái "key" — đọc theo thứ tự này

1. **Kiểm chứng được**: mọi quyết định thiết kế phải đo được và có thể sai.
   Chấm 4 mức APPROVE / CONCERNS / REJECT / **NOT ASSESSED** (thiếu dữ liệu
   ≠ đạt); gộp nhiều kết quả thì lấy mức gắt nhất. → `gates/_tong-quan.md`
2. **Trụ cột (pillars)**: 3–5 trụ, mỗi trụ có *design test* ("phân vân X hay
   Y thì trụ này chọn __") + phản trụ cột. → `templates/game-pillars.md`,
   `agents/creative-director.md`, `gates/cd-pillars.md`
3. **Vòng lặp lồng nhau** 30 giây / 5–15 phút / phiên / dài hạn, kiểm SDT
   (tự chủ, năng lực, gắn kết). → `skills/brainstorm/`, `agents/game-designer.md`
4. **Đường khó răng cưa + ZPD**: mỗi lần một cơ chế mới, dạy trước kiểm sau,
   đỉnh có thung hồi phục. → `templates/difficulty-curve.md`
5. **Soát tổng thể + đi qua kịch bản** nhiều hệ cùng chạy. →
   `skills/review-all-gdds/references/3-design-holism.md`, `4-scenarios.md`
6. **Duyệt tài liệu kiểu "phá cho hỏng"**: thay giá trị biên vào công thức,
   tiêu chí nghiệm thu phải test được. → `skills/design-review/`,
   `rules/design-docs.md`
7. **Cân bằng**: mỗi số so với mục tiêu ghi sẵn, tìm vùng chết, cú nhảy,
   chiến thuật áp đảo, kinh tế thiếu chỗ tiêu. → `skills/balance-check/`,
   `agents/systems-designer.md`, `agents/economy-designer.md`
8. **Prototype có giả thuyết**: "Nếu người chơi X thì thấy Y, đo bằng Z";
   PROCEED/PIVOT/KILL, 3 lần pivot thì cân nhắc kill. → `agents/prototyper.md`,
   `skills/prototype/references/`
9. **Art bible ràng buộc**: luật hình ảnh 1 dòng, mood theo trạng thái, hình
   bóng đọc được ở cỡ thumbnail, màu có nghĩa + dự phòng mù màu. →
   `templates/art-bible.md`, `skills/art-bible/`, `gates/ad-*.md`
10. **HUD theo ngân sách**: Must Show / Contextual / On Demand / Hidden;
    không tin nào chỉ bằng màu. → `templates/hud-design.md`, `skills/ux-design/`
11. **Tiếp cận**: tương phản ≥4,5:1, giảm chuyển động, nháy ≤3 lần/giây. →
    `agents/accessibility-specialist.md`, `templates/accessibility-requirements.md`
12. **Cốt truyện khớp luật chơi** (ludonarrative), mọi bí ẩn có đáp án thật. →
    `rules/narrative.md`, `gates/nd-consistency.md`

## Thư mục

- `agents/` — 11 vai trò thiết kế (creative director, game/level/systems/
  economy designer, art director, UX, writer, prototyper, QA, accessibility).
- `templates/` — 14 mẫu tài liệu (trụ cột, concept, GDD, màn, đường khó,
  hành trình người chơi, art bible, HUD, âm thanh, tiếp cận, nhân vật, kinh
  tế, danh mục hệ).
- `skills/` — 13 quy trình (soát tổng thể, cân bằng, duyệt thiết kế,
  brainstorm, prototype, UX, art bible, màn, phạm vi, thiết kế nhanh,
  playtest, nhất quán).
- `gates/` — câu hỏi duyệt của creative/art/narrative director.
- `rules/` — luật viết tài liệu thiết kế và cốt truyện.
