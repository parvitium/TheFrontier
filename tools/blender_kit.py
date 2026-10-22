#!/usr/bin/env python3
"""Headless Blender kitbash: sci-fi outpost, creatures, rifle. Original CC0 meshes."""

import math
import os
import random
import sys

import bpy
from mathutils import Vector

OUT = os.environ.get("KIT_OUT", "/workspace/assets/models")
os.makedirs(OUT, exist_ok=True)
FPS = 24


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 24
    bpy.context.scene.unit_settings.system = "METRIC"


def mat(name, color, metallic=0.0, roughness=0.45, emission=None, e_str=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    principled = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    principled.inputs["Base Color"].default_value = (*color, 1.0)
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    if emission is not None:
        key = "Emission Color" if "Emission Color" in principled.inputs else "Emission"
        principled.inputs[key].default_value = (*emission, 1.0)
        strength = "Emission Strength" if "Emission Strength" in principled.inputs else None
        if strength:
            principled.inputs[strength].default_value = e_str
    return m


METAL = None
PAINT = None
RUST = None
CONCRETE = None
EMIT_A = None
EMIT_C = None
EMIT_R = None
DARK = None
RUBBER = None
FLESH = None
SHELL = None
GLASS = None
SAND = None


def mats():
    global METAL, PAINT, RUST, CONCRETE, EMIT_A, EMIT_C, EMIT_R, DARK, RUBBER, FLESH, SHELL, GLASS, SAND
    METAL = mat("Metal", (0.42, 0.45, 0.48), 0.85, 0.32)
    PAINT = mat("PaintedMetal", (0.18, 0.22, 0.24), 0.55, 0.4)
    RUST = mat("Rust", (0.38, 0.22, 0.12), 0.55, 0.62)
    CONCRETE = mat("Concrete", (0.48, 0.46, 0.42), 0.02, 0.86)
    EMIT_A = mat("EmissiveAmber", (1.0, 0.62, 0.18), 0.1, 0.22, (1.0, 0.55, 0.12), 8.0)
    EMIT_C = mat("EmissiveCyan", (0.25, 0.85, 1.0), 0.2, 0.18, (0.2, 0.9, 1.0), 7.0)
    EMIT_R = mat("EmissiveRed", (1.0, 0.18, 0.12), 0.1, 0.2, (1.0, 0.15, 0.08), 6.0)
    DARK = mat("DarkMetal", (0.08, 0.09, 0.1), 0.7, 0.38)
    RUBBER = mat("Rubber", (0.08, 0.08, 0.08), 0.0, 0.78)
    FLESH = mat("CreatureFlesh", (0.45, 0.12, 0.1), 0.05, 0.48)
    SHELL = mat("CreatureShell", (0.22, 0.26, 0.28), 0.35, 0.4)
    GLASS = mat("Glass", (0.4, 0.7, 0.85), 0.1, 0.08, (0.3, 0.7, 1.0), 1.2)
    SAND = mat("Sand", (0.55, 0.42, 0.26), 0.0, 0.92)


def apply_mat(ob, m):
    if ob.data and hasattr(ob.data, "materials"):
        ob.data.materials.clear()
        ob.data.materials.append(m)


def cube(name, size, loc, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    ob = bpy.context.active_object
    ob.name = name
    sx, sy, sz = size if isinstance(size, tuple) else (size, size, size)
    ob.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(scale=True)
    apply_mat(ob, material)
    return ob


def cyl(name, r, h, loc, material, verts=16, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, vertices=verts, location=loc, rotation=rot)
    ob = bpy.context.active_object
    ob.name = name
    apply_mat(ob, material)
    return ob


def sphere(name, r, loc, material, segs=16):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=segs, ring_count=max(8, segs // 2))
    ob = bpy.context.active_object
    ob.name = name
    apply_mat(ob, material)
    return ob


def cone(name, r, h, loc, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(radius1=r, depth=h, location=loc, rotation=rot, vertices=12)
    ob = bpy.context.active_object
    ob.name = name
    apply_mat(ob, material)
    return ob


def empty(name, loc):
    bpy.ops.object.empty_add(type="PLAIN_AXES", location=loc)
    ob = bpy.context.active_object
    ob.name = name
    return ob


def parent(child, parent_ob):
    child.parent = parent_ob
    child.matrix_parent_inverse = parent_ob.matrix_world.inverted()


def bevel(ob, width=0.02, segments=2):
    mod = ob.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"


def unwrap(ob):
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")


def shade_auto(ob):
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    except Exception:
        bpy.ops.object.shade_smooth()


def join_named(name, objects, material=None):
    if not objects:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = name
    if material:
        apply_mat(ob, material)
    bevel(ob, 0.018, 2)
    unwrap(ob)
    shade_auto(ob)
    return ob


def select_only(obs):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in obs:
        if ob:
            ob.select_set(True)
            bpy.context.view_layer.objects.active = ob


def export_glb(path, objects):
    select_only(objects)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_tangents=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_animations=True,
        export_force_sampling=True,
        export_nla_strips=False,
        export_anim_single_armature=True,
        export_yup=True,
    )
    print("exported", path)


def greebles(parent_ob, rng, count, span, y, material):
    bits = []
    for i in range(count):
        s = (rng.uniform(0.08, 0.22), rng.uniform(0.06, 0.16), rng.uniform(0.08, 0.2))
        loc = (
            rng.uniform(-span[0], span[0]),
            rng.uniform(-span[1], span[1]),
            y + rng.uniform(0.0, span[2]),
        )
        b = cube(f"{parent_ob.name}_g{i}", s, loc, material)
        parent(b, parent_ob)
        bits.append(b)
    return bits


# --- models ---


def make_core():
    reset()
    mats()
    root = empty("core_engine", (0, 0, 0))
    ped = cyl("Pedestal", 1.55, 1.05, (0, 0, 0.52), CONCRETE, 24)
    ring = cyl("Ring", 1.72, 0.18, (0, 0, 1.05), METAL, 24)
    collar = cyl("Collar", 0.7, 0.28, (0, 0, 1.22), DARK, 16)
    coil = cyl("Coil", 0.42, 2.15, (0, 0, 2.2), PAINT, 20)
    fins = []
    for i in range(6):
        a = i / 6 * math.tau
        f = cube(f"Fin{i}", (0.08, 0.55, 1.6), (math.cos(a) * 0.7, math.sin(a) * 0.7, 2.15), METAL)
        f.rotation_euler = (0, 0, a)
        bpy.ops.object.transform_apply(rotation=True)
        fins.append(f)
    pipes = []
    for i, ang in enumerate((0.4, 2.2, 4.0)):
        p = cyl(f"Pipe{i}", 0.08, 1.8, (math.cos(ang) * 1.15, math.sin(ang) * 1.15, 1.4), RUST, 10)
        pipes.append(p)
        elbow = sphere(f"Elbow{i}", 0.11, (math.cos(ang) * 1.15, math.sin(ang) * 1.15, 2.25), RUST, 10)
        pipes.append(elbow)
    strips = []
    for i in range(8):
        a = i / 8 * math.tau
        s = cube(f"Strip{i}", (0.06, 0.08, 1.4), (math.cos(a) * 0.48, math.sin(a) * 0.48, 2.15), EMIT_C)
        strips.append(s)
    heart = sphere("Heart", 0.62, (0, 0, 3.35), EMIT_A, 24)
    cap = cyl("Cap", 0.55, 0.16, (0, 0, 3.95), METAL, 16)
    for ob in [ped, ring, collar, coil, *fins, *pipes, *strips, heart, cap]:
        parent(ob, root)
        if ob != heart:
            bevel(ob, 0.015, 2)
            unwrap(ob)
            shade_auto(ob)
        else:
            shade_auto(ob)
    export_glb(os.path.join(OUT, "core_engine.glb"), [root] + list(root.children_recursive))


def make_wall():
    reset()
    mats()
    root = empty("wall", (0, 0, 0))
    hull = cube("Hull", (1.98, 1.98, 2.15), (0, 0, 1.08), CONCRETE)
    plate = cube("Plate", (1.86, 0.12, 1.7), (0, 0.95, 1.15), METAL)
    plate2 = cube("PlateB", (1.86, 0.12, 1.7), (0, -0.95, 1.15), METAL)
    rim = cube("Rim", (2.0, 2.0, 0.12), (0, 0, 2.18), METAL)
    lights = []
    for x in (-0.7, 0.7):
        lights.append(cube(f"Lite{x}", (0.35, 0.08, 0.08), (x, 0.98, 1.9), EMIT_C))
    bolt_bits = []
    rng = random.Random(3)
    for i in range(10):
        bx = rng.uniform(-0.8, 0.8)
        bz = rng.uniform(0.35, 1.85)
        bolt_bits.append(cyl(f"Bolt{i}", 0.04, 0.08, (bx, 1.02, bz), DARK, 8, (math.pi / 2, 0, 0)))
    for ob in [hull, plate, plate2, rim, *lights, *bolt_bits]:
        parent(ob, root)
        unwrap(ob)
        shade_auto(ob)
    export_glb(os.path.join(OUT, "wall.glb"), [root] + list(root.children_recursive))


def make_turret():
    reset()
    mats()
    root = empty("turret", (0, 0, 0))
    base = cyl("Base", 0.62, 0.38, (0, 0, 0.2), CONCRETE, 18)
    skirt = cyl("Skirt", 0.72, 0.1, (0, 0, 0.05), METAL, 18)
    pole = cyl("Pole", 0.14, 0.85, (0, 0, 0.72), DARK, 12)
    head = empty("Head", (0, 0, 1.12))
    housing = cube("Housing", (0.55, 0.42, 0.32), (0, 0, 1.12), PAINT)
    barrel = cyl("Barrel", 0.07, 0.85, (0, 0.48, 1.14), METAL, 12, (math.pi / 2, 0, 0))
    barrel2 = cyl("BarrelB", 0.05, 0.55, (0.12, 0.38, 1.08), DARK, 10, (math.pi / 2, 0, 0))
    optic = sphere("Optic", 0.08, (0, 0.22, 1.22), EMIT_C, 12)
    muzzle = empty("Muzzle", (0, 0.92, 1.14))
    for ob in [base, skirt, pole]:
        parent(ob, root)
        unwrap(ob)
        shade_auto(ob)
    for ob in [housing, barrel, barrel2, optic, muzzle]:
        parent(ob, head)
        if ob.type == "MESH":
            unwrap(ob)
            shade_auto(ob)
    parent(head, root)
    export_glb(os.path.join(OUT, "turret.glb"), [root] + list(root.children_recursive))


def make_trap():
    reset()
    mats()
    root = empty("trap", (0, 0, 0))
    pad = cube("Pad", (1.85, 1.85, 0.1), (0, 0, 0.06), DARK)
    grate = cube("Grate", (1.6, 1.6, 0.04), (0, 0, 0.12), METAL)
    spikes = []
    for i in range(9):
        x = (i % 3 - 1) * 0.45
        y = (i // 3 - 1) * 0.45
        spikes.append(cone(f"Spike{i}", 0.07, 0.42, (x, y, 0.32), RUST))
    warn = []
    for x, y in ((0.8, 0.8), (-0.8, 0.8), (0.8, -0.8), (-0.8, -0.8)):
        warn.append(cube(f"Warn{x}{y}", (0.12, 0.12, 0.08), (x, y, 0.14), EMIT_R))
    for ob in [pad, grate, *spikes, *warn]:
        parent(ob, root)
        unwrap(ob)
        shade_auto(ob)
    export_glb(os.path.join(OUT, "trap.glb"), [root] + list(root.children_recursive))


def make_beacon():
    reset()
    mats()
    root = empty("repair_beacon", (0, 0, 0))
    foot = cyl("Foot", 0.55, 0.16, (0, 0, 0.08), CONCRETE, 16)
    stem = cyl("Stem", 0.1, 1.25, (0, 0, 0.75), METAL, 12)
    dish = cyl("Dish", 0.72, 0.12, (0, 0, 1.42), PAINT, 20)
    dish.scale = (1.0, 1.0, 0.45)
    bpy.ops.object.transform_apply(scale=True)
    hub = sphere("Hub", 0.16, (0, 0, 1.5), EMIT_C, 12)
    ring = cyl("Halo", 0.4, 0.05, (0, 0, 1.62), EMIT_C, 16)
    for ob in [foot, stem, dish, hub, ring]:
        parent(ob, root)
        unwrap(ob)
        shade_auto(ob)
    export_glb(os.path.join(OUT, "repair_beacon.glb"), [root] + list(root.children_recursive))


def make_ship():
    reset()
    mats()
    root = empty("escape_ship", (0, 0, 0))
    hull = cube("Hull", (3.4, 1.7, 1.05), (0, 0, 0.85), PAINT)
    bevel(hull, 0.08, 3)
    nose = cube("Nose", (1.15, 1.15, 0.7), (1.9, 0, 0.82), METAL)
    bevel(nose, 0.06, 3)
    cabin = cube("Cabin", (1.1, 1.2, 0.55), (0.4, 0, 1.45), GLASS)
    fin = cube("Fin", (0.18, 0.7, 1.35), (-1.4, 0, 1.55), DARK)
    engine_l = cyl("EngineL", 0.22, 0.55, (-1.7, 0.45, 0.7), METAL, 12, (0, math.pi / 2, 0))
    engine_r = cyl("EngineR", 0.22, 0.55, (-1.7, -0.45, 0.7), METAL, 12, (0, math.pi / 2, 0))
    glow_l = sphere("GlowL", 0.18, (-2.05, 0.45, 0.7), EMIT_A, 10)
    glow_r = sphere("GlowR", 0.18, (-2.05, -0.45, 0.7), EMIT_A, 10)
    strut = cube("Strut", (0.12, 1.6, 0.12), (0.2, 0, 0.28), RUST)
    for ob in [hull, nose, cabin, fin, engine_l, engine_r, glow_l, glow_r, strut]:
        parent(ob, root)
        unwrap(ob)
        shade_auto(ob)
    export_glb(os.path.join(OUT, "escape_ship.glb"), [root] + list(root.children_recursive))


def make_tank_prop():
    reset()
    mats()
    root = empty("storage_tank", (0, 0, 0))
    body = cyl("Body", 0.85, 2.4, (0, 0, 1.2), PAINT, 20)
    cap = sphere("Dome", 0.85, (0, 0, 2.4), METAL, 16)
    cap.scale = (1, 1, 0.45)
    bpy.ops.object.transform_apply(scale=True)
    pipe = cyl("Pipe", 0.12, 1.4, (0.95, 0, 0.9), RUST, 10)
    valve = cube("Valve", (0.28, 0.28, 0.2), (0.95, 0, 1.65), DARK)
    stripe = cube("Stripe", (1.75, 0.12, 0.18), (0, 0, 1.5), EMIT_A)
    for ob in [body, cap, pipe, valve, stripe]:
        parent(ob, root)
        unwrap(ob)
        shade_auto(ob)
    export_glb(os.path.join(OUT, "storage_tank.glb"), [root] + list(root.children_recursive))


def make_rock(name, seed, scale):
    reset()
    mats()
    rng = random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=(0, 0, 0.55 * scale[2]))
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.vertices_smooth(factor=0.4)
    bpy.ops.object.mode_set(mode="OBJECT")
    for v in ob.data.vertices:
        jitter = Vector((rng.uniform(-0.18, 0.18), rng.uniform(-0.18, 0.18), rng.uniform(-0.12, 0.22)))
        v.co += jitter
    apply_mat(ob, CONCRETE if seed % 2 else RUST)
    # rock uses concrete-ish albedo; Godot remaps to rock PBR
    apply_mat(ob, mat("Rock", (0.36, 0.34, 0.3), 0.02, 0.9))
    unwrap(ob)
    shade_auto(ob)
    export_glb(os.path.join(OUT, f"{name}.glb"), [ob])


def make_scrap():
    reset()
    mats()
    root = empty("scrap", (0, 0, 0))
    bits = []
    rng = random.Random(9)
    for i in range(7):
        s = (rng.uniform(0.25, 0.7), rng.uniform(0.2, 0.55), rng.uniform(0.12, 0.35))
        loc = (rng.uniform(-0.35, 0.35), rng.uniform(-0.3, 0.3), s[2] * 0.5)
        bits.append(cube(f"Bit{i}", s, loc, RUST if i % 2 else METAL, (0, 0, rng.uniform(0, 1))))
    for ob in bits:
        parent(ob, root)
        unwrap(ob)
        shade_auto(ob)
    export_glb(os.path.join(OUT, "scrap.glb"), [root] + list(root.children_recursive))


def make_crystal():
    reset()
    mats()
    root = empty("crystal", (0, 0, 0))
    shards = []
    for i, (r, h, loc, rot) in enumerate(
        [
            (0.18, 1.35, (0, 0, 0.7), (0.12, 0, 0)),
            (0.12, 0.95, (0.16, 0.05, 0.5), (0.3, 0.1, 0.4)),
            (0.1, 0.7, (-0.14, -0.08, 0.4), (-0.25, 0.2, -0.3)),
        ]
    ):
        shards.append(cone(f"Shard{i}", r, h, loc, EMIT_C, rot))
    base = cyl("Base", 0.28, 0.16, (0, 0, 0.08), DARK, 10)
    for ob in shards + [base]:
        parent(ob, root)
        unwrap(ob)
        shade_auto(ob)
    export_glb(os.path.join(OUT, "crystal.glb"), [root] + list(root.children_recursive))


def make_relic():
    reset()
    mats()
    root = empty("relic", (0, 0, 0))
    body = cube("Body", (0.55, 0.55, 0.55), (0, 0, 0.7), METAL)
    bevel(body, 0.06, 3)
    gem = sphere("Gem", 0.22, (0, 0, 0.7), EMIT_A, 16)
    ring = cyl("Ring", 0.38, 0.06, (0, 0, 0.98), EMIT_C, 16)
    for ob in [body, gem, ring]:
        parent(ob, root)
        unwrap(ob)
        shade_auto(ob)
    export_glb(os.path.join(OUT, "relic.glb"), [root] + list(root.children_recursive))


def make_rifle():
    reset()
    mats()
    root = empty("pulse_rifle", (0, 0, 0))
    body = cube("Body", (0.08, 0.55, 0.12), (0, 0.05, 0), DARK)
    receiver = cube("Receiver", (0.09, 0.22, 0.14), (0, -0.12, 0.02), PAINT)
    barrel = cyl("Barrel", 0.025, 0.42, (0, 0.42, 0.03), METAL, 10, (math.pi / 2, 0, 0))
    mag = cube("Mag", (0.06, 0.08, 0.16), (0, -0.02, -0.12), DARK)
    stock = cube("Stock", (0.07, 0.18, 0.09), (0, -0.32, 0.0), RUBBER)
    sight = cube("Sight", (0.03, 0.08, 0.06), (0, 0.1, 0.1), EMIT_C)
    muzzle = empty("Muzzle", (0, 0.64, 0.03))
    for ob in [body, receiver, barrel, mag, stock, sight, muzzle]:
        parent(ob, root)
        if ob.type == "MESH":
            unwrap(ob)
            shade_auto(ob)
    export_glb(os.path.join(OUT, "pulse_rifle.glb"), [root] + list(root.children_recursive))


def make_shotgun():
    reset()
    mats()
    root = empty("scatter_cannon", (0, 0, 0))
    body = cube("Body", (0.11, 0.42, 0.13), (0, 0.02, 0), RUST)
    barrel = cyl("Barrel", 0.04, 0.32, (0, 0.32, 0.02), METAL, 10, (math.pi / 2, 0, 0))
    barrel2 = cyl("BarrelB", 0.04, 0.32, (0, 0.32, -0.04), METAL, 10, (math.pi / 2, 0, 0))
    stock = cube("Stock", (0.08, 0.2, 0.1), (0, -0.26, -0.02), RUBBER)
    grip = cube("Grip", (0.06, 0.07, 0.14), (0, -0.08, -0.12), DARK)
    muzzle = empty("Muzzle", (0, 0.5, 0.0))
    for ob in [body, barrel, barrel2, stock, grip, muzzle]:
        parent(ob, root)
        if ob.type == "MESH":
            unwrap(ob)
            shade_auto(ob)
    export_glb(os.path.join(OUT, "scatter_cannon.glb"), [root] + list(root.children_recursive))


def make_emblem():
    reset()
    mats()
    root = empty("title_emblem", (0, 0, 0))
    ring = cyl("Ring", 0.55, 0.08, (0, 0, 0), METAL, 24)
    core = sphere("Core", 0.22, (0, 0, 0), EMIT_A, 16)
    spike_n = cone("N", 0.08, 0.55, (0, 0.55, 0), PAINT, (math.pi / 2, 0, 0))
    spike_s = cone("S", 0.08, 0.55, (0, -0.55, 0), PAINT, (-math.pi / 2, 0, 0))
    spike_e = cone("E", 0.08, 0.55, (0.55, 0, 0), PAINT, (0, 0, -math.pi / 2))
    spike_w = cone("W", 0.08, 0.55, (-0.55, 0, 0), PAINT, (0, 0, math.pi / 2))
    for ob in [ring, core, spike_n, spike_s, spike_e, spike_w]:
        parent(ob, root)
        unwrap(ob)
        shade_auto(ob)
    export_glb(os.path.join(OUT, "title_emblem.glb"), [root] + list(root.children_recursive))


def _limb(name, size, loc, material):
    return cube(name, size, loc, material)


def make_creature(kind):
    reset()
    mats()
    rng = random.Random({"rusher": 1, "ranger": 2, "tank": 3}[kind])
    root_empty = empty(f"mob_{kind}", (0, 0, 0))

    if kind == "rusher":
        height = 1.15
        torso = cube("Torso", (0.42, 0.7, 0.32), (0, 0, 0.85), FLESH)
        head = sphere("Head", 0.2, (0, 0.42, 1.05), FLESH, 12)
        jaw = cube("Jaw", (0.22, 0.28, 0.1), (0, 0.55, 0.92), DARK)
        eye_l = sphere("EyeL", 0.05, (-0.08, 0.55, 1.12), EMIT_R, 8)
        eye_r = sphere("EyeR", 0.05, (0.08, 0.55, 1.12), EMIT_R, 8)
        legs = []
        for i, x in enumerate((-0.22, 0.22)):
            for j, y in enumerate((-0.22, 0.28)):
                legs.append(cyl(f"Leg{i}{j}", 0.05, 0.7, (x, y, 0.38), SHELL, 8, (0.35 if y > 0 else -0.2, 0, x * 0.8)))
        spines = [cone(f"Spine{i}", 0.04, 0.22, (0, -0.1 + i * 0.15, 1.05), DARK, (0.8, 0, 0)) for i in range(3)]
        meshes = [torso, head, jaw, eye_l, eye_r, *legs, *spines]
    elif kind == "ranger":
        height = 1.55
        torso = cube("Torso", (0.38, 0.28, 0.7), (0, 0, 1.05), SHELL)
        pelvis = cube("Pelvis", (0.34, 0.24, 0.22), (0, 0, 0.62), DARK)
        head = cube("Head", (0.28, 0.3, 0.28), (0, 0.02, 1.52), PAINT)
        visor = cube("Visor", (0.24, 0.08, 0.1), (0, 0.16, 1.54), EMIT_C)
        arm_l = cyl("ArmL", 0.05, 0.55, (-0.28, 0.05, 1.05), METAL, 8)
        arm_r = cyl("ArmR", 0.05, 0.55, (0.28, 0.05, 1.05), METAL, 8)
        gun = cube("Gun", (0.08, 0.42, 0.1), (0.32, 0.28, 0.95), DARK)
        leg_l = cyl("LegL", 0.07, 0.7, (-0.12, 0, 0.35), SHELL, 8)
        leg_r = cyl("LegR", 0.07, 0.7, (0.12, 0, 0.35), SHELL, 8)
        meshes = [torso, pelvis, head, visor, arm_l, arm_r, gun, leg_l, leg_r]
    else:
        height = 1.85
        torso = cube("Torso", (0.85, 0.7, 0.85), (0, 0, 1.2), SHELL)
        plow = cube("Plow", (0.95, 0.22, 0.55), (0, 0.42, 0.85), METAL)
        head = cube("Head", (0.5, 0.4, 0.35), (0, 0.2, 1.75), PAINT)
        optic = sphere("Optic", 0.09, (0, 0.4, 1.78), EMIT_A, 10)
        leg_l = cube("LegL", (0.28, 0.35, 0.85), (-0.28, 0, 0.45), DARK)
        leg_r = cube("LegR", (0.28, 0.35, 0.85), (0.28, 0, 0.45), DARK)
        shoulder = cube("Shoulder", (1.05, 0.35, 0.28), (0, 0, 1.55), RUST)
        meshes = [torso, plow, head, optic, leg_l, leg_r, shoulder]

    for ob in meshes:
        parent(ob, root_empty)
        unwrap(ob)
        shade_auto(ob)

    # Simple walk: bob + yaw the whole visual (robust in Godot even without bones).
    root_empty.rotation_mode = "XYZ"
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 24
    for fr, zoff, yaw in ((1, 0.0, -0.08), (7, 0.06, 0.0), (13, 0.0, 0.08), (19, 0.06, 0.0), (24, 0.0, -0.08)):
        bpy.context.scene.frame_set(fr)
        root_empty.location = (0, 0, zoff)
        root_empty.rotation_euler = (0, 0, yaw)
        root_empty.keyframe_insert("location", frame=fr)
        root_empty.keyframe_insert("rotation_euler", frame=fr)
    if root_empty.animation_data and root_empty.animation_data.action:
        root_empty.animation_data.action.name = "walk"

    # extra loc-rot on legs if present
    for ob in meshes:
        if ob.name.startswith("Leg"):
            side = -1.0 if "L" in ob.name or ob.location.x < 0 else 1.0
            for fr, pitch in ((1, 0.35 * side), (13, -0.35 * side), (24, 0.35 * side)):
                bpy.context.scene.frame_set(fr)
                ob.rotation_euler = (pitch, 0, 0)
                ob.keyframe_insert("rotation_euler", frame=fr)

    export_glb(os.path.join(OUT, f"mob_{kind}.glb"), [root_empty] + list(root_empty.children_recursive))
    return height


def main():
    makers = [
        make_core,
        make_wall,
        make_turret,
        make_trap,
        make_beacon,
        make_ship,
        make_tank_prop,
        make_scrap,
        make_crystal,
        make_relic,
        make_rifle,
        make_shotgun,
        make_emblem,
        lambda: make_rock("rock_a", 4, (1.4, 1.1, 0.9)),
        lambda: make_rock("rock_b", 8, (1.8, 1.3, 1.15)),
        lambda: make_rock("rock_c", 15, (1.1, 1.6, 0.7)),
        lambda: make_creature("rusher"),
        lambda: make_creature("ranger"),
        lambda: make_creature("tank"),
    ]
    only = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    for fn in makers:
        name = fn.__name__ if hasattr(fn, "__name__") else "lambda"
        if only and not any(tok in name for tok in only):
            continue
        print("===", name)
        fn()
    print("KIT DONE")


if __name__ == "__main__":
    main()
