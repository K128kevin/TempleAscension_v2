extends SceneTree
## Bandits hurled together by blasts in the arena basement's narrow ways,
## against its walls and floor: every body stays whole (no limb pulled away
## from the part it hangs from) and on the ground (none flung up past a
## man's height, nor sunk through the floor).
const Data = preload("res://scripts/data.gd")
const Fragment = preload("res://scripts/stone_fragment.gd")
const Ragdoll = preload("res://scripts/ragdoll.gd")
# Each limb, and the part it hangs from.
const JOINTS = [["spine_01","pelvis"],["spine_03","spine_01"],["Head","spine_03"],["upperarm_l","spine_03"],["lowerarm_l","upperarm_l"],["upperarm_r","spine_03"],["lowerarm_r","upperarm_r"],["thigh_l","pelvis"],["calf_l","thigh_l"],["foot_l","calf_l"],["thigh_r","pelvis"],["calf_r","thigh_r"],["foot_r","calf_r"]]
# How far a joint may give, how high a limb may be thrown, how far below the
# floor it may sink.
const GIVE = .2
const HIGHEST = 3.5
const LOWEST = -.3
var passed = 0
var failed: Array[String] = []
func check(ok: bool, message: String):
	if ok: passed += 1
	else: failed.append(message); push_error(message)
func origin(b: PhysicalBone3D) -> Vector3:
	return (b.global_transform*b.body_offset.affine_inverse()).origin
func _initialize(): call_deferred("test")
func test():
	preload("res://scripts/save.gd").directory = ProjectSettings.globalize_path("res://test-results/ragdoll-stability-save")
	for run_seed in [4242,1,77]:
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		game.test_mode = true
		game.set_process(false)
		game.sound.muted = true
		game.run = Data.new_run("warrior"); game.run.seed = run_seed
		game.run.place = "basement"; game.run.floor = 0
		game.load_floor()
		game.mode = "playing"
		game.world.ensure_debris_collision()
		var rng = RandomNumberGenerator.new(); rng.seed = 7
		var victims: Array = game.enemies.slice(0,30)
		for v in victims:
			game.player.position = v.position+Vector3(1,0,1)
			v.hit(1000000,"physical",0.0,Fragment.impact(Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1)),true))
		await physics_frame
		await process_frame
		var rest: Dictionary = {}
		var give = 0.0
		var high = 0.0
		var low = 0.0
		for frame in 150:
			for v in victims: v.tick(1.0/60)
			await physics_frame
			await process_frame
			for v in victims:
				if v.visual.ragdoll == null: continue
				var parts: Dictionary = {}
				for b in Ragdoll.bodies(v.visual.ragdoll): parts[String(b.bone_name)] = b
				if not rest.has(v):
					rest[v] = {}
					for j in JOINTS: rest[v][j[0]] = origin(parts[j[0]]).distance_to(origin(parts[j[1]]))
				for j in JOINTS: give = maxf(give,origin(parts[j[0]]).distance_to(origin(parts[j[1]]))-rest[v][j[0]])
				for b in parts.values():
					high = maxf(high,b.global_position.y)
					low = minf(low,b.global_position.y)
		check(give < GIVE,"Thirty bandits blasted together stay whole (joints give %.2f m at most): seed %d" % [give,run_seed])
		check(high < HIGHEST and low > LOWEST,"and on the ground (%.2f to %.2f m): seed %d" % [low,high,run_seed])
		game.queue_free()
		await process_frame
	print("RAGDOLL_STABILITY ",passed," passed; ",failed)
	quit(0 if failed.is_empty() else 1)
