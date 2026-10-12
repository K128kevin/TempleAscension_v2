"""Paints the gold embroidery on the back of the Robe of the Lost Emperor:
assets/textures/emperor_dragon.png, read by assets/shaders/cloak.gdshader
(`dragon_map`) on a gilded robe.

A long, wingless eastern dragon worked in couched gold thread: its head in
profile on the upper back, jaws parted (nothing comes out of them), a
curling nose, a brow over a sunken eye, branched horns and a mane of flame
swept back; long whiskers trailing from the lip; its scaled body winding
in an S down the back under the sash to a flame-tufted tail near the hem,
belly plates on its under side and a saw-toothed crest on its back; four
short legs, each with flame wisps at the elbow and four hooked talons; and
three scrolling clouds about it. Every element is laid in rows of gold
thread that follow its form (round each scale, across the belly plates,
along the whiskers and talons) and edged in a twisted gold cord, with a
hair of black cloth left between elements that overlap.

The picture is the robe unrolled about the body: x is metres round it from
the middle of the back (+x to the right as the back is seen), y metres up
from the ground in the rest pose; it spans U0..U1 and V0..V1. Channels:
R how much gold covers the cloth, G the thread's height (its relief: the
shader takes its normals from it), B the thread's tone (the shade down
between scales and plates, brighter cord), A unused (opaque).

  python3 tools/paint_dragon.py [--preview]

--preview also writes test-results/emperor_dragon_preview.png, the gold lit
on black, to look at.
"""
from pathlib import Path
import math
import sys
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/textures/emperor_dragon.png'
# The span of the picture on the unrolled robe (metres), kept in step with
# the shader's DRAGON_SPAN.
U0, U1, V0, V1 = -.32, .32, .12, 1.48
W, H = 1024, 2176
PX = (U1-U0)/W
# The gold thread's width (px): about 1.9 mm.
PITCH = 3.0

rng = np.random.default_rng(7)
cover = np.zeros((H, W), np.float32)
height = np.zeros((H, W), np.float32)
tone = np.zeros((H, W), np.float32)
YY, XX = np.mgrid[0:H, 0:W].astype(np.float32)


def px(u, v):
    return np.array([(u-U0)/PX, (V1-v)/PX], np.float32)


def thread(phase):
    """A row of laid threads across `phase` (one thread a unit): each a
    rounded cord, 1 on its crown and 0 in the groove between."""
    f = phase-np.floor(phase)
    return np.sqrt(np.clip(1.0-(2.0*f-1.0)**2, 0.0, 1.0))


def spline(points, widths, step=.5):
    """A Catmull-Rom curve through `points` (metres), resampled every `step`
    px, with the half-widths (metres) given at the points eased along it:
    the samples' places, arc lengths, unit tangents and half-widths (px)."""
    P = np.array([px(*p) for p in points])
    Wd = np.array(widths, np.float32)/PX
    P = np.vstack([2*P[0]-P[1], P, 2*P[-1]-P[-2]])
    out, ws = [], []
    for i in range(1, len(P)-2):
        p0, p1, p2, p3 = P[i-1], P[i], P[i+1], P[i+2]
        n = max(2, int(np.linalg.norm(p2-p1)/step*1.3))
        t = np.linspace(0, 1, n, endpoint=False)[:, None]
        seg = .5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t**2+(-p0+3*p1-3*p2+p3)*t**3)
        out.append(seg)
        w0, w1 = Wd[i-1], Wd[i]
        e = t[:, 0]*t[:, 0]*(3-2*t[:, 0])
        ws.append(w0+(w1-w0)*e)
    out.append(P[-2][None])
    ws.append(Wd[-1:])
    Q = np.vstack(out)
    Wq = np.concatenate(ws)
    d = np.linalg.norm(np.diff(Q, axis=0), axis=1)
    S = np.concatenate([[0], np.cumsum(d)])
    # Evenly spaced along its length.
    even = np.arange(0, S[-1], step)
    Q = np.stack([np.interp(even, S, Q[:, 0]), np.interp(even, S, Q[:, 1])], 1)
    Wq = np.interp(even, S, Wq)
    T = np.gradient(Q, axis=0)
    T /= np.maximum(np.linalg.norm(T, axis=1, keepdims=True), 1e-6)
    return Q.astype(np.float32), even.astype(np.float32), T.astype(np.float32), Wq.astype(np.float32)


