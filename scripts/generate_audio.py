"""Generate the built-in, licence-free soundtrack and SFX.

Everything here is synthesised from sine/noise primitives — no third-party
samples, so the audio can ship under the project licence.
"""

from __future__ import annotations

import math
import random
import wave
from pathlib import Path

SR = 32000
OUT = Path(__file__).resolve().parent.parent / "resources" / "audio"
OUT.mkdir(parents=True, exist_ok=True)


def write_wav(name: str, samples: list[float], peak: float = 0.55) -> None:
    top = max(1e-9, max(abs(s) for s in samples))
    scale = peak / top
    frames = bytearray()
    for s in samples:
        v = int(max(-1.0, min(1.0, s * scale)) * 32767)
        frames += int(v).to_bytes(2, "little", signed=True)
    path = OUT / name
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    print(f"{path.name}: {len(samples) / SR:.2f}s, {path.stat().st_size / 1024:.0f} KiB")


def env(t: float, attack: float, decay: float, curve: float = 2.0) -> float:
    if t < 0:
        return 0.0
    if t < attack:
        return t / attack
    return math.exp(-((t - attack) / decay) ** curve)


def note(freq: float, dur: float, *, amp: float = 0.25, attack: float = 0.02, decay: float = 0.4) -> list[float]:
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        e = env(t, attack, decay)
        s = (
            math.sin(2 * math.pi * freq * t)
            + 0.35 * math.sin(2 * math.pi * freq * 2 * t)
            + 0.12 * math.sin(2 * math.pi * freq * 3 * t)
        )
        out.append(s * e * amp)
    return out


def mix_into(dst: list[float], src: list[float], at: int, gain: float = 1.0) -> None:
    if at >= len(dst):
        return
    end = min(len(dst), at + len(src))
    for i in range(at, end):
        dst[i] += src[i - at] * gain


def lowpass(samples: list[float], alpha: float = 0.25) -> list[float]:
    out = []
    prev = 0.0
    for s in samples:
        prev = prev + alpha * (s - prev)
        out.append(prev)
    return out


def reverb(samples: list[float], mix: float = 0.28) -> list[float]:
    out = list(samples)
    taps = [(int(0.031 * SR), 0.30), (int(0.047 * SR), 0.24), (int(0.073 * SR), 0.18), (int(0.119 * SR), 0.10)]
    for delay, gain in taps:
        for i in range(delay, len(samples)):
            out[i] += out[i - delay] * gain * mix
    return lowpass(out, 0.55)


