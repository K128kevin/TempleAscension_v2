"""Authors the warrior's two-handed clips onto the supplied rig (after
import_skills.py; safe to rerun): the stance and the blows of a heavy weapon
(a greatsword, a battle axe, a maul) held in both hands.

The weapon is keyed first and the man hung on it. Each frame says where the
right fist grips the haft, where the haft points and how the edge is turned;
the right hand is set outright on it, the left hand a fist's width (0.12 m)
down the haft toward the butt and turned to wrap it, and both arms are bent
to them by two-bone IK (the collar bones giving a little, the forearms rolled
after the fists). The body under it (hips, spine, head, the feet planted or
stepping by leg IK) is keyed alongside. A blow's path through space is keyed
apart from its timing, so the weapon runs along one smooth arc, slowly out of
the wind-up, at its fastest as it lands, and on through.

The grip (what the game must hold the weapon by): the weapon's length lies
along hand_r's own +Z through the hand's (0, .075, z), its edge along the
hand's X; the left palm, hand_l's (0, .075, 0), sits at hand_r's
(0, .075, -.12).

  HeavyIdle       the stance: the weapon held up before the right shoulder
                  in both hands, left foot forward, breathing (2 s, loops)
  HeavySwing1     normal attack: the weapon hauled far back over the right
                  shoulder, then the whole body hurled round and down behind
                  a diagonal cut to the lower left, the rear foot driven
                  through a long step forward as it lands (the game carries
                  him on by Visual.ROOT_ADVANCE); the lead foot comes up after
  HeavyCleave     a level sweep through the half-circle before him, coiled
                  round to the right and unwound, behind a step
  HeavyStrike     Powerful Strike: a full chop from over the right shoulder
                  straight down before him
  HeavyExecute    the weapon hauled far back over the head, the body arched,
                  then brought down with everything, down to the knee
  HeavySlam       Thunder Slam, one circle on his right: the weapon swung out
                  and down past his right hip and round behind him as the
                  chest turns away to it, the hands carried before the chest,
                  then all the way up behind him, over the head, and down
                  before him to meet the ground level, as a hammer meets a
                  nail, a stride ahead of a deep kneel; held; the rise
  HeavyShockwave  Shockwave: the weapon turned head down and hoisted as he
                  draws himself up, then rammed straight down into the ground
                  before his feet behind a stamp of the lead foot
  HeavyCry        War Cry: the weapon thrust at the sky in both hands, chest
                  open, head back
  HeavyLeap       Leap: the crouch, the spring, the tuck with the weapon
                  overhead, and the landing blow into the ground

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/import_heavy.py

  HERO_GLB=/path/to/warrior.glb   the model to read and write back
                                  (default assets/models/character/warrior.glb)
  HEAVY_ONLY=HeavyCleave,...      author only these clips (for trying one out)
  HEAVY_CHECK=1                   print each clip's measurements: reach, wrist
                                  bend, clearances, the weapon head's speed
  HEAVY_DRY=1                     author and check, but write nothing back
  SHEET_DIR=/path                 render each clip authored as a contact sheet
                                  there (tools/blender_sheet.py; implies
                                  HEAVY_DRY), at the moments SHEET_PHASES lists
"""
from pathlib import Path
import json, math, os, struct, sys
import bpy
from mathutils import Vector, Matrix, Quaternion
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
import blender_sheet as sheet
import blender_arm as grip
SHEET_DIR = os.environ.get('SHEET_DIR', '')
SHEET_PHASES = [float(v) for v in os.environ.get('SHEET_PHASES', '0,.08,.16,.24,.32,.4,.46,.52,.58,.62,.66,.75,.9,1').split(',')]
DRY = bool(os.environ.get('HEAVY_DRY')) or bool(SHEET_DIR)
GLB = Path(os.environ.get('HERO_GLB') or ROOT/'assets/models/character/warrior.glb')
if not GLB.is_absolute(): GLB = ROOT/GLB
# name: seconds
CLIPS = {'HeavyIdle': 2.0, 'HeavySwing1': 1.1, 'HeavyCleave': 1.0, 'HeavyStrike': 1.0, 'HeavyExecute': 1.3,
    'HeavySlam': 1.4, 'HeavyShockwave': 1.2, 'HeavyCry': 1.0, 'HeavyLeap': 1.0}
# name: the share of the clip at which the blow lands (the game's own figures).
CONTACT = {'HeavySwing1': .50, 'HeavyCleave': .52, 'HeavyStrike': .55, 'HeavyExecute': .58, 'HeavySlam': .66,
    'HeavyShockwave': .56, 'HeavyCry': .30, 'HeavyLeap': .56}
ONLY = [n for n in os.environ.get('HEAVY_ONLY', '').split(',') if n]
CHECK = int(os.environ.get('HEAVY_CHECK') or 0)
WANTED = [n for n in CLIPS if not ONLY or n in ONLY]
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
print('HEAVY_BEFORE', len(rig.animation_data.nla_tracks), 'clips')
# (A clip authored here once and since dropped, such as the second swing
# the normal attack had, goes too.)
STALE = ['HeavySwing2']
for track in list(rig.animation_data.nla_tracks):
    if track.name in WANTED or track.name in STALE: rig.animation_data.nla_tracks.remove(track)
for a in list(bpy.data.actions):
    if a.name in WANTED or a.name in STALE: bpy.data.actions.remove(a)
for track in rig.animation_data.nla_tracks: track.mute = True
B = rig.pose.bones

def V(x, y, z):
    return Vector((x, y, z))

def update():
    bpy.context.view_layer.update()

def frame(time):
    value = time*30
    bpy.context.scene.frame_set(math.floor(value), subframe=value % 1)
    update()

# What the two-handed stance is built on: the sword stance's legs and hips
# (left foot forward), so he moves off into a run from it as he does from that.
rig.animation_data.action = bpy.data.actions['SwordIdle']
frame(0)
BASE = {b.name: b.matrix_basis.copy() for b in B}
PLANTED = {s: B['foot_'+s].matrix.translation.copy() for s in 'lr'}
BALLS = {s: B['ball_'+s].matrix.translation.copy() for s in 'lr'}
KNEES = {s: B['calf_'+s].matrix.translation.copy() for s in 'lr'}
FOOT_TURN = {s: B['foot_'+s].matrix.to_quaternion() for s in 'lr'}
TOE_TURN = {s: B['ball_'+s].matrix.to_quaternion() for s in 'lr'}
grip.init(rig)
rig.animation_data.action = None

def reset():
    for b in B: b.matrix_basis = BASE[b.name]
    update()

def keys(f):
    for b in B:
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
    print('HEAVY_CLIP', name, length)

# ---- Curves ----

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

def hermite(x0, x1, v0, v1, m0, m1, x):
    h = x1-x0
    u = (x-x0)/h
    return v0*(2*u**3-3*u*u+1)+m0*(h*(u**3-2*u*u+u))+v1*(-2*u**3+3*u*u)+m1*(h*(u**3-u*u))

def clock(knots, t):
    """A blow's timing: how far along its path (`s`, which its poses are
    keyed against) it is at `t` of the clip, through (t, s, speed) knots
    (or (t, s, speed into it, speed out of it), where a blow is stopped)."""
    t = max(knots[0][0], min(knots[-1][0], t))
    for i in range(len(knots)-1):
        if t <= knots[i+1][0]:
            a, b = knots[i], knots[i+1]
            return hermite(a[0], b[0], a[1], b[1], a[-1], b[2], t)
    return knots[-1][1]

def slope(before, here, after, h0, h1):
    """A smooth curve's slope through a key: none at a turning point, and
    never so steep that the curve would run past its keys."""
    d0 = (here-before)/h0
    d1 = (after-here)/h1
    if d0*d1 <= 0: return 0.0
    m = (after-before)/(h0+h1)
    limit = 3*min(abs(d0), abs(d1))
    return max(-limit, min(limit, m))

def K(s, how='', **channels):
    """A pose of a blow at `s` along its path: what each channel is there
    (those not named are the stance's). `how`: 'stop', everything rests
    there; 'hit', the blow is stopped dead there (it arrives at full speed)."""
    return (s, channels, how)

def reach(s, a, how='', out=None, **channels):
    """A pose with the arms straight: the grip `out` metres from the middle
    of the shoulders along `a`, as the body channels place them at this
    pose (the figure is posed without its arms to find them)."""
    reset()
    c = {k: channels.get(k, STANCE[k]) for k in STANCE}
    body(**{k: c[k] for k in BODY+BACK})
    for side in 'lr':
        at = c[side+'f']
        foot(side, forward=at[0], lift=at[1], aside=at[2], heel=c[side+'h'], pivot=c[side+'p'], knee=c[side+'k'])
    mid = (B['upperarm_r'].matrix.translation+B['upperarm_l'].matrix.translation)/2
    # (Square to the line of the shoulders, so both arms reach it alike and
    # neither has to bend: the hands are before the chest, however it is turned.)
    line = (B['upperarm_r'].matrix.translation-B['upperarm_l'].matrix.translation).normalized()
    a = Vector(a)
    a = (a-line*a.dot(line)).normalized()
    return K(s, how, g=tuple(mid+a*(ARM_REACH if out is None else out)), **channels)

