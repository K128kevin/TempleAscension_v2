"""Builds the townspeople: assets/models/character/townsman.glb and townswoman.glb.

Each is one of the base character pack's two bodies (the pack's male and
female "superhero", which come unclothed) on its own skeleton, with the pack's
hairstyles, a wardrobe, and the clips a townsperson needs from the two
animation libraries, retargeted as tools/import_character.py retargets the
hero's: standing, talking, walking, jogging, sitting down and getting up,
sitting, sitting and talking, drinking, reaching, carrying, dancing, and
getting up from lying on the ground (played backward, lying down).

The packs have no clothes, so the wardrobe is fitted here from the body's own
shape. A garment is a tube lofted down the body: at each height the outline
of the body there (its convex hull, arms left out) is taken, eased outward by
the cloth's looseness, and joined to the next, and from the top it is laid
over the shoulders in to the neck; sleeves are lofted along the
arms the same way. Every garment is skinned from the flesh nearest it, so it
moves with the wearer. The woman's dress is such a tube with its neck cut
square and wide, leaving straps over the shoulders, over a long-sleeved blouse;
her braid is laid down her back from the nape, lobe over lobe. An apron is the
front of a skirt, laid over it. Sandals are cut to the feet: a sole under each
and straps where planes cut the foot. The starving's hair is the woman's long
hair grown out and matted, and the men's beard grown long with it.

The game picks which hair and which garment each person wears and dyes and
wears them out (scripts/townsperson.gd, assets/shaders/cloth.gdshader). Two
things are carried to it in each mesh's second UV set: on a garment, how near
its hem or cuff a point is (where rags fray) and how far down its length; on
the body, each point's height at rest and how far along the arm it is, so the
flesh under a garment is not drawn and never shows through it.

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_townsfolk.py
"""
import math
from pathlib import Path
import bpy, bmesh
from mathutils import Vector, Matrix
from mathutils.kdtree import KDTree
ROOT = Path(__file__).resolve().parents[1]
ASSETS = Path('/Users/ktabb/Documents/3dAssets')
BASE = ASSETS/'Universal Base Characters[Standard]'
HAIR = BASE/'Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)'
LIBRARIES = [ASSETS/'Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb', ASSETS/'Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb']
OUT = ROOT/'assets/models/character'
# The game's clip: the library's.
CLIPS = {'Idle': 'Idle_Loop', 'Talk': 'Idle_Talking_Loop', 'Walk': 'Walk_Loop', 'Jog': 'Jog_Fwd_Loop', 'SitDown': 'Sitting_Enter',
    'StandUp': 'Sitting_Exit', 'Sit': 'Sitting_Idle_Loop', 'SitTalk': 'Sitting_Talking_Loop', 'Reach': 'Interact', 'Dance': 'Dance_Loop',
    'Drink': 'Consume', 'Carry': 'Walk_Carry_Loop', 'Arms': 'Idle_FoldArms_Loop', 'GetUp': 'LayToIdle'}
ARM = ('upperarm', 'lowerarm', 'hand', 'index', 'middle', 'pinky', 'ring', 'thumb')
# Triangles the body is cut to (a crowd of twenty is on screen at once).
BODY_TRIANGLES = 7000
# Each garment's reach, written out for the game: from what height down to
# what height it covers the body, and how far down the arm.
WARDROBE = {}
WARDROBE_SCRIPT = ROOT/'scripts/wardrobe.gd'

def V(x, y, z):
    return Vector((x, y, z))

def hull(points):
    """The convex hull of 2D points, counter-clockwise."""
    points = sorted(set((round(p[0], 5), round(p[1], 5)) for p in points))
    if len(points) < 3: return points
    def half(sequence):
        out = []
        for p in sequence:
            while len(out) >= 2 and (out[-1][0]-out[-2][0])*(p[1]-out[-2][1])-(out[-1][1]-out[-2][1])*(p[0]-out[-2][0]) <= 0: out.pop()
            out.append(p)
        return out
    lower = half(points)
    upper = half(reversed(points))
    return lower[:-1]+upper[:-1]

def outline(points, count, ease, start):
    """`count` points evenly round the hull of 2D `points`, pushed out by
    `ease`, the first nearest the direction `start` from its middle."""
    ring = hull(points)
    if len(ring) < 3: return None
    middle = (sum(p[0] for p in ring)/len(ring), sum(p[1] for p in ring)/len(ring))
    # The ring starts where the line from its middle toward `start` leaves the
    # hull, so each ring of a tube starts in line with the next.
    for i in range(len(ring)):
        a, b = ring[i], ring[(i+1) % len(ring)]
        edge = (b[0]-a[0], b[1]-a[1])
        across = start[0]*edge[1]-start[1]*edge[0]
        if abs(across) < 1e-12: continue
        t = ((a[0]-middle[0])*edge[1]-(a[1]-middle[1])*edge[0])/across
        s = ((a[0]-middle[0])*start[1]-(a[1]-middle[1])*start[0])/across
        if t > 0 and 0.0 <= s <= 1.0:
            ring = [(middle[0]+start[0]*t, middle[1]+start[1]*t)]+ring[i+1:]+ring[:i+1]
            break
    lengths = [math.dist(ring[i], ring[(i+1) % len(ring)]) for i in range(len(ring))]
    total = sum(lengths)
    out = []
    edge, along = 0, 0.0
    for k in range(count):
        target = total*k/count
        while along+lengths[edge] < target and edge < len(ring)-1:
            along += lengths[edge]
            edge += 1
        a, b = ring[edge], ring[(edge+1) % len(ring)]
        t = (target-along)/max(lengths[edge], 1e-9)
        out.append((a[0]+(b[0]-a[0])*t, a[1]+(b[1]-a[1])*t))
    eased = []
    for k in range(count):
        before, after = out[k-1], out[(k+1) % count]
        normal = (after[1]-before[1], -(after[0]-before[0]))
        size = math.hypot(*normal) or 1.0
        eased.append((out[k][0]+normal[0]/size*ease, out[k][1]+normal[1]/size*ease))
    return eased

