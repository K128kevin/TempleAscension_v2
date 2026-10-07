"""Builds the hero wizard's staffs: assets/models/props/silver_staff.glb and
assets/models/props/ashwood_staff.glb.

The twisted silver staff (the wizard's own, and the Oracle's Staff in gold),
1.8 metres: three silver strands wound round a slender core rod from a pointed
ferrule up to its head, where they open into a twisted cage of prongs about a
long six-sided crystal standing in a silver cup, three small shards of crystal
round its foot; a leather grip, wound with a raised thong, where the fist
closes on it (GRIP_HEIGHT up, as the game holds it: scripts/visual.gd), beaded
collars above and below the grip, at the middle of the staff and under the
cage.

The ashwood staff, 1.75 metres: a gnarled shaft of pale ash, bent a little
and swelling at three knots, rough and uneven in section, splitting at its
head into three twisting branches that curl in over a rough stone they hold;
bronze bands under the split and a bronze ferrule at its foot, and a cord
wrapped round the grip.

Every part is turned on a lathe or swept along a path, with its own vertices:
round (sides) and along (rings). Each is one mesh named for what it is made of
("Metal", "Crystal", "Leather", "Wood", "Bronze") for the game's shader
(assets/shaders/staff.gdshader), unwrapped round and along it (U once round,
V in metres along it) as the hasta is (tools/make_spear.py).

The models are in metres, the foot's point at the origin, the staff up +Y in
the game.

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_staffs.py
"""
from pathlib import Path
import math
import random
import bmesh
import bpy
from mathutils import Vector, Matrix, noise

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/models/props'
# Where the fist closes on a staff, up from its foot (the game holds it so,
# its foot then on the ground: scripts/visual.gd WIZARD_GRIP_HEIGHT).
GRIP_HEIGHT = 1.254

def smooth(a, b, x):
    t = max(0.0, min(1.0, (x-a)/(b-a)))
    return t*t*(3-2*t)

# ---- Building pieces ----

class Piece:
    """Vertices and faces gathered for one part (one material), with their
    UVs, to be made one mesh."""
    def __init__(self, name):
        self.name = name
        self.verts = []
        self.faces = []
        self.uvs = []
        self.flat = []

    def add_grid(self, rings, cap_start=None, cap_end=None, flat=False):
        """`rings`: lists of (point, (u, v)), each ring the same count,
        joined ring to ring round and round; a cap closes an end at a point."""
        sides = len(rings[0])
        base = len(self.verts)
        for ring in rings:
            for p, uv in ring:
                self.verts.append(p)
                self.uvs.append(uv)
        for r in range(len(rings)-1):
            for i in range(sides):
                a = base+r*sides+i
                b = base+r*sides+(i+1) % sides
                c = base+(r+1)*sides+(i+1) % sides
                d = base+(r+1)*sides+i
                self.faces.append(((a, b, c, d), ((i/sides, rings[r][i][1][1]), ((i+1)/sides, rings[r][(i+1) % sides][1][1]),
                    ((i+1)/sides, rings[r+1][(i+1) % sides][1][1]), (i/sides, rings[r+1][i][1][1]))))
                self.flat.append(flat)
        for cap, ring_index, flip in ((cap_start, 0, True), (cap_end, len(rings)-1, False)):
            if cap is None: continue
            centre = len(self.verts)
            self.verts.append(cap)
            self.uvs.append((.5, rings[ring_index][0][1][1]))
            row = base+ring_index*sides
            for i in range(sides):
                a, b = row+i, row+(i+1) % sides
                quad = (a, centre, b) if flip else (b, centre, a)
                self.faces.append((quad, tuple((.5, self.uvs[k][1]) for k in quad)))
                self.flat.append(flat)

    def build(self):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata([tuple(v) for v in self.verts], [], [f for f, _ in self.faces])
        uv = mesh.uv_layers.new(name='UVMap')
        for poly, (_, uvs), flat in zip(mesh.polygons, self.faces, self.flat):
            for loop, value in zip(poly.loop_indices, uvs):
                uv.data[loop].uv = value
            poly.use_smooth = not flat
        mesh.validate()
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.data.materials.append(bpy.data.materials.get(self.name) or bpy.data.materials.new(self.name))
        return obj

def lathe(piece, profile, sides, turn=0.0, shape=None, flat=False, cap_start=False, cap_end=False):
    """A part turned about the staff's axis: `profile` (height, radius)
    points from its foot up; `shape(height, angle, radius)` may vary the
    radius round it (a wrapped thong's ridges, a knot)."""
    rings = []
    v = 0.0
    for k, (z, r) in enumerate(profile):
        if k: v += math.hypot(z-profile[k-1][0], r-profile[k-1][1])
        ring = []
        for i in range(sides):
            a = turn+2*math.pi*i/sides
            radius = shape(z, a, r) if shape else r
            ring.append((Vector((radius*math.cos(a), radius*math.sin(a), z)), (i/sides, v)))
        rings.append(ring)
    piece.add_grid(rings, Vector((0, 0, profile[0][0])) if cap_start else None, Vector((0, 0, profile[-1][0])) if cap_end else None, flat)