def value(rows, channel, s):
    """A channel carried smoothly through a blow's poses."""
    times = [r[0] for r in rows]
    s = max(times[0], min(times[-1], s))
    values = [r[1].get(channel, STANCE[channel]) for r in rows]
    vector = not isinstance(values[0], (int, float))
    if vector: values = [tuple(v) for v in values]
    i = max(k for k in range(len(rows)-1) if times[k] <= s)
    def tangent(k, of, out):
        if k == 0 or k == len(rows)-1 or rows[k][2] == 'stop': return 0.0
        if rows[k][2] == 'hit': return (of(k+1)-of(k))/(times[k+1]-times[k]) if out else (of(k)-of(k-1))/(times[k]-times[k-1])
        return slope(of(k-1), of(k), of(k+1), times[k]-times[k-1], times[k+1]-times[k])
    def along(of):
        return hermite(times[i], times[i+1], of(i), of(i+1), tangent(i, of, True), tangent(i+1, of, False), s)
    if not vector: return along(lambda k: values[k])
    return Vector([along(lambda k, c=c: values[k][c]) for c in range(len(values[0]))])

# ---- The rig's joints ----

def set_world(bone, position, rotation):
    bone.matrix = Matrix.Translation(position) @ rotation.to_matrix().to_4x4()
    update()

def rotate(name, axis, angle):
    """Turns a bone about a world axis, where it stands."""
    if angle == 0: return
    b = B[name]
    m = b.matrix.copy()
    set_world(b, m.translation, Quaternion(Vector(axis), angle) @ m.to_quaternion())

def shift(name, by):
    b = B[name]
    m = b.matrix.copy()
    set_world(b, m.translation+Vector(by), m.to_quaternion())

# What the last pose asked of the limbs beyond their reach (checked below).
short = {'arms': 0.0, 'legs': 0.0}

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

ARM = (B['lowerarm_r'].matrix.translation-B['upperarm_r'].matrix.translation).length+(B['hand_r'].matrix.translation-B['lowerarm_r'].matrix.translation).length
# (A grip asked for this far from the shoulders is drawn in to where both
# arms, straight, reach it.)
ARM_REACH = ARM+.1

def bend_axis(side):
    upper, lower, hand = (B[n+side].matrix.translation for n in ('upperarm_', 'lowerarm_', 'hand_'))
    return (lower-upper).cross(hand-lower).normalized()

def arm(side, target, pole):
    return grip.arm(B, side, target, pole)

def foot(side, forward=0.0, lift=0.0, aside=0.0, heel=0.0, pivot=0.0, knee=(0, 0, 0)):
    """A foot set over the ground: `forward`, `aside` (to his left) and
    `lift`ed from where the stance plants it; the `heel` raised and the foot
    `pivot`ed (to his left) about its ball, which stays where it is; the leg
    bent to it, the knee turned `knee` from where it would point."""
    step = V(aside, -forward, lift)
    ball = BALLS[side]
    toes = BALLS[side]-PLANTED[side]
    toes.z = 0
    turn = Quaternion(V(0, 0, 1), pivot) @ Quaternion(V(0, 0, 1).cross(toes.normalized()), heel)
    ankle = ball+step+turn @ (PLANTED[side]-ball)
    b = B['foot_'+side]
    pole = KNEES[side]+step+V(0, -.6-.6*lift, .5*lift)+Vector(knee)
    reached = two_bone(B['thigh_'+side], B['calf_'+side], b, ankle, pole)
    short['legs'] = max(short['legs'], (reached-ankle).length)
    set_world(b, b.matrix.translation, turn @ FOOT_TURN[side])
    # (The toes stay flat on the ground as the heel comes up.)
    toe = B['ball_'+side]
    set_world(toe, toe.matrix.translation, Quaternion(V(0, 0, 1), pivot) @ TOE_TURN[side])

def roll(name, angle):
    """Turns a bone about its own length, where it is."""
    b = B[name]
    m = b.matrix.copy()
    q = m.to_quaternion()
    set_world(b, m.translation, Quaternion(q @ V(0, 1, 0), angle) @ q)

def shrug(side, target):
    """The collar bone gives toward what the arm reaches for."""
    c = B['clavicle_'+side]
    m = c.matrix.copy()
    q = m.to_quaternion()
    y = q @ V(0, 1, 0)
    want = (Vector(target)-m.translation).normalized()
    angle = y.angle(want)
    if angle < 1e-4: return
    give = COLLAR_GIVE*math.tanh(.3*angle/COLLAR_GIVE)
    set_world(c, m.translation, Quaternion(y.cross(want).normalized(), give) @ q)

COLLAR_GIVE = math.radians(26)

# ---- The weapon in both hands ----

# The grip: the haft passes through each hand's PALM along the fingers from
# the wrist and PALM_IN toward the palm from the knuckles' plane (through
# the hollow of the curled fingers: scripts/visual.gd PALM_SEAT), along its
# own Z; the left hand holds it HANDS apart from the right, toward the butt.
PALM = .085
PALM_IN = .028
HANDS = .12
# (How far a wrist bends and a forearm turns: tools/blender_arm.py.)
# The weapon's ends from the right fist, for the checks: the battle axe's butt
# and head (its bits ACROSS either way from the haft), and the greatsword's point.
BUTT = .40
HEAD = .85
BITS = (.62, .2, .16)
POINT = 1.23
measured = {}
# (The stand-in for the sheets: a maul's haft and head, and a greatsword's point.)
if SHEET_DIR: sheet.prop(rig, 'hand_r', (-PALM_IN, PALM), [(-BUTT, HEAD, .014), (HEAD-.1, HEAD+.04, .07), (HEAD+.04, POINT, .006)])

# Where the elbows go is planned over the whole clip (author(), elbows()):
# each frame is posed (first as the search finds it, then as first planned)
# and what each way round each arm's line would cost there is measured
# (RECORD); the ways are then chosen for every frame together, so that each elbow goes where its fist
# needs it while turning round its arm no faster than it must, setting off
# before it has to; and the clip is keyed with the elbows set those ways
# (PLAN, in the chest's own frame). Searched afresh at each frame, an elbow
# was thrown from one side of its arm to the other wherever two ways were
# near enough as good: half round and back from frame to frame through the
# normal attack, and to and fro between two steps of the search with each
# breath of the stance.
RECORD = {}
PLAN = {}
# (How dear an elbow's turn round its arm is: this much for TURNING in a frame.)
TURNING = math.radians(15)
TURN_COST = .15
# (Clips whose elbows are keyed outright, each pose saying where they point.)
KEYED_ELBOWS = {'HeavySlam'}

