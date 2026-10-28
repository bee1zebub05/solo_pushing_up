# Cốt truyện & hệ thống nhân vật

> Ngày lập: 2026-10-09 · Trạng thái: **bản nháp ý tưởng**
> Liên quan: [timhieu.md](timhieu.md), [review_appstore.md](review_appstore.md)

---

## 1. Ý tưởng chính

**Tên tạm:** *12 Kỳ Công* (The Twelve Labors)

Hercules đã hoàn thành 12 kỳ công và trở thành bất tử. Nhưng một thế lực tên **Trì Trệ** (The Stagnation) đang lan khắp thế giới thần thoại:
- Anh hùng của các vùng đất **mất dần sức mạnh**.
- Quái vật **bị kích động và nổi loạn**.

Hercules không thể tự mình đi khắp nơi, nên ông chọn **một người kế nhiệm**, chính là người chơi. Người kế nhiệm phải đi qua 12 vùng đất, hoàn thành 12 kỳ công mới, và khôi phục sức mạnh cho các huyền thoại.

**Chủ đề:** *ai cũng có thể bắt đầu từ yếu đuối*. Kẻ thù là sự Trì Trệ (sự lười biếng, sự đứng yên), và mỗi rep là một lần chống lại nó.

### Vì sao chọn khung này
- Kỳ công của Hercules là thử thách sức mạnh thể chất, đúng tinh thần "tập = chiến đấu".
- Mỗi vùng là thần thoại của một nền văn minh, gắn với **bảng xếp hạng quốc gia** và niềm tự hào dân tộc.
- **Mở rộng không giới hạn:** "Kỳ công thứ 13, 14…" mỗi mùa thêm một vùng. Đây là cách giải quyết điểm yếu "hết nội dung" của Pushup RPG (xem [review_appstore.md](review_appstore.md) mục 3.2).

---

## 1b. Giai đoạn 1: CHỈ HÍT ĐẤT

Bản ra mắt chỉ dùng **push-up**. Squat, plank và các bài khác thêm dần ở các bản sau.

**Lý do:**
- Chỉ cần làm **một thuật toán đếm** thật chính xác. Đây là lợi thế cạnh tranh số 1 (xem [model_ai.md](model_ai.md)).
- Chỉ cần quay **một bộ video test**, ra mắt nhanh hơn.
- Pushup RPG cũng ra mắt chỉ với push-up. Squat đến bản 2.0.0 (17/07/2026) mới có.

### Các kiểu hành động chỉ dùng hít đất
Cùng một tư thế hít đất nhưng camera phân biệt được nhiều kiểu hành động (đều dựa trên góc khuỷu tay và độ cao vai):

| Ký hiệu | Hành động | Cách nhận biết | Vai trò trong game |
|---|---|---|---|
| 🔼 | **Rep thường** | Xuống rồi lên đủ biên độ | Tấn công cơ bản |
| 💥 | **Rep sâu** | Ngực xuống gần sàn | Đòn chí mạng |
| ⚡ | **Rep nhanh** | Một rep dưới khoảng 1 giây (tính từ lúc rời tư thế cao tới lúc đẩy lên gần thẳng tay) | Đòn liên hoàn, tấn công nhanh |
| 🐢 | **Rep chậm** | Xuống chậm khoảng 3 giây | Đòn nặng, "hạ nhiệt", giữ thăng bằng |
| ⏸ | **Giữ tư thế cao** | Tay thẳng, thân thẳng (high plank), giữ yên | Phòng thủ, ẩn mình, chống chịu |
| 🔗 | **Combo** | Nhiều rep liên tục không nghỉ | Tăng hệ số damage |

> Nhận biết "giữ yên" và "nhanh hay chậm" chỉ cần thời gian và góc khớp, không cần model mới. Rủi ro kỹ thuật thấp.

### Cơ chế từng kỳ công: bản chỉ hít đất
Những ô ghi "Như cũ" là cơ chế đã chỉ dùng hít đất từ đầu. Bảng phản diện ở mục 3b dùng ký hiệu 🔽 squat. Ở giai đoạn 1, đổi **🔽 thành 🐢 rep chậm**.

| Kỳ công | Cơ chế bản đầy đủ | Bản chỉ hít đất |
|---|---|---|
| 1. Sư tử Nemea | Chỉ rep đúng form gây damage | Như cũ (đã làm) |
| 2. Fafnir | Nghỉ quá 3 giây thì bị đóng băng | Như cũ (đã làm) |
| 3. Apep | Ngày 🔼, đêm 🔽 | Ngày ⚡ rep nhanh, đêm 🐢 rep chậm để giữ thuyền mặt trời |
| 4. Balor | Mắt mở ⏸ plank, mắt nhắm 🔼 | Như cũ (giữ tư thế cao chính là plank tay thẳng) |
| 5. Orochi | 8 đầu, mỗi đầu một combo | Như cũ (đã làm) |
| 6. Ngưu Ma Vương | 🔼 đánh, 🔽 quạt hạ nhiệt | ⚡ đánh, 🐢 rep chậm để quạt hạ nhiệt |
| Hippolyta | Phá kỷ lục cá nhân | Kỷ lục push-up liên tục |
| 7. Div Trắng | 7 set ngắn liên tiếp | Như cũ |
| 8. Zmey Gorynych | 3 đầu ứng với 🔼 🔽 ⏸ | 3 đầu ứng với ⚡ nhanh, 🐢 chậm, ⏸ giữ |
| 9. Tepegöz | Chỉ rep đủ sâu trúng mắt | Như cũ (💥 rep sâu) |
| 10. Soumaoro | Mỗi dạng yếu trước một bài tập | Mỗi dạng yếu trước một kiểu: ⚡ / 🐢 / ⏸ / 💥 |
| 11. Vucub Caquix | Trận bóng + Nhà Dơi ⏸ | Như cũ |
| 12. Thuỷ Tinh | Các đợt sóng dùng 🔼🔽⏸ | Các đợt sóng dùng ⚡ 🐢 ⏸ 💥 (đã làm: `RisingFlood`, lib/game/mechanics/rising_flood.dart) |

