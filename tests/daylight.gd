extends SceneTree
## The day's cycle (scripts/daylight.gd): thirty minutes, with a ten-minute
## night, three-minute sunrise and sunset, a sun that crosses from east to
## west, moonlight, firelight by night and mist in the early morning.
const Save = preload("res://scripts/save.gd")
const Data = preload("res://scripts/data.gd")
const Daylight = preload("res://scripts/daylight.gd")
const Overworld = preload("res://scripts/overworld.gd")
var passed: Array[String] = []
var failed: Array[String] = []
func _initialize(): call_deferred("test")
func check(ok: bool, message: String):
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)
func brightness(sky: Dictionary) -> float:
	return sky.light.get_luminance()*sky.energy*maxf(sky.toward.y,0.0)+sky.ambient.get_luminance()*sky.ambient_energy
func test():
	Save.directory = ProjectSettings.globalize_path("res://test-results/daylight-save")
	var seconds = {"sunrise":0,"day":0,"sunset":0,"night":0}
	for t in int(Daylight.CYCLE): seconds[Daylight.phase(t)] += 1
	check(Daylight.CYCLE==1800.0 and seconds.night==600 and seconds.sunrise==180 and seconds.sunset==180 and seconds.day==840,"Thirty minutes: ten of night, three each of sunrise and sunset, the rest day")
	check(Daylight.phase(Daylight.START)=="night" and Data.new_character().clock==Daylight.START and Daylight.phase(Daylight.START+420.0)=="sunrise","A new character wakes in the night, some minutes before the dawn")
	# The sun crosses from east (+X) to west, highest at noon.
	var morning: Dictionary = Daylight.sky(200.0)
	var noon: Dictionary = Daylight.sky(600.0)
	var evening: Dictionary = Daylight.sky(1000.0)
	check(not noon.moon and morning.toward.x>.5 and absf(noon.toward.x)<.05 and evening.toward.x< -.5 and noon.toward.y>morning.toward.y and noon.toward.y>evening.toward.y,"The sun rises in the east, stands highest at noon and sets in the west")
	var steady = true
	var last: Vector3 = Daylight.sky(41.0).toward
	for t in range(42,1159):
		var now: Vector3 = Daylight.sky(t).toward
		steady = steady and now.x<=last.x+.0001 and now.angle_to(last)<.01 and now.y>.2
		last = now
	check(steady,"It moves smoothly westward all day, and is never followed below the horizon")
	# Night: the moon's light, darker than day but not black.
	var midnight: Dictionary = Daylight.sky(1500.0)
	check(midnight.moon and midnight.light.b>midnight.light.r and midnight.night==1.0 and midnight.toward.y>.5,"At night the light is the moon's, cool and high")
	var dark: float = brightness(midnight)/brightness(noon)
	check(dark>.12 and dark<.4 and midnight.sky.get_luminance()<.08,"The night is much darker than the day, but not black (%.0f%% as bright)" % (dark*100.0))
	var all_night = true
	for t in range(1200,1800): all_night = all_night and Daylight.sky(t).night==1.0 and Daylight.sky(t).moon
	check(all_night and noon.night==0.0,"It is full night for the whole ten minutes")
	# Golden hours.
	for at in [[110.0,"sunrise"],[1100.0,"sunset"]]:
		var sky: Dictionary = Daylight.sky(at[0])
		check(Daylight.phase(at[0])==at[1] and sky.light.r>sky.light.g*1.5 and sky.light.g>sky.light.b*1.5 and sky.sky.r>sky.sky.b*2.0 and sky.toward.y<.5 and noon.light.b>sky.light.b*2.0,"A red-gold light, low in the sky, at "+at[1])
	# No jump in the light anywhere in the cycle.
	var smooth = true
	var before: Dictionary = Daylight.sky(0.0)
	for t in range(1,1801):
		var now: Dictionary = Daylight.sky(t)
		smooth = smooth and absf(now.energy-before.energy)<.03 and absf(now.ambient_energy-before.ambient_energy)<.01 and absf(now.sky.r-before.sky.r)<.03 and absf(now.fog-before.fog)<.0003
		# The light changes hands (and so place and colour) only while it gives none.
		if now.moon != before.moon: smooth = smooth and now.energy<.02
		before = now
	check(smooth,"The light, the sky and the mist change gradually through the whole cycle, and the sun and moon change places only when neither gives light")
	# Mist in the early morning only.
	check(Daylight.sky(100.0).fog>.004 and Daylight.sky(300.0).fog>.002 and Daylight.sky(600.0).fog==0.0 and Daylight.sky(1100.0).fog==0.0 and Daylight.sky(1500.0).fog==0.0,"Mist lies through the sunrise and early morning, and at no other time")

	# In the world.
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.sound.muted = true
	game.run = Data.new_character("warrior")
	game.load_floor()
	var world = game.world
	check(world is Overworld and world.time==Daylight.START and world.night==1.0 and world.sun.light_color.b>world.sun.light_color.r,"The game begins at night, under the moon")
	var camp = world.fires.filter(func(f): return f.flame.name=="CampFire")
	check(camp.size()==1 and camp[0].light.light_cull_mask!=0 and camp[0].light.omni_range>=10.0 and camp[0].flame.base_energy>2.0 and camp[0].glow.material_override.albedo_color.a>.5 and camp[0].light.global_position.distance_to(Overworld.START+Vector3.UP*world.lift(Overworld.START))<4.0,"The campfire lights the camp on the dune")
	check(world.fires.size()>10 and world.fires.all(func(f): return f.light.light_cull_mask==world.FIRE_LAYERS and f.glow.material_override.albedo_color.a>0.0),"Every fire in the world gives light by night")
	check(not world.environment.fog_enabled,"There is no mist at night")
	var clock: float = game.run.clock
	game._process(.5)
	check(is_equal_approx(game.run.clock,clock+.5) and is_equal_approx(world.time,game.run.clock),"The clock runs as the game is played")
	check(Save.valid(game.run),"A run with a clock is valid to save")
	world.set_time(110.0)
	check(world.environment.fog_enabled and world.environment.fog_density>.004 and world.sun.light_color.r>world.sun.light_color.b*2.0 and world.sun.global_transform.basis.z.x>.5,"At sunrise a red-gold sun stands in the east, in mist")
	world.set_time(600.0)
	check(not world.environment.fog_enabled and world.night==0.0 and world.fires.all(func(f): return f.light.light_cull_mask==0 and f.glow.material_override.albedo_color.a==0.0) and world.sun.light_energy>.75,"By day the fires are seen but give no light, and the mist is gone")
	world.set_time(1000.0)
	check(world.sun.global_transform.basis.z.x< -.5,"In the evening the sun stands in the west")
	world.set_time(1500.0)
	check(world.environment.background_color.get_luminance()<.08 and world.sun.light_energy<.3 and world.sun.shadow_enabled,"At night the sky is dark and the moon casts shadows")
	# A character from before the clock finds morning; the day wraps round.
	var old = Data.new_run(); old.place = "world"; old.position = [-186,0]
	game.run = old
	game.load_floor()
	check(game.world.time==Daylight.MORNING and Daylight.phase(game.world.time)=="day","A run saved before the clock was kept wakes to a clear morning")
	game.run.clock = Daylight.CYCLE-.2
	game._process(.5)
	check(game.run.clock<1.0 and Daylight.phase(game.run.clock)=="sunrise","After the night the sun rises again")
	# Inside, the light beyond the door follows the time.
	game.run.place = "temple"; game.run.floor = 0; game.run.position = [0,9]; game.run.clock = 1500.0
	game.load_floor()
	var beyond = game.world.get_node("TempleDoorDaylight").find_children("*","MeshInstance3D",true,false)[0].material_override.albedo_color
	game.world.set_time(600.0)
	var by_day = game.world.get_node("TempleDoorDaylight").find_children("*","MeshInstance3D",true,false)[0].material_override.albedo_color
	check(beyond.get_luminance()<by_day.get_luminance()*.5,"From inside, the doorway is dark at night and bright by day")
	FileAccess.open("res://test-results/daylight.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("DAYLIGHT ",passed.size()," passed; ",failed)
	quit(1 if not failed.is_empty() else 0)