def hold(at, haft, fingers, elbow_r, elbow_l, free=0.0, swing=math.radians(150), ease=.003):
    """Both hands on the weapon: the right fist's grip at `at`, the haft
    running along `haft` toward the weapon's head, the right hand turned
    about it so its fingers lie along `fingers` as far as the wrist allows
    (the edge then lies across both: a cut travels square to `haft` and
    `fingers`), or, `free`, along its own forearm. The left hand takes the
    haft below it, turned about it as its forearm carries it. The elbows
    bend toward `elbow_r` and `elbow_l` (from the shoulders), or swung round
    from there to where the forearms need not be wrung (tools/blender_arm.py);
    or, planned (PLAN), set the ways the plan has them."""
    z = Vector(haft).normalized()
    at = Vector(at)
    y = Vector(fingers)
    # (Fingers laid along the forearm, as far as `free`: the wrist then lies
    # between the shoulder and the grip, which the reach is checked with.)
    if free > 0: y = y.lerp((at-B['upperarm_r'].matrix.translation).normalized(), free)
    y = (y-z*y.dot(z)).normalized()
    shoulder_l = B['upperarm_l'].matrix.translation.copy()
    ly = (at-z*HANDS)-shoulder_l
    ly = (ly-z*ly.dot(z)).normalized()
    # (The right wrist sits PALM back along the fingers and PALM_IN out from
    # the palm; the left, mirrored, the other way out.)
    def wrist_r(y): return at-y*PALM+y.cross(z)*PALM_IN
    def wrist_l(ly): return at-z*HANDS-ly*PALM-ly.cross(z)*PALM_IN
    shrug('r', wrist_r(y))
    shrug('l', wrist_l(ly))
    shoulders = {s: B['upperarm_'+s].matrix.translation.copy() for s in 'lr'}
    # Neither arm is asked for more than its length: the weapon is drawn in
    # toward the middle of the shoulders, along the line it was asked on,
    # to where both arms reach it (straight, if it was asked beyond them).
    asked = at.copy()
    mid = (shoulders['r']+shoulders['l'])/2
    def over(k):
        g = mid+(asked-mid)*k
        # (Each hand's fingers lie across the haft, as near its own forearm's
        # line as that allows: the wrist sits PALM back from the grip that way.)
        r = g-shoulders['r']
        r = (y if free <= 0 else (r-z*r.dot(z))).normalized()
        l = (g-z*HANDS)-shoulders['l']
        l = (l-z*l.dot(z)).normalized()
        return max((g-r*PALM+r.cross(z)*PALM_IN-shoulders['r']).length, (g-z*HANDS-l*PALM-l.cross(z)*PALM_IN-shoulders['l']).length) > ARM-ease
    if over(1.0):
        lo, hi = 0.0, 1.0
        for i in range(14):
            k = (lo+hi)/2
            if over(k): hi = k
            else: lo = k
        at = mid+(asked-mid)*lo
    ly = (at-z*HANDS)-shoulders['l']
    ly = (ly-z*ly.dot(z)).normalized()
    short['arms'] = (at-asked).length
    # Each fist is set with its wrist bent no further than a wrist bends,
    # which may tip the haft; where the two would tip it differently it is
    # laid between them and both take the rest. Neither elbow is turned to
    # the chest's front. The left hand takes the haft with its thumb toward
    # the head, or toward the butt where that wrings it less (the hand is
    # too small to tell in the game; the forearm's turn is not).
    facing = (B['neck_01'].matrix.translation-B['spine_02'].matrix.translation).cross(shoulders['r']-shoulders['l']).normalized()
    chest = B['spine_03'].matrix.to_quaternion()
    force = {s: chest @ PLAN[s] for s in 'lr' if s in PLAN}
    def wrist_l2(ly): return at-z*HANDS-ly*PALM+ly.cross(z)*PALM_IN
    def right(z, y, deviation=True):
        measure = {}
        y, z, turn = grip.fist(B, 'r', wrist_r, z, y, shoulders['r']+Vector(elbow_r), swing=swing, hold=1.0-free, deviation=deviation, avoid=facing,
            smooth=True, force=force.get('r'), profile=measure if RECORD.get('on') else None)
        if measure: RECORD['r'] = measure
        return y, z, turn
    # (The left thumb lies along the haft toward the head unless the other
    # way wrings the forearm clearly less; and once it lies one way it is
    # kept so unless the other is clearly better (by 15 degrees). The plan
    # keeps the way it was found at each frame.)
    thumb = PLAN.get('thumb') or RECORD.get('thumb', 'head')
    margin = math.radians(15) if 'thumb' in RECORD else 0.0
    def left(haft, deviation=True):
        def take(way):
            measure = {}
            if way == 'head': ly, zl, tl = grip.fist(B, 'l', wrist_l, haft, None, shoulders['l']+Vector(elbow_l), swing=swing, deviation=deviation, avoid=facing,
                smooth=True, force=force.get('l'), profile=measure if RECORD.get('on') else None)
            else:
                ly, zl, tl = grip.fist(B, 'l', wrist_l2, -haft, None, shoulders['l']+Vector(elbow_l), swing=swing, deviation=deviation, avoid=facing,
                    smooth=True, force=force.get('l'), profile=measure if RECORD.get('on') else None)
                zl = -zl
            return (ly, zl, tl), way, measure
        def chosen(result):
            (ly, zl, tl), way, measure = result
            if measure: RECORD['l'] = measure
            RECORD['now'] = way
            return ly, zl, tl
        pose_a = {b.name: b.matrix_basis.copy() for b in B}
        first = take(thumb)
        if 'thumb' in PLAN or abs(first[0][2]) <= math.radians(60): return chosen(first)
        pose_b = {b.name: b.matrix_basis.copy() for b in B}
        for b in B: b.matrix_basis = pose_a[b.name]
        update()
        second = take('butt' if thumb == 'head' else 'head')
        if abs(second[0][2]) < abs(first[0][2])-margin: return chosen(second)
        for b in B: b.matrix_basis = pose_b[b.name]
        update()
        return chosen(first)
    y, z1, measured['twist r'] = right(z, y)
    ly, z2, measured['twist l'] = left(z1)
    if (z2-z1).length > 1e-4:
        z = z1.slerp(z2, .5).normalized()
        y = (y-z*y.dot(z)).normalized()
        y, z, measured['twist r'] = right(z, y, deviation=False)
        ly, z, measured['twist l'] = left(z, deviation=False)
    else: z = z1

# ---- The body ----

def body(down=0.0, fwd=0.0, side=0.0, turn=0.0, tilt=0.0, twist=0.0, lean=0.0, bend=0.0, hy=0.0, hp=0.0, **rest):
    """The hips sunk, carried forward and to his left; the hips' `turn` (to
    his left) and `tilt` (forward); the back's `twist` (to his left), `lean`
    (forward) and `bend` (to his left) above them; the head kept on what is
    before him, and turned `hy` (left) and `hp` (down) besides."""
    shift('pelvis', V(side, -fwd, -down))
    rotate('pelvis', (0, 0, 1), turn)
    rotate('pelvis', (1, 0, 0), tilt)
    for name, share in (('spine_01', .3), ('spine_02', .35), ('spine_03', .35)):
        rotate(name, (0, 0, 1), twist*share)
        rotate(name, (1, 0, 0), lean*share)
        rotate(name, (0, 1, 0), -bend*share)
    for name in ('neck_01', 'Head'):
        rotate(name, (0, 0, 1), (hy-.8*(turn+twist))*.5)
        rotate(name, (1, 0, 0), (hp-.6*(lean+tilt))*.5)
        rotate(name, (0, 1, 0), .6*bend*.5)

# The stance: turned side-on behind the left shoulder like a man about to
# fell a tree, the weapon upright before the right shoulder, its head back
# over it and clear of his own.
STANCE = dict(down=.03, fwd=0.0, side=0.0, turn=-.08, tilt=0.0, twist=-.3, lean=.06, bend=0.0, hy=0.0, hp=0.0,
    g=(-.14, -.2, 1.15), z=(-.54, .34, .78), n=(.7, -.5, .5), nf=0.0, er=(-.5, .3, -.7), el=(.55, .1, -.7),
    lf=(0, 0, 0), rf=(0, 0, 0), lh=0.0, rh=0.0, lp=0.0, rp=0.0, lk=(0, 0, 0), rk=(0, 0, 0), es=150.0, ea=.003)
# (`nf`: how far the right fingers are laid along the forearm instead of `n`;
# `es`: how far round the arm's line, degrees, an elbow may be swung from
# where it is asked for the fist's sake; `ea`: how far short of straight,
# metres, the arms are kept when a grip is drawn in to them.)
BODY = ('down', 'fwd', 'side', 'turn', 'tilt')
BACK = ('twist', 'lean', 'bend', 'hy', 'hp')
# The hips lead a blow and the back follows them, the arms last: how far
# ahead of the weapon each runs (of the clip).
LEAD = (.03, .015)

def pose(c, carried=0.0):
    """Sets the whole figure from its channels (`c`, a name to its value)."""
    body(**{k: c[k] for k in BODY+BACK}|{'fwd': c['fwd']-carried})
    for s in 'lr':
        at = c[s+'f']
        foot(s, forward=at[0]-carried, lift=at[1], aside=at[2], heel=c[s+'h'], pivot=c[s+'p'], knee=c[s+'k'])
    hold(c['g'], c['z'], c['n'], c['er'], c['el'], free=c['nf'], swing=math.radians(c['es']), ease=c['ea'])

def play(t, knots, rows, advance=None):
    """A blow at `t` of its clip: its poses `rows` run through at the pace
    `knots` set, the body a little ahead of the arms."""
    window = ease(t/.12)*ease((1-t)/.12)
    s = clock(knots, t)
    ahead = {k: clock(knots, t+LEAD[0]*window) for k in BODY}|{k: clock(knots, t+LEAD[1]*window) for k in BACK}
    c = {k: value(rows, k, ahead.get(k, s)) for k in STANCE}
    pose(c, sample(advance, t) if advance else 0.0)

def plane(normal, toward, degrees):
    """A direction in the plane square to `normal`: `toward` (laid into the
    plane), swung back `degrees` about the normal (clockwise, seen from
    where the normal points)."""
    n = Vector(normal).normalized()
    u = Vector(toward)
    u = (u-n*u.dot(n)).normalized()
    return tuple(Quaternion(n, -math.radians(degrees)) @ u)

# ---- Checking: nothing through anything else, the blow fastest as it lands ----

def near(p, a, b):
    """The point of the line a-b nearest p."""
    d = b-a
    return a+d*max(0.0, min(1.0, (p-a).dot(d)/max(1e-9, d.dot(d))))

def between(a0, a1, b0, b1, n=24):
    """The least distance between two lines' points (sampled along the first)."""
    return min((p-near(p, b0, b1)).length for p in (a0.lerp(a1, i/n) for i in range(n+1)))

