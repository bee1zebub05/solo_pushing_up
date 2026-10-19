---
name: vector-game-art
description: Vẽ hoặc nâng cấp đồ hoạ vector bằng code (Flutter Canvas, lib/art/) cho game Solo Pushing Up — nhân vật, boss, quái, phông nền, hiệu ứng — theo phong cách cartoon trưởng thành kiểu Kingdom Rush/Darkest Dungeon-lite, không trẻ con. Dùng khi được yêu cầu vẽ, làm đẹp, làm đáng sợ, làm phức tạp hơn hoặc soát lại bất kỳ hình nào trong lib/art/.
---

# Đồ hoạ vector bằng code: quy trình và tiêu chuẩn

Không có hoạ sĩ: mọi hình vẽ bằng `Canvas` trong `lib/art/`. Mục tiêu là
hình đủ chất lượng lên store: **cartoon trưởng thành**, không phải tranh
thiếu nhi. Đọc `rules/dohoa/phongcach.md` (nguyên tắc dự án) trước khi vẽ.

## 0. Tờ spec trước khi vẽ (bắt buộc cho mọi hình MỚI)

LLM thực thi một bản mô tả DÀY rất tốt, nhưng tự nghĩ ra thì ra "trung bình"
nhạt. Vì vậy **không vẽ từ một câu** ("vẽ con rồng dữ tợn"): trước khi mở
`lib/art/`, viết tờ spec 12–20 dòng và **xin người dùng chốt** (hoặc chốt dựa
trên ảnh tham khảo họ đưa). Gu nằm ở tờ này, không nằm ở lúc vẽ.

