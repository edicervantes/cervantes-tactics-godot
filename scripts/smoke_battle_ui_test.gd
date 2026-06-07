extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_state: Node = root.get_node("/root/SaveState")
	save_state.save_path = "user://cervantes_smoke_save.json"
	save_state.reset_all_slots()
	var battle_scene: PackedScene = load("res://scenes/Battle3D.tscn")
	var battle := battle_scene.instantiate()
	root.add_child(battle)
	await process_frame
	var music_manager: Node = root.get_node("/root/MusicManager")

	if battle.CHAPTER_DATA.objective_text == "" or battle.CHAPTER_DATA.victory_condition == "" or battle.CHAPTER_DATA.defeat_condition == "":
		push_error("Chapter mission metadata was not configured.")
		quit(1)
		return

	if battle.CHAPTER_DATA.objective_short == "":
		push_error("Chapter short objective was not configured.")
		quit(1)
		return

	if battle.CHAPTER_DATA.music_stream == null:
		push_error("Chapter music stream was not configured.")
		quit(1)
		return

	if music_manager.current_music_id != "chapter:%s" % battle.CHAPTER_DATA.chapter_name or music_manager.player.stream == null or not music_manager.player.playing:
		push_error("Battle did not start chapter music.")
		quit(1)
		return

	if not music_manager.player.stream is AudioStreamMP3 or not music_manager.player.stream.loop:
		push_error("Chapter music was not configured to loop.")
		quit(1)
		return

	if not battle.battle_ui.get_node("%ChapterIntroPanel").visible:
		push_error("Chapter intro panel was not visible during intro.")
		quit(1)
		return

	if battle.battle_ui.is_dialog_visible():
		push_error("Dialog should not open before the mission intro starts it.")
		quit(1)
		return

	if battle.battle_ui.get_node("%TopBar").visible:
		push_error("Mission tracker should stay hidden until the player starts the mission.")
		quit(1)
		return

	if not _has_responsive_battle_ui_anchors(battle.battle_ui):
		push_error("Battle UI did not keep responsive anchors on core HUD panels.")
		quit(1)
		return

	if battle.battle_ui.get_node("%PartyPanel").visible or battle.battle_ui.get_node("%EndTurnButton").visible:
		push_error("Combat controls should stay hidden during mission intro.")
		quit(1)
		return

	if battle.battle_ui.get_node("%IntroChapterLabel").text != battle.CHAPTER_DATA.chapter_name:
		push_error("Chapter intro did not show the chapter name.")
		quit(1)
		return

	if not battle.battle_ui.get_node("%ObjectiveLabel").text.contains(battle.CHAPTER_DATA.objective_short):
		push_error("Mission tracker did not show the short objective.")
		quit(1)
		return

	if not battle.battle_ui.get_node("%IntroConditionsLabel").text.contains(battle.CHAPTER_DATA.victory_condition):
		push_error("Mission intro did not show the victory condition.")
		quit(1)
		return

	battle.battle_ui.chapter_intro_started.emit()
	await process_frame

	if battle.battle_ui.get_node("%ChapterIntroPanel").visible:
		push_error("Chapter intro panel did not hide when starting dialog.")
		quit(1)
		return

	if not battle.battle_ui.get_node("%TopBar").visible:
		push_error("Mission tracker did not appear after starting the mission.")
		quit(1)
		return

	if not battle.battle_ui.get_node("%PartyPanel").visible or not battle.battle_ui.get_node("%EndTurnButton").visible:
		push_error("Combat controls did not appear after starting the mission.")
		quit(1)
		return

	if not battle.battle_ui.is_dialog_visible():
		push_error("Dialog did not open after starting the chapter intro.")
		quit(1)
		return

	var intro_steps := 0
	while battle.phase == battle.Phase.INTRO:
		battle._advance_dialog()
		await process_frame
		intro_steps += 1
		if intro_steps > 12:
			push_error("Battle did not leave intro dialog.")
			quit(1)
			return

	if battle.battle_ui.get_node("%GuidePanel").visible:
		push_error("Opening tutorial guide should stay folded into the mission HUD.")
		quit(1)
		return

	if not battle.battle_ui.get_node("%TopText").text.contains("Selecciona una unidad"):
		push_error("Opening tutorial did not show in the mission HUD.")
		quit(1)
		return

	var party_vbox: VBoxContainer = battle.battle_ui.get_node("%PartyVBox")
	var party_buttons := 0
	for child in party_vbox.get_children():
		if child is Button:
			party_buttons += 1

	if party_buttons != 4:
		push_error("Expected 4 party buttons, got %d." % party_buttons)
		quit(1)
		return

	# Unit draw depth is handled by 3D rendering engine automatically.

	var original_erick_screen: Vector2 = battle.grid_to_screen(battle.units[0].grid)
	var recentered_camera_offset: Vector2 = battle.camera_offset
	if battle.battle_camera == null or battle.battle_camera.offset != battle.camera_offset:
		push_error("Battle did not initialize the extracted camera controller.")
		quit(1)
		return
	var render_context: Dictionary = battle._battlefield_render_context()
	var obelisk_grid := Vector2i(11, 2)
	var non_blocking_decoration_grid := Vector2i(10, 1)
	if render_context["cell_terrain"].get(Vector2i(6, 4), "") != "crystal_dais":
		push_error("Chapter I did not load explicit crystal dais terrain data.")
		quit(1)
		return
	if render_context["cell_heights"].get(Vector2i(6, 4), -1) != 2:
		push_error("Chapter I did not load explicit crystal dais height data.")
		quit(1)
		return
	if render_context["cell_props"].get(obelisk_grid, "") != "obelisk":
		push_error("Chapter I did not load explicit prop data for blocking cells.")
		quit(1)
		return
	if not render_context["cell_prop_blocks_movement"].get(obelisk_grid, false):
		push_error("Chapter I did not load prop blocking data.")
		quit(1)
		return
	if render_context["cell_terrain"].get(Vector2i(9, 4), "") != "order_influence":
		push_error("Battlefield renderer did not read terrain from chapter data.")
		quit(1)
		return
	if battle.board_pieces.size() != 5:
		push_error("Battle did not instantiate the expected high board props.")
		quit(1)
		return
	var crystal_piece: Node = battle._board_piece_for_kind("crystal")
	if crystal_piece == null or crystal_piece.crystal_hp != battle.crystal_hp:
		push_error("Battle did not promote the crystal into a depth-sorted board piece.")
		quit(1)
		return
	var obelisk_piece: Node = battle._board_piece_for_grid(obelisk_grid)
	if obelisk_piece == null or obelisk_piece.piece_kind != "obelisk":
		push_error("Battle did not promote the obelisk prop into a depth-sorted board piece.")
		quit(1)
		return
	var original_obelisk_screen: Vector2 = battle.grid_to_screen(obelisk_piece.grid)
	var original_crystal_screen: Vector2 = battle.grid_to_screen(crystal_piece.grid)
	battle._pan_camera(Vector2(-80, 48))
	await process_frame

	if battle.camera_offset == recentered_camera_offset:
		push_error("Battle camera did not pan away from its starting offset.")
		quit(1)
		return
	if battle.battle_camera.offset != battle.camera_offset:
		push_error("Extracted camera controller did not stay synced after panning.")
		quit(1)
		return

	if battle.grid_to_screen(battle.units[0].grid) == original_erick_screen:
		push_error("Battle camera pan did not move unit screen positions.")
		quit(1)
		return
	if battle.grid_to_screen(obelisk_piece.grid) == original_obelisk_screen:
		push_error("Battle camera pan did not move board prop screen positions.")
		quit(1)
		return
	if battle.grid_to_screen(crystal_piece.grid) == original_crystal_screen:
		push_error("Battle camera pan did not move crystal board piece screen position.")
		quit(1)
		return
	# Board prop depth is handled by 3D rendering engine automatically.

	if battle.screen_to_grid(battle.grid_to_screen(Vector2i(1, 1))) != Vector2i(1, 1):
		push_error("Battle camera broke grid/screen coordinate conversion.")
		quit(1)
		return

	battle._recenter_camera()
	var expected_recentered_offset: Vector2 = battle._battlefield_render_context()["camera_start_offset"]
	if battle.camera_offset != expected_recentered_offset:
		push_error("Battle camera did not recenter.")
		quit(1)
		return
	if battle.battle_camera.offset != battle.camera_offset:
		push_error("Extracted camera controller did not stay synced after recentering.")
		quit(1)
		return

	battle._pause_battle()

	if not paused:
		push_error("Battle pause did not pause the scene tree.")
		_cleanup(save_state)
		quit(1)
		return

	if not battle.battle_ui.is_pause_visible():
		push_error("Pause menu did not become visible.")
		_cleanup(save_state)
		quit(1)
		return

	battle._resume_battle()

	if paused:
		push_error("Battle resume did not unpause the scene tree.")
		_cleanup(save_state)
		quit(1)
		return

	if battle.battle_ui.is_pause_visible():
		push_error("Pause menu stayed visible after resume.")
		_cleanup(save_state)
		quit(1)
		return

	battle.battle_ui.unit_requested.emit(0)

	if battle.selected_unit != 0:
		push_error("Party panel did not select unit 0.")
		quit(1)
		return

	if not battle.battle_ui.get_node("%ActionPanel").visible:
		push_error("Action panel was not visible after party selection.")
		quit(1)
		return

	if not battle.battle_ui.get_node("%UnitBanner").visible:
		push_error("Unit banner was not visible after party selection.")
		quit(1)
		return

	if battle.battle_ui.get_node("%BannerName").text != "Erick":
		push_error("Unit banner did not show the selected unit name.")
		quit(1)
		return

	if battle.units[0].limit_charge_max != 3 or battle.units[0].limit_damage_multiplier != 3:
		push_error("Erick Limit Break stats were not configured.")
		quit(1)
		return

	if not battle.battle_ui.get_node("%BannerStats").text.contains("LIM 0/3"):
		push_error("Unit banner did not show Erick Limit Break charge.")
		quit(1)
		return

	var special_button: Button = battle.battle_ui.get_node("%SpecialButton")
	if special_button.text != "Corte 0/3" or not special_button.disabled:
		push_error("Erick special button did not show locked Limit Break charge.")
		quit(1)
		return

	var portrait_texture: TextureRect = battle.battle_ui.get_node("%PortraitTexture")
	if not portrait_texture.visible or portrait_texture.texture == null:
		push_error("Unit banner did not show the selected unit portrait.")
		quit(1)
		return

	for unit in battle.units:
		if battle.grid_state.is_cell_blocked(battle.units, unit.grid, unit):
			push_error("%s spawned on a blocked grid cell." % unit.unit_name)
			quit(1)
			return
		if unit.standee_texture == null:
			push_error("%s did not load a board standee texture." % unit.unit_name)
			quit(1)
			return

	var diego = battle.units[2]
	if diego.magic_aoe_radius != 1:
		push_error("Diego magic AoE radius was not configured.")
		quit(1)
		return

	if diego.is_magic_unstable:
		push_error("Diego should start with stable magic in Chapter I.")
		quit(1)
		return

	var mitzi = battle.units[1]
	if mitzi.trap_detection_radius != 2 or mitzi.evasion_aura_radius != 2 or mitzi.evasion_damage_reduction != 1:
		push_error("Mitzi trap detection and evasion aura stats were not configured.")
		quit(1)
		return

	if not battle.trap_cells.has(Vector2i(2, 5)) or not battle.revealed_traps.has(Vector2i(2, 5)):
		push_error("Mitzi did not reveal the nearby Chapter I trap.")
		quit(1)
		return

	var diego_hp_before_trap: int = diego.hp
	diego.move_to_grid(Vector2i(2, 5), battle._unit_screen_position(Vector2i(2, 5)))
	var trap_damage: int = battle._trigger_trap_if_present(diego)
	if trap_damage != battle.TRAP_DAMAGE or diego.hp != diego_hp_before_trap - battle.TRAP_DAMAGE or battle.trap_cells.has(Vector2i(2, 5)):
		push_error("Trap did not damage Diego and consume itself.")
		quit(1)
		return
	diego.move_to_grid(Vector2i(2, 6), battle._unit_screen_position(Vector2i(2, 6)))
	diego.hp = diego_hp_before_trap
	battle.trap_cells.append(Vector2i(2, 5))
	battle.revealed_traps[Vector2i(2, 5)] = true

	if battle._evasion_damage_reduction_for(battle.units[0]) != 1:
		push_error("Mitzi evasion aura did not protect nearby Erick.")
		quit(1)
		return

	if not battle.battle_ui.get_node("%TopText").text.contains("Mover"):
		push_error("Move tutorial did not appear after selecting a unit.")
		quit(1)
		return

	if not battle.obstacles.has(Vector2i(3, 4)):
		push_error("Chapter abstract obstacles were not loaded.")
		quit(1)
		return
	if not battle.obstacles.has(obelisk_grid):
		push_error("Blocking props were not promoted into pathfinding obstacles.")
		quit(1)
		return
	if battle.obstacles.has(non_blocking_decoration_grid):
		push_error("Decorative props should not block pathfinding.")
		quit(1)
		return
	for prop_cell in battle.CHAPTER_DATA.prop_cells:
		var prop_grid: Vector2i = prop_cell.get("grid", battle.INVALID_GRID)
		var blocks_movement: bool = prop_cell.get("blocks_movement", false)
		if blocks_movement:
			if not battle.obstacles.has(prop_grid):
				push_error("Blocking prop at %s was not promoted into an obstacle." % prop_grid)
				quit(1)
				return
			if not battle.grid_state.is_cell_blocked(battle.units, prop_grid):
				push_error("Blocking prop at %s allowed a unit to stand on it." % prop_grid)
				quit(1)
				return
		elif battle.obstacles.has(prop_grid):
			push_error("Non-blocking prop at %s was promoted into an obstacle." % prop_grid)
			quit(1)
			return
	for decoration_cell in battle.CHAPTER_DATA.decoration_cells:
		var decoration_grid: Vector2i = decoration_cell.get("grid", battle.INVALID_GRID)
		if battle.cell_props.has(decoration_grid):
			continue
		if battle.grid_state.is_static_blocker(decoration_grid):
			push_error("Visual decoration at %s became a tactical blocker." % decoration_grid)
			quit(1)
			return

	var erick = battle.units[0]
	var clear_move_grid := Vector2i(2, 3)
	if battle._can_move_to(erick, Vector2i(3, 4)):
		push_error("Pathfinding allowed Erick through an abstract blocking obstacle.")
		quit(1)
		return
	if not battle.grid_state.is_cell_blocked(battle.units, obelisk_grid):
		push_error("Pathfinding did not treat blocking prop as blocked.")
		quit(1)
		return
	if battle.grid_state.is_obstacle(non_blocking_decoration_grid):
		push_error("Pathfinding treated decorative prop as a terrain obstacle.")
		quit(1)
		return

	if not battle._can_move_to(erick, clear_move_grid):
		push_error("Pathfinding rejected a clear reachable tile.")
		quit(1)
		return

	if battle.grid_state == null or battle.combat_resolver == null:
		push_error("Battle did not initialize extracted grid/combat systems.")
		quit(1)
		return
	if battle.turn_controller == null:
		push_error("Battle did not initialize the extracted turn controller.")
		quit(1)
		return

	if not battle.grid_state.is_cell_blocked(battle.units, battle.crystal["grid"]):
		push_error("Extracted grid state did not treat the crystal as a blocked cell.")
		quit(1)
		return
	if not battle.grid_state.is_obstacle(Vector2i(3, 4)):
		push_error("Extracted grid state did not preserve chapter obstacles.")
		quit(1)
		return
	if not battle.grid_state.is_obstacle(obelisk_grid):
		push_error("Extracted grid state did not preserve blocking prop obstacles.")
		quit(1)
		return
	if battle.grid_state.is_static_blocker(non_blocking_decoration_grid):
		push_error("Extracted grid state treated a decorative prop cell as a static blocker.")
		quit(1)
		return

	var guardia_blocks_movement: bool = battle.units[4].blocks_movement
	battle.units[4].blocks_movement = false
	if battle.grid_state.is_cell_blocked(battle.units, battle.units[4].grid):
		push_error("Extracted grid state treated a non-blocking support-style unit as blocked.")
		quit(1)
		return
	battle.units[4].blocks_movement = guardia_blocks_movement

	var fallback_spawn_grid: Vector2i = battle.grid_state.nearest_open_cell(battle.units, obelisk_grid)
	if fallback_spawn_grid == obelisk_grid or battle.grid_state.is_cell_blocked(battle.units, fallback_spawn_grid):
		push_error("Extracted grid state did not find an open fallback for a blocked spawn cell.")
		quit(1)
		return

	var erick_action_range: Array[Vector2i] = battle.grid_state.action_range_cells(erick.grid, erick.attack_range)
	if erick_action_range.has(battle.crystal["grid"]) or erick_action_range.has(Vector2i(3, 4)):
		push_error("Extracted grid state action range included crystal or obstacle cells.")
		quit(1)
		return

	var extracted_path: Array[Vector2i] = battle.grid_state.movement_path_for(battle.units, erick, clear_move_grid)
	if extracted_path.size() != 2 or extracted_path[0] != erick.grid or extracted_path[-1] != clear_move_grid:
		push_error("Extracted grid state returned a movement path that differs from battle expectations.")
		quit(1)
		return
	if not battle.grid_state.movement_cells_for(battle.units, erick).has(clear_move_grid):
		push_error("Extracted grid state movement cells did not include a clear reachable tile.")
		quit(1)
		return
	if battle.grid_state.movement_cells_for(battle.units, erick).has(Vector2i(3, 4)):
		push_error("Extracted grid state movement cells included a blocked obstacle.")
		quit(1)
		return

	battle._update_hovered_grid(battle.grid_to_screen(clear_move_grid))

	if battle.movement_preview_path.size() != 2:
		push_error("Expected movement preview path cost 1, got path size %d." % battle.movement_preview_path.size())
		quit(1)
		return
	var focus_context: Dictionary = battle._battlefield_render_context()
	if focus_context["hovered_grid"] != clear_move_grid or focus_context["selected_grid"] != erick.grid:
		push_error("Battlefield render context did not expose hover and selected tactical focus.")
		quit(1)
		return

	if battle.movement_preview_path[0] != erick.grid or battle.movement_preview_path[-1] != clear_move_grid:
		push_error("Movement preview path endpoints were incorrect.")
		quit(1)
		return

	var erick_original_grid: Vector2i = erick.grid
	var guardia_for_overlap = battle.units[4]
	var guardia_original_position: Vector3 = guardia_for_overlap.position
	guardia_for_overlap.position = battle._unit_world_position(clear_move_grid)
	battle._handle_click(battle.grid_to_screen(clear_move_grid))

	if erick.grid != clear_move_grid:
		push_error("Move click did not prioritize a valid tile when a unit visually overlapped it.")
		quit(1)
		return

	erick.move_to_grid(erick_original_grid, battle._unit_screen_position(erick_original_grid))
	erick.set_acted(false)
	guardia_for_overlap.position = guardia_original_position
	battle._refresh_unit_depth_order()
	battle._select_player(0)

	battle._set_selected_action("attack")

	if not battle.movement_preview_path.is_empty():
		push_error("Movement preview did not clear when leaving move mode.")
		quit(1)
		return

	if battle.battle_ui.get_node("%BannerState").text != "Elige objetivo para atacar":
		push_error("Unit banner did not update after changing action.")
		quit(1)
		return

	if not battle.battle_ui.get_node("%TopText").text.contains("Atacar"):
		push_error("Attack tutorial did not appear after choosing attack.")
		quit(1)
		return

	if battle.action_range_grids.is_empty():
		push_error("Attack range overlay did not populate when choosing attack.")
		quit(1)
		return
	if not battle._current_target_grid_set().is_empty():
		push_error("Erick should not have an attack target in range at the opening position.")
		quit(1)
		return

	var guardia_target_grid: Vector2i = battle.units[4].grid
	erick.move_to_grid(Vector2i(9, 4), battle._unit_screen_position(Vector2i(9, 4)))
	battle._refresh_unit_depth_order()
	battle._select_player(0)
	battle._set_selected_action("attack")
	if not battle._valid_targets_for_selected_action().has(4):
		push_error("Extracted grid state target range did not expose a valid enemy attack target.")
		quit(1)
		return
	if not battle._current_target_grid_set().has(guardia_target_grid):
		push_error("Target grid set did not mirror extracted grid target range.")
		quit(1)
		return
	erick.move_to_grid(erick_original_grid, battle._unit_screen_position(erick_original_grid))
	battle._refresh_unit_depth_order()
	battle._select_player(0)
	battle._set_selected_action("attack")

	battle._inspect_unit(4)
	if battle.selected_unit != -1:
		push_error("Inspecting an enemy should not keep a player unit selected.")
		quit(1)
		return

	if not battle.battle_ui.get_node("%UnitBanner").visible:
		push_error("Inspecting an enemy did not show the unit banner.")
		quit(1)
		return

	if battle.battle_ui.get_node("%BannerName").text != "Guardia Sin Memoria":
		push_error("Enemy inspect did not show enemy stats in the unit banner.")
		quit(1)
		return

	battle._select_none()

	if battle.battle_ui.get_node("%UnitBanner").visible:
		push_error("Unit banner did not hide after clearing selection.")
		quit(1)
		return

	battle._try_story_event("first_enemy_defeated", battle.CHAPTER_DATA.first_enemy_defeated_lines)
	if not battle.battle_ui.is_dialog_visible():
		push_error("Story event dialog did not open.")
		quit(1)
		return

	var dialog_portrait: TextureRect = battle.battle_ui.get_node("%DialogPortraitTexture")
	if not dialog_portrait.visible or dialog_portrait.texture == null:
		push_error("Story event dialog did not show a speaker portrait.")
		quit(1)
		return

	battle._try_story_event("first_enemy_defeated", battle.CHAPTER_DATA.first_enemy_defeated_lines)
	if battle.triggered_story_events.size() != 1:
		push_error("Story event fired more than once.")
		quit(1)
		return

	while battle.battle_ui.is_dialog_visible():
		battle._advance_dialog()

	var guardia = battle.units[4]
	var enemy_path: Array[Vector2i] = battle._enemy_path_toward_crystal(guardia)
	if enemy_path.size() <= 1:
		push_error("Enemy intent path was not calculated.")
		quit(1)
		return

	if enemy_path[0] != guardia.grid:
		push_error("Enemy intent path did not start on the enemy grid.")
		quit(1)
		return

	var enemy_indices: Array[int] = battle.turn_controller.unit_indices_by_team(battle.units, "enemy")
	if enemy_indices.size() != 3:
		push_error("Extracted turn controller did not report the expected living enemies.")
		quit(1)
		return
	var seen_turn_orders := {}
	for seed_value in range(1, 13):
		battle.enemy_ai.set_seed(seed_value)
		var turn_order: Array[int] = battle.turn_controller.enemy_turn_order(battle.units, battle.enemy_ai)
		seen_turn_orders[str(turn_order)] = true

	if seen_turn_orders.size() <= 1:
		push_error("Enemy AI turn order did not vary across seeded openings.")
		quit(1)
		return

	var ai_path: Array[Vector2i] = battle._enemy_movement_path(guardia)
	if ai_path.size() <= 1:
		push_error("Enemy AI did not choose a movement path.")
		quit(1)
		return

	if ai_path[0] != guardia.grid:
		push_error("Enemy AI path did not start on the enemy grid.")
		quit(1)
		return

	var ai_step_index: int = min(guardia.move, ai_path.size() - 1)
	if battle.grid_state.is_cell_blocked(battle.units, ai_path[ai_step_index], guardia):
		push_error("Enemy AI selected a blocked movement step.")
		quit(1)
		return

	var hidden_path_cell := Vector2i(3, 4)
	if not battle.grid_state.is_cell_blocked(battle.units, hidden_path_cell):
		push_error("Hidden path test requires an initially blocked cell.")
		quit(1)
		return
	battle.hidden_path_cells.clear()
	battle.hidden_path_cells.append(hidden_path_cell)
	var revealed_paths: int = battle._reveal_hidden_paths(battle.CHAPTER_DATA.hidden_path_revealed_lines)
	if revealed_paths != 1 or battle.grid_state.is_cell_blocked(battle.units, hidden_path_cell) or not battle.revealed_hidden_paths.has(hidden_path_cell):
		push_error("Tuffy hidden path reveal did not open the blocked cell.")
		quit(1)
		return
	if battle.cell_prop_blocks_movement.get(hidden_path_cell, true):
		push_error("Hidden path reveal did not clear the matching prop blocking flag.")
		quit(1)
		return
	if not battle.battle_ui.is_dialog_visible() or battle.battle_ui.get_node("%Speaker").text != "Tuffy":
		push_error("Hidden path reveal did not present Tuffy as a contextual guide.")
		quit(1)
		return
	while battle.battle_ui.is_dialog_visible():
		battle._advance_dialog()

	battle._set_enemy_attack_intent(guardia.grid, battle.crystal["grid"])
	if battle.enemy_intent_path.size() != 2:
		push_error("Enemy attack intent did not render a simple intent path.")
		quit(1)
		return

	battle._clear_enemy_intent()
	if not battle.enemy_intent_path.is_empty():
		push_error("Enemy intent did not clear.")
		quit(1)
		return

	var damage_done: int = erick.take_damage(2)
	if damage_done != 2 or erick.feedback_text != "":
		push_error("Direct damage returned an unexpected value or created feedback by itself.")
		quit(1)
		return

	battle._show_unit_hit_feedback(erick, damage_done)
	if erick.feedback_text != "-2" or erick.feedback_timer <= 0.0 or erick.flash_timer <= 0.0:
		push_error("Unit hit feedback did not start correctly.")
		quit(1)
		return

	var healed: int = erick.heal_amount(2)
	erick.show_feedback("+%d" % healed, Color("#9df0bd"))
	if healed != 2 or erick.feedback_text != "+2":
		push_error("Unit heal feedback did not start correctly.")
		quit(1)
		return

	var resolver_hp_before: int = erick.hp
	var resolver_result: Dictionary = battle.combat_resolver.resolve_heal(battle.units[3], erick)
	if resolver_result["healed"] != min(battle.units[3].heal, erick.max_hp - resolver_hp_before):
		push_error("Extracted combat resolver did not preserve heal amount rules.")
		quit(1)
		return

	erick.limit_charge = 0
	erick.gain_limit_charge(1)
	if erick.limit_charge != 1:
		push_error("Erick did not gain Limit Break charge.")
		quit(1)
		return
	battle.selected_unit = 0
	battle._refresh_combat_ui_for_unit(erick)
	if not battle.battle_ui.get_node("%BannerStats").text.contains("LIM 1/3"):
		push_error("Erick Limit Break charge did not refresh in the banner.")
		quit(1)
		return
	erick.gain_limit_charge(99)
	if erick.limit_charge != erick.limit_charge_max or not erick.is_limit_ready():
		push_error("Erick Limit Break charge did not cap at max readiness.")
		quit(1)
		return
	battle._refresh_combat_ui_for_unit(erick)
	if battle.battle_ui.get_node("%SpecialButton").text != "Corte listo" or battle.battle_ui.get_node("%SpecialButton").disabled:
		push_error("Ready Erick Limit Break did not enable the special button.")
		quit(1)
		return

	var guardia_limit_hp_before: int = guardia.hp
	guardia.hp = guardia.max_hp
	var limit_result: Dictionary = battle.combat_resolver.resolve_limit_break(erick, guardia)
	if limit_result["damage"] != erick.attack * erick.limit_damage_multiplier or erick.limit_charge != 0:
		push_error("Corte del Aguila resolver did not apply high damage and reset charge.")
		quit(1)
		return
	guardia.hp = guardia_limit_hp_before

	var guardia_grid_before_limit: Vector2i = guardia.grid
	var guardia_max_hp_before_limit: int = guardia.max_hp
	var guardia_hp_before_limit_action: int = guardia.hp
	var erick_limit_exp_before: int = erick.pending_exp
	guardia.move_to_grid(erick.grid + Vector2i(1, 0), battle._unit_screen_position(erick.grid + Vector2i(1, 0)))
	guardia.max_hp = 99
	guardia.hp = 99
	erick.limit_charge = erick.limit_charge_max
	battle.selected_unit = 0
	battle.selected_action = "special"
	if not battle._valid_targets_for_selected_action().has(4):
		push_error("Ready Erick Limit Break did not expose an adjacent enemy as a special target.")
		quit(1)
		return
	await battle._try_limit_break(0, 4)
	if erick.limit_charge != 0 or not erick.acted or guardia.hp != 99 - erick.attack * erick.limit_damage_multiplier:
		push_error("Corte del Aguila action did not consume charge, action, and enemy HP as expected.")
		quit(1)
		return
	guardia.max_hp = guardia_max_hp_before_limit
	guardia.hp = guardia_hp_before_limit_action
	guardia.move_to_grid(guardia_grid_before_limit, battle._unit_screen_position(guardia_grid_before_limit))
	erick.pending_exp = erick_limit_exp_before
	erick.limit_charge = 0
	erick.set_acted(false)
	battle._refresh_unit_depth_order()

	var hercules = battle.units[3]
	if hercules.team_heal != 2:
		push_error("Hercules team heal was not configured.")
		quit(1)
		return

	var erick_team_heal_hp_before: int = erick.hp
	var mitzi_hp_before: int = mitzi.hp
	var guardia_team_heal_hp_before: int = guardia.hp
	erick.hp = max(1, erick.max_hp - 3)
	mitzi.hp = max(1, mitzi.max_hp - 1)
	guardia.hp = max(1, guardia.hp - 1)
	var guardia_damaged_hp: int = guardia.hp
	var team_heals: Array[Dictionary] = battle.combat_resolver.resolve_team_heal(hercules, battle.units)
	if team_heals.size() != 2 or erick.hp != erick.max_hp - 1 or mitzi.hp != mitzi.max_hp or guardia.hp != guardia_damaged_hp:
		push_error("Cura+ resolver did not heal only injured allies by the configured amount.")
		quit(1)
		return
	erick.hp = erick_team_heal_hp_before
	mitzi.hp = mitzi_hp_before
	guardia.hp = guardia_team_heal_hp_before

	erick.hp = max(1, erick.max_hp - 2)
	mitzi.hp = max(1, mitzi.max_hp - 2)
	hercules.set_acted(false)
	battle._try_team_heal(3)
	if erick.hp != erick.max_hp or mitzi.hp != mitzi.max_hp or not hercules.acted:
		push_error("Hercules Cura+ action did not heal the team and consume his action.")
		quit(1)
		return
	erick.hp = erick_team_heal_hp_before
	mitzi.hp = mitzi_hp_before
	hercules.set_acted(false)

	var guardia_hp_before: int = guardia.hp
	var erick_hp_before: int = erick.hp
	var erick_grid_before: Vector2i = erick.grid
	erick.move_to_grid(guardia.grid + Vector2i(0, -1), battle._unit_screen_position(guardia.grid + Vector2i(0, -1)))
	var stable_hits: Array[Dictionary] = battle.combat_resolver.resolve_magic_aoe(diego, battle.units, guardia.grid, diego.magic_aoe_radius, false)
	if stable_hits.size() != 1 or stable_hits[0]["unit"] != guardia or stable_hits[0]["damage"] != diego.attack + 1:
		push_error("Stable Diego AoE should only damage enemies in the impact radius.")
		quit(1)
		return
	guardia.hp = guardia_hp_before
	erick.hp = erick_hp_before
	var unstable_hits: Array[Dictionary] = battle.combat_resolver.resolve_magic_aoe(diego, battle.units, guardia.grid, diego.magic_aoe_radius, true)
	var unstable_enemy_damage := -1
	var unstable_ally_damage := -1
	for hit in unstable_hits:
		if hit["unit"] == guardia:
			unstable_enemy_damage = hit["damage"]
		elif hit["unit"] == erick:
			unstable_ally_damage = hit["damage"]
	if unstable_enemy_damage != diego.attack + 1 or unstable_ally_damage != 1:
		push_error("Unstable Diego AoE did not apply full enemy damage and 1 HP ally damage.")
		quit(1)
		return
	guardia.hp = guardia_hp_before
	erick.hp = erick_hp_before
	erick.move_to_grid(erick_grid_before, battle._unit_screen_position(erick_grid_before))

	battle._show_crystal_feedback("-1", Color("#ff8f70"))
	if battle.crystal_feedback_text != "-1" or battle.crystal_feedback_timer <= 0.0:
		push_error("Crystal feedback did not start correctly.")
		quit(1)
		return
	if crystal_piece.feedback_text != "-1" or crystal_piece.feedback_timer <= 0.0:
		push_error("Crystal board piece did not receive feedback state.")
		quit(1)
		return

	erick.add_battle_exp(120)
	var exp_result: Dictionary = erick.apply_pending_exp()
	if exp_result["level_ups"] != 1 or erick.level != 2:
		push_error("Level up did not apply after pending EXP.")
		quit(1)
		return

	battle.battle_ui.show_results(true, "Cristal protegido", [{
		"name": erick.unit_name,
		"role": erick.role,
		"portrait_texture": erick.portrait_texture,
		"level": erick.level,
		"exp": erick.exp,
		"exp_to_next": erick.exp_to_next,
		"gained": exp_result["gained"],
		"level_ups": exp_result["level_ups"],
		"max_hp_gain": exp_result["max_hp_gain"],
		"attack_gain": exp_result["attack_gain"],
		"heal_gain": exp_result["heal_gain"],
		"alive": erick.is_alive()
	}])

	if not battle.battle_ui.get_node("%ResultPanel").visible:
		push_error("Result panel was not visible after showing battle results.")
		quit(1)
		return

	if not battle.battle_ui.get_node("%ResultBackdrop").visible:
		push_error("Result backdrop was not visible after showing battle results.")
		quit(1)
		return

	if not battle.battle_ui.get_node("%ResultMainMenuButton").visible:
		push_error("Result main menu button was not visible after showing battle results.")
		quit(1)
		return

	if battle.battle_ui.get_node("%PartyPanel").visible:
		push_error("Party panel stayed visible over battle results.")
		quit(1)
		return

	if battle.battle_ui.get_node("%ResultRows").get_child_count() != 2:
		push_error("Result panel did not render a header and one result row.")
		quit(1)
		return

	var result_row: HBoxContainer = battle.battle_ui.get_node("%ResultRows").get_child(1)
	var result_character_cell: HBoxContainer = result_row.get_child(0)
	var result_portrait_frame: PanelContainer = result_character_cell.get_child(0)
	if result_portrait_frame.get_child_count() == 0 or not result_portrait_frame.get_child(0) is TextureRect:
		push_error("Result panel did not render a character portrait.")
		quit(1)
		return

	save_state.character_progress = {
		"Erick": {
			"level": 3,
			"exp": 12,
			"exp_to_next": 140,
			"max_hp": 15,
			"attack": 5,
			"heal": 0
		}
	}
	save_state.apply_to_unit(erick)

	if erick.level != 3 or erick.max_hp != 15 or erick.attack != 5 or erick.hp != 15:
		push_error("Saved progress did not apply to a player unit.")
		quit(1)
		return

	save_state.reset_progress()
	battle._finalize_battle_rewards(true)

	if not FileAccess.file_exists(save_state.get_current_slot_path()):
		push_error("Victory rewards did not create a save file.")
		quit(1)
		return

	save_state.load_progress()
	if not save_state.character_progress.has("Erick"):
		push_error("Saved progress did not include Erick.")
		quit(1)
		return

	save_state.reset_all_slots()
	save_state.save_path = save_state.SAVE_PATH
	save_state.load_progress()
	paused = false
	music_manager.stop()

	quit(0)

