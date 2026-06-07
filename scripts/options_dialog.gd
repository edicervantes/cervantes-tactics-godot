extends AcceptDialog
class_name OptionsDialog

var quality_option: OptionButton
var aspect_option: OptionButton
var resolution_option: OptionButton
var fullscreen_check: CheckBox
var recommended_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	title = "Opciones"
	ok_button_text = "Cerrar"
	size = Vector2i(620, 420)

	var root := VBoxContainer.new()
	root.offset_left = 16.0
	root.offset_top = 14.0
	root.offset_right = 604.0
	root.offset_bottom = 360.0
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	recommended_label = Label.new()
	recommended_label.add_theme_font_size_override("font_size", 15)
	recommended_label.add_theme_color_override("font_color", Color("#f3d78a"))
	root.add_child(recommended_label)

	var settings := _settings()
	quality_option = _add_option_row(root, "Calidad grafica", settings.QUALITY_PRESETS)
	aspect_option = _add_option_row(root, "Relacion de aspecto", settings.ASPECT_PRESETS)
	aspect_option.item_selected.connect(_on_aspect_selected)
	resolution_option = _add_resolution_row(root)

	fullscreen_check = CheckBox.new()
	fullscreen_check.text = "Pantalla completa"
	fullscreen_check.add_theme_font_size_override("font_size", 16)
	root.add_child(fullscreen_check)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	root.add_child(button_row)

	var recommended_button := Button.new()
	recommended_button.text = "Usar recomendado"
	recommended_button.custom_minimum_size = Vector2(180, 42)
	recommended_button.pressed.connect(_apply_recommended)
	button_row.add_child(recommended_button)

	var apply_button := Button.new()
	apply_button.text = "Aplicar"
	apply_button.custom_minimum_size = Vector2(140, 42)
	apply_button.pressed.connect(_apply_selected)
	button_row.add_child(apply_button)

	_refresh_from_settings()

func popup_options() -> void:
	_refresh_from_settings()
	popup_centered()

func _add_option_row(parent: VBoxContainer, label_text: String, items: Array) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := Label.new()
	label.custom_minimum_size = Vector2(190, 0)
	label.text = label_text
	label.add_theme_font_size_override("font_size", 16)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.custom_minimum_size = Vector2(0, 38)
	for item in items:
		option.add_item(str(item))
	row.add_child(option)
	return option

func _add_resolution_row(parent: VBoxContainer) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := Label.new()
	label.custom_minimum_size = Vector2(190, 0)
	label.text = "Resolucion"
	label.add_theme_font_size_override("font_size", 16)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.custom_minimum_size = Vector2(0, 38)
	var settings := _settings()
	for resolution in settings.RESOLUTION_PRESETS:
		option.add_item(settings.resolution_label(resolution))
		option.set_item_metadata(option.item_count - 1, resolution)
	row.add_child(option)
	return option

func _refresh_from_settings() -> void:
	var settings := _settings()
	recommended_label.text = "Recomendado para esta pantalla: %s" % settings.recommended_label()
	_select_text(quality_option, settings.quality)
	_select_text(aspect_option, settings.aspect_mode)
	_select_resolution(settings.resolution)
	fullscreen_check.button_pressed = settings.fullscreen

func _apply_recommended() -> void:
	var settings := _settings()
	var recommended: Dictionary = settings.recommended_settings()
	settings.apply_and_save(recommended["quality"], recommended["aspect_mode"], recommended["resolution"], recommended["fullscreen"])
	_refresh_from_settings()

func _apply_selected() -> void:
	_settings().apply_and_save(
		quality_option.get_item_text(quality_option.selected),
		aspect_option.get_item_text(aspect_option.selected),
		_selected_resolution(),
		fullscreen_check.button_pressed
	)
	_refresh_from_settings()

func _on_aspect_selected(index: int) -> void:
	var aspect := aspect_option.get_item_text(index)
	_select_resolution(_settings().recommended_resolution_for_aspect(aspect))

func _selected_resolution() -> Vector2i:
	var metadata = resolution_option.get_item_metadata(resolution_option.selected)
	if typeof(metadata) == TYPE_VECTOR2I:
		return metadata
	return _settings().resolution

func _settings() -> Node:
	return get_node("/root/GameSettings")

func _select_text(option: OptionButton, value: String) -> void:
	for i in option.item_count:
		if option.get_item_text(i) == value:
			option.select(i)
			return
	option.select(0)

func _select_resolution(value: Vector2i) -> void:
	for i in resolution_option.item_count:
		var metadata = resolution_option.get_item_metadata(i)
		if typeof(metadata) == TYPE_VECTOR2I and metadata == value:
			resolution_option.select(i)
			return
	resolution_option.select(0)
