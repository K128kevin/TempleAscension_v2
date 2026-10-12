"""The warrior's kit, after his concept art, built over the hero's body.

Used by tools/outfit_hero.py (which writes it into warrior.glb with every
other class's kit); not run by itself. Every piece is skinned to the hero's
own rig, and the game dresses each by its name (scripts/visual.gd):

  HeroArmor      the scale cuirass: a shell of the torso and the tops of the
                 shoulders, its scales painted on the body's own UVs
                 (tools/paint_kits.py), drawn out from the body to a rigid
                 shape: each cross-section laid on its convex hull (no
                 cleavage, no hollow down the spine or between the ribs), and
                 below the chest it hangs straight rather than following the
                 waist in.
  HeroPauldrons  steel pauldrons over the shoulders: a domed cop and three
                 lames lapping down the upper arm, each a plate of its own
                 standing off the cuirass and the deltoid
                 (assets/shaders/harness.gdshader).
  HeroGauntlets  steel gauntlets: lames over the backs of the hands and every
                 finger, the palms leather, and a flared bell cuff over the
                 wrist that ends halfway up the forearm (harness.gdshader).
  HeroBelt       the broad studded belt, a raised shell painted with the body.
  HeroGreaves    the steel plated boots: sabatons over the feet and a shaft
                 to the middle of the shin, cut level all round at its top
                 and standing off the leg (assets/shaders/plate.gdshader).
  HeroCuisses    the plated leg armor (an item of its own): the legs plated
                 as a pair of long trousers would cover them, from the waist,
                 under the belt, down to the ankles, cuisses, knee cops and
                 greaves in one (plate.gdshader).
  HeroKilt       the war kilt: pteruges, separate strips of stiff leather
                 hung from the belt, each three rigid pieces on bones of their
                 own (kilt_<i>, kilt_<i>_1, kilt_<i>_2; its end kilt_<i>_tip)
                 that bend only at two creases, and a row of short tabs over
                 their tops (kilt_<18+i>), that the game swings and lays on
                 the legs, which push them aside (scripts/kilt_strips.gd,
                 assets/shaders/kilt.gdshader). No piece ever stretches.

Heights are metres up from the ground, the figure at rest (arms out, facing
-Y in Blender's frame).
"""
import math
import bmesh
import bpy
from mathutils import Vector, kdtree
from mathutils.bvhtree import BVHTree

# The cuirass: from just above the belt up, and (painted as scales there
# too, tools/paint_kits.py) over the tops of the shoulders out to the joint.
CUIRASS_BOTTOM = 1.05
# How steeply, below the chest, the cuirass may draw in toward the waist
# (metres in per metre down): a shirt of scales hangs from the chest.
CUIRASS_DRAPE = .3
CUIRASS_DRAPE_FROM = 1.36
# The boots' shaft ends level at the middle of the shin; it stands this far
# off the shin at its top (over the leg plates, when they are worn).
BOOT_TOP = .30
BOOT_STAND = .011
# The ankle's lames: the heights of their lower edges (the greave's own the
# last), and how far each stands out over the one below.
ANKLE_LAMES = (.064, .086, .108)
LAME_STEP = .0035
# The leg plates, from under the belt to the ankles.
LEG_TOP = 1.0
LEG_LOW = .105
# The gauntlets' cuff ends here, halfway up the forearm (out from the middle,
# at rest), and flares this far off the arm at its opening.
CUFF_END = .595
CUFF_FLARE = .017
# The kilt: its strips hang from the lower edge of the belt to mid-thigh,
# their tops tucked up under the belt; the tabs over them are short.
KILT_HINGE = .962
KILT_TOP = 1.0
KILT_HEM = .64
KILT_STRIPS = 18
TAB_HEM = .868
KILT_CENTRE_Y = .02
# Each long strip is three rigid pieces, creased this far down from its hinge
# (metres), each crease a soft fold this wide either side.
KILT_CREASES = (.1, .21)
CREASE_SOFT = .006

RIG = None
BODY = None
OUTFITS = None


def bone_head(name):
    return RIG.matrix_world @ RIG.data.bones[name].head_local


def group_names(obj):
    return {g.index: g.name for g in obj.vertex_groups}


def share(v, names, prefixes):
    """How much of a vertex's skin weight is on bones named with `prefixes`."""
    total = sum(g.weight for g in v.groups)
    if total <= 0: return 0.0
    return sum(g.weight for g in v.groups if names[g.group].startswith(prefixes))/total


def dominant(v, names):
    best = max(v.groups, key=lambda g: g.weight, default=None)
    return names[best.group] if best else ''


# --- Convex cross-sections ----------------------------------------------------

def hull2d(points):
    pts = sorted(set((round(p[0], 6), round(p[1], 6)) for p in points))
    if len(pts) < 3: return pts
    def cross(o, a, b): return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0: lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0: upper.pop()
        upper.append(p)
    return lower[:-1]+upper[:-1]


def ray_hull(hull, c, d):
    """How far from `c` (inside `hull`) along unit `d` the hull's edge lies."""
    best = 0.0
    n = len(hull)
    for i in range(n):
        a = hull[i]; b = hull[(i+1) % n]
        ex, ey = b[0]-a[0], b[1]-a[1]
        wx, wy = a[0]-c[0], a[1]-c[1]
        det = -d[0]*ey+ex*d[1]
        if abs(det) < 1e-12: continue
        t = (-wx*ey+ex*wy)/det
        s = (d[0]*wy-d[1]*wx)/det
        if -1e-6 <= s <= 1+1e-6 and t > best: best = t
    return best


def upper_hull(xs, ys):
    """The least concave function over points (xs rising): their upper
    convex hull, read back at each x."""
    pts = list(zip(xs, ys))
    hull = []
    for p in pts:
        while len(hull) >= 2 and (hull[-1][0]-hull[-2][0])*(p[1]-hull[-2][1])-(hull[-1][1]-hull[-2][1])*(p[0]-hull[-2][0]) >= 0: hull.pop()
        hull.append(p)
    out = []
    j = 0
    for x in xs:
        while j < len(hull)-2 and hull[j+1][0] < x: j += 1
        a, b = hull[j], hull[min(j+1, len(hull)-1)]
        out.append(a[1] if b[0] == a[0] else a[1]+(b[1]-a[1])*(x-a[0])/(b[0]-a[0]))
    return out


