# Нарезка капсул Steam из ключевого арта (лист 58), фона (лист 60) и логотипа (лист 33)
import sys
from PIL import Image, ImageFilter
K = Image.open(sys.argv[1]).convert("RGB")      # sheet58_keyart.png
HB = Image.open(sys.argv[2]).convert("RGB")     # sheet60_hero.png
L = Image.open(sys.argv[3]).convert("RGBA")     # logo_full.png
OUT = sys.argv[4]

def crop_aspect(im, w, h, cx=0.5, cy=0.5):
    ar = w / h
    if im.width / im.height > ar:
        cw, ch = int(im.height * ar), im.height
    else:
        cw, ch = im.width, int(im.width / ar)
    x = int(min(max(cx * im.width - cw / 2, 0), im.width - cw))
    y = int(min(max(cy * im.height - ch / 2, 0), im.height - ch))
    return im.crop((x, y, x + cw, y + ch)).resize((w, h), Image.LANCZOS)

def logo(w):
    h = int(L.height * w / L.width)
    l = L.resize((w, h), Image.LANCZOS)
    pad = max(6, w // 30)
    sh = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    a = l.split()[3].point(lambda v: int(v * 0.75))
    blk = Image.new("RGBA", l.size, (10, 5, 20, 255)); blk.putalpha(a)
    sh.alpha_composite(blk, (pad, pad + pad // 3))
    sh = sh.filter(ImageFilter.GaussianBlur(pad / 2))
    sh.alpha_composite(l, (pad, pad))
    return sh

def put(bg, frac, y):
    lg = logo(int(bg.width * frac))
    bg = bg.convert("RGBA"); bg.alpha_composite(lg, ((bg.width - lg.width) // 2, int(y)))
    return bg.convert("RGB")

out = {
    "header_capsule_920x430.png": put(crop_aspect(K, 920, 430, cy=0.3), 0.54, 0),
    "main_capsule_1232x706.png": put(crop_aspect(K, 1232, 706), 0.56, 4),
    "vertical_capsule_748x896.png": put(crop_aspect(K, 748, 896, cx=0.5), 0.92, 10),
    "library_capsule_600x900.png": put(crop_aspect(K, 600, 900, cx=0.52), 0.94, 14),
    "library_header_920x430.png": put(crop_aspect(K, 920, 430, cy=0.3), 0.54, 0),
}
small = crop_aspect(K, 462, 174, cy=0.45).filter(ImageFilter.GaussianBlur(1.5))
small = Image.blend(small, Image.new("RGB", small.size, (25, 12, 10)), 0.35)
out["small_capsule_462x174.png"] = put(small, 0.94, 10)
out["library_hero_3840x1240.png"] = crop_aspect(HB, 3840, 1240)
pb = crop_aspect(K, 1438, 810).filter(ImageFilter.GaussianBlur(6))
out["page_background_1438x810.png"] = Image.blend(pb, Image.new("RGB", pb.size, (20, 10, 8)), 0.55)
for n, im in out.items():
    im.save(f"{OUT}/{n}")
lg = L.resize((1280, int(L.height * 1280 / L.width)), Image.LANCZOS)
lg.save(f"{OUT}/library_logo_1280x{lg.height}.png")
print("ok", len(out) + 1)
