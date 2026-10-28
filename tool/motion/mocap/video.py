"""Video võ thuật → khung xương chuẩn 24 điểm (MediaPipe Pose, toạ độ thế giới).

    python tool/motion/mocap/video.py clip.mp4 out.npz [--sheet out.png]
    tool/.venv-ml/Scripts/python tool/motion/mocap/model.py clean out.npz out_clean.npz

Chỉ dùng video người dùng tự quay hoặc giấy phép mở (rules/dohoa/chuyendong.md).
MediaPipe cho 33 điểm quanh hông (mét, không có quãng đi) → map sang khung
chuẩn; lưu kèm độ tin cậy từng khớp (`vis`) để mô hình khử nhiễu che các
khớp kém tin cậy. Một camera nên chiều sâu kém: quay NGANG người diễn (đúng
góc sân khấu) cho kết quả tốt nhất.
"""

import argparse
import os
import pathlib
import sys

import cv2
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from skeleton import JOINTS, Motion, canonical  # noqa: E402

MODEL = pathlib.Path(HERE).parents[1] / "models" / "pose_landmarker_full.task"
# BlazePose 33 điểm
BP = {"nose": 0, "ear_l": 7, "ear_r": 8, "shoulder_l": 11, "shoulder_r": 12, "elbow_l": 13, "elbow_r": 14,
      "wrist_l": 15, "wrist_r": 16, "index_l": 19, "index_r": 20, "thumb_l": 21, "thumb_r": 22,
      "hip_l": 23, "hip_r": 24, "knee_l": 25, "knee_r": 26, "ankle_l": 27, "ankle_r": 28,
      "heel_l": 29, "heel_r": 30, "foot_l": 31, "foot_r": 32}


def extract(path):
    import mediapipe as mp
    from mediapipe.tasks import python as mp_tasks
    from mediapipe.tasks.python import vision

    opts = vision.PoseLandmarkerOptions(base_options=mp_tasks.BaseOptions(model_asset_path=str(MODEL)),
                                        running_mode=vision.RunningMode.VIDEO, num_poses=1)
    cap = cv2.VideoCapture(str(path))
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    frames, vis = [], []
    with vision.PoseLandmarker.create_from_options(opts) as lm:
        k = 0
        while True:
            ok, img = cap.read()
            if not ok:
                break
            rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            r = lm.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb), int(k * 1000 / fps))
            k += 1
            if not r.pose_world_landmarks:
                frames.append(None)
                vis.append(None)
                continue
            w = r.pose_world_landmarks[0]
            # MediaPipe: x phải, y xuống, z vào trong → Z lên, tay phải (X, Y, Z) = (x, z, −y).
            frames.append(np.array([[p.x, p.z, -p.y] for p in w]))
            vis.append(np.array([p.visibility for p in w]))
    return frames, vis, fps


def to_canonical(frames, vis, fps):
    n = len(frames)
    good = [i for i in range(n) if frames[i] is not None]
    if not good:
        raise SystemExit("không thấy người trong video")
    P = np.zeros((n, 33, 3))
    V = np.zeros((n, 33))
    for i in range(n):
        j = i if frames[i] is not None else min(good, key=lambda g: abs(g - i))
        P[i], V[i] = frames[j], (vis[j] if frames[i] is not None else 0.0)

    def g(name):
        return P[:, BP[name]]

    pel = (g("hip_l") + g("hip_r")) / 2
    sh = (g("shoulder_l") + g("shoulder_r")) / 2
    head = (g("ear_l") + g("ear_r")) / 2
    neck = sh + (head - sh) * 0.25
    out = {"pelvis": pel, "spine": pel + (sh - pel) * 0.33, "chest": pel + (sh - pel) * 0.66, "neck": neck,
           "head": head, "head_top": head + (head - neck) * 0.7,
           "hand_tip_l": g("index_l"), "hand_tip_r": g("index_r"), "toe_l": g("foot_l"), "toe_r": g("foot_r")}
    for n_ in ("shoulder", "elbow", "wrist", "hip", "knee", "ankle", "thumb"):
        for s in "lr":
            out[f"{n_}_{s}"] = g(f"{n_}_{s}")
    pos = np.stack([out[j] for j in JOINTS], axis=1)
    src = {"pelvis": ["hip_l", "hip_r"], "spine": ["hip_l", "shoulder_l"], "chest": ["shoulder_l", "shoulder_r"],
           "neck": ["shoulder_l", "shoulder_r"], "head": ["ear_l", "ear_r"], "head_top": ["ear_l", "ear_r"],
           "hand_tip_l": ["index_l"], "hand_tip_r": ["index_r"], "toe_l": ["foot_l"], "toe_r": ["foot_r"]}
    vj = np.stack([V[:, [BP[x] for x in src.get(j, [j])]].min(1) for j in JOINTS], axis=1)
    m = canonical(pos, fps, {"src": "video"}, height=1.75)
    return m, vj


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("out")
    ap.add_argument("--sheet")
    a = ap.parse_args()
    frames, vis, fps = extract(a.video)
    m, vj = to_canonical(frames, vis, fps)
    np.savez_compressed(a.out, pos=m.pos.astype(np.float32), fps=m.fps, vis=vj.astype(np.float32),
                        meta=np.array(repr(m.meta)))
    print(f"{len(m)} khung @ {fps:.0f} fps, tin cậy trung bình {vj.mean():.2f} → {a.out}")
    if a.sheet:
        from preview import sheet
        sheet(m, 0, (len(m) - 1) / m.fps, 18).save(a.sheet)


if __name__ == "__main__":
    main()
