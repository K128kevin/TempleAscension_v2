"""Normalize imported, authored meshes; never generate primitive geometry."""
from pathlib import Path
import bpy
import sys
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
kay=next((ROOT/'source_art/kay-dungeon').glob('*/addons/*/Assets/gltf'))
adv=next((ROOT/'source_art/adventurers').glob('*/addons/*/Assets/gltf'))
mini=ROOT/'source_art/mini/Models/GLB format'
props=ROOT/'source_art/props/Exports/glTF'
nature=Path('/Users/ktabb/Documents/3dAssets/Stylized Nature MegaKit[Standard]/glTF')
sources={
 'floor':kay/'floor_tile_large.gltf.glb', 'wall':kay/'wall.gltf.glb',
 'torch_lit':kay/'torch_lit.gltf.glb',
 'column':mini/'column.glb','arch':kay/'wall_doorway.glb',
 'stairs':kay/'stairs.gltf.glb','rubble':kay/'rubble_large.gltf.glb',
 'vase':props/'Vase_2.gltf','brazier':props/'Torch_Metal.gltf',
 'banner':props/'Banner_1.gltf','altar':kay/'table_medium_tablecloth.gltf.glb',
 'sword':props/'Sword_Bronze.gltf','spear':mini/'weapon-spear.glb',
 'axe':adv/'axe_2handed.gltf','arrow':adv/'arrow.gltf','staff':adv/'staff.gltf',
 'shield':props/'Shield_Wooden.gltf', 'scutum':adv/'shield_square.gltf','crown':ROOT/'source_art/crown.glb',
 'bow':ROOT/'source_art/bow.glb','gem':nature/'Pebble_Square_2.gltf',
 'rock':nature/'Rock_Medium_3.gltf','tree':nature/'DeadTree_1.gltf',
 'bookcase':props/'Bookcase_2.gltf','books':props/'BookGroup_Medium_1.gltf','chalice':props/'Chalice.gltf',
 'grass':nature/'Grass_Wispy_Short.gltf', 'fern':nature/'Fern_1.gltf'
}
out=ROOT/'assets/models/props';out.mkdir(parents=True,exist_ok=True)
only = sys.argv[sys.argv.index("--only")+1] if "--only" in sys.argv else None
for name,path in sources.items():
 if only and name != only: continue
 if not path.exists():
  print('MISSING',path);continue
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(path))
 for o in list(bpy.data.objects):
  if name=='arch' and o.name=='wall_doorway_door': bpy.data.objects.remove(o,do_unlink=True)
 meshes=[o for o in bpy.data.objects if o.type=='MESH']
 if name in ['bow','arrow']:
  from mathutils import Matrix
  import math
  for o in meshes: o.matrix_world = Matrix.Rotation(math.pi/2,4,'X') @ o.matrix_world
 coords=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
 lo=Vector(tuple(min(v[i] for v in coords) for i in range(3)))
 hi=Vector(tuple(max(v[i] for v in coords) for i in range(3)))
 size=hi-lo
 # Blender Z up. Unit bounds let level scenes choose world dimensions.
 for o in meshes:
  transform=o.matrix_world.copy();o.parent=None;o.matrix_world.identity()
  for v in o.data.vertices:
   p=transform@v.co
   v.co=Vector(((p.x-(lo.x+hi.x)/2)/max(size.x,.001),(p.y-(lo.y+hi.y)/2)/max(size.y,.001),(p.z-lo.z)/max(size.z,.001)))
  for mod in list(o.modifiers):o.modifiers.remove(mod)
 for o in list(bpy.data.objects):
  if o.type!='MESH':bpy.data.objects.remove(o,do_unlink=True)
 bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')),export_format='GLB',export_animations=False)
 print('ASSET_READY',name,tuple(size))
