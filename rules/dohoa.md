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

Oni bản 3 (14/10): mặt Hannya bằng target biểu cảm MPFB (`human_kit.target_path` nhận đường dẫn kiểu `expression/units/asian/mouth-open` — tên biểu cảm trùng giữa các chủng người); đắp cơ dọc xương bằng `japan_kit.muscle_bulge` + tô hõm cơ bằng AO cục bộ (`painted_skin(cavity=…)`); `--clay` bỏ hình xăm để soát khối. Dạng chân `StandPoser.place` quay quanh trục trước–sau của khung xương (trục Z cục bộ của đùi bị lệch làm chân bắt chéo); `StandPoser.palm` + `fist` cho tay nắm cán; `--grip` / `--grip-only` render ảnh soát tay, chân, thân. Gốc tóc bờm đặt theo bán kính sọ đo từ đỉnh nhóm `head` (bỏ HelperGeometry), không dùng mặt cầu cố định.

Đêm 14→15/10 (người dùng giao tự làm oni + Susanoo): bụng oni kiểu Gragas bằng `japan_kit.belly_ball` (chiếu đỉnh lên mặt elip theo tia từ tâm, hợp smooth-max — đẩy theo pháp tuyến `inflate` cho bụng nhọn); bờm mọc từ đỉnh nhóm `scalp`; `hair_kit.combed_material` (Wave của Blender tự nhân toạ độ ×20, scale chỉ 3–5); `hero_muscles(k)` dùng chung; `painted_skin(tattoo_attr=…)` giới hạn vùng xăm; `skin_snapper` dán mày lên mặt da; `flat_band` (đã chuyển vào japan_kit, có `widths`) cho tấm da hổ vắt vai + viền lông `strand_locks`; Susanoo: target biểu cảm `expression/units/caucasian/*`, nắm kiếm `fist`+`palm`, sét `lightning` (dời điểm giữa) — emission ánh màu cần strength ≈2, cao hơn bị cháy trắng. Cờ soát: oni `--belly --grip --clay`, Susanoo `--hand --clay`.

Oni bản 7 (15/10, theo nhận xét người dùng): `japan_kit.densify` gộp shape key MPFB rồi áp một bậc subsurf vào lưới gốc (75k đỉnh) — nếp nhăn/gân mảnh hơn khoảng cách đỉnh MPFB (~5–10 mm) không hiện; `weights_by_group` có nhớ đệm. `ridge` (gờ/rãnh dọc đường gấp khúc: gân xanh, nếp nhăn, sẹo, thớ cơ), `snap_rest`, `inflate(groups=…)` để khối ngực không lan sang nách (nâng tay sẽ kéo thành mẩu nhọn). `conform_outside` ép tấm da/vải bám mặt da SAU khi tạo dáng (tấm phải chia nhiều đỉnh theo bề ngang); vật dựng sau khi tạo dáng phải gắn xương theo `pose_bone.matrix` hiện tại, `parent_to_bone` tính theo dáng nghỉ. `painted_skin(paints=[(thuộc tính, màu)])` cho kumadori, đỏ rượu, sẹo, gan chân. Máy quay vừa tạo cần `view_layer.update()` trước khi đọc `matrix_world` (đồng tử nhắm nhầm lên trời). `human_kit.camera` đặt tâm ở mặt phẳng y = 0 — góc quay lớn dùng `look_at` trong oni_boss. Eo béo: bỏ `torso-muscle-dorsi-incr`, macro cơ 0,7 / mỡ 0,9, đắp mỡ sườn–lưng–bụng trên. Cờ mới: `--face`, `--checks`, `--quick`, `--dry` (+ biến `ONI_DEBUG`).

## 11. Bài học sau khi dựng oni (bản 3 → 9, 14–16/10/2026)

Oni mất ~7 vòng nhận xét. Phần lớn vòng sửa là lỗi có thể bắt trước khi đưa người dùng xem. Thứ tự làm và cách soát dưới đây áp cho mọi nhân vật hình người sau.

