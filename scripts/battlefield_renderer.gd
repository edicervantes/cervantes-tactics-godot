extends RefCounted
class_name BattlefieldRenderer

const TILE_W := 1.0
const TILE_H := 1.0
const HEIGHT_SCALE := 0.5

const COLOR_GROUND := Color("#505c54")
const COLOR_OBSTACLE := Color("#1e252b")
const COLOR_MOVE := Color("#3f7d78")
const COLOR_TARGET := Color("#72593a")
const COLOR_HOVER := Color("#d7f5ff")
const COLOR_SELECTED := Color("#f6d878")
const COLOR_DESTINATION := Color("#d7f5a6")
const COLOR_STONE_DARK := Color("#2d3739")
const COLOR_STONE_RIM := Color("#465557")
const COLOR_GOLD_INLAY := Color("#b28b4c")
const COLOR_MOSS := Color("#728f55")
const COLOR_ORDER_GLOW := Color("#a25ad5")
const COLOR_FAMILY_GLOW := Color("#65cfe0")

const KAYKIT_TILE_BRICK_A_LARGE := preload("res://assets/3d/kaykit_dungeon/Models/gltf/tileBrickA_large.glb")
const KAYKIT_TILE_BRICK_B_LARGE := preload("res://assets/3d/kaykit_dungeon/Models/gltf/tileBrickB_large.glb")
const KAYKIT_FLOOR_DECORATION_TILES_LARGE := preload("res://assets/3d/kaykit_dungeon/Models/gltf/floorDecoration_tilesLarge.glb")
const GRASS_SCENE := preload("res://assets/3d/grass.glb")
const RUBBLE_SCENE := preload("res://assets/3d/rubble.glb")
const CHEST_SCENE := preload("res://assets/3d/chest.glb")
const BANNER_SCENE := preload("res://assets/3d/banner.glb")
const DOORWAY_SCENE := preload("res://assets/3d/doorway.glb")
const TORCH_SCENE := preload("res://assets/3d/torch.glb")
const TREE_FOLIAGE_TEXTURE := preload("res://assets/textures/foliage/oaktoonbranchesgreen.png")
const KENNEY_GATE_DOOR := preload("res://assets/third_party/kenney_modular_dungeon_kit/glb/gate-door.glb")
const KENNEY_GATE_BARS := preload("res://assets/third_party/kenney_modular_dungeon_kit/glb/gate-metal-bars.glb")
const KENNEY_STAIRS_WIDE := preload("res://assets/third_party/kenney_modular_dungeon_kit/glb/stairs-wide.glb")
const KENNEY_WALL_HALF := preload("res://assets/third_party/kenney_modular_dungeon_kit/glb/template-wall-half.glb")
const KENNEY_WALL_CORNER := preload("res://assets/third_party/kenney_modular_dungeon_kit/glb/template-wall-corner.glb")
const KENNEY_WALL_DETAIL := preload("res://assets/third_party/kenney_modular_dungeon_kit/glb/template-wall-detail-a.glb")
const KENNEY_FLOOR_DETAIL := preload("res://assets/third_party/kenney_modular_dungeon_kit/glb/template-floor-detail.glb")

var terrain_meshes: Array[Node3D] = []
var overlay_meshes: Dictionary = {}
var tile_shader: Shader = preload("res://shaders/tile_shader.gdshader")
var _terrain_mat_cache: Dictionary = {}
var _current_map_size: Vector2i = Vector2i.ZERO

func _terrain_color(terrain_type: String, is_obstacle: bool) -> Color:
	if is_obstacle:
		return Color("#242d31")
	match terrain_type:
		"family_terrace":
			return Color("#7e9568")
		"order_influence":
			return Color("#2c263b")
		"order_edge":
			return Color("#433153")
		"archive_grass":
			return Color("#637d4f")
		"memory_path":
			return Color("#687a73")
		"crystal_dais":
			return Color("#82aeb1")
		"broken":
			return Color("#30383b")
		_:
			return Color("#58665c")

func _terrain_accent_color(terrain_type: String) -> Color:
	match terrain_type:
		"family_terrace", "archive_grass":
			return COLOR_FAMILY_GLOW
		"order_influence", "order_edge":
			return COLOR_ORDER_GLOW
		"crystal_dais":
			return Color("#9ee8f2")
		"memory_path":
			return Color("#8db7b2")
		"broken":
			return Color("#536166")
		_:
			return COLOR_GOLD_INLAY

func _get_terrain_shader_material(terrain_type: String) -> ShaderMaterial:
	if _terrain_mat_cache.has(terrain_type):
		return _terrain_mat_cache[terrain_type]

	var mat := ShaderMaterial.new()
	mat.shader = tile_shader

	# Load base texture
	var tex = load("res://assets/3d/Textures/stylized_stone_floor.png")
	mat.set_shader_parameter("base_texture", tex)

	var zone_tint := Color(1.0, 1.0, 1.0)
	var tint_strength := 0.3
	var is_corrupted := false
	var is_grass_terrace := false
	var is_dais := false

	match terrain_type:
		"family_terrace", "archive_grass":
			zone_tint = Color(0.22, 0.30, 0.16)
			tint_strength = 0.65
			is_grass_terrace = true
		"order_influence", "order_edge":
			zone_tint = Color(0.14, 0.11, 0.20)
			tint_strength = 0.82
			is_corrupted = true
		"crystal_dais":
			zone_tint = Color(0.30, 0.36, 0.38)
			tint_strength = 0.45
			is_dais = true
		"broken":
			zone_tint = Color(0.18, 0.16, 0.18)
			tint_strength = 0.60
			is_corrupted = true
		_: # memory_path, memory_stone
			zone_tint = Color(0.32, 0.28, 0.24)
			tint_strength = 0.50

	mat.set_shader_parameter("zone_tint", zone_tint)
	mat.set_shader_parameter("tint_strength", tint_strength)
	mat.set_shader_parameter("is_corrupted", is_corrupted)
	mat.set_shader_parameter("is_grass_terrace", is_grass_terrace)
	mat.set_shader_parameter("is_dais", is_dais)
	mat.set_shader_parameter("map_size", Vector2(_current_map_size))

	_terrain_mat_cache[terrain_type] = mat
	return mat

func _get_prop_shader_material(terrain_type: String) -> ShaderMaterial:
	var cache_key := terrain_type + "_prop"
	if _terrain_mat_cache.has(cache_key):
		return _terrain_mat_cache[cache_key]

	var mat := _get_terrain_shader_material(terrain_type).duplicate() as ShaderMaterial
	mat.set_shader_parameter("is_prop", true)
	_terrain_mat_cache[cache_key] = mat
	return mat

func _tile_scene_for_terrain(terrain_type: String) -> PackedScene:
	match terrain_type:
		"family_terrace", "archive_grass":
			return KAYKIT_TILE_BRICK_A_LARGE
		"memory_path", "memory_stone":
			return KAYKIT_TILE_BRICK_B_LARGE
		"crystal_dais":
			return KAYKIT_TILE_BRICK_B_LARGE
		"order_influence", "order_edge":
			return KAYKIT_TILE_BRICK_B_LARGE
		"broken":
			return KAYKIT_TILE_BRICK_B_LARGE
		_:
			return KAYKIT_TILE_BRICK_B_LARGE



