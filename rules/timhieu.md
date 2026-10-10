# Tìm hiểu: Pushup RPG: Fitness Quest

> Ngày tìm hiểu: 2026-10-09
> Nguồn: App Store listing, website chính thức pushup.quest, press release (31/08/2026), Kotaku. Không đọc được trang Google Play (trang trả về rỗng), nên số liệu Android lấy từ website của dev.

## 1. Thông tin chung

| Mục | Chi tiết |
|---|---|
| Tên | Pushup RPG: Fitness Quest |
| Subtitle (iOS) | Push Up & Squat Counter Game |
| Tagline | "Your pushups are the weapon." |
| Developer | Yerasyl Amanbek (solo dev), studio **ReLife Studio**, Kazakhstan |
| Website | https://pushup.quest |
| iOS | https://apps.apple.com/us/app/pushup-rpg-fitness-quest/id6782316565 |
| Android | https://play.google.com/store/apps/details?id=com.pushuprpg (package `com.pushuprpg`) |
| Category | Health & Fitness |
| Giá | Free + In-App Purchases |
| Dung lượng iOS | 58.9 MB, yêu cầu iOS 17+ |
| Age rating | 9+ |
| Ngôn ngữ app | 13: EN, AR, ZH (Trad), CS, FR, DE, JA, PL, PT, RU, ES, TR, **VI** |
| Phiên bản gần nhất | 2.5.11 (tháng 10/2026) |
| Ra mắt | Khoảng tháng 6–7/2026 (version cũ nhất trên store là 1.7.3, 14/07/2026) |
| Các app khác của dev | ReLife: Habit & Todo RPG, Tutorial AI: Study Tutor, Willu: Invitations & RSVP |

### Traction
- **100,000+ installs** trên iOS + Android sau khoảng 2 tháng ra mắt (press release 31/08/2026, số do dev tự công bố). Tăng trưởng nhờ **video push-up viral** trên mạng xã hội.
- Rating: **4.8★ App Store** (website ghi 2,619 ratings; trang store lúc fetch hiện 998), **4.9★ Google Play** (1,661 ratings, theo website).
- Kênh social: TikTok, Instagram, YouTube (@pushuprpg), Telegram, Discord.

## 2. Ý tưởng cốt lõi
Camera trước của điện thoại dùng **pose detection on-device** để đếm rep hít đất / squat theo thời gian thực. **Mỗi rep = một đòn tấn công** vào quái vật trong game RPG. Bối cảnh là dark fantasy, nhiều người so sánh với *Solo Leveling* (đúng với tên folder dự án này: solo-pushing-up).

## 3. Bài tập hỗ trợ
| Bài tập | Cách track | Vai trò |
|---|---|---|
| Push-up | Camera đếm rep | **Dùng cho combat**, XP, gold, loot, leaderboard |
| Squat | Camera đếm rep | **Dùng cho combat** (toàn bộ campaign chơi được bằng squat), có record, streak, leaderboard riêng |
| Sit-up | Camera đếm rep | Chỉ Free Training: giữ streak, không có XP/loot |
| Plank | Tính thời gian (tổng giây, lần giữ lâu nhất) | Chỉ Free Training |
| Pull-up, Dips | Camera | Chỉ Free Training (thêm ở v2.5.1) |

- Push-up chạy tốt nhất khi **đặt điện thoại dưới sàn, hướng camera vào người** (v2.5.11).
- Gear tốt hơn làm mỗi rep gây nhiều damage hơn, nhưng **không bao giờ giảm số rep yêu cầu** của quái.

## 4. Game modes
1. **Campaign**: 8 biome, **48 quái + boss** vẽ tay, boss cuối là **Aurelion, the Astral Eye**. Có **New Game+** (v2.5.9).
2. **Endless Descent**: dungeon roguelike, không có điểm kết thúc. Free tới floor 10, sâu hơn cần Vigil.
3. **Live Duels (40 giây)**:
   - Đấu với bạn bè, với **6 rival tốc độ cố định** (Ironfang Wolf, Tempest Eye, Nightwyrm, ...) hoặc **Arena** ghép người chơi cùng level.
   - Cả hai camera cùng đếm rep, **dây kéo co (tug-of-war rope)** di chuyển theo từng rep.
   - Có duel push-up và duel squat. Có thể quay và share trận, kết quả có result card để share.
   - Không có chat, chỉ có report hoặc block. Chỉ gửi **số rep** qua mạng, không gửi video.
4. **Proving mode** (v2.5.0).
5. **Free Training**: các bài phụ ở bảng trên.

### Cơ chế combat
- Quái có **rule modifiers** (luật đặc biệt).
- Boss **đổi stance giữa trận**.
- Một số trận **giới hạn thời gian**.

## 5. Progression (RPG)
- XP, level.
- **4 stats**. Store ghi Power / Stamina / Precision / Fortune; website và press release ghi Strength / Endurance / Agility / Willpower (có thể đã đổi tên).
- **Skill tree 3 nhánh**: Might, Vitality, Focus.
- **Loot** theo rarity, từ Common tới Legendary/Mythic.
- **Forge**: equip, upgrade, reforge, salvage, craft gear.
- Portraits, titles, rank sharing.
- Companion tên **Cinder**.

## 6. Retention và engagement
- Quest ngày, tuần, quest boss, **weekly trial chest**.
- **Streak** có freeze token, Streak Shield, guided rest day.
- PAYDAY gold claim (v2.4.2).
- Notifications, **Live Activities**, **Widgets**, tích hợp **Apple Health** (squat).