### Thứ tự dựng: khối trước, chi tiết sau
1. **Xin ảnh tham khảo dáng người ngay từ đầu** (cả nhìn nghiêng), không chỉ tranh phong cách. Oni chỉ đúng tỉ lệ béo phì sau khi người dùng gửi ảnh 5 dáng người gầy → béo.
2. **Chốt tỉ lệ khung (chiều dài chân, thân) trước khi đắp khối.** Rút ngắn chân cho "lùn bè" rồi đắp mỡ thì thân dưới thành cái chuông úp; người béo vẫn cần chân dài bình thường.
3. **Bóng (silhouette) ba hướng: trước, nghiêng, sau.** Người béo phì nhìn nghiêng: bụng trễ chờm qua cạp, mông là điểm nhô ra sau xa nhất, lưng chảy liền xuống mông, đùi trên dày gần bằng thân rồi thon về gối, hai đùi áp sát.
4. Rồi mới tới mặt, gân, vuốt, hiệu ứng.

### Soát thân trần dưới quần áo
- **Quần áo sao từ thân thừa hưởng mọi lỗi của thân.** Luôn render một ảnh ẩn quần áo (hakama, tạp dề…) trước khi chỉnh vải. Oni sửa hakama hai vòng mà bên trong vẫn là hông lép, đùi thon.
- Đắp mỡ quanh chi: dùng `japan_kit.limb_fat` (đẩy ra xa trục xương, khối tròn đều). `inflate` đẩy theo pháp tuyến dễ ra cục, chỉ hợp cho khối nhỏ (ngực, đệm gối). Vòng eo béo: đẩy toàn vòng ra xa trục thân (`WaistFill` trong `oni_boss.lower_fat`), không đắp từng cục.

### Vải và đồ dựng theo thân
- **Vải rộng (hakama, váy, áo choàng) dựng SAU khi tạo dáng, theo bao lồi:** `japan_kit.DrapedSkirt`. Vải rủ từ chỗ rộng nhất rồi buông thẳng, căng qua khe chân. Bản sao lưới thân + đẩy pháp tuyến (`hakama`, `garment`) chỉ hợp đồ ôm sát; với thân béo nó thành quần bó lộ từng khối.
- **Đồ gắn lên thân (khoá đai, phù hiệu, chữ thêu) phải soát lại mỗi khi khối thân đổi.** Bụng trễ xuống đã che mất khoá đai. Đặt chúng theo lớp ngoài cùng (mặt tạp dề, mặt quần) chứ không theo vòng thân gốc.
- Lưới tự dựng: kiểm tra pháp tuyến hướng ra ngoài. Ngược thì mép vải trông mờ như kính. Lụa nhiều sheen cũng loé trắng ở mép trên nền sáng; vải dày để sheen ≤ 0,2.
- Đồ dựng sau khi tạo dáng chỉ đúng cho dáng đó; sprite nhiều dáng phải dựng lại theo từng dáng.

### Dò điểm trên lưới
- **Dò ở dáng nghỉ, không ở dáng đã tạo** (vuốt chân lệch hai lần): trục xương sau khi tạo dáng không trùng hướng thật của bàn chân. Dò xong thì `parent_to_bone` (tính theo dáng nghỉ) là vật tự đi theo dáng.
- Hàng ngón chân/tay xếp chéo: trừ đường thẳng khớp qua mép trước rồi mới tìm cực đại (`toe_claws`). Chia bề ngang theo tỉ lệ cố định sẽ trượt khỏi ngón thật.
- Đọc lưới đã tạo dáng (`posed_points`): tắt tạm mọi modifier trừ Armature. MPFB có Mask ẩn lưới phụ, subsurf thì đổi số đỉnh.

### Hiệu ứng và phụ kiện nhỏ
- Lửa ma: quầng sáng opacity ≤ 0,1, nếu không thành quả bóng che mất lửa. Đuôi lửa cần thành phần hướng lên, vì đuôi theo tiếp tuyến quỹ đạo sẽ chĩa vào máy quay ở hai bên và bị ngắn lại. Bỏ ngọn nào rơi trước bụng/mặt nhìn từ máy quay.
- Tua, dây, lông: dựng đúng cấu trúc vật thật (dây treo → nút → chóp → đai → sợi), sợi đều nét và cắt bằng. Vuốt nhọn đầu là kiểu "kim".

### Quy trình nhanh
- Mỗi vòng thử dùng `--dry --quick` + biến `ONI_DEBUG` trỏ tới script soát (khoảng 1,5 phút) render đúng góc cần xem, ghép thành một ảnh lưới. Chỉ render đầy đủ (khoảng 9 phút) khi đã ưng.
- **Bộ ảnh soát cố định trước khi đưa người dùng xem:** toàn thân · nghiêng trần (ẩn quần áo) · nghiêng mặc đồ · sau lưng · cận bàn chân (trước + trên xuống) · cận mặt. Tự hỏi: bóng có giống tham khảo không, đồ gắn có bị che không, chỗ tiếp xúc (đai–thân, vải–chân, vuốt–ngón) có khớp không.
- Lỗi "Cannot change old file" / sót `.blend@` (file lớn vừa ghi bị Windows khoá tạm) đã sửa trong `boss_kit.save_blend` 16/10: lưu ra file tạm, tự đổi tên `@` có thử lại; không còn phải xoá tay.

