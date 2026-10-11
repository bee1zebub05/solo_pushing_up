# Đồ hoạ: phong cách game vector (nghiên cứu đêm 10–11/10/2026)

Mục tiêu: nhân vật và boss vẽ hoàn toàn bằng code (`lib/art/`), không mua asset, đủ đẹp để lên store. Chỉ học **kỹ thuật** từ các game đi trước, không sao chép hình.

## 1. Quan sát từ tham khảo

Tham khảo chính là dòng Kingdom Rush (Ironhide): phong cách cartoon nhiều chi tiết, chú trọng đọc được hình ở kích thước nhỏ.

| Đặc điểm | Ghi chú | Áp dụng cho mình |
|---|---|---|
| Tỉ lệ "chunky" | Đầu to, cẳng tay và bàn tay to, bàn chân/giày to, chân ngắn | Cẳng tay to hơn bắp tay, nắm đấm to, sandal to hơn |
| Viền đậm, không đều | Viền dày ở phía khuất sáng, mỏng phía có sáng | Thêm một lớp viền lệch về phía bóng |
| Đổ bóng 3 tông | Màu gốc, mảng bóng sắc cạnh, vệt sáng; chấm bóng loáng nhỏ | Đã có bóng và viền sáng; thêm chấm bóng loáng trên tóc, kim loại, má |
| Biểu cảm mạnh | Nghiến răng, mày chau, mắt nheo | Mặt đổi theo độ gắng sức của rep |
| Bóng tiếp đất | Ellipse tối dưới chân giúp nhân vật "đứng" trên nền | Thêm bóng dưới người khi đứng và khi chống đẩy |
| Boss | To hơn hẳn nhân vật, màu tương phản mạnh (xanh ngọc, tím, cam), mắt phát sáng, dáng gai góc, hiệu ứng phát sáng | Mỗi boss một màu chủ đạo, mắt và đòn có ánh phát sáng |

## 2. Nguyên tắc rút ra

1. **Đọc được ở kích thước điện thoại để trên sàn cách 1 m**: dáng tổng thể quan trọng hơn chi tiết.
2. **Ánh sáng thống nhất**: nguồn sáng trên bên trái cho mọi nhân vật, boss, phông nền (`VectorStyle.lightWorld`).
3. **Viền**: dày ở phía bóng, mỏng ở phía sáng. Đường bên trong (nếp vải, cơ) mỏng hơn viền ngoài.
4. **Boss: hình phải nói lên cơ chế** (đọc được trước khi bị đánh):
   - Thuỷ Tinh: nước dâng thật trên sân khấu.
   - Orochi: thấy rõ đầu bị chém và đầu mọc lại.
   - Fafnir: băng phủ lên khi người chơi nghỉ lâu.
5. **Mỗi kiểu nguy hiểm một màu và hình cố định** trong suốt trận, để người chơi không phải học lại.
6. **Ngân sách hiệu năng**: cả sân khấu dưới 2 ms/khung (đo bằng test trên PC). Không dùng `Path.combine` mỗi khung; phần tĩnh vẽ sẵn thành Picture.

## 3. Nguồn

