"""Prepare Poly Haven photo scans (CC0) for the outdoor world.

Each scan is cut down to a game-sized mesh, normalised to a unit box exactly as
tools/prepare_models.py does (so scenes choose its size), and exported without
images; its colour and normal maps are written beside the other textures at
512 px, where scripts/world_art.gd gives them to the model by name.

  .tools/Blender.app/Contents/MacOS/Blender --background --python tools/prepare_scans.py
"""
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'source_art/polyhaven'
OUT=ROOT/'assets/models/props'
TEXTURES=ROOT/'assets/textures'
# name: (scan, object in the scan or None for its only one, triangles to keep or 0 for all)
SCANS={
 'boulder_a':('namaqualand_boulder_03',None,2200),'boulder_b':('namaqualand_boulder_04',None,2200),
 'boulder_c':('namaqualand_boulder_05',None,1600),'boulder_d':('namaqualand_boulder_06',None,1600),
 'crag':('namaqualand_cliff_02',None,7000),
 'stone_a':('namaqualand_stones_01','namaqualand_stones_01_a',160),'stone_b':('namaqualand_stones_01','namaqualand_stones_01_b',160),
 'stone_c':('namaqualand_stones_01','namaqualand_stones_01_d',160),
 'shrub_a':('shrub_02','shrub_02_d',0),'shrub_b':('shrub_02','shrub_02_b',0),
 'scrub':('wild_rooibos_bush','wild_rooibos_bush_c',0)}

def size_of(mesh):
 return max(mesh.dimensions)

def save_texture(scan,kind,size=512):
 source=SOURCE/scan/'textures'/f'{scan}_{kind}_1k.jpg'
 target=TEXTURES/f'scan_{scan}_{kind}.jpg'
 if not source.exists(): return
 # The twenty-metre cliff keeps its full size.
 if scan=='namaqualand_cliff_02': size=1024
 image=bpy.data.images.load(str(source))
 image.scale(size,size)
 # A scan's texture is black between its islands. Cut down, the mesh's
 # triangles no longer keep exactly to them, so each island's colour is
 # spread outward over the black first.
 colour=bpy.data.images.load(str(SOURCE/scan/'textures'/f'{scan}_diff_1k.jpg'))
 colour.scale(size,size)
 lit=np.array(colour.pixels[:]).reshape(size,size,4)[:,:,:3].max(axis=2)>.03
 pixels=np.array(image.pixels[:]).reshape(size,size,4)
 for step in range(48):
  if lit.all(): break
  total=np.zeros_like(pixels); count=np.zeros((size,size,1))
  for dy,dx in ((0,1),(0,-1),(1,0),(-1,0)):
   total+=np.roll(pixels*lit[:,:,None],(dy,dx),axis=(0,1)); count+=np.roll(lit,(dy,dx),axis=(0,1))[:,:,None]
  grow=(~lit)&(count[:,:,0]>0)
  pixels[grow]=(total/np.maximum(count,1))[grow]
  lit=lit|grow
 image.pixels=pixels.ravel().tolist()
 image.filepath_raw=str(target)
 image.file_format='JPEG'
 bpy.context.scene.render.image_settings.quality=90
 image.save()

for name,(scan,part,keep) in SCANS.items():
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(SOURCE/scan/f'{scan}.gltf'))
 for o in list(bpy.data.objects):
  if o.type!='MESH' or (part and o.name!=part): bpy.data.objects.remove(o,do_unlink=True)
 mesh=[o for o in bpy.data.objects if o.type=='MESH'][0]
 bpy.context.view_layer.objects.active=mesh
 mesh.select_set(True)
 triangles=sum(len(p.vertices)-2 for p in mesh.data.polygons)
 if keep and triangles>keep:
  # A glTF mesh is split along its texture seams; welded first, the cut
  # cannot open cracks along them. (The cliff, one sheet with few seams,
  # is cut as it comes.)
  if name!='crag':
   bpy.ops.object.mode_set(mode='EDIT')
   bpy.ops.mesh.select_all(action='SELECT')
   bpy.ops.mesh.remove_doubles(threshold=size_of(mesh)*1e-5)
   bpy.ops.object.mode_set(mode='OBJECT')
   triangles=sum(len(p.vertices)-2 for p in mesh.data.polygons)
  # Cut in two passes, relaxing the surface after each: one hard cut leaves
  # folds and pits that throw hard little shadows across the rock.
  for share in ((keep*4/triangles,3),(.25,2)) if name!='crag' else ((keep/triangles,0),):
   cut=mesh.modifiers.new('cut','DECIMATE')
   cut.ratio=min(1.0,share[0])
   bpy.ops.object.modifier_apply(modifier='cut')
   if share[1]:
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.vertices_smooth(factor=.5,repeat=share[1])
    bpy.ops.object.mode_set(mode='OBJECT')
 for p in mesh.data.polygons: p.use_smooth=True
 coords=[mesh.matrix_world@v.co for v in mesh.data.vertices]
 lo=Vector(tuple(min(v[i] for v in coords) for i in range(3)))
 hi=Vector(tuple(max(v[i] for v in coords) for i in range(3)))
 size=hi-lo
 transform=mesh.matrix_world.copy();mesh.parent=None;mesh.matrix_world.identity()
 for v in mesh.data.vertices:
  p=transform@v.co
  v.co=Vector(((p.x-(lo.x+hi.x)/2)/size.x,(p.y-(lo.y+hi.y)/2)/size.y,(p.z-lo.z)/size.z))
 for m in bpy.data.materials: m.use_nodes=False
 # (The shrubs' leaves are cut out by an alpha map; their colour and alpha are
 # combined into one PNG by hand, as docs/ASSETS.md records.)
 if 'shrub' not in name and name!='scrub': save_texture(scan,'diff'); save_texture(scan,'nor_gl')
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_animations=False)
 print('SCAN_READY',name,tuple(round(s,3) for s in size),sum(len(p.vertices)-2 for p in mesh.data.polygons),[m.name for m in mesh.data.materials])
