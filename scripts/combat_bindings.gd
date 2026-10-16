extends RefCounted
## One source for live keyboard action labels and input dispatch. Assigning a
## different skill never changes its socket; InputMap remaps change its label.
const ACTIONS = ["shrine_skill_1","shrine_skill_2","shrine_skill_3","shrine_skill_4","shrine_dash","shrine_heal"]
const KEYS = [KEY_1,KEY_2,KEY_3,KEY_4,KEY_SPACE,KEY_Q]

static func ensure() -> void:
	for i in ACTIONS.size():
		if InputMap.has_action(ACTIONS[i]): continue
		InputMap.add_action(ACTIONS[i])
		var key = InputEventKey.new()
		key.physical_keycode = KEYS[i]
		InputMap.action_add_event(ACTIONS[i],key)

static func matches(event: InputEvent, index: int) -> bool:
	return event.is_action_pressed(ACTIONS[index])

static func caption(index: int) -> String:
	var events = InputMap.action_get_events(ACTIONS[index])
	if events.is_empty(): return "—"
	var key = events[0]
	if key is InputEventKey:
		return OS.get_keycode_string(key.get_physical_keycode_with_modifiers() if key.physical_keycode else key.get_keycode_with_modifiers())
	return key.as_text()
