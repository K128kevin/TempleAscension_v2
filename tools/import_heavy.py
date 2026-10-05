"""Authors the warrior's two-handed clips onto the supplied rig (after
import_skills.py; safe to rerun): the stance and the blows of a heavy weapon
(a greatsword, a battle axe, a maul) held in both hands.

The weapon is keyed first and the man hung on it. Each frame says where the
right fist grips the haft, where the haft points and how the edge is turned;
the right hand is set outright on it, the left hand a hand's breadth (0.20 m)
down the haft toward the butt and turned to wrap it, and both arms are bent
to them by two-bone IK (the collar bones giving a little, the forearms rolled
after the fists). The body under it (hips, spine, head, the feet planted or
stepping by leg IK) is keyed alongside. A blow's path through space is keyed
apart from its timing, so the weapon runs along one smooth arc, slowly out of
the wind-up, at its fastest as it lands, and on through.

The grip (what the game must hold the weapon by): the weapon's length lies
along hand_r's own +Z through the hand's (0, .075, z), its edge along the
hand's X; the left palm, hand_l's (0, .075, 0), sits at hand_r's
(0, .075, -.20).

  HeavyIdle       the stance: the weapon held up before the right shoulder
                  in both hands, left foot forward, breathing (2 s, loops)
  HeavySwing1     normal attack: a diagonal cut from over the right shoulder
                  down to the lower left, the weight thrown onto the lead foot
  HeavySwing2     normal attack: the return blow, a rising backhand sweep
                  from the low left across to the high right
  HeavyCleave     a level sweep through the half-circle before him, coiled
                  round to the right and unwound, behind a step
  HeavyStrike     Powerful Strike: a full chop from over the right shoulder
                  straight down before him
  HeavyExecute    the weapon hauled far back over the head, the body arched,
                  then brought down with everything, down to the knee
  HeavySlam       Thunder Slam: swung up high and driven into the ground a
                  stride ahead; held; a slow rise
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
"""
from pathlib import Path
import math, os
import bpy
from mathutils import Vector, Matrix, Quaternion
ROOT = Path(__file__).resolve().parents[1]
GLB = Path(os.environ.get('HERO_GLB') or ROOT/'assets/models/character/warrior.glb')
if not GLB.is_absolute(): GLB = ROOT/GLB
# name: seconds
CLIPS = {'HeavyIdle': 2.0, 'HeavySwing1': 1.1, 'HeavySwing2': 1.1, 'HeavyCleave': 1.0, 'HeavyStrike': 1.0, 'HeavyExecute': 1.3,
    'HeavySlam': 1.1, 'HeavyShockwave': 1.2, 'HeavyCry': 1.0, 'HeavyLeap': 1.0}
# name: the share of the clip at which the blow lands (the game's own figures).
CONTACT = {'HeavySwing1': .50, 'HeavySwing2': .50, 'HeavyCleave': .52, 'HeavyStrike': .55, 'HeavyExecute': .58, 'HeavySlam': .52,
    'HeavyShockwave': .56, 'HeavyCry': .30, 'HeavyLeap': .56}
ONLY = [n for n in os.environ.get('HEAVY_ONLY', '').split(',') if n]
CHECK = int(os.environ.get('HEAVY_CHECK') or 0)
WANTED = [n for n in CLIPS if not ONLY or n in ONLY]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=str(GLB))
rig = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
print('HEAVY_BEFORE', len(rig.animation_data.nla_tracks), 'clips')
for track in list(rig.animation_data.nla_tracks):
    if track.name in WANTED: rig.animation_data.nla_tracks.remove(track)
for a in list(bpy.data.actions):
    if a.name in WANTED: bpy.data.actions.remove(a)
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

def bend_axis(side):
    upper, lower, hand = (B[n+side].matrix.translation for n in ('upperarm_', 'lowerarm_', 'hand_'))
    return (lower-upper).cross(hand-lower).normalized()

