extends RefCounted
## The temple's exterior, at the eastern end of the outdoor world
## (scripts/overworld.gd): the stepped building whose floors the hero climbs
## inside, seen from its west front, with the door that begins the ascent.
const Kit = preload("res://scripts/world_art.gd")
# Each storey of the building, as on the terraces inside (Temple.facade).
const STOREY = 8.0
# Storeys below the summit, each set back from the one beneath.
const TIERS = 5
const SETBACK = 6.0
# Half the ground storey's width, and how far east of its door the building
# runs.
const HALF = 36.0
const DEPTH = 66.0
const DOOR_HALF = 3.6
const DOOR_HEIGHT = 6.4
const NAME = "Temple of the Crowned"

static func stone() -> ShaderMaterial:
	return Kit.masonry(Color(.90,.84,.72),Color(.30,.19,.11),.16)

static func build(world) -> void:
	var door: Vector3 = world.TEMPLE_DOOR
	world.block_rect(Rect2(door.x,-HALF,DEPTH,HALF*2.0),world.SOLID,false)
	for tier in TIERS: storey(world,tier)
	summit(world)
	doorway(world)
	portico(world)
	forecourt(world)
	world.add_place(NAME,"temple",door+Vector3(-6,0,0),12.0)

# A wall of the building, `from` one end to `to` the other at the foot, with
# its projecting top course and a column every few metres.
static func face(world, from: Vector3, to: Vector3, height: float, columns: bool = true) -> Array:
	var material = stone()
	var along: Vector3 = to-from
	var length = along.length()
	var middle = (from+to)*.5
	# Faces run north-south (looking west) or west-east (looking south).
	var west_face = absf(along.z)>absf(along.x)
	var out = Vector3(-1,0,0) if west_face else Vector3(0,0,1)
	var yaw = -PI/2 if west_face else 0.0
	var nodes: Array = []
	nodes.append(world.place("wall",middle-out*.6,Vector3(length,height,1.2),material,yaw))
	nodes.append(world.place("wall",middle+out*.1+Vector3.UP*(height-.8),Vector3(length+.4,.8,2.0),material,yaw))
	if columns:
		var count = maxi(1,roundi(length/6.0))
		for i in count+1:
			nodes.append(world.place("column",from.lerp(to,i/float(count))+out*.45,Vector3(1.1,height-.8,1.1),material))
	return nodes

# One storey: its west and south faces, and the terrace its setback leaves on
# the storey below.
static func storey(world, tier: int) -> void:
	var west = world.TEMPLE_DOOR.x+tier*SETBACK
	var back: float = world.TEMPLE_DOOR.x+DEPTH
	var half = HALF-tier*SETBACK
	var base = tier*STOREY
	if tier==0:
		# The ground storey's front opens at the door.
		face(world,Vector3(west,base,-half),Vector3(west,base,-DOOR_HALF-.6),STOREY)
		face(world,Vector3(west,base,DOOR_HALF+.6),Vector3(west,base,half),STOREY)
		face(world,Vector3(west,DOOR_HEIGHT,-DOOR_HALF-.6),Vector3(west,DOOR_HEIGHT,DOOR_HALF+.6),STOREY-DOOR_HEIGHT,false)
	else: face(world,Vector3(west,base,-half),Vector3(west,base,half),STOREY)
	face(world,Vector3(west,base,half),Vector3(back,base,half),STOREY)
	# The terrace round the next storey up, with a parapet at its edge.
	var top = base+STOREY
	var inner_west = west+SETBACK
	var inner_half = half-SETBACK
	var paving = Kit.masonry(Color(.78,.74,.66),Color(.3,.19,.11),.25)
	world.place("floor",Vector3((west+inner_west)*.5,top-.3,0),Vector3(SETBACK,.3,half*2.0),paving)
	world.place("floor",Vector3((inner_west+back)*.5,top-.3,(half+inner_half)*.5),Vector3(back-inner_west,.3,SETBACK),paving)
	world.place("floor",Vector3((inner_west+back)*.5,top-.3,-(half+inner_half)*.5),Vector3(back-inner_west,.3,SETBACK),paving)
	var material = stone()
	world.place("wall",Vector3(west+.3,top,0),Vector3(half*2.0,1.0,.6),material,-PI/2)
	world.place("wall",Vector3((west+back)*.5,top,half-.3),Vector3(back-west,1.0,.6),material)
	# Fire bowls burn at the terrace's corners.
	for side in [-1.0,1.0]: world.brazier(Vector3(west+1.2,top,side*(half-1.2)),1.3)

