"""Authors the ranger's own clips onto the supplied rig (after
import_character.py, import_combat.py, import_walk.py and import_skills.py;
safe to rerun).

The ranger fights with a bow and a dagger. The dagger's motions are keyed here
frame by frame, as the warrior's skill swings are (tools/import_skills.py):
the hips, spine and head turned along smooth curves, the dagger arm carried
by two-bone IK with the fist turned so the blade runs where the motion sends
it, the feet kept planted by leg IK, each eased out of the stance and back.

  DaggerStab        the normal attack: drawn back to the hip and driven in
  DaggerSlash       and, by turns with it, a cut down across the body
  SkillFlurry2/3/4  Flurry: that many stabs, high and low, one on another
  SkillTripleSlash  three cuts: down across, back across, and down from above
  SkillAmbush       Surprise Attack: the fist brought down hard from on high
  SkillSandR/L      Throw Sand: a stoop for a handful and a fling of it, with
                    the hand that holds no weapon (right with the bow, left
                    with the dagger)
  SkillHide         Hide in Shadows: down into a crouch
  SneakIdle         waiting, crouched, while hidden
  SkillVolley       the archer's shot, loosed high into the air

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/import_ranger.py
"""
from pathlib import Path
import math
import bpy
from mathutils import Vector, Matrix, Quaternion
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/models/character'
# Flurry's stabs (scripts/combat_animation.gd keeps the same times).
FLURRY_LEAD = .18
FLURRY_STAB = .22
FLURRY_END = .3
CLIPS = ['DaggerStab', 'DaggerSlash', 'SkillFlurry2', 'SkillFlurry3', 'SkillFlurry4', 'SkillTripleSlash', 'SkillAmbush', 'SkillSandR', 'SkillSandL',
    'SkillHide', 'SneakIdle', 'SkillVolley']
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

def pose_of(action, time=0.0):
    rig.animation_data.action = bpy.data.actions[action]
    frame(time)
    pose = {b.name: b.matrix_basis.copy() for b in rig.pose.bones}
    rig.animation_data.action = None
    return pose

# The stances the clips start from and return to: the plain idle (the dagger
# in the right hand), the ranger's (the bow carried in the left), and the
# crouch he hides in.
IDLE = pose_of('Idle')
CARRY = pose_of('RangerIdle')
SNEAK = pose_of('RangerCrouch')
BASE = IDLE

def apply(pose):
    for b in rig.pose.bones: b.matrix_basis = pose[b.name]
    update()

def reset():
    apply(BASE)

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
    print('RANGER_CLIP', name, round(length, 3))

def ease(u):
    u = max(0.0, min(1.0, u))
    return u*u*(3-2*u)

def sample(points, t):
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
    b = rig.pose.bones[name]
    m = b.matrix.copy()
    set_world(b, m.translation, Quaternion(Vector(axis), angle) @ m.to_quaternion())

def shift(name, by):
    b = rig.pose.bones[name]
    m = b.matrix.copy()
    set_world(b, m.translation+Vector(by), m.to_quaternion())

def two_bone(upper, lower, end, target, pole):
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

apply(IDLE)
PLANTED = {s: rig.pose.bones['foot_'+s].matrix.translation.copy() for s in 'lr'}
KNEES = {s: rig.pose.bones['calf_'+s].matrix.translation.copy() for s in 'lr'}
HOME = rig.pose.bones['hand_r'].head.copy()
HOME_L = rig.pose.bones['hand_l'].head.copy()
HOME_BLADE = (rig.pose.bones['hand_r'].matrix.to_quaternion() @ V(0, 0, 1)).normalized()
print('RANGER_HOME', [round(v, 2) for v in HOME], [round(v, 2) for v in HOME_BLADE], [round(v, 2) for v in HOME_L])

def plant(forward=0.0, lead=None, lift=0.0):
    """Both feet kept where they stand (the lead foot `forward` and `lift`ed
    if a step is under way), the knees bent as the hips have dropped."""
    for s in 'lr':
        at = PLANTED[s].copy()
        if s == lead:
            at.y -= forward
            at.z += lift
        leg(s, at, KNEES[s]+V(0, -.6, 0))

def hips(down=0.0, forward=0.0):
    shift('pelvis', V(0, -forward, -down))

