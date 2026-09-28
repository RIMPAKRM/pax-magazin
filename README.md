# Material Shop

A mod for Pax Universe.

- `mod.json` — id, name, version, dependencies
- `main.gd` — code (optional; delete it and the `"entry"` line for a data-only mod)
- `data/` — changes to game data (`*.patch.json`) and translations (`lang/`)
- `thumbnail.png` — 256×256 picture shown in the launcher (add your own)

Check: `godot --headless --path <game> -- --check-mods material_shop` · Pack: `-- --pack-mod material_shop`
