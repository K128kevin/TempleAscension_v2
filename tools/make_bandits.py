"""Builds the bandits: assets/models/character/bandit_man.glb and bandit_woman.glb,
and their curved blade, assets/models/props/sica.glb.

After the desert raider of their concept art: a long tunic of rough cream
linen, sleeveless, its hem in tatters and banded in red; a studded leather
vest over it with a strap across the chest; a red sash wound at the waist
under a leather belt, and over the skirt a ragged apron of dark cloth; a red
shawl wound about the neck and hanging down the back as a short cape; a red
cloth wrapped about the brow; leather bracers on the forearms, leather
bindings wound up the shins, and sandals (drawn on the feet by the game).

Each is one of the base character pack's two bodies (as the townspeople are,
tools/make_townsfolk.py, whose garment lofting this uses), on its own
skeleton, with the hero's fighting clips (warrior.glb) retargeted to it: the
same bones turn as the hero's do, on this body's own limb lengths, so a
bandit fights, runs, flinches and falls as the hero's model does. The
ranger's quiver and sheathed dagger are carried over from the hero's model,
moved from his frame to each body's.

The game dyes and wears each bandit's clothes and picks hair, beard and which
pieces are worn (scripts/bandit.gd). What each garment covers is written to
scripts/bandit_wardrobe.gd.

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/make_bandits.py
"""
import importlib.util
import math
from pathlib import Path
import bpy
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('townsfolk', ROOT/'tools/make_townsfolk.py')
folk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(folk)
V, outline, named = folk.V, folk.outline, folk.named
OUT = ROOT/'assets/models/character'
HERO = OUT/'warrior.glb'
# The hero's clips a bandit needs: standing, moving, the sword's and the bow's
# blows and stances, the dagger's, flinching and falling.
CLIPS = ['Idle', 'Walk', 'Run', 'Crouch', 'SneakIdle', 'Evade', 'Attack', 'Cast', 'SwordIdle', 'SwordRun', 'SwordSwing', 'SwordSlash',
    'DaggerStab', 'DaggerSlash', 'ArcherShot', 'BowIdle', 'BowShot', 'BowRun', 'BowCrouch', 'RangerIdle', 'RangerRun', 'RangerCrouch',
    'Hit', 'HitHead', 'HitStagger', 'HitKnockdown', 'Death']
# The hero's gear each bandit carries.
CARRIED = ['RangerQuiver', 'RangerDagger']
# How far the sica's point is swept back, in blade widths.
SWEEP = 1.1
WARDROBE = {}
WARDROBE_SCRIPT = ROOT/'scripts/bandit_wardrobe.gd'


