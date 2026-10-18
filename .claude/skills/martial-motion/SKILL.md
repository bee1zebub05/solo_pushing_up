---
name: martial-motion
description: Làm đòn đánh boss hình người của Solo Pushing Up từ chuyển động võ học THẬT (mocap CMU + Kyokushin CC0, video) kiểu Shadow Fight / Street Fighter — chọn đòn mocap, ghép với dáng chờ boss bằng mô hình học chuyển động (tool/mocap/model.py), retarget xoay xương lên rig Blender (khớp, cổ tay, cổ chân, ngón tay, ngón chân tự nhiên), giữ tay vũ khí theo biên đạo. Dùng khi đòn boss "cứng / như robot / không ra võ", khi thêm boss hình người mới cần đòn, khi có video võ thuật muốn đưa vào boss, hoặc khi cần huấn luyện lại mô hình chuyển động.
---

# Đòn boss từ mocap võ học

Chi tiết + bài học: `rules/dohoa.md` mục 16. Skill này là QUY TRÌNH; cơ chế
(báo trước, cách né) vẫn theo `boss-mechanic`, dựng/soát hình theo
`blender-character`.

## 0. Nguyên tắc

1. **Giấy phép trước tiên.** Chỉ CMU (thương mại OK) và Kyokushin figshare
   (CC0). Nguồn mới: đọc giấy phép, ghi vào `tool/mocap/manifest.json` /
   `segment.py`. Cấm: Bandai Namco (NC-ND), AMASS, mọi thứ "research only".
   Video: chỉ video người dùng quay hoặc giấy phép mở — không tải YouTube.
2. **Boss quay về đối thủ** (oni −72°, tengu −55°), mắt nhìn Hercules.
3. **Hai lớp:** thân (hông, cột sống, chân, đầu, tay không vũ khí, ngón) từ
   mocap; tay vũ khí theo biên đạo `tool/blender/choreo/<boss>.json`. Mốc sân
   khấu (`impact`, `hold_from`, `hold_to`) trong `moves.json` PHẢI trùng biên đạo.
4. **Cơ học thân khớp đòn vũ khí:** đòn nện kèm dậm → oi-zuki (bước dồn);
   quét bằng hông → gyaku-zuki; chém nhanh → oi-zuki nhẹ. Kiếm CMU nghiệp dư —
   tránh. Ghi lý do vào `_why`.

## 1. Chọn đòn mocap

```bash
python tool/mocap/fetch.py                 # CMU (một lần)
python tool/mocap/karate_prep.py           # Kyokushin: Karate.zip → npz (một lần)
python tool/mocap/segment.py               # thư viện đòn + index.json
python tool/mocap/segment.py 135_09 out.png --sheet   # soát một clip: in đòn + tấm người que
python tool/mocap/preview.py <clip.bvh|.npz> out.png --from 1 --to 3
```
Lọc `art_src/mocap/_cache/strikes/index.json` theo `eff` (chi), `level`
(jodan/chudan/gedan), `arc` (thrust/swing/down/up), `peak` (m/s), `src`.
Ghi vào `art_src/mocap/moves.json`: `clip`, `eff`, `at` (giây chạm), `events`,
`in`/`out` (khoảng mô hình tự điền), `mirror`.

## 2. Ghép + retarget

```bash
bash tool/blender/render.sh <boss> --mocap-ready              # dáng chờ → art_src/mocap/ready/
tool/.venv-ml/Scripts/python tool/mocap/compose.py <boss> --sheet   # → art_src/mocap/moves/*.npz + .png
ONI_MOVE=attack bash tool/blender/render.sh oni_boss --still --game --quick
python -I tool/blender/keysheet.py build/blender/oni/keys attack out.png 5
```
- Xem `.png` người que trước: vào tấn tự nhiên chưa, thu về dáng chờ có giật
  không (nới `in`/`out`), điểm "lạ" (max > 3 = đoạn nối gượng).
- Boss mới: thêm `mocap()/apply_mocap()` như `OniMotion` (StandPoser/MPFB) hoặc
  `TenguMotion` (Tripo); Tripo thiếu ngón → `tripo_kit.add_fingers(m, rig, s)`.

## 3. Soát (bắt buộc trước khi đưa người dùng)

- Chân bám đất ở pha chạm (debug: in `foot z` vs đích; với không tới → hạ hông).
- Tay vũ khí: hướng vũ khí lúc chạm về phía Hercules; nếu lệch, kiểm dấu
  `yaw_mocap − twist`.
- Ngón: nắm đấm/nắm cán khi lấy đà→chạm, thả lỏng khi thu.
- Critic "mắt lạ" (agent general-purpose MỚI mỗi vòng, đưa tấm tư thế khoá +
  mô tả đòn, không nói ai làm) — lặp tới ≥ 8/10, như `blender-character`.

## 4. Huấn luyện lại mô hình

```bash
python tool/mocap/dataset.py                                  # → _cache/dataset_30.npz
tool/.venv-ml/Scripts/python tool/mocap/model.py train --steps 20000
tool/.venv-ml/Scripts/python tool/mocap/model.py eval         # so với nội suy tuyến tính
```
- KHÔNG render Blender (Cycles GPU) cùng lúc — dùng `BLENDER_CPU=1` hoặc đợi.
- FP32 mặc định (`MOTION_BF16=1` mới bật bf16).
- Đạt khi `eval` thắng nội suy tuyến tính ở mọi độ dài che.

## 5. Video → mocap (khi có video)

MediaPipe Pose Landmarker (đã có `tool/extract_pose.py`, model trong
`tool/models/`) cho 33 điểm thế giới → map sang 24 điểm khung chuẩn
(vai/khuỷu/cổ tay/hông/gối/cổ chân/gót/mũi chân/ngón trỏ/ngón cái) → khử nhiễu
bằng `Model.fill` (che khung tin cậy thấp) trước khi đưa vào thư viện. Mạnh
hơn (cần GPU ≥ 8 GB + đăng ký SMPL): GVHMR, WHAM.
