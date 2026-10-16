"""Bộ soát nhân vật Blender trước khi đưa người dùng xem (rules/dohoa.md mục 11).

Mọi script boss hình người gọi `review(...)` khi chạy với cờ `--review`:

    bash tool/blender/render.sh oni_boss --review          # (+ --quick: ít mẫu hơn)

Ra `build/blender/review/<script>/`: từng ảnh soát, `manifest.json`, `checks.txt`;
render.sh ghép thành `sheet.png` (tool/blender/review_sheet.py, có nhãn + cảnh báo).

Bộ ảnh cố định: toàn thân góc game · nghiêng trần (ẩn quần áo) · nghiêng mặc đồ ·
sau lưng · bàn chân (trước + trên xuống) · mặt · hai bàn tay · cận từng phụ kiện
quan trọng. Kiểm tra tự động (in cảnh báo, không sửa gì):
- phụ kiện quan trọng bị che bao nhiêu % nhìn từ góc game (tia từ máy quay);
- đồ gắn chìm vào da (giáp nhỏ hơn tay béo, khoá lún vào bụng);
- da xuyên qua vải;
- đồ gắn lơ lửng không chạm thân / đồ khác (khoá đai, vuốt, mặt dây);
- lưới kín có pháp tuyến ngược (mép trông mờ như kính);
- bảng tỉ lệ thân (chân tới khớp háng/chiều cao, hông/vai, bụng/mông nhô) so với [targets].
"""

import json
import math
import os
import re

import bpy
from mathutils import Euler, Vector
from mathutils.bvhtree import BVHTree

from boss_kit import ROOT, render_to

UP = Vector((0, 0, 1))
# Lưới mắt phụ MPFB (iris/eye helper) nằm sẵn trong hốc mắt — không phải đồ chìm.
ALWAYS_EMBEDDED = [r"(?i)irishelper"]


# ---------------------------------------------------------------- hình học


def _eval_world(obj, limit=None):
    """Đỉnh thế giới + mặt của lưới đã đánh giá (xương, modifier). Không dùng
    bmesh.from_mesh/from_object: thân MPFB có shape key làm Blender sập."""
    # Modifier đánh giá theo cài đặt viewport: Mask MPFB (ẩn lưới phụ) có thể
    # chỉ bật khi render → bật tạm theo show_render cho khớp ảnh thật.
    saved = [(m, m.show_viewport) for m in obj.modifiers]
    for m, _ in saved:
        m.show_viewport = m.show_render
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    mw = obj.matrix_world
    verts = [mw @ v.co for v in me.vertices]
    polys = [tuple(p.vertices) for p in me.polygons]
    ev.to_mesh_clear()
    for m, v in saved:
        m.show_viewport = v
    if saved:
        bpy.context.view_layer.update()
    if limit and len(verts) > limit:
        step = len(verts) / limit
        sample = [verts[int(i * step)] for i in range(limit)]
    else:
        sample = verts
    return verts, polys, sample


def _matches(obj, patterns):
    return any(re.search(p, obj.name) for p in patterns)


def _meshes(patterns):
    return [o for o in bpy.data.objects if o.type in ("MESH", "CURVE", "FONT") and _matches(o, patterns)
            and not o.hide_render]


def _yaw_for(d):
    """Góc yaw máy quay (human_kit.camera) để nhìn theo hướng ngang [d]."""
    return math.degrees(math.atan2(-d.x, d.y))


def _frame(scene, pts, yaw, pitch, px=520, pad=0.12, min_size=0.0, clip_above=None):
    """Máy quay trực giao nhìn theo (yaw, pitch), khung ôm vừa [pts] (thế giới)."""
    rot = Euler((math.radians(90 - pitch), 0, math.radians(yaw)))
    m = rot.to_matrix()
    right, upv, fwd = m @ Vector((1, 0, 0)), m @ Vector((0, 1, 0)), m @ Vector((0, 0, -1))
    xs = [p.dot(right) for p in pts]
    ys = [p.dot(upv) for p in pts]
    w = max(max(xs) - min(xs), min_size) * (1 + 2 * pad)
    h = max(max(ys) - min(ys), min_size) * (1 + 2 * pad)
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    depth = sum(p.dot(fwd) for p in pts) / len(pts)
    center = right * cx + upv * cy + fwd * depth
    data = bpy.data.cameras.new("ReviewCam")
    data.type = "ORTHO"
    data.ortho_scale = max(w, h)
    data.clip_end = 80
    cam = bpy.data.objects.new("ReviewCam", data)
    scene.collection.objects.link(cam)
    cam.rotation_euler = rot
    cam.location = center - fwd * 30
    if clip_above is not None and fwd.z < -0.3:  # nhìn từ trên: cắt bỏ mọi thứ cao hơn clip_above (bụng che chân)
        data.clip_start = max(0.1, (cam.location.z - clip_above) / -fwd.z)
    scene.camera = cam
    k = px / max(w, h)
    scene.render.resolution_x = max(64, round(w * k))
    scene.render.resolution_y = max(64, round(h * k))
    bpy.context.view_layer.update()
    return cam, fwd


