"""Builds the gate guards' spear: assets/models/props/hasta.glb.

A legionary's hasta, 2.3 metres from its butt to its point: a long, slender,
leaf-shaped iron head with a raised midrib, its edges hollowed to a fine point,
on a conical socket ringed by two collars and pinned by a rivet; an ash shaft,
a little thicker at its foot, bound in leather where the guard's fist closes on
it (a metre up); and an iron butt-spike, pointed, to stand it in the ground.

Every part is the MedievalPack spear's own shaft (its cylinder, cut from its
head), subdivided and turned to the part's profile, as on a lathe; the head is
the same cylinder flattened through its section into a blade (wide across, a
ridge down its middle, thinning to its edges). Each part is its own mesh, named
for what it is made of ("Head", "Socket", "Rivet", "Butt": iron; "Shaft":
wood; "Grip": leather), unwrapped round and along it (U once round, V in
metres from the butt) for the game's shader (assets/shaders/spear.gdshader).

The model is in metres, its butt's point at the origin, the spear up +Y in
the game, the blade's flat facing +Z.

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_spear.py
"""
from pathlib import Path
import math
import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'source_art/weapons/MedievalPack/OBJ/Spear.obj'
OUT = ROOT/'assets/models/props/hasta.glb'

# Where each part runs (metres up from the butt's point).
BUTT = (0.0, .135)
SHAFT = (.12, 1.985)
GRIP = (.86, 1.14)
SOCKET = (1.965, 2.085)
HEAD = (2.07, 2.3)
# The shaft's radius at its foot and at its top, and the grip's binding over it.
SHAFT_FOOT = .0158
SHAFT_TOP = .0136
BINDING = .0024
# The leather thong's turns: how far apart, and how much each stands proud.
THONG_PITCH = .021
THONG_RIDGE = .0009
# The head: its greatest half-width, where along it that falls, its neck where
# it leaves the socket, and its midrib's half-thickness.
HEAD_WIDTH = .0215
HEAD_WIDEST = .34
HEAD_NECK = .0068
MIDRIB = .0052
EDGE = .00045


def smooth(a, b, x):
    t = min(1.0, max(0.0, (x-a)/(b-a)))
    return t*t*(3-2*t)


def shaft_radius(along):
    u = (along-SHAFT[0])/(SHAFT[1]-SHAFT[0])
    # (Tapering toward its top, a hand's swell low down where it is gripped
    # to be pulled from the ground.)
    return SHAFT_FOOT+(SHAFT_TOP-SHAFT_FOOT)*u**.8+.0006*math.exp(-((u-.08)/.06)**2)


def cylinder():
    """The kit spear's shaft, cut from its head: a unit cylinder, Z from 0 to
    1, a unit about."""
    bpy.ops.wm.obj_import(filepath=str(SOURCE), forward_axis='Y', up_axis='Z')
    obj = [o for o in bpy.context.selected_objects if o.type == 'MESH'][0]
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    # (The kit's spear stands along its Y: the head is everything past the
    # shaft's top ring.)
    # (Turned upright, not mirrored, so its faces still face out.)
    for v in bm.verts: v.co = Vector((v.co.x, -v.co.z, v.co.y))
    top = 2.02
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z > top or abs(f.calc_center_median().y) > .12], context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    lo = min(v.co.z for v in bm.verts)
    hi = max(v.co.z for v in bm.verts)
    r = max(Vector((v.co.x, v.co.y)).length for v in bm.verts)
    for v in bm.verts: v.co = Vector((v.co.x/r, v.co.y/r, (v.co.z-lo)/(hi-lo)))
    bm.to_mesh(obj.data)
    bm.free()
    print('CYLINDER', len(obj.data.vertices), 'verts', len(obj.data.polygons), 'faces')
    return obj


def turned(base, name, start, end, rings, sides, shape):
    """A copy of the cylinder, cut into `rings` rings and rounded to about
    `sides` sides, laid from `start` to `end` metres up, each point set by
    `shape(along, angle)` to (x, y) across it."""
    obj = base.copy()
    obj.data = base.data.copy()
    obj.name = name
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    # Rounder: each edge round it cut, and every point set out to the round.
    around = [e for e in bm.edges if abs(e.verts[0].co.z-e.verts[1].co.z) < 1e-6 and e.verts[0].co.xy.length > .5 and e.verts[1].co.xy.length > .5]
    ring_sides = len([e for e in around if abs(e.verts[0].co.z) < 1e-6])
    cuts = max(0, math.ceil(sides/max(ring_sides, 1))-1)
    if cuts: bmesh.ops.subdivide_edges(bm, edges=around, cuts=cuts, use_grid_fill=True)
    for v in bm.verts:
        if v.co.xy.length > .5: v.co.xy = v.co.xy.normalized()
    # Rings all along it, evenly.
    for i in range(1, rings):
        cut = bmesh.ops.bisect_plane(bm, geom=bm.verts[:]+bm.edges[:]+bm.faces[:], plane_co=(0, 0, i/rings), plane_no=(0, 0, 1))
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    # (The kit's own unwrap goes: this one, round and along, is the only one.)
    for layer in list(bm.loops.layers.uv.values()): bm.loops.layers.uv.remove(layer)
    uv = bm.loops.layers.uv.new('UVMap')
    for v in bm.verts:
        flat = Vector((v.co.x, v.co.y))
        angle = math.atan2(flat.y, flat.x) if flat.length > 1e-6 else 0.0
        along = start+(end-start)*v.co.z
        x, y = shape(along, angle) if flat.length > 1e-6 else (0.0, 0.0)
        v.co = Vector((x, y, along))
    for f in bm.faces:
        centre = math.atan2(sum(l.vert.co.y for l in f.loops), sum(l.vert.co.x for l in f.loops))
        for l in f.loops:
            angle = math.atan2(l.vert.co.y, l.vert.co.x) if l.vert.co.xy.length > 1e-7 else centre
            # (Kept on the same side of the seam as the face it is in.)
            if abs(angle-centre) > math.pi: angle += math.tau if angle < centre else -math.tau
            l[uv].uv = (angle/math.tau+.5, l.vert.co.z)
    bm.to_mesh(obj.data)
    bm.free()
    for p in obj.data.polygons: p.use_smooth = True
    obj.data.materials.clear()
    obj.data.materials.append(bpy.data.materials.new(name))
    return obj


