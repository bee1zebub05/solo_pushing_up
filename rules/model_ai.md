# Chọn model AI cho app đếm rep bằng camera & hiện trạng thế giới

> Ngày tìm hiểu: 2026-10-09
> Liên quan: [timhieu.md](timhieu.md), [review_appstore.md](review_appstore.md), [kehoach-mayao.md](kehoach-mayao.md)

---

## TL;DR

1. **Model đề xuất: MediaPipe Pose Landmarker (bản Lite/Full)**. Lý do: chạy được cả iOS và Android, giấy phép Apache 2.0 miễn phí cho thương mại, trả về 33 điểm khớp kèm toạ độ 3D, và mỗi điểm có điểm số "nhìn thấy" (visibility). Điểm số này rất cần để xử lý lỗi "khuỷu tay ra khỏi khung", lỗi bị chê nhiều nhất trong review của Pushup RPG.
2. **Ứng viên dự phòng để benchmark: RTMPose-t/s** (cũng Apache 2.0). Model này nhanh và chính xác hơn trên giấy tờ, nhưng khó tích hợp hơn.
3. **Model không phải là nút thắt.** Nghiên cứu năm 2026 cho thấy **chỉ riêng góc đặt camera** đã làm tỉ lệ đếm đúng dao động **từ 20% đến 86%**. Thứ quyết định thắng thua là **thuật toán đếm + hướng dẫn đặt máy + bộ test**, chứ không phải đổi model.
4. **Tránh YOLO-pose cho app thương mại đóng mã nguồn**, vì giấy phép AGPL-3.0 (hoặc phải mua license Enterprise).

---

## 1. So sánh các model pose estimation chạy trên điện thoại

| Model | Số điểm khớp | Nền tảng | Tốc độ (tham khảo) | Giấy phép | Nhận xét |
|---|---|---|---|---|---|
| **MediaPipe Pose Landmarker** (BlazePose lite/full/heavy) | **33, có 3D world coords** + visibility | iOS, Android, Web, Flutter/RN qua plugin | Native Android Pixel 5: khoảng 22–32 FPS (Lite/Full) | Apache 2.0 | Phổ biến nhất trong fitness. Có cổ tay, gót chân, ngón chân, rất hữu ích để kiểm tra tư thế plank. Lâu rồi chưa có model mới (chưa tìm thấy bản update 2025–2026). |
| **ML Kit Pose Detection** | 33 (dựa trên BlazePose) | iOS, Android | Khoảng 30 FPS (Pixel 4), 45 FPS (iPhone X) | Miễn phí (Google) | Dễ tích hợp native nhất, nhưng **vẫn ở trạng thái beta**. Thực chất là cùng họ với MediaPipe. |
| **MoveNet** Lightning/Thunder | 17 (COCO) | iOS, Android, Web (TFLite, TF.js) | Lightning khoảng 7 ms trên CPU mobile; web iPhone 12: 51 FPS | Apache 2.0 | Nhanh nhất, nhẹ nhất. **Kém chính xác hơn** (một nghiên cứu năm 2022 cho Lightning 75%, Thunder 81%). Không có điểm bàn chân/bàn tay. Đã cũ (2021). |
| **RTMPose** t/s/m (OpenMMLab) | 17 (COCO), có bản 133 điểm toàn thân | Android qua ncnn/ONNX, iOS qua CoreML/ONNX | Snapdragon 865 (ncnn FP16): **t ≈ 9 ms, s ≈ 14 ms**; RTMPose-s đạt **72.2 AP COCO** | Apache 2.0 | Tỉ lệ chính xác/tốc độ tốt nhất trong nhóm mã nguồn mở. Nhưng phải tự chuyển đổi model, tự dựng pipeline detector + pose; ít ví dụ cho mobile. |
| **Apple Vision** (`VNDetectHumanBodyPoseRequest`, bản 3D từ iOS 17/18) | 19 điểm 2D / 17 điểm 3D tính bằng mét | **Chỉ iOS** | Chạy trên Neural Engine, rất nhẹ | Có sẵn trong iOS | Bản 3D dùng được dữ liệu độ sâu (LiDAR/TrueDepth) để chính xác hơn. Hợp nếu làm app native iOS. |
| **YOLO26-pose** (Ultralytics, 10/2025) | 17, nhiều người cùng lúc | Export sang CoreML/TFLite | Bản Nano: 57.2 mAP | **AGPL-3.0** | Hợp khi cần bắt nhiều người, nhưng **giấy phép bắt mở mã nguồn** toàn bộ app. Muốn đóng mã thì phải mua Enterprise. |
| OpenPose, MMPose (đầy đủ), ViTPose, Sapiens | Đến 133+ | Desktop/GPU | Không chạy realtime trên điện thoại | Tuỳ model | Chỉ dùng cho server hoặc để gắn nhãn dữ liệu offline. |

