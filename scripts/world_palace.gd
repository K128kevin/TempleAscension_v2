extends RefCounted
## The elders' palace, north of the town in the outdoor world
## (scripts/overworld.gd). A paved road runs north from the arena's north gate,
## through a walled gate at the foot of the hill guarded by marble centurions,
## and climbs between seated marble lions and fires to the palace on its top: white stone kept spotless, gilded,
## hung with crimson, with pools and palms before it. Everything the town
## below is not. Guards stand at the foot of the road, and at the palace's
## door; within are the throne room and the elders' bedchambers.
const Kit = preload("res://scripts/world_art.gd")
const Town = preload("res://scripts/world_town.gd")
const Desert = preload("res://scripts/world_desert.gd")
const Interiors = preload("res://scripts/world_interiors.gd")
const Art = preload("res://scripts/assets.gd")
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

# A marble lion, `stature` times life size, sitting on a marble plinth, facing
# south down the road.
static func lion(world, at: Vector3, stature: float = 1.2) -> Array:
	var rise = .8*stature
	var plinth = world.place("floor",at,Vector3(1.3*stature,rise,2.0*stature),Kit.marble())
	world.block_rect(Rect2(at.x-.75*stature,at.z-1.1*stature,1.5*stature,2.2*stature))
	return [plinth,world.statue("lion","",at+Vector3(0,rise,.12*stature),0.0,stature,true,"Sit")]

