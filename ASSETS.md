# Assets and licenses

All third-party art in this repository is **CC0 1.0** (public domain). Meshes, UI chrome, and audio that are not listed below are original to The Frontier (same MIT terms as the code, with no extra restrictions). No paid services or paid asset packs are used.

## Textures (Poly Haven, CC0 1.0)

Downloaded as 1k/2k JPG albedo, OpenGL normal, roughness, AO, and metal where the set includes it.

| Asset | Use | URL |
| --- | --- | --- |
| metal_plate | Sci-fi kit metal | https://polyhaven.com/a/metal_plate |
| rusty_metal_02 | Rusted steel, scrap | https://polyhaven.com/a/rusty_metal_02 |
| concrete_floor_02 | Walls, pads, plinths | https://polyhaven.com/a/concrete_floor_02 |
| rock_face | Cliffs, cover rock | https://polyhaven.com/a/rock_face |
| sand_01 | Basin sand blend | https://polyhaven.com/a/sand_01 |
| brown_mud_03 | Packed dirt blend | https://polyhaven.com/a/brown_mud_03 |

Authors are credited on each Poly Haven asset page. CC0 does not require attribution; they are listed so the source is auditable.

## HDRI (Poly Haven, CC0 1.0)

| Asset | Use | URL |
| --- | --- | --- |
| qwantani_dusk_2_puresky (2k HDR) | Dusk desert sky / IBL, no man-made skyline | https://polyhaven.com/a/qwantani_dusk_2_puresky |

## Original meshes

Headless Blender 4.2 kitbash in `tools/blender_kit.py`, exported to `assets/models/*.glb`:

- core_engine, wall, turret, trap, repair_beacon, escape_ship, storage_tank
- rock_a / rock_b / rock_c
- mob_rusher, mob_ranger, mob_tank (walk cycle)
- pulse_rifle, scatter_cannon (Muzzle empties)
- scrap, crystal, relic, title_emblem

## Original audio

Synthesized WAVs from `tools/make_sfx.py` (no samples from other works):

- ui_hover, ui_click, ui_back
- fire_rifle, fire_shotgun, turret_shot, place_build

## Engine

Godot 4.7.2, MIT. https://godotengine.org/license
