class_name SeeThroughController
extends Node
## Drives the see-through walls shader globals from the camera's point of view.
##
## Each frame it checks which nodes in [member SeeThroughSettings.target_group] are
## hidden behind [member SeeThroughSettings.occluder_mask] geometry, fades a hole in
## for them, and pushes their screen position, depth and radius to the
## [code]see_through_*[/code] global shader parameters.

## The global shader parameters only have slots for this many holes.
const MAX_TARGETS: int = 8
## How many hidden wall surfaces [method intersect_ray] will look through.
const MAX_PASS_THROUGH: int = 8
## Materials whose shader includes this file get cut, so their bodies can be clicked through.
const SHADER_INCLUDE: String = "see_through.gdshaderinc"

# The controller in the scene, used by the static ray helper.
static var _active: SeeThroughController

@export var camera: Camera3D
@export var settings: SeeThroughSettings:
    set(value):
        if settings and settings.changed.is_connected(_push_static_params):
            settings.changed.disconnect(_push_static_params)
        settings = value
        if settings and is_inside_tree():
            settings.changed.connect(_push_static_params)
            _push_static_params()

# Hole open amount (0..1) per target, keyed by instance id.
var _strengths: Dictionary[int, float] = {}
# Hole data last sent to the shader, so clicks can match what is on screen.
var _packed: Array[Vector4] = []
# CPU copy of settings.mask_texture, fetched lazily.
var _mask_image: Image
# Whether a collider has a see-through material, keyed by instance id.
var _see_through_bodies: Dictionary[int, bool] = {}


func _ready() -> void:
    _active = self
    if settings and not settings.changed.is_connected(_push_static_params):
        settings.changed.connect(_push_static_params)
    _push_static_params()
    EventBus.see_through_toggled.connect(_on_see_through_toggled)
    EventBus.see_through_settings_changed.connect(_on_see_through_settings_changed)


func _exit_tree() -> void:
    if _active == self:
        _active = null
    # Leave no stale holes behind for the next level.
    RenderingServer.global_shader_parameter_set("see_through_count", 0)
    RenderingServer.global_shader_parameter_set("see_through_near_enabled", false)


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_see_through") and settings:
        EventBus.see_through_toggled.emit(not settings.enabled)


func _process(delta: float) -> void:
    if not camera or not settings or not settings.enabled or not settings.cutout_enabled:
        _strengths.clear()
        _packed.clear()
        RenderingServer.global_shader_parameter_set("see_through_count", 0)
        return

    var weight: float = 1.0 - exp(-settings.fade_speed * delta)
    var space: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
    var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
    var camera_position: Vector3 = camera.global_position
    var view: Transform3D = camera.global_transform.affine_inverse()
    var alive: Dictionary[int, float] = {}
    _packed.clear()

    for node: Node in get_tree().get_nodes_in_group(settings.target_group):
        var target: Node3D = node as Node3D
        if not target or not target.is_visible_in_tree():
            continue
        var point: Vector3 = target.global_position + Vector3.UP * settings.target_height_offset
        if camera.is_position_behind(point):
            continue

        var id: int = target.get_instance_id()
        var occluded: float = 1.0 if _is_occluded(space, camera_position, point, target) else 0.0
        var strength: float = lerpf(_strengths.get(id, 0.0), occluded, weight)
        alive[id] = strength
        if strength < 0.01 or _packed.size() >= MAX_TARGETS:
            continue

        var screen: Vector2 = camera.unproject_position(point)
        var edge: Vector2 = camera.unproject_position(point + camera.global_basis.x * settings.cutout_radius)
        var radius: float = screen.distance_to(edge) / viewport_size.y
        var depth: float = -(view * point).z
        var packed: Vector4 = Vector4(screen.x / viewport_size.x, screen.y / viewport_size.y, depth, radius * strength)
        RenderingServer.global_shader_parameter_set("see_through_target_%d" % _packed.size(), packed)
        _packed.append(packed)

    _strengths = alive
    RenderingServer.global_shader_parameter_set("see_through_count", _packed.size())


## Raycasts like [method PhysicsDirectSpaceState3D.intersect_ray], but looks through
## see-through walls wherever they are currently cut away at [param screen_position].
## Use it for mouse picking so clicks reach what the player can actually see.
static func intersect_ray(camera: Camera3D, screen_position: Vector2, query: PhysicsRayQueryParameters3D) -> Dictionary:
    var space: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
    var hit: Dictionary = space.intersect_ray(query)
    if not _active or not _active.settings or not _active.settings.enabled:
        return hit
    for i: int in MAX_PASS_THROUGH:
        if hit.is_empty() or not _active._is_see_through_body(hit["collider"]):
            break
        if not _active.is_point_hidden(screen_position, hit["position"]):
            break
        var exclude: Array[RID] = query.exclude
        exclude.append(hit["rid"])
        query.exclude = exclude
        hit = space.intersect_ray(query)
    return hit


