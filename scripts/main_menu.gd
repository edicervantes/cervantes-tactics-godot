extends Control

const OPTIONS_DIALOG_SCRIPT := preload("res://scripts/options_dialog.gd")

@onready var save_status: Label = %SaveStatus
@onready var continue_button: Button = %ContinueButton
@onready var load_button: Button = %LoadButton
@onready var new_game_button: Button = %NewGameButton
@onready var chapter_button: Button = %ChapterButton
@onready var options_button: Button = %OptionsButton
@onready var quit_button: Button = %QuitButton
@onready var new_game_confirm: ConfirmationDialog = %NewGameConfirm
@onready var slot_dialog: AcceptDialog = %SlotDialog
@onready var slot_hint: Label = %SlotHint
@onready var slot_list: VBoxContainer = %SlotList

var slot_dialog_mode := "load"
var pending_new_game_slot := 1
var options_dialog: AcceptDialog

func _ready() -> void:
	GameSettings.apply_display_settings()
	options_dialog = OPTIONS_DIALOG_SCRIPT.new()
	add_child(options_dialog)
	SaveState.load_progress()
	_refresh_save_status()
	continue_button.pressed.connect(_on_continue_pressed)
	load_button.pressed.connect(_on_load_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	chapter_button.pressed.connect(_on_chapter_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	new_game_confirm.confirmed.connect(_confirm_new_game_slot)

func _refresh_save_status() -> void:
	save_status.text = SaveState.progress_summary()
	continue_button.disabled = SaveState.get_continue_slot() <= 0
	load_button.disabled = not SaveState.has_any_progress()

func _on_continue_pressed() -> void:
	var slot := SaveState.get_continue_slot()
	if slot <= 0:
		_refresh_save_status()
		return
	SaveState.load_slot(slot)
	get_tree().change_scene_to_file("res://scenes/Battle3D.tscn")

func _on_load_pressed() -> void:
	_show_slot_dialog("load")

func _on_new_game_pressed() -> void:
	_show_slot_dialog("new_game")

func _show_slot_dialog(mode: String) -> void:
	slot_dialog_mode = mode
	slot_dialog.title = "Cargar partida" if mode == "load" else "Nueva partida"
	slot_hint.text = "Elige el slot que quieres cargar." if mode == "load" else "Elige un slot vacio o uno para sobrescribir."
	for child in slot_list.get_children():
		child.queue_free()

	for slot in SaveState.get_slots():
		var slot_index := int(slot["index"])
		var is_empty := bool(slot["empty"])
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 44)
		button.text = str(slot["summary"])
		_apply_slot_button_style(button)
		if slot_dialog_mode == "new_game" and not is_empty:
			button.text += " - sobrescribir"
		button.disabled = slot_dialog_mode == "load" and is_empty
		button.pressed.connect(_on_slot_selected.bind(slot_index, is_empty))
		slot_list.add_child(button)

	slot_dialog.popup_centered()

func _on_slot_selected(slot_index: int, is_empty: bool) -> void:
	slot_dialog.hide()
	if slot_dialog_mode == "load":
		SaveState.load_slot(slot_index)
		get_tree().change_scene_to_file("res://scenes/Battle3D.tscn")
		return

	pending_new_game_slot = slot_index
	if is_empty:
		_start_new_game_slot(slot_index)
		return

	new_game_confirm.dialog_text = "Esto borrara el Slot %d. Quieres empezar una partida nueva ahi?" % slot_index
	new_game_confirm.popup_centered()

func _confirm_new_game_slot() -> void:
	_start_new_game_slot(pending_new_game_slot)

func _start_new_game_slot(slot_index: int) -> void:
	SaveState.start_new_slot(slot_index)
	get_tree().change_scene_to_file("res://scenes/Battle3D.tscn")

func _on_chapter_pressed() -> void:
	if not SaveState.has_progress():
		_on_new_game_pressed()
		return
	get_tree().change_scene_to_file("res://scenes/Battle3D.tscn")

func _on_options_pressed() -> void:
	options_dialog.popup_options()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _apply_slot_button_style(button: Button) -> void:
	button.add_theme_color_override("font_color", Color("#fadd94"))
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _make_button_style(Color("#2e2113"), Color("#d19c52"), 2))
	button.add_theme_stylebox_override("hover", _make_button_style(Color("#45331a"), Color("#f2c261"), 2))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color("#1f170f"), Color("#8c6835"), 2))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color("#1f1f1f"), Color("#474036"), 1))

func _make_button_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	return style
