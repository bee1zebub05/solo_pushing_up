"""Tách video có nhãn thành ảnh JPEG để app chạy qua ML Kit trên điện thoại
(nút "Đánh giá ML Kit" trong danh sách giả lập), đo đúng pipeline thật.

    tool/.venv/Scripts/python tool/export_frames.py dataset/public/repcount/labels.csv --where split=test
    tool/.venv/Scripts/python tool/export_frames.py dataset/public/pushupbench/labels.csv

Kết quả: dataset/eval_frames/<clip>/000001.jpg … + meta.json, rồi đẩy sang
điện thoại bằng tool/push_eval.ps1.
"""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import sys

import cv2

OUT = pathlib.Path("dataset/eval_frames")


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("labels", type=pathlib.Path)
    parser.add_argument("--where", action="append", default=[], help="key=value lọc theo cột")
    parser.add_argument("--fps", type=float, default=20, help="giống tốc độ app (~19 FPS)")
    parser.add_argument("--width", type=int, default=480, help="cạnh ngang tối đa")
    parser.add_argument("--quality", type=int, default=85)
    args = parser.parse_args()

    filters = dict(item.split("=", 1) for item in args.where)
    with args.labels.open(encoding="utf-8") as f:
        rows = [r for r in csv.DictReader(f) if all(r.get(k) == v for k, v in filters.items())]

    for row in rows:
        video = args.labels.parent / "videos" / row["video"]
        clip = pathlib.Path(row["video"]).stem
        out = OUT / clip
        if (out / "meta.json").exists():
            continue
        out.mkdir(parents=True, exist_ok=True)

        capture = cv2.VideoCapture(str(video))
        source_fps = capture.get(cv2.CAP_PROP_FPS) or 30.0
        step_ms = 1000 / args.fps
        next_ms = 0.0
        index = 0
        timestamps = []
        size = None
        while capture.grab():
            t = index * 1000 / source_fps
            index += 1
            if t < next_ms:
                continue
            next_ms += step_ms
            ok, frame = capture.retrieve()
            if not ok:
                break
            h, w = frame.shape[:2]
            if w > args.width:
                frame = cv2.resize(frame, (args.width, round(h * args.width / w)))
            size = (frame.shape[1], frame.shape[0])
            timestamps.append(round(t))
            cv2.imwrite(
                str(out / f"{len(timestamps):06d}.jpg"),
                frame,
                [cv2.IMWRITE_JPEG_QUALITY, args.quality],
            )
        capture.release()

        tags = {k: v for k, v in row.items() if k not in ("video", "expected", "mode") and v and len(v) <= 40}
        meta = {
            "clip": clip,
            "expectedCount": int(row["expected"]) if row.get("expected") else None,
            "mode": row.get("mode") or "standard",
            "tags": {"video": row["video"], **tags},
            "imageSize": list(size) if size else [0, 0],
            "timestampsMs": timestamps,
        }
        (out / "meta.json").write_text(json.dumps(meta, ensure_ascii=False), encoding="utf-8")
        print(f"{clip}: {len(timestamps)} ảnh {size}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
