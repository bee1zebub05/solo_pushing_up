---
name: blender-character
description: Dựng, sửa hoặc xuất sprite một nhân vật/boss hình người bằng Blender (tool/blender/, MPFB hoặc model Tripo) cho game Solo Pushing Up — theo quy trình khối → bóng → chi tiết của rules/dohoa.md mục 11, BẮT BUỘC chạy bộ soát `--review` và tự đọc sheet.png trước khi đưa ảnh cho người dùng xem. Dùng khi được yêu cầu dựng boss/nhân vật mới, sửa theo nhận xét ("bụng chưa béo", "vuốt lệch"…), thêm phụ kiện, dựng dáng ra đòn hay xuất sprite cho một nhân vật Blender.
---

# Dựng nhân vật Blender: quy trình và cổng soát

Nhân vật hình người là phần tốn vòng nhận xét nhất (oni: ~9 vòng, phần lớn
là lỗi máy bắt được). Skill này đóng gói `rules/dohoa.md` mục 10–12 thành
quy trình. **Đọc mục 11 của dohoa.md trước khi làm** — skill chỉ là khung,
chi tiết bài học nằm ở đó và được bổ sung sau mỗi nhân vật.

## 0. Chọn đường dựng

| Trường hợp | Đường | Bắt đầu từ |
|---|---|---|
| Boss chính, cần sửa khối/tỉ lệ chi tiết | MPFB (`human_kit`, `japan_kit`, `hair_kit`) | `oni_boss.py` làm mẫu |
| Quái thường, đồ vật, boss người dùng đã chốt từ Tripo | Model Tripo (`tripo_kit`) | `tengu_boss.py` làm mẫu; mục 12 |

Model Tripo: người dùng gửi qua nút **Gửi vào repo** → `art_src/tripo/<tên>/`.
Xem trước bằng `bash tool/blender/render.sh tripo_view <tên>`. Đừng xoá thư
mục Tripo cũ khi người dùng bảo giữ.

## 1. Trước khi dựng (nhân vật mới)

1. **Xin ảnh tham khảo dáng người** (chính diện + nghiêng), không chỉ tranh
   phong cách. Ghi 3–5 đặc điểm nhận dạng.
2. Tranh tham khảo phải dùng thương mại được — ghi nguồn + giấy phép vào
   bảng ở dohoa.md mục 7.
3. Kami / nhân vật nhạy cảm: kiểm `rules/cottruyen.md` (ngoại lệ đã chốt
   thì không hỏi lại).
4. **Viết tờ spec và xin người dùng chốt trước khi dựng** — gu nằm ở đây, không
   ở lúc dựng. Spec gồm: silhouette một dòng, 3 khối chữ ký khác con generic,
   tỉ lệ mục tiêu (điền thẳng vào `targets` của `--review`), phụ kiện + chất
   liệu, "điểm khác biệt". Thiếu spec → dừng, viết trước; đây là đầu vào của
   cổng soát mục 4.

## 2. Thứ tự dựng: khối → bóng → chi tiết

1. **Tỉ lệ khung** (chiều dài chân, thân) — đo, đừng tin ghi chú. Chân đo
   tới khớp háng (đầu xương `thigh`): người thường 0,50–0,53, oni 0,56.
2. **Bóng ba hướng** trước, nghiêng, sau — render ẩn quần áo (`--clay`).
3. Rồi mới tới mặt, gân, vuốt, phụ kiện, hiệu ứng.

Mỗi bước dùng vòng thử nhanh `--dry --quick` + script soát (`ONI_DEBUG`
là mẫu) render đúng góc cần xem; chỉ render đầy đủ khi đã ưng.

## 3. Luật hay quên (đầy đủ ở dohoa.md mục 11)

- Quần áo sao từ thân thừa hưởng lỗi của thân → soát thân trần trước.
- Vải rộng dựng **sau** khi tạo dáng bằng bao lồi (`japan_kit.DrapedSkirt`);
  đồ dựng sau tạo dáng chỉ đúng cho **dáng đó** → sprite nhiều dáng phải
  dựng lại theo từng khung.
