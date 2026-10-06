"""Authors the wizard's spell-casting clips onto the supplied rig (after
import_character.py and the others; safe to rerun).

The wizard casts with his free left hand; his right holds his staff before
his chest like a walking stick, and the game stands the staff upright beneath
that fist every frame (scripts/visual.gd align_walking_staff), so wherever the
right fist goes a vertical staff passes down through it. Every clip is keyed
here frame by frame from his stance (WizardIdle), the whole body in it: the
hips and spine wound up and unwound, the weight carried onto the front foot
or sat back onto the rear, the head on the target, both arms carried by
two-bone IK with the left palm turned the way the spell goes, the fingers
opened from the stance's curl, the feet kept on the ground by leg IK (the
rear heel coming up as the weight goes forward), and each eased out of the
stance and back into it so one crossfades cleanly into the next. The right
fist is kept where an upright staff through it clears his body and head.

  CastBolt      .6 s, released at .50: a one-handed hurl. The left hand draws
                back past the shoulder as the body coils away; then it snaps
                forward at a chest ahead, palm open, the body uncoiling behind
                it and the weight thrown onto the front foot. (Fireball, Ice
                Bolt, Lightning Bolt.)
  CastPoint     .7 s, released at .50: the left hand drawn in across the chest,
                then the arm thrust straight out, the finger pointing at the
                target, the body leaning in behind it and the head lowered
                to stare it down; held a beat. (Ice Prison, Lightning Rod,
                System Shock.)
  CastGround    .9 s, released at .55: both hands raised above the shoulders
                (the right fist rising with the staff, which stays upright),
                the chest lifted; then the left palm driven down at the
                ground ahead as the hips drop into a half crouch; held; a rise.
                (Ice Spikes, Fire Tornado.)
  CastSelf      1.0 s, released at .50: a burst from the body. Both arms drawn
                in to the chest and the head bowed; then both flung out wide
                and a little up as the chest opens and the head comes back,
                the staff hand out to his right at shoulder height; held open
                a beat. (Blast Wave, Ice Storm, Lightning Shield, Blazing
                Speed.)
  CastChannel   1.2 s, loops: the channelling pose. The left arm out at the
                target, palm forward, fingers spread; the staff fist drawn in
                close; the body braced back against the stream on the rear
                foot; the arm trembling very slightly, the head steady. The
                game crossfades into this from the stance and out again, so
                there is no wind-up, only the held effort. (Freeze Floor,
                Frost Blast.)

None of them travels: he ends where he began.

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/import_wizard.py

  HERO_GLB=/path/model.glb      the model to read and write back
                                (default assets/models/character/warrior.glb)
  WIZARD_ONLY=CastBolt,CastSelf author only these (the rest left as they are)
  WIZARD_OUT=/path/out.glb      write there instead of over the model
  WIZARD_CHECK=1                print every frame's measurements
"""
from pathlib import Path
import json, math, os, struct
import bpy
from mathutils import Vector, Matrix, Quaternion
ROOT = Path(__file__).resolve().parents[1]
GLB = Path(os.environ.get('HERO_GLB', 'assets/models/character/warrior.glb'))
if not GLB.is_absolute(): GLB = ROOT/GLB
OUT = Path(os.environ.get('WIZARD_OUT', str(GLB)))
# name: seconds, and the share of each at which the spell leaves him
# (the game's casting code keeps the same).
CLIPS = {'CastBolt': .6, 'CastPoint': .7, 'CastGround': .9, 'CastSelf': 1.0, 'CastChannel': 1.2}
RELEASE = {'CastBolt': .5, 'CastPoint': .5, 'CastGround': .55, 'CastSelf': .5}
ONLY = [n for n in os.environ.get('WIZARD_ONLY', '').split(',') if n]
for n in ONLY: assert n in CLIPS, n
AUTHORED = ONLY or list(CLIPS)
CHECK = bool(os.environ.get('WIZARD_CHECK'))
# The staff as the game stands it in the right fist (scripts/visual.gd): this
# long, held this far up it, leaning this much forward.
STAFF_LENGTH = 1.65
STAFF_GRIP = .76
STAFF_UP = Vector((0, -.12, 1)).normalized()
PALM = .075

