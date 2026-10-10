# Hoàn thiện lõi đếm push-up — kế hoạch, kết quả, tài nguyên

> Cập nhật: 2026-10-10. Liên quan: [model_ai.md](model_ai.md), [congnghe.md](congnghe.md), [kehoach-mayao.md](kehoach-mayao.md)

## 1. Kết quả hiện tại

Độ chính xác = 1 − (tổng rep đếm sai) / (tổng rep thật). "Test" = tập test của RepCount, **không dùng để chỉnh tham số**. Đếm thuần = chế độ Tân binh (chấp nhận cả chống gối); Nghiêm = Chiến binh.

| Bộ dữ liệu | Model pose | Đếm thuần | Nghiêm |
|---|---|---|---|
| RepCount test (14 clip, 296 rep) | **ML Kit trên điện thoại (app thật)** | **80,1%** | 75,0% |
| RepCount test | MediaPipe (máy tính) | 79,1% | 78,7% |
| RepCount toàn bộ (97 clip, 2.126 rep) | MediaPipe | **86,6%** | 85,7% |
| PushupBench (2 clip người thật) | ML Kit và MediaPipe | 100% | 100% |

Diễn biến trên RepCount toàn bộ (MediaPipe): **44% → 49% → 60% → 68% → 71% → 74% → 79% → 81% → 83% → 86,6%**.
ML Kit tập test: **67,9% → 74,0% → 77,7% → 80,1%**.

**Chống gian lận trên bộ Mendeley** (CC BY 4.0; tư thế xấu = võng hông / chổng mông):

| | Tư thế đúng: bị từ chối nhầm | Tư thế xấu: bị từ chối | Tư thế xấu: được nhắc "giữ thân thẳng" |
|---|---|---|---|
| Quay ngang | 0% | 5% | 10% |
| Quay chéo | 0% | 0% | 2% |
| Quay chính diện | 1% | 0% | 0% |

→ Không từ chối oan người tập đúng (ưu tiên số 1, vì đếm thiếu là lời chê lớn nhất về Pushup RPG). Phát hiện võng/chổng **nhẹ** từ camera 2D còn yếu, nhất là ở góc chéo/chính diện. Đây là giới hạn đã biết (mục A16).

ML Kit trên điện thoại, cùng 144 video: tư thế đúng **0% bị từ chối oan ở cả 3 góc**; tư thế xấu (quay ngang) 1% bị từ chối, 9% được nhắc.

> ⚠️ **Bộ Mendeley đã làm mờ mạnh mặt và thân người** (ẩn danh). ML Kit gần như không nhận ra người trong vùng mờ (độ tin cậy khớp ~0, ví dụ subject_007 chính diện: ML Kit đếm 1, MediaPipe đếm 14), còn MediaPipe chịu được tốt hơn. Vì vậy **không dùng Mendeley để so độ chính xác đếm giữa ML Kit và MediaPipe**, chỉ dùng cho chống gian lận (có so sánh tương đối đúng/sai trên cùng model).

> So sánh tham khảo: nghiên cứu JMIR 2026 đo được tỉ lệ phát hiện push-up trung bình chỉ 61% với camera điện thoại. Đếm theo pose trên RepCount trong các bài báo đạt khoảng OBO 0,56–0,60.

## 2. Những lỗi còn lại (đã kiểm tra bằng mắt)

