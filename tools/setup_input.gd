extends SceneTree
## Одноразовый инструмент: прописывает InputMap в project.godot.
## Запуск: godot --headless --path . -s res://tools/setup_input.gd

func _init() -> void:
	var actions: Dictionary = {
		"move_left": [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0), _btn(JOY_BUTTON_DPAD_LEFT)],
		"move_right": [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0), _btn(JOY_BUTTON_DPAD_RIGHT)],
		"move_up": [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _btn(JOY_BUTTON_DPAD_UP)],
		"move_down": [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _btn(JOY_BUTTON_DPAD_DOWN)],
		"run": [_key(KEY_SHIFT), _btn(JOY_BUTTON_RIGHT_SHOULDER)],
		"interact": [_key(KEY_E), _btn(JOY_BUTTON_X)],
		"open_zoo": [_key(KEY_TAB), _key(KEY_Z), _btn(JOY_BUTTON_Y)],
		"open_map": [_key(KEY_M), _btn(JOY_BUTTON_BACK)],
		"pause": [_key(KEY_ESCAPE), _btn(JOY_BUTTON_START)],
	}
	for action_name: String in actions:
		ProjectSettings.set_setting("input/" + action_name, {"deadzone": 0.25, "events": actions[action_name]})
	var err: Error = ProjectSettings.save()
	print("InputMap saved: ", error_string(err))
	quit()


func _key(code: Key) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = code
	return ev


func _btn(button: JoyButton) -> InputEventJoypadButton:
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.button_index = button
	return ev


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	return ev