def clip_starts(path):
    """When each clip in a GLB file has its first key (seconds)."""
    with open(path, 'rb') as f:
        f.read(12)
        size, kind = struct.unpack('<II', f.read(8))
        document = json.loads(f.read(size))
    return {a.get('name', ''): min(document['accessors'][s['input']]['min'][0] for s in a['samplers']) for a in document.get('animations', [])}

BEGAN = clip_starts(GLB)
print('WIZARD_CLIPS_BEFORE', len(BEGAN))
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

BASE = pose_of('WizardIdle')
# The left hand's fingers: curled as the stance has them, and opened as the
# library's cast opens them (the right hand's the game keeps closed on the
# staff: scripts/hand_grip.gd).
FINGERS = [n+'_l' for n in ('thumb_01', 'thumb_02', 'thumb_03', 'index_01', 'index_02', 'index_03', 'middle_01', 'middle_02', 'middle_03', 'ring_01', 'ring_02',
    'ring_03', 'pinky_01', 'pinky_02', 'pinky_03')]
OPEN = {n: m for n, m in pose_of('Cast').items() if n in FINGERS} if 'Cast' in bpy.data.actions else {n: BASE[n] for n in FINGERS}
POINTING = {n: (OPEN[n] if n.startswith(('index', 'thumb')) else BASE[n]) for n in FINGERS}

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
    print('WIZARD_CLIP', name, length)

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
    """A moment ahead (or, less than nothing, behind): what moves first is
    keyed a little early, what trails a little late; the clip's ends stay
    where they are."""
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

# Each limb's hinge (the elbow's, the knee's) in its two bones' own axes: the
# rig's bones are all rolled so it is their X.
HINGES = {n+s: V(1, 0, 0) for n in ('upperarm_', 'lowerarm_', 'thigh_', 'calf_') for s in 'lr'}

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
    # no limb is ever left twisted about its length).
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

# How far each arm was left short of where it was sent, and how near its
# elbow's pole came to the arm's own line (degrees; near it, the elbow's
# side is ill-defined and can flip between frames) (checked).
short = {'l': 0.0, 'r': 0.0}
pole_angle = {'l': 90.0, 'r': 90.0}

def arm(side, target, pole):
    s = B['upperarm_'+side].matrix.translation
    pole_angle[side] = min(pole_angle[side], math.degrees((Vector(target)-s).angle(Vector(pole)-s)))
    reached = two_bone(B['upperarm_'+side], B['lowerarm_'+side], B['hand_'+side], target, pole)
    short[side] = max(short[side], (reached-Vector(target)).length)
    return reached

def shoulder(side, target):
    """The shoulder goes a little way after a hand that reaches far."""
    c = B['clavicle_'+side]
    u = B['upperarm_'+side]
    a = u.matrix.translation-c.matrix.translation
    b = Vector(target)-c.matrix.translation
    w = ease(((Vector(target)-u.matrix.translation).length-.3)/.25)
    angle = min(.4*a.angle(b), .32)*w
    if angle > 1e-4: rotate('clavicle_'+side, a.cross(b).normalized(), angle)

# The hands' own axes: the fingers run along Y, the thumb is to +Z, and the
# palm faces +X on the left hand, -X on the right.
PALM_SIDE = {'l': 1.0, 'r': -1.0}

def hand_q(side, palm, fingers):
    """The hand's turn for its palm to face along `palm` and its fingers to
    point along `fingers` (as nearly as both can be had)."""
    x = Vector(palm).normalized()*PALM_SIDE[side]
    y = Vector(fingers)
    y = (y-x*y.dot(x)).normalized()
    z = x.cross(y)
    return Matrix((x, y, z)).transposed().to_quaternion()