### Chế độ Chống gối (có ngay từ bản ra mắt)
Nếu chỉ có push-up chuẩn thì người mới tập, người lớn tuổi và người yếu sẽ bị bỏ lại. Giai đoạn 1 vì vậy có **2 mức**:

| Mức | Tên trong game | Hệ số XP / damage | Ghi chú |
|---|---|---|---|
| Chống gối | **Tân binh** | ×0.7 | Qua được toàn bộ 12 kỳ công |
| Chuẩn | **Chiến binh** | ×1.0 | |

**Cách chọn mức**
- Lúc onboarding, hỏi: *"Bạn hít đất chuẩn được bao nhiêu cái liên tục?"*. Trả lời **0–4** thì gợi ý Tân binh. Trả lời **5 trở lên** thì gợi ý Chiến binh. Người chơi vẫn tự chọn lại được.
- Đổi mức trước mỗi trận bằng một nút bật/tắt. **Không đổi được giữa trận.**

**Nhận diện bằng camera** (cùng model, cùng thuật toán đếm, chỉ thêm một bước kiểm tra tư thế):
- **Chống gối hợp lệ:** đầu gối chạm sàn, và vai–hông–gối thẳng hàng (không chổng mông).
- **Chuẩn hợp lệ:** đầu gối nhấc khỏi sàn, và vai–hông–mắt cá thẳng hàng.
- **Không khớp mức đã chọn:** chọn Chiến binh mà quỳ gối thì rep **không được tính**, và hiện nhắc nhở *"Đang ở chế độ Chiến binh, hãy duỗi thẳng chân"*. Review của Pushup RPG chê đúng lỗi này ("me kneeling counted the push ups"), đây là chỗ mình làm tốt hơn.
- Chọn Tân binh mà làm chuẩn thì **vẫn tính**, rồi gợi ý chuyển lên Chiến binh.

**Lên mức**
- Khi người chơi Tân binh đạt **15 rep chống gối liên tục** 3 lần, mở **"Thử thách Thăng cấp"**: làm 5 rep chuẩn. Qua thì nhận danh hiệu *"Vươn vai"* (gắn với Thánh Gióng, thuộc chuỗi "Những người từng yếu") và được gợi ý chuyển lên Chiến binh.
- Không ép chuyển. Người chơi có thể ở mức Tân binh bao lâu tùy ý.

**Bảng xếp hạng**
- Hai mức có **bảng xếp hạng riêng**, để người chống gối không bị lép vế và người làm chuẩn không bị so sánh không công bằng.
- Duel và Arena chỉ ghép **cùng mức** (hoặc cho đánh khác mức nhưng áp dụng hệ số).

**Việc cần thêm vào bộ test** (xem [kehoach-mayao.md](kehoach-mayao.md)):
- Video chống gối ở các góc máy, khoảng cách, tốc độ như push-up chuẩn.
- Video **quỳ gối nhưng chọn chế độ Chiến binh**, để kiểm tra rep có bị từ chối đúng không.
- Video **đổi tư thế giữa set** (đang chuẩn thì hạ gối xuống), để kiểm tra phần rep sau có được tính theo mức thấp hơn không.

**Để sau:** chống tay lên ghế (incline) và chống tường, vì góc nhìn khác nên cần thêm video test.

### Thứ tự thêm bài tập (dự kiến)
1. **Giai đoạn 1:** push-up chuẩn + chống gối
2. **Giai đoạn 1.5:** push-up chống tay lên ghế (incline)
2. **Giai đoạn 2:** squat. Mở lại cơ chế 🔽 bản đầy đủ, thêm campaign squat riêng
3. **Giai đoạn 3:** plank nằm chống khuỷu tay, sit-up
4. **Giai đoạn 4:** pull-up, dips. Mỗi bài tăng một chỉ số riêng, theo yêu cầu của người chơi trong review

---

## 2. Hệ thống nhân vật

### 2.1 Người chơi = Người kế nhiệm
- Người chơi **không phải Hercules**. Họ là chính mình, bắt đầu từ con số 0.
- Hercules là **người thầy (NPC)**, giao nhiệm vụ và hướng dẫn ở tutorial.
- **Hippolyta**, nữ hoàng Amazon, là **người thầy thứ hai**. Trong thần thoại gốc, Hercules phải lấy đai lưng của bà. Ở đây bà thử thách người chơi rồi trao đai lưng (xem mục 4).

### 2.2 Tạo nhân vật
- Chọn **Kiểu cơ thể A / B**, không ghi Nam/Nữ. Sau đó chọn ngoại hình (da, tóc, mặt) và tên.
- **Chỉ số và gameplay giống nhau 100%.** Khác nhau chỉ ở ngoại hình.
- **Cách xưng hô (tiếng Việt):** cho người chơi chọn anh / chị / cậu / bạn, hoặc dùng danh xưng trung tính như "Người kế nhiệm", "Chiến binh".
- **Hít đất chống gối** là *chế độ cho người mới tập*, ai cũng dùng được. Không gắn chế độ này với giới tính.

### 2.3 Trang phục Huyền thoại
- Mỗi vùng đất có **2 trang phục**: một anh hùng nam và một anh hùng nữ. Người chơi mặc được bất kể chọn kiểu cơ thể nào.
- **Chỉ thay đổi ngoại hình, không tăng chỉ số.** Người chơi Pushup RPG ghét bị bán sức mạnh, nên đây là hướng kiếm tiền an toàn.
- Cách mở khoá:
  - **Miễn phí:** hoàn thành kỳ công của vùng đó.
  - **Sớm hơn:** mua bằng gem.
  - **Phiên bản đặc biệt** (hiệu ứng, màu riêng): phần thưởng sự kiện hoặc bảng xếp hạng.
- Danh hiệu đi kèm, ví dụ "Truyền nhân Thánh Gióng", "Môn đồ Scáthach".

### 2.4 Danh sách Huyền thoại (12 vùng chính)