func build_terrain(parent_node: Node3D, context: Dictionary) -> void:
	var terrain_layer: Node3D = parent_node.get_node_or_null("%TerrainLayer")
	if not terrain_layer:
		return

	# Clear old meshes
	for child in terrain_layer.get_children():
		child.queue_free()
	terrain_meshes.clear()

	var grid_size: Vector2i = context["grid_size"]
	_current_map_size = grid_size
	var cell_heights: Dictionary = context.get("cell_heights", {})
	var obstacles: Array = context.get("obstacles", [])
	var cell_props: Dictionary = context.get("cell_props", {})
	var decoration_cells: Array = context.get("decoration_cells", [])

	var box_mesh = BoxMesh.new()
	var mat_cache := {}
	var seam_mat_cache := {}
	var detail_mat_cache := {}

	var cell_terrain: Dictionary = context.get("cell_terrain", {})

	for y in grid_size.y:
		for x in grid_size.x:
			var grid := Vector2i(x, y)
			var height := int(cell_heights.get(grid, 0))
			var world_y := float(height) * HEIGHT_SCALE

			var is_obstacle := obstacles.has(grid)
			var terrain_type := str(cell_terrain.get(grid, "memory_stone"))
			var base_color := _terrain_color(terrain_type, is_obstacle)
			var tint_variation := 0.94 + float((x * 19 + y * 11) % 12) * 0.012
			base_color = base_color.lightened(maxf(0.0, tint_variation - 1.0)).darkened(maxf(0.0, 1.0 - tint_variation))

			var tile_scene: PackedScene = _tile_scene_for_terrain(terrain_type)
			var tile_inst := tile_scene.instantiate() as Node3D
			tile_inst.position = Vector3(float(x), world_y, float(y))
			tile_inst.scale = Vector3((TILE_W * 0.97) / 6.0, 1.0 / 6.0, (TILE_H * 0.97) / 6.0)
			_apply_zone_material(tile_inst, terrain_type)
			terrain_layer.add_child(tile_inst)
			terrain_meshes.append(tile_inst)
			_build_tile_seams(terrain_layer, box_mesh, seam_mat_cache, grid, world_y, terrain_type)
			_build_tile_details(terrain_layer, box_mesh, detail_mat_cache, grid, world_y, terrain_type, is_obstacle)

			# 3. Si la altura es mayor a 0, instanciamos la columna base (acantilado) debajo
			if world_y > 0.0:
				var base_inst := MeshInstance3D.new()
				base_inst.mesh = box_mesh
				base_inst.material_override = _get_terrain_shader_material(terrain_type)
				base_inst.scale = Vector3(TILE_W * 0.98, world_y, TILE_H * 0.98)
				base_inst.position = Vector3(float(x), world_y * 0.5, float(y))
				terrain_layer.add_child(base_inst)
				terrain_meshes.append(base_inst)

			# 4. Si es un obstáculo (como cofre, ruinas), instanciar un prop detallado encima de forma determinista
			if is_obstacle:
				var val := (x * 13 + y * 37) % 100
				var obstacle_prop: Node3D
				var nearest_only := false
				var already_stylized := false
				var prop_offset := Vector3.ZERO
				var prop_type := str(cell_props.get(grid, ""))
				if prop_type == "crate":
					obstacle_prop = CHEST_SCENE.instantiate() as Node3D
					obstacle_prop.scale = Vector3(0.38, 0.38, 0.38)
					obstacle_prop.rotation.y = float(val) * 0.13
					nearest_only = true
				elif prop_type == "column" or prop_type == "obelisk":
					obstacle_prop = _create_stylized_column(0.70, Color("#5c6863"), prop_type == "obelisk")
					obstacle_prop.rotation.y = float(val) * 0.05
					already_stylized = true
				elif prop_type == "bramble":
					obstacle_prop = GRASS_SCENE.instantiate() as Node3D
					obstacle_prop.scale = Vector3(0.75, 0.58, 0.75)
					obstacle_prop.rotation.y = float(val) * 0.08
					nearest_only = true
				elif prop_type == "rubble" or val < 40:
					obstacle_prop = RUBBLE_SCENE.instantiate() as Node3D
					obstacle_prop.scale = Vector3(0.24, 0.24, 0.24)
					prop_offset = Vector3(0.10, 0.0, 0.02)
				elif val < 80:
					obstacle_prop = CHEST_SCENE.instantiate() as Node3D
					obstacle_prop.scale = Vector3(0.35, 0.35, 0.35)
					obstacle_prop.rotation.y = float(val) * 0.1
					nearest_only = true
				else:
					obstacle_prop = _create_stylized_column(0.58, Color("#586660"), false)
					obstacle_prop.rotation.y = float(val) * 0.05
					already_stylized = true

				# Colocar el prop arriba de la baldosa
				obstacle_prop.position = Vector3(float(x), world_y, float(y)) + prop_offset
				if not already_stylized:
					_apply_stylized_material(obstacle_prop, Color("#64706c") if not nearest_only else Color.WHITE, nearest_only, not nearest_only)
				terrain_layer.add_child(obstacle_prop)
				terrain_meshes.append(obstacle_prop)

			# 5. Si es hierba, colocar pasto 3D de Kenney aleatorio para volumen orgánico
			if terrain_type == "archive_grass" or terrain_type == "family_terrace":
				var val := (x * 17 + y * 31) % 100
				if val < 35: # 35% de probabilidad
					var grass_inst := GRASS_SCENE.instantiate() as Node3D
					var offset_x := (float(val % 10) / 10.0 - 0.5) * 0.35
					var offset_z := (float((val / 10) % 10) / 10.0 - 0.5) * 0.35
					grass_inst.position = Vector3(float(x) + offset_x, world_y, float(y) + offset_z)
					grass_inst.rotation.y = float(val) * 0.06
					grass_inst.scale = Vector3(0.45, 0.45, 0.45)
					_apply_stylized_material(grass_inst, Color.WHITE, true)
					terrain_layer.add_child(grass_inst)
					terrain_meshes.append(grass_inst)

	_build_diorama_edges(terrain_layer, grid_size, cell_heights)
	_build_height_transition_blocks(terrain_layer, grid_size, cell_heights, cell_terrain)
	_build_visual_decorations(terrain_layer, decoration_cells, cell_heights)
	_build_perimeter_story_props(terrain_layer, grid_size)

	# 6. Colocar el gran portal de piedra familiar como ancla visual de la maqueta.
	var h_0_0 := float(cell_heights.get(Vector2i(0, 2), 0)) * HEIGHT_SCALE
	_build_family_gate(terrain_layer, Vector3(-0.45, h_0_0 + 0.02, 2.05), -65.0, 0.92)

	# Custodiado por dos antorchas físicas reales que iluminan con fuego
	var torch_l := TORCH_SCENE.instantiate() as Node3D
	torch_l.position = Vector3(-0.78, h_0_0 + 0.42, 1.55)
	torch_l.scale = Vector3(0.48, 0.48, 0.48)
	torch_l.rotation_degrees.y = 20
	_apply_stylized_material(torch_l, Color.WHITE, true)

	var light_l = OmniLight3D.new()
	light_l.light_color = Color("#ffa854")
	light_l.light_energy = 1.6
	light_l.omni_range = 3.5
	light_l.shadow_enabled = true
	torch_l.add_child(light_l)
	terrain_layer.add_child(torch_l)
	terrain_meshes.append(torch_l)

	var torch_r := TORCH_SCENE.instantiate() as Node3D
	torch_r.position = Vector3(0.05, h_0_0 + 0.42, 2.55)
	torch_r.scale = Vector3(0.48, 0.48, 0.48)
	torch_r.rotation_degrees.y = -150
	_apply_stylized_material(torch_r, Color.WHITE, true)

	var light_r = OmniLight3D.new()
	light_r.light_color = Color("#ffa854")
	light_r.light_energy = 1.6
	light_r.omni_range = 3.5
	light_r.shadow_enabled = true
	torch_r.add_child(light_r)
	terrain_layer.add_child(torch_r)
	terrain_meshes.append(torch_r)

func _build_tile_seams(terrain_layer: Node3D, mesh: BoxMesh, seam_mat_cache: Dictionary, grid: Vector2i, world_y: float, terrain_type: String) -> void:
	return # Disabled: Allow natural 3D gaps/bevels between tile models to define seams

func _get_detail_material(detail_mat_cache: Dictionary, color: Color, emission := 0.0, alpha := 1.0) -> Material:
	var key := "%s:%0.2f:%0.2f" % [color.to_html(), emission, alpha]
	if detail_mat_cache.has(key):
		return detail_mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.roughness = 0.86
	mat.metallic = 0.08
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	detail_mat_cache[key] = mat
	return mat

