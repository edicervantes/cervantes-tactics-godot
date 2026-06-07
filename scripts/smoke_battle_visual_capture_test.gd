extends SceneTree

const CAPTURE_PATH := "user://cervantes_battle_visual_capture.png"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_state: Node = root.get_node("/root/SaveState")
	save_state.save_path = "user://cervantes_smoke_visual_capture_save.json"
	save_state.reset_all_slots()

	var battle_scene: PackedScene = load("res://scenes/Battle3D.tscn")
	var battle := battle_scene.instantiate()
	root.add_child(battle)
	await process_frame
	battle.battle_ui.chapter_intro_started.emit()
	await process_frame
	while battle.phase == battle.Phase.INTRO:
		battle._advance_dialog()
		await process_frame

	battle._select_player(0)
	battle._set_selected_action("move")
	battle._update_hovered_grid(battle.grid_to_screen(Vector2i(2, 4)))
	await process_frame
	await process_frame
	battle.battle_ui.visible = false
	await process_frame

	if DisplayServer.get_name() == "headless":
		push_warning("Battle visual capture skipped because headless rendering has no readable framebuffer.")
		battle.queue_free()
		quit(0)
		return

	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_warning("Battle visual capture skipped because the renderer did not expose a viewport texture.")
		battle.queue_free()
		quit(0)
		return

	var image: Image = viewport_texture.get_image()
	if image == null or image.is_empty():
		push_warning("Battle visual capture skipped because the renderer produced no readable image.")
		battle.queue_free()
		quit(0)
		return

	var result := image.save_png(CAPTURE_PATH)
	if result != OK:
		push_error("Battle visual capture could not be saved: %s." % result)
		quit(1)
		return

	if _sample_visual_variance(image) < 16:
		push_error("Battle visual capture looks too flat; expected rendered map and units.")
		quit(1)
		return

	battle.queue_free()
	quit(0)

func _sample_visual_variance(image: Image) -> int:
	var colors := {}
	var step_x: int = max(1, int(image.get_width() / 32))
	var step_y: int = max(1, int(image.get_height() / 18))
	for y in range(0, image.get_height(), step_y):
		for x in range(0, image.get_width(), step_x):
			var color: Color = image.get_pixel(x, y)
			var bucket := "%02d:%02d:%02d" % [
				int(color.r * 16.0),
				int(color.g * 16.0),
				int(color.b * 16.0)
			]
			colors[bucket] = true
	return colors.size()