class Outline:
    """A rigid plate's outline round an axis along `axis`, from points
    (positions, object space being the world's): each cross-section drawn
    out to its convex hull, and with `along` (True, the spans of the axis
    [(low, high)] it applies over, or a function giving those spans for an
    angle round the axis), each line down the plate at every angle
    round the axis made convex too, so no hollow is left between ribs,
    abdominal muscles, toes or the like. `drape` (slope, below) keeps the
    sections below `below` from drawing in faster than `slope` from any
    above them; `smooth` passes even each line down out. The axis is a
    straight line fitted through the points, or with `local` (metres), a
    curve through the mean of those within that distance along it, or one
    `fixed` (its place across the axis)."""
    ANGLES = 72

    def __init__(self, points, axis, ref, slab=.03, step=.01, along=True, drape=None, local=None, smooth=0, fixed=None, angles=72):
        self.ANGLES = angles
        D = self.D = axis.normalized()
        E1 = self.E1 = (ref-D*ref.dot(D)).normalized()
        self.E2 = D.cross(E1)
        pts = self.pts = [(p.dot(D), p.dot(E1), p.dot(self.E2)) for p in points]
        self.local = local
        self.centres = {}
        self.fixed = fixed
        n = len(pts)
        mh = sum(q[0] for q in pts)/n
        var = sum((q[0]-mh)**2 for q in pts) or 1e-9
        def fit(i):
            m = sum(q[i] for q in pts)/n
            return m, sum((q[0]-mh)*(q[i]-m) for q in pts)/var
        self.line = (mh, fit(1), fit(2))
        self.lo = min(q[0] for q in pts); hi = max(q[0] for q in pts)
        self.step = step
        units = [(math.cos(2*math.pi*j/self.ANGLES), math.sin(2*math.pi*j/self.ANGLES)) for j in range(self.ANGLES)]
        sections = []
        for k in range(int((hi-self.lo)/step)+2):
            hc = self.lo+k*step
            near = [(q[1], q[2]) for q in pts if abs(q[0]-hc) <= slab/2]
            hull = hull2d(near) if len(near) >= 4 else []
            if len(hull) < 3: continue
            c = self.centre(hc)
            sections.append([hc, [ray_hull(hull, c, u) for u in units]])
        self.sections = sections
        for j in range(self.ANGLES):
            if callable(along): spans = along(2*math.pi*j/self.ANGLES)
            else: spans = along if isinstance(along, list) else ([along] if isinstance(along, tuple) else ([(-1e9, 1e9)] if along else []))
            for span in spans:
                run = [sec for sec in sections if span[0] <= sec[0] <= span[1]]
                if len(run) < 3: continue
                ys = upper_hull([sec[0] for sec in run], [sec[1][j] for sec in run])
                for sec, y in zip(run, ys): sec[1][j] = max(sec[1][j], y)
        if drape:
            slope, below = drape
            for sec in sections:
                if sec[0] > below: continue
                for sec2 in sections:
                    if sec2[0] <= sec[0] or sec2[0] > below: continue
                    gap = sec2[0]-sec[0]
                    for j in range(self.ANGLES): sec[1][j] = max(sec[1][j], sec2[1][j]-slope*gap)
        for _ in range(smooth):
            old = [sec[1][:] for sec in sections]
            for k in range(1, len(sections)-1):
                for j in range(self.ANGLES): sections[k][1][j] = (old[k-1][j]+2*old[k][j]+old[k+1][j])/4

    def centre(self, h):
        if self.fixed: return self.fixed
        if self.local:
            # A mean weighted by nearness along the axis, so it moves smoothly.
            key = round(h, 4)
            if key not in self.centres:
                total = x = y = 0.0
                for q in self.pts:
                    w = math.exp(-((q[0]-h)/self.local)**2)
                    total += w; x += w*q[1]; y += w*q[2]
                self.centres[key] = (x/total, y/total)
            return self.centres[key]
        mh, (mx, bx), (my, by) = self.line
        return (mx+bx*(h-mh), my+by*(h-mh))

    def radius(self, h, angle):
        """How far out the outline lies at `h` along the axis, at `angle`
        round it (from E1 toward E2)."""
        secs = self.sections
        k = max(0, min(len(secs)-1, int((h-secs[0][0])/self.step)))
        while k > 0 and secs[k][0] > h: k -= 1
        while k < len(secs)-1 and secs[k+1][0] <= h: k += 1
        f = (angle % (2*math.pi))/(2*math.pi)*self.ANGLES
        j0 = int(f) % self.ANGLES; t = f-int(f)
        def at(sec): return sec[1][j0]*(1-t)+sec[1][(j0+1) % self.ANGLES]*t
        if k == len(secs)-1 or h <= secs[0][0]: return at(secs[k])
        a, b = secs[k], secs[k+1]
        u = (h-a[0])/(b[0]-a[0])
        return at(a)*(1-u)+at(b)*u

    def point(self, h, angle, r):
        c = self.centre(h)
        return self.D*h+self.E1*(c[0]+math.cos(angle)*r)+self.E2*(c[1]+math.sin(angle)*r)

    def frame(self, co):
        """Where `co` lies: along the axis, round it, and out from it."""
        h = co.dot(self.D)
        c = self.centre(h)
        x, y = co.dot(self.E1)-c[0], co.dot(self.E2)-c[1]
        return h, math.atan2(y, x), math.hypot(x, y)


