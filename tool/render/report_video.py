"""Nhúng video (base64) vào một mục của baocao_dohoa.html — báo cáo luôn là một file.

    python tool/render/report_video.py <mục> <file.mp4>=<chú thích> [...]
    python tool/render/report_video.py mocap-1910 build/videos/shuten_doji_attack.mp4="Oni — Nện đỉnh"

<mục> là tên marker của mục (<!--<mục>-start--> … <!--<mục>-end-->). Video nén
lại 540p (crf 27, không tiếng, ~150–300 KB) rồi chèn thành khối lưới ngay trước
<!--<mục>-end-->; chạy lại thì thay khối cũ của mục đó. Cần imageio-ffmpeg (pip).
"""

import base64
import os
import re
import subprocess
import sys

import imageio_ffmpeg

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REPORT = os.path.join(ROOT, "baocao_dohoa.html")
H = 540


def shrink(src):
    tmp = os.path.join(ROOT, "build", "videos", "_web")
    os.makedirs(tmp, exist_ok=True)
    out = os.path.join(tmp, os.path.basename(src))
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error", "-i", src,
                    "-vf", f"scale=-2:{H}", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "27",
                    "-preset", "slow", "-an", "-movflags", "+faststart", out], check=True)
    return out


def figure(path, caption):
    b64 = base64.b64encode(open(shrink(path), "rb").read()).decode()
    print(f"{os.path.basename(path)}: {len(b64) * 3 // 4 // 1024} KB")
    # muted + playsinline: Safari iPhone mới cho tự phát / phát tại chỗ.
    return (f'<figure><video controls loop muted playsinline preload="metadata" '
            f'style="width:100%;border-radius:8px;border:1px solid var(--line);display:block" '
            f'src="data:video/mp4;base64,{b64}"></video><figcaption>{caption}</figcaption></figure>')


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    sec, items = sys.argv[1], [a.split("=", 1) for a in sys.argv[2:]]
    figs = "".join(figure(p if os.path.isabs(p) else os.path.join(ROOT, p), c) for p, c in items)
    start, end = f"<!--{sec}-video-start-->", f"<!--{sec}-video-end-->"
    block = (f'{start}\n<h3 style="font-size:16px;margin:18px 0 6px">Video</h3>\n'
             f'<div class="pair">{figs}</div>\n{end}\n')
    html = open(REPORT, encoding="utf-8").read()
    html = re.sub(re.escape(start) + r".*?" + re.escape(end) + r"\n", "", html, flags=re.S)
    marker = f"<!--{sec}-end-->"
    if html.count(marker) != 1:
        sys.exit(f"không thấy đúng một {marker} trong baocao_dohoa.html")
    open(REPORT, "w", encoding="utf-8", newline="").write(html.replace(marker, block + marker))
    print(f"baocao_dohoa.html: {os.path.getsize(REPORT) // 1024} KB")


main()