def hand(side, q):
    """Turns the hand so, where it is."""
    h = B['hand_'+side]
    set_world(h, h.matrix.translation, q)

def quat_at(values, phase):
    """As `at`, for a turn: the hand carried from each to the next by the
    shortest way round."""
    phase = max(0.0, min(len(values)-1.0, phase))
    i = min(int(phase), len(values)-2)
    return values[i].slerp(values[i+1], phase-i)

def fingers(open, pointing=0.0):
    """The left hand's fingers opened `open` of the way from the stance's
    curl (or `pointing`: the index and thumb alone)."""
    for n in FINGERS:
        o = pose_blend(BASE[n], OPEN[n], open)
        B[n].matrix_basis = pose_blend(o, POINTING[n], pointing)
    update()

def pose_blend(m1, m2, w):
    if w <= 0: return m1.copy()
    if w >= 1: return m2.copy()
    l1, r1, s1 = m1.decompose()
    l2, r2, s2 = m2.decompose()
    return Matrix.LocRotScale(l1.lerp(l2, w), r1.slerp(r2, w), s1)

reset()
PELVIS = B['pelvis'].matrix.translation.copy()
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
# Where the stance has the wrists, and the way its hands lie.
HOME = {s: B['hand_'+s].matrix.translation.copy() for s in 'lr'}
HOME_Q = {s: B['hand_'+s].matrix.to_quaternion() for s in 'lr'}
HOME_PALM = {s: (HOME_Q[s] @ X)*PALM_SIDE[s] for s in 'lr'}
HOME_FINGERS = {s: HOME_Q[s] @ Y for s in 'lr'}

def L(palm, fingers):
    return hand_q('l', palm, fingers)

def R(palm, fingers):
    return hand_q('r', palm, fingers)
print('WIZARD_HOME', {s: [round(v, 3) for v in HOME[s]] for s in 'lr'})

def body(turn=0.0, lean=0.0, tilt=0.0, down=0.0, forward=0.0, aside=0.0, hip=.4, look=0.0, nod=0.0):
    """The trunk: the hips moved (down, forward, to his left), the whole of
    it turned (to his left; `hip` of the turn is the pelvis's, the rest the
    spine's), bent forward (`lean`) and to the side (`tilt`, to his left);
    the head kept on what is before him, turned `look` and bowed `nod`
    beyond that."""
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
    rotate('neck_01', along, -tilt*.3)
    rotate('Head', along, -tilt*.3)

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

last_feet = {}

def feet(left=None, right=None):
    last_feet.update(l=dict(left or {}), r=dict(right or {}))
    foot('l', **last_feet['l'])
    foot('r', **last_feet['r'])

# The elbows: where each hangs of itself when the hand is before the body.
POLE = {'l': V(.75, .15, .9), 'r': V(-.8, .25, .9)}

def left(target, q, pole=None, open=1.0, pointing=0.0):
    """The casting hand: carried to `target` (the wrist), turned `q` (as
    `L` gives it from the palm's and fingers' ways), opened `open`."""
    shoulder('l', target)
    arm('l', target, pole or POLE['l'])
    hand('l', q)
    fingers(open, pointing)

def staff(target, turn=0.0, pole=None, pitch=0.0, q=None):
    """The staff fist: carried to `target` (the wrist), held as the stance
    holds it (or turned `q`), turned with the body and tipped `pitch`
    forward."""
    shoulder('r', target)
    arm('r', target, pole or POLE['r'])
    hand('r', Quaternion(Z, turn) @ Quaternion(X, pitch) @ (q or HOME_Q['r']))

# ---- Measuring a pose ----

def near(p, a, b):
    """The point of the line a-b nearest p."""
    d = b-a
    return a+d*max(0.0, min(1.0, (p-a).dot(d)/max(1e-9, d.dot(d))))

def between(a0, a1, b0, b1, n=40):
    return min((p-near(p, b0, b1)).length for p in (a0.lerp(a1, i/n) for i in range(n+1)))

