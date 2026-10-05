"""Authors the warrior's two-handed spear clips onto the supplied rig (after
import_character.py, import_combat.py, import_walk.py and import_skills.py;
safe to rerun).

The long spear is held in both hands: the right is the rear hand, .70 m up
from the butt, and the left leads it, .55 m further toward the point (the
game holds the spear in the right hand exactly so: scripts/visual.gd equip;
the shaft lies along the hand's own Z, through (0, .075, z) of it). Every
clip is keyed here frame by frame from the spearman's guard: the whole body
moves through each (hips, spine, shoulders, head, both arms bent onto the
shaft the way a man's would lie, wrists and forearms unwrung, the feet kept
on the ground by leg IK, the rear heel coming up when the leg is at its full
stretch), each wound up, struck fast and
followed through, and each begins and ends in the guard, so one runs on into
another. The spear's line is set outright at every frame (where the right
fist is and the way the point runs), and where the arms could not hold it
there it is moved the little it must be, so both hands are on the shaft in
every frame.

  PikeIdle       the guard: left foot leading, the body bladed, the spear at
                 the right hip, its point raised at an enemy's chest (loops)
  PikeThrust1    normal attack A: a driving thrust at chest height behind a
                 short lunge of the lead foot
  PikeThrust2    normal attack B: he sinks, the point dipped low, and drives
                 it rising under a guard as he comes up out of his knees
  PikeCleave     the head swept level from his right round to his left
                 through everything before him, behind a step
  PikeStrike     Powerful Strike: drawn right back, then a long, deep
                 lunge through one enemy, the rear leg straight
  PikeExecute    the finisher: raised high, point down, and plunged into the
                 beaten enemy at his feet with his whole weight
  PikeSlam       Thunder Slam: swung up and back over the head, then its
                 head brought over and down onto the ground ahead
  PikeShockwave  Shockwave: stood upright, hauled up, and its butt hammered
                 straight down into the ground before his lead foot
  PikeCry        War Cry: thrust up at the sky in both hands, chest open,
                 head back
  PikeLeap       Leap: the crouch, the tuck with the spear overhead point
                 down, the landing with it driven into the ground (the game
                 carries him through the air)

Cleave steps him forward: the game carries him over the ground as he steps
(CLEAVE_ADVANCE below, [fraction of the clip, metres]) while the clip keeps
each foot where it is on the ground. The others end where they began.

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/import_pike.py

  HERO_GLB=/path/model.glb   the model to read and write back
                             (default assets/models/character/warrior.glb)
  PIKE_ONLY=PikeSlam,PikeCry author only these (the rest left as they are)
  PIKE_OUT=/path/out.glb     write there instead of over the model
  PIKE_CHECK=1               print every frame's measurements
"""
from pathlib import Path
import json, math, os, struct
import bpy
from mathutils import Vector, Matrix, Quaternion
ROOT = Path(__file__).resolve().parents[1]
GLB = Path(os.environ.get('HERO_GLB', 'assets/models/character/warrior.glb'))
if not GLB.is_absolute(): GLB = ROOT/GLB
OUT = Path(os.environ.get('PIKE_OUT', str(GLB)))
# name: seconds, and the share of each at which its blow lands
# (scripts/combat_animation.gd keeps the same).
CLIPS = {'PikeIdle': 2.0, 'PikeThrust1': .8, 'PikeThrust2': .8, 'PikeCleave': 1.0, 'PikeStrike': 1.0, 'PikeExecute': 1.3, 'PikeSlam': 1.1,
    'PikeShockwave': 1.2, 'PikeCry': 1.0, 'PikeLeap': 1.0}
CONTACT = {'PikeThrust1': .5, 'PikeThrust2': .5, 'PikeCleave': .52, 'PikeStrike': .55, 'PikeExecute': .58, 'PikeSlam': .52, 'PikeShockwave': .56,
    'PikeCry': .3, 'PikeLeap': .56}
ONLY = [n for n in os.environ.get('PIKE_ONLY', '').split(',') if n]
for n in ONLY: assert n in CLIPS, n
AUTHORED = ONLY or list(CLIPS)
CHECK = bool(os.environ.get('PIKE_CHECK'))
# The spear (scripts/visual.gd sizes): the right fist this far up from the
# butt, the left this much further toward the point, the point beyond.
GRIP = .70
SPACING = .55
REACH = 2.3-GRIP
PALM = .075

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
for track in list(rig.animation_data.nla_tracks):
    if track.name in AUTHORED: rig.animation_data.nla_tracks.remove(track)
for a in list(bpy.data.actions):
    if a.name in AUTHORED: bpy.data.actions.remove(a)
for track in rig.animation_data.nla_tracks: track.mute = True
# (The meshes need not follow the rig while it is posed: only the bones are
# keyed. They are bound to it again before the export.)
unbound = [m for o in bpy.data.objects for m in o.modifiers if m.type == 'ARMATURE' and m.show_viewport]
for m in unbound: m.show_viewport = False
B = rig.pose.bones

def V(x, y, z):
    return Vector((x, y, z))

X, Y, Z = V(1, 0, 0), V(0, 1, 0), V(0, 0, 1)
AHEAD = V(0, -1, 0)

def update():
    bpy.context.view_layer.update()

def frame(time):
    value = time*30
    bpy.context.scene.frame_set(math.floor(value), subframe=value % 1)
    update()

def pose_of(action, time=0.0):
    rig.animation_data.action = bpy.data.actions[action]
    frame(time)
    pose = {b.name: b.matrix_basis.copy() for b in B}
    rig.animation_data.action = None
    return pose

# What the guard is built on: the sword stance's legs and hips (as the plain
# idle's and the run's), so he passes from it to his feet's other clips
# cleanly; the left hand closed as the ranger closes his on his bow (the fist
# scripts/hand_grip.gd keeps).
BASE = pose_of('SwordIdle')
if 'RangerIdle' in bpy.data.actions:
    fist = pose_of('RangerIdle')
    for name in fist:
        if name.endswith('_l') and name.startswith(('thumb', 'index', 'middle', 'ring', 'pinky')): BASE[name] = fist[name]

