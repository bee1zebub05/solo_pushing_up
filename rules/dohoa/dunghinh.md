# Phòng Dựng hình (Blender: lưới, vật liệu, xương, phụ kiện)

Code: `tool/blender/` (`kits/`, `characters/`, `scenes/`, `tripo_view.py`).
Skill: `blender-character`. Đầu ra bàn giao: nhân vật/cảnh đã qua `--review`
(sheet.png sạch + critic), dáng chờ đã duyệt — phòng Chuyển động nhận từ đây.

**Quy tắc chính**
- Xin ảnh tham khảo dáng người (chính diện + nghiêng) và viết spec trước khi dựng.
- Thứ tự: tỉ lệ khung → bóng ba hướng (thân trần) → mặt, gân, phụ kiện, hiệu ứng.
- Đo, đừng tin ghi chú (chân đo tới khớp háng; người thường 0,50–0,53).
- Vải rộng dựng sau khi tạo dáng; đồ ôm chi đo da; chuỗi xử lý cả đường.
- BẮT BUỘC `--review` + tự đọc sheet.png + critic mắt lạ trước khi đưa người dùng.
- Sửa kit dùng chung → soát các nhân vật khác dùng chỗ đó.
- Boss chính dựng MPFB; Tripo hợp quái thường, đồ vật (tengu là ngoại lệ đã chốt).

## Script Blender và bẫy chung (cũ: mục 7)

- Script: `tool/blender/kits/boss_kit.py` (dùng chung) + mỗi boss một file
  (`lion_nemea.py`, `fafnir_boss.py`, `orochi_boss.py`, `thuy_tinh_boss.py`).
  Quái chương 1: `hoplite.py` (lính đá, `--spartoi`), `stymphalia.py` (chim
  Stymphalia: lông thân xếp ngói rải trên lưới, cánh `bird_kit.py` từng phiến
  lông có sống lông), `harpy.py` (MPFB bỏ tay/chân + thân chim), `boar.py`,
  `hydra.py` (biến thể theo số đầu còn sống). Nhân vật: `hero.py` (`--female`).
- Toạ độ viết theo đơn vị sân khấu 400×260, gốc ở chân boss; tư thế theo
  `AttackPose` (lấy đà 0–0,5, ra đòn 0,5–0,65) để khớp nhịp đòn của game.
- Bẫy Blender 5.2: sợi (lông, tóc) do geometry nodes sinh trên object lưới
  KHÔNG render — đặt trên object Curves riêng (`with_fur`).

## Tài sản chương 1 đã dựng (đêm 13–14/10) (cũ: mục 7)

Ảnh xem trước cho thấy quái Blender đứng trên phông vector cartoon và cạnh
nhân vật vector: lệch phong cách rõ. Hướng xử lý: dựng nốt phông, boss, nhân
vật bằng Blender.

- **Phông Thung lũng Nemea** (`tool/blender/scenes/nemea_valley.py`): cảnh 3D thật
  (đất cỏ khô, vách đá vôi xếp tầng có hang sư tử, ô liu già lá thật rải bằng
  geometry nodes, rừng ô liu trên đồi, đền Doric, núi xa trong sương). Máy
  quay phối cảnh khớp sân khấu: mặt phẳng hành động ở độ sâu 0, mặt đất tại
  y = 220, ~2 cm/đơn vị. Render THEO TẦNG (`sky`, `far`, `mid`, `near`, `fg`)
  → `assets/backdrops/nemea_<tầng>.webp`, rộng thêm 24 đơn vị mỗi bên cho
  camera trôi; sân khấu giữ parallax và lớp bụi Trì Trệ (bộ lọc màu từng tầng,
  chỉ còn màn sương vẽ thêm — mạng nhện/đống bụi khớp hình vector nên bỏ).
  Phối cảnh không khí làm trong vật liệu (trộn màu sương theo khoảng cách tới
  máy quay), không dùng volume.
  - Bài học: boolean khoét hang trên lưới voxel gồ ghề làm mất cả vách → dựng
    vòm bằng khối quanh miệng hang. Vách đá vôi ghép từ HỘP xoay lệch rồi làm
    gồ ghề (ghép ellipsoid ra khối tròn như bột nhào). Lưới nứt Voronoi trên
    đá trông như bùn khô — bỏ.
- **Boss Sư tử Nemea** (`lion_nemea.py`) chuyển sang `sprite_kit.export_sprites`
  (atlas WebP như quái), sân khấu vẽ bằng `paintLionSprite` (lion_art.dart) và
  giữ phần đọc nhịp: bụi cào đất, rung gầm gừ, vệt vuốt, sóng gầm, khiên da
  loé khi bị chặn, Trì Trệ rời xác. Đầu làm lại theo tỉ lệ sư tử thật (mõm dài
  vuông, mắt nhỏ đồng tử tròn, mũi da chữ T), bờm hai lớp ôm mặt, bóng đổ thật.