class Body:
    """The body's flesh as built, before it is cut down: where each point is,
    and which bones hold it."""
    def __init__(self, obj, rig):
        self.rig = rig
        self.points = [obj.matrix_world @ v.co for v in obj.data.vertices]
        names = [g.name for g in obj.vertex_groups]
        self.weights = [{names[g.group]: g.weight for g in v.groups if g.weight > 0.0} for v in obj.data.vertices]
        self.arm = [max(w, key=w.get).startswith(ARM) if w else False for w in self.weights]
        self.shoulder = self.joint('upperarm_l').x+.02
        obj.data.calc_loop_triangles()
        self.triangles = [tuple(t.vertices) for t in obj.data.loop_triangles]
        self.normals = [(obj.matrix_world.to_3x3() @ v.normal).normalized() for v in obj.data.vertices]

    def section(self, origin, normal, near):
        """Where the plane through `origin` facing `normal` cuts the flesh,
        among the triangles with a corner for which `near(point)` holds."""
        out = []
        for tri in self.triangles:
            corners = [self.points[i] for i in tri]
            if not any(near(c) for c in corners): continue
            side = [(c-origin).dot(normal) for c in corners]
            for a in range(3):
                b = (a+1) % 3
                if (side[a] < 0) != (side[b] < 0):
                    t = side[a]/(side[a]-side[b])
                    out.append(corners[a].lerp(corners[b], t))
        return out

    def joint(self, name):
        return self.rig.matrix_world @ self.rig.data.bones[name].head_local

    def tree(self, keep):
        chosen = [i for i in range(len(self.points)) if keep(i)]
        tree = KDTree(len(chosen))
        for i in chosen: tree.insert(self.points[i], i)
        tree.balance()
        return tree

    def skin(self, tree, at):
        """The hold of the flesh nearest `at`."""
        total = {}
        for point, index, distance in tree.find_n(at, 3):
            share = 1.0/(distance+.004)
            for name, weight in self.weights[index].items(): total[name] = total.get(name, 0.0)+weight*share
        return total

