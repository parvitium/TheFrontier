#!/usr/bin/env python3
"""Synthesize original CC0-equivalent UI and weapon WAV files (self-made)."""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sfx"
RATE = 44100


def write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    clamped = [max(-1.0, min(1.0, s)) for s in samples]
    with wave.open(str(path), "w") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(RATE)
        frames = b"".join(struct.pack("<h", int(s * 32767)) for s in clamped)
        wf.writeframes(frames)
    print(f"wrote {path} ({len(clamped)} samples)")


def envelope(i: int, n: int, attack: float = 0.01, release: float = 0.2) -> float:
    t = i / max(1, n - 1)
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = 1.0
    if t > 1.0 - release:
        r = max(0.0, (1.0 - t) / release)
    return a * r


def tone(freq: float, dur: float, vol: float = 0.3, attack=0.01, release=0.2) -> list[float]:
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        s = math.sin(2 * math.pi * freq * t)
        out.append(s * vol * envelope(i, n, attack, release))
    return out


def noise(dur: float, vol: float = 0.2, attack=0.002, release=0.3) -> list[float]:
    n = int(RATE * dur)
    rng = random.Random(7)
    return [((rng.random() * 2 - 1) * vol * envelope(i, n, attack, release)) for i in range(n)]


def mix(*parts: list[float]) -> list[float]:
    n = max(len(p) for p in parts)
    out = [0.0] * n
    for p in parts:
        for i, v in enumerate(p):
            out[i] += v
    return out


def ui_hover() -> list[float]:
    return mix(tone(880, 0.07, 0.12, 0.005, 0.4), tone(1320, 0.06, 0.06, 0.005, 0.5))


def ui_click() -> list[float]:
    return mix(tone(220, 0.09, 0.18, 0.002, 0.45), tone(640, 0.05, 0.1, 0.001, 0.35), noise(0.04, 0.08, 0.001, 0.6))


def ui_back() -> list[float]:
    return mix(tone(330, 0.1, 0.14, 0.005, 0.5), tone(196, 0.12, 0.1, 0.01, 0.5))


def fire_rifle() -> list[float]:
    n = int(RATE * 0.22)
    rng = random.Random(11)
    out = []
    for i in range(n):
        t = i / RATE
        burst = math.exp(-t * 28.0)
        crack = (rng.random() * 2 - 1) * burst
        body = math.sin(2 * math.pi * (210 - t * 80) * t) * burst * 0.55
        hiss = math.sin(2 * math.pi * 2400 * t) * burst * 0.08
        out.append((crack * 0.45 + body + hiss) * 0.7)
    return out


def fire_shotgun() -> list[float]:
    n = int(RATE * 0.38)
    rng = random.Random(23)
    out = []
    for i in range(n):
        t = i / RATE
        burst = math.exp(-t * 12.0)
        crack = (rng.random() * 2 - 1) * burst
        body = math.sin(2 * math.pi * (90 - t * 40) * t) * burst * 0.7
        out.append((crack * 0.7 + body) * 0.75)
    return out


def place_build() -> list[float]:
    return mix(tone(140, 0.16, 0.2, 0.002, 0.4), noise(0.12, 0.12, 0.001, 0.5))


def turret_shot() -> list[float]:
    return mix(tone(520, 0.08, 0.12, 0.001, 0.4), noise(0.06, 0.1, 0.001, 0.55), tone(180, 0.1, 0.08, 0.002, 0.5))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    write_wav(OUT / "ui_hover.wav", ui_hover())
    write_wav(OUT / "ui_click.wav", ui_click())
    write_wav(OUT / "ui_back.wav", ui_back())
    write_wav(OUT / "fire_rifle.wav", fire_rifle())
    write_wav(OUT / "fire_shotgun.wav", fire_shotgun())
    write_wav(OUT / "place_build.wav", place_build())
    write_wav(OUT / "turret_shot.wav", turret_shot())
    print("sfx done")


if __name__ == "__main__":
    main()
