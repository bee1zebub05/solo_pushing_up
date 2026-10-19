"""Tự cắt đòn trong clip võ học: lấy đà → chạm → thu (rules/dohoa/chuyendong.md).

Đòn = đỉnh tốc độ một chi (cổ tay / mắt cá) mà chi đó duỗi xa thân ngay sau
đỉnh. Chạm = lúc duỗi xa nhất quanh đỉnh; lấy đà = lùi tới chỗ chi gần đứng
yên (hoặc lúc rút về sau xa nhất); thu = tiến tới chỗ chi đứng yên lại.

    python tool/motion/mocap/segment.py                 # cắt mọi clip trong manifest → thư viện đòn
    python tool/motion/mocap/segment.py 135_07 --sheet  # soát một clip: in đòn + tấm người que

Thư viện: art_src/mocap/_cache/strikes/<id>.npz + index.json (sinh lại được).
Mỗi đòn chuẩn hoá: hướng đòn (chi bay về đâu lúc chạm) = +X — sân khấu nhìn
ngang, đối thủ luôn ở phía +X, kể cả đá ngang (thân quay nghiêng, chân ra +X).
"""

import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from fetch import CACHE, clip_path, manifest  # noqa: E402
from skeleton import J, Motion, from_bvh  # noqa: E402

FPS = 60
LIMBS = {"wrist_r": ("shoulder_r", "hand"), "wrist_l": ("shoulder_l", "hand"),
         "ankle_r": ("hip_r", "foot"), "ankle_l": ("hip_l", "foot")}
MIN_SPEED = {"hand": 2.6, "foot": 2.6}  # m/s đỉnh (người 1,75 m) — dưới mức này là cử động thường
LIB = os.path.join(CACHE, "strikes")


def drop_tpose(m):
    """Bỏ đoạn T-pose đầu clip CMU (hai cổ tay ngang vai, dang rộng)."""
    w = np.linalg.norm(m.joint("wrist_l")[:, :2] - m.joint("wrist_r")[:, :2], axis=1)
    hw = (np.abs(m.joint("wrist_l")[:, 2] - m.joint("shoulder_l")[:, 2]) < 0.12) & (w > 1.2)
    k = 0
    while k < len(m) and hw[k]:
        k += 1
    # cộng thêm ~0,5 s rời thế T
    return m.slice(min(len(m) - 1, k + (int(0.5 * m.fps) if k else 0)), len(m))


def speed(x, fps):
    v = np.gradient(x, axis=0) * fps
    return np.linalg.norm(v, axis=1)


def find_strikes(m):
    out = []
    pel = m.joint("pelvis")
    for eff, (root, kind) in LIMBS.items():
        p = m.joint(eff)
        # Tốc độ so với hông: bỏ phần cả người lướt đi (bước, xoay người).
        rel = p - pel
        sp = speed(rel, m.fps) * 0.6 + speed(p, m.fps) * 0.4
        ext = np.linalg.norm(p - m.joint(root), axis=1)
        # Chiều dài chi của chính người diễn (tỉ lệ CMU chân dài hơn người thường).
        mid = {"wrist_r": "elbow_r", "wrist_l": "elbow_l", "ankle_r": "knee_r", "ankle_l": "knee_l"}[eff]
        limb = float(np.median(np.linalg.norm(m.joint(root) - m.joint(mid), axis=1)
                               + np.linalg.norm(m.joint(mid) - p, axis=1)))
        if kind == "foot":
            # Bước chân không phải đòn: đá thì mắt cá phải lên ≥ 0,45 m (ngang gối).
            ext = np.where(p[:, 2] < 0.45, 0.0, ext)
        thr = MIN_SPEED[kind]
        k = 1
        while k < len(m) - 1:
            if sp[k] >= thr and sp[k] >= sp[k - 1] and sp[k] >= sp[k + 1]:
                # Chạm = duỗi xa nhất trong [đỉnh − 0,05 s, đỉnh + 0,2 s].
                a, b = max(0, k - int(0.05 * m.fps)), min(len(m), k + int(0.2 * m.fps))
                c = a + int(np.argmax(ext[a:b]))
                # Lấy đà: lùi tới khi tốc độ < 20% đỉnh và đang giảm dần về trước (tối đa 0,9 s).
                s = k
                lo = max(0, k - int(0.9 * m.fps))
                while s > lo and not (sp[s] < 0.2 * sp[k] and sp[s - 1] >= sp[s]):
                    s -= 1
                # Thu: chi rút về ≥ 60% quãng đã duỗi rồi chậm lại (khung chạm thì
                # tốc độ ~0 nên không thể dừng ngay ở đó).
                hi = min(len(m) - 1, c + int(1.0 * m.fps))
                e0 = ext[s] if ext[s] > 0 else ext[c] * 0.6
                back = ext[c] - 0.6 * (ext[c] - e0)
                e = c + 1
                while e < hi and ext[e] > back and ext[e] > 0:
                    e += 1
                while e < hi and not (sp[e] < 0.25 * sp[k] and sp[e + 1] >= sp[e]):
                    e += 1
                reach = ext[c] / limb
                if reach > 0.8 and ext[c] > 0:  # duỗi gần thẳng — đòn ra, không phải co tay về
                    out.append({"eff": eff, "kind": kind, "start": s, "contact": c, "end": e, "peak": float(sp[k]),
                                "reach": float(reach)})
                    k = max(e, c + int(0.15 * m.fps))  # bỏ cú thu chân/tay về
                else:
                    k = c + int(0.15 * m.fps)
            else:
                k += 1
    # Một đòn mỗi 0,3 s: giữ đòn mạnh nhất (tay đấm thì chân cũng khẽ nhích).
    out.sort(key=lambda s: -s["peak"])
    keep = []
    for s in out:
        if all(abs(s["contact"] - q["contact"]) > 0.3 * m.fps for q in keep):
            keep.append(s)
    return sorted(keep, key=lambda s: s["contact"])


