extends RefCounted
class_name BattleCameraController

const PAN_SPEED := 520.0
const DRAG_BUTTON := MOUSE_BUTTON_MIDDLE

var offset := Vector2.ZERO
var is_dragging := false
var last_drag_position := Vector2.ZERO

func keyboard_pan_delta(delta: float, input_locked: bool) -> Vector2:
	if input_locked:
		return Vector2.ZERO

	var direction := Vector2.ZERO
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		direction.x += 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		direction.x -= 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		direction.y += 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		direction.y -= 1.0
	if direction == Vector2.ZERO:
		return Vector2.ZERO
	return direction.normalized() * PAN_SPEED * delta

func handles_drag_button(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.button_index == DRAG_BUTTON

func set_dragging(pressed: bool, position: Vector2) -> void:
	is_dragging = pressed
	last_drag_position = position

func drag_delta(position: Vector2) -> Vector2:
	if not is_dragging:
		return Vector2.ZERO
	var delta := position - last_drag_position
	last_drag_position = position
	return delta

func stop_dragging() -> void:
	is_dragging = false

func recenter_offset(layout: Dictionary) -> Vector2:
	return layout["camera_start_offset"]

func constrained_offset(next_offset: Vector2, layout: Dictionary, render_context: Dictionary, battlefield_renderer: RefCounted) -> Vector2:
	var clamped_offset := Vector2(
		clamp(next_offset.x, layout["camera_min_offset"].x, layout["camera_max_offset"].x),
		clamp(next_offset.y, layout["camera_min_offset"].y, layout["camera_max_offset"].y)
	)
	return battlefield_renderer.clamp_camera_offset(render_context, clamped_offset)
