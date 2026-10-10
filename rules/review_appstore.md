# Phân tích review App Store: Pushup RPG

> Ngày gom: 2026-10-09
> Nguồn: RSS công khai của Apple (`itunes.apple.com/{country}/rss/customerreviews/...`), 30 quốc gia.
> Dữ liệu thô: [reviews_appstore.csv](reviews_appstore.csv) (country, date, rating, version, author, title, content)
> Liên quan: [timhieu.md](timhieu.md), [kehoach-mayao.md](kehoach-mayao.md)

**Lưu ý về độ phủ:** RSS chỉ trả về những review **có viết nội dung**, tối đa khoảng 500 review mỗi nước. App có hơn 2,600 rating nhưng phần lớn chỉ bấm sao, không viết gì. Mẫu này vì vậy thiên về những người có điều muốn nói. Số đếm theo chủ đề bên dưới là ước lượng sau khi đọc tay từng review.

---

## 1. Tổng quan số liệu

**Tổng:** 351 review có nội dung, từ 25/06/2026 đến 06/10/2026.

| Sao | Số review | % |
|---|---|---|
| 5★ | 283 | 80.6% |
| 4★ | 38 | 10.8% |
| 3★ | 13 | 3.7% |
| 2★ | 6 | 1.7% |
| 1★ | 11 | 3.1% |

**Theo quốc gia:** US 162 · GB 25 · CA 22 · **VN 19** · FR 13 · TW 13 · MX 10 · BR 10 · KZ 8 · DE 8 · RU 7 · TR 7 · AU 7 · các nước khác ≤5.
→ **Việt Nam đứng thứ 4**, dù lúc đó app chưa có tiếng Việt (mới thêm ở v2.5.4, 12/09). Đây là tín hiệu thị trường VN có nhu cầu thật.

**Giai đoạn bùng nổ:** review dày đặc nhất trong khoảng **01–16/08/2026**, trùng với đợt video viral trên TikTok. Nhiều người nói rõ họ thấy app trên TikTok hoặc mạng xã hội.

---

## 2. Người dùng KHEN gì

| Chủ đề | Mức độ | Trích dẫn tiêu biểu |
|---|---|---|
| **Miễn phí, không ép trả tiền, không quảng cáo** | **Lời khen số 1**, khoảng 40 review | "I thought you definitely needed to pay for a subscription but you don't", "No ads and no crashes", "không ngờ nó free thật… không có quảng cáo vậy app kiếm sống bằng cách nào?" |
| Biến việc tập thành game, tạo động lực | Rất nhiều | "every time i beat a foe i think 'i can do one more'", "I had done more pushups than I've ever done without even realizing" |
| Tiến bộ thật, đo được | Khoảng 10 | 5→26 rep, 6→25, 10→20, 100→300–500/ngày, "2600 push-ups in 15 days", "8,000 push-ups" |
| Thi đấu với bạn bè, bảng xếp hạng | Khoảng 10 | "Love tracking my friends' progress", "you can be the best in your country", "My boys gonna get smoked" |
| Hợp với gamer / người lười | Khoảng 10 | "as a gamer I am excited to do it now", "perfect for someone whos lazy" |
| Cảm giác Solo Leveling | Vài review | "reminds me so much of the anime Solo Leveling", "Fun way to Solo leveling!!" |
| Có thể tập offline | 1 | "kan zonder wifi" |

**Insight:** Mô hình **"free thật + membership chỉ là perk"** là vũ khí marketing mạnh nhất của họ. Người dùng ngạc nhiên vì *mọi app fitness khác đều bắt trả tiền*, nên chủ động khen việc này và còn tự nguyện mua để ủng hộ ("will be buying subscription", "metere unas moneditas").

---

## 3. Người dùng CHÊ gì

### 3.1 Đếm rep sai: vấn đề số 1, áp đảo
- Có mặt trong khoảng **34/68 review 1–4★ (một nửa)**, cộng thêm khoảng 12 review 5★ vẫn phàn nàn.
- **Gần như toàn bộ review 1★** đều là vì tracking.

Các kiểu lỗi cụ thể:

