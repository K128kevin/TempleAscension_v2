"""An arm bent to a weapon in its fist as a man's is, shared by
tools/import_skills.py and tools/import_heavy.py.

The fist is set outright on the weapon (the weapon's length along the
hand's own Z, the fingers along its Y); the arm is bent to the fist by
two-bone IK with each bone rolled to the elbow's hinge; and then, since a
fist turned about the weapon can only be carried by the forearm's own turn
(it turns some 80 degrees either way from the thumb-forward middle, where
the weapon lies in the plane the elbow bends in), the elbow is swung round
the arm's line from where it was asked to the nearest place that leaves the
fist turned no further than that. The wrist is bent no further than a wrist
bends: the weapon is tipped back toward square across the forearm where it
would bend the wrist sideways past DEVIATION, and the fingers are laid no
further round the weapon from the forearm's line than FLEX. Last, the
forearm is rolled after the fist (as far as a forearm rolls) so the wrist
is not wrung.

  init(rig)                        once the stance is set (the hinges' sense)
  fist(B, side, wrist_of, along, fingers, pole, swing)
                                   the arm and the fist set; see below
  twist(B, side)                   the fist's turn from the forearm (radians)
"""
import math, os
import bpy
from mathutils import Vector, Matrix, Quaternion

FLEX = math.radians(55)
DEVIATION = math.radians(45)
# The forearm's own turn, either way, from the middle; and how far from the
# middle a fist may be turned (the wrist carries the rest).
FOREARM_ROLL = math.radians(50)
TURN_MAX = math.radians(85)
HINGE = {}

def V(x, y, z):
    return Vector((x, y, z))

def update():
    bpy.context.view_layer.update()

def set_world(bone, position, rotation):
    bone.matrix = Matrix.Translation(position) @ rotation.to_matrix().to_4x4()
    update()

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

def bend_axis(B, side):
    upper, lower, hand = (B[n+side].matrix.translation for n in ('upperarm_', 'lowerarm_', 'hand_'))
    return (lower-upper).cross(hand-lower).normalized()

def init(rig):
    """Which way along its X each elbow's hinge runs, as the stance has them."""
    B = rig.pose.bones
    for s in 'lr':
        HINGE[s] = 1.0 if bend_axis(B, s).dot(B['lowerarm_'+s].matrix.to_quaternion() @ V(1, 0, 0)) > 0 else -1.0

def arm(B, side, target, pole):
    """An arm bent to `target`, the elbow toward `pole`; each of its bones is
    left turned about its length as the elbow's hinge has it (the hinge lies
    along the bones' own X), however far it has been swung round."""
    upper, lower = B['upperarm_'+side], B['lowerarm_'+side]
    reached = two_bone(upper, lower, B['hand_'+side], target, pole)
    hinge = bend_axis(B, side)*HINGE[side]
    fore = lower.matrix.copy()
    for bone in (upper, lower):
        m = fore if bone == lower else bone.matrix.copy()
        q = m.to_quaternion()
        along, x = q @ V(0, 1, 0), q @ V(1, 0, 0)
        want = (hinge-along*hinge.dot(along)).normalized()
        set_world(bone, m.translation, Quaternion(along, math.atan2(x.cross(want).dot(along), x.dot(want))) @ q)
    return reached

def turn_hand(B, side, x, y, z):
    hand = B['hand_'+side]
    set_world(hand, hand.matrix.translation, Matrix((x, y, z)).transposed().to_quaternion())

# The palm's side along each hand's own X (the fingers curl that way), and
# the fist's turn at which the thumb (along +Z in both) points at the elbow's
# pit: the forearm's middle, from which it turns some 80 degrees either way.
PALM_SIDE = {'r': -1.0, 'l': 1.0}
NEUTRAL = {'r': -math.pi/2, 'l': math.pi/2}

def twist(B, side):
    """The fist's turn about the forearm's length from the forearm's middle
    (radians; at none the thumb points at the elbow's pit, at a right angle
    either way the palm faces the pit or the point of the elbow)."""
    upper, lower, hand = (B[n+side].matrix for n in ('upperarm_', 'lowerarm_', 'hand_'))
    along = (lower.to_quaternion() @ V(0, 1, 0)).normalized()
    pit = (upper.translation+hand.translation)/2-lower.translation
    pit = pit-along*pit.dot(along)
    if pit.length < 1e-6: pit = lower.to_quaternion() @ V(0, 0, 1)
    pit.normalize()
    palm = hand.to_quaternion() @ V(PALM_SIDE[side], 0, 0)
    palm = (palm-along*palm.dot(along)).normalized()
    turn = math.atan2(pit.cross(palm).dot(along), pit.dot(palm))-NEUTRAL[side]
    return (turn+math.pi) % (2*math.pi)-math.pi