def apply(pose):
    for b in B: b.matrix_basis = pose[b.name]
    update()

def reset():
    apply(BASE)

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
    print('PIKE_CLIP', name, length)

# ---- Curves ----

def ease(u):
    u = max(0.0, min(1.0, u))
    return u*u*(3-2*u)

SHAPES = {'io': ease, 'in': lambda u: u*u, 'out': lambda u: 1-(1-u)*(1-u), 'lin': lambda u: u,
    # (Struck: gathering all the way, at its fastest as it lands.)
    'hit': lambda u: u**1.9,
    # (Swung: a long arc, gathering, each frame's share of it near the last's.)
    'swing': lambda u: u**1.5, 'soft': lambda u: ease(ease(u))}

def curve(points, t):
    """A value carried through (time, value[, shape]) points; each stretch
    is shaped as its end point says: 'io' eased at both ends (as it is if
    nothing is said), 'in' gathering, 'out' slowing, 'hit', 'swing', 'lin'."""
    if t <= points[0][0]: return points[0][1]
    for i in range(len(points)-1):
        if t <= points[i+1][0]:
            a, v = points[i][:2]
            b, w = points[i+1][:2]
            shape = SHAPES[points[i+1][2] if len(points[i+1]) > 2 else 'io']
            return v+(w-v)*shape((t-a)/(b-a))
    return points[-1][1]

def at(values, phase):
    """What a clip's phase asks of a value: `values` are its states at
    phases 0, 1, 2 ..., and it passes straight from each to the next (the
    phase itself gathers and slows)."""
    phase = max(0.0, min(len(values)-1.0, phase))
    i = min(int(phase), len(values)-2)
    u = phase-i
    return values[i]+(values[i+1]-values[i])*u

def dir_at(values, phase):
    """As `at`, for a direction: turned from each to the next."""
    phase = max(0.0, min(len(values)-1.0, phase))
    i = min(int(phase), len(values)-2)
    return values[i].normalized().slerp(values[i+1].normalized(), phase-i)

def bump(t, a, b):
    """Up and down again once between a and b."""
    return math.sin(math.pi*max(0.0, min(1.0, (t-a)/(b-a))))

def lead(t, by):
    """A moment ahead (or, less than nothing, behind): what moves first in a
    blow is keyed a little early, what trails a little late; the clip's ends
    stay where they are."""
    return max(0.0, min(1.0, t+by*math.sin(math.pi*t)))

# ---- The rig ----

def set_world(bone, position, rotation):
    bone.matrix = Matrix.Translation(position) @ rotation.to_matrix().to_4x4()
    update()

def rotate(name, axis, angle):
    """Turns a bone about a world axis, where it stands."""
    if not angle: return
    b = B[name]
    m = b.matrix.copy()
    set_world(b, m.translation, Quaternion(Vector(axis), angle) @ m.to_quaternion())

def shift(name, by):
    b = B[name]
    m = b.matrix.copy()
    set_world(b, m.translation+Vector(by), m.to_quaternion())

def two_bone(upper, lower, end, target, pole):
    """Bends a two-bone chain so its end reaches `target`, the joint toward
    `pole`; the place it reached (short of the target, if that is too far)."""
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
    # Each bone is laid along its part of the limb and rolled so the joint
    # between them bends about its own hinge, as it does in the stance (so
    # no limb is ever left twisted about its length, whichever way it has
    # come round).
    hinge = plane.cross(direction)
    for bone, head, tip in [(upper, s, joint), (lower, joint, target)]:
        q = bone.matrix.to_quaternion()
        along = (tip-head).normalized()
        q = (q @ Y).rotation_difference(along) @ q
        now = q @ HINGES[bone.name]
        now = (now-along*now.dot(along)).normalized()
        want = (hinge-along*hinge.dot(along)).normalized()
        angle = now.angle(want)
        if now.cross(want).dot(along) < 0: angle = -angle
        set_world(bone, head, Quaternion(along, angle) @ q)
    return target

# Each limb's hinge (the elbow's, the knee's) in its two bones' own axes: the
# rig's bones are all rolled so it is their X.
HINGES = {n+s: V(1, 0, 0) for n in ('upperarm_', 'lowerarm_', 'thigh_', 'calf_') for s in 'lr'}

def point_hand(side, shaft, fingers):
    """Turns the hand so the shaft in it runs along `shaft` and the fingers
    point along `fingers` (the shaft lies along the hand's own Z, the
    fingers along its Y)."""
    hand = B['hand_'+side]
    z = Vector(shaft).normalized()
    y = Vector(fingers)
    y = (y-z*y.dot(z)).normalized()
    x = y.cross(z)
    basis = Matrix((x, y, z)).transposed()
    set_world(hand, hand.matrix.translation, basis.to_quaternion())

reset()
PELVIS = B['pelvis'].matrix.translation.copy()
CHEST = B['spine_03'].matrix.copy()
PLANTED = {s: B['foot_'+s].matrix.translation.copy() for s in 'lr'}
BALLS = {s: B['ball_'+s].matrix.translation.copy() for s in 'lr'}
FOOT_TURN = {s: B['foot_'+s].matrix.to_quaternion() for s in 'lr'}
BALL_TURN = {s: B['ball_'+s].matrix.to_quaternion() for s in 'lr'}
LEG = {s: (B['calf_'+s].matrix.translation-B['thigh_'+s].matrix.translation).length+(B['foot_'+s].matrix.translation-B['calf_'+s].matrix.translation).length
    for s in 'lr'}
TOES = {}
for s in 'lr':
    d = BALLS[s]-PLANTED[s]
    d.z = 0
    TOES[s] = d.normalized()

