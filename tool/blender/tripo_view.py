"""Xem nhanh một model Tripo đã gửi vào repo (art_src/tripo/<tên>/) — không cần viết script riêng.

    bash tool/blender/render.sh tripo_view <tên>                      # bộ ảnh xoay vòng + ảnh đất sét
    bash tool/blender/render.sh tripo_view <tên> --height 2.2 --yaw 0  # cao 2,2 m, quay mặt về máy
    bash tool/blender/render.sh tripo_view <tên> --review             # bộ soát nhân vật (cần xương người)
    (+ --quick: ít mẫu; --save: lưu art_src/blender/tripo_<tên>.blend)

Ra build/blender/review/<tên>/sheet.png (render.sh ghép) + checks.txt (kích thước,
tam giác, đổi tên xương). Dùng thật trong game thì viết script riêng theo tripo_kit.
"""

import json
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths  # noqa: E402,F401
from boss_kit import ROOT, render_to, reset_scene, srgb  # noqa: E402
from human_kit import shadow_catcher  # noqa: E402
from review_kit import _frame, _yaw_for  # noqa: E402
import tripo_kit  # noqa: E402

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def opt(flag, default):
    return float(ARGS[ARGS.index(flag) + 1]) if flag in ARGS else default


def turnaround(scene, m, fwd, out, warns):
    from mathutils import Vector
    left = Vector((0, 0, 1)).cross(fwd).normalized()
    pts = m.points()
    shots = []

    def shot(tag, label, yaw, pitch, px, big=False):
        _frame(scene, pts, yaw, pitch, px=px, pad=0.08)
        render_to(scene, os.path.join(out, f"{len(shots):02d}_{tag}.png"))
        shots.append({"file": f"{len(shots):02d}_{tag}.png", "label": label, "big": big})

    shot("game", "Góc game", -8, 6, 760, big=True)
    shot("front", "Chính diện", _yaw_for(-fwd), 2, 560)
    shot("side", "Nghiêng", _yaw_for(left), 2, 560)
    shot("back", "Sau lưng", _yaw_for(fwd), 4, 560)
    shot("high", "3/4 từ trên", _yaw_for(-fwd) + 35, 35, 560)
    # Đất sét: bỏ texture, nhìn chất lượng lưới/khối (texture Tripo hay che lỗi hình).
    clay = bpy.data.materials.new("Clay")
    clay.use_nodes = True
    clay.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = srgb("#B8B0A6")
    bpy.context.view_layer.material_override = clay
    shot("clay_game", "Đất sét · góc game", -8, 6, 760, big=True)
    shot("clay_side", "Đất sét · nghiêng", _yaw_for(left), 2, 560)
    bpy.context.view_layer.material_override = None
    with open(os.path.join(out, "manifest.json"), "w", encoding="utf-8") as fh:
        json.dump({"name": m.name, "shots": shots, "warnings": warns, "proportions": {}}, fh, ensure_ascii=False, indent=1)


def main():
    if not ARGS or ARGS[0].startswith("--"):
        raise SystemExit("Cần tên: bash tool/blender/render.sh tripo_view <tên> [...]")
    name = ARGS[0]
    quick = "--quick" in ARGS
    scene = reset_scene(samples=16 if quick else 48, world_hex="#C9C4C0", world_strength=0.7)
    m = tripo_kit.load(name)
    yaw = opt("--yaw", 0.0)
    size = tripo_kit.normalize(m, height=opt("--height", 0.0) or None, yaw=yaw)
    fwd = tripo_kit.forward(yaw)
    tripo_kit.default_lights(scene)
    shadow_catcher()
    out = os.path.join(ROOT, "build", "blender", "review", name)
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.endswith(".png") or f in ("manifest.json", "checks.txt"):
            os.remove(os.path.join(out, f))
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in m.meshes)
    lines = [f"== {name} (Tripo) ==",
             f"kích thước (m): rộng {size.x:.2f} · sâu {size.y:.2f} · cao {size.z:.2f}",
             f"tam giác: {tris:,} · lưới: {len(m.meshes)} · hoạt hình: {', '.join(tripo_kit.actions(m)) or 'không'}"]
    if m.meta.get("note"):
        lines.append(f"ghi chú: {m.meta['note']}")
    bones_txt = os.path.join(ROOT, "build", "blender", "tripo", name, "bones.txt")
    if m.rig and os.path.exists(bones_txt):
        lines += open(bones_txt, encoding="utf-8").read().splitlines()
    else:
        lines.append("xương: không có (chỉ soát hình khối)")

    missing = tripo_kit.can_review(m)
    if "--review" in ARGS and not missing:
        from review_kit import review
        S = size.z / 1.75  # review_kit đo theo người cao ~1,75 m × S
        review(scene, m.body, m.rig, name, S, fwd, samples=16 if quick else 32)
        with open(os.path.join(out, "checks.txt"), "a", encoding="utf-8") as fh:
            fh.write("\n" + "\n".join(lines) + "\n")
    else:
        if "--review" in ARGS:
            lines.append(f"⚠ --review cần xương người MPFB, thiếu: {', '.join(missing)} → chạy bộ ảnh xoay vòng")
        turnaround(scene, m, fwd, out, [ln[2:] for ln in lines if ln.startswith("⚠")])
        with open(os.path.join(out, "checks.txt"), "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    if "--save" in ARGS:
        from boss_kit import save_blend
        save_blend(f"tripo_{name}")


main()
