extends Node3D
class_name BoardPiece

var piece_kind := ""
var grid := Vector2i.ZERO
var grid_height := 0
var crystal_hp := 0
var crystal_max_hp := 0
var crystal_color := Color("#9fd4ff")
var feedback_text := ""
var feedback_timer := 0.0
var feedback_color := Color.WHITE
var custom_rendered := false

const BANNER_SCENE := preload("res://assets/3d/banner.glb")
const FLOOR_DECORATED := preload("res://assets/3d/floor_tile_decorated.glb")

var mesh_instance: Node3D
var hp_label: Label3D
var feedback_label: Label3D

func setup(kind: String, next_grid: Vector2i, next_height: int, world_position: Vector3) -> void:
	piece_kind = kind
	grid = next_grid
	grid_height = next_height
	position = world_position
	_build_3d_mesh()

func update_crystal_state(hp: int, max_hp: int, color: Color, next_feedback_text: String, next_feedback_timer: float, next_feedback_color: Color) -> void:
	crystal_hp = hp
	crystal_max_hp = max_hp
	crystal_color = color
	feedback_text = next_feedback_text
	feedback_timer = next_feedback_timer
	feedback_color = next_feedback_color

	if hp_label:
		hp_label.text = "%d/%d" % [crystal_hp, crystal_max_hp]
	if feedback_label:
		if feedback_timer > 0.0 and feedback_text != "":
			feedback_label.text = feedback_text
			feedback_label.modulate = feedback_color
			var lift: float = (1.0 - feedback_timer / 0.9) * 1.5
			feedback_label.position.y = 2.5 + lift
			feedback_label.visible = true
		else:
			feedback_label.visible = false

func _process(delta: float) -> void:
	if piece_kind == "crystal" and mesh_instance:
		var crystal_pivot = mesh_instance.get_node_or_null("CrystalPivot")
		if crystal_pivot:
			crystal_pivot.rotation.y += delta * 1.5
			var float_offset := sin(Time.get_ticks_msec() / 400.0) * 0.1
			crystal_pivot.position.y = 1.0 + float_offset

