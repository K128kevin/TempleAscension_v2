"""Builds the lion: the temple's Lion Guardian, and the marble lions of the town.

Two models make it. The body is "Lion" by Poly by Google (CC-BY 3.0, via Poly
Pizza), a low-poly standing lion: sized here to a real lion (1.15 m at the
shoulder, 2.1 m from nose to rump), smoothed, its legs filled out, its mane
carved into locks and its paws into toes. The face is Poly Haven's sculpted
"Lion Head" (CC0), a mask of a lion's face and the mane round it, set in
place of the body's own plain head, with its normal map for the finest work
(the game's statue shader reads it through the mask's UVs, which the vertex
colours mark: blue 0 on the mask, white on the body).

The lion comes with no skeleton: one is built here, the mesh skinned to it,
and it is animated: Idle, Run (a gallop), Attack (rearing up, a swipe of the
right forepaw), and the flinches Hit, HitHead and HitStagger. Every pose is
worked out here, legs by two-bone IK, and keyed frame by frame.

It exports assets/models/character/lion.glb, facing +Z in the game like the
other figures, without a material: the game carves it in statue stone or
marble (scripts/visual.gd).

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_lion.py
"""
import math
from pathlib import Path
import bpy, bmesh
from mathutils import Vector, Matrix, Quaternion, noise
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'source_art/poly_pizza/lion_3XAJojWxSWz.glb'
FACE = ROOT/'source_art/polyhaven/lion_head/lion_head.gltf'
OUT = ROOT/'assets/models/character/lion.glb'
# Metres per unit of the source model, and where along its length the game's
# origin (the middle of the body) lies.
SCALE = .21
MIDDLE = .4
TRIANGLES = 8000
FACE_TRIANGLES = 8000
# The mask is a 32 cm ornament: this many times larger, its mane spans the
# body's; and where its nose goes.
FACE_SCALE = 2.3
NOSE = Vector((0, -1.25, .93))
FPS = 30

def J(x, y, z):
    """A point of the source model, in the armature's metres (it faces -Y)."""
    return Vector((x*SCALE, (y-MIDDLE)*SCALE, z*SCALE))

# name: (head, tail, parent, radius it holds the skin within)
BONES = {
    'root': (Vector((0, 0, 0)), Vector((0, 0, .2)), None, 0),
    'hips': (J(0, 3.9, 4.4), J(0, 2.4, 4.4), 'root', .30),
    'spine': (J(0, 2.4, 4.4), J(0, .4, 4.35), 'hips', .30),
    'chest': (J(0, .4, 4.35), J(0, -2.3, 4.5), 'spine', .32),
    'neck': (J(0, -2.3, 4.5), J(0, -3.7, 5.0), 'chest', .30),
    'head': (J(0, -3.7, 5.0), J(0, -5.4, 4.5), 'neck', .24),
    'tail1': (J(0, 4.6, 4.9), J(0, 5.7, 4.9), 'hips', .05),
    'tail2': (J(0, 5.7, 4.9), J(0, 6.8, 4.9), 'tail1', .05),
    'tail3': (J(0, 6.8, 4.9), J(0, 7.9, 4.9), 'tail2', .05),
    'tail4': (J(0, 7.9, 4.9), J(0, 8.94, 4.85), 'tail3', .05)}
for side, s in (('l', 1), ('r', -1)):
    BONES['upperarm_'+side] = (J(.75*s, -2.5, 4.2), J(.6*s, -1.65, 2.9), 'chest', .15)
    BONES['forearm_'+side] = (J(.6*s, -1.65, 2.9), J(.55*s, -1.95, 1.0), 'upperarm_'+side, .10)
    BONES['forepaw_'+side] = (J(.55*s, -1.95, 1.0), J(.55*s, -2.5, .08), 'forearm_'+side, .10)
    BONES['thigh_'+side] = (J(.65*s, 3.7, 4.3), J(.75*s, 3.05, 2.9), 'hips', .17)
    BONES['shin_'+side] = (J(.75*s, 3.05, 2.9), J(.78*s, 4.1, 1.7), 'thigh_'+side, .11)
    BONES['hindpaw_'+side] = (J(.78*s, 4.1, 1.7), J(.78*s, 3.45, .08), 'shin_'+side, .10)
ORDER = list(BONES)

# ---- The mesh ----