def rigidify(obj, amount, axis, ref, lift=None, hull_from=.5, **shape):
    """Lays vertices of `obj` on a rigid plate's outline (Outline, made from
    those of them `amount(v)` takes more than `hull_from` of) instead of the
    muscle beneath: each goes `amount(v)` (0 to 1) of the way there, then
    `lift(v, h)` further out."""
    rows = [(v, amount(v)) for v in obj.data.vertices]
    rows = [r for r in rows if r[1] > 0]
    makers = [v.co.copy() for v, a in rows if a > hull_from]
    if len(makers) < 8: return None
    outline = Outline(makers, axis, ref, **shape)
    for v, a in rows:
        h, ang, r = outline.frame(v.co)
        if r < 1e-6: continue
        target = outline.radius(h, ang)
        r2 = r+(max(r, target)-r)*a if a < 1.0 else target
        if lift: r2 += lift(v, h)
        v.co = outline.point(h, ang, r2)
    return outline


def solid(obj, thickness, offset=-1.0):
    mod = obj.modifiers.new('Plate thickness', 'SOLIDIFY')
    mod.thickness = thickness; mod.offset = offset; mod.use_rim = True
    mod.use_even_offset = False
    with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj]):
        bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
        bpy.ops.object.modifier_apply(modifier=mod.name)


def smooth_shading(obj):
    for poly in obj.data.polygons: poly.use_smooth = True


def cut(obj, height, keep_above):
    """Cuts `obj` level at `height`, keeping what is above (or below) it."""
    mesh = bmesh.new(); mesh.from_mesh(obj.data)
    geom = mesh.verts[:]+mesh.edges[:]+mesh.faces[:]
    if keep_above: bmesh.ops.bisect_plane(mesh, geom=geom, plane_co=(0, 0, height), plane_no=(0, 0, 1), clear_inner=True)
    else: bmesh.ops.bisect_plane(mesh, geom=geom, plane_co=(0, 0, height), plane_no=(0, 0, 1), clear_outer=True)
    mesh.to_mesh(obj.data); mesh.free()


def smooth_edges(obj, iterations=12):
    """Evens out the open edges of a shell cut from the body (which run
    zigzag along its faces): each point on an edge is drawn toward its two
    neighbours along it, so the neck line, armholes and hems run clean.
    Points the body splits at its UV seams are moved as one."""
    mesh = bmesh.new(); mesh.from_mesh(obj.data)
    def key(v): return (round(v.co.x, 5), round(v.co.y, 5), round(v.co.z, 5))
    ring = {}
    for e in mesh.edges:
        if not e.is_boundary: continue
        a, b = key(e.verts[0]), key(e.verts[1])
        if a == b: continue
        ring.setdefault(a, set()).add(b); ring.setdefault(b, set()).add(a)
    copies = {}
    for v in mesh.verts:
        k = key(v)
        if k in ring: copies.setdefault(k, []).append(v)
    # (Where the body is split at a seam, the two copies of its edge meet
    # head to head: only points on one run, with two neighbours, move.)
    pos = {k: Vector(k) for k in ring}
    for _ in range(iterations):
        new = {}
        for k, near in ring.items():
            if len(near) != 2: continue
            a, b = (pos[n] for n in near)
            new[k] = pos[k]*.5+(a+b)*.25
        pos.update(new)
    for k, verts in copies.items():
        for v in verts: v.co = pos[k]
    mesh.to_mesh(obj.data); mesh.free()


def body_copy(name, keep):
    """A copy of the body's faces whose every vertex `keep(v, bone)` takes,
    with its UVs and skin weights, skinned to the rig."""
    piece = BODY.copy(); piece.data = BODY.data.copy(); piece.name = name
    bpy.context.scene.collection.objects.link(piece)
    names = group_names(piece)
    kept = {v.index for v in piece.data.vertices if keep(v, dominant(v, names))}
    mesh = bmesh.new(); mesh.from_mesh(piece.data)
    bmesh.ops.delete(mesh, geom=[f for f in mesh.faces if not all(v.index in kept for v in f.verts)], context='FACES')
    bmesh.ops.delete(mesh, geom=[v for v in mesh.verts if not v.link_faces], context='VERTS')
    mesh.to_mesh(piece.data); mesh.free()
    for mod in list(piece.modifiers): piece.modifiers.remove(mod)
    piece.parent = RIG
    return piece


def finish(obj, material):
    obj.data.materials.clear()
    obj.data.materials.append(bpy.data.materials.get(material) or bpy.data.materials.new(material))
    for mod in list(obj.modifiers): obj.modifiers.remove(mod)
    obj.parent = RIG
    obj.modifiers.new('Armature', 'ARMATURE').object = RIG
    smooth_shading(obj)


def transfer_weights(obj, near=10, within=.08):
    """Skins `obj` with the weights of the body's points nearest each of its
    own (inverse-distance mean of up to `near` within `within` metres), so it
    moves smoothly with the flesh beneath."""
    names = group_names(BODY)
    tree = kdtree.KDTree(len(BODY.data.vertices))
    for v in BODY.data.vertices: tree.insert(v.co, v.index)
    tree.balance()
    for g in list(obj.vertex_groups): obj.vertex_groups.remove(g)
    groups = {}
    for v in obj.data.vertices:
        found = tree.find_n(v.co, near)
        found = [f for f in found if f[2] <= within] or found[:3]
        mix = {}
        for co, index, dist in found:
            w = 1.0/max(dist, .004)**2
            for g in BODY.data.vertices[index].groups:
                mix[names[g.group]] = mix.get(names[g.group], 0.0)+g.weight*w
        total = sum(mix.values())
        # The four strongest, as the engine skins.
        for name, weight in sorted(mix.items(), key=lambda kv: -kv[1])[:4]:
            if weight/total < .01: continue
            if name not in groups: groups[name] = obj.vertex_groups.new(name=name)
            groups[name].add([v.index], weight/total, 'REPLACE')


# --- The cuirass ---------------------------------------------------------------