class Cloth(folk.Garment):
    """A garment lofted down the body as the townspeople's are, with what a
    raider's kit needs besides: tubes that start below the shoulders (a sash,
    an apron), layers laid over the shoulders one over another, cloth cut to
    a part of its tube (a cape, a strap), and wrappings round a limb."""

    def trunk(self, top, hem, ease, count=32, step=.025, fray=.14, yoke=.014, collar=.03, keep=None):
        """As the townspeople's trunk, from `top` down to `hem`. `yoke` is how
        far over the flesh it is laid from the top ring in to the neck (None:
        it stops at its top ring, as a skirt does); `keep` which flesh it is
        fitted round (the body's, the arms left out)."""
        body = self.body
        self.top, self.hem = top, hem
        # (The figure stands with its arms out: the tops of its shoulders'
        # muscles are left out, or the cloth would stand up in points over
        # them.)
        keep = keep or (lambda i: abs(body.points[i].x) <= body.shoulder and not body.arm[i])
        chosen_points = [i for i in range(len(body.points)) if keep(i)]
        levels = []
        z = top
        while z > hem+step*.5:
            levels.append(z)
            z -= step*.6 if z > body.joint('upperarm_l').z-.07 else step
        levels.append(hem)
        rings = []
        for z in levels:
            band = step*.8
            chosen = [(body.points[i].x, body.points[i].y) for i in chosen_points if abs(body.points[i].z-z) < band]
            ring = outline(chosen, count, ease(z), (0, -1))
            if ring is None: ring = [(p.x, p.y) for p in rings[-1]]
            rings.append([V(p[0], p[1], z) for p in ring])
        for step_ in range(2):
            eased = [list(ring) for ring in rings]
            for k in range(1, len(rings)-1):
                for i in range(count):
                    middle = (rings[k-1][i]+rings[k+1][i])*.5
                    eased[k][i] = V(rings[k][i].x*.6+middle.x*.4, rings[k][i].y*.6+middle.y*.4, rings[k][i].z)
            rings = eased
        lead = self.yoke(rings[0], count, ease=yoke, collar=collar) if yoke is not None else []
        edges = [0.0]*len(lead)+[max(0.0, 1.0-(z-hem)/fray) for z in levels]
        rings = lead+rings
        tree = body.tree(lambda i: keep(i) and (not body.arm[i] or abs(body.points[i].x) <= body.shoulder))
        self.tube(rings, edges, tree, (V(0, body.joint('spine_02').y, 0), V(0, 0, 1)))
        return self

    def yoke(self, top, count, steps=5, ease=.014, collar=.03):
        body = self.body
        neck = body.joint('neck_01')
        reach = body.joint('upperarm_l').x
        around = [(p.x, p.y) for p in body.points if abs(p.z-(neck.z+.02)) < .012 and abs(p.x) < reach*.6]
        ring = outline(around, count, collar, (0, -1))
        if ring is None: return []
        under = [body.points[i] for i in range(len(body.points)) if neck.z-.15 < body.points[i].z < neck.z+.1 and (not body.arm[i] or abs(body.points[i].x) <= body.shoulder)]
        rings = []
        for k in range(steps, 0, -1):
            t = k/(steps+1)
            out = []
            for i in range(count):
                x = top[i].x+(ring[i][0]-top[i].x)*t
                y = top[i].y+(ring[i][1]-top[i].y)*t
                near = [p.z for p in under if (p.x-x)**2+(p.y-y)**2 < .018**2]
                z = max(near)+ease if near else top[i].z
                out.append(V(x, y, min(neck.z+.035+ease, max(z, top[i].z))))
            rings.append(out)
        return rings

    def limb(self, start, end, bones, reach, ease, count=14, step=.022):
        """A wrapping round a limb, from the joint `start` toward `end`, over
        the share `reach` (from, to) of the way, `ease` (from, to) loose: the
        flesh it is fitted round is that held most by `bones`."""
        body = self.body
        a, b = body.joint(start), body.joint(end)
        axis = (b-a).normalized()
        span = (b-a).length
        # (Its rings start at the limb's back, where the wrapping's ends lie.)
        back = V(0, 1, 0)
        up = (back-axis*axis.dot(back)).normalized()
        across = axis.cross(up)
        held = [i for i in range(len(body.points)) if body.weights[i] and max(body.weights[i], key=body.weights[i].get) in bones]
        rings, edges = [], []
        t = reach[0]*span
        while True:
            t = min(t, reach[1]*span)
            share = (t/span-reach[0])/max(.001, reach[1]-reach[0])
            chosen = [((body.points[i]-a).dot(up), (body.points[i]-a).dot(across)) for i in held if abs((body.points[i]-a).dot(axis)-t) < step*.8]
            ring = outline(chosen, count, ease[0]+(ease[1]-ease[0])*share, (1, 0))
            if ring is not None:
                rings.append([a+axis*t+up*p[0]+across*p[1] for p in ring])
                edges.append(0.0)
            if t >= reach[1]*span: break
            t += step
        chosen_set = set(held)
        tree = body.tree(lambda i: i in chosen_set)
        self.tube(rings, edges, tree, (a, axis))
        return self

    def cut(self, keep, snap=None):
        """Keeps only the cloth whose faces' middles `keep` says to; `snap`
        then moves each point left to where the cut's edge runs, so the edge
        is drawn straight rather than stepped face by face."""
        kept = [k for k, face in enumerate(self.faces) if keep(sum((self.verts[i] for i in face), Vector())/len(face))]
        self.faces = [self.faces[k] for k in kept]
        self.lines = [self.lines[k] for k in kept]
        if snap:
            for i in set(i for face in self.faces for i in face): self.verts[i] = snap(self.verts[i])
        return self

    def build(self, rig, material):
        obj = super().build(rig, material)
        WARDROBE.setdefault(rig.name, {})[self.name] = (round(self.top, 3), round(self.hem, 3), round(self.sleeve, 3))
        return obj


