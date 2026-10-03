extends RefCounted
## The buildings of the town the hero can walk into: the inn and the smithy.
##
## Each is a hall of the town's wall modules on all four sides, its doorway
## standing open. While the hero is inside, its roof and the two walls on the
## camera's side are lifted away (Overworld.rooms) and the room is seen from
## above; the far walls stay. A floor above the ground (the inn's loft, where
## the beds are) is a raised deck (Overworld.decks): the hero climbs to it by
## its stair as he climbs the palace hill, and whatever is set down on a deck
## stands at its height.
const Kit = preload("res://scripts/world_art.gd")
const Art = preload("res://scripts/assets.gd")
const BAY = 4.0
const MODULES = {"w":"wall","d":"wall_door","s":"wall_window","a":"wall_arched","o":"wall_archwindow","p":"arch","b":"wall_broken"}
# The inn's loft stands this far above its floor.
const LOFT = 3.4
const INN = Vector3(-279.5,0,-70.5)
const INN_BAYS = Vector2i(5,4)
const SMITHY = Vector3(-245.5,0,-69.5)
const SMITHY_BAYS = Vector2i(4,3)

# The walls and roof of a hall whose north-west corner is `corner`: `faces`
# gives each side's modules, a string of letters for every storey. Its roof
# and its south and west walls (the camera's side) are the shell that is
# lifted away while the hero is inside. Returns its room (as in
# Overworld.rooms), with "door": the middle of its doorway's step outside.
static func hall(world, corner: Vector3, bays: Vector2i, faces: Dictionary, tint: Color, wood: Color, wear: float) -> Dictionary:
	var material = Kit.masonry(tint,wood,.4,snappedf(wear,.05),0.0)
	var size = Vector2(bays.x*BAY,bays.y*BAY)
	var shell: Array = []
	var back: Array = []
	var storeys: int = faces.south.size()
	for storey in storeys:
		var y = storey*BAY
		for i in bays.x:
			var x = corner.x+BAY*.5+i*BAY
			shell.append(world.place(MODULES[faces.south[storey][i]],Vector3(x,y,corner.z+size.y-.5),Vector3(BAY,BAY,1),material))
			back.append(world.place(MODULES[faces.north[storey][i]],Vector3(x,y,corner.z+.5),Vector3(BAY,BAY,1),material,PI))
		for i in bays.y:
			var z = corner.z+BAY*.5+i*BAY
			shell.append(world.place(MODULES[faces.west[storey][i]],Vector3(corner.x+.5,y,z),Vector3(BAY,BAY,1),material,-PI/2))
			back.append(world.place(MODULES[faces.east[storey][i]],Vector3(corner.x+size.x-.5,y,z),Vector3(BAY,BAY,1),material,PI/2))
	# The roof lies below the top course, which stands round it as a parapet.
	var roof = world.place("floor",Vector3(corner.x+size.x*.5,storeys*BAY-1.0,corner.z+size.y*.5),Vector3(size.x-1.0,.3,size.y-1.0),Kit.masonry(tint*Color(.9,.87,.82),wood,.4,snappedf(wear,.05),0.0))
	world.block_rect(Rect2(corner.x,corner.z,size.x,1.0))
	world.block_rect(Rect2(corner.x,corner.z+size.y-1.0,size.x,1.0))
	world.block_rect(Rect2(corner.x,corner.z,1.0,size.y))
	world.block_rect(Rect2(corner.x+size.x-1.0,corner.z,1.0,size.y))
	# A doorway stands open.
	var room = {"area":Rect2(corner.x,corner.z,size.x,size.y),"roof":roof,"front":[],"inside":false,"door":Vector3.ZERO}
	for i in bays.x:
		if faces.south[0][i] != "p": continue
		var x = corner.x+BAY*.5+i*BAY
		world.open_rect(Rect2(x-1.0,corner.z+size.y-1.0,2.0,1.0))
		room.door = Vector3(x,0,corner.z+size.y+1.4)
	world.rooms.append(room)
	# (Nothing grows indoors.)
	world.keep_clear.append(room.area)
	world.screen_in_room(shell,room,"front")
	world.screen_in_room(back,room,"back")
	return room

