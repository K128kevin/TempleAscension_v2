"""Authors the warrior's skill clips onto the supplied rig (after
import_character.py, import_combat.py and import_walk.py; safe to rerun).

Each of the warrior's skills has a swing of its own, keyed here frame by
frame from the sword-and-shield stance: the whole body moves through each
(hips, spine, head, both arms by two-bone IK, the feet kept planted by leg
IK), every value carried along smooth curves so nothing leaps between
frames, and each eases out of the stance and back into it. The sword hand's
turn is set outright at every frame, so the blade runs where the swing
sends it and never through the body or the shield (which the game keeps on
the left forearm).

  SkillCleave     a wide level sweep from right to left
  SkillStrike     Powerful Strike: an overhead chop
  SkillStab       Vampiric Strike: a lunging thrust to the gut
  SkillBash       Shield Bash: the shield shoved forward behind a step
  SkillExecute    the blade raised far behind the head and brought down
                  with the whole body, to the knees
  SkillSlam       Ground Slam: the blade driven into the ground ahead
  SkillShockwave  Shockwave: the blade's pommel hammered down between the
                  feet from a deep crouch
  SkillCry        War Cry: blade thrust at the sky, shield flung wide, head
                  back
  SkillCharge     Shield Charge: the sprint, with the shield held out before
                  him
  SkillLeap       Leap: the crouch, the spring, the tuck and the landing
                  blow

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/import_skills.py
"""
from pathlib import Path
import math
import bpy
from mathutils import Vector, Matrix, Quaternion
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/models/character'
# name: seconds
CLIPS = {'SkillCleave': 1.0, 'SkillStrike': 1.0, 'SkillStab': .9, 'SkillBash': .9, 'SkillExecute': 1.3, 'SkillSlam': 1.1,
    'SkillShockwave': 1.2, 'SkillCry': 1.0, 'SkillCharge': 1.0, 'SkillLeap': 1.0}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=str(OUT/'warrior.glb'))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
for track in list(rig.animation_data.nla_tracks):
    if track.name in CLIPS: rig.animation_data.nla_tracks.remove(track)
for a in list(bpy.data.actions):
    if a.name in CLIPS: bpy.data.actions.remove(a)
for track in rig.animation_data.nla_tracks: track.mute = True

def V(x, y, z):
    return Vector((x, y, z))

def update():
    bpy.context.view_layer.update()

def frame(time):
    value = time*30
    bpy.context.scene.frame_set(math.floor(value), subframe=value % 1)
    update()

# The stance every clip starts from and returns to: the sword-and-shield idle.
rig.animation_data.action = bpy.data.actions['SwordIdle']
frame(0)
BASE = {b.name: b.matrix_basis.copy() for b in rig.pose.bones}
PLANTED = {s: rig.pose.bones['foot_'+s].matrix.translation.copy() for s in 'lr'}
KNEES = {s: rig.pose.bones['calf_'+s].matrix.translation.copy() for s in 'lr'}
rig.animation_data.action = bpy.data.actions['Run']
RUN_SPAN = bpy.data.actions['Run'].frame_range.y/30
RUN = []
for f in range(61):
    frame(RUN_SPAN*f/60)
    RUN.append({b.name: b.matrix_basis.copy() for b in rig.pose.bones})
rig.animation_data.action = None

def reset():
    for b in rig.pose.bones: b.matrix_basis = BASE[b.name]
    update()

def keys(f):
    for b in rig.pose.bones:
        b.keyframe_insert('location', frame=f)
        b.keyframe_insert('rotation_quaternion', frame=f)
        b.keyframe_insert('scale', frame=f)

def finish(name, a, length):
    rig.animation_data.action = None
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 0, a)
    strip.action_frame_end = length*30
    track.mute = True
    print('SKILL_CLIP', name, length)

def ease(u):
    u = max(0.0, min(1.0, u))
    return u*u*(3-2*u)

def sample(points, t):
    """A value carried through (time, value) points, easing between each."""
    for i in range(len(points)-1):
        if t <= points[i+1][0]:
            a, v = points[i]
            b, w = points[i+1]
            return v+(w-v)*ease((t-a)/(b-a))
    return points[-1][1]

