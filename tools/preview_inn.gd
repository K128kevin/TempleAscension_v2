extends SceneTree
## Photographs Anya's inn close up, for judging its life and its props
## (scripts/townsfolk.gd, scripts/beer.gd, scripts/candle_flame.gd): the room
## from above, Anya and Selene carrying mugs, a fresh head of foam and the
## beer under it once it is drunk, a candle's flames, a woman sitting at a
## table, Selene's rag at a table and the tables and bar about her.
##   Godot --path . --resolution 1280x800 --script tools/preview_inn.gd --
##     [--shots=room,anya,selene,foam,drunk,candle,woman,rag,clutter] [--out=prefix]
## The pictures go to test-results/inn-<prefix>-<shot>.png.
const Data = preload("res://scripts/data.gd")
const Daylight = preload("res://scripts/daylight.gd")
const Kit = preload("res://scripts/world_art.gd")
const Beer = preload("res://scripts/beer.gd")
const Interiors = preload("res://scripts/world_interiors.gd")
const HERO = Vector3(-262,0,144)
var game
var world
var folk
var hour = 0.0
var camera: Camera3D

func _initialize(): call_deferred("capture")
func arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"+key+"="): return a.trim_prefix("--"+key+"=")
	return fallback

func step(seconds: float, until: Callable = func(): return false) -> bool:
	var t = 0.0
	while t < seconds:
		hour += 1.0/30
		t += 1.0/30
		world.set_time(hour)
		folk.tick(1.0/30,HERO)
		await process_frame
		if until.call(): return true
	return false

func look(from: Vector3, at: Vector3, fov: float = 30.0) -> void:
	camera.fov = fov
	camera.position = from
	camera.look_at(at)

# The camera `distance` from `at`, round from the way `body` faces by `turn`
# (radians, toward its left), `rise` up, looking at it.
func frame(at: Vector3, body: Node3D, distance: float, turn: float, rise: float, fov: float = 32.0) -> void:
	var front: Vector3 = body.global_transform.basis.z.normalized().rotated(Vector3.UP,turn)
	look(at+front*distance+Vector3.UP*rise,at,fov)

func shoot(name: String) -> void:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/inn-%s-%s.png" % [arg("out","look"),name])
	print("INN_SHOT ",name)

