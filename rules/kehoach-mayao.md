# Kế hoạch: Dùng máy ảo để trải nghiệm & benchmark Pushup RPG

> Ngày lập: 2026-10-09
> Mục tiêu: hiểu sâu đối thủ (Pushup RPG: Fitness Quest, `com.pushuprpg`) mà không cần tự tập nhiều ngày; đồng thời tạo **bộ video chuẩn (ground truth)** để sau này benchmark prototype của mình.
> Liên quan: [timhieu.md](timhieu.md)

---

## 0. Nguyên tắc & giới hạn

- **Chỉ trải nghiệm và quan sát**: không decompile, không bypass SSL pinning, không sửa APK, không mua hàng thật (chỉ xem màn hình paywall).
- **Không đẩy điểm giả lên bảng xếp hạng/Arena thật**: video giả lập sẽ ảnh hưởng người chơi thật. Test duel bằng **2 máy ảo của mình kết bạn với nhau**; test Arena tối đa vài trận để xem luồng, rồi dừng.
- Dùng **guest account / email phụ**, không dùng tài khoản cá nhân.
- Kết quả trên emulator **chỉ mang tính tương đối**: model chạy CPU, FPS/độ trễ khác máy thật. Luôn có 1 lượt đối chứng trên điện thoại thật cho các kịch bản quan trọng.
- iOS Simulator **không có camera** → chỉ test bản Android.

---

## 1. Chuẩn bị môi trường (Windows)

### 1.1 Phần mềm
| Công cụ | Mục đích |
|---|---|
| Android Studio + Android Emulator | Máy ảo Android |
| System image **Google Play** (API 33/34, x86_64) | Có Play Store, có dịch ARM |
| OBS Studio (có sẵn Virtual Camera) | Phát video làm webcam ảo |
| adb (platform-tools) | Chụp màn hình, quay màn hình, log, tự động hoá |
| (tuỳ chọn) scrcpy | Xem/điều khiển màn hình emulator mượt hơn |
| Bảng tính (Excel/Google Sheets) | Ghi kết quả |

### 1.2 Tạo AVD
1. Device Manager → Create Device → **Pixel 7** (hoặc Pixel 6) → image **Google Play API 34 x86_64**.
2. Advanced: RAM 4GB+, Front camera = **Webcam0**, Back camera = Webcam0 (đổi sau nếu cần).
3. Tạo thêm 2 AVD phụ:
   - `low-end`: RAM 2GB, màn hình 720p (giả lập máy yếu).
   - `duel-b`: bản sao để làm đối thủ trong duel.

### 1.3 Nối OBS → camera emulator
1. OBS: thêm **Media Source** → chọn file video, bật Loop nếu cần; canvas 1280×720 hoặc dọc 720×1280 tuỳ video.
2. Bấm **Start Virtual Camera**.
3. Kiểm tra emulator thấy webcam:
   ```
   emulator -webcam-list -avd Pixel_7_API_34
   emulator -avd Pixel_7_API_34 -camera-front webcam0
   ```
   Nếu OBS Virtual Camera không phải `webcam0`, đổi sang `webcam1`…
4. Mở app Camera trong emulator → xác nhận thấy video OBS.
5. Fallback nếu không nhận: thử Genymotion, hoặc dùng `VirtualScene` (chỉ để kiểm tra luồng UI, không đo được rep).

### 1.4 Cài app
- Đăng nhập Play Store bằng tài khoản phụ → cài `com.pushuprpg`.
- Nếu Play Store báo "không tương thích" hoặc app bị chặn trên emulator → ghi nhận (đây cũng là dữ liệu: họ có anti-emulator không?), thử image API khác.

### 1.5 Lệnh adb hữu ích
```
adb exec-out screencap -p > shot.png          # chụp màn hình
adb shell screenrecord /sdcard/run.mp4        # quay màn hình (tối đa 3 phút)
adb pull /sdcard/run.mp4
adb logcat | findstr /i pushup                # xem log (chỉ quan sát)
adb shell pm grant com.pushuprpg android.permission.CAMERA
adb shell pm revoke com.pushuprpg android.permission.CAMERA
adb shell am force-stop com.pushuprpg
adb shell cmd battery unplug / set level 5 / reset
```
Emulator console (Extended controls hoặc `telnet localhost 5554`):
```
network speed edge     # mạng chậm
network delay 2000     # độ trễ 2s
```