def vsample(points, t):
    for i in range(len(points)-1):
        if t <= points[i+1][0]:
            a, v = points[i]
            b, w = points[i+1]
            return Vector(v).lerp(Vector(w), ease((t-a)/(b-a)))
    return Vector(points[-1][1])

def blend(m1, m2, w):
    l1, r1, s1 = m1.decompose()
    l2, r2, s2 = m2.decompose()
    return Matrix.LocRotScale(l1.lerp(l2, w), r1.slerp(r2, w), s1)

def set_world(bone, position, rotation):
    bone.matrix = Matrix.Translation(position) @ rotation.to_matrix().to_4x4()
    update()

def rotate(name, axis, angle):
    """Turns a bone about a world axis, where it stands."""
    b = rig.pose.bones[name]
    m = b.matrix.copy()
    set_world(b, m.translation, Quaternion(Vector(axis), angle) @ m.to_quaternion())

def shift(name, by):
    b = rig.pose.bones[name]
    m = b.matrix.copy()
    set_world(b, m.translation+Vector(by), m.to_quaternion())

def two_bone(upper, lower, end, target, pole):
    """Bends a two-bone chain so its end reaches `target`, the joint toward `pole`."""
    s = upper.matrix.translation.copy()
    target = Vector(target)
    l1 = (lower.matrix.translation-s).length
    l2 = (end.matrix.translation-lower.matrix.translation).length
    d = target-s
    length = max(abs(l1-l2)+.002, min(d.length, l1+l2-.002))
    direction = d.normalized()
    target = s+direction*length
    plane = Vector(pole)-s
    plane = (plane-direction*plane.dot(direction)).normalized()
    along = (l1*l1-l2*l2+length*length)/(2*length)
    joint = s+direction*along+plane*math.sqrt(max(0.0, l1*l1-along*along))
    for bone, head, tip in [(upper, s, joint), (lower, joint, target)]:
        q = bone.matrix.to_quaternion()
        y = q @ V(0, 1, 0)
        set_world(bone, head, y.rotation_difference((tip-head).normalized()) @ q)
    return target

def arm(side, target, pole):
    return two_bone(rig.pose.bones['upperarm_'+side], rig.pose.bones['lowerarm_'+side], rig.pose.bones['hand_'+side], target, pole)

def leg(side, target, pole):
    foot = rig.pose.bones['foot_'+side]
    keep = foot.matrix.to_quaternion()
    two_bone(rig.pose.bones['thigh_'+side], rig.pose.bones['calf_'+side], foot, target, pole)
    set_world(foot, foot.matrix.translation, keep)

def plant(crouch=0.0, forward=0.0, lead=None, lift=0.0):
    """Both feet kept where they stand (the lead foot `forward` and `lift`ed
    if a step is under way), the knees bent as the hips have dropped."""
    for s in 'lr':
        at = PLANTED[s].copy()
        if s == lead:
            at.y -= forward
            at.z += lift
        leg(s, at, KNEES[s]+V(0, -.6, 0))

def point_hand(side, blade, fingers):
    """Turns the hand so the blade in it runs along `blade` and the fingers
    point along `fingers` (the blade lies along the hand's own Z, the
    fingers along its Y)."""
    hand = rig.pose.bones['hand_'+side]
    z = Vector(blade).normalized()
    y = Vector(fingers)
    y = (y-z*y.dot(z)).normalized()
    x = y.cross(z)
    basis = Matrix((x, y, z)).transposed()
    set_world(hand, hand.matrix.translation, basis.to_quaternion())

def sword(target, pole, blade, fingers=None):
    """The sword arm reaching to `target` with the blade pointed along `blade`."""
    at = arm('r', target, pole)
    if fingers is None:
        fore = rig.pose.bones['lowerarm_r']
        fingers = fore.matrix.to_quaternion() @ V(0, 1, 0)
    point_hand('r', blade, fingers)
    return at

def hips(down=0.0, forward=0.0, aside=0.0):
    shift('pelvis', V(aside, -forward, -down))

def guard(forward=0.0, out=0.0, up=0.0):
    """The shield arm: the stance's guard, carried `forward`, `out` to the
    left and `up` from where it rests."""
    chest = rig.pose.bones['spine_03'].matrix
    arm('l', chest @ (GUARD_HAND+V(out, -forward, up)), chest @ GUARD_POLE)