| # | Nền văn minh | Anh hùng nam | Anh hùng nữ |
|---|---|---|---|
| 1 | Hy Lạp | Hercules | Atalanta: nữ thợ săn, người phụ nữ duy nhất trong đoàn Argonauts |
| 2 | Bắc Âu | Sigurd: người diệt rồng | Brynhildr: nữ chiến binh khiên |
| 3 | Ai Cập | Ramesses II | Ahhotep I: hoàng hậu chiến binh |
| 4 | Celt (Ireland) | Cú Chulainn | Scáthach: nữ võ sư đã dạy Cú Chulainn |
| 5 | Nhật Bản | Minamoto no Yoshitsune: truyền thuyết kể được tengu dạy võ | Tomoe Gozen |
| 6 | Trung Hoa | Tôn Ngộ Không | Mộc Lan |
| 7 | Ba Tư | Rostam: người hoàn thành "7 kỳ công" (Haft Khan) | Gordafarid: nữ chiến binh trong Shahnameh |
| 8 | Slav | Ilya Muromets | Nastasya Mikulichna: nữ bogatyr |
| 9 | Thảo nguyên Trung Á | Basat: sử thi Dede Korkut | Tomyris: nữ hoàng đã đánh bại Cyrus Đại đế |
| 10 | Tây Phi (Mali) | Sundiata Keita | Amina xứ Zazzau: nữ hoàng chiến binh |
| 11 | Maya | Cặp song sinh Hunahpu & Xbalanque (Popol Vuh) | Lady Six Sky: nữ vương chiến binh |
| 12 | Việt Nam | Thánh Gióng | Bà Triệu / Hai Bà Trưng |

> Một số nhân vật là người có thật trong lịch sử (Ramesses II, Ahhotep I, Tomoe Gozen, Tomyris, Amina, Lady Six Sky, Hai Bà Trưng, Bà Triệu), số khác là truyền thuyết. Trong game gọi chung là **"Huyền thoại"**.

### 2.5 Chuỗi "Những người từng yếu"
Ba huyền thoại có câu chuyện **khởi đầu yếu ớt rồi trở nên mạnh mẽ**, đúng hành trình của người chơi:
- **Thánh Gióng:** ba năm không nói, không cười, không biết đi, rồi vươn vai thành tráng sĩ.
- **Ilya Muromets:** nằm liệt 33 năm rồi được ban sức mạnh.
- **Sundiata Keita:** tàn tật từ nhỏ, chống gậy sắt đứng dậy, lập nên đế chế Mali.

→ Làm thành chuỗi thành tích riêng, ví dụ: *lần đầu đạt 10 / 50 / 100 rep liên tục*. Đây cũng là chất liệu tốt cho video TikTok kiểu "từ 0 đến 100".

---

## 3. 12 Kỳ công

Mỗi kỳ công gồm: bối cảnh, quái thường, boss, **cơ chế đặc biệt gắn với bài tập**, cảnh mở đầu và kết thúc.
Ký hiệu: 🔼 push-up · 🔽 squat · ⏸ plank

### Kỳ công 1: Hy Lạp, Thung lũng Nemea *(tutorial)*
- **Bối cảnh:** đồi ô liu, đền đá trắng bị Trì Trệ phủ bụi xám.
- **Quái:** chim Stymphalia, lợn rừng Erymanthus non, lính đá.
- **Boss:** **Sư tử Nemea**. Da không vũ khí nào xuyên thủng.
- **Cơ chế:** *chỉ rep đúng form mới gây damage*, vì da sư tử chặn mọi đòn "ăn gian". Đây là cách dạy người chơi về form ngay từ đầu: rep nông thì hiện chữ "Bị chặn!".
- **Mở đầu:** Hercules tìm thấy người chơi, nói: *"Sức mạnh không được ban cho. Nó được rèn ra từng lần một."*
- **Kết thúc:** người chơi nhận **áo choàng da sư tử**, món trang bị đầu tiên.

### Kỳ công 2: Bắc Âu, Rừng Băng
- **Bối cảnh:** rừng thông tuyết, hang băng, ánh cực quang.
- **Quái:** draugr (xác sống), troll, sói băng.
- **Boss:** **Rồng Fafnir** canh kho báu.
- **Cơ chế:** *Giá lạnh*. Nghỉ quá 3 giây giữa các rep thì nhân vật bị đóng băng dần và damage giảm. Dạy người chơi **giữ nhịp tập đều**.
- **Kết thúc:** Brynhildr và Sigurd lấy lại sức mạnh, mở khoá trang phục.

### Kỳ công 3: Ai Cập, Sông Nile về đêm
- **Bối cảnh:** sa mạc, kim tự tháp, con thuyền mặt trời của thần Ra trôi trong cõi âm.
- **Quái:** xác ướp, bọ cạp khổng lồ, chó rừng.
- **Boss:** **Rắn Apep**, kẻ muốn nuốt mặt trời.
- **Cơ chế:** *Ngày và đêm*. Trận đấu đổi pha liên tục. Pha ngày dùng 🔼 để đánh, pha đêm dùng 🔽 để giữ thuyền mặt trời không chìm. Đây là trận **kết hợp hai bài tập** đầu tiên.
- **Lưu ý:** thần Ra chỉ xuất hiện như bối cảnh. Người chơi không đánh thần.

### Kỳ công 4: Celt, Đảo Sương Mù
- **Bối cảnh:** đồi xanh, vòng đá cổ, sương mù.
- **Quái:** Fomorian (tộc khổng lồ biển), sói xám, cây sống.
- **Boss:** **Balor**, khổng lồ có con mắt độc giết người bằng ánh nhìn.
- **Cơ chế:** *Ánh mắt Balor*. Khi mắt mở, người chơi phải **⏸ giữ plank** (nằm yên dưới ánh nhìn). Khi mắt nhắm thì tấn công bằng 🔼. Đây là lần đầu **plank có vai trò trong chiến đấu**, đáp ứng yêu cầu của người chơi trong review.
- **Mở đầu:** Scáthach huấn luyện người chơi tại Đảo Bóng Tối (Dún Scáith).