# A floor of 4 m tiles of model `id` over `area`, its top at `top`.
static func floor_tiles(world, id: String, area: Rect2, top: float, material: Material) -> void:
	var count = Vector2i(maxi(1,roundi(area.size.x/BAY)),maxi(1,roundi(area.size.y/BAY)))
	var tile = Vector2(area.size.x/count.x,area.size.y/count.y)
	for j in count.y:
		for i in count.x:
			world.place(id,Vector3(area.position.x+(i+.5)*tile.x,top-.2,area.position.y+(j+.5)*tile.y),Vector3(tile.x,.2,tile.y),material)

# Furniture standing on the floor (or on the deck there): a kit model at its
# own proportions, `height` tall, closing the cells within `solid` of it.
static func put(world, id: String, at: Vector3, height: float, yaw: float = 0.0, solid: float = 0.0) -> Node3D:
	var node = world.prop(id,at,height,yaw)
	if solid>0: world.block_disc(Vector3(at.x,0,at.z),solid,world.LOW,false)
	return node

# A model of plain shape in a material of the town's: timber, iron.
static func made(world, id: String, at: Vector3, size: Vector3, material: Material, yaw: float = 0.0) -> Node3D:
	return world.place(id,at,size,material,yaw)

# A warm lamp's light, indoors.
static func lamp(world, at: Vector3, energy: float, reach: float, colour: Color = Color(1.0,.72,.42)) -> OmniLight3D:
	var light = OmniLight3D.new()
	light.light_color = colour
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.4
	light.position = at+Vector3.UP*world.lift(at)
	world.add_child(light)
	return light

