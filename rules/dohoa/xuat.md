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
- Video phải là bản **đúng với sprite đang commit**. Đổi biên đạo / mocap thì
  render lại video, đừng để video cũ trong mục mới (19/10: 4 video ở
  `build/videos/` vẫn là biên đạo trước mocap mà không ai biết).
- Render video song song được: mỗi tiến trình Blender ~3,4 GB RAM, ~1,2 GB
  VRAM, phần chậm là đặt dáng mocap (CPU một luồng) chứ không phải Cycles →
  chạy hai boss cùng lúc trên máy 16 GB nhanh gần gấp đôi; ba thì thiếu RAM.
- File lớn (vài MB): chèn/sửa bằng script hoặc Edit theo marker, đừng đọc cả file.
