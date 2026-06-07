extends Node3D

signal dialog_sequence_finished

const UNIT_SCENE := preload("res://scenes/Unit3D.tscn")
const CHAPTER_DATA := preload("res://data/chapters/chapter_01.tres")
const ENEMY_AI_SCRIPT := preload("res://scripts/enemy_ai.gd")
const COMBAT_RESOLVER_SCRIPT := preload("res://scripts/combat_resolver.gd")
const GRID_STATE_SCRIPT := preload("res://scripts/grid_state.gd")
const BATTLEFIELD_RENDERER_SCRIPT := preload("res://scripts/battlefield_renderer.gd")
const BATTLE_CAMERA_SCRIPT := preload("res://scripts/battle_camera_controller.gd")
const BATTLE_TURN_CONTROLLER_SCRIPT := preload("res://scripts/battle_turn_controller.gd")
const BOARD_PIECE_SCRIPT := preload("res://scripts/board_piece.gd")
const TILE_W := 1.0
const TILE_H := 1.0
const UNIT_CLICK_RADIUS := 40.0
const TARGET_CLICK_RADIUS := 64.0
const INVALID_GRID := Vector2i(-999, -999)
const FEEDBACK_RED := Color("#ff8f70")
const FEEDBACK_GREEN := Color("#9df0bd")
const FEEDBACK_BLUE := Color("#9fd4ff")
const FEEDBACK_GOLD := Color("#f6d878")
const EXP_MOVE := 4
const EXP_DAMAGE := 6
const EXP_DEFEAT := 16
const EXP_HEAL := 8
const EXP_DEFEND := 6
const EXP_WAIT := 3
const EXP_WIN_SURVIVE := 10
const EXP_LOSE_SURVIVE := 4
const TRAP_DAMAGE := 1

enum Phase { INTRO, PLAYER, ENEMY, WIN, LOSE }

var phase: Phase = Phase.INTRO
var selected_unit := -1
var selected_action := "move"
var grid_size := Vector2i(12, 9)
var crystal_hp := 4
var obstacles: Array[Vector2i] = []
var trap_cells: Array[Vector2i] = []
var revealed_traps: Dictionary = {}
var hidden_path_cells: Array[Vector2i] = []
var revealed_hidden_paths: Dictionary = {}
var cell_terrain: Dictionary = {}
var cell_heights: Dictionary = {}
var cell_props: Dictionary = {}
var cell_prop_blocks_movement: Dictionary = {}
var decoration_cells: Array[Dictionary] = []
var hovered_grid := INVALID_GRID
var movement_preview_path: Array[Vector2i] = []
var enemy_intent_path: Array[Vector2i] = []
var action_range_grids: Array[Vector2i] = []
var camera_offset := Vector2.ZERO
var crystal_feedback_text := ""
var crystal_feedback_timer := 0.0
var crystal_feedback_color := Color.WHITE
var player_units: Array[Node] = []
var battle_rewards_applied := false
var battle_result_rows: Array[Dictionary] = []
var triggered_story_events: Dictionary = {}
var shown_tutorials: Dictionary = {}
var level_up_story_pending := false
var enemy_ai: RefCounted
var combat_resolver: RefCounted
var grid_state: RefCounted
var battlefield_renderer: RefCounted
var battle_camera: RefCounted
var turn_controller: RefCounted

var units: Array[Node] = []
var board_pieces: Array[Node] = []

var crystal := {
	"grid": Vector2i(6, 4),
	"color": Color("#9fd4ff")
}

var active_dialog := []
var dialog_index := 0

@onready var unit_layer: Node3D = %UnitLayer
@onready var action_effects: Node2D = %ActionEffects
@onready var battle_ui: Node = %BattleUI
@onready var camera_3d: Camera3D = $CameraPivot/Camera3D
@onready var terrain_layer: Node3D = %TerrainLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enemy_ai = ENEMY_AI_SCRIPT.new()
	combat_resolver = COMBAT_RESOLVER_SCRIPT.new()
	grid_state = GRID_STATE_SCRIPT.new()
	battlefield_renderer = BATTLEFIELD_RENDERER_SCRIPT.new()
	battle_camera = BATTLE_CAMERA_SCRIPT.new()
	turn_controller = BATTLE_TURN_CONTROLLER_SCRIPT.new()
	_load_chapter(CHAPTER_DATA)
	MusicManager.play_chapter(CHAPTER_DATA)
	_build_board_pieces()
	_spawn_units()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	battle_ui.dialog_advanced.connect(_advance_dialog)
	battle_ui.end_turn_requested.connect(_end_player_round)
	battle_ui.action_requested.connect(_on_action_requested)
	battle_ui.target_requested.connect(_choose_target_from_panel)
	battle_ui.unit_requested.connect(_choose_unit_from_panel)
	battle_ui.chapter_intro_started.connect(_start_intro_dialog)
	battle_ui.pause_resume_requested.connect(_resume_battle)
	battle_ui.pause_main_menu_requested.connect(_return_to_main_menu_from_pause)
	battle_ui.result_main_menu_requested.connect(_return_to_main_menu_from_pause)
	_refresh_mission_tracker()
	battle_ui.set_mission_tracker_visible(false)
	battle_ui.show_chapter_intro(CHAPTER_DATA.chapter_name, _chapter_intro_objective(), CHAPTER_DATA.victory_condition, CHAPTER_DATA.defeat_condition)
	_refresh_party_panel()
	_update_end_turn_button()
	battle_ui.hide_action_panel()
	battle_ui.hide_target_panel()
	battle_ui.hide_unit_banner()
	if camera_3d:
		camera_3d.size = 9.4
	call_deferred("_apply_camera_constraints")

	if battlefield_renderer.has_method("render"):
		battlefield_renderer.render(self, _battlefield_render_context())

func _battlefield_render_context() -> Dictionary:
	var layout := _battlefield_layout()
	return {
		"grid_size": grid_size,
		"tile_w": TILE_W,
		"tile_h": TILE_H,
		"origin": layout["origin"],
		"camera_offset": camera_offset,
		"camera_start_offset": layout["camera_start_offset"],
		"camera_min_offset": layout["camera_min_offset"],
		"camera_max_offset": layout["camera_max_offset"],
		"viewport_size": get_viewport().get_visible_rect().size,
		"crystal_grid": crystal["grid"],
		"crystal_color": crystal["color"],
		"crystal_hp": crystal_hp,
		"crystal_max_hp": CHAPTER_DATA.crystal_hp,
		"crystal_feedback_text": crystal_feedback_text,
		"crystal_feedback_timer": crystal_feedback_timer,
		"crystal_feedback_color": crystal_feedback_color,
		"obstacles": obstacles,
		"cell_terrain": cell_terrain,
		"cell_heights": cell_heights,
		"cell_props": cell_props,
		"cell_prop_blocks_movement": cell_prop_blocks_movement,
		"decoration_cells": decoration_cells,
		"move_grids": _current_move_grid_set(),
		"target_grids": _current_target_grid_set(),
		"hovered_grid": hovered_grid,
		"selected_grid": _selected_unit_grid(),
		"revealed_traps": revealed_traps,
		"revealed_hidden_paths": revealed_hidden_paths,
		"enemy_threat_grids": _enemy_threat_grid_set(),
		"action_range_grids": action_range_grids,
		"selected_action": selected_action,
		"enemy_intent_path": enemy_intent_path,
		"movement_preview_path": movement_preview_path,
		"time": Time.get_ticks_msec() / 1000.0,
		"units": units,
		"board_pieces": board_pieces
	}

func _selected_unit_grid() -> Vector2i:
	if selected_unit == -1 or selected_unit >= units.size():
		return INVALID_GRID
	return units[selected_unit].grid

func _battlefield_layout() -> Dictionary:
	return {
		"origin": Vector2.ZERO,
		"camera_start_offset": Vector2.ZERO,
		"camera_min_offset": Vector2(-800.0, -800.0),
		"camera_max_offset": Vector2(800.0, 800.0)
	}

func _current_move_grid_set() -> Dictionary:
	var grids := {}
	if selected_unit == -1 or selected_unit >= units.size():
		return grids
	var actor = units[selected_unit]
	if actor.acted or selected_action != "move":
		return grids
	for grid in grid_state.movement_cells_for(units, actor):
		grids[grid] = true
	return grids