def untwist(B, side):
    """The forearm rolled after the fist, as far as a forearm rolls (and not
    at all after a fist turned right round); the fist left where it is.
    Returns the fist's turn (radians)."""
    hand, fore = B['hand_'+side], B['lowerarm_'+side]
    hm, fm = hand.matrix.copy(), fore.matrix.copy()
    turned = twist(B, side)
    qf = fm.to_quaternion()
    set_world(fore, fm.translation, Quaternion(qf @ V(0, 1, 0), FOREARM_ROLL*math.sin(turned)) @ qf)
    set_world(hand, hm.translation, hm.to_quaternion())
    return turned

def fist(B, side, wrist_of, along, fingers, pole, swing=math.radians(150), steps=12, hold=1.0, deviation=True, avoid=None):
    """The arm and the fist set on a weapon running along `along` (world)
    through the fist, whose wrist is at `wrist_of(y)` (the fingers' way `y`
    given, since the weapon's seat lies off the wrist); the fingers laid as
    near `fingers` as the wrist allows (or, none given, along the forearm);
    the elbow toward `pole` (world), or swung round the arm's line up to
    `swing` either way from it to where the forearm need not be wrung (and,
    `avoid` given, a way the elbow's point is kept from: the chest's front,
    where an elbow reads as bent the wrong way).
    Returns (y, z, turn): the fingers' and the weapon's ways as set and the
    fist's turn from the forearm (radians)."""
    shoulder = B['upperarm_'+side].matrix.translation.copy()
    z = Vector(along).normalized()
    def across(v):
        v = Vector(v)
        v = v-z*v.dot(z)
        return v.normalized() if v.length > 1e-4 else z.orthogonal().normalized()
    y = across(fingers) if fingers is not None else across(Vector(wrist_of(z.orthogonal().normalized()))-shoulder)
    arm(B, side, wrist_of(y), pole)
    def fore():
        return (B['hand_'+side].matrix.translation-B['lowerarm_'+side].matrix.translation).normalized()
    def square(z, y):
        # The weapon kept near enough to square across the forearm (a wrist
        # bends only so far sideways): tipped about the fist back toward square.
        f = fore()
        lean = f.angle(z)-math.pi/2
        if deviation and abs(lean) > DEVIATION:
            axis = f.cross(z)
            if axis.length > 1e-4:
                z = (Quaternion(axis.normalized(), -(lean-math.copysign(DEVIATION, lean))) @ z).normalized()
                y = across(y)
        return z, y
    def lay(f):
        # (The fingers along the forearm's line, or turned about the weapon
        # toward `fingers` as far as a wrist bends.)
        base = across(f)
        if fingers is None: return base
        want = across(fingers)
        off = math.atan2(base.cross(want).dot(z), base.dot(want))
        return (Quaternion(z, hold*max(-FLEX, min(FLEX, off))) @ base).normalized()
    p = Vector(pole)
    if swing <= 0: steps = 0
    for pass_ in range(2):
        z, y = square(z, y)
        axis = (Vector(wrist_of(y))-shoulder).normalized()
        best = None
        tried = []
        for k in range(-steps, steps+1):
            angle = swing*k/steps if steps else 0.0
            q = shoulder+Quaternion(axis, angle) @ (Vector(pole)-shoulder)
            for i in range(2):
                arm(B, side, wrist_of(y), q)
                y = lay(fore())
            turn_hand(B, side, y.cross(z), y, z)
            turned = twist(B, side)
            tried.append((angle, turned))
            cost = (max(0.0, abs(turned)-math.radians(45))/TURN_MAX)**2*6+((angle/swing)**2 if swing > 0 else 0.0)
            if avoid is not None:
                point = B['lowerarm_'+side].matrix.translation-(B['upperarm_'+side].matrix.translation+B['hand_'+side].matrix.translation)/2
                if point.length > .01: cost += 3*max(0.0, point.normalized().dot(Vector(avoid)))**2
                # (Nor swung in against the chest: the elbow kept a span from
                # the spine's line, or the forearm would cross the chest.)
                a, b = B['spine_02'].matrix.translation, B['neck_01'].matrix.translation
                d = b-a
                e = B['lowerarm_'+side].matrix.translation
                near = a+d*max(0.0, min(1.0, (e-a).dot(d)/max(1e-9, d.dot(d))))
                cost += 4*max(0.0, (.22-(e-near).length)/.22)**2
            if best is None or cost < best[0]: best = (cost, angle, q, y, turned)
        _, angle, p, y, turned = best
        for i in range(2):
            arm(B, side, wrist_of(y), p)
            y = lay(fore())
        turn_hand(B, side, y.cross(z), y, z)
        if os.environ.get('FIST_DEBUG') and abs(turned) > math.radians(85):
            print('FIST_DEBUG', side, 'best swing %.0f' % math.degrees(angle), ' '.join('%.0f:%.0f' % (math.degrees(a), math.degrees(t)) for a, t in tried))
    # (The elbow where it is, the weapon is squared to the forearm once more.)
    z, y = square(z, y)
    for i in range(2):
        arm(B, side, wrist_of(y), p)
        y = lay(fore())
    turn_hand(B, side, y.cross(z), y, z)
    return y, z, untwist(B, side)
