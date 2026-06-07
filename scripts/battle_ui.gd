extends CanvasLayer
class_name BattleUI

const OPTIONS_DIALOG_SCRIPT := preload("res://scripts/options_dialog.gd")

signal action_requested(action: String)
signal target_requested(target_index: int)
signal unit_requested(unit_index: int)
signal end_turn_requested
signal dialog_advanced
signal chapter_intro_started
signal pause_resume_requested
signal pause_main_menu_requested
signal result_main_menu_requested

@onready var top_text: Label = %TopText
@onready var top_bar: PanelContainer = %TopBar
@onready var chapter_label: Label = %ChapterLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var conditions_label: Label = %ConditionsLabel
@onready var end_turn_button: Button = %EndTurnButton
@onready var guide_panel: PanelContainer = %GuidePanel
@onready var guide_title: Label = %GuideTitle
@onready var guide_text: Label = %GuideText
@onready var party_panel: PanelContainer = %PartyPanel
@onready var party_vbox: VBoxContainer = %PartyVBox
@onready var party_title: Label = %PartyTitle
@onready var action_panel: PanelContainer = %ActionPanel
@onready var action_title: Label = %ActionTitle
@onready var move_button: Button = %MoveButton
@onready var attack_button: Button = %AttackButton
@onready var special_button: Button = %SpecialButton
@onready var defend_button: Button = %DefendButton
@onready var wait_button: Button = %WaitButton
@onready var target_panel: PanelContainer = %TargetPanel
@onready var target_vbox: VBoxContainer = %TargetVBox
@onready var target_title: Label = %TargetTitle
@onready var unit_banner: PanelContainer = %UnitBanner
@onready var portrait_panel: PanelContainer = %PortraitPanel
@onready var portrait_texture: TextureRect = %PortraitTexture
@onready var portrait_label: Label = %PortraitLabel
@onready var banner_name: Label = %BannerName
@onready var banner_role: Label = %BannerRole
@onready var banner_state: Label = %BannerState
@onready var banner_hp_label: Label = %BannerHpLabel
@onready var banner_hp_bar: ProgressBar = %BannerHpBar
@onready var banner_stats: Label = %BannerStats
@onready var result_backdrop: ColorRect = %ResultBackdrop
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_title: Label = %ResultTitle
@onready var result_summary: Label = %ResultSummary
@onready var result_rows: VBoxContainer = %ResultRows
@onready var result_main_menu_button: Button = %ResultMainMenuButton
@onready var pause_backdrop: ColorRect = %PauseBackdrop
@onready var pause_panel: PanelContainer = %PausePanel
@onready var pause_resume_button: Button = %PauseResumeButton
@onready var pause_options_button: Button = %PauseOptionsButton
@onready var pause_main_menu_button: Button = %PauseMainMenuButton
@onready var chapter_intro_panel: PanelContainer = %ChapterIntroPanel
@onready var intro_chapter_label: Label = %IntroChapterLabel
@onready var intro_objective_label: Label = %IntroObjectiveLabel
@onready var intro_conditions_label: Label = %IntroConditionsLabel
@onready var intro_button: Button = %IntroButton
@onready var dialog_box: PanelContainer = %DialogBox
@onready var dialog_portrait_panel: PanelContainer = %DialogPortraitPanel
@onready var dialog_portrait_texture: TextureRect = %DialogPortraitTexture
@onready var dialog_portrait_label: Label = %DialogPortraitLabel
@onready var speaker_label: Label = %Speaker
@onready var dialog_text: Label = %DialogText
@onready var dialog_button: Button = %DialogButton

const SPEAKER_PORTRAITS := {
	"Erick": preload("res://assets/portraits/family/erick-avatar.png"),
	"Mitzi": preload("res://assets/portraits/family/mitzi-avatar.png"),
	"Diego": preload("res://assets/portraits/family/diego-avatar.png"),
	"Hercules": preload("res://assets/portraits/family/hercules-avatar.png"),
	"Tuffy": preload("res://assets/portraits/family/tuffy-avatar.png")
}

