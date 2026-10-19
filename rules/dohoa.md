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

Boss dựng theo tranh người dùng chọn (ảnh duyệt `--still`; oni và tengu đã xuất sprite + BossArt 18/10 — mục 13):

| Boss | Script | Ảnh |
|---|---|---|
| Yamata no Orochi (làm lại: rắn thật xanh xám, bụng hồng, mắt vàng, vàng lá) | `orochi_boss.py` | `build/blender/orochi/` |
| Shuten-dōji (oni đỏ vác kanabō) | `oni_boss.py` | `build/blender/oni/` |
| Sutoku hoá đại tengu | `tengu_boss.py` (model Tripo `art_src/tripo/tengu_001/` từ 16/10, thay bản MPFB) | `build/blender/tengu/` |
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

### Bổ sung sau khi hiệu chỉnh `--review` (bản 10c, 16/10 đêm)
Bộ soát tự động (`bash tool/blender/render.sh <script> --review --quick`, ra `build/blender/review/<script>/sheet.png`) bắt được hai lỗi thật trên oni đã duyệt. Cả hai bị ảnh góc game che.
- **Góc game che lỗi bên hông.** Vòng tay chìm và vuốt hở chỉ lộ khi nhìn nghiêng, nhìn sau hoặc nhìn cận. Đọc đủ bộ ảnh soát, không chỉ ảnh toàn thân.
- **Có luật chưa chắc đã áp.** "Giáp đo da" đã ghi từ bản 10, nhưng vòng bắp tay oni vẫn không truyền `skin=`. Kiểm tự động đáng tin hơn danh sách nhắc.
- **Đừng tin ghi chú, hãy đo.** Ghi chú cũ nói oni cao ~2,6 m, đo thật ra 3,4 m. Tỉ lệ chân đo tới **khớp háng** (đầu xương `thigh`), không tới đầu xương `pelvis` MPFB (nằm cao hơn). Người thường khoảng 0,50–0,53; oni duyệt ở 0,56.
- **Dò trên lưới thô, hiện trên lưới mịn.** Subsurf làm ngón nhỏ co lại, nên vật gắn đặt theo lưới thô có thể hở (vuốt ngón thứ 4 hở 2,8 cm). Gắn xong thì kéo vật vào mặt da đã đánh giá (`toe_claws` đã làm việc này).
- **Vòng ôm chi béo: ôm theo viền da, không theo vòng tròn quanh xương.** Thiết diện tay béo là bầu dục và thịt xệ lệch trục. Vòng tròn hoặc chìm một phía, hoặc nới ra thì bung lỏng phía kia; nới theo tia hay nới vô hạn còn làm vòng bung ngang người. Dùng `japan_kit.band_fit` sau khi tạo dáng: nó đo viền da thật (chỉ đỉnh thuộc xương đó), làm mượt quanh chu vi rồi dựng vòng theo viền. Đặt vòng ở giữa đoạn chi; sát vai, sát hông thịt dính thân nên không có thiết diện riêng.
- **Số liệu đẹp chưa đủ, phải nhìn ảnh.** Một lần nới vòng tay cho kết quả "0% chìm" vì vòng đã phình to gấp đôi. Mỗi lần sửa theo số liệu, render ảnh cận vật vừa sửa.
- Bộ soát tự bỏ qua lưới mắt phụ MPFB (Irishelper). Đồ cố ý cắm vào thân (vuốt tay nắm, khuyên vòng sau thừng) thì khai báo qua `embedded=`.

## 12. Model Tripo AI → repo (16/10/2026)
Tripo Studio gửi model sang Blender qua addon **Tripo Bridge** (cổng 60600). Addon này ghi file vào thư mục tạm, nhập vào cảnh rồi **xoá file ngay**: model chỉ còn trong cảnh chưa lưu. Đường ống của repo:
- **Addon `SPU Tripo`** (`tool/blender/addons/tripo_inbox.py`, cài một lần bằng `blender -b -P tool/blender/install_tripo_inbox.py`; file mồi trong thư mục addon nạp code thẳng từ repo).
  - Tự động: bọc `ModelImporter.import_model` của Tripo, chép file gốc vào `art_src/tripo/_inbox/<giờ>_<tên>.glb` trước khi nhập. `_inbox/` không commit.
  - Nút **Gửi vào repo** (phím N › tab SPU): xuất vật đang chọn (cả con, xương, hoạt hình, chỗ sửa tay) → `art_src/tripo/<tên>/model.glb` + `meta.json` (tam giác, khung, xương, hoạt hình, ghi chú/prompt) + `thumb.png`. Thư mục này commit, `*.glb` qua **Git LFS** (`.gitattributes`).