def cuirass():
    shoulder_x = abs(bone_head('upperarm_l').x)
    TORSO = ('spine_', 'pelvis', 'root')
    def covered(bone, z, co):
        if bone.startswith(('upperarm', 'clavicle')): return abs(co.x) < shoulder_x-.012
        if bone.startswith(('spine_02', 'spine_03')): return True
        return bone.startswith(('spine_01', 'pelvis', 'root')) and z >= CUIRASS_BOTTOM
    def shape(shell):
        names = group_names(shell)
        rigidify(shell, lambda v: share(v, names, TORSO)**1.5, Vector((0, 0, 1)), Vector((1, 0, 0)), slab=.04, step=.01,
                 drape=(CUIRASS_DRAPE, CUIRASS_DRAPE_FROM))
        smooth_edges(shell)
    armor = OUTFITS.body_shell(BODY, RIG, 'HeroArmor', covered, .022, .018, ('clavicle', 'upperarm'), .03, shape=shape)
    smooth_shading(armor)
    return armor


# --- The pauldrons ---------------------------------------------------------------

# Each plate: its span out along the arm from the middle (metres, at rest),
# and how far round the shoulder it reaches, front and back (degrees from
# the top). The first is the cop over the joint, domed (reaching less far
# round toward the neck, from COP_INNER); the lames below it are each one
# plate of even section, the upper lapping over the lower.
PAULDRON_PLATES = [(.14, .262, 98, 102), (.243, .292, 95, 99), (.274, .322, 92, 96), (.304, .352, 89, 93)]
COP_INNER = (66, 70)
PAULDRON_CLEAR = .014
PAULDRON_LAP = .0055
# How much smaller round the arm each lame may be than the one above it.
PAULDRON_STEP = .007
PAULDRON_THICKNESS = .0035