def sweep(piece, path, radii, sides, shape=None, caps=True, flat=False):
    """A part swept along `path` (points), its radius `radii` at each, framed
    so it never twists about itself (each ring's frame carried on from the
    last's); `shape(k, angle, radius)` may vary it round."""
    rings = []
    normal = None
    v = 0.0
    for k, p in enumerate(path):
        ahead = (path[min(k+1, len(path)-1)]-path[max(k-1, 0)]).normalized()
        if normal is None:
            normal = ahead.cross(Vector((0, 0, 1)) if abs(ahead.z) < .9 else Vector((1, 0, 0))).normalized()
        normal = (normal-ahead*normal.dot(ahead)).normalized()
        side = ahead.cross(normal)
        if k: v += (p-path[k-1]).length
        ring = []
        for i in range(sides):
            a = 2*math.pi*i/sides
            r = shape(k, a, radii[k]) if shape else radii[k]
            ring.append((p+(normal*math.cos(a)+side*math.sin(a))*r, (i/sides, v)))
        rings.append(ring)
    piece.add_grid(rings, path[0] if caps else None, path[-1] if caps else None, flat)

def crystal(piece, base, axis, length, width, sides=6, seed=0):
    """A long crystal: a six-sided prism with pointed ends, its facets a
    little uneven (flat shaded, so each catches the light alone)."""
    rnd = random.Random(seed)
    axis = axis.normalized()
    across = axis.cross(Vector((0, 0, 1)) if abs(axis.z) < .9 else Vector((1, 0, 0))).normalized()
    other = axis.cross(across)
    profile = [(0.0, 0.0), (.16, .85), (.3, 1.0), (.72, .97), (1.0, 0.0)]
    rings = []
    jitter = [1+rnd.uniform(-.12, .12) for _ in range(sides)]
    for z, r in profile:
        ring = []
        for i in range(sides):
            a = 2*math.pi*i/sides
            rr = width*r*jitter[i]
            ring.append((base+axis*(z*length)+(across*math.cos(a)+other*math.sin(a))*rr, (i/sides, z*length)))
        rings.append(ring)
    # (Its points not quite on the axis, as a grown crystal's are not.)
    tip = base+axis*length+across*width*rnd.uniform(-.15, .15)
    piece.add_grid(rings[1:-1], base+axis*(profile[0][0]*length), tip, flat=True)

def collar(piece, z, radius, height, beads=0):
    """A ring round the staff, rounded at its edges; `beads`: a row of beads
    round its middle."""
    profile = [(z, radius*.82), (z+height*.12, radius), (z+height*.88, radius), (z+height, radius*.82)]
    lathe(piece, profile, 20)
    if beads:
        for i in range(beads):
            a = 2*math.pi*i/beads
            centre = Vector((math.cos(a)*radius, math.sin(a)*radius, z+height/2))
            bead = height*.32
            lathe_at(piece, centre, bead)

def lathe_at(piece, centre, radius, sides=8):
    """A small sphere (a bead, a rivet)."""
    profile = [(-radius*math.cos(math.pi*k/6), radius*math.sin(math.pi*k/6)) for k in range(7)]
    rings = []
    for z, r in profile[1:-1]:
        ring = []
        for i in range(sides):
            a = 2*math.pi*i/sides
            ring.append((centre+Vector((r*math.cos(a), r*math.sin(a), z)), (i/sides, z)))
        rings.append(ring)
    piece.add_grid(rings, centre+Vector((0, 0, -radius)), centre+Vector((0, 0, radius)))

def thong(pitch, ridge, depth=1.0):
    """A wrapped binding's turns: the radius raised along a spiral."""
    def shape(z, a, r):
        turn = (z/pitch-a/(2*math.pi)) % 1.0
        return r+ridge*(math.sin(math.pi*turn)**4)*depth-ridge*.3
    return shape

def export(name, pieces):
    bpy.ops.object.select_all(action='DESELECT')
    objects = [p.build() for p in pieces if p.verts]
    for o in objects: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')), export_format='GLB', export_animations=False, export_yup=True, export_image_format='NONE', use_selection=True)
    top = max(v.co.z for o in objects for v in o.data.vertices)
    wide = max(max(abs(v.co.x), abs(v.co.y)) for o in objects for v in o.data.vertices)
    print('STAFF_READY', name, 'length %.3f' % top, 'half width %.3f' % wide, {o.name: len(o.data.vertices) for o in objects})
    for o in objects: bpy.data.objects.remove(o, do_unlink=True)

