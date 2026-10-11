---
name: vector-game-art
description: Vẽ hoặc nâng cấp đồ hoạ vector bằng code (Flutter Canvas, lib/art/) cho game Solo Pushing Up — nhân vật, boss, quái, phông nền, hiệu ứng — theo phong cách cartoon trưởng thành kiểu Kingdom Rush/Darkest Dungeon-lite, không trẻ con. Dùng khi được yêu cầu vẽ, làm đẹp, làm đáng sợ, làm phức tạp hơn hoặc soát lại bất kỳ hình nào trong lib/art/.
---

# Đồ hoạ vector bằng code: quy trình và tiêu chuẩn

Không có hoạ sĩ: mọi hình vẽ bằng `Canvas` trong `lib/art/`. Mục tiêu là
hình đủ chất lượng lên store: **cartoon trưởng thành**, không phải tranh
thiếu nhi. Đọc `rules/dohoa.md` (nguyên tắc dự án) trước khi vẽ.

## 1. Quy trình bắt buộc (vòng lặp nhìn–sửa)

1. **Tham khảo trước khi vẽ.** Với nhân vật thần thoại: nhớ lại hình tượng
   trong sách/tranh cổ (gốm Hy Lạp, tranh Rubens, minh hoạ sách thần
   thoại) và ghi ra 3–5 đặc điểm nhận dạng. Chỉ học bố cục/đặc điểm, không
   chép hình.
2. **Phác khối lớn** (silhouette) trước, chi tiết sau. Silhouette phải đọc
   được khi tô đen toàn bộ.
3. **Xuất ảnh xem trước:** thêm case vào `test/art/art_preview_test.dart`
   rồi chạy
   `ART_PREVIEW=1 flutter test test/art/art_preview_test.dart --plain-name "<tên>"`.
   PNG nằm ở `build/art_preview/`. **Mở PNG bằng Read để tự nhìn.**
4. **Tự chấm theo bảng ở mục 3.** Mỗi mục "chưa đạt" → sửa → xuất lại.
   Ít nhất 2 vòng cho hình mới.
5. **Hiệu năng:** `flutter test test/art/perf_budget_test.dart` (< 2 ms/khung
   cả sân khấu). Phần tĩnh hoặc nặng → vẽ sẵn thành `Picture` (xem bờm sư tử
   trong `lion_art.dart`, khung chim trong `greek_monsters.dart`).
6. `flutter analyze`, `flutter test`, commit riêng từng hạng mục.

## Lý thuyết mỹ thuật làm nền (giáo trình kinh điển)

Mọi quyết định vẽ phải truy được về một nguyên lý dưới đây.

**Hình khối và tỉ lệ (Andrew Loomis, *Figure Drawing for All It's Worth*,
*Drawing the Head and Hands*).**
- Người lớn ≈ 8 đầu; anh hùng/thần ≈ 8,5–9 đầu (vai rộng 2,3 đầu). Nhân vật
  game được phép cách điệu (5,5–7 đầu) nhưng không xuống "chibi" 3–4 đầu.
- Đầu dựng theo "quả cầu cắt mặt + khối hàm" (ball and plane): có mặt phẳng
  bên, xương hàm, gò má. Mắt nằm ở nửa chiều cao đầu, nhỏ so với mặt.
- Mốc cơ thể: rốn ≈ 3 đầu, háng ≈ 4 đầu, gối ≈ 6 đầu (tính từ đỉnh đầu).

**Ánh sáng trên khối (chiaroscuro; Loomis, *Successful Drawing*; James Gurney,
*Color and Light*).** Thứ tự 6 vùng trên mọi khối tròn, từ phía sáng sang:
vệt sáng (highlight) → vùng sáng → trung gian (halftone) → **bóng lõi** (core
shadow, tối nhất) → **ánh phản xạ** (reflected light, sáng hơn bóng lõi
nhưng luôn tối hơn vùng sáng) → **bóng đổ** (cast shadow, cạnh sắc gần vật,
nhoè xa vật; đậm nhất ở chỗ tiếp xúc: occlusion). `shadedPath` cài sẵn 5
vùng đầu; bóng đổ vẽ riêng (bóng tiếp đất, bóng cánh tay lên thân).

**Màu (Gurney, *Color and Light*; Johannes Itten, *The Art of Color*).**
- Màu thấy được = màu bản thân × màu ánh sáng. Ánh sáng ấm thì bóng ngả
  lạnh và ngược lại (nhiệt độ màu tương phản giữa sáng và bóng).
- Phối cảnh không khí: càng xa càng nhạt, lạnh, ít tương phản.
- Itten — 7 kiểu tương phản: sắc độ, sáng–tối, nóng–lạnh, bổ túc, đồng thời,
  bão hoà, diện tích. Dùng tương phản bão hoà + diện tích để đặt điểm nhấn
  (mắt boss, vũ khí): mảng nhỏ bão hoà cao giữa mảng lớn trầm.