reset()
chest0 = rig.pose.bones['spine_03'].matrix.copy()
GUARD_HAND = chest0.inverted() @ rig.pose.bones['hand_l'].head
GUARD_POLE = chest0.inverted() @ V(.65, -.45, 1.0)
SWORD_HOME = rig.pose.bones['hand_r'].head.copy()
SWORD_POLE = V(-.75, .1, .9)

def settle(t, into=.12, out=.86):
    """How far the pose is eased toward the stance at the clip's ends."""
    return max(ease(1-t/into), ease((t-out)/(1-out)))

def author(name, pose):
    length = CLIPS[name]
    a = bpy.data.actions.new(name)
    rig.animation_data.action = a
    frames = int(round(length*30))
    for f in range(frames+1):
        t = f/frames
        reset()
        pose(t)
        w = settle(t)
        if w > 0:
            for b in rig.pose.bones: b.matrix_basis = blend(b.matrix_basis, BASE[b.name], w)
            update()
        keys(f)
    finish(name, a, length)

# ---- The clips ----

def cleave(t):
    # Wound back to the right and swept level across to the left, the body
    # turning with it; the shield swings the other way to balance.
    turn = sample([(0, 0), (.3, -.55), (.42, -.5), (.6, .6), (.78, .55), (1, 0)], t)
    hips(down=sample([(0, 0), (.4, .05), (.6, .08), (1, 0)], t))
    rotate('pelvis', (0, 0, 1), turn*.4)
    rotate('spine_01', (0, 0, 1), turn*.35)
    rotate('spine_02', (0, 0, 1), turn*.3)
    rotate('spine_03', (1, 0, 0), sample([(0, 0), (.4, -.05), (.6, .15), (1, 0)], t))
    rotate('neck_01', (0, 0, 1), -turn*.5)
    hand = vsample([(0, SWORD_HOME), (.3, V(-.62, .3, 1.3)), (.42, V(-.7, .15, 1.25)), (.52, V(-.3, -.6, 1.15)), (.6, V(.3, -.55, 1.1)), (.75, V(.5, -.1, 1.05)), (1, SWORD_HOME)], t)
    blade = vsample([(0, V(-.2, -1, .3)), (.3, V(-.6, .6, .5)), (.42, V(-.7, .7, .1)), (.52, V(-.2, -1, 0)), (.6, V(.8, -.6, 0)), (.75, V(.9, .2, .2)), (1, V(-.2, -1, .3))], t)
    sword(hand, V(-.8, .3, .9), blade)
    guard(out=sample([(0, 0), (.4, .12), (.6, -.1), (1, 0)], t), forward=sample([(0, 0), (.5, .12), (1, 0)], t))
    plant()

def strike(t):
    # Raised high overhead, then brought straight down with a bend of the
    # whole body behind it, and lifted back.
    up = sample([(0, 0), (.32, 1), (.42, 1), (1, 0)], t)
    chop = sample([(0, 0), (.42, 0), (.55, 1), (.72, 1), (1, 0)], t)
    hips(down=.04*up+.1*chop, forward=.06*chop)
    rotate('spine_01', (1, 0, 0), -.12*up+.3*chop)
    rotate('spine_02', (1, 0, 0), -.1*up+.25*chop)
    rotate('spine_03', (1, 0, 0), .15*chop)
    rotate('Head', (1, 0, 0), .15*up-.1*chop)
    hand = vsample([(0, SWORD_HOME), (.32, V(-.18, .12, 1.95)), (.42, V(-.15, .05, 2.0)), (.55, V(-.22, -.72, .95)), (.72, V(-.24, -.7, .9)), (1, SWORD_HOME)], t)
    blade = vsample([(0, V(-.2, -1, .3)), (.32, V(0, .6, 1)), (.42, V(0, .4, 1)), (.55, V(0, -.8, -.6)), (.72, V(0, -.8, -.6)), (1, V(-.2, -1, .3))], t)
    sword(hand, V(-.8, -.1, 1.6) if t < .5 else V(-.8, -.2, 1.0), blade)
    guard(up=-.06*chop)
    plant()