# ---- The twisted silver staff ----

SILVER_LENGTH = 1.8
# The core rod and the three strands wound round it: how far out they wind,
# how thick each is, and how far up the staff one turn takes.
CORE = .0086
STRAND_OUT = .0114
STRAND = .0058
PITCH = .17
# The grip, wrapped in leather.
GRIP = (GRIP_HEIGHT-.11, GRIP_HEIGHT+.11)
# The head: where the strands begin to open, the cup the crystal stands in,
# and the crystal.
CAGE_FROM = 1.44
CUP = (1.44, 1.535)
CRYSTAL = (1.5, 1.8)

def silver_staff():
    metal, gem, leather = Piece('Metal'), Piece('Crystal'), Piece('Leather')
    # The ferrule: a pointed silver cap, and its collar.
    lathe(metal, [(0.0, .0015), (.008, .0052), (.03, .0095), (.052, .0122), (.058, .0148), (.068, .015), (.074, .0118)], 18, cap_start=True)
    # The core rod.
    lathe(metal, [(.07, CORE), (CAGE_FROM+.04, CORE*.92)], 12)
    # The strands, wound round it, opening into the cage's prongs.
    for k in range(3):
        path, radii = [], []
        steps = 420
        for i in range(steps+1):
            z = .066+(CRYSTAL[1]-.004-.066)*i/steps
            if z < CAGE_FROM:
                out = STRAND_OUT
                turns = z/PITCH
            else:
                u = (z-CAGE_FROM)/(CRYSTAL[1]-.004-CAGE_FROM)
                # Out round the crystal's widest, then in over its point.
                out = STRAND_OUT+.046*math.sin(math.pi*min(1.0, u*1.25))**1.2*(1-.75*smooth(.7, 1.0, u))
                turns = CAGE_FROM/PITCH+(z-CAGE_FROM)/(PITCH*2.6)
            a = 2*math.pi*(turns+k/3)
            path.append(Vector((out*math.cos(a), out*math.sin(a), z)))
            radii.append(STRAND*(1-.55*smooth(CAGE_FROM+.12, CRYSTAL[1], z)))
        sweep(metal, path, radii, 8)
    # The grip: leather wound round the strands, a raised thong spiralling up
    # it.
    g0, g1 = GRIP
    profile = [(g0+(g1-g0)*i/60, .0158+.0012*math.sin(math.pi*i/60)) for i in range(61)]
    lathe(leather, profile, 24, shape=thong(.019, .0016))
    # Collars: beaded above and below the grip, plain at the middle of the
    # staff, and under the cage.
    collar(metal, g0-.018, .0175, .018, beads=10)
    collar(metal, g1, .0175, .018, beads=10)
    collar(metal, .64, .0148, .014)
    collar(metal, CAGE_FROM-.03, .0158, .016)
    # The cup the crystal stands in.
    lathe(metal, [(CUP[0], .0122), (CUP[0]+.02, .0148), (CUP[0]+.05, .022), (CUP[0]+.075, .0295), (CUP[1], .0318), (CUP[1]+.004, .0288), (CUP[1]-.006, .026)], 20)
    # The crystal, and three small shards round its foot, leaning out
    # between the prongs.
    crystal(gem, Vector((0, 0, CRYSTAL[0])), Vector((0, 0, 1)), CRYSTAL[1]-CRYSTAL[0], .037, seed=3)
    for k in range(3):
        a = 2*math.pi*(k/3+CAGE_FROM/PITCH+1/6)+.4
        out = Vector((math.cos(a), math.sin(a), 0))
        crystal(gem, Vector((0, 0, CUP[1]-.012))+out*.016, (out*.55+Vector((0, 0, 1))), .068, .011, seed=10+k)
    export('silver_staff', [metal, gem, leather])

# ---- The ashwood staff ----

ASH_LENGTH = 1.75
SPLIT = 1.5
KNOTS = [(.36, .9), (.83, 2.6), (1.27, 4.4)]

def ash_bend(z):
    """The shaft's gentle bow and wander (metres off the axis at height z)."""
    return Vector((.012*math.sin(z*1.9+.4)+.004*math.sin(z*6.1), .009*math.sin(z*1.4+2.0)+.003*math.sin(z*7.3+1), 0))

def ash_radius(z, a):
    r = .0185-.0035*smooth(0, .9, z)+.006*smooth(1.05, SPLIT, z)
    # Uneven in section, as a cut branch is; ridged along the grain.
    r *= 1+.07*math.sin(3*a+z*5.0)+.035*math.sin(5*a+z*11.0+1.0)+.012*math.sin(17*a+z*3)
    for height, facing in KNOTS:
        near = math.exp(-((z-height)/.022)**2)
        r += .0105*near*max(0.0, math.cos(a-facing))**2+.0035*near
    return r

