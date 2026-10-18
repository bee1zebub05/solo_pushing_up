"""Bộ Kyokushin đầy đủ (Karate.zip, 1 411 file C3D ≈ 15 GB giải nén) → khung
xương chuẩn npz nhỏ, không giữ C3D thô.

    python tool/mocap/karate_prep.py          # song song theo số nhân CPU

Tải zip: https://ndownloader.figshare.com/files/24601187 (CC0) vào
art_src/mocap/_cache/karate/Karate.zip. Kết quả: _cache/karate_npz/<id>.npz
(segment.all_clips đọc thẳng).
"""

import os
import re
import sys
import tempfile
import zipfile
from multiprocessing import Pool

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from fetch import CACHE  # noqa: E402

ZIP = os.path.join(CACHE, "karate", "Karate.zip")
OUT = os.path.join(CACHE, "karate_npz")
PAT = re.compile(r"(B\d+)-(S\d+)-(E\d+)-(T\d+)\.c3d$", re.I)


def one(name):
    from skeleton import from_c3d
    mm = PAT.search(name)
    who, tech, cond, trial = (g.upper() for g in mm.groups())
    cid = f"k{who[1:]}{tech}{cond}{trial}"
    out = os.path.join(OUT, f"{cid}.npz")
    if os.path.exists(out):
        return cid, "có rồi"
    with zipfile.ZipFile(ZIP) as z, tempfile.TemporaryDirectory() as td:
        p = z.extract(name, td)
        try:
            m = from_c3d(p, meta={"clip": cid, "src": "kyokushin", "tech": tech, "cond": cond, "who": who})
        except Exception as e:
            return cid, f"lỗi {e!r}"[:80]
    m.save(out)
    return cid, f"{len(m) / m.fps:.1f}s"


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    os.makedirs(OUT, exist_ok=True)
    with zipfile.ZipFile(ZIP) as z:
        names = [i.filename for i in z.infolist() if PAT.search(i.filename)]
    print(f"{len(names)} file C3D")
    ok = bad = 0
    with Pool(max(1, (os.cpu_count() or 2) - 1)) as pool:
        for k, (cid, msg) in enumerate(pool.imap_unordered(one, names), 1):
            if msg.startswith("lỗi"):
                bad += 1
                print(cid, msg, flush=True)
            else:
                ok += 1
            if k % 100 == 0:
                print(f"{k}/{len(names)}", flush=True)
    print(f"xong: {ok} được, {bad} lỗi → {OUT}")


if __name__ == "__main__":
    main()