| Loại | Ví dụ | Ghi chú |
|---|---|---|
| Rep rất nông nhưng vẫn được gán nhãn | stu2_53, stu4_46 (thử kỷ lục: đáy khoảng 130–140°) | **Bộ đếm từ chối là đúng thiết kế** (chống rep nông) |
| Hít đất chống gối trong nhãn push_up | stu7_45 | Chế độ Chiến binh từ chối là đúng; chế độ Tân binh đếm đúng |
| Cực nhanh + camera chính diện từ trên xuống | stu1_48 (111 rep / 57 giây) | Ở 20 FPS mỗi rep chỉ có ~10 khung, biên độ góc chỉ ~35° |
| Chân ngoài khung, ML Kit đoán bừa gối và mắt cá | stu9_52 | ML Kit gán độ tin cậy 0,9 cho khớp nằm ngoài ảnh |
| Hai người trong khung | stu9_48 | Đã có phát hiện đổi người; vẫn còn lệch |
| Đoạn không tập (nói chuyện, nghỉ) | stu3_43, stu10_42 | Đã có kiểm tra thân dựng đứng; vẫn còn đếm thừa |
| **Nhãn thiếu trong RepCount** | stu4_40: nhãn 6 rep (mốc khung 33–777), video có ~16 chu kỳ sâu rõ ràng | Một phần "đếm thừa" là lỗi nhãn → con số độ chính xác đang hơi thấp hơn thực tế |

## 3. Các cách cải tiến

Trạng thái: ✅ đã làm · 🔄 đang làm · ⏭ tiếp theo · 💡 ý tưởng sau

### A. Thuật toán đếm
| # | Cách | Trạng thái | Tác dụng đo được |
|---|---|---|---|
| A1 | Ngưỡng góc cố định (150°/100°) | ✅ ban đầu | 44% |
| A2 | Ngưỡng tự chỉnh theo người (sau 2 rep) | ✅ (đã thay bằng A3, giữ phần độ sâu cá nhân) | +5% |
| A3 | **Điểm đảo chiều đỉnh/đáy tương đối** (zigzag), đếm khi rời đáy 20° | ✅ | 60% → 74% |
| A4 | **Bắt đầu đếm theo nhịp**: 3 rep liên tiếp thì đếm và tính bù, không bắt buộc giữ tay thẳng | ✅ | Sửa lỗi mất cả set khi tập nhanh hoặc vừa mất dấu |
| A5 | Bỏ qua quỳ gối / thân thẳng khi chân/thân bị co ngắn trên ảnh (so với cánh tay trên) | ✅ | 263 rep chuẩn hết bị coi là quỳ; +3–4% |
| A6 | Chỉ xét tư thế từ đỉnh tới đáy (không tính động tác phía trên) | ✅ | PushupBench "toe tap" từ 42% lên 100% |
| A7 | Bỏ qua co duỗi tay khi thân dựng đứng (đứng, ngồi, quỳ nghỉ) | ✅ | Đếm thừa giảm 155 → 114 |
| A8 | Bỏ phiếu tư thế theo từng khung (trung vị góc thân, đa số khung quỳ) | ✅ | Chống khung nhiễu |
| A9 | Phát hiện đổi người (vai nhảy > 1,5 lần cánh tay, kích thước đổi > 70%) | ✅ | ML Kit +3% |
| A10 | Độ sâu theo từng người (trung vị đáy + 30°, trong khoảng 95–120°) | ✅ | Chặn rep nông với người quen xuống sâu |
| A11 | Góc chính diện: tự nhận biết (vai rộng > 1,5 lần cánh tay trên), nới biên độ ×0,6 | ✅ | Train 82,8% → 87,8%; test không đổi |
| A11b | Tín hiệu thứ hai cho chính diện (độ cao vai so với cổ tay, mũi) | 💡 | Nếu dữ liệu chính diện thật còn lỗi |
| A12 | Kiểm tra tính chu kỳ (tự tương quan / self-similarity) để loại đoạn không tập | 💡 | Theo hướng *Viewpoint-Invariant Exercise Repetition Counting* (arXiv 2107.13760) |
| A13 | Bộ lọc tốt hơn cho rep rất nhanh (Kalman, hoặc lọc thích nghi theo tần số) | 💡 | stu1_48 |
| A14 | Phân loại lên/xuống bằng k-NN trên khoảng cách giữa các khớp (cách của Google ML Kit, Apache-2.0) | 💡 | Cần dữ liệu tự quay, vài trăm mẫu mỗi trạng thái, nhiều góc máy |
| A15 | Model nhỏ học từ chuỗi khớp (kiểu PoseRAC, MIT) | 💡 | Chỉ được train bằng dữ liệu có giấy phép thương mại |
| A16 | Nhắc "giữ thân thẳng" khi võng/chổng nhẹ (165°), chỉ từ chối khi rõ ràng (145°) | ✅ | Không nhắc oan ai trên Mendeley |
| A17 | Loại đáy vô lý (< 25°) và chu kỳ quá ngắn (< 250 ms): nhận nhầm khớp | ✅ | ML Kit 74,7% → 77,7% |
| A18 | Chân "đoán bừa" khi ngoài khung (thứ tự vai→hông→gối→mắt cá, đùi gập vuông mà ngắn) | ✅ | ML Kit Chiến binh 70,6% → 75,0% |
| A19 | Bộ lọc nhạy hơn với chuyển động nhanh (One Euro beta 0,2) | ✅ | Test +1% cả hai model |
| A20 | **Máy đặt trước mặt** (như Pushup RPG, người chơi nhìn được màn hình): đếm bằng độ sâu = khoảng cách dọc vai–cổ tay / bề ngang vai (làm mượt), quy ra góc tương đương 180 − 200 × (1 − độ sâu tương đối), dùng lại toàn bộ máy đếm. Chỉ cần một bên vai + cổ tay. Ngưỡng nhận góc chính diện 1,2 (đo 144 clip Mendeley: ngang 0,21–0,44, chéo 0,54–0,92, chính diện 1,5–2,0) có vùng trễ (thoát dưới 0,96). Cổng "nhảy người" dùng bề ngang vai ở góc này | ✅ | 12 clip chính diện đếm tay: 87,2% → 96,5%; RepCount test 79,1% → 80,1%; ML Kit test 80,1% → 79,4% |