def fist():
    """The middle of the closed right fist, as the game finds it (the staff
    passes through here)."""
    return sum((B[n+'_r'].matrix.translation for n in ('middle_01', 'middle_02', 'middle_03', 'index_02', 'ring_02')), Vector())/5

def measure():
    """Where the left palm is, where the right fist is, how near the staff
    stood upright through it comes to the body (less than nothing: it is in
    it), how far each wrist is bent, and how far each arm is stretched."""
    def head(n): return B[n].matrix.translation.copy()
    grip = fist()
    foot_, top = grip-STAFF_UP*STAFF_LENGTH*STAFF_GRIP, grip+STAFF_UP*STAFF_LENGTH*(1-STAFF_GRIP)
    crown = head('Head')+(B['Head'].matrix.to_quaternion() @ Y)*.11
    parts = [('head', crown, crown, .125), ('neck', head('neck_01'), head('Head'), .07), ('chest', head('spine_02'), head('neck_01'), .16),
        ('belly', head('pelvis'), head('spine_02'), .16), ('left arm', head('upperarm_l'), head('lowerarm_l'), .05), ('left forearm', head('lowerarm_l'), head('hand_l'), .045)]
    for s in 'lr':
        parts += [('thigh '+s, head('thigh_'+s), head('calf_'+s), .085), ('shin '+s, head('calf_'+s), head('foot_'+s), .06), ('foot '+s, head('foot_'+s), head('ball_'+s), .05)]
    clear = min((between(foot_, top, a, b)-r-.03, name) for name, a, b, r in parts)
    # The left hand against the body.
    palm = B['hand_l'].matrix @ V(0, PALM, 0)
    body_parts = [p for p in parts if not p[0].startswith('left')]
    hand_clear = min(((palm-near(palm, a, b)).length-r-.03, name) for name, a, b, r in body_parts)
    wrists = {}
    for s in 'lr':
        y = B['lowerarm_'+s].matrix.to_quaternion() @ Y
        wrists[s] = math.degrees(y.angle(B['hand_'+s].matrix.to_quaternion() @ Y))
    reach = {s: (head('hand_'+s)-head('upperarm_'+s)).length/((head('lowerarm_'+s)-head('upperarm_'+s)).length+(head('hand_'+s)-head('lowerarm_'+s)).length) for s in 'lr'}
    return {'palm': palm, 'fist': grip, 'clear': clear, 'hand_clear': hand_clear, 'wrists': wrists, 'reach': reach, 'pelvis': head('pelvis')}

# The joints whose turn from one frame to the next is watched: a limb that
# flips round between two frames shows as a jump here.
WATCHED = [n+s for n in ('clavicle_', 'upperarm_', 'lowerarm_', 'hand_', 'thigh_', 'calf_', 'foot_') for s in 'lr']+['pelvis', 'spine_01', 'spine_02', 'spine_03', 'neck_01', 'Head']