var options_dialog: AcceptDialog

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	options_dialog = OPTIONS_DIALOG_SCRIPT.new()
	add_child(options_dialog)
	portrait_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	dialog_portrait_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait_panel.add_theme_stylebox_override("panel", _make_portrait_frame(Color("#141013"), Color("#d19c52")))
	dialog_portrait_panel.add_theme_stylebox_override("panel", _make_portrait_frame(Color("#141013"), Color("#d19c52")))
	banner_hp_bar.add_theme_stylebox_override("background", _make_button_style(Color("#17120f"), Color("#47331f"), 1))
	banner_hp_bar.add_theme_stylebox_override("fill", _make_button_style(Color("#7bd8a2"), Color("#cfeecb"), 0))
	move_button.pressed.connect(func() -> void: action_requested.emit("move"))
	attack_button.pressed.connect(func() -> void: action_requested.emit("attack"))
	special_button.pressed.connect(func() -> void: action_requested.emit("special"))
	defend_button.pressed.connect(func() -> void: action_requested.emit("defend"))
	wait_button.pressed.connect(func() -> void: action_requested.emit("wait"))
	end_turn_button.pressed.connect(func() -> void: end_turn_requested.emit())
	dialog_button.pressed.connect(func() -> void: dialog_advanced.emit())
	intro_button.pressed.connect(func() -> void: chapter_intro_started.emit())
	pause_resume_button.pressed.connect(func() -> void: pause_resume_requested.emit())
	pause_options_button.pressed.connect(_show_options)
	pause_main_menu_button.pressed.connect(func() -> void: pause_main_menu_requested.emit())
	result_main_menu_button.pressed.connect(func() -> void: result_main_menu_requested.emit())
	hide_action_panel()
	hide_target_panel()
	hide_unit_banner()
	hide_chapter_intro()
	hide_pause_menu()
	hide_guide()
	hide_results()

func set_mission_tracker(chapter_name: String, objective: String, crystal_hp: int, crystal_max_hp: int, enemy_count: int) -> void:
	chapter_label.text = chapter_name
	objective_label.text = "%s  |  Cristal %d/%d  |  Enemigos %d" % [objective, crystal_hp, crystal_max_hp, enemy_count]
	conditions_label.visible = false

func set_mission_tracker_visible(visible: bool) -> void:
	top_bar.visible = visible

func show_chapter_intro(chapter_name: String, objective: String, victory: String, defeat: String) -> void:
	_set_combat_controls_visible(false)
	chapter_intro_panel.visible = true
	intro_chapter_label.text = chapter_name
	intro_objective_label.text = objective
	intro_conditions_label.text = "%s\n%s" % [victory, defeat]

func hide_chapter_intro() -> void:
	chapter_intro_panel.visible = false
	_set_combat_controls_visible(true)

func set_status(message: String) -> void:
	top_text.text = message

func show_guide(title: String, text: String) -> void:
	guide_panel.visible = false
	guide_title.text = title
	guide_text.text = text
	top_text.text = "%s: %s" % [title, _first_sentence(text)]

func hide_guide() -> void:
	guide_panel.visible = false

func set_end_turn_enabled(enabled: bool) -> void:
	end_turn_button.disabled = not enabled

func show_party(units: Array[Dictionary]) -> void:
	_clear_party_buttons()
	for unit in units:
		var unit_index: int = unit["index"]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 54)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.expand_icon = true
		_apply_runtime_button_style(button)
		_apply_button_portrait(button, unit)
		button.text = "%s\nHP %d/%d" % [unit["name"], unit["hp"], unit["max_hp"]]
		if unit.get("limit_charge_max", 0) > 0:
			button.text += "   LIM %d/%d" % [unit["limit_charge"], unit["limit_charge_max"]]
		if unit["acted"]:
			button.text += "   OK"
		if unit["selected"]:
			button.text = "> " + button.text
		button.disabled = not unit["alive"]
		button.pressed.connect(func() -> void:
			unit_requested.emit(unit_index)
		)
		party_vbox.add_child(button)

func show_action_panel(unit: Node) -> void:
	action_panel.visible = true
	action_title.text = unit.unit_name
	special_button.disabled = not unit.can_heal() and unit.role != "Mage" and not unit.is_limit_ready()
	if unit.can_heal():
		special_button.text = "Curar"
	elif unit.role == "Mage":
		special_button.text = "Magia"
	elif unit.can_limit_break():
		special_button.text = "Corte listo" if unit.is_limit_ready() else "Corte %d/%d" % [unit.limit_charge, unit.limit_charge_max]
	else:
		special_button.text = "Especial"