func _build_3d_mesh() -> void:
	if mesh_instance:
		mesh_instance.queue_free()

	match piece_kind:
		"crystal":
			mesh_instance = Node3D.new()
			add_child(mesh_instance)

			# 1. Circular stone step
			var step_mesh = CylinderMesh.new()
			step_mesh.top_radius = 0.44
			step_mesh.bottom_radius = 0.44
			step_mesh.height = 0.12
			step_mesh.radial_segments = 12
			var step_inst = MeshInstance3D.new()
			step_inst.mesh = step_mesh
			step_inst.position.y = 0.06
			var step_mat = StandardMaterial3D.new()
			var stone_tex = load("res://assets/3d/Textures/stylized_stone_floor.png")
			step_mat.albedo_texture = stone_tex
			step_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			step_mat.albedo_color = Color("#3e474a")
			step_mat.roughness = 0.88
			step_mat.metallic = 0.05
			step_inst.material_override = step_mat
			mesh_instance.add_child(step_inst)

			# 2. Golden ring trim
			var gold_mesh = CylinderMesh.new()
			gold_mesh.top_radius = 0.35
			gold_mesh.bottom_radius = 0.35
			gold_mesh.height = 0.06
			gold_mesh.radial_segments = 12
			var gold_inst = MeshInstance3D.new()
			gold_inst.mesh = gold_mesh
			gold_inst.position.y = 0.14
			var gold_mat = StandardMaterial3D.new()
			gold_mat.albedo_color = Color("#c5aa6a")
			gold_mat.metallic = 0.92
			gold_mat.roughness = 0.2
			gold_inst.material_override = gold_mat
			mesh_instance.add_child(gold_inst)

			# 4. Small decorative candles
			var candle_positions := [
				Vector3(0.3, 0.12, 0.2),
				Vector3(-0.25, 0.12, -0.25),
				Vector3(0.18, 0.12, -0.3)
			]
			for c_pos in candle_positions:
				var candle := Node3D.new()
				candle.position = c_pos
				mesh_instance.add_child(candle)

				var wax := MeshInstance3D.new()
				var wax_mesh := CylinderMesh.new()
				wax_mesh.top_radius = 0.018
				wax_mesh.bottom_radius = 0.022
				wax_mesh.height = randf_range(0.05, 0.09)
				wax_mesh.radial_segments = 6
				wax.mesh = wax_mesh
				wax.position.y = wax_mesh.height * 0.5
				var wax_mat := StandardMaterial3D.new()
				wax_mat.albedo_color = Color("#ebe4d0")
				wax_mat.roughness = 0.8
				wax.material_override = wax_mat
				candle.add_child(wax)

				var flame := MeshInstance3D.new()
				var flame_mesh := SphereMesh.new()
				flame_mesh.radius = 0.012
				flame_mesh.height = 0.026
				flame.mesh = flame_mesh
				flame.position.y = wax_mesh.height + 0.013
				var flame_mat := StandardMaterial3D.new()
				flame_mat.albedo_color = Color("#ffaa44")
				flame_mat.emission_enabled = true
				flame_mat.emission = Color("#ff6600")
				flame_mat.emission_energy_multiplier = 1.2
				flame.material_override = flame_mat
				candle.add_child(flame)

			# 5. Faceted crystal setup
			var crystal_pivot = Node3D.new()
			crystal_pivot.name = "CrystalPivot"
			crystal_pivot.position.y = 0.55
			mesh_instance.add_child(crystal_pivot)

			var mat = ShaderMaterial.new()
			mat.shader = load("res://shaders/crystal_shader.gdshader")
			mat.set_shader_parameter("crystal_color", crystal_color.darkened(0.08))
			mat.set_shader_parameter("core_color", Color("#1559a7"))
			mat.set_shader_parameter("rim_color", Color("#bfefff"))
			mat.set_shader_parameter("emission_energy", 1.15)
			mat.set_shader_parameter("facet_contrast", 1.05)

			var top_mesh = CylinderMesh.new()
			top_mesh.radial_segments = 6
			top_mesh.rings = 1
			top_mesh.top_radius = 0.0
			top_mesh.bottom_radius = 0.25
			top_mesh.height = 0.64
			var top_inst = MeshInstance3D.new()
			top_inst.mesh = top_mesh
			top_inst.material_override = mat
			top_inst.position.y = 0.32
			crystal_pivot.add_child(top_inst)

			var bot_mesh = CylinderMesh.new()
			bot_mesh.radial_segments = 6
			bot_mesh.rings = 1
			bot_mesh.top_radius = 0.0
			bot_mesh.bottom_radius = 0.25
			bot_mesh.height = 0.64
			var bot_inst = MeshInstance3D.new()
			bot_inst.mesh = bot_mesh
			bot_inst.material_override = mat
			bot_inst.rotation_degrees.x = 180
			bot_inst.position.y = -0.32
			crystal_pivot.add_child(bot_inst)

			var edge_mat := StandardMaterial3D.new()
			edge_mat.albedo_color = Color("#98e4ff")
			edge_mat.emission_enabled = true
			edge_mat.emission = Color("#55bfff")
			edge_mat.emission_energy_multiplier = 0.55
			edge_mat.roughness = 0.25
			for i in 6:
				var edge := MeshInstance3D.new()
				var edge_mesh := BoxMesh.new()
				edge_mesh.size = Vector3(0.012, 0.62, 0.014)
				edge.mesh = edge_mesh
				edge.material_override = edge_mat
				var angle := float(i) * TAU / 6.0 + PI / 6.0
				edge.position = Vector3(cos(angle) * 0.205, 0.0, sin(angle) * 0.205)
				edge.rotation_degrees.y = -rad_to_deg(angle)
				crystal_pivot.add_child(edge)

			var waist := MeshInstance3D.new()
			var waist_mesh := TorusMesh.new()
			waist_mesh.inner_radius = 0.225
			waist_mesh.outer_radius = 0.245
			waist.mesh = waist_mesh
			waist.material_override = edge_mat
			waist.scale.y = 0.04
			crystal_pivot.add_child(waist)

			for i in 4:
				var chip := MeshInstance3D.new()
				var chip_mesh := CylinderMesh.new()
				chip_mesh.radial_segments = 5
				chip_mesh.rings = 1
				chip_mesh.top_radius = 0.0
				chip_mesh.bottom_radius = 0.055
				chip_mesh.height = 0.24
				chip.mesh = chip_mesh
				chip.material_override = mat
				var angle := float(i) * TAU / 4.0 + 0.45
				chip.position = Vector3(cos(angle) * 0.18, -0.02 + float(i % 2) * 0.08, sin(angle) * 0.18)
				chip.rotation_degrees = Vector3(18.0, rad_to_deg(angle), -10.0)
				crystal_pivot.add_child(chip)

			var light = OmniLight3D.new()
			light.light_color = Color("#60B0FF")
			light.light_energy = 1.05
			light.omni_range = 4.0
			light.shadow_enabled = true
			crystal_pivot.add_child(light)

			hp_label = Label3D.new()
			hp_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			hp_label.pixel_size = 0.015
			hp_label.position.y = 2.2
			hp_label.outline_render_priority = 0
			hp_label.outline_modulate = Color.BLACK
			hp_label.outline_size = 6
			hp_label.text = "%d/%d" % [crystal_hp, crystal_max_hp]
			add_child(hp_label)

			feedback_label = Label3D.new()
			feedback_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			feedback_label.pixel_size = 0.02
			feedback_label.position.y = 2.5
			feedback_label.outline_size = 8
			feedback_label.visible = false
			add_child(feedback_label)

		"column":
			mesh_instance = Node3D.new()
			add_child(mesh_instance)
			var column_mat := _make_stone_material(Color("#6f7e78"))
			var dark_mat := _make_stone_material(Color("#3d4847"))
			var gold_trim_mat := _make_metal_material(Color("#a8884a"))

			var shaft := MeshInstance3D.new()
			var shaft_mesh := CylinderMesh.new()
			shaft_mesh.top_radius = 0.105
			shaft_mesh.bottom_radius = 0.12
			shaft_mesh.height = 0.54
			shaft_mesh.radial_segments = 10
			shaft.mesh = shaft_mesh
			shaft.material_override = column_mat
			shaft.position.y = 0.29
			mesh_instance.add_child(shaft)

			for i in 5:
				var flute := MeshInstance3D.new()
				var flute_mesh := BoxMesh.new()
				flute_mesh.size = Vector3(0.015, 0.44, 0.018)
				flute.mesh = flute_mesh
				flute.material_override = dark_mat
				var angle := float(i) * TAU / 5.0
				flute.position = Vector3(cos(angle) * 0.118, 0.30, sin(angle) * 0.118)
				flute.rotation_degrees.y = -rad_to_deg(angle)
				mesh_instance.add_child(flute)

			var cap := MeshInstance3D.new()
			var cap_mesh := CylinderMesh.new()
			cap_mesh.top_radius = 0.17
			cap_mesh.bottom_radius = 0.15
			cap_mesh.height = 0.065
			cap_mesh.radial_segments = 10
			cap.mesh = cap_mesh
			cap.material_override = column_mat
			cap.position.y = 0.59
			mesh_instance.add_child(cap)

			var plinth := MeshInstance3D.new()
			var plinth_mesh := CylinderMesh.new()
			plinth_mesh.top_radius = 0.18
			plinth_mesh.bottom_radius = 0.22
			plinth_mesh.height = 0.075
			plinth_mesh.radial_segments = 10
			plinth.mesh = plinth_mesh
			plinth.material_override = column_mat
			plinth.position.y = 0.04
			mesh_instance.add_child(plinth)

			for y in [0.12, 0.51]:
				var band := MeshInstance3D.new()
				var band_mesh := CylinderMesh.new()
				band_mesh.top_radius = 0.128
				band_mesh.bottom_radius = 0.128
				band_mesh.height = 0.025
				band_mesh.radial_segments = 10
				band.mesh = band_mesh
				band.material_override = gold_trim_mat
				band.position.y = y
				mesh_instance.add_child(band)

		"obelisk":
			mesh_instance = Node3D.new()
			add_child(mesh_instance)
			var ob_mat := StandardMaterial3D.new()
			ob_mat.albedo_texture = load("res://assets/3d/Textures/stylized_stone_floor.png")
			ob_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			ob_mat.albedo_color = Color("#55405f")
			ob_mat.roughness = 0.9
			var ob_dark_mat := _make_stone_material(Color("#33223d"))
			var ob_trim_mat := _make_metal_material(Color("#8a6746"))

			var ob_base := MeshInstance3D.new()
			var ob_base_mesh := CylinderMesh.new()
			ob_base_mesh.top_radius = 0.19
			ob_base_mesh.bottom_radius = 0.23
			ob_base_mesh.height = 0.07
			ob_base_mesh.radial_segments = 6
			ob_base.mesh = ob_base_mesh
			ob_base.material_override = ob_mat
			ob_base.position.y = 0.035
			mesh_instance.add_child(ob_base)

			var ob_shaft := MeshInstance3D.new()
			var ob_shaft_mesh := CylinderMesh.new()
			ob_shaft_mesh.top_radius = 0.105
			ob_shaft_mesh.bottom_radius = 0.145
			ob_shaft_mesh.height = 0.66
			ob_shaft_mesh.radial_segments = 6
			ob_shaft.mesh = ob_shaft_mesh
			ob_shaft.material_override = ob_mat
			ob_shaft.position.y = 0.38
			ob_shaft.rotation_degrees.y = 30.0
			mesh_instance.add_child(ob_shaft)

			var ob_tip := MeshInstance3D.new()
			var ob_tip_mesh := CylinderMesh.new()
			ob_tip_mesh.top_radius = 0.0
			ob_tip_mesh.bottom_radius = 0.115
			ob_tip_mesh.height = 0.16
			ob_tip_mesh.radial_segments = 6
			ob_tip.mesh = ob_tip_mesh
			ob_tip.material_override = ob_mat
			ob_tip.position.y = 0.79
			ob_tip.rotation_degrees.y = 30.0
			mesh_instance.add_child(ob_tip)

			for y in [0.14, 0.62]:
				var band := MeshInstance3D.new()
				var band_mesh := CylinderMesh.new()
				band_mesh.top_radius = 0.15
				band_mesh.bottom_radius = 0.15
				band_mesh.height = 0.026
				band_mesh.radial_segments = 6
				band.mesh = band_mesh
				band.material_override = ob_trim_mat
				band.position.y = y
				band.rotation_degrees.y = 30.0
				mesh_instance.add_child(band)

			var chip_mesh := BoxMesh.new()
			chip_mesh.size = Vector3(0.052, 0.04, 0.016)
			for i in 3:
				var angle := float(i) * TAU / 3.0 + 0.3
				var chip := MeshInstance3D.new()
				chip.mesh = chip_mesh
				chip.material_override = ob_dark_mat
				chip.position = Vector3(cos(angle) * 0.145, 0.30 + float(i) * 0.13, sin(angle) * 0.145)
				chip.rotation_degrees.y = -rad_to_deg(angle)
				mesh_instance.add_child(chip)

		"banner":
			mesh_instance = BANNER_SCENE.instantiate()
			mesh_instance.scale = Vector3(0.42, 0.42, 0.42)
			mesh_instance.position.y = 0.0
			_apply_stylized_tint(mesh_instance, Color("#51345f"), true)
			add_child(mesh_instance)

