"""Builds the legionary's tower shield, a curved scutum: assets/models/props/scutum.glb.

It stands in for the KayKit square shield (a few hundred faces) that the
town guards, the gladiator and centurion statues and the warrior's tower
shields carried. After a Roman scutum: a board of laminated wood bent on a
cylinder about the bearer (radius .5 m), its corners rounded, its edge bound
in a rolled rim; two straight bars across it a fifth of a metre above and
below the middle; a rib (spina) down its length, swelling round the boss;
and a domed iron boss (umbo) on a round flange, over a hand grip behind it.
Its relief stands where guard_shield.gdshader paints the rim (the board's
outer 25 mm), the bars and the boss (85 mm about the middle), so paint and
shape agree.

Written as the game's other arms are: in a unit box, X across (-.5 to .5),
Y up from its foot (0 to 1), Z out through its face (the boss toward +Z);
the game sizes it (look `size`, town_guard.gd SHIELD_SIZE). In metres it is
.6 wide, 1.0 tall and about .19 deep, so sized to .2 deep it keeps its
curve.

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_scutum.py
"""
from pathlib import Path
import math
import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/models/props/scutum.glb'
WIDTH, HEIGHT = .6, 1.0
RADIUS = .5          # the curve of the board about the bearer
BOARD = .02          # the board's thickness
CORNER = .045        # the rounding of its corners
RIM = .025           # the rolled rim's width, as the paint has it
BOSS = .085          # the boss's radius, as the paint has it
BOSS_RISE = .068
FLANGE = .112
BAR_Y, BAR_HALF, BAR_REACH = .2, .018, .36*WIDTH
COLUMNS, ROWS = 44, 72


def smooth(a, b, x):
    t = min(max((x-a)/(b-a), 0.0), 1.0)
    return t*t*(3-2*t)


def outline(u, v):
    """A point of the board's flat outline, in metres from its middle, for a
    grid place (u, v) in 0..1; the corner squares are drawn round."""
    x = (u-.5)*WIDTH
    y = (v-.5)*HEIGHT
    cx = WIDTH/2-CORNER
    cy = HEIGHT/2-CORNER
    if abs(x) > cx and abs(y) > cy:
        a = abs(x)-cx
        b = abs(y)-cy
        m = max(a, b)
        d = math.hypot(a, b)
        if d > 1e-9:
            a, b = a*m/d, b*m/d
        x = math.copysign(cx+a, x)
        y = math.copysign(cy+b, y)
    return x, y


def edge_distance(x, y):
    """How far inside the outline a point lies."""
    cx = WIDTH/2-CORNER
    cy = HEIGHT/2-CORNER
    if abs(x) > cx and abs(y) > cy:
        return CORNER-math.hypot(abs(x)-cx, abs(y)-cy)
    return min(WIDTH/2-abs(x), HEIGHT/2-abs(y))


def relief(x, y):
    """How far the face stands out from the bare board here."""
    rise = 0.0
    edge = edge_distance(x, y)
    # The rolled rim: a rounded bead over the outer RIM.
    if edge < RIM:
        t = edge/RIM
        rise = max(rise, .006*math.sin(math.pi*min(t*1.15, 1.0)))
    # The bars.
    for sign in (1, -1):
        d = abs(y-sign*BAR_Y)
        if d < BAR_HALF+.004 and abs(x) < BAR_REACH:
            rise = max(rise, .0035*smooth(BAR_HALF+.004, BAR_HALF-.002, d)*smooth(BAR_REACH, BAR_REACH-.01, abs(x)))
    # The spina: a rib down the middle, from the rim to the rim.
    rib = smooth(.026, .008, abs(x))*smooth(0.0, .04, edge)
    rise = max(rise, .007*rib)
    # The boss's flange and dome.
    r = math.hypot(x, y)
    if r < FLANGE:
        rise = max(rise, .004*smooth(FLANGE, FLANGE-.008, r))
    if r < BOSS:
        rise = max(rise, .004+BOSS_RISE*math.sqrt(max(0.0, 1-(r/BOSS)**2))**1.3)
    return rise


