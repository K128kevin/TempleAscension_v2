"""Authors the warrior's skill clips onto the supplied rig (after
import_character.py, import_combat.py and import_walk.py; safe to rerun).

Each of the warrior's skills has a swing of its own, keyed here frame by
frame from the sword-and-shield stance: the whole body moves through each
(hips, spine, head, both arms by two-bone IK, the feet kept planted by leg
IK), every value carried along smooth curves so nothing leaps between
frames, and each eases out of the stance and back into it. The sword hand's
turn is set outright at every frame, so the blade runs where the swing
sends it and never through the body or the shield (which the game keeps on
the left forearm). Through every swing the shield arm is held in the guard
the town's gate guards keep (guard, below): the forearm across the front of
the body, the fist before the belly, the board on it standing upright and
facing ahead; it is raised into that guard out of the stance (where the arm
hangs at his side) as the swing begins and lowered again as he recovers, and
with no shield on it the arm is held so all the same.

  SkillCleave     a backhand sweep from left to right behind a step
  SkillStrike     Powerful Strike: an overhead chop
  SkillStab       Vampiric Strike: a lunging thrust to the gut
  SkillBash       Shield Bash: a backhand blow of the shield behind a step
  SkillExecute    the blade raised far behind the head and brought down
                  with the whole body, to the knees
  SkillSlam       Thunder Slam, one circle on his right: the blade held
                  before the belly pointed ahead, swung down past the outside
                  of his right leg and back behind him as the arm drops and
                  swings back with the chest turned to it, up behind him, over
                  the head as the body arches, and down before him, the whole
                  body hurled forward and down, the blade brought down level
                  on the ground
  DualSkillSlam   the same with a weapon in each hand: both arms swung out
                  and over the head together, both slammed down
  SkillShockwave  Shockwave: a violent stomp, stepping forward into it
  SkillCry        War Cry: blade thrust at the sky, shield flung wide, head
                  back
  SkillCharge     Shield Charge: the sprint, with the shield held out before
                  him
  SkillLeap       Leap: the crouch, the spring, the tuck and the landing
                  blow

The warrior's normal attack is keyed here too: three swings that run on
into one another for as long as he keeps attacking (a cut down from the
upper right to the lower left, a backhand cut down from the upper left to
the lower right, and a thrust), each stepping him forward. They are one
unbroken cycle of motion, cut into a clip a swing; each clip ends with a
recovery to the stance, played only if he swings no more.

He walks into his target as he swings: each swing is struck on a full step
of the rear foot past the front one, so the feet alternate from swing to
swing, and each of the three is keyed stepping with either foot.

  SwordOpen       the first cut, wound up out of the stance (right foot)
  SwordCut1R/L    the same cut, following on from the thrust
  SwordCut2R/L    the backhand cut, following on from the first
  SwordThrustR/L  the thrust, following on from the backhand

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/import_skills.py

  HERO_GLB=/path/to/warrior.glb  the model to read and write back
                             (default assets/models/character/warrior.glb)
  SKILLS_ONLY=SkillSlam,...  author only those skills again (the rest keep
                             their clips); SWINGS_ONLY=1 only the attack cycle
  SKILLS_DRY=1               author and check, but write nothing back
  SHEET_DIR=/path            render each skill authored as a contact sheet
                             there (tools/blender_sheet.py; implies
                             SKILLS_DRY), at the moments SHEET_PHASES lists
"""
from pathlib import Path
import json, math, os, struct, sys
import bpy
from mathutils import Vector, Matrix, Quaternion
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
import blender_sheet as sheet
import blender_arm as held
SHEET_DIR = os.environ.get('SHEET_DIR', '')
SHEET_PHASES = [float(v) for v in os.environ.get('SHEET_PHASES', '0,.08,.16,.24,.32,.4,.46,.52,.58,.62,.66,.75,.9,1').split(',')]
DRY = bool(os.environ.get('SKILLS_DRY')) or bool(SHEET_DIR)
GLB = Path(os.environ.get('HERO_GLB') or ROOT/'assets/models/character/warrior.glb')
if not GLB.is_absolute(): GLB = ROOT/GLB
# name: seconds
CLIPS = {'SkillCleave': 1.0, 'SkillStrike': 1.0, 'SkillStab': .9, 'SkillBash': .9, 'SkillExecute': 1.3, 'SkillSlam': 1.6,
    'SkillShockwave': 1.2, 'SkillCry': 1.0, 'SkillCharge': 1.0, 'SkillLeap': 1.0, 'DualSkillSlam': 1.6}

def clip_starts(path):
    """When each clip in a GLB file has its first key (seconds)."""
    with open(path, 'rb') as f:
        f.read(12)
        size, kind = struct.unpack('<II', f.read(8))
        document = json.loads(f.read(size))
    return {a.get('name', ''): min(document['accessors'][s['input']]['min'][0] for s in a['samplers']) for a in document.get('animations', [])}

BEGAN = clip_starts(GLB)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=str(GLB))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
# (The stand-in for the sheets: a sword's blade from the fist, with the
# length the game's checks use.)
if SHEET_DIR: sheet.prop(rig, 'hand_r', (-.028, .085), [(0, 1.08, .011), (-.03, .03, .05)])
# The normal attack's swings (scripts/combat_animation.gd SWORD_CHAIN): each
# clip is SWING_SECONDS of swing and then TAIL_SECONDS of recovery, keyed at
# a quarter of the speed it is played at so the fast cuts are sampled closely.
SWINGS = ['SwordOpen']+[name+foot for name in ('SwordCut1', 'SwordCut2', 'SwordThrust') for foot in 'RL']
# (The first version's clips, one foot only.)
OLD_SWINGS = ['SwordCut1', 'SwordCut2', 'SwordThrust']
SWING_SECONDS = 3.2
TAIL_SECONDS = 1.6
# (SKILLS_ONLY=SkillSlam,...: only those skills are authored again; the
# rest keep their clips.)
ONLY = [n for n in os.environ.get('SKILLS_ONLY', '').split(',') if n]
REMADE = [n for n in CLIPS if not ONLY or n in ONLY or n == 'DualSkillSlam']
for track in list(rig.animation_data.nla_tracks):
    if track.name in REMADE or track.name in SWINGS+OLD_SWINGS: rig.animation_data.nla_tracks.remove(track)
for a in list(bpy.data.actions):
    if a.name in REMADE or a.name in SWINGS+OLD_SWINGS: bpy.data.actions.remove(a)
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
held.init(rig)
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
    held_guard[0] = None

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

def grip(side, target, pole, blade, fingers=None, swing=math.radians(150)):
    """An arm bent to `target` with the weapon in its fist pointed along
    `blade`, as an arm can be: the wrist bent no further than a wrist bends,
    the elbow swung round the arm's line from `pole` to where the forearm
    need not be wrung, and the forearm rolled after the fist
    (tools/blender_arm.py). Returns the blade's way as set."""
    chest = rig.pose.bones['spine_03'].matrix
    facing = (chest.to_quaternion() @ CHEST_FRONT).normalized()
    y, z, turned = held.fist(rig.pose.bones, side, lambda y: Vector(target), blade, fingers, pole, swing=swing, avoid=facing)
    return z

def hips(down=0.0, forward=0.0, aside=0.0):
    shift('pelvis', V(aside, -forward, -down))

# The shield arm's guard as the pose being keyed asked for it (guard's
# arguments; None where the pose holds the arm otherwise), and how far it is
# carried aside from there to let the sword by (YIELD, below), in the
# chest's frame.
held_guard = [None]
yielding = [Vector((0, 0, 0))]
# (How many times the fist is set to the elbow's height and the arm bent to
# it again: the elbow moves a little each time.)
LEVELLING = 3
# (Nor is the fist moved further than LEVEL_MOST to do it: bowed deep over
# a blow, the elbow falls so far that levelling would fold the arm shut.)
LEVEL_MOST = .12

