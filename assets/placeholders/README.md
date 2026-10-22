# Placeholder visuals

Every spawned actor builds a child named `Visual` with `asset_slot` metadata. That node is the swap point for a Blender export.

Suggested slots:

- `core_engine`
- `player`
- `building_wall`, `building_turret`, `building_trap`, `building_repair_beacon`, `building_escape_ship`
- `mob_rusher`, `mob_ranger`, `mob_tank`
- `resource_scrap`, `resource_crystal`
- `signal_relic`

Workflow:

1. Model in Blender at 1 unit = 1 meter. Origin at ground center.
2. Export glTF Binary (`.glb`), Y-up, no paid kits.
3. Instance the `.glb` under `Visual` and hide or delete the primitive `MeshInstance3D`.
4. Keep collision shapes in code or in a sibling `CollisionShape3D` so gameplay does not depend on art bounds.

All current meshes are original greybox primitives. No third-party packs.
