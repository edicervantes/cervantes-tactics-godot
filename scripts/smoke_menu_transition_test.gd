extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_state: Node = root.get_node("/root/SaveState")
	save_state.save_path = "user://cervantes_smoke_menu_transition_save.json"
	save_state.reset_all_slots()

	var menu_scene: PackedScene = load("res://scenes/MainMenu.tscn")
	var menu := menu_scene.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame

	menu._start_new_game_slot(1)
	await process_frame
	await process_frame
	await process_frame

	if current_scene == null or current_scene.name != "Battle3D":
		push_error("New game did not transition from the menu into Battle3D.tscn. Current scene is: " + (current_scene.name if current_scene else "null"))
		_cleanup(save_state)
		quit(1)
		return

	# Avanzar por todos los pasos del storyboard (2 clics por paso: uno para saltar el tipeado y otro para avanzar)
	for i in range(16):
		current_scene.advance_storyboard()
		await process_frame
		await process_frame

	# Esperar a que termine la transición de fade out (1.2 segundos en end_chapter)
	await create_timer(1.8).timeout

	if current_scene == null or (current_scene.name != "Battle" and current_scene.name != "Battle3D"):
		push_error("Storyboard did not transition into Battle3D.tscn. Current scene is: " + (current_scene.name if current_scene else "null"))
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
