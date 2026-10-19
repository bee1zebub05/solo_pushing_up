---
name: boss-motion
description: Phòng Chuyển động của Solo Pushing Up — làm đòn đánh / cử chỉ boss: biên đạo theo võ thuật (tool/motion/choreo/*.json, một nguồn cho Blender và Flutter) và thân từ mocap võ học THẬT (CMU + Kyokushin CC0, video) kiểu Shadow Fight, ghép bằng mô hình học chuyển động (tool/motion/mocap/model.py), retarget lên rig Blender (khớp, cổ tay, cổ chân, ngón tự nhiên), tay vũ khí theo biên đạo. Dùng khi đòn boss "cứng / thô / như robot / không ra võ", khi thêm đòn cho boss mới, sửa khoá biên đạo, có video võ thuật muốn đưa vào boss, hoặc cần huấn luyện lại mô hình chuyển động.
---

# Phòng Chuyển động: biên đạo + mocap võ học

Quy tắc + bài học: `rules/dohoa/chuyendong.md`. Skill này là QUY TRÌNH.
Nhận từ phòng Dựng hình (`blender-character`): rig + dáng chờ đã duyệt. Bàn
giao cho phòng Render & xuất (`render-export`): `tool/motion/choreo/<id>.json`
+ `art_src/mocap/moves/<boss>_<move>.npz` + lớp `<Boss>Motion`. Cơ chế (báo
trước, cách né) theo `boss-mechanic`.

## A. Biên đạo (mọi boss, kể cả không phải người)

- **Biên đạo trước, code sau:** tra võ thuật của binh khí (thế thủ có tên,
  bước chân, zanshin), viết khoá vào `tool/motion/choreo/<id>.json` — mỗi boss
  ≥ 2 đòn, mỗi đòn có dấu hiệu báo trước riêng đọc được ở dạng bóng. Đòn = cả
  người: trọng tâm dịch/hạ, bước chân (IK bám đất), hông dẫn → thân → tay → vũ
  khí (`lag`), khựng lúc chạm, zanshin, phần phụ (cánh, tua) theo sau.
- Ba tư thế khoá (lấy đà / chạm / thu) đọc được ở DẠNG BÓNG từ góc game; vũ
  khí thò ra khỏi bóng thân. Khoá lặp lại cùng giá trị = giữ.
- Nhịp theo `AttackPose`: lấy đà 0–0,5, ra đòn 0,5–0,65, thu về 0,65–1
  (`lib/art/motion.dart`); mốc `impact` trong JSON canh hiệu ứng.
- Lớp chuyển động của boss nằm ở `tool/motion/<boss>_motion.py` (`OniMotion`,
  `TenguMotion`): `pose(move=, phase=)` / `pose(t=)`. File dựng hình chỉ dựng.
- Sau khi sửa JSON: `python tool/motion/gen_choreo.py` (bản vector Flutter đọc
  cùng biên đạo) + `flutter test test/art/choreo_test.dart`.
- Soát bằng tấm tư thế khoá TRƯỚC khi xuất sprite (`--still --game` →
  `python -I tool/render/keysheet.py …`); hướng vũ khí sai thì in số đo, đừng đoán.

## B. Mocap võ học (boss hình người)

### 0. Nguyên tắc

1. **Giấy phép trước tiên.** Chỉ CMU (thương mại OK) và Kyokushin figshare
   (CC0). Nguồn mới: đọc giấy phép, ghi vào `tool/motion/mocap/manifest.json` /
   `segment.py`. Cấm: Bandai Namco (NC-ND), AMASS, mọi thứ "research only".
   Video: chỉ video người dùng quay hoặc giấy phép mở — không tải YouTube.
2. **Boss quay về đối thủ** (oni −72°, tengu −55°), mắt nhìn Hercules.
3. **Hai lớp:** thân (hông, cột sống, chân, đầu, tay không vũ khí, ngón) từ
   mocap; tay vũ khí theo biên đạo `tool/motion/choreo/<boss>.json`. Mốc sân
   khấu (`impact`, `hold_from`, `hold_to`) trong `moves.json` PHẢI trùng biên đạo.
4. **Cơ học thân khớp đòn vũ khí:** đòn nện kèm dậm → oi-zuki (bước dồn);
   quét bằng hông → gyaku-zuki; chém nhanh → oi-zuki nhẹ. Kiếm CMU nghiệp dư —
   tránh. Ghi lý do vào `_why`.

### 1. Chọn đòn mocap

```bash
python tool/motion/mocap/fetch.py                 # CMU (một lần)
python tool/motion/mocap/karate_prep.py           # Kyokushin: Karate.zip → npz (một lần)
python tool/motion/mocap/segment.py               # thư viện đòn + index.json
python tool/motion/mocap/segment.py 135_09 out.png --sheet   # soát một clip: in đòn + tấm người que
python tool/motion/mocap/preview.py <clip.bvh|.npz> out.png --from 1 --to 3
```
Lọc `art_src/mocap/_cache/strikes/index.json` theo `eff` (chi), `level`
(jodan/chudan/gedan), `arc` (thrust/swing/down/up), `peak` (m/s), `src`.
Ghi vào `art_src/mocap/moves.json`: `clip`, `eff`, `at` (giây chạm), `events`,
`in`/`out` (khoảng mô hình tự điền), `mirror`.

### 2. Ghép + retarget

```bash
bash tool/blender/render.sh <boss> --mocap-ready              # dáng chờ → art_src/mocap/ready/
tool/.venv-ml/Scripts/python tool/motion/mocap/compose.py <boss> --sheet   # → art_src/mocap/moves/*.npz + .png
ONI_MOVE=attack bash tool/blender/render.sh oni_boss --still --game --quick
python -I tool/render/keysheet.py build/blender/oni/keys attack out.png 5
```
- Xem `.png` người que trước: vào tấn tự nhiên chưa, thu về dáng chờ có giật
  không (nới `in`/`out`), điểm "lạ" (max > 3 = đoạn nối gượng).
- Boss mới: thêm `mocap()/apply_mocap()` như `OniMotion` (StandPoser/MPFB) hoặc
  `TenguMotion` (Tripo); Tripo thiếu ngón → `tripo_kit.add_fingers(m, rig, s)`.

### 3. Soát (bắt buộc trước khi đưa người dùng)

- Chân bám đất ở pha chạm (debug: in `foot z` vs đích; với không tới → hạ hông).
- Tay vũ khí: hướng vũ khí lúc chạm về phía Hercules; nếu lệch, kiểm dấu
  `yaw_mocap − twist`.
- Ngón: nắm đấm/nắm cán khi lấy đà→chạm, thả lỏng khi thu.
- Critic "mắt lạ" (agent `critic` MỚI mỗi vòng, đưa tấm tư thế khoá + video +
  mô tả đòn, không nói ai làm) — lặp tới ≥ 8/10. Chỉ sửa ý lặp lại ≥ 2 vòng;
  chốt bản điểm cao nhất.
- Bản chốt → `render-export`: xuất sprite, render lại video, nhúng vào
  `baocao_dohoa.html` — video phải khớp sprite đang commit.

### 4. Huấn luyện lại mô hình

```bash
python tool/motion/mocap/dataset.py                                  # → _cache/dataset_30.npz
tool/.venv-ml/Scripts/python tool/motion/mocap/model.py train --steps 20000
tool/.venv-ml/Scripts/python tool/motion/mocap/model.py eval         # so với nội suy tuyến tính
```
- KHÔNG render Blender (Cycles GPU) cùng lúc — dùng `BLENDER_CPU=1` hoặc đợi.
- FP32 mặc định (`MOTION_BF16=1` mới bật bf16).
- Đạt khi `eval` thắng nội suy tuyến tính ở mọi độ dài che.

### 5. Video → mocap (khi có video)

MediaPipe Pose Landmarker (đã có `tool/extract_pose.py`, model trong
`tool/models/`) cho 33 điểm thế giới → map sang 24 điểm khung chuẩn
(vai/khuỷu/cổ tay/hông/gối/cổ chân/gót/mũi chân/ngón trỏ/ngón cái) → khử nhiễu
bằng `Model.fill` (che khung tin cậy thấp) trước khi đưa vào thư viện. Mạnh
hơn (cần GPU ≥ 8 GB + đăng ký SMPL): GVHMR, WHAM.