- Dò điểm trên lưới ở **dáng nghỉ**; dò trên lưới thô, kéo vật vào da mịn
  sau subsurf.
- Đồ ôm chi đo da: `limb_band(skin=…)`, chi béo dùng `japan_kit.band_fit`.
- Chuỗi/dây: xử lý cả đường (`drape_chain`), số hạt vừa chiều dài.
- Phụ kiện nhỏ phải đọc được ở cỡ sprite, có quai/khuyên bám vật mang.
- Tên thuộc tính lưới có tiền tố (không `heat`, `density`, `color`…).
- Lửa: `japan_kit.fire_material`, không `flame_material` cũ (AgX ra kem).
- Vật liệu tối: spec ≤ 0,25, sheen ≤ 0,06; đèn viền lam nhạt.
- Không `bmesh.from_mesh` trên thân MPFB đã tạo dáng (sập) → `_surface_tree`.
- Sửa kit dùng chung → soát các nhân vật khác dùng chỗ đó.
- Model Tripo: gắn xương bằng `tripo_kit.build_rig` (voxel 1,5% chiều cao,
  khối liền lớn nhất, giải ở ×10); xoay xương theo trục **thế giới** (`rot`).

## 4. Cổng soát BẮT BUỘC trước khi đưa người dùng xem

Không gửi ảnh duyệt nào khi chưa qua bước này.

1. Script nhân vật phải có khối `if "--review" in sys.argv:` gọi
   `review_kit.review(scene, body, rig, "<script>", S, fwd, clothes=…,
   important={nhãn: [regex]}, free=…, embedded=…, targets=…)` (mẫu:
   `oni_boss.main`, `tengu_boss.main`). Nhân vật chưa có → thêm trước.
   - `clothes`: vải để ảnh "nghiêng trần" ẩn đi.
   - `important`: mọi phụ kiện người dùng có thể phóng to (vũ khí, khoá,
     chuỗi hạt, lửa tay…) — mỗi cái có ảnh cận + % bị che.
   - `free`: vật trong suốt/rời (lửa, vũ khí) — tia đi xuyên.
   - `embedded`: vật cố ý cắm vào thân (vuốt nắm cán).
   - `targets`: tỉ lệ mong muốn, ví dụ `{"chân (khớp háng)/chiều cao": (0.48, 0.58)}`.
2. Chạy `bash tool/blender/render.sh <script> --review --quick` (~2 phút)
   → `build/blender/review/<script>/sheet.png` + `checks.txt`.
3. **Mở sheet.png bằng Read và nhìn từng ô**, không chỉ đọc cảnh báo:
   góc game che lỗi bên hông (vòng tay chìm, vuốt hở chỉ lộ khi nghiêng/sau).
   Tự hỏi: bóng có giống tham khảo? đồ gắn có bị che? chỗ tiếp xúc (đai–thân,
   vải–chân, vuốt–ngón, tay–cán) có khớp?
4. Mọi cảnh báo: sửa, hoặc chứng minh báo nhầm bằng ảnh cận rồi hiệu chỉnh
   `review_kit` (ghi lý do). "0 cảnh báo" mà vật phình gấp đôi vẫn là lỗi —
   mỗi lần sửa theo số liệu, render ảnh cận vật vừa sửa.
5. **Critic mắt-lạ trước khi đưa người dùng (thuốc chữa "ngô nghê"):** máy
   `--review` bắt lỗi số đo; còn "trông ngố" thì cần mắt khác. Gọi một reviewer
   ĐỘC LẬP (tool Agent, `general-purpose`), đưa sheet.png + ảnh tham khảo + tờ
   spec mục 1, KHÔNG nói mình vừa dựng. Hỏi: "Chấm 1–10 so với tham khảo; liệt
   kê ≥ 6 chỗ trông nghiệp dư (tỉ lệ, dáng, chất liệu, độ đáng sợ)." Sửa →
   render lại → critic mới, lặp tới ≥ 8/10.
