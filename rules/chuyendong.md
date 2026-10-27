# Thư viện chuyển động mượt (motion kit)

Bộ công cụ làm chuyển động của quái và nhân vật sprite mượt, liền mạch, đã
duyệt ở chương 1 (7 quái Tripo3D). Dùng lại nguyên bộ cho nhân vật mới và
các chương sau.

| Phần | File | Việc |
|---|---|---|
| Biên đạo (Blender) | `tool/blender/motion_kit.py` | Khoá động tác, vòng lặp, nhịp vỗ cánh, số khung |
| Khung xương | `tool/blender/boss_kit.py` (`Rig`, `rig.up`) | Đặt xương theo đầu–ngọn, mốc xoắn riêng |
| Render + đóng atlas | `tool/render/render_sprites.sh` | 3D + 2.5D, tỉ lệ lớn nhất giữ số trang |
| Phát trong game | `lib/art/sprite_motion.dart` (`SpriteMotion`) | Đứng chờ, đòn, hoà chuyển cảnh, track |
| Soát không cần app | `tool/render/compare_motion.py`, `tool/render/game_anim.py` | Ảnh động trước/sau, ảnh động theo nhịp game |

## 1. Biên đạo một động tác

```python
from motion_kit import Move, Loop, attack_phases, idle_count, loop_frames, move_frames

READY = dict(x=0, y=0, lean=0, arm=0, weapon=0)        # dáng chờ: mọi kênh
LAG = dict(arm=0.02, weapon=0.035)                      # trễ: hông → tay → vũ khí

ATTACK = Move(READY, [                                  # (tiến độ, kênh): khoá thưa
    (0.30, dict(lean=-8, arm=-40)),                     # lấy đà
    (0.46, dict(lean=-10, arm=-46)),                    # giữ thế (khoá lặp = giữ)
    (0.56, dict(x=-14, lean=12, arm=60, weapon=1)),     # cú đánh (0,46–0,70)
    (0.66, dict(x=-15, lean=13, arm=62, weapon=1)),     # khựng
])
```

- Nội suy Fritsch–Carlson: không vọt quá khoá, vũ khí không xuyên đất.
- Cú đánh đặt trong khoảng 0,46–0,70: game dồn khung dày và không hoà khung
  ở đó (`STRIKE`, `SpriteMotion.strikeFrom/strikeTo`).
- Động tác bắt đầu và kết thúc ở READY. Game tự hoà 10% đầu/cuối với vòng
  đứng chờ, nên khoá đầu/cuối không cần khớp pha đứng chờ.

Đứng chờ là vòng lặp: viết `idle_channels(t)` bằng sin/cos của `2πt` hoặc
`Loop([...])` (Catmull–Rom vòng, nối cuối → đầu không gãy). Chuyển động phụ
(đầu, đuôi, tóc) lệch pha so với thân để không đung đưa như một khối.

Cánh vỗ: `wingbeat(t)` cho `arm`, `bend`, `sweep`, `flex`, `lift` theo số
đo chim thật — đập xuống cánh duỗi hết; nâng lên cổ tay dẫn trước, khuỷu
gập, mút cánh rủ/quặt về phía thân; ~3/5 nhịp nâng mới duỗi. Mẫu:
`stymphalia_tripo.py` (chim) và `harpy_tripo.py` (người có cánh sau lưng:
nhịp nâng gập cánh vào trong ~145° trong mặt phẳng cánh).

## 2. Số khung

| Động tác | Hàm | Mức đã duyệt |
|---|---|---|
| Đứng chờ | `idle_count(period)` | ≥ 15–16 hình/giây (chu kỳ 3 s → 48 khung) |
| Đòn 1,6 s | `attack_phases()` | ~18 hình/giây lấy đà/thu, ~40 quanh cú đánh (~40 khung) |
| Trồi lên, gục, bị vật | chia đều | ~16–20 hình/giây theo thời lượng trên sân khấu |