- Nhóm giá trị (notan): cả cảnh đọc được khi chỉ còn 3 mảng sáng/trung/tối.

**Ngôn ngữ hình khối (shape language, sách thiết kế nhân vật hoạt hình).**
Tròn = thân thiện, an toàn; vuông = vững chãi, đáng tin; tam giác/gai =
nguy hiểm, hung dữ. Người chơi và Hercules: khối vuông–tròn. Boss và quái:
tam giác, gai, bất đối xứng.

**Hoạt hình (Frank Thomas & Ollie Johnston, *The Illusion of Life*: 12
nguyên lý Disney).** Bắt buộc dùng: lấy đà (anticipation) trước mọi đòn;
co–giãn (squash & stretch) khi trúng đòn; chuyển động theo sau (follow
through: bờm, đuôi, áo choàng trễ nhịp); vào–ra chậm (ease in/out); cung
chuyển động (arcs); động tác phụ (secondary action: thở, chớp mắt); cường
điệu (exaggeration) cho đòn của boss; dàn dựng (staging): đòn quan trọng nhất
phải nằm trong vùng sáng, tương phản cao.

**Bố cục (composition).** Quy tắc một phần ba; đường dẫn mắt (lối mòn, tia
nắng) hướng về boss; vignette và tương phản cao nhất đặt ở vùng tranh chấp
giữa nhân vật và boss.

## 2. Kỹ thuật làm hình "trưởng thành"

| Trẻ con (tránh) | Trưởng thành (làm) |
|---|---|
| Tô phẳng 1–2 tông | 4 lớp: màu gốc → bóng lõi (core shadow) sắc cạnh → bóng tiếp xúc (occlusion) đậm ở khe/chỗ chồng → vệt sáng + **ánh viền** (rim light) màu trời/hậu cảnh ở mép khuất |
| Viền đen đều mọi nơi | Viền ngoài dày phía khuất sáng, mỏng phía sáng; **đường bên trong dùng màu sẫm của chính mảng đó** (sel-line), không dùng đen |
| Màu bão hoà thuần (vàng chanh, xanh lá cây) | Màu ngả về ánh sáng cảnh (chiều: ấm cam; đêm: lạnh xanh tím), giảm bão hoà ở mảng lớn, giữ bão hoà cao cho điểm nhấn (mắt, vũ khí, phép) |
| Mặt tròn, mắt to, đầu to | Tỉ lệ 5.5–7 đầu cho người lớn; xương hàm, gò má, gờ mày; mắt nhỏ, có mí, có bóng hốc mắt |
| Bề mặt trơn | Chất liệu: lông = các nét cong theo hướng mọc, đậm ở gốc; đá = vết rạn + đốm; kim loại = dải phản chiếu sắc + chấm loá; vải = nếp gấp theo lực kéo |
| Mọi chỗ chi tiết như nhau | Phân cấp chi tiết: mặt, tay, vũ khí dày chi tiết; mảng lớn (thân, nền) yên |
| Nhân vật "dán" lên nền | Bóng tiếp đất + bóng đổ lên nền, màu phản xạ từ đất lên mặt dưới, chỉnh màu toàn cảnh (lớp phủ ánh sáng + vignette) |
| Boss dễ thương | Silhouette gai góc/bất đối xứng, mắt phát sáng, nanh vuốt, sẹo, tư thế rình (đầu thấp hơn vai), tỉ lệ khổng lồ so với nhân vật |

## 3. Bảng tự chấm (mỗi ảnh xem trước)

- [ ] Silhouette đọc được ở cỡ điện thoại cách 1 m?
- [ ] Có đủ 4 lớp sáng–tối và ánh viền ở mép khuất?
- [ ] Đường bên trong là sel-line (không đen)?
- [ ] Có ít nhất một loại chất liệu nhìn ra được (lông/đá/kim loại/vải)?
- [ ] Bảng màu khớp ánh sáng cảnh; điểm nhấn bão hoà nằm đúng chỗ cần nhìn?
- [ ] Không có chỗ nào trông "trẻ con" (mặt tròn xoe, mắt to vô hồn, màu kẹo)?
- [ ] Boss/quái: đáng sợ ngay cái nhìn đầu? Cơ chế đọc được từ hình?
- [ ] Hướng sáng thống nhất: trên–trái (`VectorStyle.lightWorld`)?
- [ ] Tỉ lệ đúng Loomis (≥ 5,5 đầu)? Đủ 6 vùng sáng–tối? Bóng ngả nhiệt độ ngược ánh sáng?
- [ ] Hoạt hình có lấy đà, co–giãn, chuyển động theo sau?

## 4. Công cụ sẵn có (`lib/art/vector_style.dart`)

- `shadedPath`, `shadedChain`: viền lệch phía bóng + bóng + vệt sáng (+ ánh
  viền, bóng tiếp xúc khi bật).