- **Nhân vật** (`hero.py`, chế độ không `--still`): sprite TÁCH LỚP để giữ tuỳ
  biến của màn tạo nhân vật (2 giới × 6 màu da × 6 màu tóc × 5 kiểu tóc) mà
  không render mọi tổ hợp: `hero_<giới>_skin` render da trắng trung tính,
  Flutter nhân màu da (`BlendMode.modulate`); `hero_<giới>_cloth` giữ màu, có
  bóng đổ; `hero_<giới>_hair_<kiểu>` render xám, nhân màu tóc. Lớp khác chỉ
  holdout (che khuất đúng, không hiện). Chuỗi: `plank`/`knees` theo góc khuỷu
  178° → 70°, `stand`, `victory`. Flutter: `lib/art/hero_sprite.dart`.
  Áo da Sư tử Nemea là lớp `hero_<giới>_pelt` (tấm da lông phủ lưng + sườn,
  cổ áo bờm, hai chân trước buộc ngực), vẽ đè sau tóc. Chưa có lớp Blender
  cho khiên, kiếm và lớp băng giá → khi đó vẽ bản vector. Mũ đầu sư tử dựng
  bằng ellipsoid trông như đồ chơi trên đầu → bỏ, cần mô hình nặn.
  Ngân sách: da + áo đóng lại ×0,85 (1 trang 2048² mỗi lớp), tóc 1 dải trang
  nhỏ → mỗi trận ~3 trang cho nhân vật.
- **Bản đồ Thung lũng Nemea** (`nemea_map.py` → `assets/backdrops/nemea_map.webp`):
  sa bàn nhìn chéo 40°, máy quay trực giao; toạ độ bản đồ 400×300 quy ra mặt
  đất bằng tia chiếu (`ground_at`), cây rải tránh đường mòn/sông theo toạ độ
  ẢNH. Vật cao (cao nguyên) bị đẩy lên trên ảnh theo độ cao → đặt vật theo
  chân, không nâng nền. Đền trên bản đồ là đền đổ mái (nhìn từ trên chỉ thấy
  mái đỏ). Flutter vẽ đường mòn, 10 điểm màn, nước lấp lánh đè lên.
- **Hercules** (`hercules.py` → atlas `hercules`): dáng lực sĩ bằng target
  chi tiết của MPFB (`make_human(details=…)` áp TRƯỚC khi gắn xương: lưng
  chữ V, vai, ngực, lưng xô, bắp tay–cẳng tay, cổ, đùi, hàm vuông) — chỉ
  macro "cơ bắp" thì ra người tập gym thường. Cởi trần (exomis chỉ giữ váy),
  râu quai nón phủ cằm–hàm (chọn đỉnh theo nửa trước đầu + cổ, không theo gốc
  xương đầu — gốc nằm trên cằm), nguyệt quế lá to, bỏ băng đầu đỏ của người
  chơi. Đứng ¾ (`FACING` 52°) để thấy mặt và ngực; tay phải (phía máy quay)
  tì đầu cán chuỳ chống đất, tay trái (phía xa) giơ về phía người chơi khi
  nói — tay phía gần giơ hướng nào cũng đi ngang mặt. `talk` 7 khung; cảnh
  mở đầu làm mượt mức giơ tay và giữ suốt đoạn thoại, chỉ nhấp nhẹ khi chữ
  đang hiện (hoà hai khung xa nhau ra bóng ma hai cánh tay). Chân dung khung
  thoại cắt từ sprite (`paintHerculesSpritePortrait`).
- **Áo da sư tử bản nữ** (`hero_female_pelt`) đã render đủ 21 khung như bản
  nam → nhân vật nữ khoác áo bằng sprite, không còn lùi về vector.

## Bộ công cụ Blender cho boss hình người chương Nhật (14/10/2026) (cũ: mục 10)

Tìm trên mạng xem có gì bổ sung được (kết quả và quyết định):

| Công cụ | Dùng? | Ghi chú |
|---|---|---|
| Gói tài nguyên hệ thống MakeHuman (CC0, 267 MB) | ✅ đã cài | Mắt, lông mày, lông mi, răng, lưỡi, tóc, da. Phải giải nén vào `%APPDATA%/Blender Foundation/Blender/5.2/extensions/.user/blender_org/mpfb/data` (thư mục MPFB đọc, KHÔNG phải `.../5.2/mpfb/data`). `human_kit.add_face_parts`. |
| Bộ node tóc có sẵn của Blender (`datafiles/assets/nodes/procedural_hair_node_assets.blend`) | ✅ | Duplicate / Clump / Frizz / Curl / Braid / Set Hair Curve Profile — `hair_kit.strand_locks` (tóc tỉa theo lọn, mỗi lọn một guide). Addon tóc trả phí (Stylized Hair Pro, Medusa Nodes) không cần. |
| blender-mcp (ahujasid) | chưa | Nối Claude với Blender đang mở (xem cảnh trực tiếp, Poly Haven, Hyper3D). Có ích khi làm tay trong Blender; quy trình script `render.sh` hiện tại không cần. |
| Poly Haven / ambientCG (CC0) | khi cần | Texture/HDRI tả thực; phong cách painted đang tự vẽ bằng node nên chưa dùng. |
| Ảnh → 3D (TRELLIS.2 MIT, Hunyuan3D, TripoSR) | ❌ | TRELLIS cần ≥16 GB VRAM (máy: RTX 3050 4 GB). Hunyuan3D: giấy phép cộng đồng loại EU/UK/Hàn. Dựng từ tranh tham khảo có bản quyền cũng là tác phẩm phái sinh. |