func _build_tile_details(terrain_layer: Node3D, mesh: BoxMesh, detail_mat_cache: Dictionary, grid: Vector2i, world_y: float, terrain_type: String, is_obstacle: bool) -> void:
	var seed := grid.x * 73 + grid.y * 41
	var y := world_y + 0.214
	var trim_color := Color("#263232")
	if terrain_type == "family_terrace" or terrain_type == "archive_grass":
		trim_color = Color("#3f543c")
	elif terrain_type == "order_influence" or terrain_type == "order_edge":
		trim_color = Color("#211a2e")
	elif terrain_type == "crystal_dais":
		trim_color = Color("#527e83")
	elif terrain_type == "broken":
		trim_color = Color("#1c2225")
	var trim_mat := _get_detail_material(detail_mat_cache, trim_color.darkened(0.12), 0.0, 0.92)

	if seed % 4 == 0 and not is_obstacle:
		var accent := _terrain_accent_color(terrain_type)
		var accent_mat := _get_detail_material(detail_mat_cache, accent, 0.10, 0.78)
		var inlay := MeshInstance3D.new()
		inlay.mesh = mesh
		inlay.material_override = accent_mat
		inlay.position = Vector3(float(grid.x), y + 0.005, float(grid.y))
		inlay.scale = Vector3(0.22, 0.006, 0.012)
		inlay.rotation_degrees.y = 0.0 if seed % 8 == 0 else 90.0
		terrain_layer.add_child(inlay)
		terrain_meshes.append(inlay)

	if (terrain_type == "family_terrace" or terrain_type == "archive_grass") and seed % 3 == 0:
		var moss_mat := _get_detail_material(detail_mat_cache, COLOR_MOSS, 0.0, 0.88)
		for i in 2:
			var moss := MeshInstance3D.new()
			moss.mesh = mesh
			moss.material_override = moss_mat
			moss.position = Vector3(float(grid.x) - 0.24 + float(i) * 0.18, y + 0.006, float(grid.y) + 0.25)
			moss.scale = Vector3(0.10 + float(i) * 0.035, 0.006, 0.035)
			moss.rotation_degrees.y = float(seed % 40) - 20.0
			terrain_layer.add_child(moss)
			terrain_meshes.append(moss)

	if terrain_type == "crystal_dais":
		var gold_mat := _get_detail_material(detail_mat_cache, COLOR_GOLD_INLAY.lightened(0.15), 0.06, 0.86)
		for i in 4:
			var spoke := MeshInstance3D.new()
			spoke.mesh = mesh
			spoke.material_override = gold_mat
			spoke.position = Vector3(float(grid.x), y + 0.011, float(grid.y))
			spoke.scale = Vector3(0.34, 0.006, 0.01)
			spoke.rotation_degrees.y = 45.0 * float(i)
			terrain_layer.add_child(spoke)
			terrain_meshes.append(spoke)

func _build_procedural_brick_wall(terrain_layer: Node3D, box_mesh: BoxMesh, mat: Material, start: float, end: float, y_center: float, thickness: float, height: float, coord_fixed: float, is_along_x: bool, moss_mat: Material) -> void:
	var rng_local := RandomNumberGenerator.new()
	rng_local.seed = int(abs(coord_fixed) * 100.0) + 123

	var layers := 3
	var layer_height := height / float(layers)
	var brick_len := 0.8

	for l in layers:
		var y_pos := y_center - height * 0.5 + layer_height * (float(l) + 0.5)
		var shift := 0.0 if l % 2 == 0 else brick_len * 0.5

		var curr := start - shift
		while curr < end + brick_len:
			var next_len := brick_len * rng_local.randf_range(0.85, 1.15)

			var c_start := clampf(curr, start, end)
			var c_end := clampf(curr + next_len, start, end)
			if c_end - c_start > 0.05:
				var brick_center := (c_start + c_end) * 0.5
				var actual_len := c_end - c_start

				var brick := MeshInstance3D.new()
				brick.mesh = box_mesh
				brick.material_override = mat

				var b_scale_x = actual_len * rng_local.randf_range(0.96, 1.0)
				var b_scale_y = layer_height * rng_local.randf_range(0.92, 0.98)
				var b_scale_z = thickness * rng_local.randf_range(0.95, 1.05)

				var pos_jitter_fixed := coord_fixed + rng_local.randf_range(-0.015, 0.015)

				if is_along_x:
					brick.position = Vector3(brick_center, y_pos, pos_jitter_fixed)
					brick.scale = Vector3(b_scale_x, b_scale_y, b_scale_z)
					brick.rotation_degrees.z = rng_local.randf_range(-1.2, 1.2)
					brick.rotation_degrees.y = rng_local.randf_range(-1.0, 1.0)
				else:
					brick.position = Vector3(pos_jitter_fixed, y_pos, brick_center)
					brick.scale = Vector3(b_scale_z, b_scale_y, b_scale_x)
					brick.rotation_degrees.x = rng_local.randf_range(-1.2, 1.2)
					brick.rotation_degrees.y = rng_local.randf_range(-1.0, 1.0)

				terrain_layer.add_child(brick)
				terrain_meshes.append(brick)

				# Procedural hanging moss/vines from seams
				if rng_local.randf() < 0.16:
					var moss_v := MeshInstance3D.new()
					var moss_v_mesh := BoxMesh.new()
					var v_height := rng_local.randf_range(0.12, 0.32)
					moss_v_mesh.size = Vector3(rng_local.randf_range(0.04, 0.08), v_height, 0.015)
					moss_v.mesh = moss_v_mesh
					moss_v.material_override = moss_mat

					if is_along_x:
						moss_v.position = Vector3(brick_center + rng_local.randf_range(-0.1, 0.1), y_pos - b_scale_y * 0.5 - v_height * 0.2, pos_jitter_fixed + thickness * 0.51)
					else:
						moss_v.position = Vector3(pos_jitter_fixed + thickness * 0.51, y_pos - b_scale_y * 0.5 - v_height * 0.2, brick_center + rng_local.randf_range(-0.1, 0.1))
						moss_v.rotation_degrees.y = 90.0

					terrain_layer.add_child(moss_v)
					terrain_meshes.append(moss_v)

			curr += next_len

