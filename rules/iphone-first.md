# iPhone-first (quyết định 11/10/2026)

App thiết kế cho iPhone trước, Android theo sau. Mọi màn hình, hiệu ứng và
âm thanh mới phải đúng trên iPhone trước khi coi là xong.

## 1. Máy mục tiêu

| Vai trò | Máy | Kích thước logic |
|---|---|---|
| Mốc tối thiểu (hiệu năng) | iPhone 11 / A13 | 414 × 896 pt |
| Màn nhỏ nhất phải vừa | iPhone SE (gen 2–3) | 375 × 667 pt, không tai thỏ |
| Màn phổ biến | iPhone 13–16 | 390–393 × 844–852 pt, Dynamic Island |
| Màn lớn | iPhone Pro Max / Plus | 428–440 × 926–956 pt |

- iOS tối thiểu **15.5** (ML Kit pose yêu cầu). `ios/Podfile`, `project.pbxproj`.
- Chỉ nhắm iPhone (`TARGETED_DEVICE_FAMILY = 1`). iPad làm sau, nếu có.
- Android (OPPO CPH2159) là máy đo hằng ngày khi chưa có iPhone; số đo
  hiệu năng trên đó là mốc dưới, không thay cho đo iPhone.

## 2. Bố cục

- Mọi màn bọc `SafeArea` (tai thỏ, Dynamic Island, thanh Home). Không đặt
  `padding` riêng cho `ListView` mà thiếu `SafeArea` (mất phần chừa thanh Home).
- Hỗ trợ cả **dọc và ngang** (người dùng phòng nhỏ đặt máy nằm ngang). Không
  dùng toạ độ cố định chỉ đúng khi dọc; dùng `LayoutBuilder` và chia bố cục
  dọc/ngang (xem `_buildStaged` trong `lib/ui/battle_screen.dart`: ngang thì
  sân khấu trái, camera phải).
- Chiều cao ngang của iPhone chỉ ~350 pt sau SafeArea — mọi thứ trong trận
  phải vừa trong đó.
- Chữ trạng thái luôn sáng (app nền tối): `SystemUiOverlayStyle.light`
  (đặt sẵn trong `lib/main.dart`).

## 3. Cử chỉ và điều hướng

- iOS vuốt từ mép trái để quay lại. Màn đang tập (trận đấu) dùng `PopScope`
  chặn cử chỉ khi đang đánh; nút ✕ vẫn rời ngay. Màn mở lần đầu bắt buộc
  hoàn thành dùng `fullscreenDialog: true`.
- Không dựa vào nút Back cứng (iPhone không có).

## 4. Camera và ML Kit trên iOS

- Luồng ảnh `bgra8888`, một plane, truyền `bytesPerRow`.
- camera_avfoundation đã xoay luồng ảnh theo hướng máy và lật gương camera
  trước → gửi ML Kit `rotation0deg`, không đảo kích thước ảnh, khung xương
  không lật thêm (`PoseCamera.overlayNeedsMirror`).
- Simulator không có camera và ML Kit không có lát arm64 cho simulator: mọi
  kiểm thử đếm rep chạy trên iPhone thật.
- **Cần soát trên iPhone thật** (chưa làm, cần máy Mac + iPhone): xoay dọc/ngang,
  khung xương khớp người, kiểm tra vị trí đứng (`setup_check.dart`).

## 5. Âm thanh và rung

- Phiên âm thanh iOS `playback` + `mixWithOthers` cho cả tiếng bíp
  (audioplayers) và giọng đọc (flutter_tts): **không được tắt nhạc** người
  dùng đang nghe khi tập (`RepFeedback._configureIosAudio`).
- Rung dùng `HapticFeedback.lightImpact/mediumImpact/heavyImpact/selectionClick`
  (Taptic Engine). Không dùng `HapticFeedback.vibrate` trên iOS (rung hệ
  thống dài ~0,4 s).
- Tốc độ đọc flutter_tts: 0,5 là bình thường trên cả iOS và Android.

## 6. Hiệu năng

- Ngân sách ở `rules/dohoa.md` mục 6: GPU tô ≤ 16 ms/khung trên iPhone 11.
- `CADisableMinimumFrameDurationOnPhone = true` cho phép 120 Hz trên iPhone
  ProMotion; game không bắt buộc 120 fps, nhưng không được giật dưới 60.
- iOS dùng Impeller (Metal): tránh `saveLayer` toàn màn hình và chế độ trộn
  đắt mỗi khung, như trên Android.
- Đo: `flutter run --profile -t lib/dev/perf_bench_main.dart` trên iPhone
  thật, đọc log `BENCH`.

## 7. Font

- Không dùng tên font chỉ có trên Android (`monospace`, `Roboto`…). Cột số
  thẳng hàng dùng `FontFeature.tabularFigures()`.

## 8. Build

- Cần máy Mac + Xcode để build iOS; đặt `DEVELOPMENT_TEAM` trong Xcode trước
  khi cài lên iPhone. `cd ios && pod install` sau `flutter pub get`.
- Bundle id: `com.solopushingup.soloPushingUp`.