# ---------------------------------------------------------------- kiểm tra


def _inside_fraction(tree, pts, tol):
    """Tỉ lệ điểm nằm trong thân (dưới mặt da quá [tol] m)."""
    n = 0
    for p in pts:
        hit, nrm, _, _ = tree.find_nearest(p)
        if hit is not None and (p - hit).dot(nrm) < -tol:
            n += 1
    return n / max(1, len(pts))


def _segments(rig):
    """Đoạn thế giới (tên, đầu, đuôi) của mọi xương biến dạng trong dáng hiện tại."""
    mw = rig.matrix_world
    return [(b.name, mw @ b.head, mw @ b.tail) for b in rig.pose.bones if b.bone.use_deform]


def _nearest_bone(segs, p):
    def d(seg):
        _, a, b = seg
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
        return (p - (a + ab * t)).length

    return min(segs, key=d)[0]


def _sunk_split(tree, pts, tol, rig, segs, own):
    """Tỉ lệ điểm chìm dưới da quá [tol], tách hai loại: chìm vào chính chi
    vật bám ([own]: tên xương cha + xương kề) — vòng nhỏ hơn bắp tay, lộ đứt
    quãng = lỗi; và ép vào phần thân khác (tay béo áp sườn, cằm chạm ngực) =
    chỗ tiếp xúc, tự nhiên."""
    mine = other = 0
    bones = {}
    for p in pts:
        hit, nrm, _, _ = tree.find_nearest(p)
        if hit is None or (p - hit).dot(nrm) >= -tol:
            continue
        b = _nearest_bone(segs, hit)
        bones[b] = bones.get(b, 0) + 1
        if b in own:
            mine += 1
        else:
            other += 1
    n = max(1, len(pts))
    return mine / n, other / n, bones


def _signed_volume(obj):
    """Thể tích có dấu của lưới gốc (âm = pháp tuyến quay vào trong) nếu lưới
    kín (mọi cạnh thuộc đúng 2 mặt); None nếu lưới hở."""
    me = obj.data
    if not hasattr(me, "polygons") or not me.polygons:
        return None
    count = {}
    for p in me.polygons:
        for e in p.edge_keys:
            count[e] = count.get(e, 0) + 1
    if any(c != 2 for c in count.values()):
        return None
    vs = [v.co for v in me.vertices]
    vol = 0.0
    for p in me.polygons:
        idx = list(p.vertices)
        a = vs[idx[0]]
        for i in range(1, len(idx) - 1):
            vol += a.dot(vs[idx[i]].cross(vs[idx[i + 1]])) / 6
    return vol


