class_name CameraRig
extends Node3D
## Free-roaming isometric-style exploration camera.
##
## The rig's origin is the ground focus point. Yaw and pitch pivots orbit the
## camera around it, and zoom is the camera's distance along the pitch pivot's +Z.

@export_group("References")
@export var camera: Camera3D
@export var yaw_pivot: Node3D
@export var pitch_pivot: Node3D
@export var follow_target: Node3D

@export_group("Pan")
@export var pan_speed: float = 12.0
@export var edge_pan_enabled: bool = false
@export var edge_pan_margin: float = 12.0

@export_group("Rotate & Tilt")
@export var rotate_speed_deg: float = 120.0
@export var mouse_sensitivity_deg: float = 0.3
@export var default_yaw_deg: float = 45.0
@export var default_pitch_deg: float = 55.0
@export var min_pitch_deg: float = 30.0
@export var max_pitch_deg: float = 75.0

@export_group("Zoom")
@export var min_zoom: float = 6.0
@export var max_zoom: float = 30.0
@export var default_zoom: float = 16.0
@export var zoom_step: float = 2.0
@export var stick_zoom_speed: float = 15.0

@export_group("Follow & Smoothing")
@export var focus_height_offset: float = 1.0
@export var smoothing: float = 10.0

@export_group("Click")
@export_flags_3d_physics var click_collision_mask: int = 1 | 4
## Layers checked for [Interactable] areas, which win over whatever is behind them.
@export_flags_3d_physics var interact_collision_mask: int = 8
@export var click_ray_length: float = 1000.0

## True while the rig is tracking [member follow_target]. Manual panning clears it.
var following: bool = true

var _target_position: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _target_pitch: float = 0.0
var _target_zoom: float = 0.0
var _is_drag_rotating: bool = false


func _ready() -> void:
	_target_yaw = deg_to_rad(default_yaw_deg)
	_target_pitch = deg_to_rad(default_pitch_deg)
	_target_zoom = default_zoom
	if follow_target:
		global_position = _follow_point()
	_target_position = global_position

	yaw_pivot.rotation.y = _target_yaw
	pitch_pivot.rotation.x = -_target_pitch
	camera.position = Vector3(0.0, 0.0, _target_zoom)

	EventBus.camera_focus_requested.connect(_on_camera_focus_requested)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.is_action_pressed("move_click"):
			_try_ground_click(mouse_event.position)
		elif mouse_event.is_action_pressed("cam_zoom_in"):
			_target_zoom = clampf(_target_zoom - zoom_step, min_zoom, max_zoom)
		elif mouse_event.is_action_pressed("cam_zoom_out"):
			_target_zoom = clampf(_target_zoom + zoom_step, min_zoom, max_zoom)

	if event.is_action_pressed("cam_rotate_drag"):
		_is_drag_rotating = true
	elif event.is_action_released("cam_rotate_drag"):
		_is_drag_rotating = false

	if event is InputEventMouseMotion and _is_drag_rotating:
		var motion: InputEventMouseMotion = event
		_target_yaw -= deg_to_rad(motion.relative.x * mouse_sensitivity_deg)
		_set_target_pitch(_target_pitch + deg_to_rad(motion.relative.y * mouse_sensitivity_deg))

	if event.is_action_pressed("cam_focus_player") and follow_target:
		focus_on(follow_target)


func _process(delta: float) -> void:
	_handle_pan(delta)
	_handle_rotation(delta)
	_handle_stick_zoom(delta)

	if following and follow_target:
		_target_position = _follow_point()

	var weight: float = 1.0 - exp(-smoothing * delta)
	global_position = global_position.lerp(_target_position, weight)
	yaw_pivot.rotation.y = lerp_angle(yaw_pivot.rotation.y, _target_yaw, weight)
	pitch_pivot.rotation.x = lerpf(pitch_pivot.rotation.x, -_target_pitch, weight)
	camera.position.z = lerpf(camera.position.z, _target_zoom, weight)


## Centres the camera on [param target] and keeps following it.
func focus_on(target: Node3D) -> void:
	follow_target = target
	following = true


func _handle_pan(delta: float) -> void:
	var input: Vector2 = Input.get_vector("cam_pan_left", "cam_pan_right", "cam_pan_forward", "cam_pan_back")
	if edge_pan_enabled:
		input = (input + _edge_pan_input()).limit_length(1.0)
	if input == Vector2.ZERO:
		return

	following = false
	var direction: Vector3 = Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, _target_yaw)
	# Pan faster when zoomed out so screen-space speed feels constant.
	var zoom_factor: float = _target_zoom / default_zoom
	_target_position += direction * pan_speed * zoom_factor * delta


func _handle_rotation(delta: float) -> void:
	var yaw_input: float = Input.get_axis("cam_rotate_left", "cam_rotate_right")
	var tilt_input: float = Input.get_axis("cam_tilt_down", "cam_tilt_up")
	var step: float = deg_to_rad(rotate_speed_deg) * delta
	_target_yaw += yaw_input * step
	_set_target_pitch(_target_pitch + tilt_input * step)


func _handle_stick_zoom(delta: float) -> void:
	var zoom_input: float = Input.get_axis("cam_zoom_in_stick", "cam_zoom_out_stick")
	if zoom_input != 0.0:
		_target_zoom = clampf(_target_zoom + zoom_input * stick_zoom_speed * delta, min_zoom, max_zoom)


func _edge_pan_input() -> Vector2:
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var mouse: Vector2 = get_viewport().get_mouse_position()
	if not viewport_rect.has_point(mouse):
		return Vector2.ZERO

	var input: Vector2 = Vector2.ZERO
	if mouse.x < edge_pan_margin:
		input.x = -1.0
	elif mouse.x > viewport_rect.size.x - edge_pan_margin:
		input.x = 1.0
	if mouse.y < edge_pan_margin:
		input.y = -1.0
	elif mouse.y > viewport_rect.size.y - edge_pan_margin:
		input.y = 1.0
	return input


func _set_target_pitch(pitch: float) -> void:
	_target_pitch = clampf(pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))


func _follow_point() -> Vector3:
	return follow_target.global_position + Vector3.UP * focus_height_offset


func _try_ground_click(screen_position: Vector2) -> void:
	var origin: Vector3 = camera.project_ray_origin(screen_position)
	var direction: Vector3 = camera.project_ray_normal(screen_position)
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + direction * click_ray_length, click_collision_mask)
	var hit: Dictionary = space.intersect_ray(query)

	# Interactables are areas, so they get their own ray that ignores bodies.
	var area_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + direction * click_ray_length, interact_collision_mask)
	area_query.collide_with_areas = true
	area_query.collide_with_bodies = false
	var area_hit: Dictionary = space.intersect_ray(area_query)
	if not area_hit.is_empty() and area_hit["collider"] is Interactable:
		var area_position: Vector3 = area_hit["position"]
		var body_position: Vector3 = hit.get("position", Vector3.INF)
		if hit.is_empty() or origin.distance_to(area_position) <= origin.distance_to(body_position):
			EventBus.interactable_clicked.emit(area_hit["collider"])
			return

	if hit.is_empty():
		return
	var collider: Object = hit["collider"]
	if collider is Combatant:
		EventBus.combatant_clicked.emit(collider)
		return
	var hit_position: Vector3 = hit["position"]
	EventBus.ground_clicked.emit(hit_position)


func _on_camera_focus_requested(target: Node3D) -> void:
	focus_on(target)
