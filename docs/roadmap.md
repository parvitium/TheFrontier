# Roadmap

## Vertical slice (this branch)

Playable FPS + core defense loop with four data-driven modes, three mobs, four standard buildings plus the escape ship, two weapons, gatherable scrap/crystal, navmesh-aware walls with breach AI, Session-authored combat/ammo/building HP, headless tests, and CI.

## Next

### Feel and presentation

- Replace `Visual` greyboxes with Blender `.glb` kits (core, walls, turret, trap, beacon, ship, three mobs, rifle, shotgun, scrap, crystal, relics).
- Animation: mob run/attack, turret yaw, ship land, player arms.
- Audio: fire, reload, gather, place, wave stinger, core alarm (CC0 or original only).
- Recoil, muzzle tracers, hit sparks, damage numbers, core heat shader.
- Controller support and remappable input.

### Systems

- More buildings: gates, mines, resource silos, ammo fabricator, tesla coil.
- Elite / bomber mobs and wave modifiers (fog, night, double rushers).
- Tech unlocks between waves instead of everything available at minute zero.
- Core upgrades (armor, pulse knockback).
- Mini-map and build radial.
- Difficulty presets as extra `GameModeDef` fields.

### Modes and meta

- Survive-by-time variant (`survive_seconds` is already evaluated).
- Contract board: combine gather + survive objectives.
- Persistent endless leaderboard (local first).
- Short campaign stitching modes as scenes.

### Multiplayer (later)

- Promote `Session` to a host-only authority (economy, combat resolution, building HP, and ammo already live there).
- Replicate `GameState` snapshots + `GameBus` events.
- Send intents: move, look, fire, reload, gather, place, dismantle.
- Keep catalogs, `WinEvaluator`, and `BreachRules` shared and deterministic.
- Delay any Steam/EOS work until the single-player loop is fun.

### Production

- Export presets (Windows / Linux).
- Options menu (mouse sens, FOV, volume).
- Save hot-path settings only; runs can stay ephemeral.
- Broader CI: GDScript lint (`godot --headless --script` parse).