def guard(forward=0.0, out=0.0, up=0.0, turn=0.0):
    """The shield arm in its guard, carried `forward`, `out` to the left and
    `up` from where the guard holds it (all in the chest's own frame, so it
    moves with the chest: the chest bone's X is its left, Y up the spine
    and Z its front), and aside as far as `yielding` says. The fist is then
    raised or lowered to the elbow's height (LEVEL_MOST at most), so the
    forearm lies level however he turns, bends or arches, and the board's
    face is turned the way the chest faces (and `turn` further round to the
    left) but kept level: the board strapped across the forearm stands
    upright, as the guards' does."""
    held_guard[0] = (forward, out, up, turn)
    chest = rig.pose.bones['spine_03'].matrix
    aside = yielding[0]
    asked = chest @ (GUARD_HAND+V(out, up, forward)+aside)
    pole = chest @ (GUARD_POLE+aside)
    target = asked
    for _ in range(LEVELLING):
        arm('l', target, pole)
        lift = target.z+rig.pose.bones['lowerarm_l'].head.z-rig.pose.bones['hand_l'].head.z-asked.z
        target = asked+V(0, 0, max(-LEVEL_MOST, min(LEVEL_MOST, lift)))
    arm('l', target, pole)
    front = chest.to_quaternion() @ CHEST_FRONT
    level = V(front.x, front.y, 0)
    if level.length > .3: front = Quaternion(V(0, 0, 1), turn) @ level.normalized()
    face_shield(front)

# The swings were made for an arm hanging at his side, and the sword's blade
# or the forearm that swings it can pass where the board now stands (loading
# the backhand at the left shoulder, drawing the thrust back along the flank
# with the chest turned away), as his head can where he bows over a blow.
# Where either would, the shield arm yields: the board is carried out, down,
# up or forward (one of YIELD_WAYS, in the chest's frame: the one that need
# move it least, keeping to the way it went a moment before where that
# serves nearly as well) as little as lets the sword by YIELD_MARGIN (at
# most YIELD_MOST); found at every moment, then spread to the moments either
# side (YIELD_REACH of a skill's frames, SWING_YIELD_REACH of the attack
# cycle's steps) and eased, so the board is moved aside beforehand and
# brought back after, never jerked. (The board as clearances() takes it: the
# round shield, scripts/visual.gd SHIELD_CENTER and SHIELD_SIZE.)
YIELD_MARGIN = .03
YIELD_MOST = .36
YIELD_STEP = .03
YIELD_WAYS = [V(1, 0, 0), V(0, -1, 0), V(.71, -.71, 0), V(0, 0, 1), V(.71, 0, .71), V(0, -.71, .71), V(.71, .71, 0), V(0, 1, 0)]
YIELD_REACH = 5
SWING_YIELD_REACH = 16
BOARD_MIDDLE = V(0, .14, -.135)
BOARD_RADIUS = .33
BOARD_HALF = .06
BLADE_RADIUS = .045
HEAD_RADIUS = .13

def board_gap():
    """How far the sword (its blade and the forearm that swings it) and the
    head (bowed over a blow) keep off the board (less than nothing: in it),
    and the point of them nearest the board's middle then."""
    B = rig.pose.bones
    hand = B['hand_r'].matrix
    board = B['lowerarm_l'].matrix
    centre = board @ BOARD_MIDDLE
    normal = (board.to_quaternion() @ V(0, 0, 1)).normalized()
    top = B['Head'].head+(B['Head'].matrix.to_quaternion() @ V(0, 1, 0))*HEAD_RADIUS
    worst, at = 9.0, centre
    for a, b, r in ((hand @ V(0, .075, 0), hand @ V(0, .075, 1.08), BLADE_RADIUS), (B['lowerarm_r'].head.copy(), B['hand_r'].head.copy(), BLADE_RADIUS), (top, top, HEAD_RADIUS)):
        for i in range(25):
            p = a.lerp(b, i/24)
            d = p-centre
            axial = d.dot(normal)
            gap = max(abs(axial)-BOARD_HALF-r, (d-normal*axial).length-BOARD_RADIUS-r)
            if gap < worst: worst, at = gap, p
    return worst, at, centre, normal

def needed_yield(before=None):
    """How far the shield arm, as the pose has just set it, must be carried
    aside (in the chest's frame) to let the sword by; `before`, the yield of
    the moment before, whose way is kept if it serves nearly as well."""
    if held_guard[0] is None or board_gap()[0] >= YIELD_MARGIN: return V(0, 0, 0)
    asked, kept = held_guard[0], yielding[0]
    def least(way):
        """The least carry along `way` that clears the sword (or None)."""
        for k in range(1, int(round(YIELD_MOST/YIELD_STEP))+1):
            yielding[0] = way*(YIELD_STEP*k)
            guard(*asked)
            if board_gap()[0] >= YIELD_MARGIN: return YIELD_STEP*k
        return None
    found = []
    for way in YIELD_WAYS:
        far = least(way)
        if far is not None: found.append((far, way))
    if before is not None and before.length > 1e-4:
        way = before.normalized()
        far = least(way)
        if far is not None and (not found or far <= min(f[0] for f in found)+2*YIELD_STEP): found = [(far, way)]
    yielding[0] = kept
    guard(*asked)
    if not found: return V(1, 0, 0)*YIELD_MOST
    far, way = min(found, key=lambda f: f[0])
    return way*far

def spread(raw, reach, wrap=False):
    """Each moment's yield carried to the moments either side, falling away
    with distance (the largest of them kept), then eased."""
    n = len(raw)
    out = []
    for f in range(n):
        best = V(0, 0, 0)
        for g in range(f-reach, f+reach+1):
            if not wrap and not 0 <= g < n: continue
            v = raw[g % n]*ease(1-abs(f-g)/(reach+1))
            if v.length > best.length: best = v
        out.append(best)
    for _ in range(2):
        out = [(out[(f-1) % n if wrap else max(0, f-1)]+out[f]*2+out[(f+1) % n if wrap else min(n-1, f+1)])/4 for f in range(n)]
    return out

reset()
chest0 = rig.pose.bones['spine_03'].matrix.copy()
# (The chest's front in its own frame: an elbow is kept from pointing there.)
CHEST_FRONT = chest0.to_quaternion().inverted() @ V(0, -1, 0)
# The shield arm's guard is the town guards' (scripts/town_guard.gd: their
# SpearShieldIdle and ScutumSwordIdle, tools/import_combat.py shield_arm):
# the left forearm across the front of the body, the fist before the belly
# (GUARD_FIST, in the stance) and the elbow forward and out to the left. The
# fist is held GUARD_RAISE higher than theirs and the elbow asked for a
# little lower and nearer (GUARD_ELBOW), so that the forearm lies level:
# the game stands a guard's scutum upright on his forearm whatever its
# slope, but the hero's board is strapped across his (scripts/visual.gd
# arm) and leans as far as the forearm does. The forearm is rolled so the
# board's face looks ahead (guard). Kept in the chest's frame, so the board
# turns and bends with the body through a swing.
GUARD_FIST = V(-.05, -.2, 1.12)
GUARD_RAISE = .08
GUARD_ELBOW = V(.6, -.4, .8)
GUARD_AT = GUARD_FIST+V(0, 0, GUARD_RAISE)
GUARD_HAND = chest0.inverted() @ GUARD_AT
GUARD_POLE = chest0.inverted() @ GUARD_ELBOW
# The shield arm (its hand turned with the forearm): raised out of the
# stance's hanging arm into the guard over the first ARM_RAISE of a skill
# and lowered back from ARM_LOWER, more gently than the rest of him eases in
# and out (settle), the board being swung up from his side to before him;
# the attack's first cut raises it over OPEN_RAISE of its swing.
SHIELD_ARM = ('clavicle_l', 'upperarm_l', 'lowerarm_l', 'hand_l')
ARM_RAISE = .25
ARM_LOWER = .75
OPEN_RAISE = .3
SWORD_HOME = rig.pose.bones['hand_r'].head.copy()
SWORD_POLE = V(-.75, .1, .9)

def settle(t, into=.12, out=.86):
    """How far the pose is eased toward the stance at the clip's ends."""
    return max(ease(1-t/into), ease((t-out)/(1-out)))

def arm_settle(t):
    """How far the shield arm is eased toward the stance's hanging arm."""
    return max(ease(1-t/ARM_RAISE), ease((t-ARM_LOWER)/(1-ARM_LOWER)))

def to_stance(w, arm_w, keep=()):
    """Eases the pose toward the stance: the body by `w`, the shield arm by
    `arm_w` (or `w`, whichever is more), bones named in `keep` not at all."""
    if w <= 0 and arm_w <= 0: return
    for b in rig.pose.bones:
        if b.name in keep: continue
        by = max(w, arm_w) if b.name in SHIELD_ARM else w
        if by > 0: b.matrix_basis = blend(b.matrix_basis, BASE[b.name], by)
    update()