def pauldrons(armor):
    """Steel pauldrons (see the module's note), made afresh round each upper
    arm's axis, clear of the body and the cuirass beneath."""
    mesh = bmesh.new()
    for obj in (BODY, armor):
        part = bmesh.new(); part.from_mesh(obj.data); part.transform(obj.matrix_world)
        temp = bpy.data.meshes.new('cover'); part.to_mesh(temp); part.free()
        mesh.from_mesh(temp); bpy.data.meshes.remove(temp)
    tree = BVHTree.FromBMesh(mesh); mesh.free()
    out = bmesh.new()
    uv = out.loops.layers.uv.new('UVMap')
    THETAS = 33
    for side in 'lr':
        joint = bone_head('upperarm_'+side)
        s = 1.0 if joint.x > 0 else -1.0
        def direction(theta):
            # Round the arm's axis: 0 straight up, positive to the front (-Y).
            return Vector((0, -math.sin(theta), math.cos(theta)))
        def reach(x, theta):
            d = direction(theta)
            origin = Vector((s*x, joint.y, joint.z))+d*.4
            hit, _, _, dist = tree.ray_cast(origin, -d, .4)
            return .4-dist if hit is not None else 0.0
        # Each plate: rows out along the arm, each [x, angles, radii].
        plates = []
        for k, (x0, x1, front, back) in enumerate(PAULDRON_PLATES):
            cols = 9 if k == 0 else 4
            rows = []
            for i in range(cols):
                x = x0+(x1-x0)*i/(cols-1)
                f, b = front, back
                if k == 0:
                    t = (i/(cols-1))**.6
                    f = COP_INNER[0]+(front-COP_INNER[0])*t; b = COP_INNER[1]+(back-COP_INNER[1])*t
                thetas = [math.radians(-b+(f+b)*j/(THETAS-1)) for j in range(THETAS)]
                # The body's (and cuirass's) outline round the axis, the
                # widest over a window along the arm (the whole plate for a
                # lame: it is one plate of even section), made convex.
                window = (x0, x1) if k else (max(x0, x-.03), min(x1, x+.03))
                samples = [window[0]+(window[1]-window[0])*q/4 for q in range(5)]
                prof = [max(reach(xx, t) for xx in samples) for t in thetas]
                pts = [(0.0, 0.0)]+[(direction(t).y*r, direction(t).z*r) for t, r in zip(thetas, prof)]
                hull = hull2d(pts)
                if len(hull) >= 3: prof = [max(r, ray_hull(hull, (0.0, 0.0), (direction(t).y, direction(t).z))) for t, r in zip(thetas, prof)]
                for _ in range(3):
                    prof = [prof[0]]+[(prof[j-1]+2*prof[j]+prof[j+1])/4 for j in range(1, len(prof)-1)]+[prof[-1]]
                rows.append([x, thetas, [r+PAULDRON_CLEAR for r in prof]])
            if k == 0:
                # The cop is one smooth dome: its rows evened out along the arm.
                for _ in range(2):
                    radii = [r[2][:] for r in rows]
                    for i in range(1, len(rows)-1):
                        rows[i][2] = [max(radii[i][j], (radii[i-1][j]+2*radii[i][j]+radii[i+1][j])/4) for j in range(THETAS)]
            plates.append(rows)
        def radius_at(row, t):
            thetas, radii = row[1], row[2]
            t = min(max(t, thetas[0]), thetas[-1])
            f = (t-thetas[0])/(thetas[-1]-thetas[0])*(len(thetas)-1)
            j0 = min(int(f), len(thetas)-2); a = f-j0
            return radii[j0]*(1-a)+radii[j0+1]*a
        # Each lame no smaller round the arm than PAULDRON_STEP inside the
        # plate above's lower edge (so the shoulder reads as one piece)...
        for k in range(1, len(plates)):
            above = plates[k-1][-1]
            for row in plates[k]:
                row[2] = [max(r, radius_at(above, t)-PAULDRON_STEP) for t, r in zip(row[1], row[2])]
        # ...and each plate, from the lowest up, lapping over the next.
        for k in range(len(plates)-2, -1, -1):
            below = plates[k+1][0]
            for row in plates[k]:
                if row[0] < below[0]-.004: continue
                row[2] = [max(r, radius_at(below, t)+PAULDRON_LAP) for t, r in zip(row[1], row[2])]
        for k, rows in enumerate(plates):
            x0, x1 = rows[0][0], rows[-1][0]
            verts = []
            for x, thetas, radii in rows:
                # Each plate's lower edge turns out a little, a rolled lip.
                lip = max(0.0, (x-(x1-.012))/.012)
                verts.append([out.verts.new(Vector((s*x, joint.y, joint.z))+direction(t)*(r+.004*lip*lip)) for t, r in zip(thetas, radii)])
            # Arc length round the plate, for the shader's rivets.
            mid = verts[len(verts)//2]
            arc = [0.0]
            for j in range(1, THETAS): arc.append(arc[-1]+(mid[j].co-mid[j-1].co).length)
            for i in range(len(rows)-1):
                for j in range(THETAS-1):
                    quad = [(i, j), (i, j+1), (i+1, j+1), (i+1, j)]
                    if s < 0: quad.reverse()
                    face = out.faces.new([verts[a][c] for a, c in quad])
                    for loop, (a, c) in zip(face.loops, quad):
                        loop[uv].uv = (arc[c], k+min(.999, (rows[a][0]-x0)/(x1-x0)))
    obj = bpy.data.objects.new('HeroPauldrons', bpy.data.meshes.new('HeroPauldrons'))
    out.normal_update()
    # Faces point out from the arm.
    for face in out.faces:
        c = face.calc_center_median()
        axis = Vector((c.x, bone_head('upperarm_l').y, bone_head('upperarm_l').z))
        if face.normal.dot(c-axis) < 0: face.normal_flip()
    out.to_mesh(obj.data); out.free()
    bpy.context.scene.collection.objects.link(obj)
    solid(obj, PAULDRON_THICKNESS)
    transfer_weights(obj)
    finish(obj, 'PauldronSteel')
    return obj


# --- The gauntlets ---------------------------------------------------------------

HAND_BONES = ('hand_', 'thumb_', 'index_', 'middle_', 'ring_', 'pinky_')
FINGERS = ('thumb', 'index', 'middle', 'ring', 'pinky')


def gauntlets():
    wrist = {side: bone_head('hand_'+side) for side in 'lr'}
    elbow = {side: bone_head('lowerarm_'+side) for side in 'lr'}
    def keep(v, bone):
        if bone.startswith(HAND_BONES): return True
        return bone.startswith('lowerarm') and abs(v.co.x) > CUFF_END-.01
    piece = body_copy('HeroGauntlets', keep)
    cut_x = CUFF_END
    mesh = bmesh.new(); mesh.from_mesh(piece.data)
    for sign in (1, -1):
        geom = mesh.verts[:]+mesh.edges[:]+mesh.faces[:]
        bmesh.ops.bisect_plane(mesh, geom=geom, plane_co=(sign*cut_x, 0, 0), plane_no=(sign, 0, 0))
    bmesh.ops.delete(mesh, geom=[f for f in mesh.faces if abs(f.calc_center_median().x) < cut_x], context='FACES')
    bmesh.ops.delete(mesh, geom=[v for v in mesh.verts if not v.link_faces], context='VERTS')
    mesh.to_mesh(piece.data); mesh.free()
    names = group_names(piece)
    piece.data.update()
    # The hand shell: a little off the skin over the hand and fingers.
    for v in piece.data.vertices:
        v.co += v.normal*(.0055 if share(v, names, HAND_BONES) > .5 else .0)
    # The cuff: a bell of one plate, rigid and round (its section the convex
    # hull of the arm's), flaring from the wrist to its opening.
    wrist_x = abs(wrist['l'].x)
    for side, sign in (('l', 1.0), ('r', -1.0)):
        side_wrist = wrist[side]
        def amount(v):
            if v.co.x*sign <= 0: return 0.0
            arm = 1.0-share(v, names, HAND_BONES)
            return arm if abs(v.co.x) < wrist_x+.03 else 0.0
        def lift(v, h):
            t = max(0.0, min(1.0, (wrist_x+.01-abs(v.co.x))/(wrist_x+.01-CUFF_END)))
            return .007+CUFF_FLARE*t**1.6
        rigidify(piece, amount, Vector((sign, 0, 0)), Vector((0, 0, 1)), slab=.02, step=.006, lift=lift, hull_from=.5)
    # Parts for the shader (harness.gdshader), in the UVs: V runs from the
    # cuff's opening out to the fingertips, its whole part the plate (0 the
    # cuff, 1 to 4 the lames over the back of the hand, 5 the knuckle plate,
    # 6 to 8 the scales of each finger, nail to knuckle); U is across, in
    # metres, plus 100 where it is the leather palm and the fingers' insides.
    piece.data.update()
    hand_lames = [wrist_x+i*.026 for i in range(5)]
    knuckle = {}
    for f in FINGERS[1:]:
        knuckle[f] = abs(bone_head(f+'_01_l').x)
    first = min(knuckle.values())
    uvs = {}
    for v in piece.data.vertices:
        x = abs(v.co.x)
        bone = dominant(v, names)
        part = None
        for f in FINGERS:
            if bone.startswith(f+'_'):
                # Its scales: the thumb's from its root on the hand, every
                # other finger's from its knuckle, one to each joint.
                seg = min(4, int(bone.split('_')[1]))
                head = RIG.matrix_world @ RIG.data.bones[bone].head_local
                tail = RIG.matrix_world @ RIG.data.bones[bone].tail_local
                along = max(0.0, min(.999, (v.co-head).dot((tail-head).normalized())/max((tail-head).length, 1e-4)))
                part = 8.999 if seg == 4 else (5+seg+along if f != 'thumb' or seg > 1 else 5+along)
                break
        if part is None:
            if x < wrist_x-.004: part = max(0.0, min(.999, (x-CUFF_END)/(wrist_x-.004-CUFF_END)))
            elif x < first-.012:
                k = min(3, int((x-wrist_x+.004)/((first-.012-wrist_x+.004)/4)))
                part = 1+k+min(.999, ((x-wrist_x+.004)-k*(first-.012-wrist_x+.004)/4)/((first-.012-wrist_x+.004)/4))
            else: part = 5+min(.999, max(0.0, (x-(first-.012))/.03))
        palm = part >= 1.0 and v.normal.z < -.35
        across = v.co.y*1.0+v.co.z*.3
        uvs[v.index] = (across+(100.0 if palm else 0.0), part)
    layer = piece.data.uv_layers.active or piece.data.uv_layers.new(name='UVMap')
    for loop in piece.data.loops:
        layer.data[loop.index].uv = uvs[loop.vertex_index]
    solid(piece, .003)
    finish(piece, 'GauntletSteel')
    return piece


# --- The boots -------------------------------------------------------------------

def boots():
    """The steel plated boots, made afresh rather than from the body's own
    foot (its toes would show through): a loft of level rings up from the
    sole, each the outline of the foot or leg within it (Outline: its convex
    hull, evened out up the leg) a little off it. So the sabaton keeps the
    foot's own size, a rounded toe box sloping up the instep; two lames
    articulate the ankle, each lapping the one below; and the greave follows
    the shin and the swell of the calf a finger's breadth off them, flaring
    a little to a rolled rim, level all round at mid-shin. (The toe's lames
    are drawn by assets/shaders/plate.gdshader.)"""
    names = group_names(BODY)
    ankle = bone_head('foot_l').z
    RING = 96
    out = bmesh.new()
    for side in 'lr':
        sign = 1.0 if bone_head('foot_'+side).x > 0 else -1.0
        pts = [v.co.copy() for v in BODY.data.vertices if v.co.x*sign > .02 and v.co.z < BOOT_TOP+.06 and dominant(v, names).startswith(('calf', 'foot', 'ball'))]
        sole = min(p.z for p in pts)
        # Measured round the shin's own upright axis.
        shin = [p for p in pts if ankle+.05 < p.z < BOOT_TOP]
        axis = (sum(p.x for p in shin)/len(shin), sum(p.y for p in shin)/len(shin))
        # Each run up the boot made convex (no hollow over the ankle bones or
        # beside the shin): the sabaton's below the ankle, the greave's above.
        outline = Outline(pts, Vector((0, 0, 1)), Vector((1, 0, 0)), slab=.024, step=.005, along=[(sole, ankle-.025), (ankle+.035, 1.0)], smooth=4, fixed=axis, angles=144)
        def stand(h):
            # A centimetre off the foot, rising to BOOT_STAND over the shin,
            # and flaring a little at the top.
            up = max(0.0, min(1.0, (h-ankle)/.08))
            flare = max(0.0, (h-(BOOT_TOP-.05))/.05)
            return .009+(BOOT_STAND-.009)*up*up*(3-2*up)+.003*flare*flare
        def lames(h):
            # Each lame's lower edge stands out over the one below it,
            # easing in to its top; the greave's lower edge laps the last.
            lift = 0.0
            for e in ANKLE_LAMES:
                if h >= e: lift = LAME_STEP*max(0.0, 1.0-(h-e)/(ANKLE_LAMES[1]-ANKLE_LAMES[0]))
            return lift
        heights = [sole+.002, sole+.006, sole+.011]
        h = sole+.016
        while h < BOOT_TOP-.004:
            heights.append(h)
            h += .006 if h < ankle+.04 else .014
        for e in ANKLE_LAMES: heights += [e-.0012, e+.0012]
        heights = sorted(set(round(x, 4) for x in heights if sole+.002 <= x < BOOT_TOP-.004))
        rows = []
        for i, h in enumerate(heights):
            # The sole's edge is rounded: the lowest rings drawn in.
            tuck = [.008, .0035, .001][i] if i < 3 else 0.0
            ring = []
            for j in range(RING):
                ang = 2*math.pi*j/RING
                r = outline.radius(max(h, sole+.011), ang)+stand(h)+lames(h)-tuck
                ring.append(out.verts.new(outline.point(h-.01 if i == 0 else h, ang, r)))
            rows.append(ring)
        # The rolled rim: up to the top, then turned out and down over it.
        last = heights[-1]
        for dz, dr in ((BOOT_TOP-.004-last, .0), (BOOT_TOP-last, .003), (BOOT_TOP-.005-last, .0065)):
            ring = []
            for j in range(RING):
                ang = 2*math.pi*j/RING
                h = last+dz
                r = outline.radius(min(h, BOOT_TOP-.004), ang)+stand(min(h, BOOT_TOP))+dr
                ring.append(out.verts.new(outline.point(h, ang, r)))
            rows.append(ring)
        for a_, b_ in zip(rows, rows[1:]):
            for j in range(RING):
                out.faces.new([a_[j], a_[(j+1) % RING], b_[(j+1) % RING], b_[j]])
        # The sole, closed.
        out.faces.new(list(reversed(rows[0])))
    obj = bpy.data.objects.new('HeroGreaves', bpy.data.meshes.new('HeroGreaves'))
    bmesh.ops.recalc_face_normals(out, faces=out.faces[:])
    out.to_mesh(obj.data); out.free()
    bpy.context.scene.collection.objects.link(obj)
    solid(obj, .004)
    transfer_weights(obj, within=.05)
    finish(obj, 'BootSteel')
    return obj


# --- The leg plates ----------------------------------------------------------------

def leg_plates():
    knee = bone_head('calf_l').z
    def keep(v, bone):
        if bone.startswith(('thigh', 'calf')): return LEG_LOW-.04 < v.co.z < LEG_TOP+.05
        if bone.startswith(('foot',)): return v.co.z > LEG_LOW-.04 and v.co.y > -.02
        return bone.startswith(('pelvis', 'root', 'spine_01')) and v.co.z < LEG_TOP+.05
    piece = body_copy('HeroCuisses', keep)
    names = group_names(piece)
    piece.data.update()
    # Off the skin: a little more over the thighs and hips than the shins.
    for v in piece.data.vertices:
        up = max(0.0, min(1.0, (v.co.z-(knee-.08))/.16))
        v.co += v.normal*(.013+.007*up)
    for sign in (1.0, -1.0):
        def amount(v):
            if v.co.x*sign <= 0: return 0.0
            return share(v, names, ('thigh', 'calf', 'foot'))
        rigidify(piece, amount, Vector((0, 0, 1)), Vector((1, 0, 0)), slab=.03, step=.01)
    # A domed cop over each knee.
    for sign in (1.0, -1.0):
        ring = [v.co for v in piece.data.vertices if v.co.x*sign > 0 and abs(v.co.z-knee) < .02]
        if not ring: continue
        front = min(c.y for c in ring)
        cx = sum(c.x for c in ring)/len(ring)
        for v in piece.data.vertices:
            if v.co.x*sign <= 0: continue
            d = math.hypot((v.co.x-cx)/.06, (v.co.z-(knee+.005))/.07)
            if d < 1 and v.co.y < front+.05:
                v.co.y -= .014*(1-d*d)**1.5*max(0.0, min(1.0, (front+.05-v.co.y)/.04))
    cut(piece, LEG_TOP, keep_above=False)
    cut(piece, LEG_LOW, keep_above=True)
    solid(piece, .008)
    finish(piece, 'LegSteel')
    return piece


# --- The kilt ----------------------------------------------------------------------

def kilt():
    """Rigid strips of leather on bones of their own (see the module's note)."""
    names = group_names(BODY)
    cy = KILT_CENTRE_Y
    ring = []
    for v in BODY.data.vertices:
        bone = dominant(v, names)
        if not bone.startswith(('pelvis', 'root', 'spine_01', 'thigh')): continue
        if not KILT_HEM-.03 < v.co.z < KILT_TOP+.03: continue
        ring.append((math.atan2(v.co.x, v.co.y-cy), math.hypot(v.co.x, v.co.y-cy), v.co.z))
    def profile(bearing, half):
        rows = {}
        for b, r, z in ring:
            gap = (b-bearing+math.pi) % (2*math.pi)-math.pi
            if abs(gap) > half: continue
            k = int(round(z/.01))
            rows[k] = max(rows.get(k, 0.0), r)
        return rows
    pitch = 2*math.pi/KILT_STRIPS
    def strip_line(bearing, half, clear, hinge_clear):
        rows = profile(bearing, half)
        def body_at(z):
            near = [rows[k] for k in rows if abs(k*.01-z) <= .015]
            return max(near) if near else 0.0
        r_hinge = body_at(KILT_HINGE)+hinge_clear
        slope = math.tan(math.radians(2.0))
        for k, r in rows.items():
            z = k*.01
            if z > KILT_HINGE-.03: continue
            slope = max(slope, (r+clear-r_hinge)/(KILT_HINGE-z))
        return r_hinge, math.atan(slope)
    lines = []
    for i in range(KILT_STRIPS):
        b = i*pitch
        r_h, phi = strip_line(b, pitch*.7, .013, .012)
        lines.append((b, r_h, phi))
    # The tabs, between the strips' middles, just outside them.
    tabs = []
    for i in range(KILT_STRIPS):
        b = (i+.5)*pitch
        a, c = lines[i], lines[(i+1) % KILT_STRIPS]
        r_h = (a[1]+c[1])/2+.0075
        phi = max(a[2], c[2])
        tabs.append((b, r_h, phi))
    mesh = bmesh.new()
    uv = mesh.loops.layers.uv.new('UVMap')
    deform = mesh.verts.layers.deform.verify()
    bones = []
    def add_strip(index, bearing, r_h, phi, low, width_top, width_low, thickness, rounded):
        out = Vector((math.sin(bearing), math.cos(bearing), 0))
        across = Vector((math.cos(bearing), -math.sin(bearing), 0))
        hinge = Vector((0, cy, KILT_HINGE))+out*r_h
        down = Vector((out.x*math.sin(phi), out.y*math.sin(phi), -math.cos(phi)))
        normal = across.cross(down).normalized()
        if normal.dot(out) < 0: normal = -normal
        length = (KILT_HINGE-low)/math.cos(phi)
        above = (KILT_TOP-KILT_HINGE)/math.cos(phi)
        long_strip = length > .2
        creases = KILT_CREASES if long_strip else ()
        # Rows down the strip (s: metres from the hinge), with a row either
        # side of each crease so it folds there and nowhere else.
        rows_at = [-above+(length+above)*r/(14 if long_strip else 5) for r in range((14 if long_strip else 5)+1)]
        for c in creases: rows_at += [c-CREASE_SOFT, c+CREASE_SOFT]
        rows_at = sorted(set(round(x, 5) for x in rows_at))
        ROWS, COLS = len(rows_at)-1, 4
        bend = r_h
        groups = [bones_index[index]]+[bones_index[(index, k)] for k in (1, 2)] if long_strip else [bones_index[index]]
        def skin(vert, s):
            # Wholly on its piece, shared between the two either side of a
            # crease across its fold.
            vert[deform].clear()
            k = sum(1 for c in creases if s >= c+CREASE_SOFT)
            for n, c in enumerate(creases):
                if abs(s-c) < CREASE_SOFT:
                    a = (s-(c-CREASE_SOFT))/(2*CREASE_SOFT)
                    vert[deform][groups[n]] = 1-a
                    vert[deform][groups[n+1]] = a
                    return
            vert[deform][groups[k]] = 1.0
        def point(row, col, back):
            s = rows_at[row]
            t = (s+above)/(length+above)
            w = width_top+(width_low-width_top)*t
            u = (col/COLS-.5)
            if rounded:
                # A rounded tongue: its corners drawn up into a curve.
                s -= (1-math.sqrt(max(0.0, 1-(2*u)**2)))*w*.5*max(0.0, (t-.55)/.45)
            p = hinge+down*s+across*(u*w)-normal*((u*w)**2/(2*bend))
            if back: p -= normal*thickness
            return p, (index+col/COLS, t), rows_at[row]
        grids = []
        for back in (False, True):
            grid = []
            for row in range(ROWS+1):
                grid.append([point(row, col, back) for col in range(COLS+1)])
            grids.append(grid)
        # Front and back, each a grid of its own; then the edges between.
        for back in (0, 1):
            grid = grids[back]
            verts = [[None]*(COLS+1) for _ in range(ROWS+1)]
            for row in range(ROWS+1):
                for col in range(COLS+1):
                    p, (u_, v_), s_ = grid[row][col]
                    vert = mesh.verts.new(p)
                    skin(vert, s_)
                    strip_of[vert] = index
                    verts[row][col] = (vert, (u_+(500.0 if back else 0.0), v_))
            for row in range(ROWS):
                for col in range(COLS):
                    quad = [verts[row][col], verts[row][col+1], verts[row+1][col+1], verts[row+1][col]]
                    if back: quad.reverse()
                    f = mesh.faces.new([q[0] for q in quad])
                    for loop, q in zip(f.loops, quad): loop[uv].uv = q[1]
                    f.smooth = True
        front, back = grids
        # The cut edges: down each side, along the hem and (under the belt) the top.
        edges = [[front[row][0] for row in range(ROWS+1)], [front[ROWS][col] for col in range(COLS+1)], [front[row][COLS] for row in range(ROWS, -1, -1)], [front[0][col] for col in range(COLS, -1, -1)]]
        backs = [[back[row][0] for row in range(ROWS+1)], [back[ROWS][col] for col in range(COLS+1)], [back[row][COLS] for row in range(ROWS, -1, -1)], [back[0][col] for col in range(COLS, -1, -1)]]
        for run, brun in zip(edges, backs):
            for a in range(len(run)-1):
                quad = [run[a], run[a+1], brun[a+1], brun[a]]
                verts = []
                for p, (u_, v_), s_ in quad:
                    vert = mesh.verts.new(p)
                    skin(vert, s_)
                    strip_of[vert] = index
                    verts.append((vert, (u_+500.0, v_)))
                f = mesh.faces.new([q[0] for q in verts])
                for loop, q in zip(f.loops, verts): loop[uv].uv = q[1]
                f.smooth = False
        bones.append((index, hinge, down, [0.0]+list(creases)+[length]))
    # Bone indices into the deform layer: a vertex group per piece (kilt_<i>
    # the top piece or a tab, kilt_<i>_1 and kilt_<i>_2 those below), made
    # below in the same order.
    bones_index = {}
    group_names_in_order = []
    for i in range(KILT_STRIPS*2):
        bones_index[i] = len(group_names_in_order); group_names_in_order.append('kilt_%d' % i)
    for i in range(KILT_STRIPS):
        for k in (1, 2):
            bones_index[(i, k)] = len(group_names_in_order); group_names_in_order.append('kilt_%d_%d' % (i, k))
    strip_of = {}
    for i, (b, r_h, phi) in enumerate(lines):
        w_top = 2*math.pi*r_h/KILT_STRIPS*.9
        add_strip(i, b, r_h, phi, KILT_HEM, w_top, w_top*1.22, .0055, False)
    for i, (b, r_h, phi) in enumerate(tabs):
        w = 2*math.pi*r_h/KILT_STRIPS*1.04
        add_strip(KILT_STRIPS+i, b, r_h, phi, TAB_HEM, w, w, .006, True)
    obj = bpy.data.objects.new('HeroKilt', bpy.data.meshes.new('HeroKilt'))
    bpy.context.scene.collection.objects.link(obj)
    for name in group_names_in_order: obj.vertex_groups.new(name=name)
    # Every strip a closed slab, each of its faces turned out from its middle
    # (its points are kept apart at the slab's edges, so they shade sharp).
    mesh.normal_update()
    middles = {}
    for v in mesh.verts:
        middles.setdefault(strip_of[v], []).append(v.co)
    middles = {g: sum(cos, Vector((0, 0, 0)))/len(cos) for g, cos in middles.items()}
    for f in mesh.faces:
        # (Its own middle: a piece's, near enough, for a strip's long faces.)
        g = strip_of[f.verts[0]]
        if f.normal.dot(f.calc_center_median()-middles[g]) < 0: f.normal_flip()
    mesh.normal_update()
    mesh.to_mesh(obj.data); mesh.free()
    # The bones: each strip's pieces from its hinge down its length, one to
    # the next, with an end bone to give the game its length.
    bpy.context.view_layer.objects.active = RIG
    bpy.ops.object.mode_set(mode='EDIT')
    edit = RIG.data.edit_bones
    to_rig = RIG.matrix_world.inverted()
    for index, hinge, down, marks in bones:
        parent = edit['pelvis']
        names = ['kilt_%d' % index]+['kilt_%d_%d' % (index, k) for k in range(1, len(marks)-1)]
        for k, name in enumerate(names):
            bone = edit.new(name)
            bone.head = to_rig @ (hinge+down*marks[k]); bone.tail = to_rig @ (hinge+down*marks[k+1])
            bone.parent = parent; bone.use_connect = k > 0
            parent = bone
        tail = hinge+down*marks[-1]
        end = edit.new('kilt_%d_tip' % index)
        end.head = to_rig @ tail; end.tail = to_rig @ (tail+down*.03)
        end.parent = parent; end.use_connect = True
    bpy.ops.object.mode_set(mode='OBJECT')
    obj.data.materials.append(bpy.data.materials.get('KiltLeather') or bpy.data.materials.new('KiltLeather'))
    obj.parent = RIG
    obj.modifiers.new('Armature', 'ARMATURE').object = RIG
    print('WARRIOR_KILT', len(bones), 'strips', ['%.0f' % math.degrees(l[2]) for l in lines])
    return obj


def build(outfits, rig, body):
    global RIG, BODY, OUTFITS
    RIG, BODY, OUTFITS = rig, body, outfits
    armor = cuirass()
    pieces = [armor, pauldrons(armor), gauntlets()]
    belt = outfits.body_shell(body, rig, 'HeroBelt', lambda bone, z: bone.startswith(('spine_01', 'pelvis', 'root', 'spine_02')) and .953 < z < 1.047, .03, .012, shape=smooth_edges)
    pieces += [belt, boots(), leg_plates(), kilt()]
    print('WARRIOR_KIT', [(o.name, len(o.data.vertices)) for o in pieces])
    return pieces
