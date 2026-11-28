# Своя музыка для трейлера (не повторяет игровые треки). numpy, 44.1 кГц, стерео.
# 120 BPM: такт = 2 с, всего 41 такт = 82 с. Разделы подогнаны под монтаж tools/steam_media/trailer.py:
#   0-3 вступление (тихо), 4-15 тема A (барабаны), 16-24 тема B (мажор, кооп/кот/крысы),
#   25-38 кульминация (хаос, босс), 39-40 финал + хвост.
import numpy as np, wave, sys

SR = 44100
BPM = 120
BEAT = 60 / BPM
BAR = BEAT * 4
BARS = 41
TAIL = 3.0
OUT = sys.argv[1] if len(sys.argv) > 1 else "trailer_music.wav"
rng = np.random.default_rng(14)
L = np.zeros(int(SR * (BARS * BAR + TAIL)))
R = np.zeros_like(L)


def f(n):  # полутон от A4
    return 440.0 * 2 ** (n / 12)


def env_adsr(n, a=0.005, d=0.1, s=0.6, r=0.05):
    t = np.arange(n) / SR
    dur = n / SR
    e = np.where(t < a, t / a, np.where(t < a + d, 1 - (1 - s) * (t - a) / d, s))
    return e * np.clip((dur - t) / r, 0, 1)


def osc(kind, fr, d, duty=0.5, vib=0.0):
    n = int(SR * d)
    t = np.arange(n) / SR
    ph = np.cumsum(fr * (1 + vib * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.25))) / SR
    if kind == "sq":
        return np.where(ph % 1 < duty, 1.0, -1.0)
    if kind == "tri":
        return 2 * np.abs(2 * (ph % 1) - 1) - 1
    if kind == "saw":
        return 2 * (ph % 1) - 1
    return np.sin(2 * np.pi * ph)


def put(x, t0, vol=1.0, pan=0.0):
    s = int(t0 * SR)
    e = min(len(L), s + len(x))
    if e <= s:
        return
    L[s:e] += x[:e - s] * vol * (1 - pan) / 2 * 2 ** 0.5
    R[s:e] += x[:e - s] * vol * (1 + pan) / 2 * 2 ** 0.5


def kick(t0, v=0.9):
    t = np.arange(int(SR * 0.35)) / SR
    fr = 150 * np.exp(-t * 30) + 42
    put(np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t * 8), t0, v)


def snare(t0, v=0.45):
    n = int(SR * 0.22)
    t = np.arange(n) / SR
    x = rng.uniform(-1, 1, n) * np.exp(-t * 18) + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30) * 0.6
    put(x, t0, v)


def hat(t0, v=0.12, pan=0.3, open_=False):
    n = int(SR * (0.25 if open_ else 0.05))
    t = np.arange(n) / SR
    x = rng.uniform(-1, 1, n)
    x = np.diff(x, prepend=0)  # ярче
    put(x * np.exp(-t * (12 if open_ else 70)), t0, v, pan)


def crash(t0, v=0.25):
    n = int(SR * 1.8)
    t = np.arange(n) / SR
    x = np.diff(rng.uniform(-1, 1, n), prepend=0)
    put(x * np.exp(-t * 2.2), t0, v, -0.2)


# аккорды (полутоны от A4): ля минор / до мажор
Am, F, C, G, Dm, E = [0, 3, 7], [-4, 0, 3], [3, 7, 10], [-2, 2, 5], [-7, -4, 0], [-5, -1, 2]
Fmaj, Gmaj, Cmaj, Emaj = [-4, 0, 3], [-2, 2, 5], [3, 7, 10], [-5, -1, 2]
prog_a = [Am, F, C, G]
prog_b = [F, G, C, Am, F, G, E, E]
prog_c = [Am, Am, F, F, Dm, Dm, E, E]

chords = []
chords += [Am, F, C, E]                       # 0-3 вступление
chords += prog_a * 3                          # 4-15 тема A
chords += prog_b + [E]                        # 16-24 тема B
chords += prog_c + [Am, F, Dm, E, E, E]       # 25-38 кульминация
chords += [Am, Am]                            # 39-40 финал

# тема: мотив на 2 такта (доли), повторяется с вариациями
motif = [(12, 1), (15, .5), (14, .5), (12, .5), (10, .5), (12, 1),
         (7, 1.5), (8, .5), (10, 1), (7, 1)]
motif2 = [(12, 1), (15, .5), (17, .5), (19, 1), (17, .5), (15, .5),
          (14, 1), (12, .5), (14, .5), (11, 2)]
motif_b = [(15, 1.5), (14, .5), (12, 1), (10, 1), (12, 2), (7, 2),
           (15, 1.5), (17, .5), (19, 1), (17, 1), (14, 4)]
motif_c = [(12, .5), (12, .5), (15, .5), (12, .5), (17, .5), (15, .5), (14, .5), (12, .5)] * 2