def describe(m, s):
    """Đặc trưng đòn để mô hình/biên đạo chọn: độ cao chạm, hướng, độ xoay người."""
    c = s["contact"]
    p = m.pos[c, J[s["eff"]]]
    d = p - m.pos[s["start"], J[s["eff"]]]
    hgt = p[2] / 1.75
    level = "jodan" if hgt > 0.78 else ("chudan" if hgt > 0.5 else "gedan")
    horiz = np.linalg.norm(d[:2])
    arc = "down" if d[2] < -0.6 * horiz else ("up" if d[2] > 0.8 * horiz else "thrust")
    path = m.pos[s["start"]:c + 1, J[s["eff"]]]
    straight = np.linalg.norm(path[-1] - path[0]) / max(1e-6, np.sum(np.linalg.norm(np.diff(path, axis=0), axis=1)))
    if straight < 0.75 and arc == "thrust":
        arc = "swing"
    return {"level": level, "arc": arc, "straight": float(straight), "windup": (c - s["start"]) / m.fps,
            "recover": (s["end"] - c) / m.fps}


def normalize(m, s, pre=0.25, post=0.35):
    """Cắt [lấy đà − pre, thu + post] và xoay sao cho chi bay về +X lúc chạm;
    gốc = hông lúc bắt đầu chiếu xuống đất."""
    a = max(0, s["start"] - int(pre * m.fps))
    b = min(len(m), s["end"] + int(post * m.fps))
    pos = m.pos[a:b].copy()
    c = s["contact"] - a
    e = J[s["eff"]]
    root = J[LIMBS[s["eff"]][0]]
    d = pos[c, e, :2] - pos[c, J["pelvis"], :2]
    if np.linalg.norm(d) < 0.15:  # đòn đi xuống sát thân: dùng hướng mặt
        d = pos[c, e, :2] - pos[c, root, :2]
    ang = np.arctan2(d[1], d[0])
    cs, sn = np.cos(-ang), np.sin(-ang)
    R = np.array([[cs, -sn, 0], [sn, cs, 0], [0, 0, 1]])
    pos = pos @ R.T
    o = pos[0, J["pelvis"]].copy()
    o[2] = 0
    pos -= o
    seg = Motion(pos, m.fps, dict(m.meta))
    seg.meta.update(eff=s["eff"], kind=s["kind"], start=s["start"] - a, contact=c, end=s["end"] - a)
    return seg


KARATE = os.path.join(CACHE, "karate")
# Bộ Kyokushin (figshare 10.6084/m9.figshare.c.4981073, CC0): S = kỹ thuật, E = điều kiện.
KARATE_TECH = {"S01": ("gyaku-zuki", ["karate", "punch"]), "S02": ("mae-geri", ["karate", "kick"]),
               "S03": ("mawashi-geri gedan", ["karate", "kick"]), "S04": ("mawashi-geri jodan", ["karate", "kick"]),
               "S05": ("ushiro-mawashi-geri", ["karate", "kick", "spin"])}
KARATE_COND = {"E01": "air", "E02": "shield", "E03": "shield", "E04": "opponent"}