func _build_diorama_edges(terrain_layer: Node3D, grid_size: Vector2i, cell_heights: Dictionary) -> void:
	var wall_color := COLOR_STONE_RIM
	var box_mesh := BoxMesh.new()
	var side_mat := _get_terrain_shader_material("memory_stone")

	var min_x := -0.55
	var max_x := float(grid_size.x) - 0.45
	var min_z := -0.55
	var max_z := float(grid_size.y) - 0.45

	var moss_mat_v := StandardMaterial3D.new()
	moss_mat_v.albedo_color = Color("#4a6836")
	moss_mat_v.roughness = 0.95
	moss_mat_v.metallic = 0.02

	# Build the four sides out of procedural stone bricks with moss
	_build_procedural_brick_wall(terrain_layer, box_mesh, side_mat, min_x, max_x, -0.34, 0.24, 0.36, min_z, true, moss_mat_v)
	_build_procedural_brick_wall(terrain_layer, box_mesh, side_mat, min_x, max_x, -0.34, 0.24, 0.36, max_z, true, moss_mat_v)
	_build_procedural_brick_wall(terrain_layer, box_mesh, side_mat, min_z, max_z, -0.34, 0.24, 0.36, min_x, false, moss_mat_v)
	_build_procedural_brick_wall(terrain_layer, box_mesh, side_mat, min_z, max_z, -0.34, 0.24, 0.36, max_x, false, moss_mat_v)

	var tex = load("res://assets/3d/Textures/stylized_stone_floor.png")

	var rim_mat := ShaderMaterial.new()
	rim_mat.shader = tile_shader
	rim_mat.set_shader_parameter("base_texture", tex)
	rim_mat.set_shader_parameter("zone_tint", wall_color)
	rim_mat.set_shader_parameter("tint_strength", 0.65)
	rim_mat.set_shader_parameter("is_prop", true)

	var cap_mat := ShaderMaterial.new()
	cap_mat.shader = tile_shader
	cap_mat.set_shader_parameter("base_texture", tex)
	cap_mat.set_shader_parameter("zone_tint", Color("#59655f"))
	cap_mat.set_shader_parameter("tint_strength", 0.65)
	cap_mat.set_shader_parameter("is_prop", true)

	var moss_mat := ShaderMaterial.new()
	moss_mat.shader = tile_shader
	moss_mat.set_shader_parameter("base_texture", tex)
	moss_mat.set_shader_parameter("zone_tint", Color("#526d42"))
	moss_mat.set_shader_parameter("tint_strength", 0.65)
	moss_mat.set_shader_parameter("is_prop", true)
	for x in grid_size.x:
		_build_rim_block(terrain_layer, box_mesh, rim_mat, Vector3(float(x), 0.08, -0.55), Vector3(0.46, 0.12, 0.08))
		_build_rim_block(terrain_layer, box_mesh, rim_mat, Vector3(float(x), 0.08, float(grid_size.y) - 0.45), Vector3(0.46, 0.12, 0.08))
		_build_rim_block(terrain_layer, box_mesh, cap_mat, Vector3(float(x), 0.23, -0.58), Vector3(0.34, 0.035, 0.10))
		_build_rim_block(terrain_layer, box_mesh, cap_mat, Vector3(float(x), 0.23, float(grid_size.y) - 0.42), Vector3(0.34, 0.035, 0.10))
		if x % 3 == 0:
			_build_rim_block(terrain_layer, box_mesh, moss_mat, Vector3(float(x) + 0.18, 0.285, -0.50), Vector3(0.12, 0.014, 0.035))
	for y in grid_size.y:
		_build_rim_block(terrain_layer, box_mesh, rim_mat, Vector3(-0.55, 0.08, float(y)), Vector3(0.08, 0.12, 0.46))
		_build_rim_block(terrain_layer, box_mesh, rim_mat, Vector3(float(grid_size.x) - 0.45, 0.08, float(y)), Vector3(0.08, 0.12, 0.46))
		_build_rim_block(terrain_layer, box_mesh, cap_mat, Vector3(-0.58, 0.23, float(y)), Vector3(0.10, 0.035, 0.34))
		_build_rim_block(terrain_layer, box_mesh, cap_mat, Vector3(float(grid_size.x) - 0.42, 0.23, float(y)), Vector3(0.10, 0.035, 0.34))
		if y % 3 == 1:
			_build_rim_block(terrain_layer, box_mesh, moss_mat, Vector3(-0.50, 0.285, float(y) - 0.18), Vector3(0.035, 0.014, 0.12))

	for x in range(-1, grid_size.x + 1, 2):
		_build_rim_block(terrain_layer, box_mesh, rim_mat, Vector3(float(x), -0.08, -0.78), Vector3(0.32, 0.18, 0.15))
		_build_rim_block(terrain_layer, box_mesh, rim_mat, Vector3(float(x), -0.08, float(grid_size.y) - 0.2), Vector3(0.32, 0.18, 0.15))
	for y in range(0, grid_size.y + 1, 2):
		_build_rim_block(terrain_layer, box_mesh, rim_mat, Vector3(-0.78, -0.08, float(y)), Vector3(0.15, 0.18, 0.32))
		_build_rim_block(terrain_layer, box_mesh, rim_mat, Vector3(float(grid_size.x) - 0.2, -0.08, float(y)), Vector3(0.15, 0.18, 0.32))

	var corners := [
		Vector3(-0.62, 0.22, -0.62),
		Vector3(float(grid_size.x) - 0.38, 0.22, -0.62),
		Vector3(-0.62, 0.22, float(grid_size.y) - 0.38),
		Vector3(float(grid_size.x) - 0.38, 0.22, float(grid_size.y) - 0.38)
	]
	for corner in corners:
		_build_corner_pillar(terrain_layer, box_mesh, cap_mat, rim_mat, corner)

func _build_rim_block(terrain_layer: Node3D, mesh: BoxMesh, mat: Material, position: Vector3, scale: Vector3) -> void:
	var block := MeshInstance3D.new()
	block.mesh = mesh
	block.material_override = mat
	block.position = position
	block.scale = scale
	terrain_layer.add_child(block)
	terrain_meshes.append(block)

func _build_corner_pillar(terrain_layer: Node3D, mesh: BoxMesh, cap_mat: Material, rim_mat: Material, position: Vector3) -> void:
	var tint := Color("#56645f") if position.x < 2.0 else Color("#46354f")
	var column := _create_stylized_column(0.78, tint, false)
	column.position = position + Vector3(0.0, -0.18, 0.0)
	terrain_layer.add_child(column)
	terrain_meshes.append(column)

	var crown_block := MeshInstance3D.new()
	crown_block.mesh = mesh
	crown_block.material_override = cap_mat
	crown_block.position = position + Vector3(0.0, 0.50, 0.0)
	crown_block.scale = Vector3(0.24, 0.035, 0.24)
	terrain_layer.add_child(crown_block)
	terrain_meshes.append(crown_block)

	var crystal_color := COLOR_FAMILY_GLOW if position.x < 2.0 else COLOR_ORDER_GLOW
	_build_crystal_cluster(terrain_layer, position + Vector3(0.0, 0.55, 0.0), crystal_color, 0.28)

func _create_stylized_column(scale: float, tint: Color, damaged := false) -> Node3D:
	var pivot := Node3D.new()

	var stone_mat := _make_stone_prop_material(tint, 0.74)
	var dark_mat := _make_stone_prop_material(tint.darkened(0.28), 0.82)
	var cap_mat := _make_stone_prop_material(tint.lightened(0.08), 0.70)
	var moss_mat := _make_stone_prop_material(Color("#4d6a3c"), 0.58)

	var plinth := MeshInstance3D.new()
	var plinth_mesh := CylinderMesh.new()
	plinth_mesh.radial_segments = 10
	plinth_mesh.top_radius = 0.22 * scale
	plinth_mesh.bottom_radius = 0.25 * scale
	plinth_mesh.height = 0.13 * scale
	plinth.mesh = plinth_mesh
	plinth.material_override = cap_mat
	plinth.position.y = 0.065 * scale
	pivot.add_child(plinth)

	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.radial_segments = 12
	shaft_mesh.top_radius = 0.145 * scale
	shaft_mesh.bottom_radius = 0.165 * scale
	shaft_mesh.height = 0.68 * scale
	shaft.mesh = shaft_mesh
	shaft.material_override = stone_mat
	shaft.position.y = 0.46 * scale
	shaft.rotation_degrees.y = 15.0
	pivot.add_child(shaft)

	var band_specs := [
		{"y": 0.17, "radius": 0.19, "height": 0.045},
		{"y": 0.77, "radius": 0.18, "height": 0.045},
		{"y": 0.86, "radius": 0.23, "height": 0.11}
	]
	for spec in band_specs:
		var band := MeshInstance3D.new()
		var band_mesh := CylinderMesh.new()
		band_mesh.radial_segments = 10
		band_mesh.top_radius = float(spec["radius"]) * scale
		band_mesh.bottom_radius = (float(spec["radius"]) + 0.015) * scale
		band_mesh.height = float(spec["height"]) * scale
		band.mesh = band_mesh
		band.material_override = cap_mat
		band.position.y = float(spec["y"]) * scale
		pivot.add_child(band)

	var flute_mesh := BoxMesh.new()
	flute_mesh.size = Vector3(0.018 * scale, 0.52 * scale, 0.014 * scale)
	for i in 8:
		var angle := float(i) * TAU / 8.0
		var flute := MeshInstance3D.new()
		flute.mesh = flute_mesh
		flute.material_override = dark_mat
		flute.position = Vector3(cos(angle) * 0.156 * scale, 0.46 * scale, sin(angle) * 0.156 * scale)
		flute.rotation_degrees.y = -rad_to_deg(angle)
		pivot.add_child(flute)

	var chip_mesh := BoxMesh.new()
	chip_mesh.size = Vector3(0.05 * scale, 0.035 * scale, 0.018 * scale)
	for i in 3:
		var angle := float(i) * 2.17 + 0.35
		var chip := MeshInstance3D.new()
		chip.mesh = chip_mesh
		chip.material_override = dark_mat
		chip.position = Vector3(cos(angle) * 0.176 * scale, (0.34 + float(i) * 0.15) * scale, sin(angle) * 0.176 * scale)
		chip.rotation_degrees = Vector3(0.0, -rad_to_deg(angle), -4.0 + float(i) * 3.0)
		pivot.add_child(chip)

	var moss_mesh := BoxMesh.new()
	moss_mesh.size = Vector3(0.07 * scale, 0.018 * scale, 0.022 * scale)
	for i in 2:
		var moss := MeshInstance3D.new()
		moss.mesh = moss_mesh
		moss.material_override = moss_mat
		var angle := 0.9 + float(i) * 2.4
		moss.position = Vector3(cos(angle) * 0.19 * scale, (0.74 + float(i) * 0.10) * scale, sin(angle) * 0.19 * scale)
		moss.rotation_degrees.y = -rad_to_deg(angle)
		pivot.add_child(moss)

	if damaged:
		pivot.scale.y = 0.86
		var broken_cap := MeshInstance3D.new()
		var broken_mesh := BoxMesh.new()
		broken_mesh.size = Vector3(0.23 * scale, 0.08 * scale, 0.16 * scale)
		broken_cap.mesh = broken_mesh
		broken_cap.material_override = dark_mat
		broken_cap.position = Vector3(0.03 * scale, 0.86 * scale, -0.02 * scale)
		broken_cap.rotation_degrees = Vector3(0.0, 18.0, 8.0)
		pivot.add_child(broken_cap)

	return pivot

