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
6. **Ngân sách hiệu năng (đổi 11/10/2026 tối, đo trên máy thật)**:
   - **Chính:** trên máy tầm trung (mốc tối thiểu: OPPO CPH2159 / Snapdragon 720G; iPhone: iPhone 11 / A13 trở lên), bản profile, trận đầy đủ: GPU tô (raster) **≤ 16 ms/khung trung bình, p90 ≤ 20 ms**; ghi lệnh vẽ (build) **≤ 5 ms**. Đo bằng `lib/dev/perf_bench_main.dart` (`flutter build apk --profile -t lib/dev/perf_bench_main.dart`, đọc log `BENCH`; iOS: `flutter run --profile -t lib/dev/perf_bench_main.dart`).
   - **Lưới chặn hồi quy trên PC:** `test/art/perf_budget_test.dart`, ghi lệnh vẽ < 3 ms/khung — chỉ bắt chậm đi rõ rệt, không thay cho đo máy thật.
   - Lý do đổi: đo trên máy thật cho thấy nút cổ chai là GPU tô hình (38,6 ms/khung khi lớp tĩnh còn là vector), trong khi test PC chỉ đo bước ghi lệnh.
   - Cách giữ ngân sách: phần tĩnh → `RasterLayer` (chụp thành ảnh một lần); tránh `saveLayer` toàn màn hình và chế độ trộn `multiply/softLight/screen` mỗi khung; không `Path.combine` mỗi khung.

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

## 6. Chuyển động, shader, âm thanh (12/10/2026 chiều)

Hướng nâng cấp sau khi thêm chi tiết tĩnh không còn đáng (người chơi nhìn
máy cách 50–80 cm): **chuyển động đọc được từ xa tốt hơn chi tiết**.

**Chuẩn boss (mọi boss mới phải có, dùng chung qua `BossArt`/sân khấu):**
1. Đòn 3 pha theo `AttackPose` (`lib/art/motion.dart`): lấy đà 0–0,5 (≥ 0,6 s
   với đòn 1,2 s) → ra đòn 0,5–0,65 → thu về; chạm người chơi ở mốc 0,55.
   Hình đặc trưng của đòn (hơi băng, sóng…) chỉ hiện từ pha ra đòn; pha lấy
   đà chỉ là dáng báo trước. Boss tự diễn đòn (sư tử) đặt `ownsAttackMotion`.
2. Thở + ngả/lao thân + nảy khi trúng đòn: `BossBodyMotion` (lò xo), tự áp
   cho mọi boss quanh `bodyAnchor`. Không dùng `MoveByEffect` cứng cho boss.
3. Sương Trì Trệ (shader) sát đất, tan theo máu boss: `mistColor`, `mistAmount`.
4. Pha cuối (máu < 40%): một khoảnh khắc chuyển pha (gầm, phồng, rung, loé
   đỏ) + viền đỏ đập nhịp tim; `rageColor`.
5. Âm `soundKey`: `boss_<key>_tell.wav` (báo đòn — người chơi nhìn sàn phải
   nghe được) và `boss_<key>_hit.wav`; tạo bằng `tool/gen_boss_sounds.py`.

**Shader (`lib/art/stage_shaders.dart`, `shaders/*.frag`):**
- Luôn vẽ vào ảnh nhỏ cố định (`ShaderLayer`, ~200×60–130) rồi phóng lên sân
  khấu, cập nhật ~30 lần/giây. Lý do: toạ độ `FlutterFragCoord` không phụ
  thuộc camera/saveLayer, và GPU chỉ tô vài chục nghìn điểm ảnh.
- Hiệu ứng mềm (sương, cực quang, vân nước) hợp độ phân giải thấp; không dùng
  cách này cho nét sắc.
- Phải có đường lui: `ShaderLayer.ready == false` thì vẽ bản vector hoặc bỏ qua.
- Không chờ lại `Future` nạp shader của lần vào trận trước (test treo / màn đen).
- Không chép shader Shadertoy (giấy phép mặc định CC BY-NC-SA); tự viết.

**Chuyển động trên nhân vật:** nhân vật được chụp ảnh theo tư thế làm tròn,
nên chuyển động phụ (đuôi băng, tóc) vẽ riêng sẽ phá bộ đệm. Chỉ áp biến đổi
toàn thân (lò xo giật lùi khi bị đòn) lên ảnh chụp sẵn.

