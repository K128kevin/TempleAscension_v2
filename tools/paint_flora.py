"""Paints the outdoor world's leaf textures (needs Pillow): the date palm's
frond, green and dry, for tools/make_palm.py's palms, and the olive's leaf
clusters, which replace the nature kit's flat blobs on the same cards.

  python3 tools/paint_flora.py
"""
import math, random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/textures'
NATURE = Path('/Users/ktabb/Documents/3dAssets/Stylized Nature MegaKit[Standard]/glTF')

def blend(a, b, t):
    return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(3))

def frond(dry: bool, seed: int) -> Image.Image:
    """One feather frond, its stalk up the middle of the image, base at the bottom."""
    rng = random.Random(seed)
    scale = 3
    width, height = 512*scale, 1024*scale
    image = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    middle = width/2
    leaflets = 86
    for side in (-1, 1):
        for i in range(leaflets):
            t = (i+rng.random()*.6)/leaflets
            y = height*(.985-t*.955)
            # Short spines at the base, the longest leaflets a third of the way
            # up, tapering to the tip.
            reach = (.30+.68*min(1.0, t/.28))*(1.0-.62*max(0.0, (t-.62)/.38)**1.4)
            length = middle*.97*reach*(.9+rng.random()*.14)
            angle = math.radians(64-34*t+rng.uniform(-7, 7))
            if dry: angle += math.radians(rng.uniform(-4, 22))
            ex = middle+side*length*math.sin(angle)
            ey = y-length*math.cos(angle)
            # A leaflet droops a little along its length.
            cx = middle+side*length*.55*math.sin(angle)
            cy = y-length*.5*math.cos(angle)+length*(.05 if not dry else .12)
            base = (9.5+rng.random()*3.5)*scale*(.7+.5*reach)
            if dry:
                shade = blend((92, 70, 44), (158, 128, 84), rng.random())
                tip = blend(shade, (176, 150, 104), .5)
            else:
                shade = blend((38, 62, 30), (74, 98, 44), rng.random())
                tip = blend(shade, (132, 138, 72), .35+rng.random()*.4)
                if rng.random() < .1: tip = (150, 122, 70)
            steps = 9
            points_a, points_b = [], []
            for s in range(steps+1):
                u = s/steps
                px = (1-u)**2*middle+2*(1-u)*u*cx+u*u*ex
                py = (1-u)**2*y+2*(1-u)*u*cy+u*u*ey
                half = base*.5*(1-u)**.8
                # Across the leaflet: perpendicular to its run.
                nx, ny = math.cos(angle), side*math.sin(angle)
                points_a.append((px-nx*half*side, py-ny*half*side))
                points_b.append((px+nx*half*side, py+ny*half*side))
            for s in range(steps):
                colour = blend(shade, tip, (s/steps)**1.6)
                draw.polygon([points_a[s], points_a[s+1], points_b[s+1], points_b[s]], fill=colour+(255,))
            # The midrib catches the light.
            draw.line([(middle, y), (cx, cy), (ex, ey)], fill=blend(shade, (190, 190, 130) if not dry else (190, 160, 110), .35)+(255,), width=max(1, scale-1), joint='curve')
    stalk = (104, 92, 50) if not dry else (120, 92, 58)
    for s in range(60):
        u = s/60
        half = (11-9*u)*scale*.5
        draw.rectangle([middle-half, height*(1-u)-height/60-1, middle+half, height*(1-u)], fill=stalk+(255,))
    return image.resize((512, 1024), Image.LANCZOS)

def olive_leaves() -> Image.Image:
    """Clusters of narrow grey-green leaves, inside the kit texture's own shapes."""
    rng = random.Random(7)
    mask = Image.open(NATURE/'Leaves_TwistedTree_C.png').convert('RGBA').split()[3]
    scale = 2
    size = mask.width*scale
    big = mask.resize((size, size), Image.LANCZOS).filter(ImageFilter.MaxFilter(9))
    inside = big.load()
    image = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    for i in range(9500):
        x, y = rng.uniform(0, size), rng.uniform(0, size)
        if inside[int(x), int(y)] < 128: continue
        length = rng.uniform(34, 62)*scale*.5
        half = length*rng.uniform(.13, .19)
        angle = rng.uniform(0, math.tau)
        # Upper sides are a dull green, undersides silver.
        shade = blend((62, 78, 48), (104, 122, 78), rng.random()) if rng.random() < .72 else blend((138, 150, 122), (172, 180, 150), rng.random())
        ax, ay = math.cos(angle), math.sin(angle)
        points = []
        for s in range(13):
            u = s/12
            w = half*math.sin(u*math.pi)**.75
            points.append((x+ax*length*(u-.5)-ay*w, y+ay*length*(u-.5)+ax*w))
        for s in range(12, -1, -1):
            u = s/12
            w = half*math.sin(u*math.pi)**.75
            points.append((x+ax*length*(u-.5)+ay*w, y+ay*length*(u-.5)-ax*w))
        draw.polygon(points, fill=shade+(255,))
        draw.line([(x-ax*length*.5, y-ay*length*.5), (x+ax*length*.5, y+ay*length*.5)], fill=blend(shade, (40, 52, 34), .45)+(255,), width=1)
    return image.resize((mask.width, mask.height), Image.LANCZOS)

if __name__ == '__main__':
    frond(False, 3).save(OUT/'palm_frond.png')
    frond(True, 5).save(OUT/'palm_frond_dry.png')
    olive_leaves().save(OUT/'olive_leaves.png')
    print('FLORA_READY')