Thư viện mới:
- `tool/blender/kits/hair_kit.py`: tóc theo lọn (`strand_locks` sợi thật, `ribbon_locks` lọn khối), `hair_material`.
- `tool/blender/kits/japan_kit.py`: da tô màu/xăm (`painted_skin`, có son môi), vải lụa vân mây (`silk_material`), vải hoa tròn (`kamon_material`), lửa ma (`flame_material`, `flame`), áo ôm thân (`garment`), tay áo rộng (`sleeve_bag`), hakama, giáp tay (`limb_band`), sừng có gờ, chuỗi hạt, thừng shimenawa, chữ Hán nổi (font Yu Gothic — máy không có Mincho), vuốt, quạt lông, đắp khối (`inflate` — bụng phệ), ghép khối elip theo mét (`blob`), dáng đứng ¾ (`StandPoser`).

Boss dựng theo tranh người dùng chọn (ảnh duyệt `--still`; oni và tengu đã xuất sprite + BossArt 18/10 — mục 13):

| Boss | Script | Ảnh |
|---|---|---|
| Yamata no Orochi (làm lại: rắn thật xanh xám, bụng hồng, mắt vàng, vàng lá) | `orochi_boss.py` | `build/blender/orochi/` |
| Shuten-dōji (oni đỏ vác kanabō) | `oni_boss.py` | `build/blender/oni/` |
| Sutoku hoá đại tengu | `tengu_boss.py` (model Tripo `art_src/tripo/tengu_001/` từ 16/10, thay bản MPFB) | `build/blender/tengu/` |
| Susanoo cuồng nộ (lửa ma xanh, hào quang) | `susanoo_boss.py` | `build/blender/susanoo/` |
| Tamamo-no-Mae, dạng cáo / dạng người | `tamamo_boss.py --form fox|human` | `build/blender/tamamo/` |

Việc tiếp: người dùng duyệt ảnh → sửa → xuất atlas sprite (`sprite_kit.export_sprites`, chuỗi idle/windup/strike/hurt/defeat) → BossArt Flutter + bản vector 2.5D (mục 9). Đã sửa (14/10): cổ áo tengu dựng bằng `flat_band` bám mặt ngoài áo theo từng tầng `body_ring` (ống dẹt Bézier cắt xuyên ngực và xoắn khi gần thẳng đứng); mày Tamamo dạng người là một nét `tapered_world` — `helper-*-eye` là tâm nhãn cầu nên phải đẩy ra trước ~0,024·H mới qua gờ mày.

Oni bản 3 (14/10): mặt Hannya bằng target biểu cảm MPFB (`human_kit.target_path` nhận đường dẫn kiểu `expression/units/asian/mouth-open` — tên biểu cảm trùng giữa các chủng người); đắp cơ dọc xương bằng `japan_kit.muscle_bulge` + tô hõm cơ bằng AO cục bộ (`painted_skin(cavity=…)`); `--clay` bỏ hình xăm để soát khối. Dạng chân `StandPoser.place` quay quanh trục trước–sau của khung xương (trục Z cục bộ của đùi bị lệch làm chân bắt chéo); `StandPoser.palm` + `fist` cho tay nắm cán; `--grip` / `--grip-only` render ảnh soát tay, chân, thân. Gốc tóc bờm đặt theo bán kính sọ đo từ đỉnh nhóm `head` (bỏ HelperGeometry), không dùng mặt cầu cố định.

Đêm 14→15/10 (người dùng giao tự làm oni + Susanoo): bụng oni kiểu Gragas bằng `japan_kit.belly_ball` (chiếu đỉnh lên mặt elip theo tia từ tâm, hợp smooth-max — đẩy theo pháp tuyến `inflate` cho bụng nhọn); bờm mọc từ đỉnh nhóm `scalp`; `hair_kit.combed_material` (Wave của Blender tự nhân toạ độ ×20, scale chỉ 3–5); `hero_muscles(k)` dùng chung; `painted_skin(tattoo_attr=…)` giới hạn vùng xăm; `skin_snapper` dán mày lên mặt da; `flat_band` (đã chuyển vào japan_kit, có `widths`) cho tấm da hổ vắt vai + viền lông `strand_locks`; Susanoo: target biểu cảm `expression/units/caucasian/*`, nắm kiếm `fist`+`palm`, sét `lightning` (dời điểm giữa) — emission ánh màu cần strength ≈2, cao hơn bị cháy trắng. Cờ soát: oni `--belly --grip --clay`, Susanoo `--hand --clay`.