func _current_target_grid_set() -> Dictionary:
	var grids := {}
	if selected_unit == -1:
		return grids
	for target_index in _valid_targets_for_selected_action():
		grids[units[target_index].grid] = true
	return grids

func _enemy_threat_grid_set() -> Dictionary:
	var threat_grids := {}
	if phase != Phase.ENEMY:
		return threat_grids
	for grid in grid_state.threat_cells_for_team(units, "enemy"):
		threat_grids[grid] = true
	return threat_grids

func _process(delta: float) -> void:
	_process_camera_input(delta)
	if crystal_feedback_timer > 0.0:
		crystal_feedback_timer = max(0.0, crystal_feedback_timer - delta)
		if crystal_feedback_timer == 0.0:
			crystal_feedback_text = ""
		_sync_crystal_piece()

	if battlefield_renderer and battlefield_renderer.has_method("update_overlays"):
		battlefield_renderer.update_overlays(self, _battlefield_render_context())

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		battle_camera.stop_dragging()
		if battle_ui.is_results_visible():
			_return_to_main_menu_from_pause()
		elif battle_ui.is_pause_visible():
			_resume_battle()
		else:
			_pause_battle()
		_mark_input_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_HOME or event.keycode == KEY_C:
			_recenter_camera()
			_mark_input_handled()

func _unhandled_input(event: InputEvent) -> void:
	if battle_ui.is_dialog_visible() or battle_ui.is_pause_visible() or battle_ui.is_results_visible():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if camera_3d:
				camera_3d.size = clampf(camera_3d.size - 1.0, 7.4, 24.0)
				_mark_input_handled()
				return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if camera_3d:
				camera_3d.size = clampf(camera_3d.size + 1.0, 8.5, 24.0)
				_mark_input_handled()
				return

	if battle_camera.handles_drag_button(event):
		battle_camera.set_dragging(event.pressed, event.position)
		_mark_input_handled()
		return
	if event is InputEventMouseMotion:
		var drag_delta: Vector2 = battle_camera.drag_delta(event.position)
		if drag_delta != Vector2.ZERO:
			_pan_camera(drag_delta)
			_mark_input_handled()
			return
	if phase != Phase.PLAYER:
		return
	if event is InputEventMouseMotion:
		_update_hovered_grid(event.position)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_update_hovered_grid(event.position)
		_handle_click(event.position)

func _load_chapter(chapter: Resource) -> void:
	grid_size = chapter.grid_size
	crystal_hp = chapter.crystal_hp
	obstacles.clear()
	for obstacle in chapter.obstacles:
		obstacles.append(obstacle)
	trap_cells.clear()
	revealed_traps.clear()
	for trap_cell in chapter.trap_cells:
		trap_cells.append(trap_cell)
	hidden_path_cells.clear()
	revealed_hidden_paths.clear()
	for hidden_path_cell in chapter.hidden_path_cells:
		hidden_path_cells.append(hidden_path_cell)
	_load_map_cells(chapter)
	crystal = {
		"grid": chapter.crystal_grid,
		"color": chapter.crystal_color
	}
	_rebuild_obstacles_from_blocking_props()
	grid_state.configure(grid_size, crystal["grid"], obstacles)

	if battlefield_renderer and battlefield_renderer.has_method("build_terrain"):
		battlefield_renderer.build_terrain(self, _battlefield_render_context())

func _load_map_cells(chapter: Resource) -> void:
	cell_terrain.clear()
	cell_heights.clear()
	cell_props.clear()
	cell_prop_blocks_movement.clear()
	decoration_cells.clear()
	for terrain_cell in chapter.terrain_cells:
		var grid: Vector2i = terrain_cell.get("grid", INVALID_GRID)
		if not _is_grid_inside_chapter_bounds(grid):
			continue
		cell_terrain[grid] = str(terrain_cell.get("terrain", "memory_stone"))
		cell_heights[grid] = int(terrain_cell.get("height", 0))
	for prop_cell in chapter.prop_cells:
		var grid: Vector2i = prop_cell.get("grid", INVALID_GRID)
		if not _is_grid_inside_chapter_bounds(grid):
			continue
		cell_props[grid] = str(prop_cell.get("prop", "rubble"))
		cell_prop_blocks_movement[grid] = bool(prop_cell.get("blocks_movement", false))
	for decoration_cell in chapter.decoration_cells:
		decoration_cells.append(decoration_cell.duplicate(true))

func _rebuild_obstacles_from_blocking_props() -> void:
	# Tactical blockers live in prop_cells. decoration_cells are visual-only.
	for prop in CHAPTER_DATA.prop_cells:
		var grid: Vector2i = prop.get("grid", Vector2i.ZERO)
		var blocks: bool = prop.get("blocks_movement", false)
		if blocks:
			if grid == crystal["grid"] or obstacles.has(grid):
				continue
			obstacles.append(grid)

func _is_grid_inside_chapter_bounds(grid: Vector2i) -> bool:
	return grid.x >= 0 and grid.y >= 0 and grid.x < grid_size.x and grid.y < grid_size.y

func _chapter_intro_objective() -> String:
	if CHAPTER_DATA.tactical_hint == "":
		return CHAPTER_DATA.objective_text
	return "%s\n\n%s" % [CHAPTER_DATA.objective_text, CHAPTER_DATA.tactical_hint]

func _spawn_units() -> void:
	for data in CHAPTER_DATA.unit_spawns:
		var unit = UNIT_SCENE.instantiate()
		unit_layer.add_child(unit)
		var spawn_grid := _valid_spawn_grid(data["grid"])
		var spawn_data := data.duplicate()
		spawn_data["grid"] = spawn_grid
		unit.setup(spawn_data, _unit_world_position(spawn_grid))
		unit.custom_rendered = true
		if unit.unit_name == "Diego":
			unit.is_magic_unstable = CHAPTER_DATA.diego_magic_unstable
		_save_state().apply_to_unit(unit)
		units.append(unit)
		if unit.team == "player":
			player_units.append(unit)
		_orient_unit_toward_cell(unit, crystal["grid"])
	_refresh_unit_depth_order()
	_refresh_revealed_traps()

func _build_board_pieces() -> void:
	for piece in board_pieces:
		if is_instance_valid(piece):
			piece.queue_free()
	board_pieces.clear()
	var crystal_piece = BOARD_PIECE_SCRIPT.new()
	unit_layer.add_child(crystal_piece)
	crystal_piece.setup("crystal", crystal["grid"], int(cell_heights.get(crystal["grid"], 0)), _board_piece_world_position(crystal["grid"]))
	crystal_piece.custom_rendered = true
	board_pieces.append(crystal_piece)
	_sync_crystal_piece()
	for grid in cell_props.keys():
		var prop := str(cell_props[grid])
		if not _is_high_board_prop(prop):
			continue
		var piece = BOARD_PIECE_SCRIPT.new()
		unit_layer.add_child(piece)
		piece.setup(prop, grid, int(cell_heights.get(grid, 0)), _board_piece_world_position(grid))
		piece.custom_rendered = true
		board_pieces.append(piece)
	_refresh_board_piece_depth_order()

func _is_high_board_prop(prop: String) -> bool:
	return prop == "column" or prop == "obelisk" or prop == "banner"

func _process_camera_input(delta: float) -> void:
	var input_locked: bool = battle_ui.is_dialog_visible() or battle_ui.is_pause_visible() or battle_ui.is_results_visible()
	var pan_delta: Vector2 = battle_camera.keyboard_pan_delta(delta, input_locked)
	if pan_delta == Vector2.ZERO:
		return
	_pan_camera(pan_delta)

func _pan_camera(delta: Vector2) -> void:
	_set_camera_offset(camera_offset - delta)

func _recenter_camera() -> void:
	_set_camera_offset(battle_camera.recenter_offset(_battlefield_layout()))

func _apply_camera_constraints() -> void:
	_set_camera_offset(camera_offset)

