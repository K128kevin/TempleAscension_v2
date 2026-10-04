extends RefCounted
const Data = preload("res://scripts/data.gd")
const Book = preload("res://scripts/skill_data.gd")

# Character screens pause combat.
static func pause(game) -> void:
	game.mode = "character"
	game.world.process_mode = Node.PROCESS_MODE_DISABLED
	game.left_held = false; game.right_held = false

static func open(game, title: String, subtitle: String) -> void:
	pause(game)
	game.hud.dialog(title,subtitle)

# The attribute panel, on the left side of the screen.
static func character(game) -> void:
	pause(game)
	game.hud.close_dialog()
	game.hud.panels.open_stats()

# The skill tree panel, on the right side of the screen.
static func skills(game) -> void:
	pause(game)
	game.hud.close_dialog()
	game.hud.panels.open_skills()

static func equipment(game) -> void:
	open(game,"EQUIPMENT","All classes can use all weapon families. Class skills show their requirements.\nChange equipment out of combat. Sword includes a shield. The ranger changes between bow and dagger at any time with X.")
	for i in Data.WEAPONS.size():
		var button = game.hud.button(Data.WEAPONS[i].capitalize()+(" · equipped" if game.run.weapon==i else ""),func():
			game.equip(i); equipment(game))
		button.disabled = not game.run.owned[i] or not game.out_of_combat()
	game.hud.button("Return to game",game.resume_game)

static func creation(game, difficulty: int) -> void:
	open(game,"CHOOSE YOUR CLASS","Every class starts at level 1 with five in each attribute\nand one skill point to spend on any skill it can learn.")
	var summaries = ["Warrior · sword and shield","Ranger · bow and dagger","Wizard · staff"]
	for i in 3:
		game.hud.button(summaries[i],func():
			game.creating_character = false
			game.run = Data.new_character(Data.CLASSES[i]); game.run.difficulty = difficulty
			game.load_floor(); game.save_run()
			game.toast("%s wakes in the desert. The temple lies east; the town lies west." % Data.CLASSES[i].capitalize()))