Oni bản 7 (15/10, theo nhận xét người dùng): `japan_kit.densify` gộp shape key MPFB rồi áp một bậc subsurf vào lưới gốc (75k đỉnh) — nếp nhăn/gân mảnh hơn khoảng cách đỉnh MPFB (~5–10 mm) không hiện; `weights_by_group` có nhớ đệm. `ridge` (gờ/rãnh dọc đường gấp khúc: gân xanh, nếp nhăn, sẹo, thớ cơ), `snap_rest`, `inflate(groups=…)` để khối ngực không lan sang nách (nâng tay sẽ kéo thành mẩu nhọn). `conform_outside` ép tấm da/vải bám mặt da SAU khi tạo dáng (tấm phải chia nhiều đỉnh theo bề ngang); vật dựng sau khi tạo dáng phải gắn xương theo `pose_bone.matrix` hiện tại, `parent_to_bone` tính theo dáng nghỉ. `painted_skin(paints=[(thuộc tính, màu)])` cho kumadori, đỏ rượu, sẹo, gan chân. Máy quay vừa tạo cần `view_layer.update()` trước khi đọc `matrix_world` (đồng tử nhắm nhầm lên trời). `human_kit.camera` đặt tâm ở mặt phẳng y = 0 — góc quay lớn dùng `look_at` trong oni_boss. Eo béo: bỏ `torso-muscle-dorsi-incr`, macro cơ 0,7 / mỡ 0,9, đắp mỡ sườn–lưng–bụng trên. Cờ mới: `--face`, `--checks`, `--quick`, `--dry` (+ biến `ONI_DEBUG`).

## Bài học sau khi dựng oni (bản 3 → 9, 14–16/10/2026) (cũ: mục 11)

Oni mất ~7 vòng nhận xét. Phần lớn vòng sửa là lỗi có thể bắt trước khi đưa người dùng xem. Thứ tự làm và cách soát dưới đây áp cho mọi nhân vật hình người sau.

### Thứ tự dựng: khối trước, chi tiết sau
1. **Xin ảnh tham khảo dáng người ngay từ đầu** (cả nhìn nghiêng), không chỉ tranh phong cách. Oni chỉ đúng tỉ lệ béo phì sau khi người dùng gửi ảnh 5 dáng người gầy → béo.
2. **Chốt tỉ lệ khung (chiều dài chân, thân) trước khi đắp khối.** Rút ngắn chân cho "lùn bè" rồi đắp mỡ thì thân dưới thành cái chuông úp; người béo vẫn cần chân dài bình thường.
3. **Bóng (silhouette) ba hướng: trước, nghiêng, sau.** Người béo phì nhìn nghiêng: bụng trễ chờm qua cạp, mông là điểm nhô ra sau xa nhất, lưng chảy liền xuống mông, đùi trên dày gần bằng thân rồi thon về gối, hai đùi áp sát.
4. Rồi mới tới mặt, gân, vuốt, hiệu ứng.

### Soát thân trần dưới quần áo
- **Quần áo sao từ thân thừa hưởng mọi lỗi của thân.** Luôn render một ảnh ẩn quần áo (hakama, tạp dề…) trước khi chỉnh vải. Oni sửa hakama hai vòng mà bên trong vẫn là hông lép, đùi thon.
- Đắp mỡ quanh chi: dùng `japan_kit.limb_fat` (đẩy ra xa trục xương, khối tròn đều). `inflate` đẩy theo pháp tuyến dễ ra cục, chỉ hợp cho khối nhỏ (ngực, đệm gối). Vòng eo béo: đẩy toàn vòng ra xa trục thân (`WaistFill` trong `oni_boss.lower_fat`), không đắp từng cục.

### Vải và đồ dựng theo thân
- **Vải rộng (hakama, váy, áo choàng) dựng SAU khi tạo dáng, theo bao lồi:** `japan_kit.DrapedSkirt`. Vải rủ từ chỗ rộng nhất rồi buông thẳng, căng qua khe chân. Bản sao lưới thân + đẩy pháp tuyến (`hakama`, `garment`) chỉ hợp đồ ôm sát; với thân béo nó thành quần bó lộ từng khối.
- **Đồ gắn lên thân (khoá đai, phù hiệu, chữ thêu) phải soát lại mỗi khi khối thân đổi.** Bụng trễ xuống đã che mất khoá đai. Đặt chúng theo lớp ngoài cùng (mặt tạp dề, mặt quần) chứ không theo vòng thân gốc.
- Lưới tự dựng: kiểm tra pháp tuyến hướng ra ngoài. Ngược thì mép vải trông mờ như kính. Lụa nhiều sheen cũng loé trắng ở mép trên nền sáng; vải dày để sheen ≤ 0,2.
- Đồ dựng sau khi tạo dáng chỉ đúng cho dáng đó; sprite nhiều dáng phải dựng lại theo từng dáng.

