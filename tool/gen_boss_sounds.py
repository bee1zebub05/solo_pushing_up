"""Tạo âm thanh riêng cho từng boss (assets/sounds/boss_*.wav).

Mỗi boss hai tiếng:
- `<boss>_tell`: báo đòn, phát lúc boss bắt đầu lấy đà. Người chơi đang nhìn
  sàn nên phải NGHE được đòn sắp tới (trụ cột 3, rules/thietke/tru-cot.md).
- `<boss>_hit`: đòn của người chơi trúng boss, theo chất liệu boss.

Tổng hợp hoàn toàn bằng code (nhiễu lọc + sóng), không dùng file trên mạng.
Chạy lại khi muốn đổi âm: python tool/gen_boss_sounds.py
"""

import pathlib
import wave

import numpy as np
from scipy import signal

RATE = 44100
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "sounds"
rng = np.random.default_rng(7)


def t_axis(sec: float) -> np.ndarray:
    return np.arange(int(RATE * sec)) / RATE


def noise(sec: float) -> np.ndarray:
    return rng.standard_normal(int(RATE * sec))


def band(x: np.ndarray, lo: float, hi: float, order: int = 4) -> np.ndarray:
    sos = signal.butter(order, [lo, hi], btype="band", fs=RATE, output="sos")
    return signal.sosfilt(sos, x)


def low(x: np.ndarray, hi: float, order: int = 4) -> np.ndarray:
    sos = signal.butter(order, hi, btype="low", fs=RATE, output="sos")
    return signal.sosfilt(sos, x)


def high(x: np.ndarray, lo: float, order: int = 4) -> np.ndarray:
    sos = signal.butter(order, lo, btype="high", fs=RATE, output="sos")
    return signal.sosfilt(sos, x)


def glide(x: np.ndarray, filters: list) -> np.ndarray:
    """Bộ lọc quét: trộn mượt giữa các bản lọc theo thời gian (không có chỗ
    nối gây lách tách như cắt từng đoạn)."""
    ys = [f(x) for f in filters]
    pos = np.linspace(0, len(ys) - 1, len(x))
    out = np.zeros_like(x)
    for k, y in enumerate(ys):
        out += y * np.clip(1 - np.abs(pos - k), 0, 1)
    return out


def env(n: int, attack: float, release: float) -> np.ndarray:
    """Đường bao: lên trong [attack] giây, tắt dần mũ trong [release] giây."""
    t = np.arange(n) / RATE
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    r = np.exp(-np.maximum(t - attack, 0) / max(release, 1e-4))
    return a * r


def swell(n: int, peak: float) -> np.ndarray:
    """Phồng lên tới [peak] (0–1 của độ dài) rồi tắt nhanh."""
    x = np.linspace(0, 1, n)
    up = np.clip(x / peak, 0, 1) ** 2
    down = np.clip((1 - x) / (1 - peak), 0, 1) ** 0.7
    return up * down


def sweep(f0: float, f1: float, sec: float, wave_fn=np.sin) -> np.ndarray:
    f = np.linspace(f0, f1, int(RATE * sec))
    return wave_fn(2 * np.pi * np.cumsum(f) / RATE)


def saw(phase: np.ndarray) -> np.ndarray:
    return 2 * (phase / (2 * np.pi) % 1) - 1


def mix(*parts: np.ndarray) -> np.ndarray:
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def write(name: str, x: np.ndarray, peak: float = 0.7) -> None:
    # Vào/ra mềm 5 ms để không lách tách.
    fade = int(RATE * 0.005)
    x = x.copy()
    x[:fade] *= np.linspace(0, 1, fade)
    x[-fade:] *= np.linspace(1, 0, fade)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"boss_{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print(f"boss_{name}.wav  {len(x) / RATE:.2f}s")


def nemea_tell() -> np.ndarray:
    # Gầm gừ: răng cưa trầm 70→95 Hz, rung "rừ" 22 Hz, hơi thở lọc dải.
    sec = 0.85
    t = t_axis(sec)
    f = np.linspace(70, 95, len(t))
    body = saw(2 * np.pi * np.cumsum(f) / RATE)
    body = low(body, 700) * (0.6 + 0.4 * np.sin(2 * np.pi * 22 * t))
    breath = band(noise(sec), 250, 1200) * 0.35
    return mix(body, breath) * swell(len(t), 0.7)