def build_body():
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    lion = [o for o in bpy.data.objects if o.type == 'MESH'][0]
    for o in list(bpy.data.objects):
        if o != lion: bpy.data.objects.remove(o, do_unlink=True)
    lion.name = 'Lion'
    lion.parent = None
    mesh = lion.data
    # Its painted mane is dark brown: that is how the mane's faces are known.
    image = bpy.data.images[0]
    width, height = image.size
    pixels = list(image.pixels)
    def dark(uv):
        px = min(width-1, max(0, int(uv.x % 1.0*width)))
        py = min(height-1, max(0, int(uv.y % 1.0*height)))
        i = (py*width+px)*4
        return (pixels[i]+pixels[i+1]+pixels[i+2])/3.0 < .3
    uvs = mesh.uv_layers[0].data
    votes = {}
    for loop in mesh.loops:
        v = votes.setdefault(loop.vertex_index, [0, 0])
        v[0] += 1
        v[1] += 1 if dark(uvs[loop.index].uv) else 0
    transform = lion.matrix_world.copy()
    lion.matrix_world = Matrix.Identity(4)
    # Its own face comes off: the mask takes its place.
    gone = [v.index for v in mesh.vertices if (transform @ v.co).y < -4.5]
    for v in mesh.vertices: v.co = J(*(transform @ v.co))
    mane = lion.vertex_groups.new(name='mane')
    for index, (count, hits) in votes.items():
        p = mesh.vertices[index].co
        # (The tail's tuft is dark too; it is no part of the mane.)
        if hits*2 >= count and p.y < .2: mane.add([index], 1.0, 'REPLACE')
    bpy.context.view_layer.objects.active = lion
    lion.select_set(True)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in gone], context='VERTS')
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    while mesh.uv_layers: mesh.uv_layers.remove(mesh.uv_layers[0])
    smooth = lion.modifiers.new('smooth', 'SUBSURF')
    smooth.levels = 2
    bpy.ops.object.modifier_apply(modifier='smooth')
    # The mane and the paws take finer work than the rest: they get more mesh.
    group = lion.vertex_groups['mane'].index
    def in_mane(v):
        return sum(g.weight for g in v.groups if g.group == group)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    deform = bm.verts.layers.deform.verify()
    fine = [e for e in bm.edges if all(v.co.z < .11 or v[deform].get(group, 0.0) > .5 for v in e.verts)]
    bmesh.ops.subdivide_edges(bm, edges=fine, cuts=1, use_grid_fill=True, smooth=1.0)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    head = J(0, -3.9, 4.9)
    # (Read once: a mesh works its normals out afresh after every change.)
    normals = [v.normal.copy() for v in mesh.vertices]
    moved = [v.co.copy() for v in mesh.vertices]
    for v in mesh.vertices:
        p = v.co.copy()
        normal = normals[v.index]
        weight = in_mane(v)
        if weight > 0:
            # Locks of the mane run back and down from the face: ridges long
            # in that direction, narrow across it.
            out = p-head
            around = math.atan2(out.x, out.z)
            flow = out.length
            locks = 1.0-abs(noise.noise(Vector((around*3.6, flow*1.6, p.y*1.2))))
            strands = 1.0-abs(noise.noise(Vector((around*12.0, flow*3.5, p.y*3.0))))
            moved[v.index] = p+normal*((locks-.6)*.085+(strands-.6)*.03+.02)*weight
        elif p.z < .62:
            # The model's legs are sticks: a lion's are heavy.
            moved[v.index] = p+normal*.016*min(1.0, (.62-p.z)/.12)
        # Haunch and shoulder stand out from the flank.
        for centre, radius, rise in ((J(.95, 3.5, 3.9), .24, .03), (J(-.95, 3.5, 3.9), .24, .03), (J(1.1, -2.2, 4.0), .22, .024), (J(-1.1, -2.2, 4.0), .22, .024)):
            d = (p-centre).length/radius
            if d < 1.0 and weight <= 0: moved[v.index] = moved[v.index]+normal*rise*(1.0-d*d)**2
    # Toes: three grooves down the front of each paw.
    for name in ('forepaw_l', 'forepaw_r', 'hindpaw_l', 'hindpaw_r'):
        toe = BONES[name][1]
        for index, p in enumerate(moved):
            if p.z > .085 or abs(p.x-toe.x) > .09 or p.y > toe.y+.07 or p.y < toe.y-.12: continue
            groove = max(math.exp(-((p.x-toe.x-offset)/.009)**2) for offset in (-.028, 0.0, .028))
            moved[index] = p-normals[index]*.011*groove*min(1.0, (toe.y+.07-p.y)/.05)
    mesh.vertices.foreach_set('co', [c for p in moved for c in p])
    mesh.update()
    cut = lion.modifiers.new('cut', 'DECIMATE')
    cut.ratio = min(1.0, TRIANGLES/len(mesh.polygons))
    bpy.ops.object.modifier_apply(modifier='cut')
    lion.vertex_groups.remove(lion.vertex_groups['mane'])
    mesh.materials.clear()
    for m in list(bpy.data.materials): bpy.data.materials.remove(m)
    for i in list(bpy.data.images): bpy.data.images.remove(i)
    return lion

