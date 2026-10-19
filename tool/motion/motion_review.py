"""Bộ soát chuyển động tự động (phòng Chuyển động, rules/dohoa/chuyendong.md) — như
`--review` của phòng Dựng hình nhưng cho đòn đánh: chỉ đặt dáng + đo, KHÔNG render.

    bash tool/blender/render.sh <boss> --motion-review [--moves attack,attack2] [--frames 60]
    → build/blender/motion_review/<boss>/data.json + checks.txt, rồi
      tool/motion/motion_sheet.py vẽ sheet.png (render.sh tự gọi)

Kiểm từng đòn theo tiến độ 0–1 (thời gian thật: đòn dài ATTACK_S giây):
- **chân xuyên đất:** đỉnh lưới bàn chân (nhóm foot/ball) thấp hơn mặt đất > 2 cm;
  mặt đất = z 0, mặt hứng bóng render ra (đo theo dáng chờ thì sai khi chính dáng
  chờ lún — tengu lún 3,4 cm trước 19/10).
- **trượt chân:** đỉnh bàn chân chạm đất (≤ 3 cm) ở hai khung liền mà dịch ngang
  nhanh hơn 0,3 m/s (xoay trên mũi chân không tính: gót đã nhấc khỏi đất).
- **vũ khí xuyên thân / xuyên đất:** đỉnh vũ khí nằm trong lưới thân sâu hơn dáng
  chờ (đã duyệt) > 3 cm (bỏ vùng nắm quanh xương tay cầm), hoặc thấp hơn mặt đất > 3 cm.
- **khung giật:** gia tốc (sai phân bậc hai) của khớp chính vọt > 5× mức quanh
  nó và > 60 m/s²; quanh mốc `impact` ghi "có thể cố ý" (khựng lúc chạm).
- **về dáng chờ:** khung đầu/cuối đòn lệch dáng chờ > 3 cm (vào/ra đòn bị giật
  khi sân khấu nối với nhịp thở).

Khung liền nhau cùng lỗi gộp thành một đoạn. Đoạn CỐ Ý khai trong biên đạo
(`attacks.<đòn>.review`, tiến độ 0–1), ví dụ bước dậm trượt hay chuỳ nằm đất:
    "review": {"slide": [[0.40, 0.52]], "weapon_ground": [[0.60, 0.75]]}
→ cảnh báo trong đoạn đó ghi "(cố ý)" và không tính vào số cảnh báo.
"""
import json
import os
import re
import sys
import time

import bpy
import numpy as np

from boss_kit import ROOT
from human_kit import weights_by_group

ATTACK_S = 1.2  # độ dài đòn trên sân khấu (battle_stage.dart _attackLength)
JOINTS = ("pelvis", "spine_03", "head", "hand_l", "hand_r", "foot_l", "foot_r")
PEN_FOOT, CONTACT, SLIDE = 0.02, 0.03, 0.3
PEN_WEAPON, JERK_RATIO, JERK_MIN, HOME = 0.03, 5.0, 60.0, 0.03


class _Posed:
    """Lưới thân đã tạo dáng (tắt tạm modifier trừ xương để chỉ số đỉnh khớp nhóm
    đỉnh — subsurf/mask đổi số đỉnh), bỏ lưới phụ MPFB (HelperGeometry)."""

    def __init__(self, body):
        self.body = body
        w = weights_by_group(body)
        self.n = len(w)
        helper = np.array([wi.get("HelperGeometry", 0) >= 0.5 for wi in w])
        self.feet = {s: np.array([i for i, wi in enumerate(w)
                                  if wi.get(f"foot_{s}", 0) + wi.get(f"ball_{s}", 0) >= 0.5 and not helper[i]])
                     for s in "lr"}
        self.polys = [list(p.vertices) for p in body.data.polygons if not helper[list(p.vertices)].any()]

    def coords(self):
        subs = [m for m in self.body.modifiers if m.type != "ARMATURE" and m.show_viewport]
        for m in subs:
            m.show_viewport = False
        bpy.context.view_layer.update()
        ev = self.body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        me = ev.to_mesh()
        assert len(me.vertices) == self.n, "lưới thân đổi số đỉnh — modifier nào chưa tắt?"
        co = np.empty(self.n * 3)
        me.vertices.foreach_get("co", co)
        ev.to_mesh_clear()
        for m in subs:
            m.show_viewport = True
        mw = np.array(self.body.matrix_world)
        return co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]

    def tree(self, co):
        from mathutils.bvhtree import BVHTree
        return BVHTree.FromPolygons(co.tolist(), self.polys)


_RAYS = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]


def _inside(tree, p):
    """Điểm nằm trong lưới thân: ≥ 4/6 tia trục cắt lưới số lẻ lần. Pháp tuyến mặt gần
    nhất không đủ tin trên lưới Tripo (hở, cánh mỏng, chiều mặt không đều)."""
    from mathutils import Vector
    odd = 0
    for d in _RAYS:
        d = Vector(d)
        o, c = Vector(p), 0
        for _ in range(32):
            hit = tree.ray_cast(o, d)
            if hit[0] is None:
                break
            c += 1
            o = hit[0] + d * 1e-4
        odd += c % 2
    return odd >= 4


