"""Tải các clip của một bài tập (mặc định push_up) từ RepCount-A, kèm số rep thật.

Nguồn: bản đóng gói Lance của RepCount-A trên Hugging Face
(lmms-lab-eval/repcounta-lance). Lance cho phép lọc và chỉ tải đúng video cần,
không phải tải cả 9,7 GB.

⚠️ RepCount (TransRAC, CVPR 2022) được phát hành cho mục đích nghiên cứu học
thuật. Chỉ dùng để đánh giá nội bộ, không phát tán lại, không đưa vào app.

Cài (một lần, cùng venv với extract_pose.py):
    tool/.venv/Scripts/python -m pip install -r tool/requirements.txt

Dùng:
    tool/.venv/Scripts/python tool/fetch_repcount.py
    tool/.venv/Scripts/python tool/fetch_repcount.py --action squat --out dataset/public/repcount_squat
"""

from __future__ import annotations

import argparse
import csv
import pathlib
import sys
import time

import lance

REPO = "hf://datasets/lmms-lab-eval/repcounta-lance/data"
SPLITS = ("train", "validation", "test")


def fetch_split(split: str, action: str, videos_dir: pathlib.Path) -> list[dict]:
    dataset = lance.dataset(f"{REPO}/{split}.lance")
    table = dataset.to_table(
        columns=["video_id", "count", "cycle_bounds_json", "video_ext"],
        filter=f"action_type = '{action}'",
        with_row_id=True,
    )
    rows = table.to_pylist()
    print(f"{split}: {len(rows)} clip {action}")

    for row in rows:
        path = videos_dir / f"{row['video_id']}.{row['video_ext'].lstrip('.') or 'mp4'}"
        row["video"] = path.name
        row["split"] = split
        if path.exists():
            continue
        for attempt in range(1, 6):
            try:
                [blob] = dataset.take_blobs("video_blob", ids=[row["_rowid"]])
                data = blob.readall()
                path.write_bytes(data)
                print(f"  {path.name} {len(data) / 1e6:.1f} MB")
                break
            except Exception as error:  # mạng hay bị ngắt, thử lại
                print(f"  thử lại {attempt} {path.name}: {error}", file=sys.stderr)
                time.sleep(2 * attempt)
        else:
            print(f"  BỎ QUA {path.name}", file=sys.stderr)
    return rows


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--action", default="push_up")
    parser.add_argument("--out", type=pathlib.Path, default=pathlib.Path("dataset/public/repcount"))
    parser.add_argument("--splits", nargs="+", default=list(SPLITS), choices=SPLITS)
    args = parser.parse_args()

    videos_dir = args.out / "videos"
    videos_dir.mkdir(parents=True, exist_ok=True)
    rows = [row for split in args.splits for row in fetch_split(split, args.action, videos_dir)]

    labels = args.out / "labels.csv"
    with labels.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["video", "expected", "split", "cycle_bounds_json"])
        writer.writeheader()
        for row in rows:
            if row["count"] is None or not (videos_dir / row["video"]).exists():
                continue
            writer.writerow({
                "video": row["video"],
                "expected": row["count"],
                "split": row["split"],
                "cycle_bounds_json": row["cycle_bounds_json"],
            })
    print(f"→ {labels}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
