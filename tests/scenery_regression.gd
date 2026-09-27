extends SceneTree
const Save = preload("res://scripts/save.gd")
const Data = preload("res://scripts/data.gd")
var game
var passed: Array[String] = []
var failed: Array[String] = []
var rendered = false

func _initialize(): call_deferred("test")

func check(ok: bool, message: String):
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)

func frames(n: int = 3):
	for i in n: await process_frame

func capture(name: String):
	if not rendered: return
	game.hud.tick(0)
	for i in 20:
		if is_instance_valid(game.world.fountain): game.world.fountain.tick(.016,game.player.position,true)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/"+name+".png")

func test():
	rendered = "--render-scenery" in OS.get_cmdline_user_args()
	Save.directory = ProjectSettings.globalize_path("res://test-results/scenery-save-render" if rendered else "res://test-results/scenery-save")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.set_process(false)
	game.run = Data.new_run()
	game.run.seed = 0
	for index in 6:
		game.run.floor = index
		game.run.dead = []; game.run.drops = []; game.run.position = [0,9]
		game.load_floor()
		await frames()
		var world = game.world
		check(is_instance_valid(world.fountain)==(index==2),"Fountain exists only on floor 3 (%d)" % (index+1))
		check(is_instance_valid(world.desert_backdrop)==(index in [3,4]),"Desert backdrop exists only on terrace floors (%d)" % (index+1))
		if index==2:
			var fountain = world.fountain
			check(fountain.pool_bounds.size==Vector2(25,12),"Pool retains original room size and 1.5-tile inset")
			var start: Vector3 = fountain.center+Vector3(-9,0,3)
			var end: Vector3 = fountain.center+Vector3(9,0,3)
			check(world.walk_line(start,end) and not world.fits(fountain.center),"Shallow water is traversable; central stone fountain stays solid")
			var at = start
			for step in 200: at = world.move(at,(end-at).normalized()*minf(.1,at.distance_to(end)))
			check(at.distance_to(end)<.01,"Actual movement crosses the shallow pool without snagging on the trim")
			check(not world.path(fountain.center-Vector3(3,0,0),fountain.center+Vector3(3,0,0)).is_empty(),"Navigation routes around the stone centerpiece")
			var near: float = fountain.gain_at(fountain.center+Vector3(2,0,0))
			var far: float = fountain.gain_at(fountain.center+Vector3(12,0,0))
			var outside = Vector3(fountain.room_bounds.position.x-.01,0,fountain.center.z)
			check(near>far and far>0 and fountain.gain_at(outside)==0,"Original distance curve grows louder nearby and is silent outside the room")
			check(is_equal_approx(near,1.0-2.0/(Vector2(28,15).length()*.5)),"Audio attenuation matches original half-diagonal formula")
			check(fountain.ambience.stream is AudioStreamWAV and fountain.ambience.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"Original audio loops continuously")
			check(absf(fountain.ambience.stream.get_length()-14.294125)<.05,"Converted audio preserves original recording duration")
			fountain.tick(.1,fountain.center+Vector3(2,0,0),true)
			check(is_equal_approx(fountain.ambience.volume_linear,near),"Audio player receives proximity gain")
			world.zoom = 36
			world.follow(fountain.center,1)
			fountain.tick(.1,fountain.center+Vector3(2,0,0),true)
			check(is_equal_approx(fountain.ambience.volume_linear,near),"Zoom does not change player-relative audio volume")
			fountain.tick(.1,fountain.center,false)
			check(fountain.ambience.volume_linear<.00001,"Paused gameplay silences fountain ambience")
			game.sound.toggle()
			check(AudioServer.is_bus_mute(0),"Existing sound switch mutes the fountain's Master bus")
			game.sound.toggle()
			fountain.tick(.2,start,true)
			fountain.tick(.2,start+Vector3(.2,0,0),true)
			check(fountain.wake_index>0,"Wading creates animated ripples")
			world.zoom = 27
			game.player.position = fountain.center+Vector3(2.8,0,3)
			world.follow(fountain.center,1)
			await capture("fountain-court-wide")
			world.zoom = 16
			world.follow(game.player.position,1)
			await capture("fountain-court-close")
			var loop = fountain.ambience
			game.run.floor = 0
			game.load_floor()
			check(not loop.playing,"Leaving the court stops the old water loop immediately")
			await frames()
			check(not is_instance_valid(loop),"Floor changes release the fountain audio player")
		if index in [3,4]:
			check(world.desert_backdrop.global_position.y< -10 and world.desert_backdrop.texture.get_width()>=1024,"Generated desert is placed far below the terrace")
			check(not world.desert_backdrop.visible and not world.terrace_moonlight.visible,"Interior spawn hides panorama and moonlight on floor %d" % (index+1))
			var interior_batch = false
			var terrace_batch = false
			for node in world.get_children():
				if node is MultiMeshInstance3D:
					if node.layers & world.TERRACE_LIGHT_LAYER: terrace_batch = true
					else: interior_batch = true
			check(interior_batch and terrace_batch and world.terrace_moonlight.light_cull_mask==world.TERRACE_LIGHT_LAYER,"Moonlight distinguishes outdoor paving from interior batches")
			for i in world.layout.terrace_doors.size():
				var door: Rect2i = world.layout.terrace_doors[i]
				var inside: Vector3 = world.layout.to_world(world.layout.center(door))
				var direction = Vector3(-1 if index==3 else 1,0,0) if i<2 else Vector3(0,0,-1)
				world.follow(inside,1)
				check(not world.desert_backdrop.visible,"Landscape is hidden on the inside of doorway %d, floor %d" % [i,index+1])
				world.follow(inside+direction,1)
				check(world.desert_backdrop.visible and world.terrace_moonlight.visible,"Stepping out of doorway %d reveals landscape and moonlight on floor %d" % [i,index+1])
				world.follow(inside,.016)
				check(not world.desert_backdrop.visible and not world.terrace_moonlight.visible,"Stepping back inside hides landscape immediately at doorway %d, floor %d" % [i,index+1])
			var terrace: Rect2i = world.layout.terrace[0]
			var cell = terrace.position+Vector2i(2,terrace.size.y/2)
			game.player.position = world.layout.to_world(cell)
			world.zoom = 24
			world.follow(game.player.position,1)
			check(world.fits(game.player.position) and not world.fits(world.layout.to_world(cell+Vector2i(-5 if index==3 else 5,0))),"Backdrop leaves terrace collision intact on floor %d" % (index+1))
			await capture("desert-terrace-%d" % (index+1))
			for zoom in [15.0,36.0]:
				for viewport_size in [Vector2i(1280,800),Vector2i(1280,720),Vector2i(1120,700)]:
					root.size = viewport_size
					await frames(2)
					world.zoom = zoom
					world.follow(game.player.position,1)
					var visible_size = root.get_visible_rect().size
					var height: float = world.camera.size
					var width: float = height*visible_size.x/visible_size.y
					var image_size: Vector2 = world.desert_backdrop.texture.get_size()*world.desert_backdrop.pixel_size
					var image_center: Vector2 = Vector2(world.desert_backdrop.position.x,world.desert_backdrop.position.y)
					check(Rect2(image_center-image_size*.5,image_size).encloses(Rect2(-Vector2(width,height)*.5,Vector2(width,height))),"Panorama covers terrace view at zoom %s / %s" % [zoom,viewport_size])
			root.size = Vector2i(1280,800)
			world.zoom = 24
			var north: Rect2i = world.layout.terrace[1]
			game.player.position = world.layout.to_world(world.layout.center(north))
			world.follow(game.player.position,1)
			check(world.desert_backdrop.visible,"Panorama also appears on north gallery, floor %d" % (index+1))
			await capture("desert-north-terrace-%d" % (index+1))
			game.player.position = world.spawn
			world.follow(game.player.position,1)
			await capture("desert-hidden-interior-%d" % (index+1))
	var suffix = "render" if rendered else "headless"
	FileAccess.open("res://test-results/scenery-%s.json" % suffix,FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("SCENERY_REGRESSION ",suffix,": ",passed.size()," passed; ",failed)
	game.queue_free()
	await frames()
	quit(0 if failed.is_empty() else 1)