## 7. Chuyển sang Blender, phong cách fantasy realism (13/10/2026)

Quyết định: đồ hoạ boss dựng 3D trong Blender, render thành sprite cho sân
khấu Flame ("cách 1": game Flutter giữ nguyên). Phong cách fantasy realism
(lông/vảy/kim loại/nước thật, ánh sáng điện ảnh), bỏ cartoon vector có viền.

- Script: `tool/blender/boss_kit.py` (dùng chung) + mỗi boss một file
  (`lion_nemea.py`, `fafnir_boss.py`, `orochi_boss.py`, `thuy_tinh_boss.py`).
  Quái chương 1: `hoplite.py` (lính đá, `--spartoi`), `stymphalia.py` (chim
  Stymphalia: lông thân xếp ngói rải trên lưới, cánh `bird_kit.py` từng phiến
  lông có sống lông), `harpy.py` (MPFB bỏ tay/chân + thân chim), `boar.py`,
  `hydra.py` (biến thể theo số đầu còn sống). Nhân vật: `hero.py` (`--female`).
- **Sprite vào game**: chạy script không có `--still` → `sprite_kit.py` render
  các chuỗi (`idle` lặp, `attack` theo tiến độ đòn 0–1, `rise`, `defeat`…),
  cắt sát, xếp vào trang 2048×2048 → `assets/sprites/<tên>_<trang>.png` + json
  (toạ độ khung theo đơn vị sân khấu quanh điểm neo). Flutter đọc bằng
  `lib/art/sprite_atlas.dart`, hoà hai khung kề nhau cho mượt; chưa nạp xong
  thì vẽ bản vector. Quái chương 1 đã nối trong `nemea_monster_art.dart`.
- Ngân sách: ~3 px/đơn vị sân khấu (máy ~6 px/đơn vị nên ảnh hơi mềm), 6 quái
  chương 1 = 22 MB PNG, ~11 trang 2048² (~180 MB nếu giải nén hết cùng lúc —
  mỗi màn chỉ nạp 1–2 quái). Chưa đo trên máy thật.
  Chạy `bash tool/blender/render.sh <tên> --still`. File mở bằng Blender để
  chỉnh tay: `art_src/blender/*.blend`.
- Toạ độ viết theo đơn vị sân khấu 400×260, gốc ở chân boss; tư thế theo
  `AttackPose` (lấy đà 0–0,5, ra đòn 0,5–0,65) để khớp nhịp đòn của game.
- Bẫy Blender 5.2: sợi (lông, tóc) do geometry nodes sinh trên object lưới
  KHÔNG render — đặt trên object Curves riêng (`with_fur`).
- Giới hạn đã thấy: khối ghép từ ellipsoid/metaball cho rồng, rắn, thần nước
  ổn; thú có lông (sư tử) và mặt người chưa đạt tả thực — cần mô hình nặn.

### Đêm 13–14/10: chương 1 đồng bộ một phong cách

Ảnh xem trước cho thấy quái Blender đứng trên phông vector cartoon và cạnh
nhân vật vector: lệch phong cách rõ. Hướng xử lý: dựng nốt phông, boss, nhân
vật bằng Blender.

- **Phông Thung lũng Nemea** (`tool/blender/nemea_valley.py`): cảnh 3D thật
  (đất cỏ khô, vách đá vôi xếp tầng có hang sư tử, ô liu già lá thật rải bằng
  geometry nodes, rừng ô liu trên đồi, đền Doric, núi xa trong sương). Máy
  quay phối cảnh khớp sân khấu: mặt phẳng hành động ở độ sâu 0, mặt đất tại
  y = 220, ~2 cm/đơn vị. Render THEO TẦNG (`sky`, `far`, `mid`, `near`, `fg`)
  → `assets/backdrops/nemea_<tầng>.webp`, rộng thêm 24 đơn vị mỗi bên cho
  camera trôi; sân khấu giữ parallax và lớp bụi Trì Trệ (bộ lọc màu từng tầng,
  chỉ còn màn sương vẽ thêm — mạng nhện/đống bụi khớp hình vector nên bỏ).
  Phối cảnh không khí làm trong vật liệu (trộn màu sương theo khoảng cách tới
  máy quay), không dùng volume.
  - Bài học: boolean khoét hang trên lưới voxel gồ ghề làm mất cả vách → dựng
    vòm bằng khối quanh miệng hang. Vách đá vôi ghép từ HỘP xoay lệch rồi làm
    gồ ghề (ghép ellipsoid ra khối tròn như bột nhào). Lưới nứt Voronoi trên
    đá trông như bùn khô — bỏ.