def arm(side, target, pole):
    """An arm bent to `target`, the elbow toward `pole`; each of its bones is
    left turned about its length as the elbow's hinge has it (the hinge lies
    along the bones' own X), however far it has been swung round."""
    upper, lower = B['upperarm_'+side], B['lowerarm_'+side]
    reached = two_bone(upper, lower, B['hand_'+side], target, pole)
    hinge = bend_axis(side)*HINGE[side]
    fore = lower.matrix.copy()
    for bone in (upper, lower):
        m = fore if bone == lower else bone.matrix.copy()
        q = m.to_quaternion()
        along, x = q @ V(0, 1, 0), q @ V(1, 0, 0)
        want = (hinge-along*hinge.dot(along)).normalized()
        set_world(bone, m.translation, Quaternion(along, math.atan2(x.cross(want).dot(along), x.dot(want))) @ q)
    return reached

# (Which way along its X each elbow's hinge runs, as the stance has them.)
HINGE = {s: 1.0 if bend_axis(s).dot(B['lowerarm_'+s].matrix.to_quaternion() @ V(1, 0, 0)) > 0 else -1.0 for s in 'lr'}

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

def turn_hand(side, x, y, z):
    hand = B['hand_'+side]
    set_world(hand, hand.matrix.translation, Matrix((x, y, z)).transposed().to_quaternion())

def untwist(side):
    """A fist turned far round on the end of the forearm wrings the wrist:
    the forearm turns after it (as far as a forearm will, and not at all
    after a fist turned right round), and the fist only what is left.
    Returns the fist's turn from the elbow's hinge (radians)."""
    hand, fore = B['hand_'+side], B['lowerarm_'+side]
    hm, fm = hand.matrix.copy(), fore.matrix.copy()
    qf, qh = fm.to_quaternion(), hm.to_quaternion()
    along = qf @ V(0, 1, 0)
    fx, fz, hx, hz = qf @ V(1, 0, 0), qf @ V(0, 0, 1), qh @ V(1, 0, 0), qh @ V(0, 0, 1)
    turned = math.atan2((fz.cross(hz)+fx.cross(hx)).dot(along), fz.dot(hz)+fx.dot(hx))
    set_world(fore, fm.translation, Quaternion(along, FOREARM_ROLL*math.sin(turned)) @ qf)
    set_world(hand, hm.translation, qh)
    return turned

FOREARM_ROLL = math.radians(50)

# ---- The weapon in both hands ----

# The grip: the haft passes through each hand's PALM, along its own Z; the
# left hand holds it HANDS apart from the right, toward the butt.
PALM = .075
HANDS = .20
# The weapon's ends from the right fist, for the checks: the battle axe's butt
# and head (its bits ACROSS either way from the haft), and the greatsword's point.
BUTT = .40
HEAD = .85
BITS = (.62, .2, .16)
POINT = 1.23
measured = {}

def hold(grip, haft, fingers, elbow_r, elbow_l):
    """Both hands on the weapon: the right fist's grip at `grip`, the haft
    running along `haft` toward the weapon's head, the right hand turned
    about it so its fingers lie along `fingers` (the edge then lies across
    both: a cut travels square to `haft` and `fingers`). The left hand takes
    the haft below it, turned about it as near as may be to the way its
    forearm carries it (and, where that leaves it free, as the right lies). The elbows bend toward `elbow_r` and `elbow_l` (from
    the shoulders)."""
    z = Vector(haft).normalized()
    grip = Vector(grip)
    y = Vector(fingers)
    y = (y-z*y.dot(z)).normalized()
    x = y.cross(z)
    def left_fingers():
        # (Of all the ways the hand could be turned about the haft, the one
        # nearest the forearm's own turn: the wrist bent and wrung least.)
        q = B['lowerarm_l'].matrix.to_quaternion()
        fx, fy = q @ V(1, 0, 0), q @ V(0, 1, 0)
        a = z.orthogonal().normalized()
        b = z.cross(a)
        fy = fy+y*PAIR
        return (a*(a.dot(fy)+WRING*a.cross(z).dot(fx))+b*(b.dot(fy)+WRING*b.cross(z).dot(fx))).normalized()
    shoulder_l = B['upperarm_l'].matrix.translation.copy()
    ly = (grip-z*HANDS)-shoulder_l
    ly = (ly-z*ly.dot(z)).normalized()
    shrug('r', grip-y*PALM)
    shrug('l', grip-z*HANDS-ly*PALM)
    shoulders = {s: B['upperarm_'+s].matrix.translation.copy() for s in 'lr'}
    # Neither arm is asked for more than its length: the weapon is drawn in.
    asked = grip.copy()
    for i in range(4):
        for s, wrist in (('r', grip-y*PALM), ('l', grip-z*HANDS-ly*PALM)):
            d = wrist-shoulders[s]
            if d.length > ARM-.006: grip -= d.normalized()*(d.length-ARM+.006)
    short['arms'] = (grip-asked).length
    arm('r', grip-y*PALM, shoulders['r']+Vector(elbow_r))
    turn_hand('r', x, y, z)
    for i in range(3):
        arm('l', grip-z*HANDS-ly*PALM, shoulders['l']+Vector(elbow_l))
        ly = left_fingers()
    arm('l', grip-z*HANDS-ly*PALM, shoulders['l']+Vector(elbow_l))
    turn_hand('l', ly.cross(z), ly, z)
    measured['twist r'], measured['twist l'] = untwist('r'), untwist('l')

