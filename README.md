# Solo Pushing Up

Game RPG fitness: hít đất trước camera để chiến đấu. Tài liệu thiết kế nằm trong [rules/](rules/).

## Giai đoạn hiện tại: lõi đếm push-up + màn chiến đấu thô + tiến trình

- **Lõi đếm**: camera + ML Kit Pose Detection + rep engine (xong, đang chờ dữ liệu người thật để tinh chỉnh).
- **Màn chiến đấu thô** (bước 2 trong `rules/congnghe.md`): mỗi rep là một đòn, combo, chí mạng khi xuống sâu, trận giới hạn thời gian. Kỳ công 1 — Sư tử Nemea: da không xuyên thủng, rep nông / thân chưa thẳng bị chặn. Kỳ công 2 — Rồng Fafnir: giá lạnh, nghỉ quá 3 giây giữa hai rep thì đòn sau bị đóng băng (×0,5). Kỳ công 5 — Yamata no Orochi: 8 đầu × 40 HP, sát thương không tràn sang đầu sau, đứt combo thì đầu đang chém mọc lại đầy máu. Combo và giá lạnh tính theo **thời gian nghỉ thật** (từ lúc xong rep trước tới lúc bắt đầu hạ người), nên rep chậm không bị phạt. Kỳ công 12 — Thuỷ Tinh: núi dâng nước dâng, nước dâng 3,5%/giây, mỗi rep đẩy lùi 8% (đúng đợt sóng 16%), ngập 100% thì thua; các đợt sóng ⚡ nhanh 12 s → 🐢 chậm 15 s → ⏸ giữ tư thế 10 s → 💥 sâu 12 s lặp lại, đúng kiểu thì sát thương ×1,5; đợt ⏸ cứ giữ tay thẳng thân thẳng 2 giây là một đòn (`CounterSnapshot.plankHoldMs`). Giọng đọc báo đợt sóng mới. Thứ tự mở khoá: 1 → 2 → 5 → 12 (bản ra mắt). Hình ảnh tạm, chưa có art.
- **Nhân vật và hoạt hình chương 1** (`lib/art/`): vẽ hoàn toàn bằng code (CustomPainter), sân khấu chạy bằng Flame (MIT). Nhân vật hít đất theo đúng góc khuỷu tay người chơi (IK định lý cos), chống gối thì quỳ theo; mỗi rep phóng luồng sức mạnh vào sư tử, rep sâu rung màn hình, rep bị chặn thì da sư tử loé sáng và hạt dội ra; thắng lần đầu thì nhân vật khoác Áo choàng da sư tử ngay trên sân khấu. Xem thử khung hình: `ART_PREVIEW=1 flutter test test/art` → `build/art_preview/*.png`. Các kỳ công khác vẫn dùng biểu tượng tạm.
- **Tạo nhân vật**: lần đầu mở app chọn nam/nữ, tên, tuổi, chiều cao, cân nặng, màu da, 5 kiểu tóc, màu tóc. Tỉ lệ mỡ tự ước tính (Deurenberg, ±4%) hoặc tự nhập; nhân vật đầy đặn/cao thấp theo số đo. Hiện BMI (ngưỡng WHO châu Á) và khối lượng đẩy mỗi rep (chuẩn 64%, chống gối 49% cân nặng — Ebben 2011). Số đo chỉ lưu trên máy. Vẽ theo phong cách game vector (đổ bóng hai tông, mắt có tròng/chấm sáng); cả sân khấu ~1,3 ms/khung (đo trên PC, phông tĩnh vẽ sẵn thành Picture).
- **Tiến trình** (lưu bằng `shared_preferences`): XP (2/rep, +50 khi thắng, +100 lần đầu qua kỳ công; Tân binh ×0,7), cấp (cần 100 + 50·(cấp−1) XP), vật phẩm khi qua kỳ công lần đầu, kỳ công sau mở khi xong kỳ công trước.