def body(turn=0.0, lean=0.0, tilt=0.0, down=0.0, forward=0.0, aside=0.0, hip=.4, look=0.0, nod=0.0):
    """The trunk: the hips moved (down, forward, to his left), the whole of
    it turned (to his left; `hip` of the turn is the pelvis's, the rest the
    spine's), bent forward (`lean`) and to the side (`tilt`); the head kept
    on what is before him, turned `look` and bowed `nod` beyond that."""
    shift('pelvis', V(aside, -forward, -down))
    rest = (1-hip)/3
    for name, share in (('pelvis', hip), ('spine_01', rest), ('spine_02', rest), ('spine_03', rest)):
        rotate(name, Z, turn*share)
    across = Quaternion(Z, turn) @ X
    along = Quaternion(Z, turn) @ AHEAD
    for name, share in (('pelvis', .2), ('spine_01', .3), ('spine_02', .3), ('spine_03', .2)):
        rotate(name, across, lean*share)
        rotate(name, along, tilt*share)
    back = max(-1.15, min(1.15, -turn*.92))+look
    rotate('neck_01', Z, back*.45)
    rotate('Head', Z, back*.55)
    bow = -lean*.75+nod
    face = Quaternion(Z, turn+back) @ X
    rotate('neck_01', face, bow*.4)
    rotate('Head', face, bow*.6)

def shoulder(side, target):
    """The shoulder goes a little way after a hand that reaches far."""
    c = B['clavicle_'+side]
    u = B['upperarm_'+side]
    a = u.matrix.translation-c.matrix.translation
    b = Vector(target)-c.matrix.translation
    w = ease(((Vector(target)-u.matrix.translation).length-.3)/.25)
    angle = min(.4*a.angle(b), .32)*w
    if angle > 1e-4: rotate('clavicle_'+side, a.cross(b).normalized(), angle)

# ---- The arms on the shaft ----
#
# A fist closed on the shaft (the shaft along the hand's Z, the thumb toward
# the point) may still lie any way round it, and the elbow anywhere on its
# circle between shoulder and wrist. Of all those, each arm takes the one a
# man's would: the wrist bent least (it gives a little toward the butt, as a
# hand holding a hammer does, hardly at all the other way), the forearm
# turned least about its length from the way the elbow carries the hand,
# the elbow down and out from the body rather than up or through it, and
# all of it near where it was the frame before.
FINGERS = {'r': V(.35, 0, -1), 'l': V(-.5, 0, -1)}
ELBOW_REST = {'r': V(-.5, .3, -.8), 'l': V(.5, .3, -.8)}
FOREARM_TWIST = .6
ARM = {s: ((B['lowerarm_'+s].matrix.translation-B['upperarm_'+s].matrix.translation).length, (B['hand_'+s].matrix.translation-B['lowerarm_'+s].matrix.translation).length)
    for s in 'lr'}
# Each arm the frame before: (the fingers' way, the elbow's way from the
# shoulder, the way the arm bends).
before = {'r': None, 'l': None}
now = {}
# Each arm as the guard has it, and how strongly a clip's arms are drawn to
# that (at its ends, where it leaves the guard and comes back to it).
HOME = {}
homing = [0.0]

def arm_cost(side, palm, shaft, y, swivel, s, chest, trunk, wanted):
    l1, l2 = ARM[side]
    wrist = palm-y*PALM
    d = wrist-s
    far = d.length
    length = max(abs(l1-l2)+.002, min(far, l1+l2-.002))
    direction = d/far
    e1 = direction.cross(chest @ Z)
    if e1.length < .05: e1 = direction.cross(chest @ Y)
    e1.normalize()
    e2 = direction.cross(e1)
    plane = e1*math.cos(swivel)+e2*math.sin(swivel)
    along = (l1*l1-l2*l2+length*length)/(2*length)
    elbow = s+direction*along+plane*math.sqrt(max(0.0, l1*l1-along*along))
    reached = s+direction*length
    fore = (reached-elbow).normalized()
    # The wrist: bent toward the butt or the point, and forward or back.
    side_bend = math.atan2(fore.dot(shaft), fore.dot(y))
    flex = math.atan2(fore.dot(y.cross(shaft)), fore.dot(y))
    cost = 9*max(0.0, side_bend-.6)**2+9*max(0.0, -side_bend-.2)**2+.25*(side_bend-.2)**2+9*max(0.0, abs(flex)-.65)**2+.25*flex*flex
    # The forearm's turn: the thumb from where the elbow's hinge has it.
    hinge = plane.cross(direction)
    thumb = hinge.cross(fore)
    lie = shaft-fore*shaft.dot(fore)
    if lie.length > 1e-4 and thumb.length > 1e-4:
        twist = thumb.angle(lie)
        cost += .12*twist*twist+9*max(0.0, twist-1.35)**2
    # The elbow: where it hangs of itself, and out of the body.
    out = (elbow-s)/l1
    cost += .3*(1-out.dot(wanted))
    off = (elbow-near(elbow, trunk[0], trunk[1])).length
    cost += 40*max(0.0, .2-off)**2
    cost += 60*(far-length)**2
    if before[side] is not None:
        cost += .6*((y-before[side][0]).length_squared+(out-before[side][1]).length_squared)+.3*(plane-before[side][2]).length_squared
    if homing[0] > 0:
        cost += 4*homing[0]*((y-HOME[side][0]).length_squared+(out-HOME[side][1]).length_squared+.5*(plane-HOME[side][2]).length_squared)
    return cost, plane, out

def near(p, a, b):
    """The point of the line a-b nearest p."""
    d = b-a
    return a+d*max(0.0, min(1.0, (p-a).dot(d)/max(1e-9, d.dot(d))))

