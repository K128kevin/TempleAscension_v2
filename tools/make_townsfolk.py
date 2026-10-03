"""Builds the townspeople: assets/models/character/townsman.glb and townswoman.glb.

Each is one of the base character pack's two bodies (the pack's male and
female "superhero", which come unclothed) on its own skeleton, with the pack's
hairstyles, a wardrobe, and the clips a townsperson needs from the two
animation libraries, retargeted as tools/import_character.py retargets the
hero's: standing, talking, walking, jogging, sitting down and getting up,
sitting, sitting and talking, drinking, reaching, carrying, dancing.

The packs have no clothes, so the wardrobe is fitted here from the body's own
shape. A garment is a tube lofted down the body: at each height the outline
of the body there (its convex hull, arms left out) is taken, eased outward by
the cloth's looseness, and joined to the next, and from the top it is laid
over the shoulders in to the neck; sleeves are lofted along the
arms the same way. Every garment is skinned from the flesh nearest it, so it
moves with the wearer. The woman's dress is such a tube with its neck cut
square and wide, leaving straps over the shoulders, over a long-sleeved blouse;
her braid is laid down her back from the nape, lobe over lobe.

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
    'Drink': 'Consume', 'Carry': 'Walk_Carry_Loop', 'Arms': 'Idle_FoldArms_Loop'}
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

    def trunk(self, top, hem, ease, count=32, step=.025, fray=.14):
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
        yoke = self.yoke(rings[0], count)
        edges = [0.0]*len(yoke)+[max(0.0, 1.0-(z-hem)/fray) for z in levels]
        rings = yoke+rings
        tree = body.tree(lambda i: not body.arm[i] or abs(body.points[i].x) <= body.shoulder)
        self.tube(rings, edges, tree, (V(0, body.joint('spine_02').y, 0), V(0, 0, 1)))
        return self

    def yoke(self, top, count, steps=5, ease=.014):
        """Rings from the neck out to the ring `top`, each point on the
        flesh beneath it (eased off it), the neck's first."""
        body = self.body
        neck = body.joint('neck_01')
        reach = body.joint('upperarm_l').x
        # A round neckline, open about the neck's root.
        around = [(p.x, p.y) for p in body.points if abs(p.z-(neck.z+.02)) < .012 and abs(p.x) < reach*.6]
        collar = outline(around, count, .03, (0, -1))
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
                ring.append(V(x, y, min(neck.z+.035, max(z, top[i].z))))
            rings.append(ring)
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

    def build(self, rig, material):
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
        groups = {}
        for k, old in enumerate(used):
            weights = sorted(self.weights[old].items(), key=lambda item: -item[1])[:4]
            total = sum(w for name, w in weights) or 1.0
            for name, w in weights:
                if name not in groups: groups[name] = obj.vertex_groups.new(name=name)
                groups[name].add([k], w/total, 'REPLACE')
        # The hold is eased over the cloth, so a skirt hangs between the legs
        # rather than splitting down the middle.
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
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
    styles = ['Hair_Long', 'Hair_Buns', 'Hair_BuzzedFemale'] if woman else ['Hair_SimpleParted', 'Hair_Buzzed', 'Hair_Beard']
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
    if woman:
        Garment('Gown', body).trunk(top, ankle+.05, cut(.02, .075, ankle+.05)).sleeves(upper*.5, .02, .03).build(rig, cloth)
        Garment('Shift', body).trunk(top, knee-.2, cut(.022, .06, knee-.2)).build(rig, cloth)
        bodice = arm-.085
        Garment('Blouse', body).trunk(top+.01, bodice-.1, lambda z: .008, fray=.01).sleeves(whole-.03, .022, .03).build(rig, named('Linen'))
        over = cut(.026, .08, ankle+.07, .022)
        Garment('Dress', body).trunk(top, ankle+.07, lambda z: max(.024, over(z))).scoop(body.joint('upperarm_l').x*.52, bodice, bodice+.03).build(rig, cloth)
        braid(body, rig)
    else:
        Garment('Tunic', body).trunk(top, knee-.04, cut(.022, .045, knee-.04)).sleeves(upper*.55, .022, .035).build(rig, cloth)
        Garment('Sack', body).trunk(top, knee+.14, cut(.024, .04, knee+.14)).build(rig, cloth)
        Garment('Robe', body).trunk(top, knee-.24, cut(.024, .06, knee-.24)).sleeves(upper*.95, .024, .04).build(rig, cloth)
    belt(body, rig, waist, .03)
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
