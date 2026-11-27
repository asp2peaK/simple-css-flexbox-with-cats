# Синтез музыки (чиптюн-луп) с нуля, numpy. Наша собственная, без прав третьих лиц.
import numpy as np, wave, sys, os
SR = 22050
OUT = sys.argv[1]
rng = np.random.default_rng(5)

def note_f(n):  # n = полутон от A4
    return 440.0 * 2 ** (n / 12)

def sq(f, d, duty=0.5, vol=1.0):
    t = np.arange(int(SR * d)) / SR
    w = np.where((t * f) % 1.0 < duty, 1.0, -1.0)
    env = np.minimum(1, t / 0.005) * np.exp(-t * 3.0)
    return w * env * vol

def tri(f, d, vol=1.0):
    t = np.arange(int(SR * d)) / SR
    w = 2 * np.abs(2 * ((t * f) % 1.0) - 1) - 1
    env = np.minimum(1, t / 0.005) * np.minimum(1, (d - t) / 0.02 + 0.0)
    return w * np.clip(env, 0, 1) * vol

def hat(d, vol=0.2):
    n = int(SR * d); t = np.arange(n) / SR
    return rng.uniform(-1, 1, n) * np.exp(-t * 60) * vol

def kick(d, vol=0.7):
    t = np.arange(int(SR * d)) / SR
    f = 120 * np.exp(-t * 25) + 45
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9) * vol

def mix_into(buf, x, start):
    s = int(start * SR); e = min(len(buf), s + len(x)); buf[s:e] += x[:e - s]

def song(bpm, chords, melody, name, swing=0.0, drums=True, mvol=0.32):
    beat = 60 / bpm; bars = len(chords); total = bars * 4 * beat
    buf = np.zeros(int(SR * total) + SR)
    for b, ch in enumerate(chords):
        root = ch[0]
        for k in range(8):  # бас восьмыми
            t0 = (b * 4 + k * 0.5) * beat
            n = root - 24 if k % 2 == 0 else root - 12
            mix_into(buf, tri(note_f(n), beat * 0.45, 0.5), t0)
        for k in range(16):  # арпеджио шестнадцатыми
            t0 = (b * 4 + k * 0.25) * beat
            n = ch[k % len(ch)]
            mix_into(buf, sq(note_f(n), beat * 0.22, 0.25, 0.11), t0)
        if drums:
            for k in range(4):
                t0 = (b * 4 + k) * beat
                if k % 2 == 0: mix_into(buf, kick(0.3), t0)
                else: mix_into(buf, hat(0.15, 0.35), t0)
                mix_into(buf, hat(0.05, 0.12), t0 + beat * (0.5 + swing))
    t = 0.0
    for n, dur in melody:  # мелодия: (полутон или None, длительность в долях)
        if n is not None:
            mix_into(buf, sq(note_f(n), beat * dur * 0.9, 0.5, mvol), t * beat)
        t += dur
    buf = buf[:int(SR * total)]
    buf = buf / (np.max(np.abs(buf)) + 1e-9) * 0.7
    data = (buf * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())

# Ля минор, бодро: Am F C G
Am, F, C, G, Dm, E = [0, 3, 7, 12], [-4, 0, 3, 8], [3, 7, 10, 15], [-2, 2, 5, 10], [-7, -4, 0, 5], [-5, -1, 2, 7]
chords = [Am, F, C, G, Am, F, Dm, E] * 2
mel_a = [(12, 1), (15, .5), (14, .5), (12, 1), (10, 1), (8, 1.5), (7, .5), (8, 1), (10, 1),
         (7, 1), (10, .5), (12, .5), (10, 1), (7, 1), (5, 2), (None, 2),
         (12, 1), (15, .5), (14, .5), (12, 1), (17, 1), (15, 1.5), (14, .5), (12, 1), (10, 1),
         (8, 1), (7, 1), (5, 1), (7, 1), (11, 2), (None, 2)]
