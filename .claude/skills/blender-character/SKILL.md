---
name: blender-character
description: Phòng Dựng hình — dựng hoặc sửa một nhân vật/boss hình người bằng Blender (tool/blender/, MPFB hoặc model Tripo) cho game Solo Pushing Up — theo quy trình khối → bóng → chi tiết của rules/dohoa/dunghinh.md, BẮT BUỘC chạy bộ soát `--review` và tự đọc sheet.png trước khi đưa ảnh cho người dùng xem. Dùng khi được yêu cầu dựng boss/nhân vật mới, sửa theo nhận xét ("bụng chưa béo", "vuốt lệch"…), thêm phụ kiện cho một nhân vật Blender. Dáng ra đòn → boss-motion; xuất sprite/video → render-export.
---

# Dựng nhân vật Blender: quy trình và cổng soát

Nhân vật hình người là phần tốn vòng nhận xét nhất (oni: ~9 vòng, phần lớn
là lỗi máy bắt được). Skill này là quy trình của **phòng Dựng hình** (`rules/dohoa/README.md`).
**Đọc `rules/dohoa/dunghinh.md` (mục "Bài học sau khi dựng oni") trước khi làm** —
skill chỉ là khung, chi tiết bài học nằm ở đó và được bổ sung sau mỗi nhân vật.

## 0. Chọn đường dựng

| Trường hợp | Đường | Bắt đầu từ |
|---|---|---|
| Boss chính, cần sửa khối/tỉ lệ chi tiết | MPFB (`human_kit`, `japan_kit`, `hair_kit`) | `oni_boss.py` làm mẫu |
| Quái thường, đồ vật, boss người dùng đã chốt từ Tripo | Model Tripo (`tripo_kit`) | `tengu_boss.py` làm mẫu; dunghinh.md mục Tripo |

Model Tripo: người dùng gửi qua nút **Gửi vào repo** → `art_src/tripo/<tên>/`.
Xem trước bằng `bash tool/blender/render.sh tripo_view <tên>`. Đừng xoá thư
mục Tripo cũ khi người dùng bảo giữ.

## 1. Trước khi dựng (nhân vật mới)

1. **Xin ảnh tham khảo dáng người** (chính diện + nghiêng), không chỉ tranh
   phong cách. Ghi 3–5 đặc điểm nhận dạng.
2. Tranh tham khảo phải dùng thương mại được — ghi nguồn + giấy phép vào
   bảng tranh tham khảo ở `rules/dohoa/phongcach.md`.
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

## 3. Luật hay quên (đầy đủ ở rules/dohoa/dunghinh.md)

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
   `--review` bắt lỗi số đo; còn "trông ngố" thì cần mắt khác. Gọi agent
   `critic` MỚI (tool Agent, `subagent_type: critic`), đưa sheet.png + ảnh tham
   khảo + tờ spec mục 1, KHÔNG nói mình vừa dựng. Hỏi: "Chấm 1–10 so với tham khảo; liệt
   kê ≥ 6 chỗ trông nghiệp dư (tỉ lệ, dáng, chất liệu, độ đáng sợ)." Sửa →
   render lại → critic mới, lặp tới ≥ 8/10.
6. Chỉ khi sheet sạch mới render ảnh duyệt đầy đủ (`--still`) và đưa người dùng.
   Khi đưa, nói rõ còn cảnh báo nào (nếu có) và vì sao chấp nhận.

## 5. Bàn giao cho phòng sau

Phòng Dựng hình xong khi sheet.png sạch + critic đạt + người dùng duyệt
`--still`. Từ đây:
- **Dáng ra đòn, biên đạo, mocap** → skill `boss-motion` (phòng Chuyển động).
  Script nhân vật chỉ cần dáng chờ ổn định, rig sạch, và lớp `<Boss>Motion`
  nằm trong `tool/motion/<boss>_motion.py` (không viết đòn trong file dựng hình).
- **Xuất sprite, video, báo cáo** → skill `render-export`.
- Nhân vật mới cần góc sân khấu: boss hình người quay gần nghiêng về Hercules
  (oni −72°, tengu −55°), mắt nhìn đối thủ (`aim_pupils(look=…)`). Model Tripo
  thiếu xương ngón → `tripo_kit.add_fingers`.

## 6. Ghi lại

- Bài học mới (bẫy Blender, luật dựng) → `rules/dohoa/dunghinh.md`, và nếu
  máy kiểm được thì thêm vào `review_kit` thay vì chỉ ghi chữ.
- Ghi `baocao_dohoa.html` theo `rules/dohoa/xuat.md` (ảnh + video nhúng base64).
- Commit riêng từng hạng mục.
