"""Lays out the frames tools/blender_sheet.py rendered into one contact
sheet a clip: a row a view, a column a moment, each labelled with its share
of the clip.

  python3 tools/sheet_compose.py <dir> <clip> <out.png>
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw
d, clip, out = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
phases = (d/(clip+'.phases')).read_text().split()
views = [v for v in ('side', 'front', 'game', 'rear', 'quarter', 'top') if (d/('%s-%s-00.png' % (clip, v))).exists()]
first = Image.open(d/('%s-%s-00.png' % (clip, views[0])))
W, H = first.size
sheet = Image.new('RGB', (W*len(phases), H*len(views)), 'black')
dr = ImageDraw.Draw(sheet)
for r, v in enumerate(views):
    for c, t in enumerate(phases):
        im = Image.open(d/('%s-%s-%02d.png' % (clip, v, c))).convert('RGB')
        sheet.paste(im, (c*W, r*H))
        dr.rectangle((c*W, r*H, c*W+44, r*H+16), fill='black')
        dr.text((c*W+3, r*H+2), t, fill='yellow')
sheet.save(out)
print('SHEET', out)
