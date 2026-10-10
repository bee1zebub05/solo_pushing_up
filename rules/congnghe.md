# Công nghệ: nhân vật, animation, trang bị (Flutter)

> Ngày lập: 2026-10-09
> Liên quan: [cottruyen.md](cottruyen.md), [model_ai.md](model_ai.md)

---

## TL;DR

| Phần | Công nghệ đề xuất | Lý do |
|---|---|---|
| Phong cách | **2D vẽ tay** | 3D trong Flutter chưa ổn định, và một người làm thì không kham nổi khối lượng 3D |
| Nhân vật người chơi + thay đồ | **Spine** (runtime chính thức `spine_flutter`) | Hệ thống **skin mix-and-match** sinh ra cho việc thay đồ. Có sẵn ví dụ dress-up cho Flutter |
| Boss & quái | **Tranh tĩnh + hiệu ứng bằng code**. Riêng boss dùng Spine với vài animation | Rẻ nhất, vẫn sống động |
| UI, nút, thanh combo, dây kéo co, hiệu ứng menu | **Rive** | Có state machine, nhẹ, gói miễn phí làm được nhiều thứ |
| Màn chiến đấu (hạt, rung, số damage) | **Flame** (game engine 2D cho Flutter) hoặc `CustomPainter` | Màn đánh đơn giản, Flame giúp có sẵn particles, effects |
| Nhận diện tư thế | `flutter_pose_detection` (MediaPipe) hoặc `google_mlkit_pose_detection` → về lâu dài **viết plugin native riêng** | Xem mục 5 |

---

## 1. Vì sao 2D chứ không 3D

- **Flutter 3D chưa sẵn sàng.** `flutter_scene` (glTF, skeletal animation, PBR) vẫn ở bản **pre-1.0** và cần **Flutter master channel**, vì Flutter GPU chưa lên kênh stable. Không nên dùng cho app phát hành.
- **Nhúng Unity** (`flutter_unity_widget`) thì nặng, phức tạp, app phình to. Lúc đó làm hẳn bằng Unity còn hợp lý hơn.
- **Chi phí art:** 3D cần model, rig, texture, animation cho từng trang bị. Với một người làm, 2D rẻ hơn rất nhiều lần.
- **Đối thủ cũng làm 2D:** Pushup RPG dùng 48 quái "hand-drawn" 2D.

---

## 2. Nhân vật người chơi: Spine

### 2.1 Spine là gì
Phần mềm **animation khung xương 2D**. Họa sĩ vẽ nhân vật thành **từng bộ phận rời** (đầu, thân, cánh tay trên, cẳng tay, bàn tay, đùi, cẳng chân, áo choàng, vũ khí…). Animator gắn các bộ phận vào **xương** rồi làm chuyển động. Ưu điểm:
- **Một bộ animation dùng cho mọi bộ đồ**: đổi áo giáp chỉ là đổi hình gắn trên xương, không phải vẽ lại animation.
- **Skins mix-and-match**: ghép skin "tóc A" + "áo giáp Hy Lạp" + "khiên Bắc Âu" lúc runtime. Đúng thứ cần cho tạo nhân vật và trang bị.
- **Runtime chính thức cho Flutter** (`spine_flutter`, viết bằng Dart FFI bọc spine-cpp), có ví dụ `dress_up` để render nhân vật và ảnh thumbnail cho màn tạo nhân vật.

### 2.2 Chi phí
- Spine Editor trả tiền **một lần**, có các gói Essential, Professional, Enterprise. Gói Essential đủ cho các tính năng cơ bản; một số tính năng nâng cao như mesh deform chỉ có ở gói Professional. **Kiểm tra giá hiện tại trên esotericsoftware.com.**
- **Giấy phép runtime:** muốn dùng Spine runtime trong sản phẩm phát hành thì phải có giấy phép Spine Editor. Kiểm tra điều khoản trước khi phát hành.