## 7. Social
- Thêm bạn bằng code.
- **Guild** đánh **boss chung hàng tuần** (Guild Boss Race). Tạo guild cần Vigil.
- Leaderboard ngày và tuần: **toàn cầu / theo quốc gia / bạn bè**, chia riêng push-up và squat. Có cờ quốc gia cạnh tên.
- **Cheers** (cổ vũ).

## 8. Monetization
Core game và đếm rep miễn phí. Membership **không bán gear hay stats** (không pay-to-win).

**Vigil Membership** gồm: tạo guild, Endless Descent không giới hạn, insights, tên màu vàng + vương miện, Streak Shield.

| Gói (iOS, USD) | Giá |
|---|---|
| Vigil Weekly | $4.99 |
| Vigil Monthly | $9.99 |
| Vigil Yearly | $39.99 (trial 7 ngày) |
| Vigil Lifetime | $99.99 |
| Gem Pouch | $1.99 |
| Gem Satchel | $4.99 |
| Gem Coffer | $9.99 |
| Gem Vault | $19.99 |

## 9. Tài khoản và privacy
- Chơi **guest** không cần đăng ký. Đăng nhập Apple, Google hoặc email để sync nhiều thiết bị và mở friends leaderboard.
- Pose detection chạy **on-device, trong memory, chỉ khi đang tập**. Không upload video hay landmarks.
- Quay clip là tùy chọn, mặc định tắt.
- Xóa tài khoản ngay trong app.
- Có disclaimer: không phải lời khuyên y tế, không phải thiết bị y tế.

## 10. Lịch sử phát triển (rút gọn)
| Version | Ngày (2026) | Nội dung |
|---|---|---|
| 1.7.3 | 14/07 | Bản sớm nhất còn trên store |
| 2.0.0 | 17/07 | Thêm Squat, làm mới visual |
| 2.3.1 | 03/08 | Live duel với bạn + 6 rival |
| 2.4.1 | 19/08 | **Arena**, leaderboard quốc gia, cờ |
| 2.4.2 | 23/08 | Plank, sit-up, PAYDAY, titles |
| 2.5.0 | 31/08 | Arena notifications, Proving mode |
| 2.5.1 | 02/09 | Pull-up, dips, nhắc liên kết guest |
| 2.5.4 | 12/09 | Thêm FR, **VI**, PL, CS |
| 2.5.5 | 16/09 | Cải thiện form detection |
| 2.5.7–2.5.8 | 22–26/09 | Squat duel, nâng cấp trình bày duel |
| 2.5.9 | 29/09 | New Game+, sync nhiều thiết bị |
| 2.5.11 | ~08/10 | Khuyến nghị đặt phone dưới sàn |

Tốc độ release rất nhanh: gần như mỗi 3–5 ngày có một bản.

## 11. Feedback người dùng
**Khen:**
- Tạo động lực, hít đất nhiều hơn. Hệ thống reward hay, hợp với gamer.
- Cảm giác giống Solo Leveling.

**Chê và yêu cầu:**
- **Camera đôi khi đếm sai hoặc miss rep**, nhất là khi khuỷu tay ra khỏi khung hình. Có review nói tracker "không hoạt động".
- Vào guild bị khóa sau paywall.
- Chủ guild bị spam yêu cầu join, không giới hạn được.
- Muốn thêm pull-up vào combat và thêm realm sau Realm 8.

## 12. Đối thủ và app tương tự
Push Up Arena, PUPG (Push Up Playground), RepChamp, RepHero (Push-Up Quest), GymQuest, PushUpLock, Conqr, Pushoff, RepScroll, Push Up Boss, Golden PushUps, **Arise: Level Up Workout Game** (theme Solo Leveling).
Website của dev có lưu ý rằng "Push Up Quest" và "PushUp Quest" **không liên quan** đến họ.

## 13. Bài học cho dự án solo-pushing-up
- **Core loop đơn giản**: rep thật → damage → loot → mạnh hơn → boss khó hơn.
- **Đếm rep bằng camera on-device** (MediaPipe / ML Kit / Apple Vision) là trái tim sản phẩm. Độ chính xác là pain point số 1 trong review, nên cần đầu tư: góc đặt máy, xử lý khi chi ra khỏi khung, hướng dẫn setup.
- Chỉ 2 bài (push-up, squat) cho combat, các bài khác để giữ streak. Phạm vi gọn mà vẫn mở rộng được.
- **Duel 40 giây + tug-of-war** là tính năng viral, dễ quay video ngắn cho TikTok. Đây là động lực chính để đạt 100k installs.
- Retention: streak + freeze, daily/weekly quest, leaderboard quốc gia.
- Monetization không pay-to-win: subscription bán tiện ích, social status (tên vàng, vương miện), mở content (endless) và tạo guild. Gem cho cosmetic/tiện ích.
- Hỗ trợ đa ngôn ngữ sớm, có cả tiếng Việt.
- Khoảng trống có thể khai thác: theme Solo Leveling rõ ràng hơn (hệ thống "System", hunter rank E→S, dungeon gate), đưa pull-up vào combat, quản lý guild tốt hơn, nhiều content endgame hơn.

## Nguồn
- App Store: https://apps.apple.com/us/app/pushup-rpg-fitness-quest/id6782316565
- Google Play: https://play.google.com/store/apps/details?id=com.pushuprpg
- Website: https://pushup.quest
- Press release (WBOC): https://www.wboc.com/online_features/press_releases/pushup-rpg-fitness-quest-surpasses-100-000-installs-following-viral-push-up-videos/article_a200e8e3-2bae-5c6b-a4a5-1df49705b4b9.html
- Kotaku: https://kotaku.com/games/pushup-rpg-fitness-quest
- AppsHunter: https://appshunter.io/ios/app/pushup-rpg-fitness-quest/id6782316565
