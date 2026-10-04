"""Builds the street sleepers' bedding: assets/models/props/bedroll.glb.

A sheet of sacking spread on the ground, a blanket thrown half over it, and a
stuffed sack for a pillow at its head, each from the props kit's own models
(its banner cloth, without its rings, and its bag), let fall and settle by
Blender's cloth simulation: the sacking spread a little too large for the
ground it lies on, so it buckles into creases and folds; the blanket dropped
on top of it askew, crumpling where it meets the pillow and the sacking's
ridges. The ground and the falling are the simulation's alone; what is kept
is the cloth as it lies.

The model is in metres, centred on the sacking with its foot on the ground,
its head (the pillow) toward -Z in the game. Each piece is its own mesh
("Sacking", "Blanket", "Pillow"), unwrapped at a metre to a unit for the
game's photographed cloth (scripts/townsfolk.gd pallet()).

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_bedroll.py
"""
from pathlib import Path
import math
import random
import bmesh
import bpy
from mathutils import Vector, Matrix, noise

ROOT = Path(__file__).resolve().parents[1]
PROPS = ROOT/'source_art/props/Exports/glTF'
OUT = ROOT/'assets/models/props/bedroll.glb'
random.seed(4)


def imported(name):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(PROPS/(name+'.gltf')))
    meshes = [o for o in set(bpy.data.objects)-before if o.type == 'MESH']
    for o in set(bpy.data.objects)-before:
        if o.type != 'MESH': bpy.data.objects.remove(o, do_unlink=True)
    obj = meshes[0]
    obj.parent = None
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.select_set(False)
    return obj


def keep(obj, material):
    """Only the faces of the material named `material`."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    wanted = [i for i, m in enumerate(obj.data.materials) if m.name.startswith(material)]
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index not in wanted], context='FACES')
    bm.to_mesh(obj.data)
    bm.free()


def fit(obj, size, centre):
    """Scaled to `size` (x, y, z) and its middle moved to `centre`."""
    pts = [v.co for v in obj.data.vertices]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    span = hi-lo
    for v in obj.data.vertices:
        p = v.co-(lo+hi)*.5
        v.co = Vector((p.x/max(span.x, 1e-6)*size[0], p.y/max(span.y, 1e-6)*size[1], p.z/max(span.z, 1e-6)*size[2]))+Vector(centre)


def flat_cloth(width, length):
    """The banner cloth without its rings, laid flat (its face up), as fine as
    the simulation needs."""
    obj = imported('Banner_1_Cloth')
    keep(obj, 'MI_Banner')
    # The banner hangs in X (across) and Z (down): lay it along Y.
    obj.data.transform(Matrix.Rotation(-math.pi/2, 4, 'X'))
    fit(obj, (width, length, .0), (0, 0, 0))
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=.004)
    bpy.ops.object.mode_set(mode='OBJECT')
    # Only the face that looks up: one layer of cloth.
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal.z < .5], context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(obj.data)
    bm.free()
    print('CLOTH', obj.name, len(obj.data.polygons), 'faces before subdivision')
    obj.modifiers.new('fine', 'SUBSURF').levels = 4
    obj.modifiers['fine'].subdivision_type = 'SIMPLE'
    bpy.ops.object.modifier_apply(modifier='fine')
    return obj


def settle(obj, frames, colliders, shrink=0.0, mass=.3):
    obj.select_set(False)
    cloth = obj.modifiers.new('cloth', 'CLOTH')
    s = cloth.settings
    s.quality = 8
    s.mass = mass
    s.tension_stiffness = 8
    s.compression_stiffness = 8
    s.shear_stiffness = 4
    s.bending_stiffness = .4
    s.shrink_min = shrink
    s.air_damping = 2.0
    cloth.collision_settings.use_self_collision = True
    cloth.collision_settings.self_distance_min = .004
    cloth.collision_settings.distance_min = .006
    cloth.point_cache.frame_start = 1
    cloth.point_cache.frame_end = frames
    for c in colliders:
        if not any(m.type == 'COLLISION' for m in c.modifiers):
            c.modifiers.new('collision', 'COLLISION')
            c.collision.thickness_outer = .004
            c.collision.cloth_friction = 8.0
    scene = bpy.context.scene
    for f in range(1, frames+1): scene.frame_set(f)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier='cloth')
    scene.frame_set(1)


def unwrap(obj):
    """UVs at a metre to a unit, for the game's cloth."""
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.2, island_margin=.02)
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.select_set(False)
    uv = obj.data.uv_layers.active.data
    flat = 0.0
    for p in obj.data.polygons:
        loops = list(p.loop_indices)
        for k in range(1, len(loops)-1):
            a, b, c = uv[loops[0]].uv, uv[loops[k]].uv, uv[loops[k+1]].uv
            flat += abs((b[0]-a[0])*(c[1]-a[1])-(c[0]-a[0])*(b[1]-a[1]))*.5
    real = sum(p.area for p in obj.data.polygons)
    k = (real/max(flat, 1e-9))**.5
    for l in uv: l.uv = (l.uv[0]*k, l.uv[1]*k)


def jostle(obj, height, scale, seed):
    """Lifted off the ground and rumpled, as cloth is thrown down."""
    for v in obj.data.vertices:
        p = v.co
        v.co.z = height+noise.noise(Vector((p.x*scale, p.y*scale, seed)))*.05


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
# The ground the bedding falls on (the simulation's only).
bpy.ops.mesh.primitive_plane_add(size=6)
ground = bpy.context.active_object
ground.select_set(False)

# The pillow: the kit's sack, stuffed flat, at the head (+Y here: -Z in the game).
pillow = imported('Bag')
fit(pillow, (.5, .32, .17), (0, .78, .085))
pillow.data.transform(Matrix.Rotation(.18, 4, 'Z'))
pillow.name = 'Pillow'

# The sacking, a little too large: it buckles into creases as it settles.
sacking = flat_cloth(.95, 2.0)
sacking.name = 'Sacking'
jostle(sacking, .03, 3.0, 1.0)
settle(sacking, 40, [ground, pillow], shrink=-.06, mass=.4)

# The blanket, thrown over the lower half, askew.
blanket = flat_cloth(1.0, 1.25)
blanket.name = 'Blanket'
blanket.data.transform(Matrix.Rotation(.32, 4, 'Z'))
blanket.data.transform(Matrix.Translation((.08, -.32, 0)))
jostle(blanket, .22, 2.4, 7.0)
settle(blanket, 70, [ground, pillow, sacking], shrink=-.03)

bpy.data.objects.remove(ground, do_unlink=True)
for obj in (sacking, blanket, pillow):
    for m in obj.modifiers: obj.modifiers.remove(m)
    # (Fine enough to fold, and no finer than its creases need: a dozen
    # lie about the town at night.)
    if obj != pillow:
        bpy.context.view_layer.objects.active = obj
        cut = obj.modifiers.new('cut', 'DECIMATE')
        cut.ratio = .3
        bpy.ops.object.modifier_apply(modifier='cut')
    unwrap(obj)
    obj.data.materials.clear()
    m = bpy.data.materials.new(obj.name)
    obj.data.materials.append(m)
    for p in obj.data.polygons: p.use_smooth = True
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB', export_animations=False, export_yup=True, export_image_format='NONE', use_selection=True)
print('BEDROLL_READY', {o.name: len(o.data.vertices) for o in (sacking, blanket, pillow)})
