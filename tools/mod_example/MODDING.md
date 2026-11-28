# Modding NOT MY PARCEL!

Mods live in a `mods` folder. The game looks in two places:

1. `mods/` next to `NotMyParcel.exe` (for Steam: right-click the game, Manage, Browse local files).
2. The user folder: main menu, **Mods**, **Open mods folder** (`%APPDATA%/punkt_vydachi/mods` on Windows).

Mods load in alphabetical order; a later mod wins. Start the game with `--nomods` to turn all mods off.
The **Mods** button in the main menu lists what loaded and shows errors.

## 1. Folder mod (no tools needed)

```
mods/
  my_mod/
    mod.json        name, author, version, description
    lines.json      extra customer lines (optional)
    lang/xx.json    translations, or a whole new language (optional)
    replace/...     your own pictures and sounds (optional)
    main.gd         your own code (optional)
```

`mod.json`:

```json
{
  "name": "My mod",
  "author": "me",
  "version": "1.0",
  "description": "What it does",
  "languages": {"pl": "Polski"}
}
```

- `languages` adds new languages to the Settings list. Codes already in the game (ru, en, de, es) don't need it.
- Add `"disabled": true` to switch a mod off without deleting it.

### lines.json: new customer phrases

Each phrase must contain exactly one `%s`, which becomes the parcel code.
`"*"` means any language; otherwise use a language code.

```json
{
  "orc":   {"*": ["ORC WANT %s! NOW!"], "ru": ["ОРК ПРИШЁЛ ЗА %s."]},
  "ghost": ["Boo... parcel %s..."]
}
```

Customer kinds: witch, orc, skeleton, goblin, vampire, dragon, ghost, dwarf, thief, king, troll, werewolf, giant.

### lang/xx.json: translations

The keys are the game's original Russian strings and the values are your text, the same format as
`lang/en.json` in the game's source. A mod file is merged over the built-in one, so you can fix or
change a few lines, or translate everything into a new language. Look at the game's `lang/en.json`
for the full list of keys. Keep `%s`, `%d`, `\n` and LMB/RMB tokens as they are.

Note: signs, boxes and neon use the English textures for every language except Russian.
Chinese, Japanese and Korean need a font mod (see below) until the game ships a CJK font.

### replace/: new pictures and sounds without any tools

Put a file at the same path as in the game, under `replace/`. For example
`replace/assets/chars/orc_idle.png` replaces the orc standing at the counter, and
`replace/assets/sfx/doorbell.wav` replaces the door bell. Supported: png, jpg, wav (PCM 8/16-bit), ogg.
Keep the same picture size as the original so it lines up. Customers have frames like
`<kind>_idle`, `_happy`, `_angry`, `_walk`, `_walk2`, `_back`, `_back_walk`.

## 2. Script mods (main.gd): write your own code

Like BepInEx mods for other games, a `main.gd` in your mod folder runs inside the game.
It is GDScript (Godot 3.6, very close to Python). It must start with `extends Node`.

```gdscript
extends Node

var api

func _mod_ready(mods_api, dir):
	api = mods_api
	api.connect("customer_spawned", self, "_on_customer")
	api.connect("parcel_delivered", self, "_on_delivered")

func _on_customer(main, customer):
	if customer.kind == "orc":
		customer.scale = Vector3.ONE * 1.6   # huge orcs

func _on_delivered(main, parcel, customer):
	api.add_money(1)                      # every parcel gives a tip
```

Events you can connect to (`api.connect("name", self, "method")`):

| Event | Arguments | When |
|---|---|---|
| `menu_ready` | menu | main menu opened |
| `level_ready` | main | the pickup point scene is built |
| `shift_started` | main | the point opens |
| `shift_ended` | main | the shift is over |
| `customer_spawned` | main, customer | a customer walks in |
| `parcel_delivered` | main, parcel, customer | you handed over a parcel |

Helpers on `api`: `flash(text, seconds)`, `add_money(n)`, `add_line(kind, text, lang)`,
`load_file(path)` (png/jpg/wav/ogg from disk), `replace(res_path, resource)`,
`api.main` (the current scene or null). Your node also gets `_process(delta)` and `_input(event)`
like any Godot node, so you can add your own objects, HUD, keys and rules.

Useful things on `main`: `money`, `customers`, `parcels`, `player`, `is_open`, `shift_over`,
`_flash(text, sec)`. Global singletons: `Game` (day, bank, upgrades), `Settings`, `Sfx`.
Read the game's scripts to find more; everything is open to mods.
Errors go to the log: Settings, Logs folder.

Script mods can do anything on the player's computer, so only install mods you trust.
In co-op every player should have the same mods.

## 3. Resource pack (.pck / .zip): replace art, sounds, scripts

Anything in the game can be replaced: textures, sounds, music, fonts, even scripts.

1. Install Godot **3.6.2** (the standard build, not Mono).
2. Make a new project, recreate the game's folder layout, and put your replacement files at the
   same paths as the originals, for example `res://assets/chars/orc_happy.png`.
3. Project, Export, add a Windows preset, Resources: "Export selected resources", pick your files,
   then **Export PCK/Zip**.
4. Put `my_mod.pck` straight into `mods/`.

The paths must match exactly. Replacing scripts works but can break with game updates, so prefer
replacing assets.

Ready-made examples: `example_mod/` (lines and a language) and `script_mod/` (code). Both are switched off by `"disabled": true`; delete that line to turn one on.
