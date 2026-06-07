extends Node2D
class_name ActionEffects

const WEAPON_DURATION := 0.48
const LIMIT_DURATION := 0.7
const MAGIC_DURATION := 0.72
const HEAL_DURATION := 0.68
const GUARD_DURATION := 0.58

var effects: Array[Dictionary] = []

func _process(delta: float) -> void:
	if effects.is_empty():
		return
	for effect in effects:
		effect["age"] = float(effect["age"]) + delta
	for i in range(effects.size() - 1, -1, -1):
		if float(effects[i]["age"]) >= float(effects[i]["duration"]):
			effects.remove_at(i)
	queue_redraw()

func play_weapon_attack(from_position: Vector2, to_position: Vector2, color: Color, label := "") -> void:
	_add_effect({
		"type": "weapon",
		"from": from_position,
		"to": to_position,
		"color": color,
		"label": label,
		"duration": WEAPON_DURATION,
		"age": 0.0
	})

func play_limit_break(from_position: Vector2, to_position: Vector2, color: Color, label := "CORTE") -> void:
	_add_effect({
		"type": "limit",
		"from": from_position,
		"to": to_position,
		"color": color,
		"label": label,
		"duration": LIMIT_DURATION,
		"age": 0.0
	})

func play_magic(from_position: Vector2, center_position: Vector2, radius: float, color: Color, label := "MAGIA") -> void:
	_add_effect({
		"type": "magic",
		"from": from_position,
		"center": center_position,
		"radius": radius,
		"color": color,
		"label": label,
		"duration": MAGIC_DURATION,
		"age": 0.0
	})

func play_heal(center_positions: Array[Vector2], color: Color, label := "CURA") -> void:
	_add_effect({
		"type": "heal",
		"centers": center_positions,
		"color": color,
		"label": label,
		"duration": HEAL_DURATION,
		"age": 0.0
	})

func play_guard(center_position: Vector2, color: Color, label := "DEFENSA") -> void:
	_add_effect({
		"type": "guard",
		"center": center_position,
		"color": color,
		"label": label,
		"duration": GUARD_DURATION,
		"age": 0.0
	})

func _add_effect(effect: Dictionary) -> void:
	effects.append(effect)
	queue_redraw()

func _draw() -> void:
	for effect in effects:
		var progress: float = clamp(float(effect["age"]) / float(effect["duration"]), 0.0, 1.0)
		var alpha := sin(progress * PI)
		if effect["type"] == "weapon":
			_draw_weapon_effect(effect, progress, alpha)
		elif effect["type"] == "limit":
			_draw_limit_effect(effect, progress, alpha)
		elif effect["type"] == "magic":
			_draw_magic_effect(effect, progress, alpha)
		elif effect["type"] == "heal":
			_draw_heal_effect(effect, progress, alpha)
		elif effect["type"] == "guard":
			_draw_guard_effect(effect, progress, alpha)

func _draw_weapon_effect(effect: Dictionary, progress: float, alpha: float) -> void:
	var from_position: Vector2 = effect["from"]
	var to_position: Vector2 = effect["to"]
	var color: Color = effect["color"]
	var direction := from_position.direction_to(to_position)
	if direction.length() <= 0.01:
		direction = Vector2.RIGHT
	var normal := direction.orthogonal()
	var swing_center := from_position.lerp(to_position, 0.58) + Vector2(0, -24)
	var swing_radius := 54.0
	var start_angle := atan2(direction.y, direction.x) - 1.85 + progress * 1.35
	var end_angle := start_angle + 1.55
	draw_arc(swing_center, swing_radius, start_angle, end_angle, 32, Color(color.r, color.g, color.b, 0.9 * alpha), 7.0)
	draw_arc(swing_center, swing_radius - 8.0, start_angle + 0.12, end_angle - 0.08, 28, Color(1, 1, 1, 0.72 * alpha), 2.5)
	var blade_mid := swing_center + Vector2(cos(end_angle), sin(end_angle)) * swing_radius
	var blade_root := blade_mid - direction * 46.0 - normal * 7.0
	var blade_tip := blade_mid + direction * 26.0
	var sword := PackedVector2Array([
		blade_root - normal * 5.0,
		blade_tip,
		blade_root + normal * 5.0
	])
	draw_colored_polygon(sword, Color(1, 1, 1, 0.68 * alpha))
	draw_polyline(_closed_shape(sword), Color(color.r, color.g, color.b, 0.9 * alpha), 2.0)
	draw_line(blade_root - normal * 15.0, blade_root + normal * 15.0, Color("#f6d878", 0.8 * alpha), 4.0)
	draw_arc(to_position, 30.0 + progress * 18.0, -0.4, PI + 0.4, 24, Color(color.r, color.g, color.b, 0.5 * alpha), 4.0)
	_draw_action_label(effect.get("label", ""), to_position + Vector2(-42, -74), color, alpha)