def turn(angle, lean=0.0):
    """The body turned (to the left) through the hips and spine, the head
    kept on the target, and bent forward."""
    rotate('pelvis', (0, 0, 1), angle*.4)
    rotate('spine_01', (0, 0, 1), angle*.35)
    rotate('spine_02', (0, 0, 1), angle*.3)
    rotate('neck_01', (0, 0, 1), -angle*.5)
    if lean:
        rotate('spine_01', (1, 0, 0), lean*.5)
        rotate('spine_02', (1, 0, 0), lean*.5)
        rotate('Head', (1, 0, 0), -lean*.6)

# How far the dagger hand's wrist may bend sideways from the forearm's line.
WRIST_BEND = math.radians(48)

def dagger(target, pole, blade):
    """The dagger arm reaching to `target`, the blade pointed along `blade`
    as nearly as the wrist allows."""
    arm('r', target, pole)
    fore = rig.pose.bones['lowerarm_r'].matrix.to_quaternion() @ V(0, 1, 0)
    z = Vector(blade).normalized()
    across = z-fore*z.dot(fore)
    if across.length > 1e-4:
        across.normalize()
        angle = max(math.pi/2-WRIST_BEND, min(math.pi/2+WRIST_BEND, fore.angle(z)))
        z = fore*math.cos(angle)+across*math.sin(angle)
    y = (fore-z*fore.dot(z)).normalized()
    x = y.cross(z)
    hand = rig.pose.bones['hand_r']
    set_world(hand, hand.matrix.translation, Matrix((x, y, z)).transposed().to_quaternion())

def author(name, length, pose, base=None, into=.12, out=.86, loop=False):
    global BASE
    BASE = base or IDLE
    a = bpy.data.actions.new(name)
    rig.animation_data.action = a
    frames = int(round(length*30))
    for f in range(frames+1):
        t = f/frames
        reset()
        pose(t)
        w = 0.0 if loop else max(ease(1-t/into) if into > 0 else 0.0, ease((t-out)/(1-out)) if out < 1 else 0.0)
        if w > 0:
            for b in rig.pose.bones: b.matrix_basis = blend(b.matrix_basis, BASE[b.name], w)
            update()
        keys(f)
    finish(name, a, length)

POLE = V(-.8, .2, .9)
READY = (-.3, .2, 1.05)

# ---- The dagger ----

def stab(t):
    back = sample([(0, 0), (.24, 1), (.32, 1), (.45, 0), (1, 0)], t)
    thrust = sample([(0, 0), (.32, 0), (.45, 1), (.6, 1), (1, 0)], t)
    hips(forward=.12*thrust-.03*back, down=.05*thrust)
    turn(-.3*back+.4*thrust, .2*thrust)
    hand = vsample([(0, HOME), (.24, (-.32, .22, 1.05)), (.32, (-.33, .24, 1.05)), (.45, (-.1, -.62, 1.15)), (.6, (-.1, -.6, 1.15)), (1, HOME)], t)
    blade = vsample([(0, HOME_BLADE), (.24, (0, -1, .15)), (.6, (.03, -1, .2)), (1, HOME_BLADE)], t)
    dagger(hand, V(-.9, .3, 1.2), blade)
    plant(lead='l', forward=.22*thrust, lift=.05*math.sin(math.pi*sample([(0, 0), (.3, 0), (.46, 1), (1, 1)], t)))

def slash(t):
    wind = sample([(0, 0), (.26, 1), (.32, 1), (.5, 0), (1, 0)], t)
    cut = sample([(0, 0), (.32, 0), (.5, 1), (.66, 1), (1, 0)], t)
    hips(forward=.08*cut, down=.03*wind+.08*cut)
    turn(-.45*wind+.55*cut, -.05*wind+.25*cut)
    hand = vsample([(0, HOME), (.26, (-.34, .14, 1.62)), (.32, (-.35, .16, 1.62)), (.42, (-.14, -.5, 1.3)), (.5, (.12, -.42, .98)), (.66, (.14, -.4, .98)), (1, HOME)], t)
    blade = vsample([(0, HOME_BLADE), (.26, (-.3, .6, .7)), (.32, (-.3, .7, .6)), (.42, (.15, -.8, .55)), (.5, (.75, -.6, 0)), (.66, (.78, -.55, .05)), (1, HOME_BLADE)], t)
    dagger(hand, vsample([(0, POLE), (.3, (-.9, .4, 1.5)), (.5, (-.8, -.3, 1.0)), (1, POLE)], t), blade)
    plant(lead='l', forward=.18*cut, lift=.04*math.sin(math.pi*sample([(0, 0), (.3, 0), (.5, 1), (1, 1)], t)))