func _set_camera_offset(next_offset: Vector2) -> void:
	if not camera_3d: return
	var vp_size = get_viewport().get_visible_rect().size
	if vp_size.y == 0: return

	# Optional: clamping can still happen via a simpler bound instead of layout layout constraints
	var max_pan := Vector2(800.0, 800.0)
	var clamped_offset := Vector2(
		clamp(next_offset.x, -max_pan.x, max_pan.x),
		clamp(next_offset.y, -max_pan.y, max_pan.y)
	)

	camera_offset = clamped_offset

	# Apply to CameraPivot
	var pivot = get_node_or_null("CameraPivot")
	if pivot:
		var units_per_pixel = camera_3d.size / vp_size.y
		var offset_3d_x = camera_offset.x * units_per_pixel
		var offset_3d_y = -camera_offset.y * units_per_pixel

		# Move pivot along the camera's local X and Y axes
		var right = camera_3d.global_transform.basis.x.normalized()
		var up = camera_3d.global_transform.basis.y.normalized()

		# Project onto XZ plane so pivot height doesn't change
		var pan_dir_x = Vector3(right.x, 0, right.z).normalized()
		var pan_dir_z = Vector3(up.x, 0, up.z).normalized()

		# The pivot's neutral position is at (0,0,0) (centered on the board).
		var board_center_x = (grid_size.x * TILE_W) / 2.0
		var board_center_z = (grid_size.y * TILE_H) / 2.0
		var base_pos = Vector3(board_center_x, 0, board_center_z)

		pivot.position = base_pos + pan_dir_x * offset_3d_x + pan_dir_z * offset_3d_y
	battle_camera.offset = camera_offset
	_update_unit_world_positions()
	_refresh_movement_preview()

func _update_unit_world_positions() -> void:
	for unit in units:
		if is_instance_valid(unit):
			unit.position = _unit_world_position(unit.grid)
	_update_board_piece_screen_positions()
	_refresh_unit_depth_order()

func _update_board_piece_screen_positions() -> void:
	for piece in board_pieces:
		if is_instance_valid(piece):
			piece.position = _board_piece_world_position(piece.grid)

func _refresh_unit_depth_order() -> void:
	for unit in units:
		if is_instance_valid(unit):
			pass # Z-sorting is handled automatically in 3D
	_refresh_board_piece_depth_order()

func _refresh_board_piece_depth_order() -> void:
	for piece in board_pieces:
		if is_instance_valid(piece):
			pass # Z-sorting is handled automatically in 3D

func _board_piece_world_position(grid: Vector2i) -> Vector3:
	var pos := _unit_world_position(grid)
	pos.y += 0.05
	return pos

func _board_depth_for_grid(grid: Vector2i, screen_position: Vector2, bias := 0) -> int:
	var height_bias := int(cell_heights.get(grid, 0)) * 4
	return int(screen_position.y) + height_bias + bias

func _board_piece_depth_bias(piece_kind: String) -> int:
	if piece_kind == "crystal":
		return 10
	return 0

func _sync_crystal_piece() -> void:
	var piece := _board_piece_for_kind("crystal")
	if piece == null:
		return
	piece.update_crystal_state(crystal_hp, CHAPTER_DATA.crystal_hp, crystal["color"], crystal_feedback_text, crystal_feedback_timer, crystal_feedback_color)

func _board_piece_for_grid(grid: Vector2i) -> Node:
	for piece in board_pieces:
		if is_instance_valid(piece) and piece.grid == grid:
			return piece
	return null

func _board_piece_for_kind(piece_kind: String) -> Node:
	for piece in board_pieces:
		if is_instance_valid(piece) and piece.piece_kind == piece_kind:
			return piece
	return null

func _handle_click(position: Vector2) -> void:
	var clicked_unit := _unit_at_screen(position)
	var grid := screen_to_grid(position)
	if clicked_unit == -1 and not grid_state.is_inside_grid(grid):
		return

	if selected_unit != -1 and selected_action == "move":
		var actor = units[selected_unit]
		if actor.acted:
			_set_status("%s ya actuo este turno." % actor.unit_name)
			return
		if _can_move_to(actor, grid):
			_move_selected_unit(grid)
			return
		if clicked_unit != -1 and units[clicked_unit].team == "player" and clicked_unit != selected_unit:
			_select_player(clicked_unit)
			return
		_set_status("Esa casilla no esta disponible para %s." % actor.unit_name)
		return

	if clicked_unit != -1 and units[clicked_unit].team == "enemy":
		if selected_unit != -1 and (selected_action == "attack" or selected_action == "special"):
			var target_unit := _target_for_action(position, grid, selected_action)
			if target_unit != -1:
				if selected_action == "attack":
					_try_attack(selected_unit, target_unit)
				elif selected_action == "special":
					_try_special(selected_unit, target_unit)
				return
		_inspect_unit(clicked_unit)
		return

	if selected_unit != -1:
		var actor = units[selected_unit]
		if actor.acted:
			_set_status("%s ya actuo este turno." % actor.unit_name)
			return

		var target_unit := _target_for_action(position, grid, selected_action)
		if target_unit != -1:
			if selected_action == "attack":
				_try_attack(selected_unit, target_unit)
			elif selected_action == "special":
				_try_special(selected_unit, target_unit)
			return

	if selected_unit != -1 and clicked_unit != -1 and units[clicked_unit].team == "player" and clicked_unit != selected_unit:
		if selected_action == "special":
			_try_special(selected_unit, clicked_unit)
		else:
			_select_player(clicked_unit)
		return

	if clicked_unit != -1 and units[clicked_unit].team == "player":
		_select_player(clicked_unit)
		return

	if selected_unit == -1:
		_set_status("Selecciona una unidad familiar para actuar.")
		return

	_set_status("Elige un objetivo valido para %s." % _action_label(selected_action))

func _select_player(unit_index: int) -> void:
	var unit = units[unit_index]
	_select_none()
	if unit.acted:
		_set_status("%s ya actuo. Elige a alguien mas o termina el turno." % unit.unit_name)
	else:
		selected_unit = unit_index
		selected_action = "move"
		unit.set_selected(true)
		_show_action_panel(unit)
		_show_unit_banner(unit, "Listo para mover")
		_set_status("%s listo: %s. Movimiento %d, rango %d." % [unit.unit_name, unit.hint, unit.move, unit.attack_range])
		_show_action_tutorial("move")
	_refresh_movement_preview()
	_refresh_party_panel()

func _inspect_unit(unit_index: int) -> void:
	if unit_index < 0 or unit_index >= units.size():
		return
	var unit = units[unit_index]
	if not unit.is_alive():
		return
	if selected_unit >= 0 and selected_unit < units.size():
		units[selected_unit].set_selected(false)
	selected_unit = -1
	selected_action = "move"
	_clear_movement_preview()
	_clear_action_range()
	battle_ui.hide_action_panel()
	battle_ui.hide_target_panel()
	_show_unit_banner(unit, "Unidad enemiga")
	_set_status("%s: %s. Movimiento %d, rango %d." % [unit.unit_name, unit.hint, unit.move, unit.attack_range])
	_refresh_party_panel()

func _select_none() -> void:
	if selected_unit >= 0 and selected_unit < units.size():
		units[selected_unit].set_selected(false)
	selected_unit = -1
	selected_action = "move"
	_clear_movement_preview()
	_clear_action_range()
	battle_ui.hide_action_panel()
	battle_ui.hide_target_panel()
	battle_ui.hide_unit_banner()
	_refresh_party_panel()

func _move_selected_unit(grid: Vector2i) -> void:
	var actor = units[selected_unit]
	var path := _movement_path_for(actor, grid)
	if path.size() > 1:
		var dir := path[-1] - path[-2]
		if abs(dir.x) >= abs(dir.y):
			actor.orientation = Vector2i(sign(dir.x), 0)
		else:
			actor.orientation = Vector2i(0, sign(dir.y))
	actor.move_to_grid(grid, _unit_world_position(grid))
	_refresh_unit_depth_order()
	var trap_damage := _trigger_trap_if_present(actor)
	var revealed_count := _refresh_revealed_traps()
	_award_exp(actor, EXP_MOVE)
	actor.set_acted(true)
	var reveal_note := ""
	if trap_damage > 0:
		reveal_note += " Activa una trampa: -%d HP." % trap_damage
	if revealed_count > 0:
		reveal_note += " Mitzi detecta %d trampa(s)." % revealed_count
	_set_status("%s avanza.%s Quedan %d acciones familiares." % [actor.unit_name, reveal_note, turn_controller.remaining_actions(units)])
	_select_none()
	if _check_battle_end():
		return
	_after_player_action()