def measure():
    """The weapon's clearances from the body and the ground (less than
    nothing: it is in them), the wrists' bends (degrees), and the rest."""
    def head(n): return B[n].matrix.translation.copy()
    hand = B['hand_r'].matrix
    haft = (hand @ V(0, PALM, -BUTT), hand @ V(0, PALM, POINT))
    bits = (hand @ V(-BITS[1], PALM, BITS[0]), hand @ V(BITS[1], PALM, BITS[0]))
    top = head('Head')+(B['Head'].matrix.to_quaternion() @ V(0, 1, 0))*.13
    parts = [('head', top, top, .14), ('neck', head('neck_01'), head('Head'), .07), ('chest', head('spine_02'), head('neck_01'), .15),
        ('shoulders', head('upperarm_l'), head('upperarm_r'), .09), ('belly', head('pelvis'), head('spine_02'), .15)]
    for s in 'lr':
        parts += [('thigh '+s, head('thigh_'+s), head('calf_'+s), .085), ('shin '+s, head('calf_'+s), head('foot_'+s), .06),
            ('foot '+s, head('foot_'+s), head('ball_'+s), .05), ('upper arm '+s, head('upperarm_'+s), head('lowerarm_'+s), .055)]
    out = {}
    for name, a, b, r in parts:
        out[name] = min(between(haft[0], haft[1], a, b)-r-.03, between(bits[0], bits[1], a, b)-r-BITS[2])
    # (Neither arm through the trunk: each arm's bones against the chest and belly.)
    for s in 'lr':
        for bone, a, b in (('upper arm', head('upperarm_'+s), head('lowerarm_'+s)), ('forearm', head('lowerarm_'+s), head('hand_'+s))):
            for name, c, d, r in parts[2:5]:
                if name == 'shoulders': continue
                out['%s %s / %s' % (bone, s, name)] = between(a, b, c, d)-r-.045
    out['ground'] = min(haft[0].z, (hand @ V(0, PALM, HEAD)).z, haft[1].z)
    out['ground axe'] = min(haft[0].z, (hand @ V(0, PALM, HEAD)).z, bits[0].z-BITS[2], bits[1].z-BITS[2])
    facing = (head('neck_01')-head('spine_02')).cross(head('upperarm_r')-head('upperarm_l')).normalized()
    for s in 'lr':
        fore = B['lowerarm_'+s].matrix.to_quaternion() @ V(0, 1, 0)
        hq = B['hand_'+s].matrix.to_quaternion()
        hy = hq @ V(0, 1, 0)
        out['wrist '+s] = -math.degrees(fore.angle(hy))
        # (Bent back, away from the palm: the worst of a wrist's bends.)
        back = -(hy-fore*hy.dot(fore)).dot(hq @ V(grip.PALM_SIDE[s], 0, 0))
        out['wrist back '+s] = -math.degrees(fore.angle(hy)) if back > 0 else 0.0
        # (An elbow pointed forward of the chest reads as bent the wrong way:
        # less than nothing here is its point turned toward the chest's front.)
        point = B['lowerarm_'+s].matrix.translation-(B['hand_'+s].matrix.translation+B['upperarm_'+s].matrix.translation)/2
        out['elbow '+s] = -point.normalized().dot(facing)*.1 if point.length > .01 else 0.0
    out['gap'] = -((B['hand_l'].matrix @ V(0, PALM, 0))-(hand @ V(0, PALM, -HANDS))).length
    out['arms short'] = -short['arms']
    out['legs short'] = -short['legs']
    for s in 'lr': out['twist '+s] = -abs(math.degrees(measured['twist '+s]))+80.0
    out['shoulders at'] = (head('upperarm_r'), head('upperarm_l'))
    out['foot l'] = B['foot_l'].matrix.translation.copy()
    out['foot r'] = B['foot_r'].matrix.translation.copy()
    out['tip'] = hand @ V(0, PALM, HEAD)
    out['edge'] = hand.to_quaternion() @ V(1, 0, 0)
    out['along'] = hand.to_quaternion() @ V(0, 0, 1)
    return out

def report(name, frames, log):
    worst = {}
    for f, m in enumerate(log):
        for k, v in m.items():
            if isinstance(v, float) and (k not in worst or v < worst[k][0]): worst[k] = (v, f/frames)
    print('HEAVY_CHECK', name, ' '.join('%s %.3f@%.2f' % (k, v, t) for k, (v, t) in sorted(worst.items(), key=lambda item: item[1][0]) if v < .06))
    speeds = [0.0]+[(log[f]['tip']-log[f-1]['tip']).length*30*frames/(CLIPS[name]*30) for f in range(1, frames+1)]
    top = max(speeds)
    peak = speeds.index(top)
    fast = [f for f in range(1, frames+1) if speeds[f] >= .5*top and all(speeds[k] >= .5*top for k in range(min(f, peak), max(f, peak)+1))]
    # (The edge is looked at about the blow itself.)
    at = CONTACT.get(name, .5)*frames
    off = 0.0
    for f in [f for f in fast if at-.14*frames <= f <= at+.1*frames]:
        go = log[f]['tip']-log[f-1]['tip']
        go = go-log[f]['along']*go.dot(log[f]['along'])
        off = max(off, math.degrees(min(go.angle(log[f]['edge']), go.angle(-log[f]['edge']))))
    print('HEAVY_CHECK', name, 'head fastest %.1f m/s at %.3f; over half that from %.3f to %.3f; edge off its travel by up to %d deg about the blow' % (
        top, (speeds.index(top)-.5)/frames, (fast[0]-1)/frames, fast[-1]/frames, off))
    print('HEAVY_CHECK', name, 'speeds', ' '.join('%.0f' % v for v in speeds))

def elbows(records):
    """Each elbow's way off its arm's line at every frame (in the chest's own
    frame), from what each way cost at each (RECORD): the ways that cost
    least over the whole clip, a turn round the arm counted TURN_COST for
    every TURNING it makes in a frame (squared), by dynamic programming; the
    ways then eased a little from frame to frame (the plan's steps are
    7.5 degrees). Also the left thumb's way at each frame."""
    plan = [{'thumb': r['thumb']} for r in records]
    for side in 'lr':
        ways = [[r['chest'] @ w for w in r[side]['ways']] for r in records]
        costs = [r[side]['costs'] for r in records]
        n = len(ways[0])
        total = list(costs[0])
        back = []
        for f in range(1, len(records)):
            step, now = [], []
            for j in range(n):
                best, at = None, 0
                for i in range(n):
                    turn = ways[f-1][i].angle(ways[f][j], 0.0)
                    c = total[i]+TURN_COST*(turn/TURNING)**2
                    if best is None or c < best: best, at = c, i
                step.append(at)
                now.append(best+costs[f][j])
            back.append(step)
            total = now
        k = min(range(n), key=lambda j: total[j])
        path = [k]
        for step in reversed(back):
            k = step[k]
            path.append(k)
        path.reverse()
        chosen = [ways[f][k] for f, k in enumerate(path)]
        for f in range(len(records)):
            eased = chosen[max(0, f-1)]+2*chosen[f]+chosen[min(len(records)-1, f+1)]
            plan[f][side] = eased.normalized() if eased.length > 1e-6 else chosen[f]
    return plan

def author(name, clip):
    length = CLIPS[name]
    a = bpy.data.actions.new(name)
    rig.animation_data.action = a
    frames = int(round(length*30))
    log = []
    # The elbows planned over the whole clip first (elbows()), and planned
    # again from the clip posed as first planned (what each way costs
    # depends on the other arm, and the weapon on both).
    # (Thunder Slam keys its elbows outright, smooth already: it is not planned.)
    plan = None if name not in KEYED_ELBOWS else [{} for f in range(frames+1)]
    RECORD.clear()
    for planning in range(0 if plan else 2):
        records = []
        for f in range(frames+1):
            reset()
            short['legs'] = 0.0
            PLAN.clear()
            if plan: PLAN.update(plan[f])
            RECORD['on'] = True
            clip(f/frames)
            RECORD['thumb'] = RECORD.get('now', 'head')
            records.append({'chest': B['spine_03'].matrix.to_quaternion().inverted(), 'r': RECORD['r'], 'l': RECORD['l'], 'thumb': RECORD['thumb']})
        plan = elbows(records)
    RECORD.clear()
    for f in range(frames+1):
        reset()
        short['legs'] = 0.0
        PLAN.clear()
        PLAN.update(plan[f])
        clip(f/frames)
        if CHECK:
            log.append(measure())
            if CHECK > 1:
                m = log[-1]
                part = min((k for k in m if isinstance(m[k], float) and not k.startswith(('wrist', 'twist', 'gap', 'arms', 'legs', 'ground'))), key=lambda k: m[k])
                print('HEAVY_FRAME %s %2d %.3f wrist %3d %3d twist %4d %4d short %.3f %.3f ground %.2f %.2f %s %.3f R %s L %s G %s' % (name, f, f/frames, -m['wrist r'], -m['wrist l'],
                    math.degrees(measured['twist r']), math.degrees(measured['twist l']), short['arms'], short['legs'], m['ground'], m['ground axe'], part, m[part],
                    ' '.join('%.2f' % v for v in m['shoulders at'][0]), ' '.join('%.2f' % v for v in m['shoulders at'][1]), ' '.join('%.2f' % v for v in B['hand_r'].matrix @ V(0, PALM, 0))))
        keys(f)
    PLAN.clear()
    finish(name, a, length)
    if CHECK: report(name, frames, log)
    if SHEET_DIR:
        def at(t):
            reset()
            short['legs'] = 0.0
            # (The elbows as planned at the nearest frame.)
            PLAN.clear()
            PLAN.update(plan[max(0, min(frames, round(t*frames)))])
            clip(t)
        sheet.render(rig, name, SHEET_PHASES, SHEET_DIR, at)

