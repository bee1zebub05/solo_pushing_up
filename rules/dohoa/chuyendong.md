# Phòng Chuyển động (biên đạo, mocap võ học, mô hình học chuyển động)

Code: `tool/motion/` (`choreo.py`, `choreo/*.json`, `gen_choreo.py`, `mocap_drive.py`,
`<boss>_motion.py`, `mocap/`). Skill: `boss-motion`. Nhận rig + dáng chờ đã duyệt
từ phòng Dựng hình; bàn giao biên đạo JSON + đòn mocap (`art_src/mocap/moves/*.npz`)
cho phòng Render & xuất.

**Quy tắc chính**
- Đòn 3 pha theo `AttackPose`: lấy đà 0–0,5 → ra đòn 0,5–0,65 → thu; chạm ~0,55.
- Mỗi boss ≥ 2 đòn, dấu hiệu báo trước khác nhau, đọc được ở dạng bóng từ góc game.
- Đòn = cả người (trọng tâm, bước chân bám đất, hông dẫn → thân → tay → vũ khí →
  phần phụ), khựng lúc chạm, zanshin. Chỉ vung tay = "thô".
- Biên đạo là MỘT nguồn (JSON) cho Blender và Flutter; sửa JSON → `gen_choreo.py`
  + `choreo_test.dart`.
- Boss hình người: thân từ mocap võ thật có giấy phép (CMU, Kyokushin CC0), tay
  vũ khí theo biên đạo; quay về Hercules, mắt nhìn đối thủ.
- Vòng critic: chỉ sửa ý lặp lại ≥ 2 vòng, chốt bản điểm cao nhất.
- Không chạy Cycles GPU cùng lúc huấn luyện torch trên GPU 4 GB.
- **Máy soát trước, critic sau:** mỗi lần sửa đòn chạy `--motion-review` (chân xuyên
  đất, trượt chân, vũ khí xuyên thân/đất, khung giật, lệch dáng chờ) và xem video
  nháp `--video --quick`; chỉ gọi critic khi sheet sạch hoặc mọi đoạn còn lại đã
  khai "cố ý" trong biên đạo (`review`).

**Phạm vi (19/10/2026).** Phòng sở hữu MỌI thứ quyết định "cái gì chuyển động thế
nào", ở cả Blender lẫn game:
- `tool/motion/` (biên đạo, mocap, lớp `<boss>_motion.py`, bộ soát chuyển động).
- `lib/art/motion.dart` (`AttackPose`, `BossBodyMotion`, `Spring`), `lib/art/bosses/choreo.dart`
  + `choreo_data.dart` (sinh), và phần **tư thế** của bản vector 2.5D (đọc kênh biên
  đạo, dáng tay/cánh/thân trong `shuten_boss.dart`, `tengu_boss.dart`,
  `japan_sprite_boss.dart`). Phần vẽ (màu, nét, phông, hiệu ứng) là của phòng Vào game.
- Test: `test/art/motion_test.dart`, `choreo_test.dart`, `stage_motion_test.dart`.

**Việc tồn của phòng:**
- Bản vector 2.5D của oni/tengu vẫn ở góc ¾ cũ; bản 3D đã quay gần nghiêng về
  Hercules (−72° / −55°). Đổi `planeDir` + dáng thân 2.5D cho khớp.
- Oni: chuỳ xuyên bụng 22–25 cm ở vòng thu về vai (Nện đỉnh 0,83–0,90, Quét
  0,71–0,81) — cần đổi đường vung trong biên đạo (đưa chuỳ vòng ra ngoài thân).

**Sửa sau lần chạy máy soát đầu (19/10 chiều) — bài học cho mọi boss:**
- **Đầu/cuối đòn mocap phải hoà về dáng chờ trong không gian rig** (`Track.from_ready`,
  hệ số `w` theo `in`/`out` của moves.json). Retarget (`turn`, `yaw_keep`, `travel`) làm
  khung đầu track lệch dáng chờ 46–74 cm → boss bật thân mỗi lần vào đòn; tengu
  Phong kesa bật từ đứng xuống ngồi trong một khung (critic 12 vòng không thấy vì chỉ
  xem tư thế khoá). Lớp cộng biên đạo (twist/lean/shift) cũng nhân `w`.
