extends SceneTree
## Zeno, the bread seller (scripts/townsfolk.gd, scripts/bread_cart.gd): his
## straw hat and his handcart; pushing it round the streets by day, his hands
## on its grips and its wheels turning; a townsperson buying a loaf of him;
## his cry, now and then, while no one is buying; and at night his cart parked
## by his door and he indoors, in a house no one else sleeps in.
const Data = preload("res://scripts/data.gd")
const Daylight = preload("res://scripts/daylight.gd")
const BreadCart = preload("res://scripts/bread_cart.gd")
var passed = 0
var failed: Array[String] = []
func check(ok: bool, message: String):
	if ok: passed += 1
	else: failed.append(message); push_error(message)

var game
var folk
var world
func run(seconds: float, hero: Vector3 = Vector3.INF, step: float = .1) -> void:
	var t = 0.0
	while t < seconds:
		folk.tick(step,zeno_near() if hero == Vector3.INF else hero)
		t += step

func zeno_near() -> Vector3:
	return folk.zeno.at+Vector3(2,0,2)

func _initialize(): call_deferred("test")
func test():
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/zeno-save")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.sound.muted = true
	game.run = Data.new_character("warrior")
	game.load_floor()
	game.mode = "playing"
	world = game.world
	folk = world.townsfolk
	var zeno = folk.zeno
	world.set_time(Daylight.MORNING+200.0)
	folk.at_once()
	check(zeno != null and zeno.body.name == "Zeno" and zeno.body.find_child("StrawHat",true,false) != null and zeno.body.find_child("Apron",true,false) != null,"Zeno is about, in his straw hat and apron")
	check(folk.named_at(zeno.at).get("name","") == "Zeno","His name shows under the cursor")
	var cart: Node3D = folk.cart.node
	check(cart.is_inside_tree() and folk.cart.wheels.size() == 2 and cart.find_children("*","MeshInstance3D",true,false).filter(func(m): return m.mesh is SphereMesh).size() >= 10,"He has his handcart, two wheels and a load of loaves")
	# Pushing it round the streets.
	folk.push_on()
	var from: Vector3 = folk.cart_at
	var wheel_turn: float = folk.cart.wheels[0].rotation.x
	var behind = true
	var on_ground = true
	for i in 120:
		folk.tick(.1,zeno_near())
		if folk.zeno.state != "push": break
		var ahead = Vector3(sin(folk.cart_heading),0,cos(folk.cart_heading))
		behind = behind and Vector3(folk.cart_at.x,0,folk.cart_at.z).distance_to(Vector3(zeno.at.x,0,zeno.at.z)+ahead*folk.BEHIND) < .05
		on_ground = on_ground and folk.open_at(folk.cart_at)
	check(folk.cart_at.distance_to(from) > 3.0 and absf(folk.cart.wheels[0].rotation.x-wheel_turn) > 1.0,"He pushes his cart along, its wheels turning")
	check(behind and on_ground,"He walks behind it, and it keeps to the streets")
	# (The hands as the skeleton last showed them: its arms' reaching applied.)
	var sk: Skeleton3D = zeno.body.skeleton
	var seen: Dictionary = {}
	var read = func():
		for bone in ["hand_l","hand_r","upperarm_l","lowerarm_l"]: seen[bone] = sk.global_transform*sk.get_bone_global_pose(sk.find_bone(bone)).origin
	sk.skeleton_updated.connect(read)
	folk.tick(.05,zeno_near())
	await process_frame
	await process_frame
	sk.skeleton_updated.disconnect(read)
	var hands_on = true
	var frame: Transform3D = folk.cart.body.global_transform
	for k in 2:
		var grip: Vector3 = frame*(folk.cart.grips[1-k]-Vector3(0,BreadCart.WHEEL,0))
		hands_on = hands_on and seen[["hand_l","hand_r"][k]].distance_to(grip) < .15
	check(hands_on,"His hands are on its grips (within a fist's breadth)")
	# A customer.
	folk.sell()
	var buyer = null
	for w in folk.people:
		if w.state in ["walk","pause"] and not folk.inside(w) and not w.child and w.at.distance_to(folk.cart_at) < 40.0: buyer = w; break
	if buyer == null: buyer = folk.people.filter(func(w): return w.state in ["walk","pause"] and not folk.inside(w))[0]
	check(folk.buy_bread(buyer),"One of the townsfolk sets off to buy bread")
	var talked = false
	var calls_before: int = folk.calls
	for i in 900:
		folk.tick(.1,zeno_near())
		if folk.zeno.body.state in ["Talk","Reach"]: talked = true
		if buyer.basket != null: break
	check(talked and folk.sold == 1 and buyer.basket != null and buyer.basket.name == "Loaf" and buyer.body.held == buyer.basket,"Zeno serves him, and he goes on with a loaf in his hand")
	check(folk.calls == calls_before,"Zeno does not cry his bread while he is serving")
	# His cry, every twenty seconds or so, while no one buys.
	folk.sell()
	folk.bread_buyers = false
	folk.zeno.timer = 1000.0
	folk.call_left = 20.0
	var before: int = folk.calls
	game.hud.speeches.clear()
	for i in 650:
		folk.tick(.1,zeno_near())
	check(folk.calls - before == 3,"He calls out every twenty seconds or so (%d calls in 65 s)" % (folk.calls-before))
	folk.call_left = .05
	run(.2)
	check(game.hud.speeches.any(func(b): return b.speaker == folk.zeno.body and b.panel.words == folk.CRY),"\"%s\" over his head" % folk.CRY)
	folk.call_left = .05
	before = folk.calls
	folk.bread_customer = buyer
	run(30.0)
	folk.bread_customer = null
	folk.bread_buyers = true
	check(folk.calls == before,"Not while someone is buying")
	# Night: home with his cart, parked by his door, and in.
	folk.zeno.timer = 0.0
	world.set_time(Daylight.NIGHT+60.0)
	var hour: float = Daylight.NIGHT+60.0
	for i in 3000:
		folk.tick(.1,Vector3(9999,0,9999))
		hour += .1
		world.set_time(hour)
		if folk.zeno.state == "indoors": break
	check(folk.zeno.state == "indoors" and not folk.zeno.body.visible,"At night he goes in at his door")
	check(folk.cart_at.distance_to(folk.cart_home) < .3 and is_equal_approx(folk.cart_tilt,BreadCart.REST_TILT) and folk.cart.node.visible,"His cart is parked beside it, tipped back on its legs")
	var others: Array = folk.people+folk.children+[folk.anya,folk.orion,folk.selene]+folk.keepers
	check(folk.zeno.bed.kind == "house" and not others.any(func(w): return w.bed.get("kind") == "house" and w.bed.at.distance_to(folk.zeno.bed.at) < .5),"His house is his alone")
	var door: Vector3 = folk.zeno.bed.at
	check(folk.cart_home.distance_to(door) < 4.0,"The cart stands by his door")
	# Morning: out again, and off with the cart.
	var dawn: float = Daylight.MORNING
	world.set_time(dawn)
	for i in 600:
		folk.tick(.1,Vector3(9999,0,9999))
		dawn += .1
		world.set_time(dawn)
		if folk.zeno.state == "push": break
	check(folk.zeno.state == "push" and folk.zeno.body.visible and folk.cart_tilt == 0.0,"In the morning he takes up his cart and sets off")
	# The clock jumped to night: at once, all as it would be.
	world.set_time(Daylight.NIGHT+300.0)
	folk.at_once()
	check(folk.zeno.state == "indoors" and folk.cart_at.distance_to(folk.cart_home) < .01,"The clock jumped to night, he is in and his cart parked")
	FileAccess.open("res://test-results/zeno.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("ZENO ",passed," passed; ",failed)
	game.queue_free()
	await process_frame
	quit(0 if failed.is_empty() else 1)
