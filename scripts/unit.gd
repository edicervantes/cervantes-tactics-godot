extends Node3D
class_name TacticalUnit

var unit_name := ""
var team := ""
var role := ""
var grid := Vector2i.ZERO
var level := 1
var exp := 0
var exp_to_next := 100
var pending_exp := 0
var hp := 1
var max_hp := 1
var move := 1
var attack := 1
var attack_range := 1
var magic_aoe_radius := 0
var heal := 0
var team_heal := 0
var limit_charge := 0
var limit_charge_max := 0
var limit_damage_multiplier := 1
var trap_detection_radius := 0
var evasion_aura_radius := 0
var evasion_damage_reduction := 0
var is_noncombatant := false
var blocks_movement := true
var spiritual_aura_radius := 0
var spiritual_aura_heal := 0
var is_magic_unstable := false
var acted := false
var hint := ""
var unit_color := Color.WHITE
var portrait_texture: Texture2D
var standee_texture: Texture2D
var standee_se: Texture2D
var standee_sw: Texture2D
var standee_ne: Texture2D
var standee_nw: Texture2D
var standee_scale := 0.23
var orientation := Vector2i(1, 0)
var custom_rendered := false
var selected := false
var defending := false
var feedback_text := ""
var feedback_color := Color.WHITE
var feedback_timer := 0.0
var flash_color := Color.TRANSPARENT
var flash_timer := 0.0
var action_tween: Tween

const FEEDBACK_DURATION := 0.85
const FLASH_DURATION := 0.28
const ACTION_STEP_DURATION := 0.12
const HIT_STEP_DURATION := 0.08
const CAST_STEP_DURATION := 0.16

var orientation_3d := Vector3(1, 0, 0)
@onready var sprite_3d: Sprite3D = $Sprite3D

var hp_label: Label3D
var feedback_label: Label3D
var shadow_decal: Decal