- **Mọi kênh dùng trong khoá phải có trong `ready`** — thiếu thì tiến độ 0 lấy giá trị
  khoá đầu (oni thiếu `cant`: chuỳ lệch 35 cm). `gen_choreo.py` nay dừng nếu thiếu.
- **Khoá thưa nội suy cả kênh bước chân:** khoá không ghi `step` thì `step` trượt đều
  giữa hai khoá có ghi → chân kéo lê. Ghim `step` ở mọi khoá chân phải đứng yên.
- **Bước = nhấc chân:** dời đích chân trên sàn là trượt. Nhánh mocap (`Track.from_ready`)
  và nhánh biên đạo (tengu `_legs`) tự nhấc chân theo tốc độ dời ngang
  (`STEP_LIFT` 0,05 m mỗi m/đơn vị tiến độ, tối đa 0,12 m theo chiều dài chân); phần
  nhấc này nâng CẢ bàn chân phẳng.
- **Bàn chân phẳng dần theo độ cao, không có/không:** ngưỡng cứng làm mũi chân chúc
  theo mocap cắm sàn 5–6 cm ngay khi nhấc vài cm; thêm chặn khớp ngón không dưới sàn.
  IK chỉ đặt cổ chân — gập gối sâu mà không ép bàn chân phẳng thì mũi chân cắm đất
  (tengu Thiên cẩu phi 10 cm).
- **Mặt đất = z 0 (mặt hứng bóng)**, không phải đáy chân dáng chờ — dáng chờ tengu
  lún 3,4 cm trước khi ép bàn chân phẳng.
- **Vũ khí chạm sàn: nhấc tay nắm, đừng xoay vũ khí** (`OniMotion.club_floor`). Xoay
  thì khi chuỳ qua phương thẳng đứng chiều nâng đổi phía → bật 58° trong một khung.
- Hai tay oni đặt lại dáng gốc trước mỗi lần IK (`reset_arms`) để kết quả không phụ
  thuộc khung trước.

Sau sửa (máy soát, 2 đòn × 60 khung): tengu 27 → 7 đoạn cảnh báo (6 đoạn cú nhảy
khai cố ý), oni 54 → 37; lệch dáng chờ, chân lún > 4 cm, chuỳ cắm đất: hết.

## Chuẩn chuyển động boss (cũ: mục 6)

Hướng nâng cấp sau khi thêm chi tiết tĩnh không còn đáng (người chơi nhìn
máy cách 50–80 cm): **chuyển động đọc được từ xa tốt hơn chi tiết**.

**Chuẩn boss (mọi boss mới phải có, dùng chung qua `BossArt`/sân khấu):**
1. Đòn 3 pha theo `AttackPose` (`lib/art/motion.dart`): lấy đà 0–0,5 (≥ 0,6 s
   với đòn 1,2 s) → ra đòn 0,5–0,65 → thu về; chạm người chơi ở mốc 0,55.
   Hình đặc trưng của đòn (hơi băng, sóng…) chỉ hiện từ pha ra đòn; pha lấy
   đà chỉ là dáng báo trước. Boss tự diễn đòn (sư tử) đặt `ownsAttackMotion`.
2. Thở + ngả/lao thân + nảy khi trúng đòn: `BossBodyMotion` (lò xo), tự áp
   cho mọi boss quanh `bodyAnchor`. Không dùng `MoveByEffect` cứng cho boss.
3. Sương Trì Trệ (shader) sát đất, tan theo máu boss: `mistColor`, `mistAmount`.
4. Pha cuối (máu < 40%): một khoảnh khắc chuyển pha (gầm, phồng, rung, loé
   đỏ) + viền đỏ đập nhịp tim; `rageColor`.
5. Âm `soundKey`: `boss_<key>_tell.wav` (báo đòn — người chơi nhìn sàn phải
   nghe được) và `boss_<key>_hit.wav`; tạo bằng `tool/gen_boss_sounds.py`.
**Chuyển động trên nhân vật:** nhân vật được chụp ảnh theo tư thế làm tròn,
nên chuyển động phụ (đuôi băng, tóc) vẽ riêng sẽ phá bộ đệm. Chỉ áp biến đổi
toàn thân (lò xo giật lùi khi bị đòn) lên ảnh chụp sẵn.

