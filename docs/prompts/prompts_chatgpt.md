# Промпты для ChatGPT: арт для «Пункта выдачи»

Как пользоваться:
1. Открой **новый чат** в ChatGPT и первым сообщением вставь **системный промпт** (шаг 0). Он задаёт стиль, и дальше всё будет в одном стиле.
2. Потом по одному кидай промпты листов (1, 2, 3...). Один промпт = одна картинка.
3. Если лист вышел кривой (персонажи слиплись, есть текст, другой стиль), пиши ему: «переделай, соблюдай правила листа» — или просто перегенерируй.
4. Готовые картинки скидывай мне сюда **как есть**, и подпиши номер листа («лист 2»). Нарезку, чистку фона и уменьшение я сделаю сам.

Промпты на английском специально: так картинки получаются точнее. Пояснения на русском.

---

## Шаг 0. Системный промпт (вставить первым)

```
You are the art generator for my indie game "Pickup Point at the Edge of the World".
It is a first-person 3D game in a low-poly PS1-era style. The player works at a parcel
pickup point in a dark, funny fantasy world: witches, orcs, skeletons, goblins come to
pick up their orders, some parcels are cursed and jump around.

STYLE RULES (apply to EVERY image I ask for, never break them):
- Look: chunky pixel art / PS1-era low-res texture look, limited palette, crisp edges,
  no blur, no smooth gradients, no photorealism, no 3D-render look.
- Mood: cozy but slightly creepy fantasy, warm lamp light, humorous characters.
- Palette: warm browns and oranges (cardboard, wood, brick), muted purples and
  sickly greens for magic, dark navy shadows. Keep the same palette across all sheets.
- NO text, NO letters, NO numbers, NO logos, NO watermarks anywhere in the image.
- Everything must be readable at very small size (as if it will be shown 64 pixels tall).

SHEET RULES:
- I will ask for "sheets": several separate items in one image.
- CHARACTER / PROP sheets: pure flat magenta background (#FF00FF), every item fully
  inside the image, items NOT touching or overlapping, generous empty space between them,
  no drop shadows on the background, no ground, no frames, same scale for all characters.
  Characters are full body, front view facing the camera (slightly 3/4 is OK), standing.
- TEXTURE sheets: a strict grid of square tiles separated by thin pure black lines.
  Each tile is a flat, straight-on (orthographic) view of a surface, fills its whole
  square edge to edge, and MUST be seamless/tileable. No perspective, no lighting
  direction, no objects in front of the surface.

Reply "Ready" and wait for my sheet requests.
```

---

## Лист 1. Клиенты (основная четвёрка)

```
Sheet 1 - customers. 4 characters in one row on pure magenta (#FF00FF), same height,
full body, front view, standing, idle pose, not touching:
1) a witch: green skin, crooked nose, tall purple pointy hat, dark purple robe, holds a broom
2) an orc: big, muscular, green skin, tusks, leather armor, grumpy face
3) a skeleton: bony, wearing a tattered old-man cardigan and slippers, polite posture
4) a goblin: small, yellow-green, huge ears, sly grin, oversized hoodie
Follow all style and sheet rules.
```

## Листы 2–5. Эмоции и походка (по одному листу на персонажа)

Повтори 4 раза, подставляя персонажа вместо `[CHARACTER]`:
`the witch from sheet 1`, `the orc from sheet 1`, `the skeleton from sheet 1`, `the goblin from sheet 1`.

```
Sheet [N] - [CHARACTER], exactly the same design, colors and proportions as before.
4 poses in one row on pure magenta (#FF00FF), same scale, not touching:
1) neutral idle, 2) happy (big smile, arms up), 3) furious (red face, shaking fist),
4) walking step (one leg forward, mid-stride).
Follow all style and sheet rules.
```

## Лист 6. Новые клиенты (на будущее)

```
Sheet 6 - more customers. 4 characters in one row on pure magenta (#FF00FF), same
height and style as sheet 1, full body, front view, not touching:
1) a vampire in a fancy cape who hides from light with an umbrella
2) a baby dragon with a backpack, cute and dangerous
3) a ghost office clerk, semi-transparent pale blue, holding a coffee mug
4) a dwarf delivery courier with a huge beard and a cap
Follow all style and sheet rules.
```

## Лист 7. Текстуры помещения

```
Sheet 7 - environment textures. A 3x2 grid of square seamless tiles separated by thin
black lines (top row left to right, then bottom row):
1) dirty stone floor tiles  2) old red brick wall  3) worn wooden planks (counter)
4) scratched grey metal (shelves)  5) dark wooden ceiling boards  6) heavy wooden door
with iron bands (front view, fills the tile)
Follow all style and texture sheet rules.
```

## Лист 8. Посылки (бока коробок)

Важно: на коробке должна быть **пустая белая наклейка** по центру. Номера я печатаю сам.

```
Sheet 8 - parcel box faces. A 3x2 grid of square tiles separated by thin black lines.
Each tile is ONE flat side of a box seen straight on, filling the tile edge to edge,
with an EMPTY blank white label rectangle in the center (no writing on it):
1) normal brown cardboard box with tape
2) cursed box: purple cardboard, glowing green tape, two small glowing yellow eyes
3) explosive box: red with black hazard stripes (no symbols or text)
4) heavy iron-bound wooden crate
5) gift box: pink with a bow ribbon
6) fragile box: light cardboard with cracked egg-shell pattern
Follow all style and texture sheet rules.
```

## Лист 9. Декор

```
Sheet 9 - decoration props on pure magenta (#FF00FF), not touching, front view:
1) a hanging oil lamp  2) a potted carnivorous plant  3) a black cat sleeping
4) a wall clock with a skull  5) a corner cobweb  6) a wanted poster with a drawn
goblin face (no text)  7) a broken magic mirror  8) a small stack of loose boxes
Follow all style and sheet rules.
```

## Лист 10. Иконки интерфейса

```
Sheet 10 - UI icons on pure magenta (#FF00FF), not touching, each icon simple and bold:
1) gold coin  2) gold star  3) empty grey star  4) hourglass (patience)
5) angry face  6) happy face  7) open hand (grab)  8) a blank speech bubble
Follow all style and sheet rules.
```

---

Когда будут 1–5, 7 и 8, этого уже хватит, чтобы игра выглядела совсем по-другому. Остальное можно позже.