- **`tool/blender/tripo_kit.py`**: `load` (nhập, gom dưới `<tên>_root`, bỏ hình hiển thị xương Icosphere của bộ nhập glTF, **đổi tên xương sang tên MPFB game_engine**), `normalize` (yaw, chiều cao, chân chạm z=0), `decimate`, `tone` (bão hoà/sáng/nhám), `action_frames` (khung sprite từ hoạt hình Tripo), `default_lights` (ba đèn như oni).
  - Đổi tên xương theo tên + độ sâu thứ bậc (Mixamo `LeftUpLeg`→`thigh_l`, `Spine/Spine1/Spine2`→`spine_01..03`…), ghi `build/blender/tripo/<tên>/bones.txt`. Đoán sai thì truyền `bones={cũ: mới}`. Nhờ vậy `review_kit` / `sprite_kit` dùng nguyên, không cần bản riêng cho Tripo.
- **Xem nhanh:** `bash tool/blender/render.sh tripo_view <tên> [--height H] [--yaw Y] [--review] [--quick] [--save]` → `build/blender/review/<tên>/sheet.png`. Không cờ = bộ xoay vòng + ảnh đất sét (bỏ texture, lộ lỗi lưới). `--review` = bộ soát nhân vật, cần đủ xương người.
- **Dùng thật trong game:** viết `tool/blender/<tên>.py` theo `tripo_kit` (như các script boss) rồi xuất sprite bằng `sprite_kit.export_sprites`.
- **Claude xem cảnh đang mở:** server MCP `blender` (`uvx blender-mcp==2.0.0`, phạm vi local, `DISABLE_TELEMETRY=true`) nói chuyện với addon *MCP for Blender* (cổng 9876). Trong Blender: N › tab BlenderMCP › **Connect**. Chỉ để xem/thử; sản phẩm đi qua hộp thư.
- **Giới hạn Tripo:** lưới tam giác lộn xộn, texture nướng sẵn ánh sáng → hợp quái thường, đồ vật, cảnh. Boss chính vẫn dựng bằng MPFB.

### Gắn xương và làm dày lưới model Tripo (tengu, 16/10 tối)
- **Đưa Tripo ảnh nhân vật tách nền, đứng chữ T/A.** Ảnh nguyên bức tranh (tengu trên cành thông) → Tripo dựng cả tranh thành tấm phù điêu, không có lưng.
- **Texture để Tripo làm (20 credit, đủ 360°); xương thì tự gắn** (`tripo_kit.build_rig`), không tốn credit. Khớp đọc trên ảnh chính diện + nghiêng có lưới toạ độ 10 cm (dáng chữ T rất dễ đọc). Xương thêm (cánh `wing_01..03_l`) đặt tên tuỳ ý, `_l` tự sinh `_r`.
- **Bone heat trên lưới AI hỏng cả lưới** (đỉnh tách theo đường nối UV, vải nhiều lớp). Ba bước đã thử ra:
  1. Tính trên bản phụ voxel remesh, ô = **1,5% chiều cao** (nhỏ hơn thì vải hở/lông cánh vỡ vụn, khối lớn nhất có khi là cái cánh).
  2. Chỉ giữ **khối liền lớn nhất**: một mảnh không "thấy" xương là hỏng cả hệ.
  3. Giải ở cỡ **×10**: cỡ 2 m có cánh thì bộ giải thiếu chính xác, ×10 thì được.
  Rồi chép trọng số về lưới thật theo 4 đỉnh gần nhất (UV/texture giữ nguyên).
