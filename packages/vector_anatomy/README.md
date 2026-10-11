# vector_anatomy

Hình học giải phẫu cho đồ hoạ vector vẽ bằng code (Flutter `Canvas`). Thư viện
chỉ **tạo `Path`**; tô màu, đổ bóng, viền do app quyết định.

- `smoothPath` — đường Catmull-Rom đi qua mọi điểm (hữu cơ hơn nối cong bậc 2).
- `taperedStroke` — nét mực thon hai đầu (dày giữa, mảnh đầu) dạng Path kín.
- `LimbFrame` — toạ độ (t dọc chi, s ngang chi) bám tư thế; phía trước theo
  hướng nhân vật nhìn (`facing`).
- `MuscleProfile` + `Groove` + `buildLimb` — đường bao mặt trước / sau độc lập
  và rãnh tách nhóm cơ.
- `HumanAnatomy`, `FelineAnatomy` — profile dựng sẵn (cánh tay, cẳng tay, đùi,
  cẳng chân người; chân trước / sau mèo lớn).

Nguyên tắc: mỗi chi một mặt gần thẳng, một mặt cong; đỉnh phồng hai mặt lệch
độ cao; thon về đầu mút; rãnh đi từ mép vào (khối chồng khối).

```dart
final arm = buildLimb(shoulder, elbow, HumanAnatomy.upperArm,
    facing: const Offset(1, 0), scale: 1.2);
canvas.drawPath(arm.outline, skinPaint);
for (final g in arm.grooves) canvas.drawPath(g, darkSkinPaint);
```

Test: `cd packages/vector_anatomy && flutter test`.