---

## 2. Bộ video chuẩn (ground truth dataset)

Đây là tài sản quan trọng nhất – dùng lại cho prototype của mình.

### 2.1 Quy cách
- Đặt tên: `EX_GOC_KC_AS_NGUOI_TOCDO_REPS.mp4`
  ví dụ `PU_san-truoc_1m_sang_A_cham_15.mp4`
- 30 fps và 60 fps, 720p; quay **dọc** (giống người dùng thật).
- Mỗi video có **file đáp án**: số rep đúng, timestamp từng rep, rep nào sai form (nửa rep, không đủ sâu).
- Lưu tại `dataset/videos/` + `dataset/labels.csv`.

### 2.2 Ma trận biến số
| Biến | Giá trị |
|---|---|
| Bài tập | push-up, squat, sit-up, plank, pull-up, dips |
| Vị trí máy | dưới sàn trước mặt (khuyến nghị của họ), dưới sàn nghiêng 45°, ngang hông, trên ghế, dựng tường xa 2m |
| Khoảng cách | 0.5m, 1m, 2m, 3m |
| Ánh sáng | ban ngày, đèn trần, tối, ngược sáng (cửa sổ phía sau), đèn nhấp nháy |
| Trang phục | áo sáng, áo đen, đồ rộng, đồ bó, cởi trần |
| Nền | tường trơn, phòng bừa bộn, có người đi qua, có gương |
| Người | nam/nữ, gầy/to, cao/thấp, trẻ/lớn tuổi |
| Tốc độ | rất chậm (4s/rep), bình thường, rất nhanh (<1s/rep), không đều |
| Số rep | 5, 15, 30, 50, 100 |

Không cần quay đủ tổ hợp – chọn ~40–60 video bao phủ mỗi giá trị ít nhất 2 lần.

---

## 3. Danh sách kịch bản

Ký hiệu ưu tiên: **P0** = phải làm, **P1** = nên làm, **P2** = nếu còn thời gian.

### A. Cài đặt & Onboarding (không cần camera)
| ID | Kịch bản | Quan sát | Ưu tiên |
|---|---|---|---|
| A1 | Mở app lần đầu, đi hết onboarding | Số màn hình, thời gian tới "rep đầu tiên", có hỏi mục tiêu/level không | P0 |
| A2 | Chơi bằng guest | Bị giới hạn gì? Khi nào bị nhắc liên kết tài khoản | P0 |
| A3 | Đăng nhập Google / email | Luồng, dữ liệu được hỏi | P1 |
| A4 | Từ chối quyền camera | App xử lý thế nào, có hướng dẫn bật lại không | P0 |
| A5 | Từ chối quyền thông báo | Có hỏi lại không, lúc nào | P1 |
| A6 | Màn hình hướng dẫn đặt máy | Họ dạy setup ra sao (ảnh, video, overlay khung người) | P0 |
| A7 | Chuyển ngôn ngữ sang **Tiếng Việt** | Chất lượng dịch, lỗi font/tràn chữ | P0 |
| A8 | Đổi sang ngôn ngữ khác (JA, AR – RTL) | Layout RTL | P2 |
| A9 | Xoá tài khoản trong app | Luồng xoá, có giữ chân không | P2 |
| A10 | Gỡ cài rồi cài lại (guest) | Mất dữ liệu không | P1 |
| A11 | Đo thời gian khởi động lạnh/ấm | Hiệu năng | P2 |
| A12 | Chụp toàn bộ màn hình của app (sitemap) | Vẽ lại sơ đồ điều hướng | P0 |