# A marble centurion on a marble plinth, facing south.
static func sentry(world, at: Vector3, stature: float = 1.6) -> Array:
	var plinth = world.place("floor",at,Vector3(2.0,1.3,2.0),Kit.marble())
	world.block_rect(Rect2(at.x-1.1,at.z-1.1,2.2,2.2))
	return [plinth,world.statue("centurion","spear",at+Vector3.UP*1.3,0.0,stature,true)]

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
	world.add_place("palace road","road",Vector3(x,0,-66),8.0)
	# Two guards where it leaves the ring street, either side of it (clear of
	# the inn's corner), facing the town.
	for side in [-1.0,1.0]: Town.guard(world,Vector3(x+side*(ROAD+1.7),0,-53.2),Vector3(side*.25,0,1),.5+side*.3)

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
		# Marble centurions stand guard outside, facing the town.
		towers += sentry(world,Vector3(x+side*11.5,0,WALL_Z+4.0))
	towers.append(world.place("wall",Vector3(x,7.8,WALL_Z),Vector3(11.6,1.6,1.5),material))
	towers.append(world.place("floor",Vector3(x,9.4,WALL_Z),Vector3(11.8,.25,1.8),gold))
	world.screen(towers)
	world.add_place("palace gate","gate",Vector3(x,0,WALL_Z),7.0)

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
# middle, and a portico of marble columns with gilded heads and feet under a
# stepped gable. Two great marble lions flank its steps, and two guards its
# door. Its doorway stands open (scripts/world_interiors.gd's halls are walked
# into the same way): inside, the throne room runs from the door to a dais at
# its far end, the elders' great throne at the top of its stair, with room for
# the town to gather before it; three bedchambers open off its west side and
# two off its east. While the hero is inside, the roof, the tower and the
# walls on the camera's side are lifted away (Overworld.rooms).
# The building's north-west corner and its size in wall modules, and the
# throne room's half-width.
const HALL = Vector3(-30.0,0,-132.0)
const HALL_BAYS = Vector2i(15,6)
const THRONE_HALF = 14.0
# The dais: its top's height above the floor, its depth, its half-width, and
# the depth of its stair.
const DAIS = Vector3(1.8,7.0,7.0)
const DAIS_STAIR = 4.0
const THRONE_HEIGHT = 3.2
# The bedchambers' walls (z, north to south) on each side, and where each
# chamber's door is (the bay of the throne room's side wall it opens from).
const WEST_ROOMS = [[-132.0,-124.0,1],[-124.0,-116.0,3],[-116.0,-108.0,4]]
const EAST_ROOMS = [[-132.0,-120.0,1],[-120.0,-108.0,4]]
static func palace(world) -> void:
	var x: float = world.HILL.x
	var material = stone(world)
	var marble = Kit.marble()
	var gold = Kit.gold()
	var face = FRONT-4.0
	var back: float = HALL.z-2.0
	var terrace = world.place("floor",Vector3(x,0,(FRONT+back)*.5),Vector3(66.0,PODIUM,FRONT-back),material)
	terrace.name = "PalaceTerrace"
	world.place("stairs",Vector3(x,0,FRONT+2.5),Vector3(16.0,PODIUM,5.0),material)
	# The terrace is walked on, up the steps; its edges are a drop.
	var top = Rect2(x-33.0,back,66.0,FRONT-back)
	world.decks.append({"area":Rect2(x-8.0,FRONT,16.0,5.0),"start":Vector2(0,FRONT+5.0),"along":Vector2(0,-1.0/5.0),"low":0.0,"high":PODIUM})
	world.decks.append({"area":top,"start":Vector2.ZERO,"along":Vector2.ZERO,"low":PODIUM,"high":PODIUM})
	# (Behind the palace and beside it, out of sight, it is closed.)
	world.block_rect(Rect2(top.position.x,top.position.y,x+HALL.x-top.position.x,FRONT-4.0-top.position.y),world.LOW,false)
	world.block_rect(Rect2(x-HALL.x,top.position.y,top.end.x-x+HALL.x,FRONT-4.0-top.position.y),world.LOW,false)
	world.block_rect(Rect2(top.position.x,top.position.y,top.size.x,HALL.z-top.position.y),world.LOW,false)
	world.block_rect(Rect2(top.position.x,top.position.y,1.0,top.size.y),world.LOW,false)
	world.block_rect(Rect2(top.end.x-1.0,top.position.y,1.0,top.size.y),world.LOW,false)
	for side in [-1.0,1.0]: world.block_rect(Rect2(x+side*20.5-12.5,FRONT-1.0,25.0,1.0),world.LOW,false)
	# (Nothing grows on it.)
	world.dab_rect(world.PAVING,top)
	var corner = Vector3(x+HALL.x,0,HALL.z)
	var room: Dictionary = hall(world,corner,material)
	var shell: Array = room.front
	var roof: Node3D = room.roof
	# The gilded cornices along the front and the west side.
	shell.append(world.place("floor",Vector3(x,8.0,face-.2),Vector3(HALL_BAYS.x*4.0+.4,.25,.7),gold))
	shell.append(world.place("floor",Vector3(corner.x+.2,8.0,corner.z+HALL_BAYS.y*2.0),Vector3(.7,.25,HALL_BAYS.y*4.0+.4),gold))
	for offset in [-22.0,-14.0,14.0,22.0]:
		shell.append(Town.hanging(world,"cloth_red",Vector3(x+offset,3.4,face+.1),4.2,0.0,Town.CRIMSON))
	# The tower over the throne room: part of the roof.
	var tower = Town.block(world,Vector3(x-8.0,0,HALL.z+4.0),Vector2i(4,3),["oooo"],["ooo"],STONE,WOOD,8.0,Town.KEPT)
	tower.append(world.place("floor",Vector3(x,12.0,HALL.z+15.8),Vector3(16.4,.25,.7),gold))
	tower.append(world.place("floor",Vector3(x-7.8,12.0,HALL.z+10.0),Vector3(.7,.25,12.4),gold))
	for node in tower: node.reparent(roof)
	for side in [-1.0,1.0]:
		# A tower at each front corner of the terrace, with a fire on top.
		var post = Vector3(x+side*31.2,0,FRONT-1.8)
		var corner_tower = world.place("pillar_decorated",post,Vector3(3.4,9.0,3.4),material)
		world.block_rect(Rect2(post.x-1.7,post.z-1.7,3.4,3.4))
		world.screen([corner_tower,fire(world,post+Vector3.UP*9.0,1.5,0.0)])
		# The great lions, either side of the steps.
		world.screen(lion(world,Vector3(x+side*11.4,0,FRONT+2.6),1.7))
	# The portico.
	var portico: Array = []
	for offset in [-15.0,-9.0,-3.3,3.3,9.0,15.0]:
		var foot = Vector3(x+offset,0,face+2.4)
		portico.append(world.place("column",foot,Vector3(1.4,8.0,1.4),marble))
		portico.append(world.place("floor",foot,Vector3(2.0,.4,2.0),gold))
		portico.append(world.place("floor",foot+Vector3.UP*7.6,Vector3(2.0,.45,2.0),gold))
		world.block_disc(foot,.8,world.LOW,false)
	portico.append(world.place("wall",Vector3(x,8.0,face+2.4),Vector3(33.6,1.3,2.1),marble))
	portico.append(world.place("floor",Vector3(x,8.9,face+1.2),Vector3(33.6,.3,4.6),marble))
	var rise = 9.3
	for course in [Vector3(25.0,1.1,1.9),Vector3(16.0,1.0,1.8),Vector3(7.6,.9,1.7)]:
		portico.append(world.place("wall",Vector3(x,rise,face+2.4),course,marble))
		rise += course.y
	portico.append(world.place("floor",Vector3(x,rise,face+2.4),Vector3(8.0,.28,2.0),gold))
	world.screen_in_room(portico,room,"front")
	# Two guards before the door, between the columns, facing the court.
	for side in [-1.0,1.0]: Town.guard(world,Vector3(x+side*6.1,0,FRONT-.9),Vector3(side*.2,0,1),.35+side*.25)
	world.add_place("palace","palace",Vector3(x,0,FRONT+7.6),6.0)
	throne_room(world,x)
	world.add_place("throne room","hall",Vector3(x,0,HALL.z+12.0),10.0)

