"""Trộn âm thanh game vào video quay màn hình demo chuyển động, cắt clip.

Máy Android 13 không ghi được tiếng khi quay màn hình, nên màn demo
(lib/dev/motion_demo_main.dart) in log `DEMO cue <tên> <epoch ms>` mỗi khi game
phát một tín hiệu âm thanh. Script này:
1. Căn thời gian: tìm khung hình đầu tiên hết màn đen (lúc boss đầu tiên vào
   trận, log `DEMO act`), suy ra độ lệch giữa giờ máy và thời gian video.
2. Đặt đúng file WAV của game (assets/sounds/) vào các mốc → audio.wav.
3. Ghép tiếng, đổi sang 30 khung/giây cố định, cắt vùng sân khấu + chú thích
   → full.mp4, mỗi boss một clip <boss>.mp4, và GIF xem nhanh <boss>.gif.

Cách dùng: python tool/mix_motion_demo.py demo/motion
Cần: numpy, imageio-ffmpeg (cung cấp ffmpeg).
"""

import pathlib
import re
import subprocess
import sys
import wave

import imageio_ffmpeg
import numpy as np

FF = imageio_ffmpeg.get_ffmpeg_exe()
ROOT = pathlib.Path(__file__).resolve().parent.parent
SOUNDS = ROOT / "assets" / "sounds"
RATE = 44100
FPS = 30
ACT_LENGTH = 17.0
# Vùng giữ lại trên màn dọc 1080×2400 (đo trên CPH2159): sân khấu từ y=107, cao 702 px
# + khối chú thích bên dưới.
CROP = "crop=1080:1120:0:100"


def run(*args: str) -> None:
    subprocess.run([FF, "-hide_banner", "-loglevel", "error", "-y", *args], check=True)


def read_wav(path: pathlib.Path) -> np.ndarray:
    with wave.open(str(path)) as w:
        assert w.getframerate() == RATE and w.getnchannels() == 1
        return np.frombuffer(w.readframes(w.getnframes()), "<i2") / 32767


def brightness(video: pathlib.Path) -> np.ndarray:
    """Độ sáng trung bình từng khung (30 khung/giây cố định, ảnh xám nhỏ)."""
    w, h = 108, 240
    out = subprocess.run(
        [FF, "-hide_banner", "-loglevel", "error", "-i", str(video),
         "-vf", f"fps={FPS},scale={w}:{h},format=gray", "-f", "rawvideo", "-"],
        check=True, capture_output=True,
    ).stdout
    frames = np.frombuffer(out, np.uint8).reshape(-1, h, w)
    return frames.reshape(len(frames), -1).mean(axis=1)


def recorded_audio(video: pathlib.Path) -> np.ndarray | None:
    """Tiếng trong video (mono, RATE Hz) hoặc None nếu không có track tiếng."""
    out = subprocess.run(
        [FF, "-hide_banner", "-loglevel", "error", "-i", str(video), "-vn",
         "-ac", "1", "-ar", str(RATE), "-f", "s16le", "-"],
        capture_output=True,
    )
    if out.returncode != 0 or not out.stdout:
        return None
    return np.frombuffer(out.stdout, "<i2") / 32767


def audio_lag(x: np.ndarray, times: list[float]) -> float:
    """Trung vị độ lệch (giây) giữa điểm bắt đầu tiếng và mốc [times]."""
    env = np.sqrt(np.convolve(x**2, np.ones(441) / 441, "same"))
    win = int(0.4 * RATE)
    lags = []
    for t in times:
        i = int(t * RATE)
        seg = env[max(0, i - win) : i + win]
        if len(seg) < 2 * win or seg.max() < 0.01:
            continue
        lags.append(np.argmax(seg > 0.3 * seg.max()) / RATE - 0.4)
    return float(np.median(lags)) if lags else 0.0


def cue_file(name: str) -> tuple[str, float] | None:
    if name in ("rep", "crit"):
        return f"{name}.wav", 0.55
    boss, _, kind = name.rpartition("_")
    return {
        "tell": (f"boss_{boss}_tell.wav", 1.0),
        "rage": (f"boss_{boss}_tell.wav", 1.0),
        "hit": (f"boss_{boss}_hit.wav", 0.6),
        "defeat": ("boss_defeat.wav", 1.0),
    }.get(kind)