def grip(side, palm, shaft):
    """The hand closed on the shaft at `palm`; where its palm came to."""
    hand = B['hand_'+side]
    fore = B['lowerarm_'+side]
    upper = B['upperarm_'+side]
    s = upper.matrix.translation.copy()
    chest = B['spine_03'].matrix.to_quaternion() @ CHEST.to_quaternion().inverted()
    trunk = (B['spine_01'].matrix.translation.copy(), B['neck_01'].matrix.translation.copy())
    wanted = (chest @ ELBOW_REST[side]).normalized()
    u = chest @ FINGERS[side]
    u = (u-shaft*u.dot(shaft))
    if u.length < .05: u = shaft.cross(chest @ X)
    u.normalize()
    v = shaft.cross(u)
    def cost(a, b):
        return arm_cost(side, palm, shaft, u*math.cos(a)+v*math.sin(a), b, s, chest, trunk, wanted)[0]
    best = min((cost(i*math.pi/9, j*math.pi/9), i*math.pi/9, j*math.pi/9) for i in range(18) for j in range(18))
    step = math.pi/18
    for i in range(6):
        c, a, b = best
        best = min([best]+[(cost(a+da, b+db), a+da, b+db) for da, db in ((step, 0), (-step, 0), (0, step), (0, -step), (step, step), (-step, -step), (step, -step), (-step, step))])
        if best[0] >= c: step /= 2
    c, a, b = best
    y = u*math.cos(a)+v*math.sin(a)
    c, plane, out = arm_cost(side, palm, shaft, y, b, s, chest, trunk, wanted)
    now[side] = (y, out, plane)
    two_bone(upper, fore, hand, palm-y*PALM, s+plane)
    point_hand(side, shaft, y)
    # A fist turned about the forearm's length takes the forearm round with
    # it, most of the way (the wrist is left the rest).
    q = hand.matrix_basis.to_quaternion()
    twist = (2*math.atan2(q.y, q.w)+math.pi) % (2*math.pi)-math.pi
    kept = hand.matrix.copy()
    m = fore.matrix.copy()
    along = m.to_quaternion() @ Y
    set_world(fore, m.translation, Quaternion(along, twist*FOREARM_TWIST) @ m.to_quaternion())
    set_world(hand, kept.translation, kept.to_quaternion())
    return hand.matrix @ V(0, PALM, 0)

# What the last pose made of the spear: how far it was moved from what was
# asked (metres, radians), and what is left between each palm and the shaft.
held = {'moved': 0.0, 'turned': 0.0, 'gap': 0.0}

def spear(fist, point):
    """Both hands on the spear: the right fist's place on the shaft at
    `fist`, the point away along `point`. Where the arms cannot hold it so,
    it is moved and turned the least that lets them."""
    fist = Vector(fist)
    point = Vector(point).normalized()
    asked = (fist.copy(), point.copy())
    shoulder('r', fist)
    shoulder('l', fist+point*SPACING)
    for i in range(10):
        got = {s: grip(s, fist+point*(SPACING if s == 'l' else 0.0), point) for s in 'rl'}
        gap = max((got['r']-fist).length, (got['l']-(fist+point*SPACING)).length)
        if gap < .0015: break
        point = (got['l']-got['r']).normalized()
        fist = (got['r']+got['l'])/2-point*SPACING/2
    before.update(now)
    held['moved'] = (fist-asked[0]).length
    held['turned'] = point.angle(asked[1])
    held['gap'] = gap

def from_point(tip, point):
    """The right fist's place for the spear's point to be at `tip`."""
    return Vector(tip)-Vector(point).normalized()*REACH

# How far a planted foot was left short of its place (checked).
stretch = [0.0]

def foot(side, forward=0.0, lift=0.0, aside=0.0, heel=0.0, yaw=0.0, knee=None):
    """A foot: where the stance has it, moved `forward`, `aside` (to his
    left) and `lift`ed, turned `yaw` (to his left), its heel raised `heel`
    (radians, about the ball of the foot). A leg at full stretch that still
    cannot reach lets its heel come up as far as it needs."""
    turn = Quaternion(Z, yaw)
    ball = BALLS[side]+V(aside, -forward, lift)
    toes = turn @ TOES[side]
    hip = B['thigh_'+side].matrix.translation
    def ankle(raised):
        q = Quaternion(Z.cross(toes), raised) @ turn
        return ball+q @ (PLANTED[side]-BALLS[side]), q
    if (ankle(heel)[0]-hip).length > LEG[side]*.985 and lift < .02:
        low, high = heel, 1.1
        for i in range(14):
            mid = (low+high)/2
            if (ankle(mid)[0]-hip).length > LEG[side]*.985: low = mid
            else: high = mid
        heel = high
    place, q = ankle(heel)
    pole = knee if knee is not None else (hip+place)/2+(toes*.4+AHEAD*.6+Z*(.5*lift)).normalized()*.6
    reached = two_bone(B['thigh_'+side], B['calf_'+side], B['foot_'+side], place, pole)
    set_world(B['foot_'+side], B['foot_'+side].matrix.translation, q @ FOOT_TURN[side])
    set_world(B['ball_'+side], B['ball_'+side].matrix.translation, turn @ BALL_TURN[side])
    if lift < .005: stretch[0] = max(stretch[0], (reached-place).length)

def feet(left=None, right=None):
    foot('l', **(left or {}))
    foot('r', **(right or {}))

# ---- The guard ----

# The trunk in the guard, from the plain stance: bladed, the left shoulder
# toward the enemy, sat a little into the knees.
GUARD = {'turn': -.62, 'lean': .07, 'down': .035, 'forward': .0, 'aside': .0}
# The spear in it: the right fist at the hip, the point at a chest ahead.
GUARD_FIST = V(-.27, .2, 1.0)
GUARD_POINT = (V(.04, -1.36, 1.36)-GUARD_FIST).normalized()

def stand(turn=0.0, lean=0.0, down=0.0, forward=0.0, aside=0.0, **more):
    """The trunk, as `body`, counted from the guard."""
    body(turn=GUARD['turn']+turn, lean=GUARD['lean']+lean, down=GUARD['down']+down, forward=GUARD['forward']+forward, aside=GUARD['aside']+aside, **more)

def idle(t):
    # Breathing, and the weight shifting a little from foot to foot; the
    # point drifts after it.
    # (Every part of it is at nothing at the loop's start: the guard itself.)
    w = 2*math.pi*t
    breath = math.sin(w)
    sway = (1-math.cos(w))/2
    drift = math.sin(w)*(1-math.cos(w))/1.3
    stand(down=.007*breath, lean=.012*breath, aside=.012*sway, turn=.025*sway, nod=-.012*breath)
    spear(GUARD_FIST+V(.004*sway, 0, .008*drift), GUARD_POINT+V(.014*sway, 0, .016*drift))
    feet()

reset()
before.update(r=None, l=None)
idle(0)
HOME.update(now)
STANCE = {b.name: b.matrix_basis.copy() for b in B}

# ---- Measuring a pose ----