### Kỳ công 5: Nhật Bản, Sông Hi
- **Bối cảnh:** rừng tuyết tùng, cổng torii, sông núi Izumo.
- **Quái:** oni, kappa, yūrei (hồn ma).
- **Boss:** **Yamata no Orochi**, rắn 8 đầu 8 đuôi. Các boss khác của vùng
  (chốt 14/10/2026): Susanoo cuồng nộ, Thiên hoàng Sutoku, Tamamo-no-Mae,
  Shuten-dōji — xem mục 3b.5. Chia màn (chốt 14/10/2026): HAI kỳ công Nhật,
  tách theo thời đại. 21/10: mỗi kỳ công **8 màn** (như chương 1), bảng màn ở
  [thietke/chuong2-nhat.md](thietke/chuong2-nhat.md):
  - *Izumo (thời thần thoại):* Susanoo cuồng nộ → Shuten-dōji → Orochi
    (boss cuối). Susanoo bại trận tỉnh lại, dẫn đường đi diệt Orochi.
  - *Kinh đô Heian (thời lịch sử):* Tamamo-no-Mae → Thiên hoàng Sutoku
    (boss cuối). Phông cung điện, đền, núi Nasu / Sanuki.
  Số thứ tự kỳ công cho phần Heian chưa xếp vào danh sách 12.
- **Cơ chế:** *8 cái đầu*. Mỗi đầu cần một chuỗi rep **không ngắt quãng** (combo). Ngắt giữa chừng thì đầu đó hồi máu.
- **Phụ:** tengu là đồng minh. Họ "dạy võ" người chơi, giống truyền thuyết về Yoshitsune.

### Kỳ công 6: Trung Hoa, Hoả Diệm Sơn
- **Bối cảnh:** núi lửa đỏ rực, sương núi, cung điện yêu quái.
- **Quái:** yêu quái núi, Nhện tinh, Bạch Cốt Tinh.
- **Boss:** **Ngưu Ma Vương**.
- **Cơ chế:** *Sức nóng*. Thanh nhiệt độ tăng liên tục. Mỗi 🔽 squat là một lần quạt bằng quạt Ba Tiêu để hạ nhiệt. Người chơi phải xen kẽ: 🔼 để đánh boss, 🔽 để không bị thiêu.
- **Kết thúc:** Tôn Ngộ Không tỉnh lại khỏi sự Trì Trệ, mở khoá trang phục.

### ⭐ Giữa chặng: Thử thách của Hippolyta
- **Bối cảnh:** thành Themiscyra của tộc Amazon.
- **Nội dung:** Hippolyta không phải kẻ thù. Bà muốn biết người kế nhiệm có xứng đáng không.
- **Cơ chế:** *Vượt chính mình*. Người chơi phải **phá kỷ lục cá nhân** (số rep liên tục nhiều nhất) ở bất kỳ bài nào. Mỗi người có mục tiêu khác nhau, nên người mới và người giỏi đều chơi được.
- **Phần thưởng:** **Đai lưng Hippolyta** và Hippolyta trở thành người thầy thứ hai.

### Kỳ công 7: Ba Tư, Bảy Chặng Đường
- **Bối cảnh:** núi đá, sa mạc muối, cung điện Persepolis.
- **Quái:** div (quỷ), sư tử, rồng nhỏ, phù thuỷ. Đây là những thử thách Rostam từng vượt qua.
- **Boss:** **Div Trắng (Div-e Sepid)**.
- **Cơ chế:** *Haft Khan, 7 chặng*. Boss rush gồm **7 set ngắn liên tiếp**, nghỉ giữa các set bị giới hạn thời gian. Đây là kỳ công về **sức bền**.
- **Ghi chú:** Rostam có 7 kỳ công, Hercules có 12. Có thể viết một cảnh hai huyền thoại gặp nhau.

### Kỳ công 8: Slav, Thảo nguyên Bạch Dương
- **Bối cảnh:** rừng bạch dương, nhà gỗ, sông băng.
- **Quái:** leshy (thần rừng giận dữ), rusalka, lính xương của Koschei.
- **Boss:** **Rồng 3 đầu Zmey Gorynych**.
- **Cơ chế:** *Ba cái đầu, ba bài tập*. Đầu 1 chỉ nhận 🔼, đầu 2 chỉ nhận 🔽, đầu 3 chỉ chết khi ⏸ giữ plank đủ lâu.
- **Mini-boss:** Koschei Bất Tử. Muốn hạ hắn thì phải tìm "cây kim chứa linh hồn" trong một màn ẩn.
- **Câu chuyện:** Ilya Muromets nằm liệt dưới sự Trì Trệ. Người chơi giúp ông đứng dậy, gợi lại truyền thuyết gốc.

### Kỳ công 9: Thảo nguyên Trung Á
- **Bối cảnh:** thảo nguyên vô tận, lều yurt, đại bàng.
- **Quái:** sói thảo nguyên, albasty (hồn ác), kỵ binh bóng tối.
- **Boss:** **Tepegöz**, khổng lồ một mắt mà không vũ khí nào làm bị thương, trừ con mắt.
- **Cơ chế:** *Nhắm vào mắt*. Chỉ những rep **đủ sâu và đúng nhịp** mới là "đòn chí mạng" trúng mắt. Rep thường không gây sát thương. Đây là kỳ công về **độ chính xác**.
- **Huyền thoại:** Basat (người diệt Tepegöz trong sử thi) và Tomyris.

### Kỳ công 10: Tây Phi, Đế chế Mali
- **Bối cảnh:** xavan, cây bao báp, thành đất nung.
- **Quái:** chiến binh phù thuỷ, sư tử, linh hồn biến hình.
- **Boss:** **Soumaoro Kanté**, vua phù thuỷ biến được nhiều hình dạng.
- **Cơ chế:** *Biến hình*. Boss liên tục đổi dạng, mỗi dạng chỉ yếu trước một bài tập. Người chơi phải **đổi bài nhanh** theo tín hiệu trên màn hình.
- **Câu chuyện:** đi theo hành trình của Sundiata, cậu bé tàn tật chống gậy sắt đứng dậy. Đây là đỉnh điểm của chuỗi "Những người từng yếu".

