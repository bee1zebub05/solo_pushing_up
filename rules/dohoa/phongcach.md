# Phong cách đồ hoạ (chung cho mọi phòng)

Phòng nào cũng đọc file này trước: hướng phong cách, nguyên tắc đọc hình,
tranh tham khảo và giấy phép.

**Quy tắc chính**
- Đọc được ở cỡ điện thoại đặt trên sàn cách 0,5–1 m: dáng tổng thể và chuyển
  động quan trọng hơn chi tiết.
- Một nguồn sáng thống nhất (trên bên trái); boss có màu chủ đạo, mắt/đòn phát sáng.
- Hình của boss phải nói lên cơ chế; mỗi kiểu nguy hiểm một màu + hình cố định.
- Hướng hiện tại: Blender fantasy realism + chất "painted" kiểu RoK lấy từ
  tài nguyên (bảng màu, khối), KHÔNG từ bộ lọc và KHÔNG bằng cách hạ bụi Trì Trệ.
- Không mua/chép asset; tranh tham khảo phải dùng thương mại được, ghi nguồn +
  giấy phép vào bảng tranh tham khảo bên dưới.

Mục tiêu: nhân vật và boss vẽ hoàn toàn bằng code (`lib/art/`), không mua asset, đủ đẹp để lên store. Chỉ học **kỹ thuật** từ các game đi trước, không sao chép hình.

## Quan sát từ tham khảo (cũ: mục 1)

Tham khảo chính là dòng Kingdom Rush (Ironhide): phong cách cartoon nhiều chi tiết, chú trọng đọc được hình ở kích thước nhỏ.

| Đặc điểm | Ghi chú | Áp dụng cho mình |
|---|---|---|
| Tỉ lệ "chunky" | Đầu to, cẳng tay và bàn tay to, bàn chân/giày to, chân ngắn | Cẳng tay to hơn bắp tay, nắm đấm to, sandal to hơn |
| Viền đậm, không đều | Viền dày ở phía khuất sáng, mỏng phía có sáng | Thêm một lớp viền lệch về phía bóng |
| Đổ bóng 3 tông | Màu gốc, mảng bóng sắc cạnh, vệt sáng; chấm bóng loáng nhỏ | Đã có bóng và viền sáng; thêm chấm bóng loáng trên tóc, kim loại, má |
| Biểu cảm mạnh | Nghiến răng, mày chau, mắt nheo | Mặt đổi theo độ gắng sức của rep |
| Bóng tiếp đất | Ellipse tối dưới chân giúp nhân vật "đứng" trên nền | Thêm bóng dưới người khi đứng và khi chống đẩy |
| Boss | To hơn hẳn nhân vật, màu tương phản mạnh (xanh ngọc, tím, cam), mắt phát sáng, dáng gai góc, hiệu ứng phát sáng | Mỗi boss một màu chủ đạo, mắt và đòn có ánh phát sáng |

## Nguyên tắc rút ra (cũ: mục 2)

1. **Đọc được ở kích thước điện thoại để trên sàn cách 1 m**: dáng tổng thể quan trọng hơn chi tiết.
2. **Ánh sáng thống nhất**: nguồn sáng trên bên trái cho mọi nhân vật, boss, phông nền (`VectorStyle.lightWorld`).
3. **Viền**: dày ở phía bóng, mỏng ở phía sáng. Đường bên trong (nếp vải, cơ) mỏng hơn viền ngoài.
4. **Boss: hình phải nói lên cơ chế** (đọc được trước khi bị đánh):
   - Thuỷ Tinh: nước dâng thật trên sân khấu.
   - Orochi: thấy rõ đầu bị chém và đầu mọc lại.
   - Fafnir: băng phủ lên khi người chơi nghỉ lâu.
5. **Mỗi kiểu nguy hiểm một màu và hình cố định** trong suốt trận, để người chơi không phải học lại.

## Nguồn (cũ: mục 3)

