extends Node

const SETTINGS_PATH := "user://cervantes_settings.json"
const QUALITY_PRESETS := ["Baja", "Media", "Alta"]
const ASPECT_PRESETS := ["16:9", "16:10", "21:9", "32:9"]
const RESOLUTION_PRESETS := [
	Vector2i(2560, 1440),
	Vector2i(2560, 1664),
	Vector2i(3440, 1440),
	Vector2i(5120, 1440)
]

var quality := "Alta"
var aspect_mode := "16:9"
var resolution := Vector2i(2560, 1440)
var fullscreen := false
var settings_path := SETTINGS_PATH

func _ready() -> void:
	load_settings()
	apply_display_settings()

func load_settings() -> void:
	var recommended := recommended_settings()
	quality = recommended["quality"]
	aspect_mode = recommended["aspect_mode"]
	resolution = recommended["resolution"]
	fullscreen = false

	if not FileAccess.file_exists(settings_path):
		return
	var file := FileAccess.open(settings_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	quality = str(parsed.get("quality", quality))
	aspect_mode = str(parsed.get("aspect_mode", aspect_mode))
	var saved_resolution = parsed.get("resolution", {})
	if typeof(saved_resolution) == TYPE_DICTIONARY:
		resolution = Vector2i(int(saved_resolution.get("x", resolution.x)), int(saved_resolution.get("y", resolution.y)))
	fullscreen = bool(parsed.get("fullscreen", fullscreen))
	_sanitize_display_preset()

func save_settings() -> bool:
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if file == null:
		return false
	var data := {
		"quality": quality,
		"aspect_mode": aspect_mode,
		"resolution": {"x": resolution.x, "y": resolution.y},
		"fullscreen": fullscreen
	}
	file.store_string(JSON.stringify(data, "\t"))
	return true

func apply_display_settings() -> void:
	var win := get_window()
	if win == null:
		return
	if fullscreen:
		win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	else:
		win.mode = Window.MODE_WINDOWED
		win.size = resolution
		_center_window()
	
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	
	var vp := get_viewport()
	if vp:
		vp.set_scaling_3d_scale(_quality_scale())

func apply_and_save(next_quality: String, next_aspect: String, next_resolution: Vector2i, next_fullscreen: bool) -> void:
	quality = next_quality
	aspect_mode = next_aspect
	resolution = next_resolution
	fullscreen = next_fullscreen
	apply_display_settings()
	save_settings()

func recommended_settings() -> Dictionary:
	var screen_size := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var recommended_resolution := _nearest_resolution(screen_size)
	return {
		"quality": _recommended_quality(screen_size),
		"aspect_mode": _aspect_label(screen_size),
		"resolution": recommended_resolution,
		"fullscreen": false
	}

func resolution_label(size: Vector2i) -> String:
	return "%dx%d  %s" % [size.x, size.y, _aspect_label(size)]

func recommended_label() -> String:
	var recommended := recommended_settings()
	return "%s / %s / %s" % [
		resolution_label(recommended["resolution"]),
		recommended["aspect_mode"],
		recommended["quality"]
	]

func recommended_resolution_for_aspect(aspect: String) -> Vector2i:
	var screen_size := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var best := RESOLUTION_PRESETS[0]
	var best_score: float = INF
	for candidate in RESOLUTION_PRESETS:
		if _aspect_label(candidate) != aspect:
			continue
		var overflow: int = max(0, candidate.x - screen_size.x) + max(0, candidate.y - screen_size.y)
		var distance: int = abs(candidate.x - screen_size.x) + abs(candidate.y - screen_size.y)
		var score: float = float(overflow * 4 + distance)
		if score < best_score:
			best_score = score
			best = candidate
	return best

func _sanitize_display_preset() -> void:
	if not ASPECT_PRESETS.has(aspect_mode):
		aspect_mode = _aspect_label(resolution)
	if not RESOLUTION_PRESETS.has(resolution):
		resolution = recommended_resolution_for_aspect(aspect_mode)

func _nearest_resolution(screen_size: Vector2i) -> Vector2i:
	var best := RESOLUTION_PRESETS[0]
	var best_score: float = INF
	for candidate in RESOLUTION_PRESETS:
		if candidate.x > screen_size.x or candidate.y > screen_size.y:
			continue
		var score: float = abs(candidate.x - screen_size.x) + abs(candidate.y - screen_size.y)
		if score < best_score:
			best_score = score
			best = candidate
	return best

func _recommended_quality(screen_size: Vector2i) -> String:
	var pixels := screen_size.x * screen_size.y
	if pixels >= 3600000:
		return "Alta"
	if pixels >= 1900000:
		return "Media"
	return "Baja"

func _aspect_label(size: Vector2i) -> String:
	if size == Vector2i(2560, 1440):
		return "16:9"
	if size == Vector2i(2560, 1664):
		return "16:10"
	if size == Vector2i(3440, 1440):
		return "21:9"
	if size == Vector2i(5120, 1440):
		return "32:9"
	var aspect := float(size.x) / float(max(1, size.y))
	if aspect >= 3.2:
		return "32:9"
	if aspect >= 2.25:
		return "21:9"
	if aspect >= 1.7 and aspect <= 1.85:
		return "16:9"
	if aspect >= 1.5 and aspect < 1.7:
		return "16:10"
	return "16:9"

func _quality_scale() -> float:
	if quality == "Baja":
		return 0.8
	if quality == "Media":
		return 0.9
	return 1.0

func _center_window() -> void:
	var win := get_window()
	if win == null:
		return
	var screen := win.current_screen
	var screen_size := DisplayServer.screen_get_size(screen)
	win.position = (screen_size - resolution) / 2
