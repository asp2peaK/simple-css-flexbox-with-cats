# Синтез всех звуков игры с нуля (numpy). Звуки наши собственные, никаких прав третьих лиц.
import numpy as np, wave, sys, os
SR = 22050
OUT = sys.argv[1]
rng = np.random.default_rng(42)

def t(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.005, r=None, curve=4.0):
    x = np.ones(n); na = max(1, int(SR * a)); x[:na] = np.linspace(0, 1, na)
    tail = np.linspace(1, 0, n - na) ** curve; x[na:] *= tail; return x
def lowpass(x, k):  # простой однополюсный ФНЧ
    y = np.zeros_like(x); a = k; acc = 0.0
    for i in range(len(x)): acc += a * (x[i] - acc); y[i] = acc
    return y
def noise(d): return rng.uniform(-1, 1, int(SR * d))
def save(name, x, vol=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * vol
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())

# Удар коробки (картон): шум через ФНЧ + низкий тук
for i, (k, f) in enumerate([(0.08, 90), (0.12, 120), (0.06, 75)]):
    d = 0.22; n = noise(d); tt = t(d)
    thump = np.sin(2 * np.pi * f * tt * (1 - tt * 1.5)) * env(len(tt), 0.002, curve=6)
    save(f"thud{i+1}", lowpass(n, k) * env(len(tt), 0.001, curve=8) * 2.5 + thump * 0.9)
# Взял коробку: короткий шорох картона
d = 0.12; save("pickup", lowpass(noise(d), 0.35) * env(int(SR*d), 0.01, curve=2) , 0.5)
# Бросок: свист (шум с ростом/спадом и сдвигом фильтра)
d = 0.35; n = noise(d); e = np.sin(np.linspace(0, np.pi, len(n))) ** 2
save("whoosh", lowpass(n, 0.05) * 0.4 * e + lowpass(n, 0.2) * e * 0.3, 0.55)
# Бонк в лицо: мультяшный удар с падающей высотой
d = 0.35; tt = t(d); f = 420 * np.exp(-tt * 9) + 110
ph = 2 * np.pi * np.cumsum(f) / SR
save("bonk", (np.sin(ph) + 0.3 * np.sin(2 * ph)) * env(len(tt), 0.001, curve=3) + lowpass(noise(d), 0.3) * env(len(tt), 0.001, curve=14))
# Монетки: два звонких тона
def ding(f, d, decay=6):
    tt = t(d); return (np.sin(2*np.pi*f*tt) + 0.4*np.sin(2*np.pi*f*2.76*tt) + 0.2*np.sin(2*np.pi*f*5.4*tt)) * np.exp(-tt*decay)
c = np.concatenate([ding(1320, 0.08, 20), ding(1760, 0.35, 9)]); save("coin", c, 0.6)
# Колокольчик двери: дзынь-дзынь
b = ding(1050, 0.6, 5) ; b2 = np.concatenate([np.zeros(int(SR*0.14)), ding(1250, 0.7, 5)])
L = max(len(b), len(b2)); bell = np.zeros(L); bell[:len(b)] += b; bell[:len(b2)] += b2; save("doorbell", bell, 0.5)
# Отказ: противный двойной бззз
def buzz(f, d):
    tt = t(d); return np.sign(np.sin(2*np.pi*f*tt)) * 0.6 * env(len(tt), 0.005, curve=1.2)
save("reject", np.concatenate([buzz(140, 0.12), np.zeros(int(SR*0.05)), buzz(110, 0.2)]), 0.45)
# Прыжок проклятой коробки: пружинистый «бойнг»
d = 0.4; tt = t(d); f = 180 + 260 * np.abs(np.sin(tt * 28)) * np.exp(-tt * 5)
save("boing", np.sin(2*np.pi*np.cumsum(f)/SR) * env(len(tt), 0.003, curve=2), 0.5)
# Шаг: мягкий глухой стук
for i, k in enumerate([0.05, 0.07]):
    d = 0.09; save(f"step{i+1}", lowpass(noise(d), k) * env(int(SR*d), 0.002, curve=5), 0.35)
