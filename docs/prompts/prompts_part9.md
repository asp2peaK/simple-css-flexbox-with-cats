# Промпты, часть 9: персонажи игроков для мультиплеера

Всё в тот же чат ChatGPT (или новый с системным промптом из prompts_chatgpt.md).

Как я это соберу:
- **Раса** (человек, гоблин, орк) — отдельный лист на каждую, 12 кадров: спереди, сбоку, сзади, идёт и несёт коробку.
- **Цвет кожи**: ChatGPT рисует одну кожу, а 3 оттенка я делаю сам перекраской. Поэтому кожа должна быть ровной, без лишних цветов.
- **Цвет фартука**: фартук рисуется ярко-бирюзовым, а в игре я перекрашиваю его в цвет игрока (выбирается в лобби).
- **Аксессуары**: шапки и очки рисуются отдельно, а я сажаю их на голову в игре. Поэтому каждая шапка нужна спереди, сбоку и сзади.
- **Ники над головой** и **зеркало** делаю кодом, картинка нужна только для рамы зеркала (лист 56).

---

## Лист 50. Игрок: человек

```
Sheet 50 - PLAYER CHARACTER: a young human parcel-shop worker, same cartoon pixel style and
same scale as the customers. Short messy brown hair, simple friendly face, plain grey
t-shirt, dark trousers, brown boots, and a work apron in ONE flat bright cyan color
(#00E5FF, no shading variety on the apron except one darker cyan for folds).
Skin: smooth flat light peach skin using only 2 tones (base and shadow), no blush, no
freckles, no other skin colors.
No hat, no accessories, empty hands.
12 frames in 3 rows on pure magenta (#FF00FF), every frame the same size and scale,
nothing touching:
Row 1 - FRONT view (facing us): 1) idle, 2) walking left leg forward, 3) walking right leg
forward, 4) carrying pose: both arms stretched forward at chest height as if holding a box
(but NO box drawn).
Row 2 - SIDE view facing RIGHT: 5) idle, 6) walking left leg forward, 7) walking right leg
forward, 8) carrying pose (arms forward, no box).
Row 3 - BACK view: 9) idle, 10) walking left leg forward, 11) walking right leg forward,
12) carrying pose seen from behind (no box).
Do not mirror frames. Follow all style and sheet rules.
```

## Лист 51. Игрок: гоблин

```
Sheet 51 - PLAYER CHARACTER: a young goblin parcel-shop worker, same cartoon pixel style
and same scale as the customers (a bit shorter than a human). Big pointy ears, big nose,
toothy grin, scruffy black hair tuft, plain grey t-shirt, dark trousers, small boots, and
a work apron in ONE flat bright cyan color (#00E5FF, only one darker cyan for folds).
Skin: smooth flat green skin using only 2 tones (base and shadow), no spots, no other skin
colors.
No hat, no accessories, empty hands.
12 frames in 3 rows on pure magenta (#FF00FF), same layout as sheet 50:
Row 1 FRONT: idle, walk left leg, walk right leg, carrying pose (arms forward, no box).
Row 2 SIDE facing RIGHT: idle, walk left leg, walk right leg, carrying pose.
Row 3 BACK: idle, walk left leg, walk right leg, carrying pose.
Do not mirror frames. Follow all style and sheet rules.
```

## Лист 52. Игрок: орк

```
Sheet 52 - PLAYER CHARACTER: a young orc parcel-shop worker, same cartoon pixel style and
same scale as the customers (a bit taller and wider than a human). Small tusks, heavy
brow, short black topknot, plain grey t-shirt, dark trousers, big boots, and a work apron
in ONE flat bright cyan color (#00E5FF, only one darker cyan for folds).
Skin: smooth flat grey-green skin using only 2 tones (base and shadow), no scars, no
tattoos, no other skin colors.
No hat, no accessories, empty hands.
12 frames in 3 rows on pure magenta (#FF00FF), same layout as sheet 50:
Row 1 FRONT: idle, walk left leg, walk right leg, carrying pose (arms forward, no box).
Row 2 SIDE facing RIGHT: idle, walk left leg, walk right leg, carrying pose.
Row 3 BACK: idle, walk left leg, walk right leg, carrying pose.
Do not mirror frames. Follow all style and sheet rules.
```

## Лист 53. Шапки, часть 1

```
Sheet 53 - wearable HATS for the player characters, pixel art, same style. 6 hats, each
drawn in 3 views. Hats only, no heads, no faces. Every hat sized to fit the head of a
customer-sized character. Pure magenta (#FF00FF), nothing touching.
Columns (one hat per column): 1) a postal cap with a brass badge, 2) a tall purple wizard
hat with stars, 3) a small golden crown, 4) a knitted red beanie with a pompom, 5) a
viking helmet with horns, 6) a chef hat.
Row 1 - every hat seen from the FRONT.
Row 2 - every hat seen from the SIDE, facing right.
Row 3 - every hat seen from the BACK.
Follow all style and sheet rules.
```

## Лист 54. Шапки, часть 2

```
Sheet 54 - more wearable HATS, same rules as sheet 53 (hats only, 3 views, same size,
pure magenta, nothing touching).
Columns: 1) a propeller cap, 2) a brown cowboy hat, 3) a pirate bandana with a skull,
4) big headphones, 5) a flower crown, 6) a pink headband with mouse ears.
Row 1 - FRONT view. Row 2 - SIDE view facing right. Row 3 - BACK view.
Follow all style and sheet rules.
```

## Лист 55. Аксессуары на лицо и шею

```
Sheet 55 - wearable FACE and NECK accessories for the player characters, pixel art, same
style, sized for a customer-sized head. Items only, no faces. Pure magenta (#FF00FF),
nothing touching.
Columns: 1) round nerd glasses, 2) black sunglasses, 3) a pirate eye patch, 4) a big fake
curly mustache, 5) a red striped scarf, 6) a little red bow tie.
Row 1 - every item seen from the FRONT.
Row 2 - every item seen from the SIDE, facing right.
Follow all style and sheet rules.
```

## Лист 56. Зеркало и таблички для лобби

```
Sheet 56 - props, pixel art, same style, pure magenta (#FF00FF), nothing touching:
1) a tall standing mirror in an ornate dark wooden frame with brass corners, front view.
   The glass area inside the frame must be filled with PURE MAGENTA (#FF00FF), exactly
   like the background, so it can be cut out,
2) the same mirror frame seen from the back (wooden back panel and a stand),
3) a small empty wooden name plate (a horizontal plank, empty middle, no text),
4) a round wooden character-select pedestal (a low round stand with a rope edge).
Follow all style and sheet rules.
```

---

## Что будет в игре

- **Лобби** (при создании игры или подключении): ник, раса, оттенок кожи, цвет фартука, шапка и аксессуар. Персонаж крутится на пьедестале, всё сохраняется.
- **Ник над головой** у каждого игрока. Пока вводится вручную, в Steam-версии будет подхватываться имя из Steam.
- **Анимация**: стоит, идёт, несёт коробку. Вид спереди, сбоку или сзади выбирается по тому, куда смотрит игрок относительно камеры.
- **Зеркало** на складе: в нём видно себя (свой персонаж с шапкой), пункт и других игроков. Отражение настоящее, рисуется отдельной камерой в низком разрешении, чтобы не тормозило на слабых ПК.