def build_face(lion):
    """Poly Haven's sculpted lion mask, set over the front of the head."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(FACE))
    face = [o for o in bpy.data.objects if o not in before and o.type == 'MESH'][0]
    for o in list(bpy.data.objects):
        if o not in before and o != face: bpy.data.objects.remove(o, do_unlink=True)
    face.parent = None
    mesh = face.data
    transform = face.matrix_world.copy()
    face.matrix_world = Matrix.Identity(4)
    for v in mesh.vertices: v.co = transform @ v.co
    # It stands on a plinth, which is left behind.
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < .0745], context='VERTS')
    bm.to_mesh(mesh)
    bm.free()
    nose = min(mesh.vertices, key=lambda v: v.co.y).co.copy()
    for v in mesh.vertices: v.co = (v.co-nose)*FACE_SCALE+NOSE
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = face
    face.select_set(True)
    cut = face.modifiers.new('cut', 'DECIMATE')
    cut.ratio = min(1.0, FACE_TRIANGLES/sum(len(p.vertices)-2 for p in mesh.polygons))
    bpy.ops.object.modifier_apply(modifier='cut')
    mesh.materials.clear()
    for m in list(bpy.data.materials): bpy.data.materials.remove(m)
    for i in list(bpy.data.images): bpy.data.images.remove(i)
    # Blue 0 marks the mask for the statue shader: its UVs carry a normal map.
    for obj, colour in ((face, (1.0, 1.0, 0.0, 1.0)), (lion, (1.0, 1.0, 1.0, 1.0))):
        mask = obj.data.color_attributes.new('StoneMask', 'BYTE_COLOR', 'POINT')
        for item in mask.data: item.color = colour
    lion.select_set(True)
    bpy.context.view_layer.objects.active = lion
    bpy.ops.object.join()
    mesh = lion.data
    mesh.color_attributes.active_color = mesh.color_attributes['StoneMask']
    mesh.color_attributes.render_color_index = mesh.color_attributes.active_color_index
    for p in mesh.polygons: p.use_smooth = True
    return lion

def build_rig():
    data = bpy.data.armatures.new('LionRig')
    rig = bpy.data.objects.new('LionRig', data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    for name in ORDER:
        head, tail, parent, _ = BONES[name]
        bone = data.edit_bones.new(name)
        bone.head = head
        bone.tail = tail
        bone.roll = 0.0
        if parent: bone.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    for bone in rig.pose.bones: bone.rotation_mode = 'QUATERNION'
    return rig

def distance_to_segment(p, a, b):
    ab = b-a
    t = max(0.0, min(1.0, (p-a).dot(ab)/ab.length_squared))
    return (p-(a+ab*t)).length

def skin(lion, rig):
    """Each vertex follows the bones it lies nearest, each within its radius."""
    groups = {name: lion.vertex_groups.new(name=name) for name in ORDER if name != 'root'}
    for v in lion.data.vertices:
        p = v.co
        weights = []
        for name in groups:
            head, tail, _, radius = BONES[name]
            # A leg moves only its own side of the body.
            if name.endswith('_l') and p.x < -.01: continue
            if name.endswith('_r') and p.x > .01: continue
            d = distance_to_segment(p, head, tail)/radius
            weights.append((1.0/(.05+d)**5, name))
        weights.sort(reverse=True)
        weights = weights[:4]
        total = sum(w for w, _ in weights)
        for w, name in weights:
            if w/total > .02: groups[name].add([v.index], w/total, 'REPLACE')
    lion.parent = rig
    modifier = lion.modifiers.new('rig', 'ARMATURE')
    modifier.object = rig

# ---- Posing ----

def turn(pitch=0.0, yaw=0.0, roll=0.0):
    """A turn of the body, in degrees: nose up, to its left, and rolled to its right."""
    return (Matrix.Rotation(math.radians(yaw), 3, 'Z') @ Matrix.Rotation(math.radians(-pitch), 3, 'X') @ Matrix.Rotation(math.radians(-roll), 3, 'Y')).to_quaternion()

def swing(a, b):
    """The smallest turn carrying direction `a` to `b`."""
    return a.normalized().rotation_difference(b.normalized())

class Pose:
    """One frame: the turn of each bone from rest, and where the hips are."""
    def __init__(self, rest):
        self.rest = rest
        self.turns = {name: Quaternion() for name in ORDER}
        self.shift = Vector((0, 0, 0))
        self.heads = {}

    def head(self, name):
        """Where a bone starts, the bones before it having turned."""
        if name in self.heads: return self.heads[name]
        parent = BONES[name][2]
        if parent is None: at = BONES[name][0].copy()
        else: at = self.head(parent)+self.turns[parent] @ (BONES[name][0]-BONES[parent][0])
        if name == 'hips': at = at+self.shift
        self.heads[name] = at
        return at

    def body(self, hips=None, spine=None, chest=None, neck=None, head=None, shift=None):
        if shift is not None: self.shift = Vector(shift)
        for name, value in (('hips', hips), ('spine', spine), ('chest', chest), ('neck', neck), ('head', head)):
            if value is not None: self.turns[name] = value
        self.heads = {}

    def tail(self, lift, sway, curl=0.0):
        """The tail: raised `lift` degrees at its root, swung `sway` degrees aside, curling up along its length."""
        for i in range(4):
            self.turns['tail%d' % (i+1)] = self.turns['hips'] @ turn(-(lift+curl*i), sway*(.4+.3*i))

    def leg(self, upper, lower, paw, toe, pitch, forward_knee):
        """Stands a leg with its toe at `toe`, its paw pitched `pitch` degrees
        (heel up), by two-bone IK from the shoulder or hip."""
        self.heads.pop(upper, None); self.heads.pop(lower, None); self.heads.pop(paw, None)
        start = self.head(upper)
        paw_turn = Matrix.Rotation(math.radians(pitch), 3, 'X').to_quaternion()
        reach = BONES[paw][1]-BONES[paw][0]
        target = Vector(toe)-paw_turn @ reach
        first = (BONES[upper][1]-BONES[upper][0]).length
        second = (BONES[lower][1]-BONES[lower][0]).length
        along = target-start
        d = max(abs(first-second)+.01, min(first+second-.003, along.length))
        along.normalize()
        target = start+along*d
        a = (first*first-second*second+d*d)/(2*d)
        h = math.sqrt(max(0.0, first*first-a*a))
        # The elbow bends back, the knee forward (the lion faces -Y).
        pole = Vector((0, -1 if forward_knee else 1, 0))
        pole = pole-along*pole.dot(along)
        pole.normalize()
        joint = start+along*a+pole*h
        self.turns[upper] = swing(BONES[upper][1]-BONES[upper][0], joint-start)
        self.turns[lower] = swing(BONES[lower][1]-BONES[lower][0], target-joint)
        self.turns[paw] = paw_turn
        self.heads[lower] = joint
        self.heads[paw] = target

    def legs(self, paws):
        """`paws`: for fl, fr, hl, hr, (toe position or None for its rest, pitch)."""
        for key, (toe, pitch) in paws.items():
            side = 'l' if key[1] == 'l' else 'r'
            front = key[0] == 'f'
            names = ('upperarm_', 'forearm_', 'forepaw_') if front else ('thigh_', 'shin_', 'hindpaw_')
            rest_toe = BONES[names[2]+side][1]
            self.leg(names[0]+side, names[1]+side, names[2]+side, rest_toe+Vector(toe) if toe is not None else rest_toe, pitch, not front)

    def key(self, rig, frame):
        poses = {}
        for name in ORDER:
            rest = self.rest[name]
            pose = Matrix.Translation(self.head(name)) @ (self.turns[name].to_matrix() @ rest.to_3x3()).to_4x4()
            poses[name] = pose
            parent = BONES[name][2]
            if parent is None: basis = rest.inverted() @ pose
            else: basis = (poses[parent] @ (self.rest[parent].inverted() @ rest)).inverted() @ pose
            bone = rig.pose.bones[name]
            bone.rotation_quaternion = basis.to_quaternion()
            bone.keyframe_insert('rotation_quaternion', frame=frame)
            if name in ('root', 'hips'):
                bone.location = basis.to_translation()
                bone.keyframe_insert('location', frame=frame)

def ease(t):
    t = max(0.0, min(1.0, t))
    return t*t*(3.0-2.0*t)

def between(keys, u):
    """A value eased through [u, value] keys (numbers or vectors)."""
    for i in range(len(keys)-1):
        if u <= keys[i+1][0]:
            w = ease((u-keys[i][0])/max(1e-5, keys[i+1][0]-keys[i][0]))
            a, b = keys[i][1], keys[i+1][1]
            return a+(b-a)*w
    return keys[-1][1]

STAND = {'fl': (None, 0.0), 'fr': (None, 0.0), 'hl': (None, 0.0), 'hr': (None, 0.0)}

def idle(pose, u):
    """Standing watch: it breathes, turns its head a little, and its tail sways."""
    breath = math.sin(u*math.tau*2.0)
    look = math.sin(u*math.tau)
    pose.body(shift=(0, 0, breath*.006), chest=turn(pitch=breath*.8), neck=turn(pitch=4+breath*.6, yaw=look*5), head=turn(pitch=2, yaw=look*9))
    pose.tail(-28, math.sin(u*math.tau)*14, curl=9)
    pose.legs(STAND)

# The gallop: when in the stride each paw lands, how much of the stride it is
# on the ground, and how far it sweeps back under the body while it is.
LANDS = {'hl': 0.0, 'hr': .09, 'fl': .43, 'fr': .52}
STANCE = .28
SWEEP = .36
# (So the stride as played covers 2*SWEEP/(STANCE*length) metres a second:
# RUN_SPEED in scripts/visual.gd.)

def run(pose, u):
    bound = math.cos((u-.14)*math.tau)
    gather = math.cos((u-.86)*math.tau)
    pose.body(shift=(0, 0, .045*math.cos((u-.86)*math.tau)-.01),
        hips=turn(pitch=-9*gather+3*bound), spine=turn(pitch=-3*gather+4*bound), chest=turn(pitch=5*bound+4*gather),
        neck=turn(pitch=8-3*bound), head=turn(pitch=-2-2*bound))
    pose.tail(8+6*bound, 0.0, curl=-5+4*math.sin(u*math.tau))
    paws = {}
    for key, lands in LANDS.items():
        p = (u-lands) % 1.0
        front = key[0] == 'f'
        neutral = -.10 if front else -.06
        if p < STANCE:
            s = p/STANCE
            forward = SWEEP*(1.0-2.0*s)
            # It rolls off its toes as the paw leaves the ground.
            paws[key] = ((0, neutral-forward, 0), 38*ease((s-.6)/.4))
        else:
            s = (p-STANCE)/(1.0-STANCE)
            forward = SWEEP*(2.0*ease(s)-1.0)
            lift = (.26 if front else .22)*math.sin(s*math.pi)**.8
            # Folded under on the way forward, opening to land flat.
            pitch = between([(0, 38), (.3, 70), (.75, -12), (1, 0)], s)
            paws[key] = ((0, neutral-forward, lift), pitch)
    pose.legs(paws)

# The swipe lands this far through the clip: the lion's wind-up over its
# whole attack (Actor.start_attack: .42 s of .67).
CONTACT = .627

def attack(pose, u):
    """Rears up off its forepaws, the right one raised beside its head, and
    rakes it forward, down and across as it comes down."""
    back = between([(0, 0), (.36, 1), (CONTACT, -1.6), (.82, -.6), (1, 0)], u)
    rear = between([(0, 0), (.36, 1), (CONTACT, .5), (.85, .08), (1, 0)], u)
    twist = between([(0, 0), (.36, -14), (CONTACT, 18), (.85, 8), (1, 0)], u)
    pose.body(shift=(0, back*.085, -.05*rear),
        hips=turn(pitch=15*rear), spine=turn(pitch=20*rear, yaw=twist*.3), chest=turn(pitch=26*rear, yaw=twist, roll=-twist*.35),
        neck=turn(pitch=4+18*rear, yaw=twist*.6), head=turn(pitch=between([(0, 2), (.36, 16), (CONTACT, -10), (1, 2)], u), yaw=twist*.5))
    pose.tail(between([(0, -28), (.36, 14), (CONTACT, 30), (1, -28)], u), -twist, curl=6)
    # The right forepaw: up beside the head, out through the blow, down. The
    # left leaves the ground as the lion rears and lands first.
    right = between([(0, Vector((0, 0, 0))), (.36, Vector((-.32, .05, 1.45))), (CONTACT, Vector((.22, -.80, 1.02))), (.82, Vector((.14, -.40, .30))), (1, Vector((0, 0, 0)))], u)
    left = between([(0, Vector((0, 0, 0))), (.36, Vector((.04, -.05, .46))), (CONTACT, Vector((0, -.16, .30))), (.8, Vector((0, -.08, 0))), (1, Vector((0, 0, 0)))], u)
    pose.legs({'hl': (None, 0.0), 'hr': (None, 0.0),
        'fl': (tuple(left), between([(0, 0), (.36, 55), (CONTACT, 25), (.8, 0), (1, 0)], u)),
        'fr': (tuple(right), between([(0, 0), (.36, 80), (CONTACT, -35), (.82, 10), (1, 0)], u))})

def hit(pose, u):
    """A blow to the body: it rocks back on its haunches and recovers."""
    jolt = between([(0, 0), (.25, 1), (1, 0)], u)
    pose.body(shift=(0, jolt*.07, -jolt*.03), hips=turn(pitch=-3*jolt), chest=turn(pitch=6*jolt), neck=turn(pitch=4+10*jolt), head=turn(pitch=2+8*jolt))
    pose.tail(-28+30*jolt, 0.0, curl=9)
    pose.legs(STAND)

def hit_head(pose, u):
    """A blow to the head: it is knocked aside."""
    jolt = between([(0, 0), (.25, 1), (1, 0)], u)
    pose.body(shift=(0, jolt*.03, -jolt*.015), chest=turn(yaw=6*jolt, roll=4*jolt), neck=turn(pitch=4-8*jolt, yaw=16*jolt), head=turn(pitch=2-6*jolt, yaw=30*jolt, roll=14*jolt))
    pose.tail(-28+20*jolt, -18*jolt, curl=9)
    pose.legs(STAND)

def hit_stagger(pose, u):
    """A heavy blow: it is driven back and down, and gathers itself."""
    jolt = between([(0, 0), (.22, 1), (.55, .7), (1, 0)], u)
    pose.body(shift=(0, jolt*.15, -jolt*.10), hips=turn(pitch=-6*jolt, roll=-5*jolt), spine=turn(roll=3*jolt), chest=turn(pitch=-4*jolt, roll=8*jolt),
        neck=turn(pitch=4-16*jolt, yaw=-10*jolt), head=turn(pitch=2-12*jolt, yaw=-12*jolt))
    pose.tail(-28+44*jolt, 16*jolt, curl=9)
    pose.legs(STAND)

# name: (pose, frames, loops)
CLIPS = {'Idle': (idle, 72, True), 'Run': (run, 15, True), 'Attack': (attack, 20, False),
    'Hit': (hit, 12, False), 'HitHead': (hit_head, 12, False), 'HitStagger': (hit_stagger, 18, False)}

def animate(rig):
    rest = {name: rig.data.bones[name].matrix_local.copy() for name in ORDER}
    rig.animation_data_create()
    for name, (maker, frames, loops) in CLIPS.items():
        action = bpy.data.actions.new(name)
        rig.animation_data.action = action
        for frame in range(frames+1):
            pose = Pose(rest)
            maker(pose, frame/frames)
            pose.key(rig, frame)
        rig.animation_data.action = None
        track = rig.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 0, action)
        strip.action_frame_end = frames
    for bone in rig.pose.bones:
        bone.rotation_quaternion = Quaternion()
        bone.location = Vector((0, 0, 0))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = FPS
lion = build_face(build_body())
rig = build_rig()
skin(lion, rig)
animate(rig)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS',
    export_nla_strips=True, export_force_sampling=True, export_skins=True, export_def_bones=False, export_yup=True, export_vertex_color='ACTIVE')
print('LION_READY', len(lion.data.vertices), sum(len(p.vertices)-2 for p in lion.data.polygons), tuple(round(d, 2) for d in lion.dimensions))
