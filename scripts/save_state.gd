extends Node

const SAVE_PATH := "user://cervantes_save.json"
const SLOT_COUNT := 3

var save_path := SAVE_PATH
var current_slot := 1
var character_progress: Dictionary = {}

func _ready() -> void:
	load_progress()

func load_progress(slot_index := 0) -> void:
	_migrate_legacy_save()
	character_progress.clear()

	if slot_index <= 0:
		slot_index = get_continue_slot()
		if slot_index <= 0:
			slot_index = current_slot

	current_slot = clampi(slot_index, 1, SLOT_COUNT)
	var data := _read_slot(current_slot)
	if data.is_empty():
		return

	var characters = data.get("characters", {})
	if typeof(characters) == TYPE_DICTIONARY:
		character_progress = characters

func load_slot(slot_index: int) -> void:
	load_progress(slot_index)

func apply_to_unit(unit: Node) -> void:
	if unit.team != "player" or not character_progress.has(unit.unit_name):
		return

	var data: Dictionary = character_progress[unit.unit_name]
	unit.level = int(data.get("level", unit.level))
	unit.exp = int(data.get("exp", unit.exp))
	unit.exp_to_next = int(data.get("exp_to_next", unit.exp_to_next))
	unit.max_hp = int(data.get("max_hp", unit.max_hp))
	unit.hp = unit.max_hp
	unit.attack = int(data.get("attack", unit.attack))
	unit.heal = int(data.get("heal", unit.heal))

func has_progress() -> bool:
	return not character_progress.is_empty()

func has_any_progress() -> bool:
	for slot in get_slots():
		if not bool(slot["empty"]):
			return true
	return false

func progress_summary() -> String:
	if character_progress.is_empty():
		if has_any_progress():
			return "Elige Cargar para seleccionar una partida"
		return "Sin progreso guardado"

	var metadata := get_slot_metadata(current_slot)
	return "Slot %d - %s - %s" % [
		current_slot,
		metadata.get("chapter", "Capitulo I"),
		_level_summary(character_progress)
	]

func capture_from_units(units: Array[Node]) -> void:
	for unit in units:
		if not is_instance_valid(unit) or unit.team != "player":
			continue
		character_progress[unit.unit_name] = {
			"level": unit.level,
			"exp": unit.exp,
			"exp_to_next": unit.exp_to_next,
			"max_hp": unit.max_hp,
			"attack": unit.attack,
			"heal": unit.heal
		}

func save_progress() -> bool:
	var file := FileAccess.open(_slot_path(current_slot), FileAccess.WRITE)
	if file == null:
		return false

	var data := {
		"version": 2,
		"slot": current_slot,
		"metadata": _build_metadata(character_progress),
		"characters": character_progress
	}
	file.store_string(JSON.stringify(data, "\t"))
	file = null
	return true

func save_units(units: Array[Node]) -> bool:
	capture_from_units(units)
	return save_progress()

func reset_progress(slot_index := 0) -> void:
	if slot_index <= 0:
		slot_index = current_slot
	slot_index = clampi(slot_index, 1, SLOT_COUNT)
	if slot_index == current_slot:
		character_progress.clear()
	if FileAccess.file_exists(_slot_path(slot_index)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot_path(slot_index)))

func reset_all_slots() -> void:
	character_progress.clear()
	for slot_index in range(1, SLOT_COUNT + 1):
		if FileAccess.file_exists(_slot_path(slot_index)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_slot_path(slot_index)))
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	current_slot = 1

func get_slots() -> Array[Dictionary]:
	_migrate_legacy_save()
	var slots: Array[Dictionary] = []
	for slot_index in range(1, SLOT_COUNT + 1):
		var data := _read_slot(slot_index)
		var metadata: Dictionary = data.get("metadata", {}) if not data.is_empty() else {}
		slots.append({
			"index": slot_index,
			"empty": data.is_empty(),
			"summary": _slot_summary(slot_index, data),
			"metadata": metadata
		})
	return slots

func get_slot_metadata(slot_index: int) -> Dictionary:
	var data := _read_slot(slot_index)
	if data.is_empty():
		return {}
	var metadata = data.get("metadata", {})
	if typeof(metadata) == TYPE_DICTIONARY:
		return metadata
	return {}

func get_continue_slot() -> int:
	var best_slot := 0
	var best_time := -1
	for slot in get_slots():
		if bool(slot["empty"]):
			continue
		var metadata: Dictionary = slot["metadata"]
		var updated_at := int(metadata.get("updated_at_unix", 0))
		if updated_at > best_time:
			best_time = updated_at
			best_slot = int(slot["index"])
	return best_slot

func start_new_slot(slot_index: int) -> void:
	current_slot = clampi(slot_index, 1, SLOT_COUNT)
	reset_progress(current_slot)

func get_current_slot_path() -> String:
	return _slot_path(current_slot)

func get_slot_path(slot_index: int) -> String:
	return _slot_path(slot_index)

func _read_slot(slot_index: int) -> Dictionary:
	var path := _slot_path(slot_index)
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _slot_path(slot_index: int) -> String:
	var prefix := save_path
	if prefix.ends_with(".json"):
		prefix = prefix.substr(0, prefix.length() - 5)
	return "%s_slot_%d.json" % [prefix, clampi(slot_index, 1, SLOT_COUNT)]

func _build_metadata(characters: Dictionary) -> Dictionary:
	return {
		"chapter": "Capitulo I",
		"updated_at_unix": Time.get_unix_time_from_system(),
		"updated_at_text": Time.get_datetime_string_from_system(false),
		"highest_level": _highest_level(characters),
		"party_count": characters.size()
	}

func _slot_summary(slot_index: int, data: Dictionary) -> String:
	if data.is_empty():
		return "Slot %d - Vacio" % slot_index

	var characters: Dictionary = data.get("characters", {})
	var metadata: Dictionary = data.get("metadata", {})
	var chapter := str(metadata.get("chapter", "Capitulo I"))
	var updated_at := str(metadata.get("updated_at_text", "sin fecha"))
	return "Slot %d - %s - %s - %s" % [
		slot_index,
		chapter,
		_level_summary(characters),
		updated_at
	]

func _level_summary(characters: Dictionary) -> String:
	return "nivel familiar maximo %d" % _highest_level(characters)

func _highest_level(characters: Dictionary) -> int:
	var highest_level := 1
	for character_name in characters.keys():
		var data: Dictionary = characters[character_name]
		highest_level = max(highest_level, int(data.get("level", 1)))
	return highest_level

func _migrate_legacy_save() -> void:
	if not FileAccess.file_exists(save_path) or FileAccess.file_exists(_slot_path(1)):
		return

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file = null
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var characters = parsed.get("characters", {})
	if typeof(characters) != TYPE_DICTIONARY or characters.is_empty():
		return

	var previous_slot := current_slot
	current_slot = 1
	character_progress = characters
	if save_progress():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	current_slot = previous_slot
