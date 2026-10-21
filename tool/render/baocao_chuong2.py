"""Báo cáo chương 2 (Nhật Bản) → baocao_chuong2.html, theo khuôn baocao_chuong1.html
của Tung (CSS chung: tool/render/baocao_style.css). Ảnh, hoạt ảnh (ghép từ atlas
sprite thật), video nhúng base64 — một file mở được ở mọi nơi.

    python -I tool/render/baocao_chuong2.py

Mục so sánh gắn xương đọc build/blender/rig_compare/{ours,tripo_<tên>}/ (tool/blender/
rig_compare.py). Chưa có bản Tripo thì cột Tripo hiện ô chờ — chạy rig_compare
tripo <tên> rồi chạy lại script này.
"""

import base64
import glob
import io
import json
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SPRITES = os.path.join(ROOT, "assets", "sprites")
BUILD = os.path.join(ROOT, "build")
OUT = os.path.join(ROOT, "baocao_chuong2.html")


def b64(data, mime):
    return f"data:{mime};base64," + base64.b64encode(data).decode()


def webp(im, width, q=80):
    im = im.copy()
    if im.width > width:
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "WEBP", quality=q, method=4)
    return b64(buf.getvalue(), "image/webp")


def still(path, width=900):
    p = os.path.join(ROOT, path)
    return webp(Image.open(p).convert("RGBA"), width) if os.path.exists(p) else None


def anim(atlas, name, width=380, frame_ms=None):
    """Hoạt ảnh WebP động từ chính atlas sprite game: mỗi khung đặt theo điểm neo (dx, dy)."""
    meta = json.load(open(os.path.join(SPRITES, f"{atlas}.json"), encoding="utf-8"))
    upp = meta["unitsPerPixel"]
    pages = {}
    frames = meta["anims"][name]
    boxes = []
    for f in frames:
        x0, y0 = f["dx"] / upp, f["dy"] / upp
        boxes.append((x0, y0, x0 + f["w"], y0 + f["h"]))
    L, T = min(b[0] for b in boxes), min(b[1] for b in boxes)
    R, B = max(b[2] for b in boxes), max(b[3] for b in boxes)
    out = []
    for f, (x0, y0, _, _) in zip(frames, boxes):
        if f["p"] not in pages:
            pages[f["p"]] = Image.open(os.path.join(SPRITES, f"{atlas}_{f['p']}.webp")).convert("RGBA")
        crop = pages[f["p"]].crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"]))
        canvas = Image.new("RGBA", (round(R - L), round(B - T)), (0, 0, 0, 0))
        canvas.alpha_composite(crop, (round(x0 - L), round(y0 - T)))
        if canvas.width > width:
            canvas = canvas.resize((width, round(canvas.height * width / canvas.width)), Image.LANCZOS)
        out.append(canvas)
    if frame_ms is None:
        frame_ms = round(meta.get("idlePeriod", 3) * 1000 / len(frames)) if name == "idle" else 75
    buf = io.BytesIO()
    out[0].save(buf, "WEBP", save_all=True, append_images=out[1:], duration=frame_ms, loop=0, quality=75, method=4)
    return b64(buf.getvalue(), "image/webp")


def video(path):
    p = os.path.join(ROOT, path)
    return b64(open(p, "rb").read(), "video/mp4") if os.path.exists(p) else None


def anim_cards(atlas, items):
    cards = []
    for key, desc in items:
        src = anim(atlas, key)
        cards.append(f'<div class="anim"><div class="stage"><img src="{src}" alt="{desc}"></div>'
                     f'<div class="cap"><code>{key}</code><span>{desc}</span></div></div>')
    return '<div class="anims">' + "\n".join(cards) + "</div>"


def video_pair(items):
    figs = []
    for path, cap in items:
        src = video(path)
        if src:
            figs.append(f'<figure><video src="{src}" controls loop muted playsinline preload="metadata"></video>'
                        f"<figcaption>{cap}</figcaption></figure>")
    return '<div class="pair">' + "".join(figs) + "</div>" if figs else ""