def ashwood_staff():
    wood, bronze, gem, cord = Piece('Wood'), Piece('Bronze'), Piece('Crystal'), Piece('Leather')
    # The shaft, from just above the ferrule to where it splits.
    rings = []
    zs = [.03+(SPLIT+.03-.03)*i/170 for i in range(171)]
    v = 0.0
    for k, z in enumerate(zs):
        if k: v += zs[k]-zs[k-1]
        centre = ash_bend(z)+Vector((0, 0, z))
        ring = []
        for i in range(16):
            a = 2*math.pi*i/16
            r = ash_radius(z, a)
            ring.append((centre+Vector((math.cos(a)*r, math.sin(a)*r, 0)), (i/16, v)))
        rings.append(ring)
    wood.add_grid(rings, Vector((0, 0, .03))+ash_bend(.03), None)
    # The ferrule: bronze, blunt, to stand the staff on.
    foot = ash_bend(.0)
    rings = []
    for z, r in [(0.0, .006), (.004, .0175), (.012, .0205), (.04, .0205), (.048, .0225), (.056, .0222), (.062, .0196)]:
        rings.append([(foot+Vector((math.cos(2*math.pi*i/18)*r, math.sin(2*math.pi*i/18)*r, z)), (i/18, z)) for i in range(18)])
    bronze.add_grid(rings, foot, None)
    # The branches: three, from the split, twisting up round the stone and
    # curling in over it.
    top = ash_bend(SPLIT)
    stone_at = top+Vector((0, 0, 1.635))-Vector((0, 0, 0))
    for k in range(3):
        path, radii = [], []
        steps = 90
        for i in range(steps+1):
            u = i/steps
            z = SPLIT+(ASH_LENGTH-.008-SPLIT)*u
            out = .007+.044*math.sin(math.pi*min(1.0, u*1.18))**.9*(1-.8*smooth(.72, 1.0, u))
            a = 2*math.pi*(k/3)+u*2.4
            path.append(top+Vector((out*math.cos(a), out*math.sin(a), z)))
            radii.append(.0135*(1-.65*u)+.003)
        sweep(wood, path, radii, 10, shape=lambda kk, a, r, k=k: r*(1+.08*math.sin(3*a+kk*.3+k)))
    # The stone they hold: rough, a little egg-shaped.
    rnd = random.Random(7)
    rings = []
    for j in range(1, 12):
        t = j/12
        z = stone_at.z-.044+.088*t
        for_r = .034*math.sin(math.pi*t)**.8
        ring = []
        for i in range(14):
            a = 2*math.pi*i/14
            bump = 1+.09*noise.noise(Vector((math.cos(a)*2, math.sin(a)*2, t*3)))
            ring.append((Vector((stone_at.x+math.cos(a)*for_r*bump, stone_at.y+math.sin(a)*for_r*bump, z)), (i/14, t*.07)))
        rings.append(ring)
    gem.add_grid(rings, Vector((stone_at.x, stone_at.y, stone_at.z-.044)), Vector((stone_at.x, stone_at.y, stone_at.z+.044)))
    # Bronze bands under the split, and a cord wound round the grip.
    for z, h in [(SPLIT-.07, .022), (SPLIT-.025, .016)]:
        c = ash_bend(z+h/2)
        profile = [(z, 0.0), (z+h*.15, 1.0), (z+h*.85, 1.0), (z+h, 0.0)]
        rings = []
        for zz, edge in profile:
            r = max(ash_radius(zz, a) for a in [2*math.pi*i/16 for i in range(16)])+.0016+.0012*edge
            rings.append([(c+Vector((math.cos(2*math.pi*i/20)*r, math.sin(2*math.pi*i/20)*r, zz)), (i/20, zz)) for i in range(20)])
        bronze.add_grid(rings)
    g0, g1 = GRIP_HEIGHT-.1, GRIP_HEIGHT+.1
    rings = []
    shape = thong(.0105, .0019)
    for j in range(81):
        z = g0+(g1-g0)*j/80
        c = ash_bend(z)
        base = max(ash_radius(z, 2*math.pi*i/16) for i in range(16))+.0018
        rings.append([(c+Vector((math.cos(2*math.pi*i/24)*shape(z, 2*math.pi*i/24, base), math.sin(2*math.pi*i/24)*shape(z, 2*math.pi*i/24, base), z)), (i/24, z-g0)) for i in range(24)])
    cord.add_grid(rings)
    export('ashwood_staff', [wood, bronze, gem, cord])

bpy.ops.wm.read_factory_settings(use_empty=True)
silver_staff()
ashwood_staff()