Tờ spec phải có:
- **Silhouette một dòng:** khối tổng đọc được khi tô đen (vd "tam giác ngược,
  vai gai, đầu thụt thấp hơn vai").
- **3 hình khối chữ ký** khiến con này khác mọi con cùng loài — không phải
  "con rồng" chung, mà: sừng mấy nhánh cong kiểu gì, pattern vảy, bất đối xứng ở đâu.
- **Bảng màu — mã hex cụ thể** cho thân / điểm nhấn / ánh viền, khớp màu-có-nghĩa mục 7.
- **Tỉ lệ** (số đầu, Loomis ≥ 5,5) và **tư thế / mood** (rình, gầm, thủ thế).
- **Ảnh tham khảo thật:** ≥ 3 ảnh đặt ở `art_src/ref/<tên>/` (ghi nguồn + giấy
  phép). Không có ảnh thật → agent đang so với tưởng tượng → ra ngô nghê.
- **"Điểm khác biệt":** một câu nói con này độc ở đâu so với bản generic.

Thiếu tờ spec → dừng, viết trước. Spec là đầu vào của bảng tự chấm mục 3 và
của critic mắt-lạ ở mục 1.

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
4. **Tự chấm theo bảng ở mục 3** so với tờ spec (mục 0) và ảnh tham khảo.
   Mỗi mục "chưa đạt" → sửa → xuất lại.
5. **Critic mắt-lạ — bắt buộc cho hình mới (đây là thuốc chữa "ngô nghê").**
   Người vẽ luôn khoan dung với hình của mình → tự chấm hay dừng non. Gọi một
   reviewer ĐỘC LẬP (tool Agent, `general-purpose`) và đưa ĐÚNG: (a) đường dẫn
   PNG vừa xuất, (b) đường dẫn ≥ 1 ảnh tham khảo thật, (c) tờ spec mục 0,
   (d) bảng tự chấm mục 3. **Không nói rằng mình vừa vẽ nó.** Yêu cầu: "Chấm
   1–10 so với ảnh tham khảo và chuẩn cartoon trưởng thành; liệt kê ≥ 6 điểm
   trông nghiệp dư/ngô nghê theo từng vùng; chỉ khen khi thật sự đạt." Sửa
   theo nhận xét → xuất lại → gọi critic MỚI. **Lặp tới khi critic cho ≥ 8/10**,
   đừng dừng ở "mình thấy ổn" (oni cần ~9 vòng).
6. **Hiệu năng** (rules/dohoa/vaogame.md): ngân sách chính là đo trên máy
   thật bằng `lib/dev/perf_bench_main.dart` — GPU tô ≤ 16 ms/khung, ghi lệnh
   ≤ 5 ms. `flutter test test/art/perf_budget_test.dart` (< 3 ms ghi lệnh
   trên PC) chỉ là lưới chặn hồi quy. Phần tĩnh → `RasterLayer` (ảnh chụp
   sẵn, xem bờm/thân sư tử trong `lion_art.dart`); phần lặp đổi theo khung →
   `Picture` (khung chim trong `greek_monsters.dart`).
7. `flutter analyze`, `flutter test`, commit riêng từng hạng mục.

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
- [ ] Mặt quái/rồng không có hàng vảy cung nằm ngang dưới mắt? (ở cỡ điện
      thoại nó đọc thành **miệng mỉm cười** — dùng tấm vảy sọ dọc sống mũi,
      sọc tối sau mắt, vảy li ti ở má).
- [ ] Chi có khớp (khuỷu, gối, hock) chứ không phải "cột thẳng"? Tay cầm vũ
      khí nhìn thấy được từ vai tới nắm tay?

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

## 6. Thiết kế màn và game feel (xem rules/dohoa/phongcach.md)

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

## 10. Ảnh chụp sẵn và GPU điện thoại (đo trên máy thật 12/10/2026)

- `RasterLayer` nằm trong thư viện `packages/stage_raster` (xuất lại qua
  `vector_style.dart`): ngân sách bộ nhớ chung `RasterBudget.shared` (LRU,
  trần 3,6 điểm ảnh/đơn vị), sân khấu tự giải phóng khi rời trận.
- Cùng một lớp mà cần hai tông (sạch / phủ bụi) → **một ảnh**, vẽ lại qua
  `paint(colorFilter: ...)`; đừng giữ ảnh thứ hai.
- Lớp xa (trời, núi) dùng `resolution` < 1: mềm hợp phối cảnh không khí,
  tiết kiệm bộ nhớ.
- **Không dùng `MaskFilter.blur` cho thứ vẽ mỗi khung** — thay bằng
  `Gradient.radial` mờ dần. Blur chỉ dùng trong lớp chụp sẵn.
- Impeller tính "raster" gồm cả chia tam giác đường cong vector: mọi thứ
  vector vẽ mỗi khung (mây, tiền cảnh…) đều tốn; tĩnh thì chụp sẵn.
- Đo: `bash tool/bench_device.sh` (dọc + ngang, bộ nhớ ảnh, log BENCH).
- **`PictureCache` chỉ tiết kiệm CPU; GPU vẫn tô lại mọi đường cong mỗi
  khung.** Mỗi `shadedPath` = 2 lần `clipPath` + nhiều lớp phủ → rất đắt trên
  Impeller. Nhân vật chính tốn ~6,6 ms GPU/khung cho tới khi chụp thành ảnh
  theo tư thế làm tròn (`paintHero(cacheKey:)`, góc khuỷu bước 2°).
- Mẫu chung cho vật động lặp lại: làm tròn đầu vào (góc, pha thở) thành
  khoá → `RasterLayer` theo khoá (LRU) → phần thay đổi liên tục (hào quang,
  hạt) vẽ riêng ngoài ảnh; lúc chuyển trạng thái thì vẽ vector.
- Đo bóc tách: `StageQuality.hero/boss/grade/dust` tắt từng phần trong bench.
- Sau mỗi thay đổi giao diện trận: chụp màn hình trên máy thật (test không
  có màn trận vì cần camera) — từng làm mất thanh máu mà test không bắt.

## 11. Quái động và CPU dựng khung (đo trên máy thật, đêm 12/10/2026)

- Màn quái phải có trong bench (`tool/bench_device.sh` đo đủ 7 màn quái):
  đàn chim từng chỉ ~28 fps (CPU 26 ms + GPU 26 ms) vì 5 con vẽ vector mỗi
  khung; Harpy ~40 fps.
- Mẫu `_FrameCache` (greek_monsters.dart): ảnh theo **pha chuyển động lặp**
  (12–24 pha) × mức ra đòn (7–9 mức). Muốn vòng pha liền mạch thì mọi
  chuyển động phụ (tóc, đuôi, lông cổ, sóng) phải **cùng tần số** (hoặc bội
  số) với chuyển động chính. Loé trúng đòn = `colorFilter` trên ảnh, không
  cần lớp.
- Phần chỉ phụ thuộc một tham số nhỏ (độ há hàm, vị trí đầu làm tròn 0,5)
  → `PictureCache` theo khoá: mặt Thuỷ Tinh, đầu Fafnir, cổ Orochi. CPU
  paintBoss giảm 3–5 lần.
- Tìm chỗ tốn CPU bằng `StageProfile` (battle_stage.dart): bench in
  `cpu-parts` (nền / cảnh / boss / nhân vật / tiền cảnh / tổng render) mỗi
  pha. Bọc tạm `StageProfile.run('tên', ...)` quanh hàm con để bóc tách.