def round_shape(radius):
    return lambda along, angle: (math.cos(angle)*radius(along), math.sin(angle)*radius(along))


def butt(along):
    # A long point rising to a collar where the shaft sits in it.
    u = along/BUTT[1]
    point = .0145*(min(1.0, u/.74))**.75
    collar = .0022*math.exp(-((u-.86)/.06)**2)
    lip = -.0012*smooth(.96, 1.0, u)
    return max(.0004, point+collar+lip)


def grip(along, angle):
    u = (along-GRIP[0])/(GRIP[1]-GRIP[0])
    # The thong wound round in a spiral, each turn standing proud, its two
    # ends bound off a little thicker.
    turn = (along/THONG_PITCH+angle/math.tau) % 1.0
    ridge = THONG_RIDGE*math.sin(math.pi*turn)**.6
    ends = .0008*(math.exp(-((u-.02)/.025)**2)+math.exp(-((u-.98)/.025)**2))
    rise = smooth(0.0, .015, u)*smooth(1.0, .985, u)
    r = shaft_radius(along)+(BINDING+ridge+ends)*rise
    return (math.cos(angle)*r, math.sin(angle)*r)


def socket(along):
    u = (along-SOCKET[0])/(SOCKET[1]-SOCKET[0])
    # Conical, closing up toward the head, with a collar near each end.
    cone = .0176+(.0098-.0176)*u**1.15
    collars = .0019*math.exp(-((u-.12)/.05)**2)+.0015*math.exp(-((u-.72)/.045)**2)
    return cone+collars


def head(along, angle):
    u = (along-HEAD[0])/(HEAD[1]-HEAD[0])
    # The leaf: out from the neck to its widest a third of the way up, then
    # in, the last of it drawn out long and hollowed to a fine point.
    if u < HEAD_WIDEST:
        t = u/HEAD_WIDEST
        width = HEAD_NECK+(HEAD_WIDTH-HEAD_NECK)*math.sin(t*math.pi*.5)**1.4
    else:
        t = (u-HEAD_WIDEST)/(1-HEAD_WIDEST)
        width = HEAD_WIDTH*(1-t)**1.35*(1-.18*math.sin(t*math.pi))
    width = max(width, .0002)
    rib = MIDRIB*(1-u)**.55+.0008*(1-u)
    # Across the section: the ridge down the middle, the faces falling away
    # from it a little hollowed, to a thin edge.
    across = math.cos(angle)
    side = 1.0 if math.sin(angle) >= 0 else -1.0
    out = abs(across)
    thick = max(EDGE*(1-u)+.0001, rib*(1-out)**1.35)
    return (across*width, side*thick*math.sqrt(max(0.0, 1-out**8)))


def rivet(base):
    """The pin through the socket, its domed heads standing either side."""
    r = socket(SOCKET[0]+.045*(SOCKET[1]-SOCKET[0])/.12)
    def shape(along, angle):
        u = along/(2*r+.006)
        dome = .0026*math.sqrt(max(0.0, 1-((abs(u-.5)*2-.62)/.38)**2)) if abs(u-.5)*2 > .62 else .0016
        return (math.cos(angle)*dome, math.sin(angle)*dome)
    pin = turned(base, 'Rivet', 0.0, 2*r+.006, 10, 12, shape)
    # (Turned through the socket, across the blade's flat.)
    for v in pin.data.vertices:
        x, y, z = v.co
        v.co = Vector((x, -(z-(r+.003)), y+SOCKET[0]+.045))
    return pin


bpy.ops.wm.read_factory_settings(use_empty=True)
base = cylinder()
parts = [
    turned(base, 'Butt', BUTT[0], BUTT[1], 40, 32, round_shape(butt)),
    turned(base, 'Shaft', SHAFT[0], SHAFT[1], 36, 24, round_shape(shaft_radius)),
    turned(base, 'Grip', GRIP[0], GRIP[1], 120, 40, grip),
    turned(base, 'Socket', SOCKET[0], SOCKET[1], 60, 40, round_shape(socket)),
    turned(base, 'Head', HEAD[0], HEAD[1], 110, 48, head),
]
parts.append(rivet(base))
bpy.data.objects.remove(base, do_unlink=True)
for obj in bpy.data.objects: obj.select_set(obj in parts)
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB', export_animations=False, export_yup=True, export_image_format='NONE', use_selection=True)
print('HASTA_READY', {o.name: len(o.data.vertices) for o in parts})