### 2.3 Thiết kế hệ thống đồ (gợi ý)
```
Skeleton "body_A" và "body_B"   (2 kiểu cơ thể, dùng chung TÊN xương và slot)
 ├─ Slot: head, hair, face
 ├─ Slot: torso, cape
 ├─ Slot: upper_arm_L/R, forearm_L/R, hand_L/R
 ├─ Slot: thigh_L/R, shin_L/R, foot_L/R
 └─ Slot: weapon, shield, belt (đai lưng Hippolyta!)

Skin = 1 món đồ (gồm nhiều attachment)
 vd. "armor/greek_hoplite" = torso + upper_arm_L + upper_arm_R + belt
Runtime: skin tổng = base_body + hair + armor + weapon + cape
```
- Hai kiểu cơ thể dùng **cùng tên xương và slot**, nên **animation dùng chung** được. Có thể khác tỉ lệ xương.
- Mỗi trang phục Huyền thoại = một bộ skin, vẽ cho **cả 2 kiểu cơ thể**.
- Đồ theo cấp hiếm (Thường → Huyền thoại) chỉ cần **đổi màu, thêm hiệu ứng phát sáng**, không cần vẽ lại toàn bộ.

### 2.4 Bộ animation cần có cho người chơi
| Animation | Kích hoạt khi | Độ dài |
|---|---|---|
| `idle` | Chờ | Lặp |
| `attack_light` | Mỗi 🔼 rep thường | **≤ 0.3 giây** (phải theo kịp rep nhanh) |
| `attack_heavy` | 💥 rep sâu / 🐢 rep chậm | khoảng 0.5 giây |
| `combo_finisher` | Kết thúc combo | khoảng 0.8 giây |
| `guard` | ⏸ giữ tư thế cao | Lặp |
| `hit` | Bị boss đánh | khoảng 0.3 giây |
| `victory` / `defeat` | Kết thúc trận | |
| `level_up` | Lên cấp, "Vươn vai" | |

**Lưu ý kỹ thuật:** người chơi có thể làm 2–3 rep mỗi giây. Animation tấn công phải **ngắt được và hoà trộn được** (Spine hỗ trợ mix giữa các track). Không xếp hàng đợi animation, nếu không nhân vật sẽ "đánh trễ" so với rep thật, rất mất cảm giác.

---

## 3. Boss & quái: rẻ mà vẫn sống

72 kẻ thù mà đều làm animation khung xương thì quá tốn. Nên chia cấp:

| Cấp | Cách làm |
|---|---|
| Quái thường, tinh anh | **1 tranh tĩnh** + hiệu ứng bằng code: thở (co giãn nhẹ), rung khi trúng đòn, chớp trắng, bay số damage, hạt bụi xám "Trì Trệ" tan ra khi bị hạ |
| Mini-boss | Tranh tĩnh + 2–3 trạng thái vẽ thêm (bình thường, giận dữ, bị hạ) |
| **Boss** | **Spine** với 4–6 animation: idle, attack, hit, phase change, defeated |

→ Đây là cách nhiều game mobile 2D làm. Chất lượng tranh vẽ quan trọng hơn lượng animation.

---

## 4. UI & hiệu ứng: Rive

- **Rive** = công cụ thiết kế và animation tương tác, có **state machine** (animation phản ứng theo input).
- Runtime Flutter (`rive`) từ bản **0.14** đã chuyển sang **native C++ runtime**: nhanh hơn, có **data binding**.
- Dùng cho: nút bấm, **thanh combo**, **thanh nhiệt độ** (Ngưu Ma Vương), **dây kéo co** (duel, Sơn Tinh – Thuỷ Tinh), màn hình lên cấp, icon động, đếm ngược.
- Rive *cũng* làm được nhân vật, nhưng việc thay đồ phức tạp có xương và biến dạng mesh thì Spine có quy trình rõ ràng hơn. **Nhân vật dùng Spine, UI dùng Rive.**
- **Lottie** chỉ dùng cho vài hiệu ứng đơn giản có sẵn, nếu cần.

---

## 5. Kiến trúc app Flutter