def flurry(count):
    length = FLURRY_LEAD+FLURRY_STAB*(count-1)+FLURRY_END
    hand_keys = [(0, HOME), ((FLURRY_LEAD-.11)/length, READY)]
    blade_keys = [(0, HOME_BLADE), ((FLURRY_LEAD-.11)/length, (0, -1, .15))]
    body_keys = [(0, 0)]
    for i in range(count):
        at = FLURRY_LEAD+FLURRY_STAB*i
        height = 1.32 if i % 2 == 0 else 1.02
        aside = -.14 if i % 2 == 0 else -.04
        hand_keys.append((at/length, (aside, -.66, height)))
        hand_keys.append(((at+.04)/length, (aside, -.64, height)))
        blade_keys.append((at/length, (.02, -1, .22 if i % 2 == 0 else .08)))
        body_keys.append((at/length, 1))
        if i < count-1:
            hand_keys.append(((at+.13)/length, (-.3, .12, 1.12)))
            body_keys.append(((at+.13)/length, .35))
    hand_keys.append((1, HOME))
    blade_keys.append((1, HOME_BLADE))
    body_keys.append((1, 0))
    def pose(t):
        drive = sample(body_keys, t)
        lean = sample([(0, 0), (FLURRY_LEAD/length, 1), (1-FLURRY_END*.7/length, 1), (1, 0)], t)
        hips(forward=.1*lean+.04*drive, down=.07*lean)
        turn(.1*lean+.3*drive-.1, .22*lean)
        dagger(vsample(hand_keys, t), V(-.9, .3, 1.15), vsample(blade_keys, t))
        plant(lead='l', forward=.24*lean)
    author('SkillFlurry%d' % count, length, pose, into=.1, out=1-FLURRY_END*.75/length)

def triple(t):
    twist = sample([(0, 0), (.1, -.45), (.22, .3), (.3, .55), (.4, .5), (.5, 0), (.58, -.45), (.68, -.3), (.78, .25), (.86, .35), (1, 0)], t)
    lean = sample([(0, 0), (.1, -.05), (.3, .25), (.4, .1), (.58, .2), (.68, -.1), (.86, .4), (1, 0)], t)
    hips(forward=sample([(0, 0), (.22, .08), (.5, .1), (.78, .14), (.9, .1), (1, 0)], t), down=sample([(0, 0), (.3, .1), (.4, .04), (.58, .08), (.68, 0), (.86, .16), (1, 0)], t))
    turn(twist, lean)
    hand = vsample([(0, HOME), (.1, (-.34, .14, 1.62)), (.22, (-.12, -.52, 1.3)), (.3, (.14, -.4, .98)), (.4, (.2, -.3, 1.38)), (.5, (-.06, -.58, 1.25)),
        (.58, (-.46, -.08, 1.05)), (.68, (-.24, .06, 1.8)), (.78, (-.1, -.58, 1.32)), (.86, (-.06, -.5, .86)), (1, HOME)], t)
    blade = vsample([(0, HOME_BLADE), (.1, (-.3, .7, .6)), (.22, (.15, -.8, .55)), (.3, (.78, -.55, 0)), (.4, (.6, .1, .75)), (.5, (-.15, -.85, .45)),
        (.58, (-.8, -.5, 0)), (.68, (-.1, .55, .8)), (.78, (0, -.8, .6)), (.86, (.05, -.9, -.4)), (1, HOME_BLADE)], t)
    pole = vsample([(0, POLE), (.1, (-.9, .4, 1.5)), (.3, (-.8, -.3, 1.0)), (.4, (-.6, -.7, 1.1)), (.58, (-.9, .5, 1.2)), (.68, (-.9, .2, 1.6)), (.86, (-.9, -.2, 1.0)), (1, POLE)], t)
    dagger(hand, pole, blade)
    plant(lead='l', forward=sample([(0, 0), (.22, .16), (.78, .22), (.9, .2), (1, 0)], t))