def between(a0, a1, b0, b1, n=40):
    return min((p-near(p, b0, b1)).length for p in (a0.lerp(a1, i/n) for i in range(n+1)))

def measure():
    """The spear's ends, how near its shaft comes to the body (less than
    nothing: it is in it), how far each wrist is bent, and how far the left
    palm is from its place on the shaft."""
    def head(n): return B[n].matrix.translation.copy()
    hand = B['hand_r'].matrix
    butt, tip = hand @ V(0, PALM, -GRIP), hand @ V(0, PALM, REACH)
    top = head('Head')+(B['Head'].matrix.to_quaternion() @ Y)*.11
    parts = [('head', top, top, .125), ('neck', head('neck_01'), head('Head'), .07), ('chest', head('spine_02'), head('neck_01'), .15),
        ('belly', head('pelvis'), head('spine_02'), .15)]
    for s in 'lr':
        parts += [('thigh '+s, head('thigh_'+s), head('calf_'+s), .085), ('shin '+s, head('calf_'+s), head('foot_'+s), .06),
            ('foot '+s, head('foot_'+s), head('ball_'+s), .05), ('upper arm '+s, head('upperarm_'+s), head('lowerarm_'+s), .05)]
    clear = min((between(butt, tip, a, b)-r-.02, name) for name, a, b, r in parts)
    wrists = {}
    for s in 'lr':
        y = B['lowerarm_'+s].matrix.to_quaternion() @ Y
        wrists[s] = math.degrees(y.angle(B['hand_'+s].matrix.to_quaternion() @ Y))
    gap = ((B['hand_l'].matrix @ V(0, PALM, 0))-(hand @ V(0, PALM, SPACING))).length
    reach = {s: (head('hand_'+s)-head('upperarm_'+s)).length/((head('lowerarm_'+s)-head('upperarm_'+s)).length+(head('hand_'+s)-head('lowerarm_'+s)).length) for s in 'lr'}
    return {'butt': butt, 'tip': tip, 'clear': clear, 'wrists': wrists, 'gap': gap, 'reach': reach}

# The joints whose turn from one frame to the next is watched: a limb that
# flips round between two frames shows as a jump here.
WATCHED = [n+s for n in ('clavicle_', 'upperarm_', 'lowerarm_', 'hand_', 'thigh_', 'calf_', 'foot_') for s in 'lr']+['pelvis', 'spine_01', 'spine_02', 'spine_03', 'neck_01', 'Head']

def author(name, pose, advance=None, loop=False, sink=()):
    """Keys a clip from `pose`; `advance`, the travel the game carries him
    through meanwhile; `sink`, the stretch of the clip through which the
    spear is meant to be in the ground."""
    length = CLIPS[name]
    a = bpy.data.actions.new(name)
    rig.animation_data.action = a
    frames = int(round(length*30))
    rows = []
    worst = {'gap': 0.0, 'moved': 0.0, 'stretch': 0.0, 'wrist': 0.0, 'clear': (9.0, ''), 'ground': 9.0}
    before.update(r=None, l=None)
    for f in range(frames+1):
        t = f/frames
        reset()
        stretch[0] = 0.0
        homing[0] = 0.0 if loop else max(ease(1-t/.12), ease((t-.82)/.18))
        pose(t)
        if not loop and f in (0, frames):
            off = max((b.matrix_basis.translation-STANCE[b.name].translation).length+b.matrix_basis.to_quaternion().rotation_difference(STANCE[b.name].to_quaternion()).angle
                for b in B)
            if off > .02: print('PIKE_CHECK', name, 'is not in the guard at', t, 'by', round(off, 3))
            apply(STANCE)
        m = measure()
        m['turns'] = {n: B[n].matrix_basis.to_quaternion() for n in WATCHED}
        m.update(t=t, moved=held['moved'], turned=held['turned'], stretch=stretch[0], travel=curve(advance, t) if advance else 0.0)
        rows.append(m)
        worst['gap'] = max(worst['gap'], m['gap'])
        worst['moved'] = max(worst['moved'], m['moved'])
        worst['stretch'] = max(worst['stretch'], m['stretch'])
        worst['wrist'] = max(worst['wrist'], *m['wrists'].values())
        worst['clear'] = min(worst['clear'], m['clear'])
        if not (sink and sink[0] <= t <= sink[1]): worst['ground'] = min(worst['ground'], m['tip'].z, m['butt'].z)
        keys(f)
    finish(name, a, length)
    # How fast the point goes over the ground (m/s), frame to frame.
    speeds = [0.0]
    for i in range(1, len(rows)):
        step = rows[i]['tip']-rows[i-1]['tip']+V(0, -(rows[i]['travel']-rows[i-1]['travel']), 0)
        speeds.append(step.length*30)
    jump = max((math.pi-abs(math.pi-rows[i]['turns'][n].rotation_difference(rows[i-1]['turns'][n]).angle), n, rows[i]['t']) for i in range(1, len(rows)) for n in WATCHED)
    print('PIKE_CHECK', name, 'sharpest turn of a joint in a frame', round(math.degrees(jump[0])), jump[1], 'at', round(jump[2], 3))
    fastest = max(speeds)
    quick = [rows[i]['t'] for i in range(len(rows)) if speeds[i] > fastest*.5]
    print('PIKE_CHECK', name, 'left palm off the shaft', round(worst['gap'], 4), '| spear moved to be held', round(worst['moved'], 3), '| foot short', round(worst['stretch'], 3),
        '| wrist', round(worst['wrist']), '| nearest', round(worst['clear'][0], 3), worst['clear'][1], '| lowest', round(worst['ground'], 3),
        '| point fastest', round(fastest, 1), 'm/s, over half that from', round(min(quick)-1/frames, 3) if quick else '-', 'to', round(max(quick), 3) if quick else '-')
    if CHECK:
        for m, speed in zip(rows, speeds):
            print('  %.3f tip (%.2f %.2f %.2f) butt z %.2f  %4.1f m/s  moved %.3f turned %2.0f  wrists r %2.0f l %2.0f  reach r %.2f l %.2f  clear %.3f %s  foot %.3f' % (m['t'], m['tip'].x,
                m['tip'].y-m['travel'], m['tip'].z, m['butt'].z, speed, m['moved'], math.degrees(m['turned']), m['wrists']['r'], m['wrists']['l'], m['reach']['r'], m['reach']['l'],
                m['clear'][0], m['clear'][1], m['stretch']))