| Kiểu lỗi | Ví dụ |
|---|---|
| Đếm thiếu rất nặng | "did 20 and yal only counted 3", "10 pushups and it read 2", "40 full push-ups, counted only half", "отжался… всего 2" |
| Làm nhanh thì miss | "when I do it fast it doesn't register", "you have to do them really slow" |
| Khuỷu tay ra khỏi khung hình | "won't register if my elbow goes out of frame" |
| Nhận nhầm khớp | "thought my arms were my legs", "keeps making my shoulders the hip point" |
| Phải nhìn vào camera mới đếm | "if i dont look at the camera… it dosent count" |
| Đếm thừa / gian lận được | "me kneeling counted the push ups", "when I swing it counts as a rep", "when i'm getting prepped it will count the movement" |
| Phụ thuộc ánh sáng & khoảng cách | "needs to be bright and u need to go a bit far away", "camera has to be angled perfectly at the right distance" |
| Camera zoom quá gần, phòng nhỏ không đủ chỗ | "option to rotate the camera… or a zoom out feature" |
| **Update làm hỏng tracking** | "most recent update has made the rep counter for all exercises very unreliable" (22/08), "now it forces itself sideways" |
| **Ép sai form, có thể gây chấn thương** | "You are lucky to have a rep counted with your elbows ALL the way out… You will hurt yourself" |

Mẹo người dùng tự tìm ra: **đặt máy nghiêng một góc** để camera thấy khuỷu tay thì đếm tốt hơn.

Gợi ý kỹ thuật từ một user leo núi: *"assume the hips stay where they need to be, and just go off of arm angle and shoulder angle and chest distance from floor"*. Nghĩa là đừng bắt buộc phải thấy hông suốt cả set.

### 3.2 Hết nội dung / endgame yếu (khoảng 10 review)
- "Once you complete the adventure there's no way for me to progress", "主線打完後沒東西玩了" (đánh xong cốt truyện chính thì hết cái để chơi).
- Endless Descent bị chặn ở **tầng 10 cho người free**, nên chơi xong là chán.
- Squat chỉ có 8 tầng, xong là hết.
- Sau level 90 rất khó kiếm gold; **31 rep trong 22 giây** vượt quá khả năng đếm của camera.
- **Chỉ số đồ (item stats) "gần như vô nghĩa"**: nâng cấp nhiều nhưng không thấy khác biệt.
- Ít đồ, gold không có gì để tiêu.

### 3.3 Giá và paywall (khoảng 6 review)
- "$4.99/tuần là quá vô lý" (DE: 1★ "knapp 5€ pro Woche (wtf)"; GB: "pricing… absolutely wild").
- Muốn **trả một lần** (khoảng €10) thay vì subscription.
- Guild bị khoá sau paywall.

### 3.4 Social / duel lỗi
- Duel bạn bè bị lỗi kết nối: "won't let us 1v1", "chỉ đấu được 1 lần, lần 2 không cho".
- Thông tin bạn bè cập nhật chậm; bảng xếp hạng thế giới bị "cap", không hiện điểm thật.
- **Chủ guild bị spam hơn 100 yêu cầu tham gia**, phải duyệt từng cái một, không tắt được.
- Muốn có guild chat.

### 3.5 Các lỗi và phàn nàn khác
- **Không nghe được Spotify khi tập** (một bản update đã làm hỏng việc này, có review 1★).
- **Mất save và mất membership đã mua** (doạ kiện).
- Ảnh trong game **rõ là làm bằng AI**, bị trừ sao: "-1 star because they used AI for the images", "probably made by Replit".
- App phức tạp: chế độ giới hạn thời gian bắt đầu trước khi người dùng kịp làm xong.
- Item nhận được từ boss chỉ hiện tên danh sách chứ không hiện tên item (user VN).
- Muốn có ngôn ngữ của mình: RU, PT-BR, ZH, KO. Một phần đã được thêm sau này.

---

## 4. Người dùng MUỐN gì (feature requests)