def headwrap(body, rig, hair):
    """A cloth wound about the brow, over the hair, knotted at the back."""
    eyes = next(o for o in bpy.data.objects if o.type == 'MESH' and o.parent == rig and 'Eye' in o.name and 'brow' not in o.name.lower())
    eye = sum((eyes.matrix_world @ v.co for v in eyes.data.vertices), Vector())/len(eyes.data.vertices)
    head = [p for i, p in enumerate(body.points) if body.weights[i] and max(body.weights[i], key=body.weights[i].get) in ('Head', 'neck_01')]
    # (Only the hair close about the skull: long hair falling loose at the
    # sides goes under the wrap, not inside it.)
    crown = body.joint('Head')
    head += [p for p in hair if math.hypot(p.x-crown.x, p.y-crown.y) < .115]
    garment = Cloth('Headwrap', body)
    rings, edges = [], []
    low, high = eye.z+.022, eye.z+.085
    for k in range(7):
        z = low+(high-low)*k/6
        # Fuller in the middle of the band, where it is wound thickest.
        ease = .012+.008*math.sin(math.pi*k/6)
        ring = outline([(p.x, p.y) for p in head if abs(p.z-z) < .012], 28, ease, (0, 1))
        if ring is None: continue
        rings.append([V(p[0], p[1], z) for p in ring])
        edges.append(0.0)
    tree = body.tree(lambda i: body.weights[i] and 'Head' in body.weights[i])
    garment.tube(rings, edges, tree, (body.joint('Head'), V(0, 0, 1)))
    # The knot: a short twist of the cloth at the back of the head.
    back = max(p.y for p in head if abs(p.z-(low+high)/2) < .015 and abs(p.x) < .03)
    knot = []
    for k in range(5):
        z = (low+high)/2+.012-k*.012
        y = back+.012+k*.004
        knot.append([V(math.cos(a*math.tau/10)*.018*(1-k*.08), y+math.sin(a*math.tau/10)*.012, z) for a in range(10)])
    garment.tube(knot, [0.0]*len(knot), tree, (V(0, back, (low+high)/2), V(0, 0, -1)))
    garment.top, garment.hem = high, low
    return garment.build(rig, named('Headwrap'))


def retarget(rig, source):
    """Bakes each of the hero's clips onto this body's skeleton, frame for
    frame (tools/make_townsfolk.py retargets the library's the same way)."""
    scene = bpy.context.scene
    rig.animation_data_create()
    bones = sorted(rig.data.bones, key=lambda b: len(b.parent_recursive))
    rest = {b.name: b.matrix_local.copy() for b in bones}
    for pose in rig.pose.bones: pose.rotation_mode = 'QUATERNION'
    # (Nothing need be skinned while the clips are baked.)
    skinned = [m for o in bpy.data.objects if o.type == 'MESH' for m in o.modifiers if m.type == 'ARMATURE' and m.show_viewport]
    for modifier in skinned: modifier.show_viewport = False
    legs = rig.data.bones['pelvis'].head_local.z/source.data.bones['pelvis'].head_local.z
    made = []
    for name in CLIPS:
        clip = bpy.data.actions[name]
        source.animation_data.action = clip
        first, last = round(clip.frame_range[0]), round(clip.frame_range[1])
        action = bpy.data.actions.new(name+'_baked')
        rig.animation_data.action = action
        for frame in range(first, last+1):
            scene.frame_set(frame)
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
        made.append((name, first, last, action))
        rig.animation_data.action = None
    for name, first, last, action in made:
        track = rig.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, first, action)
        strip.action_frame_start, strip.action_frame_end = first, last
    for pose in rig.pose.bones:
        pose.rotation_quaternion = (1, 0, 0, 0)
        pose.location = (0, 0, 0)
    for modifier in skinned: modifier.show_viewport = True