# ---- The clips ----

def idle(t):
    # Breathing: the chest rises and the weapon with it, the weight swaying a
    # little from foot to foot (one breath to the loop).
    breath = .5-.5*math.cos(2*math.pi*t)
    sway = math.sin(2*math.pi*t)
    c = dict(STANCE)
    c['down'] += .012*breath
    c['side'] += .008*sway
    c['lean'] += .02*breath
    c['twist'] += .015*sway
    c['g'] = Vector(c['g'])+V(.004*sway, 0, .006-.014*breath)
    c['z'] = Vector(c['z'])+V(.02*sway, -.03*breath, 0)
    pose(c)

# A blow's path is keyed by its poses: 0 the stance, 1 wound up, 2 the blow
# landing, 3 followed through (or held, where it is stopped), 4 the stance
# again; its clock says when it is where along that.
FORWARD = (0, -1, 0)

# The swing: the weapon hauled far up and back over the right shoulder until
# its head hangs behind him, the body wound away after it and leaning back,
# the weight on the rear foot; then the rear (right) foot driven through a
# long step forward and the whole body hurled round and down behind the
# blow, which lands before him as the foot does and runs on down to the lower
# left and round behind him; and the left foot is brought up after as the
# weapon comes back to the shoulder. The game carries him over the ground as
# he steps (ROOT_ADVANCE, with these keys); here each foot is kept where it
# is on the ground while he is carried past it.
CUT = (.62, .1, .78)
SWING1_ADVANCE = [(0, 0), (.3, 0), (.5, .44), (.64, .5), (.9, .62), (1, .62)]
SWING1_CLOCK = [(0, 0, 0), (.14, .5, 2.6), (.27, .92, 1.5), (.37, 1, .6), (.50, 2, 12, 8), (.65, 3, 1.0), (1, 4, 0)]
SWING1 = [K(0),
    # (Wound up as a batter loads: the hands drawn back past the right
    # shoulder, the right elbow pulled behind him and the arms stretched
    # back, the weapon's head hanging behind.)
    K(.5, down=.06, fwd=-.08, side=-.02, turn=-.3, twist=-.55, lean=-.08, bend=-.05, g=(-.42, .36, 1.52), z=plane(CUT, FORWARD, 150), n=CUT,
        er=(-.6, .6, -.15), el=(.35, -.3, -.45), lh=.2),
    K(1, down=.09, fwd=-.14, side=-.04, turn=-.42, tilt=-.04, twist=-.8, lean=-.16, bend=-.08, g=(-.46, .56, 1.48), z=plane(CUT, FORWARD, 158), n=CUT,
        er=(-.45, .85, -.2), el=(.4, -.05, -.5), lh=.3),
    K(1.5, down=.12, fwd=.1, side=-.02, turn=-.12, twist=-.25, lean=.14, bend=-.02, g=(-.22, -.36, 1.56), z=plane(CUT, FORWARD, 96), n=CUT,
        er=(-.7, .1, -.3), el=(.4, -.4, -.6), lh=.1, rf=(.3, .14, 0)),
    K(2, down=.17, fwd=.38, side=.04, turn=.3, tilt=.05, twist=.5, lean=.38, bend=.06, g=(.1, -.6, .94), z=plane(CUT, FORWARD, -12), n=CUT,
        er=(-.7, -.3, -.2), el=(.7, -.1, -.5), rf=(.62, 0, 0), lh=.5, lp=.25),
    K(2.5, down=.21, fwd=.44, side=.05, turn=.4, tilt=.07, twist=.66, lean=.44, bend=.1, g=(.28, -.5, .78), z=plane(CUT, FORWARD, -64), n=(.6, .0, .8),
        er=(-.6, -.5, -.1), el=(.75, .25, -.35), rf=(.62, 0, 0), lh=.6, lp=.3),
    K(3, down=.21, fwd=.46, side=.05, turn=.42, tilt=.07, twist=.72, lean=.44, bend=.12, g=(.4, -.32, .78), z=plane(CUT, FORWARD, -104), n=(.55, .15, .8),
        er=(-.5, -.6, -.1), el=(.75, .45, -.25), rf=(.62, 0, 0), lh=.6, lp=.3),
    K(3.33, down=.16, fwd=.5, turn=.3, twist=.5, lean=.32, g=(.2, -.44, .96), z=(.6, -.2, .75), n=(.5, .2, .8), rf=(.62, 0, 0), lf=(.3, .1, 0)),
    K(3.66, down=.1, fwd=.56, turn=.1, twist=.1, lean=.2, g=(.02, -.44, 1.12), z=(.05, -.3, .95), n=(.4, -.8, .4), rf=(.62, 0, 0), lf=(.56, .03, 0)),
    K(3.86, down=.05, fwd=.6, turn=-.04, twist=-.2, lean=.1, g=(-.15, -.34, 1.14), z=(-.42, .05, .9), n=(.6, -.6, .5), rf=(.62, 0, 0), lf=(.62, 0, 0)),
    K(4, fwd=.62, lf=(.62, 0, 0), rf=(.62, 0, 0))]

def swing1(t):
    play(t, SWING1_CLOCK, SWING1, SWING1_ADVANCE)

# Cleave: the weapon drawn back level at the right side, the body coiled far
# round after it; then the left foot driven forward and everything unwound,
# the weapon swept flat through the whole half-circle before him and on round
# to the left; the rear foot is brought up after. The game carries him over
# the ground as he steps (ROOT_ADVANCE, with these keys); here each foot is
# kept where it is on the ground while he is carried past it.
CLEAVE_ADVANCE = [(0, 0), (.32, 0), (.52, .38), (.66, .4), (1, .4)]
LEVEL = (0, .08, 1)
CLEAVE_CLOCK = [(0, 0, 0), (.27, .9, 1.6), (.40, 1, .5), (.52, 2, 11.5), (.64, 3, 1.6), (1, 4, 0)]
CLEAVE = [K(0),
    K(1, down=.08, fwd=-.06, side=-.03, turn=-.45, twist=-.75, lean=.02, g=(-.32, .08, 1.22), z=plane(LEVEL, FORWARD, 135), n=LEVEL,
        er=(-.6, .6, -.3), el=(.2, -.6, -.5), lh=.2),
    K(1.5, down=.1, fwd=.14, turn=-.1, twist=-.2, lean=.12, g=(-.24, -.3, 1.16), z=plane(LEVEL, FORWARD, 68), n=LEVEL,
        er=(-.7, .2, -.4), el=(.4, -.4, -.6), lf=(.2, .1, 0), rh=.25),
    K(2, down=.14, fwd=.32, side=.03, turn=.25, twist=.35, lean=.22, g=(.0, -.58, 1.12), z=plane(LEVEL, FORWARD, 0), n=LEVEL,
        er=(-.7, -.1, -.5), el=(.7, -.1, -.5), lf=(.4, 0, 0), rf=(.03, 0, 0), rh=.5, rp=.35),
    K(2.5, down=.13, fwd=.35, side=.04, turn=.4, twist=.6, lean=.2, g=(.3, -.38, 1.1), z=plane(LEVEL, FORWARD, -68), n=LEVEL,
        er=(-.6, -.4, -.4), el=(.7, .3, -.4), lf=(.4, 0, 0), rf=(.08, 0, 0), rh=.55, rp=.45),
    K(3, down=.11, fwd=.37, side=.04, turn=.45, twist=.78, lean=.14, g=(.38, -.06, 1.12), z=plane(LEVEL, FORWARD, -128), n=LEVEL,
        er=(-.5, -.6, -.3), el=(.7, .5, -.3), lf=(.4, 0, 0), rf=(.1, .02, 0), rh=.6, rp=.45),
    K(3.33, down=.1, fwd=.39, turn=.3, twist=.5, lean=.12, g=(.3, -.2, 1.1), z=(.55, .2, .8), n=(.3, -.5, .8), lf=(.4, 0, 0), rf=(.18, .07, 0), rh=.4),
    K(3.66, down=.06, fwd=.4, turn=.1, twist=.05, lean=.12, g=(.03, -.42, 1.12), z=(.05, -.25, .97), n=(.4, -.8, .2), lf=(.4, 0, 0), rf=(.34, .05, 0)),
    K(3.86, down=.04, fwd=.4, turn=-.04, twist=-.2, lean=.08, g=(-.15, -.34, 1.14), z=(-.42, .05, .9), n=(.6, -.6, .5), lf=(.4, 0, 0), rf=(.4, 0, 0)),
    K(4, fwd=.4, lf=(.4, 0, 0), rf=(.4, 0, 0))]