# (How much the left wrist's wringing counts against its bending, and how far
# the left hand leans to lying as the right does, palm against palm.)
WRING = .3
PAIR = .4

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
    g=(-.14, -.2, 1.15), z=(-.54, .34, .78), n=(.7, -.5, .5), er=(-.5, .3, -.7), el=(.55, .1, -.7),
    lf=(0, 0, 0), rf=(0, 0, 0), lh=0.0, rh=0.0, lp=0.0, rp=0.0, lk=(0, 0, 0), rk=(0, 0, 0))
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
    hold(c['g'], c['z'], c['n'], c['er'], c['el'])

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
    out['ground'] = min(haft[0].z, (hand @ V(0, PALM, HEAD)).z, haft[1].z)
    out['ground axe'] = min(haft[0].z, (hand @ V(0, PALM, HEAD)).z, bits[0].z-BITS[2], bits[1].z-BITS[2])
    for s in 'lr':
        fore = B['lowerarm_'+s].matrix.to_quaternion() @ V(0, 1, 0)
        out['wrist '+s] = -math.degrees(fore.angle(B['hand_'+s].matrix.to_quaternion() @ V(0, 1, 0)))
    out['gap'] = -((B['hand_l'].matrix @ V(0, PALM, 0))-(hand @ V(0, PALM, -HANDS))).length
    out['arms short'] = -short['arms']
    out['legs short'] = -short['legs']
    for s in 'lr': out['twist '+s] = -abs(math.degrees(measured['twist '+s]))
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

def author(name, clip):
    length = CLIPS[name]
    a = bpy.data.actions.new(name)
    rig.animation_data.action = a
    frames = int(round(length*30))
    log = []
    for f in range(frames+1):
        reset()
        short['legs'] = 0.0
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
    finish(name, a, length)
    if CHECK: report(name, frames, log)

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

