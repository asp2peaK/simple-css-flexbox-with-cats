# Звуки v0.14: кот (мур, шипение, мяу), возвраты (штамп), записки (бумага), редкие события. numpy, свои.
import numpy as np, wave, sys, os
SR = 22050
OUT = sys.argv[1]
rng = np.random.default_rng(14)
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
noise = lambda n: rng.uniform(-1, 1, n)

# мурчание: низкий рокот 25 Гц-импульсами, вдох-выдох
d = 1.6; tt = t(d)
pulses = (np.sin(2 * np.pi * 24 * tt) > 0.3).astype(float)
src = lp(noise(len(tt)), 0.08) * pulses + np.sin(2 * np.pi * 48 * tt) * 0.3 * pulses
breath = 0.55 + 0.45 * np.sin(np.pi * tt / (d / 2)) ** 2
save("purr", src * breath * np.minimum(1, tt / 0.1) * np.minimum(1, (d - tt) / 0.2), 0.55)

# шипение: шум, высокие частоты
d = 0.6; tt = t(d)
n = noise(len(tt)); hs = n - lp(n, 0.3)
save("hiss", hs * np.minimum(1, tt / 0.03) * np.exp(-tt * 3), 0.5)

# мяу: гласная с подъёмом и спадом высоты
d = 0.45; tt = t(d)
f = 520 + 380 * np.sin(np.pi * tt / d) ** 1.5
ph = 2 * np.pi * np.cumsum(f) / SR
src = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph)
e = np.sin(np.pi * tt / d) ** 0.7
save("meow", lp(src * e, 0.35), 0.5)

# штамп: глухой удар + короткий щелчок
d = 0.25; tt = t(d)
thud = np.sin(2 * np.pi * 90 * tt) * np.exp(-tt * 25) + lp(noise(len(tt)), 0.2) * np.exp(-tt * 60)
save("stamp", thud, 0.8)

# бумага: шорох
d = 0.5; tt = t(d)
n = noise(len(tt)); hp = n - lp(n, 0.5)
env = np.abs(np.sin(2 * np.pi * 5 * tt)) * np.minimum(1, (d - tt) / 0.1)
save("paper", hp * env * (0.6 + 0.4 * noise(len(tt)) ** 2), 0.45)

# событие: короткая фанфара-тревога
parts = []
for fr in [660, 880, 660, 990]:
    tt = t(0.12)
    parts.append((np.sign(np.sin(2 * np.pi * fr * tt)) * 0.4 + np.sin(2 * np.pi * fr * tt)) * np.exp(-tt * 8))
save("event", np.concatenate(parts), 0.45)

# всплеск воды
d = 0.7; tt = t(d)
n = noise(len(tt))
bub = sum(np.sin(2 * np.pi * (300 + 600 * rng.random()) * tt * (1 + 2 * tt)) * np.exp(-((tt - rng.random() * 0.4) ** 2) * 400) for _ in range(8))
save("splash", lp(n, 0.4) * np.exp(-tt * 6) + bub * 0.3, 0.6)

# писк сканера
tt = t(0.12)
save("beep", np.sin(2 * np.pi * 1760 * tt) * np.minimum(1, (0.12 - tt) / 0.02), 0.35)

# кофемашина: бульканье и пар
d = 1.0; tt = t(d)
n = noise(len(tt))
save("coffee", (n - lp(n, 0.4)) * 0.4 * np.minimum(1, tt / 0.3) + np.sin(2 * np.pi * 70 * tt) * (np.sin(2 * np.pi * 9 * tt) > 0.6) * 0.5, 0.45)

# касса улучшения
parts = []
for fr in [1320, 1760]:
    tt = t(0.14)
    parts.append(np.sin(2 * np.pi * fr * tt) * np.exp(-tt * 12))
save("upgrade", np.concatenate(parts), 0.5)