- **Xoay xương theo trục thế giới** (`tengu_tripo.rot`), không đoán trục cục bộ — xương dọc (chân) và xương ngang (tay, cánh) có trục cục bộ khác nhau.
- **GLB chỉ chứa tam giác:** quad "Smart Mesh" của Tripo bị xẻ đôi khi xuất. `tripo_kit.densify`: hàn đỉnh trùng → ghép tam giác lại thành quad (tengu 9 882 tam giác → 5 823 quad ≈ 5 769 gốc) → Subdivision Surface đặt SAU xương. Mịn viền và chỗ gập khớp, không thêm chi tiết — chi tiết nằm ở texture 4096.
- `review_kit` khung mặt chỉ lấy đỉnh gần trục đầu (lưới liền có cánh kéo khung rộng).
- **Tengu chốt dùng bản Tripo** (`tengu_boss.py`, thay hẳn bản MPFB; code MPFB cũ còn trong lịch sử git). Người dùng duyệt chỉnh: cánh ×1,25, rũ xuống (`WING_SCALE`, `WING_DROOP`). Phóng cánh bằng scale ở xương `wing_01` trong dáng nền (đốt con thừa hưởng) → lông cánh không méo, gốc cánh vẫn bám lưng.
- **Tripo hay chỉ vẽ hoạ tiết mặt trước** (tengu: mon vàng có ở ngực/quần trước, lưng trơn). `tripo_kit.front_map` chiếu model từ trước ra ảnh màu theo (x, z) → cắt một hoạ tiết trọn vẹn làm khuôn → `stamp_back` đóng khuôn lên các tâm (x, z) ở mặt sau (chỉ phần màu hoạ tiết, chỉ lên vải; khuôn lật ngang để đọc đúng chiều từ sau). Làm trên texture lúc dựng, `model.glb` giữ nguyên.
  - **Không chép nguyên vị trí trước → sau:** mặt trước bị đai buông, vạt áo, nếp gấp che → hoạ tiết sau khuyết theo.
  - **Xét "là vải" theo màu trung bình cả tam giác:** vải Tripo có đốm nhạt khác màu; xét từng điểm ảnh thì khuôn thủng lỗ chỗ.
  - UV Tripo vỡ thành hàng trăm mảnh nhỏ → mọi thao tác texture phải đi qua toạ độ 3D, không cắt dán trong ảnh UV.

## 13. Sprite + BossArt boss chương Nhật: Shuten-dōji, tengu Sutoku (18/10/2026)

Hai boss đã chốt hình được xuất sprite (`assets/sprites/shuten_doji.*`,
`tengu_sutoku.*`: idle 6, attack 12, defeat 6 khung, 3 trang WebP mỗi boss,
~1,1–1,3 MB) và có BossArt Flutter (`lib/art/bosses/shuten_boss.dart`,
`tengu_boss.dart`, lớp chung `japan_sprite_boss.dart`). Đăng ký trong
`boss_registry.dart` theo id `shuten_doji` / `tengu_sutoku`, nhưng **chưa có
EnemySpec hay màn**: máu, cơ chế (Shuten uống rượu hồi máu; Sutoku chưa
thiết kế) là việc của level-spec/balance-reps khi dựng kỳ công Izumo/Heian.

- **Đòn:** tengu giơ quạt lông hauchiwa cao sau đầu, cánh dựng xoè → quạt
  quất tới, cánh đập; hiệu ứng ba vòng gió lưỡi liềm cuốn lá phong về phía
  người chơi. Oni giơ chuỳ cao sau đầu → nện xuống trước mặt; hiệu ứng nứt
  đất, sóng chấn động, bụi, đá văng. Hiệu ứng vẽ ở cả 2.5D và 3D.
- **Phông vector** (cả hai chế độ, chưa có bản Blender): núi Ōe đêm trăng có
  sào huyệt đuốc đỏ, thùng sake; Shiramine giông chiều, cây thông, đèn đá,
  chớp xa, lá phong bay.
- **Bản vector 2.5D** vẽ cùng chỗ, cùng cỡ, cùng nhịp đòn; thân tĩnh ghi một
  `Picture`, mỗi khung chỉ vẽ tay vũ khí, lửa, cánh. Chưa đo trên máy thật.
- Xem trước: `ART_PREVIEW=1 flutter test test/art/art_preview_test.dart
  --plain-name "Shuten-dōji và tengu"` (vector + sprite × 5 pha).

Bài học:
- **Nhân vật có vải dựng sau khi tạo dáng (oni) vẫn làm sprite được mà không
  dựng lại vải từng khung:** giữ nguyên thế chân của bản duyệt, chỉ cử động
  thân trên (`OniMotion`). Vật dựng ở thế giới lúc tạo dáng (chuỳ, lửa tay)
  phải gắn vào xương bàn tay (`attach_props`, `parent_posed`) trước khi tạo
  dáng khác. Tay IK: đặt lại đích IK + `palm` mỗi khung.
- **Vung vũ khí: nội suy theo GÓC quanh vai** (`CLUB_KEYS`), không nội suy
  thẳng vị trí — thẳng thì tay cắt ngang mặt, hướng chuỳ lật đột ngột ở giữa
  hai khoá. Góc "tháo cuộn" có chủ đích (148 → 178 → −50: qua đỉnh đầu).