> Lưu ý về nguồn: phần lớn số FPS đến từ benchmark của chính tác giả model hoặc của vendor (PoseTracker dùng MoveNet và có thiên vị cho MoveNet). Các số được đo trên thiết bị khác nhau và runtime khác nhau, **không so sánh trực tiếp được**. Phải tự đo trên máy thật.

### SDK thương mại (mua thay vì tự làm)
| SDK | Ghi chú |
|---|---|
| **QuickPose** (London) | Bọc MediaPipe, có SDK cho iOS/Android/React Native, có app mẫu FitCount. Có key miễn phí để thử. |
| **Sency** | SDK B2B cho các app fitness, tự công bố hơn 1.5 triệu thành viên dùng qua các đối tác. |
| **KinesteX** | SDK white-label, đếm rep + ước tính calo, xử lý on-device. |
| **Kemtai** | Thiên về vật lý trị liệu và phục hồi chức năng. |
| **PoseTracker** | Lớp xử lý trên MoveNet (đếm rep, tính góc khớp, chấm điểm form). |

→ Hợp để ra **MVP nhanh**. Nhưng nếu muốn cạnh tranh bằng **độ chính xác** thì không nên phụ thuộc vào SDK của bên khác, vì đó chính là lợi thế cạnh tranh của mình.

---

## 2. Thế giới đã làm đến đâu

### 2.1 Sản phẩm
| Nhóm | Ví dụ | Mức độ |
|---|---|---|
| **Phần cứng cao cấp** | **Peloton IQ** (10/2025): camera trên dòng máy "Plus" đếm rep, sửa form, gợi ý mức tạ. **Tempo**: cảm biến độ sâu 3D hồng ngoại + tạ thông minh. | Chính xác nhất nhờ phần cứng chuyên dụng, nhưng giá hàng nghìn USD + phí thuê bao tháng |
| **App dùng camera điện thoại** | Zing Coach (khoảng $60/năm), Strive, Rep-IQ (30 bài tập), WorkoutSentinel (on-device, iOS 18) | Đông đúc. Tất cả đều dựa trên pose estimation + luật đếm |
| **Gamification (đối thủ trực tiếp)** | Pushup RPG, Arise, PUPG, RepHero, Push Up Arena… | Chỉ đếm 2–6 bài, độ chính xác vẫn là điểm yếu chung |
| **Thế hệ mới: AI coach dùng VLM** | Các app nhận ảnh hoặc clip rồi nhận xét **sau khi tập** và nhớ lại cho buổi sau | Chưa có sản phẩm realtime trên điện thoại thật sự tốt |

### 2.2 Nghiên cứu
**Đếm rep bằng camera điện thoại: thực tế còn kém hơn nhiều người nghĩ**
- **JMIR mHealth 2026** (44 sinh viên, 12 vị trí camera, push-up và squat):
  - Tỉ lệ phát hiện trung bình chỉ khoảng **61%**, sai trung bình khoảng 1.1 rep.
  - Push-up tốt nhất ở **góc chéo (diagonal), cách 90–180 cm: phát hiện đúng đến 85.7%, sai 0.28 rep**.
  - Tệ nhất ở **chính diện, cách 360 cm: chỉ 20%**.
  - Khuyến nghị: góc chéo, khoảng cách khoảng 180–200 cm.
  - Đáng chú ý: Pushup RPG lại khuyên **đặt máy dưới sàn, chính diện**. Đây có thể là một chỗ mình làm khác và làm tốt hơn.
