---
name: render-export
description: Phòng Render & xuất của Solo Pushing Up — xuất sprite atlas (sprite_kit, WebP), phông nền theo tầng, ảnh chụp sẵn (chân dung, khung trang chủ), video soát đòn đánh và ghi baocao_dohoa.html (ảnh + video nhúng base64) cho nhân vật/boss Blender đã duyệt hình và chuyển động. Dùng khi cần xuất / xuất lại sprite, đóng lại atlas, làm video đòn, đo ngân sách trang atlas, hoặc ghi một mục báo cáo đồ hoạ.
---

# Phòng Render & xuất

Quy tắc: `rules/dohoa/xuat.md`. Code: `tool/render/`. Nhận nhân vật đã qua
`blender-character` và chuyển động đã chốt ở `boss-motion`; bàn giao
`assets/sprites/*`, `assets/backdrops/*`, `assets/portraits/*` cho phòng Vào game.

## 1. Sprite atlas

- Chạy script nhân vật không cờ soát: `bash tool/blender/render.sh <tên>`
  (`--quick` = 16 mẫu để thử). Script gọi
  `sprite_kit.export_sprites(scene, cam, "<tên>", {"idle": [...], "attack": [...], …},
  anchor, units_per_m, extra={"idlePeriod": …})` → `build/blender/sprites/` →
  `render.sh` tự nén WebP (`tool/render/sprites_webp.py`) vào `assets/sprites/<tên>_<trang>.webp` + json.
- Ngân sách ~3 px/đơn vị sân khấu, trang 2048²; boss chương Nhật hiện 7–8 trang
  (thêm cử chỉ cơ chế) — **cần đo bộ nhớ trên máy thật** khi thêm trang.
- Máy quay nhìn ¾ về phía trái màn hình (nhân vật đứng trái); boss hình người
  quay gần nghiêng về Hercules.
- Đóng lại atlas không render lại: `python tool/render/repack_sprites.py <tên> --scale 0.8`.
- Đổi sprite → chụp lại ảnh ngoài trận: `ART_BAKE=1 flutter test test/art/art_bake_test.dart`
  rồi `python tool/render/sprites_webp.py --portraits` / `--banner`.

## 2. Video đòn đánh (bắt buộc cho mọi đòn mới / sửa)

```bash
bash tool/blender/render.sh <boss> --video          # 60 khung mỗi đòn → build/blender/<boss>/video/<đòn>/
python tool/render/boss_video.py                     # → build/videos/<boss_id>_<đòn>.mp4 (chờ → tốc độ thật → chậm 0,5×)
python tool/render/report_video.py <mục> build/videos/<file>.mp4="<chú thích>" …
```
- Giữa các vòng sửa dùng bản nháp: `render.sh <boss> --video --quick` (20 khung, 6 mẫu,
  nửa độ phân giải → `video_quick/`) rồi `boss_video.py --quick <boss>` → `*_quick.mp4`
  (tengu ~3 phút thay vì ~25). Bản nháp KHÔNG nhúng báo cáo.
- Hai boss render song song được (mỗi tiến trình ~3,4 GB RAM); ba thì thiếu RAM.
- Video phải khớp sprite đang commit — đổi biên đạo/mocap là render lại.

## 3. Báo cáo `baocao_dohoa.html`

- Mục mới chèn ngay dưới `<h1>` (kiểu stack), bọc marker `<!--<tên>-start-->` …
  `<!--<tên>-end-->`; ghi ngày giờ, làm gì, commit, việc chờ duyệt.
- Ảnh **và video** nhúng base64 — không trỏ ra `build/` (gitignore).
- File vài MB: chèn bằng script / Edit theo marker, không đọc cả file.

## 4. Nghiệm thu

- `flutter test test/art/` (atlas khớp json, chân dung khớp `BossPortrait.baked`).
- Commit sprite + báo cáo cùng hạng mục; ghi bài học xuất vào `rules/dohoa/xuat.md`.