def author(name, pose, loop=False, into=.12, out=.84):
    """Keys a clip from `pose`, eased out of the stance over its first `into`
    and back into it from `out` (a loop is left as it is)."""
    length = CLIPS[name]
    a = bpy.data.actions.new(name)
    rig.animation_data.action = a
    frames = int(round(length*30))
    rows = []
    for f in range(frames+1):
        t = f/frames
        reset()
        stretch[0] = 0.0
        short.update(l=0.0, r=0.0)
        pole_angle.update(l=90.0, r=90.0)
        pose(t)
        w = 0.0 if loop else max(ease(1-t/into), ease((t-out)/(1-out)))
        if w > 0:
            for b in B: b.matrix_basis = pose_blend(b.matrix_basis, BASE[b.name], w)
            update()
            # (The feet, set back on the ground where the blend has moved them.)
            for s in 'lr': foot(s, **{k: v*(1-w) for k, v in last_feet.get(s, {}).items()})
        m = measure()
        m['turns'] = {n: B[n].matrix_basis.to_quaternion() for n in WATCHED}
        m['feet'] = {s: B['ball_'+s].matrix.translation.copy() for s in 'lr'}
        m.update(t=t, stretch=stretch[0], short=dict(short), pole=dict(pole_angle))
        rows.append(m)
        keys(f)
    finish(name, a, length)
    # The checks: the release pose, the worst of everything, and the sharpest
    # turn of any joint between two frames.
    release = RELEASE.get(name)
    if release is not None:
        r = min(rows, key=lambda m: abs(m['t']-release))
        far = max(rows, key=lambda m: -m['palm'].y)
        print('WIZARD_CHECK %s at release %.2f: left palm ahead %.2f up %.2f aside %.2f | right fist ahead %.2f up %.2f aside %.2f | farthest palm at %.2f' % (name, r['t'],
            -r['palm'].y, r['palm'].z, r['palm'].x, -r['fist'].y, r['fist'].z, r['fist'].x, far['t']))
    jump = max((math.pi-abs(math.pi-rows[i]['turns'][n].rotation_difference(rows[i-1]['turns'][n]).angle), n, rows[i]['t']) for i in range(1, len(rows)) for n in WATCHED)
    slide = max(max((rows[i]['feet'][s]-rows[0]['feet'][s]).length for s in 'lr') for i in range(len(rows)))
    worst_clear = min((m['clear'] for m in rows), key=lambda c: c[0])
    worst_hand = min((m['hand_clear'] for m in rows), key=lambda c: c[0])
    fists = [m['fist'] for m in rows]
    print('WIZARD_CHECK %s: staff nearest %.3f (%s) | left palm nearest %.3f (%s) | fist up %.2f..%.2f ahead %.2f..%.2f | wrist l %.0f r %.0f | reach l %.2f r %.2f | arm short l %.3f r %.3f | pole off arm l %.0f r %.0f | foot short %.3f | foot slide %.3f | sharpest joint turn %.0f deg %s at %.2f' % (
        name, worst_clear[0], worst_clear[1], worst_hand[0], worst_hand[1], min(p.z for p in fists), max(p.z for p in fists), min(-p.y for p in fists), max(-p.y for p in fists),
        max(m['wrists']['l'] for m in rows), max(m['wrists']['r'] for m in rows), max(m['reach']['l'] for m in rows), max(m['reach']['r'] for m in rows),
        max(m['short']['l'] for m in rows), max(m['short']['r'] for m in rows), min(m['pole']['l'] for m in rows), min(m['pole']['r'] for m in rows), max(m['stretch'] for m in rows), slide, math.degrees(jump[0]), jump[1], jump[2]))
    if loop:
        seam = max((rows[-1]['turns'][n].rotation_difference(rows[0]['turns'][n]).angle for n in WATCHED))
        print('WIZARD_CHECK %s: loop seam %.4f rad' % (name, seam))
    if CHECK:
        for i, m in enumerate(rows):
            if i:
                turns = sorted(((math.pi-abs(math.pi-m['turns'][n].rotation_difference(rows[i-1]['turns'][n]).angle), n) for n in WATCHED), reverse=True)[:3]
                print('  %.3f turned' % m['t'], ' '.join('%s %.0f' % (n, math.degrees(v)) for v, n in turns))
            print('  %.3f palm (%.2f %.2f %.2f) fist (%.2f %.2f %.2f) clear %.3f %s hand %.3f %s wrists l %.0f r %.0f reach l %.2f r %.2f foot %.3f' % (m['t'], m['palm'].x, m['palm'].y, m['palm'].z,
                m['fist'].x, m['fist'].y, m['fist'].z, m['clear'][0], m['clear'][1], m['hand_clear'][0], m['hand_clear'][1], m['wrists']['l'], m['wrists']['r'], m['reach']['l'], m['reach']['r'], m['stretch']))