## Bài học sprite đòn đầu tiên (oni, tengu) (cũ: mục 13)

- **Nhân vật có vải dựng sau khi tạo dáng (oni) vẫn làm sprite được mà không
  dựng lại vải từng khung:** giữ nguyên thế chân của bản duyệt, chỉ cử động
  thân trên (`OniMotion`). Vật dựng ở thế giới lúc tạo dáng (chuỳ, lửa tay)
  phải gắn vào xương bàn tay (`attach_props`, `parent_posed`) trước khi tạo
  dáng khác. Tay IK: đặt lại đích IK + `palm` mỗi khung.
- **Vung vũ khí: nội suy theo GÓC quanh vai** (`CLUB_KEYS`), không nội suy
  thẳng vị trí — thẳng thì tay cắt ngang mặt, hướng chuỳ lật đột ngột ở giữa
  hai khoá. Góc "tháo cuộn" có chủ đích (148 → 178 → −50: qua đỉnh đầu).
- **Đòn nhanh trong sprite:** pha ra đòn chỉ ~2 khung trên 12; sân khấu hoà
  hai khung kề nhau ra **hai cây chuỳ chồng nhau**. `SpriteAtlas.draw(snap:)`
  lấy khung gần nhất quanh cú ra đòn. Giữ đỉnh đòn thêm ⅓ pha thu về
  (`holdStrike` / `s_ * 1.5`) để hiệu ứng chạm đất có vật chạm thật.
- **Góc sân khấu cho model Tripo:** xoay rig ¾ quanh trục qua CHÂN
  (`face_game`; thân không nằm ở gốc vì cánh kéo khung ra sau), `rot` đọc trục
  theo khung rig để rig xoay được. Xoay quá ¾ (−38°) thì cánh gần che mất cánh
  xa; −24° đủ thấy cả hai cánh.

## Biên đạo đòn đánh theo võ thuật (18/10/2026) (cũ: mục 14)

Người dùng chê đòn bản đầu (mục 13) "thô": chỉ cánh tay vung, thân đứng
yên, một đòn duy nhất. Làm lại theo nguyên lý võ thuật dùng binh khí và
hoạt hình đòn đánh, mỗi boss **hai đòn có dấu hiệu báo trước khác nhau**.

