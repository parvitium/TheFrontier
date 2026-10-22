# Visual slots

Actors still spawn a `Visual` child with `asset_slot` metadata. `VisualKit` instances the matching `.glb` from `assets/models/` and remaps materials to CC0 PBR sets.

| Slot | File |
| --- | --- |
| `core_engine` | `core_engine.glb` |
| `building_wall` | `wall.glb` |
| `building_turret` | `turret.glb` (`Head`, `Muzzle`) |
| `building_trap` | `trap.glb` |
| `building_repair_beacon` | `repair_beacon.glb` |
| `building_escape_ship` | `escape_ship.glb` |
| `mob_rusher` / `mob_ranger` / `mob_tank` | matching `mob_*.glb` |
| `pulse_rifle` / `scatter_cannon` | weapons with `Muzzle` |
| `resource_scrap` / `resource_crystal` | `scrap.glb` / `crystal.glb` |
| `signal_relic` | `relic.glb` |

Collision stays in code. Sources: `ASSETS.md`.