def stab(t):
    # Drawn back to the hip and driven forward with a lunge of the hips.
    back = sample([(0, 0), (.3, 1), (.4, 1), (.55, 0), (1, 0)], t)
    thrust = sample([(0, 0), (.4, 0), (.52, 1), (.66, 1), (1, 0)], t)
    hips(forward=.14*thrust-.03*back, down=.05*thrust)
    rotate('pelvis', (0, 0, 1), .25*back-.3*thrust)
    rotate('spine_01', (0, 0, 1), .2*back-.25*thrust)
    rotate('spine_02', (1, 0, 0), .18*thrust)
    hand = vsample([(0, SWORD_HOME), (.3, V(-.32, .28, 1.0)), (.4, V(-.33, .3, 1.0)), (.52, V(-.08, -.9, 1.12)), (.66, V(-.08, -.88, 1.1)), (1, SWORD_HOME)], t)
    sword(hand, V(-.8, .15, .9), V(0, -1, .05))
    guard(out=.08*thrust, forward=-.05*thrust)
    plant(lead='l', forward=.3*thrust)

def bash(t):
    # The shield drawn in to the chest and shoved out behind a step of the
    # left foot, the shoulder behind it; the sword hangs back and clear.
    draw = sample([(0, 0), (.28, 1), (.38, 1), (.5, 0), (1, 0)], t)
    shove = sample([(0, 0), (.38, 0), (.5, 1), (.64, 1), (1, 0)], t)
    hips(forward=.16*shove, down=.06*shove)
    rotate('pelvis', (0, 0, 1), -.2*draw+.35*shove)
    rotate('spine_01', (0, 0, 1), -.15*draw+.3*shove)
    rotate('spine_02', (1, 0, 0), .2*shove)
    guard(forward=-.1*draw+.45*shove, out=.05*draw-.05*shove, up=.05*shove)
    sword(V(-.42, .25, 1.0), V(-.85, .3, .9), V(-.3, -.8, -.2))
    plant(lead='l', forward=.35*shove, lift=.08*math.sin(math.pi*sample([(0, 0), (.38, 0), (.56, 1), (1, 1)], t)))

def execute(t):
    # The blade carried far back over the shoulder as the body arches, then
    # the whole body thrown down behind it to the knees, and a slow recovery.
    wind = sample([(0, 0), (.36, 1), (.46, 1), (1, 0)], t)
    fall = sample([(0, 0), (.46, 0), (.58, 1), (.78, 1), (1, 0)], t)
    hips(down=.06*wind+.22*fall, forward=.1*fall)
    rotate('pelvis', (1, 0, 0), -.1*wind+.2*fall)
    rotate('spine_01', (1, 0, 0), -.22*wind+.4*fall)
    rotate('spine_02', (1, 0, 0), -.18*wind+.35*fall)
    rotate('spine_03', (1, 0, 0), -.1*wind+.2*fall)
    rotate('pelvis', (0, 0, 1), -.3*wind+.2*fall)
    rotate('Head', (1, 0, 0), .2*wind-.2*fall)
    hand = vsample([(0, SWORD_HOME), (.36, V(-.3, .45, 1.9)), (.46, V(-.3, .5, 1.95)), (.58, V(-.15, -.7, .6)), (.78, V(-.15, -.65, .55)), (1, SWORD_HOME)], t)
    blade = vsample([(0, V(-.2, -1, .3)), (.36, V(-.2, .9, .6)), (.46, V(-.2, .9, .5)), (.58, V(0, -.7, -.75)), (.78, V(0, -.7, -.75)), (1, V(-.2, -1, .3))], t)
    sword(hand, V(-.85, .2, 1.4) if t < .52 else V(-.8, -.3, .9), blade)
    guard(up=.08*wind-.12*fall, out=.06*fall)
    plant()