func capture():
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/preview-inn-save")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test-results"))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.run = Data.new_character("warrior")
	game.run.clock = Daylight.MORNING+300.0
	game.load_floor()
	game.set_process(false)
	game.sound.muted = true
	world = game.world
	folk = world.townsfolk
	hour = Daylight.MORNING+300.0
	world.set_time(hour)
	# The hero in the inn, so its roof and near walls are lifted away.
	var c = Interiors.INN
	game.player.position = c+Vector3(10,0,13)
	game.player.visible = false
	world.follow(game.player.position,1.0)
	folk.tick(.1,HERO)
	if game.get("hud") != null and "visible" in game.hud: game.hud.visible = false
	camera = Camera3D.new()
	camera.near = .02
	world.add_child(camera)
	camera.current = true
	var shots: Array = arg("shots","room,anya,selene,foam,drunk,candle,woman,rag,clutter").split(",")
	await step(20.0,func(): return folk.selene.state == "idle")
	for shot in shots:
		match shot:
			"room":
				look(c+Vector3(10,13,26),c+Vector3(10,0,10),45.0)
				await shoot("room")
			"anya":
				await step(60.0,func(): return folk.anya.state == "carry" and folk.anya.body.held != null)
				await step(.6)
				var mug: Vector3 = folk.anya.body.held.global_transform*Vector3(-.1,.5,0)
				frame(mug,folk.anya.body,.75,.6,.2)
				await shoot("anya")
				frame(mug,folk.anya.body,.75,-.5,.1)
				await shoot("anya2")
			"take":
				# Selene taking up plates and a mug, close.
				await step(400.0,func(): return folk.selene.state == "take" and folk.chore.picks.any(func(p): return p.kind == "plate") and folk.selene.phase_time > .5)
				var at: Vector3 = folk.chore.picks[mini(folk.chore.i,folk.chore.picks.size()-1)].get("from",Transform3D()).origin
				frame(at,folk.selene.body,1.2,.9,.6)
				await shoot("take")
				await step(.4)
				await shoot("take2")
				await step(.5)
				await shoot("take3")
			"place":
				await step(90.0,func(): return folk.anya.state == "place" and folk.anya.phase_time > .45)
				var mug: Vector3 = folk.round[0].seat.mug if not folk.round.is_empty() else folk.anya.at
				frame(mug,folk.anya.body,1.1,1.0,.45)
				await shoot("place")
				await step(.35)
				await shoot("place2")
				await step(.5)
				await shoot("place3")
			"selene","plates":
				# Selene carrying what she has cleared.
				var carrying = await step(400.0,func(): return folk.selene.state == "carry" and (shot == "selene" or folk.tray.get_child_count() > 0))
				if not carrying: continue
				await step(.8)
				var hand: Vector3 = folk.selene.body.global_transform*Vector3(0,.95,.3)
				frame(hand,folk.selene.body,1.1,.5,.35)
				await shoot(shot)
				if shot == "plates":
					var palm_at: Vector3 = folk.tray.global_position
					frame(palm_at,folk.selene.body,.6,1.4,-.02,30.0)
					await shoot("plates_side")
					frame(palm_at,folk.selene.body,.6,1.2,-.25,30.0)
					await shoot("plates_under")
				frame(hand,folk.selene.body,1.0,-.6,.15)
				await shoot(shot+"2")
			"foam","sipped","drunk","dregs":
				var drinker = folk.people.filter(func(w): return w.state == "drink" and w.mug != null)
				if drinker.is_empty():
					await step(60.0,func(): return folk.people.any(func(w): return w.state == "drink" and w.mug != null))
					drinker = folk.people.filter(func(w): return w.state == "drink" and w.mug != null)
				var w = drinker[0]
				w.sip = 1000.0
				var beer = Beer.of(w.mug)
				# (Poured full, then drunk down to this.)
				beer.fill = 0.0
				beer.fill = 1.0
				beer.fill = {"foam":1.0,"sipped":.84,"drunk":.55,"dregs":.25}[shot]
				await step(.3)
				var top: Vector3 = w.mug.global_transform*Vector3(-.125,.9,0)
				var toward: Vector3 = (-w.seat.face+w.seat.side*.5).normalized()
				look(top+toward*.26+Vector3.UP*.3,top+Vector3.DOWN*.02,28.0)
				await shoot(shot)
			"candle":
				var lit: Array = world.get_children().filter(func(n): return n.name.begins_with("LitCandles"))
				var candle: Node3D = lit.filter(func(n): return n.light != null)[0]
				var wick: Vector3 = candle.global_position+Vector3.UP*.33
				look(wick+Vector3(.45,.1,.5),wick,22.0)
				await shoot("candle")
				await step(.15)
				await shoot("candle2")
				look(wick+Vector3(-.6,.25,.4),wick+Vector3.DOWN*.05,30.0)
				await shoot("candle3")
				var tip: Vector3 = candle.flames[0].global_position+Vector3.UP*.01
				look(tip+Vector3(.25,.03,.25),tip,12.0)
				await shoot("candle_tip")
				await step(.1)
				await shoot("candle_tip2")
				candle.hearts[1].visible = false
				await shoot("candle_tongues")
				candle.hearts[1].visible = true
				# At night, the roof over the room.
				hour = Daylight.NIGHT+60.0
				world.set_time(hour)
				look(c+Vector3(5,2.2,16.5),c+Vector3(4.6,.9,12.6),40.0)
				await shoot("candle_night")
			"woman","women":
				# Women sat at the tables, waiting (their hands in their laps).
				var women = folk.people.filter(func(w): return w.body.look.who == "woman")
				var shown = 0
				for w in women:
					if shown >= (1 if shot == "woman" else 4): break
					var seat = folk.seats.filter(func(s): return s.taken == null)
					if seat.is_empty(): break
					folk.release(w)
					seat[0].taken = w
					w.seat = seat[0]
					folk.sit(w)
					await step(2.0)
					w.state = "wait"
					var lap: Vector3 = w.at+Vector3.UP*.55
					frame(lap,w.body,.95,0.35,.25,34.0)
					await shoot("%s%d" % [shot,shown])
					frame(lap,w.body,.8,1.3,.05,34.0)
					await shoot("%s%d_side" % [shot,shown])
					print("  ",w.body.name," ",w.body.look.garment," wear=",w.body.look.wear)
					shown += 1
			"rag":
				# (Nothing left about to clear first.)
				for thing in folk.litter: thing.node.queue_free()
				folk.litter.clear()
				for i in folk.wiped: folk.wiped[i] = -folk.WIPE_REST
				var wiping = await step(240.0,func(): return folk.selene.state in ["wipe","bar_wipe"] and folk.selene.phase_time > 1.0)
				var at: Vector3 = folk.rag.global_position
				frame(at,folk.selene.body,.7,.9,.35)
				await shoot("rag")
				frame(at,folk.selene.body,.6,-.8,.25)
				await shoot("rag2")
				frame(folk.selene.at+Vector3.UP*.8,folk.selene.body,2.0,.5,.6,40.0)
				await shoot("rag3")
			"hung":
				await step(120.0,func(): return folk.selene.state == "idle" and folk.rag_hung.visible and folk.selene.at.distance_to(folk.selene_spot) < .3)
				await step(1.0)
				var hip: Vector3 = folk.rag_hung.global_position
				frame(hip+Vector3.DOWN*.12,folk.selene.body,.9,.7,.1)
				await shoot("hung")
			"later":
				await step(float(arg("later","300")))
				look(c+Vector3(8,6,18),c+Vector3(8,.8,10),45.0)
				await shoot("later")
			"clutter":
				look(c+Vector3(8,6,18),c+Vector3(8,.8,10),45.0)
				await shoot("clutter")
	print("INN_DONE")
	quit(0)