### B. Độ chính xác đếm rep – Push-up (camera = video OBS)
| ID | Kịch bản | Quan sát | Ưu tiên |
|---|---|---|---|
| B1 | Push-up chuẩn, máy dưới sàn trước mặt, 15 rep | Đếm đúng? Độ trễ hiển thị | P0 |
| B2 | Như B1 nhưng 50 và 100 rep | Sai số tích luỹ, có "drift" không | P0 |
| B3 | Máy nghiêng 45° | | P0 |
| B4 | Máy nhìn ngang (side view) | | P0 |
| B5 | Khuỷu tay ra khỏi khung hình (lỗi bị chê trong review) | Miss rep? | P0 |
| B6 | Đầu ra khỏi khung hình | | P1 |
| B7 | Chỉ thấy nửa thân trên | | P1 |
| B8 | Quá gần (0.5m) / quá xa (3m) | Ngưỡng hoạt động | P0 |
| B9 | Thiếu sáng / ngược sáng | | P0 |
| B10 | Áo đen trên nền tối | | P1 |
| B11 | Tốc độ rất nhanh (<1s/rep) | Bỏ sót? | P0 |
| B12 | Tốc độ rất chậm (4s/rep) | Đếm 2 lần? Timeout? | P0 |
| B13 | Nghỉ giữa chừng 10s, 30s, 60s rồi tiếp | Có kết thúc set không | P1 |
| B14 | Knee push-up (chống gối) | Có tính không | P1 |
| B15 | Wide / diamond / decline push-up | Biến thể | P2 |
| B16 | Push-up 1 tay | | P2 |
| B17 | Thay đổi người giữa set | | P2 |
| B18 | Video 30fps vs 60fps cùng nội dung | Ảnh hưởng FPS | P1 |
| B19 | Video độ phân giải thấp (480p, nén mạnh) | | P2 |
| B20 | Video bị lật ngang (mirror) | | P2 |
| B21 | Điện thoại xoay ngang (landscape) | App có hỗ trợ không | P1 |

### C. Form & chống gian lận
| ID | Kịch bản | Quan sát | Ưu tiên |
|---|---|---|---|
| C1 | Nửa rep (xuống không đủ sâu) | Có tính không, có cảnh báo form không | P0 |
| C2 | Chỉ gật đầu lên xuống | Bị lừa không | P0 |
| C3 | Chỉ nhấc mông (hông võng / pike) | | P0 |
| C4 | Vẫy tay trước camera | | P0 |
| C5 | Đứng yên / ảnh tĩnh | Có đếm ảo không | P0 |
| C6 | Video quay màn hình một video khác (moiré) | | P1 |
| C7 | Nhân vật hoạt hình / búp bê / mô hình 3D | Có nhận người không | P2 |
| C8 | Hai người cùng hít đất trong khung | Đếm ai? | P1 |
| C9 | Có người đi ngang phía sau | Bị nhiễu? | P1 |
| C10 | Gương phía sau (2 bóng người) | | P2 |
| C11 | Rung máy (máy dựng không chắc) | | P1 |
| C12 | Hít đất trên đầu gối rồi chuyển sang chuẩn giữa set | | P2 |

### D. Các bài tập khác
| ID | Kịch bản | Ưu tiên |
|---|---|---|
| D1 | Squat chuẩn, máy chính diện / nghiêng / ngang | P0 |
| D2 | Squat nửa (không đủ sâu), squat nhảy | P1 |
| D3 | Sit-up chuẩn & crunch | P1 |
| D4 | Plank: giữ 30s, 60s; võng hông giữa chừng; đứng dậy rồi nằm lại | P1 |
| D5 | Pull-up: máy dưới sàn nhìn lên / máy xa | P1 |
| D6 | Dips trên ghế | P2 |
| D7 | Làm squat khi app đang ở chế độ push-up (sai bài) | P1 |

### E. Combat & gameplay
| ID | Kịch bản | Quan sát | Ưu tiên |
|---|---|---|---|
| E1 | Trận campaign đầu tiên | Bao nhiêu rep để thắng, feedback mỗi rep (âm thanh, hiệu ứng, rung) | P0 |
| E2 | Đo **damage/rep** và **HP quái** qua 5–10 trận đầu | Đường cong độ khó | P0 |
| E3 | Thua trận (dừng video giữa chừng) | Hình phạt? Thử lại thế nào | P0 |
| E4 | Trận có giới hạn thời gian | Số rep/giây cần thiết | P1 |
| E5 | Quái có rule modifier | Liệt kê các modifier gặp được | P1 |
| E6 | Boss đổi stance | Cơ chế cụ thể (yêu cầu đổi bài? đổi tốc độ?) | P0 |
| E7 | Endless Descent tầng 1 → 10 | Paywall xuất hiện thế nào ở tầng 10 | P0 |
| E8 | Thoát app giữa trận rồi mở lại | Trận có được lưu không | P1 |
| E9 | Đang trận thì có cuộc gọi / thông báo (giả lập) | | P2 |
| E10 | Squat campaign vs push-up campaign | Có tách tiến độ không | P1 |
| E11 | Đồ (gear) tốt hơn → damage/rep tăng bao nhiêu | | P1 |
| E12 | Ghi lại toàn bộ tên quái, biome gặp được | Hiểu world-building | P2 |