- **Đòn nhanh trong sprite:** pha ra đòn chỉ ~2 khung trên 12; sân khấu hoà
  hai khung kề nhau ra **hai cây chuỳ chồng nhau**. `SpriteAtlas.draw(snap:)`
  lấy khung gần nhất quanh cú ra đòn. Giữ đỉnh đòn thêm ⅓ pha thu về
  (`holdStrike` / `s_ * 1.5`) để hiệu ứng chạm đất có vật chạm thật.
- **Model Tripo cầm vật:** bàn tay xoè (không có xương ngón) → cán vuông góc
  ngón, xuyên lòng bàn tay; dựng quạt bằng xoay cổ tay quanh trục cánh tay
  (sấp/ngửa) theo pha. Đặt cán dọc theo ngón thì cán nằm song song dưới bàn
  tay — `--review` báo 0 cảnh báo, chỉ ảnh cận bắt được.
- **Góc sân khấu cho model Tripo:** xoay rig ¾ quanh trục qua CHÂN
  (`face_game`; thân không nằm ở gốc vì cánh kéo khung ra sau), `rot` đọc trục
  theo khung rig để rig xoay được. Xoay quá ¾ (−38°) thì cánh gần che mất cánh
  xa; −24° đủ thấy cả hai cánh.
- Màu vật cầm phải tách khỏi vật sau nó ở khung ra đòn: quạt nâu nhạt chìm
  vào cánh nâu → đổi lông sẫm.
- `tengu_boss --review --strike`: bộ soát trên khung ra đòn.

## 14. Biên đạo đòn đánh theo võ thuật (18/10/2026)

Người dùng chê đòn bản đầu (mục 13) "thô": chỉ cánh tay vung, thân đứng
yên, một đòn duy nhất. Làm lại theo nguyên lý võ thuật dùng binh khí và
hoạt hình đòn đánh, mỗi boss **hai đòn có dấu hiệu báo trước khác nhau**.