# ---- The clips ----
#
# Each is laid out as states at phases 0, 1, 2 ... (the stance, the wind-up,
# the release, the follow-through, the stance), with a curve T carrying the
# phase through them in the clip's time: slow into the wind-up, held a beat,
# fast (`hit`) into the release, slowing (`out`) into the follow-through, and
# an easy return. The body's curve runs a moment ahead of the arm's (`lead`)
# so the hips and spine drive the hand rather than follow it.

def bolt(t):
    # The hurl. The left hand lifted out to his side and drawn back past the
    # shoulder, cocked by the ear, as the body coils to the left and sits
    # back onto the rear foot; then
    # everything unwound toward the target: the hips driven forward, the chest
    # turned after them, the arm snapped out at chest height with the palm
    # open behind the bolt, the weight thrown onto the front foot and the rear
    # heel up; a short follow-through, and back.
    # (The states: the stance, the hand lifted out to his side, cocked by
    # the ear, over the shoulder, the release, the follow-through, the
    # stance.)
    T = [(0, 0), (.1, 1), (.2, 2), (.24, 2.04, 'out'), (.38, 3, 'in'), (.5, 4, 'out'), (.62, 5, 'out'), (1, 6)]
    a = curve(T, t)
    b = curve(T, lead(t, .04))
    body(turn=at([0, .25, .5, .1, -.38, -.34, 0], b), lean=at([0, -.04, -.1, .1, .3, .3, 0], b), tilt=at([0, .03, .06, 0, -.08, -.08, 0], b),
        down=at([0, .02, .04, .07, .1, .1, 0], b), forward=at([0, -.04, -.08, .06, .2, .2, 0], b), nod=at([0, -.02, -.04, 0, .02, .04, 0], a))
    wrist = at([HOME['l'], V(.55, .06, 1.22), V(.42, .2, 1.6), V(.3, -.14, 1.64), V(.12, -.74, 1.32), V(.1, -.7, 1.22), HOME['l']], a)
    q = quat_at([HOME_Q['l'], L(V(-.2, -.6, -.75), V(.8, -.2, -.5)), L(V(.3, -.9, .3), V(.2, .1, 1)), L(V(.1, -.9, .4), V(.2, -.4, .9)), L(V(0, -.95, -.3), V(.25, -.3, .9)),
        L(V(0, -.85, -.5), V(.2, -.5, .85)), HOME_Q['l']], a)
    # (The elbow is carried out and a little back as the hand is lifted and
    # cocked, then leads the hand into the throw.)
    pole = at([POLE['l'], V(.6, .7, 1.1), V(.9, .2, 1.3), V(.9, -.1, 1.3), V(.7, -.1, .95), V(.7, -.1, .9), POLE['l']], curve(T, lead(t, .05)))
    left(wrist, q, pole, open=curve([(0, 0), (.25, 1), (.8, 1), (1, 0)], t))
    staff(at([HOME['r'], HOME['r']+V(-.02, .02, -.01), HOME['r']+V(-.03, .03, -.02), HOME['r']+V(-.02, -.06, 0), HOME['r']+V(0, -.14, .04), HOME['r']+V(0, -.14, .03), HOME['r']], a),
        turn=at([0, .15, .3, .05, -.2, -.2, 0], b))
    heel = .4*at([0, 0, 0, .3, 1, 1, 0], b)
    feet(left={}, right={'heel': heel})

