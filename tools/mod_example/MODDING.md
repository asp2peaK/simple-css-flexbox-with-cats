# Modding NOT MY PARCEL!

Mods live in a `mods` folder. The game looks in two places:

1. `mods/` next to `NotMyParcel.exe` (for Steam: right-click the game, Manage, Browse local files).
2. The user folder: main menu, **Mods**, **Open mods folder** (`%APPDATA%/Godot/app_userdata/NOT MY PARCEL!/mods` or similar).

Mods load in alphabetical order; a later mod wins. Start the game with `--nomods` to turn all mods off.
The **Mods** button in the main menu lists what loaded and shows errors.

## 1. Folder mod (no tools needed)

```
mods/
  my_mod/
    mod.json        name, author, version, description
    lines.json      extra customer lines (optional)
    lang/xx.json    translations, or a whole new language (optional)
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

## 2. Resource pack (.pck / .zip): replace art, sounds, scripts

Anything in the game can be replaced: textures, sounds, music, fonts, even scripts.

1. Install Godot **3.6.2** (the standard build, not Mono).
2. Make a new project, recreate the game's folder layout, and put your replacement files at the
   same paths as the originals, for example `res://assets/chars/orc_happy.png`.
3. Project, Export, add a Windows preset, Resources: "Export selected resources", pick your files,
   then **Export PCK/Zip**.
4. Put `my_mod.pck` straight into `mods/`.

The paths must match exactly. Replacing scripts works but can break with game updates, so prefer
replacing assets.

A ready-made folder example is in `example_mod/` (it is switched off by `"disabled": true`).