func hide_action_panel() -> void:
	action_panel.visible = false

func show_targets(targets: Array[Dictionary]) -> void:
	_clear_target_buttons()
	if targets.is_empty():
		hide_target_panel()
		return

	target_panel.visible = true
	target_title.text = "Objetivos"
	for target in targets:
		var target_index: int = target["index"]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 46)
		_apply_runtime_button_style(button)
		button.text = "%s HP %d/%d" % [target["name"], target["hp"], target["max_hp"]]
		button.pressed.connect(func() -> void:
			target_requested.emit(target_index)
		)
		target_vbox.add_child(button)

func hide_target_panel() -> void:
	target_panel.visible = false
	_clear_target_buttons()

func show_unit_banner(unit: Node, state_text: String) -> void:
	unit_banner.visible = true
	var unit_portrait: Texture2D = unit.portrait_texture
	portrait_texture.texture = unit_portrait
	portrait_texture.visible = unit_portrait != null
	portrait_label.visible = unit_portrait == null
	if unit_portrait == null:
		portrait_label.text = unit.unit_name.substr(0, 1)
		portrait_label.add_theme_color_override("font_color", unit.unit_color)
	banner_name.text = unit.unit_name
	banner_role.text = "%s / %s" % [unit.role, "Familia" if unit.team == "player" else "Orden"]
	banner_state.text = state_text
	banner_hp_label.text = "HP %d/%d" % [unit.hp, unit.max_hp]
	banner_hp_bar.max_value = unit.max_hp
	banner_hp_bar.value = unit.hp
	banner_stats.text = "MOV %d   RANGO %d%s" % [unit.move, unit.attack_range, _limit_text(unit)]

func hide_unit_banner() -> void:
	unit_banner.visible = false

func show_results(victory: bool, objective: String, rows: Array) -> void:
	_clear_result_rows()
	_set_combat_controls_visible(false)
	hide_guide()
	result_backdrop.visible = true
	result_panel.visible = true
	result_title.text = "Victoria familiar" if victory else "Derrota"
	result_summary.text = objective

	result_rows.add_child(_make_result_header())
	for row in rows:
		result_rows.add_child(_make_result_row(row))

func hide_results() -> void:
	result_panel.visible = false
	result_backdrop.visible = false
	_set_combat_controls_visible(true)
	_clear_result_rows()

func show_dialog_line(speaker: String, text: String) -> void:
	dialog_box.visible = true
	hide_guide()
	hide_unit_banner()
	hide_results()
	_set_dialog_portrait(speaker)
	speaker_label.text = speaker
	dialog_text.text = text

func hide_dialog() -> void:
	dialog_box.visible = false

func is_dialog_visible() -> bool:
	return dialog_box.visible

func show_pause_menu() -> void:
	pause_backdrop.visible = true
	pause_panel.visible = true

func hide_pause_menu() -> void:
	pause_panel.visible = false
	pause_backdrop.visible = false

func is_pause_visible() -> bool:
	return pause_panel.visible

func is_results_visible() -> bool:
	return result_panel.visible

func _show_options() -> void:
	options_dialog.popup_options()

func _clear_target_buttons() -> void:
	for child in target_vbox.get_children():
		if child != target_title:
			child.queue_free()

func _clear_party_buttons() -> void:
	for child in party_vbox.get_children():
		if child != party_title:
			child.queue_free()

func _clear_result_rows() -> void:
	for child in result_rows.get_children():
		child.queue_free()

func _make_result_header() -> HBoxContainer:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 30)
	header.add_theme_constant_override("separation", 12)
	header.add_child(_make_result_cell("Personaje", 232, 16))
	header.add_child(_make_result_cell("Nv", 64, 16))
	header.add_child(_make_result_cell("EXP", 190, 16))
	header.add_child(_make_result_cell("Subida", 120, 16))
	header.add_child(_make_result_cell("Stats", 240, 16))
	return header

