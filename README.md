# Gauty's Perk Workshop

A browser-based creation kit for the Kronos **Custom Perks** mod (Black Ops 7 Zombies). Add or remove perk scripts, give them augments, icons and credits, and download a ready-to-install copy of the mod. Everything runs locally in the browser: no server, account, API key, telemetry or install step.

The kit works with the current mod layout:

```text
kronos/mods/custom_perks/
    mod.json
    scripts/   perk GSC files + the manager (zm_cp_custom_perks.gsc)
    lua/       menu, HUD and saved-settings Lua
    images/    PNG icons
```

## Put it on GitHub

1. Create a new repository on GitHub (empty: no README, licence or .gitignore).
2. Upload **the contents of this folder** to the repository root. Either:
   - drag everything in this folder onto the repository's **Add file > Upload files** page (include the hidden `.github` folder, `.gitignore` and `.gitattributes`), or
   - from this folder run:
     ```text
     git init -b main
     git add .
     git commit -m "Perk Workshop"
     git remote add origin https://github.com/YOUR-NAME/YOUR-REPO.git
     git push -u origin main
     ```
3. In the repository open **Settings > Pages** and set **Source** to **GitHub Actions**.
4. The **Publish Perk Workshop** workflow runs the tests, builds the site and publishes it on every push to `main`. You can also start it from the **Actions** tab. When it finishes, the site's address is shown in **Settings > Pages**, for example `https://YOUR-NAME.github.io/YOUR-REPO/`.

If your default branch isn't `main`, change the branch in `.github/workflows/pages.yml`.

## Local preview

Needs Node 20 or newer. Nothing to install.

```text
node tests/serve.cjs
```

Open http://127.0.0.1:4173 (set `PORT` to change it). Opening `index.html` directly from disk doesn't work: the bundled files have to be fetched over HTTP.

## What it does

- Lists the perks in the bundled Custom Perks snapshot, with icons, creators and augments.
- Adds perk GSC scripts by upload, drag and drop or the built-in editor, and creates new ones from a working template (health regeneration with a jump-height major).
- Writes everything a perk needs into the manager and Lua: menu entry, on/off switch with saved settings, augment menu, per-player co-op augment sync and HUD numbering. Removes perks cleanly, too.
- Perk codes 1-249. Augment sync ranges stay clear of other mods on the same channel (Ring of Fire 21000-21999, slot machine 23000, forge and bank 24000-24999).
- Imports PNG icons into the mod's `images` folder.
- Imports a previous pack, a zipped `custom_perks` folder or a whole install folder. Older installs that kept perks in `kronos/custom_scripts` and `kronos/Assets/Lua` are moved into the mod layout (only perk files are taken).
- Exports the whole mod as a ZIP with `INSTALL.txt`, `REMOVED_PERKS.txt` and SHA-256 hashes of every file.

The site checks perk definitions, ID/code collisions, file paths and Lua syntax. It doesn't compile GSC, install anything or test gameplay. Kronos compiles the scripts when the game starts; test each perk solo and in co-op. Browser work lives in memory, so export a ZIP before closing the page and import it next time.

`baselines/MAKE_A_PERK.txt` explains how to write a perk script. `baselines/perk_template.gsc.template` is the template.

## Updating the bundled snapshot

To ship a newer Custom Perks version, point the refresh script at an installed copy:

```text
node tests/refresh-baselines.cjs "C:/path/to/cod25/kronos/mods/custom_perks"
node tests/generator.test.mjs
```

It copies `mod.json`, `README.txt`, `scripts/*.gsc`, `lua/*.lua` and `images/*.png` (never compiled `.gscc` caches) and rewrites `baselines/manifest.json`, which the browser uses to verify every file. Only publish files you're allowed to share; the snapshot holds the mod, not the game.

## Tests

`node tests/generator.test.mjs` covers adding, reapplying and removing perks, every bundled perk, removing all perks, many perks at once, major-only and plain perks, reserved sync ranges, code limits, collisions, keeping hand-edited co-op routes, Lua syntax and ZIP round trips. Lua parsing uses luaparse 0.3.1 (MIT, `assets/vendor`).

For this release the generated manager, the manager with every perk removed and a template-made perk were also compiled with the BO7 compiler Kronos uses (`acts gscc ... -g bo7`). That proves they compile, not that they play correctly.
