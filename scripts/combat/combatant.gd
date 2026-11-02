class_name Combatant
extends CharacterBody3D
## A unit that takes part in turn-based combat, on either side.
##
## Holds no decision-making: PlayerTurnController or AITurnController choose what
## it does, and CombatManager performs it. Dead units are disabled rather than
## freed so references held by the turn order stay valid.

enum Faction { PARTY, ENEMY }

## Emitted when a [method move_along_path] order completes or gives up.
signal move_finished

const ARRIVE_DISTANCE: float = 0.1

@export var stats: CombatStats
@export var faction: Faction = Faction.PARTY
## Overrides [member CombatStats.display_name], e.g. "Thug B".
@export var display_name_override: String = ""

@export_group("Components")
@export var health: HealthComponent
@export var action_points: ActionPointsComponent
@export var collision_shape: CollisionShape3D
@export var visual: Node3D
@export var body_mesh: MeshInstance3D
@export var selection_ring: Node3D
@export var info_label: Label3D

@export_group("Movement")
@export var move_speed: float = 4.0
@export var turn_speed: float = 12.0

## Active status effects (per-unit copies).
var statuses: Array[StatusEffect] = []

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _body_material: StandardMaterial3D
var _path: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _is_moving: bool = false
var _move_time_left: float = 0.0


func _ready() -> void:
    health.setup(stats.max_hp)
    action_points.setup(stats.max_ap)
    health.hp_changed.connect(_on_hp_changed)
    health.died.connect(_on_died)
    action_points.ap_changed.connect(_on_ap_changed)

    _body_material = StandardMaterial3D.new()
    _body_material.albedo_color = stats.color
    body_mesh.material_override = _body_material

    set_selected(false)
    _update_label()


func _physics_process(delta: float) -> void:
    var horizontal: Vector3 = Vector3.ZERO
    if _is_moving:
        _move_time_left -= delta
        horizontal = _path_velocity()
        # The timeout stops a unit that gets wedged on geometry from hanging the turn.
        if horizontal == Vector3.ZERO or _move_time_left <= 0.0:
            _finish_move()

    velocity.x = horizontal.x
    velocity.z = horizontal.z
    if not is_on_floor():
        velocity.y -= _gravity * delta
    move_and_slide()
    _update_facing(delta)


## The name shown in the UI and combat log.
func get_display_name() -> String:
    return display_name_override if not display_name_override.is_empty() else stats.display_name


## True while hit points remain.
func is_alive() -> bool:
    return not health.is_dead()


## Called by CombatManager when this unit's turn begins.
func start_turn() -> void:
    _tick_statuses()
    action_points.refill()


## Shows or hides the active-turn ring.
func set_selected(selected: bool) -> void:
    selection_ring.visible = selected and is_alive()


## Walks along [param path] (world points, e.g. from the navmesh). Await to know when it arrives.
func move_along_path(path: PackedVector3Array) -> void:
    if path.size() < 2:
        return
    _path = path
    _path_index = 1
    _is_moving = true
    _move_time_left = MoveAbility.path_length(path) / move_speed + 1.0
    await move_finished


## Snaps to face [param world_position].
func face_towards(world_position: Vector3) -> void:
    var flat: Vector3 = world_position - global_position
    flat.y = 0.0
    if flat.length_squared() > 0.0001:
        # The model faces -Z.
        rotation.y = atan2(-flat.x, -flat.z)


## Applies [param amount] damage after status modifiers. Returns hit points actually lost.
func receive_damage(amount: int) -> int:
    var multiplier: float = 1.0
    for status: StatusEffect in statuses:
        multiplier *= status.damage_taken_multiplier
    var final_amount: int = maxi(1, roundi(amount * multiplier))
    var dealt: int = health.take_damage(final_amount)
    if dealt > 0:
        EventBus.combatant_damaged.emit(self, dealt)
    return dealt


## Adds a copy of [param effect], or refreshes its duration if already present.
func add_status(effect: StatusEffect) -> void:
    for status: StatusEffect in statuses:
        if status.id == effect.id:
            status.remaining_turns = effect.duration_turns
            EventBus.status_changed.emit(self)
            return
    var instance: StatusEffect = effect.duplicate()
    instance.remaining_turns = effect.duration_turns
    statuses.append(instance)
    _update_label()
    EventBus.status_changed.emit(self)


## True if a status with [param id] is active.
func has_status(id: StringName) -> bool:
    return statuses.any(func(status: StatusEffect) -> bool: return status.id == id)


func _tick_statuses() -> void:
    if statuses.is_empty():
        return
    for status: StatusEffect in statuses:
        status.remaining_turns -= 1
    statuses.assign(statuses.filter(func(status: StatusEffect) -> bool: return status.remaining_turns > 0))
    _update_label()
    EventBus.status_changed.emit(self)


func _path_velocity() -> Vector3:
    while _path_index < _path.size():
        var to_next: Vector3 = _path[_path_index] - global_position
        to_next.y = 0.0
        if to_next.length() > ARRIVE_DISTANCE:
            return to_next.normalized() * move_speed
        _path_index += 1
    return Vector3.ZERO


func _finish_move() -> void:
    _is_moving = false
    _path = PackedVector3Array()
    move_finished.emit()


func _update_facing(delta: float) -> void:
    var flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
    if flat.length_squared() < 0.01:
        return
    var target_yaw: float = atan2(-flat.x, -flat.z)
    rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


func _update_label() -> void:
    var text: String = "%s\n%d/%d" % [get_display_name(), health.current_hp, health.max_hp]
    if not is_alive():
        text = "%s\nDOWN" % get_display_name()
    for status: StatusEffect in statuses:
        text += "\n[%s]" % status.display_name
    info_label.text = text


func _on_hp_changed(current: int, maximum: int) -> void:
    _update_label()
    EventBus.hp_changed.emit(self, current, maximum)


func _on_ap_changed(current: int, maximum: int) -> void:
    EventBus.ap_changed.emit(self, current, maximum)


func _on_died() -> void:
    statuses.clear()
    set_selected(false)
    # No collision means no floor either, so stop physics before gravity takes it.
    set_physics_process(false)
    collision_shape.set_deferred("disabled", true)
    # Topple over and grey out; placeholder until there are death animations.
    visual.rotation_degrees.z = 90.0
    visual.position.y = 0.4
    _body_material.albedo_color = stats.color.darkened(0.6)
    _update_label()
    EventBus.combatant_died.emit(self)