### Bổ sung sau vòng soát cận (bản 10 → 10b, 16/10 tối — oni được duyệt)
Người dùng phóng to ảnh duyệt và thấy lỗi mà ảnh toàn thân che mất. Ba ảnh cắt cận của người dùng ra 6 lỗi.
- **Bộ soát phải có ảnh cận từng phụ kiện** ở cỡ người dùng hay phóng (khoảng 700 px/m): tay + vật cầm, khoá đai, chuỗi hạt/vòng cổ, mép da thú/vải, giáp tay. Kèm vài con số đo (khe giữa các hạt, bán kính da so với giáp). Số liệu bắt lỗi nhanh hơn nhìn ảnh.
- **Màu dưới AgX:** vật phát sáng mạnh hoặc nhiều lớp bán trong suốt chồng nhau (mặt trước + sau ống, nhiều lưỡi lửa) cộng sáng, AgX đẩy về trắng kem. Lửa dùng `japan_kit.fire_material`: ramp bão hoà, cường độ ≈ 1,4, đục ở lõi.
- **Tên thuộc tính lưới:** không đặt `heat`, `density`, `flame`, `temperature`, `color`, `velocity`. Cycles dành các tên này cho khói/lửa thể tích, shader đọc ra 0 mà không báo lỗi. Đặt có tiền tố (`flame_heat`). Nghi ngờ thì render thẳng thuộc tính ra màu Emission để kiểm.
- **Vật liệu tối màu trên nền đèn lam:** bóng gương phản trời/đèn viền lam thành xám nhựa hoặc tím. Vải tối dùng `silk_material(spec ≤ 0,25, sheen ≤ 0,06)`, sơn mài nhám ≥ 0,4. Mặt khuất của da đỏ chỉ có đèn viền lam rọi thì ra tím: đèn viền nhạt và vừa phải.
- **Đồ ôm chi (giáp, vòng tay) phải đo da:** đắp mỡ sau khi đặt bán kính cố định thì giáp chìm vào da, lộ lốm đốm. Dùng `limb_band(skin=(body, co), pad=…)`.
- **Phụ kiện nhỏ phải đọc được ở cỡ sprite và có chỗ bám:** khối cầu một màu đọc thành quả bom. Phải là mặt phẳng có nét khắc nổi tương phản (vàng/đen/phát sáng). Đồ treo cần quai/khuyên nối vào vật mang (khoá đai treo vào thừng), không đặt lơ lửng.
- **Chuỗi, dây, vật xếp hàng: xử lý cả đường, không xử lý từng phần tử** (`japan_kit.drape_chain`).
  - Đẩy từng hạt riêng lẻ thì chuỗi gãy khúc.
  - Làm mượt vị trí một vòng kín thì vòng co lại thành vòng siết. Chỉ làm mượt *độ đẩy* để giữ dáng võng.
  - Số hạt phải vừa chiều dài dây (26 hạt cần 1,6S trên vòng 1,0S nên hạt đè thành cục).
  - Mặt dây đặt theo hình học (điểm nhô trước nhất), không theo chỉ số.
- **Đẩy vật ra khỏi thân béo:** điểm lọt trong khối thịt thì "mặt gần nhất" có thể là dưới cằm, vật bị đẩy sai hướng. Tia bắn ngang từ ngoài vào thì lại trúng cơ vai. Chọn cách đẩy theo vị trí, và soát cả hai phía.
- **Bẫy kỹ thuật:**
  - `bmesh.from_mesh`/`from_object` trên thân MPFB đã tạo dáng (có shape key) làm Blender sập. Dựng BVH từ đỉnh/mặt (`BVHTree.FromPolygons`, xem `_surface_tree`).
  - Script `ONI_DEBUG` chạy bằng `exec` trong `main()`: generator/lambda không thấy biến cục bộ. Bọc code soát trong hàm và truyền `scene` vào.
- **Sửa một chỗ trong kit dùng chung thì soát các nhân vật khác dùng chỗ đó.** Lửa Susanoo vẫn dùng `flame_material` cũ, nhiều khả năng cũng bị kem.

