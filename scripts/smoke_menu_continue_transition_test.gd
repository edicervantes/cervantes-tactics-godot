extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_state: Node = root.get_node("/root/SaveState")
	save_state.save_path = "user://cervantes_smoke_menu_continue_save.json"
	save_state.reset_all_slots()
	save_state.current_slot = 1
	save_state.character_progress = {
		"Erick": {
			"level": 2,
			"exp": 10,
			"exp_to_next": 120,
			"max_hp": 16,
			"attack": 5,
			"heal": 0
		}
	}
	save_state.save_progress()
	save_state.load_progress()

	var menu_scene: PackedScene = load("res://scenes/MainMenu.tscn")
	var menu := menu_scene.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame

	if menu.get_node("%ContinueButton").disabled:
		push_error("Continue button was disabled even though a save slot exists.")
		_cleanup(save_state)
		quit(1)
		return

	menu._on_continue_pressed()
	await process_frame
	await process_frame

	if current_scene == null or (current_scene.name != "Battle" and current_scene.name != "Battle3D"):
		push_error("Continue did not transition from the menu into Battle3D.tscn.")
		_cleanup(save_state)
		quit(1)
		return

	if current_scene.get_node_or_null("%BattleUI") == null:
		push_error("Battle scene loaded without its BattleUI node.")
		_cleanup(save_state)
		quit(1)
		return

	_cleanup(save_state)
	quit(0)

func _cleanup(save_state: Node) -> void:
	save_state.reset_all_slots()
	save_state.save_path = save_state.SAVE_PATH
	save_state.load_progress()