6. Chỉ khi sheet sạch mới render ảnh duyệt đầy đủ (`--still`) và đưa người dùng.
   Khi đưa, nói rõ còn cảnh báo nào (nếu có) và vì sao chấp nhận.

## 5. Dáng ra đòn và sprite

- **Biên đạo trước, code sau** (dohoa.md mục 14): tra võ thuật của binh
  khí (thế thủ có tên, bước chân, zanshin), viết khoá vào
  `tool/blender/choreo/<id>.json` — mỗi boss ≥ 2 đòn, mỗi đòn có dấu hiệu
  báo trước riêng đọc được ở dạng bóng. Đòn = cả người: trọng tâm dịch/hạ,
  bước chân (IK bám đất), hông dẫn → thân → tay → vũ khí (`lag`), khựng lúc
  chạm, zanshin, phần phụ (cánh, tua) theo sau. Chỉ vung tay = "thô".
- Nhịp theo `AttackPose`: lấy đà 0–0,5, ra đòn 0,5–0,65, thu về 0,65–1
  (`lib/art/motion.dart`); mốc `impact` trong JSON canh hiệu ứng.
- Soát bằng tấm tư thế khoá (`--still --game`, ghép có nhãn tiến độ) TRƯỚC
  khi xuất sprite; hướng vũ khí sai thì in số đo, đừng đoán.
- Sau khi sửa JSON: `python tool/gen_choreo.py` (bản vector Flutter đọc cùng
  biên đạo) + `flutter test test/art/choreo_test.dart`.
- Soát dáng ra đòn như dáng đứng: `--review` trên khung đỉnh đòn (tay, cánh,
  vải duỗi xa nhất) + ảnh `--still` các khung windup/strike/defeat.
- Xuất: chạy script không `--still` → `sprite_kit.export_sprites(scene, cam,
  "<tên>", {"idle": [...], "attack": [...], "defeat": [...]}, anchor,
  units_per_m, extra={"idlePeriod": …})` → `assets/sprites/<tên>.json` +
  trang WebP (render.sh tự nén). Ngân sách ~3 px/đơn vị sân khấu, 1–2 trang
  2048² mỗi boss. Máy quay nhìn ¾ về phía trái màn hình (nhân vật đứng trái).
- Flutter: BossArt nạp atlas trong `preload()`, trả trong `dispose()`, vẽ bằng
  `SpriteAtlas.draw`; **luôn có bản vector 2.5D** cho lúc chưa nạp / chế độ
  2.5D (dohoa.md mục 9). Đăng ký ở `lib/art/bosses/boss_registry.dart`, thêm
  ca xem trước ở `test/art/art_preview_test.dart`.

## 6. Ghi lại

- `baocao_dohoa.html`: mục mới chèn ngay dưới `<h1>` (kiểu stack), có
  ngày giờ, commit, việc chờ duyệt. File lớn — chèn bằng script, đừng đọc cả.
- Bài học mới (bẫy Blender, luật dựng) → bổ sung dohoa.md mục 11/12, và nếu
  máy kiểm được thì thêm vào `review_kit` thay vì chỉ ghi chữ.
- Commit riêng từng hạng mục.

## Đòn đánh từ mocap (19/10/2026)

Dáng ra đòn của boss hình người: dùng skill `martial-motion` (thân từ mocap võ
học thật + tay vũ khí theo biên đạo, `tool/blender/mocap_drive.py`). Góc sân
khấu: quay gần nghiêng về Hercules (oni −72°, tengu −55°), mắt nhìn đối thủ
(`aim_pupils(look=…)`), KHÔNG nhìn máy quay. Model Tripo thiếu xương ngón →
`tripo_kit.add_fingers`. Render khi đang huấn luyện torch: `BLENDER_CPU=1`.