### F. Live Duel & Arena
| ID | Kịch bản | Quan sát | Ưu tiên |
|---|---|---|---|
| F1 | Duel với rival AI cố định (Ironfang Wolf…) | Nhịp độ của AI (rep/giây), UI dây kéo co | P0 |
| F2 | **2 emulator (A & B) kết bạn bằng code rồi duel** | Đồng bộ, độ trễ, kết quả | P0 |
| F3 | F2 với `network delay 2000` ở máy B | Xử lý lag | P1 |
| F4 | F2, ngắt mạng máy B giữa trận | Xử lý disconnect, ai thắng | P1 |
| F5 | F2, cả hai bằng rep → hoà? | Luật hoà | P2 |
| F6 | Squat duel | | P1 |
| F7 | Arena: vào hàng chờ, xem thời gian ghép (không đánh nhiều trận) | Độ lớn cộng đồng, matchmaking | P1 |
| F8 | Quay & share kết quả duel | Format video/ảnh share, watermark → kênh viral | P0 |
| F9 | Report / block từ result card | | P2 |

### G. Progression & kinh tế
| ID | Kịch bản | Quan sát | Ưu tiên |
|---|---|---|---|
| G1 | Ghi XP mỗi rep, XP cần để lên level 1→10 | Vẽ đường cong level | P0 |
| G2 | Gold/rep, giá đồ trong Forge | Kinh tế | P1 |
| G3 | Tỉ lệ rơi loot theo rarity (ghi 30+ lần rơi) | | P1 |
| G4 | Skill tree: liệt kê toàn bộ node & hiệu ứng | | P1 |
| G5 | Stats: mỗi điểm stat ảnh hưởng gì | | P1 |
| G6 | Forge: upgrade / reforge / salvage | | P2 |
| G7 | Companion Cinder: vai trò gì | | P2 |
| G8 | New Game+ (xem điều kiện mở) | | P2 |
| G9 | Gem dùng để làm gì, kiếm được miễn phí bao nhiêu | Áp lực mua | P0 |

### H. Retention (streak, quest, thông báo)
| ID | Kịch bản | Quan sát | Ưu tiên |
|---|---|---|---|
| H1 | Liệt kê daily/weekly quest | Nội dung, phần thưởng | P0 |
| H2 | Đổi ngày hệ thống (+1 ngày) sau khi tập | Streak/quest reset theo giờ máy hay server | P1 |
| H3 | Bỏ 1 ngày (+2 ngày) | Freeze token tự dùng? Thông báo gì | P1 |
| H4 | Bỏ nhiều ngày (+7 ngày) | Màn hình "quay lại", có ưu đãi không | P1 |
| H5 | Theo dõi thông báo đẩy trong 2–3 ngày (để emulator chạy) | Tần suất, giờ gửi, nội dung | P0 |
| H6 | Tập bài phụ (sit-up) để giữ streak | Xác nhận cơ chế | P2 |
| H7 | Widget trên home screen | | P2 |
| H8 | PAYDAY gold claim | | P2 |

### I. Social
| ID | Kịch bản | Ưu tiên |
|---|---|---|
| I1 | Xem leaderboard global/country/friends – top có bao nhiêu rep/ngày | P0 |
| I2 | Leaderboard Việt Nam: bao nhiêu người, top bao nhiêu rep | P0 |
| I3 | Tìm & xin vào guild (guest có được không) | P1 |
| I4 | Xem màn hình tạo guild (paywall Vigil) | P1 |
| I5 | Guild boss tuần: cơ chế đóng góp | P1 |
| I6 | Cheers: gửi/nhận | P2 |
| I7 | Đổi cờ quốc gia | P2 |

### J. Monetization (chỉ quan sát, không mua)
| ID | Kịch bản | Ưu tiên |
|---|---|---|
| J1 | Chụp tất cả paywall và **thời điểm** chúng xuất hiện | P0 |
| J2 | Trial 7 ngày: luồng hiển thị, nút đóng ở đâu, dark pattern? | P0 |
| J3 | Giá theo khu vực (đổi quốc gia tài khoản Play nếu được, hoặc so với số liệu iOS US) | P1 |
| J4 | Shop gem: các gói, ưu đãi lần đầu | P1 |
| J5 | Có quảng cáo không (rewarded ads?) | P0 |
| J6 | Đếm số lần app nhắc mua trong 1 phiên 20 phút | P1 |