def main(out: pathlib.Path) -> None:
    raw = out / "raw.mp4"
    lines = (out / "cues.log").read_text(encoding="utf-8").splitlines()
    acts: list[tuple[str, float]] = []
    cues: list[tuple[str, float]] = []
    for line in lines:
        m = re.match(r"DEMO (act|cue|end) ?(\S*) (\d+)$", line.strip())
        if not m:
            continue
        kind, name, ms = m.group(1), m.group(2), int(m.group(3)) / 1000
        if kind == "act":
            acts.append((name, ms))
        elif kind == "cue":
            cues.append((name, ms))
    assert acts, "Không thấy log DEMO act"

    b = brightness(raw)
    # Đầu video có thể là màn hình chính (scrcpy quay trước khi app mở): tìm
    # đoạn đen ≥ 1 giây của màn demo, rồi khung đầu tiên sáng lên sau đó.
    dark = b < 4.0
    run_len = 0
    black_end = None
    for i, d in enumerate(dark):
        run_len = run_len + 1 if d else 0
        if run_len >= FPS:
            black_end = i
        elif black_end is not None and not d:
            break
    assert black_end is not None, "Không thấy đoạn màn đen trước khi diễn"
    level = b[black_end - FPS + 1 : black_end + 1].mean()
    first = black_end + int(np.argmax(b[black_end:] > level + 1.5))
    offset = first / FPS - acts[0][1]
    duration = len(b) / FPS
    print(f"video {duration:.1f}s, boss đầu vào trận ở khung {first} ({first / FPS:.2f}s)")

    audio = np.zeros(int(duration * RATE) + RATE)
    placed = 0
    for name, at in cues:
        spec = cue_file(name)
        if spec is None:
            continue
        clip = read_wav(SOUNDS / spec[0]) * spec[1]
        i = int((at + offset) * RATE)
        if 0 <= i < len(audio):
            n = min(len(clip), len(audio) - i)
            audio[i : i + n] += clip[:n]
            placed += 1
    audio = np.clip(audio, -1, 1)
    # Ưu tiên tiếng thật scrcpy ghi được; câm (máy không cho ghi) thì dùng
    # tiếng trộn từ log.
    recorded = recorded_audio(raw)
    if recorded is not None and np.sqrt(np.mean(recorded**2)) > 0.003:
        # Bản ghi scrcpy: tiếng đến sớm hơn hình (hình mã hoá trễ hơn). Đo độ
        # lệch tại các mốc log rồi dời tiếng cho khớp hình.
        # Chỉ dùng mốc không có tiếng nào khác trong 0,6 s trước đó (tiếng
        # trúng đòn đến 0,22 s sau tiếng rep: dò quanh nó sẽ bắt nhầm tiếng rep).
        lone = [at for k, (_, at) in enumerate(cues)
                if k == 0 or at - cues[k - 1][1] > 0.6]
        lag = audio_lag(recorded, [at + offset for at in lone])
        shift = int(-lag * RATE)
        print(f"dùng tiếng thật ghi từ máy (lệch {lag:+.3f}s so với hình → dời lại)")
        if shift > 0:
            audio = np.concatenate([np.zeros(shift), recorded])
        else:
            audio = recorded[-shift:]
    else:
        print(f"bản ghi câm → trộn {placed} tiếng từ log")
    with wave.open(str(out / "audio.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((audio * 32767).astype("<i2").tobytes())

    full = out / "full.mp4"
    run("-i", str(raw), "-i", str(out / "audio.wav"), "-map", "0:v", "-map", "1:a",
        "-vf", f"fps={FPS},{CROP},scale=720:-2", "-c:v", "libx264", "-crf", "22",
        "-preset", "medium", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "128k",
        "-shortest", "-movflags", "+faststart", str(full))
    for name, at in acts:
        start = at + offset
        run("-ss", f"{start:.3f}", "-t", f"{ACT_LENGTH:.3f}", "-i", str(full),
            "-c:v", "libx264", "-crf", "22", "-preset", "medium", "-pix_fmt", "yuv420p",
            "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", str(out / f"{name}.mp4"))
        # GIF xem nhanh (không tiếng): giây 1–15, 12 khung/giây, rộng 400.
        run("-ss", f"{start + 1:.3f}", "-t", "14", "-i", str(full), "-vf",
            "fps=12,scale=400:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=4",
            str(out / f"{name}.gif"))
        print(f"{name}: {start:.2f}s")


if __name__ == "__main__":
    main(pathlib.Path(sys.argv[1]))