### Dò điểm trên lưới
- **Dò ở dáng nghỉ, không ở dáng đã tạo** (vuốt chân lệch hai lần): trục xương sau khi tạo dáng không trùng hướng thật của bàn chân. Dò xong thì `parent_to_bone` (tính theo dáng nghỉ) là vật tự đi theo dáng.
- Hàng ngón chân/tay xếp chéo: trừ đường thẳng khớp qua mép trước rồi mới tìm cực đại (`toe_claws`). Chia bề ngang theo tỉ lệ cố định sẽ trượt khỏi ngón thật.
- Đọc lưới đã tạo dáng (`posed_points`): tắt tạm mọi modifier trừ Armature. MPFB có Mask ẩn lưới phụ, subsurf thì đổi số đỉnh.

### Hiệu ứng và phụ kiện nhỏ
- Lửa ma: quầng sáng opacity ≤ 0,1, nếu không thành quả bóng che mất lửa. Đuôi lửa cần thành phần hướng lên, vì đuôi theo tiếp tuyến quỹ đạo sẽ chĩa vào máy quay ở hai bên và bị ngắn lại. Bỏ ngọn nào rơi trước bụng/mặt nhìn từ máy quay.
- Tua, dây, lông: dựng đúng cấu trúc vật thật (dây treo → nút → chóp → đai → sợi), sợi đều nét và cắt bằng. Vuốt nhọn đầu là kiểu "kim".

### Quy trình nhanh
- Mỗi vòng thử dùng `--dry --quick` + biến `ONI_DEBUG` trỏ tới script soát (khoảng 1,5 phút) render đúng góc cần xem, ghép thành một ảnh lưới. Chỉ render đầy đủ (khoảng 9 phút) khi đã ưng.
- **Bộ ảnh soát cố định trước khi đưa người dùng xem:** toàn thân · nghiêng trần (ẩn quần áo) · nghiêng mặc đồ · sau lưng · cận bàn chân (trước + trên xuống) · cận mặt. Tự hỏi: bóng có giống tham khảo không, đồ gắn có bị che không, chỗ tiếp xúc (đai–thân, vải–chân, vuốt–ngón) có khớp không.
- Lỗi "Cannot change old file" / sót `.blend@` (file lớn vừa ghi bị Windows khoá tạm) đã sửa trong `boss_kit.save_blend` 16/10: lưu ra file tạm, tự đổi tên `@` có thử lại; không còn phải xoá tay.

### Bổ sung sau vòng soát cận (bản 10 → 10b, 16/10 tối — oni được duyệt)
Người dùng phóng to ảnh duyệt và thấy lỗi mà ảnh toàn thân che mất. Ba ảnh cắt cận của người dùng ra 6 lỗi.
- **Bộ soát phải có ảnh cận từng phụ kiện** ở cỡ người dùng hay phóng (khoảng 700 px/m): tay + vật cầm, khoá đai, chuỗi hạt/vòng cổ, mép da thú/vải, giáp tay. Kèm vài con số đo (khe giữa các hạt, bán kính da so với giáp). Số liệu bắt lỗi nhanh hơn nhìn ảnh.
- **Màu dưới AgX:** vật phát sáng mạnh hoặc nhiều lớp bán trong suốt chồng nhau (mặt trước + sau ống, nhiều lưỡi lửa) cộng sáng, AgX đẩy về trắng kem. Lửa dùng `japan_kit.fire_material`: ramp bão hoà, cường độ ≈ 1,4, đục ở lõi.
- **Tên thuộc tính lưới:** không đặt `heat`, `density`, `flame`, `temperature`, `color`, `velocity`. Cycles dành các tên này cho khói/lửa thể tích, shader đọc ra 0 mà không báo lỗi. Đặt có tiền tố (`flame_heat`). Nghi ngờ thì render thẳng thuộc tính ra màu Emission để kiểm.
- **Vật liệu tối màu trên nền đèn lam:** bóng gương phản trời/đèn viền lam thành xám nhựa hoặc tím. Vải tối dùng `silk_material(spec ≤ 0,25, sheen ≤ 0,06)`, sơn mài nhám ≥ 0,4. Mặt khuất của da đỏ chỉ có đèn viền lam rọi thì ra tím: đèn viền nhạt và vừa phải.
- **Đồ ôm chi (giáp, vòng tay) phải đo da:** đắp mỡ sau khi đặt bán kính cố định thì giáp chìm vào da, lộ lốm đốm. Dùng `limb_band(skin=(body, co), pad=…)`.
- **Phụ kiện nhỏ phải đọc được ở cỡ sprite và có chỗ bám:** khối cầu một màu đọc thành quả bom. Phải là mặt phẳng có nét khắc nổi tương phản (vàng/đen/phát sáng). Đồ treo cần quai/khuyên nối vào vật mang (khoá đai treo vào thừng), không đặt lơ lửng.
- **Chuỗi, dây, vật xếp hàng: xử lý cả đường, không xử lý từng phần tử** (`japan_kit.drape_chain`).
  - Đẩy từng hạt riêng lẻ thì chuỗi gãy khúc.
  - Làm mượt vị trí một vòng kín thì vòng co lại thành vòng siết. Chỉ làm mượt *độ đẩy* để giữ dáng võng.
  - Số hạt phải vừa chiều dài dây (26 hạt cần 1,6S trên vòng 1,0S nên hạt đè thành cục).
  - Mặt dây đặt theo hình học (điểm nhô trước nhất), không theo chỉ số.