def cleave(t):
    play(t, CLEAVE_CLOCK, CLEAVE, CLEAVE_ADVANCE)

# Powerful Strike: both hands thrown up over the head, the weapon tipped
# back behind it, up onto the toes; then chopped straight down before him
# with a bend of the whole body, and stopped in what it strikes.
CHOP = (1, 0, 0)
HIGH = dict(er=(-.9, -.3, .1), el=(.9, -.3, .1))
# (A blow brought down before him goes up over the right shoulder, the hands
# passing beside the head, and comes down along his left side, the body turned
# in behind it: the butt of the haft, a hand's breadth below the left hand,
# passes his left ribs.)
OVER = (.97, -.2, .15)
STRIKE_CLOCK = [(0, 0, 0), (.26, .9, 1.6), (.39, 1, 2.5), (.55, 2, 9, 2.5), (.7, 3, 0), (1, 4, 0)]
STRIKE = [K(0),
    K(.5, down=.07, twist=-.2, lean=.1, g=(-.16, -.26, 1.42), z=plane(OVER, FORWARD, 88), n=OVER, er=(-.8, .0, -.5), el=(.8, -.1, -.5)),
    K(1, down=-.03, fwd=-.06, turn=.0, twist=.1, lean=-.18, g=(-.17, .02, 1.86), z=plane(OVER, FORWARD, 138), n=OVER, lh=.3, rh=.35, hp=-.1, **HIGH),
    K(1.5, down=.03, fwd=.04, turn=.08, twist=.36, lean=.06, g=(-.08, -.44, 1.74), z=plane(OVER, FORWARD, 72), n=OVER, lh=.15, rh=.4, **HIGH),
    K(2, 'hit', down=.2, fwd=.14, side=-.04, turn=.18, twist=.56, lean=.34, g=(.1, -.68, 1.02), z=plane(OVER, FORWARD, -4), n=OVER, rh=.55, rp=.3,
        er=(-.9, -.2, -.3), el=(.9, .1, -.3)),
    K(3, down=.23, fwd=.14, side=-.04, turn=.18, twist=.56, lean=.38, g=(.1, -.66, .96), z=plane(OVER, FORWARD, -11), n=OVER, rh=.55, rp=.3,
        er=(-.9, -.2, -.3), el=(.9, .1, -.3)),
    K(3.5, down=.16, fwd=.1, twist=.2, lean=.3, g=(.02, -.48, 1.04), z=plane(OVER, FORWARD, 42), n=(.8, -.5, .3), rh=.3),
    K(4)]

def strike(t):
    play(t, STRIKE_CLOCK, STRIKE)

# Execute: the weapon hauled far back behind the head until it hangs down
# his back, the body arched after it, up on the toes; then the lead foot is
# thrown forward and he comes down with everything, onto the rear knee, the
# weapon's head brought down to the ground before him; and a slow recovery.
EXECUTE_CLOCK = [(0, 0, 0), (.3, .85, 1.8), (.43, 1, 2.5), (.58, 2, 8.5, 2), (.78, 3, 0), (1, 4, 0)]
KNEEL = dict(lf=(.3, 0, 0), rh=1.05, rk=(0, .2, -.9))
EXECUTE = [K(0),
    K(.5, down=.07, twist=-.2, lean=.08, g=(-.16, -.24, 1.46), z=plane(OVER, FORWARD, 96), n=OVER, er=(-.8, .0, -.5), el=(.8, -.1, -.5)),
    K(1, down=-.04, fwd=-.1, turn=.0, twist=.1, lean=-.34, tilt=-.06, g=(-.17, .12, 1.86), z=plane(OVER, FORWARD, 172), n=OVER, lh=.35, rh=.4, hp=-.15, **HIGH),
    K(1.5, down=.05, fwd=.08, turn=.08, twist=.36, lean=-.08, hp=-.2, g=(-.1, -.3, 1.82), z=plane(OVER, FORWARD, 85), n=OVER, lf=(.16, .1, 0), rh=.5, **HIGH),
    K(1.75, down=.26, fwd=.16, side=-.03, turn=.14, twist=.48, lean=.16, tilt=.04, hp=-.3, g=(.04, -.64, 1.3), z=plane(OVER, FORWARD, 26), n=OVER, lf=(.28, .03, 0), rh=.8,
        er=(-.9, -.2, -.1), el=(.9, .0, -.1)),
    K(2, 'hit', down=.45, fwd=.2, side=-.05, turn=.18, twist=.58, lean=.46, tilt=.1, hp=-.15, g=(.12, -.7, .6), z=plane(OVER, FORWARD, -32), n=OVER,
        er=(-.9, -.2, -.2), el=(.9, .1, -.2), **KNEEL),
    K(3, down=.48, fwd=.2, side=-.05, turn=.18, twist=.58, lean=.55, tilt=.1, g=(.12, -.67, .57), z=plane(OVER, FORWARD, -34), n=OVER,
        er=(-.9, -.2, -.2), el=(.9, .1, -.2), **KNEEL),
    K(3.5, down=.32, fwd=.14, twist=.25, lean=.42, g=(.04, -.52, .9), z=plane(OVER, FORWARD, 30), n=(.8, -.5, .2), lf=(.24, .02, 0), rh=.8, rk=(0, .1, -.5)),
    K(4)]

def execute(t):
    play(t, EXECUTE_CLOCK, EXECUTE)

# Thunder Slam, after film of the swing made with a stick in both hands, and
# the user's drawing of the head's path: one circle on his right. From the
# stance the chest turns away to his right, carrying the hands down before it
# as he sinks and leans into it, and the weapon's head swings out and down to
# his right, past his right hip at the height of the belt (the lowest it ever
# goes: it never drops to the foot behind him), and on round behind him; and
# from there it rises all the way: up behind him as the hands come up before
# the chest past the right shoulder, over the head as the back arches and the
# heels rise; the weapon whips over the top, and the whole body is hurled
# forward and down behind it on a long stride of the left foot, the head
# smashed into the ground ahead, level, as a hammer meets a nail; held; and
# the weapon is swung up before him back onto the shoulder. The hands keep
# together on the haft; the fingers lie along their forearms. (The clock
# lingers a little at the top and brings the weapon down from it fast, at
# its fastest as it lands.)
SLAM_CLOCK = [(0, 0, 0), (.03, .03, 1.0), (.57, .52, 1.5), (.66, .66, 1.4, 0), (.72, .72, 0), (1, 1, 0)]
DOWN = dict(er=(-.9, -.3, -.1), el=(.9, .1, -.1))
LUNGE = dict(rh=.8, rk=(0, .1, -.4))

def chest():
    """The middle of the shoulders and the chest's own ways as it stands:
    forward, to his right, and up along the spine."""
    right = (B['upperarm_r'].matrix.translation-B['upperarm_l'].matrix.translation).normalized()
    up = B['neck_01'].matrix.translation-B['spine_02'].matrix.translation
    up = (up-right*up.dot(right)).normalized()
    return (B['upperarm_r'].matrix.translation+B['upperarm_l'].matrix.translation)/2, up.cross(right), right, up

def in_chest(v, frame):
    """A direction given in the chest's own ways (forward, right, up), in the world's."""
    mid, f, r, u = frame
    return f*v[0]+r*v[1]+u*v[2]

def wrist(fore, pole, cock, turn):
    """The weapon's way from a right fist on a forearm running along `fore`
    with its elbow pointed toward `pole`: cocked `cock` degrees from the
    forearm's line (square across it at 90, back toward the elbow past that)
    and turned `turn` degrees about it from the elbow's pit, where the thumb
    points at the forearm's middle turn."""
    pit = -(pole-fore*pole.dot(fore)).normalized()
    turn, cock = math.radians(turn), math.radians(cock)
    return fore*math.cos(cock)+(pit*math.cos(turn)+fore.cross(pit)*math.sin(turn))*math.sin(cock)

