"""Tải các clip võ học trong tool/mocap/manifest.json về bộ nhớ đệm.

    python tool/mocap/fetch.py            # tải những clip chưa có
    python tool/mocap/fetch.py --force    # tải lại hết

Dữ liệu thô (BVH CMU, ~0,5 MB/clip) nằm ở art_src/mocap/_cache/ — không
commit; manifest là nguồn để tải lại. Giấy phép: xem `_doc` trong manifest.
"""

import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
CACHE = os.path.join(ROOT, "art_src", "mocap", "_cache")


def manifest():
    with open(os.path.join(HERE, "manifest.json"), encoding="utf-8") as f:
        return json.load(f)


def clip_path(cid):
    return os.path.join(CACHE, f"{cid}.bvh")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    m = manifest()
    os.makedirs(CACHE, exist_ok=True)
    force = "--force" in sys.argv
    for c in m["clips"]:
        subj, trial = (int(x) for x in c["id"].split("_"))
        out = clip_path(c["id"])
        if os.path.exists(out) and not force:
            continue
        url = m["source"].format(subj=subj, trial=trial)
        with urllib.request.urlopen(url, timeout=60) as r:
            data = r.read()
        with open(out, "wb") as f:
            f.write(data)
        print(f"{c['id']:>7}  {len(data) / 1e6:5.2f} MB  {c['desc']}")
    print(f"xong: {len(m['clips'])} clip trong {CACHE}")


if __name__ == "__main__":
    main()