- **Boss Sư tử Nemea** (`lion_nemea.py`) chuyển sang `sprite_kit.export_sprites`
  (atlas WebP như quái), sân khấu vẽ bằng `paintLionSprite` (lion_art.dart) và
  giữ phần đọc nhịp: bụi cào đất, rung gầm gừ, vệt vuốt, sóng gầm, khiên da
  loé khi bị chặn, Trì Trệ rời xác. Đầu làm lại theo tỉ lệ sư tử thật (mõm dài
  vuông, mắt nhỏ đồng tử tròn, mũi da chữ T), bờm hai lớp ôm mặt, bóng đổ thật.
- **Nhân vật** (`hero.py`, chế độ không `--still`): sprite TÁCH LỚP để giữ tuỳ
  biến của màn tạo nhân vật (2 giới × 6 màu da × 6 màu tóc × 5 kiểu tóc) mà
  không render mọi tổ hợp: `hero_<giới>_skin` render da trắng trung tính,
  Flutter nhân màu da (`BlendMode.modulate`); `hero_<giới>_cloth` giữ màu, có
  bóng đổ; `hero_<giới>_hair_<kiểu>` render xám, nhân màu tóc. Lớp khác chỉ
  holdout (che khuất đúng, không hiện). Chuỗi: `plank`/`knees` theo góc khuỷu
  178° → 70°, `stand`, `victory`. Flutter: `lib/art/hero_sprite.dart`.
  Áo da Sư tử Nemea là lớp `hero_<giới>_pelt` (tấm da lông phủ lưng + sườn,
  cổ áo bờm, hai chân trước buộc ngực), vẽ đè sau tóc. Chưa có lớp Blender
  cho khiên, kiếm và lớp băng giá → khi đó vẽ bản vector. Mũ đầu sư tử dựng
  bằng ellipsoid trông như đồ chơi trên đầu → bỏ, cần mô hình nặn.
  Ngân sách: da + áo đóng lại ×0,85 (1 trang 2048² mỗi lớp), tóc 1 dải trang
  nhỏ → mỗi trận ~3 trang cho nhân vật.
- **Bản đồ Thung lũng Nemea** (`nemea_map.py` → `assets/backdrops/nemea_map.webp`):
  sa bàn nhìn chéo 40°, máy quay trực giao; toạ độ bản đồ 400×300 quy ra mặt
  đất bằng tia chiếu (`ground_at`), cây rải tránh đường mòn/sông theo toạ độ
  ẢNH. Vật cao (cao nguyên) bị đẩy lên trên ảnh theo độ cao → đặt vật theo
  chân, không nâng nền. Đền trên bản đồ là đền đổ mái (nhìn từ trên chỉ thấy
  mái đỏ). Flutter vẽ đường mòn, 10 điểm màn, nước lấp lánh đè lên.
- **Hercules** (`hercules.py` → atlas `hercules`): dáng lực sĩ bằng target
  chi tiết của MPFB (`make_human(details=…)` áp TRƯỚC khi gắn xương: lưng
  chữ V, vai, ngực, lưng xô, bắp tay–cẳng tay, cổ, đùi, hàm vuông) — chỉ
  macro "cơ bắp" thì ra người tập gym thường. Cởi trần (exomis chỉ giữ váy),
  râu quai nón phủ cằm–hàm (chọn đỉnh theo nửa trước đầu + cổ, không theo gốc
  xương đầu — gốc nằm trên cằm), nguyệt quế lá to, bỏ băng đầu đỏ của người
  chơi. Đứng ¾ (`FACING` 52°) để thấy mặt và ngực; tay phải (phía máy quay)
  tì đầu cán chuỳ chống đất, tay trái (phía xa) giơ về phía người chơi khi
  nói — tay phía gần giơ hướng nào cũng đi ngang mặt. `talk` 7 khung; cảnh
  mở đầu làm mượt mức giơ tay và giữ suốt đoạn thoại, chỉ nhấp nhẹ khi chữ
  đang hiện (hoà hai khung xa nhau ra bóng ma hai cánh tay). Chân dung khung
  thoại cắt từ sprite (`paintHerculesSpritePortrait`).