## 12. Mô hình Tripo3D thay khối ghép (19/10/2026)

Sư tử Nemea làm lại từ mô hình Tripo3D (`art_src/tripo/nemea_lion.glb`,
ảnh → 3D, chọn Clean Topology, đã tô texture) thay khối ellipsoid + lông sợi
của `lion_nemea.py`. Script: `tool/blender/lion_tripo.py`.

- **Ảnh đầu vào cho Tripo**: nhìn ngang, quay trái, nền trơn, dáng trung
  tính (4 chân tách rời, miệng ngậm). Miệng há trong ảnh bị đúc vào mô hình.
- **Đặt vào cảnh**: giữ mũi đúng chỗ bản cũ và bờm cao bằng bản cũ (đo trên
  ảnh `--still`), cùng máy quay/đèn/điểm neo → sân khấu không phải đổi.
- **Xương**: đọc khớp trên ảnh nhìn ngang có lưới toạ độ (đơn vị vẽ), dùng
  `Rig` (xương phẳng, trọng số theo khoảng cách), lọc chân gần/xa theo chiều
  sâu. Bắt buộc làm mượt trọng số (`smooth_weights`): lọn bờm rời bị chia
  cho xương chân và thân thì kéo thành sợi khi cử động.
- **Bẫy GLB**: đỉnh bị tách ở mọi đường nối UV. Tìm mảnh rời / làm mượt phải
  hàn đỉnh trùng vị trí trước, nếu không lưới bị xé thành mảnh.
- Render nhanh hơn nhiều (~10 s/khung so với ~2 phút có lông sợi); 49 khung,
  thu nhỏ 0,8 → 4 trang (trang cuối 2048×512).
- Kiểm tra giấy phép gói Tripo trước khi phát hành; vẫn coi đầu ra là bản
  thô cần chỉnh (rules: tránh art "rõ là AI").
- Phần dùng chung (nạp, đặt tỉ lệ, làm mượt trọng số): `tool/blender/tripo_kit.py`.
  Quái mới: chép `boar_tripo.py`, đọc khớp trên ảnh nhìn ngang có lưới, giữ
  máy quay/điểm neo/tên atlas của script cũ để sân khấu không phải đổi.
- Lợn rừng (`boar_tripo.py`): lông gáy cao hơn bản cũ → `GROW = 0.9` cho
  đỉnh lông không chạm mép khung render.
- **Dáng người** (lính đá, `stone_tripo.py`): Tripo dựng quay mặt về -Y →
  `import_tripo_upright(..., rot_z=-90)`, chuẩn theo chiều cao, gốc giữa hai
  bàn chân. Vũ khí/khiên là mảnh lưới riêng: gắn vào **xương riêng**
  (`pin_to_bone`), đặt vào bàn tay mỗi khung — giáo dựng đứng lúc đứng, chĩa
  ngang lúc đâm mà không phải bẻ cẳng tay. Mảnh nhỏ (khoá, quai) dùng
  `follow_nearest` (chép trọng số đỉnh thân gần nhất) sau khi làm mượt, nếu
  không sẽ tách khỏi thân khi cử động. Khuỷu tay IK chọn phía chĩa xuống/ra sau.
- Dấu hiệu báo đòn vẽ trong bản vector (mũi tên lợn rừng, sao mũi giáo) phải
  vẽ lại cho nhánh sprite: tính vị trí từ chính công thức pose() trong Blender.