class Shape:
    """A swept shape: discs of the curve's half-width along it. For every
    px near it: `f` the signed distance to its edge (px, negative inside),
    `s` the arc length of the nearest place on the curve, `t` how far to
    its left (px), `w` its half-width there."""

    def __init__(self, points, widths, margin=8.0):
        Q, S, T, Wq = spline(points, widths)
        x0 = int(max(0, np.floor((Q[:, 0]-Wq).min()-margin)))
        x1 = int(min(W, np.ceil((Q[:, 0]+Wq).max()+margin)))
        y0 = int(max(0, np.floor((Q[:, 1]-Wq).min()-margin)))
        y1 = int(min(H, np.ceil((Q[:, 1]+Wq).max()+margin)))
        self.box = (slice(y0, y1), slice(x0, x1))
        gy, gx = YY[self.box], XX[self.box]
        f = np.full(gx.shape, 1e9, np.float32)
        idx = np.zeros(gx.shape, np.int32)
        for i in range(len(Q)):
            r = Wq[i]+margin
            a0, a1 = int(max(y0, Q[i, 1]-r)), int(min(y1, Q[i, 1]+r+1))
            b0, b1 = int(max(x0, Q[i, 0]-r)), int(min(x1, Q[i, 0]+r+1))
            if a0 >= a1 or b0 >= b1: continue
            sub = (slice(a0-y0, a1-y0), slice(b0-x0, b1-x0))
            d = np.hypot(gx[sub]-Q[i, 0], gy[sub]-Q[i, 1])-Wq[i]
            better = d < f[sub]
            f[sub] = np.where(better, d, f[sub])
            idx[sub] = np.where(better, i, idx[sub])
        self.f = f
        self.s = S[idx]
        dx, dy = gx-Q[idx, 0], gy-Q[idx, 1]
        # (Left of the way it runs, as the picture is seen: y runs down.)
        self.t = T[idx, 0]*dy-T[idx, 1]*dx
        self.w = Wq[idx]
        # How many of its own widths along it each place is (for patterns
        # that keep their shape as it tapers: scales, plates, spines).
        self.widths = np.concatenate([[0], np.cumsum(np.diff(S)/np.maximum(Wq[1:], 9.0))])[idx]
        self.length = S[-1]
        self.tangent = T[idx]

    def inside(self, grow=0.0):
        return np.clip(.5-(self.f-grow), 0.0, 1.0)


def lay(shape, c, h, b, gap=1.4, cord=1.6):
    """Lays an element over what is already stitched: `c` its cover, `h`
    its threads' height, `b` their tone (arrays on the shape's box). What
    lies under it is cut back a hair (`gap` px) round its edge, so the two
    read apart, and its own edge is a twisted gold cord `cord` px wide."""
    box = shape.box
    if cord > 0:
        band = np.clip(1.0-(-shape.f)/cord, 0.0, 1.0)*(shape.f < 0.5)
        twist = thread((shape.s+shape.t*.8)/2.2)
        h = np.where(band > 0, np.maximum(h*(1-band), .55+.45*twist), h)
        b = np.where(band > 0, np.maximum(b*(1-band), .82+.18*twist), b)
    carve = np.clip(shape.f/gap, 0.0, 1.0)
    old_c, old_h, old_b = cover[box], height[box], tone[box]
    old_c = old_c*carve
    cover[box] = old_c*(1-c)+c
    height[box] = old_h*(1-c)+h*c
    tone[box] = old_b*(1-c)+b*c


def along(shape, wobble=0.0):
    """Threads laid along a shape (a whisker, a talon, a wisp of flame)."""
    var = 1.0+wobble*np.sin(shape.s*.05)
    return thread(shape.t/PITCH*var)


def across(shape):
    """Threads laid across it (its rows run side to side)."""
    return thread(shape.s/PITCH)


def stroke(points, widths, pattern="along", tone_base=.8, gap=1.4, cord=1.2):
    s = Shape(points, widths)
    c = s.inside()
    h = along(s) if pattern == "along" else across(s)
    b = tone_base*(.92+.08*h)
    # Shaded a little toward its edges, as a padded stitch rounds off.
    edge = np.clip(-s.f/np.maximum(s.w, 1.0), 0.0, 1.0)
    b = b*(.7+.3*np.sqrt(edge))
    lay(s, c, h, b, gap, cord)
    return s