# The inn: a common room with its tables and its bar, the kitchen's wall and
# door behind the bar, and above the kitchen a loft of beds, up a stair by
# the east wall.
static func inn(world, tint: Color, wood: Color) -> Dictionary:
	var c = INN
	var size = Vector2(INN_BAYS.x*BAY,INN_BAYS.y*BAY)
	var room: Dictionary = hall(world,c,INN_BAYS,{"south":["swpws","sosos"],"west":["wsws","swsw"],"north":["wwwww","wswsw"],"east":["wwww","wsws"]},tint,wood,.55)
	var planks = Kit.planks(Color(.56,.44,.32))
	var timber = Kit.planks(Color(.42,.31,.21),1.6)
	var inside = Rect2(c.x+1.0,c.z+1.0,size.x-2.0,size.y-2.0)
	floor_tiles(world,"floor_wood",inside,.03,planks)
	# The loft covers the room's northern six metres; the kitchen is under it,
	# behind a wall with its own door.
	var edge = c.z+7.0
	var loft = Rect2(inside.position.x,inside.position.y,inside.size.x,edge-inside.position.y)
	floor_tiles(world,"floor_wood",loft,LOFT,planks)
	var plaster = Kit.masonry(tint*Color(.96,.94,.9),wood,.4,.3,0.0)
	for i in 4:
		made(world,"wall_door" if i==3 else "wall",Vector3(loft.position.x+2.25+i*4.5,0,edge-.6),Vector3(4.5,LOFT-.2,.4),plaster)
	# A rail along the loft's edge, as far as the stair's head.
	for i in 4: made(world,"barrier",Vector3(loft.position.x+2.0+i*4.0,LOFT,edge-.3),Vector3(4.0,1.0,.3),timber)
	world.block_rect(Rect2(loft.position.x,edge-1.0,16.0,1.0),world.LOW,false)
	# The stair climbs north along the east wall.
	var foot = c.z+12.5
	var stair = Rect2(inside.end.x-2.0,edge,2.0,foot-edge)
	made(world,"stairs_wood",Vector3(stair.get_center().x,0,stair.get_center().y),Vector3(stair.size.x,LOFT,stair.size.y),timber)
	# Casks and crates stand along its open side.
	var beside = stair.position.x-.5
	put(world,"barrel",Vector3(beside,0,edge+.6),1.0,0.0,.3)
	put(world,"barrel",Vector3(beside-.05,0,edge+1.5),.9,1.0,.3)
	put(world,"crate",Vector3(beside,0,edge+2.5),.95,.2,.3)
	put(world,"crate",Vector3(beside-.05,0,edge+3.45),.8,-.3,.3)
	put(world,"bag",Vector3(beside+.05,0,edge+4.3),.7,.6,.3)
	world.block_rect(Rect2(beside-.4,edge,.8,foot-edge-.6),world.LOW,false)
	# The bar: a long counter before the kitchen wall, kegs and shelves of
	# bottles behind it, stools before it.
	var bar = c.z+8.5
	for x in [c.x+5.0,c.x+9.0]: made(world,"table_long",Vector3(x,0,bar),Vector3(.9,1.12,4.0),timber,PI/2)
	world.block_rect(Rect2(c.x+3.0,bar-.4,8.0,.8),world.LOW,false)
	for i in 5: put(world,"stool",Vector3(c.x+3.8+i*1.6,0,bar+1.0),.62,i*1.3,.3)
	made(world,"shelves",Vector3(c.x+4.2,0,edge-.15),Vector3(2.0,2.0,.5),timber)
	made(world,"shelves",Vector3(c.x+6.3,0,edge-.15),Vector3(2.0,2.0,.5),timber)
	put(world,"barrel_rack",Vector3(c.x+8.4,0,edge+.05),1.3)
	put(world,"barrel_rack",Vector3(c.x+10.0,0,edge+.05),1.3)
	put(world,"shelf_bottles",Vector3(c.x+9.2,2.0,edge-.2),.65)
	for spot in [[3.5,.1],[4.4,-.15],[6.1,.12],[7.9,-.1],[9.6,.05],[10.5,-.12]]: put(world,"mug",Vector3(c.x+spot[0],1.12,bar+spot[1]),.17,spot[0]*2.0)
	for spot in [[5.2,-.1],[5.45,.12],[8.7,.08]]: put(world,"bottle",Vector3(c.x+spot[0],1.12,bar+spot[1]),.36)
	put(world,"candlestick",Vector3(c.x+7.0,1.12,bar-.1),.44)
	lamp(world,Vector3(c.x+7.0,2.4,bar+.4),1.1,7.0)
	put(world,"lantern",Vector3(c.x+2.2,1.9,edge-.4),.8)
	put(world,"lantern",Vector3(c.x+12.2,1.9,edge-.4),.8)
	# The common room's tables.
	var west = Vector3(c.x+4.6,0,c.z+12.6)
	put(world,"table",west,.85)
	world.block_rect(Rect2(west.x-1.5,west.z-.6,3.0,1.2),world.LOW,false)
	for side in [-1.0,1.0]: put(world,"bench",west+Vector3(0,0,side*.98),.5,0.0,.5)
	var east = Vector3(c.x+13.4,0,c.z+11.0)
	put(world,"table",east,.85,PI/2)
	world.block_rect(Rect2(east.x-.6,east.z-1.5,1.2,3.0),world.LOW,false)
	for seat in [Vector3(-.95,0,-.8),Vector3(-.95,0,.7),Vector3(.95,0,-.6),Vector3(.95,0,.8),Vector3(0,0,1.9)]: put(world,"stool",east+seat,.55,seat.z,.3)
	for table in [west,east]:
		put(world,"candlestick",table+Vector3(0,.85,0),.4)
		for spot in [Vector3(-.8,0,.2),Vector3(.7,0,-.2),Vector3(.2,0,.3)]:
			var turned: Vector3 = spot if table==west else Vector3(spot.z,0,spot.x)
			put(world,"plate",table+turned+Vector3(0,.85,0),.03)
			put(world,"mug",table+turned*1.3+Vector3(.15,.85,-.15),.17,spot.x*3.0)
	put(world,"bottle",west+Vector3(-.3,.85,-.25),.36)
	put(world,"barrel",Vector3(c.x+1.7,0,c.z+14.3),1.0,0.0,.4)
	put(world,"barrel",Vector3(c.x+2.6,0,c.z+14.5),.85,.8,.4)
	put(world,"cabinet",Vector3(c.x+1.35,0,c.z+9.6),1.5,PI/2,.5)
	lamp(world,Vector3(c.x+8.0,2.8,c.z+12.5),.9,8.0)
	# The loft and its stair are raised ground from here on: what is set down
	# on them stands at their height.
	world.decks.append({"area":loft,"start":Vector2.ZERO,"along":Vector2.ZERO,"low":LOFT,"high":LOFT})
	world.decks.append({"area":stair,"start":Vector2(0,foot),"along":Vector2(0,-1.0/(foot-edge)),"low":0.0,"high":LOFT})
	# Beds along the loft's north wall, a stand between each pair, a chest
	# and a cabinet at the west end.
	for i in 4:
		var bed = Vector3(c.x+3.1+i*4.3,0,c.z+2.35)
		put(world,"bed",bed,.81)
		world.block_rect(Rect2(bed.x-.94,c.z+1.0,1.88,2.5),world.LOW,false)
		if i<3:
			put(world,"nightstand",bed+Vector3(2.15,0,-1.05),.95,0.0,.3)
			put(world,"candlestick",bed+Vector3(2.15,.95,-1.05),.36)
	put(world,"chest",Vector3(c.x+1.6,0,c.z+5.6),.7,PI/2,.5)
	put(world,"lantern",Vector3(c.x+9.9,1.9,c.z+1.1),.8)
	lamp(world,Vector3(c.x+10.0,2.2,c.z+4.0),.8,8.0)
	return room

