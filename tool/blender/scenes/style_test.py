# blender: user-prefs  (cần tiện ích MPFB cho nhân vật — xem tool/blender/render.sh)
"""Cảnh thử phong cách: phông Thung lũng Nemea (theo tầng) + Sư tử Nemea +
nhân vật chống đẩy, render bằng đúng máy quay khi xuất sprite để ghép như
sân khấu game (tool/render/style_test_compose.py).

    bash tool/blender/render.sh style_test             # phong cách hiện tại
    bash tool/blender/render.sh style_test --painted   # phong cách "painted"
    python -I tool/render/style_test_compose.py               # ghép, đặt cạnh nhau

→ build/style/<real|painted>/: backdrop_<tầng>.png, lion.png, hero_<lớp>.png
và meta.json (điểm neo + điểm ảnh mỗi đơn vị sân khấu của từng ảnh).
"""

import json
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import paths  # noqa: E402,F401  (kits/, motion/, render/ — rules/dohoa/README.md)
from boss_kit import ARGS, P, ROOT, render_to, reset_scene, setup_camera  # noqa: E402
import style_kit  # noqa: E402
from sprite_kit import frame_scale  # noqa: E402

PAINTED = "--painted" in ARGS
OUT = os.path.join(ROOT, "build", "style", "painted" if PAINTED else "real")
meta = {}


def begin(samples):
    scene = reset_scene(samples=samples, world_hex="#9DB6D2", world_strength=0.55, keep_prefs=True)
    if PAINTED:
        style_kit.install()
    return scene


def finish(scene):
    if PAINTED:
        style_kit.apply(scene)


def backdrop():
    import nemea_valley as nv
    nv.LUSH = PAINTED  # bảng màu đồng cỏ tươi thay đất khô
    scene = begin(64)
    nv.sky_world(scene)
    nv.build()
    nv.lights(scene)
    nv.camera(scene)
    finish(scene)
    for ln in nv.LAYERS:
        nv.render_layer(scene, ln, os.path.join(OUT, f"backdrop_{ln}.png"))


def lion():
    import lion_nemea as ln
    scene = begin(64)
    rig = ln.build()
    ln.lights(scene)
    ln.shadow_floor()
    cam = setup_camera(scene, ln.FRAME_X, ln.FRAME_Y, px_per_unit=2.2, yaw=-14, pitch=6)
    ln.pose(rig, 0)
    finish(scene)
    a, ppu = frame_scale(scene, cam, P(0, 0), 50 * ln.LION_SCALE)
    render_to(scene, os.path.join(OUT, "lion.png"))
    meta["lion"] = {"anchor": [a.x, a.y], "ppu": ppu}


def hero_layers():
    import hero
    from human_kit import camera, shadow_catcher
    scene = begin(96)
    body, rig, layers = hero.build()
    poser = hero.Poser(rig)
    hero.lights(scene)
    floor = shadow_catcher()
    upm = hero.stage_units_per_m(rig)
    cam = camera(scene, 0.9, 0.95, 2.6, 2.1, 3.0 * upm, yaw=-10, pitch=7)
    poser.plank(178)
    if PAINTED:
        # Tỉ lệ anh hùng phóng đại (đọc rõ ở cỡ nhỏ): đầu, bàn tay, bàn chân to hơn.
        for bone, k in (("head", 1.14), ("hand_l", 1.18), ("hand_r", 1.18), ("foot_l", 1.1), ("foot_r", 1.1)):
            rig.pose.bones[bone].scale = (k, k, k)
        bpy.context.view_layer.update()
    finish(scene)
    a, ppu = frame_scale(scene, cam, Vector(), upm)
    for name, objs in (("skin", layers["skin"]), ("cloth", layers["cloth"] + [floor]),
                       ("hair", layers["hair"]["curly"] + layers["brows"])):
        hero.show_layer(layers, objs, hair_style="curly" if name == "hair" else None, floor=floor)
        render_to(scene, os.path.join(OUT, f"hero_{name}.png"))
    meta["hero"] = {"anchor": [a.x, a.y], "ppu": ppu}


def main():
    os.makedirs(OUT, exist_ok=True)
    only = ARGS[ARGS.index("--parts") + 1].split(",") if "--parts" in ARGS else ("backdrop", "lion", "hero")
    path = os.path.join(OUT, "meta.json")
    if os.path.exists(path):
        meta.update(json.load(open(path, encoding="utf-8")))
    if "backdrop" in only:
        backdrop()
    if "lion" in only:
        lion()
    if "hero" in only:
        hero_layers()
    with open(path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=1)


main()
