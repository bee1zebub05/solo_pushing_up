---
name: workout-hud
description: Thiết kế hoặc soát giao diện trong lúc tập (HUD trận đấu, thông báo, phản hồi rep) của Solo Pushing Up — người chơi đang hít đất, mắt nhìn sàn hoặc liếc điện thoại cách 50–80 cm — theo ngân sách hiển thị, kênh âm thanh/rung, và yêu cầu tiếp cận. Dùng khi thêm chữ/biểu tượng/thanh lên màn trận hoặc khi người chơi "không thấy" thông tin.
---

# HUD khi đang tập

Rút từ CCGS (`rules/thamkhao/ccgs/templates/hud-design.md`,
`templates/hud-design-guide.md`, `skills/ux-design/`, `skills/ux-review/`,
`agents/accessibility-specialist.md`).

## Đảo ngược quy tắc thông thường
Người chơi **không nhìn màn hình liên tục**. Thông tin sống còn (sắp bị húc,
bị chặn vì sai form, thắng/thua, sóng mới) phải có **âm thanh hoặc giọng nói**
cùng hình to; hình là phụ trợ.

## Kiến trúc thông tin (làm trước bố cục)
| Mức | Ví dụ |
|---|---|
| Must Show (≤3) | máu boss, rep/combo, cảnh báo nguy hiểm |
| Contextual | đợt sóng, mực nước, đầu Hydra, mức lạnh — chỉ ở trận có cơ chế đó |
| On Demand | chỉ số chi tiết, XP — sau trận |
| Hidden (truyền qua thế giới) | bụi tan theo máu, nhân vật đóng băng dần |

Ngân sách cứng: thêm một phần tử thì bớt một phần tử.

## Luật
- Đọc được trong một cái liếc ở 50–80 cm: chữ lớn, tương phản ≥4,5:1.
- **Không tin nào chỉ bằng màu**: kèm icon/hình/chữ/âm.
- Hàng đợi thông báo: gộp trong 500 ms; cảnh báo nguy cấp chen hàng; thông
  báo thường chờ.
- Nháy ≤3 lần/giây; có tuỳ chọn giảm rung khung/hitstop.
- Trạng thái phải thiết kế: chưa vào tư thế, mất nhận diện, tạm dừng, thắng,
  thua, đang trao thưởng.
- Giới hạn cố ý (ghi rõ, không chữa được): game cần hít đất thật; bù bằng chế
  độ chống gối, chỉnh số rep, tạm dừng bất kỳ lúc nào.

## Soát
Ít nhất 5 tiêu chí nghiệm thu người test kiểm được mà không cần đọc tài liệu
khác (ví dụ "đặt điện thoại cách 70 cm, nhìn 1 giây vẫn biết sắp bị húc").
Chấm APPROVE/CONCERNS/REJECT/NOT ASSESSED như `design-gate`.