def ambush(t):
    up = sample([(0, 0), (.3, 1), (.38, 1), (.5, 0), (1, 0)], t)
    down = sample([(0, 0), (.38, 0), (.5, 1), (.68, 1), (1, 0)], t)
    hips(forward=-.04*up+.16*down, down=-.02*up+.14*down)
    turn(-.35*up+.4*down, -.12*up+.38*down)
    hand = vsample([(0, HOME), (.3, (-.26, .1, 1.92)), (.38, (-.26, .12, 1.94)), (.5, (-.1, -.6, 1.3)), (.68, (-.1, -.58, 1.26)), (1, HOME)], t)
    blade = vsample([(0, HOME_BLADE), (.3, (0, .3, 1)), (.38, (0, .35, 1)), (.5, (0, -.55, .85)), (.68, (0, -.55, .85)), (1, HOME_BLADE)], t)
    dagger(hand, V(-.9, 0, 1.5), blade)
    plant(lead='l', forward=.3*down, lift=.07*math.sin(math.pi*sample([(0, 0), (.36, 0), (.52, 1), (1, 1)], t)))

def sand(side):
    sign = -1.0 if side == 'r' else 1.0
    home = HOME if side == 'r' else HOME_L
    def pose(t):
        stoop = sample([(0, 0), (.28, 1), (.36, 1), (.55, .2), (1, 0)], t)
        fling = sample([(0, 0), (.36, 0), (.55, 1), (.72, 1), (1, 0)], t)
        hips(down=.36*stoop+.04*fling, forward=.04*stoop+.1*fling)
        turn(sign*(.3*stoop-.45*fling), .55*stoop+.12*fling)
        hand = vsample([(0, home), (.28, (sign*.3, -.28, .22)), (.36, (sign*.3, -.3, .2)), (.48, (sign*.3, -.5, 1.0)), (.55, (sign*.14, -.72, 1.4)),
            (.72, (-sign*.1, -.62, 1.5)), (1, home)], t)
        arm(side, hand, V(sign*.9, .2, .9) if t < .42 else V(sign*.8, -.2, 1.0))
        plant(lead='l', forward=.12*fling)
    author('SkillSand'+side.upper(), .7, pose, base=CARRY if side == 'r' else IDLE)

def hide(t):
    w = ease(t)
    for b in rig.pose.bones: b.matrix_basis = blend(BASE[b.name], SNEAK[b.name], w)
    update()

def sneak(t):
    apply(SNEAK)
    rotate('spine_02', (1, 0, 0), .025*math.sin(2*math.pi*t))
    rotate('Head', (0, 0, 1), .12*math.sin(2*math.pi*t))

author('DaggerStab', 1.0, stab)
author('DaggerSlash', 1.0, slash)
for count in (2, 3, 4): flurry(count)
author('SkillTripleSlash', 2.0, triple)
author('SkillAmbush', 1.2, ambush)
sand('r')
sand('l')
author('SkillHide', .45, hide, base=CARRY, into=0, out=1)
author('SneakIdle', 3.0, sneak, loop=True)

# ---- Volley: the archer's shot, loosed high ----
shot = bpy.data.actions['ArcherShot']
span = shot.frame_range.y
a = bpy.data.actions.new('SkillVolley')
frames = int(round(span))
poses = []
rig.animation_data.action = shot
for f in range(frames+1):
    bpy.context.scene.frame_set(f)
    update()
    poses.append({b.name: b.matrix_basis.copy() for b in rig.pose.bones})
rig.animation_data.action = a
for f in range(frames+1):
    t = f/frames
    apply(poses[f])
    # The chest is tipped back (the arms and the bow with it) as he draws, and
    # comes level again after the arrows are away.
    tip = sample([(0, 0), (.3, 0), (.6, 1), (.84, 1), (1, 0)], t)
    for name in ('spine_01', 'spine_02', 'spine_03'): rotate(name, (1, 0, 0), -.17*tip)
    rotate('Head', (1, 0, 0), .12*tip)
    keys(f)
finish('SkillVolley', a, frames/30)

rig.animation_data.action = None
for track in rig.animation_data.nla_tracks: track.mute = False
used = {s.action for t in rig.animation_data.nla_tracks for s in t.strips}
for a in list(bpy.data.actions):
    if a not in used: bpy.data.actions.remove(a)
bpy.context.scene.frame_set(0)
bpy.ops.export_scene.gltf(filepath=str(OUT/'warrior.glb'), export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS', export_force_sampling=True)
print('RANGER_ANIMATIONS_READY', len(rig.animation_data.nla_tracks))