### K. Độ bền & hiệu năng
| ID | Kịch bản | Ưu tiên |
|---|---|---|
| K1 | Chạy trên AVD `low-end` (2GB RAM) | P1 |
| K2 | Pin yếu 5% / chế độ tiết kiệm pin | P2 |
| K3 | Offline hoàn toàn: tập được không, sync lại khi online | P0 |
| K4 | Chuyển app sang nền giữa set rồi quay lại | P1 |
| K5 | Xoay màn hình giữa trận | P2 |
| K6 | Set dài 10 phút liên tục | Nóng máy/leak bộ nhớ | P2 |
| K7 | Đo CPU khi đếm rep (`adb shell top`) | P2 |

### L. Nội dung marketing & viral
| ID | Kịch bản | Ưu tiên |
|---|---|---|
| L1 | Tạo video share từ app, phân tích format (dọc? có logo? có link?) | P0 |
| L2 | Đối chiếu với video trên TikTok/YouTube @pushuprpg | P0 |
| L3 | Tìm referral/invite reward | P1 |
| L4 | Có yêu cầu đánh giá app (rating prompt) – lúc nào | P1 |

---

## 4. Mẫu ghi kết quả

### 4.1 Đếm rep (`results_reps.csv`)
| video | bài | rep_đúng | rep_app | sai_số | trễ_TB(ms) | ghi chú |
|---|---|---|---|---|---|---|
| PU_san-truoc_1m_sang_A_cham_15 | PU | 15 | 14 | -1 | 300 | miss rep 9 |

Chỉ số tổng hợp:
- **Accuracy** = 1 − |rep_app − rep_đúng| / rep_đúng
- **Tỉ lệ đếm thiếu** / **đếm thừa** tách riêng
- **False positive** ở nhóm C (gian lận) – lý tưởng = 0

### 4.2 Quan sát UX/game (`notes.md`)
- ID kịch bản → ảnh chụp → nhận xét → ý tưởng cho app mình (làm tốt hơn thế nào).

---

## 5. Lịch thực hiện đề xuất

| Ngày | Việc |
|---|---|
| 1 | Dựng emulator + OBS, xác nhận camera ảo chạy, cài app. Làm A1–A12 |
| 2–3 | Quay bộ video chuẩn (~40–60 video), gắn nhãn |
| 4 | Chạy nhóm B, C, D (P0 trước) |
| 5 | Nhóm E, F (2 emulator), G |
| 6–8 | Để emulator chạy nền: H (thông báo, streak), I, J, K, L |
| 9 | Đối chứng 30–60 phút trên điện thoại thật cho các kịch bản P0 nhóm B/E/F |
| 10 | Tổng hợp báo cáo: điểm mạnh, điểm yếu, cơ hội → cập nhật [timhieu.md](timhieu.md) |

---

## 6. Đầu ra mong đợi
1. **Bảng accuracy** của Pushup RPG theo từng điều kiện → biết chính xác họ yếu ở đâu.
2. **Bộ dataset video có nhãn** → dùng benchmark prototype của mình.
3. **Sitemap + ảnh chụp toàn bộ màn hình** của app.
4. **Số liệu game design**: đường cong XP, damage/rep, HP quái, tỉ lệ loot, kinh tế gold/gem.
5. **Bản đồ monetization**: paywall ở đâu, khi nào, giá bao nhiêu.
6. **Danh sách cơ hội** để app mình khác biệt/làm tốt hơn.

## 7. Rủi ro & phương án dự phòng
| Rủi ro | Dự phòng |
|---|---|
| App chặn emulator / Play Store báo không tương thích | Thử image API khác, Genymotion; cuối cùng dùng điện thoại Android cũ + capture card/màn hình để phát video trước camera |
| Emulator không nhận OBS Virtual Camera | Đổi webcam index, cài lại OBS, thử phần mềm virtual cam khác |
| Model chạy chậm trên CPU → accuracy thấp giả | Luôn đối chứng trên máy thật trước khi kết luận |
| Đổi ngày hệ thống không ảnh hưởng (server time) | Ghi nhận là "streak tính theo server", chờ thật 1–2 ngày |
| Tài khoản bị khoá vì nghi gian lận | Dùng tài khoản phụ, tránh Arena/leaderboard |