def bgm() -> None:
    beat = 0.75
    chords = [
        [261.63, 329.63, 392.00, 493.88],  # Cmaj7
        [220.00, 261.63, 329.63, 392.00],  # Amin7
        [174.61, 220.00, 261.63, 349.23],  # Fmaj7
        [196.00, 246.94, 293.66, 329.63],  # G6
    ]
    total_beats = 32
    total_s = total_beats * beat
    buf = [0.0] * int(total_s * SR)
    rng = random.Random(7)
    for b in range(total_beats):
        chord = chords[(b // 8) % len(chords)]
        t0 = b * beat
        # soft pad: long attack, two chord tones
        for k, f in enumerate(chord[:2]):
            pad = note(f / 2, beat * 2.05, amp=0.10, attack=0.35, decay=2.2)
            mix_into(buf, pad, int(t0 * SR), 0.9)
        # arpeggio
        f = chord[b % len(chord)]
        arp = note(f * (2 if b % 4 == 2 else 1), beat * 0.9, amp=0.11, attack=0.006, decay=0.55)
        mix_into(buf, arp, int(t0 * SR), 1.0)
        # sparkle on bar starts
        if b % 8 == 0:
            for k, f2 in enumerate(chord[2:]):
                bell = note(f2 * 2, 2.2, amp=0.045, attack=0.004, decay=1.3)
                mix_into(buf, bell, int((t0 + 0.05 + k * 0.09) * SR), 0.8)
        # very soft shaker
        if b % 2 == 1:
            noise = [rng.uniform(-1, 1) * env(i / SR, 0.002, 0.05) * 0.02 for i in range(int(0.09 * SR))]
            mix_into(buf, lowpass(noise, 0.5), int(t0 * SR), 1.0)
    buf = reverb(buf, 0.22)
    # seamless loop: crossfade the tail into the head
    fade = int(0.04 * SR)
    for i in range(fade):
        a = i / fade
        buf[i] = buf[i] * a + buf[-fade + i] * (1 - a)
    buf = buf[:-fade]
    write_wav("bgm_celebration.wav", buf, peak=0.42)


def sfx() -> None:
    rng = random.Random(11)
    # wax crack: filtered noise bursts + low thump
    n = int(0.5 * SR)
    wax = []
    for i in range(n):
        t = i / SR
        crack = 0.0
        for start, amp in ((0.02, 0.9), (0.10, 0.55), (0.19, 0.35)):
            dt = t - start
            if 0 <= dt < 0.06:
                crack += rng.uniform(-1, 1) * math.exp(-dt / 0.012) * amp
        thump = math.sin(2 * math.pi * 110 * t) * env(t, 0.002, 0.09) * 0.5
        wax.append(crack * 0.4 + thump)
    write_wav("sfx_wax.wav", lowpass(wax, 0.6), peak=0.5)

    # pop: pitch-swept blip
    n = int(0.13 * SR)
    pop = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = 520 - 3000 * t
        phase += 2 * math.pi * max(90, f) / SR
        pop.append(math.sin(phase) * env(t, 0.002, 0.045) * 0.7)
    write_wav("sfx_pop.wav", pop, peak=0.34)

    # chime: bell partials
    n = int(0.95 * SR)
    chime = []
    for i in range(n):
        t = i / SR
        s = (
            math.sin(2 * math.pi * 880 * t) * 0.5
            + math.sin(2 * math.pi * 1320 * t) * 0.28
            + math.sin(2 * math.pi * 1760 * t) * 0.16
            + math.sin(2 * math.pi * 2640 * t) * 0.08
        )
        chime.append(s * env(t, 0.004, 0.5, 1.4) * 0.35)
    write_wav("sfx_chime.wav", reverb(chime, 0.35), peak=0.4)

    # whoosh: band-ish noise swell
    n = int(0.65 * SR)
    whoosh = []
    raw = [rng.uniform(-1, 1) for _ in range(n)]
    lp = lowpass(raw, 0.08)
    for i in range(n):
        t = i / SR
        e = math.sin(math.pi * min(1.0, t / 0.65)) ** 1.5
        whoosh.append(lp[i] * e * 0.9)
    write_wav("sfx_whoosh.wav", whoosh, peak=0.3)

    # blow: soft puff of low-passed noise
    n = int(0.4 * SR)
    blow = []
    raw = [rng.uniform(-1, 1) for _ in range(n)]
    lp = lowpass(raw, 0.12)
    for i in range(n):
        t = i / SR
        e = env(t, 0.03, 0.14, 1.2)
        blow.append(lp[i] * e * 0.8)
    write_wav("sfx_blow.wav", blow, peak=0.3)

    # sparkle: quick ascending bells
    n = int(1.4 * SR)
    sparkle = [0.0] * n
    for k, f in enumerate([1046.5, 1318.5, 1568.0, 2093.0, 2637.0]):
        b = note(f, 0.9, amp=0.16, attack=0.003, decay=0.5)
        mix_into(sparkle, b, int((0.02 + k * 0.055) * SR), 1.0)
    write_wav("sfx_sparkle.wav", reverb(sparkle, 0.3), peak=0.42)

    # boom: low impact for confetti (designed to fire after a 200 ms visual cue)
    n = int(0.8 * SR)
    boom = []
    for i in range(n):
        t = i / SR
        s = math.sin(2 * math.pi * (72 - 28 * min(1.0, t / 0.4)) * t) * env(t, 0.003, 0.22, 2.0)
        s += rng.uniform(-1, 1) * env(t, 0.001, 0.05) * 0.18
        boom.append(s)
    write_wav("sfx_boom.wav", lowpass(boom, 0.2), peak=0.5)


if __name__ == "__main__":
    bgm()
    sfx()
