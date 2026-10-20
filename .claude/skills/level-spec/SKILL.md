---
name: level-spec
description: Thiết kế hoặc soát một màn / cả chương của một Kỳ công trong Solo Pushing Up (ví dụ 8 màn Thung lũng Nemea 1.1–1.8) theo thứ tự truyện → hình ảnh → nhịp → quái/thưởng → nghiệm thu, kèm kiểm đường khó răng cưa và nhất quán thần thoại. Dùng khi thêm/sửa màn, chia chương mới, hoặc làm kỳ công tiếp theo.
---

# Thiết kế màn / chương

Rút từ CCGS (`rules/thamkhao/ccgs/skills/team-level/`,
`templates/level-design-document.md`, `templates/difficulty-curve.md`,
`templates/player-journey.md`, `gates/nd-consistency.md`).

## Thứ tự cố định (đầu vào ràng buộc đi trước)
1. **Truyện**: câu thần thoại dẫn vào (`Stage.lore`), mốc truyện, cảm xúc
   vào / giữa / ra. Đối chiếu `rules/cottruyen.md`; bí ẩn nào cũng có đáp án
   thật được ghi lại; không bịa sai thần thoại gốc.
2. **Hình ảnh**: giờ trong ngày / ánh sáng (`BossArt.gradeLight`), cột mốc
   thấy được, bảng màu; quái đọc được bằng hình bóng ở cỡ thumbnail.
3. **Nhịp**: biểu đồ căng–nghỉ trong màn; vị trí màn trên đường răng cưa của
   chương (dạy → kiểm → biến tấu → kết; kishōtenketsu).
4. **Quái, cơ chế, thưởng**: **mỗi màn tối đa một cơ chế mới**, giới thiệu
   riêng lẻ trước khi trộn; dấu hiệu báo đòn riêng, cố định (bảng trong
   `rules/dohoa.md`); thưởng XP theo `balance-reps`.
5. **Nghiệm thu**: ít nhất 3 tiêu chí đo được (rep mục tiêu, thời lượng, cơ
   chế đọc được mà không cần chữ…).

## Kiểm cả chương
- Đường khó răng cưa: đỉnh ở tinh anh / mini-boss / boss, thung ngay sau.
- Kỹ năng boss đòi hỏi đã được dạy ở màn thường trước đó chưa? (Ví dụ sư tử
  cần rep đúng form → đã dạy ở 1.3 lính đá; đặc tả chương 1:
  `rules/thietke/chuong1-nemea.md`.)
- Ánh sáng và độ căng liền mạch dọc bản đồ; không hai màn liền nhau giống hệt.
- Hành trình người chơi: lần thất bại đầu tiên có dạy được gì, làm lại có
  nhanh không; khoảnh khắc "mình giỏi lên" đầu tiên ở đâu.
- Màn kề bên chưa thiết kế thì ghi UNRESOLVED, không bịa.

## Mẫu một màn
`code · tên · loại (thường/tinh anh/mini-boss/boss) · rep mục tiêu · cơ chế
mới · dấu hiệu báo đòn · lore · ánh sáng · cảm xúc ra · nghiệm thu`.