class Garment:
    """Rings of cloth, joined into tubes."""
    def __init__(self, name, body):
        self.name = name
        self.body = body
        self.verts, self.faces, self.uv, self.data, self.weights = [], [], [], [], []
        # The line each face's tube runs along (a point on it and its way).
        self.lines = []
        self.top, self.hem, self.sleeve = 0.0, 0.0, 0.0

    def tube(self, rings, edges, tree, line, lengths=None):
        """Joins `rings` (each a list of points) in order. `edges` says how
        near its open edge each ring is (1 at a hem or cuff)."""
        count = len(rings[0])
        base = len(self.verts)
        run = 0.0
        total = sum((rings[k][0]-rings[k-1][0]).length for k in range(1, len(rings))) or 1.0
        for k, ring in enumerate(rings):
            if k: run += (ring[0]-rings[k-1][0]).length
            around = 0.0
            for i, point in enumerate(ring):
                if i: around += (point-ring[i-1]).length
                self.verts.append(point)
                self.uv.append((around, run))
                self.data.append((edges[k], run/total if lengths is None else lengths[k]))
                self.weights.append(self.body.skin(tree, point))
        for k in range(len(rings)-1):
            for i in range(count):
                j = (i+1) % count
                self.faces.append((base+k*count+i, base+(k+1)*count+i, base+(k+1)*count+j, base+k*count+j))
                self.lines.append((line[0], line[1], base))

    def trunk(self, top, hem, ease, count=32, step=.025, fray=.14, yoke=.014, collar=.03, rise=.035):
        """The body of the garment, from `top` down to `hem`: `ease(z)` is the
        cloth's looseness at each height."""
        body = self.body
        self.top, self.hem = top, hem
        levels = []
        z = top
        while z > hem+step*.5:
            levels.append(z)
            # (Closer together over the shoulders, where the shape turns.)
            z -= step*.6 if z > body.joint('upperarm_l').z-.07 else step
        levels.append(hem)
        rings = []
        for z in levels:
            band = step*.8
            chosen = [(p.x, p.y) for p in body.points if abs(p.z-z) < band and abs(p.x) <= body.shoulder]
            ring = outline(chosen, count, ease(z), (0, -1))
            if ring is None: ring = [(p[0], p[1]) for p in rings[-1]]
            rings.append([V(p[0], p[1], z) for p in ring])
        # The outline is eased from one height to the next.
        for step_ in range(2):
            eased = [list(ring) for ring in rings]
            for k in range(1, len(rings)-1):
                for i in range(count):
                    middle = (rings[k-1][i]+rings[k+1][i])*.5
                    eased[k][i] = V(rings[k][i].x*.6+middle.x*.4, rings[k][i].y*.6+middle.y*.4, rings[k][i].z)
            rings = eased
        # Over the shoulders: from the top ring in to the neck, the cloth laid
        # on the flesh beneath it, so the garment closes about the neck rather
        # than stopping short of the shoulders' tops.
        # (None: no yoke, the garment's top left open, as an apron's is.)
        yoke = self.yoke(rings[0], count, ease=yoke, collar=collar, rise=rise) if yoke is not None else []
        edges = [0.0]*len(yoke)+[max(0.0, 1.0-(z-hem)/fray) for z in levels]
        # (The body's rings, kept for a garment laid over this one: apron.)
        self.rings = rings
        rings = yoke+rings
        if DEBUG_RINGS and self.name in ('Tunic', 'Gown'):
            for k, ring in enumerate(rings[:12]):
                print('RING', self.name, k, ' '.join('(%.3f,%.3f,%.3f)' % tuple(ring[i]) for i in (0, 4, 8, 12, 16)))
        tree = body.tree(lambda i: not body.arm[i] or abs(body.points[i].x) <= body.shoulder)
        self.tube(rings, edges, tree, (V(0, body.joint('spine_02').y, 0), V(0, 0, 1)))
        return self

    def yoke(self, top, count, steps=5, ease=.014, collar=.03, rise=.035):
        """Rings from the neck out to the ring `top`, each point on the
        flesh beneath it (eased off it), the neck's first; the neckline
        `collar` out from the neck, and up it no higher than `rise` above
        the neck's root."""
        body = self.body
        neck = body.joint('neck_01')
        reach = body.joint('upperarm_l').x
        # A round neckline, open about the neck's root.
        around = [(p.x, p.y) for p in body.points if abs(p.z-(neck.z+.02)) < .012 and abs(p.x) < reach*.6]
        collar = outline(around, count, collar, (0, -1))
        if collar is None: return []
        # The flesh the yoke lies on: the shoulders' tops, the arms left out.
        under = [body.points[i] for i in range(len(body.points)) if neck.z-.15 < body.points[i].z < neck.z+.1 and (not body.arm[i] or abs(body.points[i].x) <= body.shoulder)]
        rings = []
        for k in range(steps, 0, -1):
            t = k/(steps+1)
            ring = []
            for i in range(count):
                x = top[i].x+(collar[i][0]-top[i].x)*t
                y = top[i].y+(collar[i][1]-top[i].y)*t
                near = [p.z for p in under if (p.x-x)**2+(p.y-y)**2 < .018**2]
                z = max(near)+ease if near else top[i].z
                ring.append(V(x, y, min(neck.z+rise, max(z, top[i].z))))
            rings.append(ring)
        # Smoothed, only ever lifted (so it stays off the flesh): a notch
        # between two higher points round a ring is filled, and no ring lies
        # lower than the one outside it; else the cloth folds over itself
        # about the neck and its inside shows, dark, like a tear.
        for step_ in range(4):
            for ring in rings:
                lifted = [max(ring[i].z, (ring[i-1].z+ring[(i+1) % count].z)*.5) for i in range(count)]
                for i in range(count): ring[i] = V(ring[i].x, ring[i].y, lifted[i])
            for k in range(len(rings)-2, -1, -1):
                for i in range(count):
                    if rings[k][i].z < rings[k+1][i].z: rings[k][i] = V(rings[k][i].x, rings[k][i].y, rings[k+1][i].z)
        return rings

    def sleeves(self, reach, ease, cuff, count=14, step=.03, fray=.07):
        """A sleeve down each arm as far as `reach` (metres from the
        shoulder), `ease` loose at the shoulder and `cuff` at its end."""
        body = self.body
        self.sleeve = reach
        for side, s in (('l', 1), ('r', -1)):
            shoulder = body.joint('upperarm_'+side)
            axis = (body.joint('hand_'+side)-shoulder).normalized()
            up = (V(0, 0, 1)-axis*axis.z).normalized()
            across = axis.cross(up)
            arm = [i for i in range(len(body.points)) if body.points[i].x*s > body.shoulder-.06 and (body.arm[i] or 'clavicle_'+side in body.weights[i])]
            rings, edges, lengths = [], [], []
            t = -.045
            while True:
                t = min(t, reach)
                chosen = [((body.points[i]-shoulder).dot(up), (body.points[i]-shoulder).dot(across)) for i in arm if abs((body.points[i]-shoulder).dot(axis)-max(t, .0)) < step*.8]
                looseness = ease+(cuff-ease)*max(0.0, t)/reach
                ring = outline(chosen, count, looseness, (1, 0))
                if ring is not None:
                    rings.append([shoulder+axis*t+up*p[0]+across*p[1] for p in ring])
                    edges.append(max(0.0, 1.0-(reach-t)/fray))
                    lengths.append(max(0.0, t)/max(reach, .01)*.5)
                if t >= reach: break
                t += step
            tree = body.tree(lambda i: body.points[i].x*s > body.shoulder-.08)
            self.tube(rings, edges, tree, (shoulder, axis), lengths)
        return self

    def scoop(self, half, front, back):
        """Cuts the neck out square: everything within `half` of the middle
        above `front` (on the chest) and `back`, leaving straps over the
        shoulders."""
        middle = self.body.joint('neck_01').y
        def gone(i):
            p = self.verts[i]
            return abs(p.x) < half and p.z > (front if p.y < middle else back)
        kept = [k for k, face in enumerate(self.faces) if not all(gone(i) for i in face)]
        self.faces = [self.faces[k] for k in kept]
        self.lines = [self.lines[k] for k in kept]
        # The cut's edge is drawn straight: what is left inside it moves out
        # to the nearer line.
        for i in set(i for face in self.faces for i in face):
            if not gone(i): continue
            p = self.verts[i]
            limit = front if p.y < middle else back
            if half-abs(p.x) < p.z-limit: self.verts[i] = V(math.copysign(half, p.x), p.y, p.z)
            else: self.verts[i] = V(p.x, p.y, limit)
        return self

    def over(self, under, top, hem, ease, reach, fray=.06, finer=4, pleats=21.0, pleat=.006, corner=.3, rounded=.07):
        """Laid over the garment `under` (built by trunk) from `top` down
        to `hem`: its rings there (each `finer` times as fine round), each
        point eased out from it by `ease(z)` (an apron over a skirt). It is
        gathered at the top: pleats round it (`pleats` to the radian about
        the body's middle, standing out `pleat` at the hem, less above), its
        hem rising and falling a little with them; and its hem is rounded
        up at the corners of the front `reach` radians either side (the
        outer `corner` of it, up `rounded` metres at the very edge)."""
        rings = [ring for ring in under.rings if hem-.001 <= ring[0].z <= top]
        middle = self.body.joint('spine_02').y
        out = []
        for ring in rings:
            n = len(ring)
            fine = []
            for i in range(n):
                for k in range(finer): fine.append(ring[i].lerp(ring[(i+1) % n], k/finer))
            n = len(fine)
            eased = []
            for i in range(n):
                before, after = fine[i-1], fine[(i+1) % n]
                normal = V(after.y-before.y, -(after.x-before.x), 0.0)
                normal = normal.normalized() if normal.length > 1e-9 else V(0, 0, 0)
                down = max(0.0, min(1.0, (top-fine[i].z)/max(top-hem, .01)))
                angle = math.atan2(fine[i].x, middle-fine[i].y)
                gather = pleat*down*(.5+.5*math.cos(angle*pleats))
                eased.append(fine[i]+normal*(ease(fine[i].z)+gather))
            out.append(eased)
        self.top, self.hem = out[0][0].z, out[-1][0].z
        edges = [max(0.0, 1.0-(ring[0].z-self.hem)/fray) for ring in out]
        # Each column shortened to where its hem now hangs.
        for i in range(len(out[0])):
            low = out[-1][i]
            a = abs(math.atan2(low.x, middle-low.y))/reach
            lift = .004*(.5+.5*math.cos(math.atan2(low.x, middle-low.y)*pleats))
            if a > 1.0-corner:
                t = min(1.0, (a-(1.0-corner))/corner)
                lift += rounded*(1.0-math.sqrt(max(0.0, 1.0-t*t)))
            span = self.top-self.hem
            for ring in out:
                p = ring[i]
                ring[i] = V(p.x, p.y, self.top-(self.top-p.z)*(span-lift)/span)
        body = self.body
        tree = body.tree(lambda i: not body.arm[i] or abs(body.points[i].x) <= body.shoulder)
        self.tube(out, edges, tree, (V(0, body.joint('spine_02').y, 0), V(0, 0, 1)))
        return self

    def front(self, reach, fray=.25):
        """Keeps only the garment's front: what lies within `reach` radians
        either side of straight ahead about the body's middle (an apron). Its
        cut sides fray as a hem does."""
        middle = self.body.joint('spine_02').y
        def off(i):
            p = self.verts[i]
            return abs(math.atan2(p.x, middle-p.y))
        kept = [k for k, face in enumerate(self.faces) if all(off(i) <= reach for i in face)]
        self.faces = [self.faces[k] for k in kept]
        self.lines = [self.lines[k] for k in kept]
        for i in set(i for face in self.faces for i in face):
            self.data[i] = (max(self.data[i][0], 1.0-(reach-off(i))/fray), self.data[i][1])
        return self

    def build(self, rig, material, hold=None):
        """The garment as a mesh on the rig; `hold(point)`, if given, the
        hold on the bones of each point of it, as it is to be held (an
        apron's)."""
        used = sorted(set(i for face in self.faces for i in face))
        new = {old: k for k, old in enumerate(used)}
        mesh = bpy.data.meshes.new(self.name)
        to_rig = rig.matrix_world.inverted()
        mesh.from_pydata([tuple(to_rig @ self.verts[i]) for i in used], [], [tuple(new[i] for i in face) for face in self.faces])
        mesh.update()
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bm.faces.ensure_lookup_table()
        bm.normal_update()
        uv = bm.loops.layers.uv.new('UVMap')
        data = bm.loops.layers.uv.new('Cloth')
        # Cloth faces outward from the line its tube runs along: a tube's faces
        # all wind one way, so each tube is turned as a whole.
        facing = {}
        for k, face in enumerate(bm.faces):
            origin, way, tube = self.lines[k]
            centre = rig.matrix_world @ face.calc_center_median()
            outward = centre-(origin+way*(centre-origin).dot(way))
            facing[tube] = facing.get(tube, 0.0)+(rig.matrix_world.to_3x3() @ face.normal).dot(outward.normalized())*face.calc_area()
        for k, face in enumerate(bm.faces):
            if facing[self.lines[k][2]] < 0: face.normal_flip()
            face.smooth = True
            for loop in face.loops:
                loop[uv].uv = self.uv[used[loop.vert.index]]
                loop[data].uv = self.data[used[loop.vert.index]]
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        holds = [self.weights[old] for old in used]
        if hold is not None: holds = [hold(self.verts[old]) for old in used]
        groups = {}
        for k, hold in enumerate(holds):
            weights = sorted(hold.items(), key=lambda item: -item[1])[:4]
            total = sum(w for name, w in weights) or 1.0
            for name, w in weights:
                if name not in groups: groups[name] = obj.vertex_groups.new(name=name)
                groups[name].add([k], w/total, 'REPLACE')
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        # The hold is eased over the cloth, so a skirt hangs between the legs
        # rather than splitting down the middle. (What is held as another
        # garment is has that one's, eased already.)
        if hold is None:
            bpy.ops.object.mode_set(mode='WEIGHT_PAINT')
            bpy.ops.object.vertex_group_smooth(group_select_mode='ALL', factor=.5, repeat=6)
            bpy.ops.object.mode_set(mode='OBJECT')
        bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=4)
        bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL', lock_active=False)
        obj.data.materials.append(material)
        obj.parent = rig
        modifier = obj.modifiers.new('rig', 'ARMATURE')
        modifier.object = rig
        WARDROBE.setdefault(rig.name, {})[self.name] = (round(self.top, 3), round(self.hem, 3), round(self.sleeve, 3))
        print('GARMENT', self.name, len(mesh.vertices), 'vertices; from %.2f down to %.2f, sleeves %.2f' % (self.top, self.hem, self.sleeve))
        return obj