```
┌─────────────────────────── Flutter (Dart) ───────────────────────────┐
│  UI app (menu, kho đồ, bản đồ, shop)  ← Flutter widgets + Rive       │
│  Màn chiến đấu                         ← Flame (hoặc CustomPainter)   │
│     ├─ Nhân vật & boss                 ← spine_flutter                │
│     ├─ Hiệu ứng, particles, số damage  ← Flame                        │
│     └─ HUD: combo, HP, kéo co          ← Rive                         │
│  Game logic (damage, combo, kỳ công)   ← Dart thuần, test được        │
│  Rep engine (state machine đếm rep)    ← Dart thuần, test bằng video  │
└───────────────▲──────────────────────────────────────────────────────┘
                │ chỉ gửi landmarks (33 điểm × x,y,z,visibility) ~30 lần/giây
┌───────────────┴────── Native plugin (Kotlin / Swift) ─────────────────┐
│  Camera (CameraX / AVFoundation) → MediaPipe Pose Landmarker (GPU)    │
└───────────────────────────────────────────────────────────────────────┘
```

### Nhận diện tư thế trong Flutter
| Package | Ưu | Nhược |
|---|---|---|
| `google_mlkit_pose_detection` (0.15) | Phổ biến, nhiều ví dụ | Do cộng đồng duy trì (không phải Google). Truyền từng frame camera qua platform channel nên tốn hiệu năng |
| `flutter_pose_detection` (0.4) | MediaPipe 33 điểm, dùng GPU/NPU, có sẵn hàm tính góc | Còn mới. Yêu cầu Android API 31+ (Android 12+) |
| **Plugin native tự viết** | Camera và model chạy hoàn toàn ở native, chỉ gửi landmarks sang Dart: **nhanh nhất, kiểm soát hoàn toàn** | Phải viết Kotlin + Swift |

**Đề xuất:**
1. **Prototype:** dùng `flutter_pose_detection` hoặc `google_mlkit_pose_detection` để có kết quả nhanh.
2. **Bản phát hành:** viết plugin native riêng, camera + MediaPipe chạy native, Dart chỉ nhận landmarks. Độ chính xác đếm rep là lợi thế cạnh tranh số 1, nên đáng đầu tư phần này.
3. **Rep engine viết bằng Dart thuần**, tách khỏi camera. Như vậy chạy được trên **bộ video test** (đưa landmarks đã trích sẵn vào) mà không cần điện thoại.

### Lưu ý hiệu năng
- Camera + model AI + animation cùng chạy: phải test trên **máy Android tầm thấp**.
- Màn chiến đấu giới hạn số particles. Spine dùng atlas texture vừa phải (2048×2048).
- Ưu tiên khung hình cho **pose detection**. Animation có thể giảm FPS khi máy yếu, đếm rep thì không được trễ.

---

## 6. Ai vẽ? Quy trình làm art

### Lựa chọn
| Cách | Khi nào dùng | Ghi chú |
|---|---|---|
| **Asset pack mua sẵn** (itch.io, Craftpix, GameDev Market, Spine asset) | **Prototype** | Rẻ, nhanh. Kiểm tra giấy phép thương mại |
| **Thuê họa sĩ freelance** (nhóm Facebook họa sĩ VN, ArtStation, Fiverr) | **Bản phát hành** | Cần: 1 họa sĩ concept/illustration + 1 người rig Spine (có thể cùng một người) |
| **AI tạo ảnh** | Chỉ dùng cho **moodboard, phác ý tưởng** | ⚠️ Pushup RPG bị trừ sao vì art "rõ là AI". Art cuối cùng nên do người vẽ, hoặc ít nhất được vẽ lại và chỉnh tay. Kiểm tra giấy phép của công cụ AI |

### Quy trình cho 1 nhân vật
1. **Concept:** phác 2 kiểu cơ thể + phong cách chung (tỉ lệ, đường nét, bảng màu).
2. **Vẽ tách lớp** theo danh sách slot ở mục 2.3, mỗi bộ phận một layer (PSD).
3. **Import vào Spine** (Spine có script xuất từ Photoshop), dựng xương, làm 8 animation ở mục 2.4.
4. **Vẽ trang bị** theo đúng khung bộ phận, mỗi món là một skin.
5. **Xuất** `.skel` / `.json` + `.atlas` + `.png`, rồi load bằng `spine_flutter`.