```
lib/
  art/vector_style.dart     Phong cách game vector: viền, đổ bóng hai tông, viền sáng (không dùng Path.combine)
  art/hero_pose.dart        Bộ xương nhân vật + IK chống đẩy theo góc khuỷu tay thật
  art/hero_art.dart         Vẽ người kế nhiệm theo ngoại hình (nam/nữ, béo/gầy, cao/thấp, da, tóc) + Áo choàng da sư tử
  game/player_profile.dart  Hồ sơ: tuổi, chiều cao, cân nặng, BMI (ngưỡng châu Á), % mỡ (Deurenberg), sức nâng mỗi rep
  ui/character_creator_screen.dart  Màn tạo/sửa nhân vật, xem trước có hoạt hình
  art/lion_art.dart         Vẽ Sư tử Nemea (thở, đuôi, gầm, trúng đòn, da loé sáng, gục)
  art/nemea_scene.dart      Phông nền Thung lũng Nemea
  art/nemea_stage.dart      Sân khấu Flame: nhân vật, đòn đánh (Effect), hạt (Particle)
  game/battle.dart          Logic trận đấu (Dart thuần): máu, combo, chí mạng, giáp
  game/labors.dart          Danh sách kỳ công: kẻ thù, cơ chế, phần thưởng
  game/progress.dart        XP, cấp, vật phẩm, mở khoá (Dart thuần)
  game/progress_store.dart  Lưu tiến trình vào shared_preferences
  session/workout_session.dart  Phiên tập: camera/giả lập → bộ đếm → âm báo, quyền camera
  ui/home_screen.dart       Màn hình chính: chọn chế độ, vào trận, vào chế độ đếm (debug)
  ui/battle_screen.dart     Màn chiến đấu thô
  pose/pose_frame.dart      Khớp, toạ độ, độ tin cậy (không phụ thuộc ML Kit)
  pose/pose_camera.dart     Camera + ML Kit → PoseFrame
  rep/one_euro_filter.dart  Lọc rung cho góc khớp
  rep/pushup_counter.dart   Rep engine: máy trạng thái đếm push-up
  ui/counter_screen.dart    Màn hình prototype + thông số debug
  ui/skeleton_painter.dart  Vẽ khung xương lên camera
test/rep/                   Test rep engine bằng dữ liệu tư thế giả lập
```

## Chạy

```bash
flutter test                  # test rep engine, không cần điện thoại
flutter run --profile         # chạy trên Android, đo FPS đúng thực tế
flutter run                   # chế độ debug, chậm hơn nhưng hot reload được
```

Bản debug chạy chậm hơn đáng kể so với bản profile/release, nên đo FPS và độ trễ bằng `--profile`.

## Tính năng của lõi đếm

- **Đọc số rep bằng giọng tiếng Việt + âm thanh + rung** (`lib/feedback/rep_feedback.dart`): đọc "một, hai, ba…" và nhắc "Duỗi thẳng chân" / "Giữ thân thẳng" khi rep bị từ chối; máy không có giọng Việt thì bíp. Nút loa ở bảng thông số đổi vòng: giọng đọc → bíp → tắt. Tiếng bíp tổng hợp bằng `tool/gen_sounds.py` (không vướng bản quyền).
- **Thuật toán đếm** (`lib/rep/pushup_counter.dart`): điểm đảo chiều đỉnh/đáy tương đối; bắt đầu đếm khi giữ tay thẳng hoặc khi thấy 3 rep liên tiếp (tính bù); tự nhận biết góc chính diện; bỏ qua co duỗi tay khi đứng/quỳ nghỉ, khi đổi người, khi khớp nhận nhầm. Chi tiết và số liệu: [rules/hoanthien_core.md](rules/hoanthien_core.md).
- **Nhắc giữ thân thẳng**: võng/chổng nhẹ thì vẫn tính rep kèm nhắc; chỉ từ chối khi sai rõ ràng.
- **Kiểm tra đặt máy** (`lib/rep/setup_check.dart`): lúc chuẩn bị, hiện bảng: thấy người, thấy rõ vai–khuỷu–cổ tay, không sát mép, khoảng cách, góc máy (cảnh báo nếu chính diện), ánh sáng. Lọc nhấp nháy qua 15 khung.
- **Độ sâu theo từng người**: sau 2 rep hợp lệ, ngưỡng đủ sâu siết theo thói quen của người tập (người hay xuống 70° thì rep chỉ tới 105° bị coi là nông). Tắt bằng `PushupConfig(adaptive: false)`.
- **Quyền camera**: từ chối thì hiện nút Mở Cài đặt / Thử lại / Dùng giả lập, không hỏi lặp lại.
- **Xoay ngang** được phép (phòng nhỏ chỉ đặt máy nằm ngang được).
- Bảng thông số có thêm thời gian xử lý ML Kit mỗi khung và ngưỡng đang dùng.

