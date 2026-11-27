# NOT MY PARCEL!

Фэнтези-пункт выдачи посылок от первого лица: 3D-мир в стиле PS1 + 2D-спрайты клиентов.
Студия: **2peaK's Studio**. Цель: релиз в Steam.

Движок: **Godot 3.6.2**, рендер **GLES2** (специально, чтобы шло на Win7 32-бит + Intel HD 4400).
Godot 4 НЕ использовать.

## Что где лежит

| Папка | Что внутри |
|---|---|
| `scripts/` | весь код (GDScript 3). Главное: `main.gd` (пункт, смены, клиенты, посылки), `game.gd` (сейв, карьера, улучшения), `career.gd` (задания, отзывы, декор), `menu.gd`, `player.gd`, `parcel.gd`, `customer.gd`, `net.gd` (кооп), `settings*.gd`, `ui_theme.gd` |
| `assets/` | нарезанный арт (спрайты, текстуры, UI), звуки и музыка (всё синтезировано скриптами) |
| `art_src/` | исходные листы из ChatGPT `sheetNN.png` (1–48) |
| `tools/` | `import_art.py` — режет листы в `assets/`; `synth_sfx.py`, `synth_music.py` — генерация звуков |
| `lang/en.json` | английский перевод (ключ = русская строка из `tr("...")`) |
| `docs/prompts/` | все промпты для ChatGPT (части 1–8) |
| `docs/ROADMAP.md` | что сделано, что дальше, идеи |

## Как собрать

1. Скачать Godot **3.6.2** (стандартный, не Mono) и шаблоны экспорта 3.6.2.
2. Открыть `project.godot`.
3. Экспорт (пресеты уже в `export_presets.cfg`):
   - **Win32 Debug** — для Win7 32-бит. Обязательно через *debug*-экспорт: release-шаблон x86 падает (c0000005). PCK встроен в exe.
   - **Win64 Release** — для нормальных ПК / Steam.

Из командной строки (Linux, как делалось в облаке):
```
godot3 --path . --export-debug "Win32 Debug" build/win32/NotMyParcel.exe
godot3 --path . --export "Win64 Release" build/win64/NotMyParcel.exe
```
(в headless-среде запускать через `xvfb-run -a`). Готовые сборки — в Releases репозитория.

## Новый арт

1. Сгенерировать лист в ChatGPT по промпту из `docs/prompts/` (сначала системный промпт из `prompts_chatgpt.md`).
2. Положить как `art_src/sheetNN.png`, дописать нарезку в `tools/import_art.py` (если её ещё нет).
3. `python3 tools/import_art.py`, потом открыть проект в Godot (переимпорт).

## Тесты (аргументы запуска)

`res://main.tscn --test5 … --test12`, `--shot`, `--shotfix`, `--closed --day=N --bank=N`, `--chaos`, `--boss`, `--decor`, `--up=freezer:1,shelf:3`, `--lang=en`.
Сеть: `res://menu.tscn --nethost --test8` и второй экземпляр `res://menu.tscn --netjoin=127.0.0.1 --test8`.

## Правила для GDScript 3 (чтобы не ломалось)

- Явные типы у переменных из `%`-форматирования и из `and`/`or` выражений.
- `Array.slice` в Godot 3 включает конец.
- Нет Label3D — текст в 3D через Sprite3D.
- В `project.godot` должно остаться `locale/fallback="ru"`, иначе русский покажется английским.
- Папка сейвов латиницей: `custom_user_dir_name="punkt_vydachi"`.