# The palace's walls and roof, as a hall of scripts/world_interiors.gd: two
# storeys of wall modules on all four sides, the doorway open in the middle of
# the front. Returns its room (as in Overworld.rooms): its roof (everything
# above that is lifted away while the hero is inside) and its "front".
static func hall(world, corner: Vector3, material: Material) -> Dictionary:
	var faces = {"south":["sasosaopoasosas","ooooooooooooooo"],"west":["sosaso","oooooo"],
		"north":["wswswswswswswsw","wowowowowowowow"],"east":["wswsws","wowowo"]}
	var size = Vector2(HALL_BAYS.x*4.0,HALL_BAYS.y*4.0)
	var front: Array = []
	var behind: Array = []
	for storey in 2:
		var y = storey*4.0
		for i in HALL_BAYS.x:
			var along = corner.x+2.0+i*4.0
			front.append(world.place(Town.MODULES[faces.south[storey][i]],Vector3(along,y,corner.z+size.y-.5),Vector3(4,4,1),material))
			behind.append(world.place(Town.MODULES[faces.north[storey][i]],Vector3(along,y,corner.z+.5),Vector3(4,4,1),material,PI))
		for i in HALL_BAYS.y:
			var along = corner.z+2.0+i*4.0
			front.append(world.place(Town.MODULES[faces.west[storey][i]],Vector3(corner.x+.5,y,along),Vector3(4,4,1),material,-PI/2))
			behind.append(world.place(Town.MODULES[faces.east[storey][i]],Vector3(corner.x+size.x-.5,y,along),Vector3(4,4,1),material,PI/2))
	var roof = Node3D.new()
	roof.name = "PalaceRoof"
	world.add_child(roof)
	world.place("floor",Vector3(corner.x+size.x*.5,7.0,corner.z+size.y*.5),Vector3(size.x-1.0,.3,size.y-1.0),material).reparent(roof)
	world.block_rect(Rect2(corner.x,corner.z,size.x,1.0))
	world.block_rect(Rect2(corner.x,corner.z+size.y-1.0,size.x,1.0))
	world.block_rect(Rect2(corner.x,corner.z,1.0,size.y))
	world.block_rect(Rect2(corner.x+size.x-1.0,corner.z,1.0,size.y))
	var room = {"area":Rect2(corner.x,corner.z,size.x,size.y),"roof":roof,"front":[],"inside":false,"door":Vector3.ZERO,"name":"palace"}
	var door = corner.x+2.0+faces.south[0].find("p")*4.0
	world.open_rect(Rect2(door-1.0,corner.z+size.y-1.0,2.0,1.0))
	room.door = Vector3(door,0,corner.z+size.y+1.4)
	world.rooms.append(room)
	world.keep_clear.append(room.area)
	world.screen_in_room(front,room,"front")
	world.screen_in_room(behind,room,"back")
	return room

