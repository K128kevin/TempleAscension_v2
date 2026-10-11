"""Prepare the photographed material library worn by every figure and weapon.

Run with python3 (numpy and Pillow) from the project root:

    python3 -I tools/prepare_materials.py

Each material is a CC0 photo scan (ambientCG, Poly Haven; downloads kept in
source_art/materials/, see docs/ASSETS.md) cut to three tiling 1024 px maps:

  col  colour, its mean brightness set to middle grey (sRGB 0.5) with its own
       hue and variation kept, so a shader can lay it over any colour;
  nrm  tangent-space normals (OpenGL, green up);
  dat  red roughness, green cavity (1 open, darker in the cracks, pores and
       weave: the scan's occlusion, or its height's own hollows), blue height.

Skin has no scan: its pores and fine creases are drawn here (`skin`), a tile
standing for about 6 cm of skin.

Each material's maps are kept in source_art/materials/prepared/, and the game
reads them as three texture arrays, one material to a layer, in the order of
ORDER (assets/shaders/detail.gdshaderinc names the layers):
assets/textures/materials/detail_col.jpg, detail_nrm.jpg and detail_dat.jpg,
the layers laid out COLUMNS across and down, imported as Texture2DArrays. They
are global shader uniforms (project.godot [shader_globals]), so any shader can
read every material through three textures.
"""
import sys
from pathlib import Path
sys.path.append(str(Path.home()/'Library/Python/3.14/lib/python/site-packages'))
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT/'source_art/materials'
PH = ROOT/'source_art/polyhaven/textures'
OUT = ROOT/'assets/textures/materials'
PREPARED = SRC/'prepared'
SIZE = 1024
COLUMNS = 4

# name: (colour, normal, roughness, occlusion or None, height or None)
def acg(asset):
    d = SRC/asset
    def f(kind):
        p = d/f'{asset}_2K-JPG_{kind}.jpg'
        return p if p.exists() else None
    return (f('Color'), f('NormalGL'), f('Roughness'), f('AmbientOcclusion'), f('Displacement'))

def ph(asset):
    d = SRC/f'ph_{asset}'
    return (d/f'{asset}_diff_2k.jpg', d/f'{asset}_nor_gl_2k.jpg', d/f'{asset}_rough_2k.jpg', None, None)

LIBRARY = {
    # Metals.
    'steel_brushed': acg('Metal009'),    # brushed, finely scratched steel
    'steel_worn': acg('Metal038'),       # scratched, mottled steel
    'iron_rusted': acg('Metal056C'),     # damaged iron, scratched and rusting
    'bronze': acg('Metal017'),           # old bronze, eroded and scratched
    'gold': acg('Metal048C'),            # impure, rough gold
    # Leathers.
    'leather_smooth': acg('Leather037'), # fine dark-brown hide
    'leather_worn': acg('Leather014'),   # old, scratched and scuffed
    'leather_rough': acg('Leather033A'), # coarse, cracked hide
    # Cloth.
    'wool': acg('Fabric031'),            # woven wool
    'cloth_coarse': acg('Fabric030'),    # coarse grey cloth
    'velvet': ph('velour_velvet'),
    'silk': ph('crepe_satin'),
    'linen': (PH/'rough_linen_Diffuse.jpg', PH/'rough_linen_nor_gl.jpg', None, None, None),
    'hessian': (PH/'hessian_230_Diffuse.jpg', PH/'hessian_230_nor_gl.jpg', None, None, None),
    # Wood.
    'wood_ash': ph('ash_veneer'),
    'wood_walnut': ph('american_walnut_veneer'),
}


def load(path, mode='RGB'):
    image = Image.open(path).convert(mode)
    if image.size != (SIZE, SIZE): image = image.resize((SIZE, SIZE), Image.LANCZOS)
    return np.asarray(image).astype(np.float32)/255.0