func _try_attack(attacker_index: int, target_index: int) -> void:
	var attacker = units[attacker_index]
	var target = units[target_index]
	if not grid_state.is_in_range(attacker.grid, target.grid, attacker.attack_range):
		_set_status("%s no tiene alcance suficiente." % attacker.unit_name)
		return

	var old_orientation = attacker.orientation
	_orient_unit_toward_cell(attacker, target.grid)

	action_effects.play_weapon_attack(camera_3d.unproject_position(attacker.position), camera_3d.unproject_position(target.position), FEEDBACK_GOLD, "ATAQUE")
	await attacker.play_attack_motion(target.position, FEEDBACK_GOLD)

	attacker.orientation = old_orientation

	var result: Dictionary = combat_resolver.resolve_weapon_attack(attacker, target)
	var damage: int = result["damage"]
	_show_unit_hit_feedback(target, damage)
	target.play_hit_motion(attacker.position, FEEDBACK_RED)
	_gain_limit_charge_from_damage(attacker)
	_gain_limit_charge_from_damage(target)
	_award_exp(attacker, EXP_DAMAGE)
	attacker.set_acted(true)
	_set_status("%s usa %s contra %s. HP enemigo: %d/%d" % [attacker.unit_name, attacker.hint, target.unit_name, target.hp, target.max_hp])
	if result["target_defeated"]:
		_award_exp(attacker, EXP_DEFEAT)
		_remove_unit(target_index)
		_refresh_mission_tracker()
		_set_status("%s cae. Quedan %d acciones familiares." % [target.unit_name, turn_controller.remaining_actions(units)])
		_try_story_event("first_enemy_defeated", CHAPTER_DATA.first_enemy_defeated_lines)
	_select_none()
	_after_player_action()

func _try_heal(healer_index: int, target_index: int) -> void:
	var healer = units[healer_index]
	var target = units[target_index]
	if not healer.can_heal():
		_set_status("%s no puede curar." % healer.unit_name)
		return
	if healer_index == target_index:
		_set_status("Hercules necesita cuidar a alguien mas en este prototipo.")
		return
	if not grid_state.is_in_range(healer.grid, target.grid, 1):
		_set_status("Hercules debe estar adyacente para proteger y curar.")
		return
	if target.hp >= target.max_hp:
		_set_status("%s ya esta con HP completo." % target.unit_name)
		return

	var old_orientation = healer.orientation
	_orient_unit_toward_cell(healer, target.grid)

	action_effects.play_heal([camera_3d.unproject_position(target.position)], FEEDBACK_GREEN, "CURA")
	await healer.play_cast_motion(FEEDBACK_BLUE)

	healer.orientation = old_orientation
	var result: Dictionary = combat_resolver.resolve_heal(healer, target)
	var healed: int = result["healed"]
	target.show_feedback("+%d" % healed, FEEDBACK_GREEN)
	target.show_flash(FEEDBACK_GREEN)
	target.play_cast_motion(FEEDBACK_GREEN)
	_award_exp(healer, EXP_HEAL)
	healer.set_acted(true)
	_select_none()
	_set_status("Hercules protege a %s. HP: %d/%d" % [target.unit_name, target.hp, target.max_hp])
	_after_player_action()

func _try_team_heal(healer_index: int) -> void:
	var healer = units[healer_index]
	if not healer.can_team_heal():
		_set_status("%s no puede usar Cura+." % healer.unit_name)
		return

	var heals: Array[Dictionary] = combat_resolver.resolve_team_heal(healer, units)
	if heals.is_empty():
		_set_status("El equipo ya esta con HP completo.")
		return

	var heal_positions: Array[Vector3] = []
	for heal_result in heals:
		heal_positions.append(heal_result["unit"].position)
	var screen_heal_positions: Array[Vector2] = []
	for p in heal_positions:
		screen_heal_positions.append(camera_3d.unproject_position(p))
	action_effects.play_heal(screen_heal_positions, FEEDBACK_GREEN, "CURA+")
	healer.play_cast_motion(FEEDBACK_BLUE)
	for heal_result in heals:
		var target: Node = heal_result["unit"]
		target.show_feedback("+%d" % heal_result["healed"], FEEDBACK_GREEN)
		target.show_flash(FEEDBACK_GREEN)
		target.play_cast_motion(FEEDBACK_GREEN)
	_award_exp(healer, EXP_HEAL)
	healer.set_acted(true)
	_select_none()
	_set_status("%s usa Cura+ y restaura a %d aliado(s)." % [healer.unit_name, heals.size()])
	_after_player_action()

func _try_special(actor_index: int, target_index: int) -> void:
	var actor = units[actor_index]
	var target = units[target_index]
	if actor.can_team_heal() and target_index == actor_index:
		_try_team_heal(actor_index)
		return
	if actor.can_heal() and target.team == "player":
		_try_heal(actor_index, target_index)
		return
	if actor.role == "Mage" and target.team == "enemy":
		_try_magic(actor_index, target_index)
		return
	if actor.is_limit_ready() and target.team == "enemy":
		_try_limit_break(actor_index, target_index)
		return
	_set_status("%s no tiene una accion especial para ese objetivo." % actor.unit_name)

func _try_limit_break(actor_index: int, target_index: int) -> void:
	var actor = units[actor_index]
	var target = units[target_index]
	if not actor.is_limit_ready():
		_set_status("%s aun no tiene listo el Corte del Aguila." % actor.unit_name)
		return
	if not grid_state.is_in_range(actor.grid, target.grid, actor.attack_range):
		_set_status("%s no tiene alcance suficiente para el Corte del Aguila." % actor.unit_name)
		return

	var old_orientation = actor.orientation
	_orient_unit_toward_cell(actor, target.grid)

	action_effects.play_limit_break(camera_3d.unproject_position(actor.position), camera_3d.unproject_position(target.position), FEEDBACK_GOLD, "CORTE DEL AGUILA")
	actor.play_cast_motion(FEEDBACK_GOLD)
	await actor.play_attack_motion(target.position, FEEDBACK_GOLD)

	actor.orientation = old_orientation
	var result: Dictionary = combat_resolver.resolve_limit_break(actor, target)
	var damage: int = result["damage"]
	_show_unit_hit_feedback(target, damage)
	target.play_hit_motion(actor.position, FEEDBACK_RED)
	_award_exp(actor, EXP_DAMAGE)
	actor.set_acted(true)
	_set_status("%s desata Corte del Aguila contra %s. HP enemigo: %d/%d" % [actor.unit_name, target.unit_name, target.hp, target.max_hp])
	if result["target_defeated"]:
		_award_exp(actor, EXP_DEFEAT)
		_remove_unit(target_index)
		_refresh_mission_tracker()
		_try_story_event("first_enemy_defeated", CHAPTER_DATA.first_enemy_defeated_lines)
	_select_none()
	_after_player_action()

func _try_magic(caster_index: int, target_index: int) -> void:
	var caster = units[caster_index]
	var target = units[target_index]
	if not grid_state.is_in_range(caster.grid, target.grid, caster.attack_range):
		_set_status("%s no tiene alcance magico suficiente." % caster.unit_name)
		return
	var hits: Array[Dictionary] = combat_resolver.resolve_magic_aoe(caster, units, target.grid, caster.magic_aoe_radius, caster.is_magic_unstable)
	if hits.is_empty():
		_set_status("%s no encuentra objetivos en el area magica." % caster.unit_name)
		return
	var old_orientation = caster.orientation
	_orient_unit_toward_cell(caster, target.grid)

	action_effects.play_magic(camera_3d.unproject_position(caster.position), camera_3d.unproject_position(_unit_world_position(target.grid)), float(max(1, caster.magic_aoe_radius) + 1) * 42.0, FEEDBACK_BLUE, "MAGIA")
	await caster.play_cast_motion(FEEDBACK_BLUE)

	caster.orientation = old_orientation
	var enemy_hits := 0
	var ally_hits := 0
	for hit in hits:
		var hit_unit: Node = hit["unit"]
		_show_unit_hit_feedback(hit_unit, hit["damage"])
		hit_unit.play_hit_motion(caster.position, FEEDBACK_RED)
		if hit_unit.team == "enemy":
			enemy_hits += 1
		elif hit_unit.team == "player":
			ally_hits += 1
	if enemy_hits > 0:
		_award_exp(caster, EXP_DAMAGE)
	caster.set_acted(true)
	var defeated_indices: Array[int] = []
	for hit in hits:
		if hit["target_defeated"]:
			defeated_indices.append(hit["index"])
	defeated_indices.sort()
	defeated_indices.reverse()
	for defeated_index in defeated_indices:
		if units[defeated_index].team == "enemy":
			_award_exp(caster, EXP_DEFEAT)
		_remove_unit(defeated_index)
	if not defeated_indices.is_empty():
		_refresh_mission_tracker()
		_try_story_event("first_enemy_defeated", CHAPTER_DATA.first_enemy_defeated_lines)
	var friendly_note := ""
	if ally_hits > 0:
		friendly_note = " Fuego inestable roza a %d aliado(s)." % ally_hits
	_set_status("%s lanza %s en area: %d enemigo(s) alcanzado(s).%s" % [caster.unit_name, caster.hint, enemy_hits, friendly_note])
	_select_none()
	_after_player_action()