- `furStrokes`, `hatch`: nét lông / gạch bóng trong vùng cắt.
- `glint`: chấm bóng loáng.
- `paintStageGrade`: chỉnh màu toàn cảnh + vignette (vẽ sau cùng).
- `capsulePath`, `chainPath`: tay chân thon dần.

## 5. Hiệu năng

- Không `Path.combine` mỗi khung. Mỗi `clipPath` có giá: gộp nhiều mảng cùng
  màu vào một `Path` rồi tô một lần.
- Hình lặp (bầy chim, bờm, chùm lá) → `Picture` dựng sẵn, mỗi khung chỉ
  biến đổi (xoay/co giãn) khi vẽ.
- Test hiệu năng đầu file chịu tải biên dịch: đặt cảnh nặng nhất ở cuối.
- Widget hoạt hình dùng `Ticker`: khởi động trong `initState`
  (`_ticker.start()`), **không** viết `late final _ticker = createTicker(..)..start()`
  vì `late` chỉ khởi tạo khi truy cập lần đầu (thường là lúc dispose) nên
  hình đứng im. Viết widget test có `pump` để chắc hình có chạy.

## 6. Thiết kế màn và game feel (xem rules/dohoa.md mục 5)

- Chương nhiều màn: độ khó răng cưa, mỗi cơ chế theo kishōtenketsu.
- Mọi đòn kẻ thù có dấu hiệu báo trước riêng, cố định; đọc được ≥ 0,6 giây.
- Mỗi đòn trúng: hitstop + loé trắng + giật lùi + rung khung + hạt.
- Ánh sáng đổi theo hành trình trong chương (`BossArt.gradeLight`).

## 7. Art bible tối thiểu (từ CCGS `rules/thamkhao/ccgs/templates/art-bible.md`)

- **Luật hình ảnh một dòng:** "Thần thoại khắc gỗ sống dậy — mọi thứ có khối,
  có ánh sáng một hướng, và chuyển động theo nhịp rep." Design test: hình mới
  phẳng, không ánh sáng trên-trái, hoặc đứng im khi người chơi hít đất → sửa.
- **Màu có nghĩa (giữ cố định):** vàng = sức mạnh người chơi / đòn trúng; tím
  xám = Trì Trệ / thứ bị nhiễm; đỏ = nguy hiểm sắp tới (báo đòn); xanh độc =
  chất độc; lục lam = nước/lạnh. Mỗi màu luôn kèm hình dạng/âm riêng (dự phòng
  mù màu: đỏ–xanh lá không bao giờ là cặp duy nhất phân biệt).
- **Mood theo trạng thái:** sẵn sàng (ánh sáng dịu, bụi đứng), giao chiến (tương
  phản cao), sắp bị đánh (đỏ + rung), thắng (ấm, sáng, hạt vàng), thua (nhạt màu).
- **Kiểm hình bóng:** quái/boss phải nhận ra khi tô đen hết ở cỡ 48 px.

## 8. Dựng người như hoạ sĩ: xương → cơ → da → quần áo

Thư viện `packages/vector_anatomy` (xem README của nó):
1. **Xương**: khớp từ `HeroPose` (vai, khuỷu, cổ tay, hông, gối, cổ chân).
2. **Cơ**: mỗi đoạn chi có `MuscleProfile` — đường bao mặt trước/sau độc lập
   (đỉnh phồng lệch độ cao, một mặt gần thẳng) và **các bó cơ `MuscleBelly`**
   bám gốc → điểm bám, khai báo cơ sâu trước, cơ nông sau.
3. **Da**: `shadedLimb` tô thân chi đổ bóng 6 vùng, rồi tô **từng bó cơ thành
   khối riêng** (bóng che ở mép khuất + nửa sáng / nửa tối), mềm theo
   `definition` (người thường ~0,5, anh hùng ~0,8–1); rãnh cơ là nét thon.
4. **Quần áo** vẽ sau cùng.

Không vẽ cơ bằng nét đè lên một ống trụ — độ sâu đến từ khối chồng khối.
Tay chân phía xa (khuất, tối) đặt `definition: 0` để tiết kiệm hiệu năng.

## 9. Ngân sách hiệu năng cho nhân vật nhiều chi tiết

- Đo từng phần trước khi tối ưu (Stopwatch tạm trong hàm vẽ) — đừng đoán.
- Bộ phận ít đổi (đầu, mặt, tóc) → `Picture` cache theo khoá (ngoại hình,
  góc làm tròn 5°, biểu cảm làm tròn) — xem `_cachedHead` trong `hero_art.dart`.
- Chi phía xa (bị thân che, màu tối): ống thuôn rẻ, không bó cơ/phụ kiện.
- Nét ngắn (quai, rãnh): ít điểm mẫu (`samples: 6`).
- Windows Defender quét làm số đo đội lên gấp đôi; so sánh tương đối với
  commit trước trên cùng máy, cùng lúc.
