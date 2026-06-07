extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_state: Node = root.get_node("/root/SaveState")
	save_state.save_path = "user://cervantes_smoke_slots.json"
	save_state.reset_all_slots()

	save_state.current_slot = 1
	save_state.character_progress = _character_progress(2)
	if not save_state.save_progress():
		_fail(save_state, "Slot 1 did not save.")
		return

	save_state.current_slot = 2
	save_state.character_progress = _character_progress(5)
	if not save_state.save_progress():
		_fail(save_state, "Slot 2 did not save.")
		return

	if not FileAccess.file_exists(save_state.get_slot_path(1)) or not FileAccess.file_exists(save_state.get_slot_path(2)):
		_fail(save_state, "Expected slot files were not created.")
		return

	var slots: Array[Dictionary] = save_state.get_slots()
	if slots.size() != save_state.SLOT_COUNT:
		_fail(save_state, "SaveState did not return every slot.")
		return

	if bool(slots[0]["empty"]) or bool(slots[1]["empty"]) or not bool(slots[2]["empty"]):
		_fail(save_state, "Slot empty states were incorrect.")
		return

	save_state.load_slot(1)
	if save_state.current_slot != 1 or int(save_state.character_progress["Erick"]["level"]) != 2:
		_fail(save_state, "Slot 1 did not load its own progress.")
		return

	save_state.load_slot(2)
	if save_state.current_slot != 2 or int(save_state.character_progress["Erick"]["level"]) != 5:
		_fail(save_state, "Slot 2 did not load its own progress.")
		return

	save_state.reset_progress(2)
	if FileAccess.file_exists(save_state.get_slot_path(2)):
		_fail(save_state, "Resetting slot 2 left its file behind.")
		return

	save_state.load_slot(1)
	if not save_state.has_progress() or int(save_state.character_progress["Erick"]["level"]) != 2:
		_fail(save_state, "Resetting slot 2 affected slot 1.")
		return

	save_state.reset_all_slots()
	_write_legacy_save(save_state.save_path, _character_progress(7))
	save_state.load_progress()

	if FileAccess.file_exists(save_state.save_path):
		_fail(save_state, "Legacy save was not removed after migration.")
		return

	if not FileAccess.file_exists(save_state.get_slot_path(1)):
		_fail(save_state, "Legacy save was not migrated into slot 1.")
		return

	if save_state.current_slot != 1 or int(save_state.character_progress["Erick"]["level"]) != 7:
		_fail(save_state, "Migrated legacy progress did not load from slot 1.")
		return

	var metadata: Dictionary = save_state.get_slot_metadata(1)
	if int(metadata.get("highest_level", 0)) != 7:
		_fail(save_state, "Migrated slot metadata did not capture highest level.")
		return

	save_state.reset_all_slots()
	save_state.save_path = save_state.SAVE_PATH
	save_state.load_progress()
	quit(0)

func _character_progress(level: int) -> Dictionary:
	return {
		"Erick": {
			"level": level,
			"exp": 20,
			"exp_to_next": 160,
			"max_hp": 18,
			"attack": 6,
			"heal": 0
		}
	}

func _write_legacy_save(path: String, characters: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"version": 1,
		"characters": characters
	}, "\t"))

func _fail(save_state: Node, message: String) -> void:
	push_error(message)
	save_state.reset_all_slots()
	save_state.save_path = save_state.SAVE_PATH
	save_state.load_progress()
	quit(1)