func _draw_limit_effect(effect: Dictionary, progress: float, alpha: float) -> void:
	var from_position: Vector2 = effect["from"]
	var to_position: Vector2 = effect["to"]
	var color: Color = effect["color"]
	draw_circle(to_position, 46.0 + progress * 38.0, Color(color.r, color.g, color.b, 0.14 * alpha))
	for i in 4:
		var offset := Vector2(0, -30 + i * 20)
		draw_line(from_position + offset, to_position - offset * 0.3, Color(color.r, color.g, color.b, 0.75 * alpha), 5.0)
	draw_line(from_position + Vector2(-18, -28), to_position + Vector2(28, 22), Color.WHITE, 0.9 * alpha, 6.0)
	_draw_action_label(effect.get("label", ""), to_position + Vector2(-50, -92), color, alpha)

func _draw_magic_effect(effect: Dictionary, progress: float, alpha: float) -> void:
	var from_position: Vector2 = effect["from"]
	var center: Vector2 = effect["center"]
	var radius: float = effect["radius"]
	var color: Color = effect["color"]
	var travel: float = clamp(progress * 1.35, 0.0, 1.0)
	var control := from_position.lerp(center, 0.5) + Vector2(0, -90)
	var projectile := _quadratic_bezier(from_position + Vector2(0, -34), control, center + Vector2(0, -18), travel)
	if progress < 0.82:
		draw_circle(projectile, 12.0 + sin(progress * PI * 4.0) * 4.0, Color(color.r, color.g, color.b, 0.85 * alpha))
		draw_arc(projectile, 22.0, progress * TAU, progress * TAU + PI * 1.6, 24, Color(1, 1, 1, 0.6 * alpha), 3.0)
		for i in 5:
			var t: float = max(0.0, travel - float(i) * 0.08)
			var trail := _quadratic_bezier(from_position + Vector2(0, -34), control, center + Vector2(0, -18), t)
			draw_circle(trail, 7.0 - i, Color(color.r, color.g, color.b, 0.28 * alpha))
	draw_circle(center, radius * (0.65 + progress * 0.45), Color(color.r, color.g, color.b, 0.16 * alpha))
	for ring in 3:
		draw_arc(center, radius * (0.45 + ring * 0.25 + progress * 0.2), progress * TAU + ring, progress * TAU + ring + PI * 1.35, 36, Color(color.r, color.g, color.b, 0.78 * alpha), 3.0)
	for i in 8:
		var angle := progress * TAU + float(i) * TAU / 8.0
		var end := center + Vector2(cos(angle), sin(angle) * 0.55) * radius * 0.86
		draw_line(center, end, Color(1, 1, 1, 0.18 * alpha), 2.0)
	_draw_action_label(effect.get("label", ""), center + Vector2(-42, -88), color, alpha)

func _draw_heal_effect(effect: Dictionary, progress: float, alpha: float) -> void:
	var color: Color = effect["color"]
	for center in effect["centers"]:
		draw_circle(center, 26.0 + progress * 34.0, Color(color.r, color.g, color.b, 0.16 * alpha))
		draw_arc(center, 20.0 + progress * 25.0, -PI / 2, PI * 1.5, 40, Color(color.r, color.g, color.b, 0.85 * alpha), 3.0)
		draw_line(center + Vector2(-12, -2), center + Vector2(12, -2), Color.WHITE, 0.82 * alpha, 4.0)
		draw_line(center + Vector2(0, -14), center + Vector2(0, 10), Color.WHITE, 0.82 * alpha, 4.0)
	_draw_action_label(effect.get("label", ""), Vector2(effect["centers"][0]) + Vector2(-38, -82), color, alpha)

func _draw_guard_effect(effect: Dictionary, progress: float, alpha: float) -> void:
	var center: Vector2 = effect["center"]
	var color: Color = effect["color"]
	var shield := PackedVector2Array([
		center + Vector2(0, -58 - progress * 8.0),
		center + Vector2(45, -36),
		center + Vector2(36, 14),
		center + Vector2(0, 46 + progress * 6.0),
		center + Vector2(-36, 14),
		center + Vector2(-45, -36)
	])
	draw_colored_polygon(shield, Color(color.r, color.g, color.b, 0.18 * alpha))
	draw_polyline(_closed_shape(shield), Color(color.r, color.g, color.b, 0.9 * alpha), 5.0)
	draw_arc(center, 54.0 + progress * 16.0, 0, TAU, 48, Color.WHITE, 0.28 * alpha, 2.5)
	_draw_action_label(effect.get("label", ""), center + Vector2(-52, -92), color, alpha)

func _draw_action_label(text: String, position: Vector2, color: Color, alpha: float) -> void:
	if text == "":
		return
	var font := ThemeDB.get_fallback_font()
	draw_string(font, position + Vector2(3, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.04, 0.05, 0.07, 0.82 * alpha))
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(color.r, color.g, color.b, alpha))

func _closed_shape(points: PackedVector2Array) -> PackedVector2Array:
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	return outline

func _quadratic_bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var ab := a.lerp(b, t)
	var bc := b.lerp(c, t)
	return ab.lerp(bc, t)