**Nguồn đã tra** (không có tài liệu kata kanabō/tessen chi tiết công khai —
lấy nguyên lý chung):
- Kiếm đạo/kiếm thuật: thế **jōdan** (vũ khí trên đầu ngả ra sau, ~70%
  trọng lượng chân trước), **hassō** (dựng đứng cạnh má), **waki-gamae**
  (giấu thấp sau hông, mũi chĩa xuống sau); **ki-ken-tai-ichi** (ý–vũ khí–
  thân chạm cùng lúc), **fumikomi** (bước dậm, lực từ chân sau), **zanshin**
  (giữ thế, giữ ánh nhìn sau cú đánh) — [Toyama-ryū kamae](https://toyamaryu.org/kihon_fundamentals_kamae.htm),
  [thế kiếm Nhật](https://swordis.com/blog/japanese-sword-stances/),
  [fumikomi](https://www.kendo-guide.com/fumikomi-how-to-perform-this-stomping-action.html).
- Kanabō-jutsu: thăng bằng + sức, đánh vỡ giáp, **quét chân ngựa**; đánh hụt
  thì hở người — [Kanabō](https://military-history.fandom.com/wiki/Kanab%C5%8D).
- Tessenjutsu: gạt đỡ một tay, đánh tay kia; Yoshitsune dùng quạt gạt giáo
  Benkei; tengu núi Kurama dạy Yoshitsune võ —
  [Tessenjutsu](https://en.wikipedia.org/wiki/Tessenjutsu), [Kurama-tengu](https://en.wikipedia.org/wiki/Kurama-tengu).
- Hoạt hình đòn nặng: ba tư thế khoá (lấy đà / chạm / thu) phải đọc được ở
  dạng bóng; người + vũ khí là một khối; quỹ đạo cong; khựng lúc chạm; phần
  phụ đi theo sau — [80.lv: vũ khí hai tay](https://80.lv/articles/breakdown-animating-tiny-character-with-massive-two-handed-weapon).

**Biên đạo** (`tool/motion/choreo/<id>.json`, một nguồn cho Blender và
Flutter; `python tool/motion/gen_choreo.py` sinh `lib/art/bosses/choreo_data.dart`;
`test/art/choreo_test.dart` so bộ nội suy Dart với Python):

| Boss | Đòn | Báo trước (0–0,5) | Ra đòn | Sau đòn |
|---|---|---|---|---|
| Shuten-dōji | `attack` Nện đỉnh | Jōdan: chuỳ giơ cao ngả sau đầu, thân ngả ra sau vặn vai phải, tay lửa vươn thẳng ngắm đích, trọng tâm lùi chân sau | Fumikomi chân phải, hông dẫn → thân → tay → chuỳ qua đỉnh đầu nện xuống trước, khuỵu sâu, tay lửa kéo về sườn | Zanshin chuỳ đè đất ~0,1, rồi nặng nề nhấc chuỳ, kéo chân về, vác lên vai |
| | `attack2` Quét chân ngựa | Waki-gamae: hạ thấp, vặn hông hết cỡ, chuỳ giấu sau hông thò đầu lên, tay lửa ngắm | Bước tới, xoay hông trọn vòng, chuỳ quét ngang thấp từ sau ra trước | Theo đà quét sang trái (quá vòng), rồi vác lại |
| | `defeat` | | Chuỳ cắm đất làm gậy chống, quỵ gối, đầu gục, lửa tắt | |
| Tengu Sutoku | `attack` Phong kesa | Hassō: quạt dựng cạnh đầu, tay trái giơ đỡ kiểu tessen, cánh dựng xoè, trọng tâm lùi | Bước tới, chém chéo kesa xuống trái, cánh đập xuống cùng nhịp, tay trái kéo về | Zanshin thấp, cánh hạ chậm (mút cánh trễ nhất) |
| | `attack2` Thiên cẩu phi | Thu người, cánh dựng cao → vỗ cánh bật lên, lơ lửng ở đỉnh quạt giơ sau đầu, chân co | Bổ quạt xuống khi đáp, khuỵu sâu, cánh xoè hãm | Gió vòng trên đất, lông bung, đứng dậy |
| | `defeat` | | Quạt trĩu, cánh rũ sụp, quỵ gối, đầu cúi | |

**Bộ máy** (`tool/motion/choreo.py`, `lib/art/bosses/choreo.dart`):
- Kênh khoá thưa (khoá có thể thiếu kênh), nội suy **cubic đơn điệu
  Fritsch–Carlson**: mượt nhưng không vọt quá khoá (vọt thì chuỳ xuyên đất).
- `lag` theo kênh = chuỗi lực hông (0) → thân (0,004–0,006) → tay (0,01) →
  vũ khí (0,01–0,014) → cánh (0,012–0,02) → mút cánh (0,035).
- Khoá lặp lại cùng giá trị = giữ (khựng lúc chạm, zanshin, lơ lửng ở đỉnh).
- Oni: chân **IK bám đất** (chân phải bước theo `step`/`lift`), hông dịch/hạ,
  vặn chia hông 40% → lưng 35% → ngực 25%, đầu bù ngược để mắt giữ nhìn đích;
  hakama/tạp dề/khoá **dựng lại mỗi khung** (~1,5 s, rẻ) nên chân cử động
  được. Tengu (model Tripo): IK tay + chân thêm vào rig tự gắn, bàn tay
  xoay theo hai vector (cán quạt đúng hướng, ngón nối cẳng tay); bay = dịch
  hông lên + bàn chân co (`lift` − `tuck`).
- Sprite: `idle` 8, `attack` 20, `attack2` 20, `defeat` 6 khung; sân khấu
  luân phiên A/B (`JapanSpriteBoss.moveFor`), không hoà khung ±0,1 quanh mốc
  `impact`, `ownsAttackMotion` = true (sprite đã có bước, sân khấu không lao
  thân chồng lên). Vệt vung (`smearArc`) theo cung đầu vũ khí 0,07 trước chạm.
- Bản vector 2.5D đọc cùng kênh: `planeDir` chiếu mặt phẳng trước–lên ¾ ra
  màn hình (trước rút ngắn 0,8; `sweep` quay về máy quay); thân trên xoay
  cứng quanh hông chỉ 55% góc ngả (lưng 3D cong dần, xoay cứng đủ góc thì
  gãy gập); hakama oni co/nghiêng theo hông, gấu nằm yên trên đất.

Bài học:
- **Nắm đấm giữ vũ khí vuông góc cẳng tay.** Muốn chuỳ nện xuống trước thì
  tay phải ở ngang vai, khuỷu hạ (cẳng tay chĩa lên–trước); tay duỗi chĩa
  xuống thì chuỳ nằm ngang.
- **`palm()` (StandPoser) chỉ đúng gần dáng duyệt:** nó coi trục đốt ngón
  vuông góc hướng ngón ở dáng nghỉ — bàn tay MPFB đã nắm lệch 30–60° khi tay
  duỗi ra trước, chuỳ chĩa sai mà không báo. Sau `palm()` đo trục vũ khí thật
  rồi xoay bù cổ tay (`club_arm`). Gặp hướng sai: in số đo (hướng mong muốn /
  cẳng tay / thực tế) trước khi chỉnh khoá.
- **Thế báo đòn phải đọc được ở dạng bóng từ góc game:** waki-gamae giấu
  chuỳ kín sau lưng → mất dấu hiệu; chuỳ chĩa thẳng ra sau thì phối cảnh rút
  ngắn → jōdan trông như không giơ. Cho vũ khí thò ra khỏi bóng thân.
- Thân béo + hakama che hết chân và nửa độ ngả: chuyển trọng tâm phải làm
  lớn hơn người thường mới thấy (ngả 16–28°, hạ 0,2–0,25 × S).
- `exec` của ONI_DEBUG: import trong hàm (đã ghi mục 11) — dính lại lần nữa.

## Cơ chế đòn có báo trước + vòng critic biên đạo (18/10/2026 tối) (cũ: mục 15)

- Cơ chế (`lib/game/mechanics/telegraphed_boss.dart`, brief
  `rules/thietke/boss-nhat-shuten-sutoku.md`): mỗi đòn boss có pha báo
  (viền đỏ + icon cách né: ⏸ hoặc rep sâu), Shuten uống rượu, Sutoku viết ấn
  nguyền; 11 test mô phỏng. Sân khấu đọc pha từ cơ chế (`phaseFromTell`,
  `tellAlt`), âm `boss_*_tell/tell2/hit.wav`.
- Biên đạo lặp critic "mắt lạ" (agent mới mỗi vòng, không nói ai làm): vòng
  1→3 điểm 3–7/10, chưa đạt 8. Tấm tư thế khoá: `tool/render/keysheet.py`.
- Vòng 4 bị thay bằng hướng mới (mục 16): thân lấy từ mocap võ thật, góc quay
  gần nghiêng — khung cũ không còn dùng.

## Đòn boss từ mocap võ học thật — kiểu Shadow Fight (19/10/2026 đêm) (cũ: mục 16)

Yêu cầu: boss đánh như game đối kháng (Shadow Fight, Street Fighter) — nhìn
và quay về phía Hercules, khớp tự nhiên tới khuỷu, cổ tay, cổ chân, ngón chân,
ngón tay; được dùng web + máy (RTX 3050 4 GB) để học dữ liệu võ.

**Góc sân khấu.** Boss hình người quay gần nghiêng về đối thủ: oni `FACING =
−72`, tengu `−55` (−70 thì cánh gần che hết cánh xa). Mắt nhìn đối thủ
(`aim_pupils(look=…)`, pha 20% về máy quay cho mắt đọc được), KHÔNG nhìn máy
quay. Boss mới (Susanoo, Tamamo, Orochi) theo luôn.

**Dữ liệu (giấy phép là điều kiện đầu tiên).**
- CMU Graphics Lab Mocap — dùng được cả thương mại, chỉ cấm bán lại dữ liệu.
  42 clip chọn tay (`tool/motion/mocap/manifest.json`): karate subject 135 (kata
  Bassai/Empi/Heian, mae/mawashi/yoko-geri, oi-zuki, shuto-uke, gedan-barai),
  đấm/đỡ/đá 144, quyền anh, kiếm (nghiệp dư — yếu), đá nhảy.
- **Kyokushin karate, 37 võ sinh, CC0** (figshare 10.6084/m9.figshare.c.4981073,
  Szczęsna et al. 2021): 1 411 file C3D, 3 229 đòn gyaku-zuki / mae-geri /
  mawashi-geri gedan–jodan / ushiro-mawashi-geri, 200 Hz, tâm khớp Plug-in
  Gait. Tốc độ đỉnh 8–14 m/s — sức võ sinh thật, hơn hẳn CMU. File thiếu tâm
  khớp thì tự suy từ marker (hông: Bell 1990).
- Loại: Bandai Namco Research (CC BY-NC-ND — cấm thương mại + phái sinh), AMASS
  (phi thương mại), UMONS-TAICHI (NC-SA), Mixamo (cần tài khoản, không tự tải).

**Đường ống** (`tool/motion/mocap/`, chạy ngoài Blender; dữ liệu thô ở
`art_src/mocap/_cache/`, không commit):
1. `fetch.py` / `karate_prep.py` tải + chuyển → khung xương chuẩn 24 điểm
   (`skeleton.py`: mét, Z lên, +X = về phía đối thủ; có gốc ngón tay + ngón
   cái để xoay cổ tay).
2. `segment.py` tự cắt đòn: đỉnh tốc độ chi → chạm = duỗi xa nhất → lấy đà /
   thu; đá phải nhấc mắt cá ≥ 0,45 m (loại bước chân); mỗi đòn xoay cho chi
   bay về +X. Thư viện ~4 200 đòn.
3. `model.py` — **mô hình học chuyển động**: 1D-UNet 12,6 M tham số, cửa sổ 64
   khung @30 fps, khử nhiễu có che khung, học PHẦN DƯ trên nền nội suy tuyến
   tính; mất mát có độ dài xương, chống trượt chân, vận tốc/gia tốc. 215 phút
   dữ liệu. Dùng để điền đoạn nối dáng chờ boss ↔ đòn mocap, khử nhiễu video,
   chấm độ "lạ". Chạy trong `tool/.venv-ml` (torch cu128).
4. `compose.py` + `art_src/mocap/moves.json`: mỗi đòn boss = (clip, chi, thời
   điểm chạm) + mốc sân khấu (TRÙNG biên đạo). Dáng chờ boss (Blender
   `--mocap-ready`) chuyển sang xương người diễn, `style.py` nắn nhịp mocap vào
   nhịp sân khấu (nạp → giữ báo → chạm → dừng lực → thu), mô hình điền hai đoạn
   nối → `art_src/mocap/moves/<boss>_<move>.npz` (commit; Blender chỉ đọc numpy).
5. `tool/motion/mocap_drive.py`: retarget TUYỆT ĐỐI (không phụ thuộc trục
   xương) — khung xoay hông/ngực/đầu dựng từ điểm, chia dần spine_01→03; tay
   chân IK với pole đúng phía khuỷu/gối; chân tính từ khung chậu (đất ↔ đất),
   với không tới thì HẠ HÔNG chứ không nhấc chân; khoá chân khi chạm đất; nhón
   gót thì gập ngón chân bám đất; mắt khoá về đối thủ; ngón tay `fingers()`.
6. Hai lớp: **thân từ mocap** (hông, cột sống, chân, đầu, tay không cầm vũ
   khí) + **tay vũ khí theo biên đạo** (chuỳ, quạt — giữ quỹ đạo đã duyệt),
   tay vũ khí xoay theo phần ngực mocap vặn khác biên đạo
   (`yaw_mocap − twist`). `ONI_MOCAP=0` / `TENGU_MOCAP=0` = biên đạo cũ.
7. Tengu (Tripo) không có xương ngón → `tripo_kit.add_fingers`: tách ngón theo
   lưới (cắt dần theo độ sâu dọc bàn tay, mức đầu ra 4 cụm = 4 ngón, cụm tách
   sớm không chứa ngón = ngón cái), 3 đốt 45/30/25 %, trục Z về lòng bàn tay
   (+X = gập), trọng số chuyển mềm từ bàn tay.

Bài học:
- **Cycles GPU và torch không được chạy cùng lúc trên GPU 4 GB** — cả hai lỗi
  truy cập bộ nhớ CUDA (trông như lỗi cuDNN). Huấn luyện thì render
  `BLENDER_CPU=1` hoặc đợi.
- Trục đứng phải neo đất ↔ đất; neo theo hông dáng chờ thì khi hạ tấn cả
  người bị đẩy lên, chân hẫng.
- Hông rig khác hông người diễn → đích chân tính từ khung chậu, không từ khớp
  hông rig.
- Kho kiếm CMU là người nghiệp dư — không đủ uy cho đòn nện; võ tay không
  chuyên nghiệp (karate) + lớp vũ khí biên đạo cho kết quả tốt hơn.
- Đá nhảy CMU bay quá cao, không kịp tiếp đất trong 1,2 s đòn → Thiên cẩu phi
  giữ biên đạo cũ.
- Mã đòn trong thư viện đổi khi dựng lại → `moves.json` tham chiếu bằng (clip,
  chi, thời điểm chạm).

**Vòng critic "mắt lạ" (19/10 đêm, agent mới mỗi vòng, tấm tư thế khoá):**

| Vòng | Oni Nện đỉnh | Oni Quét | Tengu Phong kesa | Thay đổi chính |
|---|---|---|---|---|
| 1 | 3,5 | — | 4,5 | retarget đầu tiên |
| 2 | 5 | 4 | 6 | bỏ bù vặn ngực cho tay vũ khí (biên đạo theo khung cố định) |
| 3 | 5,5 | 4 | 5 | lớp gập/vặn thân cộng dồn, tay lửa theo biên đạo |
| 4 | 5,8 | 4,2 | 6,2 | khoá xoay thân `yaw_keep` 0,3 (ngực không mở ra máy quay) |
| 5 | 6 | 4,5 | 5,5 | mắt nhìn đối thủ sau mọi lớp |
| 6 | 6 | 5 | 6,5 | sửa dấu ngẩng đầu, hạ tấn sâu đòn quét |
| 7 | 6,5 | 6 | 6,5 | chuỳ thu vòng dưới (−212° ≡ 148°), quét song song đất |
| 8–10 | 5,5–6 | 6–6,5 | 5–6,5 | critic mâu thuẫn nhau (chuỳ dựng / ngả sau) |
| **11** | **6,8** | **6,2** | **5,6** | đỉnh lấy đà trong pha giữ, cung liền — **bản chốt** |
| 12 | 6 | 5,5 | 5,5 | (bỏ, quay về v11; giữ cằm hơi cúi) |

Chưa đạt 8/10. Bài học về vòng lặp:
- Từ vòng 8 điểm bão hoà 6 ± 1, phần lớn là nhiễu giữa các critic (cùng một tư
  thế bị khen ở vòng này, chê ở vòng sau). Chỉ sửa ý **lặp lại ≥ 2 vòng**;
  chốt bản điểm cao nhất thay vì bản cuối.
- Critic chỉ thấy tư thế tĩnh → luôn đòi "thêm khung giữa". Bước tiếp: đưa
  critic dải 20 khung sprite thật (hoặc GIF người que) để chấm cung chuyển động.
- Lỗi lặp nhiều nhất đến từ hệ thống, không phải từng khoá: bù vặn sai khung,
  dấu ngẩng đầu ngược, mắt nhìn tính trước lớp cộng. Gặp lời chê lặp lại ở
  cả ba đòn → tìm lỗi trong `mocap_drive`, đừng chỉnh khoá.
- Dư địa còn lại: đòn mocap riêng cho vũ khí nặng (cần dữ liệu kiếm/gậy chuyên
  nghiệp có giấy phép), tay trái ôm cán chuỳ lúc nện (critic v4), cánh xa tengu
  điều khiển riêng, bản vector 2.5D vẫn ở góc ¾ cũ (chưa quay nghiêng).