func _after_player_action() -> void:
	if _check_battle_end():
		return
	_move_support_guides()
	_update_end_turn_button()
	if turn_controller.remaining_actions(units) == 0:
		_end_player_round()

func _end_player_round() -> void:
	if phase != Phase.PLAYER:
		return
	_select_none()
	phase = Phase.ENEMY
	_update_end_turn_button()
	_try_story_event("enemy_turn", CHAPTER_DATA.enemy_turn_lines)
	_set_status("La Orden Sin Memoria se mueve...")
	await _wait_for_dialog_if_visible()
	_show_tutorial("enemy_turn", "Ritmo enemigo", CHAPTER_DATA.enemy_turn_tutorial)
	await get_tree().create_timer(0.45).timeout
	_take_enemy_turns()

func _take_enemy_turns() -> void:
	var enemy_indices: Array[int] = turn_controller.enemy_turn_order(units, enemy_ai)
	for enemy_index in enemy_indices:
		if enemy_index >= units.size() or units[enemy_index].team != "enemy" or not units[enemy_index].is_alive():
			continue
		await _take_enemy_action(enemy_index)
		if _check_battle_end():
			_clear_enemy_intent()
			return
		await get_tree().create_timer(0.35).timeout

	_clear_enemy_intent()
	turn_controller.reset_actions(units)
	phase = Phase.PLAYER
	_refresh_party_panel()
	_update_end_turn_button()
	battle_ui.hide_unit_banner()
	_show_tutorial("player_turn", "Nueva ronda", CHAPTER_DATA.player_turn_tutorial)
	_set_status("Turno familiar. Selecciona a Erick, Mitzi, Diego o Hercules.")

func _take_enemy_action(enemy_index: int) -> void:
	var enemy = units[enemy_index]
	var target_index := _enemy_attack_target_for(enemy)
	if target_index != -1 and grid_state.is_in_range(enemy.grid, units[target_index].grid, enemy.attack_range):
		var target = units[target_index]
		_set_enemy_attack_intent(enemy.grid, target.grid)
		_show_unit_banner(enemy, "Ataca a %s" % target.unit_name)
		_set_status("%s prepara un ataque contra %s." % [enemy.unit_name, target.unit_name])
		await get_tree().create_timer(0.25).timeout
		var old_orientation = enemy.orientation
		_orient_unit_toward_cell(enemy, target.grid)
		action_effects.play_weapon_attack(camera_3d.unproject_position(enemy.position), camera_3d.unproject_position(target.position), FEEDBACK_GOLD, "ATAQUE")
		await enemy.play_attack_motion(target.position, FEEDBACK_GOLD)
		enemy.orientation = old_orientation
		var evasion_reduction := _evasion_damage_reduction_for(target)
		var result: Dictionary = combat_resolver.resolve_weapon_attack(enemy, target, evasion_reduction)
		var damage: int = result["damage"]
		_show_unit_hit_feedback(target, damage)
		await target.play_hit_motion(enemy.position, FEEDBACK_RED)
		_gain_limit_charge_from_damage(target)
		_try_story_event("first_player_hurt", CHAPTER_DATA.first_player_hurt_lines)
		await _wait_for_dialog_if_visible()
		_clear_enemy_intent()
		var evasion_note := ""
		if evasion_reduction > 0:
			evasion_note = " La evasion de Mitzi reduce el golpe."
		_set_status("%s ataca a %s. HP: %d/%d.%s" % [enemy.unit_name, target.unit_name, target.hp, target.max_hp, evasion_note])
		if result["target_defeated"]:
			_remove_unit(target_index)
		return

	if grid_state.is_in_range(enemy.grid, crystal["grid"], 1):
		_set_enemy_attack_intent(enemy.grid, crystal["grid"])
		_show_unit_banner(enemy, "Golpea el cristal")
		_set_status("%s apunta al cristal." % enemy.unit_name)
		await get_tree().create_timer(0.25).timeout
		var old_orientation = enemy.orientation
		_orient_unit_toward_cell(enemy, crystal["grid"])
		action_effects.play_weapon_attack(camera_3d.unproject_position(enemy.position), camera_3d.unproject_position(_board_piece_world_position(crystal["grid"])), FEEDBACK_GOLD, "CRISTAL")
		await enemy.play_attack_motion(_board_piece_world_position(crystal["grid"]), FEEDBACK_GOLD)
		enemy.orientation = old_orientation
		crystal_hp -= 1
		_show_crystal_feedback("-1", FEEDBACK_RED)
		_refresh_mission_tracker()
		if crystal_hp <= int(ceil(float(CHAPTER_DATA.crystal_hp) * 0.5)):
			_try_story_event("crystal_low_hp", CHAPTER_DATA.crystal_low_hp_lines)
			await _wait_for_dialog_if_visible()
		_clear_enemy_intent()
		_set_status("%s golpea el cristal. Integridad: %d/%d" % [enemy.unit_name, crystal_hp, CHAPTER_DATA.crystal_hp])
		return

	var path := _enemy_movement_path(enemy)
	if path.size() <= 1:
		_show_unit_banner(enemy, "Sin ruta")
		_set_status("%s no encuentra paso hacia el cristal." % enemy.unit_name)
		return
	enemy_intent_path = path
	_show_unit_banner(enemy, "Avanza hacia el cristal")
	_set_status("%s busca una ruta hacia el cristal." % enemy.unit_name)
	await get_tree().create_timer(0.35).timeout
	var step_index = min(enemy.move, path.size() - 1)
	if step_index >= 1:
		var dir := path[step_index] - path[step_index - 1]
		if abs(dir.x) >= abs(dir.y):
			enemy.orientation = Vector2i(sign(dir.x), 0)
		else:
			enemy.orientation = Vector2i(0, sign(dir.y))
	var next_grid := path[step_index]
	enemy.move_to_grid(next_grid, _unit_world_position(next_grid))
	_refresh_unit_depth_order()
	_clear_enemy_intent()
	_set_status("%s avanza hacia el cristal." % enemy.unit_name)

func _enemy_attack_target_for(enemy: Node) -> int:
	var candidates: Array[Dictionary] = []
	for i in grid_state.unit_indices_in_range(units, enemy.grid, "player", enemy.attack_range):
		var distance: int = grid_state.distance(enemy.grid, units[i].grid)
		candidates.append({
			"index": i,
			"hp": units[i].hp,
			"max_hp": units[i].max_hp,
			"distance": distance,
			"role": units[i].role
		})
	return enemy_ai.choose_attack_target(candidates)

func _remove_unit(unit_index: int) -> void:
	var unit = units[unit_index]
	if unit_index == selected_unit:
		selected_unit = -1
	elif unit_index < selected_unit:
		selected_unit -= 1
	units.remove_at(unit_index)
	unit.queue_free()
	_refresh_party_panel()
	_refresh_mission_tracker()

func _check_battle_end() -> bool:
	var outcome: String = turn_controller.battle_outcome(units, crystal_hp)
	if outcome == "win":
		phase = Phase.WIN
		_update_end_turn_button()
		_finalize_battle_rewards(true)
		_show_dialog(_battle_end_lines(CHAPTER_DATA.outro_win_lines))
		return true
	if outcome == "lose":
		phase = Phase.LOSE
		_update_end_turn_button()
		_finalize_battle_rewards(false)
		_show_dialog(_battle_end_lines(CHAPTER_DATA.outro_lose_lines))
		return true
	return false

