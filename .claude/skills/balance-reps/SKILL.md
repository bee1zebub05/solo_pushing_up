---
name: balance-reps
description: Cân bằng số liệu game hít đất Solo Pushing Up — máu quái/boss, sát thương mỗi rep, combo, XP, số rep mỗi màn, đường khó qua các màn của một kỳ công — bằng mục tiêu ghi sẵn và test mô phỏng Dart. Dùng khi chỉnh số, thêm quái/màn, hay hỏi "màn này dài/khó quá không".
---

# Cân bằng theo rep

Rút từ CCGS (`rules/thamkhao/ccgs/skills/balance-check/`,
`agents/systems-designer.md`, `templates/difficulty-curve.md`,
`templates/economy-model.md`).

## 1. Mỏ neo: số rep để thắng một màn
Mọi con số suy ra từ **số rep chuẩn để thắng một màn** (người chơi trung bình,
combo bình thường). Ghi mục tiêu trước, rồi mới chấm:

| Loại màn | Rep mục tiêu (chuẩn) | Ghi chú |
|---|---|---|
| Thường (1.1–1.3, 1.5, 1.7) | 6–12 | Màn đầu ít nhất |
| Tinh anh (1.4) | 12–16 | Đỉnh răng cưa 1 |
| Mini-boss (1.6) | 14–18 | Đỉnh 2 |
| Boss (1.8) | 18–22 | Đỉnh cao nhất |

Chế độ chống gối gây ×0,7 sát thương nên cần nhiều rep hơn ~1,4 lần: kiểm vẫn
nằm trong sức người mới (khoảng ≤30 rep chống gối mỗi màn).

Giá trị không có mục tiêu thì ghi "chưa chấm", không phải "ổn".

## 2. Test mô phỏng (bắt buộc khi đổi số)
Viết/chạy test Dart dùng `Battle` (`lib/game/battle.dart`) với chuỗi rep giả:
- Người chuẩn (rep thường, nghỉ 1 s), người yếu (chống gối, nghỉ 3 s), người
  khoẻ (rep sâu liên tục). Đếm rep để thắng từng màn của `nemeaStages`
  (đã có sẵn: `test/game/chapter1_balance_test.dart`, mục tiêu từng màn ở
  `rules/thietke/chuong1-nemea.md`).
- Kiểm: rep tăng theo **răng cưa** (đỉnh ở 1.4, 1.6, 1.8, thung ngay sau);
  không màn nào tụt quá 40% hay nhảy quá 60% so với màn trước nó (trừ thung
  có chủ đích sau đỉnh); người yếu vẫn thắng được mọi màn.
- Chiến thuật áp đảo: rep nông/sai form không bao giờ thắng nhanh hơn rep
  chuẩn; nghỉ dài không có lợi.

## 3. Kinh tế XP
- Nguồn (faucet): XP mỗi rep, thắng, lần đầu thắng màn/kỳ công. Chỗ tiêu
  (sink): hiện chỉ có Harpy cướp vàng — **ghi rõ đây là kinh tế chưa có sink
  thật**.
- Mục tiêu: lên cấp đầu tiên trong buổi tập đầu (≤2 màn); phần thưởng có ý
  nghĩa đầu tiên (áo choàng) sau khoảng 1–3 buổi tập.
- Đổi đường cong thì tính giá trị ở cả hai đầu (cấp 1 và cấp 20).

## 4. Báo cáo
Bảng: Giá trị | Mục tiêu | Thực tế (mô phỏng) | OK / LỆCH / CHƯA CHẤM.
CRITICAL nếu: có chiến thuật áp đảo, có màn người yếu không thắng được, hoặc
tiến trình kẹt. Đề xuất sửa kèm tác động ước tính lên con số.