def bent(x, y, out):
    """A point on the board bent round the bearer: `out` metres out from
    its back surface along the curve's radius."""
    angle = x/RADIUS
    r = RADIUS+out
    return Vector((r*math.sin(angle), y, r*math.cos(angle)-RADIUS))


bpy.ops.wm.read_factory_settings(use_empty=True)
bm = bmesh.new()
uv_layer = bm.loops.layers.uv.new()
front = {}
back = {}
for i in range(COLUMNS+1):
    for j in range(ROWS+1):
        x, y = outline(i/COLUMNS, j/ROWS)
        front[i, j] = bm.verts.new(bent(x, y, BOARD+relief(x, y)))
        back[i, j] = bm.verts.new(bent(x, y, 0.0))


def face(vs, uvs):
    f = bm.faces.new(vs)
    for loop, uv in zip(f.loops, uvs): loop[uv_layer].uv = uv
    return f


for i in range(COLUMNS):
    for j in range(ROWS):
        uvs = [(i/COLUMNS, j/ROWS), ((i+1)/COLUMNS, j/ROWS), ((i+1)/COLUMNS, (j+1)/ROWS), (i/COLUMNS, (j+1)/ROWS)]
        face([front[i, j], front[i+1, j], front[i+1, j+1], front[i, j+1]], uvs)
        face([back[i, j+1], back[i+1, j+1], back[i+1, j], back[i, j]], uvs[::-1])
# The board's edge, round its outline.
ring = [(i, 0) for i in range(COLUMNS)]+[(COLUMNS, j) for j in range(ROWS)]+[(i, ROWS) for i in range(COLUMNS, 0, -1)]+[(0, j) for j in range(ROWS, 0, -1)]
for k in range(len(ring)):
    a = ring[k]
    b = ring[(k+1) % len(ring)]
    face([front[a], back[a], back[b], front[b]], [(0, 0), (0, 1), (1, 1), (1, 0)])
# The hand grip behind the boss: a bar across the hollow of the board.
grip = bmesh.ops.create_cube(bm, size=1.0)
for v in grip['verts']:
    v.co = Vector((v.co.x*.15, v.co.y*.035, v.co.z*.03))+Vector((0, 0, -.03))
for f in bm.faces: f.smooth = True
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
mesh = bpy.data.meshes.new('Scutum')
bm.to_mesh(mesh)
bm.free()
obj = bpy.data.objects.new('Scutum', mesh)
bpy.context.scene.collection.objects.link(obj)
# Smooth across the board, crisp at its edge.
mesh.shade_smooth()
with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj]):
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(50))

# --- Into the unit box (Blender's Y is up here: glTF turns Z-up to Y-up, so
# the board is built with Y up and Z out and turned to suit).
vs = mesh.vertices
lo = Vector((min(v.co.x for v in vs), min(v.co.y for v in vs), min(v.co.z for v in vs)))
hi = Vector((max(v.co.x for v in vs), max(v.co.y for v in vs), max(v.co.z for v in vs)))
depth = hi.z-lo.z
for v in vs:
    p = v.co
    # Unit box in the game's axes (X across, Y up, Z out), written in
    # Blender's (X, -Z, Y) so the exporter's turn brings it back.
    ux = (p.x-(lo.x+hi.x)/2)/(hi.x-lo.x)
    uy = (p.y-lo.y)/(hi.y-lo.y)
    uz = (p.z-(lo.z+hi.z)/2)/depth
    v.co = Vector((ux, -uz, uy))
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB', export_animations=False, use_selection=True)
print('SCUTUM_READY faces=%d size=(%.3f, %.3f, %.3f)' % (len(mesh.polygons), hi.x-lo.x, hi.y-lo.y, depth))