func _award_exp(unit: Node, amount: int) -> void:
	if unit.team != "player" or not unit.is_alive():
		return
	unit.add_battle_exp(amount)

func _gain_limit_charge_from_damage(unit: Node) -> void:
	if unit.team != "player" or not unit.is_alive() or not unit.can_limit_break():
		return
	var previous_charge: int = unit.limit_charge
	unit.gain_limit_charge(1)
	if unit.limit_charge == previous_charge:
		return
	if unit.is_limit_ready():
		unit.show_feedback("CORTE", FEEDBACK_GOLD)
	else:
		unit.show_feedback("LIM %d/%d" % [unit.limit_charge, unit.limit_charge_max], FEEDBACK_BLUE)
	_refresh_combat_ui_for_unit(unit)

func _refresh_combat_ui_for_unit(unit: Node) -> void:
	if not is_node_ready():
		return
	_refresh_party_panel()
	if selected_unit >= 0 and selected_unit < units.size() and units[selected_unit] == unit:
		_show_action_panel(unit)
		_show_unit_banner(unit, _banner_state_for_action(selected_action))
		_refresh_target_panel()

func _finalize_battle_rewards(victory: bool) -> void:
	if battle_rewards_applied:
		return
	battle_rewards_applied = true
	battle_result_rows.clear()

	for unit in player_units:
		if not is_instance_valid(unit):
			continue
		if unit.is_alive():
			_award_exp(unit, EXP_WIN_SURVIVE if victory else EXP_LOSE_SURVIVE)

	for unit in player_units:
		if not is_instance_valid(unit):
			continue
		var result: Dictionary = unit.apply_pending_exp()
		if result["level_ups"] > 0 and not triggered_story_events.has("first_level_up"):
			triggered_story_events["first_level_up"] = true
			level_up_story_pending = true
		battle_result_rows.append({
			"name": unit.unit_name,
			"role": unit.role,
			"portrait_texture": unit.portrait_texture,
			"level": unit.level,
			"exp": unit.exp,
			"exp_to_next": unit.exp_to_next,
			"gained": result["gained"],
			"level_ups": result["level_ups"],
			"max_hp_gain": result["max_hp_gain"],
			"attack_gain": result["attack_gain"],
			"heal_gain": result["heal_gain"],
			"alive": unit.is_alive()
		})

	if victory:
		_save_state().save_units(player_units)

func _battle_end_lines(base_lines: Array) -> Array:
	var lines := base_lines.duplicate()
	if level_up_story_pending:
		lines.append_array(CHAPTER_DATA.first_level_up_lines)
		level_up_story_pending = false
	return lines

func _show_battle_results() -> void:
	var victory := phase == Phase.WIN
	var objective := "Cristal protegido" if victory else "La memoria necesita otro intento"
	battle_ui.show_results(victory, objective, battle_result_rows)

func _save_state() -> Node:
	return get_node("/root/SaveState")

func _show_dialog(lines: Array) -> void:
	if lines.is_empty():
		return
	active_dialog = lines
	dialog_index = 0
	_render_dialog_line()

func _try_story_event(event_key: String, lines: Array) -> void:
	if triggered_story_events.has(event_key) or lines.is_empty():
		return
	triggered_story_events[event_key] = true
	_show_dialog(lines)

func _wait_for_dialog_if_visible() -> void:
	if battle_ui.is_dialog_visible():
		await dialog_sequence_finished

func _advance_dialog() -> void:
	dialog_index += 1
	if dialog_index >= active_dialog.size():
		battle_ui.hide_dialog()
		dialog_sequence_finished.emit()
		if phase == Phase.INTRO:
			phase = Phase.PLAYER
			_set_status("Turno familiar. Cada personaje puede actuar una vez.")
			_show_tutorial("opening", "Primer objetivo", CHAPTER_DATA.opening_tutorial)
			_update_end_turn_button()
		elif phase == Phase.WIN:
			_set_status("Victoria del prototipo. Pulsa Esc para volver al menu.")
			_show_battle_results()
		elif phase == Phase.LOSE:
			_set_status("Derrota del prototipo. Pulsa Esc para volver al menu.")
			_show_battle_results()
		return
	_render_dialog_line()

func _start_intro_dialog() -> void:
	battle_ui.hide_chapter_intro()
	battle_ui.set_mission_tracker_visible(true)
	_show_dialog(CHAPTER_DATA.intro_lines)

func _render_dialog_line() -> void:
	var line = active_dialog[dialog_index]
	battle_ui.show_dialog_line(line["speaker"], line["text"])

func _on_action_requested(action: String) -> void:
	if action == "move" or action == "attack" or action == "special":
		_set_selected_action(action)
	elif action == "defend":
		_choose_defend()
	elif action == "wait":
		_choose_wait()

func _choose_defend() -> void:
	if selected_unit == -1:
		return
	var unit = units[selected_unit]
	_show_action_tutorial("defend")
	unit.set_defending(true)
	unit.show_feedback("DEF", FEEDBACK_BLUE)
	action_effects.play_guard(camera_3d.unproject_position(unit.position), FEEDBACK_BLUE, "DEFENSA")
	unit.play_guard_motion(FEEDBACK_BLUE)
	_award_exp(unit, EXP_DEFEND)
	unit.set_acted(true)
	_set_status("%s defiende. El proximo dano recibido se reduce." % unit.unit_name)
	_select_none()
	_after_player_action()

func _choose_wait() -> void:
	if selected_unit == -1:
		return
	var unit = units[selected_unit]
	_show_action_tutorial("wait")
	unit.show_feedback("WAIT", FEEDBACK_GOLD)
	unit.show_flash(FEEDBACK_GOLD)
	_award_exp(unit, EXP_WAIT)
	unit.set_acted(true)
	_set_status("%s espera. Quedan %d acciones familiares." % [unit.unit_name, turn_controller.remaining_actions(units)])
	_select_none()
	_after_player_action()

func _set_selected_action(action: String) -> void:
	if selected_unit == -1:
		return
	selected_action = action
	var unit = units[selected_unit]
	_show_unit_banner(unit, _banner_state_for_action(action))
	_set_status("%s: elige objetivo para %s." % [unit.unit_name, _action_label(action)])
	_show_action_tutorial(action)
	_refresh_movement_preview()
	_refresh_action_range()
	_refresh_target_panel()

func _show_action_panel(unit: Node) -> void:
	battle_ui.show_action_panel(unit)

func _show_unit_banner(unit: Node, state_text: String) -> void:
	battle_ui.show_unit_banner(unit, state_text)

func _show_action_tutorial(action: String) -> void:
	if action == "move":
		_show_tutorial("move", "Mover", CHAPTER_DATA.move_tutorial)
	elif action == "attack":
		_show_tutorial("attack", "Atacar", CHAPTER_DATA.attack_tutorial)
	elif action == "special":
		_show_tutorial("special", "Especial", CHAPTER_DATA.special_tutorial)
	elif action == "defend":
		_show_tutorial("defend", "Defender", CHAPTER_DATA.defend_tutorial)
	elif action == "wait":
		_show_tutorial("wait", "Esperar", CHAPTER_DATA.wait_tutorial)

func _show_tutorial(key: String, title: String, text: String) -> void:
	if text == "":
		return
	if shown_tutorials.has(key):
		return
	shown_tutorials[key] = true
	battle_ui.show_guide(title, text)

func _refresh_target_panel() -> void:
	var targets := _valid_targets_for_selected_action()
	if targets.is_empty():
		battle_ui.hide_target_panel()
		return
	var target_rows: Array[Dictionary] = []
	for target_index in targets:
		var target = units[target_index]
		target_rows.append({
			"index": target_index,
			"name": target.unit_name,
			"hp": target.hp,
			"max_hp": target.max_hp,
			"portrait_texture": target.portrait_texture
		})
	battle_ui.show_targets(target_rows)

func _choose_target_from_panel(target_index: int) -> void:
	if selected_unit == -1 or target_index < 0 or target_index >= units.size():
		return
	if selected_action == "attack":
		_try_attack(selected_unit, target_index)
	elif selected_action == "special":
		_try_special(selected_unit, target_index)

func _choose_unit_from_panel(unit_index: int) -> void:
	if phase != Phase.PLAYER or unit_index < 0 or unit_index >= units.size():
		return
	if units[unit_index].team != "player":
		return
	_select_player(unit_index)