# The swing is keyed as a man swings it, rather than as the weapon's path
# (which, keyed outright, asked the wrists and elbows for what they could not
# give, so that the fist tipped the weapon and the elbows swung round from one
# frame to the next, and asked the hands for places right of the chest that
# drew the arms in through it):
# where the hands are, as a direction from the middle of the shoulders in
# the chest's own ways (`a`) and a reach along it (`o`); where the right
# elbow points (`pr`, the chest's ways); and how the right wrist holds the
# weapon (`k`, its cock, and `tw`, its turn: wrist()). All of it is found
# again each frame about the chest as it then stands, so the hands are
# carried round by the chest as it turns, always before it, where both arms
# reach them without either crossing into it, and nothing is ever asked of a
# wrist or a forearm that it cannot do, so nothing is tipped or turned over
# for it between two frames: the weapon's head goes round on one smooth
# path, and the elbows and fists with it. The left elbow points away from
# the side of its arm the weapon's head lies on, where the left fist (its
# thumb toward the head) need not be turned on its forearm at all. `w`
# blends all this in from the stance as HeavyIdle begins (its keys read off
# it, and the whole figure eased to it as `w` falls) and back out to it, so
# the clip leaves the stance and comes back to it without a seam.
reset()
idle(0.0)
IDLE = {b.name: b.matrix_basis.copy() for b in B}
_frame = chest()
_poles = []
for _s in 'rl':
    _d = (B['hand_'+_s].matrix.translation-B['upperarm_'+_s].matrix.translation).normalized()
    _p = B['lowerarm_'+_s].matrix.translation-B['upperarm_'+_s].matrix.translation
    _poles.append((_p-_d*_p.dot(_d)).normalized())
_home = B['hand_r'].matrix @ V(0, PALM, 0)-_frame[0]
_chest = lambda v: tuple(Vector(v).dot(_frame[k]) for k in (1, 2, 3))
# (And the stance's right wrist, as wrist() has it.)
_fore = (B['hand_r'].matrix.translation-B['lowerarm_r'].matrix.translation).normalized()
_z = B['hand_r'].matrix.to_quaternion() @ V(0, 0, 1)
_pit = -(_poles[0]-_fore*_poles[0].dot(_fore)).normalized()
_t = _z-_fore*_z.dot(_fore)
HOME = dict(a=_chest(_home.normalized()), o=_home.length, pr=_chest(_poles[0]), pl=_chest(_poles[1]), w=0.0,
    k=math.degrees(_fore.angle(_z)), tw=math.degrees(math.atan2(_fore.dot(_pit.cross(_t)), _pit.dot(_t))))
reset()

def toward(key, v, share):
    """A channel `share` of the way from the stance's to `v`."""
    return tuple(Vector(HOME[key]).lerp(Vector(v), share))
# (The arms a shade short of straight, so no elbow is ever locked.)
ARMS = dict(nf=1, ea=.004, w=1.0, pl=(0, 0, -1))
SLAM = [K(0, **HOME),
    # The chest turns away to his right, carrying the hands out before it,
    # and he sinks and leans into it; the weapon's head swings over to his
    # right and down past his right hip and on round behind him.
    K(.12, down=.09, turn=-.09, twist=-.16, lean=.2, hy=-.2, a=(.85, .05, -.52), o=.55, pr=(-.4, .55, -.75), k=103, tw=61, **ARMS),
    K(.18, down=.14, turn=-.14, twist=-.26, lean=.35, hy=-.3, hp=-.1, a=(.8, 0, -.6), o=.55, pr=(-.5, .55, -.65), k=94, tw=68, **ARMS),
    K(.24, down=.15, turn=-.22, twist=-.4, lean=.32, bend=-.05, hy=-.4, hp=-.1, a=(.8, 0, -.6), o=.55, pr=(-.5, .5, -.7), k=88, tw=78, **ARMS),
    K(.30, down=.12, turn=-.33, twist=-.62, lean=.18, bend=-.1, hy=-.5, hp=-.05, a=(.85, .05, -.45), o=.55, pr=(-.4, .3, -.85), k=94, tw=84, **ARMS),
    # And up behind him, the hands rising before the chest past the right
    # shoulder, the chest turned right round to it.
    K(.36, down=.05, turn=-.45, twist=-.85, lean=-.06, bend=-.12, hy=-.5, hp=-.05, a=(.92, .1, .05), o=.55, pr=(-.2, 0, -1), k=104, tw=62, lh=.15, rh=.15, **ARMS),
    K(.42, down=.02, turn=-.45, twist=-.85, lean=-.16, tilt=-.03, bend=-.1, hy=-.35, hp=-.25, a=(.7, .1, .7), o=.55, pr=(.5, -.3, -.8), k=96, tw=46, lh=.3, rh=.3, **ARMS),
    K(.48, down=-.03, turn=-.25, twist=-.45, lean=-.24, tilt=-.05, bend=-.06, hy=-.1, hp=-.4, a=(.25, .3, .92), o=.55, pr=(.8, -.4, -.4), k=84, tw=34, lh=.42, rh=.42, **ARMS),
    # Over the top and down before him, the weapon kept above the arms' line
    # all the way, so it comes down level; the body folds into the blow and
    # the arms are thrown out to meet the ground ahead, the elbows down.
    K(.54, down=.02, fwd=.08, turn=.02, twist=.05, lean=.05, hp=-.4, a=(.34, .12, .93), o=.6, pr=(.8, -.4, -.4), k=80, tw=-6, lf=(.25, .08, 0), rh=.4, **ARMS),
    K(.58, down=.1, fwd=.18, turn=.06, twist=.2, lean=.3, tilt=.08, hp=-.35, a=(.66, .12, .74), o=.6, pr=(0, -.3, -.95), k=78, tw=-27, lf=(.35, .06, 0), rh=.5, rp=.1, **ARMS),
    K(.62, down=.3, fwd=.28, turn=.1, twist=.3, lean=.6, tilt=.15, hp=-.25, a=(.92, .1, .37), o=.6, pr=(0, -.3, -.95), k=66, tw=-11, lf=(.42, .03, 0), rh=.55, rp=.15, **ARMS),
    K(.66, 'hit', down=.56, fwd=.32, side=-.03, turn=.15, twist=.45, lean=.95, tilt=.2, hp=-.1, a=(.98, .11, .19), o=.6, pr=(0, -.3, -.95), k=55, tw=10, lf=(.45, 0, 0), rh=.6, rp=.2, **ARMS),
    K(.72, down=.56, fwd=.32, side=-.03, turn=.15, twist=.45, lean=.97, tilt=.2, hp=-.05, a=(.97, .12, .2), o=.6, pr=(0, -.3, -.95), k=55, tw=10, lf=(.45, 0, 0), rh=.6, rp=.2, **ARMS),
    # The rise: the weapon's head lifted off the ground and swung up before
    # him to stand over the right shoulder again.
    K(.83, down=.3, fwd=.2, twist=.1, lean=.42, tilt=.08, a=(.9, -.05, -.43), o=.55, pr=toward('pr', (0, -.3, -.95), .6), k=92, tw=38, lf=(.4, .02, 0), rh=.45, **ARMS),
    K(.94, down=.05, fwd=.04, twist=-.22, lean=.1, a=toward('a', (.9, -.05, -.43), .2), o=.38, pr=toward('pr', (0, -.3, -.95), .15), k=118, tw=56, lf=(.06, 0, 0), rh=.05, **dict(ARMS, w=.6)),
    K(1, **HOME)]

def carried(channel, s):
    """One of Thunder Slam's own channels (which the stance has not) carried
    through its keys as value() carries the stance's."""
    kind = 'down' if isinstance(SLAM[0][1][channel], float) else 'g'
    return value([(r[0], {kind: r[1][channel]}, r[2]) for r in SLAM], kind, s)

def slam_pose(c, s):
    """Thunder Slam's figure from its channels `c` (at `s` along it)."""
    body(**{k: c[k] for k in BODY+BACK})
    for side in 'lr':
        at = c[side+'f']
        foot(side, forward=at[0], lift=at[1], aside=at[2], heel=c[side+'h'], pivot=c[side+'p'], knee=c[side+'k'])
    frame = chest()
    g = frame[0]+in_chest(carried('a', s), frame).normalized()*carried('o', s)
    er = in_chest(carried('pr', s), frame)
    w = carried('w', s)
    z = Vector(c['z']).normalized()
    if w > 0:
        grip.arm(B, 'r', g, B['upperarm_r'].matrix.translation+er)
        fore = (B['hand_r'].matrix.translation-B['lowerarm_r'].matrix.translation).normalized()
        z = z.lerp(wrist(fore, er, carried('k', s), carried('tw', s)), w).normalized()
    el = in_chest(carried('pl', s), frame).normalized()
    d = ((g-z*HANDS)-B['upperarm_l'].matrix.translation).normalized()
    away = z-d*z.dot(d)
    if away.length > 1e-3: el = el.lerp(-away.normalized(), w)
    hold(g, z, c['n'], er, el, free=c['nf'], swing=0.0, ease=c['ea'])