# The throne room and the bedchambers off it.
static func throne_room(world, x: float) -> void:
	var rng: RandomNumberGenerator = world.rng
	var marble = Kit.marble()
	var gold = Kit.gold()
	var inside = Rect2(x+HALL.x+1.0,HALL.z+1.0,HALL_BAYS.x*4.0-2.0,HALL_BAYS.y*4.0-2.0)
	# The floor's marble is a warmer, greyer stone than the dais's.
	var paving: StandardMaterial3D = marble.duplicate()
	paving.albedo_color *= Color(.8,.76,.7)
	Interiors.floor_tiles(world,"floor",inside,.03,paving)
	var plaster = Kit.masonry(STONE*Color(.98,.96,.93),WOOD,.4,Town.KEPT,world.HILL_HEIGHT)
	# The side walls between the throne room and the bedchambers, and between
	# the chambers: a storey high, each chamber's door an open arch.
	var walls: Array = []
	for side in [-1.0,1.0]:
		var line = x+side*THRONE_HALF
		var rooms: Array = WEST_ROOMS if side < 0.0 else EAST_ROOMS
		var doors: Array = rooms.map(func(r): return r[2])
		for i in HALL_BAYS.y:
			var along = HALL.z+2.0+i*4.0
			walls.append(world.place("arch" if i in doors else "wall",Vector3(line,0,along),Vector3(4,4,1),plaster,PI/2))
			if not i in doors: world.block_rect(Rect2(line-.5,along-2.0,1.0,4.0))
			else:
				world.block_rect(Rect2(line-.5,along-2.0,1.0,1.0))
				world.block_rect(Rect2(line-.5,along+1.0,1.0,1.0))
		var outer = x+side*(HALL_BAYS.x*2.0-1.0)
		for k in rooms.size()-1:
			var z: float = rooms[k][1]
			for j in 4:
				var across = line+side*(2.0+j*4.0)
				walls.append(world.place("wall",Vector3(across,0,z),Vector3(4,4,1),plaster))
			world.block_rect(Rect2(minf(line,outer),z-.5,absf(outer-line),1.0))
		for k in rooms.size():
			# (Inside its walls: the outer walls a metre thick, the others half
			# a metre either side of their line.)
			var north: float = rooms[k][0]+(1.0 if rooms[k][0] == HALL.z else .5)
			var south: float = rooms[k][1]-(1.0 if rooms[k][1] == HALL.z+HALL_BAYS.y*4.0 else .5)
			var area = Rect2(minf(line,outer)+.5,north,absf(outer-line)-1.0,south-north)
			bedchamber(world,area,side,k+(0 if side < 0.0 else 3),rng)
	world.screen(walls)
	# The dais at the far end, white marble edged with gold, its stair down to
	# the floor, the great throne at its top.
	var dais_top = HALL.z+1.0+DAIS.y
	world.place("floor",Vector3(x,0,HALL.z+1.0+DAIS.y*.5),Vector3(DAIS.z*2.0,DAIS.x,DAIS.y),marble)
	world.place("floor",Vector3(x,DAIS.x-.02,dais_top-.1),Vector3(DAIS.z*2.0+.1,.06,.25),gold)
	world.place("stairs",Vector3(x,0,dais_top+DAIS_STAIR*.5),Vector3(10.0,DAIS.x,DAIS_STAIR),marble)
	world.decks.insert(0,{"area":Rect2(x-5.0,dais_top,10.0,DAIS_STAIR),"start":Vector2(0,dais_top+DAIS_STAIR),"along":Vector2(0,-1.0/DAIS_STAIR),"low":PODIUM,"high":PODIUM+DAIS.x})
	world.decks.insert(0,{"area":Rect2(x-DAIS.z,HALL.z+1.0,DAIS.z*2.0,DAIS.y),"start":Vector2.ZERO,"along":Vector2.ZERO,"low":PODIUM+DAIS.x,"high":PODIUM+DAIS.x})
	# Its edges are a drop, but for the stair.
	world.block_rect(Rect2(x-DAIS.z,HALL.z+1.0,.6,DAIS.y),world.LOW,false)
	world.block_rect(Rect2(x+DAIS.z-.6,HALL.z+1.0,.6,DAIS.y),world.LOW,false)
	for side in [-1.0,1.0]: world.block_rect(Rect2(x+side*(DAIS.z+5.0)*.5-(DAIS.z-5.0)*.5,dais_top-.6,DAIS.z-5.0,.6),world.LOW,false)
	var throne = world.place("chair",Vector3(x,0,HALL.z+3.2),Kit.sized("chair",THRONE_HEIGHT),gold,0.0)
	throne.set_meta("great_throne",true)
	world.block_disc(Vector3(x,0,HALL.z+3.2),1.0,world.LOW,false)
	# Crimson hangings behind it, fires to either side.
	for offset in [-4.0,0.0,4.0]: Town.hanging(world,"cloth_red",Vector3(x+offset,2.0,HALL.z+1.02),5.0 if offset == 0.0 else 4.2,0.0,Town.CRIMSON)
	for side in [-1.0,1.0]:
		fire(world,Vector3(x+side*3.4,0,HALL.z+3.0),1.0,.9)
		fire(world,Vector3(x+side*(DAIS.z+1.6),0,dais_top+1.2),1.2,1.2)
	# Two rows of marble columns down the hall, gilded at head and foot.
	for side in [-1.0,1.0]:
		for z in [HALL.z+21.5,HALL.z+17.0,HALL.z+12.5]:
			var foot = Vector3(x+side*9.0,0,z)
			world.place("column",foot,Vector3(1.0,7.0,1.0),marble)
			world.place("floor",foot,Vector3(1.5,.35,1.5),gold)
			world.place("floor",foot+Vector3.UP*6.65,Vector3(1.5,.35,1.5),gold)
			world.block_disc(foot,.75,world.LOW,false)
	# A crimson runner from the door to the stair.
	rug(world,Vector3(x,0,HALL.z+HALL_BAYS.y*4.0-1.2),Vector3(0,0,-1),HALL_BAYS.y*4.0-1.2-DAIS.y-DAIS_STAIR-1.0,2.6,Town.CRIMSON*Color(1.25,1.1,1.1))
	# Benches along the side walls for the elders' councils; the floor between
	# is left clear for the town to gather.
	for side in [-1.0,1.0]:
		# (Clear of the chambers' doors.)
		for z in [HALL.z+21.5,HALL.z+10.0]:
			polish(Interiors.put(world,"bench",Vector3(x+side*(THRONE_HALF-1.4),0,z),.5,PI/2,0.0))
			world.block_rect(Rect2(x+side*(THRONE_HALF-1.4)-.4,z-1.5,.8,3.0),world.LOW,false)
	Interiors.lamp(world,Vector3(x,4.5,HALL.z+6.0),2.2,16.0)
	Interiors.lamp(world,Vector3(x,4.5,HALL.z+16.0),1.6,16.0)