| Yêu cầu | Số lần | Ghi chú |
|---|---|---|
| Thêm bài tập: **pull-up**, sit-up, squat, dead hang, giãn cơ | Khoảng 10 | Pull-up được nhắc nhiều nhất. Họ đã thêm nhưng chỉ ở mức Free Training |
| Cho bài phụ (sit-up, plank, pull-up) có **duel/dungeon riêng** | 2–3 | Hiện tại các bài này không có XP |
| Thêm realm, quest, gear mới | Khoảng 6 | |
| Ngôn ngữ địa phương | Khoảng 9 | |
| **Multiplayer theo đội đánh boss** (party) | 2 | |
| Trận đấu dài hơn (2 phút) | 1 | |
| **XP khác nhau theo biến thể push-up** | 1 | |
| **Chế độ chậm, không giới hạn thời gian** (tập chậm hiệu quả hơn) | 1 | |
| **Báo cáo sau set**: form đúng không, có tiến bộ hơn lần trước không | 1 | |
| Mỗi bài tăng một chỉ số riêng (push-up → Strength, plank/chạy → Endurance), đếm bước chân, kết nối đồng hồ thông minh | 1 | Ý tưởng "nuôi nhân vật riêng" |
| Xem camera của đối thủ (khi cả hai đồng ý) để chống gian lận | 1 | |
| Restart cốt truyện nhưng giữ loot | 1 | Đã có (New Game+) |
| Nghe nhạc riêng khi tập | 2 | |
| Duyệt/từ chối tất cả yêu cầu vào guild | 2 | |

---

## 5. Review từ Việt Nam (19 review)
- Hầu hết 5★, ngắn gọn: "Hay lắm ae=)) hít đất đánh boss", "quá là múp còn free", "Cảm giác như chơi game vậy mà còn free nữa".
- 1 review 1★ rất gay gắt vì **chống mỏi tay mà không được điểm nào** (tracking).
- 1 review 4★ góp ý kỹ: UI/UX 9/10, lỗi tên item, muốn có duel và dungeon cho sit-up, plank, pull-up.
- "Pls full miễn phí": người dùng VN rất nhạy cảm với giá.

---

## 6. Kết luận cho dự án solo-pushing-up

1. **Độ chính xác đếm rep là cơ hội lớn nhất.** Một nửa số review tiêu cực là vì tracking. Nếu làm được "đếm đúng ngay lần đầu" thì đó là lý do để người dùng chuyển sang app mình. Những trường hợp phải xử lý được:
   - Làm nhanh (dưới 1 giây/rep).
   - Khuỷu tay ra khỏi khung, hông bị che.
   - Phòng nhỏ, ánh sáng yếu.
   - Không đếm khi quỳ, khi đung đưa người hoặc khi đang chuẩn bị tư thế.
   - **Không ép người dùng mở rộng khuỷu tay** (an toàn).
2. **Không được làm hỏng tracking khi update.** Cần một bộ video regression test (xem [kehoach-mayao.md](kehoach-mayao.md) mục 2) và chạy lại trước mỗi lần release.
3. **Giữ mô hình "free thật".** Đây là lời khen số 1. Thêm **gói trả một lần** (lifetime giá thấp hoặc theo khu vực), vì giá theo tuần bị ghét.
4. **Đầu tư endgame từ đầu**: ít nhất endless mode miễn phí, và mỗi lần nâng cấp gear phải thấy rõ hiệu quả.
5. **Độ khó phải theo kịp giới hạn của camera.** Không yêu cầu số rep/giây vượt khả năng đếm.
6. **Mọi bài tập đều có giá trị trong game**: pull-up, plank, sit-up đều tăng chỉ số riêng. Đây là yêu cầu được nhắc nhiều.
7. **Art tự làm hoặc có phong cách riêng.** Ảnh rõ là AI bị chê, và cộng đồng gamer nhạy cảm với chuyện này.
8. **Những tính năng nhỏ nhưng được đòi nhiều:**
   - Cho phép nhạc nền (Spotify) chạy khi tập.
   - Duyệt hàng loạt và đóng/mở yêu cầu vào guild.
   - Guild chat.
   - Báo cáo sau mỗi set.
   - Chế độ tập chậm không giới hạn thời gian.
9. **Thị trường VN đã có nhu cầu thật** (đứng thứ 4 về số review). Làm tiếng Việt chuẩn ngay từ đầu, giá phù hợp người dùng VN, marketing bằng TikTok.
10. **Sync cloud chắc chắn.** Mất save là review 1★ kèm doạ kiện.
