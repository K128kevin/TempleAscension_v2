extends RefCounted
## The elders' palace, north of the town in the outdoor world
## (scripts/overworld.gd). A paved road runs north from the arena's north gate,
## through a walled gate at the foot of the hill, and climbs between marble
## lions and fires to the palace on its top: white stone kept spotless, gilded,
## hung with crimson, with pools and palms before it. Everything the town
## below is not.
const Kit = preload("res://scripts/world_art.gd")
const Town = preload("res://scripts/world_town.gd")
const Desert = preload("res://scripts/world_desert.gd")
const NAME = "The Elders' Palace"
# (Brighter than white: it takes the yellow out of the limestone.)
const STONE = Color(1.06,1.09,1.16)
const WOOD = Color(.24,.15,.09)
# Half the road's width; the wall across the foot of the hill; the height of
# the terrace the palace stands on, and where its front edge is.
const ROAD = 4.5
const WALL_Z = -79.0
const PODIUM = 1.6
const FRONT = -104.0

static func build(world) -> void:
	world.upkeep["palace"] = Town.KEPT
	road(world)
	precinct(world)
	approach(world)
	forecourt(world)
	palace(world)
	gardens(world)

static func stone(world) -> ShaderMaterial:
	return Kit.masonry(STONE,WOOD,.4,Town.KEPT,world.HILL_HEIGHT)

# A marble lion, `stature` times life size, on a marble plinth, facing south
# down the road.
static func lion(world, at: Vector3, stature: float = 1.2) -> Array:
	var rise = .9*stature
	var plinth = world.place("floor",at,Vector3(1.15*stature,rise,2.5*stature),Kit.marble())
	world.block_rect(Rect2(at.x-.7*stature,at.z-1.4*stature,1.4*stature,2.8*stature))
	return [plinth,world.statue("lion","",at+Vector3(0,rise,-.15*stature),0.0,stature,true)]

# A fire in a gilded bowl, on a marble pedestal.
static func fire(world, at: Vector3, width: float = 1.2, pedestal: float = 1.3) -> Node3D:
	if pedestal>0.0: world.place("floor",at,Vector3(width*.8,pedestal,width*.8),Kit.marble())
	var bowl = world.brazier(at+Vector3.UP*pedestal,width)
	for mesh in bowl.find_children("*","MeshInstance3D",true,false): mesh.material_override = Kit.gold()
	if at.y<.5: world.block_disc(Vector3(at.x,0,at.z),maxf(.6,width*.5),world.LOW)
	return bowl

# The road from the arena's north gate to the top of the hill, well laid.
static func road(world) -> void:
	var x: float = world.HILL.x
	var top: float = world.HILL.z+world.HILL_HALF.y
	world.dab_rect(world.PAVING,Rect2(x-ROAD,top,ROAD*2.0,-52.0-top))
	world.add_place("The Palace Road","road",Vector3(x,0,-66),8.0)

# A wall of clean white stone shuts the hill off from the town, with a
# towered gate where the road goes through.
static func precinct(world) -> void:
	var x: float = world.HILL.x
	var material = Kit.masonry(STONE,WOOD,.4,Town.KEPT)
	var gold = Kit.gold()
	var at = x-66.0
	while at<x+66.0:
		var middle = at+2.0
		at += 4.0
		if absf(middle-x)<6.5 or world.margin_at(Vector3(middle,0,WALL_Z))<-9.0: continue
		var piece = world.place("wall",Vector3(middle,0,WALL_Z),Vector3(4.0,6.4,1.4),material)
		var coping = world.place("floor",Vector3(middle,6.4,WALL_Z),Vector3(4.05,.3,1.8),Kit.marble())
		world.block_rect(Rect2(middle-2.0,WALL_Z-.7,4.0,1.4))
		world.screen([piece,coping])
	var towers: Array = []
	for side in [-1.0,1.0]:
		var tower = Vector3(x+side*7.6,0,WALL_Z)
		towers.append(world.place("pillar_decorated",tower,Vector3(3.8,10.0,3.6),material))
		world.block_rect(Rect2(tower.x-1.9,WALL_Z-1.8,3.8,3.6))
		towers.append(fire(world,tower+Vector3.UP*10.0,1.4,0.0))
		towers.append(Town.hanging(world,"cloth_red",Vector3(tower.x,3.2,WALL_Z+1.86),5.2,0.0,Town.CRIMSON))
		# Marble lions stand outside, facing the town.
		towers += lion(world,Vector3(x+side*11.5,0,WALL_Z+4.4),1.3)
	towers.append(world.place("wall",Vector3(x,7.8,WALL_Z),Vector3(11.6,1.6,1.5),material))
	towers.append(world.place("floor",Vector3(x,9.4,WALL_Z),Vector3(11.8,.25,1.8),gold))
	world.screen(towers)
	world.add_place("The Palace Gate","gate",Vector3(x,0,WALL_Z),7.0)

