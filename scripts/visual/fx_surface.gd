class_name FxSurface
extends RefCounted

## Classifies a hit so CombatFx can pick sparks, blood, bone, or dust.
## Pure — no nodes, safe to call from headless tests.

const ORGANIC := "organic"
const SKELETAL := "skeletal"
const METAL := "metal"
const TERRAIN := "terrain"
const MAGICAL := "magical"

const SHOT_KINETIC := "kinetic"
const SHOT_FIRE := "fire"
const SHOT_ICE := "ice"
const SHOT_SPELL := "spell"

const SURFACES: Array[String] = [ORGANIC, SKELETAL, METAL, TERRAIN, MAGICAL]
const SHOTS: Array[String] = [SHOT_KINETIC, SHOT_FIRE, SHOT_ICE, SHOT_SPELL]


static func of_collider(collider: Object) -> String:
	if collider == null:
		return TERRAIN
	if collider is MobActor:
		return of_mob_def((collider as MobActor).def)
	if collider is Node:
		var node := collider as Node
		if node.is_in_group("mobs"):
			if node is MobActor:
				return of_mob_def((node as MobActor).def)
			return ORGANIC
		if node.is_in_group("buildings") or node is BuildingBase:
			return METAL
		if node.is_in_group("core"):
			return METAL
		if node.is_in_group("player"):
			return ORGANIC
	return TERRAIN


static func of_mob_def(def: MobDef) -> String:
	if def == null:
		return ORGANIC
	match def.body_kind:
		MobDef.BodyKind.SKELETAL:
			return SKELETAL
		MobDef.BodyKind.MECHANICAL:
			return METAL
		MobDef.BodyKind.MAGICAL:
			return MAGICAL
		_:
			return ORGANIC


static func normalize_shot(shot_vfx: String) -> String:
	if SHOTS.has(shot_vfx):
		return shot_vfx
	return SHOT_KINETIC


static func death_explodes(surface: String) -> bool:
	return surface == METAL or surface == MAGICAL


static func size_scale(collider: Object) -> float:
	if collider is MobActor:
		var actor := collider as MobActor
		if actor.def:
			return clampf(actor.def.radius * actor.def.height * 0.5, 0.65, 2.6)
	return 1.0


static func shot_color(shot_vfx: String) -> Color:
	match normalize_shot(shot_vfx):
		SHOT_FIRE:
			return Color(1.0, 0.48, 0.16)
		SHOT_ICE:
			return Color(0.62, 0.86, 1.0)
		SHOT_SPELL:
			return Color(0.45, 0.82, 1.0)
		_:
			return Color(1.0, 0.78, 0.34)
