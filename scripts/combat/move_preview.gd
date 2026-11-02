class_name MovePreview
extends Node3D
## While Move is armed, draws the path to the hovered point: the affordable part
## in one colour, the rest in another, with the AP cost at the end.

@export var path_mesh: MeshInstance3D
@export var cost_label: Label3D
@export var reachable_color: Color = Color(0.2, 1.0, 0.5)
@export var unreachable_color: Color = Color(1.0, 0.25, 0.25)
@export var ribbon_width: float = 0.15
@export var height_offset: float = 0.05
@export_flags_3d_physics var ground_mask: int = 1
@export var ray_length: float = 1000.0

var _unit: Combatant
var _move: MoveAbility
var _busy: bool = false
var _mesh: ImmediateMesh
var _last_point: Vector3 = Vector3.INF


func _ready() -> void:
    # Vertices are written in world space.
    global_transform = Transform3D.IDENTITY
    _mesh = ImmediateMesh.new()
    path_mesh.mesh = _mesh
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo = true
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    path_mesh.material_override = material

    EventBus.ability_armed.connect(_on_ability_armed)
    EventBus.ability_used.connect(_on_ability_used)
    EventBus.action_resolved.connect(_on_action_resolved)
    _clear()


func _process(_delta: float) -> void:
    if not _unit or not _move or _busy:
        return
    var point: Vector3 = _mouse_ground_point()
    if point == Vector3.INF:
        _clear()
        return
    if point.distance_to(_last_point) < 0.05:
        return
    _last_point = point

    var full_path: PackedVector3Array = MoveAbility.find_path(_unit, point)
    var budget: float = _unit.action_points.current_ap * _move.meters_per_ap
    var parts: Array[PackedVector3Array] = MoveAbility.split_path(full_path, budget)
    var reachable: PackedVector3Array = parts[0]
    var unreachable: PackedVector3Array = parts[1]
    if reachable.size() < 2:
        _clear()
        return

    _mesh.clear_surfaces()
    _add_ribbon(reachable, reachable_color)
    _add_ribbon(unreachable, unreachable_color)

    var cost: int = _move.ap_for_distance(MoveAbility.path_length(reachable))
    cost_label.text = "%d AP" % cost
    if MoveAbility.path_length(unreachable) > 0.05:
        cost_label.text += " (partial)"
    cost_label.global_position = reachable[reachable.size() - 1] + Vector3.UP * 0.6
    cost_label.visible = true


func _clear() -> void:
    _mesh.clear_surfaces()
    cost_label.visible = false
    _last_point = Vector3.INF


func _add_ribbon(path: PackedVector3Array, color: Color) -> void:
    var vertices: PackedVector3Array = PackedVector3Array()
    var lift: Vector3 = Vector3.UP * height_offset
    for i: int in range(1, path.size()):
        var a: Vector3 = path[i - 1] + lift
        var b: Vector3 = path[i] + lift
        var direction: Vector3 = b - a
        direction.y = 0.0
        if direction.length_squared() < 0.000001:
            continue
        var side: Vector3 = direction.normalized().cross(Vector3.UP) * ribbon_width * 0.5
        vertices.append_array(PackedVector3Array([a - side, a + side, b + side, a - side, b + side, b - side]))
    if vertices.is_empty():
        return

    _mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    for vertex: Vector3 in vertices:
        _mesh.surface_set_color(color)
        _mesh.surface_add_vertex(vertex)
    _mesh.surface_end()


func _mouse_ground_point() -> Vector3:
    var camera: Camera3D = get_viewport().get_camera_3d()
    if not camera:
        return Vector3.INF
    var mouse: Vector2 = get_viewport().get_mouse_position()
    var origin: Vector3 = camera.project_ray_origin(mouse)
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
        origin, origin + camera.project_ray_normal(mouse) * ray_length, ground_mask)
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return Vector3.INF
    return hit["position"]


func _on_ability_armed(user: Combatant, ability: Ability) -> void:
    if ability is MoveAbility:
        _unit = user
        _move = ability
    else:
        _unit = null
        _move = null
    _clear()


func _on_ability_used(_user: Combatant, _ability: Ability, _target: AbilityTarget) -> void:
    _busy = true
    _clear()


func _on_action_resolved(_user: Combatant) -> void:
    _busy = false