### B. Đo lường và dữ liệu
| # | Cách | Trạng thái |
|---|---|---|
| B1 | Bộ dữ liệu giả lập + 56 unit test | ✅ |
| B2 | Ghi bản ghi trong app, lấy về, chạy lại (`tool/replay.dart`) | ✅ |
| B3 | Trích pose từ video bằng MediaPipe (`tool/extract_pose.py`, 20 FPS giống app, chạy song song) | ✅ |
| B4 | RepCount-A: 97 clip push_up, đánh giá nội bộ (giấy phép học thuật) | ✅ |
| B5 | Chia train/test, dò tham số trên train (`tool/sweep.dart`) | ✅ |
| B6 | **Đánh giá bằng đúng ML Kit trên điện thoại** (`tool/export_frames.py` → `tool/push_eval.ps1` → nút trong app) | ✅ |
| B7 | Bộ Mendeley tư thế đúng/sai, chính diện/chéo/ngang (CC BY 4.0): 144 video; **3 góc KHÔNG quay đồng thời** (đã kiểm tra) → dùng để đo chống gian lận (`tool/form_check.dart`) | ✅ (ML Kit trên điện thoại 🔄) |
| B8 | Countix: 154 clip push-up có số rep (video YouTube, nhiều clip đã bị xoá) | 💡 chỉ đánh giá nội bộ |
| B9 | MM-Fit (video CC BY 4.0, 39 GB, có đoạn không tập) | 💡 |
| B10 | **Bản ghi người thật từ app** (nhiều góc, nhiều người) | ⏭ cần người dùng |