def nemea_hit() -> np.ndarray:
    # Đấm vào thân nặng: sin 95→40 Hz tắt nhanh + tiếng vỗ lông.
    sec = 0.32
    n = int(RATE * sec)
    thump = sweep(95, 40, sec) * env(n, 0.002, 0.09)
    slap = band(noise(sec), 300, 2500) * env(n, 0.001, 0.025) * 0.6
    return mix(thump, slap)


def fafnir_tell() -> np.ndarray:
    # Hít hơi băng: tiếng rít lọc dải trượt lên + gầm trầm 48 Hz.
    sec = 0.9
    t = t_axis(sec)
    out = glide(
        noise(sec),
        [lambda x, lo=300 + 120 * i: band(x, lo, lo * 2.2) for i in range(12)],
    )
    rumble = np.sin(2 * np.pi * 48 * t) * 0.8 + saw(2 * np.pi * 48 * t) * 0.2
    return mix(out * 0.6, low(rumble, 300)) * swell(len(t), 0.85)


def fafnir_hit() -> np.ndarray:
    # Băng nứt: vài tiếng tách sắc + leng keng cao tắt dần.
    sec = 0.45
    n = int(RATE * sec)
    x = np.zeros(n)
    for start in (0.0, 0.018, 0.041, 0.07):
        i = int(start * RATE)
        burst = high(noise(0.02), 2500) * env(int(RATE * 0.02), 0.0005, 0.004)
        x[i : i + len(burst)] += burst
    t = t_axis(sec)
    tink = sum(
        np.sin(2 * np.pi * f * t) * np.exp(-t / d) * a
        for f, d, a in ((3150, 0.12, 0.3), (4710, 0.08, 0.25), (6230, 0.05, 0.2))
    )
    thud = sweep(120, 60, sec) * env(n, 0.002, 0.05) * 0.5
    return mix(x, tink, thud)


def orochi_tell() -> np.ndarray:
    # Tám đầu rít so le: nhiễu cao, mỗi đầu phồng lên lệch nhau.
    sec = 0.8
    n = int(RATE * sec)
    x = np.zeros(n)
    for k in range(4):
        delay = int(RATE * 0.07 * k)
        h = high(band(noise(sec), 3000, 9000), 2800) * swell(n, 0.6)
        x[delay:] += h[: n - delay] * (1 - 0.15 * k)
    return x


def orochi_hit() -> np.ndarray:
    # Chém vào vảy: tiếng xoẹt ngắn + thịch trầm.
    sec = 0.3
    n = int(RATE * sec)
    slash = band(noise(sec), 1200, 4500) * env(n, 0.001, 0.03)
    thud = sweep(110, 55, sec) * env(n, 0.002, 0.07) * 0.8
    return mix(slash, thud)


def thuy_tinh_tell() -> np.ndarray:
    # Sóng dâng: nhiễu lọc thấp mở dần + gầm nước trầm.
    sec = 1.0
    n = int(RATE * sec)
    out = glide(
        noise(sec),
        [lambda x, c=250 + 180 * i: low(x, c) for i in range(10)],
    )
    roar = low(noise(sec), 120) * 2.5
    return mix(out, roar) * swell(n, 0.8)


def thuy_tinh_hit() -> np.ndarray:
    # Té nước: nhiễu cao tắt nhanh + vài bọt nước (chirp lên).
    sec = 0.5
    n = int(RATE * sec)
    splash = high(noise(sec), 900) * env(n, 0.002, 0.07)
    bubbles = np.zeros(n)
    for start, f in ((0.05, 600), (0.11, 820), (0.16, 700), (0.24, 950)):
        b = sweep(f, f * 2.2, 0.04) * env(int(RATE * 0.04), 0.002, 0.012) * 0.4
        i = int(start * RATE)
        bubbles[i : i + len(b)] += b
    thud = sweep(90, 45, sec) * env(n, 0.002, 0.06) * 0.6
    return mix(splash, bubbles, thud)


SOUNDS = {
    "nemea_tell": nemea_tell,
    "nemea_hit": nemea_hit,
    "fafnir_tell": fafnir_tell,
    "fafnir_hit": fafnir_hit,
    "orochi_tell": orochi_tell,
    "orochi_hit": orochi_hit,
    "thuy_tinh_tell": thuy_tinh_tell,
    "thuy_tinh_hit": thuy_tinh_hit,
}

if __name__ == "__main__":
    for name, make in SOUNDS.items():
        write(name, make())
