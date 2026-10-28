# Phông nền 8 màn Kỳ công 1 bằng ChatGPT

Mỗi màn một phông riêng, khớp vị trí điểm màn trên bản đồ (`2_ban_do.png`).
Vị trí các mốc (đền, cầu, sông, vách hang) trong từng prompt tính từ toạ độ
bản đồ: góc nhìn ngang từ đường mòn, hướng đi về hang = bên PHẢI ảnh.

## Cách làm

1. Mở MỘT cuộc trò chuyện mới với ChatGPT, làm cả 8 màn trong đó (giữ phong cách).
2. Kéo thả 3 ảnh trong thư mục này, dán **Tin nhắn 0**. Chưa tạo ảnh ở bước này.
3. Dán prompt **màn 1.8** trước (gần phông hiện tại nhất) → sửa tới khi ưng.
4. Lần lượt dán prompt các màn còn lại. Ảnh nào lệch phong cách: nhắc
   "giữ đúng phong cách, ánh sáng, đường chân trời và đường đất như ảnh màn 1.8".
5. Tải ảnh về, đặt tên `1.1.png` … `1.8.png` vào thư mục này rồi báo Claude:
   tách tầng parallax, chỉnh màu, gắn vào game.

Soát mỗi ảnh trước khi gửi: vùng nhân vật (trái) và vùng quái (phải) phải là
nền đất thoáng; không có người/quái/chữ trong ảnh; không có chi tiết méo kiểu
"rõ là AI" (cột đền xiêu vẹo, mái lệch, cây mọc lơ lửng).

---

## Tin nhắn 0 — luật chung (gửi kèm 3 ảnh)

```
I'm making a mobile push-up fitness RPG set in Ancient Greece (the Nemean Valley, Labor 1 of Hercules). I need 8 battle BACKGROUNDS, one per stage, all in one consistent style. Please read these rules first and only reply "ready" — don't generate yet.

Attached:
1) Current battle background — match its STYLE: fantasy-realism 3D-render look, warm late-afternoon Greek light, soft haze, golden-green meadows, olive trees, white marble temple with terracotta roof, pale limestone rocks, blue-grey mountains far away.
2) The valley MAP — each stage is a point on the winding trail from the olive grove (bottom-left) to the lion's cave (top-right). Each background must show what you would see at that point of the map.
3) The LAYOUT template — follow it exactly in every image:
   - Landscape 3:2 (1536x1024). Top and bottom grey bands will be cropped: put only sky / plain ground there.
   - A flat, open dirt path runs left-to-right along the red GROUND LINE (about 80% down the image). Characters stand on it.
   - HERO ZONE (green box, left) and MONSTER ZONE (purple box, right) must stay clear: only open path and DISTANT scenery behind them. No big trees, rocks or buildings inside those boxes.
   - Horizon roughly at the blue dashed line.
   - Big framing elements (trees, rocks) only at the far left and far right edges.
   - Side-on camera at standing eye height, looking across the trail; walking direction toward the lion's cave = RIGHT side of the image.
Rules for all 8: no people, no creatures, no text, no UI, no frame or border. Same camera height, horizon line, ground line, and rendering style in every image. Only the scenery and the time of day change between stages.
```

---

## Màn 1.1 — Bìa rừng ô liu (Đàn chim Stymphalia)

```
Stage 1.1 — Edge of the olive grove (bottom-left of the map, start of the trail). Early morning, soft golden sunrise light, light mist in the hollows, dew on the grass.
Foreground: gnarled old olive trees framing the far LEFT edge, wildflowers and tall grass along the path.
Middle distance: open rolling meadow; the river glints far away across the RIGHT half of the image.
Far: gentle green hills on the right, blue-grey mountains on the horizon. The temple is NOT visible yet.
Mood: peaceful start of a journey, birds' silhouettes allowed only as tiny dots in the sky.
```

## Màn 1.2 — Ruộng ven sông (Spartoi)

```
Stage 1.2 — Ploughed field by the river (left side of the map, trail meets the river). Mid-morning light.
Foreground: freshly ploughed dark earth furrows on both sides of the path (the dragon-tooth field where the Spartoi rise), a few scattered stones, a broken wooden plough at the far left edge.
Middle distance: the river runs across MOST of the width just behind the field (close, clearly visible water with reeds on its bank).
Far: green hills on the right half, mountains behind. No temple visible.
Mood: slightly ominous — a few cracks in the soil, darker clouds starting at the edges of the sky.
```

## Màn 1.3 — Chân đồi đền (Lính đá)

```
Stage 1.3 — Foot of the temple hill (center-left of the map). Late morning, bright and clear.
Right side: the white marble temple stands close and LARGE on a low hill at the far RIGHT (about 85–100% across), partly cropped by the right edge, behind the monster zone.
Along the path: empty marble statue pedestals and toppled statue pieces (the stone soldiers come from here), cypress trees.
Left: olive trees and stone walls framing the far left edge.
Far: limestone cliffs faintly visible on the right horizon. River not visible (it is behind the viewer).
```

## Màn 1.4 — Bụi rậm sườn đồi (Lợn rừng Erymanthus)

