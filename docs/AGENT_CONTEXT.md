# Agent context — TheFrontier

Godot 4.7.2 GDScript prototype. Owner: Adam. First-person shooter plus core defense. Multiplayer is not in this slice; keep rules out of input and drawing code so a host can own them later.

## Layout

| Path | Role |
| --- | --- |
| `data/modes/*.tres` | Selectable game modes (`GameModeDef`) |
| `scripts/core/` | Pure-ish rules: economy, placement, waves, win eval, catalogs, breach |
| `scripts/autoload/session.gd` | Only writer of `GameState` during a run |
| `scripts/autoload/game_bus.gd` | Signals from rules to views |
| `scripts/player/` | Local input + FPS presentation |
| `scripts/world/` | Arena assembly, core, nodes, relics |
| `scripts/buildings/` | Placeable actors |
| `scripts/waves/` | Director + mobs |
| `scripts/ui/` | Menu, HUD, pause, end card |
| `tests/run_tests.gd` | Headless Session + rules assertions |
| `tests/smoke_arena.gd` | Headless arena boot for real seconds |

Greybox helpers live in `scripts/world/greybox.gd`. Every placeholder root is named `Visual` and has `asset_slot` metadata (`core_engine`, `building_wall`, `mob_rusher`, …). Drop a Blender `.glb` in as that child and hide the primitive mesh.

## State vs presentation

`GameState` (`scripts/core/game_state.gd`) is the run snapshot: phase, wallets, occupied grid, building HP, weapon magazines, wave counters, core/player health, relics, escape flag, score.

`Session` applies **commands**:

- `cmd_gather`, `cmd_try_place`, `cmd_dismantle_at`
- `cmd_damage_core` / `cmd_heal_core`
- `cmd_damage_player` / `cmd_heal_player`
- `cmd_damage_building` / `cmd_heal_building`
- `cmd_apply_damage` / `cmd_resolve_hit` (hitscan, turret, trap, melee)
- `cmd_try_fire`, `cmd_start_reload`, `cmd_select_weapon`
- `cmd_try_turret_fire`, `cmd_trap_pulse`
- `cmd_collect_relic`, `cmd_mark_escape_built`
- `cmd_mob_spawned`, `cmd_mob_killed`
- `tick(delta)` for rest timers, respawn, fire/turret cooldown, and reload

Views listen to `GameBus`. They must not increment scrap, spend ammo, or apply building/mob/core damage themselves.

Player locomotion still runs locally (`PlayerController`). Hitscan rays stay in the view (need a `World3D`); the result is resolved through `Session.cmd_resolve_hit("player", …)`. Treat move as a client-prediction candidate. Do not hide economy, combat, or win checks inside `_input`.

## Pause

`Session.set_paused(true)` is a full sim halt. `tick` returns immediately: rest, respawn, fire cooldown, turret cooldown, and reload freeze. `PauseMenu` also pauses the scene tree so views stop. This is intentional — pause is not a HUD overlay. Tests assert `tick` is a no-op while `sim_paused`.

## Walls and enclosure

Placement does **not** reject a closed ring. Walls stay meaningful: they delay the wave.

`BreachRules` is a 4-way grid flood on `occupied_cells`. If the 3×3 core is unreachable from a mob cell, `blocking_serials` is the occupied frontier. Mobs then path to those buildings and melee them. Navmesh `is_target_reachable()` / `is_navigation_finished()` is a second trigger when the bake stalls them short of the core.

Building colliders fill the 2 m cell (`BuildingBase.footprint_collider_size`) so adjacent walls have no 0.3 m gap.

## Data-driven content

Add a mode: create `data/modes/05_whatever.tres` (`GameModeDef`) or extend `ModeCatalog`. Menu reads `ModeCatalog.all()`.

Add a wave: edit the tables in `WaveCatalog.campaign_waves()`. Endless growth is `WaveScaler.scale(n)` — keep it a pure function so tests stay cheap.

Add a building: `BuildingDef` in `BuildingCatalog`, a `BuildingBase` subclass, and a branch in `BuildingFactory`. Register HP through `Session.cmd_try_place`.

Add a mob: `MobDef` in `MobCatalog` and a row in a `WaveSpec`.

Add a weapon: `WeaponDef` in `WeaponCatalog`. Session equips the catalog in order.

## Simulation notes

- Grid is 2 m (`PlacementRules.CELL_SIZE`). Core occupies a 3×3 hole. Buildings store a serial so dismantle/death frees one instance, not every wall.
- Navmesh lives under `Arena/NavigationRegion3D`. Walls parent into `Obstacles` and set `GameBus.nav_dirty` so the region rebakes.
- Collision layers: 1 world, 2 player, 3 mobs, 4 buildings, 5 projectiles, 6 core, 7 resources.
- Target bias: rusher hybrid (player inside aggro, else core), ranger prefers player, tank always core. If the core is unreachable, mobs breach the blocking buildings.
- Player hitscan uses mask `1|4|8` so walls block shots, but `cmd_resolve_hit("player", …)` refuses damage to friendly buildings.
- Rest phases restock resource nodes to full (including partial drains) and a fraction of reserve ammo.

## Death and outcomes

`WinEvaluator` is the only win/lose decoder. Survive uses `survive_waves` and/or `survive_seconds`. Gather uses `relics_collected`. Escape uses `escape_ship_built`. Endless never returns victory. Core `<= 0` is always defeat.

Player HP, building HP, and ammo are session-authored. Local `Health` on the player/core/buildings is a mirror.

Endless spawns `relics_on_map` signal relics. Pickups add score only; they do not win.

## Tests

`tests/test_runner.tscn` runs `tests/run_tests.gd` and exits non-zero on failure. Drive rules through `Session.cmd_*` and `Session.tick`. Do not mutate a raw `GameState` to simulate a run. Scene-level smoke is `tests/smoke_arena.tscn` (real seconds, all four modes) and `tests/smoke_menu.tscn`.

## What is intentionally unfinished

No audio. No cooked Blender assets. No save/load. No networking. No controller glyphs. Turret/trap VFX are lights and primitives. See `docs/roadmap.md`.