### Khối lượng cho bản ra mắt (4 vùng: Hy Lạp, Bắc Âu, Nhật, Việt Nam)
| Hạng mục | Số lượng |
|---|---|
| Nhân vật người chơi | 2 kiểu cơ thể × 8 animation |
| Trang phục khởi đầu | 1 bộ × 2 kiểu cơ thể |
| Trang phục Huyền thoại | 4 vùng × 2 (nam/nữ) × 2 kiểu cơ thể |
| Trang bị thường | khoảng 20–30 món (đổi màu theo độ hiếm) |
| Quái & tinh anh | 4 vùng × 4 = 16 tranh tĩnh |
| Mini-boss | 4 × 3 trạng thái |
| Boss (Spine) | 4 boss × 4–6 animation |
| NPC (Hercules, Hippolyta, Thánh Gióng…) | Chân dung + vài biểu cảm |
| Background | 4 vùng × 2–3 màn |
| UI (Rive) | Bộ nút, thanh combo, kéo co, lên cấp |

---

## 7. Lộ trình kỹ thuật đề xuất

| Bước | Việc |
|---|---|
| 1 ✅ | Prototype đếm rep: Flutter + plugin pose có sẵn + rep engine Dart (chưa cần art) — xem rules/hoanthien_core.md |
| 2 ✅ | Màn chiến đấu thô: mỗi rep là một đòn, để kiểm tra cảm giác (làm bằng widget Flutter + `lib/game/battle.dart`, chưa cần Flame). Đã thêm tiến trình XP/cấp/vật phẩm và Kỳ công 2 (Rồng Fafnir, giá lạnh), Kỳ công 5 (Orochi, 8 đầu mọc lại khi đứt combo), Kỳ công 12 (Thuỷ Tinh, nước dâng + đợt sóng ⚡🐢⏸💥) |
| 3 ✅ (đổi hướng) | Không dùng Spine/Rive (trả phí: Spine cần giấy phép, Rive từ 10/2025 phải trả phí mới xuất .riv). Thay bằng: vẽ nhân vật bằng code (`lib/art/`) + sân khấu **Flame** (MIT) cho effect/hạt. Nhân vật chương 1 + Sư tử Nemea đã xong. 3D (flutter_scene/Flutter GPU) còn preview, chỉ chạy kênh master: theo dõi sau |
| 4 | Chốt phong cách art, thuê họa sĩ làm **1 nhân vật + 1 boss (Sư tử Nemea)** làm mẫu |
| 5 | Viết plugin native camera + MediaPipe, thay plugin có sẵn |
| 6 | Sản xuất art cho 4 vùng ra mắt |

---

## Nguồn
- [spine-flutter Runtime Documentation](http://en.esotericsoftware.com/spine-flutter) · [Spine Runtime Skins](https://esotericsoftware.com/spine-runtime-skins) · [Spine Mix and Match](http://esotericsoftware.com/spine-unity-mix-and-match)
- [rive (pub.dev)](https://pub.dev/packages/rive) · [rive-flutter GitHub](https://github.com/rive-app/rive-flutter) · [Rive Best Practices](https://rive.app/docs/getting-started/best-practices) · [Rive Flutter native runtime](https://medium.com/@cscipher/upgrading-rive-in-flutter-the-move-to-a-native-runtime-9763747ff3e6) · [Issue: runtime asset swapping](https://github.com/rive-app/rive-flutter/issues/43)
- [flame (pub.dev)](https://pub.dev/packages/flame/versions/1.38.0) · [Flame (fluttergems)](https://fluttergems.dev/packages/flame/)
- [flutter_scene (pub.dev)](https://pub.dev/packages/flutter_scene/versions/0.19.0)
- [google_mlkit_pose_detection](https://pub.dev/packages/google_mlkit_pose_detection) · [flutter_pose_detection](https://pub.dev/documentation/flutter_pose_detection/latest/) · [flutter_mp_pose_landmarker](https://pub-web-s1.flutter-io.cn/documentation/flutter_mp_pose_landmarker/0.1.3)