func _refresh_party_panel() -> void:
	if not is_node_ready():
		return
	var party_rows: Array[Dictionary] = []
	for i in units.size():
		var unit = units[i]
		if unit.team != "player":
			continue
		party_rows.append({
			"index": i,
			"name": unit.unit_name,
			"hp": unit.hp,
			"max_hp": unit.max_hp,
			"limit_charge": unit.limit_charge,
			"limit_charge_max": unit.limit_charge_max,
			"acted": unit.acted,
			"selected": i == selected_unit,
			"alive": unit.is_alive(),
			"portrait_texture": unit.portrait_texture
		})
	battle_ui.show_party(party_rows)

func _valid_targets_for_selected_action() -> Array[int]:
	var targets: Array[int] = []
	if selected_unit == -1:
		return targets

	var actor = units[selected_unit]
	if selected_action == "attack":
		return grid_state.unit_indices_in_range(units, actor.grid, "enemy", actor.attack_range)

	if selected_action != "special":
		return targets

	if actor.can_team_heal() and _has_injured_allies(actor.team):
		targets.append(selected_unit)
	if actor.can_heal():
		for i in grid_state.unit_indices_in_range(units, actor.grid, "player", 1, selected_unit):
			if units[i].hp < units[i].max_hp:
				targets.append(i)
	if actor.role == "Mage":
		targets.append_array(grid_state.unit_indices_in_range(units, actor.grid, "enemy", actor.attack_range))
	if actor.is_limit_ready():
		for i in grid_state.unit_indices_in_range(units, actor.grid, "enemy", actor.attack_range):
			if not targets.has(i):
				targets.append(i)
	return targets

func _has_injured_allies(team: String) -> bool:
	for unit in units:
		if unit.team == team and unit.is_alive() and unit.hp < unit.max_hp:
			return true
	return false

func _action_label(action: String) -> String:
	if action == "move":
		return "mover"
	if action == "attack":
		return "atacar"
	if action == "special":
		return "especial"
	return action

func _banner_state_for_action(action: String) -> String:
	if action == "move":
		return "Listo para mover"
	if action == "attack":
		return "Elige objetivo para atacar"
	if action == "special":
		return "Elige objetivo especial"
	return action

func grid_to_screen(grid: Vector2i) -> Vector2:
	if not camera_3d: return Vector2.ZERO
	return camera_3d.unproject_position(_unit_world_position(grid))

func _unit_world_position(grid: Vector2i) -> Vector3:
	var height := int(cell_heights.get(grid, 0))
	return Vector3(grid.x, float(height) * 0.5, grid.y)

func _unit_screen_position(grid: Vector2i) -> Vector3:
	return _unit_world_position(grid)


func _show_unit_hit_feedback(unit: Node, damage: int) -> void:
	unit.show_feedback("-%d" % damage, FEEDBACK_RED)
	unit.show_flash(FEEDBACK_RED)

func _show_crystal_feedback(text: String, color: Color) -> void:
	crystal_feedback_text = text
	crystal_feedback_color = color
	crystal_feedback_timer = 0.9
	_sync_crystal_piece()

func screen_to_grid(screen_pos: Vector2) -> Vector2i:
	if not camera_3d: return Vector2i(-999, -999)
	var ray_origin := camera_3d.project_ray_origin(screen_pos)
	var ray_dir := camera_3d.project_ray_normal(screen_pos)

	var best_grid = Vector2i(-999, -999)
	var best_dist = 999999.0

	for y in grid_size.y:
		for x in grid_size.x:
			var g = Vector2i(x, y)
			var h = float(cell_heights.get(g, 0)) * 0.5
			if ray_dir.y != 0:
				var t = (h - ray_origin.y) / ray_dir.y
				if t > 0:
					var pt = ray_origin + ray_dir * t
					if abs(pt.x - x) <= 0.5 and abs(pt.z - y) <= 0.5:
						var d = ray_origin.distance_to(pt)
						if d < best_dist:
							best_dist = d
							best_grid = g

	return best_grid

func _can_move_to(unit: Node, grid: Vector2i) -> bool:
	return not _movement_path_for(unit, grid).is_empty()

func _valid_spawn_grid(requested_grid: Vector2i) -> Vector2i:
	var spawn_grid: Vector2i = grid_state.nearest_open_cell(units, requested_grid)
	if spawn_grid == requested_grid:
		return requested_grid
	push_warning("Spawn bloqueado en %s; reubicando unidad a %s." % [requested_grid, spawn_grid])
	return spawn_grid

func _movement_path_for(unit: Node, grid: Vector2i) -> Array[Vector2i]:
	return grid_state.movement_path_for(units, unit, grid)

func _update_hovered_grid(position: Vector2) -> void:
	var next_grid := screen_to_grid(position)
	if next_grid == hovered_grid:
		return
	hovered_grid = next_grid
	_refresh_movement_preview()

func _refresh_movement_preview() -> void:
	if selected_unit == -1 or selected_action != "move" or selected_unit >= units.size():
		_clear_movement_preview()
		return
	var actor = units[selected_unit]
	if actor.acted:
		_clear_movement_preview()
		return
	movement_preview_path = _movement_path_for(actor, hovered_grid)

func _clear_movement_preview() -> void:
	movement_preview_path.clear()

func _refresh_action_range() -> void:
	action_range_grids.clear()
	if selected_unit == -1 or selected_unit >= units.size():
		return
	if selected_action != "attack" and selected_action != "special":
		return

	var actor = units[selected_unit]
	var action_range: int = actor.attack_range
	if selected_action == "special" and actor.can_heal():
		action_range = 1
	elif selected_action == "special" and actor.role != "Mage" and not actor.is_limit_ready():
		return

	action_range_grids = grid_state.action_range_cells(actor.grid, action_range)

func _clear_action_range() -> void:
	action_range_grids.clear()

func _path_between(from_cell: Vector2i, to_cell: Vector2i, moving_unit: Node = null) -> Array[Vector2i]:
	return grid_state.path_between(units, from_cell, to_cell, moving_unit)

func _unit_at_screen(position: Vector2) -> int:
	var closest_index := -1
	var closest_distance := UNIT_CLICK_RADIUS
	for i in range(units.size() - 1, -1, -1):
		if not units[i].is_alive():
			continue
		var distance := position.distance_to(camera_3d.unproject_position(units[i].global_position))
		if distance <= closest_distance:
			closest_distance = distance
			closest_index = i
	return closest_index

func _target_for_action(position: Vector2, grid: Vector2i, action: String) -> int:
	if action == "attack":
		return _unit_at_screen_or_grid(position, grid, "enemy")
	if action == "special":
		var actor = units[selected_unit]
		if actor.can_team_heal():
			return _unit_at_screen_or_grid(position, grid, "player")
		if actor.can_heal():
			return _unit_at_screen_or_grid(position, grid, "player", selected_unit)
		if actor.role == "Mage":
			return _unit_at_screen_or_grid(position, grid, "enemy")
		if actor.is_limit_ready():
			return _unit_at_screen_or_grid(position, grid, "enemy")
	return -1

func _unit_at_screen_or_grid(position: Vector2, grid: Vector2i, team: String, excluded_index := -1) -> int:
	var screen_target := _unit_at_screen_for_team(position, team, excluded_index)
	if screen_target != -1:
		return screen_target

	var grid_target: int = grid_state.unit_at(units, grid)
	if grid_target != -1 and grid_target != excluded_index and units[grid_target].team == team:
		return grid_target
	return -1

func _unit_at_screen_for_team(position: Vector2, team: String, excluded_index := -1) -> int:
	var closest_index := -1
	var closest_distance := TARGET_CLICK_RADIUS
	for i in range(units.size() - 1, -1, -1):
		if i == excluded_index or not units[i].is_alive() or units[i].team != team:
			continue
		var distance := position.distance_to(camera_3d.unproject_position(units[i].global_position))
		if distance <= closest_distance:
			closest_distance = distance
			closest_index = i
	return closest_index

func _is_target_grid_for_selected_action(grid: Vector2i) -> bool:
	if selected_action == "move":
		return false
	for target_index in _valid_targets_for_selected_action():
		if units[target_index].grid == grid:
			return true
	return false