# Up the slope the road runs between marble lions and fires.
static func approach(world) -> void:
	var x: float = world.HILL.x
	for side in [-1.0,1.0]:
		world.screen(lion(world,Vector3(x+side*(ROAD+2.4),0,-84.6),1.1))
		fire(world,Vector3(x+side*(ROAD+2.4),0,-89.6))

# The court before the palace: paving, and a pool to either side of the road.
static func forecourt(world) -> void:
	var x: float = world.HILL.x
	var south: float = world.HILL.z+world.HILL_HALF.y
	world.dab_rect(world.PAVING,Rect2(x-34.0,FRONT,68.0,south-FRONT))
	var marble = Kit.marble()
	for side in [-1.0,1.0]:
		var pool = Rect2(x+side*21.0-6.0,FRONT+3.4,12.0,4.6)
		# The water runs on under its marble kerb, which hides its soft edge.
		world.dab_rect(world.WATER,pool.grow(.8))
		world.block_rect(pool.grow(1.6),world.LOW,false)
		world.place("floor",Vector3(pool.get_center().x,0,pool.position.y-1.0),Vector3(pool.size.x+4.0,.45,2.0),marble)
		world.place("floor",Vector3(pool.get_center().x,0,pool.end.y+1.0),Vector3(pool.size.x+4.0,.45,2.0),marble)
		world.place("floor",Vector3(pool.position.x-1.0,0,pool.get_center().y),Vector3(2.0,.45,pool.size.y),marble)
		world.place("floor",Vector3(pool.end.x+1.0,0,pool.get_center().y),Vector3(2.0,.45,pool.size.y),marble)
		for along in [pool.position.x-3.6,pool.end.x+3.6]:
			if absf(along-x)>ROAD+10.0: Desert.palm(world,Vector3(along,0,pool.get_center().y),world.rng.randf_range(7.5,9.0))
		fire(world,Vector3(x+side*(ROAD+2.4),0,south-1.6))

