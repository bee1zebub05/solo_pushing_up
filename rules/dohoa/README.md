# Đồ hoạ: bốn phòng theo đường ống

Đồ hoạ đi qua bốn công đoạn. Mỗi phòng có code, skill và file quy tắc riêng;
giữa hai phòng là một **đầu ra bàn giao** cố định — phòng sau chỉ đọc đầu ra
đó, không với vào code của phòng trước.

```
Dựng hình ──(rig + dáng chờ đã --review)──▶ Chuyển động ──(choreo.json + moves/*.npz)──▶
Render & xuất ──(assets/sprites, backdrops, portraits + mục báo cáo)──▶ Vào game
```

| Phòng | Quy tắc | Code | Skill |
|---|---|---|---|
| Chung | [phongcach.md](phongcach.md) | — | `vector-game-art` (phong cách vector) |
| Dựng hình | [dunghinh.md](dunghinh.md) | `tool/blender/` (`kits/`, `characters/`, `scenes/`, `tripo_view.py`) | `blender-character` |
| Chuyển động | [chuyendong.md](chuyendong.md) | `tool/motion/` (`choreo*`, `mocap_drive.py`, `<boss>_motion.py`, `motion_review.py`, `mocap/`) + phía game: `lib/art/motion.dart`, `lib/art/bosses/choreo*.dart`, tư thế bản vector 2.5D | `boss-motion` |
| Render & xuất | [xuat.md](xuat.md) | `tool/render/` | `render-export` |
| Vào game | [vaogame.md](vaogame.md) | `lib/art/` (trừ phần chuyển động), `lib/game/`, `shaders/` | `boss-mechanic`, `vector-game-art`, `workout-hud` |

Critic "mắt lạ" (chấm 1–10 ảnh/video mà không biết ai làm) là agent
`.claude/agents/critic.md` — dùng chung cho cả bốn phòng, mỗi vòng gọi mới.

## Ghi bài học vào đâu

- Bài học thuộc **một** phòng → file của phòng đó, mục có ngày.
- Bài học máy kiểm được → thêm vào `review_kit` / test thay vì chỉ ghi chữ.
- Thay đổi đồ hoạ nào cũng ghi `baocao_dohoa.html` (xem [xuat.md](xuat.md), mục báo cáo).
- Lịch sử theo ngày: [nhatky.md](nhatky.md).

## Bảng tra số mục cũ

Trước 19/10/2026 mọi thứ nằm trong một file `rules/dohoa.md` đánh số 1–17
(báo cáo HTML, commit và ghi chú cũ còn trỏ "dohoa.md mục N"). Mỗi mục mới
ghi "(cũ: mục N)" trong tiêu đề.

| Mục cũ | Nội dung | Nay ở |
|---|---|---|
| 1, 3 | Quan sát Kingdom Rush, nguồn | phongcach.md |
| 2 | Nguyên tắc (1–5) / ngân sách hiệu năng (6) | phongcach.md / vaogame.md |
| 4 | Bớt "trẻ con" / kỹ thuật sân khấu 11/10 | phongcach.md / vaogame.md |
| 5 | Nghiên cứu skill, lý thuyết thiết kế | phongcach.md |
| 6 | Chuẩn chuyển động boss / shader | chuyendong.md / vaogame.md |
| 7 | Chuyển sang Blender, tranh tham khảo / script, tài sản chương 1 / sprite, ảnh chụp sẵn | phongcach.md / dunghinh.md / xuat.md |
| 8 | Thử phong cách RoK | phongcach.md |
| 9 | Công tắc 2.5D ↔ 3D | vaogame.md |
| 10, 11, 12 | Bộ công cụ chương Nhật, bài học oni, Tripo | dunghinh.md |
| 13 | Sprite boss Nhật / bài học đòn / Tripo cầm vật / BossArt | xuat.md / chuyendong.md / dunghinh.md / vaogame.md |
| 14, 15, 16 | Biên đạo, vòng critic, mocap võ học | chuyendong.md |
| 17 | Báo cáo đồ hoạ | xuat.md |
