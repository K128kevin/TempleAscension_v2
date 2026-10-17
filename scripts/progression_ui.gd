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
# tab, its skills tab, or its inventory. The game plays on while it is open.
static func character(game) -> void:
	game.hud.close_dialog()
	game.hud.panels.open_stats()

static func skills(game) -> void:
	game.hud.close_dialog()
	game.hud.panels.open_skills()

static func equipment(game) -> void:
	game.hud.close_dialog()
	game.hud.panels.open_inventory()