def blur(a, radius):
    # A box blur, three times (near enough a Gaussian), wrapping round the
    # tile's edges so it stays seamless.
    for _ in range(3):
        for axis in (0, 1):
            s = np.zeros_like(a)
            for k in range(-radius, radius+1): s += np.roll(a, k, axis=axis)
            a = s/(2*radius+1)
    return a


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1)-np.roll(h, 1, 1))*0.5
    dy = (np.roll(h, -1, 0)-np.roll(h, 1, 0))*0.5
    n = np.stack([-dx*strength, dy*strength, np.ones_like(h)], -1)
    return n/np.linalg.norm(n, axis=-1, keepdims=True)


def save(name, col, nrm, dat):
    PREPARED.mkdir(parents=True, exist_ok=True)
    Image.fromarray((np.clip(col, 0, 1)*255+.5).astype(np.uint8)).save(PREPARED/f'{name}_col.png')
    Image.fromarray((np.clip(nrm*.5+.5, 0, 1)*255+.5).astype(np.uint8)).save(PREPARED/f'{name}_nrm.png')
    Image.fromarray((np.clip(dat, 0, 1)*255+.5).astype(np.uint8)).save(PREPARED/f'{name}_dat.png')


# The layers of the arrays, in order (detail.gdshaderinc's MAT_* constants).
ORDER = ['steel_brushed', 'steel_worn', 'iron_rusted', 'bronze', 'gold',
    'leather_smooth', 'leather_worn', 'leather_rough', 'wool', 'cloth_coarse',
    'velvet', 'silk', 'linen', 'hessian', 'wood_ash', 'wood_walnut', 'skin']


