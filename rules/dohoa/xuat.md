# Phòng Render & xuất (sprite atlas, ảnh chụp sẵn, video, báo cáo)

Code: `tool/render/` (`sprite_kit.py`, `atlas_pack.py`, `sprites_webp.py`,
`repack_sprites.py`, `keysheet.py`, `boss_video.py`, `report_video.py`).
Nhận nhân vật + chuyển động đã duyệt; bàn giao `assets/sprites/*`,
`assets/backdrops/*`, `assets/portraits/*` và mục báo cáo cho phòng Vào game.

**Quy tắc chính**
- Sprite: ~3 px/đơn vị sân khấu, trang 2048², WebP; đo bộ nhớ trên máy thật khi
  thêm trang.
- Render lại sprite → chụp lại chân dung/khung trang chủ (`art_bake_test`).
- Mọi thay đổi đồ hoạ ghi `baocao_dohoa.html` kiểu stack; ảnh **và video** nhúng
  base64; đòn đánh phải có video khớp sprite đang commit.

## Sprite vào game (cũ: mục 7)

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

## Công cụ đóng lại atlas, ảnh chụp sẵn (cũ: mục 7)

- Công cụ: `tool/render/repack_sprites.py` đóng lại atlas từ khung đã render (cắt
  theo thân đục, thu nhỏ) không cần chạy Blender; `hero.py --only pelt,...`
  chỉ render lớp còn thiếu.
- **Ảnh chụp sẵn cho màn ngoài trận** (`test/art/art_bake_test.dart`, chạy
  `ART_BAKE=1 flutter test test/art/art_bake_test.dart` rồi
  `python tool/render/sprites_webp.py --portraits` / `--banner`): màn chọn màn và
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

## Sprite boss chương Nhật đã xuất (cũ: mục 13)

Hai boss đã chốt hình được xuất sprite (`assets/sprites/shuten_doji.*`,
`tengu_sutoku.*`: idle 6, attack 12, defeat 6 khung, 3 trang WebP mỗi boss,
~1,1–1,3 MB) và có BossArt Flutter (`lib/art/bosses/shuten_boss.dart`,
`tengu_boss.dart`, lớp chung `japan_sprite_boss.dart`). Đăng ký trong
`boss_registry.dart` theo id `shuten_doji` / `tengu_sutoku`, nhưng **chưa có
EnemySpec hay màn**: máu, cơ chế (Shuten uống rượu hồi máu; Sutoku chưa
thiết kế) là việc của level-spec/balance-reps khi dựng kỳ công Izumo/Heian.

## Báo cáo đồ hoạ `baocao_dohoa.html` (quy tắc, 19/10/2026) (cũ: mục 17)

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
  2. `python tool/render/boss_video.py` → `build/videos/<boss>_<đòn>.mp4`,
  3. `python tool/render/report_video.py <tên mục> build/videos/<file>.mp4="<chú thích>" …`
     — nén 540p (~150–300 KB mỗi video), chèn khối `<video>` trước
     `<!--<tên>-end-->`; chạy lại thì thay khối cũ.
- Bản nháp giữa các vòng: `--video --quick` → `*_quick.mp4` (không nhúng báo cáo).
- Video phải là bản **đúng với sprite đang commit**. Đổi biên đạo / mocap thì
  render lại video, đừng để video cũ trong mục mới (19/10: 4 video ở
  `build/videos/` vẫn là biên đạo trước mocap mà không ai biết).
- Render video song song được: mỗi tiến trình Blender ~3,4 GB RAM, ~1,2 GB
  VRAM, phần chậm là đặt dáng mocap (CPU một luồng) chứ không phải Cycles →
  chạy hai boss cùng lúc trên máy 16 GB nhanh gần gấp đôi; ba thì thiếu RAM.
- File lớn (vài MB): chèn/sửa bằng script hoặc Edit theo marker, đừng đọc cả file.

## Phông vẽ riêng từng màn + bản đồ vẽ (ChatGPT, 23–24/10/2026) (cũ: mục 13 nhánh chương 1)

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
- **Thư viện:** mọi luật dưới đây đã gom thành motion kit — hướng dẫn dùng cho
  nhân vật / chương sau ở `rules/chuyendong.md`.
- **Độ mượt (01/11):** khung chia đều làm đoạn ra đòn chỉ ~3 khung (nhảy cóc), đứng
  chờ 2–3 hình/giây (nhoè). Nay `motion_kit.dense_phases` dồn khung dày quanh cú
  đánh (0,46–0,70), ghi `phases` vào atlas; `SpriteAtlas.phasesOf/positionOf` đọc
  tiến độ từng khung (cả track `spearTip`/`headTrack`/`headAttack`). Quanh cú
  đánh vẫn `snap` (thân lao nhanh, hoà khung hiện bóng kép). Đứng chờ ~gấp đôi
  khung. Soát độ mượt không cần app: `tool/render/compare_motion.py` (trước/sau,
  phát đúng như game 30 hình/giây), `tool/render/game_anim.py` (ảnh động báo
  cáo theo nhịp game). Hydra 3 bản đầu → giảm còn 8 + 15 khung để vừa 4 trang.
- **Đợt 2 (26–27/10):** đòn quái chương 1 dài 1,6 s (`BossArt.attackSeconds`);
  đứng chờ: lính đá/Spartoi/lợn rừng/sư tử 24 khung, chim/Harpy 16, Hydra 14
  (Hydra 5 trang ở tỉ lệ 0,7; sư tử 4 trang ở 0,65; lợn rừng 3 trang ở 0,75).
  Cánh chim + Harpy gập vào cuối nhịp đập xuống (`tuck`) — đợt 3 làm lại.
- **Đợt 3 (27/10):** cánh vỗ theo số đo chim thật (`motion_kit.wingbeat`,
  bồ câu bay chậm PMC12068018): đập xuống cánh duỗi, mút cánh trễ ~0,1 nhịp;
  nâng lên cổ tay dẫn trước, khuỷu gập (`flex`), mút cánh rủ xuống −80° và
  quét ra sau, ~3/5 nhịp nâng mới duỗi. Xương cánh nằm dọc chiều sâu phải có
  mốc xoắn riêng (`rig.up`, Rig.set) — không thì cánh vặn xoắn khi xoay.
  Harpy (người có cánh sau lưng): nhịp nâng gập cánh VÀO TRONG — sải co
  ~45%, bàn tay cánh gập xuống quặt về phía thân ~145° trong mặt phẳng cánh
  (khuỷu–cổ tay liên động như chim); gập ra sau lưng thì cánh gần bị thân che.
  Game hoà dáng chờ vào 10% đầu/cuối mỗi đòn (`SpriteAtlas.idleBlend`): vòng
  đứng chờ ở pha bất kỳ nên chuyển thẳng sang đòn bị giật. Khung: đứng chờ
  ~gấp đôi, đòn `dense_phases(0.035–0.05, 0.46, 0.70, 0.016–0.02)`.