### C. Trải nghiệm và độ bền trong app
| # | Cách | Trạng thái |
|---|---|---|
| C1 | Âm thanh + rung mỗi rep | ✅ |
| C2 | Bảng kiểm tra đặt máy (người, tay, mép, khoảng cách, góc máy, ánh sáng) | ✅ |
| C3 | Quyền camera: không hỏi lặp, có nút mở Cài đặt / thử lại / giả lập | ✅ (đã test trên máy thật) |
| C4 | Camera Android dùng Camera2 (CameraX crash khi khởi tạo lại) | ✅ |
| C5 | Độ phân giải thấp: 9–11 → 19 FPS (khi có người: 19 FPS, ML Kit 46 ms/khung) | ✅ |
| C6 | Cho xoay ngang | ✅ (chưa test được trên máy: OPPO chặn xoay qua adb) |
| C7 | Hướng dẫn đặt máy chéo 45°, cách 1,8–2 m (theo JMIR 2026) | ✅ dòng mẹo trong bảng kiểm tra đặt máy |
| C8 | Plugin native: camera + ML Kit chạy trong Kotlin, không đi qua Dart | 💡 khi cần thêm FPS |
| C9 | Đọc số rep bằng giọng tiếng Việt (flutter_tts), nhắc sửa tư thế bằng lời; bíp nếu máy không có giọng Việt | ✅ (đã kiểm tra trên máy ảo: Google TTS vi-VN) |
| C10 | So model ML Kit "accurate" với "base" (tập test): accurate 75,7%/75,7% vs base **80,1%**/75,0% → **giữ base** (nhanh hơn, đếm thuần tốt hơn) | ✅ quyết định |
| C11 | `tool/check_all.ps1`: phân tích code + test + chấm điểm mọi bộ dữ liệu có ngưỡng — chạy trước khi giữ thay đổi | ✅ |

## 4. Tài nguyên trên mạng (đã kiểm tra giấy phép)

| Tài nguyên | Nội dung | Giấy phép | Dùng cho app thương mại? |
|---|---|---|---|
| RepCount-A (`lmms-lab-eval/repcounta-lance`) | 97 clip push_up có số rep và mốc từng rep | Học thuật; video YouTube | **Không** — chỉ đánh giá nội bộ |
| PushupBench (`anonymousatom/pushupbench`) | 227 clip, chỉ vài clip push-up | CC BY 4.0 (theo dataset card); nguồn video không rõ | Nhãn được; video nên chỉ dùng nội bộ |
| Mendeley "Multi-View … Good/Bad Form" (DOI 10.17632/kgbb3yn47p) | 26 người, push-up chuẩn quay chính diện/chéo/ngang, nhãn tư thế đúng/sai, không có số rep | **CC BY 4.0** | **Có**, ghi nguồn |
| MM-Fit (zenodo 7672767) | 809 phút, có push-up và đoạn không tập | Video CC BY 4.0 | Có (video), ghi nguồn |
| Countix | 154 clip push-up, có số rep | Code Apache-2.0; video YouTube | Không |
| QEVD-FIT (Qualcomm) | 148 bài tập, rất lớn | Chỉ nghiên cứu | **Không** |
| Fitness-AQA, WAVd | Không có / có push-up | Phi thương mại | Không |
| InfiniteRep (tổng hợp, có push-up, CC BY 4.0 theo trang cũ) | — | Nguồn chính đã ngừng; bản còn lại CC BY-NC-SA | Không (bản hiện có) |
| Google ML Kit pose classification (code mẫu) | k-NN lên/xuống + bộ đếm | Apache-2.0 | Có |
| PoseRAC (code) | Đếm theo 2 tư thế chính | MIT | Có (ý tưởng/code), không dùng data RepCount để train |

**Nguyên tắc:** dữ liệu không có giấy phép thương mại chỉ dùng để **đánh giá nội bộ**. Không train model cho app bằng chúng, không đưa vào app, không phát tán lại. Video tải về không commit vào git.

## 5. Bước tiếp theo (theo thứ tự)
1. ~~Mendeley chạy qua ML Kit trên điện thoại~~ ✅ (xong; xem cảnh báo làm mờ ở mục 1).
2. Khi có bản ghi người thật (B10): chỉnh tham số theo ML Kit thật, cân nhắc A14 (k-NN lên/xuống).
3. A12 — kiểm tra tính chu kỳ để loại đoạn không tập.
4. Cải thiện phát hiện võng/chổng nhẹ ở góc chéo (A16): cần dữ liệu có nhãn từng rep.