func _refresh_revealed_traps() -> int:
	var revealed_count := 0
	for trap_cell in trap_cells:
		if revealed_traps.has(trap_cell):
			continue
		if _can_any_unit_detect_trap(trap_cell):
			revealed_traps[trap_cell] = true
			revealed_count += 1
	return revealed_count

func _trigger_trap_if_present(unit: Node) -> int:
	if unit.team != "player" or not unit.is_alive() or not trap_cells.has(unit.grid):
		return 0
	var damage: int = unit.take_damage(TRAP_DAMAGE)
	unit.show_feedback("-%d" % damage, FEEDBACK_RED)
	unit.show_flash(FEEDBACK_RED)
	revealed_traps[unit.grid] = true
	trap_cells.erase(unit.grid)
	return damage

func _reveal_hidden_paths(lines: Array = []) -> int:
	var revealed_count := 0
	for hidden_path_cell in hidden_path_cells:
		if revealed_hidden_paths.has(hidden_path_cell):
			continue
		revealed_hidden_paths[hidden_path_cell] = true
		obstacles.erase(hidden_path_cell)
		cell_prop_blocks_movement[hidden_path_cell] = false
		revealed_count += 1
	if revealed_count == 0:
		return 0
	grid_state.configure(grid_size, crystal["grid"], obstacles)
	if not lines.is_empty():
		_show_dialog(lines)
	return revealed_count

func _can_any_unit_detect_trap(trap_cell: Vector2i) -> bool:
	for unit in units:
		if unit.team != "player" or not unit.is_alive() or unit.trap_detection_radius <= 0:
			continue
		if grid_state.is_in_range(unit.grid, trap_cell, unit.trap_detection_radius):
			return true
	return false

func _evasion_damage_reduction_for(target: Node) -> int:
	if target.team != "player" or not target.is_alive():
		return 0
	var reduction := 0
	for unit in units:
		if unit.team != target.team or not unit.is_alive() or unit.evasion_aura_radius <= 0:
			continue
		if grid_state.is_in_range(unit.grid, target.grid, unit.evasion_aura_radius):
			reduction = max(reduction, unit.evasion_damage_reduction)
	return reduction

func _move_support_guides() -> void:
	for unit in units:
		if unit.team != "support" or not unit.is_alive() or not unit.is_noncombatant:
			continue
		var target := _lowest_hp_player_unit()
		if target == null:
			continue
		var path := _support_path_toward(unit, target)
		if path.size() > 1:
			var step_index: int = min(unit.move, path.size() - 1)
			if step_index >= 1:
				var dir := path[step_index] - path[step_index - 1]
				if abs(dir.x) >= abs(dir.y):
					unit.orientation = Vector2i(sign(dir.x), 0)
				else:
					unit.orientation = Vector2i(0, sign(dir.y))
			unit.move_to_grid(path[step_index], _unit_world_position(path[step_index]))
			_refresh_unit_depth_order()
		if unit.spiritual_aura_heal > 0 and grid_state.is_in_range(unit.grid, target.grid, unit.spiritual_aura_radius) and target.hp < target.max_hp:
			var healed: int = target.heal_amount(unit.spiritual_aura_heal)
			if healed > 0:
				target.show_feedback("+%d" % healed, FEEDBACK_GREEN)
				unit.show_flash(FEEDBACK_BLUE)

func _lowest_hp_player_unit() -> Node:
	var target: Node = null
	var lowest_ratio := 2.0
	for unit in units:
		if unit.team != "player" or not unit.is_alive():
			continue
		var ratio := float(unit.hp) / float(max(1, unit.max_hp))
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			target = unit
	return target

func _support_path_toward(support_unit: Node, target: Node) -> Array[Vector2i]:
	var best_path: Array[Vector2i] = []
	for destination in grid_state.adjacent_cells(target.grid, true, units, support_unit):
		var path := _path_between(support_unit.grid, destination, support_unit)
		if path.size() <= 1:
			continue
		if best_path.is_empty() or path.size() < best_path.size():
			best_path = path
	return best_path

func _enemy_path_toward_crystal(enemy: Node) -> Array[Vector2i]:
	var best_path: Array[Vector2i] = []
	for destination in grid_state.adjacent_cells(crystal["grid"], true, units, enemy):
		var path := _path_between(enemy.grid, destination, enemy)
		if path.size() <= 1:
			continue
		if best_path.is_empty() or path.size() < best_path.size():
			best_path = path
	if best_path.is_empty():
		return []
	return best_path

func _enemy_movement_path(enemy: Node) -> Array[Vector2i]:
	var options: Array[Dictionary] = []
	_add_enemy_crystal_path_options(enemy, options)
	_add_enemy_pressure_path_options(enemy, options)
	return enemy_ai.choose_movement_path(options)

func _add_enemy_crystal_path_options(enemy: Node, options: Array[Dictionary]) -> void:
	for destination in grid_state.adjacent_cells(crystal["grid"], true, units, enemy):
		var path := _path_between(enemy.grid, destination, enemy)
		if path.size() <= 1:
			continue
		options.append({
			"path": path,
			"score": _enemy_crystal_score(enemy, path)
		})

func _add_enemy_pressure_path_options(enemy: Node, options: Array[Dictionary]) -> void:
	for i in units.size():
		if units[i].team != "player" or not units[i].is_alive():
			continue
		for destination in _attack_cells_for(enemy, units[i].grid):
			var path := _path_between(enemy.grid, destination, enemy)
			if path.size() <= 1:
				continue
			options.append({
				"path": path,
				"score": _enemy_pressure_score(enemy, units[i], path)
			})

func _attack_cells_for(enemy: Node, target_grid: Vector2i) -> Array[Vector2i]:
	return grid_state.attack_cells_for(units, enemy, target_grid)

func _enemy_crystal_score(enemy: Node, path: Array[Vector2i]) -> float:
	var role_bonus := 0.0
	if enemy.role == "Guard":
		role_bonus = 12.0
	elif enemy.role == "Adept":
		role_bonus = 7.0
	return 56.0 + role_bonus - float(path.size()) * 4.0

func _enemy_pressure_score(enemy: Node, target: Node, path: Array[Vector2i]) -> float:
	var missing_hp := 1.0 - float(target.hp) / float(max(1, target.max_hp))
	var role_bonus := 0.0
	if enemy.role == "Bowman":
		role_bonus = 14.0
	elif enemy.role == "Adept":
		role_bonus = 8.0
	return 44.0 + role_bonus + missing_hp * 24.0 - float(path.size()) * 3.0

func _set_enemy_attack_intent(from_grid: Vector2i, to_grid: Vector2i) -> void:
	enemy_intent_path = [from_grid, to_grid]

func _clear_enemy_intent() -> void:
	enemy_intent_path.clear()

func _set_status(message: String) -> void:
	battle_ui.set_status(message)

func _mark_input_handled() -> void:
	if not is_inside_tree():
		return
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()

func _pause_battle() -> void:
	battle_ui.show_pause_menu()
	get_tree().paused = true

func _resume_battle() -> void:
	get_tree().paused = false
	battle_ui.hide_pause_menu()

func _return_to_main_menu_from_pause() -> void:
	get_tree().paused = false
	battle_ui.hide_pause_menu()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _refresh_mission_tracker() -> void:
	var objective := CHAPTER_DATA.objective_short
	if objective == "":
		objective = CHAPTER_DATA.objective_text
	battle_ui.set_mission_tracker(CHAPTER_DATA.chapter_name, objective, crystal_hp, CHAPTER_DATA.crystal_hp, turn_controller.unit_indices_by_team(units, "enemy").size())

func _update_end_turn_button() -> void:
	if not is_node_ready():
		return
	battle_ui.set_end_turn_enabled(phase == Phase.PLAYER)

func _orient_unit_toward_cell(unit: Node, target_grid: Vector2i) -> void:
	if unit.grid == target_grid:
		return
	var diff := target_grid - Vector2i(unit.grid)
	if abs(diff.x) >= abs(diff.y):
		unit.orientation = Vector2i(sign(diff.x), 0)
	else:
		unit.orientation = Vector2i(0, sign(diff.y))

func _on_viewport_size_changed() -> void:
	var layout := _battlefield_layout()
	camera_offset = battle_camera.constrained_offset(camera_offset, layout, _battlefield_render_context(), battlefield_renderer)
	battle_camera.offset = camera_offset
	_update_unit_world_positions()
	_refresh_movement_preview()