# The summit: the open floor where the crown waits, ringed by columns.
static func summit(world) -> void:
	var west = world.TEMPLE_DOOR.x+TIERS*SETBACK
	var back: float = world.TEMPLE_DOOR.x+DEPTH
	var half = HALF-TIERS*SETBACK
	var base = TIERS*STOREY
	var material = stone()
	world.place("floor",Vector3((west+back)*.5,base-.3,0),Vector3(back-west,.3,half*2.0),Kit.masonry(Color(.78,.74,.66),Color(.3,.19,.11),.25))
	for i in 5:
		for side in [-1.0,1.0]:
			world.place("column",Vector3(west+2.0+i*5.0,base,side*(half-1.0)),Vector3(1.1,6.0,1.1),material)
	for i in 3: world.place("column",Vector3(west+1.0,base,-half+1.0+i*(half-1.0)),Vector3(1.1,6.0,1.1),material)
	world.place("wall",Vector3(west+1.0,base+6.0,0),Vector3(half*2.0,.9,1.6),material,-PI/2)
	for side in [-1.0,1.0]: world.place("wall",Vector3(west+12.0,base+6.0,side*(half-1.0)),Vector3(22.0,.9,1.6),material)
	world.brazier(Vector3(west+4.0,base,0),2.2)

# The way in: a short passage into the dark, lit from within by torchlight.
static func doorway(world) -> void:
	var door: Vector3 = world.TEMPLE_DOOR
	var material = stone()
	var depth = 6.0
	world.open_rect(Rect2(door.x-.5,-DOOR_HALF+.6,depth-1.5,DOOR_HALF*2.0-1.2))
	world.dab_rect(world.PAVING,Rect2(door.x-1.0,-DOOR_HALF,depth+1.0,DOOR_HALF*2.0))
	for side in [-1.0,1.0]:
		world.place("wall",Vector3(door.x+depth*.5+.6,0,side*(DOOR_HALF+.5)),Vector3(depth,DOOR_HEIGHT,1.0),material)
	world.place("floor",Vector3(door.x+depth*.5+.6,DOOR_HEIGHT,0),Vector3(depth,.4,DOOR_HALF*2.0+2.0),material)
	# Past the passage there is only the dark of the first hall.
	var dark = StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(.012,.010,.008)
	var end = world.place("floor",Vector3(door.x+depth+.4,0,0),Vector3(.4,DOOR_HEIGHT,DOOR_HALF*2.0+2.0),dark)
	end.name = "TempleDoorDark"
	# Seen from above, it is the floor that shows the dark within.
	world.place("floor",Vector3(door.x+depth*.5+1.4,.02,0),Vector3(depth-1.4,.02,DOOR_HALF*2.0),dark)
	var glow = OmniLight3D.new()
	glow.name = "TempleDoorTorchlight"
	glow.light_color = Color(1,.62,.3)
	glow.light_energy = 2.2
	glow.omni_range = 8.0
	glow.omni_attenuation = 1.3
	glow.position = Vector3(door.x+depth-1.2,2.6,0)
	world.add_child(glow)

# A porch of four great columns stands before the door, a stepped gable over
# them, and a stone guardian either side.
static func portico(world) -> void:
	var door: Vector3 = world.TEMPLE_DOOR
	var material = stone()
	var front = door.x-5.4
	# The columns stand free, so the door shows between them from afar; the
	# gable they would carry rises from the wall above the door instead.
	for z in [-9.6,-4.8,4.8,9.6]:
		var column = world.place("column",Vector3(front,0,z),Vector3(1.7,9.2,1.7),material)
		world.block_disc(Vector3(front,0,z),.9)
		world.screen([column])
	world.place("wall",Vector3(door.x-.4,STOREY,0),Vector3(22.0,1.6,2.2),material,-PI/2)
	world.place("wall",Vector3(door.x-.4,STOREY+1.6,0),Vector3(15.0,1.3,2.0),material,-PI/2)
	world.place("wall",Vector3(door.x-.4,STOREY+2.9,0),Vector3(8.0,1.1,1.8),material,-PI/2)
	for side in [-1.0,1.0]:
		world.brazier(Vector3(front-1.6,0,side*6.8),1.5,1.5)
		# The guardians: centurions like those within, in the same carved
		# stone, three times a man's height. Both look out west, away from the
		# temple, down the road.
		var plinth_at = Vector3(door.x-4.2,0,side*16.5)
		var plinth = world.place("wall",plinth_at,Vector3(4.6,1.4,4.6),material)
		world.block_rect(Rect2(plinth_at.x-2.3,plinth_at.z-2.3,4.6,4.6))
		var guardian = world.statue("centurion","spear",plinth_at+Vector3.UP*1.4,-PI/2,3.0)
		guardian.name = "TempleGuardian"
		world.screen([plinth,guardian])

# The paved court before the porch, lined with pillars and fire.
static func forecourt(world) -> void:
	var door: Vector3 = world.TEMPLE_DOOR
	var material = stone()
	world.dab_rect(world.PAVING,Rect2(door.x-34.0,-11.0,34.0,22.0))
	world.dab_rect(world.PAVING,Rect2(door.x-12.0,-24.0,12.0,48.0),.8)
	for i in 4:
		for side in [-1.0,1.0]:
			var at = Vector3(door.x-12.0-i*7.0,0,side*9.4)
			if i%2==0: world.brazier(at,1.3,1.3)
			else:
				var pillar = world.place("pillar",at,Vector3(1.3,5.2,1.3),material)
				world.block_disc(at,.8)
				world.screen([pillar])