def slam(t):
    # The blade swung high over the head as the body arches back and rises
    # onto its toes, then the whole body hurled down behind it: the lead foot
    # driven forward, the hips dropped, the back folded, the blade rammed
    # point-first into the ground ahead; held there, and a slow rise.
    up = sample([(0, 0), (.26, 1), (.36, 1), (1, 0)], t)
    down = sample([(0, 0), (.36, 0), (.46, 1), (.7, 1), (1, 0)], t)
    hips(down=-.03*up+.5*down, forward=-.08*up+.22*down)
    rotate('pelvis', (1, 0, 0), -.15*up+.35*down)
    rotate('spine_01', (1, 0, 0), -.3*up+.55*down)
    rotate('spine_02', (1, 0, 0), -.2*up+.4*down)
    rotate('spine_03', (1, 0, 0), -.1*up+.25*down)
    rotate('neck_01', (1, 0, 0), -.15*up+.1*down)
    rotate('Head', (1, 0, 0), .2*up-.2*down)
    hand = vsample([(0, SWORD_HOME), (.26, V(-.2, .35, 2.15)), (.36, V(-.2, .4, 2.2)), (.46, V(-.18, -1.05, .2)), (.7, V(-.18, -1.02, .16)), (1, SWORD_HOME)], t)
    blade = vsample([(0, V(-.2, -1, .3)), (.26, V(0, .7, .8)), (.36, V(0, .8, .6)), (.46, V(0, -.3, -1)), (.7, V(0, -.3, -1)), (1, V(-.2, -1, .3))], t)
    sword(hand, V(-.9, .1, 1.6) if t < .42 else V(-.9, -.4, .9), blade)
    # Both hands to the hilt for the blow: the shield arm comes across.
    guard(forward=-.08*up+.3*down, out=-.12*down, up=.25*up-.2*down)
    plant(lead='l', forward=.55*down, lift=.14*math.sin(math.pi*sample([(0, 0), (.32, 0), (.5, 1), (1, 1)], t)))

def leap(t):
    # A deep crouch, the arms swung back; the spring, the body stretched and
    # the blade carried up over the head in the air; the landing, driven
    # down with everything: the hips to the heels, the back folded, the
    # blade hammered into the ground; then the slow rise.
    crouch = sample([(0, 0), (.12, 1), (.2, 1), (.28, 0), (1, 0)], t)
    air = sample([(0, 0), (.2, 0), (.3, 1), (.46, 1), (.56, 0), (1, 0)], t)
    land = sample([(0, 0), (.48, 0), (.57, 1), (.76, 1), (1, 0)], t)
    hips(down=.32*crouch-.05*air+.5*land, forward=-.05*crouch+.1*air+.18*land)
    rotate('pelvis', (1, 0, 0), .2*crouch-.1*air+.3*land)
    rotate('spine_01', (1, 0, 0), .4*crouch-.3*air+.4*land)
    rotate('spine_02', (1, 0, 0), .25*crouch-.2*air+.25*land)
    rotate('spine_03', (1, 0, 0), .1*crouch-.1*air+.12*land)
    rotate('Head', (1, 0, 0), -.3*crouch+.25*air-.3*land)
    hand = vsample([(0, SWORD_HOME), (.12, V(-.5, .45, .75)), (.2, V(-.5, .45, .72)), (.3, V(-.25, .3, 2.1)), (.46, V(-.2, .25, 2.2)), (.57, V(-.18, -.95, .18)), (.76, V(-.18, -.92, .14)), (1, SWORD_HOME)], t)
    blade = vsample([(0, V(-.2, -1, .3)), (.12, V(-.2, .9, -.3)), (.2, V(-.2, .9, -.3)), (.3, V(0, .6, .8)), (.46, V(0, .7, .7)), (.57, V(0, -.3, -1)), (.76, V(0, -.3, -1)), (1, V(-.2, -1, .3))], t)
    sword(hand, V(-.9, .4, 1.1) if t < .25 else (V(-.9, .1, 1.7) if t < .52 else V(-.9, -.4, .9)), blade)
    guard(up=-.1*crouch+.3*air-.05*land, out=.15*crouch+.1*air+.15*land, forward=-.15*crouch+.1*air+.2*land)
    if air > 0:
        # Legs drawn up beneath him in the air.
        for s in 'lr': leg(s, PLANTED[s]+V(0, -.1*air, .5*air), KNEES[s]+V(0, -.8, .3))
    else: plant(lead='l', forward=.3*land)