def held_as(obj, at):
    """The hold on the bones of `obj` (a skinned mesh built already) at the
    world point `at`, which lies off a ring of it: as the two points of
    that ring either side of it are held, in proportion (so a finer mesh
    laid over it moves with it, between its points as at them)."""
    if obj.name not in HELD:
        bpy.context.view_layer.update()
        names = [g.name for g in obj.vertex_groups]
        tree = KDTree(len(obj.data.vertices))
        for v in obj.data.vertices: tree.insert(obj.matrix_world @ v.co, v.index)
        tree.balance()
        HELD[obj.name] = ([{names[g.group]: g.weight for g in v.groups if g.weight > 0.0} for v in obj.data.vertices], tree)
    weights, tree = HELD[obj.name]
    found = tree.find_n(at, 8)
    level = [f for f in found if abs(f[0].z-at.z) < .004][:2] or found[:1]
    total = {}
    shares = [1.0/(f[2]+1e-5) for f in level]
    for (point, index, distance), share in zip(level, shares):
        for name, weight in weights[index].items(): total[name] = total.get(name, 0.0)+weight*share/sum(shares)
    return total
HELD = {}
DEBUG_RINGS = False

def skinned(name, verts, faces, holds, material, rig):
    """A mesh on the rig from world points, faces and each point's hold on
    the bones; its faces turned all outward."""
    mesh = bpy.data.meshes.new(name)
    to_rig = rig.matrix_world.inverted()
    mesh.from_pydata([tuple(to_rig @ v) for v in verts], [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for face in bm.faces: face.smooth = True
    bm.to_mesh(mesh)
    bm.free()
    mesh.uv_layers.new(name='UVMap')
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    groups = {}
    for k, hold in enumerate(holds):
        weights = sorted(hold.items(), key=lambda item: -item[1])[:4]
        total = sum(w for n, w in weights) or 1.0
        for n, w in weights:
            if n not in groups: groups[n] = obj.vertex_groups.new(name=n)
            groups[n].add([k], w/total, 'REPLACE')
    obj.data.materials.append(material)
    obj.parent = rig
    obj.modifiers.new('rig', 'ARMATURE').object = rig
    return obj

def sandals(body, rig):
    """A pair of leather sandals: under each foot a flat sole a little
    larger than the foot's print, its edge rounded; over it straps cut to the
    foot's own shape (each where a plane cuts the flesh, eased off it, a strip
    of leather of some width and thickness): across the foot behind the
    toes, across the instep, round the ankle, and up the back of the heel
    to the ankle's."""
    verts, faces, holds = [], [], []
    for side in 'lr':
        ankle, ball = body.joint('foot_'+side), body.joint('ball_'+side)
        bones = ('foot_'+side, 'ball_'+side, 'calf_'+side)
        def near(p):
            return abs(p.x-ankle.x) < .1 and p.z < ankle.z+.1 and -.2 < p.y-ankle.y < .12
        chosen = [i for i in range(len(body.points)) if near(body.points[i]) and any(n.startswith(bones) for n in body.weights[i])]
        tree = KDTree(len(chosen))
        for i in chosen: tree.insert(body.points[i], i)
        tree.balance()
        low = min(body.points[i].z for i in chosen)
        bottom, top = low-.002, low+.021
        # The sole: its print, and its edge rounded top and bottom.
        footprint = [(body.points[i].x, body.points[i].y) for i in chosen if body.points[i].z < low+.035]
        layers = [(bottom, .0035), (bottom+.004, .0065), (top-.004, .0065), (top, .004)]
        count = 44
        base = len(verts)
        for z, ease in layers:
            for x, y in outline(footprint, count, ease, (0, -1)):
                verts.append(V(x, y, z))
                holds.append(body.skin(tree, V(x, y, top)))
        for k in range(len(layers)-1):
            for i in range(count):
                j = (i+1) % count
                faces.append((base+k*count+i, base+k*count+j, base+(k+1)*count+j, base+(k+1)*count+i))
        faces.append(tuple(base+(len(layers)-1)*count+i for i in range(count)))
        faces.append(tuple(base+i for i in reversed(range(count))))
        def strap(origin, normal, width, keep, inner=.0012, outer=.0048, count=56, below=None):
            # (`below`: the flesh cut only below this height, so the outline
            # of the foot is not drawn straight across from the heel or the
            # toes to the shin above, over the hollows at the ankle.)
            normal = normal.normalized()
            up = V(0, 0, 1)-normal*normal.z
            if up.length < .3: up = V(0, -1, 0)-normal*normal.y
            up.normalize()
            across = normal.cross(up)
            cut = body.section(origin, normal, near if below is None else lambda p: near(p) and p.z < below)
            flat = [((p-origin).dot(up), (p-origin).dot(across)) for p in cut]
            rings = {e: outline(flat, count, e, (1, 0)) for e in (inner, outer)}
            at = lambda q, off: origin+up*q[0]+across*q[1]+normal*off
            kept = [keep(at(rings[outer][i], 0.0)) for i in range(count)]
            closed = all(kept)
            if closed: run = list(range(count))
            else:
                # The longest run of kept points, round the ring.
                begin = kept.index(False)
                run, best = [], []
                for k in range(1, count+1):
                    i = (begin+k) % count
                    if kept[i]: run.append(i)
                    else:
                        if len(run) > len(best): best = run
                        run = []
                run = best
            if len(run) < 2: return
            profile = [(inner, -width*.5), (outer, -width*.5), (outer, width*.5), (inner, width*.5)]
            first = len(verts)
            for i in run:
                for e, off in profile:
                    verts.append(at(rings[e][i], off))
                    holds.append(body.skin(tree, verts[-1]))
            n = len(run)
            for k in range(n if closed else n-1):
                a, b = first+k*4, first+((k+1) % n)*4
                for r in range(4):
                    q = (r+1) % 4
                    faces.append((a+r, b+r, b+q, a+q))
            if not closed:
                faces.append((first+3, first+2, first+1, first))
                last = first+(n-1)*4
                faces.append((last, last+1, last+2, last+3))
        over = lambda p: p.z > top-.004
        strap(ball+V(0, .02, 0), V(0, 1, -.3), .015, over)
        strap(ball.lerp(ankle, .55)+V(0, 0, 0), V(0, 1, .6), .016, over)
        wrap = ankle.z+.03
        strap(V(ankle.x, ankle.y, wrap), V(0, 0, 1), .017, lambda p: True)
        strap(V(ankle.x, ankle.y, 0), V(1, 0, 0), .014, lambda p: p.y > ankle.y+.015 and top-.004 < p.z < wrap-.004, below=wrap+.004)
    obj = skinned('Sandals', verts, faces, holds, named('Sandals'), rig)
    print('SANDALS', len(verts), 'vertices')
    return obj

# The head the pack's Hair_Long was made for (the woman's): its flesh's
# bounds, as (least, most) corners. Fitted to another head, the hair is
# moved and sized from these to that head's.
HAIR_LONG_HEAD = (V(-.0889, -.1119, 1.5381), V(.0889, .1129, 1.7666))

def head_box(body):
    head = [body.points[i] for i in range(len(body.points)) if body.weights[i].get('Head', 0.0) > .5]
    return (V(min(p.x for p in head), min(p.y for p in head), min(p.z for p in head)), V(max(p.x for p in head), max(p.y for p in head), max(p.z for p in head)))

def grown(body, rig, source, name, fit, start, end, taper, mess, clear, seed, follow=1.0, straggle=.02):
    """A copy of the hair `source` grown out long and let go unkempt (the
    starving's: scripts/townsperson.gd starve). Fitted to this head (`fit`
    the head it was made for, or None); what hangs below the height `start`
    drawn down to `end`, narrowing by `taper` toward its ends; combed out
    from the flesh to lie `clear` off it (and off the clothes there), and
    tangled: moved about by noise, more toward the ends (`mess`, metres),
    and frizzed out a little all over. What hangs below the neck is held by
    the neck and the back as the braid is (`follow` of it: a beard hangs
    from the chin), so it moves with the shoulders. Each lock of it (each
    piece of the mesh on its own) straggles its own way, more toward its
    end (`straggle`, metres), so that the locks part and cross."""
    from mathutils import noise
    import random
    obj = source.copy()
    obj.data = source.data.copy()
    obj.name = name
    obj.data.name = name
    bpy.context.scene.collection.objects.link(obj)
    world = obj.matrix_world.copy()
    back = world.inverted()
    points = [world @ v.co for v in obj.data.vertices]
    if fit is not None:
        made, own = fit, head_box(body)
        middle_made, middle_own = (made[0]+made[1])*.5, (own[0]+own[1])*.5
        size = V(*((own[1][k]-own[0][k])/(made[1][k]-made[0][k]) for k in range(3)))
        points = [middle_own+V(*((p-middle_made)[k]*size[k] for k in range(3))) for p in points]
    low = min(p.z for p in points)
    stretch = (start-end)/max(start-low, .01)
    # The locks: the mesh's pieces, and a way for each to straggle.
    lock = list(range(len(points)))
    def root(i):
        while lock[i] != i:
            lock[i] = lock[lock[i]]
            i = lock[i]
        return i
    for polygon in obj.data.polygons:
        first = root(polygon.vertices[0])
        for v in polygon.vertices[1:]: lock[root(v)] = first
    chance = random.Random(seed)
    ways = {}
    for i in range(len(points)):
        r = root(i)
        if r not in ways: ways[r] = V(chance.uniform(-1, 1), chance.uniform(-.6, 1), chance.uniform(-.3, .3))
    neck = body.joint('neck_01')
    middle = V(0, body.joint('Head').y, 0)
    flesh = [i for i in range(len(body.points)) if not body.arm[i] and body.points[i].z > neck.z-.35]
    tree = KDTree(len(flesh))
    for i in flesh: tree.insert(body.points[i], i)
    tree.balance()
    out = []
    for k, p in enumerate(points):
        q = p.copy()
        t = 0.0
        if p.z < start:
            q.z = start-(start-p.z)*stretch
            t = (start-q.z)/max(start-end, .01)
            # (Narrowing toward the ends about the head's middle.)
            q.x *= 1.0-taper*t**1.5
            q += ways[root(k)]*straggle*t*t
        # Tangles: slow noise to its locks, quick to its strands.
        q += noise.noise_vector(q*14.0+V(seed, 0, 0))*(.0015+mess*t)
        q += noise.noise_vector(q*55.0+V(0, seed, 0))*(.0025+mess*.3*t)
        if q.z >= start:
            # Frizzed: lifted off the scalp a little, here and there.
            lift = (q-middle-V(0, 0, start-.02)).normalized() if q.z > start else V(0, 0, 0)
            q += lift*abs(noise.noise(q*30.0+V(0, 0, seed)))*.004
        out.append(q)
    # Off the flesh beneath it: how far each point must go, eased along the
    # locks (so a lock lying on a shoulder bends over it rather than
    # kinking), and then as far as it still must.
    def wanted(q):
        if q.z >= start: return V(0, 0, 0)
        near = tree.find_n(q, 6)
        if not near: return V(0, 0, 0)
        at = sum((body.points[i] for _, i, _ in near), V(0, 0, 0))/len(near)
        normal = sum((body.normals[i] for _, i, _ in near), V(0, 0, 0)).normalized()
        want = clear*min(1.0, (start-q.z)/.04)
        depth = (q-at).dot(normal)
        return normal*(want-depth) if depth < want else V(0, 0, 0)
    pushes = [wanted(q) for q in out]
    beside = [set() for _ in out]
    for polygon in obj.data.polygons:
        for a in polygon.vertices:
            for b in polygon.vertices:
                if a != b: beside[a].add(b)
    for step_ in range(10):
        eased = []
        for i, push in enumerate(pushes):
            if not beside[i]:
                eased.append(push)
                continue
            mean = sum((pushes[j] for j in beside[i]), V(0, 0, 0))/len(beside[i])
            eased.append(push*.4+mean*.6 if mean.length > push.length*.5 else push)
        pushes = eased
    out = [q+push for q, push in zip(out, pushes)]
    out = [q+wanted(q) for q in out]
    for v, q in zip(obj.data.vertices, out): v.co = back @ q
    # Held by the head above the neck's root, by the neck and the back below.
    for group in list(obj.vertex_groups): obj.vertex_groups.remove(group)
    groups = {n: obj.vertex_groups.new(name=n) for n in ('Head', 'neck_01', 'spine_03')}
    for v, q in zip(obj.data.vertices, out):
        below = max(0.0, min(1.0, (neck.z+.04-q.z)/.1))
        down = max(0.0, min(1.0, (neck.z-.06-q.z)/.12))
        below *= follow
        hold = {'Head': 1.0-below, 'neck_01': below*(1.0-down), 'spine_03': below*down}
        for n, w in hold.items():
            if w > 0.0: groups[n].add([v.index], w, 'REPLACE')
    return obj

def named(name):
    return bpy.data.materials.get(name) or bpy.data.materials.new(name)

def braid(body, rig):
    """A plait down the back from the nape: lobes laid over one another,
    left and right in turn, a tie and a tuft at its end."""
    head = body.joint('Head')
    neck = body.joint('neck_01')
    low = body.joint('spine_02').z+.02
    verts, faces, weights = [], [], []
    def back_at(z):
        # The back of the head, the neck and the spine at this height.
        return max((p.y for p in body.points if abs(p.x) < .035 and abs(p.z-z) < .02), default=neck.y+.06)
    def lobe(centre, radii, lean, hold):
        base = len(verts)
        around, rings = 8, 5
        turn = Matrix.Rotation(lean, 3, 'Y')
        verts.append(centre+turn @ V(0, 0, radii.z))
        for r in range(1, rings):
            polar = math.pi*r/rings
            for a in range(around): verts.append(centre+turn @ V(math.sin(polar)*math.cos(a*math.tau/around)*radii.x, math.sin(polar)*math.sin(a*math.tau/around)*radii.y, math.cos(polar)*radii.z))
        verts.append(centre+turn @ V(0, 0, -radii.z))
        for a in range(around):
            b = (a+1) % around
            faces.append((base, base+1+a, base+1+b))
            for r in range(rings-2): faces.append((base+1+r*around+a, base+1+(r+1)*around+a, base+1+(r+1)*around+b, base+1+r*around+b))
            last = base+1+(rings-2)*around
            faces.append((last+b, last+a, base+1+(rings-1)*around))
        weights.extend([hold]*(2+(rings-1)*around))
    top = head.z+.075
    z = top
    k = 0
    while z > low:
        t = (top-z)/(top-low)
        thick = 1.0-.35*t
        # (Clear of the head's hair above, and of the dress below.)
        y = back_at(z)+(.03 if z > neck.z else .05)*thick
        side = 1 if k % 2 == 0 else -1
        if z > neck.z+.03: hold = {'Head': 1.0}
        elif z > neck.z-.06: hold = {'Head': .4, 'neck_01': .6}
        else: hold = {'spine_03': 1.0} if z > body.joint('spine_03').z else {'spine_03': .5, 'spine_02': .5}
        lobe(V(side*.012*thick, y, z), V(.024, .02, .034)*thick, side*.5, hold)
        z -= .034*thick
        k += 1
    y = back_at(z)+.035
    lobe(V(0, y, z+.008), V(.017, .017, .012), 0.0, {'spine_02': 1.0})
    lobe(V(0, y+.004, z-.035), V(.019, .016, .04), 0.0, {'spine_02': 1.0})
    mesh = bpy.data.meshes.new('Braid')
    to_rig = rig.matrix_world.inverted()
    mesh.from_pydata([tuple(to_rig @ v) for v in verts], [], faces)
    mesh.update()
    for p in mesh.polygons: p.use_smooth = True
    mesh.uv_layers.new(name='UVMap')
    obj = bpy.data.objects.new('Braid', mesh)
    bpy.context.scene.collection.objects.link(obj)
    groups = {}
    for i, hold in enumerate(weights):
        for name, w in hold.items():
            if name not in groups: groups[name] = obj.vertex_groups.new(name=name)
            groups[name].add([i], w, 'REPLACE')
    obj.data.materials.append(named('Braid'))
    obj.parent = rig
    obj.modifiers.new('rig', 'ARMATURE').object = rig
    return obj

def belt(body, rig, z, ease):
    ring_top = outline([(p.x, p.y) for p in body.points if abs(p.z-(z+.02)) < .02 and abs(p.x) <= body.shoulder], 24, ease, (0, -1))
    ring_low = outline([(p.x, p.y) for p in body.points if abs(p.z-(z-.02)) < .02 and abs(p.x) <= body.shoulder], 24, ease, (0, -1))
    garment = Garment('Belt', body)
    tree = body.tree(lambda i: not body.arm[i])
    garment.tube([[V(p[0], p[1], z+.02) for p in ring_top], [V(p[0], p[1], z-.02) for p in ring_low]], [0.0, 0.0], tree, (V(0, body.joint('spine_02').y, 0), V(0, 0, 1)))
    garment.top, garment.hem = z+.02, z-.02
    return garment.build(rig, named('Belt'))

def retarget(rig, sources, actions):
    """Bakes each clip onto this body's skeleton: every bone turns as the
    library's does, on this body's own limb lengths; the hips move as the
    library's do, in proportion to its legs."""
    scene = bpy.context.scene
    rig.animation_data_create()
    bones = sorted(rig.data.bones, key=lambda b: len(b.parent_recursive))
    rest = {b.name: b.matrix_local.copy() for b in bones}
    for pose in rig.pose.bones: pose.rotation_mode = 'QUATERNION'
    for name, library in CLIPS.items():
        source = next(s for s in sources if library in actions[s.name])
        for other in sources: other.animation_data.action = actions[other.name][library] if other == source else None
        legs = rig.data.bones['pelvis'].head_local.z/source.data.bones['pelvis'].head_local.z
        end = actions[source.name][library].frame_range[1]
        action = bpy.data.actions.new(name)
        rig.animation_data.action = action
        for frame in range(math.ceil(end)+1):
            scene.frame_set(frame)
            bpy.context.view_layer.update()
            posed = {}
            for bone in bones:
                parent = bone.parent.name if bone.parent else None
                held = posed[parent] @ rest[parent].inverted() if parent else Matrix.Identity(4)
                sb = source.data.bones.get(bone.name)
                if sb is None: posed[bone.name] = held @ rest[bone.name]
                else:
                    sp = source.pose.bones[bone.name]
                    rotation = sp.matrix.to_quaternion() @ sb.matrix_local.to_quaternion().inverted() @ bone.matrix_local.to_quaternion()
                    head = held @ bone.head_local
                    if bone.name in ('root', 'pelvis'): head += (held.to_3x3() @ rest[bone.name].to_3x3()) @ (sp.location*legs)
                    posed[bone.name] = Matrix.Translation(head) @ rotation.to_matrix().to_4x4()
                basis = (held @ rest[bone.name]).inverted() @ posed[bone.name]
                pose = rig.pose.bones[bone.name]
                pose.rotation_quaternion = basis.to_quaternion()
                pose.keyframe_insert('rotation_quaternion', frame=frame)
                if bone.name in ('root', 'pelvis'):
                    pose.location = basis.to_translation()
                    pose.keyframe_insert('location', frame=frame)
        track = rig.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 0, action)
        strip.action_frame_end = end
        track.mute = True
        rig.animation_data.action = None
    for track in rig.animation_data.nla_tracks: track.mute = False
    for pose in rig.pose.bones:
        pose.rotation_quaternion = (1, 0, 0, 0)
        pose.location = (0, 0, 0)

def make(who):
    woman = who == 'woman'
    HELD.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sources, actions = [], {}
    for library in LIBRARIES:
        before = set(bpy.data.objects)
        known = set(bpy.data.actions)
        bpy.ops.import_scene.gltf(filepath=str(library))
        source = next(o for o in set(bpy.data.objects)-before if o.type == 'ARMATURE')
        for track in list(source.animation_data.nla_tracks): source.animation_data.nla_tracks.remove(track)
        sources.append(source)
        actions[source.name] = {a.name: a for a in set(bpy.data.actions)-known}
    library_objects = set(bpy.data.objects)
    library_names = [o.name for o in library_objects]
    bpy.ops.import_scene.gltf(filepath=str(BASE/'Base Characters/Godot - UE'/('Superhero_Female_FullBody.gltf' if woman else 'Superhero_Male_FullBody.gltf')))
    rig = next(o for o in set(bpy.data.objects)-library_objects if o.type == 'ARMATURE')
    rig.name = 'TownswomanRig' if woman else 'TownsmanRig'
    flesh = next(o for o in bpy.data.objects if o.type == 'MESH' and o.parent == rig and o.name.lower().startswith('superhero'))
    flesh.name = 'Body'
    for obj in list(bpy.data.objects):
        if obj.type == 'MESH' and obj.parent is None: bpy.data.objects.remove(obj, do_unlink=True)
    body = Body(flesh, rig)
    # Hair from the pack: each style fits one of the two heads.
    styles = ['Hair_Long', 'Hair_Buns', 'Hair_BuzzedFemale'] if woman else ['Hair_SimpleParted', 'Hair_Buzzed', 'Hair_Beard', 'Hair_Long']
    for style in styles:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(HAIR/(style+'.gltf')))
        for obj in set(bpy.data.objects)-before:
            if obj.type == 'MESH' and obj.vertex_groups:
                world = obj.matrix_world.copy()
                obj.parent = rig
                obj.matrix_world = world
                obj.name = style
                for modifier in obj.modifiers:
                    if modifier.type == 'ARMATURE': modifier.object = rig
            else: bpy.data.objects.remove(obj, do_unlink=True)
    # One material of each kind, by name: the game supplies them all.
    for obj in bpy.data.objects:
        if obj.type != 'MESH' or obj.parent != rig: continue
        for slot in obj.material_slots:
            name = slot.material.name
            slot.material = named('Skin' if 'Superhero' in name else 'Eyes' if 'Eyes' in name else 'Hair2' if 'Hair_2' in name else 'Hair1')
    # The starving's hair, grown out long and matted, and the men's beards
    # with it (the woman's long hair made for her head, fitted to his).
    neck_z = body.joint('neck_01').z
    crown = head_box(body)
    long_hair = bpy.data.objects['Hair_Long']
    grown(body, rig, long_hair, 'Hair_Matted', None if woman else HAIR_LONG_HEAD, crown[0].z+.07, neck_z-.2, .15, .02, .03, 3.7, straggle=.035)
    if not woman:
        bpy.data.objects.remove(long_hair, do_unlink=True)
        beard = bpy.data.objects['Hair_Beard']
        chin = min((beard.matrix_world @ v.co).z for v in beard.data.vertices)
        grown(body, rig, beard, 'Hair_BeardLong', None, chin+.05, neck_z-.14, .4, .012, .03, 8.1, follow=.4, straggle=.02)
    # The wardrobe. Heights are taken from this body's own joints.
    neck, arm, hips, knee, ankle = body.joint('neck_01').z, body.joint('upperarm_l').z, body.joint('pelvis').z, body.joint('calf_l').z, body.joint('foot_l').z
    waist = body.joint('spine_01').z+.03
    upper = (body.joint('lowerarm_l')-body.joint('upperarm_l')).length
    whole = (body.joint('hand_l')-body.joint('upperarm_l')).length
    def cut(loose, flare, hem, cinch=.016):
        """Looseness by height: close at the shoulders, bloused over a drawn-in
        waist, fuller over the hips and flaring to the hem."""
        def ease(z):
            if z > arm+.03: return .012
            if z > waist+.07: return loose
            if z > waist-.07: return cinch+(loose-cinch)*min(1.0, abs(z-waist)/.07)
            return loose+.008+flare*max(0.0, (hips-.1-z)/max(.01, hips-.1-hem))
        return ease
    cloth = named('Cloth')
    top = neck+.012
    # An apron: the front of a skirt from the waist (under the belt) to
    # above the knee, standing off the garment it is worn over and held as
    # that garment is (each point as the point beneath it): so it lies on the
    # lap of one sitting. Standing and walking it hangs from the hips instead,
    # pushed out by a striding leg (scripts/townsperson.gd apron_legs).
    def apron(under, under_mesh):
        return Garment('Apron', body).over(under, waist+.01, knee+.09, lambda z: .006+.016*min(1.0, max(0.0, waist+.01-z)/.1), .95).front(.95).build(rig, cloth, hold=lambda point: held_as(under_mesh, point))
    if woman:
        # (The gown and dress are worn over the blouse: their yokes lie well
        # off the shoulders, its close on them, its sleeves close at the
        # shoulder, so it never shows through them; its collar stands a
        # little above theirs, about the neck. The dress's straps come down
        # over the shoulders' points, where the blouse's sleeves come out.)
        gown = Garment('Gown', body).trunk(top, ankle+.05, cut(.02, .075, ankle+.05), yoke=.022).sleeves(upper*.5, .024, .032)
        gown_mesh = gown.build(rig, cloth)
        Garment('Shift', body).trunk(top, knee-.2, cut(.022, .06, knee-.2)).build(rig, cloth)
        bodice = arm-.085
        Garment('Blouse', body).trunk(top-.004, bodice-.1, lambda z: .004, fray=.01, yoke=.006, collar=.008, rise=.045).sleeves(whole-.03, .008, .03).build(rig, named('Linen'))
        over = cut(.026, .08, ankle+.07, .022)
        Garment('Dress', body).trunk(top, ankle+.07, lambda z: max(.024, over(z)), yoke=.022).sleeves(.035, .026, .028, fray=.02).scoop(body.joint('upperarm_l').x*.52, bodice, bodice+.03).build(rig, cloth)
        apron(gown, gown_mesh)
        braid(body, rig)
    else:
        tunic = Garment('Tunic', body).trunk(top, knee-.04, cut(.022, .045, knee-.04)).sleeves(upper*.55, .022, .035)
        tunic_mesh = tunic.build(rig, cloth)
        Garment('Sack', body).trunk(top, knee+.14, cut(.024, .04, knee+.14)).build(rig, cloth)
        Garment('Robe', body).trunk(top, knee-.24, cut(.024, .06, knee-.24)).sleeves(upper*.95, .024, .04).build(rig, cloth)
        apron(tunic, tunic_mesh)
    belt(body, rig, waist, .03)
    sandals(body, rig)
    # The pack's body comes in pieces along its texture's seams (each point
    # there twice, with its own normal): drawn in by hunger along those
    # normals (assets/shaders/gaunt.gdshaderinc) the pieces part, and the
    # seams open as cracks at the ankles and down the shins. So its points
    # are joined, and its normals made smooth across the seams.
    mesh = bmesh.new()
    mesh.from_mesh(flesh.data)
    bmesh.ops.remove_doubles(mesh, verts=mesh.verts, dist=1e-5)
    for face in mesh.faces: face.smooth = True
    for edge in mesh.edges: edge.smooth = True
    mesh.to_mesh(flesh.data)
    mesh.free()
    if flesh.data.has_custom_normals:
        bpy.ops.object.select_all(action='DESELECT')
        flesh.select_set(True)
        bpy.context.view_layer.objects.active = flesh
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    # The flesh is cut down, then marked with what a garment needs to hide
    # it: each point's height, and how far along its arm it is.
    bpy.ops.object.select_all(action='DESELECT')
    flesh.select_set(True)
    bpy.context.view_layer.objects.active = flesh
    cutter = flesh.modifiers.new('cut', 'DECIMATE')
    cutter.ratio = min(1.0, BODY_TRIANGLES/sum(len(p.vertices)-2 for p in flesh.data.polygons))
    bpy.ops.object.modifier_apply(modifier='cut')
    # (The body comes with spare UV sets; the marks must be its second.)
    while len(flesh.data.uv_layers) > 1: flesh.data.uv_layers.remove(flesh.data.uv_layers[-1])
    cover = flesh.data.uv_layers.new(name='Cover')
    names = [g.name for g in flesh.vertex_groups]
    marks = []
    for v in flesh.data.vertices:
        p = flesh.matrix_world @ v.co
        held = {names[g.group]: g.weight for g in v.groups}
        on_arm = abs(p.x) > body.shoulder and held and max(held, key=held.get).startswith(ARM)
        marks.append((p.z, abs(p.x)-body.joint('upperarm_l').x if on_arm else 0.0))
    for loop in flesh.data.loops: cover.data[loop.index].uv = marks[loop.vertex_index]
    retarget(rig, sources, actions)
    for name in library_names:
        if name in bpy.data.objects: bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
    for action in list(bpy.data.actions):
        if action.name not in CLIPS: bpy.data.actions.remove(action)
    bpy.context.scene.frame_set(0)
    bpy.ops.object.select_all(action='SELECT')
    path = OUT/('townswoman.glb' if woman else 'townsman.glb')
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS',
        export_nla_strips=True, export_force_sampling=True, export_yup=True, export_image_format='NONE')
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    print('TOWNSFOLK_READY', path.name, {o.name: sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes})