def point(t):
    # The point. The hand drawn in across the chest, palm down, the body
    # turned a little away; then the arm thrust straight out, the finger on
    # the target, the body leaning in behind the arm and the head lowered to
    # stare the target down; held so a beat; and back.
    T = [(0, 0), (.24, 1), (.3, 1.05, 'out'), (.5, 2, 'hit'), (.6, 2.5, 'out'), (.74, 3), (1, 4)]
    a = curve(T, t)
    b = curve(T, lead(t, .03))
    body(turn=at([0, .25, -.32, -.32, 0], b), lean=at([0, -.04, .3, .32, 0], b), tilt=at([0, .03, -.05, -.05, 0], b), down=at([0, .02, .08, .08, 0], b),
        forward=at([0, -.05, .14, .15, 0], b), nod=at([0, -.02, .28, .3, 0], a))
    wrist = at([HOME['l'], V(.1, -.1, 1.27), V(.16, -.63, 1.3), V(.16, -.61, 1.28), HOME['l']], a)
    q = quat_at([HOME_Q['l'], L(V(-.3, -.1, -1), V(-.8, -.6, 0)), L(V(-.75, 0, -.65), V(0, -1, -.05)), L(V(-.75, 0, -.65), V(0, -1, -.05)), HOME_Q['l']], a)
    pole = at([POLE['l'], V(.75, .1, .95), V(.6, -.1, .85), V(.6, -.1, .85), POLE['l']], a)
    left(wrist, q, pole, open=0.0, pointing=curve([(0, 0), (.22, 1), (.84, 1), (1, 0)], t))
    staff(at([HOME['r'], HOME['r']+V(-.01, .06, 0), HOME['r']+V(0, -.1, .02), HOME['r']+V(0, -.1, .02), HOME['r']], a), turn=at([0, .15, -.2, -.2, 0], b))
    feet(left={}, right={'heel': .3*at([0, 0, 1, 1, 0], b)})

def ground(t):
    # The slam. Both hands raised above the shoulders, the right fist rising
    # with the staff (upright all the while), the chest lifted and the weight
    # on the toes; a beat at the top; then the left palm driven down at the
    # ground ahead as the hips drop into a half crouch and the back folds
    # over, the staff fist coming down beside the hip; held low; a rise.
    # (The states: the stance, the hands half raised before him, raised,
    # the slam, held low, the stance.)
    T = [(0, 0), (.15, 1, 'in'), (.3, 2, 'out'), (.37, 2.04, 'out'), (.55, 3, 'swing'), (.68, 4, 'out'), (1, 5)]
    a = curve(T, t)
    b = curve(T, lead(t, .03))
    body(turn=at([0, .05, .1, -.12, -.12, 0], b), lean=at([0, -.08, -.2, .5, .52, 0], b), down=at([0, -.01, -.03, .32, .33, 0], b), forward=at([0, -.01, -.03, .12, .12, 0], b),
        nod=at([0, -.04, -.1, .3, .3, 0], a))
    wrist = at([HOME['l'], V(.42, -.3, 1.3), V(.3, -.14, 1.8), V(.25, -.5, .64), V(.25, -.5, .6), HOME['l']], a)
    q = quat_at([HOME_Q['l'], L(V(0, -.7, -.7), V(.1, -.7, .7)), L(V(.1, -.95, -.15), V(.1, -.2, 1)), L(V(0, -.35, -1), V(0, -1, -.35)), L(V(0, -.35, -1), V(0, -1, -.35)), HOME_Q['l']], a)
    pole = at([POLE['l'], V(.95, .1, 1.1), V(.85, .15, 1.5), V(.7, -.15, .85), V(.7, -.15, .85), POLE['l']], a)
    left(wrist, q, pole, open=curve([(0, 0), (.25, 1), (.84, 1), (1, 0)], t))
    staff(at([HOME['r'], V(-.38, -.22, 1.38), V(-.36, -.14, 1.62), V(-.52, -.32, 1.06), V(-.52, -.32, 1.04), HOME['r']], a), turn=at([0, .05, .1, -.1, -.1, 0], b),
        pole=at([POLE['r'], V(-1.0, .1, 1.1), V(-.95, .2, 1.4), V(-1.0, -.1, .9), V(-1.0, -.1, .9), POLE['r']], a), pitch=at([0, -.1, -.25, .1, .1, 0], a))
    toes = .22*at([0, .3, 1, 0, 0, 0], a)
    feet(left={'heel': toes}, right={'heel': toes+.3*at([0, 0, 0, 1, 1, 0], b)})