- **Pūioio (2023)**: hệ thống đếm on-device, push-up chỉ đạt **65.7%** so với squat 88.2%. **Push-up khó hơn squat** vì chuyển động gần như nằm ngang và cơ thể dễ bị che.
- Các bài báo báo cáo độ chính xác 93–99% thường dùng tập test nhỏ (khoảng 10 video), quay trong điều kiện kiểm soát. Không nên tin các con số này.

**Đếm hành động lặp lại (Repetitive Action Counting) tổng quát**
- Các mốc chính: RepNet (Google 2020) → TransRAC (CVPR 2022, dataset RepCount) → **PoseRAC** (2023, đếm dựa trên keypoint, nhẹ) → LMRL (01/2025) → **CountLLM** (03/2025, dùng LLM).
- Kết quả tốt nhất trên RepCount-A với hướng dựa trên pose: **MAE khoảng 0.21, OBO khoảng 0.60** (bản PoseRAC cải tiến). Nghĩa là chỉ khoảng 60% video được đếm sai trong phạm vi ±1 rep. Đếm tổng quát cho mọi loại hành động **vẫn chưa giải quyết xong**.
- → Với app chỉ có vài bài tập cố định, **luật hình học + máy trạng thái (state machine)** trên keypoint vẫn là cách thực dụng và chính xác nhất. Nếu cần thì thêm một classifier nhỏ kiểu PoseRAC, train trên dữ liệu của chính mình.

**Sửa form bằng VLM (vision-language model)**
- **FormCoach** (2025): VLM so sánh video người dùng với video chuẩn, có dataset 1,700 cặp video, 22 bài tập. Kết luận: **còn xa mới bằng huấn luyện viên thật**.
- **BioCoach** (Drexel + Michigan State, CVPR 06/2026): VLM + dữ liệu góc khớp 3D, nói được *lỗi gì và vì sao nó quan trọng*. Vẫn là prototype.
- → VLM hợp để **nhận xét sau mỗi set** (chạy trên cloud, không cần realtime). **Không dùng VLM để đếm rep.**

---

## 3. Kiến trúc đề xuất cho solo-pushing-up

```
Camera (30fps)
  → Pose model on-device (MediaPipe Lite; benchmark thêm RTMPose-s)
  → Lọc nhiễu (One Euro filter) + bỏ điểm có visibility thấp
  → Tính đặc trưng:
       - góc khuỷu tay (vai–khuỷu–cổ tay), lấy bên trái hoặc phải tuỳ bên nào nhìn rõ hơn
       - độ cao vai/ngực so với cổ tay, chuẩn hoá theo chiều dài thân
       - độ thẳng thân (vai–hông–mắt cá) → kiểm tra plank hợp lệ
  → Máy trạng thái có hysteresis: TOP → DOWN → BOTTOM → UP → TOP (+1 rep)
       - ngưỡng thích nghi theo từng người (calibrate bằng 2 rep đầu)
       - khi mất một khớp: suy luận từ các khớp còn lại (ví dụ thiếu hông → dùng góc vai + khuỷu)
  → Chống gian lận: phải đúng tư thế plank, đủ độ sâu, có chuyển động thân chứ không chỉ gật đầu
  → Game engine (damage, combo…)
  → (Sau set, tuỳ chọn) gửi tóm tắt góc khớp lên VLM trên cloud → nhận xét form
```

Những điểm khắc phục trực tiếp các lỗi của Pushup RPG (xem [review_appstore.md](review_appstore.md)):
- **Không bắt buộc phải thấy hông suốt set.** Đây là gợi ý của chính một user.
- **Tự chọn bên cơ thể nhìn rõ hơn**, nên khuỷu tay ra khỏi khung một bên vẫn đếm được.
- **Không thưởng cho tư thế khuỷu tay mở rộng** (an toàn cho người tập).
- **Màn hình setup có khung hướng dẫn** đặt máy ở **góc chéo, cách 1–2 m** theo nghiên cứu JMIR, và có kiểm tra ánh sáng.
- **Độ khó không vượt khả năng đếm**: giới hạn số rep/giây mà game yêu cầu.
- **Bộ video regression** chạy lại trước mỗi lần release.