## True if a see-through surface at [param world_point], seen at [param screen_position],
## is currently cut away. Mirrors [code]see_through_cut[/code] in the shader, without dither.
func is_point_hidden(screen_position: Vector2, world_point: Vector3) -> bool:
    if not camera or not settings or not settings.enabled:
        return false

    if settings.near_fade_enabled:
        var near_limit: float = settings.near_fade_distance - settings.near_fade_softness * 0.5
        if camera.global_position.distance_to(world_point) < near_limit:
            return true

    var mask: Image = _get_mask_image()
    if not settings.cutout_enabled or not mask or _packed.is_empty():
        return false
    var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
    var screen_uv: Vector2 = screen_position / viewport_size
    var aspect: float = viewport_size.x / viewport_size.y
    var depth: float = -(camera.global_transform.affine_inverse() * world_point).z
    var mask_size: Vector2 = Vector2(mask.get_size())

    for target: Vector4 in _packed:
        if target.w <= 0.0 or depth > target.z - settings.depth_bias:
            continue
        var offset: Vector2 = (screen_uv - Vector2(target.x, target.y)) * Vector2(aspect, 1.0) / target.w
        var mask_uv: Vector2 = offset * 0.5 + Vector2(0.5, 0.5)
        if mask_uv.x < 0.0 or mask_uv.y < 0.0 or mask_uv.x > 1.0 or mask_uv.y > 1.0:
            continue
        var pixel: Vector2i = Vector2i((mask_uv * mask_size).floor()).clamp(Vector2i.ZERO, mask.get_size() - Vector2i.ONE)
        var color: Color = mask.get_pixelv(pixel)
        if color.r * color.a < settings.mask_threshold:
            return true
    return false


func _is_occluded(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, target: Node3D) -> bool:
    var exclude: Array[RID] = []
    if target is CollisionObject3D:
        exclude.append((target as CollisionObject3D).get_rid())
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
        from, to, settings.occluder_mask, exclude)
    return not space.intersect_ray(query).is_empty()


func _get_mask_image() -> Image:
    if not _mask_image and settings and settings.mask_texture:
        _mask_image = settings.mask_texture.get_image()
        if _mask_image and _mask_image.is_compressed():
            _mask_image.decompress()
    return _mask_image


func _is_see_through_body(collider: Object) -> bool:
    var body: CollisionObject3D = collider as CollisionObject3D
    if not body:
        return false
    var id: int = body.get_instance_id()
    if not _see_through_bodies.has(id):
        var found: bool = false
        for child: Node in body.get_children():
            var mesh: MeshInstance3D = child as MeshInstance3D
            if not mesh or not mesh.mesh:
                continue
            for surface: int in mesh.mesh.get_surface_count():
                var material: ShaderMaterial = mesh.get_active_material(surface) as ShaderMaterial
                if material and material.shader and material.shader.code.contains(SHADER_INCLUDE):
                    found = true
        _see_through_bodies[id] = found
    return _see_through_bodies[id]


func _push_static_params() -> void:
    _mask_image = null
    var on: bool = settings != null and settings.enabled
    RenderingServer.global_shader_parameter_set("see_through_cutout_enabled",
        on and settings.cutout_enabled and settings.mask_texture != null)
    RenderingServer.global_shader_parameter_set("see_through_near_enabled", on and settings.near_fade_enabled)
    if not settings:
        return
    RenderingServer.global_shader_parameter_set("see_through_mask", settings.mask_texture)
    RenderingServer.global_shader_parameter_set("see_through_mask_threshold", settings.mask_threshold)
    RenderingServer.global_shader_parameter_set("see_through_edge_softness", settings.edge_softness)
    RenderingServer.global_shader_parameter_set("see_through_edge_color", settings.edge_color)
    RenderingServer.global_shader_parameter_set("see_through_edge_width", settings.edge_width)
    RenderingServer.global_shader_parameter_set("see_through_depth_bias", settings.depth_bias)
    RenderingServer.global_shader_parameter_set("see_through_near_distance", settings.near_fade_distance)
    RenderingServer.global_shader_parameter_set("see_through_near_softness", settings.near_fade_softness)


func _on_see_through_toggled(enabled: bool) -> void:
    if settings:
        settings.enabled = enabled


func _on_see_through_settings_changed(new_settings: SeeThroughSettings) -> void:
    settings = new_settings