# The first cut: hauled up and back over the right shoulder, the weight on
# the rear foot and the body turned away; then the lead foot driven out and
# the whole body thrown round and down behind the blow, which lands before
# him and runs on down to the lower left; and drawn back up to the shoulder.
CUT = (.62, .1, .78)
SWING1_CLOCK = [(0, 0, 0), (.26, .9, 1.6), (.37, 1, 1.0), (.50, 2, 11, 9), (.63, 3, 1.2), (1, 4, 0)]
SWING1 = [K(0),
    K(1, down=.06, fwd=-.1, side=-.03, turn=-.3, twist=-.6, lean=-.08, bend=-.05, g=(-.3, .1, 1.56), z=plane(CUT, FORWARD, 128), n=CUT,
        er=(-.7, .3, -.2), el=(.3, -.5, -.5), lh=.2),
    K(1.5, down=.08, fwd=.03, turn=-.05, twist=-.15, lean=.1, g=(-.2, -.46, 1.5), z=plane(CUT, FORWARD, 86), n=CUT,
        er=(-.7, .0, -.3), el=(.4, -.4, -.6), rh=.25, lf=(.1, .07, 0)),
    K(2, down=.15, fwd=.17, side=.03, turn=.2, twist=.36, lean=.28, bend=.05, g=(.08, -.7, 1.02), z=plane(CUT, FORWARD, 4), n=CUT,
        er=(-.7, -.2, -.3), el=(.6, -.1, -.6), rh=.5, rp=.3, lf=(.18, 0, 0)),
    K(2.5, down=.2, fwd=.2, side=.04, turn=.3, twist=.5, lean=.36, bend=.08, g=(.22, -.66, .9), z=plane(CUT, FORWARD, -48), n=CUT,
        er=(-.6, -.4, -.2), el=(.7, .2, -.4), rh=.55, rp=.35, lf=(.18, 0, 0)),
    K(3, down=.21, fwd=.19, side=.04, turn=.32, twist=.56, lean=.38, bend=.1, g=(.34, -.46, .9), z=plane(CUT, FORWARD, -92), n=CUT,
        er=(-.5, -.5, -.2), el=(.7, .4, -.3), rh=.55, rp=.35, lf=(.18, 0, 0)),
    K(3.33, down=.17, fwd=.15, turn=.22, twist=.34, lean=.3, g=(.12, -.46, 1.04), z=(.6, -.2, .75), n=(.5, .2, .8), rh=.4, rp=.25, lf=(.16, 0, 0)),
    K(3.66, down=.1, fwd=.08, turn=.06, twist=.0, lean=.2, g=(.02, -.44, 1.12), z=(.05, -.3, .95), n=(.4, -.8, .4), rh=.15, rp=.1, lf=(.08, .04, 0)),
    K(3.86, down=.05, fwd=.02, turn=-.04, twist=-.2, lean=.1, g=(-.15, -.34, 1.14), z=(-.42, .05, .9), n=(.6, -.6, .5), lf=(.02, .01, 0)),
    K(4)]

def swing1(t):
    play(t, SWING1_CLOCK, SWING1)

# The return blow: the weapon dropped to the low left behind him, the body
# coiled round to the left over the lead leg; then unwound, the back of the
# upper hand leading the weapon up across the front and away to the high
# right, where it comes to the shoulder again.
RISE = (.34, .1, .93)
SWING2_CLOCK = [(0, 0, 0), (.3, .93, 1.0), (.38, 1, 1.0), (.50, 2, 11, 9), (.63, 3, 1.2), (1, 4, 0)]
SWING2 = [K(0),
    K(.35, down=.07, turn=.03, twist=-.05, lean=.12, g=(-.06, -.36, 1.13), z=(-.1, -.8, .6), n=(.6, -.1, .8)),
    K(.7, down=.12, turn=.15, twist=.22, lean=.2, g=(.1, -.36, 1.05), z=(.6, -.75, -.25), n=(.45, .1, .9)),
    K(1, down=.15, fwd=-.03, side=.05, turn=.25, twist=.45, lean=.22, bend=.08, g=(.2, -.22, 1.0), z=plane(RISE, FORWARD, -125), n=RISE,
        er=(-.5, -.5, -.4), el=(.7, .4, -.4), rh=.15),
    K(1.5, down=.15, fwd=.08, turn=.2, twist=.35, lean=.26, g=(.16, -.46, 1.02), z=plane(RISE, FORWARD, -82), n=RISE,
        er=(-.6, -.3, -.5), el=(.7, .1, -.5), rh=.3),
    K(2, down=.14, fwd=.2, turn=.1, twist=.25, lean=.3, g=(-.06, -.58, 1.06), z=plane(RISE, FORWARD, -4), n=RISE,
        er=(-.7, -.1, -.5), el=(.6, -.2, -.6), rh=.45, rp=.25),
    K(2.5, down=.07, fwd=.17, turn=-.1, twist=-.25, lean=.12, g=(-.27, -.44, 1.3), z=plane(RISE, FORWARD, 55), n=RISE,
        er=(-.7, .2, -.4), el=(.4, -.5, -.5), rh=.4, rp=.25),
    K(3, down=.02, fwd=.08, turn=-.25, twist=-.55, lean=-.06, g=(-.36, -.12, 1.42), z=plane(RISE, FORWARD, 105), n=RISE,
        er=(-.7, .3, -.3), el=(.3, -.5, -.5), rh=.25, rp=.1),
    K(4)]

