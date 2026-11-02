class_name AITurnController
extends Node
## Simple enemy brain for testing.
##
## Each step: pick the nearest living party member, hit it with the priciest
## damage ability that's affordable and in range, otherwise walk closer.
## Repeats until out of AP or out of useful options, then ends the turn.

@export var combat_manager: CombatManager
## Pause before each decision so the player can follow what happens.
@export var think_delay: float = 0.5
## Stop this fraction of an ability's range away from the target, for some slack.
@export var approach_range_factor: float = 0.8


## Called by CombatManager when an enemy unit's turn starts.
func begin_turn(unit: Combatant) -> void:
    _run_turn(unit)


func _run_turn(unit: Combatant) -> void:
    while true:
        var can_continue: bool = await _think(unit)
        if not can_continue:
            break
        var acted: bool = await _take_step(unit)
        if not acted:
            break
    if _is_my_turn(unit):
        combat_manager.end_turn(unit)


## Waits [member think_delay], then returns whether [param unit] can keep acting.
func _think(unit: Combatant) -> bool:
    await get_tree().create_timer(think_delay).timeout
    return _is_my_turn(unit) and unit.action_points.current_ap > 0


func _is_my_turn(unit: Combatant) -> bool:
    return combat_manager.is_running and combat_manager.active_combatant == unit


func _take_step(unit: Combatant) -> bool:
    var victim: Combatant = _nearest_opponent(unit)
    if not victim:
        return false
    var victim_target: AbilityTarget = AbilityTarget.at_combatant(victim)

    var attacks: Array[DamageAbility] = _affordable_attacks(unit)
    if attacks.is_empty():
        return false
    for attack: DamageAbility in attacks:
        if attack.validate(unit, victim_target).is_empty():
            return await combat_manager.perform(unit, attack, victim_target)

    return await _approach(unit, victim, attacks[0])


## Walks towards [param victim] until within [param attack]'s range, keeping
## enough AP to use it this turn when that's possible.
func _approach(unit: Combatant, victim: Combatant, attack: DamageAbility) -> bool:
    var move: MoveAbility = _find_move(unit)
    if not move:
        return false

    var to_unit: Vector3 = unit.global_position - victim.global_position
    to_unit.y = 0.0
    var stop_distance: float = attack.max_range * approach_range_factor
    var destination: Vector3 = victim.global_position + to_unit.normalized() * stop_distance

    var full_path: PackedVector3Array = MoveAbility.find_path(unit, destination)
    var budget: int = unit.action_points.current_ap - attack.ap_cost
    if budget < 1 or move.ap_for_distance(MoveAbility.path_length(full_path)) > budget:
        # Can't reach and still attack this turn, so close as much distance as possible.
        budget = unit.action_points.current_ap

    var target: AbilityTarget = AbilityTarget.at_position(destination)
    target.path = MoveAbility.split_path(full_path, budget * move.meters_per_ap)[0]
    if not move.validate(unit, target).is_empty():
        return false
    return await combat_manager.perform(unit, move, target)


func _nearest_opponent(unit: Combatant) -> Combatant:
    var nearest: Combatant
    var best_distance: float = INF
    for other: Combatant in combat_manager.combatants:
        if other.faction == unit.faction or not other.is_alive():
            continue
        var distance: float = unit.global_position.distance_squared_to(other.global_position)
        if distance < best_distance:
            best_distance = distance
            nearest = other
    return nearest


## Damage abilities [param unit] can pay for now, most expensive first.
func _affordable_attacks(unit: Combatant) -> Array[DamageAbility]:
    var attacks: Array[DamageAbility] = []
    for ability: Ability in unit.stats.abilities:
        if ability is DamageAbility and unit.action_points.can_afford(ability.ap_cost):
            attacks.append(ability as DamageAbility)
    attacks.sort_custom(func(a: DamageAbility, b: DamageAbility) -> bool: return a.ap_cost > b.ap_cost)
    return attacks


func _find_move(unit: Combatant) -> MoveAbility:
    for ability: Ability in unit.stats.abilities:
        if ability is MoveAbility:
            return ability as MoveAbility
    return null