# One of the elders' bedchambers, its floor `area` (inside its walls), on the
# west (`side` -1) or east of the throne room, its door in the throne room's
# wall: a great bed against its outer wall, its head to the north, a stand
# with a candle either side of it and a chest at its foot, a rug, a table and
# chairs, a cabinet and a fire, each room in its own colours.
const CHAMBERS = [Color(.42,.06,.08),Color(.12,.18,.34),Color(.18,.30,.20),Color(.40,.26,.10),Color(.28,.12,.30)]
static func bedchamber(world, area: Rect2, side: float, index: int, rng: RandomNumberGenerator) -> void:
	var dye: Color = CHAMBERS[index]
	var gold = Kit.gold()
	var outer = area.position.x+2.5 if side < 0.0 else area.end.x-2.5
	var head = area.position.y
	var bed = Vector3(outer,0,head+1.75)
	var made = Interiors.put(world,"bed",bed,1.1,0.0)
	bedding(made,dye)
	polish(made)
	world.block_rect(Rect2(bed.x-1.35,head,2.7,3.6),world.LOW,false)
	for across in [-1.0,1.0]:
		var stand = Vector3(bed.x+across*1.85,0,head+.35)
		polish(Interiors.put(world,"nightstand",stand,1.0,0.0,.35))
		Interiors.put(world,"candlestick",stand+Vector3.UP*1.0,.4)
	polish(Interiors.put(world,"chest",Vector3(bed.x,0,head+4.0),1.3,0.0,.6))
	rug(world,Vector3(bed.x,0,head+1.0),Vector3(0,0,1),5.4,3.6,dye*Color(1.2,1.15,1.1))
	# Toward the door a table on gilded legs, topped with marble, as the
	# elders' in their box; gilded chairs either side, a candle and a bottle.
	var inner = area.end.x-2.6 if side < 0.0 else area.position.x+2.6
	var table = Vector3((inner+outer)*.5+side*-.4,0,area.get_center().y+(.6 if area.size.y > 8.0 else .9))
	world.place("table",table,Kit.sized("table",.74),gold,PI/2)
	world.place("floor",table+Vector3.UP*.74,Vector3(1.2,.06,2.95),Kit.marble())
	world.block_disc(table,.9,world.LOW,false)
	Interiors.put(world,"candlestick",table+Vector3(0,.8,-.4),.36)
	Interiors.put(world,"bottle",table+Vector3(.15,.8,.3),.3)
	for across in [-1.0,1.0]: world.place("chair",table+Vector3(across*.95,0,0),Kit.sized("chair",1.1),gold,-across*PI/2)
	# Gilded urns in the corners by the bed.
	for across in [-1.0,1.0]:
		var corner = Vector3(bed.x+across*3.1,0,head+.45)
		if area.has_point(Vector2(corner.x,corner.z)): world.place("urn",corner,Kit.sized("urn",1.0),gold,across)
	# A cabinet against the south wall, and a fire in a gilded bowl.
	polish(Interiors.put(world,"cabinet",Vector3(outer+side*-.2,0,area.end.y-.25),1.5,PI,.4))
	fire(world,Vector3(area.get_center().x+side*1.4,0,area.end.y-1.0),.8,.9)
	# A hanging of the room's colour above the bed, and a lamp.
	Town.hanging(world,"cloth_blue" if index % 2 == 1 else "cloth_red",Vector3(bed.x,2.4,area.position.y+.02),2.6,0.0,dye)
	Interiors.lamp(world,Vector3(area.get_center().x,3.0,area.get_center().y),1.3,9.0)
	# (Named at the clear floor on the door's side.)
	world.add_place("bedchamber","chamber",Vector3(inner,0,area.end.y-1.2),minf(area.size.x,area.size.y)*.5)