def shockwave(t):
    # A deep crouch, the sword raised with it, and the pommel hammered down
    # between the feet; the shield arm flung out for balance.
    up = sample([(0, 0), (.3, 1), (.44, 1), (1, 0)], t)
    down = sample([(0, 0), (.44, 0), (.56, 1), (.76, 1), (1, 0)], t)
    hips(down=.1*up+.42*down, forward=.02*down)
    rotate('spine_01', (1, 0, 0), -.1*up+.5*down)
    rotate('spine_02', (1, 0, 0), -.1*up+.3*down)
    rotate('spine_03', (1, 0, 0), .15*down)
    rotate('Head', (1, 0, 0), .15*up-.25*down)
    hand = vsample([(0, SWORD_HOME), (.3, V(-.25, .15, 1.95)), (.44, V(-.25, .1, 2.0)), (.56, V(-.3, -.42, .3)), (.76, V(-.3, -.4, .26)), (1, SWORD_HOME)], t)
    blade = vsample([(0, V(-.2, -1, .3)), (.3, V(0, .5, 1)), (.44, V(0, .45, 1)), (.56, V(0, -.3, 1)), (.76, V(0, -.3, 1)), (1, V(-.2, -1, .3))], t)
    sword(hand, V(-.85, 0, 1.5) if t < .5 else V(-.85, -.1, .7), blade)
    guard(out=.3*down, up=.05*down, forward=-.05*down)
    plant()

def cry(t):
    # The blade thrust straight up, the shield flung wide, the chest out and
    # the head thrown back in a shout; held, then lowered.
    up = sample([(0, 0), (.3, 1), (.7, 1), (1, 0)], t)
    hips(forward=.03*up)
    rotate('spine_01', (1, 0, 0), -.12*up)
    rotate('spine_02', (1, 0, 0), -.15*up)
    rotate('spine_03', (1, 0, 0), -.1*up)
    rotate('neck_01', (1, 0, 0), -.2*up)
    rotate('Head', (1, 0, 0), -.3*up)
    hand = vsample([(0, SWORD_HOME), (.3, V(-.3, -.1, 2.1)), (.7, V(-.32, -.08, 2.12)), (1, SWORD_HOME)], t)
    blade = vsample([(0, V(-.2, -1, .3)), (.3, V(-.05, -.05, 1)), (.7, V(-.05, -.05, 1)), (1, V(-.2, -1, .3))], t)
    sword(hand, V(-.9, 0, 1.4), blade)
    guard(out=.3*up, up=.12*up, forward=-.08*up)
    plant()

def charge(t):
    # The sprint itself, the shield held out before him and the sword kept
    # back; the run eases in from the stance and out to it.
    running = sample([(0, 0), (.12, 1), (.86, 1), (1, 0)], t)
    cycle = RUN[int(round((t*2.5 % 1.0)*60))]
    for b in rig.pose.bones:
        if not b.name.startswith(('clavicle', 'upperarm', 'lowerarm', 'hand', 'thumb', 'index', 'middle', 'ring', 'pinky')): b.matrix_basis = blend(b.matrix_basis, cycle[b.name], running)
    update()
    rotate('spine_02', (1, 0, 0), .15*running)
    # The shield arm straight out before the chest, the board square to
    # the way he runs; the sword arm kept back.
    chest = rig.pose.bones['spine_03'].matrix
    held = chest @ (GUARD_HAND+V(-.02, -.34, .1))
    arm('l', V(.14, -.62, 1.22)*running+held*(1-running), V(.55, -.3, .95))
    sword(V(-.42, .25, 1.0), V(-.85, .3, .9), V(-.3, -.8, -.25))

for name, pose in [('SkillCleave', cleave), ('SkillStrike', strike), ('SkillStab', stab), ('SkillBash', bash), ('SkillExecute', execute),
        ('SkillSlam', slam), ('SkillShockwave', shockwave), ('SkillCry', cry), ('SkillCharge', charge), ('SkillLeap', leap)]:
    author(name, pose)

rig.animation_data.action = None
for track in rig.animation_data.nla_tracks: track.mute = False
used = {s.action for t in rig.animation_data.nla_tracks for s in t.strips}
for a in list(bpy.data.actions):
    if a not in used: bpy.data.actions.remove(a)
bpy.context.scene.frame_set(0)
bpy.ops.export_scene.gltf(filepath=str(OUT/'warrior.glb'), export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS', export_force_sampling=True)
print('SKILL_ANIMATIONS_READY', len(rig.animation_data.nla_tracks))