def author(name, pose, keep=()):
    """Keys `pose` frame by frame; bones named in `keep` are not eased into
    the stance at the ends (a dual swing's left arm, which the game carries
    on into its own hanging idle). The shield arm yields to the sword where
    it must (YIELD), found over the whole clip first."""
    length = CLIPS[name]
    frames = int(round(length*30))
    raw = []
    for f in range(frames+1):
        reset()
        pose(f/frames)
        raw.append(needed_yield(raw[-1] if raw else None))
    aside = spread(raw, YIELD_REACH)
    a = bpy.data.actions.new(name)
    rig.animation_data.action = a
    least = (9.0, 0.0)
    for f in range(frames+1):
        t = f/frames
        reset()
        yielding[0] = aside[f]
        pose(t)
        to_stance(settle(t), arm_settle(t), keep)
        if held_guard[0] is not None: least = min(least, (board_gap()[0], t))
        # SLAM_CHECK=1: how high the blade is over the ground (its two ends)
        # through Thunder Slam and Leap, and how near the body it comes.
        if name in ('SkillSlam', 'DualSkillSlam', 'SkillLeap') and os.environ.get('SLAM_CHECK') and (f % 3 == 0):
            c = clearances()
            hand = rig.pose.bones['hand_r'].matrix
            ends = [hand @ V(0, .075, 0), hand @ V(0, .075, 1.08)]
            print('SLAM_CHECK', name, round(t, 2), 'blade z', round(ends[0].z, 3), round(ends[1].z, 3), 'worst body', min((v, k) for k, v in c.items() if k.startswith('blade /') and k != 'blade / ground'), 'arm', min((v, k) for k, v in c.items() if k.startswith('arm /')), 'wrist', round(c['wrist']), 'twist', round(c['twist']))
        keys(f)
    yielding[0] = V(0, 0, 0)
    finish(name, a, length)
    print('SHIELD_CHECK', name, 'yields', round(max(v.length for v in aside), 3), 'sword and head off the board', round(least[0], 3), 'at', round(least[1], 2))
    if SHEET_DIR:
        def at(t):
            reset()
            yielding[0] = aside[int(round(t*frames))]
            pose(t)
            to_stance(settle(t), arm_settle(t), keep)
            yielding[0] = V(0, 0, 0)
        sheet.render(rig, name, SHEET_PHASES, SHEET_DIR, at)

# ---- The clips ----

# Cleave's, Shield Bash's and Shockwave's step: he steps forward into the blow and
# brings the rear foot up after it, ending in his stance a step further on.
# The game carries him over the ground as he steps (scripts/visual.gd
# ROOT_ADVANCE keeps the same keys); here each foot is kept where it is on
# the ground beneath him while he is carried past it.
BASH_ADVANCE = [(0, 0), (.3, 0), (.5, .38), (.66, .4), (1, .4)]
CLEAVE_ADVANCE = [(0, 0), (.32, 0), (.52, .38), (.66, .4), (1, .4)]
STOMP_ADVANCE = [(0, 0), (.36, .1), (.56, .45), (.74, .5), (1, .5)]

def step_feet(advance, t, left, right):
    """The feet, each a list of (time, (forward, lift)) points of where it is
    over the ground (forward of where it stood), kept there in the clip as he
    is carried along by `advance`."""
    carried = sample(advance, t)
    for s, points in (('l', left), ('r', right)):
        at = vsample([(k, (v[0], v[1], 0)) for k, v in points], t)
        foot = PLANTED[s]+V(0, -(at.x-carried), at.y)
        # (A raised knee comes up forward of the foot.)
        leg(s, foot, KNEES[s]+V(0, -.6-.6*at.y, .5*at.y))

def face_shield(direction):
    """Rolls the shield forearm about its length so the shield's face looks
    along `direction` (the board lies on the forearm's outer side, along its -Z)."""
    fore = rig.pose.bones['lowerarm_l']
    q = fore.matrix.to_quaternion()
    along = q @ V(0, 1, 0)
    want = Vector(direction)
    want = (want-along*want.dot(along)).normalized()
    now = -(q @ V(0, 0, 1))
    now = (now-along*now.dot(along)).normalized()
    angle = now.angle(want)
    if now.cross(want).dot(along) < 0: angle = -angle
    roll('lowerarm_l', angle)

def cleave(t):
    # A backhand sweep behind a step: the blade carried across the body to
    # the left shoulder, its point back over it, the body coiled round to the
    # left after it; then the left foot driven forward and the body uncoiled
    # through the blow, the blade swept flat out across the front and away to
    # the right, the back of the hand leading, and followed right round; the
    # shield arm drops low at his side as the sword arm crosses above it, the
    # board turned out to the left, edge on to the blade, and is held there
    # below the sweep until it has passed, then raised again into the guard;
    # and the rear foot is brought up after.
    coil = sample([(0, 0), (.3, 1), (.38, 1), (.5, 0), (1, 0)], t)
    sweep = sample([(0, 0), (.38, 0), (.6, 1), (.74, 1.05), (1, 0)], t)
    low = sample([(0, 0), (.3, 1), (.6, 1), (.8, 0), (1, 0)], t)
    hips(down=.04*coil+.1*sweep, forward=sample([(0, 0), (.3, -.04), (.52, .3), (.66, .36), (.9, .4), (1, .4)], t)-sample(CLEAVE_ADVANCE, t))
    rotate('pelvis', (0, 0, 1), .3*coil-.35*sweep)
    rotate('spine_01', (0, 0, 1), .35*coil-.35*sweep)
    rotate('spine_02', (0, 0, 1), .3*coil-.3*sweep)
    rotate('spine_02', (1, 0, 0), .05*coil+.18*sweep)
    rotate('neck_01', (0, 0, 1), -.35*coil+.3*sweep)
    hand = vsample([(0, SWORD_HOME), (.3, V(.22, -.12, 1.32)), (.38, V(.24, -.1, 1.34)), (.47, V(.1, -.62, 1.2)), (.52, V(-.25, -.7, 1.16)), (.6, V(-.62, -.3, 1.12)), (.74, V(-.64, -.05, 1.1)), (1, SWORD_HOME)], t)
    blade = vsample([(0, V(-.2, -1, .3)), (.3, V(.5, .7, .4)), (.38, V(.55, .75, .3)), (.47, V(.45, -.9, .05)), (.52, V(-.35, -1, 0)), (.6, V(-.95, -.3, -.05)), (.74, V(-.85, .45, 0)), (1, V(-.2, -1, .3))], t)
    sword(hand, vsample([(0, V(-.8, .3, .9)), (.3, V(-.1, -.7, 1.7)), (.47, V(-.3, -.6, 1.6)), (.6, V(-.9, -.2, 1.5)), (1, V(-.8, .3, .9))], t), blade)
    guard(out=.25*low, up=-.5*low, forward=-.1*low, turn=1.5*low)
    step_feet(CLEAVE_ADVANCE, t, [(0, (0, 0)), (.32, (0, 0)), (.44, (.22, .1)), (.52, (.42, 0)), (1, (.42, 0))],
        [(0, (0, 0)), (.66, (0, 0)), (.78, (.22, .08)), (.9, (.4, 0)), (1, (.4, 0))])

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
    guard(forward=-.06*chop)
    plant()

def stab(t):
    # Drawn back to the hip and driven forward with a lunge of the hips, the
    # shield carried out to the left for the sword to pass its rim.
    back = sample([(0, 0), (.3, 1), (.4, 1), (.55, 0), (1, 0)], t)
    thrust = sample([(0, 0), (.4, 0), (.52, 1), (.66, 1), (1, 0)], t)
    hips(forward=.14*thrust-.03*back, down=.05*thrust)
    rotate('pelvis', (0, 0, 1), .25*back-.3*thrust)
    rotate('spine_01', (0, 0, 1), .2*back-.25*thrust)
    rotate('spine_02', (1, 0, 0), .18*thrust)
    hand = vsample([(0, SWORD_HOME), (.3, V(-.32, .28, 1.0)), (.4, V(-.33, .3, 1.0)), (.52, V(-.08, -.9, 1.12)), (.66, V(-.08, -.88, 1.1)), (1, SWORD_HOME)], t)
    sword(hand, V(-.8, .15, .9), V(0, -1, .05))
    guard(out=.3*thrust, up=.05*thrust, forward=-.05*thrust)
    plant(lead='l', forward=.3*thrust)