## Chế độ Giả lập

Nút 🤖 trên thanh công cụ: một người ảo hít đất theo kịch bản (chuẩn, nhanh, chậm, sâu, nông, quỳ gối, võng hông, rung nhiễu, mất dấu, chuẩn bị lộn xộn, giữ plank) thay cho camera. Mỗi kịch bản hiện kết quả mong đợi để đối chiếu, và đều có unit test (`test/sim/`). Dùng để thử giao diện, luồng ghi bản ghi, hoặc demo khi không tiện tập. Bản ghi tạo từ giả lập có `source: simulator:…`, đừng trộn vào `dataset/recordings`.

## Ghi chú kỹ thuật

- **Camera Android dùng `camera_android` (Camera2)** thay cho mặc định `camera_android_camerax`: bản CameraX 0.7.5 crash `Unsupported value: ProcessCameraProvider` khi khởi tạo lại camera (sau khi xin quyền, quay lại từ nền, đổi camera). Xem flutter/flutter#176687, #180497.
- **Độ phân giải camera `low`**: khoảng 19 FPS so với 9–11 FPS ở `medium` trên OPPO CPH2159 (bản profile).

## Đặt máy

**Khuyên dùng: dựng điện thoại đứng trên sàn, trước mặt**, cách bàn tay 0,6–1 m, camera thấy đầu, vai và hai tay (như Pushup RPG). Người chơi vừa tập vừa xem được trận đấu và thanh độ sâu. Ở góc này bộ đếm dùng độ sâu vai–cổ tay thay cho góc khuỷu (rules/hoanthien_core.md A20). Đặt chéo hoặc ngang vẫn đếm được (app nhắc nhẹ), nhưng người chơi khó nhìn màn hình; góc ngang kiểm tra form (thân thẳng, quỳ gối) tốt hơn vì thấy được chân.

## Công cụ test độ chính xác

Mọi bản ghi đều là file JSON chứa toạ độ các khớp theo thời gian, kèm **số rep thật** (đáp án). Chạy lại các bản ghi qua rep engine sau mỗi lần chỉnh code thì biết ngay độ chính xác tăng hay giảm, không cần tập lại.

```
dataset/recordings/*.json   ← bản ghi (từ app hoặc từ video)
        │
        ▼
dart run tool/replay.dart   → bảng sai số từng set + độ chính xác tổng
```

### Cách 1: Ghi ngay trong app (khuyên dùng, đúng model ML Kit thật)

1. Bấm nút **●** đỏ trên thanh công cụ. Số đếm reset về 0, chữ **REC** hiện lên.
2. Tập một set như bình thường.
3. Bấm **■** để dừng. Nhập **số rep bạn thực sự làm**, chọn góc máy, khoảng cách, ánh sáng, tốc độ, rồi **Lưu**.
4. Cắm điện thoại vào máy tính, lấy bản ghi về:

   ```powershell
   powershell -ExecutionPolicy Bypass -File tool/pull_recordings.ps1
   ```

   Script chỉ lấy file mới, file đã có trong `dataset/recordings` thì bỏ qua.

### Cách 2: Trích từ video (quay bằng camera thường, hoặc video có sẵn)

