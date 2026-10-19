# Phòng Vào game (Flutter: BossArt, sân khấu, shader, hiệu năng)

Code: `lib/art/`, `lib/game/`, `shaders/`, `test/art/`. Skill: `vector-game-art`
(bản vector 2.5D), `boss-mechanic` (cơ chế + game feel), `workout-hud`.

**Quy tắc chính**
- Ngân sách: GPU tô ≤ 16 ms/khung trung bình (p90 ≤ 20 ms) trên máy tầm trung,
  ghi lệnh vẽ ≤ 5 ms; đo bằng `perf_bench_main.dart` trên máy thật.
- Code vector 2.5D là một chế độ thật (công tắc 2.5D ↔ 3D), không phải tạm:
  hình mới cần cả bản vector.
- Shader vẽ vào ảnh nhỏ cố định, luôn có đường lui; không chép Shadertoy.

## Ngân sách hiệu năng (cũ: mục 2)

6. **Ngân sách hiệu năng (đổi 11/10/2026 tối, đo trên máy thật)**:
   - **Chính:** trên máy tầm trung (mốc tối thiểu: OPPO CPH2159 / Snapdragon 720G; iPhone: iPhone 11 / A13 trở lên), bản profile, trận đầy đủ: GPU tô (raster) **≤ 16 ms/khung trung bình, p90 ≤ 20 ms**; ghi lệnh vẽ (build) **≤ 5 ms**. Đo bằng `lib/dev/perf_bench_main.dart` (`flutter build apk --profile -t lib/dev/perf_bench_main.dart`, đọc log `BENCH`; iOS: `flutter run --profile -t lib/dev/perf_bench_main.dart`).
   - **Lưới chặn hồi quy trên PC:** `test/art/perf_budget_test.dart`, ghi lệnh vẽ < 3 ms/khung — chỉ bắt chậm đi rõ rệt, không thay cho đo máy thật.
   - Lý do đổi: đo trên máy thật cho thấy nút cổ chai là GPU tô hình (38,6 ms/khung khi lớp tĩnh còn là vector), trong khi test PC chỉ đo bước ghi lệnh.
   - Cách giữ ngân sách: phần tĩnh → `RasterLayer` (chụp thành ảnh một lần); tránh `saveLayer` toàn màn hình và chế độ trộn `multiply/softLight/screen` mỗi khung; không `Path.combine` mỗi khung.

## Kỹ thuật sân khấu (11/10) (cũ: mục 4)

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

## Shader (cũ: mục 6)

**Shader (`lib/art/stage_shaders.dart`, `shaders/*.frag`):**
- Luôn vẽ vào ảnh nhỏ cố định (`ShaderLayer`, ~200×60–130) rồi phóng lên sân
  khấu, cập nhật ~30 lần/giây. Lý do: toạ độ `FlutterFragCoord` không phụ
  thuộc camera/saveLayer, và GPU chỉ tô vài chục nghìn điểm ảnh.
- Hiệu ứng mềm (sương, cực quang, vân nước) hợp độ phân giải thấp; không dùng
  cách này cho nét sắc.
- Phải có đường lui: `ShaderLayer.ready == false` thì vẽ bản vector hoặc bỏ qua.
- Không chờ lại `Future` nạp shader của lần vào trận trước (test treo / màn đen).
- Không chép shader Shadertoy (giấy phép mặc định CC BY-NC-SA); tự viết.

## Công tắc đồ hoạ 2.5D ↔ 3D (14/10/2026) (cũ: mục 9)

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

## BossArt chương Nhật: hiệu ứng, phông, vector 2.5D (cũ: mục 13)

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