**Nguồn đã tra** (không có tài liệu kata kanabō/tessen chi tiết công khai —
lấy nguyên lý chung):
- Kiếm đạo/kiếm thuật: thế **jōdan** (vũ khí trên đầu ngả ra sau, ~70%
  trọng lượng chân trước), **hassō** (dựng đứng cạnh má), **waki-gamae**
  (giấu thấp sau hông, mũi chĩa xuống sau); **ki-ken-tai-ichi** (ý–vũ khí–
  thân chạm cùng lúc), **fumikomi** (bước dậm, lực từ chân sau), **zanshin**
  (giữ thế, giữ ánh nhìn sau cú đánh) — [Toyama-ryū kamae](https://toyamaryu.org/kihon_fundamentals_kamae.htm),
  [thế kiếm Nhật](https://swordis.com/blog/japanese-sword-stances/),
  [fumikomi](https://www.kendo-guide.com/fumikomi-how-to-perform-this-stomping-action.html).
- Kanabō-jutsu: thăng bằng + sức, đánh vỡ giáp, **quét chân ngựa**; đánh hụt
  thì hở người — [Kanabō](https://military-history.fandom.com/wiki/Kanab%C5%8D).
- Tessenjutsu: gạt đỡ một tay, đánh tay kia; Yoshitsune dùng quạt gạt giáo
  Benkei; tengu núi Kurama dạy Yoshitsune võ —
  [Tessenjutsu](https://en.wikipedia.org/wiki/Tessenjutsu), [Kurama-tengu](https://en.wikipedia.org/wiki/Kurama-tengu).
- Hoạt hình đòn nặng: ba tư thế khoá (lấy đà / chạm / thu) phải đọc được ở
  dạng bóng; người + vũ khí là một khối; quỹ đạo cong; khựng lúc chạm; phần
  phụ đi theo sau — [80.lv: vũ khí hai tay](https://80.lv/articles/breakdown-animating-tiny-character-with-massive-two-handed-weapon).

**Biên đạo** (`tool/blender/choreo/<id>.json`, một nguồn cho Blender và
Flutter; `python tool/gen_choreo.py` sinh `lib/art/bosses/choreo_data.dart`;
`test/art/choreo_test.dart` so bộ nội suy Dart với Python):

| Boss | Đòn | Báo trước (0–0,5) | Ra đòn | Sau đòn |
|---|---|---|---|---|
| Shuten-dōji | `attack` Nện đỉnh | Jōdan: chuỳ giơ cao ngả sau đầu, thân ngả ra sau vặn vai phải, tay lửa vươn thẳng ngắm đích, trọng tâm lùi chân sau | Fumikomi chân phải, hông dẫn → thân → tay → chuỳ qua đỉnh đầu nện xuống trước, khuỵu sâu, tay lửa kéo về sườn | Zanshin chuỳ đè đất ~0,1, rồi nặng nề nhấc chuỳ, kéo chân về, vác lên vai |
| | `attack2` Quét chân ngựa | Waki-gamae: hạ thấp, vặn hông hết cỡ, chuỳ giấu sau hông thò đầu lên, tay lửa ngắm | Bước tới, xoay hông trọn vòng, chuỳ quét ngang thấp từ sau ra trước | Theo đà quét sang trái (quá vòng), rồi vác lại |
| | `defeat` | | Chuỳ cắm đất làm gậy chống, quỵ gối, đầu gục, lửa tắt | |
| Tengu Sutoku | `attack` Phong kesa | Hassō: quạt dựng cạnh đầu, tay trái giơ đỡ kiểu tessen, cánh dựng xoè, trọng tâm lùi | Bước tới, chém chéo kesa xuống trái, cánh đập xuống cùng nhịp, tay trái kéo về | Zanshin thấp, cánh hạ chậm (mút cánh trễ nhất) |
| | `attack2` Thiên cẩu phi | Thu người, cánh dựng cao → vỗ cánh bật lên, lơ lửng ở đỉnh quạt giơ sau đầu, chân co | Bổ quạt xuống khi đáp, khuỵu sâu, cánh xoè hãm | Gió vòng trên đất, lông bung, đứng dậy |
| | `defeat` | | Quạt trĩu, cánh rũ sụp, quỵ gối, đầu cúi | |

**Bộ máy** (`tool/blender/choreo.py`, `lib/art/bosses/choreo.dart`):
- Kênh khoá thưa (khoá có thể thiếu kênh), nội suy **cubic đơn điệu
  Fritsch–Carlson**: mượt nhưng không vọt quá khoá (vọt thì chuỳ xuyên đất).
- `lag` theo kênh = chuỗi lực hông (0) → thân (0,004–0,006) → tay (0,01) →
  vũ khí (0,01–0,014) → cánh (0,012–0,02) → mút cánh (0,035).
- Khoá lặp lại cùng giá trị = giữ (khựng lúc chạm, zanshin, lơ lửng ở đỉnh).
- Oni: chân **IK bám đất** (chân phải bước theo `step`/`lift`), hông dịch/hạ,
  vặn chia hông 40% → lưng 35% → ngực 25%, đầu bù ngược để mắt giữ nhìn đích;
  hakama/tạp dề/khoá **dựng lại mỗi khung** (~1,5 s, rẻ) nên chân cử động
  được. Tengu (model Tripo): IK tay + chân thêm vào rig tự gắn, bàn tay
  xoay theo hai vector (cán quạt đúng hướng, ngón nối cẳng tay); bay = dịch
  hông lên + bàn chân co (`lift` − `tuck`).
- Sprite: `idle` 8, `attack` 20, `attack2` 20, `defeat` 6 khung; sân khấu
  luân phiên A/B (`JapanSpriteBoss.moveFor`), không hoà khung ±0,1 quanh mốc
  `impact`, `ownsAttackMotion` = true (sprite đã có bước, sân khấu không lao
  thân chồng lên). Vệt vung (`smearArc`) theo cung đầu vũ khí 0,07 trước chạm.
- Bản vector 2.5D đọc cùng kênh: `planeDir` chiếu mặt phẳng trước–lên ¾ ra
  màn hình (trước rút ngắn 0,8; `sweep` quay về máy quay); thân trên xoay
  cứng quanh hông chỉ 55% góc ngả (lưng 3D cong dần, xoay cứng đủ góc thì
  gãy gập); hakama oni co/nghiêng theo hông, gấu nằm yên trên đất.

Bài học:
- **Nắm đấm giữ vũ khí vuông góc cẳng tay.** Muốn chuỳ nện xuống trước thì
  tay phải ở ngang vai, khuỷu hạ (cẳng tay chĩa lên–trước); tay duỗi chĩa
  xuống thì chuỳ nằm ngang.
- **`palm()` (StandPoser) chỉ đúng gần dáng duyệt:** nó coi trục đốt ngón
  vuông góc hướng ngón ở dáng nghỉ — bàn tay MPFB đã nắm lệch 30–60° khi tay
  duỗi ra trước, chuỳ chĩa sai mà không báo. Sau `palm()` đo trục vũ khí thật
  rồi xoay bù cổ tay (`club_arm`). Gặp hướng sai: in số đo (hướng mong muốn /
  cẳng tay / thực tế) trước khi chỉnh khoá.
- **Thế báo đòn phải đọc được ở dạng bóng từ góc game:** waki-gamae giấu
  chuỳ kín sau lưng → mất dấu hiệu; chuỳ chĩa thẳng ra sau thì phối cảnh rút
  ngắn → jōdan trông như không giơ. Cho vũ khí thò ra khỏi bóng thân.
- Thân béo + hakama che hết chân và nửa độ ngả: chuyển trọng tâm phải làm
  lớn hơn người thường mới thấy (ngả 16–28°, hạ 0,2–0,25 × S).
- `exec` của ONI_DEBUG: import trong hàm (đã ghi mục 11) — dính lại lần nữa.


## 15. Cơ chế đòn có báo trước + vòng critic biên đạo (18/10/2026 tối)

- Cơ chế (`lib/game/mechanics/telegraphed_boss.dart`, brief
  `rules/thietke/boss-nhat-shuten-sutoku.md`): mỗi đòn boss có pha báo
  (viền đỏ + icon cách né: ⏸ hoặc rep sâu), Shuten uống rượu, Sutoku viết ấn
  nguyền; 11 test mô phỏng. Sân khấu đọc pha từ cơ chế (`phaseFromTell`,
  `tellAlt`), âm `boss_*_tell/tell2/hit.wav`.
- Biên đạo lặp critic "mắt lạ" (agent mới mỗi vòng, không nói ai làm): vòng
  1→3 điểm 3–7/10, chưa đạt 8. Tấm tư thế khoá: `tool/blender/keysheet.py`.
- Vòng 4 bị thay bằng hướng mới (mục 16): thân lấy từ mocap võ thật, góc quay
  gần nghiêng — khung cũ không còn dùng.

## 16. Đòn boss từ mocap võ học thật — kiểu Shadow Fight (19/10/2026 đêm)

Yêu cầu: boss đánh như game đối kháng (Shadow Fight, Street Fighter) — nhìn
và quay về phía Hercules, khớp tự nhiên tới khuỷu, cổ tay, cổ chân, ngón chân,
ngón tay; được dùng web + máy (RTX 3050 4 GB) để học dữ liệu võ.

**Góc sân khấu.** Boss hình người quay gần nghiêng về đối thủ: oni `FACING =
−72`, tengu `−55` (−70 thì cánh gần che hết cánh xa). Mắt nhìn đối thủ
(`aim_pupils(look=…)`, pha 20% về máy quay cho mắt đọc được), KHÔNG nhìn máy
quay. Boss mới (Susanoo, Tamamo, Orochi) theo luôn.

**Dữ liệu (giấy phép là điều kiện đầu tiên).**
- CMU Graphics Lab Mocap — dùng được cả thương mại, chỉ cấm bán lại dữ liệu.
  42 clip chọn tay (`tool/mocap/manifest.json`): karate subject 135 (kata
  Bassai/Empi/Heian, mae/mawashi/yoko-geri, oi-zuki, shuto-uke, gedan-barai),
  đấm/đỡ/đá 144, quyền anh, kiếm (nghiệp dư — yếu), đá nhảy.
- **Kyokushin karate, 37 võ sinh, CC0** (figshare 10.6084/m9.figshare.c.4981073,
  Szczęsna et al. 2021): 1 411 file C3D, 3 229 đòn gyaku-zuki / mae-geri /
  mawashi-geri gedan–jodan / ushiro-mawashi-geri, 200 Hz, tâm khớp Plug-in
  Gait. Tốc độ đỉnh 8–14 m/s — sức võ sinh thật, hơn hẳn CMU. File thiếu tâm
  khớp thì tự suy từ marker (hông: Bell 1990).
- Loại: Bandai Namco Research (CC BY-NC-ND — cấm thương mại + phái sinh), AMASS
  (phi thương mại), UMONS-TAICHI (NC-SA), Mixamo (cần tài khoản, không tự tải).

**Đường ống** (`tool/mocap/`, chạy ngoài Blender; dữ liệu thô ở
`art_src/mocap/_cache/`, không commit):
1. `fetch.py` / `karate_prep.py` tải + chuyển → khung xương chuẩn 24 điểm
   (`skeleton.py`: mét, Z lên, +X = về phía đối thủ; có gốc ngón tay + ngón
   cái để xoay cổ tay).
2. `segment.py` tự cắt đòn: đỉnh tốc độ chi → chạm = duỗi xa nhất → lấy đà /
   thu; đá phải nhấc mắt cá ≥ 0,45 m (loại bước chân); mỗi đòn xoay cho chi
   bay về +X. Thư viện ~4 200 đòn.
3. `model.py` — **mô hình học chuyển động**: 1D-UNet 12,6 M tham số, cửa sổ 64
   khung @30 fps, khử nhiễu có che khung, học PHẦN DƯ trên nền nội suy tuyến
   tính; mất mát có độ dài xương, chống trượt chân, vận tốc/gia tốc. 215 phút
   dữ liệu. Dùng để điền đoạn nối dáng chờ boss ↔ đòn mocap, khử nhiễu video,
   chấm độ "lạ". Chạy trong `tool/.venv-ml` (torch cu128).
4. `compose.py` + `art_src/mocap/moves.json`: mỗi đòn boss = (clip, chi, thời
   điểm chạm) + mốc sân khấu (TRÙNG biên đạo). Dáng chờ boss (Blender
   `--mocap-ready`) chuyển sang xương người diễn, `style.py` nắn nhịp mocap vào
   nhịp sân khấu (nạp → giữ báo → chạm → dừng lực → thu), mô hình điền hai đoạn
   nối → `art_src/mocap/moves/<boss>_<move>.npz` (commit; Blender chỉ đọc numpy).
5. `tool/blender/mocap_drive.py`: retarget TUYỆT ĐỐI (không phụ thuộc trục
   xương) — khung xoay hông/ngực/đầu dựng từ điểm, chia dần spine_01→03; tay
   chân IK với pole đúng phía khuỷu/gối; chân tính từ khung chậu (đất ↔ đất),
   với không tới thì HẠ HÔNG chứ không nhấc chân; khoá chân khi chạm đất; nhón
   gót thì gập ngón chân bám đất; mắt khoá về đối thủ; ngón tay `fingers()`.
6. Hai lớp: **thân từ mocap** (hông, cột sống, chân, đầu, tay không cầm vũ
   khí) + **tay vũ khí theo biên đạo** (chuỳ, quạt — giữ quỹ đạo đã duyệt),
   tay vũ khí xoay theo phần ngực mocap vặn khác biên đạo
   (`yaw_mocap − twist`). `ONI_MOCAP=0` / `TENGU_MOCAP=0` = biên đạo cũ.
7. Tengu (Tripo) không có xương ngón → `tripo_kit.add_fingers`: tách ngón theo
   lưới (cắt dần theo độ sâu dọc bàn tay, mức đầu ra 4 cụm = 4 ngón, cụm tách
   sớm không chứa ngón = ngón cái), 3 đốt 45/30/25 %, trục Z về lòng bàn tay
   (+X = gập), trọng số chuyển mềm từ bàn tay.

Bài học:
- **Cycles GPU và torch không được chạy cùng lúc trên GPU 4 GB** — cả hai lỗi
  truy cập bộ nhớ CUDA (trông như lỗi cuDNN). Huấn luyện thì render
  `BLENDER_CPU=1` hoặc đợi.
- Trục đứng phải neo đất ↔ đất; neo theo hông dáng chờ thì khi hạ tấn cả
  người bị đẩy lên, chân hẫng.
- Hông rig khác hông người diễn → đích chân tính từ khung chậu, không từ khớp
  hông rig.
- Kho kiếm CMU là người nghiệp dư — không đủ uy cho đòn nện; võ tay không
  chuyên nghiệp (karate) + lớp vũ khí biên đạo cho kết quả tốt hơn.
- Đá nhảy CMU bay quá cao, không kịp tiếp đất trong 1,2 s đòn → Thiên cẩu phi
  giữ biên đạo cũ.
- Mã đòn trong thư viện đổi khi dựng lại → `moves.json` tham chiếu bằng (clip,
  chi, thời điểm chạm).

**Vòng critic "mắt lạ" (19/10 đêm, agent mới mỗi vòng, tấm tư thế khoá):**

| Vòng | Oni Nện đỉnh | Oni Quét | Tengu Phong kesa | Thay đổi chính |
|---|---|---|---|---|
| 1 | 3,5 | — | 4,5 | retarget đầu tiên |
| 2 | 5 | 4 | 6 | bỏ bù vặn ngực cho tay vũ khí (biên đạo theo khung cố định) |
| 3 | 5,5 | 4 | 5 | lớp gập/vặn thân cộng dồn, tay lửa theo biên đạo |
| 4 | 5,8 | 4,2 | 6,2 | khoá xoay thân `yaw_keep` 0,3 (ngực không mở ra máy quay) |
| 5 | 6 | 4,5 | 5,5 | mắt nhìn đối thủ sau mọi lớp |
| 6 | 6 | 5 | 6,5 | sửa dấu ngẩng đầu, hạ tấn sâu đòn quét |
| 7 | 6,5 | 6 | 6,5 | chuỳ thu vòng dưới (−212° ≡ 148°), quét song song đất |
| 8–10 | 5,5–6 | 6–6,5 | 5–6,5 | critic mâu thuẫn nhau (chuỳ dựng / ngả sau) |
| **11** | **6,8** | **6,2** | **5,6** | đỉnh lấy đà trong pha giữ, cung liền — **bản chốt** |
| 12 | 6 | 5,5 | 5,5 | (bỏ, quay về v11; giữ cằm hơi cúi) |

Chưa đạt 8/10. Bài học về vòng lặp:
- Từ vòng 8 điểm bão hoà 6 ± 1, phần lớn là nhiễu giữa các critic (cùng một tư
  thế bị khen ở vòng này, chê ở vòng sau). Chỉ sửa ý **lặp lại ≥ 2 vòng**;
  chốt bản điểm cao nhất thay vì bản cuối.
- Critic chỉ thấy tư thế tĩnh → luôn đòi "thêm khung giữa". Bước tiếp: đưa
  critic dải 20 khung sprite thật (hoặc GIF người que) để chấm cung chuyển động.
- Lỗi lặp nhiều nhất đến từ hệ thống, không phải từng khoá: bù vặn sai khung,
  dấu ngẩng đầu ngược, mắt nhìn tính trước lớp cộng. Gặp lời chê lặp lại ở
  cả ba đòn → tìm lỗi trong `mocap_drive`, đừng chỉnh khoá.
- Dư địa còn lại: đòn mocap riêng cho vũ khí nặng (cần dữ liệu kiếm/gậy chuyên
  nghiệp có giấy phép), tay trái ôm cán chuỳ lúc nện (critic v4), cánh xa tengu
  điều khiển riêng, bản vector 2.5D vẫn ở góc ¾ cũ (chưa quay nghiêng).

## 17. Báo cáo đồ hoạ `baocao_dohoa.html` (quy tắc, 19/10/2026)

Mọi thay đổi đồ hoạ (nhân vật, boss, đòn đánh, phông, hiệu ứng, sprite) phải
ghi vào `baocao_dohoa.html` ở gốc repo, cùng commit với thay đổi (hoặc ngay sau).

- **Kiểu stack:** mục mới chèn ngay dưới `<h1>`, mục cũ đẩy xuống. Mỗi mục bọc
  bằng marker `<!--<tên>-start-->` … `<!--<tên>-end-->`, ghi ngày giờ, làm gì,
  commit, việc còn chờ duyệt.
- **Một file duy nhất:** ảnh **và video** đều nhúng base64 vào HTML, không trỏ
  ra `build/` (thư mục bị gitignore, người khác mở báo cáo sẽ không thấy).
- **Đòn đánh / chuyển động phải có video,** không chỉ tấm tư thế khoá: tư thế
  tĩnh không cho thấy nhịp lấy đà → chạm → thu. Quy trình:
  1. `bash tool/blender/render.sh <boss> --video` (60 khung mỗi đòn),
  2. `python tool/boss_video.py` → `build/videos/<boss>_<đòn>.mp4`,
  3. `python tool/report_video.py <tên mục> build/videos/<file>.mp4="<chú thích>" …`
     — nén 540p (~150–300 KB mỗi video), chèn khối `<video>` trước
     `<!--<tên>-end-->`; chạy lại thì thay khối cũ.
- Video phải là bản **đúng với sprite đang commit**. Đổi biên đạo / mocap thì
  render lại video, đừng để video cũ trong mục mới (19/10: 4 video ở
  `build/videos/` vẫn là biên đạo trước mocap mà không ai biết).
- Render video song song được: mỗi tiến trình Blender ~3,4 GB RAM, ~1,2 GB
  VRAM, phần chậm là đặt dáng mocap (CPU một luồng) chứ không phải Cycles →
  chạy hai boss cùng lúc trên máy 16 GB nhanh gần gấp đôi; ba thì thiếu RAM.
- File lớn (vài MB): chèn/sửa bằng script hoặc Edit theo marker, đừng đọc cả file.