func _ready() -> void:
	hp_label = Label3D.new()
	hp_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	hp_label.no_depth_test = true
	hp_label.render_priority = 10
	hp_label.font_size = 64
	hp_label.outline_size = 16
	hp_label.position.y = 1.8
	add_child(hp_label)
	
	feedback_label = Label3D.new()
	feedback_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	feedback_label.no_depth_test = true
	feedback_label.render_priority = 11
	feedback_label.font_size = 80
	feedback_label.outline_size = 20
	feedback_label.position.y = 2.5
	feedback_label.visible = false
	add_child(feedback_label)

	# Procedural soft shadow plane
	var shadow_mesh = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(0.8, 0.8)
	shadow_mesh.mesh = quad
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	var shadow_tex := GradientTexture2D.new()
	shadow_tex.fill = GradientTexture2D.FILL_RADIAL
	shadow_tex.fill_from = Vector2(0.5, 0.5)
	shadow_tex.fill_to = Vector2(0.5, 1.0)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.45), Color(0, 0, 0, 0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	shadow_tex.gradient = grad
	mat.albedo_texture = shadow_tex
	shadow_mesh.material_override = mat
	
	shadow_mesh.rotation_degrees.x = -90
	shadow_mesh.position.y = 0.015
	add_child(shadow_mesh)

func _process(delta: float) -> void:
	if hp_label:
		var color_hex = "eae5d9"
		var ratio = float(hp) / float(max(1, max_hp))
		if ratio <= 0.35: color_hex = "d96666"
		elif ratio <= 0.65: color_hex = "f2d180"
		hp_label.text = "[color=#%s]%d/%d[/color]" % [color_hex, hp, max_hp]
		# Fallback if rich text isn't supported directly on Label3D without bbcode
		hp_label.text = "%d/%d" % [hp, max_hp]
		hp_label.modulate = Color("#" + color_hex)

	if feedback_timer > 0.0:
		feedback_timer = max(0.0, feedback_timer - delta)
		if feedback_label:
			feedback_label.text = feedback_text
			feedback_label.modulate = feedback_color
			feedback_label.visible = true
			var sprite_height: float = 1.0
			if sprite_3d and sprite_3d.texture:
				sprite_height = float(sprite_3d.texture.get_height()) * sprite_3d.pixel_size
			var lift = (1.0 - feedback_timer / FEEDBACK_DURATION) * 1.5
			feedback_label.position.y = sprite_height + 0.5 + lift
		if feedback_timer == 0.0:
			feedback_text = ""
			if feedback_label:
				feedback_label.visible = false
	
	if flash_timer > 0.0:
		flash_timer = max(0.0, flash_timer - delta)

	if sprite_3d:
		sprite_3d.pixel_size = (standee_scale / 72.0) * 1.5
		sprite_3d.cast_shadow = 0 # GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var active_data := get_active_standee_texture()
		var tex = active_data[0]
		sprite_3d.texture = tex
		sprite_3d.flip_h = active_data[1]
		if tex != null:
			# Shift sprite up so its bottom is at the origin
			sprite_3d.offset = Vector2(0, tex.get_height() * 0.5)
			var sprite_height: float = float(tex.get_height()) * sprite_3d.pixel_size
			if hp_label:
				hp_label.position.y = sprite_height + 0.25
			
		if flash_timer > 0.0:
			sprite_3d.modulate = flash_color.lerp(Color.WHITE, 1.0 - (flash_timer / FLASH_DURATION))
		elif team == "player" and acted:
			sprite_3d.modulate = Color(0.58, 0.62, 0.66, 1.0)
		else:
			sprite_3d.modulate = Color.WHITE


func setup(data: Dictionary, spawn_position: Vector3) -> void:
	var stats: Resource = data.get("stats", null)
	if stats != null:
		_setup_from_stats(stats, data, spawn_position)
		return

	unit_name = data.get("name", "Unit")
	team = data.get("team", "neutral")
	role = data.get("role", "")
	grid = data.get("grid", Vector2i.ZERO)
	level = data.get("level", 1)
	exp = data.get("exp", 0)
	exp_to_next = data.get("exp_to_next", 100)
	pending_exp = 0
	hp = data.get("hp", 1)
	max_hp = data.get("max_hp", hp)
	move = data.get("move", 1)
	attack = data.get("attack", 1)
	attack_range = data.get("range", 1)
	magic_aoe_radius = data.get("magic_aoe_radius", 0)
	heal = data.get("heal", 0)
	team_heal = data.get("team_heal", 0)
	limit_charge = data.get("limit_charge", 0)
	limit_charge_max = data.get("limit_charge_max", 0)
	limit_damage_multiplier = data.get("limit_damage_multiplier", 1)
	trap_detection_radius = data.get("trap_detection_radius", 0)
	evasion_aura_radius = data.get("evasion_aura_radius", 0)
	evasion_damage_reduction = data.get("evasion_damage_reduction", 0)
	is_noncombatant = data.get("is_noncombatant", false)
	blocks_movement = data.get("blocks_movement", true)
	spiritual_aura_radius = data.get("spiritual_aura_radius", 0)
	spiritual_aura_heal = data.get("spiritual_aura_heal", 0)
	is_magic_unstable = data.get("is_magic_unstable", false)
	acted = data.get("acted", false)
	hint = data.get("hint", "")
	unit_color = data.get("color", Color.WHITE)
	portrait_texture = data.get("portrait_texture", null)
	standee_texture = data.get("standee_texture", null)
	standee_se = data.get("standee_se", null)
	standee_sw = data.get("standee_sw", null)
	standee_ne = data.get("standee_ne", null)
	standee_nw = data.get("standee_nw", null)
	standee_scale = data.get("standee_scale", 0.23)
	position = spawn_position

func _setup_from_stats(stats: Resource, spawn_data: Dictionary, spawn_position: Vector3) -> void:
	unit_name = stats.unit_name
	team = spawn_data.get("team", "neutral")
	role = stats.role
	grid = spawn_data.get("grid", Vector2i.ZERO)
	level = stats.level
	exp = stats.exp
	exp_to_next = stats.exp_to_next
	pending_exp = spawn_data.get("pending_exp", 0)
	hp = stats.max_hp
	max_hp = stats.max_hp
	move = stats.move
	attack = stats.attack
	attack_range = stats.attack_range
	magic_aoe_radius = stats.magic_aoe_radius
	heal = stats.heal
	team_heal = stats.team_heal
	limit_charge = spawn_data.get("limit_charge", 0)
	limit_charge_max = stats.limit_charge_max
	limit_damage_multiplier = stats.limit_damage_multiplier
	trap_detection_radius = stats.trap_detection_radius
	evasion_aura_radius = stats.evasion_aura_radius
	evasion_damage_reduction = stats.evasion_damage_reduction
	is_noncombatant = stats.is_noncombatant
	blocks_movement = stats.blocks_movement
	spiritual_aura_radius = stats.spiritual_aura_radius
	spiritual_aura_heal = stats.spiritual_aura_heal
	is_magic_unstable = spawn_data.get("is_magic_unstable", false)
	acted = spawn_data.get("acted", false)
	hint = stats.hint
	unit_color = stats.unit_color
	portrait_texture = stats.portrait_texture
	standee_texture = stats.standee_texture
	standee_se = stats.standee_se
	standee_sw = stats.standee_sw
	standee_ne = stats.standee_ne
	standee_nw = stats.standee_nw
	standee_scale = stats.standee_scale
	position = spawn_position

func move_to_grid(next_grid: Vector2i, next_position: Vector3) -> void:
	grid = next_grid
	position = next_position

func take_damage(amount: int) -> int:
	var final_amount := amount
	if defending:
		final_amount = max(1, int(ceil(float(amount) * 0.5)))
		defending = false
	hp = max(0, hp - final_amount)
	return final_amount

func heal_amount(amount: int) -> int:
	var previous_hp := hp
	hp = min(max_hp, hp + amount)
	return hp - previous_hp

func set_acted(value: bool) -> void:
	acted = value

func set_selected(value: bool) -> void:
	selected = value

func set_defending(value: bool) -> void:
	defending = value

func show_feedback(text: String, color: Color) -> void:
	feedback_text = text
	feedback_color = color
	feedback_timer = FEEDBACK_DURATION

func show_flash(color: Color) -> void:
	flash_color = color
	flash_timer = FLASH_DURATION

func play_attack_motion(target_position: Vector3, color: Color) -> void:
	_reset_action_pose()
	var home_position := position
	var direction := home_position.direction_to(target_position)
	if direction.length() <= 0.01:
		direction = Vector3(0, 0, -1)
	var windup_position := home_position - direction * 0.5 + Vector3(0, 0.2, 0)
	var strike_position := home_position + direction * 1.2 + Vector3(0, 0.1, 0)
	var turn: float = clamp(direction.x, -1.0, 1.0) * 0.12
	show_flash(color)
	action_tween = create_tween()
	action_tween.set_parallel(true)
	action_tween.set_trans(Tween.TRANS_BACK)
	action_tween.set_ease(Tween.EASE_OUT)
	action_tween.tween_property(self, "position", windup_position, ACTION_STEP_DURATION)
	action_tween.tween_property(self, "rotation:z", -turn, ACTION_STEP_DURATION)
	action_tween.tween_property(self, "scale", Vector3(0.94, 1.08, 1.0), ACTION_STEP_DURATION)
	action_tween.chain().tween_property(self, "position", strike_position, ACTION_STEP_DURATION * 0.72)
	action_tween.parallel().tween_property(self, "rotation:z", turn * 1.35, ACTION_STEP_DURATION * 0.72)
	action_tween.parallel().tween_property(self, "scale", Vector3(1.12, 0.92, 1.0), ACTION_STEP_DURATION * 0.72)
	action_tween.chain().tween_property(self, "position", home_position, ACTION_STEP_DURATION)
	action_tween.parallel().tween_property(self, "rotation:z", 0.0, ACTION_STEP_DURATION)
	action_tween.parallel().tween_property(sprite_3d, "scale", Vector3.ONE, ACTION_STEP_DURATION)
	await action_tween.finished

func play_hit_motion(source_position: Vector3, color: Color) -> void:
	_reset_action_pose()
	var home_position := position
	var direction := source_position.direction_to(home_position)
	if direction.length() <= 0.01:
		direction = Vector3(0, 0, 1)
	var recoil_position := home_position + direction * 0.8 + Vector3(0, 0.1, 0)
	var turn: float = clamp(direction.x, -1.0, 1.0) * 0.14
	show_flash(color)
	action_tween = create_tween()
	action_tween.set_parallel(true)
	action_tween.set_trans(Tween.TRANS_SINE)
	action_tween.set_ease(Tween.EASE_OUT)
	action_tween.tween_property(self, "position", recoil_position, HIT_STEP_DURATION)
	action_tween.tween_property(self, "rotation:z", turn, HIT_STEP_DURATION)
	action_tween.tween_property(self, "scale", Vector3(1.08, 0.9, 1.0), HIT_STEP_DURATION)
	action_tween.chain().tween_property(self, "position", home_position, HIT_STEP_DURATION * 1.4)
	action_tween.parallel().tween_property(self, "rotation:z", 0.0, HIT_STEP_DURATION * 1.4)
	action_tween.parallel().tween_property(sprite_3d, "scale", Vector3.ONE, HIT_STEP_DURATION * 1.4)
	await action_tween.finished

func play_cast_motion(color: Color) -> void:
	_reset_action_pose()
	var home_position := position
	show_flash(color)
	action_tween = create_tween()
	action_tween.set_parallel(true)
	action_tween.set_trans(Tween.TRANS_SINE)
	action_tween.set_ease(Tween.EASE_IN_OUT)
	action_tween.tween_property(self, "position", home_position + Vector3(0, 0.5, 0), CAST_STEP_DURATION)
	action_tween.chain().tween_property(self, "position", home_position + Vector3(0, 0.2, 0), CAST_STEP_DURATION)
	action_tween.chain().tween_property(self, "position", home_position, CAST_STEP_DURATION * 0.75)
	await action_tween.finished

func play_guard_motion(color: Color) -> void:
	_reset_action_pose()
	var home_position := position
	show_flash(color)
	action_tween = create_tween()
	action_tween.set_parallel(true)
	action_tween.set_trans(Tween.TRANS_BACK)
	action_tween.set_ease(Tween.EASE_OUT)
	action_tween.tween_property(self, "position", home_position + Vector3(0, -0.2, 0), HIT_STEP_DURATION)
	action_tween.chain().tween_property(self, "position", home_position + Vector3(0, 0.1, 0), HIT_STEP_DURATION)
	action_tween.chain().tween_property(self, "position", home_position, HIT_STEP_DURATION)
	await action_tween.finished

func _reset_action_pose() -> void:
	if action_tween != null and action_tween.is_valid():
		action_tween.kill()
	if sprite_3d:
		sprite_3d.rotation = Vector3.ZERO
		sprite_3d.scale = Vector3.ONE

func add_battle_exp(amount: int) -> void:
	if amount <= 0:
		return
	pending_exp += amount

func apply_pending_exp() -> Dictionary:
	var gained := pending_exp
	var before_level := level
	var before_max_hp := max_hp
	var before_attack := attack
	var before_heal := heal
	exp += pending_exp
	pending_exp = 0

	while exp >= exp_to_next:
		exp -= exp_to_next
		level += 1
		_apply_level_growth()
		exp_to_next += 20

	return {
		"gained": gained,
		"before_level": before_level,
		"after_level": level,
		"level_ups": level - before_level,
		"max_hp_gain": max_hp - before_max_hp,
		"attack_gain": attack - before_attack,
		"heal_gain": heal - before_heal,
		"exp": exp,
		"exp_to_next": exp_to_next
	}

func _apply_level_growth() -> void:
	var hp_gain := 2 if role == "Guardian" else 1
	max_hp += hp_gain
	hp = min(max_hp, hp + hp_gain)
	if level % 2 == 0:
		attack += 1
		if heal > 0:
			heal += 1

func is_alive() -> bool:
	return hp > 0

func can_heal() -> bool:
	return heal > 0

func can_team_heal() -> bool:
	return team_heal > 0

func can_limit_break() -> bool:
	return limit_charge_max > 0

func is_limit_ready() -> bool:
	return can_limit_break() and limit_charge >= limit_charge_max

func gain_limit_charge(amount: int) -> void:
	if not can_limit_break() or amount <= 0:
		return
	limit_charge = min(limit_charge_max, limit_charge + amount)

func reset_limit_charge() -> void:
	if not can_limit_break():
		return
	limit_charge = 0

func has_any_standee_texture() -> bool:
	return (
		standee_texture != null or
		standee_se != null or
		standee_sw != null or
		standee_ne != null or
		standee_nw != null
	)

func get_active_standee_texture() -> Array:
	var tex: Texture2D = null
	var flip := false

	var eff_orient = orientation
	var cam = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		var cam_forward = -cam.global_transform.basis.z
		var cam_right = cam.global_transform.basis.x
		var unit_forward = Vector3(float(orientation.x), 0.0, float(orientation.y)).normalized()
		if unit_forward.length() > 0.1:
			var dot_fwd = unit_forward.dot(cam_forward)
			var dot_right = unit_forward.dot(cam_right)
			if dot_fwd <= 0:
				eff_orient = Vector2i(1, 0) if dot_right >= 0 else Vector2i(0, 1)
			else:
				eff_orient = Vector2i(0, -1) if dot_right >= 0 else Vector2i(-1, 0)

	if eff_orient == Vector2i(1, 0): # SE
		if standee_se != null:
			tex = standee_se
		elif standee_texture != null:
			tex = standee_texture
	elif eff_orient == Vector2i(0, 1): # SW
		if standee_sw != null:
			tex = standee_sw
		elif standee_se != null:
			tex = standee_se
			flip = true
		elif standee_texture != null:
			tex = standee_texture
			flip = true
	elif eff_orient == Vector2i(0, -1): # NE
		if standee_ne != null:
			tex = standee_ne
		elif standee_nw != null:
			tex = standee_nw
			flip = true
		elif standee_texture != null:
			tex = standee_texture
	elif eff_orient == Vector2i(-1, 0): # NW
		if standee_nw != null:
			tex = standee_nw
		elif standee_ne != null:
			tex = standee_ne
			flip = true
		elif standee_texture != null:
			tex = standee_texture
			flip = true
	else:
		tex = standee_texture

	if tex == null:
		for candidate in [standee_se, standee_sw, standee_ne, standee_nw, standee_texture]:
			if candidate != null:
				tex = candidate
				break

	if tex == standee_texture and team == "enemy":
		flip = not flip

	return [tex, flip]
