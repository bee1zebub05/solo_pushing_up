"""Ghép video soát đòn đánh từ khung Blender (`render.sh <boss> --video`).

    python tool/boss_video.py            # mọi boss có khung → build/videos/<boss>_<đòn>.mp4

Mỗi video: đứng chờ → tốc độ thật trong trận (đòn 1,2 s) → chiếu chậm 0,5×,
có tên đòn (lấy từ biên đạo tool/blender/choreo/<id>.json), nhãn pha
(lấy đà / ra đòn / thu về theo AttackPose) và thanh tiến độ đánh dấu mốc chạm.
Cần imageio-ffmpeg (pip) — ffmpeg đi kèm gói đó.
"""

import glob
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FPS = 25
ATTACK_S = 1.2  # độ dài đòn trên sân khấu (battle_stage.dart _attackLength)
H = 720
BOSSES = {  # thư mục khung → id biên đạo, tên hiển thị
    "oni": ("shuten_doji", "Shuten-dōji"),
    "tengu": ("tengu_sutoku", "Tengu Sutoku"),
}
PHASES = [(0.0, 0.5, "Lấy đà", (110, 140, 200)), (0.5, 0.65, "Ra đòn", (220, 70, 60)),
          (0.65, 1.0, "Thu về", (110, 170, 110))]


def font(size, bold=False):
    for f in ((r"C:\Windows\Fonts\segoeuib.ttf",) if bold else ()) + (r"C:\Windows\Fonts\segoeui.ttf",):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            pass
    return ImageFont.load_default()


def background(w, h):
    bg = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(bg)
    for y in range(h):
        t = y / h
        d.line([(0, y), (w, y)], fill=(int(214 - 40 * t), int(208 - 40 * t), int(202 - 36 * t)))
    return bg


_masks = {}


def _edge_mask(size, edge=70):
    if size not in _masks:
        w, h = size
        m = Image.new("L", size, 0)
        d = ImageDraw.Draw(m)
        for i in range(edge):
            v = round(255 * (i / edge) ** 1.5)
            d.rectangle([i, i, w - 1 - i, h - 1 - i], outline=v)
        d.rectangle([edge, edge, w - 1 - edge, h - 1 - edge], fill=255)
        _masks[size] = m
    return _masks[size]


def compose(frame, phase, title, speed, impact, bg):
    W, Hh = bg.size
    im = Image.open(frame).convert("RGBA")
    k = (Hh - 120) / im.height
    im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    # Shadow catcher phủ alpha nhẹ lên cả sàn: mờ dần ở mép để khung không lộ thành hình chữ nhật.
    # Chỉ làm mờ lớp bóng sàn gần trong suốt (alpha thấp), giữ nguyên nhân vật.
    a = im.getchannel("A")
    faded = Image.composite(a, Image.new("L", im.size, 0), _edge_mask(im.size))
    im.putalpha(Image.composite(a, faded, a.point(lambda x: 255 if x > 90 else 0)))
    out = bg.copy().convert("RGBA")
    out.alpha_composite(im, ((W - im.width) // 2, 30))
    d = ImageDraw.Draw(out)
    d.text((28, 18), title, fill=(30, 26, 24), font=font(34, True))
    d.text((W - 28, 22), speed, fill=(60, 52, 48), font=font(26), anchor="ra")
    # Thanh tiến độ: ba pha, mốc chạm, đầu đọc.
    x0, x1, y = 60, W - 60, Hh - 52
    for a, b, name, col in PHASES:
        d.rectangle([x0 + (x1 - x0) * a, y, x0 + (x1 - x0) * b, y + 12], fill=col)
        d.text((x0 + (x1 - x0) * (a + b) / 2, y + 18), name, fill=(40, 36, 34), font=font(20), anchor="ma")
    xi = x0 + (x1 - x0) * impact
    d.polygon([(xi - 7, y - 12), (xi + 7, y - 12), (xi, y - 1)], fill=(30, 26, 24))
    d.text((xi, y - 14), "chạm", fill=(30, 26, 24), font=font(18), anchor="md")
    if phase is not None:
        xp = x0 + (x1 - x0) * phase
        d.rectangle([xp - 2, y - 4, xp + 2, y + 16], fill=(255, 255, 255))
        cur = next((n for a, b, n, _ in PHASES if a <= phase <= b), "")
        d.text((28, 62), cur, fill=next(c for a, b, n, c in PHASES if n == cur), font=font(30, True))
    else:
        d.text((28, 62), "Đứng chờ", fill=(80, 72, 68), font=font(30, True))
    return out.convert("RGB")


def build(folder, choreo_id, boss_name, move):
    frames = sorted(glob.glob(os.path.join(folder, "f_*.png")))
    if not frames:
        return None
    spec = json.load(open(os.path.join(ROOT, "tool", "blender", "choreo", f"{choreo_id}.json"), encoding="utf-8"))
    m = spec["attacks"][move]
    title = f"{boss_name} — {m['_name'].split('—')[0].strip()}"
    impact = m.get("events", {}).get("impact", 0.62)
    n = len(frames)
    probe = Image.open(frames[0])
    w = round(probe.width * (H - 120) / probe.height) + 80
    w = max(w, 960) // 2 * 2
    bg = background(w, H)
    tmp = os.path.join(ROOT, "build", "videos", "_tmp", f"{choreo_id}_{move}")
    os.makedirs(tmp, exist_ok=True)
    for f in glob.glob(os.path.join(tmp, "*.png")):
        os.remove(f)
    seq = [(frames[0], None, "")] * round(0.6 * FPS)
    real = round(ATTACK_S * FPS)
    for i in range(real):
        ph = i / (real - 1)
        seq.append((frames[round(ph * (n - 1))], ph, "Tốc độ thật"))
    seq += [(frames[-1], 1.0, "Tốc độ thật")] * round(0.5 * FPS)
    slow = round(ATTACK_S * FPS / 0.5)
    for i in range(slow):
        ph = i / (slow - 1)
        seq.append((frames[round(ph * (n - 1))], ph, "Chậm 0,5×"))
    seq += [(frames[-1], 1.0, "Chậm 0,5×")] * round(0.8 * FPS)
    for i, (f, ph, sp) in enumerate(seq):
        compose(f, ph, title, sp, impact, bg).save(os.path.join(tmp, f"{i:04d}.png"))
    import imageio_ffmpeg
    out = os.path.join(ROOT, "build", "videos", f"{choreo_id}_{move}.mp4")
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error", "-framerate", str(FPS),
                    "-i", os.path.join(tmp, "%04d.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p",
                    "-crf", "20", "-movflags", "+faststart", out], check=True)
    return out


for folder, (cid, name) in BOSSES.items():
    for move in ("attack", "attack2"):
        path = build(os.path.join(ROOT, "build", "blender", folder, "video", move), cid, name, move)
        if path:
            print(f"{os.path.relpath(path, ROOT)}: {os.path.getsize(path) // 1024} KB")