def textures():
    """The pack's skin and hair, and Poly Haven's photographed linen and
    hessian (CC0), at the size the game draws them."""
    skins = BASE/'Base Characters/Textures'
    cloth = ROOT/'source_art/polyhaven/textures'
    wanted = {'skin_man_light.jpg': skins/'T_Superhero_Male_Ligh.png', 'skin_man_dark.jpg': skins/'T_Superhero_Male_Dark.png',
        'skin_woman_light.jpg': skins/'T_Superhero_Female_Light_BaseColor.png', 'skin_woman_dark.jpg': skins/'T_Superhero_Female_Dark_BaseColor.png',
        'hair_2.jpg': skins/'T_Hair_2_BaseColor.png', 'hair_1.jpg': skins/'T_Hair_1_BaseColor.png',
        'cloth_linen.jpg': cloth/'rough_linen_Diffuse.jpg', 'cloth_hessian.jpg': cloth/'hessian_230_Diffuse.jpg'}
    bpy.context.scene.render.image_settings.file_format = 'JPEG'
    bpy.context.scene.render.image_settings.quality = 90
    for name, source in wanted.items():
        image = bpy.data.images.load(str(source))
        size = 512 if name.startswith(('hair', 'cloth')) else 1024
        image.scale(size, size)
        image.save_render(str(ROOT/'assets/textures'/name))

if __name__ == '__main__':
    for who in ('man', 'woman'): make(who)
    textures()
    lines = ['extends RefCounted', '## Written by tools/make_townsfolk.py: what each garment covers, as', '## [top, hem, sleeve] in metres on the body at rest.', 'const COVER = {']
    for rig, garments in WARDROBE.items():
        lines.append('\t"%s": {%s},' % ('woman' if 'woman' in rig else 'man', ', '.join('"%s": [%s, %s, %s]' % ((name,)+cover) for name, cover in garments.items())))
    lines.append('}')
    WARDROBE_SCRIPT.write_text('\n'.join(lines)+'\n')
