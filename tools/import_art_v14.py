# Листы 64–68 (v0.14): кот, инспектор, владелец и письма, возвраты, значки/крыса/лужа.
import os
import numpy as np
from import_art import load_rgba, find_items, crop_scaled, save, OUT
from import_art_v10 import clean_specks, frames_on_canvas


def part(a, y0, y1):
    b = np.zeros_like(a)
    b[y0:y1] = a[y0:y1]
    return b


def by_height(a, boxes, h):
    return [crop_scaled(a, b, h / (b[3] - b[1])) for b in boxes]


def cat():
    a = load_rgba(64)
    body = clean_specks(part(a, 0, 850))
    it = find_items(body, 2, 3)
    scale = 40.0 / (it[0][3] - it[0][1])  # спящий кот — как старый (40 px)
    names = ["sleep", "wake", "purr", "belly", "stretch", "angry"]
    for n, b in zip(names, it):
        save(crop_scaled(body, b, scale), "props/cat_%s.png" % n)
    save(crop_scaled(body, it[0], scale), "props/cat.png")
    # сердечки розовые, близки к фону: ключ только по точному цвету фона
    from PIL import Image
    from import_art import SRC
    raw = np.array(Image.open(os.path.join(SRC, "sheet64.png")).convert("RGBA"))
    d = np.abs(raw[..., :3].astype(int) - raw[5, 5, :3].astype(int)).sum(2)
    raw[d < 90] = [0, 0, 0, 0]
    small = part(raw, 850, raw.shape[0])
    it2 = find_items(small, 1, 3)
    for n, b, h in zip(["heart_big", "heart_small", "zzz"], it2, [14, 9, 8]):
        save(crop_scaled(small, b, h / (b[3] - b[1])), "fx/%s.png" % n)
    print("cat", len(it), len(it2))


def inspector():
    a = clean_specks(load_rgba(65))
    top = find_items(part(a, 0, 440), 1, 4)
    bot = find_items(part(a, 440, a.shape[0]), 1, 2)
    scale = 92.0 / (top[0][3] - top[0][1])
    fr = frames_on_canvas([crop_scaled(a, b, scale) for b in top + bot])
    # лист 65B: второй шаг (другая нога) спереди и сзади, нарисован крупнее — подгоняем по высоте шага
    from PIL import Image
    from import_art import SRC
    raw = np.array(Image.open(os.path.join(SRC, "sheet65b.png")).convert("RGBA"))
    r, g, bl = raw[..., 0].astype(int), raw[..., 1].astype(int), raw[..., 2].astype(int)
    raw[(np.minimum(r, bl) - g > 70) & (r > 140) & (bl > 140)] = [0, 0, 0, 0]
    raw = clean_specks(raw)
    it2 = find_items(raw, 1, 2)
    extra = [crop_scaled(raw, it2[0], (top[3][3] - top[3][1]) * scale / (it2[0][3] - it2[0][1])),
             crop_scaled(raw, it2[1], (bot[1][3] - bot[1][1]) * scale / (it2[1][3] - it2[1][1]))]
    fr = frames_on_canvas([crop_scaled(a, b, scale) for b in top + bot] + extra)
    for n, f in zip(["idle", "happy", "angry", "walk", "back", "back_walk", "walk2", "back_walk2"], fr):
        save(f, "chars/inspector_%s.png" % n)
    print("inspector", fr[0].shape)


def owner():
    a = clean_specks(load_rgba(66))
    it = find_items(a, 2, 3)
    for k, b in enumerate(it[:3]):
        save(crop_scaled(a, b, 96.0 / (b[3] - b[1])), "ui/owner_%d.png" % k)
    save(crop_scaled(a, it[3], 250.0 / (it[3][3] - it[3][1])), "ui/letter.png")
    save(crop_scaled(a, it[4], 22.0 / (it[4][3] - it[4][1])), "props/envelope.png")
    save(crop_scaled(a, it[5], 28.0 / (it[5][3] - it[5][1])), "props/envelope_open.png")
    print("owner", len(it))


def returns():
    a = load_rgba(67)
    it = find_items(clean_specks(a, 150), 2, 4)
    for n, b in zip(["tear", "stain", "boot", "dent"], it[:4]):
        save(crop_scaled(a, b, 48.0 / max(b[3] - b[1], b[2] - b[0])), "fx/dmg_%s.png" % n)
    for n, b in zip(["stamp_red", "stamp_green"], it[4:6]):
        save(crop_scaled(a, b, 64.0 / (b[2] - b[0])), "ui/%s.png" % n)
    save(crop_scaled(a, it[6], 40.0 / (it[6][3] - it[6][1])), "props/return_form.png")
    save(crop_scaled(a, it[7], 72.0 / (it[7][2] - it[7][0])), "props/returns_tray.png")
    print("returns", len(it))


def icons():
    a = clean_specks(load_rgba(68), 150)
    r1 = find_items(part(a, 0, 360), 1, 4)
    r2 = find_items(part(a, 360, 720), 1, 4)
    r3 = find_items(part(a, 720, a.shape[0]), 1, 4)
    for n, b in zip(["belt", "coffee", "camera", "catbed"], r1):
        save(crop_scaled(a, b, 24.0 / (b[3] - b[1])), "ui/up_%s.png" % n)
    for n, b in zip(["rats", "flood", "mimic", "vip"], r2):
        save(crop_scaled(a, b, 30.0 / (b[3] - b[1])), "ui/ev_%s.png" % n)
    save(crop_scaled(a, r3[0], 40.0 / (r3[0][3] - r3[0][1])), "ui/hardcore.png")
    sc = 22.0 / (r3[1][3] - r3[1][1])
    fr = frames_on_canvas([crop_scaled(a, r3[1], sc), crop_scaled(a, r3[2], sc)])
    save(fr[0], "props/rat_run0.png")
    save(fr[1], "props/rat_run1.png")
    save(crop_scaled(a, r3[3], 80.0 / (r3[3][2] - r3[3][0])), "props/puddle.png")
    print("icons", len(r1), len(r2), len(r3))


if __name__ == "__main__":
    cat(); inspector(); owner(); returns(); icons()