def _proportions(verts, rig, fwd, S):
    mw = rig.matrix_world
    pb = rig.pose.bones
    zs = [p.z for p in verts]
    floor, top = min(zs), max(zs)
    H = top - floor
    side = fwd.cross(UP).normalized()
    pelvis = mw @ pb["pelvis"].head
    sh_z = (mw @ pb["clavicle_l"].head).z

    def band(z, half=0.03 * S):
        return [p for p in verts if abs(p.z - z) < half]

    def width(z):
        b = band(z)
        return (max(p.dot(side) for p in b) - min(p.dot(side) for p in b)) if b else 0.0

    hip_z = pelvis.z - 0.06 * S
    # Hông: dải da quanh trục xương chậu (bỏ tay buông ngang hông).
    near = [p for p in band(hip_z) if ((p - pelvis) - UP * (p - pelvis).dot(UP)).length < 0.45 * S]
    hip = (max(p.dot(side) for p in near) - min(p.dot(side) for p in near)) if near else 0.0
    # Vai: khoảng cách hai khớp vai (đầu xương cánh tay), không lẫn cánh tay.
    sh = abs((mw @ pb["upperarm_l"].head - mw @ pb["upperarm_r"].head).dot(side))
    torso = [p for p in verts if pelvis.z - 0.15 * S < p.z < sh_z]
    belly = max((p - pelvis).dot(fwd) for p in torso) if torso else 0.0
    butt = max((pelvis - p).dot(fwd) for p in band(hip_z, 0.12 * S)) if torso else 0.0
    # Chân đo tới khớp háng (đầu xương đùi), người thường ~0,50–0,53 H. Đầu
    # xương pelvis MPFB nằm cao hơn khớp háng nên không dùng.
    hip_joint = sum((mw @ pb[f"thigh_{s}"].head).z for s in "lr") / 2
    return {
        "cao (m)": round(H, 3),
        "chân (khớp háng)/chiều cao": round((hip_joint - floor) / H, 3),
        "hông (da)/khớp vai": round(hip / sh, 3) if sh else None,
        "bụng nhô trước xương chậu /H": round(belly / H, 3),
        "mông nhô sau xương chậu /H": round(butt / H, 3),
    }


# ---------------------------------------------------------------- chạy