def melody(seq, start_bar, vol=0.16, kind="sq", duty=0.5, oct_=0, pan=-0.15):
    t = start_bar * BAR
    for n, d in seq:
        if n is not None:
            x = osc(kind, f(n + oct_), d * BEAT * 0.92, duty, vib=0.006) * env_adsr(int(SR * d * BEAT * 0.92), d=0.15, s=0.7, r=0.04)
            put(x, t, vol, pan)
            # эхо
            put(x * 0.35, t + BEAT * 0.75, vol, -pan)
        t += d * BEAT


for b, ch in enumerate(chords):
    t0 = b * BAR
    sec = "intro" if b < 4 else "a" if b < 16 else "b" if b < 25 else "c" if b < 39 else "end"
    root = ch[0]
    # пэд (мягкая пила, на всех разделах)
    for k, n in enumerate(ch):
        x = osc("saw", f(n - 12), BAR, vib=0.002) * env_adsr(int(SR * BAR), a=0.25, d=0.3, s=0.8, r=0.3)
        x = np.convolve(x, np.ones(18) / 18, mode="same")  # тише верх
        put(x, t0, 0.05 if sec != "intro" else 0.07, [-0.5, 0, 0.5][k % 3])
    # арпеджио шестнадцатыми
    if sec in ("intro", "a", "b", "c"):
        for k in range(16):
            n = ch[k % 3] + (12 if k % 8 >= 4 else 0)
            x = osc("sq", f(n), BEAT * 0.2, 0.25) * env_adsr(int(SR * BEAT * 0.2), d=0.05, s=0.3)
            put(x, t0 + k * BEAT / 4, 0.045 if sec == "intro" else 0.06, 0.4 if k % 2 else -0.4)
    # бас
    if sec != "intro":
        step = 0.5 if sec != "c" else 0.25
        for k in range(int(4 / step)):
            n = root - 24 + (12 if (k % 2 and sec == "c") else 0)
            x = osc("tri", f(n), BEAT * step * 0.85) * env_adsr(int(SR * BEAT * step * 0.85), s=0.9)
            put(x, t0 + k * step * BEAT, 0.42)
    # барабаны
    if sec in ("a", "b", "c"):
        for k in range(4):
            tb = t0 + k * BEAT
            if k in (0, 2) or (sec == "c"):
                kick(tb, 0.85 if k in (0, 2) else 0.6)
            if k in (1, 3):
                snare(tb)
            hat(tb + BEAT / 2, 0.11)
            if sec == "c":
                hat(tb + BEAT / 4, 0.07, -0.3)
                hat(tb + 3 * BEAT / 4, 0.07, -0.3)
        if b in (15, 24, 38):  # сбивка перед новым разделом
            for k in range(4):
                snare(t0 + 3 * BEAT + k * BEAT / 4, 0.25 + k * 0.08)
    if b in (4, 16, 25, 39):
        crash(t0)
    if sec == "intro" and b == 3:
        for k in range(8):
            hat(t0 + 2 * BEAT + k * BEAT / 4, 0.03 + k * 0.012)

# мелодии по разделам
melody([(None, 8)] + [(12, 2), (10, 1), (8, 1), (7, 4)], 0, 0.10, "tri", oct_=0)       # вступление
for i in range(3):
    melody(motif + motif2, 4 + i * 4, 0.15)
melody(motif_b * 2, 16, 0.15, duty=0.25, oct_=0)
melody(motif_c * 3 + motif + motif2 + [(12, 4), (15, 4)], 25, 0.13, duty=0.25)
melody(motif + [(12, 4)], 39, 0.16)
# финальный аккорд звенит
for n in [0, 3, 7, 12]:
    put(osc("sq", f(n + 12), 3.0, 0.5, vib=0.004) * np.exp(-np.arange(int(SR * 3.0)) / SR * 1.3), 40 * BAR + BEAT * 2, 0.06)
kick(40 * BAR + BEAT * 2, 1.0)
crash(40 * BAR + BEAT * 2, 0.3)

# мастер: мягкий лимитер и плавный хвост
mx = max(np.max(np.abs(L)), np.max(np.abs(R)))
L = np.tanh(L / mx * 1.6) / np.tanh(1.6) * 0.85
R = np.tanh(R / mx * 1.6) / np.tanh(1.6) * 0.85
n = len(L)
fade = np.ones(n)
fade[-int(SR * 1.0):] = np.linspace(1, 0, int(SR * 1.0))
L *= fade
R *= fade
data = np.empty(n * 2, dtype=np.int16)
data[0::2] = (L * 32767).astype(np.int16)
data[1::2] = (R * 32767).astype(np.int16)
with wave.open(OUT, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(data.tobytes())
print(OUT, round(n / SR, 1), "s")