func _make_stone_prop_material(tint: Color, tint_strength: float) -> ShaderMaterial:
	var key := "stone_prop_custom_%s_%0.2f" % [tint.to_html(false), tint_strength]
	if _terrain_mat_cache.has(key):
		return _terrain_mat_cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = tile_shader
	var tex = load("res://assets/3d/Textures/stylized_stone_floor.png")
	mat.set_shader_parameter("base_texture", tex)
	mat.set_shader_parameter("zone_tint", tint)
	mat.set_shader_parameter("tint_strength", tint_strength)
	mat.set_shader_parameter("is_prop", true)
	_terrain_mat_cache[key] = mat
	return mat

func _build_height_transition_blocks(terrain_layer: Node3D, grid_size: Vector2i, cell_heights: Dictionary, cell_terrain: Dictionary) -> void:
	var box_mesh := BoxMesh.new()
	var mat_cache := {}
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]
	for y in grid_size.y:
		for x in grid_size.x:
			var grid := Vector2i(x, y)
			var height := int(cell_heights.get(grid, 0))
			if height <= 0:
				continue
			var terrain_type := str(cell_terrain.get(grid, "memory_stone"))
			var color := _terrain_color(terrain_type, false).darkened(0.28)
			var key := color.to_html()
			if not mat_cache.has(key):
				var tex = load("res://assets/3d/Textures/stylized_stone_floor.png")
				var mat := ShaderMaterial.new()
				mat.shader = tile_shader
				mat.set_shader_parameter("base_texture", tex)
				mat.set_shader_parameter("zone_tint", color)
				mat.set_shader_parameter("tint_strength", 0.65)
				mat.set_shader_parameter("is_prop", true)
				mat_cache[key] = mat
			for dir in dirs:
				var n: Vector2i = grid + dir
				var n_height := int(cell_heights.get(n, 0))
				if n.x < 0 or n.y < 0 or n.x >= grid_size.x or n.y >= grid_size.y or n_height < height:
					var diff: int = max(1, height - n_height)
					var side_y := float(n_height) * HEIGHT_SCALE + float(diff) * HEIGHT_SCALE * 0.5
					var side := MeshInstance3D.new()
					side.mesh = box_mesh
					side.material_override = mat_cache[key]
					side.position = Vector3(float(grid.x), side_y, float(grid.y))
					if dir.x != 0:
						side.position.x += float(dir.x) * 0.47
						side.scale = Vector3(0.055, float(diff) * HEIGHT_SCALE * 0.5, 0.42)
					else:
						side.position.z += float(dir.y) * 0.47
						side.scale = Vector3(0.42, float(diff) * HEIGHT_SCALE * 0.5, 0.055)
					terrain_layer.add_child(side)
					terrain_meshes.append(side)

func _build_visual_decorations(terrain_layer: Node3D, decoration_cells: Array, cell_heights: Dictionary) -> void:
	for decoration in decoration_cells:
		var kind := str(decoration.get("kind", ""))
		var grid: Vector2i = decoration.get("grid", Vector2i.ZERO)
		var offset: Vector2 = decoration.get("offset", Vector2.ZERO)
		var base_height := float(cell_heights.get(grid, 0)) * HEIGHT_SCALE
		var position := Vector3(float(grid.x) + offset.x, base_height + float(decoration.get("y_offset", 0.0)), float(grid.y) + offset.y)
		var rotation := float(decoration.get("rotation", 0.0))
		var scale := float(decoration.get("scale", 1.0))

		match kind:
			"family_crystal":
				_build_crystal_cluster(terrain_layer, position, Color("#74d8ff"), scale)
			"order_crystal":
				_build_crystal_cluster(terrain_layer, position, Color("#9b5bcc"), scale)
			"memory_tree":
				_build_memory_tree(terrain_layer, position, scale)
			"crate_stack":
				_build_crate_stack(terrain_layer, position, rotation, scale)
			"rune_family":
				_build_rune_marker(terrain_layer, position, Color("#54c7d6"), scale)
			"rune_order":
				_build_rune_marker(terrain_layer, position, Color("#a35ad3"), scale)
			"order_banner":
				_place_scene_prop(terrain_layer, BANNER_SCENE, position, Vector3(0.36, 0.36, 0.36) * scale, rotation, Color("#4d365f"), false)
			"gate":
				_place_scene_prop(terrain_layer, KENNEY_GATE_DOOR, position, Vector3(0.2, 0.2, 0.2) * scale, rotation, Color("#6d6153"), false)
			"gate_bars":
				_place_scene_prop(terrain_layer, KENNEY_GATE_BARS, position, Vector3(0.2, 0.2, 0.2) * scale, rotation, Color("#44334f"), false)
			"stairs":
				_place_scene_prop(terrain_layer, KENNEY_STAIRS_WIDE, position, Vector3(0.2, 0.2, 0.2) * scale, rotation, Color("#3b4650"), false)
			"floor_detail":
				_place_scene_prop(terrain_layer, KENNEY_FLOOR_DETAIL, position, Vector3(0.34, 0.34, 0.34) * scale, rotation, Color("#8ab6b8"), false)
			"family_shrine":
				_build_low_shrine(terrain_layer, position, Color("#6ed7e3"), scale)
			"order_shrine":
				_build_low_shrine(terrain_layer, position, Color("#a45ad9"), scale)
			"small_ruin":
				_build_small_ruin(terrain_layer, position, rotation, scale, Color("#596763"))

func _build_family_gate(terrain_layer: Node3D, position: Vector3, rotation_y: float, scale: float) -> void:
	var pivot := Node3D.new()
	pivot.position = position
	pivot.rotation_degrees.y = rotation_y
	terrain_layer.add_child(pivot)
	terrain_meshes.append(pivot)

	var box_mesh := BoxMesh.new()
	var stone_mat := _get_terrain_shader_material("memory_stone")
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = COLOR_GOLD_INLAY.darkened(0.05)
	trim_mat.roughness = 0.62
	trim_mat.metallic = 0.18
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color("#765536")
	wood_mat.roughness = 0.82

	var stone_specs := [
		{"pos": Vector3(-0.32, 0.42, 0.0), "scale": Vector3(0.12, 0.42, 0.13), "mat": stone_mat},
		{"pos": Vector3(0.32, 0.42, 0.0), "scale": Vector3(0.12, 0.42, 0.13), "mat": stone_mat},
		{"pos": Vector3(0.0, 0.86, 0.0), "scale": Vector3(0.48, 0.11, 0.14), "mat": stone_mat},
		{"pos": Vector3(0.0, 0.43, -0.03), "scale": Vector3(0.24, 0.34, 0.035), "mat": wood_mat},
		{"pos": Vector3(0.0, 0.78, -0.065), "scale": Vector3(0.39, 0.025, 0.025), "mat": trim_mat},
		{"pos": Vector3(0.0, 0.19, -0.065), "scale": Vector3(0.39, 0.025, 0.025), "mat": trim_mat}
	]
	for spec in stone_specs:
		var block := MeshInstance3D.new()
		block.mesh = box_mesh
		block.material_override = spec["mat"]
		block.position = spec["pos"] * scale
		block.scale = spec["scale"] * scale
		pivot.add_child(block)

	for i in 5:
		var cap := MeshInstance3D.new()
		cap.mesh = box_mesh
		cap.material_override = stone_mat
		cap.position = Vector3(-0.44 + float(i) * 0.22, 1.02 + sin(float(i) * 0.8) * 0.035, 0.0) * scale
		cap.scale = Vector3(0.10, 0.08, 0.13) * scale
		pivot.add_child(cap)

	_build_crystal_cluster(terrain_layer, position + Vector3(0.0, 1.04 * scale, 0.0).rotated(Vector3.UP, deg_to_rad(rotation_y)), Color("#6ed7e3"), 0.38 * scale)