def flame(root, direction, length, width, curl=.6, n=3, spread=.5, gap=1.2):
    """A tuft of flame: `n` tapering, curling wisps from `root` (metres),
    fanned about `direction` (radians, 0 to the right, up positive)."""
    for k in range(n):
        a = direction+(k-(n-1)/2)*spread/max(1, n-1)
        L = length*(1.0-.25*abs(k-(n-1)/2))
        pts, ws = [], []
        for j in range(6):
            q = j/5
            ang = a+curl*q*q*(1 if k % 2 == 0 else -.6)
            if j == 0: x, y = root
            else:
                x += math.cos(ang)*L/5; y += math.sin(ang)*L/5
            pts.append((x, y)); ws.append(width*(1-q)**.8+.0006)
        stroke(pts, ws, "along", .82, gap)


def scales(shape, rows_per_width=.75, across_n=4.0):
    """The scales of a body or limb: rows of rounded scales, each lying over
    the next toward the tail, staggered; their thread laid round them."""
    w = np.maximum(shape.w, 9.0)
    # (Row length eased to the width, so smaller scales down a tapering tail.)
    r = shape.widths/(2.0/across_n*rows_per_width*1.6)
    cpos = (shape.t/w+1.0)*.5*across_n
    owner_e = np.full(r.shape, 9.0, np.float32)
    shadow = np.zeros(r.shape, np.float32)
    best_row = np.full(r.shape, 1e9, np.float32)
    # The scale of the most forward row whose disc holds the px is the one
    # seen; just behind its free edge the next one lies in its shadow.
    for di in (-1, 0):
        i = np.floor(r)+di
        stagger = .5*np.mod(i, 2)
        for dj in (-1, 0, 1):
            j = np.floor(cpos-stagger)+dj+.5+stagger
            e = np.sqrt(((r-i)/1.35)**2+((cpos-j)/.66)**2)
            e = np.where(r >= i, e, 9.0)
            take = (e < 1.0) & (i < best_row)
            owner_e = np.where(take, e, owner_e)
            best_row = np.where(take, i, best_row)
    for dj in (-1, 0, 1):
        i = best_row-1
        stagger = .5*np.mod(i, 2)
        j = np.floor(cpos-stagger)+dj+.5+stagger
        e = np.sqrt(((r-i)/1.35)**2+((cpos-j)/.66)**2)
        shadow = np.maximum(shadow, 1.0-np.clip((e-1.0)/.3, 0.0, 1.0))
    owner_e = np.where(owner_e > 1.5, 1.0, owner_e)
    # Couched round: rings toward the scale's free edge, a raised rim on it.
    scale_px = w*2.0/across_n
    rings = thread(owner_e*scale_px*.66/PITCH)
    rim = np.clip(1.0-np.abs(owner_e-.93)/.07, 0.0, 1.0)
    h = np.maximum(rings*.8, rim)
    b = (.62+.38*owner_e**1.5)*(1.0-.5*shadow)+.15*rim
    return h, np.clip(b, 0.0, 1.1)


def body(points, widths, belly_side=-1, crest=True):
    s = Shape(points, widths, margin=14.0)
    c = s.inside()
    h, b = scales(s)
    a = s.t/np.maximum(s.w, 1.0)
    # The belly: plates across its under side, each a bar of laid thread.
    belly = np.clip((a*belly_side-.38)/.08, 0.0, 1.0)
    plate = s.widths/.55
    seam = np.abs(plate-np.round(plate))
    plate_h = thread(s.s/PITCH*.9)*.8*np.clip(seam/.12, 0.0, 1.0)
    plate_b = (.95-.4*np.clip(1.0-seam/.12, 0.0, 1.0))*(.9+.1*np.abs(a))
    h = h*(1-belly)+plate_h*belly
    b = b*(1-belly)+plate_b*belly
    # A thin line of cord between the scales and the belly.
    line = np.clip(1.0-np.abs(a*belly_side-.38)*np.maximum(s.w, 1.0)/1.2, 0.0, 1.0)
    h = np.maximum(h, line*.9)
    b = np.maximum(b, line)
    if crest:
        # The crest: a saw of short spines along its back, sloped tailward.
        tooth = s.widths/.7
        ph = tooth-np.floor(tooth)
        spine_h = np.maximum(s.w*.55, 5.0)*(1.0-ph)
        out = (s.t*-belly_side > 0) & (s.f >= -1.0)
        spine = np.clip(.5-(s.f-spine_h), 0.0, 1.0)*out
        c = np.maximum(c, spine)
        sh = thread((s.f+s.s*.3)/PITCH)*.8
        h = np.where(out & (s.f > 0), sh, h)
        b = np.where(out & (s.f > 0), .75+.15*sh, b)
    lay(s, c, h, b, gap=1.6, cord=1.8)
    return s


