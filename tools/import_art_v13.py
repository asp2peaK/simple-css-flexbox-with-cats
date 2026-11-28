# Лист 61: работники лежат после удара (на спине / лицом вниз) для человека, гоблина и орка.
# Кожа и фартук перекрашиваются так же, как в players() из import_art_v10.py.
import os, json
import numpy as np
from import_art import load_rgba, find_items, crop_scaled, save, OUT
from import_art_v10 import clean_specks, SKINS, HEIGHTS, is_skin, is_apron


def down_poses():
    meta = json.load(open(os.path.join(OUT, "players", "meta.json")))
    a = clean_specks(load_rgba(61))
    it = find_items(a, 3, 2)
    for r, race in enumerate(["human", "goblin", "orc"]):
        ref = np.array(meta[race]["skin_ref"])
        boxes = it[r * 2: r * 2 + 2]
        # длина лежащего тела ~ рост стоящего
        scale = HEIGHTS[race] * 0.95 / (boxes[0][2] - boxes[0][0])
        for name, b in zip(["down_back", "down_front"], boxes):
            f = crop_scaled(a, b, scale)
            ap = is_apron(f)
            sk = is_skin(f, ref, race)
            apron = np.zeros_like(f)
            lum = f[..., :3].astype(float).mean(2)
            norm = np.clip(lum / max(1.0, lum[ap].max() if ap.any() else 1.0) * 255, 0, 255).astype(np.uint8)
            for c in range(3):
                apron[ap, c] = norm[ap]
            apron[ap, 3] = 255
            save(apron, "players/%s_%s_apron.png" % (race, name))
            for si, tgt in enumerate(SKINS[race]):
                out = f.copy()
                out[ap] = 0
                if si > 0:
                    l2 = f[..., :3].astype(float)[sk] @ np.array([0.3, 0.59, 0.11])
                    rl = float(np.dot(ref.astype(float), [0.3, 0.59, 0.11]))
                    out[sk, :3] = np.clip((l2 / max(1.0, rl))[:, None] * np.array(tgt, float), 0, 255).astype(np.uint8)
                save(out, "players/%s_%d_%s.png" % (race, si, name))
            print(race, name, f.shape)


if __name__ == "__main__":
    down_poses()
    fx_and_cow()


def fx_and_cow():
    # лист 62: звёздочка (4 кадра) + значки проклятий
    a = clean_specks(load_rgba(62))
    it = find_items(a, 2, 4)
    for k, b in enumerate(it[:4]):
        save(crop_scaled(a, b, 16.0 / (b[3] - b[1])), "fx/star_%d.png" % k)
    for name, b in zip(["invert", "bighead", "oink", "glue"], it[4:8]):
        save(crop_scaled(a, b, 30.0 / (b[3] - b[1])), "ui/curse_%s.png" % name)
    # лист 63: корова над краем ящика (спокойная / мычит)
    a = clean_specks(load_rgba(63))
    it = find_items(a, 1, 2)
    h = it[0][3] - it[0][1]
    for name, b in zip(["cow_crate", "cow_crate_moo"], it):
        save(crop_scaled(a, b, 60.0 / h), "props/%s.png" % name)
    print("fx/cow ok", len(it))