func _apply_nearest_filter(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var orig_mat = child.get_active_material(0)
			if orig_mat is StandardMaterial3D:
				var new_mat := orig_mat.duplicate() as StandardMaterial3D
				new_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				child.material_override = new_mat
		_apply_nearest_filter(child)

func _make_stone_material(tint: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/tile_shader.gdshader")
	mat.set_shader_parameter("base_texture", load("res://assets/3d/Textures/stylized_stone_floor.png"))
	mat.set_shader_parameter("zone_tint", tint)
	mat.set_shader_parameter("tint_strength", 0.62)
	mat.set_shader_parameter("is_prop", true)
	return mat

func _make_metal_material(tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.metallic = 0.55
	mat.roughness = 0.34
	return mat

func _apply_stylized_tint(node: Node, albedo_color: Color, keep_texture: bool = true) -> void:
	var stone_tex = load("res://assets/3d/Textures/stylized_stone_floor.png")
	var tile_shader = load("res://shaders/tile_shader.gdshader")

	if node is MeshInstance3D:
		var orig_mat = node.get_active_material(0)
		if orig_mat == null and node.mesh != null and node.mesh.get_surface_count() > 0:
			orig_mat = node.mesh.surface_get_material(0)

		if keep_texture and orig_mat is StandardMaterial3D and orig_mat.albedo_texture != null:
			var new_mat := StandardMaterial3D.new()
			new_mat.albedo_texture = orig_mat.albedo_texture
			new_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			new_mat.albedo_color = albedo_color
			new_mat.roughness = 0.86
			new_mat.metallic = 0.08
			node.material_override = new_mat
		else:
			var prop_mat := ShaderMaterial.new()
			prop_mat.shader = tile_shader
			prop_mat.set_shader_parameter("base_texture", stone_tex)
			prop_mat.set_shader_parameter("zone_tint", albedo_color)
			prop_mat.set_shader_parameter("tint_strength", 0.65)
			prop_mat.set_shader_parameter("is_prop", true)
			node.material_override = prop_mat

	for child in node.get_children():
		_apply_stylized_tint(child, albedo_color, keep_texture)