```
Stage 1.4 — Thorny thicket on the hillside past the temple (center of the map). Noon, hot hard sunlight.
Left edge: the temple is close but cut by the LEFT edge of the image (only its corner columns and roof visible).
Middle distance: dense dry thickets, oak scrub and trampled bushes, broken branches, hoof-churned mud on the path edges.
Far: the pale limestone cliffs of the lion's lair are a distant band on the horizon, center-right.
Mood: wild, rough, a beast's territory.
```

## Màn 1.5 — Cầu đá trên sông (Harpy)

```
Stage 1.5 — The old stone bridge over the river (center-bottom of the map). Early afternoon.
The river flows very close in the foreground-left and middle (left third of the image), with the arched stone bridge crossing it at the LEFT third; the path continues to the right on the river bank.
Middle distance, centered: the temple on its hill, small and far.
Far left: green hills. Sky slightly overcast with circling dark birds (tiny).
Mood: windy and exposed — feathers and leaves blowing.
```

## Màn 1.6 — Đầm lầy (Hydra non)

```
Stage 1.6 — A marsh pool off the river (right-center of the map), the young Hydra's swamp. Mid-afternoon, dimmer greenish light.
Middle distance: stagnant marsh water with reeds, lily pads, dead grey trees, mossy rocks; sickly green mist low over the water across most of the width.
Path: muddy, with a few flat stones; the open path area must stay clear and solid.
Far left: the temple on its hill, small; far right: limestone cliffs getting closer.
Mood: humid, eerie, poisonous.
```

## Màn 1.7 — Đường lên vách đá (Lính đá canh hang)

```
Stage 1.7 — Rocky climb toward the lion's lair (upper-right of the map). Late afternoon, long shadows, warm orange light.
Right half: tall pale limestone cliffs rising behind the monster zone, rubble and fallen boulders at their foot, broken marble statue parts (guardians of the lair).
Left: dry grass and sparse cypress; far below on the left, the valley with a thin glint of river and tiny hills.
Mood: tense, the air dustier and greyer as we near the lion.
```

## Màn 1.8 — Cửa hang sư tử (Sư tử Nemea, boss)

```
Stage 1.8 — The Nemean lion's cave (top-right end of the trail). Sunset, deep orange and purple sky, heavy dusty haze.
Right: the huge limestone cliff with the dark cave mouth, directly behind the monster zone (like the current background).
Left: a lone old olive tree at the far left edge, scattered bones and broken marble columns on the ground near the path edges.
Far: the temple tiny on a distant hill, mountains in purple haze.
Mood: climax, oppressive and grand.
```

---

## Bản đồ thung lũng (màn chọn màn)

Gửi trong CÙNG cuộc trò chuyện (sau 8 phông), kèm `4_khung_ban_do.png`.
Game tự vẽ đường mòn và 8 điểm màn (đỏ) đè lên ảnh theo toạ độ cố định,
nên các mốc phải nằm đúng chỗ như khung. Lưu kết quả thành `ban_do.png`.

```
Now paint the VALLEY MAP for the stage-select screen, in the same painterly style and palette as the 8 backgrounds. Follow the attached layout guide EXACTLY for where things are (the grey side bands will be cropped).
- View: a bird's-eye diorama of the Nemean valley seen from high above at an angle (about 40° tilt), like a fantasy board-game map, soft warm morning light from the upper left.
- Place every landmark exactly where the guide shows it: the winding river (blue band) with stepping stones where the trail fords it and an arched stone bridge at the BRIDGE mark; the white marble temple with terracotta roof on its hill at TEMPLE HILL; a dark green marsh pool with reeds and dead trees at MARSH, fed by a small stream from the river; dry thorny thicket at THICKET; ploughed brown field at PLOUGHED FIELD; old olive grove at bottom-left; pale limestone cliffs in the top-right corner with the dark cave mouth at LION CAVE.
- The RED line is the trail: paint a plain, light dirt footpath exactly along it, with no trees or rocks on it. Do NOT draw the red line, numbers, circles or any text.
- Elsewhere: golden-green meadows, olive trees and cypresses, rocky hills top-left; the area near the cave darker and dustier (the lion's corrupted land).
- No characters, no creatures, no labels, no compass, no border or frame.
```

**Bản 2 (dùng cái này nếu bản trên lệch vị trí):** kéo thả `5_phac_ban_do.png`
(bản phác màu thật, không chữ), dán:

```
Repaint THIS sketch into a detailed painted fantasy map in exactly the same style as the valley map you just made. This is an image edit: keep every shape EXACTLY where it is and the same size — the river's curve, the light dirt trail (every bend), the stone bridge where the trail crosses the river, the stepping stones, the ploughed field, the temple on its hill, the brown thicket, the dark marsh pool and its stream, the limestone cliffs and the black cave mouth top-right, the darker lion's land below the cave. Only add painterly detail: olive trees, cypresses, rocks, grass texture, water ripples, soft morning light from the upper left. Do not move, add or remove any path or landmark. No text, no characters. Keep the grey side bands grey.
```

---

Ghi chú cho Claude khi nhận ảnh: cắt 1536×1024 → dải giữa tỉ lệ 1344:780
(bỏ 66 px trên/dưới), tách tầng theo đường chân trời/đường đất của
`3_khung_bo_cuc.png`, chỉnh màu đồng bộ, thay phông theo màn
(`NemeaBackdrop`, rules/dohoa.md). Màn 1.6 dùng đầm lầy: cần thêm đầm vào
bản đồ (tool/blender/nemea_map.py + lib/art/nemea_map_art.dart).
