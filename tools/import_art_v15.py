# Листы 69–70 (v0.15.1): шкала терпения (рамка + рожицы) и значок «Краски для стеллажей».
import numpy as np
from import_art import load_rgba, find_items, crop_scaled, save
from import_art_v10 import clean_specks


def part(a, y0, y1):
    b = np.zeros_like(a)
    b[y0:y1] = a[y0:y1]
    return b


def patience():
    a = clean_specks(load_rgba(69))
    h = a.shape[0]
    fr = find_items(part(a, 0, int(h * 0.38)), 1, 1)[0]
    # рамка: 64 px в ширину (во весь пузырь), заливку рисую кодом цветом настроения
    save(crop_scaled(a, fr, 72.0 / (fr[2] - fr[0])), "ui/pat_frame.png")
    faces = find_items(part(a, int(h * 0.62), h), 1, 4)
    for k, b in enumerate(faces):
        save(crop_scaled(a, b, 16.0 / (b[3] - b[1])), "ui/pat_face_%d.png" % k)
    print("patience", fr, len(faces))


def paints():
    a = clean_specks(load_rgba(70))
    b = find_items(a, 1, 1)[0]
    save(crop_scaled(a, b, 24.0 / (b[3] - b[1])), "ui/up_paints.png")
    print("paints", b)


if __name__ == "__main__":
    patience()
    paints()