Cài một lần:

```powershell
py -3.12 -m venv tool/.venv
tool/.venv/Scripts/python -m pip install -r tool/requirements.txt
```

Trích (lần đầu tự tải model khoảng 9 MB vào `tool/models/`):

```powershell
tool/.venv/Scripts/python tool/extract_pose.py video.mp4 --expected 15
tool/.venv/Scripts/python tool/extract_pose.py a.mp4 b.mp4 --mode knee --tag angle=chéo --tag light=tối
```

Lưu ý: MediaPipe trên máy tính gần giống nhưng không y hệt ML Kit trong app. Dùng để có thêm nhiều tình huống test, còn con số chính xác cuối cùng nên dựa trên bản ghi từ app.

### Chạy lại và đọc kết quả

```powershell
dart run tool/replay.dart                       # mọi bản ghi trong dataset/recordings
dart run tool/replay.dart --verbose             # in từng rep: thời gian, góc nhỏ nhất, loại rep
dart run tool/replay.dart --min-accuracy 0.95   # exit code 1 nếu dưới 95%
```

| Cột | Ý nghĩa |
|---|---|
| Thật / Đếm / Lệch | Số rep thật, số app đếm, chênh lệch (+ thừa, − thiếu) |
| Nông | Số lần hạ người chưa đủ sâu (không tính) |
| Quỳ / Thân | Số rep bị từ chối vì quỳ gối ở chế độ Chiến binh / thân không thẳng |

Chỉ số tổng: **độ chính xác** = 1 − tổng rep đếm sai / tổng rep thật; **lệch ≤1** là tỉ lệ set đếm sai không quá 1 rep (chỉ số OBO trong các bài báo).

### Dữ liệu công khai và đánh giá ML Kit thật

Kế hoạch, kết quả và giấy phép từng bộ dữ liệu: [rules/hoanthien_core.md](rules/hoanthien_core.md). Nguồn tải: [dataset/public/README.md](dataset/public/README.md).

```powershell
# Dò tham số trên split=train, báo kết quả split=test (tránh overfit)
dart run tool/sweep.dart dataset/public/repcount/recordings

# Đếm thuần (chấp nhận cả chống gối) vs nghiêm, chỉ tập test
dart run tool/replay.dart dataset/public/repcount/recordings --where split=test --mode knee

# Bộ Mendeley (quay đồng thời 3 góc): so góc chéo/chính diện với góc ngang
dart run tool/consistency.dart dataset/public/mendeley_form/recordings --verbose

# Đánh giá bằng đúng ML Kit trên điện thoại
tool/.venv/Scripts/python tool/export_frames.py dataset/public/repcount/labels.csv --where split=test
powershell -ExecutionPolicy Bypass -File tool/push_eval.ps1          # Android 14+: thêm -Internal (bản debug)
#   trong app: 🤖 → Đánh giá ML Kit trên ảnh mẫu (hoặc "model accurate" để so sánh)
powershell -ExecutionPolicy Bypass -File tool/pull_recordings.ps1 -Folder recordings_eval -Out dataset/mlkit_eval
dart run tool/replay.dart dataset/mlkit_eval --where split=test --mode knee
```

## Tinh chỉnh

Mọi ngưỡng nằm trong `PushupConfig` (`lib/rep/pushup_counter.dart`). Màn hình có hiện góc khuỷu tay, góc thân, tư thế, FPS để dò ngưỡng. Các giá trị mặc định chỉ là ước lượng ban đầu. Quy trình chỉnh:

1. Ghi khoảng 10–20 set với các điều kiện khác nhau (xem ma trận biến số trong `rules/kehoach-mayao.md` mục 2).
2. `dart run tool/replay.dart --verbose`, xem set nào lệch và góc khuỷu tay nhỏ nhất của từng rep.
3. Sửa ngưỡng trong `PushupConfig`, chạy lại bước 2 để so sánh.

## iOS

Đã bật nền tảng iOS và quyền camera, nhưng phải build trên máy Mac có Xcode.