def slam(t):
    # (The body leads the arms but for the blow itself, which the hands
    # carried before the chest would otherwise reach before the clock does.)
    window = ease(t/.12)*ease((1-t)/.12)*(1-ease((t-.54)/.1)*ease((.9-t)/.06))
    s = clock(SLAM_CLOCK, t)
    ahead = {k: clock(SLAM_CLOCK, t+LEAD[0]*window) for k in BODY}|{k: clock(SLAM_CLOCK, t+LEAD[1]*window) for k in BACK}
    slam_pose({k: value(SLAM, k, ahead.get(k, s)) for k in STANCE}, s)
    rest = 1-carried('w', s)
    if rest > 0:
        for b in B:
            m = b.matrix_basis
            loc, rot, scale = m.decompose()
            l0, r0, s0 = IDLE[b.name].decompose()
            b.matrix_basis = Matrix.LocRotScale(loc.lerp(l0, rest), rot.slerp(r0, rest), scale.lerp(s0, rest))
        update()

# Shockwave: the weapon is swung over before him, its head round to the left
# and down, and hoisted in both hands as he draws himself up, the lead knee
# hauled up with it; then foot and weapon are brought down together, the
# weapon's head rammed straight down into the ground before his feet and
# everything hurled down after it; held, and he rises.
SHOCK_CLOCK = [(0, 0, 0), (.3, 1, 1.2), (.43, 1.15, 1.5), (.56, 2, 10, 1.5), (.76, 3, 0), (1, 4, 0)]
PLUNGE = dict(n=(.95, -.3, .1), er=(-.9, -.3, -.2), el=(.9, -.3, -.2))
SHOCK = [K(0),
    K(.25, down=.05, twist=-.2, lean=.08, g=(-.1, -.34, 1.26), z=(.15, -.25, .95), n=(.4, -.9, .2)),
    K(.5, down=.08, twist=.0, lean=.1, g=(-.05, -.4, 1.4), z=(.9, -.2, .3), n=(.3, -.95, .1), er=(-.8, .0, -.5), el=(.8, -.1, -.5)),
    K(1, down=-.02, fwd=-.02, turn=.08, twist=.3, lean=.05, g=(-.08, -.44, 1.5), z=(.08, -.12, -1), lf=(.08, .26, 0), rh=.4, hp=.1, **PLUNGE),
    K(1.15, down=-.05, fwd=-.03, turn=.08, twist=.3, lean=.0, g=(-.08, -.42, 1.56), z=(0, -.06, -1), lf=(.1, .34, 0), rh=.45, hp=.1, **PLUNGE),
    K(2, 'hit', down=.36, fwd=.06, turn=.08, twist=.3, lean=.36, tilt=.06, g=(-.04, -.6, .9), z=(0, .28, -.96), lf=(.14, 0, 0), rh=.7, rk=(0, .1, -.4), hp=.2, **PLUNGE),
    K(3, down=.39, fwd=.06, turn=.08, twist=.3, lean=.4, tilt=.06, g=(-.04, -.6, .88), z=(0, .28, -.96), lf=(.14, 0, 0), rh=.7, rk=(0, .1, -.4), hp=.2, **PLUNGE),
    K(3.5, down=.2, fwd=.04, twist=.1, lean=.25, g=(-.02, -.46, 1.12), z=(.9, -.2, -.25), lf=(.08, .03, 0), rh=.3, n=(.3, -.95, .1), er=(-.8, .0, -.5), el=(.8, -.1, -.5)),
    K(3.8, down=.06, twist=-.15, lean=.1, g=(-.1, -.34, 1.2), z=(.3, -.25, .9), n=(.4, -.9, .2)),
    K(4)]

def shockwave(t):
    play(t, SHOCK_CLOCK, SHOCK)

# War Cry: a dip, and the weapon is thrust at the sky in both hands, the
# chest thrown open and the head back in a roar; held, shaking; and lowered.
CRY_CLOCK = [(0, 0, 0), (.14, 1, 2), (.30, 2, 3, .8), (.68, 3, .5), (1, 4, 0)]
RAISED = dict(n=(.3, -1, 0), er=(-.9, -.2, .0), el=(.9, -.3, .0))
CRY = [K(0),
    K(1, down=.1, lean=.16, twist=-.25, g=(-.12, -.28, 1.08), z=(-.5, .2, .85)),
    K(2, down=-.03, fwd=.06, turn=.05, twist=.25, lean=-.34, tilt=-.08, g=(-.08, -.06, 1.92), z=(-.12, .02, 1), hp=-.45, lh=.25, rh=.3, **RAISED),
    K(3, down=-.01, fwd=.05, turn=.05, twist=.25, lean=-.28, tilt=-.07, g=(-.08, -.06, 1.9), z=(-.1, .0, 1), hp=-.4, lh=.15, rh=.2, **RAISED),
    K(4)]

def cry(t):
    play(t, CRY_CLOCK, CRY)
    # (The roar shakes him.)
    shake = math.sin(t*math.pi*2*9)*.012*ease((t-.28)/.06)*ease((.7-t)/.1)
    if shake: rotate('Head', (1, 0, 0), shake)

# Leap: a deep crouch, the weapon drawn back low; the spring, the legs
# tucked up under him and the weapon carried up over the head (the game
# lifts him through the air from .20 of the clip to .56); the landing,
# driven down with everything, the weapon's head smashed into the ground
# before him; held; the rise.
LEAP_CLOCK = [(0, 0, 0), (.13, 1, 2), (.20, 1.1, 2), (.32, 2, 4), (.40, 2.5, 3), (.56, 3, 4.5, 1.5), (.76, 4, 0), (1, 5, 0)]
TUCK = dict(lf=(.12, .5, 0), rf=(.2, .42, 0), lk=(0, -.3, .3), rk=(0, -.3, .3))
LEAP = [K(0),
    K(1, down=.34, fwd=-.04, lean=.5, tilt=.15, twist=-.15, g=(-.2, -.3, .78), z=(-.3, .5, .8), n=(.5, -.8, .2), rh=.3),
    K(2, down=-.04, fwd=.08, turn=.0, twist=.1, lean=-.2, g=(-.17, -.02, 1.88), z=plane(OVER, FORWARD, 120), n=OVER, hp=-.1, **TUCK, **HIGH),
    K(2.5, down=-.02, fwd=.1, turn=.0, twist=.1, lean=-.25, g=(-.17, .04, 1.9), z=plane(OVER, FORWARD, 150), n=OVER, hp=.1, **TUCK, **HIGH),
    K(2.75, down=.1, fwd=.18, turn=.08, twist=.36, lean=.0, hp=-.2, g=(-.08, -.4, 1.72), z=plane(OVER, FORWARD, 58), n=OVER, lf=(.26, .22, 0), rf=(.08, .2, 0), rh=.3, **HIGH),
    K(2.88, down=.26, fwd=.22, side=-.03, turn=.14, twist=.48, lean=.2, tilt=.06, hp=-.3, g=(.06, -.66, 1.22), z=plane(OVER, FORWARD, 12), n=OVER, lf=(.3, .08, 0), rf=(.03, .07, 0), rh=.6,
        er=(-.9, -.2, -.1), el=(.9, .0, -.1)),
    K(3, 'hit', down=.44, fwd=.24, side=-.05, turn=.18, twist=.58, lean=.48, tilt=.12, hp=-.15, g=(.12, -.7, .62), z=plane(OVER, FORWARD, -36), n=OVER, lf=(.3, 0, 0), **LUNGE, **DOWN),
    K(4, down=.47, fwd=.24, side=-.05, turn=.18, twist=.58, lean=.53, tilt=.12, g=(.12, -.7, .62), z=plane(OVER, FORWARD, -36), n=OVER, lf=(.3, 0, 0), **LUNGE, **DOWN),
    K(4.5, down=.3, fwd=.16, twist=.25, lean=.45, g=(.04, -.54, .92), z=plane(OVER, FORWARD, 25), n=(.8, -.5, .2), lf=(.22, .02, 0), rh=.6),
    K(5)]

def leap(t):
    play(t, LEAP_CLOCK, LEAP)

AUTHORS = {'HeavyIdle': idle, 'HeavySwing1': swing1, 'HeavyCleave': cleave, 'HeavyStrike': strike, 'HeavyExecute': execute,
    'HeavySlam': slam, 'HeavyShockwave': shockwave, 'HeavyCry': cry, 'HeavyLeap': leap}
for name in WANTED:
    if name in AUTHORS: author(name, AUTHORS[name])

rig.animation_data.action = None
# The clips that were there already all come in with their strips from frame
# 1, where these begin at 0, and the export begins every clip at 0: left so,
# each would go out a frame later and longer than it came in (as
# tools/import_pike.py has it). Those that began at once in the file (BEGAN)
# are set back to begin at 0, so authoring a few clips (HEAVY_ONLY) leaves
# every other clip's timing as it was.
for track in rig.animation_data.nla_tracks:
    if track.name in WANTED or BEGAN.get(track.name, 1.0) > 1/60: continue
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
if DRY: raise SystemExit(print('HEAVY_DRY: nothing written'))
bpy.ops.export_scene.gltf(filepath=str(GLB), export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS', export_force_sampling=True)
print('HEAVY_ANIMATIONS_READY', len(rig.animation_data.nla_tracks), 'clips')
