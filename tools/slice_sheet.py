# Нарезка листов из ChatGPT.
#   sprites: python3 slice_sheet.py sprites sheet.png out_dir name1,name2,... [height=64]
#            фон пурпурный #FF00FF -> прозрачность, объекты ищутся сами (не нужна точная сетка)
#   grid:    python3 slice_sheet.py grid sheet.png out_dir cols rows name1,name2,... [size=64]
#            сетка квадратов, разделённая чёрными линиями
import sys, os
import numpy as np
from PIL import Image

def magenta_mask(a):
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    return (r > 170) & (b > 170) & (g < 110) & (abs(r - b) < 90)

def components(fg, min_area):
    h, w = fg.shape; lab = np.zeros((h, w), np.int32); boxes = []; cur = 0
    for y0 in range(0, h, 2):
        for x0 in range(0, w, 2):
            if fg[y0, x0] and lab[y0, x0] == 0:
                cur += 1; stack = [(y0, x0)]; lab[y0, x0] = cur
                x1 = x2 = x0; y1 = y2 = y0; area = 0
                while stack:
                    y, x = stack.pop(); area += 1
                    x1, x2, y1, y2 = min(x1, x), max(x2, x), min(y1, y), max(y2, y)
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < h and 0 <= nx < w and fg[ny, nx] and lab[ny, nx] == 0:
                            lab[ny, nx] = cur; stack.append((ny, nx))
                if area >= min_area:
                    boxes.append((x1, y1, x2 + 1, y2 + 1, area))
    return boxes

def sprites(path, out, names, height=64):
    im = Image.open(path).convert("RGBA")
    scale = 512 / max(im.size); small = im.resize((int(im.width * scale), int(im.height * scale)), Image.NEAREST)
    a = np.array(small); fg = ~magenta_mask(a)
    boxes = components(fg, min_area=150)
    boxes.sort(key=lambda b: (round(b[1] / (small.height / 3)), b[0]))  # по строкам, слева направо
    full = np.array(im); full[magenta_mask(full)] = [0, 0, 0, 0]
    im2 = Image.fromarray(full)
    print(f"найдено объектов: {len(boxes)}, имён: {len(names)}")
    for i, b in enumerate(boxes[:len(names)]):
        x1, y1, x2, y2 = [int(v / scale) for v in b[:4]]
        pad = 4; crop = im2.crop((max(0, x1 - pad), max(0, y1 - pad), x2 + pad, y2 + pad))
        h = height; w = max(1, round(crop.width * h / crop.height))
        crop = crop.resize((w, h), Image.BOX)
        arr = np.array(crop); arr[..., 3] = np.where(arr[..., 3] > 128, 255, 0)  # чёткая альфа
        Image.fromarray(arr).save(os.path.join(out, names[i] + ".png")); print("  ->", names[i], crop.size)

def grid(path, out, cols, rows, names, size=64):
    im = Image.open(path).convert("RGB"); a = np.array(im).astype(int)
    dark = a.sum(axis=2) < 60
    def cuts(axis, n):
        frac = dark.mean(axis=axis); L = len(frac); edges = []
        for k in range(1, n):
            c = int(L * k / n); win = range(max(0, c - L // (n * 4)), min(L, c + L // (n * 4)))
            edges.append(max(win, key=lambda i: frac[i]))
        return [0] + edges + [L]
    xs, ys = cuts(0, cols), cuts(1, rows); idx = 0
    for r in range(rows):
        for c in range(cols):
            if idx >= len(names): return
            m = 8; tile = im.crop((xs[c] + m, ys[r] + m, xs[c + 1] - m, ys[r + 1] - m))
            side = min(tile.size); tile = tile.crop((0, 0, side, side)).resize((size, size), Image.BOX)
            tile.save(os.path.join(out, names[idx] + ".png")); print("  ->", names[idx]); idx += 1

if __name__ == "__main__":
    mode = sys.argv[1]; os.makedirs(sys.argv[3], exist_ok=True)
    if mode == "sprites":
        sprites(sys.argv[2], sys.argv[3], sys.argv[4].split(","), int(sys.argv[5]) if len(sys.argv) > 5 else 64)
    else:
        grid(sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5]), sys.argv[6].split(","), int(sys.argv[7]) if len(sys.argv) > 7 else 64)