```python
ATTACK_PHASES = attack_phases()
anims = {
    "idle": loop_frames(lambda v: pose(rig, v), idle_channels, idle_count(2.4)),
    "attack": move_frames(lambda v: pose(rig, v), ATTACK, ATTACK_PHASES),
}
export_sprites(scene, cam, "ten_quai", anims, ..., extra={
    "idlePeriod": 2.4, "phases": {"attack": ATTACK_PHASES}})
```

Ghi `phases` cho mọi động tác có khung không chia đều; thiếu thì game chia
đều và cú đánh lệch thời điểm. Điểm bám theo khung (mũi giáo, đầu, vuốt)
ghi thêm vào `extra` dạng danh sách `[x, y]` từng khung (xem `spear_tips()`
trong `stone_tripo.py`, `head_track()` trong `harpy_tripo.py`).

Nhiều khung thì tốn trang ảnh (2048², mỗi trang ~16 MB bộ nhớ GPU khi đánh
màn đó). Chương 1: chim 1 trang, Harpy 2, quái thường 2–5, boss tới ~7.
Nhân vật có nhiều biến thể (Hydra 3 bản đầu) thì bớt khung đứng chờ trước.

## 3. Render

```bash
bash tool/blender/render.sh ten_tripo --still          # vài dáng xem nhanh trước
bash tool/render/render_sprites.sh ten_tripo:ten_atlas:2   # 3D + 2.5D, tối đa 2 (→3) trang
```

Chạy từng nhân vật một (10–40 phút mỗi con). Dừng giữa chừng trên Windows
phải dừng cả bash lẫn blender.exe; trang atlas dở dang thì chạy lại
`tool/repack_sprites.py <atlas> --scale S`.

## 4. Phát trong game

```dart
if (attackPhase >= 0) {
  SpriteMotion.action(canvas, sprite, 'attack', attackPhase,
      idleAnim: 'idle', time: time, flash: hurt, tint: tint);
} else {
  SpriteMotion.idle(canvas, sprite, 'idle', time, flash: hurt, tint: tint);
}
final tip = SpriteMotion.track(sprite, 'spearTip', attackPhase);
```

Thời lượng đòn đặt ở `BossArt.attackSeconds` (chương 1: 1,6 s); hiệu ứng
chạm theo `stage.strikeLeadMs`.

## 5. Soát không cần chạy app

```bash
python -I tool/render/compare_motion.py build/old/ten build/blender/sprites/ten OUT.webp --anim attack --seconds 1.6 --snap
python -I tool/render/compare_motion.py OLD NEW OUT.webp --anim idle --seconds 3.0 --loop
python -I tool/render/game_anim.py build/blender/sprites/ten OUT.webp --anim attack --seconds 1.6 --snap
```

Trước khi render lại, chép `build/blender/sprites/<atlas>/` ra chỗ khác để
có bản "trước" so sánh.

## 6. Lỗi đã gặp

- **Dấu kênh ngược** (đầu, chân, cánh quay sai chiều): render `--still` vài
  dáng cực trước khi render cả bộ, đổi dấu kênh trong `pose()`.
- **Xương vặn xoắn**: `Rig.set` lấy trục chiều sâu làm mốc xoắn; xương nằm
  gần song song trục đó (cánh dọc chiều sâu) bị lật khi xoay → lông dựng
  thành gai. Đặt `rig.up = {tên_xương: Vector(trục vuông góc mặt phẳng xoay)}`.
- **Bóng kép quanh cú đánh**: hai khung kề nhau cách xa mà hoà thì hiện hai
  vũ khí — để `snapStrike` (mặc định bật) và dồn khung dày ở 0,46–0,70.
- **Giật khi bắt đầu/kết thúc đòn**: vòng đứng chờ ở pha bất kỳ — dùng
  `SpriteMotion.action` (đã hoà 10% đầu/cuối), đừng gọi `sprite.draw` thẳng.
- **Vật nhỏ dính nhầm xương** (khiên dính chân, nắm tay lệch giáo): ghim
  bằng `tripo_kit.pin_to_bone`, sau `smooth_weights`.