def bash(t):
    # A backhand blow with the shield behind a step: the shield drawn across
    # the chest to the right, the body coiled round after it and the weight
    # sat back; then the left foot driven forward and the whole body uncoiled
    # through it, the shield arm flung out forward and to the left, the back
    # of the board leading, the shoulder behind it, and followed through
    # wide; the sword kept back and clear, the rear foot brought up after.
    # It starts and ends in the shield's guard (GUARD_AT, the board's face
    # ahead).
    coil = sample([(0, 0), (.3, 1), (.36, 1), (.48, 0), (1, 0)], t)
    swing = sample([(0, 0), (.34, 0), (.5, 1), (.64, 1.15), (.8, .5), (1, 0)], t)
    hips(down=.05*coil+.1*swing, forward=sample([(0, 0), (.3, -.06), (.5, .3), (.66, .36), (.9, .4), (1, .4)], t)-sample(BASH_ADVANCE, t))
    rotate('pelvis', (0, 0, 1), -.4*coil+.45*swing)
    rotate('spine_01', (0, 0, 1), -.4*coil+.45*swing)
    rotate('spine_02', (0, 0, 1), -.3*coil+.35*swing)
    rotate('spine_02', (1, 0, 0), -.05*coil+.28*swing)
    rotate('neck_01', (0, 0, 1), .3*coil-.35*swing)
    hand = vsample([(0, GUARD_AT), (.3, V(-.1, -.34, 1.2)), (.36, V(-.12, -.34, 1.22)), (.5, V(.48, -.78, 1.28)), (.64, V(.78, -.42, 1.2)), (.8, V(.4, -.3, 1.15)), (1, GUARD_AT)], t)
    pole = vsample([(0, GUARD_ELBOW), (.3, V(.5, -.4, 1.7)), (.5, V(1.0, -.1, 1.4)), (.64, V(1.0, .4, 1.2)), (1, GUARD_ELBOW)], t)
    arm('l', hand, pole)
    face = vsample([(0, V(0, -1, 0)), (.3, V(0, -1, .1)), (.5, V(.4, -1, 0)), (.64, V(1, -.5, 0)), (.8, V(.5, -1, 0)), (1, V(0, -1, 0))], t)
    face_shield(face)
    sword(V(-.42, .25, 1.0), V(-.85, .3, .9), V(-.3, -.8, -.2))
    step_feet(BASH_ADVANCE, t, [(0, (0, 0)), (.3, (0, 0)), (.42, (.24, .12)), (.5, (.42, 0)), (1, (.42, 0))],
        [(0, (0, 0)), (.64, (0, 0)), (.76, (.22, .08)), (.88, (.4, 0)), (1, (.4, 0))])

def execute(t):
    # The blade carried far back over the shoulder as the body arches, then
    # the whole body thrown down behind it to the knees (the shield carried
    # out beside the left knee, clear of the folded body), and a slow
    # recovery.
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
    guard(forward=.08*wind, out=.22*fall, up=.06*fall)
    plant()

# Thunder Slam's and Leap's blow: the blade struck down along the ground
# rather than point-first into it. The hand (held with the grip the swing
# gives it) comes down as low as the folded body lets it, a little ahead; the
# blade points ahead, tipped just enough that it meets the ground along its
# length to the point (Leap lands lower, so tips it less).
SLAM_HAND = .14
SLAM_AHEAD = .6
FLAT_BLADE = V(0, -1, -.1)
LEAP_BLADE = V(0, -1, -.25)

# Thunder Slam's wind-up and blow, after film of the swing made with a stick
# in one hand, shared by the one-handed and the dual swing. The weapon never
# leaves his forehand side. First the hand stays before the belly and the
# blade, held up, is tipped over to his right and let fall down his right
# side, the hand drawing to the right hip as it comes. Then the arm
# straightens (a shade short of locked), and arm and blade swing up together
# on his right as one lever, the blade lagging a half right angle behind the
# arm (the wrist bent no further than a wrist bends), the chest turned to
# face the swing and the head after it: from hanging below the fist, out
# level at the shoulder, up over the head as the back arches; the blade
# comes over the top as the whole body folds forward and down behind it on a
# long stride of the lead foot, the hips dropped, the back bent, the blade
# struck down flat along the ground ahead; held there, and a slow rise. The
# shield arm is carried out to the left for balance as the sword arm goes
# out, and out beside the lead knee with the blow. The fingers lie along the
# forearm and the elbow is swung no further than SLAM_SWING_PATH allows from
# where it is asked to where the forearm is not wrung
# (tools/blender_arm.py).
def slam_body(t, side_scale=1.0):
    square = sample([(0, 0), (.06, 1), (.14, .6), (.26, 0), (1, 0)], t)
    side = sample([(0, 0), (.1, 0), (.26, 1), (.42, .8), (.52, 0), (1, 0)], t)*side_scale
    up = sample([(0, 0), (.4, 0), (.49, 1), (.56, 0), (1, 0)], t)
    down = sample([(0, 0), (.54, 0), (.66, 1), (.84, 1), (1, 0)], t)
    hips(down=.06*square+.02*side-.08*up+.45*down, forward=-.02*square-.06*side-.08*up+.3*down, aside=-.04*side)
    rotate('pelvis', (1, 0, 0), .08*square-.05*side-.2*up+.3*down)
    rotate('spine_01', (1, 0, 0), .08*square-.06*side-.38*up+.55*down)
    rotate('spine_02', (1, 0, 0), .05*square-.04*side-.28*up+.45*down)
    rotate('spine_03', (1, 0, 0), .02*square-.02*side-.14*up+.3*down)
    rotate('pelvis', (0, 0, 1), -.4*side+.15*down)
    rotate('spine_01', (0, 0, 1), -.35*side+.1*down)
    rotate('spine_02', (0, 0, 1), -.3*side+.1*down)
    rotate('spine_01', (0, 1, 0), -.08*side-.04*up)
    rotate('spine_02', (0, 1, 0), -.08*side-.04*up)
    rotate('neck_01', (0, 0, 1), -.3*side-.1*up)
    rotate('neck_01', (1, 0, 0), .15*square-.15*up+.1*down)
    rotate('Head', (0, 0, 1), -.25*side)
    rotate('Head', (1, 0, 0), .1*square+.1*side+.3*up-.2*down)
    plant(lead='l', forward=.6*down, lift=.16*math.sin(math.pi*sample([(0, 0), (.52, 0), (.64, 1), (1, 1)], t)))
    return square, side, up, down

# The hand before the belly through the first drop, then at the end of the
# arm (SLAM_ARM_PATH from the shoulder, SLAM_REACH out, by SLAM_LEVER's
# weight), and down on the ground for the blow. The blade is kept at least
# a half right angle off the arm's line, on the side the elbow's pit faces,
# so the wrist is never wrung: ahead of the arm as it hangs, trailing below
# and behind as the arm swings back and up, above the arm as it comes over
# and down, and level on the ground at the blow.
SLAM_REACH = .486
SLAM_HAND_PATH = [(0, SWORD_HOME), (.06, V(-.25, -.32, 1.0)),
    (.66, V(-.18, -SLAM_AHEAD, SLAM_HAND)), (.84, V(-.18, -SLAM_AHEAD+.03, SLAM_HAND-.02)), (1, SWORD_HOME)]
SLAM_ARM_PATH = [(0, V(-.35, -.2, -.9)), (.06, V(-.45, -.5, -.74)), (.12, V(-.45, -.5, -.74)), (.18, V(-.5, -.1, -.86)), (.24, V(-.35, .3, -.89)), (.30, V(-.5, .6, -.62)), (.38, V(-.55, .6, .58)), (.44, V(-.3, .35, .89)),
    (.49, V(-.15, 0, .99)), (.54, V(0, -.5, .87)), (.58, V(0, -.97, .26)), (.62, V(0, -.87, -.5)), (.66, V(0, -.64, -.77)), (1, V(0, -.64, -.77))]
SLAM_LEVER = [(0, 0), (.06, 0), (.12, 1), (.62, 1), (.66, 0), (1, 0)]
SLAM_BLADE_PATH = [(0, V(-.2, -1, .3)), (.06, V(0, -.87, .5)), (.12, V(-.4, -.9, .17)), (.18, V(-.9, -.1, -.42)), (.24, V(-.45, .85, -.27)), (.30, V(0, .1, -1)), (.38, V(0, .75, -.66)),
    (.44, V(0, .9, .44)), (.49, V(0, .75, .66)), (.54, V(0, .3, .95)), (.58, V(0, -.5, .87)), (.62, V(0, -.76, .65)), (.66, FLAT_BLADE), (.84, FLAT_BLADE), (1, V(-.2, -1, .3))]
# (Where the elbow is asked to bend toward, chosen with SKILLS_PROBE so the
# elbow points back, down or out and the fist is not turned far.)
SLAM_POLE_PATH = [(0, V(-.75, .1, .9)), (.06, V(-.2, .25, 1.1)), (.12, V(-.4, .3, 1.1)), (.18, V(-.3, .4, 1.1)), (.24, V(-.3, .4, 1.1)), (.30, V(-.45, .4, .9)), (.38, V(-.55, .3, .9)),
    (.44, V(-.6, .2, 1.1)), (.49, V(-.6, 0, 1.3)), (.54, V(-.6, -.1, 1.1)), (.58, V(-.6, -.2, 1.0)), (.62, V(-.6, -.3, .9)), (.66, V(-.5, -.3, .5)), (1, V(-.75, .1, .9))]
