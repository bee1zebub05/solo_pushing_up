"""Khung video soát đòn đánh (`render.sh <boss> --video [--quick]`; tool/render/boss_video.py ghép mp4).

`--quick` = bản nháp giữa các vòng sửa: 20 khung mỗi đòn, 6 mẫu, nửa độ phân giải,
ghi vào video_quick/ (không đè bản đầy đủ dùng cho báo cáo).
"""
import os

from boss_kit import render_to


def video_frames(scene, motion, out, moves=("attack", "attack2"), n=60, samples=24, quick=False):
    """[n] khung mỗi đòn theo tiến độ 0–1 → <out>/video[_quick]/<đòn>/f_000.png…"""
    if quick:
        n, samples = 20, 6
        scene.render.resolution_percentage = 50
    scene.cycles.samples = samples
    for move in moves:
        vdir = os.path.join(out, "video_quick" if quick else "video", move)
        os.makedirs(vdir, exist_ok=True)
        for f in os.listdir(vdir):
            if f.startswith("f_"):
                os.remove(os.path.join(vdir, f))
        for k in range(n):
            motion.pose(move=move, phase=k / (n - 1))
            render_to(scene, os.path.join(vdir, f"f_{k:03d}.png"))
