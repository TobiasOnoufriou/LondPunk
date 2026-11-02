class_name PlayerTurnController
extends Node
## Turns player input into ability uses during party turns.
##
## Listens to EventBus for UI requests and world clicks; never touches the HUD.

@export var combat_manager: CombatManager

var _unit: Combatant
var _armed: Ability


func _ready() -> void:
    EventBus.ability_selected.connect(_on_ability_selected)
    EventBus.ability_cancelled.connect(_on_ability_cancelled)
    EventBus.end_turn_requested.connect(_on_end_turn_requested)
    EventBus.ground_clicked.connect(_on_ground_clicked)
    EventBus.combatant_clicked.connect(_on_combatant_clicked)
    EventBus.turn_ended.connect(_on_turn_ended)


## Called by CombatManager when a party unit's turn starts.
func begin_turn(unit: Combatant) -> void:
    _unit = unit
    _arm(_default_ability())


func _arm(ability: Ability) -> void:
    _armed = ability
    EventBus.ability_armed.emit(_unit, _armed)


## Move if the unit has it, so a fresh turn can click-to-walk straight away.
func _default_ability() -> Ability:
    for ability: Ability in _unit.stats.abilities:
        if ability is MoveAbility:
            return ability
    return null


func _use(ability: Ability, target: AbilityTarget) -> void:
    var unit: Combatant = _unit
    var performed: bool = await combat_manager.perform(unit, ability, target)
    # After a one-off action, drop back to Move if it's still this unit's turn.
    if performed and _unit == unit and combat_manager.active_combatant == unit and not (ability is MoveAbility):
        _arm(_default_ability())


func _can_act() -> bool:
    return _unit != null and not combat_manager.busy


func _on_ability_selected(ability: Ability) -> void:
    if not _can_act() or not _unit.stats.abilities.has(ability):
        return
    if ability.target_mode == Ability.TargetMode.SELF:
        _use(ability, AbilityTarget.at_combatant(_unit))
    else:
        _arm(ability)


func _on_ability_cancelled() -> void:
    if not _can_act():
        return
    var fallback: Ability = _default_ability()
    _arm(null if _armed == fallback else fallback)


func _on_end_turn_requested() -> void:
    if _can_act():
        combat_manager.end_turn(_unit)


func _on_ground_clicked(world_position: Vector3) -> void:
    if _can_act() and _armed and _armed.target_mode == Ability.TargetMode.GROUND:
        _use(_armed, AbilityTarget.at_position(world_position))


func _on_combatant_clicked(combatant: Combatant) -> void:
    if not _can_act() or not _armed:
        return
    if _armed.target_mode == Ability.TargetMode.ENEMY or _armed.target_mode == Ability.TargetMode.ALLY:
        _use(_armed, AbilityTarget.at_combatant(combatant))


func _on_turn_ended(unit: Combatant) -> void:
    if unit != _unit:
        return
    _unit = null
    _armed = null
    EventBus.ability_armed.emit(unit, null)