melody = mel_a + mel_a
song(128, chords, melody, "music_game", swing=0.08)
# Меню: спокойнее, без барабанов
chords_m = [Am, F, C, E] * 2
mel_m = [(12, 2), (10, 1), (8, 1), (7, 3), (None, 1), (8, 2), (10, 1), (12, 1), (11, 3), (None, 1)] * 2
song(84, chords_m, mel_m, "music_menu", drums=False, mvol=0.25)

# --- v0.8: музыка районов, босса, хаоса и пластинки для проигрывателя ---
def gen_melody(chords, seed, rhythm_sets, octave=12):
    r = np.random.default_rng(seed); mel = []
    for ch in chords:
        pat = rhythm_sets[r.integers(len(rhythm_sets))]
        for d in pat:
            if r.random() < 0.12:
                mel.append((None, d))
            else:
                n = ch[r.integers(len(ch))] + octave
                if r.random() < 0.25: n += [2, -1, 1, -2][r.integers(4)]
                mel.append((int(n), d))
    return mel
R1 = [[1, 1, 1, 1], [1.5, .5, 1, 1], [.5, .5, 1, 2], [2, 1, 1], [1, .5, .5, 2]]
R2 = [[.5] * 8, [.5, .5, 1, .5, .5, 1], [1, .5, .5, .5, .5, 1]]
R3 = [[2, 2], [3, 1], [1, 1, 2], [4]]
# Болото: ре минор, вразвалочку
Dm2, Bb, Gm, A7 = [-7, -4, 0, 5], [1, 5, 8, 13], [-2, 1, 5, 10], [0, 4, 7, 10]
ch = [Dm2, Bb, Gm, A7] * 4
song(100, ch, gen_melody(ch, 11, R1), "music_swamp", swing=0.18)
# Кладбище: ми минор, медленно и жутко
Em, C2, Am2, B7 = [-5, -2, 2, 7], [3, 7, 10, 15], [0, 3, 7, 12], [2, 6, 9, 14]
ch = [Em, C2, Am2, B7] * 4
song(88, ch, gen_melody(ch, 23, R3), "music_crypt", drums=True, mvol=0.26)
# Замок: до мажор, марш
Cj, Fj, Gj, Amj = [3, 7, 10, 15], [8, 12, 15, 20], [10, 14, 17, 22], [0, 3, 7, 12]
ch = [Cj, Fj, Gj, Cj, Amj, Fj, Gj, Gj] * 2
song(118, ch, gen_melody(ch, 37, R1, 0), "music_castle")
# Ледяные горы: си минор, звонко
Bm, G2, D2, A2 = [2, 5, 9, 14], [-2, 2, 5, 10], [5, 9, 12, 17], [0, 4, 7, 12]
ch = [Bm, G2, D2, A2] * 4
song(110, ch, gen_melody(ch, 41, R2), "music_ice", mvol=0.24)
# Босс: быстро и тревожно
ch = [Am, [1, 5, 8, 13], Am, E, Dm, [1, 5, 8, 13], E, E] * 2
song(150, ch, gen_melody(ch, 53, R2), "music_boss", swing=0.0)
# Хаос: очень быстро
ch = [Am, G, F, E] * 4
song(165, ch, gen_melody(ch, 61, R2), "music_chaos")
# Пластинки: джаз, лоу-фай, полька
Cmaj7, Am7, Dm7, G7 = [3, 7, 10, 14], [0, 3, 7, 10], [-7, -3, 0, 3], [-2, 2, 5, 8]
ch = [Cmaj7, Am7, Dm7, G7] * 4
song(136, ch, gen_melody(ch, 71, R1), "rec_jazz", swing=0.22, mvol=0.26)
ch = [Cmaj7, Am7, Fj, G7] * 4
song(76, ch, gen_melody(ch, 83, R3), "rec_lofi", drums=True, mvol=0.22)
ch = [Cj, Gj, Gj, Cj, Cj, Fj, Gj, Cj] * 2
song(172, ch, gen_melody(ch, 97, R2, 0), "rec_polka")
print("ok")