- **Biên đạo theo khoá (21/10, lính đá):** `pose()` nội suy thẳng giữa ba thế
  (lấy đà/ra đòn/thu) trông cứng và "vung tay". Thay bằng `tool/blender/choreo_kit.py`
  (bản gọn của biên đạo nhánh chương Nhật): khoá thưa quanh dáng chờ, nội suy
  cubic đơn điệu, `lag` từng kênh (hông → thân → khiên → tay → giáo → đầu),
  khoá lặp lại = giữ thế (nén trước cú đâm, khựng ở đỉnh đòn); bước = nhấc
  chân; 20 khung đòn chia đều + `SpriteAtlas.draw(snap:)` quanh pha ra đòn để
  không hiện hai cây giáo chồng nhau. Vị trí mũi giáo từng khung ghi vào atlas
  (`spearTip`) cho sao báo đòn, không chép số tay.
  Cùng ngày làm lại theo cách này cả lợn rừng, Harpy, Hydra, sư tử (mỗi script
  có `READY` + `Move` cho từng động tác + `idle_channels(t)` vòng lặp liền).
  Track ghi vào atlas: `headTrack` (Harpy → túi vàng, sóng rít), `headAttack`
  / `pawAttack` / `headPounce` (sư tử → sóng gầm, vệt vuốt, khiên). Giữ số
  trang atlas như cũ bằng `repack_sprites.py --scale` (0,7–0,85).
  Nhịp riêng: Harpy đập cánh xuống nhanh, nâng chậm (pha cong
  `arg = ph + 0,5 sin ph`); Hydra cổ uốn theo sóng (pha trễ theo vị trí trên
  cổ) + võng chữ S khi thu thế; lợn rừng lấy đà theo `charge` của cơ chế
  (sân khấu tự diễn nốt pha thu về khi `charge` về 0, lao 120 đơn vị theo pha
  — trước đây nhảy cóc). Soát dấu kênh bằng ảnh cực trị trước khi biên đạo:
  đầu lợn rừng `rot2` dương là NGẨNG (chú thích cũ ghi ngược).
- **Cảnh mở màn trồi từ dưới đất (lính đá 1.3, 1.7):** `rise` cũ chỉ diễn khi
  lính đá canh hang ráp lại → vào trận thấy đứng sẵn. Nay `BossArt.introSeconds`
  (sân khấu lùi đòn doạ đầu tiên) + `rise` 16 khung theo kiểu xác sống trồi
  khỏi mộ: chìm sâu (`sink` 154) để mũi giáo ló trước, tay giơ thẳng, mũ, vai;
  mặt hứng bóng che phần dưới đất. Đất nứt/hố/gò/đá văng/bụi vẽ ở sân khấu
  (`_risingEarth`, hố trước sprite, gò + đá sau sprite). Đá vụn vẽ hình góc
  cạnh xoay theo đà — hình tròn trông như chuỗi hạt.
- **Bản 2.5D của quái Tripo = render hoạt hình từ chính mô hình 3D (23/10):**
  bản vector cũ khác hẳn thiết kế Tripo và gần như không có động tác.
  `tool/blender/toon_kit.py` + cờ `--toon` ở 5 script → atlas `<tên>_toon`
  (cùng xương, biên đạo, track `spearTip`/`headTrack`…). Ở chế độ 2.5D,
  `SpriteAtlas.load/get` tự đổi sang `_toon` cho các tên trong
  `SpriteAtlas.toon`; tên khác trả null (vẽ vector, không nạp atlas vô ích).
  Chân dung `assets/portraits/<id>_toon.webp` (`BossPortrait.bakedToon`,
  art_bake_test chụp cả hai chế độ). Bài học tô hoạt hình trong Cycles:
  Toon BSDF cắt mặt khuất về đen → tự tính N·L với hướng sáng cố định, chia
  nấc bằng ColorRamp, tô bằng Emission; ảnh màu Tripo đầy vân lông → làm
  phẳng ảnh (thu nhỏ, làm mờ, k-means 8–12 màu, nội suy Linear — Closest vỡ
  ô vuông); gom màu phải trên thang gamma; viền = vỏ Solidify lật pháp tuyến,
  mực ở mặt KHÔNG quay lưng. Hoa văn nhỏ (khiên lính đá) cần ô làm phẳng nhỏ.
- **Khung chân dung (art_bake_test `framing`) phải đo lại mỗi khi đổi tỉ lệ /
  vị trí quái** trên `build/portraits/_stage_<id>.png`: sau đợt phóng to,
  chân dung sư tử chỉ còn ngực/chân, Hydra mất đầu. Chân dung vẽ ở
  `0,4 + introSeconds` giây (sau cảnh mở màn).

## 13. Phông vẽ riêng từng màn + bản đồ vẽ (ChatGPT, 23–24/10/2026)

Trước đây cả 8 màn dùng chung một phông Blender (thung lũng + hang = cảnh
màn 1.8). Nay mỗi màn một tranh vẽ đúng cảnh ở điểm màn trên bản đồ, bản đồ
cũng vẽ lại cùng chất. Toàn bộ tài liệu tạo ảnh ở `art_src/backdrop_prompts/`
(`PROMPTS.md`: tin nhắn luật chung + 8 prompt + prompt bản đồ).