func _make_result_row(row: Dictionary) -> HBoxContainer:
	var result_row := HBoxContainer.new()
	result_row.custom_minimum_size = Vector2(0, 52)
	result_row.add_theme_constant_override("separation", 12)
	result_row.add_child(_make_result_character_cell(row))
	result_row.add_child(_make_result_cell("Nv %d" % row["level"], 64, 18))
	result_row.add_child(_make_result_cell("+%d  %d/%d" % [row["gained"], row["exp"], row["exp_to_next"]], 190, 18))
	result_row.add_child(_make_result_cell(_result_level_text(row), 120, 18))
	result_row.add_child(_make_result_cell(_result_stat_text(row), 240, 18))
	return result_row

func _make_result_cell(text: String, width: int, font_size: int) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(width, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _make_result_character_cell(row: Dictionary) -> HBoxContainer:
	var cell := HBoxContainer.new()
	cell.custom_minimum_size = Vector2(232, 0)
	cell.add_theme_constant_override("separation", 10)
	cell.add_child(_make_result_portrait(row))

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 18)
	label.text = row["name"]
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.add_child(label)
	return cell

func _make_result_portrait(row: Dictionary) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(44, 44)
	frame.add_theme_stylebox_override("panel", _make_portrait_frame(Color("#141013"), Color("#8c6835")))

	var texture = row.get("portrait_texture", null)
	if texture != null:
		var image := TextureRect.new()
		image.texture = texture
		image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		frame.add_child(image)
	else:
		var label := Label.new()
		label.text = str(row["name"]).substr(0, 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20)
		frame.add_child(label)
	return frame

func _result_level_text(row: Dictionary) -> String:
	if row["level_ups"] > 0:
		return "+%d nivel" % row["level_ups"]
	return "-"

func _result_stat_text(row: Dictionary) -> String:
	var stat_notes: Array[String] = []
	if row["max_hp_gain"] > 0:
		stat_notes.append("HP +%d" % row["max_hp_gain"])
	if row["attack_gain"] > 0:
		stat_notes.append("ATQ +%d" % row["attack_gain"])
	if row["heal_gain"] > 0:
		stat_notes.append("CURA +%d" % row["heal_gain"])

	var stat_text := ""
	if not stat_notes.is_empty():
		stat_text = _join_text(stat_notes, ", ")
	return stat_text if stat_text != "" else "-"

func _limit_text(unit: Node) -> String:
	if not unit.can_limit_break():
		return ""
	if unit.is_limit_ready():
		return "   CORTE LISTO"
	return "   LIM %d/%d" % [unit.limit_charge, unit.limit_charge_max]

func _join_text(parts: Array[String], separator: String) -> String:
	var text := ""
	for i in parts.size():
		if i > 0:
			text += separator
		text += parts[i]
	return text

func _first_sentence(text: String) -> String:
	var sentence_end := text.find(".")
	if sentence_end == -1:
		return text
	return text.substr(0, sentence_end + 1)

func _apply_runtime_button_style(button: Button) -> void:
	button.add_theme_color_override("font_color", Color("#f7dc98"))
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.04, 0.055, 0.064, 0.5), Color(0.78, 0.58, 0.3, 0.4), 1))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.1, 0.14, 0.15, 0.7), Color(0.95, 0.76, 0.38, 0.74), 1))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.03, 0.045, 0.052, 0.84), Color("#8c6835"), 1))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.08, 0.08, 0.08, 0.36), Color(0.28, 0.25, 0.2, 0.36), 1))

func _apply_button_portrait(button: Button, unit: Dictionary) -> void:
	var texture = unit.get("portrait_texture", null)
	if texture == null:
		return
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.icon = texture
	button.expand_icon = true

func _set_dialog_portrait(speaker: String) -> void:
	var texture = SPEAKER_PORTRAITS.get(speaker, null)
	dialog_portrait_texture.texture = texture
	dialog_portrait_texture.visible = texture != null
	dialog_portrait_label.visible = texture == null
	if texture == null:
		dialog_portrait_label.text = speaker.substr(0, 1)

func _make_button_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(2)
	return style

func _make_portrait_frame(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 4
	style.content_margin_top = 4
	style.content_margin_right = 4
	style.content_margin_bottom = 4
	return style

func _set_combat_controls_visible(visible: bool) -> void:
	top_bar.visible = visible
	end_turn_button.visible = visible
	guide_panel.visible = false if not visible else guide_panel.visible
	party_panel.visible = visible
	action_panel.visible = false if not visible else action_panel.visible
	target_panel.visible = false if not visible else target_panel.visible
	unit_banner.visible = false if not visible else unit_banner.visible