def carry_over(obj, source, rig, scale):
    """Moves a piece of the hero's gear from his frame to this body's: each
    point goes with the bones that hold it, from where they are on him to
    where they are on this body, its offset from them scaled to this body."""
    names = [g.name for g in obj.vertex_groups]
    points = []
    for v in obj.data.vertices:
        world = obj.matrix_world @ v.co
        moved = Vector()
        total = 0.0
        for g in v.groups:
            bone = names[g.group]
            if g.weight <= 0 or bone not in rig.data.bones: continue
            his = source.matrix_world @ source.data.bones[bone].matrix_local
            hers = rig.matrix_world @ rig.data.bones[bone].matrix_local
            local = his.inverted() @ world
            moved += (hers @ (local*scale))*g.weight
            total += g.weight
        points.append(moved/total if total else world)
    world_to_obj = obj.matrix_world.inverted()
    for v, p in zip(obj.data.vertices, points): v.co = world_to_obj @ p
    world = obj.matrix_world.copy()
    obj.parent = rig
    obj.matrix_world = world
    for modifier in obj.modifiers:
        if modifier.type == 'ARMATURE': modifier.object = rig


def make(who):
    woman = who == 'woman'
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # The hero's clips are baked at 30 fps (tools/import_combat.py).
    bpy.context.scene.render.fps = 30
    bpy.ops.import_scene.gltf(filepath=str(HERO))
    source = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    source.name = 'HeroRig'
    for track in list(source.animation_data.nla_tracks): source.animation_data.nla_tracks.remove(track)
    for obj in list(bpy.data.objects):
        if obj.type == 'MESH' and obj.name not in CARRIED: bpy.data.objects.remove(obj, do_unlink=True)
    gear = [bpy.data.objects[name] for name in CARRIED]
    hero_objects = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(folk.BASE/'Base Characters/Godot - UE'/('Superhero_Female_FullBody.gltf' if woman else 'Superhero_Male_FullBody.gltf')))
    rig = next(o for o in set(bpy.data.objects)-hero_objects if o.type == 'ARMATURE')
    rig.name = 'BanditWomanRig' if woman else 'BanditManRig'
    flesh = next(o for o in bpy.data.objects if o.type == 'MESH' and o.parent == rig and o.name.lower().startswith('superhero'))
    flesh.name = 'Body'
    for obj in list(bpy.data.objects):
        if obj.type == 'MESH' and obj.parent is None: bpy.data.objects.remove(obj, do_unlink=True)
    body = folk.Body(flesh, rig)
    styles = ['Hair_Long', 'Hair_Buns'] if woman else ['Hair_SimpleParted', 'Hair_Buzzed', 'Hair_Beard']
    hair = []
    for style in styles:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(folk.HAIR/(style+'.gltf')))
        for obj in set(bpy.data.objects)-before:
            if obj.type == 'MESH' and obj.vertex_groups:
                world = obj.matrix_world.copy()
                obj.parent = rig
                obj.matrix_world = world
                obj.name = style
                for modifier in obj.modifiers:
                    if modifier.type == 'ARMATURE': modifier.object = rig
                if style != 'Hair_Beard': hair += [obj.matrix_world @ v.co for v in obj.data.vertices]
            else: bpy.data.objects.remove(obj, do_unlink=True)
    for obj in bpy.data.objects:
        if obj.type != 'MESH' or obj.parent != rig: continue
        for slot in obj.material_slots:
            name = slot.material.name
            slot.material = named('Skin' if 'Superhero' in name else 'Eyes' if 'Eyes' in name else 'Hair2' if 'Hair_2' in name else 'Hair1')
    neck, arm, hips, knee, ankle = body.joint('neck_01').z, body.joint('upperarm_l').z, body.joint('pelvis').z, body.joint('calf_l').z, body.joint('foot_l').z
    head = body.joint('Head').z
    waist = body.joint('spine_01').z+.03
    upper = (body.joint('lowerarm_l')-body.joint('upperarm_l')).length
    top = neck+.012
    def tunic_cut(z):
        if z > arm+.03: return .012
        if z > waist+.07: return .02
        if z > waist-.07: return .016+.004*min(1.0, abs(z-waist)/.07)
        return .028+.06*max(0.0, (hips-.1-z)/max(.01, hips-.1-(knee-.08)))
    Cloth('Tunic', body).trunk(top, knee-.08, tunic_cut, fray=.16).sleeves(upper*(.22 if woman else .18), .024, .034, fray=.05).build(rig, named('Tunic'))
    # The vest: close leather to the waist, over the tunic.
    def vest_cut(z):
        if z > arm+.03: return .022
        return .032 if z > waist+.05 else .034
    Cloth('Vest', body).trunk(top+.004, waist-.035, vest_cut, fray=.05, yoke=.024, collar=.04).build(rig, named('Leather'))
    # A strap across the chest and back, from the left shoulder to the right hip.
    shoulder = body.joint('upperarm_l').x
    def line(p):
        return arm+.05+(p.x-shoulder*.8)*((arm+.05)-(waist-.02))/(shoulder*1.6)
    def across(p):
        return abs(p.z-line(p)) < .03
    def onto(p):
        return V(p.x, p.y, max(line(p)-.024, min(line(p)+.024, p.z)))
    Cloth('Strap', body).trunk(top+.008, waist-.06, lambda z: .042 if z < arm+.03 else .03, count=72, step=.012, fray=.01, yoke=.03, collar=.048).cut(across, onto).build(rig, named('Strap'))
    Cloth('Sash', body).trunk(waist+.06, waist-.065, lambda z: .042, fray=.01, yoke=None).build(rig, named('Sash'))
    Cloth('Belt', body).trunk(waist-.005, waist-.05, lambda z: .052, fray=.01, yoke=None).build(rig, named('Belt'))
    def apron_cut(z):
        return .036+.07*max(0.0, (hips-.1-z)/max(.01, hips-.1-(knee+.1)))
    Cloth('Apron', body).trunk(waist-.04, knee+.1, apron_cut, fray=.2, yoke=None).build(rig, named('Apron'))
    # The shawl: wound thick about the neck up to the jaw, and hanging down
    # the back from the shoulders as a short cape.
    def cowl_cut(z):
        return .05 if z < neck+.02 else .03
    Cloth('Shawl', body).trunk(neck+(head-neck)*.55, arm-.06, cowl_cut, step=.02, fray=.06, yoke=None).build(rig, named('Shawl'))
    middle = body.joint('spine_02').y
    def cape_cut(z):
        return .05+.09*max(0.0, (arm-z)/(arm-(knee-.05)))
    def behind(p):
        return math.degrees(math.atan2(abs(p.x), p.y-middle)) < 62
    Cloth('Cape', body).trunk(arm+.02, knee-.05, cape_cut, fray=.22, yoke=.066, collar=.07).cut(behind).build(rig, named('Cape'))
    headwrap(body, rig, hair)
    for side in ('l', 'r'):
        Cloth('Bracer_'+side, body).limb('lowerarm_'+side, 'hand_'+side, ('lowerarm_'+side,), (.22, .95), (.014, .012)).build(rig, named('Bracers'))
        Cloth('Bindings_'+side, body).limb('calf_'+side, 'foot_'+side, ('calf_'+side,), (.1, 1.0), (.012, .012)).build(rig, named('Bindings'))
    # The hero's gear, moved to this body. (The pelvis's height says how
    # much smaller or larger it is than his.)
    scale = rig.data.bones['pelvis'].head_local.z/source.data.bones['pelvis'].head_local.z
    for obj in gear:
        carry_over(obj, source, rig, scale)
        obj.name = {'RangerQuiver': 'Quiver', 'RangerDagger': 'Dagger'}[obj.name]
    bpy.ops.object.select_all(action='DESELECT')
    flesh.select_set(True)
    bpy.context.view_layer.objects.active = flesh
    cutter = flesh.modifiers.new('cut', 'DECIMATE')
    cutter.ratio = min(1.0, folk.BODY_TRIANGLES/sum(len(p.vertices)-2 for p in flesh.data.polygons))
    bpy.ops.object.modifier_apply(modifier='cut')
    while len(flesh.data.uv_layers) > 1: flesh.data.uv_layers.remove(flesh.data.uv_layers[-1])
    cover = flesh.data.uv_layers.new(name='Cover')
    names = [g.name for g in flesh.vertex_groups]
    marks = []
    for v in flesh.data.vertices:
        p = flesh.matrix_world @ v.co
        held = {names[g.group]: g.weight for g in v.groups}
        on_arm = abs(p.x) > body.shoulder and held and max(held, key=held.get).startswith(folk.ARM)
        marks.append((p.z, abs(p.x)-body.joint('upperarm_l').x if on_arm else 0.0))
    for loop in flesh.data.loops: cover.data[loop.index].uv = marks[loop.vertex_index]
    retarget(rig, source)
    bpy.data.objects.remove(source, do_unlink=True)
    for action in list(bpy.data.actions):
        if not action.name.endswith('_baked'): bpy.data.actions.remove(action)
    bpy.context.scene.frame_set(0)
    bpy.ops.object.select_all(action='SELECT')
    path = OUT/('bandit_woman.glb' if woman else 'bandit_man.glb')
    # (Images go only with the carried gear: the game supplies the rest.)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS',
        export_nla_strips=True, export_force_sampling=True, export_yup=True)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    print('BANDIT_READY', path.name, {o.name: sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes})


