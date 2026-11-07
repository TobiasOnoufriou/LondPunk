class_name PlayerController
extends CharacterBody3D
## Exploration-mode player movement.
##
## Mouse players click the ground and the character pathfinds there via its
## NavigationAgent3D. Controller players steer directly with the left stick,
## relative to the active camera's facing. Clicking an [Interactable] walks
## within its range and then uses it.

@export var nav_agent: NavigationAgent3D
@export var move_speed: float = 4.0
@export var turn_speed: float = 12.0
@export var stick_deadzone: float = 0.2

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _stick_active: bool = false
var _in_conversation: bool = false
var _pending_interaction: Interactable


func _ready() -> void:
    EventBus.ground_clicked.connect(_on_ground_clicked)
    EventBus.interactable_clicked.connect(_on_interactable_clicked)
    EventBus.conversation_started.connect(_on_conversation_started)
    EventBus.conversation_ended.connect(_on_conversation_ended)


func _physics_process(delta: float) -> void:
    _try_pending_interaction()
    var horizontal: Vector3 = _stick_velocity() if not _in_conversation else Vector3.ZERO
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


## Shows and enables the Player, or hides and freezes it (e.g. while the party fights).
func set_active(active: bool) -> void:
    stop()
    _pending_interaction = null
    visible = active
    set_physics_process(active)
    velocity = Vector3.ZERO


## Moves straight to [param world_position] without pathing.
func teleport(world_position: Vector3) -> void:
    global_position = world_position
    stop()


func _accepts_orders() -> bool:
    return is_physics_processing() and not _in_conversation


func _try_pending_interaction() -> void:
    if _pending_interaction == null:
        return
    if not is_instance_valid(_pending_interaction) or not _pending_interaction.enabled:
        _pending_interaction = null
        return
    if not _pending_interaction.is_in_range(global_position):
        return
    var target: Interactable = _pending_interaction
    _pending_interaction = null
    stop()
    _face_towards(target.global_position)
    target.interact(self)


func _stick_velocity() -> Vector3:
    var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back", stick_deadzone)
    if input == Vector2.ZERO:
        _stick_active = false
        return Vector3.ZERO

    if not _stick_active:
        _stick_active = true
        stop()
        _pending_interaction = null
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


func _face_towards(world_position: Vector3) -> void:
    var flat: Vector3 = world_position - global_position
    flat.y = 0.0
    if flat.length_squared() > 0.0001:
        rotation.y = atan2(-flat.x, -flat.z)


func _on_ground_clicked(world_position: Vector3) -> void:
    if not _accepts_orders():
        return
    _pending_interaction = null
    nav_agent.target_position = world_position


func _on_interactable_clicked(interactable: Interactable) -> void:
    if not _accepts_orders() or not interactable.enabled:
        return
    _pending_interaction = interactable
    nav_agent.target_position = interactable.global_position


func _on_conversation_started(_speaker: Node3D) -> void:
    _in_conversation = true
    _pending_interaction = null
    stop()


func _on_conversation_ended(_speaker: Node3D) -> void:
    _in_conversation = false
    # Hand the camera back after it framed the speaker.
    if is_physics_processing():
        EventBus.camera_focus_requested.emit(self)