- **Đẩy vật ra khỏi thân béo:** điểm lọt trong khối thịt thì "mặt gần nhất" có thể là dưới cằm, vật bị đẩy sai hướng. Tia bắn ngang từ ngoài vào thì lại trúng cơ vai. Chọn cách đẩy theo vị trí, và soát cả hai phía.
- **Bẫy kỹ thuật:**
  - `bmesh.from_mesh`/`from_object` trên thân MPFB đã tạo dáng (có shape key) làm Blender sập. Dựng BVH từ đỉnh/mặt (`BVHTree.FromPolygons`, xem `_surface_tree`).
  - Script `ONI_DEBUG` chạy bằng `exec` trong `main()`: generator/lambda không thấy biến cục bộ. Bọc code soát trong hàm và truyền `scene` vào.
- **Sửa một chỗ trong kit dùng chung thì soát các nhân vật khác dùng chỗ đó.** Lửa Susanoo vẫn dùng `flame_material` cũ, nhiều khả năng cũng bị kem.

### Bổ sung sau khi hiệu chỉnh `--review` (bản 10c, 16/10 đêm)
Bộ soát tự động (`bash tool/blender/render.sh <script> --review --quick`, ra `build/blender/review/<script>/sheet.png`) bắt được hai lỗi thật trên oni đã duyệt. Cả hai bị ảnh góc game che.
- **Góc game che lỗi bên hông.** Vòng tay chìm và vuốt hở chỉ lộ khi nhìn nghiêng, nhìn sau hoặc nhìn cận. Đọc đủ bộ ảnh soát, không chỉ ảnh toàn thân.
- **Có luật chưa chắc đã áp.** "Giáp đo da" đã ghi từ bản 10, nhưng vòng bắp tay oni vẫn không truyền `skin=`. Kiểm tự động đáng tin hơn danh sách nhắc.
- **Đừng tin ghi chú, hãy đo.** Ghi chú cũ nói oni cao ~2,6 m, đo thật ra 3,4 m. Tỉ lệ chân đo tới **khớp háng** (đầu xương `thigh`), không tới đầu xương `pelvis` MPFB (nằm cao hơn). Người thường khoảng 0,50–0,53; oni duyệt ở 0,56.
- **Dò trên lưới thô, hiện trên lưới mịn.** Subsurf làm ngón nhỏ co lại, nên vật gắn đặt theo lưới thô có thể hở (vuốt ngón thứ 4 hở 2,8 cm). Gắn xong thì kéo vật vào mặt da đã đánh giá (`toe_claws` đã làm việc này).
- **Vòng ôm chi béo: ôm theo viền da, không theo vòng tròn quanh xương.** Thiết diện tay béo là bầu dục và thịt xệ lệch trục. Vòng tròn hoặc chìm một phía, hoặc nới ra thì bung lỏng phía kia; nới theo tia hay nới vô hạn còn làm vòng bung ngang người. Dùng `japan_kit.band_fit` sau khi tạo dáng: nó đo viền da thật (chỉ đỉnh thuộc xương đó), làm mượt quanh chu vi rồi dựng vòng theo viền. Đặt vòng ở giữa đoạn chi; sát vai, sát hông thịt dính thân nên không có thiết diện riêng.
- **Số liệu đẹp chưa đủ, phải nhìn ảnh.** Một lần nới vòng tay cho kết quả "0% chìm" vì vòng đã phình to gấp đôi. Mỗi lần sửa theo số liệu, render ảnh cận vật vừa sửa.
- Bộ soát tự bỏ qua lưới mắt phụ MPFB (Irishelper). Đồ cố ý cắm vào thân (vuốt tay nắm, khuyên vòng sau thừng) thì khai báo qua `embedded=`.