def assemble():
    rows = (len(ORDER)+COLUMNS-1)//COLUMNS
    blank = {'col': (128, 128, 128), 'nrm': (128, 128, 255), 'dat': (204, 255, 128)}
    OUT.mkdir(parents=True, exist_ok=True)
    for map_name, fill in blank.items():
        sheet = Image.new('RGB', (SIZE*COLUMNS, SIZE*rows), fill)
        for i, name in enumerate(ORDER):
            sheet.paste(Image.open(PREPARED/f'{name}_{map_name}.png').convert('RGB'), ((i % COLUMNS)*SIZE, (i//COLUMNS)*SIZE))
        sheet.save(OUT/f'detail_{map_name}.jpg', quality=95 if map_name == 'nrm' else 92)
    print('arrays', COLUMNS, 'x', rows)


def grey_mean(col):
    # Mean brightness to middle grey, keeping hue and variation.
    lum = col@np.array([.299, .587, .114], np.float32)
    return np.clip(col*(.5/max(lum.mean(), 1e-3)), 0, 1)


def prepare(name, sources):
    colour, normal, rough, occlusion, height = sources
    col = load(colour)
    nrm = load(normal)*2.0-1.0
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    lum = col@np.array([.299, .587, .114], np.float32)
    if height is not None:
        h = load(height, 'L')
    else:
        # No scan of its height: the colour's own light and dark, its broad
        # swings taken out.
        h = lum-blur(lum, 24)
        h = (h-h.min())/max(h.max()-h.min(), 1e-3)
    r = load(rough, 'L') if rough is not None else np.clip(.8+(lum-lum.mean())*.4, 0, 1)
    if occlusion is not None:
        cavity = load(occlusion, 'L')
    else:
        # The hollows: how far below its surroundings each point lies.
        hollow = blur(h, 6)-h
        cavity = np.clip(1.0-np.maximum(hollow, 0)*4.0, 0, 1)
    save(name, grey_mean(col), nrm, np.stack([r, cavity, h], -1))
    print(name, 'mean roughness %.2f' % r.mean())


def skin():
    # Pores, scattered in clusters, each a small pit; fine creases criss-
    # crossing in two directions; and a soft mottle of the skin beneath.
    rng = np.random.default_rng(7)
    h = np.zeros((SIZE, SIZE), np.float32)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    density = blur(rng.random((SIZE, SIZE)).astype(np.float32), 40)
    density = (density-density.min())/(density.max()-density.min())
    pores = np.zeros_like(h)
    count = 7000
    px = rng.random(count)*SIZE
    py = rng.random(count)*SIZE
    keep = rng.random(count) < .35+.65*density[py.astype(int), px.astype(int)]
    radius = rng.uniform(1.0, 2.2, count)
    for x, y, rad in zip(px[keep], py[keep], radius[keep]):
        x0, y0 = int(x)-6, int(y)-6
        ys = (np.arange(y0, y0+13) % SIZE)
        xs = (np.arange(x0, x0+13) % SIZE)
        gy, gx = np.meshgrid(np.arange(y0, y0+13)-y, np.arange(x0, x0+13)-x, indexing='ij')
        pit = np.exp(-(gx*gx+gy*gy)/(rad*rad))
        pores[np.ix_(ys, xs)] = np.maximum(pores[np.ix_(ys, xs)], pit)
    # The creases are the skin's own net of furrows: the edges of irregular
    # cells (where the nearest of a scatter of points gives way to the next),
    # drawn out a little along one direction, as skin is stretched.
    creases = np.zeros_like(h)
    for cell, depth, stretch in ((32, 1.0, 1.33), (16, .45, 1.0)):
        # (Whole numbers of cells across and down, so the tile still tiles.)
        n = SIZE//cell
        m = int(round(SIZE/(cell*stretch)))
        tall = SIZE/m
        jitter = rng.random((m, n, 2))
        warp_x = blur(rng.random((SIZE, SIZE)).astype(np.float32), 25)
        warp_y = blur(rng.random((SIZE, SIZE)).astype(np.float32), 25)
        wx = xx+(warp_x-warp_x.mean())*cell*6.0
        wy = yy+(warp_y-warp_y.mean())*cell*6.0
        cx = np.floor(wx/cell).astype(int)
        cy = np.floor(wy/tall).astype(int)
        f1 = np.full(h.shape, 1e9, np.float32)
        f2 = np.full(h.shape, 1e9, np.float32)
        for oy in (-1, 0, 1):
            for ox in (-1, 0, 1):
                gx, gy = cx+ox, cy+oy
                j = jitter[gy % m, gx % n]
                d = np.hypot(wx-(gx+j[..., 0])*cell, (wy-(gy+j[..., 1])*tall)*cell/tall)
                f2 = np.where(d < f1, f1, np.minimum(f2, d))
                f1 = np.minimum(f1, d)
        edge = np.exp(-((f2-f1)/(cell*.09))**2)
        fade = blur(rng.random((SIZE, SIZE)).astype(np.float32), 18)
        fade = np.clip((fade-fade.mean())*10+.75, 0, 1)
        creases = np.maximum(creases, edge*fade*depth)
    mottle = blur(rng.random((SIZE, SIZE)).astype(np.float32), 12)
    mottle = (mottle-mottle.mean())/(mottle.std()+1e-6)
    h = .5-pores*.45-creases*.25+mottle*.03
    h = blur(h, 1)
    nrm = normal_from_height(h, 9.0)
    cavity = np.clip(1.0-pores*.55-creases*.35, 0, 1)
    rough = np.clip(.5+pores*.25+creases*.1+mottle*.04, 0, 1)
    tone = .5+mottle[..., None]*np.array([.018, .012, .010], np.float32)-pores[..., None]*np.array([.05, .06, .06], np.float32)
    save('skin', np.clip(tone, 0, 1), nrm, np.stack([rough, cavity, np.clip(h, 0, 1)], -1))
    print('skin')


if __name__ == '__main__':
    only = sys.argv[1:]
    for name, sources in LIBRARY.items():
        if not only or name in only: prepare(name, sources)
    if not only or 'skin' in only: skin()
    assemble()
