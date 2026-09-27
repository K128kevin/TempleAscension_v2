extends SceneTree
const Save=preload("res://scripts/save.gd")
const Data=preload("res://scripts/data.gd")
var game
var passed: Array=[]
var failed: Array=[]
func _initialize(): call_deferred("test")
func check(ok: bool, message: String):
	if ok: passed.append(message)
	else: failed.append(message); push_error(message)
func key(code: int, ctrl: bool=false):
	var event=InputEventKey.new()
	event.physical_keycode=code; event.ctrl_pressed=ctrl; event.pressed=true
	Input.parse_input_event(event); Input.flush_buffered_events()
	event=event.duplicate(); event.pressed=false
	Input.parse_input_event(event); Input.flush_buffered_events()
func test():
	var base=ProjectSettings.globalize_path("res://test-results/debug-class-isolation")
	Save.directory=base
	var regular=Data.new_run("ranger"); regular.seed=93741
	Save.write(regular)
	var original=FileAccess.get_file_as_bytes(base.path_join("run.json"))
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.test_mode=true; game.set_process(false)
	var debug=game.debug
	if not debug.enabled:
		check(not is_instance_valid(debug.panel) and game.run.class_id=="ranger" and game.run.seed==93741,"Normal launch loads its character without debug UI")
		var generation=game.run_generation
		for code in [KEY_R,KEY_T,KEY_N,KEY_B,KEY_L,KEY_H,KEY_J,KEY_F9,KEY_G,KEY_F,KEY_F10]: key(code)
		check(game.run_generation==generation and game.remaining()==24,"Debug shortcuts are gated")
		key(KEY_K)
		check(game.mode=="character","K opens the ordinary skills screen")
		key(KEY_ESCAPE)
		key(KEY_C)
		check(game.mode=="character","C opens ordinary attributes")
	else:
		check(Save.directory==base.path_join("debug"),"Debug uses an isolated save")
		key(KEY_R)
		check(game.run.stats==[5,5,5,5,5] and game.run.level==1,"Debug reset restores new progression baseline")
		key(KEY_G); game.hurt_player(10000)
		check(not game.player.dead and game.player.hp==100,"God mode protects player")
		key(KEY_H); key(KEY_J)
		game.player.busy=0; game.combat_age=10; game.equip(2)
		check(game.run.owned[3] and game.run.weapon==2,"Debug grants weapons usable through equipment")
		Data.gain_xp(game.run,Data.xp_at_level(4))
		var points=game.run.points
		for i in 5:
			key(KEY_1+i,true)
			check(game.run.floor==i and game.run.points==points and game.run.weapon==2,"Floor jump preserves character budget and equipment")
		key(KEY_L); key(KEY_N)
		check(game.run.floor==1 and game.run.points==points and game.mode=="playing","Debug next floor grants no points")
		key(KEY_B)
		check(game.run.floor==5 and game.run.level==25 and game.run.points==72,"Boss playtest shortcut grants level 25 through XP")
		key(KEY_B)
		check(game.run.points==72,"Repeated boss shortcut cannot duplicate level awards")
		key(KEY_K)
		check(game.mode=="character","K remains skills in debug mode")
		key(KEY_ESCAPE)
		key(KEY_F9)
		check(game.boss.dead and game.crown_available,"F9 clears enemies and releases crown")
		key(KEY_T); key(KEY_F10)
		check(game.mode=="ending" and game.run.completed,"F10 opens the ending")
		key(KEY_L)
		check(game.mode=="playing" and game.run.floor==0,"Floor jumps recover from ending")
		game.save_run()
		check(FileAccess.get_file_as_bytes(base.path_join("run.json"))==original,"Debug actions never modify the regular save")
		check(not Save.load_run().is_empty(),"Debug character remains save-valid")
	var suffix="debug" if debug.enabled else "normal"
	FileAccess.open("res://test-results/debug-"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"failed":failed},"  "))
	print("DEBUG_REGRESSION ",suffix," ",passed.size()," passed; ",failed)
	game.queue_free(); await process_frame; await process_frame
	quit(0 if failed.is_empty() else 1)