### Kỳ công 11: Maya, Xibalba (Cõi âm)
- **Bối cảnh:** rừng rậm, kim tự tháp bậc thang, sân bóng đá cổ, hang dơi.
- **Quái:** chúa tể Xibalba, dơi Camazotz, báo đốm bóng tối.
- **Boss:** **Vucub Caquix**, con chim tự xưng là mặt trời.
- **Cơ chế:** *Trận bóng Xibalba*. Một trận đấu kiểu **kéo co PvE** với chúa tể cõi âm: rep nhanh hơn thì đẩy được quả bóng sang phía đối thủ. Sau đó vào **Nhà Dơi**, nơi phải ⏸ plank để ẩn mình.
- **Huyền thoại:** cặp song sinh Hunahpu & Xbalanque (từng hạ Vucub Caquix trong Popol Vuh), và Lady Six Sky.

### Kỳ công 12: Việt Nam, Núi Tản Viên *(chương cuối)*
- **Bối cảnh:** núi non, ruộng bậc thang, sông Hồng, đền cổ, trống đồng.
- **Quái và mini-boss:** **Ngư Tinh, Hồ Tinh, Mộc Tinh**, ba yêu quái từng bị Lạc Long Quân diệt, nay sống lại vì sự Trì Trệ.
- **Boss:** **Thuỷ Tinh** dâng nước tấn công.
- **Cơ chế:** *Núi dâng, nước dâng*. Mỗi rep giúp Sơn Tinh **nâng núi cao thêm**, còn Thuỷ Tinh liên tục **dâng nước**. Đây là trận kéo co lớn nhất game, dùng cả 🔼🔽⏸ theo từng đợt sóng.
- **Câu chuyện:**
  - Thánh Gióng đang ngủ yên ở làng Phù Đổng dưới sự Trì Trệ. Người chơi giúp cậu bé "vươn vai" (cảnh cắt quay lại truyền thuyết gốc).
  - Bà Triệu và Hai Bà Trưng dẫn đầu nghĩa quân cùng chiến đấu.
  - Câu thoại của Bà Triệu: *"Tôi muốn cưỡi cơn gió mạnh, đạp luồng sóng dữ…"*
- **Kết thúc:**
  - Thánh Gióng cưỡi ngựa sắt bay về trời từ núi Sóc Sơn, để lại lời hứa sẽ trở lại khi Trì Trệ quay về.
  - Hercules xuất hiện, công nhận người chơi là **Anh hùng của 12 Kỳ công**.
  - Cảnh cuối hé lộ **trái tim của Trì Trệ** vẫn còn đâu đó, mở ra phần endgame.

> **Lưu ý:** boss chương Việt Nam là **quái vật thần thoại**, không phải một quốc gia có thật (không dùng giặc Ân, quân Hán, quân Ngô), để tránh gây tranh cãi với người chơi nước ngoài.

---

## 3b. Danh sách phản diện theo nền văn minh

Mỗi vùng có **6 kẻ thù: 3 quái thường, 1 tinh anh, 1 mini-boss, 1 boss**, tổng cộng **72 kẻ thù** cho 12 vùng (Pushup RPG có 48).
Tất cả đều bị sự **Trì Trệ** làm biến chất: mắt xám, thân phủ bụi đá. Khi bị đánh bại, chúng được "giải thoát" thay vì bị giết. Cách này nhẹ nhàng hơn và tôn trọng các thần thoại gốc.

Ký hiệu: 🔼 push-up · 🔽 squat · ⏸ plank

### 1. Hy Lạp
| Cấp | Tên | Nguồn gốc | Đặc điểm trong game |
|---|---|---|---|
| Thường | Chim Stymphalia | Kỳ công thứ 6 của Hercules | Bay theo đàn, máu thấp, xuất hiện nhiều con |
| Thường | Spartoi | Chiến binh mọc lên từ răng rồng (chuyện Cadmus, Jason) | Mỗi lần ngã có thể mọc lại một lần |
| Thường | Harpy | Quái chim đầu người | Cướp vàng nếu người chơi nghỉ quá lâu |
| Tinh anh | Lợn rừng Erymanthus | Kỳ công thứ 4 | Lao húc: phải 🔽 để "né" |
| Mini-boss | Hydra non | Hydra xứ Lerna (kỳ công thứ 2) | Bản yếu cho tutorial. Hydra trưởng thành để dành cho Thử thách Huyền thoại |
| **Boss** | **Sư tử Nemea** | Kỳ công thứ 1 | Da không xuyên thủng: chỉ rep đúng form mới gây damage |

### 2. Bắc Âu
| Cấp | Tên | Nguồn gốc | Đặc điểm |
|---|---|---|---|
| Thường | Draugr | Xác sống canh mộ | Chậm nhưng nhiều máu |
| Thường | Sói băng | Bầy sói trong truyền thuyết Bắc Âu | Tấn công theo bầy |
| Thường | Troll | Quái khổng lồ núi | Sợ ánh sáng, yếu hơn khi rep nhanh |
| Tinh anh | Jötunn băng | Khổng lồ băng giá | Gây hiệu ứng "đóng băng" mạnh |
| Mini-boss | Garmr | Chó canh cổng cõi chết Hel | Tiếng hú làm giảm nhịp, phải giữ combo |
| **Boss** | **Rồng Fafnir** | Bị Sigurd diệt trong saga Völsunga | Giá lạnh: nghỉ quá 3 giây thì bị đóng băng |

### 3. Ai Cập
| Cấp | Tên | Nguồn gốc | Đặc điểm |
|---|---|---|---|
| Thường | Xác ướp | Lăng mộ cổ | Hồi máu nếu không bị đánh liên tục |
| Thường | Bọ cạp khổng lồ | Sa mạc | Độc: mất máu theo thời gian |
| Thường | Chó rừng bóng tối | Sa mạc về đêm | Nhanh, chỉ xuất hiện trong pha đêm |
| Tinh anh | Ammit | "Kẻ nuốt linh hồn": đầu cá sấu, thân sư tử, chân hà mã | Nuốt phần thưởng nếu thua |
| Mini-boss | Nhân sư (Sphinx) | Thần thoại Ai Cập và Hy Lạp | Đố một câu (về form, về sức khoẻ), trả lời đúng thì boss yếu đi |
| **Boss** | **Rắn Apep** | Kẻ thù của thuyền mặt trời Ra | Ngày và đêm: 🔼 ban ngày, 🔽 ban đêm |