def limb(points, widths, claws_at, claw_dir, claw_len=.022, wisps=None):
    """A leg: scaled, from the body to the wrist; flame at the elbow; four
    hooked talons splayed from the wrist (`claw_dir` radians, as flame)."""
    if wisps: flame(*wisps)
    s = Shape(points, widths)
    c = s.inside()
    h, b = scales(s, across_n=3.0)
    lay(s, c, h, b, gap=1.6, cord=1.6)
    for k in range(4):
        a = claw_dir+(k-1.5)*.42
        x, y = claws_at
        pts, ws = [(x, y)], [.0042]
        for j in range(1, 6):
            q = j/5
            # Each talon curls over toward its tip, as a raptor's does.
            ang = a-1.1*q*q
            L = claw_len*(.85 if k in (0, 3) else 1.0)
            x += math.cos(ang)*L/5; y += math.sin(ang)*L/5
            pts.append((x, y)); ws.append(.0042*(1-q)**.9+.0004)
        stroke(pts, ws, "along", .95, gap=1.3, cord=.9)


def scroll(cx, cy, r, turns, hand, width):
    """One curl of cloud: a spiral of cord wound inward."""
    pts, ws = [], []
    n = int(30*turns)
    for j in range(n):
        q = j/(n-1)
        th = hand*(math.pi*.5+q*turns*2*math.pi)
        rr = r*(1-q*.82)
        pts.append((cx+rr*math.cos(th), cy+rr*math.sin(th))); ws.append(width*(1-.55*q))
    stroke(pts, ws, "along", .88)


def cloud(center, size, flip=1):
    """An auspicious cloud: a large scroll between two small ones on a
    bank of cloud, and a long tail streaming off one side."""
    cx, cy = center
    # The bank: a lobed outline under the scrolls.
    bank = [(cx-flip*size*1.25, cy-size*.05), (cx-flip*size*.9, cy-size*.42), (cx-flip*size*.3, cy-size*.52), (cx+flip*size*.3, cy-size*.5), (cx+flip*size*.9, cy-size*.38), (cx+flip*size*1.25, cy-size*.02)]
    stroke(bank, [.0032, .0042, .0046, .0046, .0042, .003], "along", .84)
    tail = [(cx+flip*size*1.2, cy-size*.15), (cx+flip*size*1.8, cy-size*.35), (cx+flip*size*2.5, cy-size*.2), (cx+flip*size*3.1, cy-size*.45), (cx+flip*size*3.6, cy-size*.4)]
    stroke(tail, [.0042, .0036, .0028, .0016, .0005], "along", .82)
    scroll(cx, cy+size*.12, size*.5, 2.2, flip, .0052)
    scroll(cx-flip*size*.85, cy-size*.06, size*.3, 1.8, -flip, .0038)
    scroll(cx+flip*size*.85, cy-size*.04, size*.3, 1.8, flip, .0038)


def eye(center, r):
    """The eye: a dark hollow under the brow, a gold ring and a slit pupil."""
    cx, cy = px(*center)
    d = np.hypot((XX-cx)/1.25, YY-cy)-r/PX
    hole = np.clip(.5-d+1.5, 0.0, 1.0)
    for arr in (cover,):
        arr *= 1.0-hole
    ring = np.clip(1.0-np.abs(d+r/PX*.35)/1.6, 0.0, 1.0)
    pupil = np.clip(.5-(np.hypot((XX-cx)/.35, YY-cy)-r/PX*.55), 0.0, 1.0)
    add = np.maximum(ring, pupil)
    cover[:] = np.maximum(cover, add)
    height[:] = np.where(add > 0, np.maximum(height, add), height)
    tone[:] = np.where(add > 0, np.maximum(tone, 1.0*add), tone)


# --- The design --------------------------------------------------------------
# Clouds first: everything else lies over them.
cloud((.125, .80), .05, 1)
cloud((-.15, .47), .045, -1)
cloud((.135, .275), .04, 1)
cloud((-.16, 1.21), .034, -1)

# The far legs, behind the body.
limb([(.03, 1.07), (-.06, 1.12), (-.115, 1.105), (-.13, 1.16)], [.019, .014, .011, .008], (-.13, 1.16), math.radians(105),
     wisps=((-.07, 1.115), math.radians(-35), .05, .009, .9, 3, .6))