## Model Tripo AI → repo (16/10/2026) (cũ: mục 12)
Tripo Studio gửi model sang Blender qua addon **Tripo Bridge** (cổng 60600). Addon này ghi file vào thư mục tạm, nhập vào cảnh rồi **xoá file ngay**: model chỉ còn trong cảnh chưa lưu. Đường ống của repo:
- **Addon `SPU Tripo`** (`tool/blender/addons/tripo_inbox.py`, cài một lần bằng `blender -b -P tool/blender/install_tripo_inbox.py`; file mồi trong thư mục addon nạp code thẳng từ repo).
  - Tự động: bọc `ModelImporter.import_model` của Tripo, chép file gốc vào `art_src/tripo/_inbox/<giờ>_<tên>.glb` trước khi nhập. `_inbox/` không commit.
  - Nút **Gửi vào repo** (phím N › tab SPU): xuất vật đang chọn (cả con, xương, hoạt hình, chỗ sửa tay) → `art_src/tripo/<tên>/model.glb` + `meta.json` (tam giác, khung, xương, hoạt hình, ghi chú/prompt) + `thumb.png`. Thư mục này commit, `*.glb` qua **Git LFS** (`.gitattributes`).
- **`tool/blender/kits/tripo_kit.py`**: `load` (nhập, gom dưới `<tên>_root`, bỏ hình hiển thị xương Icosphere của bộ nhập glTF, **đổi tên xương sang tên MPFB game_engine**), `normalize` (yaw, chiều cao, chân chạm z=0), `decimate`, `tone` (bão hoà/sáng/nhám), `action_frames` (khung sprite từ hoạt hình Tripo), `default_lights` (ba đèn như oni).
  - Đổi tên xương theo tên + độ sâu thứ bậc (Mixamo `LeftUpLeg`→`thigh_l`, `Spine/Spine1/Spine2`→`spine_01..03`…), ghi `build/blender/tripo/<tên>/bones.txt`. Đoán sai thì truyền `bones={cũ: mới}`. Nhờ vậy `review_kit` / `sprite_kit` dùng nguyên, không cần bản riêng cho Tripo.
- **Xem nhanh:** `bash tool/blender/render.sh tripo_view <tên> [--height H] [--yaw Y] [--review] [--quick] [--save]` → `build/blender/review/<tên>/sheet.png`. Không cờ = bộ xoay vòng + ảnh đất sét (bỏ texture, lộ lỗi lưới). `--review` = bộ soát nhân vật, cần đủ xương người.
- **Dùng thật trong game:** viết `tool/blender/characters/<tên>.py` theo `tripo_kit` (như các script boss) rồi xuất sprite bằng `sprite_kit.export_sprites`.
- **Claude xem cảnh đang mở:** server MCP `blender` (`uvx blender-mcp==2.0.0`, phạm vi local, `DISABLE_TELEMETRY=true`) nói chuyện với addon *MCP for Blender* (cổng 9876). Trong Blender: N › tab BlenderMCP › **Connect**. Chỉ để xem/thử; sản phẩm đi qua hộp thư.
- **Giới hạn Tripo:** lưới tam giác lộn xộn, texture nướng sẵn ánh sáng → hợp quái thường, đồ vật, cảnh. Boss chính vẫn dựng bằng MPFB.

### Gắn xương và làm dày lưới model Tripo (tengu, 16/10 tối)
- **Đưa Tripo ảnh nhân vật tách nền, đứng chữ T/A.** Ảnh nguyên bức tranh (tengu trên cành thông) → Tripo dựng cả tranh thành tấm phù điêu, không có lưng.
- **Texture để Tripo làm (20 credit, đủ 360°); xương thì tự gắn** (`tripo_kit.build_rig`), không tốn credit. Khớp đọc trên ảnh chính diện + nghiêng có lưới toạ độ 10 cm (dáng chữ T rất dễ đọc). Xương thêm (cánh `wing_01..03_l`) đặt tên tuỳ ý, `_l` tự sinh `_r`.
- **Bone heat trên lưới AI hỏng cả lưới** (đỉnh tách theo đường nối UV, vải nhiều lớp). Ba bước đã thử ra:
  1. Tính trên bản phụ voxel remesh, ô = **1,5% chiều cao** (nhỏ hơn thì vải hở/lông cánh vỡ vụn, khối lớn nhất có khi là cái cánh).
  2. Chỉ giữ **khối liền lớn nhất**: một mảnh không "thấy" xương là hỏng cả hệ.
  3. Giải ở cỡ **×10**: cỡ 2 m có cánh thì bộ giải thiếu chính xác, ×10 thì được.
  Rồi chép trọng số về lưới thật theo 4 đỉnh gần nhất (UV/texture giữ nguyên).