- [Kingdom Rush (Wikipedia)](https://en.wikipedia.org/wiki/Kingdom_Rush): phong cách cartoon chi tiết, art director Gonzalo Sande.
- [Ironhide: "As long as our fans love Kingdom Rush…"](https://gameworldobserver.com/2018/12/06/ironhide-long-fans-love-kingdom-rush-will-continue-working): giữ phong cách cartoon, thêm chi tiết và hoạt hình.
- [Blender Studio: cartoon character shading](https://studio.blender.org/blog/cartoon-character-shading-with-geometry-nodes): viền là yếu tố chính giúp nhân vật dễ đọc; viền sáng theo góc nhấn dáng.
- [Tuts+: vector anime character, coloring](https://design.tutsplus.com/tutorials/creating-a-vector-anime-character-in-adobe-photoshop-part-2-coloring--vector-8797): cel shading là mảng bóng sắc cạnh, hợp với vector.
- [Enemy telegraph shape language (2026)](https://gamineai.com/blog/enemy-telegraph-shape-language-top-down-boss-fights-fast-visual-consistency-audit-2026) và [Designing for difficulty readability](https://gamedeveloper.com/blogs/designing-for-difficulty-readability-in-arpgs): dáng boss báo trước kiểu tấn công; dấu hiệu nhất quán.
- Ảnh tham khảo Kingdom Rush xem qua Google Images (chỉ để học, không lưu, không dùng lại).

## 4. Nâng cấp sáng 11/10/2026: bớt "trẻ con", theo giáo trình mỹ thuật

Phản hồi: hình còn hơi trẻ con. Cách làm (chi tiết và checklist ở skill
`.claude/skills/vector-game-art/SKILL.md`):

- **Ánh sáng 6 vùng** (Loomis *Successful Drawing*, Gurney *Color and Light*):
  `shadedPath` giờ tô vệt sáng → màu gốc chuyển nhẹ trên–dưới → bóng → bóng
  lõi → ánh phản xạ lạnh (`VectorStyle.rimTint`) ở mép khuất. Mọi nhân vật
  tự được nâng cấp vì dùng chung hàm.
- **Chỉnh màu toàn cảnh** (`paintStageGrade`): phủ ánh sáng chủ đạo của cảnh
  (nhân màu) + vignette, giúp nhân vật và nền cùng một "không khí".
- **Ngôn ngữ hình khối**: boss/quái dùng tam giác, gai, bất đối xứng; người
  chơi/Hercules khối vuông–tròn.
- **Tỉ lệ người** (Loomis): mục tiêu ≥ 5,5 đầu, không chibi.
- **Hoạt hình** (Thomas & Johnston, *The Illusion of Life*): đòn vồ của sư tử
  có lấy đà → ra đòn → thu về; trúng đòn co–giãn; bờm/đuôi theo sau.
- **Chất liệu**: `furStrokes` (lông), `hatch` (gạch bóng) trong vùng cắt.

Nguồn đọc thêm (tóm tắt thứ cấp, nên đọc sách gốc khi có thể):
- [Color and light basic concepts (tóm tắt theo Gurney)](https://zoungyart.substack.com/p/color-and-light-basic-concepts)
- [Still life and portrait: ánh sáng, bóng lõi, ánh phản xạ](https://www.studiomatrx.org/students/visual-arts/still-life-and-portrait)
- [Portrait fundamentals (Clip Studio Tips)](https://tips.clip-studio.com/es-es/articles/3912?org=1)
- Không tìm được skill vẽ vector cho agent phù hợp trên mạng (chỉ có skill pixel art SVG trên claudskills.com và bộ Claude Code Game Studios thiên về thiết kế game), nên tự viết skill riêng.

### Kỹ thuật thêm trong buổi sáng 11/10

- **2,5D bằng parallax**: tách phông nền thành lớp (trời, xa, giữa, gần), mỗi lớp
  một `Picture`; camera trôi chậm, lớp xa lệch nhiều hơn lớp nhân vật đứng; lớp
  **tiền cảnh** (cỏ, đá tối ngược sáng ở góc) vẽ đè lên nhân vật và trôi ngược
  chiều. Bản phủ bụi cũng tách theo lớp cho khớp (`NemeaLayer`).
- **Khoảnh khắc trúng đòn** (impact frame): vòng chấn động + lõi loé vài khung
  + tia nhọn toả; kết hợp loé trắng boss và rung khung khi chí mạng.
- **Soát cận cảnh**: ngoài ảnh toàn cảnh, luôn xuất ảnh phóng to (mặt boss, mặt
  nhân vật, quái) — lỗi "trẻ con" chỉ lộ ra khi nhìn gần.
- **Test sân khấu Flame thật** (`test/art/stage_game_test.dart`): bắt lỗi hiệu
  ứng chỉ xuất hiện khi chạy game (đòn bay, huy hiệu, da sư tử bay).
- **Bảng dấu hiệu báo trước đòn (chương 1)**, mỗi kẻ thù một màu/hình cố định:
  sư tử = cào đất tung bụi + rung + mắt loé cam; lợn rừng = mũi tên đỏ chớp trên
  đất (né bằng squat); Harpy = vòng sóng rít tím; Hydra = vũng độc xanh sủi bọt; lính đá = mũi giáo loé sao tím;
  rep sai form = khiên lục giác vàng + "BỊ CHẶN!".

## 5. Nghiên cứu 11/10 chiều: skill cho agent, lý thuyết thiết kế game

**Skill/plugin cho agent đã xem** (không có cái nào cho Flutter Canvas; skill
`vector-game-art` của dự án vẫn hợp nhất):
- [Claude-Code-Game-Studios](https://github.com/Donchitos/Claude-Code-Game-Studios): bộ 49 agent cho Godot/Unity/Unreal, quá nặng; chỉ tham khảo `/art-bible`, `/balance-check`.
- [opusgamelabs/game-creator](https://github.com/opusgamelabs/game-creator): skill "visual polish" cho Phaser/three.js (JS), tham khảo ý tưởng.
- [genart-ops](https://github.com/0xDarkMatter/claude-mods/blob/main/skills/genart-ops/SKILL.md): bảng màu OKLCH, hình hữu cơ bằng cubic — có thể mượn ý.

**Lý thuyết áp dụng cho chương nhiều màn:**
- Kishōtenketsu (Nintendo): mỗi cơ chế giới thiệu → phát triển → biến tấu → kết ([nguồn](https://www.mcvuk.com/development/video-nintendos-level-design-secrets-in-four-steps)).
- Độ khó răng cưa: đỉnh khó (1.5 tinh anh, 1.8 mini-boss, 1.10 boss) xen màn dễ hơn; cơ chế mới ra mắt ở chỗ dễ.
- Flow (Jenova Chen, [Flow in Games](https://khoury.northeastern.edu/~lieber/courses/csu670/f08/materials/p31-chen-flow-in-games.pdf)), [MDA](https://users.cs.northwestern.edu/~hunicke/MDA.pdf).
- Boss: mọi đòn có lấy đà đọc được; pha sau lật ngược điều đã dạy; thắng có thưởng cảm xúc ([nguồn](https://choostgames.com/blog/what-makes-a-good-boss-fight/)).
- Game feel: hitstop, loé trắng, giật lùi, rung khung giảm dần ([Juice it or lose it](https://www.youtube.com/watch?v=Fy0aCDmgnxg), [The Art of Screenshake](https://www.youtube.com/watch?v=AJdEqssNZ-U)). Đã làm: hitstop 50/90 ms, rung nhẹ mỗi đòn.
- Thể dục: Ring Fit (bài tập = đòn, quái có điểm yếu buộc đổi bài), Zombies, Run! (cốt truyện giữ chân). Đối thủ trực tiếp: Pushup RPG (camera đếm rep) — cần khác biệt bằng thần thoại, đồ hoạ, boss.
- Animation procedural kiểu David Rosen ([GDC](http://www.gdcvault.com/play/1020583/Animation-Bootcamp-An-Indie-Approach)): vài pose chính + nội suy spring.

**Việc nên làm tiếp (theo nghiên cứu):** boss sư tử 2–3 pha; điều chỉnh độ khó động
khi người chơi hụt mục tiêu; kiểm tra bóng đen/thang xám trong test xem trước;
1–2 câu thoại thần thoại trước mỗi màn; quái có "điểm yếu" theo biến thể hít đất.
