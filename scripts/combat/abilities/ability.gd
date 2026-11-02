class_name Ability
extends Resource
## Base class for anything a unit can do on its turn.
##
## To add an ability, either make a new .tres from an existing subclass
## (e.g. another DamageAbility with different numbers) or extend this class and
## override [method execute]. Then add it to a unit's [member CombatStats.abilities].
## CombatManager handles AP, validation and turn flow for every ability alike.

enum TargetMode {
    SELF,    ## Used instantly on the user.
    ENEMY,   ## Click a unit of the opposing faction.
    ALLY,    ## Click a unit of the user's faction (including themselves).
    GROUND,  ## Click a point in the world.
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var ap_cost: int = 1
## Max distance from the user to the target in metres. 0 means unlimited.
@export var max_range: float = 0.0
@export var target_mode: TargetMode = TargetMode.ENEMY


## AP this use will cost. Override for variable costs (see MoveAbility).
func get_ap_cost(_user: Combatant, _target: AbilityTarget) -> int:
    return ap_cost


## Short cost text for buttons, e.g. "3".
func get_cost_label() -> String:
    return str(ap_cost)


## Returns why [param user] can't use this on [param target], or "" if it can.
## Does not check AP; CombatManager does that.
func validate(user: Combatant, target: AbilityTarget) -> String:
    match target_mode:
        TargetMode.SELF:
            if target.combatant != user:
                return "%s can only target yourself." % display_name
        TargetMode.ENEMY:
            if not target.combatant or target.combatant.faction == user.faction:
                return "%s needs an enemy target." % display_name
        TargetMode.ALLY:
            if not target.combatant or target.combatant.faction != user.faction:
                return "%s needs an ally target." % display_name
        TargetMode.GROUND:
            if target.combatant:
                return "%s needs a spot on the ground." % display_name

    if target.combatant and not target.combatant.is_alive():
        return "That target is already down."
    if not is_in_range(user, target):
        return "Out of range (%s needs %.0fm)." % [display_name, max_range]
    return ""


## True if [param target] is within [member max_range] of [param user].
func is_in_range(user: Combatant, target: AbilityTarget) -> bool:
    if max_range <= 0.0:
        return true
    var offset: Vector3 = target.get_position() - user.global_position
    offset.y = 0.0
    return offset.length() <= max_range


## Performs the ability. AP has already been spent. May await (animations, movement).
func execute(_user: Combatant, _target: AbilityTarget) -> void:
    push_warning("Ability '%s' does not override execute()." % id)