def swing2(t):
    play(t, SWING2_CLOCK, SWING2)

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

# Thunder Slam: the weapon swung up high over the head, up on the toes; then
# the lead foot driven forward and the whole body hurled down behind it, the
# weapon's head smashed into the ground a stride ahead; held; a slow rise.
SLAM_CLOCK = [(0, 0, 0), (.22, .9, 1.8), (.35, 1, 2.5), (.52, 2, 7.5, 1.5), (.74, 3, 0), (1, 4, 0)]
DOWN = dict(er=(-.9, -.3, -.1), el=(.9, .1, -.1))
LUNGE = dict(rh=.8, rk=(0, .1, -.4))
STRIDE = dict(lf=(.46, 0, 0), rh=.65, rp=.2)
SLAM = [K(0),
    K(.5, down=.08, twist=-.2, lean=.12, g=(-.16, -.26, 1.4), z=plane(OVER, FORWARD, 82), n=OVER, er=(-.8, .0, -.5), el=(.8, -.1, -.5)),
    K(1, down=-.04, fwd=-.08, turn=.0, twist=.1, lean=-.24, g=(-.17, .02, 1.88), z=plane(OVER, FORWARD, 128), n=OVER, lh=.4, rh=.4, hp=-.1, **HIGH),
    K(1.4, down=.03, fwd=.06, turn=.06, twist=.3, lean=.0, hp=-.2, g=(-.1, -.36, 1.78), z=plane(OVER, FORWARD, 75), n=OVER, lf=(.16, .12, 0), rh=.5, **HIGH),
    K(1.75, down=.2, fwd=.22, side=-.03, turn=.14, twist=.48, lean=.22, tilt=.06, hp=-.3, g=(.05, -.72, 1.3), z=plane(OVER, FORWARD, 20), n=OVER, lf=(.42, .04, 0), rh=.6,
        er=(-.9, -.2, -.1), el=(.9, .0, -.1)),
    K(2, 'hit', down=.34, fwd=.3, side=-.05, turn=.18, twist=.58, lean=.6, tilt=.18, hp=-.2, g=(.12, -.8, .64), z=plane(OVER, FORWARD, -37), n=OVER, **STRIDE, **DOWN),
    K(3, down=.37, fwd=.3, side=-.05, turn=.18, twist=.58, lean=.64, tilt=.18, hp=-.1, g=(.12, -.8, .64), z=plane(OVER, FORWARD, -37), n=OVER, **STRIDE, **DOWN),
    K(3.5, down=.26, fwd=.2, twist=.25, lean=.45, g=(.04, -.58, .95), z=plane(OVER, FORWARD, 25), n=(.8, -.5, .2), lf=(.34, .02, 0), rh=.5),
    K(4)]

def slam(t):
    play(t, SLAM_CLOCK, SLAM)

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

AUTHORS = {'HeavyIdle': idle, 'HeavySwing1': swing1, 'HeavySwing2': swing2, 'HeavyCleave': cleave, 'HeavyStrike': strike, 'HeavyExecute': execute,
    'HeavySlam': slam, 'HeavyShockwave': shockwave, 'HeavyCry': cry, 'HeavyLeap': leap}
for name in WANTED:
    if name in AUTHORS: author(name, AUTHORS[name])

rig.animation_data.action = None
for track in rig.animation_data.nla_tracks: track.mute = False
used = {s.action for t in rig.animation_data.nla_tracks for s in t.strips}
for a in list(bpy.data.actions):
    if a not in used: bpy.data.actions.remove(a)
bpy.context.scene.frame_set(0)
bpy.ops.export_scene.gltf(filepath=str(GLB), export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS', export_force_sampling=True)
print('HEAVY_ANIMATIONS_READY', len(rig.animation_data.nla_tracks), 'clips')
