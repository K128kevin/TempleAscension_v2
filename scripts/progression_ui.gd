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

# The character window, on the right side of the screen, at its attributes
# tab, its skills tab, or its inventory.
static func character(game) -> void:
	pause(game)
	game.hud.close_dialog()
	game.hud.panels.open_stats()

static func skills(game) -> void:
	pause(game)
	game.hud.close_dialog()
	game.hud.panels.open_skills()

static func equipment(game) -> void:
	pause(game)
	game.hud.close_dialog()
	game.hud.panels.open_inventory()

static func creation(game, difficulty: int) -> void:
	open(game,"CHOOSE YOUR CLASS","Every class starts at level 1 with five in each attribute\nand one skill point to spend on any skill it can learn.")
	var summaries = ["Warrior · sword and shield","Ranger · bow and dagger","Wizard · staff"]
	for i in 3:
		game.hud.button(summaries[i],func():
			game.creating_character = false
			game.run = Data.new_character(Data.CLASSES[i]); game.run.difficulty = difficulty
			game.load_floor(); game.save_run()
			game.toast("%s wakes in the desert. The temple lies east; the town lies west." % Data.CLASSES[i].capitalize()))