### 4. Celt (Ireland)
| Cấp | Tên | Nguồn gốc | Đặc điểm |
|---|---|---|---|
| Thường | Chiến binh Fomorian | Tộc khổng lồ biển | Khiên dày, cần rep sâu |
| Thường | Púca | Linh hồn biến hình (ngựa, dê, quạ) | Đổi dạng giữa trận |
| Thường | Sói xám Ireland | Rừng cổ | Tấn công theo bầy |
| Tinh anh | Dullahan | Kỵ sĩ không đầu | Đếm ngược: phải hạ trước khi hết giờ |
| Mini-boss | Sluagh | Bầy linh hồn lang thang | Bay quanh như cơn bão: ⏸ để chống |
| **Boss** | **Balor** | Vua Fomorian mắt độc, bị Lugh hạ | Mắt mở thì ⏸ plank, mắt nhắm thì 🔼 |

### 5. Nhật Bản
| Cấp | Tên | Nguồn gốc | Đặc điểm |
|---|---|---|---|
| Thường | Oni | Quỷ cầm chuỳ sắt | Đòn nặng, chậm |
| Thường | Kappa | Thuỷ quái có đĩa nước trên đầu | Cúi chào (🔽) làm nó cúi theo, đổ nước, mất sức. Lấy từ truyện dân gian |
| Thường | Yūrei | Hồn ma | Tàng hình xen kẽ, chỉ đánh được khi hiện hình |
| Tinh anh | Tsuchigumo | Nhện đất khổng lồ | Giăng tơ: giảm tốc độ đếm combo |
| Mini-boss | Shuten-dōji | Vua oni ở núi Ōe, nghiện rượu; Minamoto no Raikō cùng Tứ Thiên Vương giả làm tu sĩ, chuốc rượu độc rồi chém | Uống rượu hồi máu: phải ngắt bằng combo |
| **Boss** | **Susanoo cuồng nộ** | Thần bão. Trước khi diệt Orochi, ông phá ruộng lúa của Amaterasu, ném ngựa lột da vào phòng dệt làm chết một thị nữ; Amaterasu trốn vào hang Ama-no-Iwato, thế giới tối đen; ông bị đuổi khỏi Takamagahara (Kojiki) | Chưa thiết kế cơ chế. Gợi ý: bão, gió đẩy lùi, kiếm Totsuka |
| **Boss** | **Thiên hoàng Sutoku** | Thiên hoàng thua loạn Hōgen (1156), bị đày sang Sanuki; chép kinh gửi về kinh đô bị trả lại, ông cắn lưỡi viết lời nguyền bằng máu, chết thành oan hồn hoá đại tengu, vua quỷ (Hōgen monogatari, Ugetsu monogatari) | Chưa thiết kế cơ chế. Gợi ý: lời nguyền máu, đàn tengu, lửa ma |
| **Boss** | **Tamamo-no-Mae** | Hồ ly chín đuôi giả làm mỹ nhân trong cung Thiên hoàng Toba; bị âm dương sư Abe no Yasunari vạch mặt, chạy về Nasu, bị quân triều đình giết, hoá đá độc Sesshō-seki | Chưa thiết kế cơ chế. Gợi ý: ảo ảnh, chín đuôi |
| **Boss** | **Yamata no Orochi** | Rắn 8 đầu, bị Susanoo chuốc rượu ủ 8 lần rồi chém; kiếm Kusanagi nằm trong đuôi | 8 đầu, mỗi đầu cần một combo không ngắt quãng (đã làm) |

> Susanoo và Sutoku là kami đang được thờ (đền Yasaka, Hikawa; Shiramine
> Jingū) — ngoại lệ có chủ ý của nguyên tắc nhạy cảm 1 (mục 6), người dùng
> chốt ngày 14/10/2026: đánh thẳng như boss phản diện.

### 6. Trung Hoa
| Cấp | Tên | Nguồn gốc | Đặc điểm |
|---|---|---|---|
| Thường | Tiểu yêu núi | Thuộc hạ của các yêu vương trong Tây Du Ký | Đông, yếu |
| Thường | Nhện tinh | Động Bàn Tơ (Tây Du Ký) | Trói: phải 🔽 để thoát |
| Thường | Hổ yêu | Yêu quái núi | Nhanh |
| Tinh anh | Bạch Cốt Tinh | Biến hình 3 lần (Tây Du Ký) | Giả làm đồng minh, phải nhận ra để đánh |
| Mini-boss | Hồng Hài Nhi | Con trai Ngưu Ma Vương, phun Tam Muội Chân Hoả | Tăng thanh nhiệt độ cực nhanh |
| **Boss** | **Ngưu Ma Vương** | Tây Du Ký | Sức nóng: 🔼 đánh boss, 🔽 quạt Ba Tiêu hạ nhiệt |

> Thiết Phiến Công Chúa (vợ Ngưu Ma Vương, giữ quạt Ba Tiêu) có thể là NPC trung lập, cho mượn quạt nếu người chơi hoàn thành thử thách.

### 7. Ba Tư
| Cấp | Tên | Nguồn gốc | Đặc điểm |
|---|---|---|---|
| Thường | Div | Quỷ trong Shahnameh | Đông, đa dạng |
| Thường | Sư tử sa mạc | Chặng 1 trong 7 kỳ công của Rostam | Nhanh, mạnh |
| Thường | Phù thuỷ | Chặng 4: phù thuỷ giả làm thiếu nữ | Gây ảo ảnh: đếm rep bị ẩn |
| Tinh anh | Rồng sa mạc | Chặng 3 | Phun lửa theo nhịp |
| Mini-boss | Arzhang Div | Chặng 6 | Gọi thêm quân div |
| **Boss** | **Div Trắng** | Chặng 7, kẻ thù cuối của Rostam | Boss rush 7 set ngắn liên tiếp |