- **Xoay xương theo trục thế giới** (`tengu_tripo.rot`), không đoán trục cục bộ — xương dọc (chân) và xương ngang (tay, cánh) có trục cục bộ khác nhau.
- **GLB chỉ chứa tam giác:** quad "Smart Mesh" của Tripo bị xẻ đôi khi xuất. `tripo_kit.densify`: hàn đỉnh trùng → ghép tam giác lại thành quad (tengu 9 882 tam giác → 5 823 quad ≈ 5 769 gốc) → Subdivision Surface đặt SAU xương. Mịn viền và chỗ gập khớp, không thêm chi tiết — chi tiết nằm ở texture 4096.
- `review_kit` khung mặt chỉ lấy đỉnh gần trục đầu (lưới liền có cánh kéo khung rộng).
- **Tengu chốt dùng bản Tripo** (`tengu_boss.py`, thay hẳn bản MPFB; code MPFB cũ còn trong lịch sử git). Người dùng duyệt chỉnh: cánh ×1,25, rũ xuống (`WING_SCALE`, `WING_DROOP`). Phóng cánh bằng scale ở xương `wing_01` trong dáng nền (đốt con thừa hưởng) → lông cánh không méo, gốc cánh vẫn bám lưng.
- **Tripo hay chỉ vẽ hoạ tiết mặt trước** (tengu: mon vàng có ở ngực/quần trước, lưng trơn). `tripo_kit.front_map` chiếu model từ trước ra ảnh màu theo (x, z) → cắt một hoạ tiết trọn vẹn làm khuôn → `stamp_back` đóng khuôn lên các tâm (x, z) ở mặt sau (chỉ phần màu hoạ tiết, chỉ lên vải; khuôn lật ngang để đọc đúng chiều từ sau). Làm trên texture lúc dựng, `model.glb` giữ nguyên.
  - **Không chép nguyên vị trí trước → sau:** mặt trước bị đai buông, vạt áo, nếp gấp che → hoạ tiết sau khuyết theo.
  - **Xét "là vải" theo màu trung bình cả tam giác:** vải Tripo có đốm nhạt khác màu; xét từng điểm ảnh thì khuôn thủng lỗ chỗ.
  - UV Tripo vỡ thành hàng trăm mảnh nhỏ → mọi thao tác texture phải đi qua toạ độ 3D, không cắt dán trong ảnh UV.

### Sửa trọng số sau `build_rig` (học từ chương 1 của Tung, 21/10/2026)
Năm hàm trong `tripo_kit`, đều hàn đỉnh trùng vị trí trước khi tính theo cạnh (GLB tách đỉnh ở đường nối UV):
- `islands(o)`: số mảnh lưới rời cho mỗi đỉnh (0 = lớn nhất). Vũ khí/khiên Tripo đúc liền file thường là một mảnh riêng.
- `add_prop_bone(rig, "club", đầu, đuôi, "hand_r")` + `pin_to_bone(o, ids, "club")`: **vũ khí gắn cứng vào xương riêng** con của bàn tay. Biên đạo xoay vũ khí mà không bẻ cổ tay; trọng số bàn tay không kéo méo cán.
- `smooth_weights(o, keep_groups=("club",))`: mảnh nhỏ (lọn tóc, tua, vạt) dùng chung trọng số trung bình rồi làm mượt Laplace; đỉnh vũ khí giữ nguyên. Chữa vải/tóc bị kéo thành sợi khi chân vung.
- `follow_nearest(o, isl, skip_groups=("club",))`: mảnh nhỏ (chuỗi hạt, khoá) lấy trọng số chỗ thân gần nhất → không tách khỏi thân.
- `surface_regions(o, {nhãn: hàm(toạ độ thế giới)})`: chia đỉnh theo đường đi trên bề mặt. Dùng khi các phần chồng nhau trong không gian (nhiều cổ rắn — Orochi; cánh áp thân; tay ôm bụng); lọc xương được phép theo vùng.
Thứ tự: `build_rig` → `add_fingers` → `pin_to_bone` → `smooth_weights` → `follow_nearest`. Đã chạy thử trên tengu (11 mảnh, tổng trọng số = 1 mọi đỉnh, < 1 s).

## Model Tripo cầm vật, màu vật cầm (cũ: mục 13)

- **Model Tripo cầm vật:** bàn tay xoè (không có xương ngón) → cán vuông góc
  ngón, xuyên lòng bàn tay; dựng quạt bằng xoay cổ tay quanh trục cánh tay
  (sấp/ngửa) theo pha. Đặt cán dọc theo ngón thì cán nằm song song dưới bàn
  tay — `--review` báo 0 cảnh báo, chỉ ảnh cận bắt được.
- Màu vật cầm phải tách khỏi vật sau nó ở khung ra đòn: quạt nâu nhạt chìm
  vào cánh nâu → đổi lông sẫm.
- `tengu_boss --review --strike`: bộ soát trên khung ra đòn.