- Công cụ: `tool/repack_sprites.py` đóng lại atlas từ khung đã render (cắt
  theo thân đục, thu nhỏ) không cần chạy Blender; `hero.py --only pelt,...`
  chỉ render lớp còn thiếu.
- **Áo da sư tử bản nữ** (`hero_female_pelt`) đã render đủ 21 khung như bản
  nam → nhân vật nữ khoác áo bằng sprite, không còn lùi về vector.
- **Ảnh chụp sẵn cho màn ngoài trận** (`test/art/art_bake_test.dart`, chạy
  `ART_BAKE=1 flutter test test/art/art_bake_test.dart` rồi
  `python tool/sprites_webp.py --portraits` / `--banner`): màn chọn màn và
  trang chủ không nạp atlas 2048² chỉ để vẽ hình tĩnh, mà dùng ảnh vẽ từ chính
  sprite + phông Blender, cùng độ bão hoà sân khấu.
  - Chân dung tròn 256 px cho 10 quái chương 1 → `assets/portraits/<id>.webp`
    (~140 KB tổng). Khung riêng cho sprite (`framing` trong test, đo trên
    `build/portraits/_stage_<id>.png` có lưới 20 đơn vị); bụi Trì Trệ lắng ở
    mức máu 25 %. `BossPortrait.baked` là tập quái có ảnh; quái khác vẫn vẽ
    vector.
  - Khung trang chủ (`lib/art/home_banner_art.dart`): cảnh có sư tử hai bản
    (phủ bụi / thung lũng đã giải phóng) + từng lớp nhân vật tư thế đứng (da,
    áo, 5 kiểu tóc, áo da × nam/nữ), da và tóc nhân màu lúc vẽ → ~380 KB.
  - Render lại sprite thì chạy lại bước chụp; test kiểm tra
    `assets/portraits` khớp `BossPortrait.baked`.
- Chương 1 không còn hình vector khi đã nạp tài nguyên Blender (vector chỉ
  là bản dự phòng lúc chưa nạp). Khiên/kiếm/băng giá trên nhân vật thuộc kỳ
  công sau.

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

## 8. Thử phong cách "painted" kiểu Rise of Kingdoms (14/10/2026, đang dở)

Mục tiêu: học cách làm đồ hoạ của RoK (3D chiếu sáng mềm, texture như vẽ tay,
màu tươi, hình khối lớn, tỉ lệ anh hùng phóng đại) — không dùng tài nguyên
của họ. Tượng fan RoK trên Yeggi (STL in 3D) chỉ để tham khảo dáng: không có
màu/texture/xương, và vướng bản quyền Lilith + người nặn → không đưa vào game.

Công cụ (`tool/blender/style_kit.py`, `style_test.py`,
`tool/style_test_compose.py`): dựng một cảnh Nemea + sư tử + nhân vật, render
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
`python tool/sprites_webp.py --portraits` / `--banner`). Bụi Trì Trệ giữ
nguyên nên khung trang chủ trước khi giải phóng vẫn xám.

## 9. Công tắc đồ hoạ 2.5D ↔ 3D (14/10/2026)

Trang chủ có mục "Đồ hoạ": **2.5D** = bản vector vẽ bằng code (`lib/art/`,
phông nhiều lớp parallax), **3D** = tài nguyên Blender (mặc định). Lưu bằng
SharedPreferences (`art_mode_v1`), nạp trong `main()`.

Cách làm (`lib/art/art_mode.dart`): không rẽ nhánh ở từng hình — các cổng
nạp tài nguyên Blender (`SpriteAtlas.get`, `NemeaBackdrop.ready`,
`NemeaMapImage.image`, `HomeBannerArt.ready`, chân dung chụp sẵn trong
`BossPortrait`) coi như chưa có ảnh khi ở 2.5D, nên mọi hình tự rơi về bản
vector như lúc thiếu tài nguyên. Hệ quả: code vector KHÔNG còn là tạm — phải
giữ chạy được; hình mới cần có cả bản vector, hoặc chấp nhận 2.5D vẽ thiếu.
Test: `test/art/art_mode_test.dart`.