> **Zahhak**, vua bạo chúa có rắn mọc trên vai, để dành cho Thử thách Huyền thoại của vùng Ba Tư.

### 8. Slav
| Cấp | Tên | Nguồn gốc | Đặc điểm |
|---|---|---|---|
| Thường | Leshy | Thần rừng (bị Trì Trệ làm giận dữ) | Làm lạc đường, đổi vị trí |
| Thường | Rusalka | Hồn nữ dưới nước | Kéo xuống nước: phải ⏸ trụ vững |
| Thường | Lính xương | Quân của Koschei | Đông, yếu |
| Tinh anh | Likho Một Mắt | Hiện thân của vận rủi | Gây "xui": ngẫu nhiên giảm damage |
| Mini-boss | Koschei Bất Tử | Linh hồn giấu trong cây kim | Bất tử cho đến khi tìm được cây kim ở màn ẩn |
| **Boss** | **Zmey Gorynych** | Rồng 3 đầu, bị Dobrynya Nikitich hạ | 3 đầu ứng với 🔼, 🔽, ⏸ |

> Baba Yaga là nhân vật nước đôi trong truyện dân gian, có thể làm NPC giao nhiệm vụ phụ.

### 9. Thảo nguyên Trung Á
| Cấp | Tên | Nguồn gốc | Đặc điểm |
|---|---|---|---|
| Thường | Sói thảo nguyên | Biểu tượng thảo nguyên | Tấn công theo bầy |
| Thường | Albasty | Hồn ác trong dân gian Kazakh và Turk | Đè nặng: giảm tốc độ |
| Thường | Kỵ binh bóng tối | Quân của Trì Trệ | Lao nhanh theo đợt |
| Tinh anh | Jalmauyz Kempir | Phù thuỷ nhiều đầu trong cổ tích Kazakh | Mỗi đầu một kiểu tấn công |
| Mini-boss | Aydahar | Rồng trong dân gian Kazakh | Cuộn mình phòng thủ, chỉ hở khi combo |
| **Boss** | **Tepegöz** | Khổng lồ một mắt, bị Basat diệt (Dede Korkut) | Chỉ rep đủ sâu và đúng nhịp mới trúng mắt |

### 10. Tây Phi (Mali)
| Cấp | Tên | Nguồn gốc | Đặc điểm |
|---|---|---|---|
| Thường | Chiến binh Sosso | Quân của Soumaoro | Khiên, giáo |
| Thường | Sư tử xavan | Biểu tượng Mali | Nhanh, mạnh |
| Thường | Linh hồn biến hình | Phép thuật Sosso | Đổi dạng |
| Tinh anh | Ninki Nanka | Sinh vật giống rồng trong dân gian Tây Phi | Ẩn dưới đầm lầy, bất ngờ trồi lên |
| Mini-boss | Trâu rừng xứ Do | Sử thi Sundiata: người phụ nữ hoá trâu tàn phá xứ Do | Lao húc liên tục: 🔽 để né |
| **Boss** | **Soumaoro Kanté** | Vua phù thuỷ Sosso, bị Sundiata hạ | Biến hình: mỗi dạng chỉ yếu trước một bài tập |

### 11. Maya
| Cấp | Tên | Nguồn gốc | Đặc điểm |
|---|---|---|---|
| Thường | Báo đốm bóng tối | Rừng rậm, cõi âm | Nhanh, ẩn mình |
| Thường | Dơi Camazotz | Nhà Dơi trong Xibalba | Bay theo đàn: ⏸ plank để ẩn |
| Thường | Chiến binh xương | Cư dân Xibalba | Đông |
| Tinh anh | Zipacna | Con trai Vucub Caquix, khổng lồ cá sấu | Mai cứng, cần rep sâu |
| Mini-boss | Chúa tể Xibalba (Hun-Came & Vucub-Came) | Hai chúa tể cõi âm, bị cặp song sinh đánh bại | Trận bóng: kéo co PvE |
| **Boss** | **Vucub Caquix** | Chim tự xưng mặt trời | Ánh sáng giả làm loá: phải giữ nhịp khi không nhìn rõ số đếm |

> **Cabrakan**, khổng lồ gây động đất và là con trai thứ hai của Vucub Caquix, để dành cho Thử thách Huyền thoại.

### 12. Việt Nam
| Cấp | Tên | Nguồn gốc | Đặc điểm |
|---|---|---|---|
| Thường | Thuồng luồng | Thuỷ quái trong dân gian | Kéo xuống nước |
| Thường | Ma da | Hồn ma dưới nước | Tàng hình xen kẽ |
| Thường | Đại bàng tinh | Truyện Thạch Sanh | Tấn công từ trên cao |
| Tinh anh | Chằn tinh | Truyện Thạch Sanh | Biến hình, rất nhiều máu |
| Mini-boss | **Ngư Tinh, Hồ Tinh, Mộc Tinh** | Ba yêu quái bị Lạc Long Quân diệt | Ba trận liên tiếp, mỗi trận một bài tập chính |
| **Boss** | **Thuỷ Tinh** | Sơn Tinh – Thuỷ Tinh | Núi dâng, nước dâng: kéo co lớn nhất game |

> **Thuỷ Tinh** trong truyền thuyết không hẳn là ác; ông ghen tuông và giận dữ vì thua. Trong game, ông **bị Trì Trệ khuếch đại cơn giận**. Đánh bại ông là giải thoát ông khỏi Trì Trệ, và Thuỷ Tinh hoá giải được với Sơn Tinh. Kết thúc như vậy tôn trọng truyền thuyết gốc hơn.

### 13. Phản diện xuyên suốt: Trì Trệ
| Cấp | Tên | Vai trò |
|---|---|---|
| Sứ giả | **Kẻ Ru Ngủ** (12 hình dạng, mỗi vùng một dạng) | Xuất hiện cuối mỗi kỳ công để báo hiệu vùng tiếp theo, thoại ngắn kiểu *"Nghỉ thêm chút nữa đi…"* |
| Trùm cuối (endgame) | **Trái tim Trì Trệ** | Hé lộ sau kỳ công 12. Ở đáy Vực Trì Trệ, là boss sự kiện theo mùa |