func _cleanup(save_state: Node) -> void:
	paused = false
	var music_manager := root.get_node_or_null("/root/MusicManager")
	if music_manager != null:
		music_manager.stop()
	save_state.reset_all_slots()
	save_state.save_path = save_state.SAVE_PATH
	save_state.load_progress()

func _has_responsive_battle_ui_anchors(battle_ui: BattleUI) -> bool:
	var top_bar: Control = battle_ui.get_node("%TopBar")
	var unit_banner: Control = battle_ui.get_node("%UnitBanner")
	var result_backdrop: Control = battle_ui.get_node("%ResultBackdrop")
	var pause_backdrop: Control = battle_ui.get_node("%PauseBackdrop")
	var chapter_intro_panel: Control = battle_ui.get_node("%ChapterIntroPanel")
	var pause_panel: Control = battle_ui.get_node("%PausePanel")
	var action_panel: Control = battle_ui.get_node("%ActionPanel")
	var target_panel: Control = battle_ui.get_node("%TargetPanel")

	if top_bar.offset_right - top_bar.offset_left > 700.0:
		return false
	if unit_banner.anchor_bottom != 1.0:
		return false
	if result_backdrop.anchor_right != 1.0 or result_backdrop.anchor_bottom != 1.0:
		return false
	if pause_backdrop.anchor_right != 1.0 or pause_backdrop.anchor_bottom != 1.0:
		return false
	if chapter_intro_panel.anchor_left <= 0.0 or chapter_intro_panel.anchor_right >= 1.0:
		return false
	if pause_panel.anchor_left <= 0.0 or pause_panel.anchor_right >= 1.0:
		return false
	if action_panel.anchor_bottom <= action_panel.anchor_top:
		return false
	if target_panel.anchor_left <= 0.0 or target_panel.anchor_right <= target_panel.anchor_left:
		return false
	return true