def sica():
    """The bandits' curved blade: the bronze sword's, its blade swept back
    along a curve from the guard, as a sica's is."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/props/sword.glb'))
    # (Unit bounds, the blade up +Z, the guard at .33 of its length: the
    # sword's shader's GUARD_TOP.)
    for obj in bpy.data.objects:
        if obj.type != 'MESH': continue
        for v in obj.data.vertices:
            along = max(0.0, v.co.z-.36)/(1.0-.36)
            # Swept toward the back of the blade, more and more toward its
            # point (x is across the blade's flat, a unit its width; the
            # game's sword shader follows the same curve, SWEEP).
            v.co.x -= SWEEP*along*along
            v.co.z -= .08*along*along
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/props/sica.glb'), export_format='GLB', export_animations=False)
    print('SICA_READY')


if __name__ == '__main__':
    for who in ('man', 'woman'): make(who)
    sica()
    lines = ['extends RefCounted', '## Written by tools/make_bandits.py: what each garment covers, as', '## [top, hem, sleeve] in metres on the body at rest.', 'const COVER = {']
    for rig, garments in WARDROBE.items():
        lines.append('\t"%s": {%s},' % ('woman' if 'Woman' in rig else 'man', ', '.join('"%s": [%s, %s, %s]' % ((name,)+cover) for name, cover in garments.items())))
    lines.append('}')
    WARDROBE_SCRIPT.write_text('\n'.join(lines)+'\n')