# The smithy: the forge and its chimney against the north wall, anvils before
# it, benches, a grindstone, and the smith's work hung on every wall.
# Where Orion's work is, from the smithy's corner (scripts/smith.gd): his
# anvil (from the forge), the grindstone and its axle (in the model's own
# unit space, about which tools/prepare_whetstone.py cut the wheel free),
# and the foot of the sword he takes down from the north wall.
const ANVIL = Vector3(-1.5,0,3.3)
const WHEEL = Vector3(12.6,0,9.0)
const WHEEL_AXLE = Vector3(0,.70,0)
# (The stone itself sits this far north of the frame's middle, in metres.)
const WHEEL_STONE = -.077
const WORK_SWORD = Vector3(4.6,1.3,1.17)
# The smithy's finished arms: each kind's size (smaller than the heroes'
# carry them), and how far up its length the steel begins (a sword and a
# shield are finished as the warrior's own).
const ARMS = {"sword":[Vector3(.15,.9,.06),0.0],"sword_long":[Vector3(.34,1.15,.1),.27],"axe":[Vector3(.66,1.0,.14),.6],
	"hand_axe":[Vector3(.36,.64,.09),.55],"axe_bronze":[Vector3(.2,.58,.04),.62],"shield":[Vector3(.6,.6,.12),0.0],"scutum":[Vector3(.56,.78,.2),0.0]}

# One of them, hung or leaning at `at`.
static func arm(world, id: String, at: Vector3, yaw: float) -> Node3D:
	var finish: Material = Art.arms_material(ARMS[id][1])
	if id == "sword": finish = Art.sword_material()
	elif id == "shield": finish = Art.gladiator_shield()
	elif id == "scutum": finish = Art.metal()
	return made(world,id,at,ARMS[id][0],finish,yaw)