# Конец смены: короткий джингл
mel = [523, 659, 784, 1047]; s = np.concatenate([ding(f, 0.18 if i < 3 else 0.7, 7) for i, f in enumerate(mel)]); save("shift_end", s, 0.55)
# Голоса: бормотание-«блипы» (как в Animal Crossing), разная высота на каждого
def voice(base, n_syll, rate, rough=0.0, angry=False):
    out = []
    for i in range(n_syll):
        d = rate * rng.uniform(0.7, 1.3); tt = t(d)
        f = base * rng.uniform(0.85, 1.25) * (1 + 0.15 * np.sin(tt * 30))
        ph = 2*np.pi*np.cumsum(f)/SR
        w = np.sin(ph) + 0.5*np.sin(2*ph) + 0.25*np.sin(3*ph)
        if angry: w = np.tanh(w * 3)
        if rough: w += rough * lowpass(noise(d), 0.3)
        out.append(w * env(len(tt), 0.01, curve=1.5)); out.append(np.zeros(int(SR * rate * 0.25)))
    return np.concatenate(out)
for kind, base, rate, rough in [("witch", 520, 0.07, 0.15), ("orc", 110, 0.11, 0.5), ("skeleton", 300, 0.06, 0.6), ("goblin", 750, 0.05, 0.05), ("vampire", 220, 0.09, 0.1), ("dragon", 160, 0.08, 0.7), ("ghost", 420, 0.12, 0.9), ("dwarf", 180, 0.07, 0.3), ("thief", 600, 0.045, 0.2), ("king", 330, 0.1, 0.05), ("troll", 280, 0.06, 0.4), ("werewolf", 190, 0.08, 0.5), ("giant", 85, 0.14, 0.4)]:
    save(f"voice_{kind}", voice(base, 6, rate, rough), 0.5)
    save(f"angry_{kind}", voice(base * 0.8, 5, rate * 0.9, rough + 0.2, True), 0.55)
# Фон: гул склада (луп, 4 сек): низкий гул ламп + тихий шум
d = 4.0; tt = t(d)
hum = 0.5*np.sin(2*np.pi*50*tt) + 0.25*np.sin(2*np.pi*100*tt) + 0.1*np.sin(2*np.pi*150*tt)
amb = hum * 0.25 + lowpass(noise(d), 0.02) * 1.5
fade = int(SR * 0.05); amb[:fade] *= np.linspace(0, 1, fade); amb[-fade:] *= np.linspace(1, 0, fade)
save("ambient", amb, 0.25)
# Взрыв: низкий бум + шумовой хвост
d = 1.2; tt = t(d); f = 90 * np.exp(-tt * 3) + 30
boom = np.sin(2*np.pi*np.cumsum(f)/SR) * np.exp(-tt * 4) + lowpass(noise(d), 0.08) * np.exp(-tt * 3) * 2.5
save("boom", boom, 0.9)
# Хруст хрупкой посылки: серия коротких щелчков
cr = np.zeros(int(SR * 0.3))
for k in range(9):
    pos = int(rng.uniform(0, 0.22) * SR); L = int(SR * 0.012)
    cr[pos:pos + L] += rng.uniform(-1, 1, L) * np.linspace(1, 0, L) * rng.uniform(0.4, 1.0)
save("crack", cr, 0.7)
print("ok")
# --- v0.6 ---
# Тиканье таймера: короткий щелчок
d = 0.05; tt = t(d); save("tick", (np.sin(2*np.pi*2400*tt) * np.exp(-tt*120) + lowpass(noise(d), 0.5) * np.exp(-tt*200)), 0.5)
# Портал: восходящий вжух с мерцанием
d = 0.9; tt = t(d); f = 200 + 900 * tt / d + 60 * np.sin(tt * 40)
save("portal", np.sin(2*np.pi*np.cumsum(f)/SR) * np.sin(np.linspace(0, np.pi, len(tt))) + lowpass(noise(d), 0.08) * 0.4, 0.45)
# Укус мимика: клац
d = 0.18; tt = t(d); save("bite", lowpass(noise(d), 0.6) * np.exp(-tt*40) + np.sin(2*np.pi*180*tt) * np.exp(-tt*25), 0.7)
# Кнопка «ВОН»: клик + сирена-вяк
d = 0.4; tt = t(d); f = 600 + 300 * np.sin(tt * 30)
save("kick", np.concatenate([lowpass(noise(0.03), 0.7), np.sign(np.sin(2*np.pi*np.cumsum(f)/SR)) * 0.4 * env(len(tt), 0.01, curve=1.5)]), 0.45)
# Крышка морозилки: скрип + глухой стук
d = 0.35; tt = t(d); f = 300 + 80 * np.sin(tt * 60)
save("lid", np.sin(2*np.pi*np.cumsum(f)/SR) * 0.3 * env(len(tt), 0.05, curve=1) + lowpass(noise(d), 0.1) * np.exp(-tt*10), 0.5)