SLAM_SWING_PATH = [(0, 35), (.06, 35), (.12, 150), (.49, 150), (.54, 35), (.92, 35), (1, 35)]
# (The arm is held fully straight while the blade trails below it, since the
# fist can only carry it there with the elbow turned up, which a straight
# arm does not show; and a shade bent, the elbow asked for, through the blow.)
SLAM_REACH_PATH = [(0, .494), (.49, .494), (.54, .486), (1, .486)]

def slam_hand(t, side='r'):
    """Where the sword hand is at `t`: before the body, or out from its
    shoulder along SLAM_ARM_PATH, a shade short of the arm's length."""
    shoulder = rig.pose.bones['upperarm_'+side].matrix.translation
    along = vsample(SLAM_ARM_PATH, t)
    at = vsample(SLAM_HAND_PATH, t)
    if side == 'l': along, at = mirror_x(along), mirror_x(at)
    return at.lerp(shoulder+along.normalized()*sample(SLAM_REACH_PATH, t), sample(SLAM_LEVER, t))

def slam(t):
    square, side, up, down = slam_body(t)
    grip('r', slam_hand(t), vsample(SLAM_POLE_PATH, t), vsample(SLAM_BLADE_PATH, t), swing=math.radians(sample(SLAM_SWING_PATH, t)))
    # The shield arm carried out to the left as the sword arm goes out, a
    # little forward as the weapon comes over, and out beside the lead knee
    # as the blow lands.
    guard(up=-.05*side-.1*up-.05*down, out=.1*square+.2*side+.05*up+.25*down, forward=.1*side+.15*up+.05*down)

def mirror_x(v):
    return V(-v.x, v.y, v.z)

def dual_slam(t):
    # A weapon in each hand: the left does as the right, mirrored, both
    # swung out and over the head together and both slammed down (the chest
    # kept nearer square, since both arms go out).
    slam_body(t, side_scale=.4)
    swing = math.radians(sample(SLAM_SWING_PATH, t))
    grip('r', slam_hand(t), vsample(SLAM_POLE_PATH, t), vsample(SLAM_BLADE_PATH, t), swing=swing)
    grip('l', slam_hand(t, 'l'), mirror_x(vsample(SLAM_POLE_PATH, t)), mirror_x(vsample(SLAM_BLADE_PATH, t)), swing=swing)

def leap(t):
    # A deep crouch, the sword arm swung back and the shield carried out to
    # the left, clear of the knees; the spring, the body stretched and the
    # blade carried up over the head in the air; the landing, driven down
    # with everything: the hips to the heels, the back folded, the blade
    # struck down flat along the ground, the shield out beside the left
    # knee; then the slow rise.
    crouch = sample([(0, 0), (.12, 1), (.2, 1), (.28, 0), (1, 0)], t)
    air = sample([(0, 0), (.2, 0), (.3, 1), (.46, 1), (.56, 0), (1, 0)], t)
    land = sample([(0, 0), (.48, 0), (.57, 1), (.76, 1), (1, 0)], t)
    hips(down=.32*crouch-.05*air+.5*land, forward=-.05*crouch+.1*air+.18*land)
    rotate('pelvis', (1, 0, 0), .2*crouch-.1*air+.3*land)
    rotate('spine_01', (1, 0, 0), .4*crouch-.3*air+.4*land)
    rotate('spine_02', (1, 0, 0), .25*crouch-.2*air+.25*land)
    rotate('spine_03', (1, 0, 0), .1*crouch-.1*air+.12*land)
    rotate('Head', (1, 0, 0), -.3*crouch+.25*air-.3*land)
    hand = vsample([(0, SWORD_HOME), (.12, V(-.5, .45, .75)), (.2, V(-.5, .45, .72)), (.3, V(-.25, .3, 2.1)), (.46, V(-.2, .25, 2.2)), (.57, V(-.18, -SLAM_AHEAD+.1, SLAM_HAND)), (.76, V(-.18, -SLAM_AHEAD+.13, SLAM_HAND-.02)), (1, SWORD_HOME)], t)
    blade = vsample([(0, V(-.2, -1, .3)), (.12, V(-.2, .9, -.3)), (.2, V(-.2, .9, -.3)), (.3, V(0, .6, .8)), (.46, V(0, .7, .7)), (.57, LEAP_BLADE), (.76, LEAP_BLADE), (1, V(-.2, -1, .3))], t)
    sword(hand, V(-.9, .4, 1.1) if t < .25 else (V(-.9, .1, 1.7) if t < .52 else V(-.9, -.4, .9)), blade)
    guard(forward=-.05*crouch+.1*air, out=.25*crouch+.1*air+.25*land, up=.05*crouch)
    if air > 0:
        # Legs drawn up beneath him in the air.
        for s in 'lr': leg(s, PLANTED[s]+V(0, -.1*air, .5*air), KNEES[s]+V(0, -.8, .3))
    else: plant(lead='l', forward=.3*land)

def shockwave(t):
    # A violent stomp: the left knee hauled up high as he rears back, the
    # sword flung up, the shield raised and out and the chest thrown open;
    # then the foot driven down a stride ahead with the whole body behind
    # it, the hips dropped deep, the back folded over it, the sword hurled
    # down and out and the shield out to the left; held, and the rear foot
    # brought up as he rises.
    rear = sample([(0, 0), (.36, 1), (.42, 1), (.54, 0), (1, 0)], t)
    drive = sample([(0, 0), (.42, 0), (.56, 1), (.74, 1), (1, 0)], t)
    hips(down=-.05*rear+.4*drive, forward=sample([(0, 0), (.36, -.02), (.56, .34), (.74, .36), (.95, .5), (1, .5)], t)-sample(STOMP_ADVANCE, t))
    rotate('pelvis', (1, 0, 0), -.12*rear+.3*drive)
    rotate('spine_01', (1, 0, 0), -.25*rear+.45*drive)
    rotate('spine_02', (1, 0, 0), -.18*rear+.3*drive)
    rotate('spine_03', (1, 0, 0), -.08*rear+.15*drive)
    rotate('pelvis', (0, 0, 1), .1*rear-.08*drive)
    rotate('neck_01', (1, 0, 0), -.12*rear+.05*drive)
    rotate('Head', (1, 0, 0), .2*rear-.3*drive)
    hand = vsample([(0, SWORD_HOME), (.36, V(-.45, .12, 1.75)), (.42, V(-.46, .14, 1.78)), (.56, V(-.68, -.2, .62)), (.74, V(-.66, -.18, .6)), (1, SWORD_HOME)], t)
    blade = vsample([(0, V(-.2, -1, .3)), (.36, V(-.4, .3, .9)), (.42, V(-.4, .35, .9)), (.56, V(-.8, -.4, -.3)), (.74, V(-.8, -.4, -.3)), (1, V(-.2, -1, .3))], t)
    sword(hand, V(-.9, .3, 1.5) if t < .48 else V(-1.0, .2, .9), blade)
    guard(out=.25*rear+.4*drive, forward=.15*rear, up=.1*rear)
    step_feet(STOMP_ADVANCE, t, [(0, (0, 0)), (.18, (.04, .14)), (.38, (.18, .42)), (.44, (.24, .42)), (.56, (.5, 0)), (1, (.5, 0))],
        [(0, (0, 0)), (.74, (0, 0)), (.84, (.26, .08)), (.94, (.5, 0)), (1, (.5, 0))])

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
    guard(out=.3*up, forward=.12*up, up=.08*up)
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
    # The shield arm thrust straight out before the chest from its guard,
    # the board square to the way he runs; the sword arm kept back.
    chest = rig.pose.bones['spine_03'].matrix
    held = chest @ GUARD_HAND
    arm('l', V(.14, -.62, 1.22)*running+held*(1-running), V(.55, -.3, .95)*running+(chest @ GUARD_POLE)*(1-running))
    face_shield(V(0, -1, 0))
    sword(V(-.42, .25, 1.0), V(-.85, .3, .9), V(-.3, -.8, -.25))

# ---- The normal attack: three swings in one unbroken cycle ----