POSES = [
    ("1_ha_tay", "Đứng, hạ tay", "Vai và nách: tay hạ từ chữ T, vải tay áo phải rủ theo, không kéo theo sườn."),
    ("2_gio_tay", "Giơ hai tay qua đầu", "Vai: lưới quanh vai không sụp, đầu không bị kéo theo tay."),
    ("3_gap_khuyu", "Gập khuỷu 115°", "Khuỷu: mặt trong không xẹp như vòi gập, mặt ngoài giữ khối."),
    ("4_khuyu_goi", "Khuỵu gối 55°", "Gối, háng, vạt hakama: quần không xé, gối không gãy gập."),
    ("5_buoc_dai", "Bước dài", "Háng: vải giữa hai chân không bị kéo thành màng."),
    ("6_van_than", "Vặn thân 30°", "Eo: đai lưng vặn đều, không xoắn thắt một chỗ; cánh theo lưng."),
    ("7_nam_tay", "Nắm tay", "Ngón: gập đúng khớp, không dính nhau, mu bàn tay không méo."),
]


def rig_compare():
    ours = os.path.join(BUILD, "blender", "rig_compare", "ours")
    tripo = sorted(glob.glob(os.path.join(BUILD, "blender", "rig_compare", "tripo_*")))
    tripo = tripo[0] if tripo else None
    rows = []

    def cell(d, key):
        if not d or not os.path.exists(os.path.join(d, f"{key}_tex.png")):
            return '<div class="pending">Chờ bản Tripo Auto Rig</div>'
        tex = webp(Image.open(os.path.join(d, f"{key}_tex.png")).convert("RGBA"), 560)
        clay = webp(Image.open(os.path.join(d, f"{key}_clay.png")).convert("RGBA"), 560)
        return (f'<div class="rc-img"><img class="v-tex" src="{tex}" alt="có texture" loading="lazy">'
                f'<img class="v-clay" src="{clay}" alt="đất sét" loading="lazy"></div>')

    for key, label, look in POSES:
        rows.append(f'<div class="rc-row"><div class="rc-label"><b>{label}</b><span>{look}</span></div>'
                    f'<div class="rc-pair"><figure>{cell(ours, key)}<figcaption>A · mình tự gắn</figcaption></figure>'
                    f'<figure>{cell(tripo, key)}<figcaption>B · Tripo Auto Rig</figcaption></figure></div></div>')

    def nbones(d):
        p = d and os.path.join(d, "bones.txt")
        return open(p, encoding="utf-8").readline().strip() if p and os.path.exists(p) else "—"

    return "\n".join(rows), nbones(ours), nbones(tripo), bool(tripo)


EXTRA_CSS = """
:root { --bg: #F1EDE6; --line: #DDD5C8; --accent: #A3301E; --accent-soft: #F6E2DC; --stage: #D8CFC2; }
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) { --bg: #17140F; --surface: #211D17; --line: #3A332A; --accent: #EE8C74; --accent-soft: #3D211B; --stage: #CBBFAE; }
}
:root[data-theme="dark"] { --bg: #17140F; --surface: #211D17; --line: #3A332A; --accent: #EE8C74; --accent-soft: #3D211B; --stage: #CBBFAE; }
video { width: 100%; height: auto; display: block; border-radius: 8px; border: 1px solid var(--line); background: #000; }
.dodge { font-size: 1.05rem; }
/* So sánh gắn xương: A trái, B phải; nút đổi texture / đất sét. */
.rc-toolbar { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
.rc-toolbar button { font: inherit; font-size: 0.9rem; padding: 6px 14px; border-radius: 999px; border: 1px solid var(--line); background: var(--surface); color: var(--fg); cursor: pointer; }
.rc-toolbar button[aria-pressed="true"] { background: var(--accent); border-color: var(--accent); color: var(--bg); }
.rc-row { display: grid; grid-template-columns: minmax(0, 220px) minmax(0, 1fr); gap: 16px; align-items: center; border-top: 1px solid var(--line); padding-top: 14px; }
.rc-label { display: flex; flex-direction: column; gap: 4px; }
.rc-label span { font-size: 0.86rem; color: var(--muted); }
.rc-pair { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
.rc-img { background: radial-gradient(ellipse at 50% 85%, #F4EEE4 0%, var(--stage) 75%); border-radius: 8px; border: 1px solid var(--line); aspect-ratio: 4 / 3; display: grid; place-items: center; overflow: hidden; }
.rc-img img { border: 0; border-radius: 0; max-height: 100%; width: auto; max-width: 100%; }
.pending { aspect-ratio: 4 / 3; display: grid; place-items: center; text-align: center; padding: 12px; border: 1px dashed var(--line); border-radius: 8px; color: var(--muted); font-size: 0.9rem; }
body.clay .v-tex, body:not(.clay) .v-clay { display: none; }
.vote { display: flex; flex-wrap: wrap; gap: 8px; }
@media (max-width: 640px) { .rc-row { grid-template-columns: 1fr; } }
"""