Thoại của Trì Trệ nên dùng chính những câu người ta tự nói với mình khi lười, như *"Mai tập cũng được"*, *"Hôm nay mệt rồi"*. Kẻ thù trong game là cái lười, nên người chơi dễ đồng cảm.

### Kẻ thù cho các vùng mở rộng (gợi ý)
| Vùng | Quái thường / tinh anh | Boss gợi ý |
|---|---|---|
| Hàn Quốc | Dokkaebi (yêu tinh), Gumiho (cáo chín đuôi) | Imugi (rắn chưa hoá rồng) |
| Indonesia | Kuntilanak (hồn ma), Genderuwo | Buto Ijo (khổng lồ xanh) |
| Philippines | Tikbalang (đầu ngựa), Manananggal, Aswang | Bakunawa (rồng nuốt trăng) |
| Lưỡng Hà | Scorpion-men (người bọ cạp) | Humbaba, Thiên Ngưu (Bull of Heaven) |
| Brazil | Cuca, Mapinguari | Boitatá (rắn lửa) |
| Inca | Ukuku (người gấu) | Amaru (rắn rồng) |

## 4. Sau 12 kỳ công (endgame)

| Chế độ | Mô tả |
|---|---|
| **Vực Trì Trệ** | Dungeon vô tận, mỗi tầng mang quái của một vùng ngẫu nhiên. **Miễn phí không giới hạn** (Pushup RPG giới hạn tầng 10 cho người chơi free và bị chê) |
| **Kỳ công thứ 13, 14…** | Mỗi mùa thêm một nền văn minh mới, kèm sự kiện, trang phục, bảng xếp hạng riêng |
| **Thử thách Huyền thoại** | Đánh lại boss cũ ở độ khó cao hơn, với điều kiện đặc biệt (ví dụ chỉ được dùng squat) |
| **New Game+** | Chơi lại 12 kỳ công, giữ đồ, quái mạnh hơn |
| **Đại chiến quốc gia** | Sự kiện theo mùa: các nước cùng góp rep để hạ một boss chung |

---

## 5. Danh sách mở rộng theo mùa

| Nền văn minh | Anh hùng nam | Anh hùng nữ | Boss gợi ý | Ghi chú |
|---|---|---|---|---|
| Hàn Quốc | Jumong | Yuhwa | Imugi (rắn chưa hoá rồng) | |
| Indonesia | Gatotkaca: "cơ bắp sắt, xương thép" | Srikandi | Buto Ijo (khổng lồ xanh) | |
| Philippines | Lam-ang | Urduja | Bakunawa (rồng nuốt trăng) | |
| Inca | Pachacuti | Mama Huaco | | |
| Lưỡng Hà | Gilgamesh | (cần tìm thêm) | Humbaba | Thiếu anh hùng nữ chiến binh |
| Brazil | (cần tìm thêm) | Icamiabas (bộ tộc nữ chiến binh) | Boitatá (rắn lửa) | Hợp làm vùng có quái vật dân gian |
| Ấn Độ | Bhima | — | | ⚠️ Cần tư vấn người am hiểu tôn giáo |
| Polynesia | Māui | — | | ⚠️ Cần người bản địa tư vấn |

---

## 6. Nguyên tắc nhạy cảm văn hoá

1. **Không dùng thần linh của tôn giáo còn được thờ** làm boss hay nhân vật để đánh (Hindu, Hồi giáo, Kitô giáo, Phật giáo, kami Shinto). Thần chỉ xuất hiện như bối cảnh hoặc đồng minh xa.
   - **Ngoại lệ đã chốt (14/10/2026):** Susanoo cuồng nộ và Thiên hoàng Sutoku (vùng Nhật Bản) là boss để đánh, dù đang được thờ như kami. Người dùng đã được báo rủi ro và chọn giữ. Vẫn bắt buộc mục 5 (người Nhật đọc lại thoại và hình) trước khi phát hành.
2. **Không biến quốc gia có thật thành kẻ thù.** Kẻ thù luôn là quái vật thần thoại hoặc sự Trì Trệ.
3. **Không dùng hoàng gia Thái Lan** (luật khi quân).
4. **Câu chuyện linh thiêng của người bản địa** (thổ dân châu Mỹ, Úc, Māori) chỉ làm khi có người trong cộng đồng tư vấn.
5. **Nhờ người bản xứ đọc lại** lời thoại và kiểm tra hình ảnh của từng vùng trước khi phát hành.
6. **Art tự vẽ hoặc có phong cách nhất quán.** Pushup RPG bị chê vì ảnh rõ là AI tạo ra.

---

## 7. Kế hoạch ra mắt nội dung

| Giai đoạn | Nội dung |
|---|---|
| **Ra mắt** | Kỳ công 1 (Hy Lạp, tutorial), 2 (Bắc Âu), 5 (Nhật Bản), 12 (Việt Nam, mở sớm làm "chương đặc biệt" cho thị trường VN) |
| Mỗi 2–4 tuần | Mở thêm 1 kỳ công theo thứ tự còn lại |
| Sau khi đủ 12 | Mùa mới: Kỳ công 13+ từ danh sách mở rộng |

Mỗi lần mở vùng mới là một dịp làm video TikTok, kèm trang phục và sự kiện bảng xếp hạng theo quốc gia.

---

## 8. Việc cần làm tiếp
- [ ] Đặt tên chính thức cho game và cho thế lực "Trì Trệ"
- [ ] Chọn phong cách art, vẽ concept 1 vùng (Hy Lạp) + 2 trang phục
- [ ] Viết thoại chi tiết cho Kỳ công 1 (tutorial)
- [ ] Cân bằng số rep / HP boss cho từng kỳ công (cần dữ liệu từ [kehoach-mayao.md](kehoach-mayao.md) nhóm E)
- [ ] Kiểm tra lại các chi tiết thần thoại và lịch sử với nguồn đáng tin
- [ ] Tìm người bản xứ đọc lại cho 4 vùng ra mắt đầu tiên