def self_(t):
    # The burst. Both arms drawn in to the chest, the head bowed over them,
    # the body sunk a little as it gathers; then both flung out wide and up
    # as the chest opens and the head comes back, the staff fist out to his
    # right at shoulder height; the open pose held a beat; and back.
    # (The states: the stance, drawn in, half out, out, held, the stance.)
    T = [(0, 0), (.3, 1), (.36, 1.04, 'out'), (.44, 2, 'in'), (.5, 3, 'out'), (.62, 4, 'out'), (1, 5)]
    a = curve(T, t)
    b = curve(T, lead(t, .03))
    body(lean=at([0, .2, -.12, -.36, -.38, 0], b), down=at([0, .08, .03, -.02, -.02, 0], b), forward=at([0, -.03, .01, .06, .06, 0], b), nod=at([0, .42, -.05, -.45, -.5, 0], a))
    wrist = at([HOME['l'], V(.13, -.2, 1.3), V(.4, -.3, 1.42), V(.6, -.18, 1.5), V(.6, -.18, 1.5), HOME['l']], a)
    q = quat_at([HOME_Q['l'], L(V(-.4, .85, .3), V(-.9, -.3, .3)), L(V(-.75, -.1, -.65), V(.1, -.6, .8)), L(V(.5, -.85, .15), V(.85, .5, .15)), L(V(.5, -.85, .15), V(.85, .5, .15)),
        HOME_Q['l']], a)
    pole = at([POLE['l'], V(.6, .15, 1.0), V(.6, .1, .9), V(.5, .2, .9), V(.5, .2, .9), POLE['l']], a)
    left(wrist, q, pole, open=curve([(0, 0), (.3, .5), (.5, 1), (.84, 1), (1, 0)], t))
    q_r = quat_at([HOME_Q['r'], HOME_Q['r'], R(V(.4, .4, -.8), V(-.6, -.6, -.5)), R(V(.4, .5, -.75), V(-.9, -.15, -.4)), R(V(.4, .5, -.75), V(-.9, -.15, -.4)), HOME_Q['r']], a)
    staff(at([HOME['r'], V(-.27, -.13, 1.3), V(-.42, -.2, 1.36), V(-.58, -.1, 1.42), V(-.58, -.1, 1.42), HOME['r']], a),
        pole=at([POLE['r'], V(-.7, .2, 1.0), V(-.6, .25, .95), V(-.5, .25, .95), V(-.5, .25, .95), POLE['r']], a), q=q_r)
    toes = .2*bump(t, .4, .76)
    feet(left={'heel': toes}, right={'heel': toes})

def channel(t):
    # The channel. The left arm straight out at the target, palm forward and
    # fingers spread; the staff fist in close against the body; the body
    # braced back against the stream, the weight sat on the rear foot; the
    # arm trembling very slightly with the effort, the head steady on the
    # target; a slow breath through it. (Every term is periodic in the clip,
    # so its last frame is its first.)
    w = 2*math.pi*t
    breath = math.sin(w)
    tremble = V(.006*math.sin(4*w)+.004*math.sin(7*w+1), .004*math.sin(5*w+2), .006*math.sin(6*w)+.003*math.sin(9*w+1))
    body(turn=-.4, lean=-.08+.012*breath, tilt=-.04, down=.06-.006*breath, forward=-.08, nod=.08-.01*breath)
    left(V(.12, -.48, 1.36)+tremble, L(V(.15, -.9, -.3), V(.3, -.3, .9)), V(.65, -.2, .95), open=1.0)
    staff(V(-.3, -.04, 1.1)+tremble*.4, turn=-.3)
    feet(left={}, right={})

POSES = [('CastBolt', bolt, {}), ('CastPoint', point, {}), ('CastGround', ground, {}), ('CastSelf', self_, {}), ('CastChannel', channel, {'loop': True})]
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
print('WIZARD_ANIMATIONS_READY', len(rig.animation_data.nla_tracks), 'clips (were', len(BEGAN), ')')