JS = """
document.querySelectorAll('[data-view]').forEach(b => b.addEventListener('click', () => {
  document.body.classList.toggle('clay', b.dataset.view === 'clay');
  document.querySelectorAll('[data-view]').forEach(x => x.setAttribute('aria-pressed', String(x === b)));
}));
"""


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    css = open(os.path.join(os.path.dirname(__file__), "baocao_style.css"), encoding="utf-8").read()
    rc_rows, ours_bones, tripo_bones, have_tripo = rig_compare()
    oni_still = still("build/blender/oni/still_full.png")
    tengu_still = still("build/blender/review/tengu_boss/00_full.png")
    oni_sheet = still("build/blender/review/oni_boss/sheet.png", 1200)
    tengu_sheet = still("build/blender/review/tengu_boss/sheet.png", 1200)

    def fig(src, alt, cap):
        return f'<figure><img src="{src}" alt="{alt}" loading="lazy"><figcaption>{cap}</figcaption></figure>' if src else ""

    # Artifact tự bọc <!doctype>/<head>/<body> khi đăng: file chỉ chứa nội dung trang.
    html = f"""<title>Solo Pushing Up · Chương 2</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Lora:wght@500;600;700&family=Be+Vietnam+Pro:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap">
<style>
{css}
{EXTRA_CSS}
</style>
<div class="page" lang="vi">

<header>
  <span class="eyebrow">Báo cáo tiến độ · cập nhật 21/10/2026</span>
  <h1>Solo Pushing Up · Chương 2: Nhật Bản</h1>
  <p>Chương Nhật đưa vào hai boss ra đòn theo võ thuật Nhật, mỗi đòn có thế báo trước để người chơi đọc và chọn cách né bằng chính động tác hít đất. Báo cáo tóm tắt thiết kế, đồ hoạ 3D của hai boss, và một bài so sánh gắn xương để chọn cách làm cho các boss sau.</p>
  <div class="meta"><span><b>Nhánh</b> feat/chapter2_japan</span><span><b>Đồ hoạ</b> Blender 5.2 → sprite</span><span><b>Chuyển động</b> mocap võ học thật + biên đạo</span></div>
  <div class="summary">
    <div class="fact"><span class="num">2</span><span class="lbl">boss: Shuten-dōji (mini-boss Izumo) và Thiên hoàng Sutoku hoá tengu (boss Heian)</span></div>
    <div class="fact"><span class="num">2</span><span class="lbl">cách né dùng chung cả chương: giữ tay thẳng đỡ đòn bổ, rep sâu rạp người né đòn quét</span></div>
    <div class="fact"><span class="num">11</span><span class="lbl">hoạt ảnh trong game, đòn đánh lấy thân từ mocap võ thật (Kyokushin, CMU)</span></div>
    <div class="fact"><span class="num">MPFB + Tripo</span><span class="lbl">oni dựng người MPFB; tengu sinh từ ảnh bằng Tripo AI, tự gắn xương</span></div>
  </div>
</header>

<section>
  <div class="sec-head"><span class="eyebrow">Thiết kế</span><h2>Đọc thế đòn, chọn cách né</h2></div>
  <p>Hai boss dùng chung một bộ từ vựng né, học một lần dùng cả chương. Mỗi đòn báo trước 2,5 giây bằng thế đứng, âm thanh và giọng đọc, vì lúc hít đất người chơi nhìn sàn. Né được thì rep kế tiếp thành <b>phản đòn ×2</b>; trúng đòn chỉ mất combo, không hồi máu boss.</p>
  <div class="table-wrap"><table>
    <thead><tr><th>Đòn của boss</th><th>Thế báo trước</th><th>Người chơi</th></tr></thead>
    <tbody>
      <tr><td>Đòn <b>bổ từ trên xuống</b> (nện, bổ nhào)</td><td>Vũ khí giơ cao trên đầu</td><td class="dodge">⏸ Giữ tay thẳng ≥ 0,8 s lúc chạm</td></tr>
      <tr><td>Đòn <b>quét ngang</b> (quét chân, gió chéo)</td><td>Vũ khí giấu thấp, kéo ngang</td><td class="dodge">💥 Một rep sâu, đáy rep rơi vào cửa sổ chạm</td></tr>
    </tbody>
  </table></div>
  <div class="table-wrap"><table>
    <thead><tr><th>Boss</th><th>Hành động</th><th>Cách hoá giải</th></tr></thead>
    <tbody>
      <tr class="peak"><td>Shuten-dōji</td><td>Nện đỉnh (thế jōdan)</td><td>⏸ giữ tay thẳng</td></tr>
      <tr><td></td><td>Quét chân ngựa (thế waki-gamae)</td><td>💥 rep sâu</td></tr>
      <tr><td></td><td>Uống rượu: hồi 10% máu trong 5 s</td><td>3 rep trong 5 s (chống gối 2) → vò vỡ, choáng 3 s, mọi đòn ×1,5</td></tr>
      <tr class="peak"><td>Sutoku (tengu)</td><td>Phong kesa: quạt gió chéo (thế hassō)</td><td>💥 rep sâu</td></tr>
      <tr><td></td><td>Thiên cẩu phi: bật lên, bổ quạt khi đáp</td><td>⏸ giữ tay thẳng</td></tr>
      <tr><td></td><td>Lời nguyền chép kinh (máu &lt; 60%): đòn ×0,75</td><td>Một rep chậm (xuống ≥ 2,5 s) → ấn cháy, rep đó ×2</td></tr>
    </tbody>
  </table></div>
  <p class="muted">Đã qua duyệt thiết kế lần 1 (18/10). Chưa xếp thành các màn của chương: còn chờ chia màn (level-spec) và chốt số máu bằng mô phỏng.</p>
</section>

<section>
  <div class="sec-head"><span class="eyebrow">Quy trình</span><h2>Bốn phòng đồ hoạ</h2></div>
  <ol class="flow">
    <li><b>Dựng hình</b><span>MPFB (oni) hoặc ảnh → Tripo AI (tengu). Bộ soát <code>--review</code> chụp cố định mặt, tay, chân, vũ khí, tự báo lỗi.</span></li>
    <li><b>Biên đạo</b><span>Mỗi đòn một file choreo: lấy đà → giữ thế báo trước → chạm → thu. Một nguồn cho Blender và Flutter.</span></li>
    <li><b>Mocap võ thật</b><span>Thân lấy từ mocap võ học, ghép bằng mô hình học chuyển động, retarget lên rig boss.</span></li>
    <li><b>Cổng soát chuyển động</b><span>Máy bắt chân lún, thân bật, vũ khí cắm đất trước khi cho xuất.</span></li>
    <li><b>Nướng → atlas</b><span>Khung dày quanh mốc chạm, nướng thành khoá Blender, xuất sprite WebP + track tư thế cho bản 2.5D.</span></li>
  </ol>
</section>

<section>
  <div class="sec-head"><span class="eyebrow">Mini-boss · kỳ công Izumo</span><h2>Shuten-dōji</h2></div>
  <p>Vua oni núi Ōe nghiện rượu, chuỳ kanabō gai sắt. Dựng người bằng MPFB qua 10 bản sửa theo ảnh tham khảo: thân dưới béo phì, da đỏ, lửa ma trơi, khoá đai mặt quỷ.</p>
  {fig(oni_still, "Shuten-dōji dáng đứng", "Ảnh duyệt dáng đứng.")}
  <h3>Hoạt ảnh trong game</h3>
  {anim_cards("shuten_doji", [("idle", "Đứng thở, chuỳ trên vai"), ("attack", "Nện đỉnh: giơ chuỳ jōdan, giữ thế, nện"),
                              ("attack2", "Quét chân ngựa: hạ thấp waki, quét ngang"), ("drink", "Cắm chuỳ, tu vò rượu"),
                              ("stagger", "Vò vỡ, sặc rượu, choáng"), ("defeat", "Gục")])}
  {video_pair([("build/videos/_web/shuten_doji_attack.mp4", "Video soát đòn nện đỉnh."),
               ("build/videos/_web/shuten_doji_attack2.mp4", "Video soát đòn quét chân ngựa.")])}
  {fig(oni_sheet, "Bộ ảnh soát oni", "Bộ ảnh soát cố định (--review): toàn thân, nghiêng, sau, chân, mặt, tay.")}
</section>

<section>
  <div class="sec-head"><span class="eyebrow">Boss · kỳ công Heian</span><h2>Thiên hoàng Sutoku hoá đại tengu</h2></div>
  <p>Mặt đỏ mũi dài, kimono xanh lá hoa tròn vàng, cánh đại bàng, quạt lông. Model sinh từ ảnh bằng Tripo AI (dáng chữ T, có texture); xương, ngón tay, mon vàng sau lưng do mình tự làm trong Blender.</p>
  {fig(tengu_still, "Tengu dáng đứng", "Ảnh soát toàn thân.")}
  <h3>Hoạt ảnh trong game</h3>
  {anim_cards("tengu_sutoku", [("idle", "Đứng thở, cánh khẽ nâng"), ("attack", "Phong kesa: quạt dựng hassō rồi chém chéo"),
                               ("attack2", "Thiên cẩu phi: bật lên, bổ quạt khi đáp"), ("write", "Cắn ngón, viết ấn nguyền"),
                               ("defeat", "Gục")])}
  {video_pair([("build/videos/_web/tengu_sutoku_attack.mp4", "Video soát Phong kesa."),
               ("build/videos/_web/tengu_sutoku_attack2.mp4", "Video soát Thiên cẩu phi.")])}
  {fig(tengu_sheet, "Bộ ảnh soát tengu", "Bộ ảnh soát cố định, có ảnh cận hai bàn tay và quạt.")}
</section>

<section id="gan-xuong">
  <div class="sec-head"><span class="eyebrow">Cần bạn chọn</span><h2>So sánh gắn xương: tự gắn hay Tripo Auto Rig</h2></div>
  <p>Cùng một model tengu của Tripo, hai bộ xương, cùng bảy dáng thử, cùng góc máy và ánh sáng. <b>A</b>: mình tự gắn (đọc khớp trên ảnh lưới, trọng số tính trên bản voxel kín, ngón tự tách từ lưới) — {ours_bones}. <b>B</b>: Tripo Studio Auto Rig — {tripo_bones}. Dáng bị cố ý đẩy xa hơn đòn trong game để lộ chỗ méo.</p>
  <p class="muted">Chế độ <b>đất sét</b> bỏ texture: lưới méo, xẹp, kéo thành màng hiện rõ hơn. Xem cả hai chế độ.</p>
  {"" if have_tripo else '<p class="muted"><b>Cột B đang chờ:</b> mở tengu_001 trong Tripo Studio → Auto Rig → gửi sang Blender → bấm “Gửi vào repo” (tab SPU) với tên <code>tengu_rig</code>.</p>'}
  <div class="rc-toolbar"><span class="muted">Xem:</span>
    <button type="button" data-view="tex" aria-pressed="true">Có texture</button>
    <button type="button" data-view="clay" aria-pressed="false">Đất sét</button></div>
  {rc_rows}
</section>

<section>
  <div class="sec-head"><span class="eyebrow">Tiếp theo</span><h2>Việc còn lại của chương 2</h2></div>
  <ul class="list">
    <li>Chia màn chương Nhật (level-spec), xếp hai boss vào kỳ công, chốt số máu bằng mô phỏng như test cân bằng chương 1.</li>
    <li>Âm báo riêng cho từng loại đòn (⏸ / 💥) để người nhìn sàn phân biệt được — điểm duyệt thiết kế còn treo.</li>
    <li>Chuỳ oni xuyên bụng ở vài khung đòn: thử gắn chuỳ vào xương riêng (cách lính đá chương 1).</li>
    <li>Chọn cách gắn xương cho boss sau theo kết quả so sánh ở trên.</li>
    <li>Kiểm tra giấy phép thương mại Tripo trước khi phát hành.</li>
  </ul>
</section>

<footer>Hoạt ảnh ghép từ chính các khung sprite trong game (assets/sprites). Sinh bằng tool/render/baocao_chuong2.py.</footer>
</div>
<script>{JS}</script>
"""
    open(OUT, "w", encoding="utf-8").write(html)
    print(f"{os.path.relpath(OUT, ROOT)}: {len(html) / 1e6:.1f} MB, cột Tripo: {'có' if have_tripo else 'chờ'}")


if __name__ == "__main__":
    main()