# ---- The clips ----

def thrust1(t):
    # Normal attack A. The weight sat back and the spear drawn back past the
    # hip as the body coils away; then the lead foot lunged out, the hips
    # driven after it and the rear hip and shoulder thrown round behind the
    # shaft as both arms shoot it out level at a chest; a beat at full reach,
    # the point pushed through, and a quick recovery.
    T = [(0, 0), (.27, 1), (.33, 1.05, 'out'), (.5, 2, 'hit'), (.6, 3, 'out'), (.94, 4), (1, 4)]
    a = curve(T, t)
    b = curve(T, lead(t, .035))
    stand(turn=at([0, -.42, .3, .34, 0], b), lean=at([0, -.1, .3, .35, 0], b), down=at([0, .07, .17, .19, 0], b), forward=at([0, -.13, .34, .38, 0], b),
        nod=at([0, .05, -.1, -.1, 0], a))
    fist = at([GUARD_FIST, V(-.43, .6, 1.04), V(-.29, -.36, 1.0), V(-.29, -.4, 1.0), GUARD_FIST], a)
    point = dir_at([GUARD_POINT, V(.1, -1, .2), V(.15, -1, .1), V(.15, -1, .09), GUARD_POINT], a)
    spear(fist, point)
    step = curve([(0, 0), (.3, 0), (.48, .42), (.64, .42), (.9, 0), (1, 0)], t)
    feet(left={'forward': step, 'lift': .07*bump(t, .3, .48)+.04*bump(t, .64, .9)}, right={'heel': .4*at([0, 0, 1, 1, 0], b)})

def thrust2(t):
    # Normal attack B. He sinks and the point is dipped low, the butt drawn
    # back and up past the hip; then he comes up out of his knees behind it
    # and the point is driven rising under a guard, into the belly and up to
    # the breast.
    T = [(0, 0), (.27, 1), (.33, 1.05, 'out'), (.5, 2, 'hit'), (.6, 3, 'out'), (.94, 4), (1, 4)]
    a = curve(T, t)
    b = curve(T, lead(t, .035))
    stand(turn=at([0, -.36, .28, .32, 0], b), lean=at([0, .2, .1, .08, 0], b), down=at([0, .2, .03, .0, 0], b), forward=at([0, -.1, .32, .36, 0], b),
        nod=at([0, -.1, -.05, -.05, 0], a))
    fist = at([GUARD_FIST, V(-.42, .52, 1.0), V(-.28, -.3, .9), V(-.28, -.33, .88), GUARD_FIST], a)
    point = dir_at([GUARD_POINT, V(.12, -1, -.3), V(.15, -1, .3), V(.15, -1, .34), GUARD_POINT], a)
    spear(fist, point)
    step = curve([(0, 0), (.3, 0), (.48, .4), (.64, .4), (.9, 0), (1, 0)], t)
    feet(left={'forward': step, 'lift': .07*bump(t, .3, .48)+.04*bump(t, .64, .9)}, right={'heel': .45*at([0, 0, 1, 1, 0], b)})

def strike(t):
    # Powerful Strike. Drawn right back: the weight on the rear leg, the body
    # wound away, the butt far behind the hip; a held breath; then the lead
    # foot flung far out and everything thrown down the shaft, the hips
    # sunk and driven, the rear leg straight behind, the body laid along the
    # line of the spear. Held at full reach, the point twisted home, and
    # the lead foot pushed off to recover.
    T = [(0, 0), (.32, 1), (.4, 1.06, 'out'), (.533, 2, 'hit'), (.68, 3, 'out'), (.95, 4), (1, 4)]
    # (The arms start out sooner than the hips' drive gathers, so they are
    # not flung the whole way in the last frame.)
    a = curve([k[:2]+('swing',) if k[2:] == ('hit',) else k for k in T], t)
    b = curve(T, lead(t, .04))
    stand(turn=at([0, -.75, .3, .34, 0], b), lean=at([0, -.2, .46, .52, 0], b), down=at([0, .15, .3, .33, 0], b), forward=at([0, -.26, .5, .55, 0], b),
        nod=at([0, .08, -.25, -.25, 0], a))
    fist = at([GUARD_FIST, V(-.46, .72, 1.08), V(-.3, -.6, .84), V(-.3, -.65, .83), GUARD_FIST], a)
    point = dir_at([GUARD_POINT, V(.1, -1, .26), V(.14, -1, .16), V(.14, -1, .15), GUARD_POINT], a)
    spear(fist, point)
    step = curve([(0, 0), (.3, -.12), (.38, -.12), (.54, .7), (.7, .7), (.93, 0), (1, 0)], t)
    feet(left={'forward': step, 'lift': .05*bump(t, .06, .3)+.1*bump(t, .38, .54)+.05*bump(t, .7, .93)}, right={'heel': .5*at([0, 0, 1, 1, 0], b)})

# Cleave's step: he steps forward into the sweep and brings the rear foot up
# after it, ending in his guard a step further on. The game carries him over
# the ground as he steps (the same keys: fraction of the clip, metres); here
# each foot is kept where it is on the ground beneath him.
CLEAVE_ADVANCE = [(0, 0), (.34, 0), (.54, .36), (.68, .4), (1, .4)]
GUARD_HEADING = math.atan2(GUARD_POINT.x, -GUARD_POINT.y)

def turned(point, turn):
    """A point beside him as he stood in the plain stance, carried round with
    his hips' place and the chest's `turn`."""
    at_hips = B['pelvis'].matrix.translation
    p = Quaternion(Z, turn) @ V(point.x-PELVIS.x, point.y-PELVIS.y, 0)
    return V(at_hips.x+p.x, at_hips.y+p.y, point.z)