func _build_perimeter_story_props(terrain_layer: Node3D, grid_size: Vector2i) -> void:
	var back_z := -0.88
	var front_z := float(grid_size.y) - 0.12
	_place_stylized_column(terrain_layer, Vector3(1.4, 0.02, back_z), 0.82, -45.0, Color("#617067"), false)
	_place_stylized_column(terrain_layer, Vector3(2.55, 0.02, back_z - 0.08), 0.68, -30.0, Color("#52645b"), true)
	_place_scene_prop(terrain_layer, KENNEY_WALL_CORNER, Vector3(float(grid_size.x) - 1.3, 0.12, back_z), Vector3(0.18, 0.18, 0.18), 45.0, Color("#44334f"), false)
	_place_scene_prop(terrain_layer, KENNEY_WALL_HALF, Vector3(float(grid_size.x) - 0.4, 0.1, 2.0), Vector3(0.15, 0.15, 0.15), 90.0, Color("#3d3046"), false)
	_place_scene_prop(terrain_layer, KENNEY_WALL_HALF, Vector3(float(grid_size.x) - 0.48, 0.1, 5.3), Vector3(0.14, 0.14, 0.14), 90.0, Color("#352a43"), false)
	_place_scene_prop(terrain_layer, KENNEY_WALL_HALF, Vector3(-0.35, 0.1, 5.5), Vector3(0.15, 0.15, 0.15), -90.0, Color("#50604f"), false)
	_place_scene_prop(terrain_layer, KENNEY_WALL_CORNER, Vector3(-0.52, 0.1, 7.4), Vector3(0.15, 0.15, 0.15), -145.0, Color("#4e604d"), false)
	_build_crystal_cluster(terrain_layer, Vector3(0.4, 0.08, back_z + 0.2), Color("#7ee1ff"), 0.5)
	_build_crystal_cluster(terrain_layer, Vector3(float(grid_size.x) - 0.95, 0.08, front_z - 0.2), Color("#a05de0"), 0.5)
	_build_crystal_cluster(terrain_layer, Vector3(float(grid_size.x) - 2.0, 0.09, 2.05), Color("#9b5bcc"), 0.46)
	_build_memory_tree(terrain_layer, Vector3(-0.55, 0.02, 3.7), 0.56)
	_build_memory_tree(terrain_layer, Vector3(1.25, 0.06, -0.72), 0.44)
	_build_memory_tree(terrain_layer, Vector3(-0.78, 0.02, 6.55), 0.42)
	_build_memory_tree(terrain_layer, Vector3(-1.20, 0.02, 1.5), 0.58) # Extra tree on the far left (family green side)
	_build_crate_stack(terrain_layer, Vector3(2.4, 0.04, front_z), -16.0, 0.68)
	_build_crate_stack(terrain_layer, Vector3(float(grid_size.x) - 1.1, 0.04, 6.75), 24.0, 0.62)
	_build_rune_marker(terrain_layer, Vector3(float(grid_size.x) - 2.5, 0.08, 0.7), Color("#a35ad3"), 0.55)
	_build_crystal_cluster(terrain_layer, Vector3(float(grid_size.x) + 0.2, 0.08, 4.5), Color("#a05de0"), 0.54) # Extra crystal on far right (Order side)
	_build_low_shrine(terrain_layer, Vector3(3.85, 0.06, front_z - 0.05), Color("#65cfe0"), 0.62)
	_build_low_shrine(terrain_layer, Vector3(float(grid_size.x) - 2.7, 0.06, front_z - 0.1), Color("#a45ad9"), 0.66)
	_build_banner_pair(terrain_layer, Vector3(float(grid_size.x) - 0.8, 0.05, 3.4), 90.0, Color("#463055"), 0.72)
	_build_banner_pair(terrain_layer, Vector3(0.55, 0.55, 1.75), -45.0, Color("#40544f"), 0.62)

func _place_scene_prop(terrain_layer: Node3D, scene: PackedScene, position: Vector3, scale: Vector3, rotation_y: float, tint: Color, nearest_only := true) -> Node3D:
	var inst := scene.instantiate() as Node3D
	inst.position = position
	inst.scale = scale
	inst.rotation_degrees.y = rotation_y
	_apply_stylized_material(inst, tint, nearest_only)

	terrain_layer.add_child(inst)
	terrain_meshes.append(inst)
	return inst

func _place_stylized_column(terrain_layer: Node3D, position: Vector3, scale: float, rotation_y: float, tint: Color, damaged := false) -> Node3D:
	var inst := _create_stylized_column(scale, tint, damaged)
	inst.position = position
	inst.rotation_degrees.y = rotation_y
	terrain_layer.add_child(inst)
	terrain_meshes.append(inst)
	return inst

