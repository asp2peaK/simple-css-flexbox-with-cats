# Импорт листов из ChatGPT (art_src/sheetNN.png) в assets/.
# Запуск: python3 tools/import_art.py  (из корня проекта)
import os, json
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art_src")
OUT = os.path.join(ROOT, "assets")
FONT = os.path.join(ROOT, "fonts", "DejaVuSans-Bold.ttf")


def load_rgba(n):
    im = Image.open(os.path.join(SRC, "sheet%02d.png" % n)).convert("RGBA")
    a = np.array(im)
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    bg = (np.minimum(r, b) - g > 70) & (r > 140) & (b > 140)
    a[bg] = [0, 0, 0, 0]
    return a


def runs(mask1d, n, min_gap=3):
    idx = np.where(mask1d)[0]
    segs = []
    start = idx[0]; prev = idx[0]
    for i in idx[1:]:
        if i - prev > min_gap:
            segs.append([start, prev]); start = i
        prev = i
    segs.append([start, prev])
    while len(segs) > n:  # склеиваем по наименьшему промежутку
        gaps = [segs[i + 1][0] - segs[i][1] for i in range(len(segs) - 1)]
        k = int(np.argmin(gaps)); segs[k] = [segs[k][0], segs[k + 1][1]]; del segs[k + 1]
    return segs


