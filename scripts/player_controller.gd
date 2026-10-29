class_name PlayerController
extends CharacterBody3D
## Exploration-mode player movement.
##
## Mouse players click the ground and the character pathfinds there via its
## NavigationAgent3D. Controller players steer directly with the left stick,
## relative to the active camera's facing.

@export var nav_agent: NavigationAgent3D
@export var move_speed: float = 4.0
@export var turn_speed: float = 12.0
@export var stick_deadzone: float = 0.2

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _stick_active: bool = false


func _ready() -> void:
    EventBus.ground_clicked.connect(_on_ground_clicked)


func _physics_process(delta: float) -> void:
    var horizontal: Vector3 = _stick_velocity()
    if horizontal == Vector3.ZERO and not nav_agent.is_navigation_finished():
        horizontal = _path_velocity()

    velocity.x = horizontal.x
    velocity.z = horizontal.z
    if not is_on_floor():
        velocity.y -= _gravity * delta

    move_and_slide()
    _update_facing(delta)


## Cancels any active click-to-move path.
func stop() -> void:
    nav_agent.target_position = global_position


func _stick_velocity() -> Vector3:
    var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back", stick_deadzone)
    if input == Vector2.ZERO:
        _stick_active = false
        return Vector3.ZERO

    if not _stick_active:
        _stick_active = true
        stop()
        EventBus.camera_focus_requested.emit(self)

    var camera: Camera3D = get_viewport().get_camera_3d()
    var yaw: float = camera.global_rotation.y if camera else 0.0
    # Input length is kept so partial stick tilt walks slower.
    return Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw) * move_speed


func _path_velocity() -> Vector3:
    var to_next: Vector3 = nav_agent.get_next_path_position() - global_position
    to_next.y = 0.0
    if to_next.length_squared() < 0.0001:
        return Vector3.ZERO
    return to_next.normalized() * move_speed


func _update_facing(delta: float) -> void:
    var flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
    if flat.length_squared() < 0.01:
        return
    # The model faces -Z.
    var target_yaw: float = atan2(-flat.x, -flat.z)
    rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


func _on_ground_clicked(world_position: Vector3) -> void:
    nav_agent.target_position = world_position