- **Cách giữ thống nhất:** một cuộc trò chuyện; ảnh mẫu phong cách + bản đồ +
  **khung bố cục** (`3_khung_bo_cuc.png`: đường đất ở dòng 220/260, vùng
  nhân vật trái, vùng quái phải để trống, dải trên/dưới sẽ cắt); làm màn 1.8
  trước làm chuẩn. Vị trí mốc trong từng prompt TÍNH từ toạ độ bản đồ (hướng
  và khoảng cách từ điểm màn tới đền, cầu, sông, hang).
- **Soát mỗi ảnh:** chồng khung bố cục + GHÉP THỬ sprite quái vào chỗ đứng.
  Lỗi hay gặp: quái cùng màu nền (lính đá trắng trước vách/đền cẩm thạch →
  xin vách trong bóng râm), đường đất quá cao hoặc nhìn dọc (phải chạy ngang),
  vật cản trong vùng nhân vật, không khí sai (đầm độc mà trời nắng đẹp; đừng
  phủ sương XANH lên cảnh Hydra xanh).
- **Bản đồ:** đưa khung có chữ thì ChatGPT chỉ coi là gợi ý (sông, đường mòn
  sai hết). Đưa **bản phác màu thật không chữ** (`5_phac_ban_do.png`, tô đúng
  đường mòn game vẽ) và bảo "vẽ lại chính ảnh này" thì giữ bố cục.
- **Nhập:** `python -I tool/import_painted_backdrops.py` → cắt về 448×260
  (1344×780) `assets/backdrops/nemea_stage_1_X.webp`, bản đồ 1200×900; DÒ lối
  đất (màu) và dòng sông trong tranh thành đường gấp khúc (đường đi chi phí
  nhỏ nhất, băng được chỗ đứt ở cầu/đá kê), in hằng số Dart cho
  `nemea_map_art.dart` (`nemeaMapTrail`, `_nodeOnTrail` theo mốc, `_riverLine`).
  Trên tranh game chỉ vẽ chấm đoạn đã đi + điểm màn (lối đất có sẵn).
- **Game:** `NemeaStageBackdrop` (một ảnh/màn, nạp theo `backdropScene` của
  BossArt, dùng ở CẢ 2.5D và 3D), trôi theo camera ×0,3 (không tách tầng:
  vách/cây cao từ trời xuống đất bị xé), bụi Trì Trệ ×0,5. `sceneLight`:
  phủ màu toàn cảnh + nhân màu sprite quái/chim theo ánh sáng tranh (bình
  minh vàng, đầm xám tím, hoàng hôn cam). Phông Blender 5 tầng còn dùng cho
  màn mở đầu (`nemea_intro_screen`) và khi thiếu ảnh màn.
- Bẫy gặp lúc làm lính đá: Tripo dính **ống chân + bàn chân vào cùng mảnh
  khiên** → ghim cả mảnh vào xương khiên thì chân không bước được (chỉ ghim
  phần trên mặt khiên, ghim SAU `smooth_weights`); chân gần duỗi thẳng che
  mất lỗi chiều gập gối — có khuỵu gối thì phải soát IK (gối chĩa tới trước).
  In nhóm đỉnh trội theo xương (số đỉnh, khoảng toạ độ) trước khi tin rig.
- **Khung trang chủ (26/10):** chụp lại từ cảnh trận 1.8 hiện tại (phông vẽ
  cửa hang + sư tử lionScale 1,2) — ảnh chụp sẵn phải chụp lại mỗi khi đổi
  phông/tỉ lệ boss (`ART_BAKE=1 flutter test test/art/art_bake_test.dart` rồi
  `python -I tool/sprites_webp.py --banner`). Thêm bản 2.5D
  `scene_*_toon.webp` (sư tử hoạt hình); nhân vật 2.5D vẽ vector đè lên.
- **Chim Stymphalia + Spartoi Tripo3D (26/10):** chim nhập xoay -45° (Tripo
  dựng chéo), gốc ở tâm thân như bản cũ; chia cánh/đuôi/đầu bằng
  `surface_regions`. Soát dấu kênh bằng ảnh thử: cả `pitch`/`neck` lẫn `flap`
  đều ngược với giả định ban đầu. Spartoi sinh từ khuôn lính đá
  (`stone_tripo.py`), chỉ đổi khớp, lọc gần/xa, biên đạo.
- **Bóng đổ bị cắt thành mép chữ nhật** (Spartoi): bóng nắng xiên đậm có
  alpha ≥ 0,6 nên bị coi là thân, không được làm mờ ở mép khung cắt.
  `atlas_pack.crop` nay làm mờ MỌI điểm trong dải ≤ lề quanh thân.