func _build_crystal_cluster(terrain_layer: Node3D, position: Vector3, color: Color, scale: float) -> void:
	var pivot := Node3D.new()
	pivot.position = position
	terrain_layer.add_child(pivot)
	terrain_meshes.append(pivot)

	var crystal_shader = load("res://shaders/crystal_shader.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = crystal_shader
	mat.set_shader_parameter("crystal_color", color)
	mat.set_shader_parameter("core_color", color.darkened(0.55))
	mat.set_shader_parameter("rim_color", Color("#d8c8ff") if color.b > color.g else Color("#bdefff"))
	mat.set_shader_parameter("emission_energy", 0.82)
	mat.set_shader_parameter("facet_contrast", 1.15)

	for i in 5:
		var shard := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.radial_segments = 6
		mesh.rings = 1
		mesh.top_radius = 0.0
		mesh.bottom_radius = (0.07 + float(i % 3) * 0.018) * scale
		mesh.height = (0.34 - float(i % 2) * 0.06) * scale
		shard.mesh = mesh
		shard.material_override = mat
		var angle := float(i) * TAU / 5.0 + 0.22
		var radius := (0.03 if i == 0 else 0.13) * scale
		shard.position = Vector3(cos(angle) * radius, mesh.height * 0.33, sin(angle) * radius)
		shard.rotation_degrees = Vector3(0.0, 25.0 + i * 38.0, -8.0 + float(i % 2) * 14.0)
		pivot.add_child(shard)

	var glint_mat := StandardMaterial3D.new()
	glint_mat.albedo_color = color.lightened(0.35)
	glint_mat.emission_enabled = true
	glint_mat.emission = color
	glint_mat.emission_energy_multiplier = 0.35
	glint_mat.roughness = 0.22
	var glint := MeshInstance3D.new()
	var glint_mesh := BoxMesh.new()
	glint_mesh.size = Vector3(0.018 * scale, 0.34 * scale, 0.012 * scale)
	glint.mesh = glint_mesh
	glint.material_override = glint_mat
	glint.position = Vector3(0.03 * scale, 0.17 * scale, 0.02 * scale)
	glint.rotation_degrees.y = 28.0
	pivot.add_child(glint)

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.42
	light.omni_range = 1.65
	pivot.add_child(light)

func _build_memory_tree(terrain_layer: Node3D, position: Vector3, scale: float) -> void:
	var pivot := Node3D.new()
	pivot.position = position
	terrain_layer.add_child(pivot)
	terrain_meshes.append(pivot)

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color("#4a2f1f")
	trunk_mat.roughness = 0.92
	trunk_mat.metallic = 0.0

	var branch_mat := StandardMaterial3D.new()
	branch_mat.albedo_color = Color("#3c281c")
	branch_mat.roughness = 0.95

	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_texture = TREE_FOLIAGE_TEXTURE
	leaf_mat.albedo_color = Color("#74845c")
	leaf_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	leaf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	leaf_mat.alpha_scissor_threshold = 0.20
	leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaf_mat.roughness = 0.96
	leaf_mat.metallic = 0.0
	leaf_mat.emission_enabled = true
	leaf_mat.emission = Color("#1d2c1b")
	leaf_mat.emission_energy_multiplier = 0.03

	var moss_mat := _get_prop_shader_material("family_terrace")
	var moss_patch := MeshInstance3D.new()
	var moss_mesh := CylinderMesh.new()
	moss_mesh.top_radius = 0.22 * scale
	moss_mesh.bottom_radius = 0.24 * scale
	moss_mesh.height = 0.02
	moss_mesh.radial_segments = 6
	moss_patch.mesh = moss_mesh
	moss_patch.material_override = moss_mat
	moss_patch.position.y = 0.01
	pivot.add_child(moss_patch)

	# Gnarled trunk segment 1 (base, angled left)
	var segment1 := MeshInstance3D.new()
	var mesh1 := CylinderMesh.new()
	mesh1.radial_segments = 6
	mesh1.top_radius = 0.075 * scale
	mesh1.bottom_radius = 0.11 * scale
	mesh1.height = 0.45 * scale
	segment1.mesh = mesh1
	segment1.material_override = trunk_mat
	segment1.position = Vector3(0.0, 0.22 * scale, 0.0)
	segment1.rotation_degrees.z = -12.0
	pivot.add_child(segment1)

	# Gnarled trunk segment 2 (upper, angled right)
	var segment2 := MeshInstance3D.new()
	var mesh2 := CylinderMesh.new()
	mesh2.radial_segments = 6
	mesh2.top_radius = 0.05 * scale
	mesh2.bottom_radius = 0.075 * scale
	mesh2.height = 0.45 * scale
	segment2.mesh = mesh2
	segment2.material_override = trunk_mat
	segment2.position = Vector3(-0.04 * scale, 0.56 * scale, 0.0)
	segment2.rotation_degrees.z = 18.0
	segment2.rotation_degrees.y = 45.0
	pivot.add_child(segment2)

	# Branch extending off to the right
	var branch1 := MeshInstance3D.new()
	var b_mesh1 := CylinderMesh.new()
	b_mesh1.radial_segments = 5
	b_mesh1.top_radius = 0.03 * scale
	b_mesh1.bottom_radius = 0.05 * scale
	b_mesh1.height = 0.32 * scale
	branch1.mesh = b_mesh1
	branch1.material_override = branch_mat
	branch1.position = Vector3(0.06 * scale, 0.65 * scale, 0.02 * scale)
	branch1.rotation_degrees = Vector3(18.0, -35.0, 48.0)
	pivot.add_child(branch1)

	var leaf_placements := [
		{"pos": Vector3(-0.10 * scale, 0.84 * scale, -0.04 * scale), "radius": 0.25 * scale, "height": 0.30 * scale, "squash": Vector3(1.15, 0.75, 0.95), "color": Color("#7e8d62")},
		{"pos": Vector3(0.16 * scale, 0.76 * scale, 0.08 * scale), "radius": 0.19 * scale, "height": 0.22 * scale, "squash": Vector3(1.0, 0.72, 1.15), "color": Color("#66764f")},
		{"pos": Vector3(0.02 * scale, 0.93 * scale, -0.12 * scale), "radius": 0.20 * scale, "height": 0.24 * scale, "squash": Vector3(0.95, 0.78, 1.05), "color": Color("#879764")},
		{"pos": Vector3(-0.25 * scale, 0.74 * scale, 0.06 * scale), "radius": 0.15 * scale, "height": 0.18 * scale, "squash": Vector3(1.05, 0.72, 0.9), "color": Color("#566849")}
	]

	for placement in leaf_placements:
		var crown_pos: Vector3 = placement["pos"]
		var crown := MeshInstance3D.new()
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = placement["radius"]
		crown_mesh.height = placement["height"]
		crown_mesh.radial_segments = 8
		crown_mesh.rings = 4
		crown.mesh = crown_mesh
		var crown_mat := leaf_mat.duplicate() as StandardMaterial3D
		crown_mat.albedo_color = placement["color"]
		crown.material_override = crown_mat
		crown.position = crown_pos
		crown.scale = placement["squash"]
		crown.rotation_degrees.y = float(crown_pos.x + crown_pos.z) * 120.0
		pivot.add_child(crown)

	var leaf_card_mesh := PlaneMesh.new()
	leaf_card_mesh.size = Vector2(0.52 * scale, 0.38 * scale)
	for i in 3:
		var card := MeshInstance3D.new()
		card.mesh = leaf_card_mesh
		var card_mat := leaf_mat.duplicate() as StandardMaterial3D
		card_mat.albedo_color = [Color("#8a966d"), Color("#6f8058"), Color("#9aa36f")][i]
		card.material_override = card_mat
		card.position = Vector3((-0.10 + float(i) * 0.12) * scale, (0.88 - float(i) * 0.05) * scale, (-0.04 + float(i % 2) * 0.10) * scale)
		card.rotation_degrees = Vector3(0.0, 30.0 + float(i) * 74.0, 0.0)
		pivot.add_child(card)

func _build_crate_stack(terrain_layer: Node3D, position: Vector3, rotation_y: float, scale: float) -> void:
	var offsets := [Vector3.ZERO, Vector3(0.18, 0.0, 0.12), Vector3(0.08, 0.18, 0.03)]
	for i in offsets.size():
		var inst := CHEST_SCENE.instantiate() as Node3D
		inst.position = position + offsets[i] * scale
		inst.scale = Vector3(0.25, 0.25, 0.25) * scale
		inst.rotation_degrees.y = rotation_y + float(i) * 14.0
		_apply_stylized_material(inst, Color.WHITE, true)
		terrain_layer.add_child(inst)
		terrain_meshes.append(inst)

func _build_banner_pair(terrain_layer: Node3D, position: Vector3, rotation_y: float, tint: Color, scale: float) -> void:
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var offset := Vector3(side * 0.26 * scale, 0.0, 0.0)
		var banner := _place_scene_prop(terrain_layer, BANNER_SCENE, position + offset, Vector3(0.32, 0.32, 0.32) * scale, rotation_y, tint, false)
		banner.position.y += 0.05

func _build_small_ruin(terrain_layer: Node3D, position: Vector3, rotation_y: float, scale: float, tint: Color) -> void:
	var box_mesh := BoxMesh.new()
	var mat := _get_terrain_shader_material("memory_stone")
	var offsets := [
		{"pos": Vector3(-0.18, 0.11, -0.1), "scale": Vector3(0.12, 0.22, 0.12)},
		{"pos": Vector3(0.13, 0.08, 0.12), "scale": Vector3(0.15, 0.16, 0.12)},
		{"pos": Vector3(0.0, 0.205, 0.02), "scale": Vector3(0.36, 0.04, 0.10)}
	]
	var pivot := Node3D.new()
	pivot.position = position
	pivot.rotation_degrees.y = rotation_y
	terrain_layer.add_child(pivot)
	terrain_meshes.append(pivot)
	for spec in offsets:
		var block := MeshInstance3D.new()
		block.mesh = box_mesh
		block.material_override = mat
		block.position = spec["pos"] * scale
		block.scale = spec["scale"] * scale
		pivot.add_child(block)

func _build_low_shrine(terrain_layer: Node3D, position: Vector3, color: Color, scale: float) -> void:
	var pivot := Node3D.new()
	pivot.position = position
	terrain_layer.add_child(pivot)
	terrain_meshes.append(pivot)

	var stone_mat := _get_prop_shader_material("memory_stone")
	var metal_mat := StandardMaterial3D.new()
	metal_mat.albedo_color = COLOR_GOLD_INLAY
	metal_mat.roughness = 0.72
	metal_mat.metallic = 0.18
	var stone_tex = load("res://assets/3d/Textures/stylized_stone_floor.png")
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_texture = stone_tex
	glow_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	glow_mat.albedo_color = Color(color.r * 0.7, color.g * 0.7, color.b * 0.8, 0.78)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.emission_enabled = true
	glow_mat.emission = color
	glow_mat.emission_texture = stone_tex
	glow_mat.emission_energy_multiplier = 0.8
	glow_mat.roughness = 0.3
	glow_mat.metallic = 0.4

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.radial_segments = 8
	base_mesh.top_radius = 0.28 * scale
	base_mesh.bottom_radius = 0.34 * scale
	base_mesh.height = 0.16 * scale
	base.mesh = base_mesh
	base.material_override = stone_mat
	base.position.y = 0.08 * scale
	pivot.add_child(base)

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.19 * scale
	ring_mesh.outer_radius = 0.23 * scale
	ring.mesh = ring_mesh
	ring.material_override = metal_mat
	ring.position.y = 0.18 * scale
	ring.scale.y = 0.06
	pivot.add_child(ring)

	var shard := MeshInstance3D.new()
	var shard_mesh := CylinderMesh.new()
	shard_mesh.radial_segments = 6
	shard_mesh.rings = 1
	shard_mesh.top_radius = 0.0
	shard_mesh.bottom_radius = 0.1 * scale
	shard_mesh.height = 0.36 * scale
	shard.mesh = shard_mesh
	shard.material_override = glow_mat
	shard.position.y = 0.36 * scale
	shard.rotation_degrees.y = 30.0
	pivot.add_child(shard)

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.26
	light.omni_range = 1.25
	pivot.add_child(light)

func _build_rune_marker(terrain_layer: Node3D, position: Vector3, color: Color, scale: float) -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.28 * scale
	mesh.outer_radius = 0.34 * scale
	ring.mesh = mesh
	var mat := StandardMaterial3D.new()
	var stone_tex = load("res://assets/3d/Textures/stylized_stone_floor.png")
	mat.albedo_texture = stone_tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_color = Color(color.r, color.g, color.b, 0.62)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_texture = stone_tex
	mat.emission_energy_multiplier = 0.8
	mat.roughness = 0.4
	ring.material_override = mat
	ring.position = position + Vector3(0.0, 0.04, 0.0)
	ring.scale.y = 0.04
	terrain_layer.add_child(ring)
	terrain_meshes.append(ring)

func update_overlays(parent_node: Node3D, context: Dictionary) -> void:
	var terrain_layer: Node3D = parent_node.get_node_or_null("%TerrainLayer")
	if not terrain_layer:
		return

	var move_grids: Dictionary = context.get("move_grids", {})
	var target_grids: Dictionary = context.get("target_grids", {})
	var action_range_grids: Array = context.get("action_range_grids", [])
	var hovered_grid: Vector2i = context.get("hovered_grid", Vector2i(-999, -999))
	var selected_grid: Vector2i = context.get("selected_grid", Vector2i(-999, -999))
	var path: Array = context.get("movement_preview_path", [])

	var cell_heights: Dictionary = context.get("cell_heights", {})
	var active_overlays := {}

	# Helper to create/update an overlay
	var ensure_overlay = func(grid: Vector2i, color: Color, type: String):
		var key := str(grid) + "_" + type
		active_overlays[key] = true
		if not overlay_meshes.has(key):
			var quad = PlaneMesh.new()
			quad.size = Vector2(0.78, 0.78)
			var inst = MeshInstance3D.new()
			inst.mesh = quad
			var mat = StandardMaterial3D.new()
			mat.albedo_color = color
			mat.albedo_color.a = 0.26
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = 0.14
			inst.material_override = mat
			terrain_layer.add_child(inst)
			overlay_meshes[key] = inst

		var inst: MeshInstance3D = overlay_meshes[key]
		var height := float(cell_heights.get(grid, 0)) * HEIGHT_SCALE
		inst.position = Vector3(float(grid.x), height + 0.22, float(grid.y))

	for grid in move_grids.keys():
		ensure_overlay.call(grid, COLOR_MOVE, "move")

	for grid in target_grids.keys():
		ensure_overlay.call(grid, COLOR_TARGET, "target")

	for grid in action_range_grids:
		ensure_overlay.call(grid, Color(0.96, 0.85, 0.47), "range")

	if selected_grid != Vector2i(-999, -999):
		ensure_overlay.call(selected_grid, COLOR_SELECTED, "select")

	if hovered_grid != Vector2i(-999, -999):
		ensure_overlay.call(hovered_grid, COLOR_HOVER, "hover")

	if path.size() > 1:
		for i in range(1, path.size()):
			var grid = path[i]
			var c = COLOR_DESTINATION if i == path.size() - 1 else Color(0.8, 0.9, 0.6)
			ensure_overlay.call(grid, c, "path")

	# Cleanup unused overlays
	var keys_to_remove := []
	for key in overlay_meshes.keys():
		if not active_overlays.has(key):
			var inst: Node3D = overlay_meshes[key]
			inst.queue_free()
			keys_to_remove.append(key)

	for key in keys_to_remove:
		overlay_meshes.erase(key)

func render(parent_node: Node3D, context: Dictionary) -> void:
	pass # Replaced by 3D workflow

func tactical_grid_to_screen(context: Dictionary, grid: Vector2i) -> Vector2:
	return Vector2.ZERO # Obsolete

func screen_to_grid(context: Dictionary, screen_pos: Vector2) -> Vector2i:
	return Vector2i(-999, -999) # Obsolete

func clamp_camera_offset(context: Dictionary, offset: Vector2) -> Vector2:
	# Restrict pan offset in pixels to keep the map in view
	return Vector2(
		clampf(offset.x, -400.0, 400.0),
		clampf(offset.y, -300.0, 300.0)
	)

func _apply_stylized_material(node: Node, albedo_color: Color, force_nearest_only: bool = false, is_parent_stone: bool = false) -> void:
	var name_l := node.name.to_lower()
	var is_non_stone := ("door" in name_l and not "doorway" in name_l) or "bar" in name_l or "metal" in name_l or "banner" in name_l or "flag" in name_l or "wood" in name_l or "plank" in name_l or "crate" in name_l or "chest" in name_l or "cloth" in name_l or "torch" in name_l or "fire" in name_l or "flame" in name_l or "glass" in name_l or "crystal" in name_l
	var is_stone := (is_parent_stone and not is_non_stone) or ("stair" in name_l or "wall" in name_l or ("gate" in name_l and not "bar" in name_l) or "doorway" in name_l or "pillar" in name_l or "obelisk" in name_l or "ruin" in name_l or "shrine" in name_l or "brick" in name_l or "rubble" in name_l or "floor" in name_l)

	if node is MeshInstance3D:
		var orig_mat = node.get_active_material(0)
		if orig_mat == null and node.mesh != null and node.mesh.get_surface_count() > 0:
			orig_mat = node.mesh.surface_get_material(0)

		if is_stone:
			var cache_key := "stone_prop_" + albedo_color.to_html(false)
			var prop_mat: ShaderMaterial
			if _terrain_mat_cache.has(cache_key):
				prop_mat = _terrain_mat_cache[cache_key]
			else:
				prop_mat = ShaderMaterial.new()
				prop_mat.shader = tile_shader
				var tex = load("res://assets/3d/Textures/stylized_stone_floor.png")
				prop_mat.set_shader_parameter("base_texture", tex)
				prop_mat.set_shader_parameter("zone_tint", albedo_color)
				prop_mat.set_shader_parameter("tint_strength", 0.65)
				prop_mat.set_shader_parameter("is_prop", true)
				_terrain_mat_cache[cache_key] = prop_mat
			node.material_override = prop_mat
		else:
			var new_mat := StandardMaterial3D.new()
			if orig_mat is StandardMaterial3D:
				new_mat.albedo_texture = orig_mat.albedo_texture
				new_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				if force_nearest_only:
					new_mat.albedo_color = orig_mat.albedo_color
				else:
					new_mat.albedo_color = orig_mat.albedo_color * albedo_color

				# Smart prop materials based on mesh names
				if "metal" in name_l or "bar" in name_l or "lock" in name_l or "trim" in name_l or "handle" in name_l or "chain" in name_l or "gold" in name_l or "iron" in name_l:
					new_mat.metallic = 0.85
					new_mat.roughness = 0.22
				elif "wood" in name_l or "crate" in name_l or "chest" in name_l or "plank" in name_l or "door" in name_l:
					new_mat.metallic = 0.05
					new_mat.roughness = 0.82
				elif "banner" in name_l or "flag" in name_l or "cloth" in name_l:
					new_mat.metallic = 0.0
					new_mat.roughness = 0.95
				else:
					new_mat.roughness = orig_mat.roughness
					new_mat.metallic = orig_mat.metallic
			else:
				new_mat.albedo_color = albedo_color
				if "metal" in name_l or "bar" in name_l or "lock" in name_l or "trim" in name_l or "handle" in name_l or "chain" in name_l or "gold" in name_l or "iron" in name_l:
					new_mat.metallic = 0.85
					new_mat.roughness = 0.22
				else:
					new_mat.roughness = 0.85
					new_mat.metallic = 0.05
			node.material_override = new_mat

	for child in node.get_children():
		_apply_stylized_material(child, albedo_color, force_nearest_only, is_stone)

func _apply_zone_material(node: Node, terrain_type: String) -> void:
	var mat := _get_terrain_shader_material(terrain_type)
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_zone_material(child, terrain_type)
