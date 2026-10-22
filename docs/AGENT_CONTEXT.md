# Agent context — TheFrontier

Godot 4.7.2 GDScript prototype. Owner: Adam. First-person shooter plus core defense. Multiplayer is not in this slice; keep rules out of input and drawing code so a host can own them later.

## Layout

| Path | Role |
| --- | --- |
| `data/modes/*.tres` | Selectable game modes (`GameModeDef`) |
| `scripts/core/` | Pure-ish rules: economy, placement, waves, win eval, catalogs |
| `scripts/autoload/session.gd` | Only writer of `GameState` during a run |
| `scripts/autoload/game_bus.gd` | Signals from rules to views |
| `scripts/player/` | Local input + FPS presentation |
| `scripts/world/` | Arena assembly, core, nodes, relics |
| `scripts/buildings/` | Placeable actors |
| `scripts/waves/` | Director + mobs |
| `scripts/ui/` | Menu, HUD, pause, end card |
| `tests/run_tests.gd` | Headless assertions |

Greybox helpers live in `scripts/world/greybox.gd`. Every placeholder root is named `Visual` and has `asset_slot` metadata (`core_engine`, `building_wall`, `mob_rusher`, …). Drop a Blender `.glb` in as that child and hide the primitive mesh.

## State vs presentation

`GameState` (`scripts/core/game_state.gd`) is the run snapshot: phase, wallets, occupied grid, wave counters, core/player health, relics, escape flag, score.

`Session` applies **commands**:

- `cmd_gather`, `cmd_try_place`, `cmd_dismantle_at`
- `cmd_damage_core` / `cmd_heal_core`
- `cmd_damage_player` / `cmd_heal_player`
- `cmd_collect_relic`, `cmd_mark_escape_built`
- `cmd_mob_spawned`, `cmd_mob_killed`
- `tick(delta)` for rest timers and respawn

Views listen to `GameBus`. They must not increment scrap or complete waves themselves.

Player locomotion and hitscan still run locally (`PlayerController`, `WeaponController`). Treat those as client prediction candidates: a future server should accept `MoveIntent` / `FireIntent` / `PlaceIntent` and echo results. Do not hide economy or win checks inside `_input`.

## Data-driven content

Add a mode: create `data/modes/05_whatever.tres` (`GameModeDef`) or extend `ModeCatalog`. Menu reads `ModeCatalog.all()`.

Add a wave: edit the tables in `WaveCatalog.campaign_waves()`. Endless growth is `WaveScaler.scale(n)` — keep it a pure function so tests stay cheap.

Add a building: `BuildingDef` in `BuildingCatalog`, a `BuildingBase` subclass, and a branch in `BuildingFactory`.

Add a mob: `MobDef` in `MobCatalog` and a row in a `WaveSpec`.

Add a weapon: `WeaponDef` in `WeaponCatalog`. The player equips the catalog in order.

## Simulation notes

- Grid is 2 m (`PlacementRules.CELL_SIZE`). Core occupies a 3×3 hole. Buildings store a serial so dismantle/death frees one instance, not every wall.
- Navmesh lives under `Arena/NavigationRegion3D`. Walls parent into `Obstacles` and set `GameBus.nav_dirty` so the region rebakes.
- Collision layers: 1 world, 2 player, 3 mobs, 4 buildings, 5 projectiles, 6 core, 7 resources.
- Target bias: rusher hybrid (player inside aggro, else core), ranger prefers player, tank always core. Mobs melee walls they raycast into.
- Rest phases restock depleted resource nodes and a fraction of reserve ammo.

## Death and outcomes

`WinEvaluator` is the only win/lose decoder. Survive uses `survive_waves` and/or `survive_seconds`. Gather uses `relics_collected`. Escape uses `escape_ship_built`. Endless never returns victory. Core `<= 0` is always defeat.

Player HP is session-authored. Local `Health` on the player/core is a mirror.

## Tests

`tests/run_tests.gd` extends `SceneTree` and exits non-zero on failure. Prefer adding cases there for any new rule. Do not require a window. Scene-level smoke is `godot --headless --quit-after 2`.

## What is intentionally unfinished

No audio. No cooked Blender assets. No save/load. No networking. No controller glyphs. Turret/trap VFX are lights and primitives. See `docs/roadmap.md`.