def review(scene, body, rig, name, S, fwd, *, clothes=(), important=None, free=(), embedded=(), targets=None,
           samples=24, game_view=(-8, 6)):
    """Bộ soát cho nhân vật [body]/[rig] đang đứng dáng duyệt.

    [fwd] hướng nhân vật quay mặt (ngang). [clothes]: regex tên vật là quần áo
    (ẩn ở ảnh "nghiêng trần", kiểm da xuyên vải). [important]: {nhãn: [regex]}
    phụ kiện quan trọng (ảnh cận + % bị che từ góc game). [free]: regex vật
    được phép lơ lửng (lửa bay, hào quang, sét), tia soát che đi xuyên qua.
    [embedded]: regex vật cố ý cắm vào thân (vuốt tay nắm, khuyên vòng ra sau
    thừng) — bỏ qua kiểm "chìm vào da". [targets]: {tên tỉ lệ: (thấp,
    cao)} để cảnh báo khi lệch. Trả về danh sách cảnh báo."""
    out = os.path.join(ROOT, "build", "blender", "review", name)
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.endswith(".png") or f in ("manifest.json", "checks.txt"):
            os.remove(os.path.join(out, f))
    scene.cycles.samples = samples
    important = important or {}
    fwd = Vector((fwd.x, fwd.y, 0)).normalized()
    left = UP.cross(fwd).normalized()
    verts, polys, body_pts = _eval_world(body, limit=6000)
    body_tree = BVHTree.FromPolygons(verts, polys)
    mw = rig.matrix_world
    pb = rig.pose.bones
    shots = []

    def shot(tag, label, pts, yaw, pitch, px=520, hide=(), min_size=0.0, pad=0.12, clip_above=None, big=False):
        hidden = [o for o in bpy.data.objects if _matches(o, hide) and not o.hide_render] if hide else []
        for o in hidden:
            o.hide_render = True
        _frame(scene, pts, yaw, pitch, px=px, pad=pad, min_size=min_size, clip_above=clip_above)
        path = os.path.join(out, f"{len(shots):02d}_{tag}.png")
        render_to(scene, path)
        for o in hidden:
            o.hide_render = False
        shots.append({"file": os.path.basename(path), "label": label, "big": big})

    gy, gp = game_view
    # Toàn thân: thân + mọi vật gắn xương (vũ khí, phụ kiện), bỏ vật bay tự do.
    attached = [o for o in bpy.data.objects if o.type == "MESH" and o is not body and not o.hide_render
                and not _matches(o, free) and o.name != "Floor"]
    full_pts = list(body_pts)
    for o in attached:
        full_pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    shot("full", "Toàn thân · góc game", full_pts, gy, gp, px=760, big=True)
    shot("side_bare", "Nghiêng · ẩn quần áo", body_pts, _yaw_for(left), 2, px=620, hide=clothes, big=True)
    shot("side", "Nghiêng · mặc đồ", full_pts, _yaw_for(left), 2, px=620, big=True)
    shot("back", "Sau lưng", full_pts, _yaw_for(fwd), 4, px=620, big=True)
    ankle = max((mw @ pb[f"foot_{s}"].head).z for s in "lr")
    feet = [p for p in verts if p.z < ankle + 0.06 * S]
    shot("feet_front", "Bàn chân · trước", feet, _yaw_for(-fwd), 8, px=520, hide=clothes)
    shot("feet_top", "Bàn chân · trên xuống", feet, _yaw_for(-fwd), 70, px=520, hide=clothes,
         clip_above=ankle + 0.18 * S)
    hz = (mw @ pb["head"].head).z
    head = [p for p in verts if p.z > hz - 0.03 * S]
    shot("face", "Mặt · chính diện", head, _yaw_for(-fwd), 3, px=560, pad=0.2)
    shot("face_game", "Mặt · góc game", head, gy, gp, px=560, pad=0.2)
    for s, lab in (("l", "trái"), ("r", "phải")):
        hc = mw @ pb[f"hand_{s}"].tail
        hand = [p for p in verts if (p - hc).length < 0.13 * S]
        if hand:
            shot(f"hand_{s}", f"Tay {lab} · góc game", hand, gy, gp, px=460, pad=0.35, min_size=0.25 * S)

    warns, lines = [], []

    def warn(msg):
        warns.append(msg)
        lines.append("⚠ " + msg)

    # ---- phụ kiện quan trọng: ảnh cận + % bị che từ góc game
    dg = bpy.context.evaluated_depsgraph_get()
    lines.append("== Phụ kiện quan trọng: % thấy được từ góc game ==")
    for lab, pats in important.items():
        objs = _meshes(pats)
        if not objs:
            warn(f"{lab}: không tìm thấy vật khớp {pats}")
            continue
        pts = []
        for o in objs:
            if o.type == "MESH":
                pts += _eval_world(o, limit=400)[2]
            else:
                pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
        shot("prop_" + re.sub(r"\W+", "_", lab), f"Cận: {lab}", pts, gy, gp, px=440, pad=0.45, min_size=0.2 * S)
        cam = scene.camera
        cdir = cam.matrix_world.to_3x3() @ Vector((0, 0, -1))
        names = {o.name for o in objs}
        mesh_pts = [p for o in objs if o.type == "MESH" for p in _eval_world(o, limit=200)[2]]
        if not mesh_pts:
            continue
        seen = 0
        for p in mesh_pts:
            o_ = p - cdir * 25
            for _ in range(8):  # đi xuyên vật trong suốt / bay tự do (quầng lửa, lửa ma)
                ok, loc, _, _, hit, _ = scene.ray_cast(dg, o_, cdir)
                if not ok:
                    break
                if hit.original.name in names or (loc - p).length < 0.004 * S:
                    seen += 1
                    break
                if not _matches(hit.original, free):
                    break
                o_ = loc + cdir * 0.001
        pct = 100 * seen / len(mesh_pts)
        lines.append(f"  {lab}: thấy {pct:.0f}%")
        if pct < 60:
            warn(f"{lab} bị che {100 - pct:.0f}% nhìn từ góc game")

    # ---- quần áo: da xuyên vải
    lines.append("== Quần áo: % đỉnh vải nằm trong da (da xuyên ra) ==")
    for o in _meshes(clothes):
        if o.type != "MESH":
            continue
        f = _inside_fraction(body_tree, _eval_world(o, limit=1500)[2], 0.003 * S)
        lines.append(f"  {o.name}: {100 * f:.1f}%")
        if f > 0.03:
            warn(f"Da xuyên qua {o.name}: {100 * f:.0f}% đỉnh vải nằm dưới da")

    # ---- đồ gắn: chìm vào da / lơ lửng / pháp tuyến ngược
    lines.append("== Đồ gắn thân ==")
    parts = [o for o in attached if not _matches(o, clothes) and o.type == "MESH"
             and not any(m.type == "ARMATURE" for m in o.modifiers)]
    all_v, all_p, owner = list(verts), list(polys), [None] * len(polys)
    data = {}
    for o in parts:
        v, p, smp = _eval_world(o, limit=300)
        base = len(all_v)
        all_v += v
        all_p += [tuple(i + base for i in f) for f in p]
        owner += [o.name] * len(p)
        data[o.name] = smp
    world_tree = BVHTree.FromPolygons(all_v, all_p)
    segs = _segments(rig)
    sunk, pressed, floating, flipped = [], [], [], []
    for o in parts:
        smp = data[o.name]
        if not smp:
            continue
        if not _matches(o, list(embedded) + ALWAYS_EMBEDDED):
            if o.parent is rig and o.parent_type == "BONE" and o.parent_bone in pb:
                bone = pb[o.parent_bone]
                # Chi = xương cha + xương con (cẳng tay, xương xoắn); không lấy xương
                # ông (xương đòn): da sườn/nách gần xương đòn nhất.
                own = {bone.name} | {c.name for c in bone.children}
                mine, other, bones = _sunk_split(body_tree, smp, 0.002 * S, rig, segs, own)
                if max(mine, other) > 0.15:
                    lines.append(f"  {o.name}: điểm chìm theo xương gần nhất {bones}")
            else:
                mine, other = _inside_fraction(body_tree, smp, 0.002 * S), 0.0
            # Ngưỡng 15%: vòng tay oni phải chìm 22% vào bắp tay gồng → thấy đứt quãng ở ảnh sau lưng.
            if mine > 0.15:
                sunk.append((o.name, mine))
            if other > 0.15:
                pressed.append((o.name, other))
        near = False
        gap = math.inf
        for q in smp:
            for _, _, idx, _ in world_tree.find_nearest_range(q, 0.012 * S):
                if owner[idx] != o.name:
                    near = True
                    break
            if near:
                break
            hit = body_tree.find_nearest(q)
            if hit[0] is not None:
                gap = min(gap, hit[3])
        if not near:
            floating.append((o.name, gap))
        vol = _signed_volume(o)
        if vol is not None and vol < 0:
            flipped.append(o.name)

    def group(names):
        """Gộp tên đánh số (Bead0..Bead25 → Bead×26) cho gọn."""
        out_, seen_ = [], {}
        for n_ in names:
            k = re.sub(r"[\d.]+$", "", n_)
            seen_[k] = seen_.get(k, 0) + 1
        for k, c in seen_.items():
            out_.append(f"{k}×{c}" if c > 1 else k)
        return ", ".join(out_)

    for n_, f in sunk:
        warn(f"{n_} chìm {100 * f:.0f}% vào chính chi nó bám (vòng nhỏ hơn bắp gồng? khoá lún vào bụng?)")
    for n_, f in pressed:
        lines.append(f"  (i) {n_}: {100 * f:.0f}% ép vào phần thân khác (tay áp sườn) — tiếp xúc, thường ổn")
    for n_, g in floating:
        warn(f"{n_} lơ lửng: cách da {100 * g:.1f} cm, không chạm đồ khác trong {0.012 * S * 100:.1f} cm")
    if not (sunk or floating):
        lines.append("  không có lỗi")
    if flipped:  # vô hại với vật đục; chỉ hỏng vật trong suốt/vải sheen/lửa (Facing)
        lines.append(f"  (i) pháp tuyến ngược, chỉ hại nếu vật trong suốt/sheen/lửa: {group(flipped)}")

    # ---- tỉ lệ
    lines.append("== Tỉ lệ thân (dáng duyệt) ==")
    props = _proportions(verts, rig, fwd, S)
    for k, v in props.items():
        rng = (targets or {}).get(k)
        tag = ""
        if rng and v is not None and not (rng[0] <= v <= rng[1]):
            tag = f"  ← ngoài mục tiêu {rng}"
            warn(f"Tỉ lệ {k} = {v} ngoài mục tiêu {rng}")
        lines.append(f"  {k}: {v}{tag}")

    text = "\n".join(lines)
    print("\n===== REVIEW " + name + " =====\n" + text + f"\n===== {len(warns)} cảnh báo =====")
    with open(os.path.join(out, "checks.txt"), "w", encoding="utf-8") as fh:
        fh.write(text + "\n")
    with open(os.path.join(out, "manifest.json"), "w", encoding="utf-8") as fh:
        json.dump({"name": name, "shots": shots, "warnings": warns, "proportions": props}, fh, ensure_ascii=False,
                  indent=1)
    return warns