### Lộ trình kỹ thuật
| Bước | Việc | Kết quả |
|---|---|---|
| 1 | Prototype MediaPipe Lite + state machine cho push-up | Đếm được trên máy thật |
| 2 | Quay dataset có nhãn (xem [kehoach-mayao.md](kehoach-mayao.md) mục 2) | Bộ test chuẩn |
| 3 | Benchmark: MediaPipe Lite vs Full vs RTMPose-s vs Apple Vision (iOS) trên cùng dataset, trên máy rẻ và máy đắt | Chọn model cuối cùng dựa trên dữ liệu |
| 4 | So với Pushup RPG trên cùng bộ video | Có con số để marketing ("chính xác hơn X%") |
| 5 | (Sau này) classifier nhỏ kiểu PoseRAC train trên dữ liệu thu được | Tăng độ chính xác, thêm bài tập mới nhanh |

---

## Nguồn
- [The Best Human Pose Estimation Model in 2026 (Medium)](https://medium.com/@fabrice_77308/the-best-human-pose-estimation-model-in-2026-db7f7cfe6dab)
- [Best Pose Estimation Model in 2026: Real-Time Mobile Guide (PoseTracker, vendor)](https://www.posetracker.com/news/best-pose-estimation-model-in-2026-the-real-time-mobile-guide)
- [Roboflow: Best Pose Estimation Models](https://blog.roboflow.com/best-pose-estimation-models/)
- [Comparative Analysis of OpenPose, PoseNet, MoveNet on Mobile](https://www.iieta.org/journals/ts/paper/10.18280/ts.390111)
- [RTMPose paper (arXiv 2303.07399)](https://arxiv.org/abs/2303.07399) · [RTMPose benchmark](https://cdn05042023.gitlink.org.cn/OpenMMLab/mmpose/src/branch/main/projects/rtmpose/benchmark)
- [YOLO26 Keypoint Detection (Roboflow)](https://inference-models.roboflow.com/models/yolo26-keypoint-detection/)
- [MediaPipe BlazePose (Google Research)](https://www.research.google/blog/on-device-real-time-body-pose-tracking-with-mediapipe-blazepose/)
- [Apple: DetectHumanBodyPose3DRequest](https://developer.apple.com/documentation/vision/detecthumanbodypose3drequest.md) · [WWDC23](https://developer.apple.com/videos/play/wwdc2023/111241/)
- [JMIR 2026: Smartphone Camera Positioning & Pose Estimation Accuracy](https://doi.org/10.2196/82412)
- [Pūioio: On-device Rep Counting (arXiv 2308.02420)](https://arxiv.org/pdf/2308.02420)
- [Recognizing Exercises and Counting Repetitions in Real Time (arXiv 2005.03194)](https://arxiv.org/pdf/2005.03194)
- [Lightweight pose-based fitness action recognition (Springer 2026)](https://link.springer.com/article/10.1007/s44163-026-02200-4)
- [TransRAC](https://arxiv.org/pdf/2204.01018) · [PoseRAC](https://arxiv.org/pdf/2303.08450) · [Joint-based PoseRAC](https://arxiv.org/pdf/2308.08632) · [LMRL 2025](https://arxiv.org/pdf/2501.07312) · [CountLLM 2025](https://arxiv.org/pdf/2503.17690) · [RACnet](https://arxiv.org/pdf/2407.09431)
- [FormCoach (arXiv 2508.07501)](https://arxiv.org/abs/2508.07501v1) · [BioCoach (Drexel, 2026)](https://drexel.edu/news/archive/2026/june/biocoach-ai-cv-exercise-form-coaching)
- [Peloton IQ (Wareable)](https://www.wareable.com/sport/peloton-cross-training-series-iq-artificial-intelligence) · [Axios](https://www.axios.com/2025/10/01/peloton-cross-training-ai-bike) · [Tempo](https://yespress.io/tempo)
- [Best AI Workout Form Check Apps 2026 (SensAI)](https://www.sensai.fit/blog/best-ai-workout-form-check-apps-2026)
- [QuickPose FitCount](https://github.com/quickpose/FitCount) · [Sency](https://athletechnews.com/sency-transforms-fitness-market-ai-motion-tracking/)
