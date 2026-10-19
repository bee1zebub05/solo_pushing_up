"""Khung video soát đòn đánh (`render.sh <boss> --video`; tool/render/boss_video.py ghép mp4)."""
import os

from boss_kit import render_to


def video_frames(scene, motion, out, moves=("attack", "attack2"), n=60, samples=24):
    """[n] khung mỗi đòn theo tiến độ 0–1 → <out>/video/<đòn>/f_000.png…"""
    scene.cycles.samples = samples
    for move in moves:
        vdir = os.path.join(out, "video", move)
        os.makedirs(vdir, exist_ok=True)
        for k in range(n):
            motion.pose(move=move, phase=k / (n - 1))
            render_to(scene, os.path.join(vdir, f"f_{k:03d}.png"))
