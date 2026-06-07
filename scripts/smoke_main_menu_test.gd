extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_state: Node = root.get_node("/root/SaveState")
	save_state.save_path = "user://cervantes_smoke_menu_save.json"
	save_state.reset_all_slots()

	var menu_scene: PackedScene = load("res://scenes/MainMenu.tscn")
	var menu := menu_scene.instantiate()
	root.add_child(menu)
	await process_frame

	if menu.get_node("Root/Logo").texture == null:
		push_error("Main menu did not load the official logo texture.")
		_cleanup(save_state)
		quit(1)
		return

	if not menu.get_node("%ContinueButton").disabled:
		push_error("Continue button should be disabled with no save.")
		_cleanup(save_state)
		quit(1)
		return

	if not menu.get_node("%LoadButton").disabled:
		push_error("Load button should be disabled with no save.")
		_cleanup(save_state)
		quit(1)
		return

	if menu.get_node("%SaveStatus").text != "Sin progreso guardado":
		push_error("Menu did not show empty save status.")
		_cleanup(save_state)
		quit(1)
		return

	if menu.get_node_or_null("%OptionsButton") == null:
		push_error("Main menu did not expose an options button.")
		_cleanup(save_state)
		quit(1)
		return

	menu._on_options_pressed()
	await process_frame

	if menu.options_dialog == null or not menu.options_dialog.visible:
		push_error("Options button did not open the graphics settings dialog.")
		_cleanup(save_state)
		quit(1)
		return

	if not menu.options_dialog.recommended_label.text.contains("Recomendado"):
		push_error("Options dialog did not show an automatic recommendation.")
		_cleanup(save_state)
		quit(1)
		return

	var expected_aspects := ["16:9", "16:10", "21:9", "32:9"]
	if menu.options_dialog.aspect_option.item_count != expected_aspects.size():
		push_error("Options dialog exposed an unexpected number of aspect presets.")
		_cleanup(save_state)
		quit(1)
		return
	for i in expected_aspects.size():
		if menu.options_dialog.aspect_option.get_item_text(i) != expected_aspects[i]:
			push_error("Options dialog aspect presets did not match the production target list.")
			_cleanup(save_state)
			quit(1)
			return

	var expected_resolutions := [
		Vector2i(2560, 1440),
		Vector2i(2560, 1664),
		Vector2i(3440, 1440),
		Vector2i(5120, 1440)
	]
	if menu.options_dialog.resolution_option.item_count != expected_resolutions.size():
		push_error("Options dialog exposed an unexpected number of resolution presets.")
		_cleanup(save_state)
		quit(1)
		return
	for i in expected_resolutions.size():
		if menu.options_dialog.resolution_option.get_item_metadata(i) != expected_resolutions[i]:
			push_error("Options dialog resolution presets did not match the production target list.")
			_cleanup(save_state)
			quit(1)
			return

	menu.options_dialog.hide()

	save_state.character_progress = {
		"Erick": {
			"level": 4,
			"exp": 20,
			"exp_to_next": 160,
			"max_hp": 18,
			"attack": 6,
			"heal": 0
		}
	}
	save_state.current_slot = 1
	save_state.save_progress()
	save_state.load_progress()
	menu._refresh_save_status()

	if menu.get_node("%ContinueButton").disabled:
		push_error("Continue button should be enabled with a save.")
		_cleanup(save_state)
		quit(1)
		return

	if menu.get_node("%LoadButton").disabled:
		push_error("Load button should be enabled with a save.")
		_cleanup(save_state)
		quit(1)
		return

	if not menu.get_node("%SaveStatus").text.contains("nivel familiar maximo 4"):
		push_error("Menu did not summarize saved progress.")
		_cleanup(save_state)
		quit(1)
		return

	menu._on_new_game_pressed()
	await process_frame

	if not menu.get_node("%SlotDialog").visible:
		push_error("New game should open the slot chooser.")
		_cleanup(save_state)
		quit(1)
		return

	if menu.get_node("%SlotList").get_child_count() != save_state.SLOT_COUNT:
		push_error("Slot chooser did not render every save slot.")
		_cleanup(save_state)
		quit(1)
		return

	menu._on_slot_selected(1, false)
	await process_frame

	if not menu.get_node("%NewGameConfirm").visible:
		push_error("Occupied slot should ask for overwrite confirmation.")
		_cleanup(save_state)
		quit(1)
		return

	if not save_state.has_progress():
		push_error("Occupied slot should not reset progress before confirmation.")
		_cleanup(save_state)
		quit(1)
		return

	menu.get_node("%NewGameConfirm").hide()
	save_state.reset_progress(1)
	menu._refresh_save_status()

	if not menu.get_node("%ContinueButton").disabled:
		push_error("Continue button did not disable after reset.")
		_cleanup(save_state)
		quit(1)
		return

	_cleanup(save_state)
	quit(0)

func _cleanup(save_state: Node) -> void:
	var music_manager := root.get_node_or_null("/root/MusicManager")
	if music_manager != null:
		music_manager.stop()
	save_state.reset_all_slots()
	save_state.save_path = save_state.SAVE_PATH
	save_state.load_progress()