def cleave(t):
    # The body wound far round to the right, the hips with it, the point
    # carried out and back to his right at the level of a chest; then the
    # lead foot stepped in and the whole of him unwound: hips, chest, and the
    # left arm hauling the shaft round and out, the head of the spear swept
    # level from his right through everything before him and away past his
    # left; carried round after it, then brought back to the guard as the
    # rear foot comes up.
    # (The chest's turn, and the spear's heading: to his left of ahead.)
    turn = curve([(0, GUARD['turn']), (.3, -1.82), (.37, -1.9, 'out'), (.63, .3), (.72, .42, 'out'), (1, GUARD['turn'])], t)
    heading = curve([(0, GUARD_HEADING), (.3, -1.36), (.39, -1.46, 'out'), (.665, 1.82), (.75, 1.98, 'out'), (1, GUARD_HEADING)], t)
    coil = curve([(0, 0), (.3, 1), (.38, 1), (.52, 0), (1, 0)], t)
    sweep = curve([(0, 0), (.38, 0), (.6, 1), (.74, 1), (1, 0)], t)
    forward = curve([(0, 0), (.3, -.06), (.52, .3), (.66, .36), (.9, .4), (1, .4)], t)-curve(CLEAVE_ADVANCE, t)
    held_in = curve([(0, 0), (.22, 1), (.8, 1), (1, 0)], t)
    body(turn=turn, hip=.4+.1*held_in, lean=GUARD['lean']+.05*coil+.12*sweep, tilt=0, down=GUARD['down']+.07*coil+.1*sweep, forward=forward, nod=-.05*sweep)
    # Where the chest has the right fist: by the hip while the spear lies
    # near ahead of the chest, out before the belly as it comes across it.
    across = heading-turn
    w = max(0.0, min(1.0, (across-.45)/1.15))
    fist = turned(V(-.27, .12, 1.05).lerp(V(-.2, -.33, 1.14), w), turn)
    level = curve([(0, GUARD_POINT.z), (.3, .1), (.5, .04), (.7, .08), (1, GUARD_POINT.z)], t)
    point = Quaternion(Z, heading) @ AHEAD+V(0, 0, level)
    spear(GUARD_FIST.lerp(fist, held_in), point)
    carried_on = curve(CLEAVE_ADVANCE, t)
    l = curve([(0, 0), (.36, 0), (.52, .42), (.68, .42), (.9, .4), (1, .4)], t)
    r = curve([(0, 0), (.68, 0), (.9, .4), (1, .4)], t)
    feet(left={'forward': l-carried_on, 'lift': .09*bump(t, .36, .52), 'yaw': -.25*coil+.2*sweep},
        right={'forward': r-carried_on, 'lift': .07*bump(t, .68, .9), 'yaw': -.45*coil, 'heel': .5*sweep*(1-bump(t, .68, .9))*curve([(0, 1), (.68, 1), (.9, 0), (1, 0)], t)})

def execute(t):
    # The finisher. The spear swung up high in both hands, the butt over
    # the head, the point hung down at the beaten enemy at his feet, his body
    # stretched up and arched back; then plunged: the whole of him dropped on
    # the shaft, the hips sunk, the back folded over it, the point driven
    # through and into the ground; he bears down on it, then hauls it out
    # and rises.
    T = [(0, 0), (.34, 1), (.45, 1.07, 'out'), (.564, 2, 'hit'), (.66, 2.6, 'out'), (.8, 3), (1, 4)]
    a = curve(T, t)
    b = curve(T, lead(t, .03))
    stand(turn=at([0, .1, .1, .1, 0], b), lean=at([0, -.22, .3, .36, 0], b), down=at([0, -.03, .38, .45, 0], b), forward=at([0, -.06, .06, .08, 0], b),
        nod=at([0, .3, .15, .15, 0], a))
    aim = [GUARD_POINT, V(.05, -.74, -.67), V(0, -.3, -.95), V(0, -.3, -.95), GUARD_POINT]
    fist = at([GUARD_FIST, V(-.32, .2, 1.86), from_point(V(-.27, -.88, -.1), aim[2]), from_point(V(-.27, -.88, -.17), aim[3]), GUARD_FIST], a)
    spear(fist, dir_at(aim, a))
    toes = .3*bump(t, .12, .52)
    feet(left={'heel': toes}, right={'heel': toes+.5*at([0, 0, 1, 1, 0], b)})

def slam(t):
    # Thunder Slam. The spear swung up and back over the head, the body
    # stretched up onto its toes and arched under it; then the whole length
    # of it hurled over and down as he drops, the lead foot stamped out, the
    # back folded, the head of the spear brought down on the ground ahead;
    # held there a beat, and a slow rise.
    T = [(0, 0), (.26, 1), (.32, 1.05, 'out'), (.513, 2, 'swing'), (.72, 3), (1, 4)]
    a = curve(T, t)
    b = curve(T, lead(t, .03))
    stand(turn=at([0, .3, .25, .25, 0], b), lean=at([0, -.28, .46, .5, 0], b), down=at([0, -.04, .3, .33, 0], b), forward=at([0, -.04, .0, .0, 0], b),
        nod=at([0, .2, -.2, -.2, 0], a))
    low = V(-.3, -.04, .9)
    struck = (V(-.04, -1.33, .035)-low).normalized()
    # (Over the top on the way down, not round the side: a state between.)
    over = a if a < 1 else (1+2*(a-1) if a < 2 else a+1)
    aim = [GUARD_POINT, V(.12, .5, .86), V(.12, -.5, .86), struck, struck, GUARD_POINT]
    fist = at([GUARD_FIST, V(.16, -.26, 1.4), V(-.25, -.4, 1.25), low, low+V(0, 0, -.01), GUARD_FIST], over)
    fist += V(-.1, -.12, 0)*bump(a, 0, 1)
    a = over
    spear(fist, dir_at(aim, a))
    step = curve([(0, 0), (.36, 0), (.5, .24), (.74, .24), (.95, 0), (1, 0)], t)
    toes = .3*bump(t, .1, .46)
    feet(left={'forward': step, 'lift': .1*bump(t, .36, .5)+.04*bump(t, .74, .95), 'heel': toes*(1 if t < .36 else 0)}, right={'heel': toes})