- [Kingdom Rush (Wikipedia)](https://en.wikipedia.org/wiki/Kingdom_Rush): phong cách cartoon chi tiết, art director Gonzalo Sande.
- [Ironhide: "As long as our fans love Kingdom Rush…"](https://gameworldobserver.com/2018/12/06/ironhide-long-fans-love-kingdom-rush-will-continue-working): giữ phong cách cartoon, thêm chi tiết và hoạt hình.
- [Blender Studio: cartoon character shading](https://studio.blender.org/blog/cartoon-character-shading-with-geometry-nodes): viền là yếu tố chính giúp nhân vật dễ đọc; viền sáng theo góc nhấn dáng.
- [Tuts+: vector anime character, coloring](https://design.tutsplus.com/tutorials/creating-a-vector-anime-character-in-adobe-photoshop-part-2-coloring--vector-8797): cel shading là mảng bóng sắc cạnh, hợp với vector.
- [Enemy telegraph shape language (2026)](https://gamineai.com/blog/enemy-telegraph-shape-language-top-down-boss-fights-fast-visual-consistency-audit-2026) và [Designing for difficulty readability](https://gamedeveloper.com/blogs/designing-for-difficulty-readability-in-arpgs): dáng boss báo trước kiểu tấn công; dấu hiệu nhất quán.
- Ảnh tham khảo Kingdom Rush xem qua Google Images (chỉ để học, không lưu, không dùng lại).

## Nâng cấp sáng 11/10/2026: bớt "trẻ con", theo giáo trình mỹ thuật (cũ: mục 4)

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

## Nghiên cứu 11/10 chiều: skill cho agent, lý thuyết thiết kế game (cũ: mục 5)

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

## Chuyển sang Blender, fantasy realism (cũ: mục 7)

Quyết định: đồ hoạ boss dựng 3D trong Blender, render thành sprite cho sân
khấu Flame ("cách 1": game Flutter giữ nguyên). Phong cách fantasy realism
(lông/vảy/kim loại/nước thật, ánh sáng điện ảnh), bỏ cartoon vector có viền.
- Giới hạn đã thấy: khối ghép từ ellipsoid/metaball cho rồng, rắn, thần nước
  ổn; thú có lông (sư tử) và mặt người chưa đạt tả thực — cần mô hình nặn.

## Tranh tham khảo cho boss (cũ: mục 7)

**Tranh tham khảo** (chỉ học hình tượng, không chép; đều dùng thương mại được):

| Boss | Tranh | Giấy phép |
|---|---|---|
| Fafnir | Delitz, "Siegfried and the dragon" (Victrola book of the opera, 1917) — [Commons](https://commons.wikimedia.org/wiki/File:Wagner_-_Siegfried_-_Siegfried_and_the_dragon_-_From_the_painting_by_Delitz_-_The_Victrola_book_of_the_opera.jpg) | No restrictions |
| Fafnir | Arthur Rackham, Siegfried and the Twilight of the Gods (1911) — [Ring45](https://commons.wikimedia.org/wiki/File:Ring45.jpg), [p162](https://commons.wikimedia.org/wiki/File:Siegfried_and_the_Twilight_of_the_Gods_p_162.jpg) | Public domain |
| Orochi | Tsukioka Yoshitoshi (1887) — [Commons](https://commons.wikimedia.org/wiki/File:Susanoo-no-Mikoto-slays-Yamata-no-Orochi-in-Izumo-By-Tsukioka-Yoshitoshi.png) | Public domain |
| Orochi | Tranh bộ ba khoảng 1870 — [Commons](https://commons.wikimedia.org/wiki/File:YamataNoOrochi.jpg); Torii Kiyomasu II (1748) — [Commons](https://commons.wikimedia.org/wiki/File:Susano-o_no_Mikoto_Killing_the_Eight-headed_Dragon.jpg) | Public domain; CC0 |
| Thuỷ Tinh | Tranh thờ Tản Viên Sơn Thánh, sách Nhất thành khả cách chân kinh — [Commons](https://commons.wikimedia.org/wiki/File:Tranh_v%E1%BA%BD_T%E1%BA%A3n_Vi%C3%AAn_S%C6%A1n_Th%C3%A1nh_trong_quy%E1%BB%83n_Nh%E1%BA%A5t_th%C3%A0nh_kh%E1%BA%A3_c%C3%A1ch_ch%C3%A2n_kinh_%E4%B8%80%E8%AA%A0%E5%8F%AF%E6%A0%BC%E7%9C%9F%E7%B6%93.jpg) | Public domain |

Không dùng: ảnh chụp đá khắc Hylestad (CC BY-SA, buộc chia sẻ lại cùng giấy
phép), tranh Rackham 1924 trên Heritage Images (bản quyền thương mại), mẫu
sư tử RenderHub "editorial only".

## Thử phong cách "painted" kiểu Rise of Kingdoms (14/10/2026, đang dở) (cũ: mục 8)

Mục tiêu: học cách làm đồ hoạ của RoK (3D chiếu sáng mềm, texture như vẽ tay,
màu tươi, hình khối lớn, tỉ lệ anh hùng phóng đại) — không dùng tài nguyên
của họ. Tượng fan RoK trên Yeggi (STL in 3D) chỉ để tham khảo dáng: không có
màu/texture/xương, và vướng bản quyền Lilith + người nặn → không đưa vào game.

Công cụ (`tool/blender/kits/style_kit.py`, `style_test.py`,
`tool/render/style_test_compose.py`): dựng một cảnh Nemea + sư tử + nhân vật, render
hai bản (hiện tại / `--painted`) bằng đúng máy quay xuất sprite, ghép như sân
khấu → `build/style/compare.png`.

Kết quả 3 lần thử: lượt chỉnh TOÀN CỤC (bão hoà, AgX Punchy, chất liệu mờ,
bớt gồ ghề, lông to thưa, "vẽ sẵn ánh sáng" theo hướng mặt + độ lồi, đầu/tay
to hơn 14–18 %) chỉ đổi rất nhẹ — chưa ra chất RoK. Standard + tăng phơi
sáng thì cháy cam; lọc Kuwahara hộp vuông ra ô vỡ hạt. Phát hiện: dưới nắng
sạch, tài nguyên hiện tại đã khá gần RoK; trong game xám tím là do bụi Trì
Trệ + sương phủ.

Bước tiếp (cần sửa từng mô hình, không phải bộ lọc):
1. Bảng màu: cỏ xanh tươi thay đất khô, bớt bụi Trì Trệ trong game (hoặc
   chỉ phủ nhẹ) — thử nhanh nhất, tác động lớn nhất.
2. Hình khối: đá/vách mặt lớn phẳng, bỏ nhiễu lổn nhổn; tán cây khối tròn
   (đã có).
3. Nhân vật: phóng đại mạnh (vai, tay, đầu, trang phục to bản, viền màu
   đậm), texture vẽ tay cho áo/da.
4. Lông/tóc: khối tạc từng lọn thay sợi.

Bước 1 (14/10, phiên sau): `nemea_valley.LUSH` (style_test bật khi
`--painted`) đổi bảng màu sang đồng cỏ tươi: nền cỏ xanh vàng, đồi ô liu và
bách xanh đậm hơn, cỏ lông xanh; lối đất trụi chỉ ở lõi dải hành động (thuộc
tính `scar` ≥ 0,7, màu đất dịu `#A48C68`; ngưỡng 0,35 thì lối phủ gần hết tiền
cảnh và cam gắt vì bị bão hoà thêm). Đây là thay đổi ĐẦU TIÊN thấy rõ chất
RoK — xác nhận màu nền mới là đòn bẩy chính, không phải shader. Còn thiếu:
vách đá vẫn lổn nhổn (bước 2), nhân vật nhỏ và nhạt so với nền (bước 3).
Chưa đụng bụi Trì Trệ trong game (`NemeaBoss.maxDust = 0.85`): đó là cơ chế
"thung lũng sạch dần theo máu boss". Người dùng chốt (14/10): KHÔNG hạ
bụi Trì Trệ — giữ nguyên cơ chế; chất RoK phải đến từ tài nguyên, không từ
việc bớt bụi.

Áp dụng (14/10): `LUSH = True` mặc định; đã render lại phông trận, bản đồ chọn
màn (`nemea_map.py` lấy màu cỏ/đất/cây qua `nv.pal`), chụp lại chân dung và
khung trang chủ (`ART_BAKE=1 flutter test test/art/art_bake_test.dart` rồi
`python tool/render/sprites_webp.py --portraits` / `--banner`). Bụi Trì Trệ giữ
nguyên nên khung trang chủ trước khi giải phóng vẫn xám.