# The kit's furniture in the palace's dark polished wood.
static func polish(node: Node3D) -> void:
	var wood: StandardMaterial3D = Kit.shared("MI_Trim_Furniture")
	if not Kit.cache.has("palace_wood"):
		var dark: StandardMaterial3D = wood.duplicate()
		dark.albedo_color = Color(.48,.36,.30)
		dark.roughness = .55
		Kit.cache["palace_wood"] = dark
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		for s in mesh.mesh.get_surface_count():
			var source: Material = mesh.mesh.surface_get_material(s)
			if source != null and source.resource_name == "MI_Trim_Furniture": mesh.set_surface_override_material(s,Kit.cache["palace_wood"])

# A bed's covers dyed `dye` (the kit's cloth: its sheets and blanket).
static func bedding(node: Node3D, dye: Color) -> void:
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		for s in mesh.mesh.get_surface_count():
			var source: Material = mesh.mesh.surface_get_material(s)
			if source != null and source.resource_name == "MI_Trim_Cloth": mesh.set_surface_override_material(s,Kit.gritty(dye,2.2,true))

# A rug laid flat on the floor (the kit's banner cloth): its near end at
# `from`, running `length` the way `toward` points, `width` across.
static func rug(world, from: Vector3, toward: Vector3, length: float, width: float, dye: Color) -> Node3D:
	var cloth = Art.model("cloth_red",Vector3(width,length,.03))
	Kit.dress(cloth)
	Kit.dye(cloth,dye)
	world.add_child(cloth)
	var across = Vector3.UP.cross(toward)
	cloth.basis = Basis(across*width,toward*length,toward.cross(across).normalized()*.03)
	cloth.position = from+Vector3.UP*(world.lift(from)+.05)
	for mesh in cloth.find_children("*","MeshInstance3D",true,false): mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return cloth

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
