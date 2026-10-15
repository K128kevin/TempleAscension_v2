"""Rebuilds the legacy night sky: assets/textures/night_sky.png.
The outdoor world now uses the generated desert_sky_only.png image;
see docs/OPENING_SKY.md for its prompts and placement. This generator is
retained for the old asset and does not overwrite the active opening sky.

A deep blue-black that pales a little toward the horizon; a few thousand
stars of every size and brightness, a few of them tinted blue or warm, with
the band of the Milky Way crossing the sky; and a gibbous moon low in the
north-north-east, cratered and marked with its seas, with a soft halo. North
is the middle of the picture (the panorama's -Z).

  python3 tools/make_night_sky.py
"""
from pathlib import Path
import struct
import zlib
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/textures/night_sky.png'
W, H = 2048, 1024
rng = np.random.default_rng(7)

# --- The sky itself: dark, bluer and a touch paler toward the horizon.
v = np.linspace(0.0, 1.0, H)[:, None]
u = np.linspace(0.0, 1.0, W)[None, :]
elevation = (0.5-v)*180.0  # degrees above the horizon
horizon = np.clip(1.0-np.abs(elevation)/14.0, 0.0, 1.0)**2
img = np.zeros((H, W, 3), dtype=np.float32)
img[..., 0] = 0.016+0.02*horizon
img[..., 1] = 0.022+0.028*horizon
img[..., 2] = 0.05+0.05*horizon
# Below the horizon the ground hides it: left dark.
img[elevation[:, 0] < -2.0] *= 0.6


def value_noise(h, w, cells, seed):
    """Smooth noise across (h, w) from a cells-by-cells grid of random values."""
    g = np.random.default_rng(seed).random((cells+1, cells*2+1))
    ys = np.linspace(0, cells, h)
    xs = np.linspace(0, cells*2, w)
    y0 = np.floor(ys).astype(int); x0 = np.floor(xs).astype(int)
    fy = (ys-y0)[:, None]; fx = (xs-x0)[None, :]
    fy = fy*fy*(3-2*fy); fx = fx*fx*(3-2*fx)
    y1 = np.minimum(y0+1, cells); x1 = np.minimum(x0+1, cells*2)
    a = g[y0][:, x0]; b = g[y0][:, x1]; c = g[y1][:, x0]; d = g[y1][:, x1]
    return (a*(1-fx)+b*fx)*(1-fy)+(c*(1-fx)+d*fx)*fy


# --- The Milky Way: a band tilted across the sky, its light a mottled haze.
band_centre = 0.3+0.15*np.sin((u-0.15)*2*np.pi)  # v of the band's middle along u
band = np.exp(-((v-band_centre)/0.055)**2)
haze = value_noise(H, W, 12, 3)*0.6+value_noise(H, W, 40, 5)*0.4
milky = band*np.clip(haze-0.3, 0.0, 1.0)*0.8
img[..., 0] += milky*0.16
img[..., 1] += milky*0.17
img[..., 2] += milky*0.22
# (Dust lanes: darker threads through it.)
lanes = np.clip(value_noise(H, W, 60, 9)-0.62, 0.0, 1.0)*band*2.0
img -= lanes[..., None]*np.array([0.05, 0.05, 0.06], dtype=np.float32)

# --- The stars.
def star(cx, cy, radius, brightness, colour):
    r = int(np.ceil(radius*3))+1
    y0, y1 = max(0, cy-r), min(H, cy+r+1)
    x0, x1 = max(0, cx-r), min(W, cx+r+1)
    if y0 >= y1 or x0 >= x1: return
    yy, xx = np.mgrid[y0:y1, x0:x1]
    d2 = (yy-cy)**2+(xx-cx)**2
    glow = np.exp(-d2/(2*radius*radius))*brightness
    img[y0:y1, x0:x1] += glow[..., None]*np.array(colour, dtype=np.float32)

count = 5600
for i in range(count):
    # (More of them along the Milky Way; none below the horizon, and those
    # near it dimmed by the air.)
    if rng.random() < 0.45:
        cx = int(rng.random()*W)
        cy = int((band_centre[0, cx]+rng.normal(0, 0.05))*H)
    else:
        cx = int(rng.random()*W); cy = int(rng.random()*H*0.5)
    if cy < 0 or cy >= int(H*0.495): continue
    size = rng.random()
    radius = 0.55+size**6*2.2
    brightness = (0.25+size**3*1.3)*min(1.0, (0.5-cy/H)*180.0/12.0+0.15)
    tint = rng.random()
    colour = (0.85, 0.9, 1.0) if tint < 0.25 else ((1.0, 0.92, 0.8) if tint < 0.4 else (1.0, 1.0, 1.0))
    star(cx, cy, radius, brightness, colour)

# --- The moon: low in the north-north-east, gibbous, lit from its upper right.
MOON_U, MOON_EL, MOON_RADIUS_DEG = 0.5+18.0/360.0, 9.0, 4.0
mx = int(MOON_U*W); my = int((0.5-MOON_EL/180.0)*H)
mr = MOON_RADIUS_DEG/360.0*W
yy, xx = np.mgrid[0:H, 0:W]
d = np.sqrt((yy-my)**2+(xx-mx)**2)/mr
halo = np.exp(-np.clip(d-1.0, 0.0, None)*0.8)*0.3*(d > 1.0)
img += halo[..., None]*np.array([0.55, 0.62, 0.8], dtype=np.float32)
disc = d <= 1.0
# Seas: broad darker patches; craters: small rings; a soft terminator on
# the lower left, past the gibbous edge.
seas = value_noise(H, W, 300, 11)
sea_dark = np.clip(seas-0.52, 0.0, 1.0)*1.6
craters = value_noise(H, W, 900, 13)
crater_dark = np.clip(craters-0.7, 0.0, 1.0)*1.2
nx = (xx-mx)/mr; ny = (yy-my)/mr
lit = np.clip(0.55+0.45*(0.75*nx-0.45*ny), 0.0, 1.0)
limb = np.sqrt(np.clip(1.0-d*d, 0.0, 1.0))
shade = (0.78-0.4*sea_dark-0.3*crater_dark)*lit*(0.55+0.45*limb)
moon = np.stack([shade*0.98, shade*0.96, shade*0.9], axis=-1)
img[disc] = moon[disc]+np.array([0.02, 0.02, 0.03], dtype=np.float32)

# --- Written.
pixels = np.clip(img, 0.0, 1.0)
data = (pixels*255.0+0.5).astype(np.uint8)
raw = b''.join(b'\x00'+data[y].tobytes() for y in range(H))
def chunk(kind, body):
    return struct.pack('>I', len(body))+kind+body+struct.pack('>I', zlib.crc32(kind+body) & 0xffffffff)
png = b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0))+chunk(b'IDAT', zlib.compress(raw, 9))+chunk(b'IEND', b'')
OUT.write_bytes(png)
print('SKY_READY', OUT, W, H)