## 10. Bộ công cụ Blender cho boss hình người chương Nhật (14/10/2026)

Tìm trên mạng xem có gì bổ sung được (kết quả và quyết định):

| Công cụ | Dùng? | Ghi chú |
|---|---|---|
| Gói tài nguyên hệ thống MakeHuman (CC0, 267 MB) | ✅ đã cài | Mắt, lông mày, lông mi, răng, lưỡi, tóc, da. Phải giải nén vào `%APPDATA%/Blender Foundation/Blender/5.2/extensions/.user/blender_org/mpfb/data` (thư mục MPFB đọc, KHÔNG phải `.../5.2/mpfb/data`). `human_kit.add_face_parts`. |
| Bộ node tóc có sẵn của Blender (`datafiles/assets/nodes/procedural_hair_node_assets.blend`) | ✅ | Duplicate / Clump / Frizz / Curl / Braid / Set Hair Curve Profile — `hair_kit.strand_locks` (tóc tỉa theo lọn, mỗi lọn một guide). Addon tóc trả phí (Stylized Hair Pro, Medusa Nodes) không cần. |
| blender-mcp (ahujasid) | chưa | Nối Claude với Blender đang mở (xem cảnh trực tiếp, Poly Haven, Hyper3D). Có ích khi làm tay trong Blender; quy trình script `render.sh` hiện tại không cần. |
| Poly Haven / ambientCG (CC0) | khi cần | Texture/HDRI tả thực; phong cách painted đang tự vẽ bằng node nên chưa dùng. |
| Ảnh → 3D (TRELLIS.2 MIT, Hunyuan3D, TripoSR) | ❌ | TRELLIS cần ≥16 GB VRAM (máy: RTX 3050 4 GB). Hunyuan3D: giấy phép cộng đồng loại EU/UK/Hàn. Dựng từ tranh tham khảo có bản quyền cũng là tác phẩm phái sinh. |

Thư viện mới:
- `tool/blender/hair_kit.py`: tóc theo lọn (`strand_locks` sợi thật, `ribbon_locks` lọn khối), `hair_material`.
- `tool/blender/japan_kit.py`: da tô màu/xăm (`painted_skin`, có son môi), vải lụa vân mây (`silk_material`), vải hoa tròn (`kamon_material`), lửa ma (`flame_material`, `flame`), áo ôm thân (`garment`), tay áo rộng (`sleeve_bag`), hakama, giáp tay (`limb_band`), sừng có gờ, chuỗi hạt, thừng shimenawa, chữ Hán nổi (font Yu Gothic — máy không có Mincho), vuốt, quạt lông, đắp khối (`inflate` — bụng phệ), ghép khối elip theo mét (`blob`), dáng đứng ¾ (`StandPoser`).

Boss dựng theo tranh người dùng chọn (ảnh duyệt `--still`, CHƯA xuất sprite):

| Boss | Script | Ảnh |
|---|---|---|
| Yamata no Orochi (làm lại: rắn thật xanh xám, bụng hồng, mắt vàng, vàng lá) | `orochi_boss.py` | `build/blender/orochi/` |
| Shuten-dōji (oni đỏ vác kanabō) | `oni_boss.py` | `build/blender/oni/` |
| Sutoku hoá đại tengu | `tengu_boss.py` | `build/blender/tengu/` |
| Susanoo cuồng nộ (lửa ma xanh, hào quang) | `susanoo_boss.py` | `build/blender/susanoo/` |
| Tamamo-no-Mae, dạng cáo / dạng người | `tamamo_boss.py --form fox|human` | `build/blender/tamamo/` |

Việc tiếp: người dùng duyệt ảnh → sửa → xuất atlas sprite (`sprite_kit.export_sprites`, chuỗi idle/windup/strike/hurt/defeat) → BossArt Flutter + bản vector 2.5D (mục 9). Đã sửa (14/10): cổ áo tengu dựng bằng `flat_band` bám mặt ngoài áo theo từng tầng `body_ring` (ống dẹt Bézier cắt xuyên ngực và xoắn khi gần thẳng đứng); mày Tamamo dạng người là một nét `tapered_world` — `helper-*-eye` là tâm nhãn cầu nên phải đẩy ra trước ~0,024·H mới qua gờ mày.
