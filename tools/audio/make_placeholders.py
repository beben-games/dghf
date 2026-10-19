#!/usr/bin/env python3
"""Makes the placeholder sounds and the music loop (issue #65), team-made, so
nothing needs a licence: short synthesized cues for hits, blocks, swings, a
fireball, a death, a pick-up, a barrel and the dash, and a sixteen-second
loop in A minor. Pure Python; oggenc (or ffmpeg) turns the WAVs into OGG.

    python3 tools/audio/make_placeholders.py

Rerun it after changing a cue; the OGGs in assets/ are what the game loads."""
import math
import os
import random
import shutil
import struct
import subprocess
import tempfile
import wave

RATE = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
random.seed(5)


def env(t, attack, decay):
    """A fast rise and an exponential fall, 0 to 1."""
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


def render(seconds, fn):
    n = int(RATE * seconds)
    out = []
    for i in range(n):
        t = i / RATE
        out.append(max(-1.0, min(1.0, fn(t))))
    return out


def lowpass(samples, cutoff_fn):
    """A one-pole low-pass whose cutoff may move over time."""
    out = []
    y = 0.0
    for i, x in enumerate(samples):
        c = cutoff_fn(i / RATE)
        a = 1.0 - math.exp(-2.0 * math.pi * c / RATE)
        y += a * (x - y)
        out.append(y)
    return out


def noise():
    return random.uniform(-1.0, 1.0)


def swing():
    s = render(0.18, lambda t: noise() * env(t, 0.01, 0.05))
    return lowpass(s, lambda t: 600 + 4000 * (1.0 - t / 0.18))


def dash():
    s = render(0.16, lambda t: noise() * env(t, 0.03, 0.06))
    return lowpass(s, lambda t: 300 + 3000 * t / 0.16)


def hit():
    def f(t):
        pitch = 180 * math.exp(-t * 20) + 50
        return 0.9 * math.sin(2 * math.pi * pitch * t * 4) * env(t, 0.002, 0.05) + 0.5 * noise() * env(t, 0.001, 0.02)
    return render(0.14, f)


def hit_heavy():
    def f(t):
        pitch = 110 * math.exp(-t * 12) + 35
        return 1.0 * math.sin(2 * math.pi * pitch * t * 3) * env(t, 0.003, 0.09) + 0.6 * noise() * env(t, 0.001, 0.04)
    return render(0.28, f)


def block():
    def f(t):
        ring = sum(math.sin(2 * math.pi * hz * t) * w for hz, w in [(1210, 0.5), (1830, 0.3), (2740, 0.2)])
        return ring * env(t, 0.002, 0.04) + 0.5 * noise() * env(t, 0.001, 0.01)
    return render(0.16, f)


def guard_break():
    def f(t):
        thump = math.sin(2 * math.pi * (70 * math.exp(-t * 6) + 30) * t * 2) * env(t, 0.004, 0.14)
        ring = math.sin(2 * math.pi * 640 * t) * env(t, 0.01, 0.2) * 0.4
        return 0.9 * thump + ring + 0.5 * noise() * env(t, 0.001, 0.05)
    return render(0.55, f)


def fireball():
    s = render(0.4, lambda t: noise() * env(t, 0.03, 0.15) + 0.3 * math.sin(2 * math.pi * (300 + 600 * t) * t) * env(t, 0.02, 0.1))
    return lowpass(s, lambda t: 400 + 3000 * t / 0.4)


def death():
    def f(t):
        pitch = 380 * math.exp(-t * 5) + 90
        return 0.6 * math.sin(2 * math.pi * pitch * t) * env(t, 0.01, 0.12) + 0.4 * noise() * env(t, 0.001, 0.06)
    return render(0.32, f)


def pickup():
    def f(t):
        hz = 660 if t < 0.1 else 990
        return 0.5 * math.sin(2 * math.pi * hz * t) * env(t % 0.1 if t < 0.2 else 0.1, 0.005, 0.05)
    return render(0.26, f)


def barrel():
    clicks = sorted(random.uniform(0.0, 0.25) for _ in range(14))

    def f(t):
        v = 0.7 * math.sin(2 * math.pi * (90 * math.exp(-t * 10) + 40) * t * 2) * env(t, 0.003, 0.08)
        for c in clicks:
            if 0 <= t - c < 0.006:
                v += 0.6 * noise()
        return v
    return render(0.34, f)


def music():
    """Eight bars at 120 bpm in A minor: a kick, a hat, a bass and a slow lead."""
    bpm = 120
    beat = 60.0 / bpm
    bars = 8
    length = bars * 4 * beat
    chords = [(55.0, 220.0), (65.41, 261.6), (49.0, 196.0), (41.2, 164.8)]  # A, C, G, E: bass and lead roots
    lead_notes = [220.0, 261.6, 246.9, 220.0, 196.0, 164.8, 196.0, 220.0]

    def f(t):
        b = t / beat
        bar = int(b // 4) % bars
        in_beat = b % 1.0
        chord = chords[bar // 2 % 4]
        kick = math.sin(2 * math.pi * (120 * math.exp(-in_beat * 18) + 45) * in_beat) * env(in_beat * beat, 0.003, 0.08)
        hat = noise() * env(((b + 0.5) % 1.0) * beat, 0.001, 0.015) * 0.25
        bass_t = (b % 0.5) * beat
        bass = (1.0 if math.sin(2 * math.pi * chord[0] * t) > 0 else -1.0) * 0.18 * env(bass_t, 0.005, 0.12)
        lead_hz = lead_notes[bar]
        lead = (2.0 / math.pi) * math.asin(math.sin(2 * math.pi * lead_hz * t)) * 0.12 * (0.6 + 0.4 * math.sin(2 * math.pi * 0.25 * t))
        return 0.8 * kick + hat + bass + lead
    return render(length, f)


def write(name, samples, folder):
    path = os.path.join(tempfile.gettempdir(), name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * 32000)) for s in samples))
    out = os.path.join(ROOT, "assets", folder, name + ".ogg")
    if shutil.which("oggenc"):
        subprocess.run(["oggenc", "-Q", "-q", "4", "-o", out, path], check=True)
    else:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "vorbis", "-strict", "-2", "-q:a", "4", out], check=True)
    os.remove(path)
    print("wrote", os.path.relpath(out, ROOT))


if __name__ == "__main__":
    for name, fn in [("swing", swing), ("dash", dash), ("hit", hit), ("hit_heavy", hit_heavy), ("block", block),
                     ("guard_break", guard_break), ("fireball", fireball), ("death", death), ("pickup", pickup), ("barrel", barrel)]:
        write(name, fn(), "sfx")
    write("placeholder_loop", music(), "music")
