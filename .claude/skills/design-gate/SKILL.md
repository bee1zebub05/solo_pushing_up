---
name: design-gate
description: Duyệt một thiết kế (hệ thống, cơ chế, màn, boss, thay đổi luật) của game Solo Pushing Up trước khi code hoặc sau khi viết tài liệu — kiểm trụ cột, vòng lặp, edge case, công thức ở giá trị biên, đi qua kịch bản nhiều hệ cùng chạy, chấm APPROVE/CONCERNS/REJECT/NOT ASSESSED. Dùng khi được hỏi "thiết kế này ổn không", "duyệt", "review thiết kế", hoặc trước khi thêm cơ chế mới.
---

# Cổng duyệt thiết kế

Rút từ CCGS (`rules/thamkhao/ccgs/`: design-review, review-all-gdds,
gates/cd-*). Tinh thần: **tìm cách làm nó hỏng**, không xác nhận nó đúng.

## 1. Đầu vào tối thiểu
Thiết kế phải có (thiếu mục nào thì ghi NOT ASSESSED cho mục đó, không đoán):
1. Tóm tắt + ảo tưởng người chơi ("người chơi cảm thấy…").
2. Luật chi tiết (lập trình viên làm được mà không phải đoán).
3. Công thức: biểu thức, bảng biến (kiểu/khoảng/ý nghĩa), khoảng đầu ra.
4. Edge case: nói rõ chuyện gì xảy ra — cấm "xử lý mềm dẻo".
5. Núm chỉnh (tăng thì sao / giảm thì sao) + tiêu chí nghiệm thu đo được
   ("cảm giác cân bằng" không phải tiêu chí).

## 2. Kiểm theo trụ cột
Đọc `rules/thietke/tru-cot.md`. Với từng trụ: thiết kế phục vụ, trung lập hay
vi phạm? Vi phạm phản trụ cột thì REJECT. Không phục vụ trụ nào thì đề nghị
cắt (pillar proximity: phiên bản tối thiểu nào vẫn phục vụ trụ?).

## 3. Kiểm vòng lặp và sự chú ý
- Gắn vào vòng nào: 1 rep (~2 giây) / 1 màn (1–3 phút) / 1 buổi tập / dài hạn?
  Không gắn vòng nào thì cắt.
- **Ngân sách chú ý**: người chơi đang hít đất, gần như không nhìn màn hình.
  Tối đa **2** thứ đòi người chơi quyết định cùng lúc; mọi tin sống còn phải
  có kênh âm thanh/rung, không chỉ hình.
- SDT: tự chủ / năng lực / gắn kết — ít nhất một.

## 4. Phá cho hỏng
- Thay giá trị biên vào mọi công thức: người yếu (5 rep/màn, chống gối),
  người khoẻ (50 rep, rep nhanh), rep 0, máu 0, combo cực đại. Có âm, chia 0,
  vô hạn, không thắng được, thắng mà không cần tập?
- Chiến thuật áp đảo: rep nông/nhanh/nửa vời có lợi hơn rep chuẩn không?
  (Mục tiêu dự án: rep chuẩn luôn tốt nhất.)
- Cầu tuyết: khoẻ hơn → mạnh hơn → dễ hơn; có đường đuổi kịp cho người yếu?
- Chi phí thất bại tỉ lệ với tần suất thất bại: thua thường thì làm lại nhanh.

## 5. Đi qua kịch bản (ít nhất 3)
Lần theo: kích hoạt → thứ tự hệ chạy → dữ liệu → người chơi thấy gì. Kịch
bản mặc định cho game này:
- Rep cuối hạ boss đúng lúc lên cấp + nhận vật phẩm + mở màn mới.
- Camera nhận sai / mất người giữa combo; người chơi đứng dậy nghỉ.
- Thoát app giữa màn; quay lại hôm sau.
- Hai cơ chế cùng lúc (ví dụ lợn rừng húc đúng lúc đang chém đầu Hydra).

Soi: hai hệ ghi đè cùng trạng thái, thưởng hai lần, phản hồi ngược nhau
(âm thắng nhưng UI thua), hành vi chưa định nghĩa.

## 6. Kết luận
Mỗi mục: APPROVE / CONCERNS / REJECT / NOT ASSESSED; tổng = mức gắt nhất.
NOT ASSESSED không bao giờ là đạt. Quy mô sửa S/M/L/XL. Mâu thuẫn giữa các
góc nhìn: nêu cả hai, để người làm chọn, kèm đề xuất "tôi chọn X vì…".
Ghi luôn "ta sẽ biết quyết định đúng nếu…" (tiêu chí kiểm chứng sau playtest).
