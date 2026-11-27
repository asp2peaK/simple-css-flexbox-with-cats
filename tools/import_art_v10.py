# Нарезка листов 47-56 (Мага, Королева Мышей, персонажи игроков, шапки, аксессуары, зеркало).
# Запуск: python3 tools/import_art_v10.py  (из корня проекта)
import os, sys, json
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_art import load_rgba, find_items, crop_scaled, save, OUT, SRC


def clean_specks(a, min_px=400):
    """Убираем мелкие отдельные пятна (линии движения и т.п.) — простая заливка компонент."""
    fg = a[..., 3] > 0
    h, w = fg.shape
    seen = np.zeros_like(fg)
    for y0 in range(0, h, 2):
        for x0 in range(0, w, 2):
            if fg[y0, x0] and not seen[y0, x0]:
                stack = [(y0, x0)]; seen[y0, x0] = True; comp = []
                while stack:
                    y, x = stack.pop(); comp.append((y, x))
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < h and 0 <= nx < w and fg[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True; stack.append((ny, nx))
                if len(comp) < min_px:
                    ys, xs = zip(*comp)
                    a[list(ys), list(xs)] = 0
    return a


def frames_on_canvas(frames):
    W = max(f.shape[1] for f in frames) + 2
    H = max(f.shape[0] for f in frames) + 1
    out = []
    for f in frames:
        c = np.zeros((H, W, 4), np.uint8)
        x = (W - f.shape[1]) // 2; y = H - f.shape[0]
        c[y:y + f.shape[0], x:x + f.shape[1]] = f
        out.append(c)
    return out


def char8(sheet, kind, target_h):
    a = load_rgba(sheet)
    if sheet == 47:
        # розовые наушники Маги близки к фону: возвращаем пиксели, где красный заметно больше синего
        raw = np.array(Image.open(os.path.join(SRC, "sheet%02d.png" % sheet)).convert("RGBA"))
        r, b = raw[..., 0].astype(int), raw[..., 2].astype(int)
        keep = (a[..., 3] == 0) & (r - b > 35) & (r > 150)
        a[keep] = raw[keep]
    a = clean_specks(a)
    it = find_items(a, 2, 4)
    scale = target_h / (it[0][3] - it[0][1])
    fr = frames_on_canvas([crop_scaled(a, b, scale) for b in it])
    for name, f in zip(["idle", "walk", "walk2", "happy", "angry", "back", "back_walk", "back_walk2"], fr):
        save(f, "chars/%s_%s.png" % (kind, name))


# ---- игроки
SKINS = {  # раса: [исходный цвет кожи берётся с картинки, целевые базовые цвета 3 оттенков]
    "human": [(246, 196, 160), (196, 140, 98), (122, 80, 54)],
    "goblin": [(140, 196, 70), (196, 190, 80), (80, 160, 150)],
    "orc": [(150, 170, 110), (170, 110, 80), (100, 104, 100)],
}
HEIGHTS = {"human": 92, "goblin": 80, "orc": 100}
VIEWS = ["front", "side", "back"]
POSES = ["idle", "walk", "walk2", "carry"]


def skin_mask(f):
    r, g, b = [f[..., i].astype(int) for i in range(3)]
    return r, g, b


def detect_skin(fr, race):
    """Цвет кожи: самый частый цвет в верхней трети фронтального кадра, не волосы и не обводка."""
    f = fr[0]
    h = f.shape[0]
    top = f[: h // 3]
    px = top[top[..., 3] > 0][:, :3].astype(int)
    lum = px.sum(1)
    px = px[(lum > 250)]
    if race == "human":
        px = px[(px[:, 0] > px[:, 2] + 40)]
    else:
        px = px[(px[:, 1] > px[:, 2] + 30)]
    q = (px // 16) * 16 + 8
    keys, counts = np.unique(q, axis=0, return_counts=True)
    return keys[np.argmax(counts)]


def is_skin(f, ref):
    rgb = f[..., :3].astype(int)
    # оттенок близок к коже: отношения каналов как у ref, яркость может отличаться (тень)
    s = rgb.sum(2) + 1
    rs = ref.sum() + 1
    d = np.abs(rgb[..., 0] / s - ref[0] / rs) + np.abs(rgb[..., 1] / s - ref[1] / rs) + np.abs(rgb[..., 2] / s - ref[2] / rs)
    bright = (s > rs * 0.45) & (s < rs * 1.35)
    return (d < 0.06) & bright & (f[..., 3] > 0)


def is_apron(f):
    r, g, b = [f[..., i].astype(int) for i in range(3)]
    return (g > 120) & (b > 120) & (r < 120) & (b - r > 80) & (f[..., 3] > 0)


def head_info(f):
    """Верх головы, центр головы по x и низ головы (самая узкая строка — шея)."""
    al = f[..., 3] > 0
    rows = np.where(al.any(1))[0]
    top = rows[0]; h = rows[-1] - top
    widths = [al[y].sum() for y in range(top, top + int(h * 0.45))]
    # шея: минимум ширины после первых 15% высоты
    start = int(h * 0.15)
    neck = top + start + int(np.argmin(widths[start:]))
    xs = np.where(al[top:neck].any(0))[0]
    cx = float(np.mean(np.where(al[top + 2:neck])[1])) if neck > top + 2 else f.shape[1] / 2
    return {"top": int(top), "neck": int(neck), "cx": round(cx, 1), "w": int(xs[-1] - xs[0] + 1) if len(xs) else 20}


def players(meta):
    for sheet, race in [(50, "human"), (51, "goblin"), (52, "orc")]:
        a = clean_specks(load_rgba(sheet))
        it = find_items(a, 3, 4)
        scale = HEIGHTS[race] / (it[0][3] - it[0][1])
        fr = frames_on_canvas([crop_scaled(a, b, scale) for b in it])
        ref = detect_skin(fr, race)
        meta[race] = {"h": fr[0].shape[0], "w": fr[0].shape[1], "frames": {}}
        for i, f in enumerate(fr):
            name = "%s_%s" % (VIEWS[i // 4], POSES[i % 4])
            meta[race]["frames"][name] = head_info(f)
            ap = is_apron(f)
            sk = is_skin(f, ref)
            # слой фартука: серый по яркости, красится в игре
            apron = np.zeros_like(f)
            lum = f[..., :3].astype(float).mean(2)
            norm = np.clip(lum / max(1.0, lum[ap].max() if ap.any() else 1.0) * 255, 0, 255).astype(np.uint8)
            apron[ap, 0] = norm[ap]; apron[ap, 1] = norm[ap]; apron[ap, 2] = norm[ap]; apron[ap, 3] = 255
            save(apron, "players/%s_%s_apron.png" % (race, name))
            for si, tgt in enumerate(SKINS[race]):
                out = f.copy()
                out[ap] = 0
                if si > 0:
                    k = f[..., :3].astype(float)[sk] / np.maximum(1, ref.astype(float))
                    out[sk, :3] = np.clip(k * np.array(tgt, float), 0, 255).astype(np.uint8)
                save(out, "players/%s_%d_%s.png" % (race, si, name))
        meta[race]["skin_ref"] = [int(v) for v in ref]


# ---- шапки и аксессуары: ширина относительно ширины головы человека (~ px), sink — насколько уходит на голову
HATS1 = ["postal", "wizard", "crown", "beanie", "viking", "chef"]
HATS2 = ["propeller", "cowboy", "bandana", "headphones", "flowers", "mouse_ears"]
FACE = ["glasses", "sunglasses", "eyepatch", "mustache", "scarf", "bowtie"]
HAT_W = {"postal": 1.05, "wizard": 1.1, "crown": 0.75, "beanie": 1.0, "viking": 1.35, "chef": 1.05,
         "propeller": 1.0, "cowboy": 1.55, "bandana": 1.05, "headphones": 1.2, "flowers": 1.05, "mouse_ears": 1.15}
FACE_W = {"glasses": 0.85, "sunglasses": 0.85, "eyepatch": 0.85, "mustache": 0.6, "scarf": 1.15, "bowtie": 0.45}


def accessories(meta, head_w):
    acc = {}
    for sheet, names, nviews in [(53, HATS1, 3), (54, HATS2, 3), (55, FACE, 2)]:
        a = clean_specks(load_rgba(sheet), 150)
        it = find_items(a, nviews, 6)
        for vi in range(nviews):
            for k, name in enumerate(names):
                b = it[vi * 6 + k]
                fb = it[k]  # масштаб общий для всех видов предмета — по фронтальному
                wf = HAT_W.get(name, FACE_W.get(name, 1.0))
                scale = head_w * wf / (fb[2] - fb[0])
                f = crop_scaled(a, b, scale)
                save(f, "acc/%s_%s.png" % (name, VIEWS[vi]))
                acc.setdefault(name, {})[VIEWS[vi]] = [int(f.shape[1]), int(f.shape[0])]
    meta["acc"] = acc


def main():
    meta = {}
    char8(47, "maga", 90)
    # Королева Мышей: лист 48 (2 ряда: 4 + 2), лист 49 (4 в ряд)
    a = clean_specks(load_rgba(48))
    fg = a[..., 3] > 0
    it = find_items(a, 2, 4)
    row1 = it[:4]
    names = [("props/mouse_plush.png", 46), ("props/mouse_parcel.png", 40), ("props/mouse_parcel_run0.png", 40),
             ("props/mouse_run0.png", 14)]
    for (n, h), b in zip(names, row1):
        save(crop_scaled(a, b, h / (b[3] - b[1])), n)
    it2 = find_items(a, 2, 2) if False else None
    # второй ряд: иконка и медаль
    from import_art import runs
    rows = runs(fg.sum(axis=1) > 2, 2, 10)
    band = fg[rows[1][0]:rows[1][1] + 1]
    cs = runs(band.sum(axis=0) > 2, 2, 10)
    for cx, (n, h) in zip(cs, [("decor/icon_mouse_queen.png", 24), ("ui/medal_maga.png", 40)]):
        sub = band[:, cx[0]:cx[1] + 1]
        ys = np.where(sub.sum(axis=1) > 0)[0]
        box = (cx[0], rows[1][0] + ys[0], cx[1] + 1, rows[1][0] + ys[-1] + 1)
        save(crop_scaled(a, box, h / (box[3] - box[1])), n)
    a = clean_specks(load_rgba(49))
    it = find_items(a, 1, 4)
    for (n, h), b in zip([("props/mouse_parcel_run1.png", 40), ("props/mouse_parcel_run2.png", 40),
                          ("props/mouse_run1.png", 14), ("props/mouse_run2.png", 14)], it):
        save(crop_scaled(a, b, h / (b[3] - b[1])), n)
    players(meta)
    hw = meta["human"]["frames"]["front_idle"]["w"]
    accessories(meta, hw)
    # лист 56: зеркало (стекло вырезается вместе с фоном), подставка, табличка, пьедестал
    a = load_rgba(56)
    it = find_items(a, 1, 4)
    for (n, h), b in zip([("props/mirror.png", 160), ("props/mirror_back.png", 160), ("ui/name_plate.png", 24),
                          ("props/pedestal.png", 40)], it):
        save(crop_scaled(a, b, h / (b[3] - b[1])), n)
    with open(os.path.join(OUT, "players", "meta.json"), "w") as fo:
        json.dump(meta, fo, indent=1)
    print("ok", {r: (meta[r]["h"], meta[r]["skin_ref"]) for r in ("human", "goblin", "orc")})




def maga_box():
    """Текстура коробки Королевы Мышей (6 граней 128x128 в атласе 3x2) с кодом М-01 / M-01."""
    from PIL import ImageDraw, ImageFont
    font = ImageFont.truetype(os.path.join(ROOT_DIR, "fonts", "DejaVuSans-Bold.ttf"), 30)
    for folder, code in [("boxes", "М-01"), ("boxes_en", "M-01")]:
        atlas = Image.new("RGB", (384, 256))
        for fy in range(2):
            for fx in range(3):
                f = Image.new("RGB", (128, 128), (236, 140, 178))
                d = ImageDraw.Draw(f)
                for k in range(-128, 128, 16):
                    d.line([(k, 0), (k + 128, 128)], fill=(222, 120, 162), width=4)
                d.rectangle([54, 0, 74, 127], fill=(250, 200, 220))
                d.rectangle([54, 0, 56, 127], fill=(200, 90, 140))
                d.rectangle([72, 0, 74, 127], fill=(200, 90, 140))
                # корона
                d.polygon([(14, 30), (14, 14), (22, 22), (28, 10), (34, 22), (42, 14), (42, 30)], fill=(250, 200, 60),
                          outline=(120, 70, 20))
                bb = d.textbbox((0, 0), code, font=font); tw, th = bb[2] - bb[0], bb[3] - bb[1]
                d.rectangle([64 - tw // 2 - 8, 64 - th // 2 - 6, 64 + tw // 2 + 8, 64 + th // 2 + 8], fill=(255, 250, 240),
                            outline=(20, 10, 10), width=3)
                d.text((64 - tw // 2 - bb[0], 64 - th // 2 - bb[1]), code, font=font, fill=(20, 10, 10))
                atlas.paste(f, (fx * 128, fy * 128))
        atlas.save(os.path.join(OUT, folder, "box_maga.png"))


ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if __name__ == "__main__" and "--box" in sys.argv:
    maga_box()

if __name__ == "__main__" and "--box" not in sys.argv:
    main()
    maga_box()
