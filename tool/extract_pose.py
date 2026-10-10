"""Trích landmarks từ video bằng MediaPipe Pose Landmarker, xuất ra file bản ghi
JSON cùng định dạng với app (lib/dataset/recording.dart) để chạy lại bằng
`dart run tool/replay.dart`.

Cài đặt (một lần):
    python -m venv tool/.venv
    tool/.venv/Scripts/python -m pip install -r tool/requirements.txt

Dùng:
    tool/.venv/Scripts/python tool/extract_pose.py video.mp4 --expected 15
    tool/.venv/Scripts/python tool/extract_pose.py a.mp4 b.mp4 --mode knee \
        --tag angle=chéo --tag light=tối --notes "phòng nhỏ"

Lưu ý: model MediaPipe trên máy tính không giống hệt ML Kit trong app, nên kết
quả chỉ là tương đối. Bản ghi từ app (nút ghi) phản ánh đúng model thật.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import pathlib
import sys
import urllib.request

import cv2
import mediapipe as mp
from mediapipe.tasks import python as mp_tasks
from mediapipe.tasks.python import vision

TOOL_DIR = pathlib.Path(__file__).resolve().parent
MODELS_DIR = TOOL_DIR / "models"
MODEL_URL = (
    "https://storage.googleapis.com/mediapipe-models/pose_landmarker/"
    "pose_landmarker_{variant}/float16/latest/pose_landmarker_{variant}.task"
)

# Chỉ số BlazePose 33 điểm → tên Joint trong lib/pose/pose_frame.dart.
JOINTS = {
    "nose": 0,
    "leftShoulder": 11,
    "rightShoulder": 12,
    "leftElbow": 13,
    "rightElbow": 14,
    "leftWrist": 15,
    "rightWrist": 16,
    "leftHip": 23,
    "rightHip": 24,
    "leftKnee": 25,
    "rightKnee": 26,
    "leftAnkle": 27,
    "rightAnkle": 28,
}


def ensure_model(variant: str) -> pathlib.Path:
    path = MODELS_DIR / f"pose_landmarker_{variant}.task"
    if not path.exists():
        MODELS_DIR.mkdir(parents=True, exist_ok=True)
        url = MODEL_URL.format(variant=variant)
        print(f"Tải model {variant} từ {url}")
        urllib.request.urlretrieve(url, path)
    return path


def extract(
    video: pathlib.Path,
    model: pathlib.Path,
    target_fps: float | None = None,
) -> tuple[list[dict], tuple[int, int]]:
    capture = cv2.VideoCapture(str(video))
    if not capture.isOpened():
        raise RuntimeError(f"Không mở được video {video}")
    fps = capture.get(cv2.CAP_PROP_FPS) or 30.0
    # Lấy mẫu thưa hơn để giống app (~20 FPS) và chạy nhanh hơn.
    keep_every_ms = 1000 / target_fps if target_fps and target_fps < fps else 0
    next_keep_ms = 0.0

    options = vision.PoseLandmarkerOptions(
        base_options=mp_tasks.BaseOptions(model_asset_path=str(model)),
        running_mode=vision.RunningMode.VIDEO,
        num_poses=1,
    )
    frames: list[dict] = []
    size = (0, 0)
    index = 0
    with vision.PoseLandmarker.create_from_options(options) as landmarker:
        while True:
            if not capture.grab():
                break
            timestamp_ms = round(index * 1000 / fps)
            index += 1
            if timestamp_ms < next_keep_ms:
                continue
            next_keep_ms += keep_every_ms
            ok, bgr = capture.retrieve()
            if not ok:
                break
            height, width = bgr.shape[:2]
            size = (width, height)

            rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
            image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
            result = landmarker.detect_for_video(image, timestamp_ms)

            landmarks = {}
            if result.pose_landmarks:
                points = result.pose_landmarks[0]
                for name, i in JOINTS.items():
                    p = points[i]
                    landmarks[name] = [
                        round(p.x * width, 1),
                        round(p.y * height, 1),
                        round(p.visibility or 0.0, 3),
                    ]
            frames.append({"t": timestamp_ms, "lm": landmarks})
    capture.release()
    return frames, size


def parse_tags(raw: list[str]) -> dict[str, str]:
    tags = {}
    for item in raw:
        key, sep, value = item.partition("=")
        if not sep:
            raise SystemExit(f"--tag phải có dạng key=value: {item}")
        tags[key] = value
    return tags


def read_labels(path: pathlib.Path) -> list[tuple[pathlib.Path, int | None, dict[str, str]]]:
    """CSV có cột `video` (đường dẫn tương đối với thư mục `videos/` cạnh file),
    `expected`, tuỳ chọn `mode`; các cột khác (trừ cột dài) thành tag."""
    jobs = []
    with path.open(encoding="utf-8") as f:
        for row in csv.DictReader(f):
            video = path.parent / "videos" / row.pop("video")
            expected = row.pop("expected", "")
            extra = {k: v for k, v in row.items() if v and len(v) <= 40}
            jobs.append((video, int(expected) if expected else None, extra))
    return jobs


def main() -> int:
    # Console Windows mặc định cp1252, không in được tiếng Việt.
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("videos", nargs="*", type=pathlib.Path)
    parser.add_argument("--labels", type=pathlib.Path, help="CSV video,expected[,mode,...] để xử lý hàng loạt")
    parser.add_argument("--expected", type=int, help="số rep thật trong video")
    parser.add_argument("--mode", choices=["standard", "knee"], default="standard")
    parser.add_argument("--model", choices=["lite", "full", "heavy"], default="full")
    parser.add_argument("--tag", action="append", default=[], help="key=value, lặp được")
    parser.add_argument("--notes", default="")
    parser.add_argument("--out", type=pathlib.Path, default=pathlib.Path("dataset/recordings"))
    parser.add_argument("--skip-existing", action="store_true", help="bỏ qua video đã có bản ghi")
    parser.add_argument("--fps", type=float, help="lấy mẫu tối đa bấy nhiêu khung/giây (app chạy ~20)")
    parser.add_argument("--shard", default="0/1", help="i/n: chỉ xử lý phần thứ i trong n, để chạy song song")
    args = parser.parse_args()

    tags = parse_tags(args.tag)
    jobs = [(video, args.expected, {}) for video in args.videos]
    if args.labels:
        jobs += read_labels(args.labels)
    if not jobs:
        parser.error("cần ít nhất một video hoặc --labels")
    shard, shards = (int(x) for x in args.shard.split("/"))
    jobs = jobs[shard::shards]

    model = ensure_model(args.model)
    args.out.mkdir(parents=True, exist_ok=True)

    for video, expected, extra in jobs:
        out = args.out / f"{video.stem}.json"
        if args.skip_existing and out.exists():
            continue
        mode = extra.pop("mode", args.mode)
        frames, (width, height) = extract(video, model, args.fps)
        detected = sum(1 for f in frames if f["lm"])
        recording = {
            "version": 1,
            "source": f"mediapipe-python-{args.model}",
            "createdAt": dt.datetime.now().isoformat(timespec="seconds"),
            "mode": mode,
            "expectedCount": expected,
            "tags": {"video": video.name, **extra, **tags},
            "notes": args.notes,
            "imageSize": [width, height],
            "frames": frames,
        }
        out.write_text(json.dumps(recording, ensure_ascii=False), encoding="utf-8")
        print(f"{video.name}: {len(frames)} khung, thấy người ở {detected} khung → {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