def valley_cuts(band, n):
    """Фигуры стоят вплотную: режем по самым пустым столбцам около равных долей."""
    col = band.sum(axis=0)
    xs = np.where(col > 2)[0]
    x0, x1 = xs[0], xs[-1]
    cuts = [x0]
    win = int((x1 - x0) / n * 0.3)
    for k in range(1, n):
        c = int(x0 + (x1 - x0) * k / n)
        seg = col[c - win:c + win]
        m = seg.min()
        idx = np.where(seg <= m + 1)[0]
        cuts.append(c - win + int(idx[len(idx) // 2]))
    cuts.append(x1 + 1)
    out = []
    for i in range(n):
        sub = col[cuts[i]:cuts[i + 1]]
        nz = np.where(sub > 0)[0]
        out.append([cuts[i] + nz[0], cuts[i] + nz[-1]])
    return out


def find_items(a, rows, cols):
    fg = a[..., 3] > 0
    # убираем мелкий мусор: строки/столбцы с очень малым числом пикселей
    items = []
    rsegs = runs(fg.sum(axis=1) > 2, rows, 10) if rows > 1 else [[0, fg.shape[0] - 1]]
    for ry in rsegs:
        band = fg[ry[0]:ry[1] + 1]
        csegs = runs(band.sum(axis=0) > 2, cols, 10)
        if len(csegs) < cols:
            csegs = valley_cuts(band, cols)
        for cx in csegs:
            sub = band[:, cx[0]:cx[1] + 1]
            ys = np.where(sub.sum(axis=1) > 0)[0]
            items.append((cx[0], ry[0] + ys[0], cx[1] + 1, ry[0] + ys[-1] + 1))
    return items


def crop_scaled(a, box, scale):
    x1, y1, x2, y2 = box
    im = Image.fromarray(a[y1:y2, x1:x2])
    w, h = max(1, round(im.width * scale)), max(1, round(im.height * scale))
    im = im.resize((w, h), Image.BOX)
    arr = np.array(im)
    arr[..., 3] = np.where(arr[..., 3] > 110, 255, 0)
    return arr


def save(arr, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(arr).save(path)


def char_frames(sheet, kind, target_h, names=("idle", "happy", "angry", "walk")):
    """Позы одного персонажа: общий масштаб, общий холст, ноги внизу."""
    a = load_rgba(sheet)
    items = find_items(a, 1, len(names))
    neutral_h = items[0][3] - items[0][1]
    scale = target_h / neutral_h
    frames = [crop_scaled(a, b, scale) for b in items]
    W = max(f.shape[1] for f in frames) + 2
    H = max(f.shape[0] for f in frames) + 1
    for name, f in zip(names, frames):
        canvas = np.zeros((H, W, 4), np.uint8)
        x = (W - f.shape[1]) // 2; y = H - f.shape[0]
        canvas[y:y + f.shape[0], x:x + f.shape[1]] = f
        save(canvas, "chars/%s_%s.png" % (kind, name))
    return H


TARGET_H = {"witch": 92, "orc": 100, "skeleton": 94, "goblin": 82, "vampire": 94, "dragon": 82, "ghost": 92, "dwarf": 86,
            "thief": 84, "king": 70, "troll": 78, "werewolf": 96, "giant": 122, "golem": 104, "helper": 82}


def back_frames(sheet, kinds):
    a = load_rgba(sheet)
    n = len(kinds)
    items = find_items(a, 2, n)
    for i, kind in enumerate(kinds):
        stand, walk = items[i], items[i + n]
        scale = TARGET_H[kind] / (stand[3] - stand[1])
        frames = [crop_scaled(a, stand, scale), crop_scaled(a, walk, scale)]
        W = max(f.shape[1] for f in frames) + 2
        H = max(f.shape[0] for f in frames) + 1
        for name, f in zip(["back", "back_walk"], frames):
            canvas = np.zeros((H, W, 4), np.uint8)
            x = (W - f.shape[1]) // 2; y = H - f.shape[0]
            canvas[y:y + f.shape[0], x:x + f.shape[1]] = f
            save(canvas, "chars/%s_%s.png" % (kind, name))


def matched_frame(a, box, kind, ref, out):
    """Кадр в масштабе уже нарезанного кадра ref того же персонажа (ноги внизу)."""
    refp = os.path.join(OUT, "chars", "%s_%s.png" % (kind, ref))
    if not os.path.exists(refp):
        return
    r = np.array(Image.open(refp))
    ys = np.where(r[..., 3].max(axis=1) > 0)[0]
    f = crop_scaled(a, box, (ys[-1] - ys[0] + 1) / (box[3] - box[1]))
    H, W = r.shape[0], max(r.shape[1], f.shape[1])
    canvas = np.zeros((max(H, f.shape[0]), W, 4), np.uint8)
    x = (W - f.shape[1]) // 2; y = canvas.shape[0] - f.shape[0]
    canvas[y:y + f.shape[0], x:x + f.shape[1]] = f
    save(canvas, "chars/%s_%s.png" % (kind, out))


def single_chars(sheet, kinds, tallest):
    a = load_rgba(sheet)
    items = find_items(a, 1, len(kinds))
    scale = tallest / max(b[3] - b[1] for b in items)
    for kind, b in zip(kinds, items):
        f = crop_scaled(a, b, scale)
        save(f, "chars/%s_idle.png" % kind)


def props(sheet, names, rows, cols, h):
    a = load_rgba(sheet)
    items = find_items(a, rows, cols)
    for name, b, hh in zip(names, items, h):
        save(crop_scaled(a, b, hh / (b[3] - b[1])), name)


def grid_tiles(sheet, cols, rows, size):
    im = Image.open(os.path.join(SRC, "sheet%02d.png" % sheet)).convert("RGB")
    a = np.array(im).astype(int); dark = a.sum(axis=2) < 70

    def cuts(axis, n):
        frac = dark.mean(axis=axis); L = len(frac); edges = []
        for k in range(1, n):
            c = int(L * k / n); w = L // (n * 5)
            edges.append(c - w + int(np.argmax(frac[c - w:c + w])))
        return [0] + edges + [L]
    xs, ys = cuts(0, cols), cuts(1, rows); tiles = []
    for r in range(rows):
        for c in range(cols):
            m = 7
            t = im.crop((xs[c] + m, ys[r] + m, xs[c + 1] - m, ys[r + 1] - m))
            s = min(t.size); t = t.crop(((t.width - s) // 2, (t.height - s) // 2, (t.width + s) // 2, (t.height + s) // 2))
            tiles.append(t.resize((size, size), Image.BOX))
    return tiles


def make_seamless(t):
    # мягко сшиваем края: смешиваем с копией, сдвинутой на половину
    a = np.array(t).astype(float); n = a.shape[0]
    sh = np.roll(np.roll(a, n // 2, 0), n // 2, 1)
    x = np.abs(np.linspace(-1, 1, n)); w = np.clip((np.maximum(x[None, :], x[:, None]) - 0.75) / 0.25, 0, 1)[..., None]
    return Image.fromarray((a * (1 - w) + sh * w).astype(np.uint8))


def main():
    os.makedirs(os.path.join(OUT, "chars"), exist_ok=True)
    heights = {}
    for sheet, kind, h in [(2, "witch", 92), (3, "orc", 100), (4, "skeleton", 94), (5, "goblin", 82)]:
        heights[kind] = char_frames(sheet, kind, h)
    # Позы новых клиентов (листы 13-16), если уже есть; иначе одиночные спрайты из листа 6
    new4 = [(13, "vampire", 94), (14, "dragon", 82), (15, "ghost", 92), (16, "dwarf", 86)]
    if all(os.path.exists(os.path.join(SRC, "sheet%02d.png" % n)) for n, _, _ in new4):
        for sheet, kind, h in new4:
            heights[kind] = char_frames(sheet, kind, h)
    else:
        single_chars(6, ["vampire", "dragon", "ghost", "dwarf"], 92)
    # Спины (листы 11-12): верхний ряд стоя, нижний ряд идут
    for sheet, kinds in [(11, ["witch", "orc", "skeleton", "goblin"]), (12, ["vampire", "dragon", "ghost", "dwarf"])]:
        if os.path.exists(os.path.join(SRC, "sheet%02d.png" % sheet)):
            back_frames(sheet, kinds)

    env = grid_tiles(7, 3, 2, 128)
    for name, t in zip(["floor", "wall", "wood", "metal", "ceiling", "door"], env):
        (t if name == "door" else make_seamless(t)).save(os.path.join(OUT, "env_%s.png" % name))

    # Коробки: 6 видов, номер печатаем на белой наклейке, атлас 3x2 для CubeMesh
    box_tiles = grid_tiles(8, 3, 2, 128)
    types = ["normal", "cursed", "explosive", "heavy", "gift", "fragile"]
    if os.path.exists(os.path.join(SRC, "sheet29.png")):
        box_tiles += grid_tiles(29, 3, 2, 128)
        types += ["mimic", "timer", "chest", "frozen", "returns", "living"]
    codes = json.load(open(os.path.join(ROOT, "tools", "box_codes.json"), encoding="utf-8"))
    font = ImageFont.truetype(FONT, 30)
    LAT = {"А": "A", "Б": "B", "В": "V", "Г": "G", "Д": "D", "К": "K", "М": "M"}
    for folder in ["boxes", "boxes_en"]:
        os.makedirs(os.path.join(OUT, folder), exist_ok=True)
        for f in os.listdir(os.path.join(OUT, folder)):
            if f.endswith(".png"):
                os.remove(os.path.join(OUT, folder, f))
    for i, item in enumerate(codes):
        code, typ = item["code"], item["type"]
        for folder, text in [("boxes", code), ("boxes_en", LAT[code[0]] + code[1:])]:
            tile = box_tiles[types.index(typ)].copy()
            d = ImageDraw.Draw(tile)
            # крупная белая наклейка с толстой рамкой: номер читается издалека
            d.rectangle([10, 42, 117, 86], fill=(250, 248, 238), outline=(20, 14, 10), width=3)
            tw = d.textlength(text, font=font)
            d.text((64 - tw / 2, 47), text, font=font, fill=(15, 10, 6))
            atlas = Image.new("RGB", (384, 256))
            for gx in range(3):
                for gy in range(2):
                    atlas.paste(tile, (gx * 128, gy * 128))
            atlas.save(os.path.join(OUT, folder, "box_%02d.png" % i))

    props(9, ["props/lantern.png", "props/plant.png", "props/cat.png", "props/clock.png",
              "props/cobweb.png", "props/poster.png", "props/mirror.png", "props/boxstack.png"],
          2, 4, [56, 56, 40, 56, 56, 64, 64, 56])
    props(10, ["ui/coin.png", "ui/star.png", "ui/star_empty.png", "ui/hourglass.png",
               "ui/angry.png", "ui/happy.png", "ui/hand.png", "ui/bubble.png"],
          2, 4, [16, 16, 16, 16, 16, 16, 16, 32])
    # Второй шаг другой ногой (листы 20 и 21) для персонажей с предметами в руках
    asym = ["witch", "orc", "vampire", "ghost", "dwarf"]
    for sheet, ref, out in [(20, "walk", "walk2"), (21, "back_walk", "back_walk2")]:
        if os.path.exists(os.path.join(SRC, "sheet%02d.png" % sheet)):
            a = load_rgba(sheet)
            for kind, b in zip(asym, find_items(a, 1, 5)):
                refp = os.path.join(OUT, "chars", "%s_%s.png" % (kind, ref))
                if not os.path.exists(refp):
                    continue
                r = np.array(Image.open(refp))
                ys = np.where(r[..., 3].max(axis=1) > 0)[0]
                f = crop_scaled(a, b, (ys[-1] - ys[0] + 1) / (b[3] - b[1]))
                H, W = r.shape[0], max(r.shape[1], f.shape[1])
                canvas = np.zeros((max(H, f.shape[0]), W, 4), np.uint8)
                x = (W - f.shape[1]) // 2; y = canvas.shape[0] - f.shape[0]
                canvas[y:y + f.shape[0], x:x + f.shape[1]] = f
                save(canvas, "chars/%s_%s.png" % (kind, out))
    # Новые клиенты (23-27), спины (28)
    for sheet, kind, names in [(23, "thief", ("idle", "happy", "angry", "walk", "run")),
                               (24, "king", None), (25, "troll", None), (26, "werewolf", None), (27, "giant", None)]:
        if os.path.exists(os.path.join(SRC, "sheet%02d.png" % sheet)):
            if names:
                char_frames(sheet, kind, TARGET_H[kind], names)
            else:
                char_frames(sheet, kind, TARGET_H[kind])
    if os.path.exists(os.path.join(SRC, "sheet28.png")):
        back_frames(28, ["thief", "king", "troll", "werewolf", "giant"])
    # Помощники
    if os.path.exists(os.path.join(SRC, "sheet31.png")):
        char_frames(31, "golem", TARGET_H["golem"], ("idle", "walk", "hold", "point"))
    if os.path.exists(os.path.join(SRC, "sheet32.png")):
        char_frames(32, "helper", TARGET_H["helper"], ("idle", "carry", "walk", "steal"))
    # Иконки
    if os.path.exists(os.path.join(SRC, "sheet17.png")):
        props(17, ["ui/up_%s.png" % n for n in ["cart", "patience", "sorter", "amulet", "shoes", "bell",
                                                 "shelf", "expand", "window", "golem", "helper", "freezer"]],
              2, 6, [24] * 12)
    if os.path.exists(os.path.join(SRC, "sheet19.png")):
        props(19, ["ui/ev_%s.png" % n for n in ["blackout", "rush", "inspector", "flashlight"]], 1, 4, [32] * 4)
    if os.path.exists(os.path.join(SRC, "sheet30.png")):
        props(30, ["props/%s.png" % n for n in ["receipt", "receipt_fake", "stamp", "mimic_open", "legs",
                                                 "van", "returns_bin", "freezer", "cage", "button"]],
              2, 5, [40, 40, 32, 48, 24, 64, 56, 48, 56, 48])
    # Фон меню, лого, заставка
    for sheet, rel, size in [(18, "ui/menu_bg.png", (640, 360)), (34, "ui/splash.png", (640, 360))]:
        if os.path.exists(os.path.join(SRC, "sheet%02d.png" % sheet)):
            im = Image.open(os.path.join(SRC, "sheet%02d.png" % sheet)).convert("RGB")
            r = max(size[0] / im.width, size[1] / im.height)
            im = im.resize((round(im.width * r), round(im.height * r)), Image.BOX)
            x = (im.width - size[0]) // 2; y = (im.height - size[1]) // 2
            im.crop((x, y, x + size[0], y + size[1])).save(os.path.join(OUT, rel))
    if os.path.exists(os.path.join(SRC, "sheet33.png")):
        props(33, ["ui/logo.png"], 1, 1, [110])
    # Лист 35-36: второй шаг вора, тролля, оборотня (лицом и спиной)
    trio = ["thief", "troll", "werewolf"]
    for sheet, ref, out in [(35, "walk", "walk2"), (36, "back_walk", "back_walk2")]:
        if os.path.exists(os.path.join(SRC, "sheet%02d.png" % sheet)):
            a = load_rgba(sheet)
            for kind, b in zip(trio, find_items(a, 1, 3)):
                matched_frame(a, b, kind, ref, out)
    # Лист 37: спины и второй шаг помощников
    if os.path.exists(os.path.join(SRC, "sheet37.png")):
        a = load_rgba(37)
        it = find_items(a, 2, 4)
        for b, (kind, ref, out) in zip(it, [("golem", "idle", "back"), ("golem", "walk", "back_walk"),
                                            ("golem", "walk", "walk2"), ("golem", "walk", "back_walk2"),
                                            ("helper", "idle", "back"), ("helper", "carry", "back_carry"),
                                            ("helper", "carry", "carry2"), ("helper", "walk", "walk2")]):
            matched_frame(a, b, kind, ref, out)
    # Лист 38: текстуры для объёмных предметов
    if os.path.exists(os.path.join(SRC, "sheet38.png")):
        for t, n in zip(grid_tiles(38, 3, 2, 64), ["freezer_side", "freezer_lid", "freezer_in", "safe", "conveyor", "cage"]):
            t.save(os.path.join(OUT, "env_%s.png" % n))
            if n == "conveyor":  # рёбра поперёк хода ленты
                t.rotate(90).save(os.path.join(OUT, "env_conveyor_x.png"))
    # Лист 39: предметы с анимацией
    if os.path.exists(os.path.join(SRC, "sheet39.png")):
        props(39, ["props/%s.png" % n for n in ["button_up", "button_down", "portal_0", "portal_1", "portal_2",
                                                 "shutters_closed", "shutters_open", "lever_up", "lever_down", "bell_ring"]],
              2, 5, [48, 48, 72, 72, 72, 56, 56, 48, 48, 40])
    # Картинка 40: иконка игры
    if os.path.exists(os.path.join(SRC, "sheet40.png")):
        a = load_rgba(40)
        b = find_items(a, 1, 1)[0]
        im = Image.fromarray(a[b[1]:b[3], b[0]:b[2]])
        s2 = max(im.size); sq = Image.new("RGBA", (s2, s2), (0, 0, 0, 0))
        sq.paste(im, ((s2 - im.width) // 2, (s2 - im.height) // 2))
        sq.resize((256, 256), Image.LANCZOS).save(os.path.join(OUT, "..", "icon.png"))
        sq.resize((256, 256), Image.LANCZOS).save(os.path.join(OUT, "..", "icon.ico"),
                                                  sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    # Лист 41: босс Тёмный Почтмейстер (2 ряда по 4 кадра, общий масштаб)
    if os.path.exists(os.path.join(SRC, "sheet41.png")):
        a = load_rgba(41)
        it = find_items(a, 2, 4)
        scale = 100 / (it[0][3] - it[0][1])
        frames = [crop_scaled(a, b, scale) for b in it]
        W = max(f.shape[1] for f in frames) + 2
        H = max(f.shape[0] for f in frames) + 1
        for name, f in zip(["idle", "walk", "walk2", "happy", "angry", "back", "back_walk", "back_walk2"], frames):
            canvas = np.zeros((H, W, 4), np.uint8)
            x = (W - f.shape[1]) // 2; y = H - f.shape[0]
            canvas[y:y + f.shape[0], x:x + f.shape[1]] = f
            save(canvas, "chars/boss_%s.png" % name)
    # Лист 42: стены и полы районов
    if os.path.exists(os.path.join(SRC, "sheet42.png")):
        names = ["wall_swamp", "wall_crypt", "wall_castle", "wall_ice", "wall_lair",
                 "floor_swamp", "floor_crypt", "floor_castle", "floor_ice", "floor_lair"]
        for t, n in zip(grid_tiles(42, 5, 2, 128), names):
            make_seamless(t).save(os.path.join(OUT, "env_%s.png" % n))
    # Лист 43: декор
    if os.path.exists(os.path.join(SRC, "sheet43.png")):
        props(43, ["props/%s.png" % n for n in ["cat_hat", "trophy", "plant_big", "plant_flytrap"]], 1, 4, [52, 56, 64, 60])
    # Лист 44: иконки декора для магазина
    if os.path.exists(os.path.join(SRC, "sheet44.png")):
        props(44, ["decor/icon_%s.png" % n for n in ["plant", "rug", "garland", "vinyl", "rec_lofi",
                                                      "rec_polka", "cat_hat", "neon", "gold", "trophy"]], 2, 5, [24] * 10)
    # Лист 45: пункт закрыт (табличка, ноутбук, раскладушка, доска, доставка, звонок)
    if os.path.exists(os.path.join(SRC, "sheet45.png")):
        props(45, ["props/%s.png" % n for n in ["sign_closed", "sign_open", "laptop", "cot", "board",
                                                 "deliv_box", "deliv_box_open", "desk_bell"]],
              2, 4, [56, 56, 48, 40, 60, 48, 48, 32])
    # Лист 46: интерфейс (ряды с разным числом элементов, масштаб 1/4 — пиксели ровные)
    if os.path.exists(os.path.join(SRC, "sheet46.png")):
        a = load_rgba(46)
        fg = a[..., 3] > 0
        rows = runs(fg.sum(axis=1) > 2, 3, 10)
        names = [["btn_normal", "btn_hover", "btn_pressed", "btn_disabled"],
                 ["panel", "tab", "tab_active", "banner"],
                 ["slider", "knob", "check_off", "check_on"]]
        for ry, row in zip(rows, names):
            band = fg[ry[0]:ry[1] + 1]
            cs = runs(band.sum(axis=0) > 2, len(row), 10)
            for cx, name in zip(cs, row):
                sub = band[:, cx[0]:cx[1] + 1]
                ys = np.where(sub.sum(axis=1) > 0)[0]
                box = (cx[0], ry[0] + ys[0], cx[1] + 1, ry[0] + ys[-1] + 1)
                sc = 0.13 if name in ("knob", "check_off", "check_on") else 0.25
                save(crop_scaled(a, box, sc), "ui/kit/%s.png" % name)
    print("heights", heights)


if __name__ == "__main__":
    main()