limb([(.11, .55), (.17, .575), (.205, .54), (.205, .49)], [.019, .014, .011, .008], (.205, .49), math.radians(-80),
     wisps=((.175, .58), math.radians(55), .05, .009, .8, 3, .6))

# The tail's flame, a fan of it about the tip.
flame((-.07, .25), math.radians(-150), .06, .008, .9, 5, 1.3)

# The body: from behind the head, down the back in an S, to the tail.
spine = [(.04, 1.30), (.10, 1.25), (.115, 1.17), (.065, 1.09), (-.04, 1.03), (-.11, .94), (-.12, .82), (-.06, .72),
         (.06, .66), (.13, .57), (.11, .46), (.02, .39), (-.08, .34), (-.10, .285), (-.075, .25)]
girth = [.024, .028, .031, .034, .036, .036, .035, .033, .031, .028, .024, .019, .014, .009, .004]
body(spine, girth, belly_side=-1)

# The near legs, over the body.
limb([(.10, 1.16), (.15, 1.115), (.185, 1.15), (.18, 1.215)], [.019, .014, .011, .008], (.18, 1.215), math.radians(85),
     wisps=((.15, 1.10), math.radians(-60), .05, .009, -.9, 3, .6))
limb([(-.10, .79), (-.16, .76), (-.19, .70), (-.18, .64)], [.02, .015, .011, .008], (-.18, .64), math.radians(-95),
     wisps=((-.165, .77), math.radians(140), .05, .009, .9, 3, .6))

# The head, in profile to the left, laid out from the back of its skull:
# `x` forward along it, `y` up from it (metres).
HEAD_AT = (.045, 1.315)
HEAD_TURN = math.radians(166)
fw = (math.cos(HEAD_TURN), math.sin(HEAD_TURN))
up = (fw[1], -fw[0])


def hd(x, y):
    return (HEAD_AT[0]+x*fw[0]+y*up[0], HEAD_AT[1]+x*fw[1]+y*up[1])


def hds(points):
    return [hd(*q) for q in points]


def hflame(x, y, angle, *rest):
    """A flame tuft on the head: `angle` in the head's own frame (0 forward,
    pi back)."""
    turn = math.atan2(fw[1], fw[0])
    flame(hd(x, y), turn+angle, *rest)


# The mane: a mass of flame streaming back from the skull and down the neck.
hflame(-.02, .018, math.radians(168), .1, .01, -.8, 4, .8)
hflame(-.025, -.004, math.radians(192), .095, .01, -.7, 4, .7)
hflame(-.05, -.03, math.radians(212), .08, .009, -.8, 3, .6)
hflame(-.085, -.06, math.radians(225), .065, .008, -.8, 3, .55)
# The horns: a stag's, branched, swept back over the mane.
stroke(hds([(.03, .026), (.0, .05), (-.04, .072), (-.085, .08)]), [.0062, .005, .0035, .0006], "across", .92)
stroke(hds([(-.025, .066), (-.03, .09), (-.045, .105)]), [.0035, .0025, .0006], "across", .92)
stroke(hds([(.045, .024), (.025, .055), (-.005, .085), (-.03, .1)]), [.0055, .0045, .003, .0006], "across", .86)
stroke(hds([(.005, .082), (.02, .1), (.022, .112)]), [.003, .002, .0006], "across", .86)
# The cheek: a frill of flame behind the jaw's hinge.
hflame(-.005, -.024, math.radians(208), .065, .0085, .7, 3, .65)
# The lower jaw, dropped open, and the beard: fine strands swept back
# from under the chin (nothing hangs from the mouth).
for k, (x0, y0) in enumerate(((.075, -.05), (.06, -.044), (.045, -.038))):
    stroke(hds([(x0, y0), (x0-.02, y0-.018), (x0-.045, y0-.022), (x0-.065, y0-.035+.004*k)]), [.0022, .0018, .0012, .0004], "along", .95, cord=.7)