def flow(points, t, period=3.0):
    """A value carried round a cycle of (time, value) points along a smooth
    curve (no pause at any of them), `period` long."""
    n = len(points)
    t %= period
    i = max((k for k in range(n) if points[k][0] <= t), default=-1)
    def at(k):
        time, value = points[k % n]
        value = Vector(value) if not isinstance(value, (int, float)) else value
        return time+period*(k//n), value
    (t0, v0), (t1, v1), (t2, v2), (t3, v3) = at(i-1), at(i), at(i+1), at(i+2)
    h = t2-t1
    u = (t-t1)/h
    m1 = (v2-v0)*(1/(t2-t0))
    m2 = (v3-v1)*(1/(t3-t1))
    return v1*(2*u**3-3*u*u+1)+m1*(h*(u**3-2*u*u+u))+v2*(-2*u**3+3*u*u)+m2*(h*(u**3-u*u))

# The cycle, a swing to each unit of its time: the first cut through 0..1,
# the backhand through 1..2, the thrust through 2..3, each landing .52 through
# its own. The sword hand, the way the blade points and the elbow's side:
# (Each cut is wound up as a throw is: the hand drawn back past the shoulder
# with the elbow pulled behind him and the arm stretching back, before it
# is whipped through; the backhand is loaded across the body at the left
# shoulder, the thrust with the hand drawn far back by the hip.)
SWING_HAND = [(.22, (-.42, .5, 1.5)), (.42, (-.46, .62, 1.42)), (.47, (-.38, .12, 1.62)), (.52, (-.04, -.62, 1.2)), (.60, (.12, -.66, .5)), (.70, (.14, -.62, .5)), (.88, (.16, -.4, 1.15)),
    (1.22, (.26, -.06, 1.52)), (1.42, (.3, .1, 1.5)), (1.47, (.12, -.42, 1.48)), (1.52, (-.1, -.6, 1.2)), (1.60, (-.4, -.18, .68)), (1.70, (-.42, -.14, .68)), (1.88, (-.42, .14, .95)),
    (2.14, (-.44, .5, 1.0)), (2.36, (-.46, .56, .98)), (2.52, (-.1, -.73, .9)), (2.64, (-.1, -.71, .9)), (2.84, (-.32, -.05, 1.4))]
SWING_BLADE = [(.22, (-.3, .75, .45)), (.42, (-.3, .9, .2)), (.47, (-.5, .2, .85)), (.52, (.15, -.85, .5)), (.60, (.88, -.35, -.25)), (.70, (.9, -.25, -.22)), (.88, (.5, -.1, .85)),
    (1.22, (.5, .6, .6)), (1.42, (.5, .85, .15)), (1.47, (.55, .1, .8)), (1.52, (-.15, -.85, .5)), (1.60, (-.8, -.4, -.4)), (1.70, (-.84, -.3, -.38)), (1.88, (-.5, -.8, -.1)),
    (2.14, (0, -1, .16)), (2.36, (.02, -1, .18)), (2.52, (.04, -1, .2)), (2.64, (.04, -1, .2)), (2.84, (-.1, -.6, .8))]
SWING_POLE = [(.22, (-.65, .9, 1.25)), (.42, (-.6, 1.0, 1.2)), (.52, (-.8, -.1, .9)), (.60, (-.9, -.6, .9)), (1.22, (-.3, -.5, 1.2)), (1.52, (-.8, -.1, .9)),
    (1.60, (-.9, .3, .9)), (2.14, (-.6, 1.0, 1.15)), (2.52, (-1, 0, 1.3)), (2.84, (-.9, 0, 1.2))]
# The whole body goes into each: wound far round against the swing and
# thrown round with it (the turn, to the left), bent over it (the lean
# forward), the hips dropped and driven forward under it. The cuts are
# struck fast and followed all the way through, down almost to the ground,
# as a serve is; he rises out of each into the next.
SWING_TURN = [(.22, -.75), (.42, -.95), (.52, .3), (.60, .95), (.70, 1.0), (1.22, .8), (1.42, .95), (1.52, .2), (1.60, -.6), (1.70, -.7), (2.14, -.7), (2.36, -.85),
    (2.52, .8), (2.64, .8), (2.84, 0)]
SWING_LEAN = [(.22, -.1), (.42, -.18), (.52, .35), (.60, .8), (.70, .8), (.9, .2), (1.22, 0), (1.42, -.1), (1.52, .35), (1.60, .75), (1.70, .75), (1.9, .2),
    (2.14, .05), (2.36, -.05), (2.52, .4), (2.64, .4), (2.84, .1)]
SWING_DOWN = [(0, .06), (.22, .04), (.42, .08), (.52, .25), (.60, .38), (.70, .38), (.88, .12), (1.22, .04), (1.42, .08), (1.52, .25), (1.60, .38), (1.70, .38), (1.88, .12),
    (2.14, .06), (2.36, .1), (2.52, .22), (2.64, .22), (2.86, .06)]
SWING_FORWARD = [(0, 0), (.42, -.06), (.52, .1), (.62, .14), (.9, 0), (1.42, -.06), (1.52, .1), (1.62, .14), (1.9, 0), (2.36, -.08), (2.52, .16),
    (2.64, .16), (2.9, 0)]
# The first cut out of the stance has a wind-up of its own, as a serve or a
# long throw has: the blade is not lifted straight to the shoulder but swung
# round to it. The hand drops back past the hip as he turns away and dips,
# the point left standing before him; it comes up behind the shoulder with the
# elbow leading, the point tipping back over it; and the blade, left lying
# back over the shoulder, is whipped over the top into the cut. These are the cycle's keys with its
# first .42 replaced (from the cut's last moment before it lands, .47, the
# two are the same, so the swings that follow run on from it as before).
OPEN_UNTIL = .45
def opening(points, keys):
    return keys+[k for k in points if k[0] > OPEN_UNTIL]
OPEN_HAND = opening(SWING_HAND, [(0, tuple(SWORD_HOME)), (.12, (-.38, .32, .88)), (.24, (-.45, .5, 1.02)), (.34, (-.47, .62, 1.3)), (.42, (-.46, .62, 1.42))])
OPEN_BLADE = opening(SWING_BLADE, [(0, tuple(rig.pose.bones['hand_r'].matrix.to_quaternion() @ V(0, 0, 1))), (.12, (0, -.55, .85)), (.24, (-.1, .25, .95)), (.34, (-.25, .9, .35)),
    (.42, (-.3, .9, .2))])
OPEN_POLE = opening(SWING_POLE, [(0, (-.4, .6, 1.2)), (.12, (-.6, .9, 1.1)), (.24, (-.7, 1.0, 1.1)), (.34, (-.6, 1.0, 1.2)), (.42, (-.6, 1.0, 1.2))])
OPEN_TURN = opening(SWING_TURN, [(0, 0), (.12, -.25), (.24, -.6), (.34, -.85), (.42, -.95)])
OPEN_LEAN = opening(SWING_LEAN, [(0, 0), (.12, .12), (.24, .05), (.34, -.1), (.42, -.18)])
OPEN_DOWN = opening(SWING_DOWN, [(0, .02), (.12, .12), (.24, .1), (.34, .05), (.42, .08)])
# Each swing's step: the travel the game carries him through over the swing
# (scripts/visual.gd ROOT_ADVANCE keeps the same keys), and the rear foot's
# stride past the front one (start, end, distance, lift) over ground that
# stays still, leaving him in his stance the other way about. A swing begun
# with the left foot forward (his stance) steps with the right, and the next
# with the left.
# (The step waits until SWING_FOLLOW into the swing: so far each clip runs on
# into the next swing, for the next clip to take over from it on the way.)
SWING_FOLLOW = .18
SWING_ADVANCE = [(0, 0), (.18, 0), (.56, .42), (.8, .5), (1, .5)]
SWING_STRIDE = (.18, .56, 1.0, .12)
# How far the shield arm yields to the sword through the cycle (YIELD),
# SWING_YIELD a step of TWIST_STEPS a swing (filled in below), and through
# the first cut's wind-up out of the stance (OPEN_YIELD).
SWING_YIELD = []
OPEN_YIELD = []

def yielded(tau, of):
    table = OPEN_YIELD if of is OPENING and tau < 1 else SWING_YIELD
    if not table: return V(0, 0, 0)
    at = tau*TWIST_STEPS if table is OPEN_YIELD else (tau % 3.0)*TWIST_STEPS
    i = min(int(at), len(table)-2)
    return table[i].lerp(table[i+1], at-i)

# How far the sword hand's wrist may bend sideways from the forearm's line.
WRIST_BEND = math.radians(45)
TOES = {}
for s in 'lr':
    d = rig.pose.bones['ball_'+s].head-rig.pose.bones['foot_'+s].head
    d.z = 0
    TOES[s] = d.normalized()

# What the pose asked of the sword arm beyond its reach (checked below).
short = [0.0]

def hand_twist():
    """How far the sword hand is turned about its own length from the way
    the arm carries it (radians, within half a turn either way)."""
    q = rig.pose.bones['hand_r'].matrix_basis.to_quaternion()
    return (2*math.atan2(q.y, q.w)+math.pi) % (2*math.pi)-math.pi

def roll(name, angle):
    """Turns a bone about its own length, where it is."""
    b = rig.pose.bones[name]
    m = b.matrix.copy()
    q = m.to_quaternion()
    set_world(b, m.translation, Quaternion(q @ V(0, 1, 0), angle) @ q)

# The hand's turn through the cycle (filled in below), and the share of it
# the upper arm and the forearm take up (the wrist is left the rest).
TWIST = []
OPEN_TWIST = []
TWIST_STEPS = 96
ARM_ROLL = (.45, .3)
# What a swing is keyed from: the cycle, or the cycle wound up out of the
# stance.
CYCLE = {'hand': SWING_HAND, 'blade': SWING_BLADE, 'pole': SWING_POLE, 'turn': SWING_TURN, 'lean': SWING_LEAN, 'down': SWING_DOWN, 'twist': TWIST}
OPENING = {'hand': OPEN_HAND, 'blade': OPEN_BLADE, 'pole': OPEN_POLE, 'turn': OPEN_TURN, 'lean': OPEN_LEAN, 'down': OPEN_DOWN, 'twist': OPEN_TWIST}

def swing_pose(tau, twist=True, of=CYCLE):
    u = tau % 1.0
    turn = flow(of['turn'], tau)
    lean = flow(of['lean'], tau)
    hips(down=flow(of['down'], tau), forward=flow(SWING_FORWARD, tau))
    rotate('pelvis', (0, 0, 1), turn*.4)
    rotate('spine_01', (0, 0, 1), turn*.35)
    rotate('spine_02', (0, 0, 1), turn*.3)
    rotate('spine_01', (1, 0, 0), lean*.5)
    rotate('spine_02', (1, 0, 0), lean*.5)
    rotate('neck_01', (0, 0, 1), -turn*.5)
    rotate('Head', (1, 0, 0), -lean*.6)
    hand = flow(of['hand'], tau)
    short[0] = (arm('r', hand, flow(of['pole'], tau))-hand).length
    # The wrist bends only so far: where the blade would lie nearer along
    # the forearm than that, it is held off it.
    fore = rig.pose.bones['lowerarm_r'].matrix.to_quaternion() @ V(0, 1, 0)
    blade = flow(of['blade'], tau).normalized()
    across = (blade-fore*blade.dot(fore)).normalized()
    angle = max(math.pi/2-WRIST_BEND, min(math.pi/2+WRIST_BEND, fore.angle(blade)))
    point_hand('r', fore*math.cos(angle)+across*math.sin(angle), fore)
    if twist:
        # A fist turned far round on the end of the forearm wrings the wrist:
        # the whole arm turns with it instead, the upper arm a little, the
        # forearm more, and the fist only what is left.
        at = (tau % 3.0)*TWIST_STEPS
        i = int(at)
        table = of['twist']
        turned = table[i]+(table[i+1]-table[i])*(at-i)
        hand = rig.pose.bones['hand_r'].matrix.copy()
        fore = rig.pose.bones['lowerarm_r'].matrix.copy()
        roll('upperarm_r', turned*ARM_ROLL[0])
        set_world(rig.pose.bones['lowerarm_r'], fore.translation, fore.to_quaternion())
        roll('lowerarm_r', turned*(ARM_ROLL[0]+ARM_ROLL[1]))
        set_world(rig.pose.bones['hand_r'], hand.translation, hand.to_quaternion())
    yielding[0] = yielded(tau, of)
    guard()
    yielding[0] = V(0, 0, 0)

# How far the planted feet were left short of their places (checked below).
stretch = [0.0]

def swing_feet(foot, u, settle=0.0):
    """The feet through a swing stepping with `foot` ('r' from his stance,
    'l' from the stance the other way about), `u` through it; then, `settle`
    through the recovery, back into his own stance if the swing left him the
    other way about (the front foot drawn back, the rear brought up)."""
    carried = sample(SWING_ADVANCE, u)
    a0, a1, distance, height = SWING_STRIDE
    w = max(0.0, min(1.0, (u-a0)/(a1-a0)))
    # Each foot's place behind where the stance has it, and its lift.
    back = {'l': 0.0, 'r': 0.0} if foot == 'r' else {'l': .5, 'r': -.5}
    lift = {'l': 0.0, 'r': 0.0}
    for s in 'lr': back[s] += carried
    back[foot] -= distance*ease(w)
    lift[foot] = height*math.sin(math.pi*w)
    if foot == 'r' and settle > 0:
        for s, a, b in [('r', 0.0, .5), ('l', .5, 1.0)]:
            w = max(0.0, min(1.0, (settle-a)/(b-a)))
            back[s] *= 1-ease(w)
            lift[s] = .06*math.sin(math.pi*w)
    stretch[0] = 0.0
    for s in 'lr':
        at = PLANTED[s]+V(0, back[s], lift[s])
        # (The knees bend more nearly forward than the splayed feet point.)
        leg(s, at, (rig.pose.bones['thigh_'+s].head+at)/2+(TOES[s]*.4+V(0, -.6, 0)).normalized()*.6)
        if lift[s] == 0: stretch[0] = max(stretch[0], (rig.pose.bones['foot_'+s].head-at).length)

# The hand's turn at each moment of the cycle, followed round it unbroken (it
# comes back to where it began: the arm is never wound up).
for i in range(3*TWIST_STEPS+1):
    reset()
    swing_pose(i/TWIST_STEPS, twist=False)
    angle = hand_twist()
    if TWIST: angle += 2*math.pi*round((TWIST[-1]-angle)/(2*math.pi))
    TWIST.append(angle)
# (Counted from the turn nearest none: the arm turns the short way round.)
middle = 2*math.pi*round((max(TWIST)+min(TWIST))/2/(2*math.pi))
TWIST[:] = [a-middle for a in TWIST]
print('SWING_TWIST', [round(math.degrees(a)) for a in TWIST[::12]], 'wound', round(math.degrees(TWIST[-1]-TWIST[0])))
TWIST.append(TWIST[-1])
# The opening's: followed back from the cut's landing, where it is the
# cycle's own, to the stance.
landing = TWIST_STEPS//2
OPEN_TWIST[:] = TWIST
for i in range(landing-1, -1, -1):
    reset()
    swing_pose(i/TWIST_STEPS, twist=False, of=OPENING)
    angle = hand_twist()
    OPEN_TWIST[i] = angle+2*math.pi*round((OPEN_TWIST[i+1]-angle)/(2*math.pi))
print('SWING_TWIST opening', [round(math.degrees(a)) for a in OPEN_TWIST[:landing+1:6]])
# The shield arm's yield at each moment of the cycle, spread round it
# unbroken; the opening's from its own wind-up, on into the cycle's (from
# the cut's landing the two swings are the same, and so, a reach on, are
# their yields). (Not wanted by a dry run of some skills alone.)
if not (DRY and ONLY):
    raw = []
    for i in range(3*TWIST_STEPS):
        reset()
        swing_pose(i/TWIST_STEPS)
        raw.append(needed_yield(raw[-1] if raw else None))
    cycle = spread(raw, SWING_YIELD_REACH, wrap=True)
    opening_raw = []
    for i in range(TWIST_STEPS+1):
        if i > landing:
            opening_raw.append(raw[i])
            continue
        reset()
        swing_pose(i/TWIST_STEPS, of=OPENING)
        opening_raw.append(needed_yield(opening_raw[-1] if opening_raw else None))
    OPEN_YIELD[:] = spread(opening_raw, SWING_YIELD_REACH)
    SWING_YIELD[:] = cycle+[cycle[0]]
    print('SWING_YIELD', [round(v.length, 2) for v in SWING_YIELD[::12]], 'opening', [round(v.length, 2) for v in OPEN_YIELD[:landing+1:6]])

# ---- Checking the swings: nothing through anything else ----

def near(p, a, b):
    """The point of the line a-b nearest p."""
    d = b-a
    return a+d*max(0.0, min(1.0, (p-a).dot(d)/max(1e-9, d.dot(d))))

def between(a0, a1, b0, b1, n=24):
    """The least distance between two lines' points (sampled along the first)."""
    return min((p-near(p, b0, b1)).length for p in (a0.lerp(a1, i/n) for i in range(n+1)))

def clearances():
    """How far the blade and the sword arm are from the body, the other arm
    and the shield (less than nothing: one is in the other), and how far the
    wrist is bent to hold the blade so (degrees)."""
    B = rig.pose.bones
    def head(n): return B[n].matrix.translation.copy()
    hand = B['hand_r'].matrix
    blade = (hand @ V(0, .075, 0), hand @ V(0, .075, 1.08))
    fore = (head('lowerarm_r'), head('hand_r'))
    top = head('Head')+(B['Head'].matrix.to_quaternion() @ V(0, 1, 0))*.13
    body = [('head', top, top, .13), ('neck', head('neck_01'), head('Head'), .07), ('chest', head('spine_02'), head('neck_01'), .15),
        ('belly', head('pelvis'), head('spine_02'), .15), ('upper arm', head('upperarm_l'), head('lowerarm_l'), .05),
        ('shield arm', head('lowerarm_l'), head('hand_l'), .05)]
    for s in 'lr':
        body += [('thigh '+s, head('thigh_'+s), head('calf_'+s), .085), ('shin '+s, head('calf_'+s), head('foot_'+s), .06),
            ('foot '+s, head('foot_'+s), head('ball_'+s), .05)]
    out = {}
    for name, a, b, r in body:
        out['blade / '+name] = between(blade[0], blade[1], a, b)-r-.045
        if name in ('head', 'chest', 'belly', 'thigh r', 'thigh l'): out['arm / '+name] = between(fore[0], fore[1], a, b)-r-.045
    # The round shield on the forearm (scripts/visual.gd SHIELD_CENTER, SHIELD_SIZE).
    board = B['lowerarm_l'].matrix
    centre = board @ V(0, .14, -.135)
    normal = (board.to_quaternion() @ V(0, 0, 1)).normalized()
    def off_board(a, b, r):
        gap = 9.0
        for i in range(41):
            d = a.lerp(b, i/40)-centre
            axial = abs(d.dot(normal))
            gap = min(gap, max(axial-.06-r, (d-normal*d.dot(normal)).length-.33-r))
        return gap
    out['blade / ground'] = min(blade[0].z, blade[1].z)-.045
    out['blade / shield'] = off_board(blade[0], blade[1], .045)
    out['arm / shield'] = off_board(fore[0], fore[1], .045)
    y = B['lowerarm_r'].matrix.to_quaternion() @ V(0, 1, 0)
    out['wrist'] = math.degrees(y.angle(B['hand_r'].matrix.to_quaternion() @ V(0, 1, 0)))
    out['twist'] = math.degrees(held.twist(B, 'r'))
    out['reach'] = short[0]
    out['stretch'] = stretch[0]
    return out

def author_swing(name, start, foot, opening=False):
    """One swing of the cycle from `start`, stepping with `foot`, then the
    recovery to the stance; `opening`, it winds up out of the stance instead
    of following on from the swing before."""
    a = bpy.data.actions.new(name)
    rig.animation_data.action = a
    swing = int(round(SWING_SECONDS*30))
    frames = swing+int(round(TAIL_SECONDS*30))
    worst = {}
    for f in range(frames+1):
        reset()
        if f <= swing:
            t = f/swing
            swing_pose(start+t, of=OPENING if opening else CYCLE)
            # (Its first key is the stance's own sword arm: only the rest of
            # him has to be eased out of the stance, the shield arm more
            # gently.)
            w = 1-ease(t/.1) if opening else 0.0
            arm_w = 1-ease(t/OPEN_RAISE) if opening else 0.0
            feet = (foot, t, 0.0)
        else:
            # On into the next swing as far as SWING_FOLLOW, exactly as the
            # next clip begins; from there it slows and settles to the stance.
            on = (f-swing)/swing
            x = max(0.0, on-SWING_FOLLOW)
            swing_pose(start+1+min(on, SWING_FOLLOW)+(x-x*x/.4 if x < .2 else .1))
            w = x/((frames-swing)/swing-SWING_FOLLOW)
            feet = (foot, 1.0, w)
            w = arm_w = ease(w)
        to_stance(w, arm_w)
        swing_feet(*feet)
        for k, v in clearances().items():
            if k in ('wrist', 'reach', 'stretch'): v = -v
            if k not in worst or v < worst[k][0]: worst[k] = (v, f/swing)
        keys(f)
    finish(name, a, frames/30)
    for k, (v, t) in sorted(worst.items(), key=lambda item: item[1][0]):
        if k in ('wrist', 'reach', 'stretch'): print('SWING_CHECK', name, k, round(-v, 3), 'at', round(t, 2))
        elif v < .08: print('SWING_CHECK', name, k, round(v, 3), 'at', round(t, 2))

# (A dry run of some skills alone leaves the attack cycle be.)
if not (DRY and ONLY):
    author_swing('SwordOpen', 0, 'r', opening=True)
    for start, name in enumerate(['SwordCut1', 'SwordCut2', 'SwordThrust']):
        for foot in 'rl': author_swing(name+foot.upper(), start, foot)

if os.environ.get('SWINGS_ONLY'):
    raise SystemExit

def probe():
    """SKILLS_PROBE=s,s,...: at those moments of Thunder Slam, the sword
    elbow's pole swept right round the arm's line (no swing allowed the fist)
    and the fist's turn printed for each: where the elbow should be asked for."""
    for s in [float(v) for v in os.environ['SKILLS_PROBE'].split(',')]:
        reset(); slam_body(s)
        shoulder = rig.pose.bones['upperarm_r'].matrix.translation.copy()
        hand = slam_hand(s)
        axis = (hand-shoulder).normalized()
        base = vsample(SLAM_POLE_PATH, s)
        chest = rig.pose.bones['spine_03'].matrix
        facing = (chest.to_quaternion() @ CHEST_FRONT).normalized()
        row = []
        for k in range(12):
            reset(); slam_body(s)
            pole = shoulder+Quaternion(axis, math.radians(30*k)) @ (base-shoulder)
            y, z, turned = held.fist(rig.pose.bones, 'r', lambda y: Vector(hand), vsample(SLAM_BLADE_PATH, s), None, pole, swing=0.0)
            B = rig.pose.bones
            point = B['lowerarm_r'].matrix.translation-(B['upperarm_r'].matrix.translation+B['hand_r'].matrix.translation)/2
            pn = point.normalized() if point.length > .01 else Vector((0, 0, 0))
            row.append('%3d:%4d/f%+.1f/u%+.1f' % (30*k, math.degrees(turned), pn.dot(facing), pn.z))
        print('SKILLS_PROBE %.2f pole %s |' % (s, ' '.join('%.2f' % v for v in base)), ' '.join(row))
    raise SystemExit

if os.environ.get('SKILLS_PROBE'): probe()
for name, pose in [('SkillCleave', cleave), ('SkillStrike', strike), ('SkillStab', stab), ('SkillBash', bash), ('SkillExecute', execute),
        ('SkillSlam', slam), ('SkillShockwave', shockwave), ('SkillCry', cry), ('SkillCharge', charge), ('SkillLeap', leap)]:
    if ONLY and name not in ONLY: continue
    author(name, pose)
author('DualSkillSlam', dual_slam, keep=('clavicle_l', 'upperarm_l', 'lowerarm_l', 'hand_l'))

rig.animation_data.action = None
# The clips that were there already all come in with their strips from frame
# 1, where these begin at 0, and the export begins every clip at 0: left so,
# each would go out a frame later and longer than it came in, held on its
# first pose. Those that began at once in the file (BEGAN, read from it
# above) are set back to begin at 0, so every clip goes out with the timing
# it came in with (as tools/import_pike.py does).
for track in rig.animation_data.nla_tracks:
    if track.name in REMADE or track.name in SWINGS or BEGAN.get(track.name, 1.0) > 1/60: continue
    for strip in list(track.strips):
        if strip.frame_start != 1: continue
        action, first, last, name = strip.action, strip.action_frame_start, strip.action_frame_end, strip.name
        track.strips.remove(strip)
        strip = track.strips.new(name, 0, action)
        strip.action_frame_start = first
        strip.action_frame_end = last
for track in rig.animation_data.nla_tracks: track.mute = False
used = {s.action for t in rig.animation_data.nla_tracks for s in t.strips}
for a in list(bpy.data.actions):
    if a not in used: bpy.data.actions.remove(a)
bpy.context.scene.frame_set(0)
if DRY: raise SystemExit(print('SKILLS_DRY: nothing written'))
bpy.ops.export_scene.gltf(filepath=str(GLB), export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS', export_force_sampling=True)
print('SKILL_ANIMATIONS_READY', len(rig.animation_data.nla_tracks))
