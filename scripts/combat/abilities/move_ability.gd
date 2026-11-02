class_name MoveAbility
extends Ability
## Walks along the navmesh. Costs AP by distance, and a destination that's too far
## away is clamped to as far as the unit can afford.

## Distance covered per AP spent.
@export var meters_per_ap: float = 2.0
## Shorter moves than this are rejected as accidental clicks.
@export var min_distance: float = 0.3


func get_ap_cost(user: Combatant, target: AbilityTarget) -> int:
    return ap_for_distance(path_length(resolve_path(user, target)))


func get_cost_label() -> String:
    return "%d/%.0fm" % [ap_cost, meters_per_ap]


func validate(user: Combatant, target: AbilityTarget) -> String:
    var reason: String = super(user, target)
    if not reason.is_empty():
        return reason
    if path_length(resolve_path(user, target)) < min_distance:
        return "Can't move there."
    return ""


func execute(user: Combatant, target: AbilityTarget) -> void:
    var path: PackedVector3Array = resolve_path(user, target)
    EventBus.combat_log_message.emit("%s moves %.1fm." % [user.get_display_name(), path_length(path)])
    await user.move_along_path(path)


## AP needed to cover [param distance] metres.
func ap_for_distance(distance: float) -> int:
    # The small epsilon stops float noise turning exactly 2.0m into 2 AP.
    return ceili(maxf(distance - 0.01, 0.0) / meters_per_ap)


## The path this move will take, clamped to the user's AP. Cached on [param target]
## so the cost doesn't change once AP has been spent.
func resolve_path(user: Combatant, target: AbilityTarget) -> PackedVector3Array:
    if target.path.is_empty():
        var budget: float = user.action_points.current_ap * meters_per_ap
        target.path = split_path(find_path(user, target.position), budget)[0]
    return target.path


## Full navmesh path from [param user] to [param destination], ignoring AP.
static func find_path(user: Combatant, destination: Vector3) -> PackedVector3Array:
    var map: RID = user.get_world_3d().navigation_map
    return NavigationServer3D.map_get_path(map, user.global_position, destination, true)


## Total length of [param path] in metres.
static func path_length(path: PackedVector3Array) -> float:
    var total: float = 0.0
    for i: int in range(1, path.size()):
        total += path[i - 1].distance_to(path[i])
    return total


## Splits [param path] at [param max_distance] metres. Returns
## [code][reachable, unreachable][/code]; both share the split point.
static func split_path(path: PackedVector3Array, max_distance: float) -> Array[PackedVector3Array]:
    var reachable: PackedVector3Array = PackedVector3Array()
    var unreachable: PackedVector3Array = PackedVector3Array()
    var result: Array[PackedVector3Array] = [reachable, unreachable]
    if path.is_empty():
        return result

    reachable.append(path[0])
    var travelled: float = 0.0
    for i: int in range(1, path.size()):
        var from: Vector3 = path[i - 1]
        var to: Vector3 = path[i]
        var segment: float = from.distance_to(to)
        if not unreachable.is_empty():
            unreachable.append(to)
        elif travelled + segment <= max_distance:
            reachable.append(to)
            travelled += segment
        else:
            var cut: Vector3 = from.lerp(to, (max_distance - travelled) / segment)
            reachable.append(cut)
            unreachable.append(cut)
            unreachable.append(to)
    result = [reachable, unreachable]
    return result