# The palace: a two-storey hall of white stone on a terrace, a tower over its
# middle, a wing to either side, and a portico of marble columns with gilded
# heads and feet under a stepped gable. Two great marble lions flank its steps.
static func palace(world) -> void:
	var x: float = world.HILL.x
	var material = stone(world)
	var marble = Kit.marble()
	var gold = Kit.gold()
	var face = FRONT-4.0
	var terrace = world.place("floor",Vector3(x,0,FRONT-13.0),Vector3(66.0,PODIUM,26.0),material)
	terrace.name = "PalaceTerrace"
	world.block_rect(Rect2(x-33.0,FRONT-26.0,66.0,26.0))
	world.place("stairs",Vector3(x,0,FRONT+2.5),Vector3(16.0,PODIUM,5.0),material)
	world.block_rect(Rect2(x-8.0,FRONT,16.0,4.6),world.LOW,false)
	var hall = Town.block(world,Vector3(x-20.0,0,FRONT-24.0),Vector2i(10,5),["osaoddoaso","oooooooooo"],["sosos","ooooo"],STONE,WOOD,PODIUM,Town.KEPT)
	hall.append(world.place("floor",Vector3(x,PODIUM+8.0,face-.2),Vector3(40.4,.25,.7),gold))
	hall.append(world.place("floor",Vector3(x-19.8,PODIUM+8.0,FRONT-14.0),Vector3(.7,.25,20.4),gold))
	for offset in [-14.0,-6.0,6.0,14.0]:
		hall.append(Town.hanging(world,"cloth_red",Vector3(x+offset,PODIUM+3.4,face+.1),4.2,0.0,Town.CRIMSON))
	world.screen(hall)
	var tower = Town.block(world,Vector3(x-8.0,0,FRONT-20.0),Vector2i(4,3),["oooo"],["ooo"],STONE,WOOD,PODIUM+7.0,Town.KEPT)
	tower.append(world.place("floor",Vector3(x,PODIUM+11.0,FRONT-8.2),Vector3(16.4,.25,.7),gold))
	tower.append(world.place("floor",Vector3(x-7.8,PODIUM+11.0,FRONT-14.0),Vector3(.7,.25,12.4),gold))
	tower.append(fire(world,Vector3(x,PODIUM+10.0,FRONT-14.0),2.0,0.0))
	world.screen(tower)
	for side in [-1.0,1.0]:
		var corner = Vector3(x-32.0 if side<0 else x+20.0,0,FRONT-20.0)
		var wing = Town.block(world,corner,Vector2i(3,3),["sos"],["sos"],STONE,WOOD,PODIUM,Town.KEPT)
		wing.append(world.place("floor",Vector3(corner.x+6.0,PODIUM+4.0,FRONT-8.2),Vector3(12.4,.25,.7),gold))
		wing.append(world.place("floor",Vector3(corner.x+.2,PODIUM+4.0,FRONT-14.0),Vector3(.7,.25,12.4),gold))
		world.screen(wing)
		# A tower at each front corner of the terrace, with a fire on top.
		var post = Vector3(x+side*31.2,0,FRONT-1.8)
		var corner_tower = world.place("pillar_decorated",post,Vector3(3.4,PODIUM+9.0,3.4),material)
		world.screen([corner_tower,fire(world,post+Vector3.UP*(PODIUM+9.0),1.5,0.0)])
		# The great lions, either side of the steps.
		world.screen(lion(world,Vector3(x+side*11.4,0,FRONT+2.6),1.7))
	# The portico.
	var portico: Array = []
	for offset in [-15.0,-9.0,-3.3,3.3,9.0,15.0]:
		var foot = Vector3(x+offset,PODIUM,face+2.4)
		portico.append(world.place("column",foot,Vector3(1.4,8.0,1.4),marble))
		portico.append(world.place("floor",foot,Vector3(2.0,.4,2.0),gold))
		portico.append(world.place("floor",foot+Vector3.UP*7.6,Vector3(2.0,.45,2.0),gold))
	portico.append(world.place("wall",Vector3(x,PODIUM+8.0,face+2.4),Vector3(33.6,1.3,2.1),marble))
	portico.append(world.place("floor",Vector3(x,PODIUM+8.9,face+1.2),Vector3(33.6,.3,4.6),marble))
	var rise = PODIUM+9.3
	for course in [Vector3(25.0,1.1,1.9),Vector3(16.0,1.0,1.8),Vector3(7.6,.9,1.7)]:
		portico.append(world.place("wall",Vector3(x,rise,face+2.4),course,marble))
		rise += course.y
	portico.append(world.place("floor",Vector3(x,rise,face+2.4),Vector3(8.0,.28,2.0),gold))
	world.screen(portico)
	world.add_place(NAME,"palace",Vector3(x,0,FRONT+7.6),6.0)

# Palms and olives round the hilltop, and green grass: there is water to
# spare up here.
static func gardens(world) -> void:
	var rng: RandomNumberGenerator = world.rng
	var x: float = world.HILL.x
	var south: float = world.HILL.z+world.HILL_HALF.y
	for side in [-1.0,1.0]:
		for z in [south-2.0,FRONT-6.0,FRONT-14.0,FRONT-22.0]:
			var at = Vector3(x+side*37.0,0,z+rng.randf_range(-1.0,1.0))
			if world.fits(at,1.0): Desert.palm(world,at,rng.randf_range(8.0,9.5))
		var olive = Vector3(x+side*32.0,0,FRONT+8.6)
		if world.fits(olive,1.0):
			var tree = world.prop("olive_a" if side<0 else "olive_b",olive,rng.randf_range(5.0,6.0),rng.randf_range(0,TAU))
			world.block_disc(olive,.6)
			world.screen([tree])
	for i in 420:
		var at = Vector3(x+rng.randf_range(-52.0,52.0),0,rng.randf_range(world.HILL_REACH.y+6.0,WALL_Z-2.0))
		var c = world.to_cell(at)
		var cell = world.index(c.x,c.y)
		if world.cells[cell] != world.OPEN or world.paint[cell*4+world.PAVING]>30 or world.paint[cell*4+world.WATER]>10: continue
		Desert.tuft(world,at,Color(.50,.62,.30))