stroke(hds([(.022, -.016), (.055, -.03), (.088, -.046), (.105, -.052)]), [.011, .0095, .0075, .0055], "across", .84)
# Fangs: the lower jaw's, turned up into the open mouth.
stroke(hds([(.098, -.046), (.101, -.031)]), [.0032, .0004], "along", 1.0, cord=0)
stroke(hds([(.078, -.038), (.08, -.028)]), [.0024, .0004], "along", 1.0, cord=0)
# The skull and the upper jaw: a high brow-bossed head, a long muzzle.
stroke(hds([(-.012, .006), (.012, .009), (.035, .012), (.055, .012)]), [.013, .019, .02, .018], "across", .86, gap=1.8, cord=1.6)
# Over the back of the skull, the mane's first locks.
hflame(.005, .016, math.radians(175), .05, .0065, -.6, 3, .5)
hflame(.0, -.004, math.radians(190), .045, .006, -.6, 2, .4)
stroke(hds([(.045, .006), (.07, .003), (.095, .001), (.118, .005)]), [.0155, .012, .0102, .0108], "across", .86, gap=1.8, cord=1.6)
# The bridge of the nose: a knotted ridge from the brow to the nose pad.
stroke(hds([(.072, .016), (.085, .0135), (.098, .0125), (.108, .015)]), [.0028, .0034, .0026, .002], "across", .98, cord=.8)
# Its upper lip, rolled up at the front, and the fangs under it.
stroke(hds([(.06, -.009), (.09, -.008), (.12, -.006), (.133, .004), (.131, .016)]), [.0038, .0042, .0042, .0036, .0016], "along", .98, cord=1.0)
stroke(hds([(.112, -.008), (.109, -.027)]), [.0034, .0004], "along", 1.0, cord=0)
stroke(hds([(.09, -.009), (.088, -.021)]), [.0026, .0004], "along", 1.0, cord=0)
stroke(hds([(.07, -.009), (.069, -.017)]), [.0022, .0004], "along", 1.0, cord=0)
# The nose: a round pad on the muzzle's end, its nostril curled in it.
stroke(hds([(.112, .018), (.12, .02)]), [.0095, .009], "across", .92, cord=1.4)
stroke(hds([(.122, .024), (.127, .019), (.122, .013), (.116, .017), (.119, .021)]), [.0024, .0022, .002, .0016, .0008], "along", 1.0, cord=.6)
# The brow: a heavy ridge over the eye, flaring back into flame.
stroke(hds([(.085, .016), (.065, .026), (.04, .03), (.015, .032)]), [.003, .0055, .006, .0035], "across", .97)
hflame(.012, .032, math.radians(165), .04, .0055, -.7, 3, .5)
eye(hd(.055, .014), .0072)
# The whiskers: long, thin and wavering, from the upper lip back over the
# head, and down below the jaw.
stroke(hds([(.118, -.004), (.11, .03), (.09, .06), (.06, .075), (.02, .08), (-.02, .09), (-.05, .11), (-.06, .13)]),
       [.0024, .0022, .002, .0018, .0015, .0012, .0009, .0004], "along", 1.0, cord=.8)
stroke(hds([(.104, -.006), (.1, -.03), (.08, -.06), (.05, -.075), (.02, -.075), (-.01, -.09), (-.02, -.11)]),
       [.0024, .0022, .002, .0017, .0013, .0009, .0004], "along", 1.0, cord=.8)


# --- Out ---------------------------------------------------------------------
cover_u8 = (np.clip(cover, 0, 1)*255+.5).astype(np.uint8)
height_u8 = (np.clip(height, 0, 1)*255+.5).astype(np.uint8)
tone_u8 = (np.clip(tone/1.1, 0, 1)*255+.5).astype(np.uint8)
alpha = np.full_like(cover_u8, 255)
OUT.parent.mkdir(parents=True, exist_ok=True)
Image.fromarray(np.stack([cover_u8, height_u8, tone_u8, alpha], -1), "RGBA").save(OUT, optimize=True)
print("wrote", OUT)

if "--preview" in sys.argv:
    # Lit from the upper left: the thread's relief, its tone, on black wool.
    hgt = height*.6
    gy, gx = np.gradient(hgt)
    n = np.stack([-gx, -gy, np.full_like(gx, .5)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    light = np.array([-.5, -.6, .62]); light /= np.linalg.norm(light)
    lam = np.clip((n*light).sum(-1), 0, 1)
    spec = np.clip(lam, 0, 1)**12
    gold = np.array([.86, .63, .25])
    col = gold[None, None]*(tone[..., None]*(.25+.9*lam[..., None]))+spec[..., None]*.6
    cloth = np.array([.03, .028, .03])
    img = cloth*(1-cover[..., None])+col*cover[..., None]
    out = ROOT/'test-results/emperor_dragon_preview.png'
    out.parent.mkdir(exist_ok=True)
    Image.fromarray((np.clip(img, 0, 1)**(1/1.4)*255).astype(np.uint8)).save(out)
    print("wrote", out)