static func smithy(world, tint: Color, wood: Color) -> Dictionary:
	var c = SMITHY
	var size = Vector2(SMITHY_BAYS.x*BAY,SMITHY_BAYS.y*BAY)
	var room: Dictionary = hall(world,c,SMITHY_BAYS,{"south":["spsw"],"west":["wsw"],"north":["wwww"],"east":["wsw"]},tint,wood,.6)
	var stone = Kit.masonry(Color(.40,.37,.33),wood,.4,.5,0.0)
	var iron = Kit.iron()
	var soot = Kit.masonry(Color(.34,.31,.28),wood,.4,.6,0.0)
	var timber = Kit.planks(Color(.42,.31,.21),1.6)
	floor_tiles(world,"floor",Rect2(c.x+1.0,c.z+1.0,size.x-2.0,size.y-2.0),.03,stone)
	# The forge: a hearth of blackened stone, the fire in its arch, a hood
	# over it, and the chimney up through the roof.
	var forge = Vector3(c.x+9.0,0,c.z+1.0)
	made(world,"floor",forge+Vector3(0,0,.95),Vector3(3.2,.95,1.9),soot)
	made(world,"wall_arched",forge+Vector3(0,.95,.3),Vector3(3.2,1.7,.6),soot)
	made(world,"pillar",forge+Vector3(0,2.45,.85),Vector3(2.9,.75,1.7),soot)
	made(world,"pillar",forge+Vector3(0,3.0,.75),Vector3(1.3,3.6,1.3),soot)
	world.block_rect(Rect2(forge.x-1.6,c.z+1.0,3.2,1.9),world.LOW,false)
	# A bed of burning coals in the hearth: lumps of charcoal, glowing in the
	# cracks between them (the temple's braziers' coals, spread wide).
	var coals = MeshInstance3D.new()
	coals.mesh = SphereMesh.new()
	coals.mesh.radial_segments = 64
	coals.mesh.rings = 24
	var burning = ShaderMaterial.new()
	burning.shader = load("res://assets/shaders/embers.gdshader")
	burning.set_shader_parameter("grain",Vector3(34,3,18))
	burning.set_shader_parameter("fine_grain",90.0)
	burning.set_shader_parameter("glow",1.1)
	coals.material_override = burning
	coals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	coals.scale = Vector3(2.2,.13,1.15)
	coals.position = forge+Vector3(0,.95,1.0)
	world.add_child(coals)
	var glow = lamp(world,forge+Vector3(0,1.5,1.3),2.2,9.0,Color(1.0,.52,.20))
	var fire = preload("res://scripts/torch_flame.gd").new()
	fire.position = forge+Vector3(0,1.05,1.0)
	fire.scale = Vector3.ONE*1.5
	world.add_child(fire)
	fire.setup(glow,37.0)
	# Anvils on their logs before it, the quenching barrel, water, coal. (The
	# first is Orion's: its face runs east and west before him.)
	var anvil = put(world,"anvil_log",forge+ANVIL,1.07,0.0,.55)
	put(world,"anvil_log",forge+Vector3(1.7,0,3.6),1.07,-.5,.55)
	put(world,"anvil",forge+Vector3(.2,0,5.4),.56,1.2,.5)
	put(world,"barrel",forge+Vector3(2.3,0,.9),1.0,0.0,.4)
	put(world,"bucket_metal",forge+Vector3(-2.2,0,1.3),.37,.5,.3)
	put(world,"bag",forge+Vector3(-2.3,0,.5),.75,.3,.3)
	put(world,"bag",forge+Vector3(3.1,0,.5),.7,1.1,.3)
	put(world,"chain",forge+Vector3(3.0,.03,1.7),.09,.4)
	# Benches along the west wall, with the smith's small work on them.
	for z in [c.z+3.2,c.z+6.6]:
		put(world,"workbench",Vector3(c.x+1.7,0,z),.9,PI/2)
		world.block_rect(Rect2(c.x+1.0,z-1.0,1.3,2.0),world.LOW,false)
	put(world,"workbench_drawers",Vector3(c.x+1.5,.9,c.z+2.7),.24,PI/2)
	made(world,"hand_axe",Vector3(c.x+1.7,.93,c.z+3.6),ARMS.hand_axe[0],Art.arms_material(ARMS.hand_axe[1]),.4).rotation.x = PI/2
	made(world,"sword",Vector3(c.x+1.7,.93,c.z+6.2),ARMS.sword[0],Art.sword_material(),-.3).rotation.x = PI/2
	put(world,"mug",Vector3(c.x+1.5,.9,c.z+7.2),.17)
	put(world,"crate_metal",Vector3(c.x+1.6,0,c.z+9.2),.85,.1,.5)
	put(world,"crate_metal",Vector3(c.x+1.5,0,c.z+10.2),.7,.6,.4)
	# The grindstone (its wheel apart from its frame, to turn: its axle runs
	# north and south), racks of finished arms, a chest.
	var stone_size: Vector3 = Kit.sized("whetstone",1.17)
	put(world,"whetstone",c+WHEEL,1.17,0.0,.6)
	var wheel = world.place("whetstone_wheel",c+WHEEL+WHEEL_AXLE*stone_size,stone_size)
	for z in [c.z+3.4,c.z+5.6]:
		put(world,"weapon_stand",Vector3(c.x+14.3,0,z),1.25,-PI/2)
		world.block_rect(Rect2(c.x+13.7,z-.7,1.3,1.4),world.LOW,false)
	put(world,"chest",Vector3(c.x+14.2,0,c.z+7.6),.7,-PI/2,.5)
	# Arms hang from pegs on the north wall, either side of the forge, and on
	# the east wall: swords and shields as the warrior's own, axes and long
	# swords in bright steel on dark hafts.
	var wall = c.z+1.12
	for rack in [c.x+3.2,c.x+5.6,c.x+12.6]: put(world,"peg_rack",Vector3(rack,2.4,wall),.35)
	var hung = [["sword",2.3,1.45],["sword_long",3.0,1.15],["axe",3.8,1.3],["hand_axe",5.4,1.7],["axe_bronze",6.0,1.72],["sword",6.6,1.45],
		["shield",11.6,1.6],["scutum",12.7,1.45],["shield",13.8,1.6]]
	for piece in hung: arm(world,piece[0],Vector3(c.x+piece[1],piece[2],wall),0.0)
	# (The sword Orion works on hangs by itself, low enough to take down:
	# scripts/smith.gd hangs it at WORK_SWORD.)
	put(world,"peg_rack",c+Vector3(WORK_SWORD.x,WORK_SWORD.y+.95,1.12),.3)
	var east = c.x+size.x-1.12
	for rack in [c.z+2.2,c.z+4.6,c.z+6.8]: put(world,"peg_rack",Vector3(east,2.4,rack),.35,-PI/2)
	var more = [["sword",1.6,1.45],["hand_axe",2.3,1.7],["sword",2.9,1.45],["axe",4.1,1.3],["sword_long",5.1,1.15],["shield",6.3,1.6],
		["axe_bronze",7.2,1.72],["sword",7.8,1.45]]
	for piece in more: arm(world,piece[0],Vector3(east,piece[2],c.z+piece[1]),-PI/2)
	# More lean on the racks and in the corner by the forge.
	for spot in [[14.0,3.0,.25,"sword_long"],[14.05,3.8,-.2,"sword"],[14.0,5.2,.3,"axe"],[14.05,6.0,-.25,"sword"],[10.9,1.35,.2,"sword_long"],[11.25,1.3,-.3,"hand_axe"]]:
		arm(world,spot[3],Vector3(c.x+spot[0],.05,c.z+spot[1]),-PI/2 if spot[0]>13.0 else 0.0).rotation.z = spot[2]
	put(world,"peg_rack",Vector3(east,2.4,c.z+9.4),.35,-PI/2)
	arm(world,"sword_long",Vector3(east,1.15,c.z+8.9),-PI/2)
	made(world,"pickaxe",Vector3(east,1.4,c.z+9.8),Vector3(.6,.9,.1),null,-PI/2)
	arm(world,"shield",Vector3(east,1.6,c.z+10.6),-PI/2)
	room["anvil"] = anvil
	room["wheel"] = wheel
	put(world,"lantern",Vector3(c.x+2.0,1.9,c.z+1.1),.8)
	return room