def _weapon_points(objs, cap=400):
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in objs:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        co = np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get("co", co)
        ev.to_mesh_clear()
        mw = np.array(o.matrix_world)
        pts.append(co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3])
    pts = np.concatenate(pts) if pts else np.zeros((0, 3))
    step = max(1, len(pts) // cap)
    return pts[::step]


def _bone(rig, name, t=0.0):
    pb = rig.pose.bones[name]
    return np.array(rig.matrix_world @ pb.head.lerp(pb.tail, t))


def _sample(motion, posed, rig, weapons, grip, **pose):
    motion.pose(**pose)
    bpy.context.view_layer.update()
    co = posed.coords()
    f = {"feet": {s: co[posed.feet[s]] for s in "lr"},
         "joints": {j: _bone(rig, j) for j in JOINTS if j in rig.pose.bones}}
    if weapons:
        wp = _weapon_points(weapons)
        f["joints"]["vũ khí"] = wp.mean(axis=0)
        g = _bone(rig, grip[0], 0.5)
        free = wp[np.linalg.norm(wp - g, axis=1) > grip[1]]
        tree = posed.tree(co)
        depth = 0.0
        for p in free:
            hit = tree.find_nearest(p.tolist())
            if hit[0] is not None and hit[3] > depth and (p - np.array(hit[0])).dot(np.array(hit[1])) < 0 \
                    and _inside(tree, p.tolist()):
                depth = hit[3]
        f["weapon_depth"], f["weapon_min_z"] = depth, float(wp[:, 2].min())
    return f


def _spec(choreo_id, move):
    """(events, review) của đòn trong biên đạo tool/motion/choreo/<id>.json."""
    path = os.path.join(ROOT, "tool", "motion", "choreo", f"{choreo_id}.json")
    try:
        m = json.load(open(path, encoding="utf-8"))["attacks"][move]
    except (OSError, KeyError):
        return {}, {}
    return m.get("events") or {}, m.get("review") or {}


INTENT = {"trượt chân": "slide", "vũ khí xuyên đất": "weapon_ground", "vũ khí xuyên thân": "weapon_body",
          "chân xuyên đất": "foot_ground", "khung giật": "jerk"}


def _runs(flags, n, review):
    """Gộp khung liền nhau cùng (loại, đối tượng) thành đoạn; đánh dấu đoạn cố ý."""
    out = []
    by = {}
    for f in flags:
        by.setdefault((f["kind"], f["who"]), []).append(f)
    for (kind, who), fs in by.items():
        fs.sort(key=lambda f: f["frame"])
        cur = [fs[0]]
        for f in fs[1:] + [None]:
            if f is not None and f["frame"] - cur[-1]["frame"] <= 1:
                cur.append(f)
                continue
            a, b = cur[0]["frame"] / (n - 1), cur[-1]["frame"] / (n - 1)
            wins = review.get(INTENT.get(kind, ""), [])
            intended = any(lo - 1e-6 <= a and b <= hi + 1e-6 for lo, hi in wins)
            out.append({"from": cur[0]["frame"], "to": cur[-1]["frame"], "kind": kind, "who": who,
                        "worst": max(x["value"] for x in cur), "unit": cur[0]["unit"], "intended": intended,
                        "note": cur[0].get("note", "")})
            if f is not None:
                cur = [f]
    # Cùng loại + cùng đoạn khung ở nhiều khớp (thân bật cả khối) → một dòng.
    merged = {}
    for r in out:
        k = (r["kind"], r["from"], r["to"], r["intended"])
        if k in merged:
            m = merged[k]
            m["who"] += ", " + r["who"]
            if r["worst"] > m["worst"]:
                m["worst"], m["note"] = r["worst"], r["note"]
        else:
            merged[k] = dict(r)
    return sorted(merged.values(), key=lambda r: (r["intended"], r["from"]))


def review_motion(motion, body, rig, name, choreo_id, weapons=(), grip=("hand_r", 0.15)):
    """Đo các đòn của [motion] (lớp tool/motion/<boss>_motion.py) và ghi báo cáo."""
    argv = sys.argv
    moves = argv[argv.index("--moves") + 1].split(",") if "--moves" in argv else ["attack", "attack2"]
    n = int(argv[argv.index("--frames") + 1]) if "--frames" in argv else 60
    objs = [o for o in bpy.data.objects if o.type == "MESH" and any(re.match(r, o.name) for r in weapons)]
    posed = _Posed(body)
    t0 = time.time()
    home = _sample(motion, posed, rig, objs, grip, t=0.0)
    ground = 0.0  # mặt hứng bóng (human_kit.shadow_catcher) = sàn người chơi thấy
    home_low = float(min(home["feet"][s][:, 2].min() for s in "lr"))
    dt = ATTACK_S / (n - 1)
    out = {"name": name, "ground": ground, "frames": n, "attack_s": ATTACK_S, "moves": {}}
    warn, intended = [], []
    for move in moves:
        ev, review = _spec(choreo_id, move)
        fr = [_sample(motion, posed, rig, objs, grip, move=move, phase=k / (n - 1)) for k in range(n)]
        m = {"events": ev, "review": review, "foot_min": {}, "slide": {}, "accel": {}, "flags": []}

        def flag(k, kind, who, value, unit, note=""):
            m["flags"].append({"frame": k, "phase": round(k / (n - 1), 3), "kind": kind, "who": who,
                               "value": round(float(value), 3), "unit": unit, "note": note})

        for s in "lr":
            zmin = [float(f["feet"][s][:, 2].min() - ground) for f in fr]
            m["foot_min"][s] = zmin
            for k, z in enumerate(zmin):
                if z < -PEN_FOOT:
                    flag(k, "chân xuyên đất", f"chân {s}", -z * 100, "cm")
            sp = [0.0]
            for k in range(1, n):
                a, b = fr[k - 1]["feet"][s], fr[k]["feet"][s]
                # Chạm đất = sát mặt đất (đỉnh lún dưới đất đã có cảnh báo "chân xuyên đất").
                za, zb = a[:, 2] - ground, b[:, 2] - ground
                both = (za <= CONTACT) & (zb <= CONTACT) & (za >= -PEN_FOOT) & (zb >= -PEN_FOOT)
                v = float(np.median(np.linalg.norm((b - a)[both][:, :2], axis=1)) / dt) if both.sum() >= 8 else 0.0
                sp.append(v)
                if v > SLIDE:
                    flag(k, "trượt chân", f"chân {s}", v, "m/s")
            m["slide"][s] = sp
        if objs:
            m["weapon_depth"] = [f["weapon_depth"] for f in fr]
            m["weapon_min_z"] = [f["weapon_min_z"] - ground for f in fr]
            for k, f in enumerate(fr):
                if f["weapon_depth"] > home.get("weapon_depth", 0.0) + PEN_WEAPON:
                    flag(k, "vũ khí xuyên thân", "vũ khí", f["weapon_depth"] * 100, "cm")
                if f["weapon_min_z"] - ground < -PEN_WEAPON:
                    flag(k, "vũ khí xuyên đất", "vũ khí", (ground - f["weapon_min_z"]) * 100, "cm")
        impact = ev.get("impact")
        for j in fr[0]["joints"]:
            p = np.array([f["joints"][j] for f in fr])
            acc = np.zeros(n)
            acc[1:-1] = np.linalg.norm(p[2:] - 2 * p[1:-1] + p[:-2], axis=1) / dt ** 2
            m["accel"][j] = acc.tolist()
            for k in range(1, n - 1):
                around = np.concatenate([acc[max(1, k - 4):k], acc[k + 1:min(n - 1, k + 5)]])
                base = float(np.median(around)) if len(around) else 0.0
                if acc[k] > JERK_MIN and acc[k] > JERK_RATIO * max(base, 1e-6):
                    near = impact is not None and abs(k / (n - 1) - impact) <= 0.06
                    flag(k, "khung giật", j, acc[k], "m/s²",
                         "quanh mốc chạm, có thể cố ý" if near else f"gấp {acc[k] / max(base, 1e-6):.0f}× quanh nó")
        if move != "defeat":
            for k in (0, n - 1):
                for j, hp in home["joints"].items():
                    d = float(np.linalg.norm(fr[k]["joints"][j] - hp))
                    if d > HOME:
                        flag(k, "lệch dáng chờ", j, d * 100, "cm", "đầu đòn" if k == 0 else "cuối đòn")
        m["runs"] = _runs(m["flags"], n, review)
        out["moves"][move] = m
        for r in m["runs"]:
            span = f"khung {r['from']:02d}" + (f"–{r['to']:02d}" if r["to"] > r["from"] else "")
            ph = f"{r['from'] / (n - 1):.2f}" + (f"–{r['to'] / (n - 1):.2f}" if r["to"] > r["from"] else "")
            line = (f"[{move} {span} · {ph}] {r['kind']} · {r['who']}: tệ nhất {r['worst']:g} {r['unit']}"
                    + (f" ({r['note']})" if r["note"] else ""))
            (intended if r["intended"] else warn).append(line + (" (cố ý)" if r["intended"] else ""))
    d = os.path.join(ROOT, "build", "blender", "motion_review", name)
    os.makedirs(d, exist_ok=True)
    json.dump(out, open(os.path.join(d, "data.json"), "w", encoding="utf-8"), ensure_ascii=False)
    head = [f"{name}: {len(moves)} đòn × {n} khung, {time.time() - t0:.0f} s; đáy chân dáng chờ {home_low * 100:+.1f} cm so với sàn",
            f"{len(warn)} đoạn cảnh báo, {len(intended)} đoạn cố ý theo biên đạo"]
    open(os.path.join(d, "checks.txt"), "w", encoding="utf-8").write("\n".join(head + warn + intended) + "\n")
    print("\n".join(head + warn[:40]))
