# Звуки для кооп-фишек (хрюк, муу, «звёздочки», проклятие, сирена перегруза). Наши собственные, numpy.
import numpy as np, wave, sys, os
SR = 22050
OUT = sys.argv[1]
rng = np.random.default_rng(7)
def t(d): return np.arange(int(SR * d)) / SR
def save(name, x, vol=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * vol
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())
def lp(x, k):
    y = np.zeros_like(x); acc = 0.0
    for i in range(len(x)): acc += k * (x[i] - acc); y[i] = acc
    return y

# хрюк: короткий гнусавый звук с шумом, частота падает
d = 0.22; tt = t(d)
f = 190 - 60 * tt / d
ph = 2 * np.pi * np.cumsum(f) / SR
src = np.sign(np.sin(ph)) * 0.5 + np.sin(2 * ph) * 0.3 + rng.uniform(-1, 1, len(tt)) * 0.35
e = np.sin(np.linspace(0, np.pi, len(tt))) ** 0.6 * (1 + 0.5 * np.sin(2 * np.pi * 28 * tt))
save("oink", lp(src * e, 0.25), 0.6)

# муу: низкий гул с плавным подъёмом и спадом
d = 1.0; tt = t(d)
f = 110 + 40 * np.sin(np.pi * tt / d) ** 2
ph = 2 * np.pi * np.cumsum(f) / SR
src = sum(np.sin(k * ph) / k for k in range(1, 9))
e = np.minimum(1, tt / 0.12) * np.minimum(1, (d - tt) / 0.3)
save("moo", lp(src * e, 0.12) + lp(rng.uniform(-1, 1, len(tt)), 0.05) * e * 0.3, 0.65)

# головокружение: щебет-колокольчики по кругу
parts = []
for i, fr in enumerate([1800, 2400, 2000, 2700, 2200]):
    tt = t(0.11)
    parts.append(np.sin(2 * np.pi * fr * tt) * np.exp(-tt * 30) * (1 + 0.3 * np.sin(2 * np.pi * 40 * tt)))
save("dizzy", np.concatenate(parts), 0.45)

# проклятие: зловещий нисходящий аккорд
d = 0.9; tt = t(d)
x = sum(np.sin(2 * np.pi * np.cumsum(fr * (1 - 0.35 * tt / d)) / SR) for fr in [440, 466, 622])
save("curse", x * np.exp(-tt * 2.5) * np.minimum(1, tt / 0.03), 0.5)

# сирена перегруза портала
d = 1.6; tt = t(d)
f = 600 + 300 * np.sin(2 * np.pi * 2.5 * tt)
save("siren", np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.4 * np.minimum(1, (d - tt) / 0.2), 0.35)

# удар по напарнику: «бдыщ»
d = 0.3; tt = t(d)
x = np.sin(2 * np.pi * np.cumsum(220 - 150 * tt / d) / SR) * np.exp(-tt * 12) + lp(rng.uniform(-1, 1, len(tt)), 0.5) * np.exp(-tt * 30)
save("bonk_player", x, 0.8)

# голосование: короткий «пинг»
tt = t(0.25)
save("vote", np.sin(2 * np.pi * 1320 * tt) * np.exp(-tt * 14) + np.sin(2 * np.pi * 1980 * tt) * np.exp(-tt * 18) * 0.5, 0.5)
