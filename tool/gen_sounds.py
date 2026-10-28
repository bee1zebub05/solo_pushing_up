"""Tạo các tiếng bíp ngắn cho phản hồi rep (assets/sounds/*.wav).

Dùng tiếng tổng hợp thay vì file tải trên mạng để không vướng bản quyền.
Chạy lại khi muốn đổi âm: python tool/gen_sounds.py
"""

import math
import pathlib
import struct
import wave

RATE = 44100
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "sounds"


def tone(freq_start: float, freq_end: float, ms: int, volume: float = 0.6) -> list[float]:
    n = int(RATE * ms / 1000)
    attack = int(RATE * 0.005)
    release = int(RATE * 0.03)
    samples = []
    phase = 0.0
    for i in range(n):
        freq = freq_start + (freq_end - freq_start) * i / n
        phase += 2 * math.pi * freq / RATE
        envelope = min(1.0, i / attack, (n - i) / release)
        samples.append(volume * envelope * math.sin(phase))
    return samples


def silence(ms: int) -> list[float]:
    return [0.0] * int(RATE * ms / 1000)


def write(name: str, samples: list[float]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in samples))


SOUNDS = {
    # Rep hợp lệ: bíp ngắn, cao.
    "rep": tone(880, 880, 70),
    # Rep sâu (đòn chí mạng): hai nốt đi lên.
    "crit": tone(880, 880, 60) + tone(1320, 1320, 90),
    # Chưa đủ sâu: nốt trầm, nhẹ.
    "partial": tone(330, 300, 120, volume=0.45),
    # Bị từ chối (sai tư thế): hai nốt trầm.
    "reject": tone(220, 220, 90) + silence(40) + tone(220, 220, 90),
    # Vào tư thế sẵn sàng: quét lên.
    "ready": tone(660, 990, 150, volume=0.5),
    # Báo đòn theo CÁCH NÉ, chung mọi quái (người chơi nhìn sàn — rules/thietke/
    # boss-nhat-shuten-sutoku.md, trụ 3). ⏸ giữ tay: hai tiếng trống trầm đứng yên.
    "dodge_hold": tone(150, 110, 140, volume=0.9) + silence(70) + tone(150, 110, 200, volume=0.9),
    # Rep sâu: tiếng vút trượt từ cao xuống thấp — "cúi xuống".
    "dodge_duck": tone(1100, 240, 380, volume=0.7),
    # Đếm ngược tới lúc chạm (1 s, 0,5 s trước): tích ngắn, khô.
    "count_tick": tone(1600, 1600, 35, volume=0.5),
}

if __name__ == "__main__":
    for name, samples in SOUNDS.items():
        write(name, samples)
        print(f"{OUT / name}.wav")