def shockwave(t):
    # Shockwave. The spear swung upright before him and hauled up high in
    # both hands, he on his toes under it; then its butt hammered straight
    # down into the ground by his lead foot, both arms and the drop of his
    # whole body behind it; held, and he rises with it.
    # (Guard, the spear stood up beside the right hip on its way round,
    # hauled up before him, struck down, held, and back the same way.)
    T = [(0, 0), (.17, 1, 'in'), (.33, 2, 'out'), (.44, 2.07, 'out'), (.555, 3, 'hit'), (.76, 4), (.88, 5, 'in'), (1, 6, 'out')]
    a = curve(T, t)
    b = curve(T, lead(t, .03))
    stand(turn=at([0, .2, .4, .5, .5, .2, 0], b), lean=at([0, -.04, -.1, .22, .26, .04, 0], b), down=at([0, -.01, -.04, .36, .4, .1, 0], b),
        forward=at([0, 0, .0, .06, .06, .0, 0], b), nod=at([0, .05, .1, -.15, -.15, 0, 0], a))
    beside = (V(-.4, -.1, 1.1), V(-.05, -.5, .87))
    aim = [GUARD_POINT, beside[1], V(0, -.08, 1), V(0, 0, 1), V(0, 0, 1), beside[1], GUARD_POINT]
    fist = at([GUARD_FIST, beside[0], V(-.08, -.48, 1.3), V(-.08, -.5, GRIP+.02), V(-.08, -.5, GRIP+.02), beside[0], GUARD_FIST], a)
    spear(fist, dir_at(aim, a))
    toes = .3*bump(t, .14, .5)
    feet(left={'heel': toes}, right={'heel': toes})

def cry(t):
    # War Cry. He sinks a little and gathers the spear in; then heaves it up
    # at the sky in both hands, the chest thrown open, up on his toes, the
    # head back in a roar; holds it shaking there, and lowers it.
    T = [(0, 0), (.13, 1), (.3, 2, 'swing'), (.7, 3), (1, 4)]
    a = curve(T, t)
    b = curve(T, lead(t, .02))
    stand(turn=at([0, -.05, .4, .4, 0], b), lean=at([0, .14, -.36, -.38, 0], b), down=at([0, .1, -.04, -.03, 0], b), forward=at([0, -.02, .05, .05, 0], b),
        nod=at([0, .1, -.55, -.6, 0], a))
    shake = math.sin(t*75)*bump(t, .3, .72)
    aim = [GUARD_POINT, V(.14, -1, .3), V(.5, -.05, .87), V(.52, -.05, .86), GUARD_POINT]
    fist = at([GUARD_FIST, V(-.26, .14, .95), V(0, -.3, 1.46), V(0, -.3, 1.44), GUARD_FIST], a)
    spear(fist+V(0, 0, .012*shake), dir_at(aim, a)+V(.02*shake, 0, 0))
    toes = .32*bump(t, .16, .82)
    feet(left={'heel': toes}, right={'heel': toes})

def leap(t):
    # Leap. A deep crouch, the spear drawn low and back; the spring (the game
    # lifts him from here), the legs tucked up under him and the spear swung
    # up over the head, point down; the landing, his whole weight dropped on
    # the shaft and the point driven into the ground before him; then he
    # hauls it out and rises.
    crouch = curve([(0, 0), (.12, 1), (.2, 1), (.28, 0), (1, 0)], t)
    air = curve([(0, 0), (.2, 0), (.3, 1), (.46, 1), (.56, 0), (1, 0)], t)
    land = curve([(0, 0), (.48, 0), (.56, 1, 'hit'), (.76, 1), (1, 0)], t)
    stand(down=.3*crouch-.05*air+.45*land, forward=-.05*crouch+.08*air+.08*land, lean=.42*crouch-.32*air+.32*land, turn=.1*crouch+.1*air+.1*land,
        nod=.1*air+.15*land)
    T = [(0, 0), (.12, 1), (.2, 1.04), (.32, 2), (.46, 2.08), (.555, 3, 'hit'), (.76, 4), (1, 5)]
    a = curve(T, t)
    aim = [GUARD_POINT, V(.12, -1, .3), V(.05, -.74, -.67), V(0, -.3, -.95), V(0, -.3, -.95), GUARD_POINT]
    fist = at([GUARD_FIST, V(-.34, .32, .74), V(-.32, .2, 1.84), from_point(V(-.27, -.9, -.08), aim[3]), from_point(V(-.27, -.9, -.13), aim[4]), GUARD_FIST], a)
    spear(fist, dir_at(aim, a))
    if air > 0:
        # Legs drawn up beneath him in the air.
        feet(left={'forward': .12*air, 'lift': .5*air}, right={'forward': .06*air, 'lift': .42*air, 'heel': .3*air})
    else: feet(left={'forward': .28*land}, right={'heel': .4*land})

POSES = [('PikeIdle', idle, {'loop': True}), ('PikeThrust1', thrust1, {}), ('PikeThrust2', thrust2, {}), ('PikeCleave', cleave, {'advance': CLEAVE_ADVANCE}),
    ('PikeStrike', strike, {}), ('PikeExecute', execute, {'sink': (.5, .95)}), ('PikeSlam', slam, {'sink': (.5, .75)}), ('PikeShockwave', shockwave, {}),
    ('PikeCry', cry, {}), ('PikeLeap', leap, {'sink': (.5, .92)})]
for name, pose, more in POSES:
    if name in AUTHORED: author(name, pose, **more)

rig.animation_data.action = None
for m in unbound: m.show_viewport = True
# The clips that were there already all come in with their strips from frame
# 1, where these begin at 0, and the export begins every clip at 0: left so,
# each would go out a frame later and longer than it came in, held on its
# first pose. Those that began at once in the file (BEGAN, read from it
# above) are set back to begin at 0, so every clip goes out with the timing
# it came in with.
for track in rig.animation_data.nla_tracks:
    if track.name in AUTHORED or BEGAN.get(track.name, 1.0) > 1/60: continue
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
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS', export_force_sampling=True)
print('PIKE_ANIMATIONS_READY', len(rig.animation_data.nla_tracks))