def karate_clips():
    """(id, đường dẫn c3d, nhãn, mô tả) mọi file karate đã giải nén."""
    import glob
    import re
    out = []
    for p in sorted(glob.glob(os.path.join(KARATE, "**", "*.c3d"), recursive=True)):
        mm = re.search(r"(B\d+)-(S\d+)-(E\d+)-(T\d+)\.c3d$", p)
        if not mm or mm.group(2) not in KARATE_TECH:
            continue
        who, tech, cond, trial = mm.groups()
        name, tags = KARATE_TECH[tech]
        cid = f"k{who[1:]}{tech}{cond}{trial}"
        out.append((cid, p, tags + [KARATE_COND.get(cond, cond)], f"{name} ({KARATE_COND.get(cond, cond)}, {who})"))
    return out


def all_clips():
    """Mọi clip nguồn: (id, hàm nạp Motion, nhãn, mô tả)."""
    from skeleton import from_c3d
    out = [(c["id"], (lambda p=clip_path(c["id"]), c=c: from_bvh(p, meta={"clip": c["id"], "tags": c["tags"], "src": "cmu"})),
            c["tags"], c["desc"]) for c in manifest()["clips"]]
    npz = os.path.join(CACHE, "karate_npz")
    if os.path.isdir(npz) and os.listdir(npz):  # bộ đầy đủ đã chuyển (karate_prep.py)
        import glob
        for p in sorted(glob.glob(os.path.join(npz, "*.npz"))):
            cid = os.path.basename(p)[:-4]
            tech, cond = cid[5:8], cid[8:11]
            name, tags = KARATE_TECH.get(tech, (tech, ["karate"]))
            tags = tags + [KARATE_COND.get(cond, cond)]

            def load(p=p, cid=cid, tags=tags):
                m = Motion.load(p)
                m.meta.update(clip=cid, tags=tags, src="kyokushin")
                return m
            out.append((cid, load, tags, f"{name} ({KARATE_COND.get(cond, cond)}, B{cid[1:5]})"))
        return out
    for cid, p, tags, desc in karate_clips():
        out.append((cid, (lambda p=p, cid=cid, tags=tags: from_c3d(p, meta={"clip": cid, "tags": tags, "src": "kyokushin"})),
                    tags, desc))
    return out


def build_library(ids=None, verbose=True):
    os.makedirs(LIB, exist_ok=True)
    index = []
    for cid, load, tags, desc in all_clips():
        clip = {"id": cid, "tags": tags, "desc": desc}
        if ids and clip["id"] not in ids:
            continue
        try:
            m = load()
        except Exception as e:  # file hỏng / thiếu marker
            print(f"{cid}: bỏ qua ({e!r})"[:120])
            continue
        m = drop_tpose(m).resample(FPS).smooth(0.06)
        strikes = [s for s in find_strikes(m) if s["peak"] >= 3.2]
        for n, s in enumerate(strikes):
            seg = normalize(m, s)
            sid = f"{clip['id']}_{n:02d}"
            seg.meta.update(describe(m, s), id=sid, peak=s["peak"], reach=s["reach"], at=s["contact"] / FPS)
            seg.save(os.path.join(LIB, f"{sid}.npz"))
            index.append({k: (round(v, 3) if isinstance(v, float) else v) for k, v in seg.meta.items()})
        if verbose:
            kinds = {}
            for s in strikes:
                kinds[s["eff"]] = kinds.get(s["eff"], 0) + 1
            print(f"{clip['id']:>7} {len(m) / FPS:6.1f}s  {len(strikes):3d} đòn {kinds}  ({clip['desc']})")
    with open(os.path.join(LIB, "index.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=0)
    return index


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--sheet" in sys.argv and args:
        from preview import sheet
        m = from_bvh(clip_path(args[0]))
        m = drop_tpose(m).resample(FPS).smooth(0.06)
        strikes = find_strikes(m)
        for s in strikes:
            d = describe(m, s)
            print(f"{s['eff']:8} {s['start'] / FPS:6.2f} → {s['contact'] / FPS:6.2f} → {s['end'] / FPS:6.2f}s"
                  f"  đỉnh {s['peak']:4.1f} m/s  duỗi {s['reach']:.2f}  {d['level']:6} {d['arc']:6}"
                  f"  đà {d['windup']:.2f}s thu {d['recover']:.2f}s")
        out = args[1] if len(args) > 1 else f"{args[0]}_strikes.png"
        if strikes:
            from PIL import Image
            rows = []
            for s in strikes[:8]:
                seg = normalize(m, s)
                c = seg.meta
                rows.append(sheet(seg, 0, (len(seg) - 1) / seg.fps, 8, cols=8, size=180))
            im = Image.new("RGB", (rows[0].width, sum(r.height for r in rows)), "white")
            y = 0
            for r in rows:
                im.paste(r, (0, y))
                y += r.height
            im.save(out)
        return
    idx = build_library(args or None)
    print(f"thư viện: {len(idx)} đòn → {LIB}")


if __name__ == "__main__":
    main()
